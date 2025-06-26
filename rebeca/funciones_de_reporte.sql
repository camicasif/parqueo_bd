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

    -- Validación 2: Placa debe tener un formato válido
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
      AND vep.fecha_hora_salida >= vep.fecha_hora_ingreso
      AND vep.eliminado=false;

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






-- 4.Listar ingresos y salidas por fecha específica

CREATE OR REPLACE FUNCTION F_ingresos_salidas_por_fecha(p_fecha DATE)
RETURNS TABLE (
    placa VARCHAR,
    fecha_hora_ingreso TIMESTAMP,
    fecha_hora_salida TIMESTAMP,
    id_espacio_parqueo INTEGER
) AS $$
BEGIN
    -- Validación de fecha no nula
    IF p_fecha IS NULL THEN
        RAISE EXCEPTION 'La fecha proporcionada no puede ser NULL';
    END IF;

    -- Validación de existencia de registros para la fecha proporcionada
    IF NOT EXISTS (
        SELECT 1
        FROM core.registro_parqueo vep
        WHERE DATE(vep.fecha_hora_ingreso) = p_fecha
           OR (vep.fecha_hora_salida IS NOT NULL AND DATE(vep.fecha_hora_salida) = p_fecha)
    ) THEN
        RAISE NOTICE 'No existen registros para la fecha %', p_fecha;
    END IF;

    -- Retorno de registros
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




-- 5.Contar cuántos vehículos ingresaron en una semana dada

CREATE OR REPLACE FUNCTION F_contar_ingresos_semana(p_inicio_semana DATE)
RETURNS INTEGER AS $$
DECLARE
    total_ingresos INTEGER := 0;
BEGIN
    -- Validación 1: p_inicio_semana no debe ser NULL
    IF p_inicio_semana IS NULL THEN
        RAISE EXCEPTION 'La fecha de inicio de semana no puede ser NULL';
    END IF;

    -- Validación 2 (opcional): fecha de inicio no debería ser futura
    IF p_inicio_semana > CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de inicio de semana no puede ser futura';
    END IF;

    -- Consulta de ingresos en la semana definida
    SELECT COUNT(*)
    INTO total_ingresos
    FROM core.registro_parqueo
    WHERE fecha_hora_ingreso >= p_inicio_semana
      AND fecha_hora_ingreso < p_inicio_semana + INTERVAL '7 days';

    RETURN total_ingresos;
END;
$$ LANGUAGE plpgsql;

--6. Generar reporte mensual de ingresos/salidas.

CREATE OR REPLACE FUNCTION F_reporte_ingresos_salidas_mensual(p_anio INT, p_mes INT)
RETURNS TABLE (
    id_registro INT,
    fecha_hora_ingreso TIMESTAMP,
    fecha_hora_salida TIMESTAMP,
    placa VARCHAR(7),
    id_espacio_parqueo INT
) AS $$
BEGIN
    -- Validación de parámetros
    IF p_anio IS NULL OR p_mes IS NULL THEN
        RAISE EXCEPTION 'Se deben especificar tanto el año como el mes';
    END IF;

    IF p_anio < 2000 OR p_anio > EXTRACT(YEAR FROM CURRENT_DATE) THEN
        RAISE EXCEPTION 'Año proporcionado no válido: %. El año debe estar entre 2000 y el actual.', p_anio;
    END IF;

    IF p_mes < 1 OR p_mes > 12 THEN
        RAISE EXCEPTION 'Mes proporcionado no válido: %. El mes debe estar entre 1 y 12.', p_mes;
    END IF;

    -- Verificación de registros para ese mes/año
    IF NOT EXISTS (
        SELECT 1
        FROM core.registro_parqueo rp
        WHERE EXTRACT(YEAR FROM rp.fecha_hora_ingreso) = p_anio
              AND EXTRACT(MONTH FROM rp.fecha_hora_ingreso) = p_mes
    ) THEN
        RAISE EXCEPTION 'No existen registros para el mes % y el año %.', p_mes, p_anio;
    END IF;

    RETURN QUERY
    SELECT
        rp.id_registro,
        rp.fecha_hora_ingreso,
        rp.fecha_hora_salida,
        rp.placa,
        rp.id_espacio_parqueo
    FROM core.registro_parqueo rp
    WHERE EXTRACT(YEAR FROM rp.fecha_hora_ingreso) = p_anio
      AND EXTRACT(MONTH FROM rp.fecha_hora_ingreso) = p_mes
    ORDER BY rp.fecha_hora_ingreso;

END;
$$ LANGUAGE plpgsql;


--7. Top 5 vehículos más frecuentes.

CREATE OR REPLACE FUNCTION F_top_5_parqueos_mas_recurridos(
    p_inicio_semana DATE
)
RETURNS TABLE (
    id_espacio_parqueo INTEGER,
    nombre_seccion VARCHAR,
    total_registros BIGINT
) AS $$
BEGIN
    -- Validación: parámetro NULL
    IF p_inicio_semana IS NULL THEN
        RAISE EXCEPTION 'El parámetro p_inicio_semana no puede ser NULL.';
    END IF;

    -- Validación: fecha futura
    IF p_inicio_semana > CURRENT_DATE THEN
        RAISE EXCEPTION 'El parámetro p_inicio_semana no puede ser una fecha futura.';
    END IF;

    -- Validación: existencia de registros en la semana
    IF NOT EXISTS (
        SELECT 1
        FROM core.registro_parqueo rp
        WHERE rp.fecha_hora_ingreso >= p_inicio_semana
          AND rp.fecha_hora_ingreso < p_inicio_semana + INTERVAL '7 days'
    ) THEN
        RAISE NOTICE 'No existen registros para la semana iniciada en %.', p_inicio_semana;
        RETURN;
    END IF;

    -- Consulta con join para traer nombre de sección
    RETURN QUERY
    SELECT rp.id_espacio_parqueo,
           sp.nombre_seccion,
           COUNT(*) AS total_registros
    FROM core.registro_parqueo rp
    JOIN core.espacio_parqueo ep ON ep.id_espacio_parqueo = rp.id_espacio_parqueo
    JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
    WHERE rp.fecha_hora_ingreso >= p_inicio_semana
      AND rp.fecha_hora_ingreso < p_inicio_semana + INTERVAL '7 days'
    GROUP BY rp.id_espacio_parqueo, sp.nombre_seccion
    ORDER BY total_registros DESC
    LIMIT 5;

END;
$$ LANGUAGE plpgsql;


--8. Comparar ocupación por sección en 2 fechas distintas.

CREATE OR REPLACE FUNCTION F_comparar_ocupacion_por_seccion(
    p_fecha1 DATE,
    p_fecha2 DATE
)
RETURNS TABLE (
    nombre_seccion VARCHAR,
    ocupacion_fecha1 BIGINT,
    ocupacion_fecha2 BIGINT
) AS $$
BEGIN
    -- Validaciones básicas
    IF p_fecha1 IS NULL OR p_fecha2 IS NULL THEN
        RAISE EXCEPTION 'Los parámetros p_fecha1 y p_fecha2 no pueden ser NULL.';
    END IF;

    IF p_fecha2 < p_fecha1 THEN
        RAISE EXCEPTION 'La segunda fecha debe ser igual o posterior a la primera.';
    END IF;

    -- Validar que existan registros para la primera fecha
    IF NOT EXISTS (
        SELECT 1 FROM core.registro_parqueo
        WHERE fecha_hora_ingreso >= p_fecha1
          AND fecha_hora_ingreso < p_fecha1 + INTERVAL '1 day'
    ) THEN
        RAISE NOTICE 'No existen registros para la fecha %.', p_fecha1;
        RETURN;
    END IF;

    -- Validar que existan registros para la segunda fecha
    IF NOT EXISTS (
        SELECT 1 FROM core.registro_parqueo
        WHERE fecha_hora_ingreso >= p_fecha2
          AND fecha_hora_ingreso < p_fecha2 + INTERVAL '1 day'
    ) THEN
        RAISE NOTICE 'No existen registros para la fecha %.', p_fecha2;
        RETURN;
    END IF;

    -- Consulta para comparar ocupación por sección
    RETURN QUERY
    WITH ocupacion_fecha1 AS (
        SELECT sp.nombre_seccion,
               COUNT(*) AS ocupacion
        FROM core.registro_parqueo rp
        JOIN core.espacio_parqueo ep ON ep.id_espacio_parqueo = rp.id_espacio_parqueo
        JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
        WHERE rp.fecha_hora_ingreso >= p_fecha1
          AND rp.fecha_hora_ingreso < p_fecha1 + INTERVAL '1 day'
        GROUP BY sp.nombre_seccion
    ),
    ocupacion_fecha2 AS (
        SELECT sp.nombre_seccion,
               COUNT(*) AS ocupacion
        FROM core.registro_parqueo rp
        JOIN core.espacio_parqueo ep ON ep.id_espacio_parqueo = rp.id_espacio_parqueo
        JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
        WHERE rp.fecha_hora_ingreso >= p_fecha2
          AND rp.fecha_hora_ingreso < p_fecha2 + INTERVAL '1 day'
        GROUP BY sp.nombre_seccion
    )
    SELECT
        COALESCE(f1.nombre_seccion, f2.nombre_seccion) AS nombre_seccion,
        COALESCE(f1.ocupacion, 0) AS ocupacion_fecha1,
        COALESCE(f2.ocupacion, 0) AS ocupacion_fecha2
    FROM ocupacion_fecha1 f1
    FULL OUTER JOIN ocupacion_fecha2 f2 ON f1.nombre_seccion = f2.nombre_seccion
    ORDER BY nombre_seccion;

END;
$$ LANGUAGE plpgsql;



--9. Listar espacios nunca usados.
CREATE OR REPLACE FUNCTION F_listar_espacios_nunca_usados()
RETURNS TABLE (
    id_espacio_parqueo INTEGER,
    estado estado_espacio,
    id_seccion INTEGER
) AS $$
BEGIN
    -- Validar que existan las tablas requeridas
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'core'
          AND table_name = 'espacio_parqueo'
    ) THEN
        RAISE EXCEPTION 'La tabla core.espacio_parqueo no existe.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'core'
          AND table_name = 'registro_parqueo'
    ) THEN
        RAISE EXCEPTION 'La tabla core.registro_parqueo no existe.';
    END IF;

    -- Validar si hay espacios registrados
    IF NOT EXISTS (SELECT 1 FROM core.espacio_parqueo) THEN
        RAISE NOTICE 'No existen espacios de parqueo registrados.';
        RETURN;
    END IF;

    -- Retornar espacios que no tienen registros en registro_parqueo
    RETURN QUERY
    SELECT ep.id_espacio_parqueo,
           ep.estado,
           ep.id_seccion
    FROM core.espacio_parqueo ep
    LEFT JOIN core.registro_parqueo rp ON rp.id_espacio_parqueo = ep.id_espacio_parqueo
    WHERE rp.id_espacio_parqueo IS NULL
    ORDER BY ep.id_espacio_parqueo;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error inesperado: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;



--10. Promedio de tiempo de permanencia por usuario.  --corregir
CREATE OR REPLACE FUNCTION F_promedio_tiempo_permanencia_por_usuario(
    p_user_id INTEGER
)
RETURNS TABLE (
    id_usuario INTEGER,
    nombre VARCHAR,
    apellidos VARCHAR,
    promedio_minutos NUMERIC(10,2)
) AS $$
DECLARE
    v_msg TEXT;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'El parámetro p_user_id no puede ser NULL.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM core.usuario WHERE id_usuario = p_user_id) THEN
        v_msg := 'No existe el usuario con id_usuario = ' || p_user_id::TEXT;
        RAISE EXCEPTION '%', v_msg;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.registro_parqueo rp
        JOIN core.vehiculo v ON v.placa = rp.placa
        WHERE v.id_usuario = p_user_id
          AND rp.fecha_hora_salida IS NOT NULL
    ) THEN
        v_msg := 'El usuario con id_usuario = ' || p_user_id::TEXT || ' no tiene registros con fecha_hora_salida.';
        RAISE NOTICE '%', v_msg;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        u.id_usuario,
        u.nombre,
        u.apellidos,
        AVG(EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso)) / 60) AS promedio_minutos
    FROM core.usuario u
    JOIN core.vehiculo v ON v.id_usuario = u.id_usuario
    JOIN core.registro_parqueo rp ON rp.placa = v.placa
    WHERE u.id_usuario = p_user_id
      AND rp.fecha_hora_salida IS NOT NULL
    GROUP BY u.id_usuario, u.nombre, u.apellidos;

EXCEPTION
    WHEN OTHERS THEN
        v_msg := 'Error inesperado: ' || SQLERRM;
        RAISE EXCEPTION '%', v_msg;
END;
$$ LANGUAGE plpgsql;








