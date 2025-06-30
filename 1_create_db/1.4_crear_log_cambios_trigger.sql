CREATE OR REPLACE FUNCTION log_cambios_tablas()
    RETURNS TRIGGER AS
$$
DECLARE
    v_old_data       JSONB;
    v_new_data       JSONB;
    v_action         TEXT;
    v_table_name     TEXT;
    v_pk_column_name TEXT;
    v_id_registro    TEXT;
BEGIN
    v_table_name := TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME;
    -- Obtener el nombre del usuario actual de la base de datos
    SELECT a.attname
    INTO v_pk_column_name
    FROM pg_index i
             JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
    WHERE i.indrelid = v_table_name::regclass
      AND i.indisprimary
    LIMIT 1;
    -- En caso de que se reporten múltiples columnas (para PK compuesta), tomamos la primera.

    IF (TG_OP = 'UPDATE') THEN
        v_action := 'UPDATE';
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);

        -- Obtener el valor del ID de la fila original (OLD)
        IF v_pk_column_name IS NOT NULL THEN
            EXECUTE format('SELECT ($1).%I::TEXT', v_pk_column_name)
                USING OLD
                INTO v_id_registro;
        END IF;

    ELSIF (TG_OP = 'DELETE') THEN
        v_action := 'DELETE';
        v_old_data := to_jsonb(OLD);
        v_new_data := NULL;

        -- Obtener el valor del ID de la fila eliminada (OLD)
        IF v_pk_column_name IS NOT NULL THEN
            EXECUTE format('SELECT ($1).%I::TEXT', v_pk_column_name)
                USING OLD
                INTO v_id_registro;
        END IF;
    END IF;

    IF v_table_name = 'core.usuario' THEN
        v_old_data := v_old_data - 'contrasena';
        v_new_data := v_new_data - 'contrasena';
    END IF;


    -- Insertar en la tabla log, incluyendo el usuario_bd
    INSERT INTO log.log_cambios (tabla, accion, datos_antes, datos_despues, fecha_evento, id_registro)
    VALUES (v_table_name, v_action, v_old_data, v_new_data, NOW(), v_id_registro);

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

/** Eliminar triggers existentes **/
DROP TRIGGER IF EXISTS trg_log_tipo_usuario ON config.tipo_usuario;

DROP TRIGGER IF EXISTS trg_log_usuario ON core.usuario;

DROP TRIGGER IF EXISTS trg_log_tipo_vehiculo ON config.tipo_vehiculo;

DROP TRIGGER IF EXISTS trg_log_vehiculo ON core.vehiculo;

DROP TRIGGER IF EXISTS trg_log_seccion_parqueo ON core.seccion_parqueo;

DROP TRIGGER IF EXISTS trg_log_espacio_parqueo ON core.espacio_parqueo;

DROP TRIGGER IF EXISTS trg_log_vehiculo_espacio_parqueo ON core.registro_parqueo;

DROP TRIGGER IF EXISTS trg_log_tipo_vehiculo_seccion_parqueo ON config.tipo_vehiculo_seccion;

DROP TRIGGER IF EXISTS trg_log_reserva_espacio ON core.reserva_espacio;


/** Reemplazar o crear triggers para logs de update o delete **/
-- Trigger para la tabla tipo_usuario
CREATE TRIGGER trg_log_tipo_usuario
    AFTER UPDATE OR DELETE
    ON config.tipo_usuario
    FOR EACH ROW
EXECUTE PROCEDURE log_cambios_tablas();

-- Trigger para la tabla usuario
CREATE TRIGGER trg_log_usuario
    AFTER UPDATE OR DELETE
    ON core.usuario
    FOR EACH ROW
EXECUTE PROCEDURE log_cambios_tablas();

-- Trigger para la tabla tipo_vehiculo
CREATE TRIGGER trg_log_tipo_vehiculo
    AFTER UPDATE OR DELETE
    ON config.tipo_vehiculo
    FOR EACH ROW
EXECUTE PROCEDURE log_cambios_tablas();

-- Trigger para la tabla vehículo
CREATE TRIGGER trg_log_vehiculo
    AFTER UPDATE OR DELETE
    ON core.vehiculo
    FOR EACH ROW
EXECUTE PROCEDURE log_cambios_tablas();

-- Trigger para la tabla seccion_parqueo
CREATE TRIGGER trg_log_seccion_parqueo
    AFTER  UPDATE OR DELETE
    ON core.seccion_parqueo
    FOR EACH ROW
EXECUTE PROCEDURE log_cambios_tablas();

-- Trigger para la tabla espacio_parqueo
CREATE TRIGGER trg_log_espacio_parqueo
    AFTER UPDATE OR DELETE
    ON core.espacio_parqueo
    FOR EACH ROW
EXECUTE PROCEDURE log_cambios_tablas();

-- Trigger para la tabla vehiculo_espacio_parqueo
CREATE TRIGGER trg_log_vehiculo_espacio_parqueo
    AFTER  UPDATE OR DELETE
    ON core.registro_parqueo
    FOR EACH ROW
EXECUTE PROCEDURE log_cambios_tablas();

-- Trigger para la tabla tipo_vehiculo_seccion_parqueo
CREATE TRIGGER trg_log_tipo_vehiculo_seccion_parqueo
    AFTER UPDATE OR DELETE
    ON config.tipo_vehiculo_seccion
    FOR EACH ROW
EXECUTE PROCEDURE log_cambios_tablas();

-- Trigger para la tabla core_reserva_espacio
CREATE TRIGGER trg_log_reserva_espacio
    AFTER UPDATE OR DELETE
    ON core.reserva_espacio
    FOR EACH ROW
EXECUTE PROCEDURE log_cambios_tablas();