CREATE OR REPLACE FUNCTION core.crear_reserva(
    p_id_espacio integer,
    p_id_usuario integer,
    p_fecha_inicio timestamp,
    p_fecha_fin timestamp
) RETURNS void AS
$$
BEGIN
    -- Validación de permisos
    IF current_user NOT IN ('app_user', 'core_editor') THEN
        RAISE EXCEPTION 'No tiene permisos para crear reservas';
    END IF;

    -- Validación de conflicto de fechas para el mismo espacio
    IF EXISTS (
        SELECT 1
        FROM core.reserva_espacio r inner join core.espacio_parqueo e on reserva_espacio.id_espacio = espacio_parqueo.id_espacio_parqueo
        WHERE r.id_espacio = p_id_espacio
          AND e.eliminado = false
          AND r.estado = 'aprobada'
          AND (
            -- Solapamiento de rangos de fechas
            p_fecha_inicio < fecha_fin AND p_fecha_fin > fecha_inicio
            )
    ) THEN
        RAISE EXCEPTION 'Ya existe una reserva que se solapa con el rango de fechas indicado';
    END IF;

    -- Inserción de la nueva reserva
    INSERT INTO core.reserva_espacio (
        id_espacio, id_usuario, fecha_inicio, fecha_fin,
        estado, fecha_creacion, usuario_creacion
    )
    VALUES (
               p_id_espacio, p_id_usuario, p_fecha_inicio, p_fecha_fin,
               'pendiente', NOW(), current_user
           );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION core.aprobar_reserva(p_id_reserva integer)
    RETURNS void AS $$
DECLARE
    v_estado estado_reserva;
    v_fecha_inicio timestamp;
    v_fecha_fin timestamp;
    v_id_espacio integer;
BEGIN
    -- Validar permisos del usuario
    IF current_user != 'core_editor' THEN
        RAISE EXCEPTION 'No tiene permisos para aprobar reservas';
    END IF;

    -- Obtener estado, fechas y espacio de la reserva
    SELECT estado, fecha_inicio, fecha_fin, id_espacio
    INTO v_estado, v_fecha_inicio, v_fecha_fin, v_id_espacio
    FROM core.reserva_espacio
    WHERE id_reserva = p_id_reserva;

    -- Validar que la reserva esté pendiente
    IF v_estado != 'pendiente' THEN
        RAISE EXCEPTION 'Solo se pueden aprobar reservas pendientes';
    END IF;

    -- Validar que no haya una reserva aprobada en el mismo rango y espacio
    IF EXISTS (
        SELECT 1
        FROM core.reserva_espacio
        WHERE id_espacio = v_id_espacio
          AND id_reserva != p_id_reserva
          AND eliminado = false
          AND estado = 'aprobada'
          AND (
            v_fecha_inicio < fecha_fin AND v_fecha_fin > fecha_inicio
            )
    ) THEN
        RAISE EXCEPTION 'Ya existe una reserva aprobada que se solapa con el mismo rango de fechas';
    END IF;

    -- Si la reserva es para hoy, validar que el espacio no esté ocupado
    IF CURRENT_DATE = DATE(v_fecha_inicio) THEN
        IF EXISTS (
            SELECT 1
            FROM core.espacio_parqueo
            WHERE id_espacio_parqueo = v_id_espacio
              AND estado = 'Ocupado'
        ) THEN
            RAISE EXCEPTION 'No se puede aprobar la reserva: el espacio ya está ocupado hoy';
        END IF;

        -- Reservar el espacio si está disponible
        UPDATE core.espacio_parqueo
        SET estado = 'Reservado'
        WHERE id_espacio_parqueo = v_id_espacio
          AND estado = 'Disponible';
    END IF;

    -- Aprobar la reserva
    UPDATE core.reserva_espacio
    SET estado = 'aprobada'
    WHERE id_reserva = p_id_reserva;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;





CREATE OR REPLACE FUNCTION core.rechazar_reserva(p_id_reserva integer) RETURNS void AS
$$
DECLARE
    v_estado estado_reserva;
BEGIN
    IF current_user != 'core_editor' THEN
        RAISE EXCEPTION 'No tiene permisos para rechazar reservas';
    END IF;

    SELECT estado INTO v_estado FROM core.reserva_espacio WHERE id_reserva = p_id_reserva;
    IF v_estado != 'pendiente' THEN
        RAISE EXCEPTION 'Solo se pueden rechazar reservas pendientes';
    END IF;

    UPDATE core.reserva_espacio
    SET estado = 'rechazada'
    WHERE id_reserva = p_id_reserva;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION core.cancelar_reserva(p_id_reserva integer) RETURNS void AS
$$
DECLARE
    v_estado     estado_reserva;
    v_id_usuario integer;
BEGIN
    SELECT estado, id_usuario INTO v_estado, v_id_usuario FROM core.reserva_espacio WHERE id_reserva = p_id_reserva;

    IF current_user = 'core_editor' THEN
        -- admin puede cancelar cualquiera
        NULL;
    ELSIF current_user = 'app_user' THEN
        -- usuario sólo puede cancelar su reserva si está aprobada o pendiente
        IF v_id_usuario != (SELECT id_usuario FROM core.usuario WHERE usuario_creacion = current_user LIMIT 1) THEN
            RAISE EXCEPTION 'No puede cancelar reservas de otros usuarios';
        END IF;
        IF v_estado NOT IN ('pendiente', 'aprobada') THEN
            RAISE EXCEPTION 'Solo puede cancelar reservas pendientes o aprobadas';
        END IF;
    ELSE
        RAISE EXCEPTION 'No tiene permisos para cancelar reservas';
    END IF;

    UPDATE core.reserva_espacio
    SET estado = 'cancelada'
    WHERE id_reserva = p_id_reserva;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- SE CREO UN TASK EJECUTER EN WINDOWS PARA EJECUTAR DIARIAMENTE ESTAS DOS TAREAS:

CREATE OR REPLACE FUNCTION core.finalizar_reservas_vencidas() RETURNS void AS
$$
BEGIN
    UPDATE core.reserva_espacio
    SET estado = 'cancelada'
    WHERE estado IN ('pendiente', 'aprobada')
      AND fecha_fin < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION core.reservar_espacios_para_hoy() RETURNS void AS
$$
BEGIN
    -- Actualizar los espacios cuyo estado es 'Disponible' y tienen una reserva aprobada vigente para hoy
    UPDATE core.espacio_parqueo ep
    SET estado = 'Reservado'
    FROM core.reserva_espacio re
    WHERE ep.id_espacio_parqueo = re.id_espacio
      AND re.estado = 'aprobada'
      AND re.fecha_inicio <= CURRENT_TIMESTAMP
      AND ep.estado = 'Disponible';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;




