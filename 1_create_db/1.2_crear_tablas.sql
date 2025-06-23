CREATE SCHEMA config;
CREATE SCHEMA core;
CREATE SCHEMA log;

CREATE TABLE config.tipo_usuario
(
    id_tipo_usuario     SERIAL PRIMARY KEY,
    nombre_tipo_usuario VARCHAR(50) NOT NULL
);

CREATE TABLE config.tipo_vehiculo
(
    id_tipo_vehiculo     SERIAL PRIMARY KEY,
    nombre_tipo_vehiculo VARCHAR(50) NOT NULL
);

CREATE TABLE config.estado_espacio_parqueo
(
    id_estado     SERIAL PRIMARY KEY,
    nombre_estado VARCHAR(20) NOT NULL CHECK (nombre_estado IN ('Disponible', 'Reservado', 'Ocupado'))
);

CREATE TABLE config.tipo_vehiculo_seccion
(
    id_tipo_vehiculo INTEGER NOT NULL REFERENCES config.tipo_vehiculo,
    id_seccion       INTEGER NOT NULL, -- Se referencia más adelante desde core.seccion_parqueo
    PRIMARY KEY (id_tipo_vehiculo, id_seccion)
);

CREATE TABLE core.usuario
(
    id_usuario           SERIAL PRIMARY KEY,
    codigo_universitario INTEGER,
    telefono_contacto    VARCHAR(20),
    contrasena           VARCHAR(100),
    nombre               VARCHAR(50),
    apellidos            VARCHAR(100),
    id_tipo_usuario      INTEGER REFERENCES config.tipo_usuario
);

CREATE TABLE core.vehiculo
(
    codigo_sticker   SERIAL PRIMARY KEY,
    placa            VARCHAR(7) UNIQUE NOT NULL,
    id_tipo_vehiculo INTEGER REFERENCES config.tipo_vehiculo,
    id_usuario       INTEGER REFERENCES core.usuario
);

CREATE TABLE core.seccion_parqueo
(
    id_seccion      SERIAL PRIMARY KEY,
    nombre_seccion  VARCHAR(50),
    id_tipo_usuario INTEGER REFERENCES config.tipo_usuario
);

-- Agregamos la FK faltante para tipo_vehiculo_seccion
ALTER TABLE config.tipo_vehiculo_seccion
    ADD CONSTRAINT fk_tipo_vehiculo_seccion
        FOREIGN KEY (id_seccion) REFERENCES core.seccion_parqueo;

CREATE TABLE core.espacio_parqueo
(
    id_espacio_parqueo SERIAL PRIMARY KEY,
    id_estado          INTEGER REFERENCES config.estado_espacio_parqueo,
    id_seccion         INTEGER REFERENCES core.seccion_parqueo
);

CREATE TABLE core.registro_parqueo
(
    id_registro        SERIAL PRIMARY KEY,
    fecha_hora_ingreso TIMESTAMP NOT NULL,
    fecha_hora_salida  TIMESTAMP,
    placa              VARCHAR(7) REFERENCES core.vehiculo (placa),
    id_espacio_parqueo INTEGER REFERENCES core.espacio_parqueo
);

CREATE TABLE core.reserva_espacio (
                                      id_reserva SERIAL PRIMARY KEY,
                                      id_espacio INT NOT NULL REFERENCES core.espacio_parqueo(id_espacio_parqueo),
                                      id_usuario INT NOT NULL REFERENCES core.usuario(id_usuario),
                                      fecha_inicio TIMESTAMP NOT NULL,
                                      fecha_fin TIMESTAMP NOT NULL,
                                      estado VARCHAR(20) DEFAULT 'pendiente',  -- Ej: pendiente, confirmada, cancelada
                                      fecha_creacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE log.log_cambios (
                                 id_log         SERIAL PRIMARY KEY,
                                 tabla          VARCHAR(100) NOT NULL,
                                 id_registro    VARCHAR(100),
                                 accion         VARCHAR(10) NOT NULL CHECK (accion IN ('INSERT', 'UPDATE', 'DELETE')),
                                 datos_antes    JSONB,
                                 datos_despues  JSONB,
                                 fecha_evento   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                 usuario_bd     VARCHAR(100) DEFAULT CURRENT_USER
);

CREATE TABLE log.log_fallos_parqueo (
                                        id            SERIAL PRIMARY KEY,
                                        id_usuario    INTEGER,
                                        placa         VARCHAR(7),
                                        fecha         DATE,
                                        hora_ingreso  TIME,
                                        hora_salida   TIME,
                                        motivo        TEXT,
                                        fecha_evento  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
