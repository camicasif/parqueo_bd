--FUNCTION1: Reportes Historial Vehiculo
    SELECT *
    FROM F_reporte_historial_vehiculo(
        'ABC0011',
        '2024-06-01 00:00:00'::timestamp,
        '2024-06-30 23:59:59'::timestamp
    );


    SELECT * FROM F_reporte_historial_vehiculo(
        'ABC1234',
        '2025-06-01 00:00:00',
        '2025-06-30 23:59:59'
    );

    SELECT * FROM F_reporte_historial_vehiculo(
        'XYZ789',
        '2025-06-20 00:00:00',
        '2025-06-25 23:59:59'
    );
    SELECT * FROM F_reporte_historial_vehiculo(
        'JEF0001',
        '2025-07-01 00:00:00',
        '2025-06-01 00:00:00'
    );
    SELECT * FROM F_reporte_historial_vehiculo(NULL, '2025-06-01', '2025-06-30');
    SELECT * FROM F_reporte_historial_vehiculo(
        'NOEXISTE',
        '2025-06-01 00:00:00',
        '2025-06-30 23:59:59'
    );



--FUNCTION 2:Generar reporte de ocupación por sección y por día

    SELECT *
    FROM F_reporte_ocupacion_por_seccion_por_dia('2024-06-20');

    --  CASO 1: Parámetro NULL
    SELECT 'Caso 1 - Parámetro NULL' AS prueba,
           *
    FROM F_reporte_ocupacion_por_seccion_por_dia(NULL);
    -- Esperado: ERROR - La fecha proporcionada no puede ser nula

    -- CASO 2: Fecha futura
    SELECT 'Caso 2 - Fecha futura' AS prueba,
           *
    FROM F_reporte_ocupacion_por_seccion_por_dia(CURRENT_DATE + INTERVAL '1 day');
    -- Esperado: ERROR - La fecha proporcionada no puede estar en el futuro

    -- CASO 3: Fecha muy antigua (más de 10 años)
    SELECT 'Caso 3 - Fecha antigua' AS prueba,
           *
    FROM F_reporte_ocupacion_por_seccion_por_dia(CURRENT_DATE - INTERVAL '11 years');
    -- Esperado: ERROR - La fecha proporcionada excede el límite histórico permitido

    --  CASO 4: Fecha sin registros
    SELECT 'Caso 4 - Fecha sin registros' AS prueba,
           *
    FROM F_reporte_ocupacion_por_seccion_por_dia('1999-01-01');
    -- Esperado: ERROR - No existen registros para la fecha proporcionada

    -- CASO 5: Fecha válida con registros (REEMPLAZAR por una fecha real que tengas en la tabla)
    SELECT 'Caso 5 - Fecha válida con datos' AS prueba,
           *
    FROM F_reporte_ocupacion_por_seccion_por_dia('2024-05-15');
    -- Esperado: Devuelve filas con ocupaciones por sección





-- FUNCTION 3:Tiempo total de permanencia de vehiculo segun placa.
    SELECT F_tiempo_total_permanencia('ABC2131') AS total_tiempo;
    -- CASO 1: Placa NULL
    SELECT 'Caso 1 - Placa NULL' AS prueba,
           F_tiempo_total_permanencia(NULL) AS resultado;

    -- CASO 2: Placa vacía
    SELECT 'Caso 2 - Placa vacía' AS prueba,
           F_tiempo_total_permanencia('') AS resultado;

    -- CASO 3: Formato inválido (ejemplo: minúsculas o caracteres no permitidos)
    SELECT 'Caso 3 - Formato inválido' AS prueba,
           F_tiempo_total_permanencia('abc-123') AS resultado;

    -- CASO 4: Placa inexistente
    SELECT 'Caso 4 - Placa inexistente' AS prueba,
           F_tiempo_total_permanencia('ZZZ999') AS resultado;

    -- CASO 5: Placa con registros pero sin fecha de salida
    -- Asegúrate de que exista una placa con ingresos pero sin salidas
    SELECT 'Caso 5 - Placa sin salida' AS prueba,
           F_tiempo_total_permanencia('ABC123') AS resultado;

    -- CASO 6: Placa válida con ingresos y salidas correctos
    -- Reemplaza por una placa real existente
    SELECT 'Caso 6 - Placa válida' AS prueba,
           F_tiempo_total_permanencia('JEF0001') AS resultado;

    -- CASO 8: Placa con múltiples ingresos y salidas válidas
    SELECT 'Caso 8 - Múltiples registros' AS prueba,
           F_tiempo_total_permanencia('JEF0004') AS resultado;



--FUNCTION 4 : Listar ingresos y salidas por fecha específica

    SELECT *
    FROM F_ingresos_salidas_por_fecha('2024-06-20');

    -- 1. Fecha NULL (debería lanzar EXCEPCIÓN)
    SELECT *
    FROM F_ingresos_salidas_por_fecha(NULL);

    -- 2. Fecha sin registros en la tabla (debería mostrar NOTICE y retornar 0 registros)
    SELECT *
    FROM F_ingresos_salidas_por_fecha('1900-01-01');


    -- 3. Fecha con registros en fecha_hora_salida (ajustar a una fecha válida en tu tabla)
    SELECT *
    FROM F_ingresos_salidas_por_fecha('2023-10-25');

    -- 4. Fecha donde hay registros tanto en fecha_hora_ingreso como en fecha_hora_salida (ajustar a una fecha válida en tu tabla)
    SELECT *
    FROM F_ingresos_salidas_por_fecha('2023-10-25');



--FUNCTION 5:Contar cuántos vehículos ingresaron en una semana dada

    SELECT F_contar_ingresos_semana('2024-06-17') AS total_ingresos;

    -- 1. Fecha NULL (debería lanzar EXCEPCIÓN)
    SELECT *
    FROM F_contar_ingresos_semana(NULL);

    -- 2. Fecha futura (debería lanzar EXCEPCIÓN)
    SELECT *
    FROM F_contar_ingresos_semana(CURRENT_DATE + INTERVAL '1 day');

    -- 3. Fecha sin registros en la tabla (puede retornar 0)
    SELECT *
    FROM F_contar_ingresos_semana('1900-01-01');

    -- 4. Fecha con registros en fecha_hora_ingreso (ajustar a una fecha válida en tu tabla)
    SELECT *
    FROM F_contar_ingresos_semana('2025-06-01');

    --FUNCTION 6: Generar reporte mensual de ingresos/salidas.

    SELECT *
    FROM F_reporte_ingresos_salidas_mensual(2024, 6);



--FUNCION 6: reporte_ingresos_salidas_mensual(año, mes)

    -- 1. Parámetros NULL (debería lanzar EXCEPCIÓN)
    SELECT *
    FROM F_reporte_ingresos_salidas_mensual(NULL, NULL);

    -- 2. Año fuera de rango (debería lanzar EXCEPCIÓN)
    SELECT *
    FROM F_reporte_ingresos_salidas_mensual(1999, 5);

    -- 3. Mes fuera de rango (debería lanzar EXCEPCIÓN)
    SELECT *
    FROM F_reporte_ingresos_salidas_mensual(2024, 13);

    -- 4. Mes y año sin registros en la tabla
    SELECT *
    FROM F_reporte_ingresos_salidas_mensual(1900, 1);

    -- 5. Mes y año con registros en fecha_hora_ingreso
    SELECT *
    FROM F_reporte_ingresos_salidas_mensual(2024, 6);

    -- 6. Mes y año donde  NO hay registros tanto en fecha_hora_ingreso como fecha_hora_salida
    SELECT *
    FROM F_reporte_ingresos_salidas_mensual(2023, 10);



--FUNCTION 7: Top 5 vehículos más frecuentes.
       -- 1. Parámetro NULL (debería lanzar EXCEPCIÓN o aviso)
    SELECT *
    FROM F_top_5_parqueos_mas_recurridos(NULL);

    -- 2. Fecha inválida (no es una fecha real, debería fallar)
    SELECT * FROM F_top_5_parqueos_mas_recurridos('2024-02-30');

    -- 3. Fecha en futuro (si quieres validar que no sea futura, si no, esta pasa)
    SELECT *
    FROM F_top_5_parqueos_mas_recurridos('2050-01-01');

    -- 4. Semana sin registros (debería mostrar NOTICE y retornar 0 filas)
    SELECT *
    FROM F_top_5_parqueos_mas_recurridos('1900-01-01');

    -- 5. Semana con registros (debería devolver top 5 espacios)
    SELECT *
    FROM F_top_5_parqueos_mas_recurridos('2024-06-24');



--FUNCTION 8: Comparar ocupación por sección en 2 fechas distintas.
    -- 1. Parámetros NULL (debería lanzar EXCEPCIÓN)
    SELECT *
    FROM F_comparar_ocupacion_por_seccion(NULL, NULL);

    -- 2. Solo uno de los parámetros NULL (debería lanzar EXCEPCIÓN)
    SELECT *
    FROM F_comparar_ocupacion_por_seccion('2024-06-24', NULL);

    SELECT *
    FROM F_comparar_ocupacion_por_seccion(NULL, '2024-06-25');

    -- 3. Segunda fecha anterior a la primera (debería lanzar EXCEPCIÓN)
    SELECT *
    FROM F_comparar_ocupacion_por_seccion('2024-06-25', '2024-06-24');

    -- 4. Primera fecha sin registros (debería mostrar NOTICE y retornar 0 filas)
    SELECT *
    FROM F_comparar_ocupacion_por_seccion('1900-01-01', '2024-06-25');

    -- 5. Segunda fecha sin registros (debería mostrar NOTICE y retornar 0 filas)
    SELECT *
    FROM F_comparar_ocupacion_por_seccion('2024-06-24', '1900-01-01');

    -- 6. Ambas fechas con registros (debería devolver comparación por sección)
    SELECT *
    FROM F_comparar_ocupacion_por_seccion('2024-06-24', '2024-06-25');


--FUNCTION 9: HISTORIAL DE INGRESO  Y SALIDA POR USUARIO
     select * from core.obtener_historial_por_usuario(10);
--FUNCTION 10: HISTORIAL DE INGRESO POR VEHICULO. (PLACA)
    select * from core.obtener_historial_por_vehiculo('JEF0001');










