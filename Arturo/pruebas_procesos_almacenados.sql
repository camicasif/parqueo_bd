-- ============================================
-- PRUEBAS PARA CADA PROCEDIMIENTO/FUNCIÓN
-- ============================================

-- 1. asignar_seccion_a_usuario
CALL asignar_seccion_a_usuario(10, 1);  -- válido
CALL asignar_seccion_a_usuario(2, 1);  -- inválido
CALL asignar_seccion_a_usuario(999, 1); -- inválido (sección no existe)

-- 2. asignar_tipo_vehiculo_a_seccion
CALL asignar_tipo_vehiculo_a_seccion(1, 1); -- inválido
CALL asignar_tipo_vehiculo_a_seccion(2, 15); -- válido

-- 3. verificar_combinacion_valida
CALL verificar_combinacion_valida(1, 1); -- válido
CALL verificar_combinacion_valida(2, 2); -- inválido

-- 4. listar_secciones_por_tipo_vehiculo
SELECT * FROM listar_secciones_por_tipo_vehiculo(1); -- debe listar
SELECT * FROM listar_secciones_por_tipo_vehiculo(2); -- puede estar vacío o con resultados

-- 5. listar_vehiculos_por_seccion
SELECT * FROM listar_vehiculos_por_seccion(1); -- debe listar
SELECT * FROM listar_vehiculos_por_seccion(999); -- inválido (sección no existe)

-- 6. resetear_contrasena_usuario
CALL resetear_contrasena_usuario(2, 'jefe2', 'NuevaSegura123'); -- válido
CALL resetear_contrasena_usuario(4, 'jefe', 'NuevaSegura123'); -- contraseña actual incorrecta
CALL resetear_contrasena_usuario(3, 'jefe3', 'short'); -- inválido (muy corta)

-- 7. eliminar_registros_parqueo
CALL eliminar_registros_parqueo('JEF0007'); -- válido
CALL eliminar_registros_parqueo('ZZZ9999'); -- inválido

-- 8. verificar_vehiculos_usuario
SELECT verificar_vehiculos_usuario(2);
SELECT verificar_vehiculos_usuario(999); -- inválido

-- 9. reasignar_vehiculo
CALL reasignar_vehiculo('JEF0008', 2); -- válido
CALL reasignar_vehiculo('NOEXISTE', 2); -- inválido
CALL reasignar_vehiculo('JEF0008', 999); -- inválido

-- 10. info_completa_vehiculo
SELECT * FROM info_completa_vehiculo('JEF0008'); -- válido
SELECT * FROM info_completa_vehiculo('NOEXISTE'); -- inválido
