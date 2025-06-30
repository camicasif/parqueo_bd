
from sqlalchemy import create_engine
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


usuario = 'parqueo_admin'
contrasena = '123456'
host = 'localhost'
puerto = '5432'
base_de_datos = 'parqueo'

engine = create_engine(f'postgresql+psycopg2://{usuario}:{contrasena}@{host}:{puerto}/{base_de_datos}')

#Consulta inicial: solo registros del año 2024 
df = pd.read_sql("""
    SELECT * 
    FROM core.registro_parqueo 
    WHERE EXTRACT(YEAR FROM fecha_hora_ingreso) = 2024
""", engine)
print(df.head())

# 1. Uso diario de espacios 
df['fecha'] = pd.to_datetime(df['fecha_hora_ingreso']).dt.date
conteo_diario = df.groupby('fecha').size()

# 2. Uso de espacios por sección (sin filtro de año, ya que está agregado arriba)
df_secciones = pd.read_sql("""
    SELECT sp.nombre_seccion, COUNT(*) as total_usos
    FROM core.registro_parqueo rp
    JOIN core.espacio_parqueo ep ON rp.id_espacio_parqueo = ep.id_espacio_parqueo
    JOIN core.seccion_parqueo sp ON ep.id_seccion = sp.id_seccion
    WHERE EXTRACT(YEAR FROM rp.fecha_hora_ingreso) = 2024
    GROUP BY sp.nombre_seccion
""", engine)

sns.barplot(data=df_secciones, x='nombre_seccion', y='total_usos', hue='nombre_seccion', palette='magma', legend=False)
plt.title('Uso de espacios por sección (2024)')
plt.ylabel('Total de usos')
plt.xlabel('Sección')
plt.xticks(rotation=30)
plt.tight_layout()
plt.show()

#3. Consolidado de uso diario (sólo 2024)
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
  AND EXTRACT(YEAR FROM rp.fecha_hora_ingreso) = 2024
GROUP BY fecha
ORDER BY fecha;
"""
df_uso_diario = pd.read_sql(query_uso_diario, engine)

plt.figure(figsize=(12, 6))
plt.plot(df_uso_diario['fecha'], df_uso_diario['total_ingresos'], label='Ingresos')
plt.plot(df_uso_diario['fecha'], df_uso_diario['total_salidas'], label='Salidas')
plt.title('Ingresos y Salidas Diarios (2024)')
plt.xlabel('Fecha')
plt.ylabel('Cantidad')
plt.legend()
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

plt.figure(figsize=(12, 4))
plt.fill_between(df_uso_diario['fecha'], 0, df_uso_diario['pct_ocupacion_general'], alpha=0.4)
plt.plot(df_uso_diario['fecha'], df_uso_diario['pct_ocupacion_general'], label='Ocupación General (%)')
plt.title('Porcentaje de Ocupación General Diario (2024)')
plt.ylabel('% Ocupación')
plt.xlabel('Fecha')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

# 4. Distribución del tiempo de permanencia (2024) 
df['fecha_hora_ingreso'] = pd.to_datetime(df['fecha_hora_ingreso'])
df['fecha_hora_salida'] = pd.to_datetime(df['fecha_hora_salida'])
df['tiempo_permanencia_horas'] = (df['fecha_hora_salida'] - df['fecha_hora_ingreso']).dt.total_seconds() / 3600

plt.figure(figsize=(10,6))
sns.histplot(df['tiempo_permanencia_horas'].dropna(), bins=30, kde=True, color='steelblue')
plt.title('Distribución del tiempo de permanencia (horas) - 2024')
plt.xlabel('Horas')
plt.ylabel('Frecuencia')
plt.tight_layout()
plt.show()

# 5. Días de la semana con mayor ingreso (2024) 
df['dia_semana'] = df['fecha_hora_ingreso'].dt.day_name()
conteo_dia_semana = df['dia_semana'].value_counts().reindex([
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
])

plt.figure(figsize=(10,5))
sns.barplot(x=conteo_dia_semana.index, y=conteo_dia_semana.values, palette='pastel')
plt.title('Cantidad de ingresos por día de la semana (2024)')
plt.xlabel('Día de la semana')
plt.ylabel('Cantidad de ingresos')
plt.tight_layout()
plt.show()

# 6. Horas pico de ingreso (2024)
df['hora_ingreso'] = df['fecha_hora_ingreso'].dt.hour
conteo_hora = df['hora_ingreso'].value_counts().sort_index()

plt.figure(figsize=(10,5))
sns.lineplot(x=conteo_hora.index, y=conteo_hora.values, marker='o', color='coral')
plt.title('Cantidad de ingresos por hora del día (2024)')
plt.xlabel('Hora')
plt.ylabel('Cantidad de ingresos')
plt.xticks(range(0,24))
plt.tight_layout()
plt.show()

# 8. Cantidad de usuarios por tipo (no requiere filtro de año)
query_tipos_usuarios = """
SELECT tu.nombre_tipo_usuario, COUNT(*) AS cantidad
FROM core.usuario u
JOIN config.tipo_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
GROUP BY tu.nombre_tipo_usuario
ORDER BY cantidad DESC;
"""
df_tipos_usuarios = pd.read_sql(query_tipos_usuarios, engine)

plt.figure(figsize=(10,6))
sns.barplot(data=df_tipos_usuarios, x='nombre_tipo_usuario', y='cantidad', palette='viridis')
plt.title('Cantidad de Usuarios por Tipo')
plt.xlabel('Tipo de Usuario')
plt.ylabel('Cantidad')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()
