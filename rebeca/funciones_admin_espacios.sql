--ADMINISTRACION DE ESPACIOS Y PARQUEOS
--FUNCTION:1 Registrar ingreso de un vehículo a un espacio de parqueo
--FUNCTION:2 Registrar la salida de un espacio parqueo

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
