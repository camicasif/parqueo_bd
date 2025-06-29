--PRUEBAS
--FUNCTION 1: REGISTRAR VEHICULO EN ESPACIO
    SELECT core.registrar_ingreso_vehiculo('JEF0003', 138);

select  ep.id_espacio_parqueo, ep.estado, sp.id_tipo_usuario, sp.id_seccion
from core.espacio_parqueo ep inner join core.seccion_parqueo sp on
    ep.id_seccion = sp.id_seccion
         where id_espacio_parqueo=138;
select * from core.registro_parqueo where placa='JEF0003' AND id_espacio_parqueo=138;

SELECT *
FROM core.registro_parqueo
ORDER BY fecha_hora_ingreso DESC
LIMIT 10; -- Muestra los últimos 10 registros

DROP FUNCTION core.registrar_ingreso_vehiculo(p_placa varchar, p_id_espacio integer);

SELECT id_espacio_parqueo, estado
FROM core.espacio_parqueo
WHERE id_espacio_parqueo = 135;

SELECT core.registrar_ingreso_vehiculo('JEF0002', 135);

SELECT nombre_tipo_usuario
FROM core.vehiculo v
INNER JOIN core.usuario u ON v.id_usuario = u.id_usuario
INNER JOIN config.tipo_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
WHERE v.placa = 'JEF0003';




SELECT * FROM core.espacio_parqueo where id_espacio_parqueo=135;


--FUNCTION 3: ACTUALIZAR EL ESTADO DE UN PARQUEO
    SELECT core.actualizar_estado_espacio(36, 'Ocupado');
    SELECT * FROM core.espacio_parqueo where id_espacio_parqueo=36;


--FUNCTION 4: OBTENER LISTA DE ESPACIOS DISPONIBLES POR SECCION

    SELECT core.contar_espacios_disponibles_por_seccion (100000);

    SELECT core.obtener_espacios_disponibles_por_seccion(100000);
