-- =======================
-- 1. Tablas Consolidadas
-- =======================

CREATE TABLE IF NOT EXISTS consolidado_uso_diario (
                                                      fecha DATE PRIMARY KEY,
                                                      total_ingresos INTEGER,
                                                      total_salidas INTEGER,
                                                      total_horas_ocupadas NUMERIC(10,2),
                                                      porcentaje_ocupacion_general NUMERIC(5,2),
                                                      porcentaje_ocupacion_por_seccion JSONB,
                                                      fecha_creacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS consolidado_alertas_sistema (
                                                           id_alerta SERIAL PRIMARY KEY,
                                                           id_usuario INTEGER,
                                                           placa VARCHAR(7),
                                                           fecha_evento TIMESTAMP,
                                                           tipo_alerta VARCHAR(100),
                                                           accion_sugerida TEXT,
                                                           fecha_creacion TIMESTAMP DEFAULT NOW(),
                                                           FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
);

CREATE TABLE IF NOT EXISTS consolidado_usuario_actividad (
                                                             id_usuario INTEGER PRIMARY KEY,
                                                             tipo_usuario VARCHAR(50),
                                                             cantidad_vehiculos INTEGER,
                                                             total_ingresos_mes INTEGER,
                                                             promedio_permanencia NUMERIC(5,2),
                                                             ultimo_ingreso TIMESTAMP,
                                                             seccion_mas_usada VARCHAR(100),
                                                             fecha_actualizacion TIMESTAMP DEFAULT NOW(),
                                                             FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
);


-- ===========================
-- 2. Procedimiento: Uso Diario
-- ===========================

CREATE OR REPLACE PROCEDURE actualizar_consolidado_uso_diario()
    LANGUAGE plpgsql
AS $$
DECLARE
    fecha_dia DATE := CURRENT_DATE - INTERVAL '1 day';
    total_espacios INT;
    total_ingresos INT;
    total_salidas INT;
    total_horas NUMERIC(10,2);
    ocupacion_seccion JSONB := '{}';
    seccion RECORD;
    espacios_ocupados INT;
BEGIN
    SELECT COUNT(*) INTO total_espacios FROM espacio_parqueo WHERE eliminado = false;

    SELECT COUNT(*) INTO total_ingresos
    FROM registro_parqueo
    WHERE DATE(fecha_hora_ingreso) = fecha_dia AND eliminado = false;

    SELECT COUNT(*) INTO total_salidas
    FROM registro_parqueo
    WHERE DATE(fecha_hora_salida) = fecha_dia AND eliminado = false;

    SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (fecha_hora_salida - fecha_hora_ingreso)) / 3600), 0)
    INTO total_horas
    FROM registro_parqueo
    WHERE DATE(fecha_hora_ingreso) = fecha_dia AND fecha_hora_salida IS NOT NULL AND eliminado = false;

    IF total_espacios = 0 THEN
        total_espacios := 1;
    END IF;

    FOR seccion IN
        SELECT sp.id_seccion, sp.nombre_seccion
        FROM seccion_parqueo sp
        WHERE eliminado = false
        LOOP
            SELECT COUNT(*) INTO espacios_ocupados
            FROM espacio_parqueo ep
                     JOIN registro_parqueo rp ON ep.id_espacio_parqueo = rp.id_espacio_parqueo
            WHERE ep.id_seccion = seccion.id_seccion
              AND DATE(rp.fecha_hora_ingreso) = fecha_dia
              AND rp.eliminado = false;

            ocupacion_seccion := ocupacion_seccion || jsonb_build_object(seccion.nombre_seccion,
                                                                         ROUND(100.0 * espacios_ocupados / total_espacios, 2));
        END LOOP;

    INSERT INTO consolidado_uso_diario (
        fecha, total_ingresos, total_salidas, total_horas_ocupadas,
        porcentaje_ocupacion_general, porcentaje_ocupacion_por_seccion
    )
    VALUES (
               fecha_dia, total_ingresos, total_salidas, total_horas,
               ROUND(100.0 * total_ingresos / total_espacios, 2), ocupacion_seccion
           );
END;
$$;


-- ===================================
-- 3. Procedimiento: Alertas del Sistema
-- ===================================

CREATE OR REPLACE PROCEDURE generar_alertas_sistema()
    LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    reserva RECORD;
    now_ts TIMESTAMP := NOW();
BEGIN
    -- 1. Ingresos sin salida por más de 5 días
    FOR r IN
        SELECT v.id_usuario, rp.placa, rp.fecha_hora_ingreso
        FROM registro_parqueo rp
                 JOIN vehiculo v ON v.placa = rp.placa
        WHERE rp.fecha_hora_salida IS NULL
          AND rp.fecha_hora_ingreso < now_ts - INTERVAL '5 days'
          AND rp.eliminado = false
        LOOP
            INSERT INTO consolidado_alertas_sistema (
                id_usuario, placa, fecha_evento, tipo_alerta, accion_sugerida
            )
            VALUES (
                       r.id_usuario, r.placa, now_ts,
                       'Vehículo sin salida por más de 5 días',
                       'Verificar posible abandono'
                   );
        END LOOP;

    -- 2. Reservas no utilizadas (evitar ambigüedad con alias y variable)
    FOR reserva IN
        SELECT resv.id_usuario, resv.fecha_inicio, resv.fecha_fin
        FROM reserva_espacio resv
        WHERE NOT EXISTS (
            SELECT 1
            FROM registro_parqueo rp
                     JOIN vehiculo v ON v.placa = rp.placa
            WHERE v.id_usuario = resv.id_usuario
              AND rp.fecha_hora_ingreso BETWEEN resv.fecha_inicio AND resv.fecha_fin
              AND rp.eliminado = false
        )
          AND resv.fecha_fin < now_ts - INTERVAL '1 day'
          AND resv.eliminado = false
        LOOP
            INSERT INTO consolidado_alertas_sistema (
                id_usuario, fecha_evento, tipo_alerta, accion_sugerida
            )
            VALUES (
                       reserva.id_usuario, now_ts,
                       'Reserva no utilizada',
                       'Revisar comportamiento de reservas'
                   );
        END LOOP;
END;
$$;




-- ======================================
-- 4. Procedimiento: Actividad por Usuario
-- ======================================

CREATE OR REPLACE PROCEDURE actualizar_consolidado_usuario_actividad()
    LANGUAGE plpgsql
AS $$
DECLARE
    u RECORD;
    ingresos INT;
    promedio NUMERIC(5,2);
    ultima TIMESTAMP;
    seccion TEXT;
BEGIN
    FOR u IN SELECT * FROM usuario WHERE eliminado = false
        LOOP
            SELECT COUNT(*) INTO ingresos
            FROM registro_parqueo rp
                     JOIN vehiculo v ON v.placa = rp.placa
            WHERE v.id_usuario = u.id_usuario
              AND DATE(rp.fecha_hora_ingreso) >= DATE_TRUNC('month', CURRENT_DATE)
              AND rp.eliminado = false;

            SELECT ROUND(AVG(EXTRACT(EPOCH FROM (fecha_hora_salida - fecha_hora_ingreso)) / 3600), 2)
            INTO promedio
            FROM registro_parqueo rp
                     JOIN vehiculo v ON v.placa = rp.placa
            WHERE v.id_usuario = u.id_usuario
              AND rp.fecha_hora_salida IS NOT NULL
              AND rp.eliminado = false;

            SELECT MAX(rp.fecha_hora_ingreso)
            INTO ultima
            FROM registro_parqueo rp
                     JOIN vehiculo v ON v.placa = rp.placa
            WHERE v.id_usuario = u.id_usuario
              AND rp.eliminado = false;

            SELECT sp.nombre_seccion INTO seccion
            FROM registro_parqueo rp
                     JOIN espacio_parqueo ep ON ep.id_espacio_parqueo = rp.id_espacio_parqueo
                     JOIN seccion_parqueo sp ON sp.id_seccion = ep.id_seccion
                     JOIN vehiculo v ON v.placa = rp.placa
            WHERE v.id_usuario = u.id_usuario
              AND rp.eliminado = false
            GROUP BY sp.nombre_seccion
            ORDER BY COUNT(*) DESC
            LIMIT 1;

            INSERT INTO consolidado_usuario_actividad (
                id_usuario, tipo_usuario, cantidad_vehiculos, total_ingresos_mes,
                promedio_permanencia, ultimo_ingreso, seccion_mas_usada, fecha_actualizacion
            )
            VALUES (
                       u.id_usuario,
                       (SELECT nombre_tipo_usuario FROM tipo_usuario WHERE id_tipo_usuario = u.id_tipo_usuario),
                       (SELECT COUNT(*) FROM vehiculo WHERE id_usuario = u.id_usuario AND eliminado = false),
                       ingresos, promedio, ultima, seccion, NOW()
                   )
            ON CONFLICT (id_usuario) DO UPDATE SET
                                                   tipo_usuario = EXCLUDED.tipo_usuario,
                                                   cantidad_vehiculos = EXCLUDED.cantidad_vehiculos,
                                                   total_ingresos_mes = EXCLUDED.total_ingresos_mes,
                                                   promedio_permanencia = EXCLUDED.promedio_permanencia,
                                                   ultimo_ingreso = EXCLUDED.ultimo_ingreso,
                                                   seccion_mas_usada = EXCLUDED.seccion_mas_usada,
                                                   fecha_actualizacion = EXCLUDED.fecha_actualizacion;
        END LOOP;
END;
$$;
