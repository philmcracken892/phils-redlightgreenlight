local RSGCore = exports['rsg-core']:GetCoreObject()

local gameActive = false
local participants = {}
local gameState = "waiting"
local gameTimer = 0
local eliminatedPlayers = {}
local autoStartTimer = 0
local autoStartActive = false
local registrationObjectId = nil

local function ShowNotification(source, message, duration)
    TriggerClientEvent('rNotify:ShowObjective', source, message, duration or 1000)
end

local function ShowNotificationAll(message, duration)
    for playerId in pairs(participants) do
        ShowNotification(playerId, message, duration)
    end
end

local function IsGameMaster(source)
    return RSGCore.Functions.HasPermission(source, Config.GameMasterGroup)
end

local function GetPlayerCount()
    local count = 0
    for _ in pairs(participants) do
        count = count + 1
    end
    return count
end

local function GetDistance(pos1, pos2)
    return #(vector3(pos1.x, pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
end

local function CheckGameEnd()
    local remainingPlayers = GetPlayerCount()
    
    if remainingPlayers <= 0 then
        EndGame(false)
    elseif remainingPlayers == 1 then
        EndGame(true)
    end
end

local function EliminatePlayer(source, reason)
    if participants[source] then
        local Player = RSGCore.Functions.GetPlayer(source)
        if Player then
            eliminatedPlayers[source] = true
            participants[source] = nil
            
            ShowNotification(source, Config.Messages.eliminated .. ' Reason: ' .. reason, 'error')
            TriggerClientEvent('redlight:client:eliminate', source, reason)
            TriggerClientEvent('redlight:client:clearGPS', source) -- Clear GPS route
            
            local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            for playerId in pairs(participants) do
                ShowNotification(playerId, playerName .. ' has been eliminated!', 'warning')
                TriggerClientEvent('redlight:client:playerEliminated', playerId, playerName, reason)
            end
            
            CheckGameEnd()
        end
    end
end

local function CheckFinishLine()
    for playerId, data in pairs(participants) do
        local playerPed = GetPlayerPed(playerId)
        local playerPos = GetEntityCoords(playerPed)
        
        if GetDistance(playerPos, Config.FinishLine) <= 5.0 then
            local Player = RSGCore.Functions.GetPlayer(playerId)
            if Player then
                local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
                ShowNotificationAll('?? ' .. playerName .. ' has won the game!', 'success')
                
                Player.Functions.AddMoney('cash', Config.WinnerPrize)
                ShowNotification(playerId, Config.Messages.winner .. ' You won $' .. Config.WinnerPrize, 'success')
                
                EndGame(true, playerId)
                return
            end
        end
    end
end

function StartRedLight()
    gameState = "redlight"
    gameTimer = Config.RedLightDuration
    
    for playerId in pairs(participants) do
        TriggerClientEvent('redlight:client:setState', playerId, 'redlight', gameTimer)
    end
    
    ShowNotificationAll(Config.Messages.redLight, 'error')
    
    CreateThread(function()
        while gameState == "redlight" and gameTimer > 0 and gameActive do
            Wait(1000)
            gameTimer = gameTimer - 1
        end
        
        if gameState == "redlight" and gameActive then
            StartGreenLight()
        end
    end)
end

function StartGreenLight()
    gameState = "greenlight"
    gameTimer = Config.GreenLightDuration
    
    for playerId in pairs(participants) do
        TriggerClientEvent('redlight:client:setState', playerId, 'greenlight', gameTimer)
    end
    
    ShowNotificationAll(Config.Messages.greenLight, 'success')
    
    CreateThread(function()
        while gameState == "greenlight" and gameTimer > 0 and gameActive do
            Wait(1000)
            gameTimer = gameTimer - 1
            CheckFinishLine()
        end
        
        if gameState == "greenlight" and gameActive then
            StartRedLight()
        end
    end)
end

local function StartCountdown()
    gameState = "countdown"
    
    for playerId in pairs(participants) do
        TriggerClientEvent('redlight:client:startCountdown', playerId)
    end
    
    CreateThread(function()
        Wait(10000)
        if gameActive then
            Wait(2000)
            StartGreenLight()
        end
    end)
end

local function UpdateAutoStartTimer()
    local playerCount = GetPlayerCount()
    
    if playerCount >= Config.MinPlayers and not gameActive and not autoStartActive then
        autoStartActive = true
        autoStartTimer = Config.AutoStartDelay
        
        --ShowNotificationAll(string.format(Config.Messages.autoStarting, Config.AutoStartDelay), 'success')
        
        CreateThread(function()
            while autoStartTimer > 0 and autoStartActive and not gameActive do
                Wait(1000)
                autoStartTimer = autoStartTimer - 1
                
                if autoStartTimer > 0 then
                    ShowNotificationAll('Game starting in ' .. autoStartTimer .. ' seconds...', 'inform')
                end
            end
            
            if autoStartActive and not gameActive and GetPlayerCount() >= Config.MinPlayers then
                for playerId in pairs(participants) do
                    TriggerClientEvent('redlight:client:teleportToStart', playerId, Config.StartLine)
                end
                
                gameActive = true
                eliminatedPlayers = {}
                
                StartCountdown()
                
                SetTimeout(Config.MaxGameTime * 1000, function()
                    if gameActive then
                        ShowNotificationAll(Config.Messages.timeUp, 'error')
                        EndGame(false)
                    end
                end)
            end
            
            autoStartActive = false
        end)
    elseif playerCount < Config.MinPlayers and autoStartActive then
        autoStartActive = false
        autoStartTimer = 0
        ShowNotificationAll(Config.Messages.autoStartCancelled, 'warning')
    end
end

function StartGame()
    if gameActive then
        return false, "Game already in progress"
    end
    
    if GetPlayerCount() < Config.MinPlayers then
        return false, "Not enough players (minimum " .. Config.MinPlayers .. ")"
    end
    
    gameActive = true
    gameState = "countdown"
    eliminatedPlayers = {}
    autoStartActive = false
    autoStartTimer = 0
    
    for playerId in pairs(participants) do
        TriggerClientEvent('redlight:client:teleportToStart', playerId, Config.StartLine)
        TriggerClientEvent('redlight:client:setGPS', playerId, Config.FinishLine) -- Set GPS route
    end
    
    StartCountdown()
    
    SetTimeout(Config.MaxGameTime * 1000, function()
        if gameActive then
            ShowNotificationAll(Config.Messages.timeUp, 'error')
            EndGame(false)
        end
    end)
    
    return true, "Game started with " .. GetPlayerCount() .. " players"
end

function EndGame(hasWinner, winnerId)
    gameActive = false
    gameState = "finished"
    
    TriggerClientEvent('redlight:client:gameEnded', -1)
    TriggerClientEvent('redlight:client:clearGPS', -1) -- Clear GPS route for all players
    
    if hasWinner and winnerId then
        local Player = RSGCore.Functions.GetPlayer(winnerId)
        if Player then
            local winnerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            ShowNotificationAll('?? ' .. winnerName .. ' is the winner!', 'success')
        end
    else
        ShowNotificationAll('Game ended with no winner.', 'inform')
    end
    
    CreateThread(function()
        Wait(10000)
        participants = {}
        eliminatedPlayers = {}
        gameState = "waiting"
        autoStartActive = false
        autoStartTimer = 0
    end)
end

RegisterNetEvent('redlight:server:joinGame', function()
    local source = source
    
    if gameActive then
        ShowNotification(source, Config.Messages.gameInProgress, 'error')
        return
    end
    
    if participants[source] then
        ShowNotification(source, Config.Messages.alreadyJoined, 'warning')
        return
    end
    
    if GetPlayerCount() >= Config.MaxPlayers then
        ShowNotification(source, string.format(Config.Messages.gameFull, Config.MaxPlayers), 'error')
        return
    end
    
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player.PlayerData.money.cash < Config.EntryFee then
        ShowNotification(source, string.format(Config.Messages.notEnoughMoney, Config.EntryFee), 'error')
        return
    end
    
    Player.Functions.RemoveMoney('cash', Config.EntryFee)
    
    participants[source] = {
        name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    }
    
    ShowNotificationAll('Player joined! Players: ' .. GetPlayerCount() .. '/' .. Config.MaxPlayers, 'inform')
    
    
    TriggerClientEvent('redlight:client:setGPS', source, Config.FinishLine)
    
    UpdateAutoStartTimer()
end)

RegisterNetEvent('redlight:server:leaveGame', function()
    local source = source
    
    if gameActive then
        ShowNotification(source, Config.Messages.cantLeave, 'error')
        return
    end
    
    if not participants[source] then
        ShowNotification(source, Config.Messages.notRegistered, 'warning')
        return
    end
    
    local Player = RSGCore.Functions.GetPlayer(source)
    Player.Functions.AddMoney('cash', Config.EntryFee)
    
    participants[source] = nil
    ShowNotification(source, Config.Messages.left, 'inform')
    ShowNotificationAll('Player left! Players: ' .. GetPlayerCount() .. '/' .. Config.MaxPlayers, 'inform')
    
    TriggerClientEvent('redlight:client:clearGPS', source) -- Clear GPS route
    
    UpdateAutoStartTimer()
end)

RegisterNetEvent('redlight:server:forceStart', function()
    local source = source
    
    if not IsGameMaster(source) then
        ShowNotification(source, Config.Messages.noPermission, 'error')
        return
    end
    
    if GetPlayerCount() < Config.MinPlayers then
        ShowNotification(source, 'Not enough players to start the game!', 'error')
        return
    end
    
    autoStartActive = false
    autoStartTimer = 0
    
    local success, message = StartGame()
    ShowNotification(source, message, success and 'success' or 'error')
end)

RegisterNetEvent('redlight:server:playerMovedDuringRedLight', function()
    local source = source
    if gameState == "redlight" and participants[source] then
        TriggerClientEvent('redlight:client:guardsAttack', source)
       
    end
end)

RegisterNetEvent('redlight:server:playerKilledByGuards', function(reason)
    local source = source
    EliminatePlayer(source, reason or "Attacked by guards")
end)

RegisterNetEvent('redlight:server:getGameStatus', function()
    local source = source
    
    TriggerClientEvent('redlight:client:updateGameStatus', source, {
        active = gameActive,
        state = gameState,
        players = GetPlayerCount(),
        maxPlayers = Config.MaxPlayers,
        isParticipant = participants[source] ~= nil,
        autoStartTimer = autoStartTimer,
        autoStartActive = autoStartActive,
        entryFee = Config.EntryFee,
        winnerPrize = Config.WinnerPrize
    })
end)

AddEventHandler('playerDropped', function()
    local source = source
    if participants[source] then
        participants[source] = nil
        TriggerClientEvent('redlight:client:clearGPS', source) 
        if gameActive then
            CheckGameEnd()
        else
            UpdateAutoStartTimer()
        end
    end
end)

CreateThread(function()
    while not exports['rsg-core'] or not exports['rsg-core']:GetCoreObject() do
        Wait(100)
    end
    
    while not exports['ox_lib'] or (Config.RegistrationObject and not exports['ox_target']) do
        Wait(100)
    end
    
    if not Config or not Config.RegistrationObject then
        return
    end
    
    TriggerClientEvent('redlight:client:setupRegistration', -1)
    
    AddEventHandler('playerConnecting', function()
        TriggerClientEvent('redlight:client:setupRegistration', source)
    end)
end)