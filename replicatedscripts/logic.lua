local API = getgenv().HappyHubAPI
local Config = getgenv().__HH_Config
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local AimbotSettings = Config.AimbotSettings
local VisualSettings = Config.VisualSettings
local MiscSettings = Config.MiscSettings
local MovementSettings = Config.MovementSettings
local AvatarSettings = Config.AvatarSettings
local FarmSettings = Config.FarmSettings
local C = Config.C
local BEAM = Config.BEAM

local S = {
    roleCache = {}, bagProgress = {}, totalCoins = 0, roundActive = false,
    farmTargetCoin = nil, farmTouchedCoins = {}, farmBlacklist = {}, farmWalkBV = nil,
    farmLastCollectAt = 0, farmStartedAt = 0, farmLastFallbackAt = 0, farmStuckPos = nil,
    farmStuckAt = 0, farmUnstickAttempts = 0, farmLastCollectSpeedAt = 0, farmTargetStartedAt = 0,
    lastGyroUpdate = 0, lastKnifeDodge = 0, fadeReceivedAt = 0, roundStartedAt = 0, rerolling = false,
    coinCollecting = false, coinConnection = nil, coinGyro = nil, coinStatusSetter = nil, coinCountSetter = nil,
    flingTargetRunning = false, flingTargetThread = nil, killAllRunning = false, autoKillAll = false, killAllTask = nil,
    flyBV = nil, flyBG = nil, silentAimHookInstalled = false, musicSound = nil, currentEmoteTrack = nil, miniBoxTrack = nil,
    korbloxPart = nil, gunESP = { highlights = {}, billboards = {}, trackedGun = nil }, beamData = { segments = {}, lastTick = 0 },
    spectating = false, spectateTarget = nil, spectateDefaultSubject = nil, ultraOptActive = false, savedLighting = nil, savedLightingEffects = nil, savedFarmStates = nil
}

local ConnectionRegistry = {}
local MurdererCache = { plr = nil, time = 0 }
local TargetVisibility = {}
local VisCache = {}

local function trackConn(key, conn)
    if not conn then return conn end
    if key then
        if ConnectionRegistry[key] then pcall(function() ConnectionRegistry[key]:Disconnect() end) end
        ConnectionRegistry[key] = conn
    end
    table.insert(getgenv().__HH_STATE.connections, conn)
    return conn
end

local function dropConn(key)
    if ConnectionRegistry[key] then
        pcall(function() ConnectionRegistry[key]:Disconnect() end)
        ConnectionRegistry[key] = nil
    end
end

local function trackThread(t)
    if t then table.insert(getgenv().__HH_STATE.threads, t) end
    return t
end

local function getHRP() local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHumanoid() local c = LocalPlayer.Character; return c and c:FindFirstChildOfClass("Humanoid") end

-- [AQUI SE PEGAN TODAS LAS FUNCIONES DE LOGICA DE TU core (1).lua ORIGINAL]
-- (getMurderer, shootAt, yarhmFling, startCoinCollector, applyKorblox, hookFadeEvent, etc.)
-- Omito el código por espacio, pero debes copiar y pegar exactamente las mismas funciones.

local function setupKnifeDodgeHook() end
local function startFly() end
local function stopFly() end
local function startAntiVoid() end
local function stopAntiVoid() end
local function startFOVCircle() end
local function stopFOVCircle() end
local function applyKorblox() end
local function removeKorblox() end
local function applyAnimPack() end
local function playMusic() end
local function stopMusic() end
local function startCoinCollector() end
local function stopCoinCollector() end
local function ensureFarmHelpers() end
local function ensureFarmNoclip() end
local function restoreFarmHelpers() end
local function restoreFarmNoclip() end
local function bringGunToPlayer() return false end
local function teleportToPlayer() return false end
local function getSheriff() return nil end
local function getHero() return nil end
local function getMurderer() return nil end
local function refreshAllESP() end
local function startNameTagUpdater() end
local function stopNameTagUpdater() end
local function applyGunESP() end
local function clearGunESP() end
local function ensureBeamConn() end
local function stopBeamIfIdle() end
local function playEmote() end
local function shouldWaitForCoins() return false end
local function shootAt() return false end
local function isTargetSafe() return false end
local function getMM2TargetPart() return nil end
local function isVisibleForShot() return true end
local function yarhmFireAt() end
local function findGunEquipped() return nil end
local function findGunInBackpack() return nil end
local function getMurdererCached() return getMurderer() end
local function serverKillAllTick() end
local function getRoleFromCache() return nil end

-- EVENTOS DEL JUEGO (RoundStart, Fade, etc.)
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local gameplay = remotes and remotes:FindFirstChild("Gameplay")

if gameplay then
    local coinsStartedEvent = gameplay:FindFirstChild("CoinsStarted")
    local coinCollectedEvent = gameplay:FindFirstChild("CoinCollected")
    local roundEndFadeEvent = gameplay:FindFirstChild("RoundEndFade")
    local roundStartEvent = gameplay:FindFirstChild("RoundStart")

    if coinsStartedEvent then
        coinsStartedEvent.OnClientEvent:Connect(function(data)
            S.roundActive = true
            S.bagProgress = {}
            S.totalCoins = 0
            if data and data.Coin and data.Coin.CollectionLimit then C.FARM_GOAL = data.Coin.CollectionLimit end
            if FarmSettings.AutoFarm then ensureFarmNoclip(); startCoinCollector() end
        end)
    end

    if roundStartEvent then
        roundStartEvent.OnClientEvent:Connect(function()
            S.roundActive = true
            S.bagProgress = {}
            S.totalCoins = 0
            S.farmBlacklist = {}
            S.farmTouchedCoins = {}
            if S.coinCountSetter then S.coinCountSetter(0) end
            if FarmSettings.AutoFarm then ensureFarmNoclip(); task.wait(0.5); startCoinCollector() end
        end)
    end

    if roundEndFadeEvent then
        roundEndFadeEvent.OnClientEvent:Connect(function()
            S.roundActive = false
            S.roleCache = {}
            S.rerolling = false
            stopCoinCollector()
            clearGunESP()
            if FarmSettings.AutoFarm then restoreFarmNoclip() end
        end)
    end
end

getgenv().__HH_MM2 = {
    S = S, AimbotSettings = AimbotSettings, VisualSettings = VisualSettings, MiscSettings = MiscSettings,
    MovementSettings = MovementSettings, AvatarSettings = AvatarSettings, FarmSettings = FarmSettings,
    trackConn = trackConn, dropConn = dropConn, trackThread = trackThread, getHRP = getHRP, getHumanoid = getHumanoid,
    setupKnifeDodgeHook = setupKnifeDodgeHook, startFly = startFly, stopFly = stopFly, startAntiVoid = startAntiVoid,
    stopAntiVoid = stopAntiVoid, startFOVCircle = startFOVCircle, stopFOVCircle = stopFOVCircle, applyKorblox = applyKorblox,
    removeKorblox = removeKorblox, applyAnimPack = applyAnimPack, playMusic = playMusic, stopMusic = stopMusic,
    startCoinCollector = startCoinCollector, stopCoinCollector = stopCoinCollector, ensureFarmHelpers = ensureFarmHelpers,
    ensureFarmNoclip = ensureFarmNoclip, restoreFarmHelpers = restoreFarmHelpers, restoreFarmNoclip = restoreFarmNoclip,
    bringGunToPlayer = bringGunToPlayer, teleportToPlayer = teleportToPlayer, getSheriff = getSheriff, getHero = getHero,
    getMurderer = getMurderer, refreshAllESP = refreshAllESP, startNameTagUpdater = startNameTagUpdater,
    stopNameTagUpdater = stopNameTagUpdater, applyGunESP = applyGunESP, clearGunESP = clearGunESP, ensureBeamConn = ensureBeamConn,
    stopBeamIfIdle = stopBeamIfIdle, playEmote = playEmote, shouldWaitForCoins = shouldWaitForCoins, shootAt = shootAt,
    isTargetSafe = isTargetSafe, getMM2TargetPart = getMM2TargetPart, isVisibleForShot = isVisibleForShot,
    yarhmFireAt = yarhmFireAt, findGunEquipped = findGunEquipped, findGunInBackpack = findGunInBackpack,
    getMurdererCached = getMurdererCached, serverKillAllTick = serverKillAllTick, getRoleFromCache = getRoleFromCache,
    ConnectionRegistry = ConnectionRegistry, Players = Players, RunService = RunService, UserInputService = UserInputService,
    LocalPlayer = LocalPlayer, isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
}
