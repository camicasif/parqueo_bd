-- Rol para la aplicación
CREATE ROLE app_user LOGIN PASSWORD 'tu_password_seguro';
GRANT CONNECT ON DATABASE parqueo TO app_user;

-- Rol para administrar configuración
CREATE ROLE config_admin LOGIN PASSWORD 'tu_password_seguro';
GRANT CONNECT ON DATABASE parqueo TO config_admin;

-- Rol solo lectura para logs
CREATE ROLE log_reader LOGIN PASSWORD 'tu_password_seguro';
GRANT CONNECT ON DATABASE parqueo TO log_reader;

-- Rol editor para core
CREATE ROLE core_editor LOGIN PASSWORD 'tu_password_seguro';
GRANT CONNECT ON DATABASE parqueo TO core_editor;



-- Permisos para esquema core
GRANT USAGE ON SCHEMA core TO app_user, core_editor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA core TO app_user, core_editor;
-- core_editor NO tiene DELETE

-- Permisos para esquema config
GRANT USAGE ON SCHEMA config TO config_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA config TO config_admin;
-- NO TRUNCATE para nadie

-- Permisos para esquema log
GRANT USAGE ON SCHEMA log TO log_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA log TO log_reader;