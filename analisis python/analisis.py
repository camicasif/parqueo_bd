# === Importación de librerías ===
from sqlalchemy import create_engine  # Para conectar Python con una base de datos SQL
import pandas as pd                   
import matplotlib.pyplot as plt
import seaborn as sns


# === Conexión a la base de datos PostgreSQL ===
usuario = 'parqueo_admin'
contrasena = '123456'
host = 'localhost'
puerto = '5432'
base_de_datos = 'parqueo'

# Creamos una "engine" para hacer consultas SQL desde Python
engine = create_engine(f'postgresql+psycopg2://{usuario}:{contrasena}@{host}:{puerto}/{base_de_datos}')

# === Consulta inicial: obtenemos registros de entradas/salidas del parqueo ===
df = pd.read_sql("SELECT * FROM core.registro_parqueo LIMIT 1000", engine)
print(df.head())

# === 1. Uso diario de espacios ===
# Convertimos la fecha de ingreso a solo fecha (sin hora) y contamos cuántos ingresos hubo por día
df['fecha'] = pd.to_datetime(df['fecha_hora_ingreso']).dt.date
conteo_diario = df.groupby('fecha').size()

# === 2. Uso de espacios por sección ===
# Consulta SQL para contar los registros de parqueo por cada sección
df_secciones = pd.read_sql("""
    SELECT sp.nombre_seccion, COUNT(*) as total_usos
    FROM core.registro_parqueo rp
    JOIN core.espacio_parqueo ep ON rp.id_espacio_parqueo = ep.id_espacio_parqueo
    JOIN core.seccion_parqueo sp ON ep.id_seccion = sp.id_seccion
    GROUP BY sp.nombre_seccion
""", engine)

# Gráfico: muestra cuántas veces se usó cada sección del parqueo
sns.barplot(data=df_secciones, x='nombre_seccion', y='total_usos', hue='nombre_seccion', palette='magma', legend=False)
plt.title('Uso de espacios por sección')
plt.ylabel('Total de usos')
plt.xlabel('Sección')
plt.xticks(rotation=30)
plt.tight_layout()
plt.show()

# === 3. Consolidado de uso diario ===
# Consulta SQL que agrupa por día y calcula:
# - Total ingresos
# - Total salidas
# - Horas ocupadas
# - Porcentaje de ocupación del parqueo
query_uso_diario = """
SELECT
    DATE(rp.fecha_hora_ingreso) AS fecha,
    COUNT(rp.id_registro) AS total_ingresos,
    COUNT(CASE WHEN rp.fecha_hora_salida IS NOT NULL THEN 1 END) AS total_salidas,
    SUM(EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso))/3600) AS total_horas_ocupadas,
    SUM(EXTRACT(EPOCH FROM (rp.fecha_hora_salida - rp.fecha_hora_ingreso))/3600) /
    (24 * (SELECT COUNT(*) FROM core.espacio_parqueo)) * 100 AS pct_ocupacion_general
FROM core.registro_parqueo rp
WHERE rp.eliminado = false
GROUP BY fecha
ORDER BY fecha;
"""
df_uso_diario = pd.read_sql(query_uso_diario, engine)

# Gráfico: ingresos y salidas por día
plt.figure(figsize=(12, 6))
plt.plot(df_uso_diario['fecha'], df_uso_diario['total_ingresos'], label='Ingresos')
plt.plot(df_uso_diario['fecha'], df_uso_diario['total_salidas'], label='Salidas')
plt.title('Ingresos y Salidas Diarios')
plt.xlabel('Fecha')
plt.ylabel('Cantidad')
plt.legend()
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

# Gráfico: porcentaje de ocupación diaria del parqueo
plt.figure(figsize=(12, 4))
plt.fill_between(df_uso_diario['fecha'], 0, df_uso_diario['pct_ocupacion_general'], alpha=0.4)
plt.plot(df_uso_diario['fecha'], df_uso_diario['pct_ocupacion_general'], label='Ocupación General (%)')
plt.title('Porcentaje de Ocupación General Diario')
plt.ylabel('% Ocupación')
plt.xlabel('Fecha')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

# === 4. Distribución del tiempo de permanencia en horas ===
# Calculamos la diferencia entre salida e ingreso para saber cuánto tiempo estuvo cada vehículo
df['fecha_hora_ingreso'] = pd.to_datetime(df['fecha_hora_ingreso'])
df['fecha_hora_salida'] = pd.to_datetime(df['fecha_hora_salida'])
df['tiempo_permanencia_horas'] = (df['fecha_hora_salida'] - df['fecha_hora_ingreso']).dt.total_seconds() / 3600

# Histograma del tiempo de permanencia
plt.figure(figsize=(10,6))
sns.histplot(df['tiempo_permanencia_horas'].dropna(), bins=30, kde=True, color='steelblue')
plt.title('Distribución del tiempo de permanencia (horas)')
plt.xlabel('Horas')
plt.ylabel('Frecuencia')
plt.tight_layout()
plt.show()

# === 5. Días de la semana con mayor ingreso ===
# Se extrae el nombre del día de la semana de cada registro
df['dia_semana'] = df['fecha_hora_ingreso'].dt.day_name()

# Se cuenta cuántas veces aparece cada día usando value_counts()
# y luego se reordena con reindex() para que siempre aparezcan en orden (lunes a domingo)
conteo_dia_semana = df['dia_semana'].value_counts().reindex([
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
])

# Gráfico: ingresos por día de la semana
plt.figure(figsize=(10,5))
sns.barplot(x=conteo_dia_semana.index, y=conteo_dia_semana.values, palette='pastel')
plt.title('Cantidad de ingresos por día de la semana')
plt.xlabel('Día de la semana')
plt.ylabel('Cantidad de ingresos')
plt.tight_layout()
plt.show()

# === 6. Horas pico de ingreso ===
# Se extrae la hora del ingreso para saber a qué hora del día llegan más vehículos
df['hora_ingreso'] = df['fecha_hora_ingreso'].dt.hour
conteo_hora = df['hora_ingreso'].value_counts().sort_index()  # Se ordenan por hora (0 a 23)

# Gráfico: ingresos por hora del día
plt.figure(figsize=(10,5))
sns.lineplot(x=conteo_hora.index, y=conteo_hora.values, marker='o', color='coral')
plt.title('Cantidad de ingresos por hora del día')
plt.xlabel('Hora')
plt.ylabel('Cantidad de ingresos')
plt.xticks(range(0,24))
plt.tight_layout()
plt.show()

# === 7. Vehículos que más ingresan (Top 10 placas) ===
top_placas = df['placa'].value_counts().head(10)  # Se cuentan las placas y se extraen las 10 más frecuentes

# Gráfico: top 10 placas que más ingresan al parqueo
plt.figure(figsize=(12,5))
sns.barplot(x=top_placas.index, y=top_placas.values, palette='cubehelix')
plt.title('Top 10 vehículos con más ingresos')
plt.xlabel('Placa')
plt.ylabel('Número de ingresos')
plt.tight_layout()
plt.show()

# === 8. Cantidad de usuarios por tipo ===
# Consulta SQL que junta la tabla de usuarios con su tipo y los cuenta
query_tipos_usuarios = """
SELECT tu.nombre_tipo_usuario, COUNT(*) AS cantidad
FROM core.usuario u
JOIN config.tipo_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
GROUP BY tu.nombre_tipo_usuario
ORDER BY cantidad DESC;
"""

df_tipos_usuarios = pd.read_sql(query_tipos_usuarios, engine)

# Gráfico: usuarios agrupados por tipo (estudiante, docente, externo, etc.)
plt.figure(figsize=(10,6))
sns.barplot(data=df_tipos_usuarios, x='nombre_tipo_usuario', y='cantidad', palette='viridis')
plt.title('Cantidad de Usuarios por Tipo')
plt.xlabel('Tipo de Usuario')
plt.ylabel('Cantidad')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

