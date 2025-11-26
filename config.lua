Config = {}

-- Configuración General
Config.AdminGroup = 'admin' -- Grupo que puede usar el comando /territorys

-- Zona de Edición
Config.ZoneEditor = {
    DefaultSize = 50.0, -- Tamaño inicial del territorio
    MinSize = 10.0, -- Tamaño mínimo
    MaxSize = 500.0, -- Tamaño máximo
    MoveSpeed = {
        Normal = 1.0,
        Fast = 3.0 -- Con SHIFT presionado
    },
    SizeSpeed = 2.0,
    RotationSpeed = 2.0,
    ZoneHeight = 50.0, -- Altura de la zona
    ZoneColor = {r = 255, g = 0, b = 0, a = 100} -- Color rojo semitransparente
}

-- Colores para los territorios
Config.TerritoryColors = {
    ['ballas'] = {r = 128, g = 0, b = 128, a = 100}, -- Morado
    ['families'] = {r = 0, g = 255, b = 0, a = 100}, -- Verde
    ['vagos'] = {r = 255, g = 255, b = 0, a = 100}, -- Amarillo
    ['marabunta'] = {r = 0, g = 191, b = 255, a = 100}, -- Azul claro
    ['bloods'] = {r = 255, g = 0, b = 0, a = 100}, -- Rojo
    ['default'] = {r = 200, g = 200, b = 200, a = 100} -- Gris
}

-- Blip para visualización
Config.EditorBlip = {
    sprite = 1,
    color = 1,
    alpha = 180
}

-- Sistema de Captura
Config.CaptureSystem = {
    PointsPerSecond = 1, -- Puntos que gana cada jugador por segundo en la zona
    CaptureTime = 300, -- 5 minutos (300 segundos) tiempo máximo de captura
    PointsToCapture = 100, -- Puntos necesarios para capturar al 100%
    CooldownTime = 7200, -- 2 horas (7200 segundos) de cooldown después de capturar
    RespawnTime = 30, -- 30 segundos para volver a contar después de morir
    AttackCommand = '/atacar', -- Comando para atacar un territorio en cooldown
    UIToggleKey = 'F6' -- Tecla para ocultar/mostrar UI
}

-- Jobs de bandas que pueden capturar
Config.GangJobs = {
    ['ballas'] = {
        label = 'Ballas',
        color = {r = 128, g = 0, b = 128}, -- Morado
        blipColor = 27
    },
    ['families'] = {
        label = 'Families',
        color = {r = 0, g = 255, b = 0}, -- Verde
        blipColor = 2
    },
    ['vagos'] = {
        label = 'Vagos',
        color = {r = 255, g = 255, b = 0}, -- Amarillo
        blipColor = 5
    },
    ['marabunta'] = {
        label = 'Marabunta',
        color = {r = 0, g = 191, b = 255}, -- Azul claro
        blipColor = 3
    },
    ['bloods'] = {
        label = 'Bloods',
        color = {r = 255, g = 0, b = 0}, -- Rojo
        blipColor = 1
    }
}

-- Policía (pueden ver pero no capturar)
Config.PoliceJob = {
    job = 'police',
    minGrade = 20, -- Rango mínimo para ver territorios
    canCapture = true
}

-- Colores de estado
Config.StateColors = {
    free = 0, -- Blanco
    contested = 1, -- Rojo (parpadeante)
    captured = nil -- Se usa el color de la banda
}