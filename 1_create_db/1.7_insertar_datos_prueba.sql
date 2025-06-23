--insertar usuarios, vehiculos, reservas. registros
DO $$
    DECLARE
        nombres TEXT[] := ARRAY[
            'Carlos', 'Ana', 'Luis', 'María', 'Pedro', 'Lucía', 'José', 'Sofía', 'Jorge', 'Camila',
            'Andrés', 'Valeria', 'Ricardo', 'Elena', 'Diego', 'Fernanda', 'Santiago', 'Daniela',
            'Manuel', 'Gabriela', 'Raúl', 'Patricia', 'Miguel', 'Alejandra', 'Javier',
            'Rosa', 'Fernando', 'Carmen', 'Rubén', 'Isabel', 'Tomás', 'Liliana', 'Ernesto',
            'Carolina', 'Héctor', 'Paola', 'Eduardo', 'Beatriz', 'Álvaro', 'Mónica',
            'Gustavo', 'Verónica', 'Rodrigo', 'Silvia', 'Marcos', 'Lorena', 'Nicolás', 'Claudia', 'Iván', 'Natalia',
            -- 50 adicionales
            'Benjamín', 'Agustina', 'Facundo', 'Julieta', 'Thiago', 'Martina', 'Luciano', 'Josefina', 'Emiliano', 'Renata',
            'Franco', 'Bianca', 'Matías', 'Zoe', 'Axel', 'Victoria', 'Kevin', 'Antonella', 'Tomás', 'Mia',
            'Esteban', 'Ariadna', 'Bruno', 'Regina', 'Alan', 'Florencia', 'Ivana', 'Ciro', 'Milagros', 'Sebastián',
            'Noelia', 'Axel', 'Valentín', 'Carla', 'Dante', 'Nicole', 'Fabián', 'Melina', 'Ramiro', 'Celeste',
            'Leandro', 'Juliana', 'Ulises', 'Abril', 'Federico', 'Aitana', 'Simón', 'Tamara', 'Cristian', 'Elsa'
            ];

        apellidos TEXT[] := ARRAY[
            'García', 'Rodríguez', 'Martínez', 'López', 'Hernández', 'González', 'Pérez', 'Sánchez', 'Ramírez', 'Cruz',
            'Flores', 'Rivera', 'Torres', 'Gómez', 'Díaz', 'Reyes', 'Morales', 'Ortiz', 'Gutiérrez', 'Chávez',
            'Ramos', 'Vargas', 'Castro', 'Jiménez', 'Romero', 'Navarro', 'Medina', 'Aguilar', 'Rojas', 'Mendoza',
            'Salazar', 'Delgado', 'Cortés', 'Cabrera', 'Vega', 'Paredes', 'Silva', 'Peña', 'Escobar',
            'Molina', 'Acosta', 'Fuentes', 'Carrillo', 'Ibarra', 'Palacios', 'Arroyo', 'Valdez', 'Barrios', 'Montoya',
            -- 50 adicionales
            'Alvarado', 'Bravo', 'Camacho', 'Domínguez', 'Estévez', 'Figueroa', 'Galindo', 'Herrera', 'Infante', 'Juárez',
            'Lara', 'Mejía', 'Nieto', 'Orozco', 'Pacheco', 'Quintero', 'Rentería', 'Saavedra', 'Tapia', 'Uribe',
            'Varela', 'Wong', 'Zambrano', 'Yáñez', 'Bautista', 'Cardozo', 'Espinoza', 'Garrido', 'Huerta', 'Izquierdo',
            'Jacinto', 'Lemus', 'Mojica', 'Noriega', 'Olivares', 'Pinto', 'Quezada', 'Rosales', 'Soria', 'Tobar',
            'Ulloa', 'Villalobos', 'Ximénez', 'Yupanqui', 'Zárate', 'Campos', 'Durán', 'Escalante', 'Franco', 'Gallo'
            ];

        i INTEGER;
        nombre_sel TEXT;
        apellido_sel TEXT;
        tipo_usuario_id INT;
    BEGIN
        FOR i IN 1..500 LOOP
                -- Para más combinaciones, permitimos nombres y apellidos aleatorios sin importar repeticiones
                nombre_sel := nombres[ceil(random() * array_length(nombres, 1))];
                apellido_sel := apellidos[ceil(random() * array_length(apellidos, 1))];

                -- Asignar tipo de usuario según rangos exactos
                IF i <= 50 THEN
                    tipo_usuario_id := 2;  -- Docente
                ELSIF i <= 110 THEN
                    tipo_usuario_id := 3;  -- Administrativo
                ELSIF i <= 115 THEN
                    tipo_usuario_id := 4;  -- Externo
                ELSIF i <= 120 THEN
                    tipo_usuario_id := 5;  -- Discapacitado
                ELSE
                    tipo_usuario_id := 1;  -- Estudiante
                END IF;

                INSERT INTO usuario (
                    codigo_universitario,
                    telefono_contacto,
                    contrasena,
                    id_tipo_usuario,
                    nombre,
                    apellidos
                ) VALUES (
                             100000 + i,
                             70000000 + i,
                             'pass' || i,
                             tipo_usuario_id,
                             nombre_sel,
                             apellido_sel
                         );
            END LOOP;
    END $$;

/************************** INSERTAR VEHICULOS ********************************************/

DO $$
    DECLARE
        i INT;
        tipo_vehiculo INT;
        v_id_tipo_usuario INT;
        vehiculos_por_usuario INT;
        bus_asignado BOOLEAN := FALSE;
    BEGIN
        FOR i IN 1..500 LOOP
                -- Obtener tipo de usuario
                SELECT id_tipo_usuario INTO v_id_tipo_usuario FROM usuario WHERE id_usuario = i;

                -- Determinar cuántos vehículos debe tener
                IF i <= 100 THEN
                    vehiculos_por_usuario := 2;
                ELSE
                    vehiculos_por_usuario := 1;
                END IF;

                FOR j IN 1..vehiculos_por_usuario LOOP
                        -- Lógica de tipo de vehículo
                        IF v_id_tipo_usuario = 4 THEN -- Externo
                            IF NOT bus_asignado THEN
                                tipo_vehiculo := 2; -- uno con auto
                                bus_asignado := TRUE;
                            ELSE
                                tipo_vehiculo := 4; -- bus
                            END IF;

                        ELSIF v_id_tipo_usuario = 5 THEN -- Discapacitado
                        -- Solo auto o camioneta (sin moto)
                            tipo_vehiculo := CASE
                                                 WHEN random() < 0.7 THEN 2 -- auto
                                                 ELSE 3 -- camioneta
                                END;

                        ELSE -- Estudiante, Docente, Administrativo
                            IF i <= 100 THEN
                                -- Aleatorio entre moto, auto, camioneta
                                tipo_vehiculo := floor(random() * 3 + 1); -- 1 a 3
                            ELSE
                                -- Sesgo: más autos
                                tipo_vehiculo := CASE
                                                     WHEN random() < 0.1 THEN 3  -- 10% camioneta
                                                     WHEN random() < 0.2 THEN 1  -- 10% moto
                                                     ELSE 2                      -- 80% auto
                                    END;
                            END IF;
                        END IF;

                        -- Insertar vehículo
                        INSERT INTO vehiculo (
                             placa, id_tipo_vehiculo, id_usuario
                        ) VALUES (
                                     'ABC' || LPAD((i::TEXT || j::TEXT), 4, '0'),
                                     tipo_vehiculo,
                                     i
                                 );
                    END LOOP;
            END LOOP;
    END $$;


-- voy a insertar por dia
-- en esa fecha de ese dia van a haber 480 registros
-- los buses los ingreso despues
--
