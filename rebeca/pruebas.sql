--1. Reportes Historial Vehiculo
SELECT *
FROM F_reporte_historial_vehiculo(
    'ABC0011',
    '2024-06-01 00:00:00'::timestamp,
    '2024-06-30 23:59:59'::timestamp
);
SELECT * FROM F_reporte_historial_vehiculo('XYZ123'' OR 1=1 --', '2024-01-01', '2024-01-10');

SELECT * FROM F_reporte_historial_vehiculo(
    'ABC123',
    '2025-06-01 00:00:00',
    '2025-06-30 23:59:59'
);

SELECT * FROM F_reporte_historial_vehiculo(
    'XYZ789',
    '2025-06-20 00:00:00',
    '2025-06-25 23:59:59'
);
SELECT * FROM F_reporte_historial_vehiculo(
    'ABC123',
    '2025-07-01 00:00:00',
    '2025-06-01 00:00:00'
);
SELECT * FROM F_reporte_historial_vehiculo(NULL, '2025-06-01', '2025-06-30');
SELECT * FROM F_reporte_historial_vehiculo(
    'NOEXISTE',
    '2025-06-01 00:00:00',
    '2025-06-30 23:59:59'
);



--2. Generar reporte de ocupación por sección y por día

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





--3. Tiempo total de permanencia de vehiculo segun placa.
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



--4.

