
4. Vista de Vehículos que Ingresaron Hoy

CREATE OR REPLACE VIEW vista_ingresos_hoy AS
SELECT
    rp.id_registro,
    rp.placa,
    v.descripcion AS vehiculo_descripcion,
    tv.nombre_tipo_vehiculo,
    u.nombre || ' ' || u.apellidos AS usuario,
    u.codigo_universitario,
    rp.fecha_hora_ingreso,
    rp.id_espacio_parqueo,
    sp.nombre_seccion,
    CASE
        WHEN rp.fecha_hora_salida IS NULL THEN 'En parqueo'
        ELSE 'Ya salió'
    END AS estado
FROM
    core.registro_parqueo rp
JOIN
    core.vehiculo v ON rp.placa = v.placa AND v.eliminado = false
JOIN
    config.tipo_vehiculo tv ON v.id_tipo_vehiculo = tv.id_tipo_vehiculo AND tv.eliminado = false
JOIN
    core.usuario u ON v.id_usuario = u.id_usuario AND u.eliminado = false
JOIN
    core.espacio_parqueo ep ON rp.id_espacio_parqueo = ep.id_espacio_parqueo AND ep.eliminado = false
JOIN
    core.seccion_parqueo sp ON ep.id_seccion = sp.id_seccion AND sp.eliminado = false
WHERE
    rp.eliminado = false
    AND DATE(rp.fecha_hora_ingreso) = CURRENT_DATE
ORDER BY
    rp.fecha_hora_ingreso DESC;

5. Vista de Usuarios que Nunca Han Registrado un Ingreso

CREATE OR REPLACE VIEW vista_usuarios_sin_ingresos AS
SELECT
    u.id_usuario,
    u.codigo_universitario,
    u.nombre || ' ' || u.apellidos AS nombre_completo,
    u.telefono_contacto,
    tu.nombre_tipo_usuario,
    COUNT(v.placa) AS cantidad_vehiculos_registrados
FROM
    core.usuario u
JOIN
    config.tipo_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario AND tu.eliminado = false
LEFT JOIN
    core.vehiculo v ON u.id_usuario = v.id_usuario AND v.eliminado = false
LEFT JOIN
    core.registro_parqueo rp ON v.placa = rp.placa AND rp.eliminado = false
WHERE
    u.eliminado = false
    AND rp.id_registro IS NULL
GROUP BY
    u.id_usuario, u.codigo_universitario, u.nombre, u.apellidos, u.telefono_contacto, tu.nombre_tipo_usuario
HAVING
    COUNT(v.placa) > 0  -- Solo usuarios con vehículos registrados pero sin ingresos
ORDER BY
    u.apellidos, u.nombre;


7. Vista de Porcentaje de Ocupación Diaria por Sección

CREATE OR REPLACE VIEW vista_porcentaje_ocupacion_diaria_por_seccion AS
SELECT
    sp.id_seccion,
    sp.nombre_seccion,
    DATE(rp.fecha_hora_ingreso) AS fecha,
    COUNT(DISTINCT rp.id_espacio_parqueo) AS espacios_ocupados,
    COUNT(DISTINCT ep.id_espacio_parqueo) AS espacios_totales,
    ROUND((COUNT(DISTINCT rp.id_espacio_parqueo) * 100.0 / NULLIF(COUNT(DISTINCT ep.id_espacio_parqueo), 0)), 2) AS porcentaje_ocupacion
FROM
    core.seccion_parqueo sp
LEFT JOIN
    core.espacio_parqueo ep ON sp.id_seccion = ep.id_seccion AND ep.eliminado = false
LEFT JOIN
    core.registro_parqueo rp ON ep.id_espacio_parqueo = rp.id_espacio_parqueo
    AND rp.eliminado = false
    AND DATE(rp.fecha_hora_ingreso) = CURRENT_DATE
    AND (rp.fecha_hora_salida IS NULL OR DATE(rp.fecha_hora_salida) = CURRENT_DATE)
GROUP BY
    sp.id_seccion, sp.nombre_seccion, DATE(rp.fecha_hora_ingreso)
ORDER BY
    fecha, sp.id_seccion;


8. Vista de Conteo de Usuarios por Tipo


CREATE OR REPLACE VIEW vista_conteo_por_tipo_usuario AS
SELECT
    tu.id_tipo_usuario,
    tu.nombre_tipo_usuario,
    COUNT(u.id_usuario) AS cantidad_usuarios
FROM
    config.tipo_usuario tu
LEFT JOIN
    core.usuario u ON tu.id_tipo_usuario = u.id_tipo_usuario AND u.eliminado = false
WHERE
    tu.eliminado = false
GROUP BY
    tu.id_tipo_usuario, tu.nombre_tipo_usuario
ORDER BY
    cantidad_usuarios DESC;

CREATE OR REPLACE VIEW vista_vehiculos_estadia_prolongada AS
WITH estadia_promedio AS (
    SELECT 6.5 AS horas_promedio -- Se define el promedio manualmente
)
SELECT
    rp.placa,
    v.descripcion,
    u.nombre || ' ' || u.apellidos AS usuario,
    rp.fecha_hora_ingreso,
    rp.fecha_hora_salida,
    EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso)) / 3600 AS horas_estadia,
    ep.horas_promedio AS estadia_promedio_horas,
    CASE
        WHEN (EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso)) / 3600) > ep.horas_promedio * 1.5
        THEN 'Estadía prolongada'
        ELSE 'Dentro del promedio'
    END AS estado_estadia
FROM
    core.registro_parqueo rp
JOIN
    core.vehiculo v ON rp.placa = v.placa AND v.eliminado = false
JOIN
    core.usuario u ON v.id_usuario = u.id_usuario AND u.eliminado = false
CROSS JOIN
    estadia_promedio ep
WHERE
    rp.fecha_hora_salida IS NOT NULL
    AND rp.eliminado = false
    AND (EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso)) / 3600) > ep.horas_promedio
ORDER BY
    horas_estadia DESC;

10. Vista de Ingresos por Hora Diaria
CREATE OR REPLACE VIEW vista_ingresos_por_hora_diaria AS
SELECT
    DATE(fecha_hora_ingreso) AS fecha,
    EXTRACT(HOUR FROM fecha_hora_ingreso) AS hora,
    COUNT(*) AS cantidad_ingresos,
    sp.nombre_seccion,
    tv.nombre_tipo_vehiculo
FROM
    core.registro_parqueo rp
JOIN
    core.espacio_parqueo ep ON rp.id_espacio_parqueo = ep.id_espacio_parqueo AND ep.eliminado = false
JOIN
    core.seccion_parqueo sp ON ep.id_seccion = sp.id_seccion AND sp.eliminado = false
JOIN
    core.vehiculo v ON rp.placa = v.placa AND v.eliminado = false
JOIN
    config.tipo_vehiculo tv ON v.id_tipo_vehiculo = tv.id_tipo_vehiculo AND tv.eliminado = false
WHERE
    rp.eliminado = false
GROUP BY
    DATE(fecha_hora_ingreso), EXTRACT(HOUR FROM fecha_hora_ingreso), sp.nombre_seccion, tv.nombre_tipo_vehiculo
ORDER BY
    fecha, hora, cantidad_ingresos DESC;
