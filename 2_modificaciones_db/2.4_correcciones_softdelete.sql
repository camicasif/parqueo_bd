-- Agregar columna 'eliminado' a core.usuario
ALTER TABLE core.usuario
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_usuario_eliminado ON core.usuario(eliminado);

-- Agregar columna 'eliminado' a core.vehiculo
ALTER TABLE core.vehiculo
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_vehiculo_eliminado ON core.vehiculo(eliminado);
-- Eliminar restricción única anterior si existe
ALTER TABLE core.vehiculo DROP CONSTRAINT IF EXISTS vehiculo_placa_key;

-- Crear índice único solo para placas de vehículos no eliminados
CREATE UNIQUE INDEX uq_vehiculo_placa_activa ON core.vehiculo (placa)
    WHERE eliminado = false;


-- Agregar columna 'eliminado' a core.registro_parqueo
ALTER TABLE core.registro_parqueo
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_registro_parqueo_eliminado ON core.registro_parqueo(eliminado);

-- Agregar columna 'eliminado' a core.seccion_parqueo
ALTER TABLE core.seccion_parqueo
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;

-- Agregar columna 'eliminado' a core.espacio_parqueo
ALTER TABLE core.espacio_parqueo
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;


-- Agregar columna 'eliminado' a core.reserva_espacio
ALTER TABLE core.reserva_espacio
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;

-- Agregar columnas a config.tipo_usuario
ALTER TABLE config.tipo_usuario
    ADD COLUMN fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN usuario_creacion VARCHAR(100) DEFAULT CURRENT_USER,
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;

-- Agregar columnas a config.tipo_vehiculo
ALTER TABLE config.tipo_vehiculo
    ADD COLUMN fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN usuario_creacion VARCHAR(100) DEFAULT CURRENT_USER,
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;

-- Agregar columnas a config.tipo_vehiculo_seccion
ALTER TABLE config.tipo_vehiculo_seccion
    ADD COLUMN fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN usuario_creacion VARCHAR(100) DEFAULT CURRENT_USER,
    ADD COLUMN eliminado BOOLEAN DEFAULT FALSE;
