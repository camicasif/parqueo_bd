/************* 1. Cambiar tabla estado por enum **************/
--
-- CREATE TYPE estado_espacio AS ENUM ('Disponible', 'Reservado', 'Ocupado');
-- ALTER TABLE core.espacio_parqueo
--     ALTER COLUMN id_estado DROP DEFAULT,
--     DROP COLUMN id_estado,
--     ADD COLUMN estado estado_espacio NOT NULL DEFAULT 'Disponible';
-- drop table config.estado_espacio_parqueo;
--
-- CREATE TYPE estado_reserva AS ENUM ('pendiente', 'aprobada', 'rechazada', 'cancelada');
--
-- ALTER TABLE core.reserva_espacio
--     ALTER COLUMN estado DROP DEFAULT;
--
-- ALTER TABLE core.reserva_espacio
--     ALTER COLUMN estado TYPE estado_reserva
--         USING estado::estado_reserva;
--
-- ALTER TABLE core.reserva_espacio
--     ALTER COLUMN estado SET DEFAULT 'pendiente';

/************* 2. Agregar campos de auditoria ***************/

-- Agregar campos de auditoría básica a core.usuario
ALTER TABLE core.usuario
    ADD COLUMN fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN usuario_creacion VARCHAR(100) DEFAULT CURRENT_USER;

-- Agregar a core.vehiculo
ALTER TABLE core.vehiculo
    ADD COLUMN fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN usuario_creacion VARCHAR(100) DEFAULT CURRENT_USER;

-- Agregar a core.seccion_parqueo
ALTER TABLE core.seccion_parqueo
    ADD COLUMN fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN usuario_creacion VARCHAR(100) DEFAULT CURRENT_USER;

-- Agregar a core.espacio_parqueo
ALTER TABLE core.espacio_parqueo
    ADD COLUMN fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN usuario_creacion VARCHAR(100) DEFAULT CURRENT_USER;

-- Agregar a core.reserva_espacio
ALTER TABLE core.reserva_espacio
    ADD COLUMN usuario_creacion VARCHAR(100) DEFAULT CURRENT_USER;

-- Agregar a core.registro_parqueo
ALTER TABLE core.registro_parqueo
    ADD COLUMN fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN usuario_creacion VARCHAR(100) DEFAULT CURRENT_USER;

/************ 3. Agregar tabla comentarios y columnas descripcion a vehiculo **********/

ALTER TABLE core.vehiculo
    ADD COLUMN descripcion VARCHAR(255);

DO $$
    DECLARE
        r RECORD;
        descripciones_moto TEXT[] := ARRAY['Moto deportiva roja, con escape modificado',
            'Scooter blanca en perfecto estado',
            'Moto negra con rayón en el tanque',
            'Enduro azul con neumáticos todoterreno',
            'Moto gris con asiento desgastado',
            'Chopper cromada, sin fallas visibles',
            'Moto eléctrica negra, sin ruido',
            'Moto amarilla con espejos rotos',
            'Moto custom roja con alforjas',
            'Scooter verde con rayón leve en guardabarros',
            'Moto azul marino, neumáticos nuevos',
            'Moto blanca, rayón en la defensa delantera',
            'Ciclomotor rojo, usado ocasionalmente',
            'Moto negra deportiva con luces LED',
            'Moto café con detalles en cuero',
            'Moto gris sin carenado, usada en ciudad',
            'Moto blanca con manillar modificado',
            'Enduro roja, rayón lateral izquierdo',
            'Moto antigua negra restaurada',
            'Moto touring azul con parabrisas rajado'];
        descripciones_auto TEXT[] := ARRAY['Sedán blanco, rayón leve en la puerta',
            'Hatchback gris, sin detalles visibles',
            'Coupe rojo, abolladura en el capó',
            'Sedán negro con techo solar',
            'Auto compacto verde, pintura opaca',
            'Sedán azul marino, rayón en parachoques trasero',
            'Sedán plateado, en excelente estado',
            'Auto blanco con rayón en guardabarros izquierdo',
            'Coupe negro, con polarizado',
            'Auto gris oscuro, defensa trasera dañada',
            'Sedán vino, sin fallas visibles',
            'Sedán rojo, desgaste en pintura del techo',
            'Auto beige, rayón pequeño en costado',
            'Auto azul cielo con faros nuevos',
            'Sedán gris con rayón en puerta trasera',
            'Auto negro, polarizado al 50%',
            'Sedán blanco, rayón en defensa frontal',
            'Auto gris, tapicería manchada',
            'Hatchback rojo, con llantas nuevas',
            'Auto marrón, sin daños visibles',
            'Auto verde con espejos nuevos',
            'Sedán negro, rayón leve lado derecho',
            'Coupe gris claro, interior en buen estado',
            'Auto azul, con pequeña abolladura frontal',
            'Sedán rojo oscuro, sin observaciones',
            'Auto blanco perla con detalles cromados',
            'Sedán azul con tapicería de cuero',
            'Hatchback gris metálico, sin detalles',
            'Auto rojo con pintura opaca',
            'Auto dorado con rayón leve en el capó',
            'Sedán gris oscuro, abolladura trasera leve',
            'Auto negro mate, interior deportivo',
            'Auto celeste con techo quemado',
            'Sedán blanco, sin retrovisor derecho',
            'Auto amarillo, detalles negros',
            'Auto azul eléctrico, rayón en lateral izquierdo',
            'Auto gris con defensa trasera rayada',
            'Auto naranja, luces traseras rotas',
            'Sedán negro, sin placa delantera',
            'Auto blanco, desgaste en llantas',
            'Sedán plata, sin parabrisas trasero',
            'Auto azul marino, polarizado al 100%',
            'Auto gris claro, sin rayones',
            'Auto rojo cereza con detalles cromados',
            'Auto beige con defensa reparada',
            'Sedán verde oliva, sin problemas',
            'Auto gris oscuro, interior tapizado negro',
            'Auto rojo fuego, rayón lateral trasero',
            'Auto negro con antena rota',
            'Sedán gris acero, luneta trasera trizada',
            'Auto blanco nieve, impecable',
            'Auto plata con rayones leves',
            'Sedán azul oscuro, detalles de pintura',
            'Auto gris con manchas en parachoques',
            'Auto vino con polarizado bajo',
            'Auto marfil con rayón en puerta',
            'Auto negro brillante, luces LED',
            'Sedán rojo con manchas de óxido',
            'Auto azul petróleo, sin detalles visibles',
            'Auto lila con rayón trasero'];
        descripciones_camioneta TEXT[] := ARRAY['Camioneta blanca, rayón en la puerta trasera',
            'Camioneta gris con llantas todo terreno',
            'Camioneta negra, sin retrovisor derecho',
            'Camioneta azul, rayón en defensa delantera',
            'Camioneta roja, sin tapa en batea',
            'Camioneta gris claro con abolladura lateral',
            'Camioneta negra mate, sin detalles',
            'Camioneta blanca con barra antivuelco',
            'Camioneta azul marino, faro roto',
            'Camioneta roja brillante con rayones leves',
            'Camioneta verde oliva, en perfecto estado',
            'Camioneta beige, pintura opaca',
            'Camioneta vino, sin parachoques trasero',
            'Camioneta celeste, sin rayones visibles',
            'Camioneta blanca con tapa rígida',
            'Camioneta gris con manijas oxidadas',
            'Camioneta negra, leve rayón lateral',
            'Camioneta azul con abolladura trasera',
            'Camioneta rojo oscuro, interior de cuero',
            'Camioneta gris metálico con rayón frontal',
            'Camioneta blanca, neumáticos desgastados',
            'Camioneta verde, rayón en la batea',
            'Camioneta gris grafito con accesorios 4x4',
            'Camioneta azul eléctrico con capota de lona',
            'Camioneta negra con defensa reforzada',
            'Camioneta blanca sin rayones, polarizada',
            'Camioneta beige, leve abolladura en puerta',
            'Camioneta gris, desgaste en pintura del techo',
            'Camioneta celeste con ganchos de remolque',
            'Camioneta negra brillante, sin observaciones',
            'Camioneta rojo fuego con estribos metálicos',
            'Camioneta blanco perla con antena rota',
            'Camioneta gris oscuro, sin placa trasera',
            'Camioneta verde militar con lona trasera',
            'Camioneta marrón, rayón en faro trasero',
            'Camioneta blanca, espejos nuevos',
            'Camioneta negra, rayón en defensa lateral',
            'Camioneta gris claro con pintura deteriorada',
            'Camioneta azul con rayón en capó',
            'Camioneta gris con logos descoloridos'];

        i_moto INT := 1;
        i_auto INT := 1;
        i_camioneta INT := 1;
    BEGIN
        FOR r IN SELECT codigo_sticker, id_tipo_vehiculo FROM core.vehiculo LOOP
                IF r.id_tipo_vehiculo = 1 THEN  -- Moto
                    UPDATE core.vehiculo
                    SET descripcion = descripciones_moto[i_moto]
                    WHERE codigo_sticker = r.codigo_sticker;
                    i_moto := (i_moto % array_length(descripciones_moto, 1)) + 1;

                ELSIF r.id_tipo_vehiculo = 2 THEN  -- Auto
                    UPDATE core.vehiculo
                    SET descripcion = descripciones_auto[i_auto]
                    WHERE codigo_sticker = r.codigo_sticker;
                    i_auto := (i_auto % array_length(descripciones_auto, 1)) + 1;

                ELSIF r.id_tipo_vehiculo = 3 THEN  -- Camioneta
                    UPDATE core.vehiculo
                    SET descripcion = descripciones_camioneta[i_camioneta]
                    WHERE codigo_sticker = r.codigo_sticker;
                    i_camioneta := (i_camioneta % array_length(descripciones_camioneta, 1)) + 1;
                END IF;
            END LOOP;
    END $$;

CREATE TABLE core.comentarios_registro (
                                           id_comentario     SERIAL PRIMARY KEY,
                                           id_registro       INTEGER NOT NULL
                                               REFERENCES core.registro_parqueo(id_registro)
                                                   ON DELETE CASCADE,
                                           comentario        VARCHAR(255) NOT NULL,
                                           fecha_comentario  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                           usuario_creacion        VARCHAR(100) DEFAULT CURRENT_USER
);

