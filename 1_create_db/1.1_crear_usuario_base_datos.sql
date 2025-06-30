/******************************************************************************
   NAME:       1.1_crear_usuario_base_datos.sql
   PURPOSE:    Script para crear un usuario de base de datos y asignar permisos completos (sin ser superusuario)

   REVISIONS:
   Ver        Date          Description
   ---------  ----------    ------------------------------------
   1.0        20/06/2025    1. Creación de rol, base de datos y privilegios
******************************************************************************/

-- Crear el usuario con login, sin privilegios de superusuario ni replicación
CREATE USER parqueo_admin2 WITH
LOGIN
NOSUPERUSER      -- No es superusuario
NOCREATEDB       -- No puede crear bases de datos
INHERIT
NOREPLICATION;

ALTER ROLE parqueo_admin2 CREATEROLE;

-- Asignar una contraseña segura
ALTER USER parqueo_admin2 WITH PASSWORD '123456';

-- Crear la base de datos con el usuario como dueño
CREATE DATABASE parqueo2
    WITH OWNER = parqueo_admin2
    ENCODING = 'UTF8'
    CONNECTION LIMIT = 100;

-- Otorgar todos los privilegios sobre la base de datos
GRANT ALL PRIVILEGES ON DATABASE parqueo2 TO parqueo_admin2;
