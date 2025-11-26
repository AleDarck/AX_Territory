ESX = exports["es_extended"]:getSharedObject()

local territories = {}
local isEditingZone = false
local currentZone = {
    coords = nil,
    width = 100.0,
    height = 100.0,
    rotation = 0.0
}
local currentTerritoryId = nil

-- Variables para sistema de captura
local currentZoneId = nil
local isUIVisible = true
local playerCanCapture = false
local playerJob = nil
local isPlayerDead = false
local territoryBlips = {}

-- Cargar territorios al iniciar el recurso
CreateThread(function()
    Wait(3000)
    
    -- Solicitar territorios al servidor
    TriggerServerEvent('ax_territory:requestTerritories')
    
    -- Esperar a que se verifique si puede capturar
    Wait(2000)
    
    -- Forzar actualización de blips
    if playerCanCapture or playerJob == 'police' then
        UpdateTerritoryBlips()
    end
end)

-- Evento cuando el jugador spawns
AddEventHandler('playerSpawned', function()
    Wait(2000)
    if playerCanCapture or playerJob == 'police' then
        TriggerServerEvent('ax_territory:requestTerritories')
        Wait(1000)
        UpdateTerritoryBlips()
    end
end)

-- Actualizar territorios
RegisterNetEvent('ax_territory:updateTerritories', function(newTerritories)
    territories = newTerritories
    for k, v in pairs(territories) do
        if not v.width then v.width = 100.0 end
        if not v.height then v.height = 100.0 end
        if not v.state then v.state = 'free' end
    end
    UpdateTerritoryBlips()
end)

-- Abrir menú administrativo
RegisterNetEvent('ax_territory:openAdminMenu', function()
    OpenAdminMenu()
end)

-- Función para abrir el menú principal
function OpenAdminMenu()
    lib.callback('ax_territory:getTerritories', false, function(territoryList)
        local options = {}
        
        -- Agregar opción de crear nuevo territorio
        table.insert(options, {
            title = 'Crear Nuevo Territorio',
            description = 'Crea un nuevo territorio',
            icon = 'plus',
            onSelect = function()
                CreateTerritoryDialog()
            end
        })
        
        -- Agregar separador si hay territorios
        if #territoryList > 0 then
            table.insert(options, {
                title = '────────────────────',
                disabled = true
            })
        end
        
        -- Listar territorios existentes
        for _, territory in ipairs(territoryList) do
            table.insert(options, {
                title = territory.name,
                description = 'ID: ' .. territory.id,
                icon = 'location-dot',
                onSelect = function()
                    OpenTerritoryOptions(territory)
                end
            })
        end
        
        lib.registerContext({
            id = 'ax_territory_admin',
            title = 'TERRITORIOS',
            options = options
        })
        
        lib.showContext('ax_territory_admin')
    end)
end

-- Diálogo para crear territorio
function CreateTerritoryDialog()
    local input = lib.inputDialog('Crear Territorio', {
        {
            type = 'input',
            label = 'Nombre del Territorio',
            placeholder = 'Ej: Zona Norte',
            required = true,
            min = 3,
            max = 50
        }
    })
    
    if input then
        TriggerServerEvent('ax_territory:createTerritory', input[1])
    else
        OpenAdminMenu()
    end
end

-- Opciones del territorio
function OpenTerritoryOptions(territory)
    local options = {
        {
            title = 'Zona',
            description = 'Configurar zona del territorio',
            icon = 'map',
            onSelect = function()
                StartZoneEditor(territory)
            end
        }
    }
    
    -- Solo mostrar botón de liberar si la zona está capturada
    if territory.owner and territory.state == 'captured' then
        table.insert(options, {
            title = 'Liberar Zona',
            description = 'Liberar este territorio capturado',
            icon = 'unlock',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Confirmar Liberacion',
                    content = 'Estas seguro que deseas liberar ' .. territory.name .. '?',
                    centered = true,
                    cancel = true
                })
                
                if confirm == 'confirm' then
                    TriggerServerEvent('ax_territory:freeTerritory', territory.id)
                else
                    OpenTerritoryOptions(territory)
                end
            end
        })
    end
    
    table.insert(options, {
        title = 'Eliminar',
        description = 'Eliminar este territorio',
        icon = 'trash',
        onSelect = function()
            local confirm = lib.alertDialog({
                header = 'Confirmar Eliminacion',
                content = 'Estas seguro que deseas eliminar ' .. territory.name .. '?',
                centered = true,
                cancel = true
            })
            
            if confirm == 'confirm' then
                TriggerServerEvent('ax_territory:deleteTerritory', territory.id)
            else
                OpenTerritoryOptions(territory)
            end
        end
    })
    
    lib.registerContext({
        id = 'ax_territory_options',
        title = territory.name,
        menu = 'ax_territory_admin',
        options = options
    })
    
    lib.showContext('ax_territory_options')
end

-- Iniciar editor de zona
function StartZoneEditor(territory)
    isEditingZone = true
    currentTerritoryId = territory.id
    
    if territory.coords.x ~= 0.0 or territory.coords.y ~= 0.0 then
        currentZone.coords = vector3(territory.coords.x, territory.coords.y, territory.coords.z)
        currentZone.width = territory.width
        currentZone.height = territory.height
        currentZone.rotation = territory.rotation
    else
        local playerPed = PlayerPedId()
        currentZone.coords = GetEntityCoords(playerPed)
        currentZone.width = 100.0
        currentZone.height = 100.0
        currentZone.rotation = 0.0
    end
    
    -- Usar BIGMAP en lugar del menú de pausa
    DisplayRadar(true)
    SetRadarBigmapEnabled(true, false)
    Wait(100)
    
    -- Congelar al jugador durante la edición
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)
    
    ESX.ShowNotification('Editor de zona iniciado')
    
    CreateThread(function()
        local editorBlip = nil
        
        while isEditingZone do
            Wait(0)
            
            -- Mantener bigmap activo
            if not IsBigmapActive() then
                SetRadarBigmapEnabled(true, false)
            end
            
            -- Remover blip anterior
            if editorBlip then
                RemoveBlip(editorBlip)
            end
            
            -- Crear nuevo blip de área
            editorBlip = AddBlipForArea(currentZone.coords.x, currentZone.coords.y, currentZone.coords.z, currentZone.width, currentZone.height)
            SetBlipRotation(editorBlip, math.floor(currentZone.rotation))
            SetBlipColour(editorBlip, Config.EditorBlip.color)
            SetBlipAlpha(editorBlip, Config.EditorBlip.alpha)
            
            -- Mostrar controles
            DisplayControls()
            
            -- Manejar controles
            HandleEditorControls()
        end
        
        -- Cerrar bigmap al salir
        SetRadarBigmapEnabled(false, false)
        if editorBlip then
            RemoveBlip(editorBlip)
        end
        -- Descongelar al jugador
        FreezeEntityPosition(PlayerPedId(), false)
    end)
end

-- Mostrar controles en pantalla
function DisplayControls()
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.0, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    
    local controls = {
        "Move: W, A, S, D",
        "Size: ARROW KEYS",
        "Rotate: E, Q",
        "Speed: LSHIFT",
        "Confirm: ENTER",
        "Cancel: ESC"
    }
    
    for i, text in ipairs(controls) do
        AddTextComponentString(text)
        DrawText(0.5, 0.85 + (i * 0.025))
    end
end

-- Manejar controles del editor
function HandleEditorControls()
    local speed = 1.0
    
    if IsControlPressed(0, 21) then
        speed = 3.0
    end
    
    if IsControlPressed(0, 32) then
        currentZone.coords = currentZone.coords + vector3(0.0, speed, 0.0)
    end
    if IsControlPressed(0, 33) then
        currentZone.coords = currentZone.coords + vector3(0.0, -speed, 0.0)
    end
    if IsControlPressed(0, 34) then
        currentZone.coords = currentZone.coords + vector3(-speed, 0.0, 0.0)
    end
    if IsControlPressed(0, 35) then
        currentZone.coords = currentZone.coords + vector3(speed, 0.0, 0.0)
    end
    
    if IsControlPressed(0, 174) then
        currentZone.width = math.max(currentZone.width - 2.0, 10.0)
    end
    if IsControlPressed(0, 175) then
        currentZone.width = math.min(currentZone.width + 2.0, 500.0)
    end
    
    if IsControlPressed(0, 172) then
        currentZone.height = math.min(currentZone.height + 2.0, 500.0)
    end
    if IsControlPressed(0, 173) then
        currentZone.height = math.max(currentZone.height - 2.0, 10.0)
    end
    
    if IsControlPressed(0, 38) then
        currentZone.rotation = (currentZone.rotation + 2.0) % 360
    end
    if IsControlPressed(0, 44) then
        currentZone.rotation = (currentZone.rotation - 2.0) % 360
    end
    
    if IsControlJustPressed(0, 191) then
        isEditingZone = false
        TriggerServerEvent('ax_territory:updateZone', currentTerritoryId, currentZone.coords, currentZone.width, currentZone.height, currentZone.rotation)
    end
    
    if IsControlJustPressed(0, 322) then
        isEditingZone = false
        ESX.ShowNotification('Editor de zona cancelado')
        OpenAdminMenu()
    end
end

-- SISTEMA DE CAPTURA

-- Verificar si el jugador puede capturar
CreateThread(function()
    Wait(2000)
    lib.callback('ax_territory:canCapture', false, function(canCapture, job)
        playerCanCapture = canCapture
        playerJob = job
        
        -- Cargar territorios si puede verlos
        if canCapture or job == 'police' then
            Wait(500)
            TriggerServerEvent('ax_territory:requestTerritories')
            
            -- Esperar respuesta y actualizar blips
            Wait(1000)
            UpdateTerritoryBlips()
        end
    end)
end)

-- Detectar muerte del jugador
CreateThread(function()
    while true do
        Wait(1000)
        local playerPed = PlayerPedId()
        local isDead = IsEntityDead(playerPed)
        
        if isDead and not isPlayerDead then
            isPlayerDead = true
            if currentZoneId then
                TriggerServerEvent('ax_territory:playerDied', currentZoneId)
            end
        elseif not isDead and isPlayerDead then
            isPlayerDead = false
        end
    end
end)

-- Función para verificar si el jugador está en una zona rotada
function IsPlayerInZone(zone)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    local origin = vector3(zone.coords.x, zone.coords.y, zone.coords.z)
    local r = zone.rotation * math.pi / 180
    local c1 = vector3(origin.x - zone.width / 2, origin.y + zone.height / 2, -100.0)
    local c2 = vector3(origin.x + zone.width / 2, origin.y - zone.height / 2, 100.0)
    
    local v = vector3(
        (playerCoords.x - origin.x) * math.cos(r) + (playerCoords.y - origin.y) * math.sin(r) + origin.x,
        (playerCoords.x - origin.x) * math.sin(r) - (playerCoords.y - origin.y) * math.cos(r) + origin.y,
        playerCoords.z
    )
    
    return ((v.x < c1.x and v.x > c2.x) or (v.x > c1.x and v.x < c2.x)) and 
           ((v.y < c1.y and v.y > c2.y) or (v.y > c1.y and v.y < c2.y)) and 
           ((v.z < c1.z and v.z > c2.z) or (v.z > c1.z and v.z < c2.z))
end

-- Thread para detectar entrada/salida de zonas
CreateThread(function()
    while true do
        Wait(1000)
        
        if not playerCanCapture and playerJob ~= 'police' then
            Wait(5000)
            goto continue
        end
        
        local foundZone = nil
        
        for id, zone in pairs(territories) do
            if zone.coords and (zone.coords.x ~= 0.0 or zone.coords.y ~= 0.0) then
                if IsPlayerInZone(zone) then
                    foundZone = id
                    break
                end
            end
        end
        
        if foundZone ~= currentZoneId then
            if currentZoneId then
                -- Salió de zona
                TriggerServerEvent('ax_territory:exitZone', currentZoneId)
                if playerCanCapture then
                    TriggerServerEvent('ax_territory:updatePresence', currentZoneId, false)
                end
                SendNUIMessage({
                    action = 'hideUI'
                })
            end
            
            if foundZone then
                -- Entró a zona
                currentZoneId = foundZone
                TriggerServerEvent('ax_territory:enterZone', foundZone)
                if playerCanCapture and not isPlayerDead then
                    TriggerServerEvent('ax_territory:updatePresence', foundZone, true)
                end
            else
                currentZoneId = nil
            end
        end
        
        ::continue::
    end
end)

-- Actualizar UI de zona
RegisterNetEvent('ax_territory:updateZoneUI', function(zoneData)
    if not isUIVisible then return end
    
    SendNUIMessage({
        action = 'showUI',
        data = zoneData,
        canCapture = playerCanCapture,
        isPolice = playerJob == 'police',
        gangColors = Config.GangJobs
    })
end)

-- Ocultar UI
RegisterNetEvent('ax_territory:hideZoneUI', function()
    SendNUIMessage({
        action = 'hideUI'
    })
end)

-- Actualizar progreso de captura
RegisterNetEvent('ax_territory:updateCaptureProgress', function(zoneId, captureData)
    if not isUIVisible or currentZoneId ~= zoneId then return end
    
    SendNUIMessage({
        action = 'updateProgress',
        data = captureData,
        gangColors = Config.GangJobs
    })
end)

-- Toggle UI con tecla F6
CreateThread(function()
    while true do
        Wait(0)
        
        -- Detectar tecla F6 (167)
        if IsControlJustPressed(0, 167) then
            isUIVisible = not isUIVisible
            
            if not isUIVisible then
                SendNUIMessage({
                    action = 'hideUI'
                })
            elseif currentZoneId then
                TriggerServerEvent('ax_territory:enterZone', currentZoneId)
            end
        end
    end
end)

-- Solicitar captura de territorio libre
RegisterNetEvent('ax_territory:requestCapture', function()
    if currentZoneId then
        local territory = territories[currentZoneId]
        if territory and territory.state == 'free' then
            TriggerServerEvent('ax_territory:startCapture', currentZoneId)
        else
            ESX.ShowNotification('Este territorio no esta disponible para capturar')
        end
    else
        ESX.ShowNotification('Debes estar dentro del territorio para capturarlo')
    end
end)

-- Solicitar ataque de territorio
RegisterNetEvent('ax_territory:requestAttack', function()
    if currentZoneId then
        TriggerServerEvent('ax_territory:confirmAttack', currentZoneId)
    else
        ESX.ShowNotification('Debes estar dentro del territorio para atacarlo')
    end
end)

-- Actualizar blips de territorios
function UpdateTerritoryBlips()
    -- Solo si el jugador puede ver territorios
    if not playerCanCapture and playerJob ~= 'police' then
        return
    end
    
    -- Eliminar blips existentes
    for _, blip in pairs(territoryBlips) do
        RemoveBlip(blip)
    end
    territoryBlips = {}
    
    -- Crear nuevos blips
    for _, territory in pairs(territories) do
        if territory.coords and (territory.coords.x ~= 0.0 or territory.coords.y ~= 0.0) then
            local blip = AddBlipForArea(territory.coords.x, territory.coords.y, territory.coords.z, territory.width, territory.height)
            SetBlipRotation(blip, math.floor(territory.rotation))
            
            -- Color según estado
            if not territory.state or territory.state == 'free' then
                SetBlipColour(blip, 0) -- Blanco
                SetBlipAlpha(blip, 128)
            elseif territory.state == 'contested' then
                SetBlipColour(blip, 1) -- Rojo para disputa
                SetBlipAlpha(blip, 128)
            elseif territory.state == 'captured' and territory.owner then
                local gangData = Config.GangJobs[territory.owner]
                if gangData then
                    SetBlipColour(blip, gangData.blipColor)
                    SetBlipAlpha(blip, 128)
                else
                    SetBlipColour(blip, 0)
                    SetBlipAlpha(blip, 128)
                end
            else
                SetBlipColour(blip, 0) -- Blanco por defecto
                SetBlipAlpha(blip, 128)
            end
            
            territoryBlips[territory.id] = blip
        end
    end
end

-- Thread para hacer parpadear zonas en disputa
CreateThread(function()
    local blinkState = true
    while true do
        Wait(500)
        
        for id, territory in pairs(territories) do
            if territory.state == 'contested' and territoryBlips[id] then
                if blinkState then
                    SetBlipAlpha(territoryBlips[id], 220)
                else
                    SetBlipAlpha(territoryBlips[id], 60)
                end
            end
        end
        
        blinkState = not blinkState
    end
end)