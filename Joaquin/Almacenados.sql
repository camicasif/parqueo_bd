-- Regla 1: Validar NOT NULL donde tenga sentido
-- Regla 2: Validar relaciones y entradas inválidas (placas, claves, etc.)
-- Regla 3: Validar longitud y consistencia de datos (placas 7, contraseñas)
-- Regla 4: Control de duplicados explícito si es posible
-- Regla 5: Soft eliminado con eliminado = false

CREATE OR REPLACE FUNCTION registrar_usuario(
    p_codigo_universitario INTEGER,
    p_telefono_contacto VARCHAR,
    p_contrasena VARCHAR,
    p_nombre VARCHAR,
    p_apellidos VARCHAR,
    p_id_tipo_usuario INTEGER
) RETURNS VOID AS $$
BEGIN
    IF LENGTH(p_contrasena) < 8 THEN
        RAISE EXCEPTION 'La contraseña debe tener al menos 8 caracteres.';
    ELSIF p_contrasena !~ '[a-z]' THEN
        RAISE EXCEPTION 'La contraseña debe contener al menos una letra minúscula.';
    ELSIF p_contrasena !~ '[A-Z]' THEN
        RAISE EXCEPTION 'La contraseña debe contener al menos una letra mayúscula.';
    ELSIF p_contrasena !~ '[0-9]' THEN
        RAISE EXCEPTION 'La contraseña debe contener al menos un número.';
    END IF;

    INSERT INTO core.usuario (
        codigo_universitario,
        telefono_contacto,
        contrasena,
        nombre,
        apellidos,
        id_tipo_usuario,
        eliminado
    ) VALUES (
        p_codigo_universitario,
        p_telefono_contacto,
        p_contrasena,
        p_nombre,
        p_apellidos,
        p_id_tipo_usuario,
        false
    );
    RAISE NOTICE 'Usuario registrado exitosamente.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al registrar usuario: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION actualizar_usuario(
    p_id_usuario INTEGER,
    p_codigo_universitario INTEGER,
    p_telefono_contacto VARCHAR,
    p_contrasena VARCHAR,
    p_nombre VARCHAR,
    p_apellidos VARCHAR,
    p_id_tipo_usuario INTEGER
) RETURNS VOID AS $$
BEGIN
    UPDATE core.usuario
    SET codigo_universitario = p_codigo_universitario,
        telefono_contacto = p_telefono_contacto,
        contrasena = p_contrasena,
        nombre = p_nombre,
        apellidos = p_apellidos,
        id_tipo_usuario = p_id_tipo_usuario
    WHERE id_usuario = p_id_usuario AND eliminado = false;

    IF FOUND THEN
        RAISE NOTICE 'Usuario actualizado.';
    ELSE
        RAISE NOTICE 'Usuario no encontrado o desactivado.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al actualizar usuario: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION eliminar_usuario(
    p_id_usuario INTEGER
) RETURNS VOID AS $$
BEGIN
    -- Desactivar usuario
    UPDATE core.usuario
    SET eliminado = true
    WHERE id_usuario = p_id_usuario;

    IF FOUND THEN
        -- Si se desactivó el usuario, también desactivar sus vehículos
        UPDATE core.vehiculo
        SET eliminado = true
        WHERE id_usuario = p_id_usuario;

        RAISE NOTICE 'Usuario y vehículos asociados desactivados.';
    ELSE
        RAISE NOTICE 'Usuario no encontrado.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al eliminar usuario: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION listar_usuarios_por_tipo()
    RETURNS VOID AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT u.id_usuario, u.nombre, u.apellidos, tu.nombre_tipo_usuario
        FROM core.usuario u
        JOIN config.tipo_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
        WHERE u.eliminado = false
        ORDER BY tu.nombre_tipo_usuario, u.nombre
    LOOP
        RAISE NOTICE 'ID: %, Nombre: % %, Tipo: %',
            r.id_usuario, r.nombre, r.apellidos, r.nombre_tipo_usuario;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al listar usuarios: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION validar_login(
    p_codigo_universitario INTEGER,
    p_contrasena VARCHAR
) RETURNS VOID AS $$
DECLARE
    v_usuario core.usuario%ROWTYPE;
BEGIN
    SELECT * INTO v_usuario
    FROM core.usuario
    WHERE codigo_universitario = p_codigo_universitario
      AND contrasena = p_contrasena
      AND eliminado = false;

    IF FOUND THEN
        RAISE NOTICE 'Login exitoso. Bienvenido, % %', v_usuario.nombre, v_usuario.apellidos;
    ELSE
        RAISE NOTICE 'Credenciales inválidas o usuario desactivado.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error en validación de login: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


-- FUNCIONES DE VEHÍCULOS CON REGLAS APLICADAS

-- 1. Registrar vehículo
CREATE OR REPLACE FUNCTION registrar_vehiculo(
    p_placa VARCHAR,
    p_id_tipo_vehiculo INTEGER,
    p_id_usuario INTEGER,
    p_codigo_sticker VARCHAR,
    p_usuario_creacion TEXT DEFAULT current_user,
    p_descripcion TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    IF LENGTH(p_placa) <> 7 THEN
        RAISE EXCEPTION 'La placa debe tener exactamente 7 caracteres.';
    END IF;

    INSERT INTO core.vehiculo (
        placa, id_tipo_vehiculo, id_usuario,
        codigo_sticker, usuario_creacion, descripcion, eliminado
    )
    VALUES (
        p_placa, p_id_tipo_vehiculo, p_id_usuario,
        p_codigo_sticker, p_usuario_creacion, p_descripcion, false
    );

    RAISE NOTICE 'Vehículo con placa % registrado exitosamente.', p_placa;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ya existe un vehículo con esa placa o sticker.';
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Usuario o tipo de vehículo no válido.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al registrar vehículo: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- 2. Actualizar vehículo
CREATE OR REPLACE FUNCTION actualizar_vehiculo(
    p_codigo_sticker VARCHAR,
    p_nueva_placa VARCHAR,
    p_nuevo_tipo INTEGER
) RETURNS VOID AS $$
BEGIN
    IF LENGTH(p_nueva_placa) <> 7 THEN
        RAISE EXCEPTION 'La nueva placa debe tener exactamente 7 caracteres.';
    END IF;

    UPDATE core.vehiculo
    SET placa = p_nueva_placa,
        id_tipo_vehiculo = p_nuevo_tipo
    WHERE codigo_sticker = p_codigo_sticker AND eliminado = false;

    IF FOUND THEN
        RAISE NOTICE 'Vehículo con sticker % actualizado.', p_codigo_sticker;
    ELSE
        RAISE NOTICE 'No se encontró vehículo activo con ese código.';
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'La nueva placa ya está registrada.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al actualizar vehículo: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- 3. Eliminar vehículo (soft eliminado)
CREATE OR REPLACE FUNCTION eliminar_vehiculo_por_placa(
    p_placa VARCHAR
) RETURNS VOID AS $$
BEGIN
    UPDATE core.vehiculo
    SET eliminado = true
    WHERE placa = p_placa AND eliminado = false;

    IF FOUND THEN
        RAISE NOTICE 'Vehículo con placa % marcado como fuera de circulación.', p_placa;
    ELSE
        RAISE NOTICE 'No se encontró un vehículo activo con placa %.', p_placa;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al eliminar vehículo: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- 4. Listar vehículos por usuario (solo activos)
CREATE OR REPLACE FUNCTION listar_vehiculos_por_usuario(
    p_id_usuario INTEGER
) RETURNS VOID AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT v.codigo_sticker, v.placa, tv.nombre_tipo_vehiculo
        FROM core.vehiculo v
        JOIN config.tipo_vehiculo tv ON v.id_tipo_vehiculo = tv.id_tipo_vehiculo
        WHERE v.id_usuario = p_id_usuario AND v.eliminado = false
    LOOP
        RAISE NOTICE '🚗 Sticker: %, Placa: %, Tipo: %',
            r.codigo_sticker, r.placa, r.nombre_tipo_vehiculo;
    END LOOP;

    RAISE NOTICE 'Listado finalizado para el usuario %.', p_id_usuario;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al listar vehículos: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- 5. Verificar existencia de vehículo por placa (activo)
CREATE OR REPLACE FUNCTION verificar_vehiculo_por_placa(
    p_placa VARCHAR
) RETURNS VOID AS $$
DECLARE
    v_existente INTEGER;
BEGIN
    SELECT 1 INTO v_existente
    FROM core.vehiculo
    WHERE placa = p_placa AND eliminado = false;

    IF FOUND THEN
        RAISE NOTICE 'El vehículo con placa % ya está registrado.', p_placa;
    ELSE
        RAISE NOTICE 'No existe vehículo activo con esa placa.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error en la verificación: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

---RESUMEN SEGUNDA PARTE

-- FUNCIÓN: Mostrar historial de parqueo por vehículo
CREATE OR REPLACE FUNCTION historial_parqueo_vehiculo(
    p_placa VARCHAR
) RETURNS TABLE (
    fecha_ingreso TIMESTAMP,
    fecha_salida TIMESTAMP,
    id_espacio INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT fecha_hora_ingreso, fecha_hora_salida, id_espacio_parqueo
    FROM core.registro_parqueo
    WHERE placa = p_placa
    ORDER BY fecha_hora_ingreso DESC;
END;
$$;

---1. Función para calcular tiempo promedio en el parqueo por usuario

CREATE OR REPLACE FUNCTION fn_tiempo_promedio_parqueo(p_id_usuario INTEGER)
RETURNS INTERVAL AS $$
DECLARE
    tiempo_promedio INTERVAL;
BEGIN
    SELECT
        date_trunc('minute', AVG(rp.fecha_hora_salida - rp.fecha_hora_ingreso))
    INTO tiempo_promedio
    FROM core.registro_parqueo rp
    JOIN core.vehiculo v ON rp.placa = v.placa AND v.eliminado = false
    WHERE v.id_usuario = p_id_usuario
      AND rp.fecha_hora_salida IS NOT NULL
      AND rp.eliminado = false;

    RETURN tiempo_promedio;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM fn_tiempo_promedio_parqueo(1); -- Reemplaza 1 con un ID de usuario real

---2. Función para calcular porcentaje de uso de una sección

CREATE OR REPLACE FUNCTION fn_porcentaje_uso_seccion(p_id_seccion INTEGER, p_fecha_inicio DATE, p_fecha_fin DATE)
RETURNS DECIMAL(5,2) AS $$
DECLARE
    total_espacios INTEGER;
    horas_ocupadas DECIMAL;
    horas_posibles DECIMAL;
    porcentaje DECIMAL(5,2);
BEGIN
    -- Contar espacios totales en la sección
    SELECT COUNT(*) INTO total_espacios
    FROM core.espacio_parqueo
    WHERE id_seccion = espacio_parqueo.id_seccion AND eliminado = false;

    -- Sumar horas ocupadas en el periodo
    SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso))/3600), 0) INTO horas_ocupadas
    FROM core.registro_parqueo rp
    JOIN core.espacio_parqueo ep ON rp.id_espacio_parqueo = ep.id_espacio_parqueo
    WHERE ep.id_seccion = p_id_seccion
    AND rp.fecha_hora_ingreso >= p_fecha_inicio
    AND rp.fecha_hora_salida <= p_fecha_fin + INTERVAL '1 day'
    AND rp.eliminado = false;

    -- Calcular horas posibles (espacios * horas en el periodo)
    horas_posibles := total_espacios * EXTRACT(EPOCH FROM (p_fecha_fin - p_fecha_inicio + INTERVAL '1 day'))/3600;

    -- Calcular porcentaje
    IF horas_posibles > 0 THEN
        porcentaje := (horas_ocupadas / horas_posibles) * 100;
    ELSE
        porcentaje := 0;
    END IF;

    RETURN ROUND(porcentaje, 2);
END;
$$ LANGUAGE plpgsql;

---3. Función para verificar si usuario sobrepasa límite de horas

CREATE OR REPLACE FUNCTION fn_usuario_sobrepasa_limite(p_id_usuario INTEGER, p_limite_horas INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    horas_acumuladas DECIMAL;
BEGIN
    SELECT COALESCE(
        SUM(EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso)) / 3600),
        0
    )
    INTO horas_acumuladas
    FROM core.registro_parqueo rp
    JOIN core.vehiculo v ON rp.placa = v.placa AND COALESCE(v.eliminado, false) = false
    WHERE v.id_usuario = p_id_usuario
      AND DATE(rp.fecha_hora_ingreso) = CURRENT_DATE
      AND COALESCE(rp.eliminado, false) = false
      AND rp.fecha_hora_salida IS NOT NULL;

    RETURN horas_acumuladas > p_limite_horas;
END;
$$ LANGUAGE plpgsql;

---4. Función para bloquear usuario tras 3 intentos fallidos (to_do)

CREATE OR REPLACE FUNCTION fn_bloquear_usuario_login(p_id_usuario INTEGER)
RETURNS VOID AS $$
BEGIN
    -- Registrar intento fallido
    INSERT INTO log.log_fallos_parqueo (id_usuario, fecha, fecha_evento)
    VALUES (p_id_usuario, CURRENT_DATE, NOW());

    -- Verificar si tiene 3 o más intentos hoy
    IF (SELECT COUNT(*) FROM log.log_fallos_parqueo
        WHERE id_usuario = p_id_usuario
        AND fecha = CURRENT_DATE) >= 3 THEN

        -- Actualizar usuario como eliminado (soft delete)
        UPDATE core.usuario
        SET eliminado = true
        WHERE id_usuario = p_id_usuario;

        -- Registrar en log de cambios
        INSERT INTO log.log_cambios (tabla, id_registro, accion, datos_antes, datos_despues, fecha_evento, usuario_bd)
        VALUES ('usuario', p_id_usuario, 'BLOQUEO POR INTENTOS FALLIDOS',
                (SELECT row_to_json(u) FROM core.usuario u WHERE id_usuario = p_id_usuario),
                (SELECT row_to_json(u) FROM core.usuario u WHERE id_usuario = p_id_usuario AND eliminado = true),
                NOW(), 'system');
    END IF;
END;
$$ LANGUAGE plpgsql;

----5. Función para buscar usuario por nombre o apellido

CREATE OR REPLACE FUNCTION fn_buscar_usuario(p_busqueda VARCHAR)
RETURNS TABLE (
    id_usuario INTEGER,
    nombre_completo VARCHAR,
    codigo_universitario VARCHAR,
    telefono_contacto VARCHAR,
    tipo_usuario VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id_usuario,
        u.nombre || ' ' || u.apellidos AS nombre_completo,
        u.codigo_universitario,
        u.telefono_contacto,
        tu.nombre_tipo_usuario
    FROM
        core.usuario u
    JOIN
        config.tipo_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario AND tu.eliminado = false
    WHERE
        (u.nombre ILIKE '%' || p_busqueda || '%' OR u.apellidos ILIKE '%' || p_busqueda || '%')
        AND u.eliminado = false
    ORDER BY
        u.apellidos, u.nombre;
END;
$$ LANGUAGE plpgsql;

----6. Función para desactivar usuario (soft delete)

CREATE OR REPLACE FUNCTION fn_desactivar_usuario(p_id_usuario INTEGER, p_usuario_operacion VARCHAR)
RETURNS VOID AS $$
DECLARE
    datos_antes JSONB;
BEGIN
    -- Obtener datos antes del cambio
    SELECT row_to_json(u) INTO datos_antes FROM core.usuario u WHERE id_usuario = p_id_usuario;

    -- Actualizar usuario
    UPDATE core.usuario
    SET
        eliminado = true,
        usuario_creacion = p_usuario_operacion,
        fecha_creacion = NOW()
    WHERE id_usuario = p_id_usuario;

    -- Registrar en log de cambios
    INSERT INTO log.log_cambios (tabla, id_registro, accion, datos_antes, datos_despues, fecha_evento, usuario_bd)
    VALUES ('usuario', p_id_usuario, 'DESACTIVACION',
            datos_antes,
            (SELECT row_to_json(u) FROM core.usuario u WHERE id_usuario = p_id_usuario),
            NOW(), p_usuario_operacion);
END;
$$ LANGUAGE plpgsql;

----7. Función para cambiar tipo de usuario
CREATE OR REPLACE FUNCTION fn_cambiar_tipo_usuario(p_id_usuario INTEGER, p_nuevo_tipo INTEGER, p_usuario_operacion VARCHAR)
RETURNS VOID AS $$
DECLARE
    datos_antes JSONB;
BEGIN
    -- Obtener datos antes del cambio
    SELECT row_to_json(u) INTO datos_antes FROM core.usuario u WHERE id_usuario = p_id_usuario;

    -- Actualizar usuario
    UPDATE core.usuario
    SET
        id_tipo_usuario = p_nuevo_tipo,
        usuario_creacion = p_usuario_operacion,
        fecha_creacion = NOW()
    WHERE id_usuario = p_id_usuario;

    -- Registrar en log de cambios
    INSERT INTO log.log_cambios (tabla, id_registro, accion, datos_antes, datos_despues, fecha_evento, usuario_bd)
    VALUES ('usuario', p_id_usuario, 'CAMBIO TIPO USUARIO',
            datos_antes,
            (SELECT row_to_json(u) FROM core.usuario u WHERE id_usuario = p_id_usuario),
            NOW(), p_usuario_operacion);
END;
$$ LANGUAGE plpgsql;

----8. Función para listar vehículos por tipo
CREATE OR REPLACE FUNCTION fn_listar_vehiculos_por_tipo(p_id_tipo_vehiculo INTEGER DEFAULT NULL)
RETURNS TABLE (
    placa VARCHAR,
    descripcion TEXT,
    codigo_sticker VARCHAR,
    nombre_usuario VARCHAR,
    tipo_vehiculo VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.placa,
        v.descripcion,
        v.codigo_sticker,
        u.nombre || ' ' || u.apellidos AS nombre_usuario,
        tv.nombre_tipo_vehiculo
    FROM
        core.vehiculo v
    JOIN
        core.usuario u ON v.id_usuario = u.id_usuario AND u.eliminado = false
    JOIN
        config.tipo_vehiculo tv ON v.id_tipo_vehiculo = tv.id_tipo_vehiculo AND tv.eliminado = false
    WHERE
        v.eliminado = false
        AND (p_id_tipo_vehiculo IS NULL OR v.id_tipo_vehiculo = p_id_tipo_vehiculo)
    ORDER BY
        tv.nombre_tipo_vehiculo, u.apellidos, u.nombre;
END;
$$ LANGUAGE plpgsql;