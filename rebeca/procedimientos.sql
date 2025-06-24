--PROCESOS ALMACENADOS DE CONSULTAS Y REPORTES
-- 1. Reporte de historial de parqueo de un vehículo por rango de fechas

CREATE OR REPLACE FUNCTION reporte_historial_vehiculo(p_placa VARCHAR, p_inicio TIMESTAMP, p_fin TIMESTAMP)
RETURNS TABLE (
    fecha_hora_ingreso TIMESTAMP,
    fecha_hora_salida TIMESTAMP,
    id_espacio_parqueo INTEGER,
    nombre_seccion VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT vep.fecha_hora_ingreso,
           vep.fecha_hora_salida,
           vep.id_espacio_parqueo,
           sp.nombre_seccion
    FROM core.registro_parqueo vep
    JOIN core.espacio_parqueo ep ON ep.id_espacio_parqueo = vep.id_espacio_parqueo
    JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
    WHERE vep.placa = p_placa
      AND vep.fecha_hora_ingreso BETWEEN p_inicio AND p_fin;
END;
$$ LANGUAGE plpgsql;


-- 2. Generar reporte de ocupación por sección y por día

CREATE OR REPLACE FUNCTION reporte_ocupacion_por_seccion_por_dia(p_fecha DATE)
RETURNS TABLE (
    id_seccion INTEGER,
    nombre_seccion VARCHAR,
    total_ocupaciones INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT sp.id_seccion,
           sp.nombre_seccion,
           COUNT(*) AS total_ocupaciones
    FROM core.registro_parqueo vep
    JOIN core.espacio_parqueo ep ON ep.id_espacio_parqueo = vep.id_espacio_parqueo
    JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
    WHERE DATE(vep.fecha_hora_ingreso) = p_fecha
    GROUP BY sp.id_seccion, sp.nombre_seccion;
END;
$$ LANGUAGE plpgsql;


-- 3. Calcular tiempo total de permanencia de un vehículo en el parqueo

CREATE OR REPLACE FUNCTION tiempo_total_permanencia(p_placa VARCHAR)
RETURNS INTERVAL AS $$
DECLARE
    total_tiempo INTERVAL := '0';
BEGIN
    SELECT SUM(vep.fecha_hora_salida - vep.fecha_hora_ingreso)
    INTO total_tiempo
    FROM core.registro_parqueo vep
    WHERE vep.placa = p_placa
      AND vep.fecha_hora_salida IS NOT NULL;

    RETURN total_tiempo;
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

--PROCESOS ALMACENADOS DE ADMINISTRACION GENERAL
-- 6. Resetear la contraseña de un usuario
CREATE OR REPLACE FUNCTION resetear_contrasena_usuario(p_id_usuario INTEGER, p_nueva_contrasena VARCHAR)
RETURNS VOID AS $$
BEGIN
    UPDATE core.usuario
    SET contrasena = p_nueva_contrasena
    WHERE id_usuario = p_id_usuario;
END;
$$ LANGUAGE plpgsql;


-- 7. Eliminar todos los registros de parqueo de un vehículo específico

CREATE OR REPLACE FUNCTION eliminar_registros_vehiculo(p_placa VARCHAR)
RETURNS VOID AS $$
BEGIN
    DELETE FROM core.registro_parqueo
    WHERE placa = p_placa;
END;
$$ LANGUAGE plpgsql;

-- 8. Verificar si un usuario tiene más de un vehículo registradO
CREATE OR REPLACE FUNCTION usuario_tiene_mas_de_un_vehiculo(p_id_usuario INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    total_vehiculos INTEGER := 0;
BEGIN
    SELECT COUNT(*)
    INTO total_vehiculos
    FROM core.vehiculo
    WHERE id_usuario = p_id_usuario;

    RETURN total_vehiculos > 1;
END;
$$ LANGUAGE plpgsql;


-- 9.  Reasignar un vehículo a otro usuario
CREATE OR REPLACE FUNCTION reasignar_vehiculo(p_placa VARCHAR, p_nuevo_id_usuario INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE core.vehiculo
    SET id_usuario = p_nuevo_id_usuario
    WHERE placa = p_placa;
END;
$$ LANGUAGE plpgsql;

-- 10.  Obtener información completa de un vehículo (usuario, tipo, historial)
CREATE OR REPLACE FUNCTION obtener_informacion_vehiculo(p_placa VARCHAR)
RETURNS TABLE (
    placa VARCHAR,
    nombre_tipo_vehiculo VARCHAR,
    nombre_usuario VARCHAR,
    apellidos_usuario VARCHAR,
    fecha_hora_ingreso TIMESTAMP,
    fecha_hora_salida TIMESTAMP,
    id_espacio_parqueo INTEGER,
    nombre_seccion VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT v.placa,
           tv.nombre_tipo_vehiculo,
           u.nombre AS nombre_usuario,
           u.apellidos AS apellidos_usuario,
           vep.fecha_hora_ingreso,
           vep.fecha_hora_salida,
           vep.id_espacio_parqueo,
           sp.nombre_seccion
    FROM core.vehiculo v
    LEFT JOIN core.usuario u ON u.id_usuario = v.id_usuario
    LEFT JOIN config.tipo_vehiculo tv ON tv.id_tipo_vehiculo = v.id_tipo_vehiculo
    LEFT JOIN core.registro_parqueo vep ON vep.placa = v.placa
    LEFT JOIN core.espacio_parqueo ep ON ep.id_espacio_parqueo = vep.id_espacio_parqueo
    LEFT JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
    WHERE v.placa = p_placa
    ORDER BY vep.fecha_hora_ingreso;
END;
$$ LANGUAGE plpgsql;

--ADMINISTRACION DE ESPACIOS Y PARQUEOS
-- 11. Registrar ingreso de un vehículo a un espacio de parqueo
CREATE OR REPLACE FUNCTION registrar_ingreso_vehiculo(p_placa VARCHAR, p_id_espacio INTEGER)
RETURNS VOID AS $$
BEGIN
    INSERT INTO core.registro_parqueo (fecha_hora_ingreso, placa, id_espacio_parqueo)
    VALUES (NOW(), p_placa, p_id_espacio);

    UPDATE core.espacio_parqueo
    SET id_estado = 3
    WHERE id_espacio_parqueo = p_id_espacio;
END;
$$ LANGUAGE plpgsql;


-- 12. Registrar salida de un vehículo del parqueo

CREATE OR REPLACE FUNCTION registrar_salida_vehiculo(p_placa VARCHAR, p_id_espacio INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE core.registro_parqueo
    SET fecha_hora_salida = NOW()
    WHERE registro_parqueo.placa = p_placa
      AND id_espacio_parqueo = p_id_espacio
      AND fecha_hora_salida IS NULL;

    UPDATE core.espacio_parqueo
    SET id_estado = 1
    WHERE id_espacio_parqueo = p_id_espacio;
END;
$$ LANGUAGE plpgsql;


-- 13. Actualizar el estado de un espacio de parqueo (libre, ocupado, reservado)

CREATE OR REPLACE FUNCTION actualizar_estado_espacio(p_id_espacio INTEGER, p_estado INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE core.espacio_parqueo
    SET id_estado = p_estado
    WHERE id_espacio_parqueo = p_id_espacio;
END;
$$ LANGUAGE plpgsql;

-- 14. Obtener lista de espacios disponibles por sección
CREATE OR REPLACE FUNCTION obtener_espacios_disponibles(p_id_seccion INTEGER)
RETURNS TABLE (
    id_espacio_parqueo INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT id_espacio_parqueo
    FROM core.espacio_parqueo
    WHERE id_seccion = p_id_seccion
      AND id_estado = 1;
END;
$$ LANGUAGE plpgsql;


-- 15. Asignar automáticamente un espacio disponible según tipo de usuario y tipo de vehículo
CREATE OR REPLACE FUNCTION asignar_espacio_automatico(p_id_tipo_usuario INTEGER, p_id_tipo_vehiculo INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_id_espacio INTEGER;
BEGIN
    SELECT ep.id_espacio_parqueo
    INTO v_id_espacio
    FROM core.espacio_parqueo ep
    JOIN core.seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
    JOIN config.tipo_vehiculo_seccion tvsp ON tvsp.id_seccion = sp.id_seccion
    WHERE tvsp.id_tipo_vehiculo = p_id_tipo_vehiculo
      AND sp.id_tipo_usuario = p_id_tipo_usuario
      AND ep.id_estado = 1
    LIMIT 1;

    RETURN v_id_espacio;
END;
$$ LANGUAGE plpgsql;