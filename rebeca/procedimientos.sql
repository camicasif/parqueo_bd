--FUNCIONES DE REPORTE



-- 1. Reporte de historial de parqueo de un vehículo por rango de fechas
CREATE OR REPLACE FUNCTION F_reporte_historial_vehiculo(
    p_placa VARCHAR,
    p_inicio TIMESTAMP,
    p_fin TIMESTAMP
)
RETURNS TABLE (
    fecha_hora_ingreso TIMESTAMP,
    fecha_hora_salida TIMESTAMP,
    id_espacio_parqueo INTEGER,
    nombre_seccion VARCHAR
)
AS $$
BEGIN
    -- Validación de parámetros nulos
    IF p_placa IS NULL OR p_inicio IS NULL OR p_fin IS NULL THEN
        RAISE EXCEPTION 'Los parámetros no pueden ser nulos';
    END IF;

    -- Validación del formato de placa: 3 letras + 4 dígitos
    IF p_placa !~ '^[A-Za-z]{3}[0-9]{4}$' THEN
        RAISE EXCEPTION 'La placa "%" no tiene el formato requerido (3 letras y 4 números)', p_placa;
    END IF;

    -- Validación de rango de fechas
    IF p_inicio > p_fin THEN
        RAISE EXCEPTION 'La fecha de inicio no puede ser mayor que la fecha fin';
    END IF;

    RETURN QUERY
    SELECT vep.fecha_hora_ingreso,
           vep.fecha_hora_salida,
           vep.id_espacio_parqueo,
           sp.nombre_seccion
    FROM core.registro_parqueo vep
    JOIN core.espacio_parqueo ep ON ep.id_espacio_parqueo = vep.id_espacio_parqueo
    JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
    WHERE vep.placa = p_placa
      AND (
            (vep.fecha_hora_ingreso BETWEEN p_inicio AND p_fin)
            OR (vep.fecha_hora_salida BETWEEN p_inicio AND p_fin)
            OR (vep.fecha_hora_ingreso <= p_inicio AND (vep.fecha_hora_salida IS NULL OR vep.fecha_hora_salida >= p_fin))
          );
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error en F_reporte_historial_vehiculo: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


-- 2. Generar reporte de ocupación por sección y por día

CREATE OR REPLACE FUNCTION F_reporte_ocupacion_por_seccion_por_dia(p_fecha DATE)
RETURNS TABLE (
    id_seccion INTEGER,
    nombre_seccion VARCHAR,
    total_ocupaciones BIGINT
) AS $$
BEGIN
    -- Validación 1: Fecha no puede ser nula
    IF p_fecha IS NULL THEN
        RAISE EXCEPTION 'La fecha proporcionada no puede ser nula';
    END IF;

    -- Validación 2: La fecha no puede estar en el futuro
    IF p_fecha > CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha proporcionada no puede estar en el futuro: %', p_fecha;
    END IF;

    -- Validación 3: La fecha no debe ser demasiado antigua (por ejemplo, más de 10 años)
    IF p_fecha < CURRENT_DATE - INTERVAL '10 years' THEN
        RAISE EXCEPTION 'La fecha proporcionada excede el límite histórico permitido: %', p_fecha;
    END IF;

    -- Validación 4: Verificar si hay registros en la fecha
    IF NOT EXISTS (
        SELECT 1
        FROM core.registro_parqueo
        WHERE DATE(fecha_hora_ingreso) = p_fecha
    ) THEN
        RAISE EXCEPTION 'No existen registros para la fecha proporcionada: %', p_fecha;
    END IF;


    RETURN QUERY
    SELECT sp.id_seccion,
           sp.nombre_seccion,
           COUNT(*) AS total_ocupaciones
    FROM core.registro_parqueo vep
    JOIN core.espacio_parqueo ep ON ep.id_espacio_parqueo = vep.id_espacio_parqueo
    JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
    WHERE DATE(vep.fecha_hora_ingreso) = p_fecha
    GROUP BY sp.id_seccion, sp.nombre_seccion;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error inesperado en F_reporte_ocupacion_por_seccion_por_dia: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;




-- 3. Calcular tiempo total de permanencia de un vehículo en el parqueo
CREATE OR REPLACE FUNCTION F_tiempo_total_permanencia(p_placa VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    total_tiempo INTERVAL := '0';
    dias INT;
    horas INT;
    minutos INT;
    segundos INT;
BEGIN
    -- Validación 1: Placa no puede ser nula ni vacía
    IF p_placa IS NULL OR TRIM(p_placa) = '' THEN
        RAISE EXCEPTION 'La placa proporcionada no puede ser nula o vacía.';
    END IF;

    -- Validación 2: Placa debe tener un formato válido (opcional, si aplica)
    -- Por ejemplo: 3 letras y 3 números (AJX123)
    IF p_placa !~ '^[A-Z]{3}[0-9]{4}$' THEN
        RAISE NOTICE 'Advertencia: La placa % no sigue el formato estándar.', p_placa;
        -- No se lanza excepción para permitir placas válidas con otro patrón si lo deseas
    END IF;

    -- Validación 3: Verificamos existencia de la placa en la base de datos
    IF NOT EXISTS (
        SELECT 1
        FROM core.registro_parqueo
        WHERE placa = p_placa
    ) THEN
        RAISE EXCEPTION 'La placa "%" no existe en los registros de estacionamiento.', p_placa;
    END IF;

    -- Cálculo del tiempo total solo con salidas válidas
    SELECT COALESCE(SUM(vep.fecha_hora_salida - vep.fecha_hora_ingreso), INTERVAL '0')
    INTO total_tiempo
    FROM core.registro_parqueo vep
    WHERE vep.placa = p_placa
      AND vep.fecha_hora_salida IS NOT NULL
      AND vep.fecha_hora_ingreso IS NOT NULL
      AND vep.fecha_hora_salida >= vep.fecha_hora_ingreso;

    -- Validación 4: Si no hubo registros con ingreso/salida válidos
    IF total_tiempo = INTERVAL '0' THEN
        RETURN 'No se encontraron registros completos de permanencia para la placa "' || p_placa || '".';
    END IF;

    -- Extraemos los componentes del intervalo
    dias := EXTRACT(DAY FROM total_tiempo);
    horas := EXTRACT(HOUR FROM total_tiempo);
    minutos := EXTRACT(MINUTE FROM total_tiempo);
    segundos := EXTRACT(SECOND FROM total_tiempo);

    RETURN dias || ' días, ' || horas || ' horas, ' || minutos || ' minutos y ' || segundos || ' segundos';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error en F_tiempo_total_permanencia: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;






-- 4 .Listar ingresos y salidas por fecha específica

CREATE OR REPLACE FUNCTION ingresos_salidas_por_fecha(p_fecha DATE)
RETURNS TABLE (
    placa VARCHAR,
    fecha_hora_ingreso TIMESTAMP,
    fecha_hora_salida TIMESTAMP,
    id_espacio_parqueo INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT vep.placa,
           vep.fecha_hora_ingreso,
           vep.fecha_hora_salida,
           vep.id_espacio_parqueo
    FROM core.registro_parqueo vep
    WHERE DATE(vep.fecha_hora_ingreso) = p_fecha
       OR (vep.fecha_hora_salida IS NOT NULL AND DATE(vep.fecha_hora_salida) = p_fecha);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM ingresos_salidas_por_fecha('2024-06-20');



-- 5.Contar cuántos vehículos ingresaron en una semana dada

CREATE OR REPLACE FUNCTION contar_ingresos_semana(p_inicio_semana DATE)
RETURNS INTEGER AS $$
DECLARE
    total_ingresos INTEGER := 0;
BEGIN
    SELECT COUNT(*)
    INTO total_ingresos
    FROM core.registro_parqueo
    WHERE fecha_hora_ingreso >= p_inicio_semana
      AND fecha_hora_ingreso < p_inicio_semana + INTERVAL '7 days';
    RETURN total_ingresos;
END;
$$ LANGUAGE plpgsql;

SELECT contar_ingresos_semana('2024-06-17') AS total_ingresos;


--ADMINISTRACION DE ESPACIOS Y PARQUEOS
-- 6. Registrar ingreso de un vehículo a un espacio de parqueo

CREATE OR REPLACE PROCEDURE registrar_ingreso_vehiculo(
    p_placa VARCHAR,
    p_id_espacio INTEGER,
    OUT p_mensaje VARCHAR
) AS $$
DECLARE
    v_existe_placa BOOLEAN;
    v_estado_espacio INTEGER;
    v_registro_abierto BOOLEAN;
BEGIN
    -- Verificación de existencia de vehículo
    SELECT EXISTS(SELECT 1 FROM core.vehiculo WHERE placa = p_placa) INTO v_existe_placa;
    IF NOT v_existe_placa THEN
        p_mensaje := 'Error: la placa ' || p_placa || ' no existe en la tabla vehiculo.';
        RETURN;
    END IF;

    -- Verificación de registro abierto para este vehículo
    SELECT EXISTS(
        SELECT 1
        FROM core.registro_parqueo
        WHERE placa = p_placa AND fecha_hora_salida IS NULL
    ) INTO v_registro_abierto;

    IF v_registro_abierto THEN
        p_mensaje := 'Error: el vehículo con placa ' || p_placa || ' aún no ha registrado salida.';
        RETURN;
    END IF;

    -- Verificación de disponibilidad del espacio
    SELECT id_estado INTO v_estado_espacio
    FROM core.espacio_parqueo
    WHERE id_espacio_parqueo = p_id_espacio;

    IF NOT FOUND THEN
        p_mensaje := 'Error: el espacio ' || p_id_espacio || ' no existe.';
        RETURN;
    ELSIF v_estado_espacio <> 1 THEN
        p_mensaje := 'Error: el espacio ' || p_id_espacio || ' no está libre para ingresar.';
        RETURN;
    END IF;

    -- Registrar ingreso
    INSERT INTO core.registro_parqueo (fecha_hora_ingreso, placa, id_espacio_parqueo)
    VALUES (NOW(), p_placa, p_id_espacio);

    UPDATE core.espacio_parqueo
    SET id_estado = 2
    WHERE id_espacio_parqueo = p_id_espacio;

    p_mensaje := 'Ingreso registrado correctamente.';
EXCEPTION
    WHEN foreign_key_violation THEN
        p_mensaje := 'Error de integridad referencial al intentar crear el registro.';
    WHEN others THEN
        p_mensaje := 'Error inesperado: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;



CALL registrar_ingreso_vehiculo('JEF0001', 132, NULL);

SELECT *
FROM core.registro_parqueo
WHERE placa = 'JEF0001';


-- 7. Registrar salida de un vehículo del parqueo

CREATE OR REPLACE PROCEDURE registrar_salida_vehiculo(
    p_placa VARCHAR,
    p_id_espacio INTEGER,
    OUT p_mensaje VARCHAR
) AS $$
DECLARE
    v_filas_actualizadas INTEGER;
BEGIN
    -- Intenta actualizar la salida
    UPDATE core.registro_parqueo
    SET fecha_hora_salida = NOW()
    WHERE placa = p_placa
      AND id_espacio_parqueo = p_id_espacio
      AND fecha_hora_salida IS NULL
    RETURNING 1 INTO v_filas_actualizadas;

    IF v_filas_actualizadas IS NULL THEN
        p_mensaje := 'Error: No se encontró registro activo para salida con esa placa y espacio.';
        RETURN;
    END IF;


    UPDATE core.espacio_parqueo
    SET id_estado = 1
    WHERE id_espacio_parqueo = p_id_espacio;

    p_mensaje := 'Salida registrada correctamente.';
EXCEPTION
    WHEN others THEN
        p_mensaje := 'Error inesperado: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    v_mensaje VARCHAR;
BEGIN
    CALL registrar_salida_vehiculo('JEF0001', 132, v_mensaje);
    RAISE NOTICE 'Resultado: %', v_mensaje;
END;
$$;




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