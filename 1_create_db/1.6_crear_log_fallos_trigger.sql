CREATE OR REPLACE FUNCTION core.validar_vehiculo_y_usuario(p_placa TEXT)
    RETURNS RECORD AS $$
DECLARE
    result RECORD;
BEGIN
    SELECT u.id_usuario, u.id_tipo_usuario, v.id_tipo_vehiculo
    INTO result
    FROM core.vehiculo v
             JOIN core.usuario u ON u.id_usuario = v.id_usuario
    WHERE v.placa = p_placa AND v.eliminado = false;

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
    WHERE ep.id_espacio_parqueo = p_id_espacio AND ep.eliminado = false AND sp.eliminado = false;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Error: El espacio de parqueo % no existe.', p_id_espacio;
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
              AND eliminado = false
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
              AND tvsp.eliminado = false
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
          AND eliminado = false
          AND rp.fecha_hora_ingreso < COALESCE(p_fin, rp.fecha_hora_salida)
          AND rp.fecha_hora_salida > p_inicio
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.vehiculo_ya_estacionado_en_otro_lugar(
    p_placa TEXT,
    p_inicio TIMESTAMP,
    p_fin TIMESTAMP,
    p_id_actual INT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM core.registro_parqueo
        WHERE placa = p_placa
          AND eliminado = false
          AND (p_id_actual IS NULL OR id_registro != p_id_actual)
          AND fecha_hora_ingreso < COALESCE(p_fin, fecha_hora_salida)
          AND fecha_hora_salida > p_inicio
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.validar_disponibilidad_espacio(
    p_id_espacio INT,
    p_id_usuario INT
) RETURNS VOID AS $$
DECLARE
    v_estado TEXT;
BEGIN
    SELECT estado INTO v_estado
    FROM core.espacio_parqueo
    WHERE id_espacio_parqueo = p_id_espacio;

    IF v_estado = 'Ocupado' THEN
        RAISE EXCEPTION 'Error: El espacio ya está ocupado.';
    ELSIF v_estado = 'Reservado' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM core.reserva_espacio
            WHERE id_espacio = p_id_espacio
              AND id_usuario = p_id_usuario
              AND estado = 'aprobada'
        ) THEN
            RAISE EXCEPTION 'Error: El espacio está reservado por otro usuario.';
        END IF;
    END IF;
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
        RAISE EXCEPTION 'Error: Incompatibilidad entre usuario, vehículo y sección';
    END IF;

    -- Validar coherencia de horas
    IF NEW.fecha_hora_salida IS NOT NULL AND NEW.fecha_hora_ingreso >= NEW.fecha_hora_salida THEN
        RAISE EXCEPTION 'Error: La hora de ingreso debe ser menor que la de salida.';
    END IF;

    PERFORM core.validar_disponibilidad_espacio(NEW.id_espacio_parqueo, v_usuario.id_usuario);

    -- Validar que el mismo vehículo no esté en otro lugar
    IF core.vehiculo_ya_estacionado_en_otro_lugar(NEW.placa, NEW.fecha_hora_ingreso, NEW.fecha_hora_salida, NEW.id_registro) THEN
        INSERT INTO log.log_fallos_parqueo (id_usuario, placa, fecha, hora_ingreso, hora_salida, motivo)
        VALUES (
                   v_usuario.id_usuario,
                   NEW.placa,
                   DATE(NEW.fecha_hora_ingreso),
                   NEW.fecha_hora_ingreso::time,
                   COALESCE(NEW.fecha_hora_salida::time, NULL),
                   'Vehículo ya registrado en otro espacio en ese horario'
               );
        RAISE EXCEPTION 'Error: Vehículo ya registrado en otro espacio en ese horario';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;




DROP TRIGGER IF EXISTS trg_validar_y_loggear_vehiculo_espacio ON core.registro_parqueo;

CREATE TRIGGER trg_validar_y_loggear_vehiculo_espacio
    BEFORE INSERT ON core.registro_parqueo
    FOR EACH ROW
EXECUTE PROCEDURE core.validar_y_loggear_vehiculo_espacio();

