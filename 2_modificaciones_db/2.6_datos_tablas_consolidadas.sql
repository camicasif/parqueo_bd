CREATE OR REPLACE FUNCTION generar_registros_parqueo_por_rango_consolidada(
    fecha_inicio DATE,
    fecha_fin DATE
) RETURNS VOID AS $$
DECLARE
    v_fecha DATE;
    v_usuario_ids INT[];
    v_usuario_id INT;
    v_usuario_tipo INT;
    v_lista_vehiculos TEXT[];
    v_placa TEXT;
    v_tipo_vehiculo INT;
    v_hora_ingreso TIME;
    v_ingreso TIMESTAMP;
    v_salida TIMESTAMP;
    v_espacio_id INT;
    v_no_espacio_count INTEGER := 0;
    v_insertados_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Iniciando inserción desde % hasta %', fecha_inicio, fecha_fin;

    -- Obtener y mezclar la lista de IDs de usuario solo una vez
    SELECT array_agg(id_usuario ORDER BY random()) INTO v_usuario_ids
    FROM core.usuario;

    -- Iterar por cada día del rango
    FOR v_fecha IN SELECT generate_series(fecha_inicio, fecha_fin, INTERVAL '1 day')::DATE LOOP

            -- Recorrer usuarios en orden aleatorio
            FOREACH v_usuario_id IN ARRAY v_usuario_ids LOOP

                    -- Obtener tipo de usuario
                    SELECT id_tipo_usuario INTO v_usuario_tipo
                    FROM core.usuario
                    WHERE id_usuario = v_usuario_id;

                    -- Obtener lista de placas del usuario
                    SELECT array_agg(placa) INTO v_lista_vehiculos
                    FROM core.vehiculo
                    WHERE id_usuario = v_usuario_id;

                    IF v_lista_vehiculos IS NOT NULL AND array_length(v_lista_vehiculos, 1) > 0 THEN
                        -- Elegir una placa al azar
                        v_placa := v_lista_vehiculos[ceil(random() * array_length(v_lista_vehiculos, 1))::INT];

                        -- Obtener tipo de vehículo
                        SELECT id_tipo_vehiculo INTO v_tipo_vehiculo
                        FROM core.vehiculo
                        WHERE placa = v_placa;

                        -- Generar horario aleatorio
                        v_hora_ingreso := TIME '06:45' + (random() * INTERVAL '9 hours');
                        v_ingreso := v_fecha + v_hora_ingreso;

                        -- Algunas salidas serán nulas (10% de los casos)
                        IF random() < 0.1 THEN
                            v_salida := NULL;
                        ELSE
                            v_salida := v_ingreso + INTERVAL '2 hours' + (random() * INTERVAL '4 hours');
                        END IF;

                        -- Buscar el primer espacio compatible y disponible
                        SELECT ep.id_espacio_parqueo INTO v_espacio_id
                        FROM core.espacio_parqueo ep
                                 JOIN core.seccion_parqueo sp ON ep.id_seccion = sp.id_seccion
                                 JOIN config.tipo_vehiculo_seccion tvsp ON tvsp.id_seccion = sp.id_seccion
                        WHERE sp.id_tipo_usuario = v_usuario_tipo
                          AND tvsp.id_tipo_vehiculo = v_tipo_vehiculo
                          AND NOT EXISTS (
                            SELECT 1 FROM core.registro_parqueo rp
                            WHERE rp.id_espacio_parqueo = ep.id_espacio_parqueo
                              AND rp.fecha_hora_ingreso < COALESCE(v_salida, v_ingreso + INTERVAL '6 hours')
                              AND rp.fecha_hora_salida > v_ingreso
                        )
                        LIMIT 1;

                        -- Insertar si hay espacio
                        IF v_espacio_id IS NOT NULL THEN
                            INSERT INTO core.registro_parqueo (
                                fecha_hora_ingreso, fecha_hora_salida, placa, id_espacio_parqueo
                            ) VALUES (
                                         v_ingreso, v_salida, v_placa, v_espacio_id
                                     );

                            v_insertados_count := v_insertados_count + 1;
                        ELSE
                            v_no_espacio_count := v_no_espacio_count + 1;
                        END IF;
                    END IF;

                END LOOP;
        END LOOP;

    RAISE NOTICE 'Finalizada inserción. Registros insertados: %, vehículos sin espacio: %',
        v_insertados_count, v_no_espacio_count;
END;
$$ LANGUAGE plpgsql;



