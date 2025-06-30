Listado de funciones.-
        Registrar nuevo usuario
        Actualizar información de un usuario
        Eliminar un usuario por ID
        Listar todos los usuarios por tipo de usuario (estudiante, docente, etc.)
        Validar credenciales de un usuario (login)

        Registrar un nuevo vehículo vinculado a un usuario___
        Actualizar información del vehículo (placa, tipo)
        Eliminar vehículo por placa
        Listar vehículos registrados por un usuario específico
        Verificar si un vehículo ya está registrado por su placa

        Segunda Parte
        Función para saber cuánto tiempo promedio pasa un usuario en el parqueo.
        Función para calcular % de uso de una sección.
        Función para saber si un usuario sobrepasa un límite de horas.
        Bloquear usuario tras 3 intentos fallidos de login.
        Buscar usuario por nombre o apellido.
        Desactivar usuario (soft delete).
        Cambiar tipo de usuario (de estudiante a docente, por ejemplo).
        Listar vehículos por tipo.

Listado de vistas
        4.vista_ingresos_hoy

        5.vista_usuarios_sin_ingresos

        7.vista_porcentaje_ocupacion_diaria_por_seccion

        8.vista_conteo_por_tipo_usuario

        9.vista_vehiculos_estadia_prolongada

        10.vista_ingresos_por_hora_diaria

Listado de logs
        Log de intentos fallidos de login. (JO)
            Desgloce en dos funcioens
                - validar_login
                - registrar_login_fallido_en_log