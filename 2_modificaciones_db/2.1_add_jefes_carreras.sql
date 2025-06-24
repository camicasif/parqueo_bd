INSERT INTO config.tipo_usuario (id_tipo_usuario, nombre_tipo_usuario)
VALUES (6, 'Jefes de carrera');

INSERT INTO core.seccion_parqueo (id_seccion, nombre_seccion, id_tipo_usuario)
VALUES (16, 'Seccion 16', 6);


INSERT INTO config.tipo_vehiculo_seccion (id_seccion, id_tipo_vehiculo)
VALUES
    (16, 1),
    (16, 2),
    (16, 3);

-- 10 esapcios para el usuario jefe de carrera asociado a la seccion 16
DO $$
BEGIN
FOR i IN 1..10 LOOP
                INSERT INTO core.espacio_parqueo (id_estado, id_seccion)
                VALUES (1, 16);
END LOOP;
END $$;

DO $$
DECLARE
nombres_completos TEXT[] := ARRAY[
        'Juan Pablo Gonzales',
        'Melina Arqueaga',
        'Carla Soliz',
        'Giselle Calvo',
        'Carlos Anibarro',
        'Kurt Jurgensen',
        'Paola Estrada',
        'Luis Alberto Villalba',
        'Alejandra Guardia',
        'Bernardo Agustin'
    ];
    i INT;
    partes TEXT[];
    nombre_final TEXT;
    apellido_final TEXT;
    id_usuario_insertado INT;
    tipo_vehiculo INT;
BEGIN
FOR i IN 1..array_length(nombres_completos, 1) LOOP
        -- Dividir el nombre completo en partes
        partes := regexp_split_to_array(nombres_completos[i], ' ');

        -- El apellido es la última palabra, el resto es el nombre
        apellido_final := partes[array_length(partes, 1)];
        nombre_final := array_to_string(partes[1:array_length(partes, 1) - 1], ' ');

        -- Insertar usuario
INSERT INTO core.usuario (
    codigo_universitario,
    telefono_contacto,
    contrasena,
    id_tipo_usuario,
    nombre,
    apellidos
)
VALUES (
           900000 + i,
           78000000 + i,
           'jefe' || i,
           6,
           nombre_final,
           apellido_final
       )
    RETURNING id_usuario INTO id_usuario_insertado;

-- Alternar entre auto (2) y camioneta (3)
tipo_vehiculo := CASE WHEN i % 2 = 0 THEN 3 ELSE 2 END;

        -- Insertar vehículo
INSERT INTO core.vehiculo (
    placa,
    id_tipo_vehiculo,
    id_usuario
)
VALUES (
           'JEF' || LPAD(i::TEXT, 4, '0'),
           tipo_vehiculo,
           id_usuario_insertado
       );
END LOOP;
END $$;

SELECT * from usuario u inner join core.vehiculo v on u.id_usuario = v.id_usuario where u.id_tipo_usuario =6