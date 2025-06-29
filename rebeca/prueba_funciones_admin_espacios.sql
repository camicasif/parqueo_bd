--PRUEBAS DE FUNCIONES
--FUNCTION 1: REGISTRAR EL INGRESO DE UN VEHICULO A UN ESPACIO.

    -- 1. Caso exitoso: placa válida, espacio 'Disponible', sin registro abierto
    SELECT 'Caso 1 - Éxito' AS caso, registrar_ingreso_vehiculo('JEF0003', 132) AS resultado;

    -- 2. Placa no registrada en la tabla core.vehiculo
    SELECT 'Caso 2 - Placa no existe' AS caso, registrar_ingreso_vehiculo('XXX9999', 132) AS resultado;

    -- 3. Registro abierto para la placa (ya ingresó, no ha salido)
    SELECT 'Caso 3 - Registro abierto' AS caso, registrar_ingreso_vehiculo('JEF0001', 132) AS resultado;

    -- 4. Espacio no existe
    SELECT 'Caso 4 - Espacio no existe' AS caso, registrar_ingreso_vehiculo('JEF0001', 9999) AS resultado;

    -- 5. Espacio no está disponible (estado distinto de 'Disponible', como 'Ocupado')
    SELECT 'Caso 5 - Espacio ocupado' AS caso, registrar_ingreso_vehiculo('JEF0001', 132) AS resultado;

    -- 6. Error de integridad referencial: placa que no tiene relación válida (por ejemplo, eliminada pero usada aquí)
    SELECT 'Caso 6 - Integridad referencial' AS caso, registrar_ingreso_vehiculo('ZZZ0000', 132) AS resultado;

    SELECT 'CASO 7' AS caso, registrar_ingreso_vehiculo('JEF0010', 133) AS resultado;


select * from core.registro_parqueo where id_espacio_parqueo=132;
SELECT * FROM core.espacio_parqueo where id_espacio_parqueo=132;

--FUNCTION 2: REGISTRAR LA SALIDA DE UN VEHICULO EN UN ESPACIO

UPDATE core.espacio_parqueo
SET estado = 'Disponible'
WHERE id_espacio_parqueo = 132;


    -- 1. Salida válida
    SELECT 'Caso 1 - Éxito' AS caso, registrar_salida_vehiculo('JEF0002', 132) AS resultado;

    -- 2. No existe registro abierto para esa placa en ese espacio
    SELECT 'Caso 2 - No hay registro abierto' AS caso, registrar_salida_vehiculo('JEF0001', 132) AS resultado;

    -- 3. Placa incorrecta
    SELECT 'Caso 3 - Placa inexistente o sin ingreso' AS caso, registrar_salida_vehiculo('XXX9999', 132) AS resultado;

    -- 4. Espacio incorrecto (no coincide con el ingreso)
    SELECT 'Caso 4 - Espacio no coincide' AS caso, registrar_salida_vehiculo('JEF0001', 9999) AS resultado;
