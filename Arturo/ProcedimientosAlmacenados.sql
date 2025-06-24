--Asignar sección de parqueo a un tipo de usuario
CREATE PROCEDURE asignar_seccion_a_usuario(
    IN p_id_seccion INT,
    IN p_id_tipo_usuario INT
)
    language plpgsql
as
$$
BEGIN
UPDATE seccion_parqueo
SET id_tipo_usuario = p_id_tipo_usuario
WHERE id_seccion = p_id_seccion;
END;
$$;

--Asignar tipo de vehículo a una sección permitida
CREATE PROCEDURE asignar_tipo_vehiculo_a_seccion(
    IN p_id_tipo_vehiculo INT,
    IN p_id_seccion INT
)
    language plpgsql
as
$$
BEGIN
INSERT INTO tipo_vehiculo_seccion (id_tipo_vehiculo, id_seccion)
VALUES (p_id_tipo_vehiculo, p_id_seccion);
END;
$$;

--Verificar si una combinación de *tipo\_vehículo* y *sección* es válida
CREATE PROCEDURE verificar_combinacion_valida(
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
    ) THEN
SELECT 'Válido' AS resultado;
ELSE
SELECT 'Inválido' AS resultado;
END IF;
END;
$$;

--Listar las secciones disponibles para un tipo de vehículo específico
CREATE PROCEDURE listar_secciones_por_tipo_vehiculo(
    IN p_id_tipo_vehiculo INT
)
    language plpgsql
as
$$
BEGIN
SELECT sp.id_seccion, sp.nombre_seccion
FROM tipo_vehiculo_seccion tvs
         JOIN seccion_parqueo sp ON tvs.id_seccion = sp.id_seccion
WHERE tvs.id_tipo_vehiculo = p_id_tipo_vehiculo;
END;
$$;

--Listar los tipos de vehículos permitidos por sección
CREATE PROCEDURE listar_vehiculos_por_seccion(
    IN p_id_seccion INT
)
    language plpgsql
as
$$
BEGIN
SELECT tv.id_tipo_vehiculo, tv.nombre_tipo_vehiculo
FROM tipo_vehiculo_seccion tvs
         JOIN tipo_vehiculo tv ON tv.id_tipo_vehiculo = tvs.id_tipo_vehiculo
WHERE tvs.id_seccion = p_id_seccion;
END;
$$;

CREATE PROCEDURE resetear_contrasena_usuario(
    IN p_id_usuario INT,
    IN p_contrasena_actual VARCHAR(100),
    IN p_nueva_contrasena VARCHAR(100)
)
    language plpgsql
as
$$
DECLARE
v_contrasena VARCHAR(100);
    v_user_exists BOOLEAN;
BEGIN
    IF p_nueva_contrasena IS NULL OR LENGTH(TRIM(p_nueva_contrasena)) < 8 THEN
        RAISE EXCEPTION 'La nueva contraseña debe tener al menos 8 caracteres';
END IF;

SELECT EXISTS (
    SELECT 1 FROM usuario WHERE id_usuario = p_id_usuario
) INTO v_user_exists;

IF NOT v_user_exists THEN
        RAISE EXCEPTION 'Usuario no encontrado';
END IF;

SELECT contrasena INTO v_contrasena
FROM usuario
WHERE id_usuario = p_id_usuario;

IF v_contrasena = p_contrasena_actual THEN
UPDATE usuario
SET contrasena = p_nueva_contrasena
WHERE id_usuario = p_id_usuario;
ELSE
        RAISE EXCEPTION 'Contraseña actual incorrecta';
END IF;
END;
$$;

--Eliminar todos los registros de parqueo de un vehículo específico
CREATE PROCEDURE eliminar_registros_parqueo(
    IN p_placa VARCHAR(7)
)
    language plpgsql
as
$$
BEGIN
DELETE FROM registro_parqueo
WHERE placa = p_placa;
END;
$$;

--Verificar si un usuario tiene más de un vehículo registrado
CREATE PROCEDURE verificar_vehiculos_usuario(
    IN p_id_usuario INT
)
    language plpgsql
as
$$
BEGIN
SELECT COUNT(*) AS cantidad
FROM vehiculo
WHERE id_usuario = p_id_usuario;
END;
$$;

--Reasignar un vehículo a otro usuario
CREATE PROCEDURE reasignar_vehiculo(
    IN p_placa VARCHAR(7),
    IN p_nuevo_id_usuario INT
)
    language plpgsql
as
$$
BEGIN
UPDATE vehiculo
SET id_usuario = p_nuevo_id_usuario
WHERE placa = p_placa;
END;
$$;

--Obtener información completa de un vehículo (usuario, tipo, historial)
CREATE PROCEDURE info_completa_vehiculo(
    IN p_placa VARCHAR(7)
)
    language plpgsql
as
$$
BEGIN
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
WHERE v.placa = p_placa;
END;
$$;