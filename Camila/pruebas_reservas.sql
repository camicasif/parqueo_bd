-- SELECT generar_registros_parqueo_por_rango('2025-06-01', '2025-06-30');

-- usuario de prueba: id: 266 nombre: Camila Varela
-- placa: ABC2661 tipo_auto: 2 (Auto) tipo_usuario = 1 (Estudiante)

SELECT core.crear_reserva(
               p_id_espacio := 10,
               p_id_usuario := 266,
               p_fecha_inicio := (NOW() + INTERVAL '1 day')::timestamp,
               p_fecha_fin := (NOW() + INTERVAL '1 day 2 hours')::timestamp
       );


-- Mismo espacio y hora solapada con reserva anterior
SELECT core.crear_reserva(
               p_id_espacio := 10,
               p_id_usuario := 266,
               p_fecha_inicio := NOW() + INTERVAL '1 day 1 hour',
               p_fecha_fin := NOW() + INTERVAL '1 day 3 hours'
       );
