Config = {}

-- Configuración General
Config.Framework = 'esx'
Config.Locale = 'es'

-- Permisos
Config.AdminGroup = 'admin'

-- Configuración de Territorios
Config.DefaultZoneColor = {r = 255, g = 0, b = 0, a = 100}
Config.ZoneHeight = 50.0 -- Altura del área de captura

Config.Gangs = {
    ['ballas'] = {
        name = 'Ballas',
        color = {r = 145, g = 0, b = 200, a = 120} -- Morado
    },
    ['vagos'] = {
        name = 'Vagos',
        color = {r = 255, g = 215, b = 0, a = 120} -- Amarillo oro
    },
    ['families'] = {
        name = 'Families',
        color = {r = 0, g = 200, b = 0, a = 120} -- Verde gang
    },
    ['marabunta'] = {
        name = 'Marabunta',
        color = {r = 0, g = 180, b = 255, a = 120} -- Azul celeste
    },
    ['cartel'] = {
        name = 'Cartel',
        color = {r = 0, g = 40, b = 80, a = 120} -- Azul oscuro (estilo narco)
    },
    ['triad'] = {
        name = 'Triad',
        color = {r = 200, g = 0, b = 0, a = 120} -- Rojo intenso
    }
}

-- Configuración de Captura
Config.CaptureTime = 20000 -- 20 segundos para capturar un punto
Config.TimeBetweenPoints = 60 -- 1 minuto entre capturas de puntos
Config.PointsToCapture = 3 -- Puntos necesarios para conquistar
Config.TimeBetweenConquers = 7200 -- 2 horas de cooldown (en segundos)
Config.CaptureReward = 50000 -- Dinero que gana la banda al capturar

-- Textos
Config.Locale = {
    ['menu_title'] = 'TERRITORIOS',
    ['create_territory'] = 'Crear Nuevo Territorio',
    ['territory_name'] = 'Nombre del Territorio',
    ['territory_name_desc'] = 'Ingresa el nombre para el nuevo territorio',
    ['edit_zone'] = 'Editar Zona',
    ['delete_territory'] = 'Eliminar',
    ['confirm_delete'] = 'Confirmar Eliminacion',
    ['confirm_delete_desc'] = 'Estas seguro de eliminar este territorio?',
    ['territory_created'] = 'Territorio creado exitosamente',
    ['territory_deleted'] = 'Territorio eliminado exitosamente',
    ['zone_saved'] = 'Zona guardada exitosamente',
    ['no_territories'] = 'No hay territorios creados',
    ['no_permission'] = 'No tienes permisos para usar este comando',
    ['zone_editor_title'] = 'EDITOR DE ZONA',
    ['zone_editor_controls'] = 'Move: 8, 4, 5, 6 | Size: N, M | Rotate: 7, 9 | Speed: LSHIFT | Confirm: ENTER | Cancel: ESC',
}

-- Configuración de Police
Config.PoliceJob = 'police'
Config.PoliceRanksCanView = {
    'boss',
    'lieutenant',
    'sergeant'
}

-- Configuración de Captura
Config.CaptureTime = 60 -- 1 minuto (en segundos) para capturar
Config.CaptureCheckInterval = 2000 -- Cada 2 segundos actualizar el progreso
Config.PointsPerPlayer = 1 -- Puntos que suma cada jugador por intervalo
Config.CooldownTime = 7200 -- 2 horas en segundos
Config.HideUIKey = 'X' -- Tecla para ocultar UI

-- Colores de zonas
Config.FreeZoneColor = {r = 255, g = 255, b = 255, a = 100} -- Blanco
Config.DisputeBlinkSpeed = 500 -- Velocidad de parpadeo en ms

-- Comandos
Config.CaptureCommand = 'capturar'
Config.AttackCommand = 'atacar'

-- Textos adicionales
Config.Locale['police_cant_capture'] = 'La policia no puede capturar territorios'
Config.Locale['not_gang_member'] = 'No eres miembro de una banda'
Config.Locale['territory_free'] = 'LIBRE'
Config.Locale['territory_cooldown'] = 'EN COOLDOWN'
Config.Locale['territory_available'] = 'DISPONIBLE'
Config.Locale['conquest_in_progress'] = 'CONQUISTA EN PROGRESO'
Config.Locale['conquering'] = 'CONQUISTANDO'
Config.Locale['controlled_by'] = 'CONTROLADO POR'
Config.Locale['time_remaining'] = 'TIEMPO RESTANTE'
Config.Locale['status'] = 'ESTADO'
Config.Locale['capture_instructions'] = 'Usa /%s para comenzar a capturar este territorio'
Config.Locale['attack_instructions'] = 'Usa /%s para atacar este territorio. TODAS LAS BANDAS SERAN ALERTADAS'
Config.Locale['hide_ui_hint'] = 'Presiona %s para ocultar/mostrar la interfaz'
Config.Locale['territory_under_attack'] = 'El territorio %s esta siendo atacado!'
Config.Locale['free_zone'] = 'Liberar Zona'
Config.Locale['zone_freed'] = 'Zona liberada exitosamente'
Config.Locale['already_in_capture'] = 'Ya hay una captura en progreso en este territorio'
Config.Locale['capture_started'] = 'Captura iniciada! Defiende el territorio!'