-----Login errores
--------------------------------
CREATE OR REPLACE FUNCTION registrar_login_fallido_en_log(
    p_codigo_universitario INTEGER,
    p_motivo TEXT,
    p_usuario_bd TEXT
) RETURNS VOID AS $$
DECLARE
    v_datos JSONB;
BEGIN
    v_datos := jsonb_build_object(
        'codigo_universitario', p_codigo_universitario,
        'motivo', p_motivo
    );

    INSERT INTO log.log_cambios (
        tabla,
        id_registro,
        accion,
        datos_antes,
        datos_despues,
        fecha_evento,
        usuario_bd
    )
    VALUES (
        'usuario',
        p_codigo_universitario::TEXT,
        'login_fallido',
        v_datos,
        NULL,
        NOW(),
        p_usuario_bd
    );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION validar_login(
    p_codigo_universitario INTEGER,
    p_contrasena VARCHAR,
    p_usuario_bd TEXT DEFAULT 'admin'
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
        -- Loguear intento fallido
        PERFORM registrar_login_fallido_en_log(
            p_codigo_universitario,
            'Credenciales inválidas o usuario desactivado',
            p_usuario_bd
        );
        RAISE NOTICE 'Credenciales inválidas o usuario desactivado.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error en validación de login: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
