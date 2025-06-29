--ADMINISTRACION DE ESPACIOS Y PARQUEOS
-- 1. Registrar ingreso de un vehículo a un espacio de parqueo


-- 2. Registrar salida de un vehículo del parqueo

CREATE OR REPLACE FUNCTION registrar_salida_vehiculo(
    p_placa VARCHAR,
    p_id_espacio INTEGER
) RETURNS TEXT AS $$
DECLARE
    v_filas_actualizadas INTEGER;
BEGIN
    -- Intenta registrar la salida
    UPDATE core.registro_parqueo
    SET fecha_hora_salida = NOW()
    WHERE placa = p_placa
      AND id_espacio_parqueo = p_id_espacio
      AND fecha_hora_salida IS NULL
    RETURNING 1 INTO v_filas_actualizadas;

    -- Si no se actualizó ningún registro, el vehículo no tiene una entrada activa en ese espacio
    IF v_filas_actualizadas IS NULL THEN
        RETURN 'Error: No se encontró registro activo de ingreso para esa placa en ese espacio.';
    END IF;

    -- Liberar el espacio
    UPDATE core.espacio_parqueo
    SET estado = 'Disponible'
    WHERE id_espacio_parqueo = p_id_espacio;

    RETURN 'Salida registrada correctamente.';

EXCEPTION
    WHEN others THEN
        RETURN 'Error inesperado: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;





-- 8. Actualizar el estado de un espacio de parqueo (libre, ocupado, reservado)

CREATE OR REPLACE FUNCTION actualizar_estado_espacio(p_id_espacio INTEGER, p_estado INTEGER)
RETURNS VARCHAR AS $$
DECLARE
    filas_actualizadas INTEGER;
BEGIN
    UPDATE espacio_parqueo
    SET id_estado = p_estado
    WHERE id_espacio_parqueo = p_id_espacio
    RETURNING 1 INTO filas_actualizadas;

    IF filas_actualizadas IS NULL THEN
        RETURN 'Error: No se encontró el espacio con ID ' || p_id_espacio;
    END IF;

    RETURN 'Estado actualizado correctamente para espacio ' || p_id_espacio;

EXCEPTION
    WHEN others THEN
        RETURN 'Error inesperado: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

SELECT actualizar_estado_espacio(3, 1) AS mensaje;



-- 9. Obtener lista de espacios disponibles por sección

CREATE OR REPLACE FUNCTION obtener_espacios_disponibles(p_id_seccion INTEGER)
RETURNS TABLE (
    id_espacio_parqueo INTEGER,
    mensaje TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT ep.id_espacio_parqueo,
           'Espacio disponible'::text AS mensaje
    FROM espacio_parqueo ep
    WHERE ep.id_seccion = p_id_seccion
      AND ep.id_estado = 1;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT NULL AS id_espacio_parqueo,
               ('No hay espacios disponibles para la sección ' || p_id_seccion)::text AS mensaje;
    END IF;

END;
$$ LANGUAGE plpgsql;

SELECT * FROM obtener_espacios_disponibles(4);




-- 10. Asignar automáticamente un espacio disponible según tipo de usuario y tipo de vehículo
CREATE OR REPLACE FUNCTION asignar_espacio_automatico(p_id_tipo_usuario INTEGER, p_id_tipo_vehiculo INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_id_espacio INTEGER;
BEGIN
    SELECT ep.id_espacio_parqueo
    INTO v_id_espacio
    FROM espacio_parqueo ep
    JOIN seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
    JOIN tipo_vehiculo_seccion tvsp ON tvsp.id_seccion = sp.id_seccion
    WHERE tvsp.id_tipo_vehiculo = p_id_tipo_vehiculo
      AND sp.id_tipo_usuario = p_id_tipo_usuario
      AND ep.id_estado = 0
    LIMIT 1;

    RETURN v_id_espacio;
END;
$$ LANGUAGE plpgsql;