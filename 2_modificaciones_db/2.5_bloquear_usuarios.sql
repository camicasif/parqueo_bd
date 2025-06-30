ALTER TABLE core.usuario ADD COLUMN bloqueado BOOLEAN DEFAULT FALSE;

CREATE TABLE log.log_intentos_login (
    id_log SERIAL PRIMARY KEY,
    id_usuario INTEGER,
    fecha_intento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    exito BOOLEAN,
    direccion_ip VARCHAR(100),
    motivo TEXT,
    FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario)
);
