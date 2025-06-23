SELECT
    n.nspname AS esquema,
    c.relname AS tabla,
    t.tgname AS trigger_nombre,
    p.proname AS funcion_asociada,
    t.tgenabled AS trigger_habilitado,
    t.tgtype AS tipo_trigger
FROM pg_trigger t
         JOIN pg_class c ON c.oid = t.tgrelid
         JOIN pg_namespace n ON n.oid = c.relnamespace
         JOIN pg_proc p ON p.oid = t.tgfoid
WHERE NOT t.tgisinternal  -- solo triggers definidos por el usuario, no internos
ORDER BY n.nspname, c.relname, t.tgname;
