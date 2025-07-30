local RSGCore = exports['rsg-core']:GetCoreObject()
local registrationZoneId = nil
local spawnedGuards = {}
local isInGame = false
local registrationBlip = nil
local finishBlip = nil
local countdownStateMachine = nil
local isRedLightActive = false
local barrelsSpawned = false
local gameTimerThread = nil
local gpsRoute = nil
local gpsActive = false
local lastGpsCoords = nil
function UpdateGPS(coords, showNotification)
    if lastGpsCoords and #(vector3(coords.x, coords.y, coords.z) - vector3(lastGpsCoords.x, lastGpsCoords.y, lastGpsCoords.z)) < 5.0 then
        return
    end

    if gpsActive then
        ClearGpsMultiRoute()
        gpsActive = false
    end
    
    StartGpsMultiRoute(GetHashKey("COLOR_RED"), true, true)
    AddPointToGpsMultiRoute(coords.x, coords.y, coords.z)
    SetGpsMultiRouteRender(true)
    gpsActive = true
    
    if gpsRoute then
        RemoveBlip(gpsRoute)
    end
    gpsRoute = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z)
    if gpsRoute then
        Citizen.InvokeNative(0x74F74D3207ED525C, gpsRoute, -1103135225, 1)
        Citizen.InvokeNative(0x9CB1A1623062F402, gpsRoute, 'Finish Line')
    end
    
    lastGpsCoords = coords
    
    if showNotification then
        lib.notify({
            title = 'Game Update',
            description = 'Finish line location marked on your map',
            type = 'inform',
            duration = 4000
        })
    end
end


function ClearDeliveryGPS()
    if gpsActive then
        ClearGpsMultiRoute()
        gpsActive = false
    end
    if gpsRoute then
        RemoveBlip(gpsRoute)
        gpsRoute = nil
    end
    lastGpsCoords = nil
end


RegisterNetEvent('redlight:client:setGPS', function(coords)
    if not coords or not coords.x or not coords.y or not coords.z then
        return
    end
    UpdateGPS(coords, true)
end)


RegisterNetEvent('redlight:client:clearGPS', function()
    ClearDeliveryGPS()
end)
function StartTotalGameTimer()
    if gameTimerThread then
        TerminateThread(gameTimerThread)
        gameTimerThread = nil
    end

    gameTimerThread = CreateThread(function()
        local remaining = Config.MaxGameTime or 120
        while remaining > 0 and isInGame do
            Wait(1000)
            remaining -= 1
        end

        if isInGame then
            TriggerEvent('redlight:client:gameEnded') 
            lib.notify({
                title = "Time's Up",
                description = "Game over! No one made it in time.",
                type = "warning"
            })
        end
    end)
end



local function MonitorKeypresses()
    
    local movementKeys = {
        0x8FD015D8, -- W (FORWARD)
        0xD27782E3, -- S (BACKWARD)
        0x7065027D, -- A (LEFT)
        0xB4E465B4, -- D (RIGHT)
        0x8FFC75D6, -- SHIFT (SPRINT)
    }

    CreateThread(function()
        while isRedLightActive and isInGame do
            for _, key in ipairs(movementKeys) do
                if IsControlJustPressed(0, key) or IsControlPressed(0, key) then
                   
                    TriggerServerEvent('redlight:server:playerMovedDuringRedLight')
                    break
                end
            end
            Wait(0) 
        end
    end)
end

local function SpawnGuardNPC(model, coords)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end
    
    if HasModelLoaded(model) then
        local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
        local finalZ = foundGround and groundZ or coords.z
        
        local guard = CreatePed(model, coords.x, coords.y, finalZ, coords.w, false, false, 0, 0)
        if guard and guard ~= 0 then
            SetEntityCoords(guard, coords.x, coords.y, finalZ, false, false, false, false)
            SetEntityHeading(guard, coords.w)
            SetEntityAlpha(guard, 0, false)
            SetRandomOutfitVariation(guard, true)
            SetEntityCanBeDamaged(guard, false)
            SetEntityInvincible(guard, true)
            SetBlockingOfNonTemporaryEvents(guard, true)
            SetPedCanBeTargetted(guard, false)
            
            GiveWeaponToPed(guard, GetHashKey("weapon_sniperrifle_carcano"), 50, false, true)
            
            for i = 0, 255, 51 do
                Wait(50)
                SetEntityAlpha(guard, i, false)
            end
            
            SetModelAsNoLongerNeeded(model)
            return guard
        end
    end
    return nil
end

local function SpawnGameGuards()
    if not Config.GuardPositions then return end
    
    for k, guardData in pairs(Config.GuardPositions) do
        if not spawnedGuards[k] then
            local guard = SpawnGuardNPC(guardData.model, guardData.coords)
            if guard then
                spawnedGuards[k] = { guard = guard, coords = guardData.coords }
            end
        end
    end
end

local function CleanupGuards()
    for k, v in pairs(spawnedGuards) do
        if DoesEntityExist(v.guard) then
            for i = 255, 0, -51 do
                Wait(50)
                SetEntityAlpha(v.guard, i, false)
            end
            DeletePed(v.guard)
        end
        spawnedGuards[k] = nil
    end
end

local function MakeGuardsAttackPlayer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local attackRange = 70.0 
    local accuracy = 100
    local shootRate = 200

    

    

    for k, v in pairs(spawnedGuards) do
        if DoesEntityExist(v.guard) then
            local guardCoords = GetEntityCoords(v.guard)
            local distance = #(playerCoords - guardCoords)
            
            if distance <= attackRange then
                TaskTurnPedToFaceEntity(v.guard, playerPed, 1000)
                Wait(100)
                
                TaskCombatPed(v.guard, playerPed, 0, 16)
                SetPedCombatRange(v.guard, 2)
                SetPedAccuracy(v.guard, accuracy)
                SetPedShootRate(v.guard, shootRate)
                SetPedCombatAttributes(v.guard, 46, true) 
                SetPedCombatAttributes(v.guard, 5, true)  
            end
        end
    end
end

local function StopGuardsAttacking()
    for k, v in pairs(spawnedGuards) do
        if DoesEntityExist(v.guard) then
            ClearPedTasks(v.guard)
            SetPedCombatAttributes(v.guard, 46, false)
            SetPedCombatAttributes(v.guard, 5, false)
            SetPedAccuracy(v.guard, 0)
            SetPedShootRate(v.guard, 0)
            TaskTurnPedToFaceCoord(v.guard, v.coords.x, v.coords.y, v.coords.z, 1000)
        end
    end
end

local function CleanupCountdown()
    if countdownStateMachine then
        if UiStateMachineExists(countdownStateMachine) then
            UiStateMachineDestroy(countdownStateMachine)
        end
        countdownStateMachine = nil
    end

    if DatabindingGetDataContainerFromPath and DatabindingIsEntryValid and DatabindingGetDataBool and DatabindingWriteDataBool and DatabindingGetDataString then
        local container = DatabindingGetDataContainerFromPath("MPCountdown")
        if container and DatabindingIsEntryValid(container) then
            local dataString = DatabindingGetDataString(container, "Timer")
            if DatabindingIsEntryValid(dataString) then
                DatabindingRemoveDataEntry(dataString)
            end
            local dataBoolean = DatabindingGetDataBool(container, "showTimer")
            if DatabindingIsEntryValid(dataBoolean) then
                DatabindingWriteDataBool(dataBoolean, false)
                DatabindingRemoveDataEntry(dataBoolean)
            end
            DatabindingRemoveDataEntry(container)
        end
    else
        
    end
end

local function StartGameCountdown()
    local count = 10

    if DatabindingAddDataContainerFromPath and DatabindingAddDataString and DatabindingAddDataBool and DatabindingWriteDataString and DatabindingWriteDataBool then
        local container = DatabindingAddDataContainerFromPath("", "MPCountdown")
        local dataString = DatabindingAddDataString(container, "Timer", tostring(count))
        local dataBoolean = DatabindingAddDataBool(container, "showTimer", true)
        countdownStateMachine = 190275865

        CreateThread(function()
            for i = count, 0, -1 do
                if i == 0 then
                    DatabindingWriteDataBool(dataBoolean, false)
                    CleanupCountdown()
                    break
                end
                DatabindingWriteDataString(dataString, tostring(i))
                Wait(1000)
            end

            if lib and lib.notify then
                lib.notify({
                    title = 'Game Started!',
                    description = 'Red Light Green Light has begun!',
                    type = 'success',
                    duration = 1000
                })
            end

            StartTotalGameTimer() 
        end)
    else
        CreateThread(function()
            for i = count, 0, -1 do
                if i == 0 then
                    CleanupCountdown()
                    break
                end
                if lib and lib.notify then
                    lib.notify({
                        title = 'Game Starting!',
                        description = 'Starting in ' .. tostring(i) .. ' seconds',
                        type = 'inform',
                        duration = 1000
                    })
                end
                Wait(1000)
            end

            if lib and lib.notify then
                lib.notify({
                    title = 'Game Started!',
                    description = 'Red Light Green Light has begun!',
                    type = 'success',
                    duration = 1000
                })
            end

            StartTotalGameTimer() 
        end)
    end
end
local function CreateRegistrationBlip()
    if not Config.RegistrationObject or not Config.RegistrationObject.coords then
        return
    end
    
    local coords = Config.RegistrationObject.coords
    registrationBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z)
    if registrationBlip then
        Citizen.InvokeNative(0x74F74D3207ED525C, registrationBlip, GetHashKey("blip_code_waypoint"), true)
        Citizen.InvokeNative(0x4B8F743A4A6D2FF8, registrationBlip, 0.8)
        Citizen.InvokeNative(0x9CB1A1623062F402, registrationBlip, "Red Light Green Light")
        Citizen.InvokeNative(0x662D364ABF16DE2F, registrationBlip, GetHashKey("BLIP_MODIFIER_MP_COLOR_2"))
        Citizen.InvokeNative(0x9029B2F3DA924928, registrationBlip, true)
    end
end

local function CreateFinishBlip()
    if not Config.FinishLine then
        return
    end
    
    local coords = Config.FinishLine
    finishBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z)
    if finishBlip then
        Citizen.InvokeNative(0x74F74D3207ED525C, finishBlip, GetHashKey("blip_code_waypoint"), true)
        Citizen.InvokeNative(0x4B8F743A4A6D2FF8, finishBlip, 0.8)
        Citizen.InvokeNative(0x9CB1A1623062F402, finishBlip, "Finish Line")
        Citizen.InvokeNative(0x662D364ABF16DE2F, finishBlip, GetHashKey("BLIP_MODIFIER_MP_COLOR_3"))
        Citizen.InvokeNative(0x9029B2F3DA924928, finishBlip, true)
    end
end

local function RemoveRegistrationBlip()
    if registrationBlip then
        Citizen.InvokeNative(0xF83D0FEBE75E62C9, registrationBlip)
        registrationBlip = nil
    end
end

local function RemoveFinishBlip()
    if finishBlip then
        Citizen.InvokeNative(0xF83D0FEBE75E62C9, finishBlip)
        finishBlip = nil
    end
end
local function ResetGameClientState()
    isInGame = false
    isRedLightActive = false

    CleanupGuards()
    CleanupCountdown()
    RemoveRegistrationBlip()
    RemoveFinishBlip()

    if registrationZoneId then
        exports.ox_target:removeZone(registrationZoneId)
        registrationZoneId = nil
    end

    if gameTimerThread then
		TerminateThread(gameTimerThread)
		gameTimerThread = nil
	end


    
    if lib and lib.hideContext then
        lib.hideContext('redlight_menu')
        lib.hideContext('redlight_rules')
    end

    
    CreateThread(function()
        Wait(500) 
        TriggerEvent('redlight:client:setupRegistration', true) 
    end)
end
RegisterNetEvent('redlight:client:setupRegistration')
AddEventHandler('redlight:client:setupRegistration', function(force)
    
    if registrationObjectId and DoesEntityExist(registrationObjectId) then
		DeleteEntity(registrationObjectId)
		registrationObjectId = nil
	end

    if not Config or not Config.RegistrationObject or not Config.RegistrationObject.model or not Config.RegistrationObject.coords then
        lib.notify({
            title = "Error",
            description = "Invalid configuration data.",
            type = 'error'
        })
        return
    end

    local coords = Config.RegistrationObject.coords
    local model = GetHashKey(Config.RegistrationObject.model)

    RequestModel(model)
    local timeout = 5000
    local startTime = GetGameTimer()
    while not HasModelLoaded(model) do
        Wait(100)
        if GetGameTimer() - startTime > timeout then
            lib.notify({
                title = "Error",
                description = "Failed to load object model.",
                type = 'error'
            })
            return
        end
    end

    
    local obj = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    if obj and obj ~= 0 then
        PlaceObjectOnGroundProperly(obj)
        SetEntityHeading(obj, coords.w or 0.0)
        SetModelAsNoLongerNeeded(model)

       
        SetEntityAsMissionEntity(obj, true, true)
        FreezeEntityPosition(obj, true)

        registrationObjectId = obj

       
        if registrationZoneId then
            exports.ox_target:removeZone(registrationZoneId)
        end

        registrationZoneId = exports.ox_target:addBoxZone({
            coords = vector3(coords.x, coords.y, coords.z),
            size = vector3(5.0, 5.0, 3.0),
            rotation = coords.w or 0.0,
            debug = false,
            options = {
                {
                    name = 'redlight_registration',
                    event = 'redlight:client:openMenu',
                    icon = 'fas fa-gamepad',
                    label = Config.RegistrationObject.label or 'Red Light Green Light Registration',
                    distance = 5.0
                }
            }
        })

        CreateRegistrationBlip()
    else
        lib.notify({
            title = "Error",
            description = "Failed to create object.",
            type = 'error'
        })
    end
end)



RegisterNetEvent('redlight:client:openMenu', function()
    TriggerServerEvent('redlight:server:getGameStatus')
end)

RegisterNetEvent('redlight:client:updateGameStatus', function(status)
    local options = {}
    
    if status.active then
        table.insert(options, {
            title = 'Game Status: Active (' .. string.upper(status.state) .. ')',
            description = 'Players: ' .. status.players .. '/' .. status.maxPlayers,
            icon = 'play-circle',
            disabled = true
        })
    else
        table.insert(options, {
            title = 'Game Status: Waiting for Players',
            description = 'Players: ' .. status.players .. '/' .. status.maxPlayers,
            icon = 'users',
            disabled = true
        })
        
        if status.autoStartActive then
            table.insert(options, {
                title = 'Auto-Start Timer',
                description = 'Game starts in ' .. status.autoStartTimer .. ' seconds',
                icon = 'clock',
                disabled = true
            })
        end
        
        if not status.isParticipant then
            table.insert(options, {
                title = 'Join Game',
                description = 'Entry Fee: $' .. status.entryFee .. ' | Winner Prize: $' .. status.winnerPrize,
                icon = 'sign-in-alt',
                event = 'redlight:client:joinGame'
            })
        else
            table.insert(options, {
                title = 'Leave Game',
                description = 'Refund: $' .. status.entryFee,
                icon = 'sign-out-alt',
                event = 'redlight:client:leaveGame'
            })
        end
        
        local PlayerData = RSGCore.Functions.GetPlayerData()
        local isAdmin = false
        
        if PlayerData then
            if PlayerData.job and PlayerData.job.name == 'admin' then
                isAdmin = true
            elseif PlayerData.job and PlayerData.job.grade and PlayerData.job.grade.level >= 90 then
                isAdmin = true
            elseif PlayerData.group and (PlayerData.group == 'admin' or PlayerData.group == 'god') then
                isAdmin = true
            end
        end
        
        if isAdmin then
            table.insert(options, {
                title = 'Force Start Game (Admin)',
                description = 'Start the game immediately',
                icon = 'rocket',
                event = 'redlight:client:forceStart'
            })
        end
    end
    
    table.insert(options, {
        title = 'Game Rules',
        description = 'Learn how to play Red Light Green Light',
        icon = 'question-circle',
        event = 'redlight:client:showRules'
    })
    
    if lib and lib.registerContext then
        lib.registerContext({
            id = 'redlight_menu',
            title = 'Red Light Green Light',
            options = options
        })
        
        lib.showContext('redlight_menu')
    else
        TriggerEvent('ox_lib:notify', {
            title = 'Red Light Green Light',
            description = 'Menu system unavailable. Check ox_lib installation.',
            type = 'error'
        })
    end
end)

RegisterNetEvent('redlight:client:showRules', function()
    if not lib or not lib.registerContext then
        return
    end
    
    lib.registerContext({
        id = 'redlight_rules',
        title = 'Game Rules',
        menu = 'redlight_menu',
        options = {
            {
                title = 'Objective',
                description = 'Be the first player to reach the finish line',
                icon = 'flag-checkered',
                disabled = true
            },
            {
                title = 'Green Light',
                description = 'You can move freely when green light is active',
                icon = 'play',
                disabled = true
            },
            {
                title = 'Red Light',
                description = 'STOP MOVING! Pressing movement keys will trigger guards!',
                icon = 'stop',
                disabled = true
            },
            {
                title = 'Guards',
                description = 'Armed guards are watching. Pressing movement keys during red light = elimination',
                icon = 'crosshairs',
                disabled = true
            },
            {
                title = 'Victory',
                description = 'First to cross the finish line wins the prize!',
                icon = 'trophy',
                disabled = true
            }
        }
    })
    
    lib.showContext('redlight_rules')
end)

RegisterNetEvent('redlight:client:joinGame', function()
    TriggerServerEvent('redlight:server:joinGame')
end)

RegisterNetEvent('redlight:client:leaveGame', function()
    TriggerServerEvent('redlight:server:leaveGame')
end)

RegisterNetEvent('redlight:client:forceStart', function()
    TriggerServerEvent('redlight:server:forceStart')
end)

RegisterNetEvent('redlight:client:teleportToStart', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
    isInGame = true
    SpawnGameGuards()
    CreateFinishBlip()
end)

RegisterNetEvent('redlight:client:startCountdown', function()
    StartGameCountdown()
end)

RegisterNetEvent('redlight:client:setState', function(state, timer)
    if not lib or not lib.notify then
        return
    end
    
    if state == 'redlight' then
        isRedLightActive = true
        MonitorKeypresses() 
        lib.notify({
            title = 'RED LIGHT!',
            description = 'STOP! Do not press movement keys!',
            type = 'error',
            duration = math.floor(timer * 1000)
        })
    elseif state == 'greenlight' then
        isRedLightActive = false
        StopGuardsAttacking()
        lib.notify({
            title = 'GREEN LIGHT!',
            description = 'GO GO GO!',
            type = 'success',
            duration = math.floor(timer * 1000)
        })
    end
end)

RegisterNetEvent('redlight:client:eliminate', function(reason)
    isInGame = false
    if reason and reason:find("red light") then
        MakeGuardsAttackPlayer()
    end
    ResetGameClientState()
end)

RegisterNetEvent('redlight:client:gameEnded', function()
    ResetGameClientState()
end)

RegisterNetEvent('redlight:client:playerEliminated', function(playerName, reason)
    if lib and lib.notify then
        lib.notify({
            title = 'Player Eliminated',
            description = playerName .. ' - ' .. reason,
            type = 'warning',
            duration = 1000
        })
    end
end)

RegisterNetEvent('redlight:client:guardsAttack', function()
    MakeGuardsAttackPlayer()
    
    CreateThread(function()
        local playerPed = PlayerPedId()
        local startHealth = GetEntityHealth(playerPed)
        
        while GetEntityHealth(playerPed) > 0 and GetEntityHealth(playerPed) <= startHealth do
            Wait(100)
        end
        
        if GetEntityHealth(playerPed) <= 0 then
            TriggerServerEvent('redlight:server:playerKilledByGuards', "Attacked by guards for moving during red light")
        end
    end)
end)

RegisterNetEvent('redlight:client:gameEnded', function()
    isInGame = false
    isRedLightActive = false
    CleanupGuards()
    CleanupCountdown()
    RemoveRegistrationBlip()
    RemoveFinishBlip()
    
    if registrationZoneId then
        exports.ox_target:removeZone(registrationZoneId)
        registrationZoneId = nil
    end
    
    if registrationObjectId then
        if DoesEntityExist(registrationObjectId) then
            DeleteEntity(registrationObjectId)
        end
        registrationObjectId = nil
    end
    
    if lib and lib.hideContext then
        lib.hideContext('redlight_menu')
        lib.hideContext('redlight_rules')
    end
end)


AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    CreateThread(function()
        Wait(1000)
        if not barrelsSpawned then
            TriggerEvent('redlight:client:setupRegistration', true)
            barrelsSpawned = true
        end
    end)
end)


AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CleanupGuards()
    CleanupCountdown()
    RemoveRegistrationBlip()
    RemoveFinishBlip()
    
    if registrationZoneId then
        exports.ox_target:removeZone(registrationZoneId)
        registrationZoneId = nil
    end
    
    
end)