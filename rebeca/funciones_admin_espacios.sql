--ADMINISTRACION DE ESPACIOS Y PARQUEOS
--1.Registrar ingreso de un vehículo a un espacio de parqueo
CREATE OR REPLACE FUNCTION core.registrar_ingreso_vehiculo(
    p_placa VARCHAR(7),
    p_id_espacio_parqueo INTEGER
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_vehiculo_existe BOOLEAN;
    v_estado_actual estado_espacio;
    v_nuevo_id INTEGER;
BEGIN
--     -- 1. Validar que la placa del vehículo exista
--     SELECT EXISTS (
--         SELECT 1 FROM core.vehiculo WHERE placa = p_placa
--     ) INTO v_vehiculo_existe;
--
--     IF NOT v_vehiculo_existe THEN
--         RETURN 'Error: La placa del vehículo no existe.';
--     END IF;
--
--     -- 2. Verificar existencia y disponibilidad del espacio
--     SELECT estado
--     INTO v_estado_actual
--     FROM core.espacio_parqueo
--     WHERE id_espacio_parqueo = p_id_espacio_parqueo;
--
--     IF NOT FOUND THEN
--         RETURN 'Error: El espacio de parqueo no existe.';
--     END IF;
--
--     IF v_estado_actual != 'Disponible' THEN
--         RETURN 'Error: El espacio de parqueo no está disponible. Su estado actual es ' || v_estado_actual || '.';
--     END IF;

    -- 3. Insertar y obtener el ID generado
    INSERT INTO core.registro_parqueo (
        fecha_hora_ingreso,
        placa,
        id_espacio_parqueo
    )
    VALUES (
        NOW(),
        p_placa,
        p_id_espacio_parqueo
    )
    RETURNING id_registro INTO v_nuevo_id;

    -- 4. Actualizar estado del espacio
    UPDATE core.espacio_parqueo
    SET estado = 'Ocupado'
    WHERE id_espacio_parqueo = p_id_espacio_parqueo;

    -- 5. Retornar mensaje con ID
    RETURN 'Ingreso registrado con ID: ' || v_nuevo_id || '. Espacio ' || p_id_espacio_parqueo || ' ahora Ocupado.';

EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error al registrar el ingreso: ' || SQLERRM;
END;
$$;

--2.Registrar la salida de un espacio parqueo
CREATE OR REPLACE FUNCTION core.registrar_salida_vehiculo(
    p_id_registro INTEGER -- El ID del registro de ingreso que se desea finalizar
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_espacio_id INTEGER;
    v_placa VARCHAR(7);
    v_fecha_salida_existente TIMESTAMP;
BEGIN
    -- 1. Validar que el registro de parqueo exista y que la fecha_hora_salida sea NULL
    SELECT
        id_espacio_parqueo,
        placa,
        fecha_hora_salida
    INTO
        v_espacio_id,
        v_placa,
        v_fecha_salida_existente
    FROM
        core.registro_parqueo
    WHERE
        id_registro = p_id_registro;

    IF NOT FOUND THEN
        RETURN 'Error: El ID de registro no existe.';
    END IF;

    IF v_fecha_salida_existente IS NOT NULL THEN
        RETURN 'Error: La salida para este registro ya ha sido previamente registrada.';
    END IF;

    -- 2. Actualizar la fecha_hora_salida en core.registro_parqueo
    UPDATE core.registro_parqueo
    SET
        fecha_hora_salida = NOW()
    WHERE
        id_registro = p_id_registro;

    -- 3. Actualizar el estado del espacio de parqueo a 'Disponible'
    UPDATE core.espacio_parqueo
    SET
        estado = 'Disponible'
    WHERE
        id_espacio_parqueo = v_espacio_id;

    -- 4. Retornar un mensaje de éxito
    RETURN 'Salida del vehículo con placa ' || v_placa || ' registrada con éxito. Espacio ' || v_espacio_id || ' ahora Disponible.';

EXCEPTION
    WHEN OTHERS THEN
        -- Captura cualquier otro error inesperado
        RETURN 'Error inesperado al registrar la salida: ' || SQLERRM;
END;
$$;
