-- 1. Usuarios con sus vehículos
SELECT * FROM vista_usuarios_con_vehiculos;

-- 2. Espacios ocupados actualmente
SELECT * FROM vista_espacios_ocupados_actualmente;

-- 3. Espacios libres actualmente
SELECT * FROM vista_espacios_libres_actualmente;

-- 4. Vehículos que ingresaron hoy
SELECT * FROM vista_ingresos_hoy;


select * from core.vehiculo where id_usuario = 121;
select * from core.registro_parqueo where placa='ABC1211';
-- 5. Usuarios que nunca han registrado un ingreso
SELECT * FROM vista_usuarios_sin_ingresos;

-- 6. Reservas activas actualmente
SELECT * FROM vista_reservas_activas;

-- 8. Conteo de usuarios por tipo
SELECT * FROM vista_conteo_por_tipo_usuario;

-- 9. Vehículos con estadía prolongada
SELECT * FROM vista_vehiculos_estadia_prolongada;

-- 10. Ingresos por hora diaria
SELECT * FROM vista_ingresos_por_hora_diaria;
