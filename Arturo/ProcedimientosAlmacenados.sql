--Asignar sección de parqueo a un tipo de usuario
CREATE OR REPLACE PROCEDURE asignar_seccion_a_usuario(
    IN p_id_seccion INT,
    IN p_id_tipo_usuario INT
)
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM seccion_parqueo WHERE id_seccion = p_id_seccion AND eliminado = FALSE) THEN
        RAISE EXCEPTION 'Sección % no existe o está eliminada', p_id_seccion;
    END IF;

    UPDATE seccion_parqueo
    SET id_tipo_usuario = p_id_tipo_usuario
    WHERE id_seccion = p_id_seccion AND eliminado = FALSE;
END;
$$;


--Asignar tipo de vehículo a una sección permitida
CREATE OR REPLACE PROCEDURE asignar_tipo_vehiculo_a_seccion(
    IN p_id_tipo_vehiculo INT,
    IN p_id_seccion INT
)
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tipo_vehiculo_seccion
        WHERE id_tipo_vehiculo = p_id_tipo_vehiculo
          AND id_seccion = p_id_seccion
    ) THEN
        RAISE EXCEPTION 'Ya existe esa combinación de tipo de vehículo % y sección %', p_id_tipo_vehiculo, p_id_seccion;
    END IF;

    INSERT INTO tipo_vehiculo_seccion (id_tipo_vehiculo, id_seccion)
    VALUES (p_id_tipo_vehiculo, p_id_seccion);
END;
$$;


--Verificar si una combinación de *tipo\_vehículo* y *sección* es válida
CREATE OR REPLACE PROCEDURE verificar_combinacion_valida(
    IN p_id_tipo_vehiculo INT,
    IN p_id_seccion INT
)
    language plpgsql
as
$$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tipo_vehiculo_seccion
        WHERE id_tipo_vehiculo = p_id_tipo_vehiculo
          AND id_seccion = p_id_seccion
          AND eliminado = FALSE
    ) THEN
        RAISE NOTICE 'Válido';
    ELSE
        RAISE NOTICE 'Inválido';
    END IF;
END;
$$;

--Listar las secciones disponibles para un tipo de vehículo específico
CREATE OR REPLACE FUNCTION listar_secciones_por_tipo_vehiculo(
    p_id_tipo_vehiculo INT
)
    RETURNS TABLE (id_seccion INT, nombre_seccion varchar(50))
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tipo_vehiculo
        WHERE id_tipo_vehiculo = p_id_tipo_vehiculo AND eliminado = FALSE
    ) THEN
        RAISE EXCEPTION 'Tipo de vehículo % no existe o está eliminado', p_id_tipo_vehiculo;
    END IF;

    RETURN QUERY
        SELECT sp.id_seccion, sp.nombre_seccion
        FROM tipo_vehiculo_seccion tvs
                 JOIN seccion_parqueo sp ON tvs.id_seccion = sp.id_seccion
        WHERE tvs.id_tipo_vehiculo = p_id_tipo_vehiculo AND tvs.eliminado = FALSE;
END;
$$;
--Listar los tipos de vehículos permitidos por sección
CREATE OR REPLACE FUNCTION listar_vehiculos_por_seccion(
    p_id_seccion INT
)
    RETURNS TABLE (
                      id_tipo_vehiculo INT,
                      nombre_tipo_vehiculo VARCHAR
                  )
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM seccion_parqueo WHERE id_seccion = p_id_seccion AND eliminado = FALSE) THEN
        RAISE EXCEPTION 'Sección % no existe o está eliminada', p_id_seccion;
    END IF;

    RETURN QUERY
        SELECT tv.id_tipo_vehiculo, tv.nombre_tipo_vehiculo
        FROM tipo_vehiculo_seccion tvs
                 JOIN tipo_vehiculo tv ON tv.id_tipo_vehiculo = tvs.id_tipo_vehiculo
        WHERE tvs.id_seccion = p_id_seccion AND tv.eliminado = FALSE;
END;
$$;

--Resetear la contraseña de un usuario
CREATE OR REPLACE PROCEDURE resetear_contrasena_usuario(
    IN p_id_usuario INT,
    IN p_contrasena_actual VARCHAR(100),
    IN p_nueva_contrasena VARCHAR(100)
)
    LANGUAGE plpgsql
AS
$$
DECLARE
v_contrasena VARCHAR(100);
    v_user_exists BOOLEAN;
    v_datos_antes JSONB;
    v_datos_despues JSONB;
BEGIN
    -- Validar contraseña nueva
    IF LENGTH(p_nueva_contrasena) < 8 THEN
        RAISE EXCEPTION 'La contraseña debe tener mínimamente 8 caracteres.';

    ELSIF p_nueva_contrasena !~ '[a-z]' THEN
        RAISE EXCEPTION 'La contraseña debe contener al menos una letra minúscula.';

    ELSIF p_nueva_contrasena !~ '[A-Z]' THEN
        RAISE EXCEPTION 'La contraseña debe contener al menos una letra mayúscula.';

    ELSIF p_nueva_contrasena !~ '[0-9]' THEN
        RAISE EXCEPTION 'La contraseña debe contener mínimamente un número.';
    END IF;
    -- Verificar si el usuario existe
SELECT EXISTS (
    SELECT 1 FROM usuario WHERE id_usuario = p_id_usuario
) INTO v_user_exists;

IF NOT v_user_exists THEN
        RAISE EXCEPTION 'Usuario no encontrado';
END IF;

    -- Obtener la contraseña actual
SELECT contrasena INTO v_contrasena
FROM usuario
WHERE id_usuario = p_id_usuario;

-- Comparar con la actual
IF v_contrasena = p_contrasena_actual THEN
        -- Datos antes y después para el log
        v_datos_antes := jsonb_build_object('contrasena', v_contrasena);
        v_datos_despues := jsonb_build_object('contrasena', p_nueva_contrasena);

        -- Actualizar contraseña
UPDATE usuario
SET contrasena = p_nueva_contrasena
WHERE id_usuario = p_id_usuario
  AND eliminado = FALSE;

-- Insertar en log
INSERT INTO log.log_cambios(tabla, id_registro, accion, datos_antes, datos_despues, usuario_bd)
VALUES (
           'usuario',
           p_id_usuario::TEXT,
           'UPDATE',
           v_datos_antes,
           v_datos_despues,
           CURRENT_USER
       );
ELSE
        -- Contraseña incorrecta, insertar log
        v_datos_antes := jsonb_build_object('contrasena', v_contrasena);
INSERT INTO log.log_cambios(tabla, id_registro, accion, datos_antes, datos_despues, usuario_bd)
VALUES (
           'usuario',
           p_id_usuario::TEXT,
           'UPDATE',
           v_datos_antes,
           '',
           CURRENT_USER
       );
RAISE EXCEPTION 'Contraseña actual incorrecta';
END IF;
END;
$$;


--Eliminar todos los registros de parqueo de un vehículo específico
CREATE OR REPLACE PROCEDURE eliminar_registros_parqueo(
    IN p_placa VARCHAR(7)
)
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM registro_parqueo WHERE placa = p_placa) THEN
        RAISE EXCEPTION 'No existen registros de parqueo con la placa %', p_placa;
    END IF;

    UPDATE registro_parqueo
    SET eliminado = TRUE
    WHERE placa = p_placa;
END;
$$;

--Verificar si un usuario tiene más de un vehículo registrado
CREATE OR REPLACE FUNCTION verificar_vehiculos_usuario(
    p_id_usuario INT
) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_cantidad INT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM usuario WHERE id_usuario = p_id_usuario AND eliminado = FALSE
    ) THEN
        RAISE EXCEPTION 'Usuario % no existe o está eliminado', p_id_usuario;
    END IF;

    SELECT COUNT(*) INTO v_cantidad
    FROM vehiculo
    WHERE id_usuario = p_id_usuario AND eliminado = FALSE;

    RETURN v_cantidad;
END;
$$;

--Reasignar un vehículo a otro usuario
CREATE OR REPLACE PROCEDURE reasignar_vehiculo(
    IN p_placa VARCHAR(7),
    IN p_nuevo_id_usuario INT
)
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM vehiculo WHERE placa = p_placa AND eliminado = FALSE) THEN
        RAISE EXCEPTION 'Vehículo con placa % no existe o está eliminado', p_placa;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM usuario WHERE id_usuario = p_nuevo_id_usuario AND eliminado = FALSE) THEN
        RAISE EXCEPTION 'Nuevo usuario % no existe o está eliminado', p_nuevo_id_usuario;
    END IF;

    UPDATE vehiculo
    SET id_usuario = p_nuevo_id_usuario
    WHERE placa = p_placa AND eliminado = FALSE;
END;
$$;

--Obtener información completa de un vehículo (usuario, tipo, historial)
CREATE OR REPLACE FUNCTION info_completa_vehiculo(
    p_placa VARCHAR(7)
)
    RETURNS TABLE (
                      placa VARCHAR(7),
                      nombre VARCHAR(50),
                      apellidos VARCHAR(100),
                      nombre_tipo_vehiculo VARCHAR(50),
                      fecha_hora_ingreso TIMESTAMP,
                      fecha_hora_salida TIMESTAMP,
                      id_espacio_parqueo INT,
                      nombre_seccion VARCHAR(50)
                  )
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM vehiculo v WHERE v.placa = p_placa AND v.eliminado = FALSE
    ) THEN
        RAISE EXCEPTION 'Vehículo con placa % no existe o está eliminado', p_placa;
    END IF;

    RETURN QUERY
        SELECT
            v.placa,
            u.nombre,
            u.apellidos,
            tv.nombre_tipo_vehiculo,
            rp.fecha_hora_ingreso,
            rp.fecha_hora_salida,
            ep.id_espacio_parqueo,
            sp.nombre_seccion
        FROM vehiculo v
                 JOIN usuario u ON v.id_usuario = u.id_usuario
                 JOIN tipo_vehiculo tv ON v.id_tipo_vehiculo = tv.id_tipo_vehiculo
                 LEFT JOIN registro_parqueo rp ON v.placa = rp.placa
                 LEFT JOIN espacio_parqueo ep ON rp.id_espacio_parqueo = ep.id_espacio_parqueo
                 LEFT JOIN seccion_parqueo sp ON ep.id_seccion = sp.id_seccion
        WHERE v.placa = p_placa AND v.eliminado = FALSE;
END;
$$;



select * from registro_parqueo;
SELECT * FROM listar_vehiculos_por_seccion(1);
