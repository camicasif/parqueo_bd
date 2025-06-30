CREATE OR REPLACE FUNCTION registrar_login_fallido_en_log(
    p_id_usuario INTEGER,
    p_motivo TEXT,
    p_direccion_ip TEXT DEFAULT '127.0.0.1'
) RETURNS VOID AS $$
DECLARE
    v_fallas_count INTEGER;
BEGIN
    -- Registrar el intento fallido
    INSERT INTO log.log_intentos_login (
        id_usuario,
        exito,
        direccion_ip,
        motivo
    ) VALUES (
        p_id_usuario,
        FALSE,
        p_direccion_ip,
        p_motivo
    );

    -- Verificar si hay 3 fallos consecutivos
    SELECT COUNT(*) INTO v_fallas_count
    FROM (
        SELECT exito
        FROM log.log_intentos_login
        WHERE id_usuario = p_id_usuario
        ORDER BY fecha_intento DESC
        LIMIT 3
    ) sub
    WHERE exito = FALSE;

    -- Bloquear si hay 3 fallos seguidos
    IF v_fallas_count = 3 THEN
        UPDATE core.usuario
        SET bloqueado = TRUE
        WHERE id_usuario = p_id_usuario;

        RAISE NOTICE 'Usuario bloqueado por múltiples intentos fallidos.';
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION validar_login(
    p_codigo_universitario INTEGER,
    p_contrasena VARCHAR,
    p_direccion_ip TEXT DEFAULT '127.0.0.1'
) RETURNS VOID AS $$
DECLARE
    v_usuario core.usuario%ROWTYPE;
BEGIN
    -- Buscar al usuario por código universitario
    SELECT * INTO v_usuario
    FROM core.usuario
    WHERE codigo_universitario = p_codigo_universitario
      AND eliminado = FALSE;

    -- Si no existe
    IF NOT FOUND THEN
        RAISE NOTICE 'Usuario no encontrado.';
        RETURN;
    END IF;

    -- Si está bloqueado
    IF v_usuario.bloqueado THEN
        RAISE NOTICE 'El usuario está bloqueado.';
        RETURN;
    END IF;

    -- Verificar contraseña
    IF v_usuario.contrasena = p_contrasena THEN
        RAISE NOTICE 'Login exitoso. Bienvenido, % %', v_usuario.nombre, v_usuario.apellidos;
    ELSE
        -- Intento fallido
        PERFORM registrar_login_fallido_en_log(
            v_usuario.id_usuario,
            'Contraseña incorrecta',
            p_direccion_ip
        );
        RAISE NOTICE 'Credenciales inválidas.';
    END IF;
END;
$$ LANGUAGE plpgsql;


SELECT validar_login(100045, 'clave_incorrecta1', '192.168.1.10');
SELECT validar_login(100045, 'clave_incorrecta1', '192.168.1.10');


;