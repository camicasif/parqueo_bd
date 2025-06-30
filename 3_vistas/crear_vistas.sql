-- Vista: Usuarios con sus vehículos
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

-- Vista: Espacios ocupados actualmente
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

drop view vista_espacios_libres_actualmente;
-- Vista: Espacios libres actualmente
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

-- Vista: Reservas activas actualmente
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
