Config = {}

-- Permisos
Config.AdminGroup = 'admin'

-- Configuración de Territorios
Config.ZoneHeight = 50.0

Config.Gangs = {
    ['ballas'] = {
        name = 'Ballas',
        color = {r = 145, g = 0, b = 200, a = 120},
        blipColor = 83  -- Morado
    },
    ['vagos'] = {
        name = 'Vagos',
        color = {r = 255, g = 215, b = 0, a = 120},
        blipColor = 5  -- Amarillo
    },
    ['families'] = {
        name = 'Families',
        color = {r = 0, g = 200, b = 0, a = 120},
        blipColor = 2  -- Verde
    },
    ['marabunta'] = {
        name = 'Marabunta',
        color = {r = 0, g = 180, b = 255, a = 120},
        blipColor = 3  -- Azul claro
    },
    ['cartel'] = {
        name = 'Cartel',
        color = {r = 0, g = 40, b = 80, a = 120},
        blipColor = 29  -- Azul oscuro
    },
    ['triads'] = {
        name = 'Triads',
        color = {r = 200, g = 0, b = 0, a = 120},
        blipColor = 1  -- Rojo
    }
}

-- Sistema de Recompensas
Config.CaptureReward = 10000 -- Dinero negro que gana la banda
Config.GangAccounts = {
    ['ballas'] = 'gang_ballas',
    ['vagos'] = 'gang_vagos',
    ['families'] = 'gang_families',
    ['marabunta'] = 'gang_marabunta',
    ['cartel'] = 'gang_cartel',
    ['triads'] = 'gang_triads'
}

-- Sistema de XP
Config.CaptureXP = 100 -- XP que gana cada miembro de la banda al capturar
Config.UseGangXPSystem = true -- Activar/desactivar sistema de XP

-- Configuración de Police
Config.PoliceJob = 'police'
Config.PoliceRanksCanView = {20, 21, 22, 23, 24, 25} -- Rango mínimo para ver territorios

-- Configuración de Captura
Config.CaptureTime = 60
Config.CaptureCheckInterval = 2000 -- ms
Config.PointsPerPlayer = 1
Config.CooldownTime = 60

-- Tecla para ocultar UI (puedes cambiar el código)
-- Lista de códigos: https://docs.fivem.net/docs/game-references/controls/
Config.HideUIKey = 'F6' -- Texto que se muestra
Config.HideUIKeyCode = 167 -- Código de la tecla X (cambiar este para cambiar la tecla)

-- Colores de zonas
Config.FreeZoneColor = {r = 255, g = 255, b = 255, a = 100}
Config.DisputeBlinkSpeed = 500

-- Comandos
Config.CaptureCommand = 'capturar'
Config.AttackCommand = 'atacar'

-- Blips disponibles para territorios
Config.AvailableBlips = {
    {id = 1, name = 'Sin Blip', sprite = nil},
    {id = 2, name = 'Arma', sprite = 110},
    {id = 3, name = 'Cuchillo', sprite = 432},
    {id = 4, name = 'Puño', sprite = 311},
    {id = 5, name = 'Granada', sprite = 156},
    {id = 6, name = 'Rifle', sprite = 110},
    {id = 7, name = 'Pistola', sprite = 150},
    {id = 8, name = 'Calavera', sprite = 84},
    {id = 9, name = 'Alerta', sprite = 161},
    {id = 10, name = 'Corona', sprite = 478}
}