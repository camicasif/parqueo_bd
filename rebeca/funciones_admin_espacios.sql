--ADMINISTRACION DE ESPACIOS Y PARQUEOS
--FUNCTION:1 Registrar ingreso de un vehículo a un espacio de parqueo
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


--FUNCTION:2 Registrar la salida de un espacio parqueo
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


--FUNCTION 3: ACTUALIZAR EL ESTADO DE UN PARQUEO
CREATE OR REPLACE FUNCTION core.actualizar_estado_espacio(
    p_id_espacio_parqueo INTEGER,
    p_nuevo_estado estado_espacio
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual estado_espacio;
BEGIN
    -- Verificar si el espacio existe y obtener su estado actual
    SELECT estado
    INTO v_estado_actual
    FROM core.espacio_parqueo
    WHERE id_espacio_parqueo = p_id_espacio_parqueo;

    IF NOT FOUND THEN
        RETURN 'Error: El espacio de parqueo no existe.';
    END IF;

    -- *** NUEVA VALIDACIÓN: Si el estado actual es 'DISPONIBLE' y se intenta cambiar a 'DISPONIBLE' ***
    IF v_estado_actual = 'DISPONIBLE' AND p_nuevo_estado = 'DISPONIBLE' THEN
        RETURN 'Error: El espacio ya está DISPONIBLE y no se puede actualizar a DISPONIBLE nuevamente.';
    END IF;

    -- Verificar si el estado ya es el mismo (para otros estados)
    IF v_estado_actual = p_nuevo_estado THEN
        RETURN 'El espacio ya está en estado "' || p_nuevo_estado || '". No es necesario actualizar.';
    END IF;

    -- Realizar la actualización
    UPDATE core.espacio_parqueo
    SET estado = p_nuevo_estado
    WHERE id_espacio_parqueo = p_id_espacio_parqueo;

    RETURN 'Estado actualizado de "' || v_estado_actual || '" a "' || p_nuevo_estado || '" para el espacio ' || p_id_espacio_parqueo || '.';
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error inesperado al actualizar estado: ' || SQLERRM;
END;
$$;


--FUNCTION 4: OBTENER LISTA DE ESAPCIOS DISPONIBLES POR SECCION -- CORREGIR
CREATE OR REPLACE FUNCTION core.contar_espacios_disponibles_por_seccion(
    p_id_seccion INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INTEGER := 0;
    v_seccion_existe BOOLEAN;
BEGIN
    -- Validar si la sección existe
    SELECT EXISTS (
        SELECT 1 FROM core.seccion_parqueo WHERE id_seccion = p_id_seccion
    )
    INTO v_seccion_existe;

    IF NOT v_seccion_existe THEN
        RAISE NOTICE ' La sección con ID % no existe.', p_id_seccion;
        RETURN 'La sección no existe';
    END IF;

    -- Contar espacios disponibles si la sección existe
    SELECT COUNT(*)
    INTO v_total
    FROM core.espacio_parqueo
    WHERE estado = 'Disponible' AND id_seccion = p_id_seccion;

    RETURN v_total;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE ' Error inesperado al contar espacios disponibles: %', SQLERRM;
        RETURN 'ERROR';
END;
$$;




--FUNCTION 5:OBTENER QUE ESPACIOS ESTAN DISPONIBLES EN UNA DETERMINADA SECCION
CREATE OR REPLACE FUNCTION core.obtener_espacios_disponibles_por_seccion(
    p_id_seccion INTEGER
)
RETURNS TABLE (
    id_espacio_parqueo INTEGER,
    espacio_id_seccion INTEGER -- Se renombra para evitar ambigüedad
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_seccion_existe BOOLEAN;
BEGIN
    -- Validar que el id_seccion proporcionado exista en la tabla core.seccion_parqueo
    SELECT EXISTS (SELECT 1 FROM core.seccion_parqueo WHERE id_seccion = p_id_seccion)
    INTO v_seccion_existe;

    IF NOT v_seccion_existe THEN
        -- Si la sección no existe, se emite una notificación y se retorna una tabla vacía.
        RAISE NOTICE 'Advertencia: La sección con ID % no existe. No se pueden obtener espacios disponibles.', p_id_seccion;
        RETURN;
    END IF;

    -- Si la sección existe, se procede a obtener los espacios de parqueo disponibles
    -- para la sección especificada.
    RETURN QUERY
    SELECT
        ep.id_espacio_parqueo,
        ep.id_seccion AS espacio_id_seccion -- Se alias la columna para coincidir con el retorno
    FROM
        core.espacio_parqueo ep
    WHERE
        ep.estado = 'Disponible' AND -- Se utiliza 'Disponible' con 'D' mayúscula según la definición del ENUM
        ep.id_seccion = p_id_seccion;

EXCEPTION
    WHEN OTHERS THEN
        -- Captura cualquier otro error inesperado durante la ejecución
        RAISE NOTICE 'Error inesperado al obtener espacios disponibles por sección: %', SQLERRM;
        RETURN; -- Retorna una tabla vacía en caso de error
END;
$$;


--FUNCTION 6: VERIFICAR LA DISPONIBILIDAD DE ESPACIO ANTRES DE INGRESAR
CREATE OR REPLACE FUNCTION core.verificar_disponibilidad_espacio(
    p_id_espacio_parqueo INTEGER
)
RETURNS TEXT -- Retornará un mensaje indicando el estado o si hay error
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual estado_espacio;
BEGIN
    -- Verificar si el espacio existe y obtener su estado actual
    SELECT estado
    INTO v_estado_actual
    FROM core.espacio_parqueo
    WHERE id_espacio_parqueo = p_id_espacio_parqueo;

    IF NOT FOUND THEN
        RETURN 'Error: El espacio de parqueo no existe.';
    END IF;

    -- Verificar si el estado actual es 'Disponible'
    IF v_estado_actual = 'Disponible' THEN
        RETURN 'Disponible: El espacio ' || p_id_espacio_parqueo || ' está listo para ser ocupado.';
    ELSE
        RETURN 'No Disponible: El espacio ' || p_id_espacio_parqueo || ' se encuentra en estado "' || v_estado_actual || '".';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Captura cualquier error inesperado durante la ejecución
        RETURN 'Error inesperado al verificar disponibilidad del espacio ' || p_id_espacio_parqueo || ': ' || SQLERRM;
END;
$$;






