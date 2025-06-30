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
RETURNS TABLE (
    id_usuario INTEGER,
    nombre VARCHAR,
    apellidos VARCHAR,
    nombre_tipo_usuario VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT u.id_usuario, u.nombre, u.apellidos, tu.nombre_tipo_usuario
    FROM core.usuario u
    JOIN config.tipo_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
    WHERE u.eliminado = false
    ORDER BY tu.nombre_tipo_usuario, u.nombre;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validar_login(
    p_codigo_universitario INTEGER,
    p_contrasena VARCHAR,
    p_direccion_ip VARCHAR DEFAULT '0.0.0.0'
) RETURNS VOID AS $$
DECLARE
    v_usuario core.usuario%ROWTYPE;
    v_exito BOOLEAN := FALSE;
    v_motivo TEXT := '';
BEGIN
    -- Buscar al usuario por su código
    SELECT * INTO v_usuario
    FROM core.usuario
    WHERE codigo_universitario = p_codigo_universitario
      AND eliminado = FALSE;

    IF NOT FOUND THEN
        v_motivo := 'Usuario no encontrado o eliminado';
        RAISE NOTICE 'Credenciales inválidas.';
    ELSIF v_usuario.bloqueado THEN
        v_motivo := 'Usuario bloqueado';
        RAISE NOTICE 'Usuario bloqueado.';
    ELSIF v_usuario.contrasena = p_contrasena THEN
        v_exito := TRUE;
        v_motivo := 'Login exitoso';
        RAISE NOTICE 'Login exitoso. Bienvenido, % %', v_usuario.nombre, v_usuario.apellidos;
    ELSE
        v_motivo := 'Contraseña incorrecta';
        RAISE NOTICE 'Contraseña incorrecta.';
    END IF;

    -- Registrar el intento en el log
    PERFORM registrar_intento_login(v_usuario.id_usuario, v_exito, p_direccion_ip, v_motivo);

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
    p_usuario_creacion TEXT DEFAULT current_user,
    p_descripcion TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    IF LENGTH(p_placa) <> 7 THEN
        RAISE EXCEPTION 'La placa debe tener exactamente 7 caracteres.';
    END IF;

    INSERT INTO core.vehiculo (
        placa, id_tipo_vehiculo, id_usuario,
         usuario_creacion, descripcion, eliminado
    )
    VALUES (
        p_placa, p_id_tipo_vehiculo, p_id_usuario,
            p_usuario_creacion, p_descripcion, false
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
CREATE OR REPLACE FUNCTION registrar_intento_login(
    p_id_usuario INTEGER,
    p_exito BOOLEAN,
    p_direccion_ip VARCHAR,
    p_motivo TEXT
) RETURNS VOID AS $$
DECLARE
    intentos_fallidos INTEGER;
BEGIN
    -- Registrar el intento en el log
    INSERT INTO core.log_intentos_login (
        id_usuario, exito, direccion_ip, motivo
    ) VALUES (
        p_id_usuario, p_exito, p_direccion_ip, p_motivo
    );

    -- Si el intento fue fallido, contamos cuántos fallos seguidos lleva hoy
    IF NOT p_exito THEN
        SELECT COUNT(*) INTO intentos_fallidos
        FROM core.log_intentos_login
        WHERE id_usuario = p_id_usuario
          AND exito = FALSE
          AND fecha_intento::date = CURRENT_DATE;

        -- Si tiene 3 o más fallos hoy, lo bloqueamos
        IF intentos_fallidos >= 3 THEN
            UPDATE core.usuario
            SET bloqueado = TRUE
            WHERE id_usuario = p_id_usuario;

            RAISE NOTICE 'Usuario bloqueado por múltiples intentos fallidos.';
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_cambiar_tipo_usuario(
    p_id_usuario INTEGER,
    p_nuevo_tipo INTEGER,
    p_usuario_operacion VARCHAR
)
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

    -- Registrar en log de cambios con valor permitido en 'accion'
    INSERT INTO log.log_cambios (
        tabla, id_registro, accion, datos_antes, datos_despues, fecha_evento, usuario_bd
    )
    VALUES (
        'usuario',
        p_id_usuario::varchar,
        'UPDATE',  -- este valor sí pasa la restricción CHECK
        datos_antes,
        (SELECT row_to_json(u) FROM core.usuario u WHERE id_usuario = p_id_usuario),
        NOW(),
        p_usuario_operacion
    );

END;
$$ LANGUAGE plpgsql;




--- 1. `registrar_usuario(...)`

---**Descripción:** Crea un nuevo usuario en el sistema, validando la seguridad de la contraseña y evitando registros incorrectos.
---**Ejemplos de uso:**

SELECT registrar_usuario(12345, '70000000', 'Passw0rd', 'Juan', 'Pérez', 2);
SELECT registrar_usuario(67890, '75556666', 'Seguro123', 'Ana', 'Gómez', 3);

--- 2. `actualizar_usuario(...)`

---**Descripción:** Actualiza los datos de un usuario existente si no ha sido eliminado lógicamente.
---**Ejemplos de uso:**

SELECT actualizar_usuario(1, 12345, '70009999', 'NuevaPass1', 'Juan', 'Pérez', 2);
SELECT actualizar_usuario(5, 67890, '71112233', 'OtraPass2', 'Ana', 'Gómez', 3);

--- 3. `eliminar_usuario(p_id_usuario)`

---**Descripción:** Realiza un "soft delete" del usuario y de todos sus vehículos asociados.
---**Ejemplos de uso:**

SELECT eliminar_usuario(1);
SELECT eliminar_usuario(7);

--- 4. `listar_usuarios_por_tipo()`

---**Descripción:** Lista todos los usuarios activos agrupados por tipo de usuario.
---**Ejemplos de uso:**

SELECT * FROM listar_usuarios_por_tipo();

--- 5. `validar_login(...)`

---**Descripción:** Verifica si las credenciales son correctas e informa si el usuario está bloqueado o la contraseña es incorrecta. Registra el intento.
---**Ejemplos de uso:**

SELECT validar_login(12345, 'Passw0rd');
SELECT validar_login(67890, 'Seguro123', '192.168.0.1');

--- 6. `registrar_vehiculo(...)`

---**Descripción:** Registra un nuevo vehículo con validación de placa, relación con usuario y tipo de vehículo.
---**Ejemplos de uso:**

-- Correcto:
SELECT registrar_vehiculo('ABC1234', 1, 2, 54001);
SELECT registrar_vehiculo('XYZ5678', 3, 4, 'admin');


--- 8. `eliminar_vehiculo_por_placa(p_placa)`

---**Descripción:** Realiza un "soft delete" del vehículo asociado a la placa dada.
---**Ejemplos de uso:**
SELECT eliminar_vehiculo_por_placa('ABC1234');
SELECT eliminar_vehiculo_por_placa('ABC0151');

---

---### 9. `listar_vehiculos_por_usuario(p_id_usuario)`

---**Descripción:** Lista los vehículos activos registrados por un usuario.
---**Ejemplos de uso:**
SELECT listar_vehiculos_por_usuario(2);
SELECT listar_vehiculos_por_usuario(4);

---

---### 10. `verificar_vehiculo_por_placa(p_placa)`

---**Descripción:** Verifica si existe un vehículo activo con la placa indicada.
---**Ejemplos de uso:**
SELECT verificar_vehiculo_por_placa('ABC1234');
SELECT verificar_vehiculo_por_placa('ZZZ9999');

---

---### 11. `historial_parqueo_vehiculo(p_placa)`

---**Descripción:** Devuelve el historial de entradas y salidas de parqueo de un vehículo.
---**Ejemplos de uso:**
SELECT * FROM historial_parqueo_vehiculo('ABC1234');
SELECT * FROM historial_parqueo_vehiculo('ABC0791');

---

---### 12. `fn_tiempo_promedio_parqueo(p_id_usuario)`

---**Descripción:** Calcula el tiempo promedio que un usuario permanece estacionado.
---**Ejemplos de uso:**
SELECT fn_tiempo_promedio_parqueo(1);
SELECT fn_tiempo_promedio_parqueo(2);

---

---### 14. `fn_usuario_sobrepasa_limite(...)`

---**Descripción:** Verifica si un usuario ha excedido un límite de horas en el parqueo hoy.
----**Ejemplos de uso:**
SELECT fn_usuario_sobrepasa_limite(58, 1);
SELECT fn_usuario_sobrepasa_limite(3, 2);

---

---### 15. `registrar_intento_login(...)`(revisarrr)

---**Descripción:** Registra un intento de inicio de sesión y bloquea al usuario tras 3 intentos fallidos en el día.
---**Ejemplos de uso:**
SELECT registrar_intento_login(1, false, '192.168.1.1', 'Contraseña incorrecta');
SELECT registrar_intento_login(2, true, '192.168.1.2', 'Login exitoso');


---


---### 18. `fn_cambiar_tipo_usuario(...)`

---**Descripción:** Cambia el tipo de usuario y registra el cambio con datos anteriores y posteriores.
---**Ejemplos de uso:**

SELECT fn_cambiar_tipo_usuario(1, 3, 'admin');
SELECT fn_cambiar_tipo_usuario(4, 2, 'moderador');

SELECT id_usuario, id_tipo_usuario, usuario_creacion, fecha_creacion
FROM core.usuario
WHERE id_usuario = 1;
