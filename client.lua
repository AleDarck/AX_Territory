local ESX = exports['es_extended']:getSharedObject()
local territories = {}
local editingZone = false
local currentZoneData = nil
local playerInsideTerritory = nil
local captureInProgress = {}
local uiVisible = true
local isDead = false

-- Recibir actualización de territorios
RegisterNetEvent('ax_territory:updateTerritories', function(data)
    territories = data
    UpdateTerritoryBlips()
    
    -- Si el jugador está dentro de un territorio, actualizar el UI
    if playerInsideTerritory and territories[playerInsideTerritory] then
        ShowTerritoryUI(playerInsideTerritory, territories[playerInsideTerritory])
    end
end)

-- Solicitar territorios al cargar
CreateThread(function()
    Wait(1000)
    ESX.TriggerServerCallback('ax_territory:getTerritories', function(data)
        territories = data
    end)
end)

-- Abrir menú de administración
RegisterNetEvent('ax_territory:openAdminMenu', function()
    ESX.TriggerServerCallback('ax_territory:getTerritories', function(data)
        territories = data
        OpenAdminMenu()
    end)
end)

-- Verificar si el jugador es miembro de banda
function IsPlayerGangMember()
    local playerData = ESX.GetPlayerData()
    if not playerData or not playerData.job then return false, nil end
    
    for gangName, _ in pairs(Config.Gangs) do
        if playerData.job.name == gangName then
            return true, gangName
        end
    end
    return false, nil
end

-- Verificar si es policía con permiso
function IsPlayerPoliceViewer()
    local playerData = ESX.GetPlayerData()
    if not playerData or not playerData.job then return false end
    
    if playerData.job.name == Config.PoliceJob then
        for _, rank in ipairs(Config.PoliceRanksCanView) do
            if playerData.job.grade_name == rank then
                return true
            end
        end
    end
    return false
end

-- Verificar si el jugador puede ver territorios
function CanViewTerritories()
    return IsPlayerGangMember() or IsPlayerPoliceViewer()
end

-- Verificar si está dentro de un territorio
function IsInsideTerritory(territory)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    local origin = vector3(territory.coords.x, territory.coords.y, territory.coords.z)
    local r = territory.rotation * math.pi / 180
    local halfWidth = territory.size.width / 2
    local halfHeight = territory.size.height / 2
    
    local v = vector3(
        (playerCoords.x - origin.x) * math.cos(r) + (playerCoords.y - origin.y) * math.sin(r) + origin.x,
        -(playerCoords.x - origin.x) * math.sin(r) + (playerCoords.y - origin.y) * math.cos(r) + origin.y,
        playerCoords.z
    )
    
    return math.abs(v.x - origin.x) <= halfWidth and math.abs(v.y - origin.y) <= halfHeight
end

function OpenAdminMenu()
    local elements = {}
    
    -- Botón para crear nuevo territorio
    table.insert(elements, {
        title = Config.Locale['create_territory'],
        icon = 'plus',
        onSelect = function()
            CreateTerritoryDialog()
        end
    })
    
    -- Listar territorios existentes
    for id, territory in pairs(territories) do
        table.insert(elements, {
            title = territory.name,
            icon = 'map-marked-alt',
            onSelect = function()
                OpenTerritoryOptions(id, territory)
            end
        })
    end
    
    lib.registerContext({
        id = 'ax_territory_admin',
        title = Config.Locale['menu_title'],
        options = elements
    })
    
    lib.showContext('ax_territory_admin')
end

function CreateTerritoryDialog()
    local input = lib.inputDialog(Config.Locale['create_territory'], {
        {
            type = 'input',
            label = Config.Locale['territory_name'],
            description = Config.Locale['territory_name_desc'],
            required = true,
            min = 3,
            max = 50
        }
    })
    
    if input then
        TriggerServerEvent('ax_territory:createTerritory', input[1])
    end
end

function OpenTerritoryOptions(territoryId, territory)
    lib.registerContext({
        id = 'ax_territory_options',
        title = territory.name,
        menu = 'ax_territory_admin',
        options = {
            {
                title = Config.Locale['edit_zone'],
                icon = 'edit',
                onSelect = function()
                    StartZoneEditor(territoryId, territory)
                end
            },
            {
                title = Config.Locale['free_zone'],
                icon = 'unlock',
                onSelect = function()
                    TriggerServerEvent('ax_territory:freeZone', territoryId)
                end
            },
            {
                title = Config.Locale['delete_territory'],
                icon = 'trash',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = Config.Locale['confirm_delete'],
                        content = Config.Locale['confirm_delete_desc'],
                        centered = true,
                        cancel = true
                    })
                    
                    if alert == 'confirm' then
                        TriggerServerEvent('ax_territory:deleteTerritory', territoryId)
                    end
                end
            }
        }
    })
    
    lib.showContext('ax_territory_options')
end

-- Editor de zona
function StartZoneEditor(territoryId, territory)
    editingZone = true
    
    -- Obtener posición del jugador o usar la guardada del territorio
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    currentZoneData = {
        id = territoryId,
        coords = territory.coords.x ~= 0 and territory.coords or {x = playerCoords.x, y = playerCoords.y, z = 30.0},
        size = territory.size,
        rotation = territory.rotation
    }
    
    -- Variables de control
    local speedMultiplier = 1.0
    local moveSpeed = 2.0
    local sizeSpeed = 2.0
    local rotationSpeed = 2.0
    local blip = nil
    
    -- Abrir el mapa
    SetFrontendActive(true)
    ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'), false, -1)
    
    ESX.ShowNotification(Config.Locale['zone_editor_controls'])
    
    CreateThread(function()
        while editingZone do
            Wait(0)
            
            -- Remover blip anterior
            if blip then
                RemoveBlip(blip)
            end
            
            -- Crear blip del área en el mapa
            blip = AddBlipForArea(
                currentZoneData.coords.x,
                currentZoneData.coords.y,
                currentZoneData.coords.z,
                currentZoneData.size.width,
                currentZoneData.size.height
            )
            SetBlipRotation(blip, math.floor(currentZoneData.rotation))
            SetBlipColour(blip, 1) -- Rojo
            SetBlipAlpha(blip, 200)
            
            -- Deshabilitar controles del mapa
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            
            -- Velocidad aumentada con SHIFT
            if IsDisabledControlPressed(0, 21) then -- LSHIFT
                speedMultiplier = 3.0
            else
                speedMultiplier = 1.0
            end
            
            -- Movimiento - NUMPAD 8, 4, 5, 6
            if IsDisabledControlPressed(0, 111) then -- NUMPAD 8 (arriba)
                local forward = GetForwardVector(currentZoneData.rotation)
                currentZoneData.coords.x = currentZoneData.coords.x + forward.x * moveSpeed * speedMultiplier
                currentZoneData.coords.y = currentZoneData.coords.y + forward.y * moveSpeed * speedMultiplier
            end
            
            if IsDisabledControlPressed(0, 112) then -- NUMPAD 5 (abajo)
                local forward = GetForwardVector(currentZoneData.rotation)
                currentZoneData.coords.x = currentZoneData.coords.x - forward.x * moveSpeed * speedMultiplier
                currentZoneData.coords.y = currentZoneData.coords.y - forward.y * moveSpeed * speedMultiplier
            end
            
            if IsDisabledControlPressed(0, 108) then -- NUMPAD 4 (izquierda)
                local right = GetRightVector(currentZoneData.rotation)
                currentZoneData.coords.x = currentZoneData.coords.x - right.x * moveSpeed * speedMultiplier
                currentZoneData.coords.y = currentZoneData.coords.y - right.y * moveSpeed * speedMultiplier
            end
            
            if IsDisabledControlPressed(0, 109) then -- NUMPAD 6 (derecha)
                local right = GetRightVector(currentZoneData.rotation)
                currentZoneData.coords.x = currentZoneData.coords.x + right.x * moveSpeed * speedMultiplier
                currentZoneData.coords.y = currentZoneData.coords.y + right.y * moveSpeed * speedMultiplier
            end
            
            -- Tamaño - NUMPAD 1, 3
            if IsDisabledControlPressed(0, 306) then -- NUMPAD 1 (reducir)
                currentZoneData.size.height = math.max(10.0, currentZoneData.size.height - sizeSpeed * speedMultiplier)
                currentZoneData.size.width = math.max(10.0, currentZoneData.size.width - sizeSpeed * speedMultiplier)
            end
            
            if IsDisabledControlPressed(0, 244) then -- NUMPAD 3 (aumentar)
                currentZoneData.size.height = currentZoneData.size.height + sizeSpeed * speedMultiplier
                currentZoneData.size.width = currentZoneData.size.width + sizeSpeed * speedMultiplier
            end
            
            -- Rotación - NUMPAD 7, 9
            if IsDisabledControlPressed(0, 117) then -- NUMPAD 7 (rotar izquierda)
                currentZoneData.rotation = (currentZoneData.rotation - rotationSpeed * speedMultiplier) % 360
            end
            
            if IsDisabledControlPressed(0, 118) then -- NUMPAD 9 (rotar derecha)
                currentZoneData.rotation = (currentZoneData.rotation + rotationSpeed * speedMultiplier) % 360
            end
            
            -- Confirmar - ENTER
            if IsDisabledControlJustPressed(0, 191) then
                if blip then RemoveBlip(blip) end
                SetFrontendActive(false)
                TriggerServerEvent('ax_territory:saveZone', 
                    currentZoneData.id, 
                    currentZoneData.coords, 
                    currentZoneData.size, 
                    currentZoneData.rotation
                )
                editingZone = false
            end
            
            -- Cancelar - ESC
            if IsDisabledControlJustPressed(0, 322) then
                if blip then RemoveBlip(blip) end
                SetFrontendActive(false)
                editingZone = false
                ESX.ShowNotification('Editor cancelado')
            end
        end
    end)
end

function DrawZoneBox(coords, size, rotation)
    local halfWidth = size.width / 2
    local halfHeight = size.height / 2
    local zBase = coords.z
    local zTop = coords.z + Config.ZoneHeight
    
    local rad = math.rad(rotation)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    
    -- Calcular las 4 esquinas del rectángulo rotado
    local function rotatePoint(x, y)
        return {
            x = coords.x + (x * cos - y * sin),
            y = coords.y + (x * sin + y * cos)
        }
    end
    
    local corners = {
        rotatePoint(-halfWidth, -halfHeight),
        rotatePoint(halfWidth, -halfHeight),
        rotatePoint(halfWidth, halfHeight),
        rotatePoint(-halfWidth, halfHeight)
    }
    
    -- Dibujar líneas del suelo
    for i = 1, 4 do
        local next = i % 4 + 1
        DrawLine(
            corners[i].x, corners[i].y, zBase,
            corners[next].x, corners[next].y, zBase,
            255, 0, 0, 255
        )
    end
    
    -- Dibujar líneas superiores
    for i = 1, 4 do
        local next = i % 4 + 1
        DrawLine(
            corners[i].x, corners[i].y, zTop,
            corners[next].x, corners[next].y, zTop,
            255, 0, 0, 255
        )
    end
    
    -- Dibujar líneas verticales
    for i = 1, 4 do
        DrawLine(
            corners[i].x, corners[i].y, zBase,
            corners[i].x, corners[i].y, zTop,
            255, 0, 0, 255
        )
    end
    
    -- Dibujar punto central
    DrawMarker(
        28, -- Marker type
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        0.5, 0.5, 0.5,
        255, 255, 0, 200,
        false, true, 2, false, nil, nil, false
    )
end

-- Mostrar territorios en el mapa
local territoryBlips = {}

function UpdateTerritoryBlips()
    -- Limpiar blips anteriores
    for _, blip in pairs(territoryBlips) do
        RemoveBlip(blip)
    end
    territoryBlips = {}
    
    if not CanViewTerritories() then return end
    
    -- Crear nuevos blips
    for id, territory in pairs(territories) do
        if territory.coords.x ~= 0 then
            local blip = AddBlipForArea(
                territory.coords.x,
                territory.coords.y,
                territory.coords.z,
                territory.size.width,
                territory.size.height
            )
            SetBlipRotation(blip, math.floor(territory.rotation))
            
            -- Color según estado
            local color = 0
            if territory.status == 1 or not territory.owner then
                -- Libre - Blanco
                color = 0
                SetBlipColour(blip, color)
            elseif territory.status == 2 then
                -- En disputa - Color de la banda pero parpadeando (se maneja en otro thread)
                color = 1 -- Rojo temporal
                SetBlipColour(blip, color)
            elseif territory.status == 3 and territory.owner then
                -- Capturado - Color de la banda
                if Config.Gangs[territory.owner] then
                    -- Convertir RGB a color de blip (aproximado)
                    color = 1 -- Por ahora rojo, puedes mapear colores específicos
                    SetBlipColour(blip, color)
                end
            end
            
            SetBlipAlpha(blip, 150)
            territoryBlips[id] = blip
        end
    end
end

-- Thread para parpadeo de zonas en disputa
CreateThread(function()
    local blinkState = true
    while true do
        Wait(Config.DisputeBlinkSpeed)
        
        if CanViewTerritories() then
            for id, territory in pairs(territories) do
                if territory.status == 2 and territoryBlips[id] then
                    blinkState = not blinkState
                    SetBlipAlpha(territoryBlips[id], blinkState and 200 or 50)
                end
            end
        end
    end
end)

-- Thread para detectar cuando el jugador entra/sale de territorios
CreateThread(function()
    while true do
        Wait(1000)
        
        if CanViewTerritories() then
            local currentTerritory = nil
            
            for id, territory in pairs(territories) do
                if territory.coords.x ~= 0 and IsInsideTerritory(territory) then
                    currentTerritory = id
                    break
                end
            end
            
            -- Detectar cambio de territorio
            if currentTerritory ~= playerInsideTerritory then
                if playerInsideTerritory then
                    -- Salió del territorio - SIEMPRE ocultar UI
                    SendNUIMessage({
                        action = 'hideUI'
                    })
                    
                    -- Notificar al servidor que salió
                    if captureInProgress[playerInsideTerritory] then
                        TriggerServerEvent('ax_territory:updateCaptureParticipant', playerInsideTerritory, false, false)
                    end
                end
                
                playerInsideTerritory = currentTerritory
                
                if currentTerritory then
                    -- Entró a un territorio - SIEMPRE mostrar UI
                    local territory = territories[currentTerritory]
                    ShowTerritoryUI(currentTerritory, territory)
                    
                    -- Notificar al servidor que entró (solo cuenta si está vivo)
                    if captureInProgress[currentTerritory] and not isDead then
                        TriggerServerEvent('ax_territory:updateCaptureParticipant', currentTerritory, true, false)
                    end
                end
            else
                -- Sigue dentro del territorio
                if currentTerritory and captureInProgress[currentTerritory] then
                    -- Solo actualizar si está muerto para que no cuente
                    if isDead then
                        TriggerServerEvent('ax_territory:updateCaptureParticipant', currentTerritory, false, true)
                    end
                end
            end
        else
            -- No puede ver territorios
            if playerInsideTerritory then
                SendNUIMessage({
                    action = 'hideUI'
                })
                playerInsideTerritory = nil
            end
        end
    end
end)

function ShowTerritoryUI(territoryId, territory)
    if not uiVisible then return end
    
    local status = 'free'
    local cooldownRemaining = 0
    
    -- Determinar el estado correcto
    if territory.status == 2 then
        -- En disputa
        status = 'dispute'
    elseif territory.status == 3 and territory.owner then
        -- Capturado
        status = 'captured'
        -- Solicitar el cooldown al servidor
        ESX.TriggerServerCallback('ax_territory:getCooldownTime', function(remaining)
            cooldownRemaining = remaining
            
            local ownerName = territory.owner and Config.Gangs[territory.owner] and Config.Gangs[territory.owner].name or 'Desconocido'
            
            SendNUIMessage({
                action = 'showUI',
                data = {
                    territoryId = territoryId,
                    name = territory.name,
                    status = status,
                    owner = territory.owner,
                    ownerName = ownerName,
                    cooldownRemaining = cooldownRemaining,
                    captureCommand = Config.CaptureCommand,
                    attackCommand = Config.AttackCommand,
                    hideKey = Config.HideUIKey
                }
            })
        end, territoryId)
        return
    else
        -- Libre (status == 1 o sin owner)
        status = 'free'
    end
    
    local ownerName = territory.owner and Config.Gangs[territory.owner] and Config.Gangs[territory.owner].name or 'Desconocido'
    
    SendNUIMessage({
        action = 'showUI',
        data = {
            territoryId = territoryId,
            name = territory.name,
            status = status,
            owner = territory.owner,
            ownerName = ownerName,
            cooldownRemaining = cooldownRemaining,
            captureCommand = Config.CaptureCommand,
            attackCommand = Config.AttackCommand,
            hideKey = Config.HideUIKey
        }
    })
end

-- Actualizar blips cuando cambian los territorios
RegisterNetEvent('ax_territory:updateTerritories', function(data)
    territories = data
    UpdateTerritoryBlips()
end)

-- Cargar blips al inicio
CreateThread(function()
    Wait(2000)
    UpdateTerritoryBlips()
end)

function GetForwardVector(rotation)
    local rad = math.rad(rotation)
    return {
        x = -math.sin(rad),
        y = math.cos(rad)
    }
end

function GetRightVector(rotation)
    local rad = math.rad(rotation)
    return {
        x = math.cos(rad),
        y = math.sin(rad)
    }
end

-- Comandos
RegisterCommand(Config.CaptureCommand, function()
    if not playerInsideTerritory then
        ESX.ShowNotification('No estas dentro de un territorio')
        return
    end
    
    local isGang, gangName = IsPlayerGangMember()
    if not isGang then
        ESX.ShowNotification(Config.Locale['not_gang_member'])
        return
    end
    
    local territory = territories[playerInsideTerritory]
    if territory.status ~= 1 and territory.owner then
        ESX.ShowNotification('Este territorio no esta libre')
        return
    end
    
    TriggerServerEvent('ax_territory:startCapture', playerInsideTerritory, false)
    
    -- Notificar inmediatamente al servidor que estás capturando
    Wait(500) -- Esperar a que el servidor inicie la captura
    if not isDead then
        TriggerServerEvent('ax_territory:updateCaptureParticipant', playerInsideTerritory, true, false)
    end
end)

RegisterCommand(Config.AttackCommand, function()
    if not playerInsideTerritory then
        ESX.ShowNotification('No estas dentro de un territorio')
        return
    end
    
    local isGang, gangName = IsPlayerGangMember()
    if not isGang then
        ESX.ShowNotification(Config.Locale['not_gang_member'])
        return
    end
    
    local territory = territories[playerInsideTerritory]
    if territory.status ~= 3 or not territory.owner then
        ESX.ShowNotification('Este territorio no esta capturado')
        return
    end
    
    if territory.last_capture then
        local elapsed = os.time() - territory.last_capture
        if elapsed < Config.CooldownTime then
            ESX.ShowNotification('Este territorio aun esta en cooldown')
            return
        end
    end
    
    TriggerServerEvent('ax_territory:startCapture', playerInsideTerritory, true)
    
    -- Notificar inmediatamente al servidor que estás capturando
    Wait(500) -- Esperar a que el servidor inicie la captura
    if not isDead then
        TriggerServerEvent('ax_territory:updateCaptureParticipant', playerInsideTerritory, true, false)
    end
end)

-- Tecla para ocultar/mostrar UI
RegisterCommand('toggleTerritoryUI', function()
    uiVisible = not uiVisible
    if not uiVisible then
        SendNUIMessage({action = 'hideUI'})
    elseif playerInsideTerritory then
        ShowTerritoryUI(playerInsideTerritory, territories[playerInsideTerritory])
    end
end)
RegisterKeyMapping('toggleTerritoryUI', 'Ocultar/Mostrar UI de Territorios', 'keyboard', Config.HideUIKey)

-- Eventos de actualización
RegisterNetEvent('ax_territory:startCaptureUI', function(territoryId, territory)
    captureInProgress[territoryId] = true
    territories[territoryId] = territory
    
    if playerInsideTerritory == territoryId then
        ShowTerritoryUI(territoryId, territory)
        
        -- Si estoy vivo y dentro, registrarme inmediatamente
        if not isDead then
            Wait(100)
            TriggerServerEvent('ax_territory:updateCaptureParticipant', territoryId, true, false)
        end
    end
end)

RegisterNetEvent('ax_territory:updateCaptureProgress', function(territoryId, progress, gangCounts, elapsed, totalTime)
    -- Solo actualizar si el jugador está dentro del territorio
    if playerInsideTerritory == territoryId then
        SendNUIMessage({
            action = 'updateProgress',
            territoryId = territoryId,
            progress = progress,
            gangCounts = gangCounts,
            elapsed = elapsed,
            totalTime = totalTime
        })
    end
end)

RegisterNetEvent('ax_territory:captureFinished', function(territoryId, winner, territory)
    captureInProgress[territoryId] = nil
    territories[territoryId] = territory
    
    SendNUIMessage({
        action = 'captureFinished',
        territoryId = territoryId,
        winner = winner
    })
    
    -- Actualizar inmediatamente el UI
    if playerInsideTerritory == territoryId then
        Wait(2000) -- Esperar 2 segundos para que el jugador vea el mensaje
        ShowTerritoryUI(territoryId, territory)
    end
end)

RegisterNetEvent('ax_territory:cooldownFinished', function(territoryId)
    if playerInsideTerritory == territoryId then
        ShowTerritoryUI(territoryId, territories[territoryId])
    end
end)

-- Detectar muerte
AddEventHandler('esx:onPlayerDeath', function()
    isDead = true
    
    -- Notificar al servidor que murió (deja de contar en captura)
    if playerInsideTerritory and captureInProgress[playerInsideTerritory] then
        TriggerServerEvent('ax_territory:updateCaptureParticipant', playerInsideTerritory, false, true)
    end
    
    -- NO ocultar el UI, el jugador puede seguir viendo
end)

AddEventHandler('esx:playerSpawned', function()
    Wait(1000)
    isDead = false
    
    -- NO notificar al servidor automáticamente
    -- El jugador debe salir y volver a entrar para contar de nuevo
end)

-- Evento para detectar respawn
RegisterNetEvent('esx:onPlayerSpawn', function()
    Wait(1000)
    isDead = false
end)