local ESX = exports['es_extended']:getSharedObject()
local territories = {}
local editingZone = false
local currentZoneData = nil
local playerInsideTerritory = nil
local captureInProgress = {}
local uiVisible = true
local isDead = false

-- Locales
local Locale = {
    ['create_territory'] = 'Crear Nuevo Territorio',
    ['territory_name'] = 'Nombre del Territorio',
    ['territory_name_desc'] = 'Ingresa el nombre para el nuevo territorio',
    ['edit_zone'] = 'Editar Zona',
    ['delete_territory'] = 'Eliminar',
    ['confirm_delete'] = 'Confirmar Eliminacion',
    ['confirm_delete_desc'] = 'Estas seguro de eliminar este territorio?',
    ['zone_editor_controls'] = 'Move: 8,4,5,6 | Cuadrado: 1,3 | Ancho: K,L | Largo: N,M | Rotar: 7,9 | Speed: SHIFT | OK: ENTER | Cancel: ESC',
    ['not_gang_member'] = 'No eres miembro de una banda',
    ['menu_title'] = 'TERRITORIOS',
    ['free_zone'] = 'Liberar Zona'
}

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
    while not ESX.IsPlayerLoaded() do
        Wait(500)
    end
    
    Wait(2000) -- Esperar un poco más para asegurar carga completa
    
    ESX.TriggerServerCallback('ax_territory:getTerritories', function(data)
        territories = data
        UpdateTerritoryBlips()
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
            if playerData.job.grade == rank then
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
        title = Locale['create_territory'],
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
        title = Locale['menu_title'],
        options = elements
    })
    
    lib.showContext('ax_territory_admin')
end

function CreateTerritoryDialog()
    local input = lib.inputDialog(Locale['create_territory'], {
        {
            type = 'input',
            label = Locale['territory_name'],
            description = Locale['territory_name_desc'],
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
                title = Locale['edit_zone'],
                icon = 'edit',
                onSelect = function()
                    StartZoneEditor(territoryId, territory)
                end
            },
            {
                title = 'Cambiar Blip',
                icon = 'map-pin',
                onSelect = function()
                    OpenBlipSelector(territoryId, territory)
                end
            },
            {
                title = Locale['free_zone'],
                icon = 'unlock',
                onSelect = function()
                    TriggerServerEvent('ax_territory:freeZone', territoryId)
                end
            },
            {
                title = Locale['delete_territory'],
                icon = 'trash',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = Locale['confirm_delete'],
                        content = Locale['confirm_delete_desc'],
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

function OpenBlipSelector(territoryId, territory)
    local elements = {}
    
    for _, blipData in ipairs(Config.AvailableBlips) do
        table.insert(elements, {
            title = blipData.name,
            icon = blipData.sprite and 'map-marker-alt' or 'ban',
            description = blipData.sprite and ('Sprite ID: ' .. blipData.sprite) or 'Sin blip adicional',
            onSelect = function()
                TriggerServerEvent('ax_territory:setCustomBlip', territoryId, blipData.sprite)
            end
        })
    end
    
    lib.registerContext({
        id = 'ax_territory_blip_selector',
        title = 'Seleccionar Blip',
        menu = 'ax_territory_options',
        options = elements
    })
    
    lib.showContext('ax_territory_blip_selector')
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
    
    ESX.ShowNotification(Locale['zone_editor_controls'])
    
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

            if IsDisabledControlPressed(0, 311) then -- K (reducir ancho)
                currentZoneData.size.width = math.max(10.0, currentZoneData.size.width - sizeSpeed * speedMultiplier)
            end
            
            if IsDisabledControlPressed(0, 7) then -- L (aumentar ancho)
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

-- Mostrar territorios en el mapa
local territoryBlips = {}

function UpdateTerritoryBlips()
    -- Limpiar blips anteriores
    for _, blipData in pairs(territoryBlips) do
        if type(blipData) == 'table' then
            if blipData.area then RemoveBlip(blipData.area) end
            if blipData.custom then RemoveBlip(blipData.custom) end
        else
            RemoveBlip(blipData)
        end
    end
    territoryBlips = {}
    
    if not CanViewTerritories() then return end
    
    -- Crear nuevos blips
    for id, territory in pairs(territories) do
        if territory.coords.x ~= 0 then
            -- Blip de área (cuadrado)
            local areaBlip = AddBlipForArea(
                territory.coords.x,
                territory.coords.y,
                territory.coords.z,
                territory.size.width,
                territory.size.height
            )
            
            SetBlipRotation(areaBlip, math.floor(territory.rotation))
            
            -- Color según estado y dueño
            if territory.status == 1 or not territory.owner then
                SetBlipColour(areaBlip, 0)
                SetBlipAlpha(areaBlip, 100)
            elseif territory.status == 2 then
                SetBlipColour(areaBlip, 1)
                SetBlipAlpha(areaBlip, 150)
            elseif territory.status == 3 and territory.owner then
                local gangColor = GetGangBlipColor(territory.owner)
                SetBlipColour(areaBlip, gangColor)
                SetBlipAlpha(areaBlip, 150)
            end
            
            territoryBlips[id] = {area = areaBlip}
            
            -- Blip personalizado (si existe)
            if territory.custom_blip then
                local customBlip = AddBlipForCoord(
                    territory.coords.x,
                    territory.coords.y,
                    territory.coords.z
                )
                
                SetBlipSprite(customBlip, territory.custom_blip)
                SetBlipScale(customBlip, 0.8)
                SetBlipColour(customBlip, 1)
                SetBlipAsShortRange(customBlip, true)
                
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentSubstringPlayerName(territory.name)
                EndTextCommandSetBlipName(customBlip)
                
                territoryBlips[id].custom = customBlip
            end
        end
    end
end

function GetGangBlipColor(gangName)
    if Config.Gangs[gangName] and Config.Gangs[gangName].blipColor then
        return Config.Gangs[gangName].blipColor
    end
    return 0 -- Blanco por defecto
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
    while not ESX.IsPlayerLoaded() do
        Wait(500)
    end
    
    Wait(3000)
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
        ESX.ShowNotification(Locale['not_gang_member'])
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
        ESX.ShowNotification(Locale['not_gang_member'])
        return
    end
    
    local territory = territories[playerInsideTerritory]
    if territory.status ~= 3 or not territory.owner then
        ESX.ShowNotification('Este territorio no esta capturado')
        return
    end
    
    -- Verificar cooldown en el servidor
    ESX.TriggerServerCallback('ax_territory:canAttack', function(canAttack, message)
        if not canAttack then
            ESX.ShowNotification(message)
            return
        end
        
        TriggerServerEvent('ax_territory:startCapture', playerInsideTerritory, true)
        
        -- Notificar inmediatamente al servidor que estás capturando
        Wait(500)
        if not isDead then
            TriggerServerEvent('ax_territory:updateCaptureParticipant', playerInsideTerritory, true, false)
        end
    end, playerInsideTerritory)
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

-- Thread alternativo para detectar la tecla personalizada
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, Config.HideUIKeyCode) then
            ExecuteCommand('toggleTerritoryUI')
        end
    end
end)

-- Evento para recargar territorios manualmente
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    Wait(3000)
    ESX.TriggerServerCallback('ax_territory:getTerritories', function(data)
        territories = data
        UpdateTerritoryBlips()
    end)
end)

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

-- Actualizar blips cuando cambia el job
RegisterNetEvent('esx:setJob', function(job)
    Wait(1000)
    UpdateTerritoryBlips()
end)