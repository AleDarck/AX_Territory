local ESX = exports['es_extended']:getSharedObject()
local territories = {}

-- Locales
local Locale = {
    ['territory_created'] = 'Territorio creado exitosamente',
    ['territory_deleted'] = 'Territorio eliminado exitosamente',
    ['zone_saved'] = 'Zona guardada exitosamente',
    ['no_permission'] = 'No tienes permisos para usar este comando',
    ['not_gang_member'] = 'No eres miembro de una banda',
    ['territory_under_attack'] = 'El territorio %s esta siendo atacado!',
    ['already_in_capture'] = 'Ya hay una captura en progreso en este territorio',
    ['capture_started'] = 'Captura iniciada! Defiende el territorio!',
    ['zone_freed'] = 'Zona liberada exitosamente'
}

-- Cargar territorios desde la base de datos
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `ax_territories` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(100) NOT NULL,
            `coords` TEXT NOT NULL,
            `size` TEXT NOT NULL,
            `rotation` FLOAT NOT NULL DEFAULT 0.0,
            `owner` VARCHAR(50) DEFAULT NULL,
            `points` TEXT DEFAULT NULL,
            `status` INT(1) NOT NULL DEFAULT 1,
            `last_capture` BIGINT(20) DEFAULT NULL,
            `last_point` BIGINT(20) DEFAULT NULL,
            `custom_blip` INT(11) DEFAULT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    LoadTerritories()
end)

function LoadTerritories()
    territories = {}
    local result = MySQL.query.await('SELECT * FROM ax_territories')
    
    if result then
        for _, territory in ipairs(result) do
            territories[territory.id] = {
                id = territory.id,
                name = territory.name,
                coords = json.decode(territory.coords),
                size = json.decode(territory.size),
                rotation = territory.rotation,
                owner = territory.owner,
                points = territory.points and json.decode(territory.points) or {},
                status = territory.status or 1,
                last_capture = territory.last_capture,
                last_point = territory.last_point,
                custom_blip = territory.custom_blip  -- AGREGAR ESTA LÍNEA
            }
        end
    end
end

-- Liberar territorios disponibles al iniciar el servidor
CreateThread(function()
    Wait(5000) -- Esperar a que todo cargue
    
    for id, territory in pairs(territories) do
        if territory.status == 3 and territory.last_capture then
            local elapsed = os.time() - territory.last_capture
            
            -- Si el cooldown ya pasó, liberar el territorio
            if elapsed >= Config.CooldownTime then
                territory.owner = nil
                territory.status = 1
                territory.last_capture = nil
                territory.points = {}
                territories[id] = territory
                
                MySQL.update('UPDATE ax_territories SET owner = NULL, status = 1, last_capture = NULL, points = NULL WHERE id = ?', {
                    id
                })
                
                print(string.format('[AX_Territory] Territorio "%s" liberado (cooldown expirado)', territory.name))
            end
        end
    end
end)

-- Estado de capturas activas
local activeCaptures = {}

-- Verificar si es miembro de banda
function IsGangMember(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    for gangName, _ in pairs(Config.Gangs) do
        if xPlayer.job.name == gangName then
            return true, gangName
        end
    end
    return false, nil
end

-- Verificar si es policía con rango permitido
function IsPoliceViewer(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    if xPlayer.job.name == Config.PoliceJob then
        for _, rank in ipairs(Config.PoliceRanksCanView) do
            if xPlayer.job.grade_name == rank then
                return true
            end
        end
    end
    return false
end

-- Dar recompensa a la banda
function GiveGangReward(gangName)
    local gangAccount = Config.GangAccounts[gangName]
    if not gangAccount then return end
    
    MySQL.update('INSERT INTO gang_black_money (gang_account, amount) VALUES (?, ?) ON DUPLICATE KEY UPDATE amount = amount + ?', {
        gangAccount,
        Config.CaptureReward,
        Config.CaptureReward
    })
end

-- Dar XP a la banda
function GiveGangXP(gangName, amount)
    if not Config.UseGangXPSystem then return end
    
    -- Verificar si el export existe
    local success, result = pcall(function()
        exports['AX_GangTab']:GiveGangXP(gangName, amount)
    end)
    
    if not success then
        print('[AX_Territory] Error al dar XP: AX_GangTab no disponible')
    end
end

-- Callback para obtener tiempo de cooldown
ESX.RegisterServerCallback('ax_territory:getCooldownTime', function(source, cb, territoryId)
    local territory = territories[territoryId]
    if not territory or not territory.last_capture then
        cb(0)
        return
    end
    
    local elapsed = os.time() - territory.last_capture
    local remaining = math.max(0, Config.CooldownTime - elapsed)
    cb(remaining)
end)

-- Callback para verificar si se puede atacar
ESX.RegisterServerCallback('ax_territory:canAttack', function(source, cb, territoryId)
    local territory = territories[territoryId]
    
    if not territory then
        cb(false, 'Territorio no encontrado')
        return
    end
    
    if territory.status ~= 3 or not territory.owner then
        cb(false, 'Este territorio no esta capturado')
        return
    end
    
    if activeCaptures[territoryId] then
        cb(false, Locale['already_in_capture'])
        return
    end
    
    if territory.last_capture then
        local elapsed = os.time() - territory.last_capture
        if elapsed < Config.CooldownTime then
            local remaining = Config.CooldownTime - elapsed
            local hours = math.floor(remaining / 3600)
            local minutes = math.floor((remaining % 3600) / 60)
            cb(false, string.format('Cooldown activo. Tiempo restante: %dh %dm', hours, minutes))
            return
        end
    end
    
    cb(true, '')
end)

-- Iniciar captura de territorio
RegisterNetEvent('ax_territory:startCapture', function(territoryId, isAttack)
    local src = source
    local isGang, gangName = IsGangMember(src)
    
    if not isGang then
        TriggerClientEvent('esx:showNotification', src, Locale['not_gang_member'])
        return
    end
    
    local territory = territories[territoryId]
    if not territory then return end
    
    -- Verificar si ya hay captura activa
    if activeCaptures[territoryId] then
        TriggerClientEvent('esx:showNotification', src, Locale['already_in_capture'])
        return
    end
    
    -- Iniciar captura
    activeCaptures[territoryId] = {
        startTime = os.time(),
        participants = {},
        progress = {}
    }
    
    territory.status = 2 -- En disputa
    territories[territoryId] = territory
    
    -- Actualizar en base de datos
    MySQL.update('UPDATE ax_territories SET status = 2 WHERE id = ?', {territoryId})
    
    -- Alertar a todas las bandas si es ataque
    if isAttack then
        for _, playerId in ipairs(ESX.GetPlayers()) do
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then
                for gangName, _ in pairs(Config.Gangs) do
                    if xPlayer.job.name == gangName then
                        TriggerClientEvent('esx:showNotification', playerId, 
                            string.format(Locale['territory_under_attack'], territory.name))
                    end
                end
            end
        end
    end
    
    TriggerClientEvent('esx:showNotification', src, Locale['capture_started'])
    TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
    TriggerClientEvent('ax_territory:startCaptureUI', -1, territoryId, territory)
end)

-- Actualizar participantes en captura
RegisterNetEvent('ax_territory:updateCaptureParticipant', function(territoryId, isInside, isDead)
    local src = source
    local isGang, gangName = IsGangMember(src)
    
    if not isGang or not activeCaptures[territoryId] then return end
    
    if isInside and not isDead then
        activeCaptures[territoryId].participants[src] = gangName
    else
        activeCaptures[territoryId].participants[src] = nil
    end
end)

-- Liberar zona (admin)
RegisterNetEvent('ax_territory:freeZone', function(territoryId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    
    local territory = territories[territoryId]
    if not territory then return end
    
    territory.owner = nil
    territory.status = 1
    territory.last_capture = nil
    territory.points = {}
    
    MySQL.update('UPDATE ax_territories SET owner = NULL, status = 1, last_capture = NULL, points = NULL WHERE id = ?', {
        territoryId
    }, function()
        TriggerClientEvent('esx:showNotification', src, Locale['zone_freed'])
        TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
    end)
end)

-- Verificar si el jugador es admin
function IsPlayerAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    return xPlayer.getGroup() == Config.AdminGroup
end

-- Comando para abrir el menú de administración
RegisterCommand('aterri', function(source, args)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('esx:showNotification', source, Locale['no_permission'])
        return
    end
    
    TriggerClientEvent('ax_territory:openAdminMenu', source)
end)

-- Obtener lista de territorios
ESX.RegisterServerCallback('ax_territory:getTerritories', function(source, cb)
    cb(territories)
end)

-- Crear nuevo territorio
RegisterNetEvent('ax_territory:createTerritory', function(name)
    local src = source
    
    if not IsPlayerAdmin(src) then return end
    
    MySQL.insert('INSERT INTO ax_territories (name, coords, size, rotation, status) VALUES (?, ?, ?, ?, ?)', {
        name,
        json.encode({x = 0.0, y = 0.0, z = 0.0}),
        json.encode({width = 100.0, height = 100.0}),
        0.0,
        1
    }, function(id)
        if id then
            territories[id] = {
                id = id,
                name = name,
                coords = {x = 0.0, y = 0.0, z = 0.0},
                size = {width = 100.0, height = 100.0},
                rotation = 0.0,
                owner = nil,
                points = {},
                status = 1,
                last_capture = nil,
                last_point = nil
            }
            
            TriggerClientEvent('esx:showNotification', src, Locale['territory_created'])
            TriggerClientEvent('ax_territory:openAdminMenu', src)
            TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
        end
    end)
end)

-- Guardar zona editada
RegisterNetEvent('ax_territory:saveZone', function(territoryId, coords, size, rotation)
    local src = source
    
    if not IsPlayerAdmin(src) then return end
    
    MySQL.update('UPDATE ax_territories SET coords = ?, size = ?, rotation = ? WHERE id = ?', {
        json.encode(coords),
        json.encode(size),
        rotation,
        territoryId
    }, function(affectedRows)
        if affectedRows > 0 then
            territories[territoryId].coords = coords
            territories[territoryId].size = size
            territories[territoryId].rotation = rotation
            
            TriggerClientEvent('esx:showNotification', src, Locale['zone_saved'])
            TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
        end
    end)
end)

-- Eliminar territorio
RegisterNetEvent('ax_territory:deleteTerritory', function(territoryId)
    local src = source
    
    if not IsPlayerAdmin(src) then return end
    
    MySQL.query('DELETE FROM ax_territories WHERE id = ?', {territoryId}, function()
        territories[territoryId] = nil
        TriggerClientEvent('esx:showNotification', src, Locale['territory_deleted'])
        TriggerClientEvent('ax_territory:openAdminMenu', src)
        TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
    end)
end)

-- Thread para procesar capturas activas
CreateThread(function()
    while true do
        Wait(Config.CaptureCheckInterval)
        
        for territoryId, capture in pairs(activeCaptures) do
            local territory = territories[territoryId]
            if not territory then
                activeCaptures[territoryId] = nil
                goto continue
            end
            
            -- Verificar si se acabó el tiempo
            local elapsed = os.time() - capture.startTime
            if elapsed >= Config.CaptureTime then
                -- Se acabó el tiempo
                local winner = nil
                local maxProgress = 0
                
                -- Determinar ganador por mayor progreso
                for gangName, progress in pairs(capture.progress) do
                    if progress > maxProgress then
                        maxProgress = progress
                        winner = gangName
                    end
                end
                
                if winner and maxProgress > 0 then
                    -- Hay un ganador
                    territory.owner = winner
                    territory.status = 3
                    territory.last_capture = os.time()
                    territory.points = {}
                    
                    territories[territoryId] = territory
                    
                    MySQL.update('UPDATE ax_territories SET owner = ?, status = 3, last_capture = ?, points = ? WHERE id = ?', {
                        winner,
                        os.time(),
                        json.encode({}),
                        territoryId
                    }, function()
                            -- Dar recompensa
                            GiveGangReward(winner)
                            
                            -- Dar XP a la banda
                            GiveGangXP(winner, Config.CaptureXP)

                            -- Notificar a todos los miembros de la banda ganadora
                                for _, playerId in ipairs(ESX.GetPlayers()) do
                                local xPlayer = ESX.GetPlayerFromId(playerId)
                                if xPlayer and xPlayer.job.name == winner then
                                    TriggerClientEvent('esx:showNotification', playerId, 
                                        string.format('Tu banda ha capturado %s! +$%s y +%s XP', 
                                            territory.name, 
                                            ESX.Math.GroupDigits(Config.CaptureReward),
                                            Config.CaptureXP
                                        ))
                                end
                        end
                        
                        TriggerClientEvent('ax_territory:captureFinished', -1, territoryId, winner, territory)
                        TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
                        activeCaptures[territoryId] = nil
                    end)
                else
                    -- Nadie capturó, reiniciar zona
                    territory.status = 1
                    territory.owner = nil
                    territory.points = {}
                    
                    territories[territoryId] = territory
                    
                    MySQL.update('UPDATE ax_territories SET status = 1, owner = NULL, points = ? WHERE id = ?', {
                        json.encode({}),
                        territoryId
                    }, function()
                        TriggerClientEvent('esx:showNotification', -1, 
                            string.format('El territorio %s ha sido liberado por inactividad', territory.name))
                        TriggerClientEvent('ax_territory:captureFinished', -1, territoryId, nil, territory)
                        TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
                        activeCaptures[territoryId] = nil
                    end)
                end
                
                goto continue
            end
            
            -- Contar solo jugadores VIVOS y DENTRO del territorio
            local gangCounts = {}
            local validParticipants = {}
            
            for playerId, gangName in pairs(capture.participants) do
                local xPlayer = ESX.GetPlayerFromId(playerId)
                -- Verificar que el jugador existe, está vivo y sigue conectado
                if xPlayer then
                    validParticipants[playerId] = gangName
                    gangCounts[gangName] = (gangCounts[gangName] or 0) + 1
                end
            end
            
            -- Actualizar lista de participantes válidos
            capture.participants = validParticipants
            
            -- Calcular progreso SOLO para bandas con jugadores vivos
            if not capture.progress then capture.progress = {} end
            
            -- Solo incrementar progreso para bandas con jugadores activos
            for gangName, count in pairs(gangCounts) do
                if count > 0 then
                    -- Cada jugador aporta % por segundo
                    local progressIncrease = (count * Config.PointsPerPlayer * (Config.CaptureCheckInterval / 1000))
                    capture.progress[gangName] = (capture.progress[gangName] or 0) + progressIncrease
                end
            end
            
            -- Calcular porcentajes basados en el tiempo total
            local timeProgress = (elapsed / Config.CaptureTime) * 100
            local percentages = {}
            local totalProgress = 0
            
            for gangName, progress in pairs(capture.progress) do
                totalProgress = totalProgress + progress
            end
            
            if totalProgress > 0 then
                for gangName, progress in pairs(capture.progress) do
                    percentages[gangName] = (progress / totalProgress) * timeProgress
                end
            else
                -- Si no hay progreso, asignar 0 a todos
                for gangName, _ in pairs(Config.Gangs) do
                    percentages[gangName] = 0
                end
            end
            
            -- Enviar actualización a clientes
            TriggerClientEvent('ax_territory:updateCaptureProgress', -1, territoryId, percentages, gangCounts, elapsed, Config.CaptureTime)
            
            ::continue::
        end
    end
end)

-- Thread para verificar cooldowns
CreateThread(function()
    while true do
        Wait(30000) -- Cada 30 segundos
        
        for id, territory in pairs(territories) do
            if territory.status == 3 and territory.last_capture then
                local elapsed = os.time() - territory.last_capture
                if elapsed >= Config.CooldownTime then
                    -- Cooldown terminado, zona disponible para ataque
                    TriggerClientEvent('ax_territory:cooldownFinished', -1, id)
                end
            end
        end
    end
end)

-- Establecer blip personalizado
RegisterNetEvent('ax_territory:setCustomBlip', function(territoryId, blipSprite)
    local src = source
    
    if not IsPlayerAdmin(src) then return end
    
    MySQL.update('UPDATE ax_territories SET custom_blip = ? WHERE id = ?', {
        blipSprite,
        territoryId
    }, function(affectedRows)
        if affectedRows > 0 then
            territories[territoryId].custom_blip = blipSprite
            TriggerClientEvent('esx:showNotification', src, 'Blip actualizado exitosamente')
            TriggerClientEvent('ax_territory:updateTerritories', -1, territories)
        end
    end)
end)