@echo off
set PGPASSWORD=123456
psql -U parqueo_admin -d parqueo -c "SELECT core.cambiar_estado_reservas_hoy();"
psql -U parqueo_admin -d parqueo -c "SELECT core.finalizar_reservas_vencidas();"
