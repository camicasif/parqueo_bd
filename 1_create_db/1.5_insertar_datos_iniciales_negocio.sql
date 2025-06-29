-- Insertar tipos de usuario
INSERT INTO config.tipo_usuario (id_tipo_usuario, nombre_tipo_usuario)
VALUES (1, 'Estudiante'),
       (2, 'Administrativo'),
       (3, 'Docente'),
       (4, 'Externo'),
       (5, 'Discapacitado');


-- Insertar tipos de vehículo
INSERT INTO config.tipo_vehiculo (id_tipo_vehiculo, nombre_tipo_vehiculo)
VALUES (1, 'Moto'),
       (2, 'Auto'),
       (3, 'Camioneta'),
       (4, 'Bus');


INSERT INTO core.seccion_parqueo (id_seccion, nombre_seccion, id_tipo_usuario)
VALUES (1, 'Seccion 1', 1),
       (2, 'Seccion 2', 2),
       (3, 'Seccion 3', 3),
       (4, 'Seccion 4', 1),
       (5, 'Seccion 5', 1),
       (6, 'Seccion 6', 1),
       (7, 'Seccion 7', 1),
       (8, 'Seccion 8', 1),
       (9, 'Seccion 9', 1),
       (10, 'Seccion 10', 2),
       (11, 'Seccion 11', 2),
       (12, 'Seccion 12', 3),
       (13, 'Seccion 13', 3),
       (14, 'Seccion 14', 4),
       (15, 'Seccion 15', 5);



DO $$
    DECLARE
        seccion_id INTEGER;
        i INTEGER;
    BEGIN
        FOR seccion_id IN
            SELECT id_seccion FROM core.seccion_parqueo
            LOOP
                FOR i IN 1..10 LOOP
                        INSERT INTO core.espacio_parqueo (estado, id_seccion)
                        VALUES ('Disponible', seccion_id);  -- 1 = Disponible
                    END LOOP;
            END LOOP;
    END $$;

DO $$
    BEGIN
        FOR i IN 1..3 LOOP
                INSERT INTO core.espacio_parqueo (estado, id_seccion)
                VALUES ('Disponible', 15);  -- Disponible en sección 15 (Discapacitados)
            END LOOP;
    END $$;


-- Secciones 1, 2, 3 → Moto
INSERT INTO config.tipo_vehiculo_seccion (id_seccion, id_tipo_vehiculo)
VALUES
    (1, 1),
    (2, 1),
    (3, 1);

-- Secciones 4 a 13 → Auto
INSERT INTO config.tipo_vehiculo_seccion (id_seccion, id_tipo_vehiculo)
SELECT generate_series(4, 13), 2;

-- Secciones 4, 5, 10, 12 → Camioneta
INSERT INTO config.tipo_vehiculo_seccion (id_seccion, id_tipo_vehiculo)
VALUES
    (4, 3),
    (5, 3),
    (10, 3),
    (12, 3);

-- Sección 14 → Moto, Auto, Camioneta, Bus
INSERT INTO config.tipo_vehiculo_seccion (id_seccion, id_tipo_vehiculo)
VALUES
    (14, 1),
    (14, 2),
    (14, 3),
    (14, 4);

