-- Regla 1: Validar NOT NULL donde tenga sentido
-- Regla 2: Validar relaciones y entradas inválidas (placas, claves, etc.)
-- Regla 3: Validar longitud y consistencia de datos (placas 7, contraseñas)
-- Regla 4: Control de duplicados explícito si es posible
-- Regla 5: Soft delete con delete = false

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
        delete
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
    WHERE id_usuario = p_id_usuario AND delete = false;

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
    UPDATE core.usuario
    SET delete = true
    WHERE id_usuario = p_id_usuario;

    IF FOUND THEN
        RAISE NOTICE 'Usuario desactivado.';
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
        WHERE u.delete = false
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
      AND delete = false;

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
-- FUNCIONES CONVERTIDAS Y MEJORADAS CON MANEJO DE ERRORES Y SOFT DELETE

-- 1. Registrar vehículo
CREATE OR REPLACE FUNCTION registrar_vehiculo(
    p_placa VARCHAR,
    p_id_tipo_vehiculo INTEGER,
    p_id_usuario INTEGER
) RETURNS VOID AS $$
BEGIN
    IF LENGTH(p_placa) <> 7 THEN
        RAISE EXCEPTION 'La placa debe tener exactamente 7 caracteres.';
    END IF;

    INSERT INTO core.vehiculo (placa, id_tipo_vehiculo, id_usuario, delete)
    VALUES (p_placa, p_id_tipo_vehiculo, p_id_usuario, false);

    RAISE NOTICE 'Vehículo con placa % registrado exitosamente.', p_placa;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ya existe un vehículo con esa placa.';
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Usuario o tipo de vehículo no válido.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al registrar vehículo: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- 2. Actualizar vehículo
CREATE OR REPLACE FUNCTION actualizar_vehiculo(
    p_codigo_sticker INTEGER,
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
    WHERE codigo_sticker = p_codigo_sticker AND delete = false;

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

-- 3. Eliminar vehículo (soft delete)
CREATE OR REPLACE FUNCTION eliminar_vehiculo_por_placa(
    p_placa VARCHAR
) RETURNS VOID AS $$
BEGIN
    UPDATE core.vehiculo
    SET delete = true
    WHERE placa = p_placa AND delete = false;

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
        WHERE v.id_usuario = p_id_usuario AND v.delete = false
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
    WHERE placa = p_placa AND delete = false;

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

---Resumen partes


-- FUNCIÓN: Cambiar placa de un vehículo (con auditoría)
CREATE OR REPLACE FUNCTION cambiar_placa_vehiculo(
    p_codigo_sticker INTEGER,
    p_nueva_placa VARCHAR,
    p_usuario_bd VARCHAR
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_placa_antigua VARCHAR;
BEGIN
    SELECT placa INTO v_placa_antigua
    FROM core.vehiculo
    WHERE codigo_sticker = p_codigo_sticker;

    IF v_placa_antigua IS NULL THEN
        RETURN 'Vehículo no encontrado.';
    END IF;

    UPDATE core.vehiculo
    SET placa = p_nueva_placa
    WHERE codigo_sticker = p_codigo_sticker;

    INSERT INTO log.log_cambios(tabla, id_registro, accion, datos_antes, datos_despues, usuario_bd)
    VALUES ('vehiculo', p_codigo_sticker::TEXT, 'UPDATE',
            jsonb_build_object('placa', v_placa_antigua),
            jsonb_build_object('placa', p_nueva_placa), p_usuario_bd);

    RETURN 'Placa actualizada correctamente.';
EXCEPTION
    WHEN unique_violation THEN
        RETURN 'La nueva placa ya está registrada.';
    WHEN OTHERS THEN
        RETURN 'Error: ' || SQLERRM;
END;
$$;

-- FUNCIÓN: Clonar información de un vehículo para otro usuario
CREATE OR REPLACE FUNCTION clonar_vehiculo_a_usuario(
    p_codigo_sticker_origen INTEGER,
    p_id_usuario_destino INTEGER
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_vehiculo core.vehiculo%ROWTYPE;
BEGIN
    SELECT * INTO v_vehiculo
    FROM core.vehiculo
    WHERE codigo_sticker = p_codigo_sticker_origen;

    IF NOT FOUND THEN
        RETURN 'Vehículo origen no encontrado.';
    END IF;

    INSERT INTO core.vehiculo (placa, id_tipo_vehiculo, id_usuario)
    VALUES (v_vehiculo.placa || '_C', v_vehiculo.id_tipo_vehiculo, p_id_usuario_destino);

    RETURN 'Vehículo clonado exitosamente.';
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error al clonar: ' || SQLERRM;
END;
$$;

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


-- FUNCIÓN: Marcar vehículo como fuera de circulación (soft delete)
ALTER TABLE core.vehiculo ADD COLUMN delete BOOLEAN DEFAULT FALSE;
CREATE OR REPLACE FUNCTION eliminar_vehiculo_soft(
    p_codigo_sticker INTEGER
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE core.vehiculo
    SET delete = TRUE
    WHERE codigo_sticker = p_codigo_sticker;

    IF FOUND THEN
        RETURN 'Vehículo marcado como fuera de circulación.';
    ELSE
        RETURN 'Vehículo no encontrado.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error al marcar vehículo como eliminado: ' || SQLERRM;
END;
$$;

-- FUNCIÓN: Cambiar placa de un vehículo (con auditoría)
CREATE OR REPLACE FUNCTION cambiar_placa_vehiculo(
    p_codigo_sticker INTEGER,
    p_nueva_placa VARCHAR,
    p_usuario_bd VARCHAR
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_placa_antigua VARCHAR;
BEGIN
    SELECT placa INTO v_placa_antigua
    FROM core.vehiculo
    WHERE codigo_sticker = p_codigo_sticker;

    IF v_placa_antigua IS NULL THEN
        RETURN 'Vehículo no encontrado.';
    END IF;

    UPDATE core.vehiculo
    SET placa = p_nueva_placa
    WHERE codigo_sticker = p_codigo_sticker;

    INSERT INTO log.log_cambios(tabla, id_registro, accion, datos_antes, datos_despues, usuario_bd)
    VALUES ('vehiculo', p_codigo_sticker::TEXT, 'UPDATE',
            jsonb_build_object('placa', v_placa_antigua),
            jsonb_build_object('placa', p_nueva_placa), p_usuario_bd);

    RETURN 'Placa actualizada correctamente.';
EXCEPTION
    WHEN unique_violation THEN
        RETURN 'La nueva placa ya está registrada.';
    WHEN OTHERS THEN
        RETURN 'Error: ' || SQLERRM;
END;
$$;

-- FUNCIÓN: Clonar información de un vehículo para otro usuario
CREATE OR REPLACE FUNCTION clonar_vehiculo_a_usuario(
    p_codigo_sticker_origen INTEGER,
    p_id_usuario_destino INTEGER
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_vehiculo core.vehiculo%ROWTYPE;
BEGIN
    SELECT * INTO v_vehiculo
    FROM core.vehiculo
    WHERE codigo_sticker = p_codigo_sticker_origen;

    IF NOT FOUND THEN
        RETURN 'Vehículo origen no encontrado.';
    END IF;

    INSERT INTO core.vehiculo (placa, id_tipo_vehiculo, id_usuario)
    VALUES (v_vehiculo.placa || '_C', v_vehiculo.id_tipo_vehiculo, p_id_usuario_destino);

    RETURN 'Vehículo clonado exitosamente.';
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error al clonar: ' || SQLERRM;
END;
$$;

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
