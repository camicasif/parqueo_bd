CREATE OR REPLACE FUNCTION core.validar_vehiculo_y_usuario(p_placa TEXT)
    RETURNS RECORD AS $$
DECLARE
    result RECORD;
BEGIN
    SELECT u.id_usuario, u.id_tipo_usuario, v.id_tipo_vehiculo
    INTO result
    FROM core.vehiculo v
             JOIN core.usuario u ON u.id_usuario = v.id_usuario
    WHERE v.placa = p_placa;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El vehículo con placa % no existe.', p_placa;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.validar_espacio_existente(p_id_espacio INT)
    RETURNS RECORD AS $$
DECLARE
    result RECORD;
BEGIN
    SELECT ep.*, sp.id_tipo_usuario
    INTO result
    FROM core.espacio_parqueo ep
             JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
    WHERE ep.id_espacio_parqueo = p_id_espacio;

    IF NOT FOUND THEN
        RAISE NOTICE 'Error: El espacio de parqueo % no existe.', p_id_espacio;
        RETURN NULL;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.validar_compatibilidad_seccion(
    p_id_tipo_usuario INT,
    p_id_tipo_vehiculo INT,
    p_id_seccion INT
) RETURNS BOOLEAN AS $$
BEGIN
    IF p_id_tipo_usuario = 5 THEN
        -- Discapacitado: solo validar compatibilidad con tipo de vehículo
        RETURN EXISTS (
            SELECT 1
            FROM config.tipo_vehiculo_seccion
            WHERE id_seccion = p_id_seccion
              AND id_tipo_vehiculo = p_id_tipo_vehiculo
        );
    ELSE
        -- Validar compatibilidad completa
        RETURN EXISTS (
            SELECT 1
            FROM core.seccion_parqueo sp
                     JOIN config.tipo_vehiculo_seccion tvsp ON tvsp.id_seccion = sp.id_seccion
            WHERE sp.id_seccion = p_id_seccion
              AND sp.id_tipo_usuario = p_id_tipo_usuario
              AND tvsp.id_tipo_vehiculo = p_id_tipo_vehiculo
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.hay_conflicto_en_espacio(
    p_id_espacio INT,
    p_inicio TIMESTAMP,
    p_fin TIMESTAMP
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM core.registro_parqueo rp
        WHERE rp.id_espacio_parqueo = p_id_espacio
          AND rp.fecha_hora_ingreso < COALESCE(p_fin, rp.fecha_hora_salida)
          AND rp.fecha_hora_salida > p_inicio
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.vehiculo_ya_estacionado(
    p_placa TEXT,
    p_id_espacio INT,
    p_inicio TIMESTAMP,
    p_fin TIMESTAMP
) RETURNS BOOLEAN AS $$
DECLARE
    v_estado INT;
    v_usuario_id INT;
BEGIN
    -- Obtener estado del espacio
    SELECT ep.estado
    INTO v_estado
    FROM core.espacio_parqueo ep
    WHERE ep.id_espacio_parqueo = p_id_espacio;

    -- Si está disponible, no hay conflicto
    IF v_estado = 'Disponible' THEN
        RETURN FALSE;
    END IF;

    -- Si está ocupado (estado 3), hay conflicto
    IF v_estado = 'Ocupado' THEN
        RAISE NOTICE 'ERROR: El espacio esta ocupado';
        RETURN TRUE;
    END IF;
    -- Obtener id del usuario del vehículo
    SELECT id_usuario
    INTO v_usuario_id
    FROM core.vehiculo
    WHERE placa = p_placa;

    -- Si está reservado, verificar si la reserva le pertenece
    IF v_estado = 'Reservado' THEN
        -- Buscar reserva del espacio que sea del mismo usuario y coincida con el rango de tiempo
        IF EXISTS (
            SELECT 1
            FROM core.reserva_espacio r
            WHERE r.id_espacio = p_id_espacio
              AND r.id_usuario = v_usuario_id
              AND r.estado = 'aprobada'
        ) THEN
            RETURN FALSE; -- La reserva le pertenece
        ELSE
            RAISE NOTICE 'ERROR: El espacio esta reservado por otro usuario';
            RETURN TRUE; -- Está reservado y no le pertenece
        END IF;
    END IF;

    RETURN TRUE;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION core.validar_y_loggear_vehiculo_espacio()
    RETURNS TRIGGER AS $$
DECLARE
    v_usuario RECORD;
    v_espacio RECORD;
    es_compatible BOOLEAN;
BEGIN
    -- Validar existencia de vehículo y usuario
    v_usuario := core.validar_vehiculo_y_usuario(NEW.placa);

    -- Validar existencia y disponibilidad del espacio
    v_espacio := core.validar_espacio_existente(NEW.id_espacio_parqueo);

    -- Validar compatibilidad de usuario/vehículo con sección
    es_compatible := core.validar_compatibilidad_seccion(
            v_usuario.id_tipo_usuario,
            v_usuario.id_tipo_vehiculo,
            v_espacio.id_seccion
                     );

    IF NOT es_compatible THEN
        INSERT INTO log.log_fallos_parqueo (id_usuario, placa, fecha, hora_ingreso, hora_salida, motivo)
        VALUES (v_usuario.id_usuario, NEW.placa, DATE(NEW.fecha_hora_ingreso),
                NEW.fecha_hora_ingreso::time, COALESCE(NEW.fecha_hora_salida::time, NULL),
                'Incompatibilidad entre usuario, vehículo y sección');
        RAISE NOTICE 'Error: Incompatibilidad entre usuario, vehículo y sección';
        RETURN NULL;
    END IF;

    -- Validar coherencia de horas
    IF NEW.fecha_hora_salida IS NOT NULL AND NEW.fecha_hora_ingreso >= NEW.fecha_hora_salida THEN
        RAISE NOTICE 'Error: La hora de ingreso debe ser menor que la de salida.';
        RETURN NULL;
    END IF;

    -- Validar que el mismo vehículo no esté en otro lugar
    IF core.vehiculo_ya_estacionado(NEW.placa, NEW.id_espacio_parqueo, NEW.fecha_hora_ingreso, NEW.fecha_hora_salida) THEN
        INSERT INTO log.log_fallos_parqueo (id_usuario, placa, fecha, hora_ingreso, hora_salida, motivo)
        VALUES (v_usuario.id_usuario, NEW.placa, DATE(NEW.fecha_hora_ingreso),
                NEW.fecha_hora_ingreso::time, COALESCE(NEW.fecha_hora_salida::time, NULL),
                'Vehículo ya registrado en otro espacio en ese horario');
        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;




DROP TRIGGER IF EXISTS trg_validar_y_loggear_vehiculo_espacio ON core.registro_parqueo;

CREATE TRIGGER trg_validar_y_loggear_vehiculo_espacio
    BEFORE INSERT OR UPDATE ON core.registro_parqueo
    FOR EACH ROW
EXECUTE PROCEDURE core.validar_y_loggear_vehiculo_espacio();


/************************************** PRUEBAS  ************************************************/
--
-- -- Usuario estudiante
-- INSERT INTO core.usuario (id_usuario, nombre, id_tipo_usuario)
-- VALUES (1001, 'Juan Pérez', 1);
--
-- -- Vehículo tipo moto
-- INSERT INTO core.vehiculo (placa, id_usuario, id_tipo_vehiculo)
-- VALUES ('ABC123', 1001, 1);
--
--
-- INSERT INTO core.registro_parqueo (
--     id_espacio_parqueo, placa, fecha_hora_ingreso, fecha_hora_salida
-- ) VALUES (
--              1, 'NOEXIST', NOW(), NOW() + INTERVAL '1 hour'
--          );
-- -- ERROR esperado: El vehículo con placa NOEXISTE no existe.
--
-- INSERT INTO core.registro_parqueo (
--     id_espacio_parqueo, placa, fecha_hora_ingreso, fecha_hora_salida
-- ) VALUES (
--              9999, 'ABC123', NOW(), NOW() + INTERVAL '1 hour'
--          );
-- -- ERROR esperado: El espacio de parqueo 9999 no existe.
--
-- -- Crear otro usuario y auto
-- INSERT INTO core.usuario (id_usuario, nombre, id_tipo_usuario)
-- VALUES (1002, 'Lucía Gómez', 1);  -- Estudiante
--
-- INSERT INTO core.vehiculo (placa, id_usuario, id_tipo_vehiculo)
-- VALUES ('CAR999', 1002, 2);  -- Auto
--
-- -- Insertar registro en sección 1 (solo acepta motos)
-- INSERT INTO core.registro_parqueo (
--     id_espacio_parqueo, placa, fecha_hora_ingreso, fecha_hora_salida
-- ) VALUES (
--              2, 'CAR999', NOW(), NOW() + INTERVAL '1 hour'
--          );
-- -- ERROR esperado: Incompatibilidad entre usuario, vehículo y sección
--
-- -- Crear usuarios
-- INSERT INTO core.usuario (nombre) VALUES ('Usuario1'); -- id_usuario=1
-- INSERT INTO core.usuario (nombre) VALUES ('Usuario2'); -- id_usuario=2
--
-- -- Crear vehículos
-- INSERT INTO core.vehiculo (placa, id_usuario,id_tipo_vehiculo) VALUES ('AAA111', 1,2);
-- INSERT INTO core.vehiculo (placa, id_usuario,id_tipo_vehiculo) VALUES ('BBB222', 2,2);
--
-- INSERT INTO core.reserva_espacio (id_espacio, id_usuario, estado, fecha_inicio, fecha_fin)
-- VALUES (12, 1, 'pendiente', NOW(), NOW() + INTERVAL '2 hours');
--
-- INSERT INTO core.registro_parqueo (id_espacio_parqueo, placa, fecha_hora_ingreso, fecha_hora_salida)
-- VALUES (12, 'AAA111', NOW(), NOW() + INTERVAL '1 hour');
-- -- Esperado: Inserción OK
-- INSERT INTO core.registro_parqueo (id_espacio_parqueo, placa, fecha_hora_ingreso, fecha_hora_salida)
-- VALUES (12, 'BBB222', NOW(), NOW() + INTERVAL '1 hour');
-- -- Esperado: Exception "Conflicto: el vehículo BBB222 no puede estacionar en el espacio 12"

-- HACER ESTOS TRIGGERS
-- TODO AL RESERVAR HAY QUE ACTUALIZAR EL ESTADO DEL ESPACIO PARA PONERLO EN RESERVADO
-- HAY QUE ACTUALIZAR LA RESERVA  A FINALIZADA CUANDO EL VEHICULO SE VAYA
-- HAY QUE ACTUALIZAR EL ESTADO DEL ESPACIO CUANDO EL VEHICULO ESTE OCUPADO Y A DESOCUPADO CUANDO EL VEHICULO SE VAYA