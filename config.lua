Config = {}


Config.MinPlayers = 1
Config.MaxPlayers = 10
Config.EntryFee = 1
Config.WinnerPrize = 50
Config.GameMasterGroup = 'admin'

-----Do not change ----
Config.MovementThreshold = 0.1 -- Maximum movement allowed during red light
Config.CheckInterval = 5000 -- Check player movement every 500ms during red light
Config.AutoStartDelay = 0 -- seconds to wait once min players reached



Config.MaxGameTime = 120 -- 2 minutes total game time
Config.RedLightDuration = 5 -- seconds
Config.GreenLightDuration = 7 -- seconds


Config.StartLine = vector3(-2869.24, -2733.39, 78.76)
Config.FinishLine = vector3(-3013.05, -2636.09, 78.19) 
Config.RegistrationObject = {
    model = 'mp001_p_barreltriple01x', 
    coords = vector4(-2872.21, -2732.36, 78.99, 52.54), 
    label = "Red Light Green Light "
}



-- Notifications
Config.Messages = {
    joined = "You joined the Red Light Green Light game!",
    left = "You left the game. Entry fee refunded.",
    eliminated = "You have been eliminated!",
    winner = "Congratulations! You are the winner!",
    gameStart = "Game starting! You have been teleported to the starting line.",
    redLight = "🔴 RED LIGHT! STOP MOVING!",
	greenLight = "🟢 GREEN LIGHT! GO!",
    notEnoughMoney = "You need $%s to join the game!",
    gameFull = "Game is full! Maximum %s players allowed.",
    alreadyJoined = "You are already registered for the game!",
    gameInProgress = "Game is already in progress!",
    cantLeave = "Cannot leave during an active game!",
    notRegistered = "You are not registered for the game!",
    autoStarting = "Minimum players reached! Game will start in %s seconds.",
    autoStartCancelled = "Not enough players! Auto-start cancelled.",
    timeUp = "Time limit exceeded! Game over.",
    noPermission = "You do not have permission to use this command."
}

Config.GuardPositions = {
    {
        model = GetHashKey("msp_mary1_males_01"), 
        coords = vector4(-2887.12, -2726.35, 83.93, 320.21) 
    },
    {
        model = GetHashKey("msp_mary1_males_01"), 
        coords = vector4(-2912.66, -2723.87, 83.25, 348.52)
    },
    {
        model = GetHashKey("msp_mary1_males_01"), 
        coords = vector4(-2934.36, -2701.53, 78.50, 239.02)
    },
	{
        model = GetHashKey("msp_mary1_males_01"), 
        coords = vector4(-2884.98, -2709.22, 81.66, 205.49)
    },
	{
        model = GetHashKey("msp_mary1_males_01"), 
        coords = vector4(-2908.35, -2708.77, 84.17, 162.60)
    },
	{
        model = GetHashKey("msp_mary1_males_01"), 
        coords = vector4(-2921.86, -2693.22, 83.34, 139.81)
    },
	{
        model = GetHashKey("re_goldpanner_males_01"), 
        coords = vector4(-2929.11, -2671.12, 83.20, 138.19)
    },
	{
        model = GetHashKey("re_injuredrider_males_01"), 
        coords = vector4(-2943.78, -2646.27, 78.41, 180.67)
    },
	{
        model = GetHashKey("re_outlawlooter_males_01"), 
        coords = vector4(-2958.33, -2628.08, 81.53, 229.46)
    },
	{
        model = GetHashKey("cs_mrwayne"), 
        coords = vector4(-2989.02, -2641.74, 81.80, 324.12)
    }
    -- Add more guard positions as needed
}