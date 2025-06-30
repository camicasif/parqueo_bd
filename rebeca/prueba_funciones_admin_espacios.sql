--PRUEBAS
--FUNCTION 1: REGISTRAR VEHICULO EN ESPACIO
    SELECT core.registrar_ingreso_vehiculo('ABC1161', 157);
    SELECT * FROM core.registro_parqueo where placa='ABC1161';

    SELECT * FROM core.registro_parqueo where placa='JEF0001';


SELECT * FROM core.vehiculo INNER JOIN core.usuario ON vehiculo.id_usuario = usuario.id_usuario
         where id_tipo_usuario=5;

SELECT core.registrar_ingreso_vehiculo('JEF0001', 156);

--FUNCTION 2: REGISTRAR SALIDA
      SELECT core.registrar_salida_vehiculo(58070);


--FUNCTION 3: ACTUALIZAR EL ESTADO DE UN PARQUEO
    SELECT core.actualizar_estado_espacio(36, 'Ocupado');
    SELECT * FROM core.espacio_parqueo where id_espacio_parqueo=36;

--FUNCTION 4: CONTAR  ESPACIOS DISPONIBLES POR SECCION

    SELECT core.contar_espacios_disponibles_por_seccion (1);

--FUNCTION 5: OBTENER ESPACIOS DISPONIBLES POR SECCION

    SELECT core.obtener_espacios_disponibles_por_seccion(100000);

--FUNCTION 6: VERIFICAR LA DISPONIBILIDAD DE ESPACIO ANTRES DE INGRESAR
    SELECT core.verificar_disponibilidad_espacio(10);


