ESX = exports["es_extended"]:getSharedObject()

-- Tabla para almacenar territorios en memoria
local territories = {}
local activeCaptureZones = {}
local zoneCooldowns = {}
local deadPlayers = {}

-- Función para cargar territorios desde la base de datos
function LoadTerritories()
    MySQL.query('SELECT * FROM ax_territories', {}, function(result)
        if result then
            territories = {}
            for _, territory in ipairs(result) do
                local cooldownEnd = territory.cooldown_end or 0
                
                territories[territory.id] = {
                    id = territory.id,
                    name = territory.name,
                    coords = {
                        x = territory.x or 0.0,
                        y = territory.y or 0.0,
                        z = territory.z or 0.0
                    },
                    width = territory.width or 100.0,
                    height = territory.height or 100.0,
                    rotation = territory.rotation or 0.0,
                    gang = territory.gang,
                    owner = territory.gang,
                    state = territory.gang and 'captured' or 'free'
                }
                
                -- Cargar cooldown si existe y aún es válido
                if cooldownEnd > 0 and os.time() < cooldownEnd then
                    zoneCooldowns[territory.id] = cooldownEnd
                elseif territory.gang and cooldownEnd > 0 and os.time() >= cooldownEnd then
                    -- Cooldown expirado, marcar como disponible
                    territories[territory.id].state = 'captured'
                end
            end
            print('[AX_Territory] ^2' .. #result .. ' territorios cargados^7')
            
            -- Enviar a todos los clientes después de un delay
            Wait(1000)
            TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
        end
    end)
end

-- Crear tabla en la base de datos si no existe
MySQL.query([[
    CREATE TABLE IF NOT EXISTS ax_territories (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        x FLOAT NOT NULL DEFAULT 0.0,
        y FLOAT NOT NULL DEFAULT 0.0,
        z FLOAT NOT NULL DEFAULT 0.0,
        width FLOAT NOT NULL DEFAULT 100.0,
        height FLOAT NOT NULL DEFAULT 100.0,
        rotation FLOAT NOT NULL DEFAULT 0.0,
        gang VARCHAR(50) DEFAULT NULL,
        cooldown_end BIGINT DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
]])

-- Cargar territorios al iniciar el servidor
CreateThread(function()
    Wait(2000)
    LoadTerritories()
end)

-- Cuando un jugador se conecta, enviarle los territorios
RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
    Wait(2000)
    
    -- Asegurar que los territorios tengan todos los datos
    for id, territory in pairs(territories) do
        if not territory.state then
            territory.state = territory.gang and 'captured' or 'free'
        end
        if not territory.owner then
            territory.owner = territory.gang
        end
    end
    
    -- Contar territorios
    local count = 0
    for _ in pairs(territories) do
        count = count + 1
    end
    
    print('[AX_Territory] Jugador cargado, enviando ' .. count .. ' territorios a ' .. playerId)
    TriggerClientEvent('ax_territory:updateTerritories', playerId, territories)
end)

-- Evento para solicitar territorios
RegisterNetEvent('ax_territory:requestTerritories', function()
    local src = source
    
    -- Asegurar que los territorios tengan todos los datos
    for id, territory in pairs(territories) do
        if not territory.state then
            territory.state = territory.gang and 'captured' or 'free'
        end
        if not territory.owner then
            territory.owner = territory.gang
        end
    end
    
    -- Contar territorios
    local count = 0
    for _ in pairs(territories) do
        count = count + 1
    end
    
    print('[AX_Territory] Enviando ' .. count .. ' territorios a jugador ' .. src)
    TriggerClientEvent('ax_territory:updateTerritories', src, territories)
end)

-- Comando para abrir el menú de territorios (solo admins)
ESX.RegisterCommand('territorys', 'admin', function(xPlayer, args, showError)
    TriggerClientEvent('ax_territory:openAdminMenu', xPlayer.source)
end, false)

-- Callback para obtener todos los territorios
lib.callback.register('ax_territory:getTerritories', function(source)
    local territoryList = {}
    for _, territory in pairs(territories) do
        table.insert(territoryList, territory)
    end
    return territoryList
end)

-- Crear nuevo territorio
RegisterNetEvent('ax_territory:createTerritory', function(name)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer or xPlayer.getGroup() ~= Config.AdminGroup then
        return
    end
    
    if not name or name == '' then
        TriggerClientEvent('esx:showNotification', src, 'Debes ingresar un nombre para el territorio')
        return
    end
    
    -- Insertar en la base de datos
    MySQL.insert('INSERT INTO ax_territories (name, x, y, z, width, height) VALUES (?, ?, ?, ?, ?, ?)', {
        name,
        0.0,
        0.0,
        0.0,
        100.0,
        100.0
    }, function(insertId)
        if insertId then
            territories[insertId] = {
                id = insertId,
                name = name,
                coords = {
                    x = 0.0,
                    y = 0.0,
                    z = 0.0
                },
                width = 100.0,
                height = 100.0,
                rotation = 0.0,
                gang = nil,
                owner = nil,
                state = 'free'
            }
            
            TriggerClientEvent('esx:showNotification', src, 'Territorio creado exitosamente')
            TriggerClientEvent('ax_territory:openAdminMenu', src)
        else
            TriggerClientEvent('esx:showNotification', src, 'Error al crear el territorio')
        end
    end)
end)

-- Eliminar territorio
RegisterNetEvent('ax_territory:deleteTerritory', function(territoryId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer or xPlayer.getGroup() ~= Config.AdminGroup then
        return
    end
    
    MySQL.query('DELETE FROM ax_territories WHERE id = ?', {territoryId}, function(result)
        local affectedRows = result.affectedRows or 0
        if affectedRows > 0 then
            territories[territoryId] = nil
            TriggerClientEvent('esx:showNotification', src, 'Territorio eliminado exitosamente')
            TriggerClientEvent('ax_territory:openAdminMenu', src)
            TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
        else
            TriggerClientEvent('esx:showNotification', src, 'Error al eliminar el territorio')
        end
    end)
end)

-- Actualizar zona del territorio
RegisterNetEvent('ax_territory:updateZone', function(territoryId, coords, width, height, rotation)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer or xPlayer.getGroup() ~= Config.AdminGroup then
        return
    end
    
    -- Validar que width y height no sean nil
    if not width or not height then
        TriggerClientEvent('esx:showNotification', src, 'Error: Dimensiones invalidas')
        return
    end
    
    MySQL.update('UPDATE ax_territories SET x = ?, y = ?, z = ?, width = ?, height = ?, rotation = ? WHERE id = ?', {
        coords.x,
        coords.y,
        coords.z,
        width,
        height,
        rotation,
        territoryId
    }, function(affectedRows)
        if affectedRows > 0 then
            territories[territoryId].coords = {
                x = coords.x,
                y = coords.y,
                z = coords.z
            }
            territories[territoryId].width = width
            territories[territoryId].height = height
            territories[territoryId].rotation = rotation
            
            TriggerClientEvent('esx:showNotification', src, 'Zona actualizada exitosamente')
            TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
        else
            TriggerClientEvent('esx:showNotification', src, 'Error al actualizar la zona')
        end
    end)
end)

-- Sistema de captura
-- Callback para verificar si un jugador puede capturar
lib.callback.register('ax_territory:canCapture', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, nil end
    
    local job = xPlayer.job.name
    
    -- Verificar si es policía
    if job == Config.PoliceJob.job then
        if xPlayer.job.grade >= Config.PoliceJob.minGrade then
            return false, 'police' -- Puede ver pero no capturar
        end
        return false, nil
    end
    
    -- Verificar si es una banda
    if Config.GangJobs[job] then
        return true, job
    end
    
    return false, nil
end)

-- Jugador entra a zona
RegisterNetEvent('ax_territory:enterZone', function(zoneId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local territory = territories[zoneId]
    if not territory then return end
    
    -- Enviar datos de la zona al cliente
    TriggerClientEvent('ax_territory:updateZoneUI', src, {
        id = zoneId,
        name = territory.name,
        owner = territory.owner,
        cooldownEnd = zoneCooldowns[zoneId],
        captureData = activeCaptureZones[zoneId],
        state = territory.state or 'free'
    })
end)

-- Jugador sale de zona
RegisterNetEvent('ax_territory:exitZone', function(zoneId)
    local src = source
    TriggerClientEvent('ax_territory:hideZoneUI', src)
end)

-- Actualizar presencia del jugador en zona
RegisterNetEvent('ax_territory:updatePresence', function(zoneId, isInside)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local job = xPlayer.job.name
    if not Config.GangJobs[job] then return end
    
    local territory = territories[zoneId]
    if not territory then return end
    
    -- SOLO actualizar presencia si ya hay una captura activa
    if not activeCaptureZones[zoneId] then
        return
    end
    
    if isInside then
        if not activeCaptureZones[zoneId].gangs[job] then
            activeCaptureZones[zoneId].gangs[job] = {players = {}, points = 0}
        end
        
        if not activeCaptureZones[zoneId].gangs[job].players[src] then
            activeCaptureZones[zoneId].gangs[job].players[src] = true
        end
    else
        if activeCaptureZones[zoneId] and activeCaptureZones[zoneId].gangs[job] then
            activeCaptureZones[zoneId].gangs[job].players[src] = nil
        end
    end
end)

-- Jugador muere en zona
RegisterNetEvent('ax_territory:playerDied', function(zoneId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local job = xPlayer.job.name
    
    -- Remover de conteo
    if activeCaptureZones[zoneId] and activeCaptureZones[zoneId].gangs[job] then
        activeCaptureZones[zoneId].gangs[job].players[src] = nil
    end
    
    -- Agregar a lista de respawn
    deadPlayers[src] = {
        zoneId = zoneId,
        respawnTime = os.time() + Config.CaptureSystem.RespawnTime
    }
end)

-- Comando para capturar territorio libre
RegisterCommand('capturar', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local job = xPlayer.job.name
    if not Config.GangJobs[job] then
        TriggerClientEvent('esx:showNotification', source, 'No tienes permiso para usar este comando')
        return
    end
    
    TriggerClientEvent('ax_territory:requestCapture', source)
end)

-- Iniciar captura de territorio libre
RegisterNetEvent('ax_territory:startCapture', function(zoneId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local job = xPlayer.job.name
    local territory = territories[zoneId]
    
    if not territory or territory.state ~= 'free' then
        TriggerClientEvent('esx:showNotification', src, 'Este territorio no esta disponible')
        return
    end
    
    -- Iniciar captura
    territory.state = 'contested'
    activeCaptureZones[zoneId] = {
        startTime = os.time(),
        gangs = {
            [job] = {
                players = {[src] = true},
                points = 0
            }
        }
    }
    
    TriggerClientEvent('esx:showNotification', src, 'Has iniciado la captura del territorio ' .. territory.name)
    TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
    
    -- Actualizar UI
    TriggerClientEvent('ax_territory:updateZoneUI', src, {
        id = zoneId,
        name = territory.name,
        owner = territory.owner,
        cooldownEnd = zoneCooldowns[zoneId],
        captureData = activeCaptureZones[zoneId],
        state = territory.state
    })
end)

-- Comando para atacar territorio en cooldown
RegisterCommand(Config.CaptureSystem.AttackCommand:gsub('/', ''), function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local job = xPlayer.job.name
    if not Config.GangJobs[job] then
        TriggerClientEvent('esx:showNotification', source, 'No tienes permiso para usar este comando')
        return
    end
    
    TriggerClientEvent('ax_territory:requestAttack', source)
end)

RegisterNetEvent('ax_territory:confirmAttack', function(zoneId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local job = xPlayer.job.name
    local territory = territories[zoneId]
    
    if not territory or territory.state ~= 'captured' then
        TriggerClientEvent('esx:showNotification', src, 'Este territorio no puede ser atacado')
        return
    end
    
    if territory.owner == job then
        TriggerClientEvent('esx:showNotification', src, 'No puedes atacar tu propio territorio')
        return
    end
    
    -- Verificar si el cooldown ya pasó
    if zoneCooldowns[zoneId] and os.time() < zoneCooldowns[zoneId] then
        TriggerClientEvent('esx:showNotification', src, 'Este territorio aun esta en cooldown')
        return
    end
    
    -- Marcar como bajo ataque
    territory.underAttack = true
    territory.state = 'contested'
    
    -- Iniciar captura
    activeCaptureZones[zoneId] = {
        startTime = os.time(),
        gangs = {
            [job] = {
                players = {[src] = true},
                points = 0
            }
        }
    }
    
    -- Alertar a todas las bandas
    for gangJob, _ in pairs(Config.GangJobs) do
        local players = ESX.GetExtendedPlayers('job', gangJob)
        for _, gangPlayer in ipairs(players) do
            TriggerClientEvent('esx:showNotification', gangPlayer.source, 'ALERTA: El territorio ' .. territory.name .. ' esta siendo atacado')
        end
    end
    
    TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
end)

-- Thread para calcular puntos de captura
CreateThread(function()
    while true do
        Wait(1000)
        
        for zoneId, captureData in pairs(activeCaptureZones) do
            local territory = territories[zoneId]
            if not territory then goto continue end
            
            -- Verificar tiempo máximo
            if os.time() - captureData.startTime >= Config.CaptureSystem.CaptureTime then
                local winner = nil
                local maxPoints = 0
                
                for gang, data in pairs(captureData.gangs) do
                    if data.points > maxPoints then
                        maxPoints = data.points
                        winner = gang
                    end
                end
                
                if winner and maxPoints > 0 then
                    -- Capturar zona
                    territory.owner = winner
                    territory.gang = winner
                    territory.state = 'captured'
                    territory.underAttack = false
                    zoneCooldowns[zoneId] = os.time() + Config.CaptureSystem.CooldownTime
                    
                    -- Actualizar base de datos con gang y cooldown
                    local cooldownEndTime = os.time() + Config.CaptureSystem.CooldownTime
                    MySQL.update('UPDATE ax_territories SET gang = ?, cooldown_end = ? WHERE id = ?', {winner, cooldownEndTime, zoneId})
                    
                    -- Alertar
                    local players = ESX.GetExtendedPlayers('job', winner)
                    for _, player in ipairs(players) do
                        TriggerClientEvent('esx:showNotification', player.source, 'Han capturado el territorio ' .. territory.name)
                    end
                    
                    TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
                    
                    -- Actualizar UI de jugadores en la zona
                    for gang, data in pairs(captureData.gangs) do
                        for playerId in pairs(data.players) do
                            TriggerClientEvent('ax_territory:updateZoneUI', playerId, {
                                id = zoneId,
                                name = territory.name,
                                owner = territory.owner,
                                cooldownEnd = zoneCooldowns[zoneId],
                                captureData = nil,
                                state = 'captured'
                            })
                        end
                    end
                    
                    activeCaptureZones[zoneId] = nil
                else
                    territory.state = 'free'
                end
                
                activeCaptureZones[zoneId] = nil
                TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
                goto continue
            end
            
            -- Calcular puntos por cada banda
            for gang, data in pairs(captureData.gangs) do
                local playerCount = 0
                for _ in pairs(data.players) do
                    playerCount = playerCount + 1
                end
                
                if playerCount > 0 then
                    data.points = data.points + (Config.CaptureSystem.PointsPerSecond * playerCount)
                    
                    -- Verificar si llegó a 100%
                    if data.points >= Config.CaptureSystem.PointsToCapture then
                        territory.owner = gang
                        territory.gang = gang
                        territory.state = 'captured'
                        territory.underAttack = false
                        zoneCooldowns[zoneId] = os.time() + Config.CaptureSystem.CooldownTime
                        
                        -- Actualizar base de datos con gang y cooldown
                        local cooldownEndTime = os.time() + Config.CaptureSystem.CooldownTime
                        MySQL.update('UPDATE ax_territories SET gang = ?, cooldown_end = ? WHERE id = ?', {gang, cooldownEndTime, zoneId})
                        
                        -- Alertar
                        local players = ESX.GetExtendedPlayers('job', gang)
                        for _, player in ipairs(players) do
                            TriggerClientEvent('esx:showNotification', player.source, 'Han capturado el territorio ' .. territory.name)
                        end
                        
                        TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
                        
                        -- Actualizar UI de jugadores en la zona
                        for gang, data in pairs(captureData.gangs) do
                            for playerId in pairs(data.players) do
                                TriggerClientEvent('ax_territory:updateZoneUI', playerId, {
                                    id = zoneId,
                                    name = territory.name,
                                    owner = territory.owner,
                                    cooldownEnd = zoneCooldowns[zoneId],
                                    captureData = nil,
                                    state = 'captured'
                                })
                            end
                        end
                        
                        activeCaptureZones[zoneId] = nil
                        goto continue
                    end
                end
            end
            
            -- Enviar actualización a todos en la zona
            for gang, data in pairs(captureData.gangs) do
                for playerId in pairs(data.players) do
                    TriggerClientEvent('ax_territory:updateCaptureProgress', playerId, zoneId, captureData)
                end
            end
            
            ::continue::
        end
    end
end)

-- Liberar territorio
RegisterNetEvent('ax_territory:freeTerritory', function(territoryId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer or xPlayer.getGroup() ~= Config.AdminGroup then
        return
    end
    
    local territory = territories[territoryId]
    if not territory then
        TriggerClientEvent('esx:showNotification', src, 'Territorio no encontrado')
        return
    end
    
    -- Liberar territorio
    territory.owner = nil
    territory.gang = nil
    territory.state = 'free'
    territory.underAttack = false
    
    -- Eliminar cooldown
    zoneCooldowns[territoryId] = nil
    
    -- Detener captura activa si existe
    if activeCaptureZones[territoryId] then
        activeCaptureZones[territoryId] = nil
    end
    
    -- Actualizar base de datos
    MySQL.update('UPDATE ax_territories SET gang = NULL, cooldown_end = NULL WHERE id = ?', {territoryId}, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('esx:showNotification', src, 'Territorio liberado exitosamente')
            TriggerClientEvent('ax_territory:openAdminMenu', src)
            TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
        else
            TriggerClientEvent('esx:showNotification', src, 'Error al liberar el territorio')
        end
    end)
end)

-- Limpiar jugadores muertos
CreateThread(function()
    while true do
        Wait(1000)
        
        for playerId, data in pairs(deadPlayers) do
            if os.time() >= data.respawnTime then
                deadPlayers[playerId] = nil
            end
        end
    end
end)