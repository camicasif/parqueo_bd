-- 1. Vista: Usuarios con sus vehículos
CREATE OR REPLACE VIEW vista_usuarios_con_vehiculos AS
SELECT
    u.id_usuario,
    u.nombre AS nombre_usuario,
    u.apellidos,
    v.placa,
    tv.nombre_tipo_vehiculo AS tipo_vehiculo,
    v.descripcion
FROM core.usuario u
         JOIN core.vehiculo v ON u.id_usuario = v.id_usuario
         JOIN config.tipo_vehiculo tv ON v.id_tipo_vehiculo = tv.id_tipo_vehiculo
WHERE u.eliminado = false AND v.eliminado = false;

-- 2. Vista: Espacios ocupados actualmente
CREATE OR REPLACE VIEW vista_espacios_ocupados_actualmente AS
SELECT
    ep.id_espacio_parqueo,
    sp.nombre_seccion AS seccion,
    tvs.id_tipo_vehiculo,
    tu.id_tipo_usuario,
    rp.placa,
    rp.fecha_hora_ingreso,
    rp.fecha_hora_salida
FROM core.registro_parqueo rp
         JOIN core.espacio_parqueo ep ON rp.id_espacio_parqueo = ep.id_espacio_parqueo
         JOIN core.seccion_parqueo sp ON ep.id_seccion = sp.id_seccion
         JOIN config.tipo_vehiculo_seccion tvs ON tvs.id_seccion = sp.id_seccion
         JOIN config.tipo_usuario tu ON tu.id_tipo_usuario = sp.id_tipo_usuario
WHERE rp.fecha_hora_ingreso <= now()
  AND rp.fecha_hora_salida >= now()
  AND rp.eliminado = false
  AND ep.eliminado = false;

drop view if exists vista_espacios_libres_actualmente;
-- 3. Vista: Espacios libres actualmente
CREATE OR REPLACE VIEW vista_espacios_libres_actualmente AS
SELECT
    ep.id_espacio_parqueo,
    sp.nombre_seccion AS seccion,
    tvs.id_tipo_vehiculo,
    tv.nombre_tipo_vehiculo,
    tu.id_tipo_usuario,
    tu.nombre_tipo_usuario
FROM core.espacio_parqueo ep
         JOIN core.seccion_parqueo sp ON ep.id_seccion = sp.id_seccion
         JOIN config.tipo_vehiculo_seccion tvs ON tvs.id_seccion = sp.id_seccion
         JOIN config.tipo_usuario tu ON tu.id_tipo_usuario = sp.id_tipo_usuario
         JOIN config.tipo_vehiculo tv on tvs.id_tipo_vehiculo = tv.id_tipo_vehiculo
WHERE NOT EXISTS (
    SELECT 1 FROM core.registro_parqueo rp
    WHERE rp.id_espacio_parqueo = ep.id_espacio_parqueo
      AND rp.fecha_hora_ingreso <= now()
      AND rp.fecha_hora_salida >= now()
      AND rp.eliminado = false
)
  AND ep.eliminado = false;

-- 4. Vista de Vehículos que Ingresaron Hoy

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

-- 5. Vista de Usuarios que Nunca Han Registrado un Ingreso

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


-- 6. Vista: Reservas activas actualmente
CREATE OR REPLACE VIEW vista_reservas_activas AS
SELECT
    r.id_reserva,
    u.id_usuario,
    u.nombre || ' ' || u.apellidos AS nombre_usuario,
    r.id_espacio,
    ep.id_seccion,
    sp.nombre_seccion,
    r.fecha_inicio,
    r.fecha_fin,
    r.estado
FROM core.reserva_espacio r
         JOIN core.usuario u ON r.id_usuario = u.id_usuario
         JOIN core.espacio_parqueo ep ON r.id_espacio = ep.id_espacio_parqueo
         JOIN core.seccion_parqueo sp ON ep.id_seccion = sp.id_seccion
WHERE r.estado = 'aprobada'
  AND r.eliminado = false
  AND u.eliminado = false
  AND ep.eliminado = false
  AND sp.eliminado = false;


-- 8. Vista de Conteo de Usuarios por Tipo


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

-- 9. Vehiculos con estadia prolongada

CREATE OR REPLACE VIEW vista_vehiculos_estadia_prolongada AS
SELECT
    rp.placa,
    v.descripcion,
    u.nombre || ' ' || u.apellidos AS usuario,
    rp.fecha_hora_ingreso,
    rp.fecha_hora_salida,
    EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso)) / 3600 AS horas_estadia,
    5.5 AS estadia_promedio_horas,
    CASE
        WHEN EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso)) / 3600 > 5.5 * 1.5
            THEN 'Estadía prolongada'
        ELSE 'Dentro del promedio'
        END AS estado_estadia
FROM
    core.registro_parqueo rp
        JOIN
    core.vehiculo v ON rp.placa = v.placa AND v.eliminado = FALSE
        JOIN
    core.usuario u ON v.id_usuario = u.id_usuario AND u.eliminado = FALSE
WHERE
    rp.fecha_hora_salida IS NOT NULL
  AND rp.eliminado = FALSE
  AND EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso)) / 3600 > 5.5
ORDER BY
    horas_estadia DESC;

-- 10. Vista de Ingresos por Hora Diaria
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
