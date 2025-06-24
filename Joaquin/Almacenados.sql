CREATE OR REPLACE PROCEDURE registrar_usuario(
    p_codigo_universitario INTEGER,
    p_telefono_contacto VARCHAR,
    p_contrasena VARCHAR,
    p_nombre VARCHAR,
    p_apellidos VARCHAR,
    p_id_tipo_usuario INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO core.usuario (
        codigo_universitario,
        telefono_contacto,
        contrasena,
        nombre,
        apellidos,
        id_tipo_usuario
    )
    VALUES (
        p_codigo_universitario,
        p_telefono_contacto,
        p_contrasena,
        p_nombre,
        p_apellidos,
        p_id_tipo_usuario
    );

    RAISE NOTICE 'Usuario registrado exitosamente.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al registrar usuario: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE actualizar_usuario(
    p_id_usuario INTEGER,
    p_codigo_universitario INTEGER,
    p_telefono_contacto VARCHAR,
    p_contrasena VARCHAR,
    p_nombre VARCHAR,
    p_apellidos VARCHAR,
    p_id_tipo_usuario INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE core.usuario
    SET codigo_universitario = p_codigo_universitario,
        telefono_contacto = p_telefono_contacto,
        contrasena = p_contrasena,
        nombre = p_nombre,
        apellidos = p_apellidos,
        id_tipo_usuario = p_id_tipo_usuario
    WHERE id_usuario = p_id_usuario;

    IF FOUND THEN
        RAISE NOTICE 'Usuario con ID % actualizado exitosamente.', p_id_usuario;
    ELSE
        RAISE NOTICE 'No se encontró un usuario con ID %.', p_id_usuario;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al actualizar usuario: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE eliminar_usuario(
    p_id_usuario INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM core.usuario
    WHERE id_usuario = p_id_usuario;

    IF FOUND THEN
        RAISE NOTICE 'Usuario con ID % eliminado exitosamente.', p_id_usuario;
    ELSE
        RAISE NOTICE 'No se encontró un usuario con ID % para eliminar.', p_id_usuario;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al eliminar usuario: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE listar_usuarios_por_tipo()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT u.id_usuario, u.nombre, u.apellidos, tu.nombre_tipo_usuario
        FROM core.usuario u
        JOIN config.tipo_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
        ORDER BY tu.nombre_tipo_usuario, u.nombre
    LOOP
        RAISE NOTICE 'ID: %, Nombre: % %, Tipo: %',
            r.id_usuario, r.nombre, r.apellidos, r.nombre_tipo_usuario;
    END LOOP;

    RAISE NOTICE 'Listado completo.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al listar usuarios: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE validar_login(
    p_codigo_universitario INTEGER,
    p_contrasena VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_usuario core.usuario%ROWTYPE;
BEGIN
    SELECT * INTO v_usuario
    FROM core.usuario
    WHERE codigo_universitario = p_codigo_universitario
      AND contrasena = p_contrasena;

    IF FOUND THEN
        RAISE NOTICE 'Login exitoso. Bienvenido, % %', v_usuario.nombre, v_usuario.apellidos;
    ELSE
        RAISE NOTICE 'Credenciales inválidas.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error en validación de login: %', SQLERRM;
END;
$$;


---------------------------------------------------------




CREATE OR REPLACE PROCEDURE actualizar_vehiculo(
    p_codigo_sticker INTEGER,
    p_nueva_placa VARCHAR,
    p_nuevo_tipo INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE core.vehiculo
    SET placa = p_nueva_placa,
        id_tipo_vehiculo = p_nuevo_tipo
    WHERE codigo_sticker = p_codigo_sticker;

    IF FOUND THEN
        RAISE NOTICE 'Vehículo con sticker % actualizado.', p_codigo_sticker;
    ELSE
        RAISE NOTICE 'No se encontró vehículo con ese código.';
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'La nueva placa ya está registrada.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al actualizar vehículo: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE eliminar_vehiculo_por_placa(
    p_placa VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM core.vehiculo
    WHERE placa = p_placa;

    IF FOUND THEN
        RAISE NOTICE 'Vehículo con placa % eliminado.', p_placa;
    ELSE
        RAISE NOTICE 'No se encontró un vehículo con placa %.', p_placa;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al eliminar vehículo: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE listar_vehiculos_por_usuario(
    p_id_usuario INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT v.codigo_sticker, v.placa, tv.nombre_tipo_vehiculo
        FROM core.vehiculo v
        JOIN config.tipo_vehiculo tv ON v.id_tipo_vehiculo = tv.id_tipo_vehiculo
        WHERE v.id_usuario = p_id_usuario
    LOOP
        RAISE NOTICE '🚗 Sticker: %, Placa: %, Tipo: %',
            r.codigo_sticker, r.placa, r.nombre_tipo_vehiculo;
    END LOOP;

    RAISE NOTICE 'Listado finalizado para el usuario %.', p_id_usuario;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al listar vehículos: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE verificar_vehiculo_por_placa(
    p_placa VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existente INTEGER;
BEGIN
    SELECT 1 INTO v_existente
    FROM core.vehiculo
    WHERE placa = p_placa;

    IF FOUND THEN
        RAISE NOTICE 'El vehículo con placa % ya está registrado.', p_placa;
    ELSE
        RAISE NOTICE 'No existe vehículo con esa placa.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error en la verificación: %', SQLERRM;
END;
$$;