SELECT core.registrar_comentario_registro(
               p_id_registro := 1,
               p_comentario := 'Primera observación del registro.'
       );

SELECT * FROM core.leer_comentarios_registro(1);

SELECT core.editar_comentario_registro(
               p_id_comentario := 1,
               p_nuevo_comentario := 'Comentario actualizado del registro.'
       );

SELECT * FROM core.leer_comentarios_registro(1);

SELECT core.eliminar_comentario_registro(
               p_id_comentario := 1
       );

SELECT * FROM core.leer_comentarios_registro(1); -- Debe retornar vacío

