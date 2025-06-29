ALTER TABLE core.comentarios_registro
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;

CREATE OR REPLACE FUNCTION core.registrar_comentario_registro(
    p_id_registro INTEGER,
    p_comentario VARCHAR
) RETURNS VOID AS $$
BEGIN
    INSERT INTO core.comentarios_registro (
        id_registro,
        comentario,
        fecha_comentario,
        usuario_creacion
    )
    VALUES (
               p_id_registro,
               p_comentario,
               CURRENT_TIMESTAMP,
               CURRENT_USER
           );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.leer_comentarios_registro(
    p_id_registro INTEGER
) RETURNS TABLE (
                    id_comentario INTEGER,
                    comentario VARCHAR,
                    fecha_comentario TIMESTAMP,
                    usuario_creacion VARCHAR
                ) AS $$
BEGIN
    RETURN QUERY
        SELECT
            id_comentario,
            comentario,
            fecha_comentario,
            usuario_creacion
        FROM core.comentarios_registro
        WHERE id_registro = p_id_registro
        AND eliminado = false
        ORDER BY fecha_comentario DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.editar_comentario_registro(
    p_id_comentario INTEGER,
    p_nuevo_comentario VARCHAR
) RETURNS VOID AS $$
BEGIN
    UPDATE core.comentarios_registro
    SET comentario = p_nuevo_comentario,
        fecha_comentario = CURRENT_TIMESTAMP,
        usuario_creacion = CURRENT_USER
    WHERE id_comentario = p_id_comentario
      AND eliminado = FALSE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.eliminar_comentario_registro(
    p_id_comentario INTEGER
) RETURNS VOID AS $$
BEGIN
    UPDATE core.comentarios_registro
    SET eliminado = TRUE
    WHERE id_comentario = p_id_comentario
      AND eliminado = FALSE;
END;
$$ LANGUAGE plpgsql;

