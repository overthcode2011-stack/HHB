do
    local oldState = getgenv and getgenv().__HH_STATE
    if oldState then
        pcall(function()
            for _, c in ipairs(oldState.connections or {}) do
                pcall(function() c:Disconnect() end)
            end
            for _, t in ipairs(oldState.threads or {}) do
                pcall(task.cancel, t)
            end
            for _, g in ipairs(oldState.screenGuis or {}) do
                pcall(function() g:Destroy() end)
            end
        end)
        if getgenv then getgenv().__HH_STATE = nil end
        task.wait(0.3)
    end
end

getgenv().__HH_STATE = {
    connections = {},
    threads = {},
    screenGuis = {},
    startedAt = tick(),
}

local ConnectionRegistry = {}

local function trackConn(key, conn)
    if not conn then return conn end
    if key then
        if ConnectionRegistry[key] then
            pcall(function() ConnectionRegistry[key]:Disconnect() end)
        end
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
    if t then
        table.insert(getgenv().__HH_STATE.threads, t)
    end
    return t
end

local function trackGui(g)
    if g then
        table.insert(getgenv().__HH_STATE.screenGuis, g)
    end
    return g
end

local API
do
    local ok, err = pcall(function()
        API = loadstring(game:HttpGet("https://raw.githubusercontent.com/overthcode2011-stack/HHB-MM2-/refs/heads/main/API"))()
    end)
    if not ok or type(API) ~= "table" then
        warn("[HappyHub] API load failed: " .. tostring(err))
        return
    end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
API.Config.SupportedGames = { 142823291 }
local HAS = {
    RegisterControl   = type(API.RegisterControl) == "function",
    SyncUIControls    = type(API.SyncUIControls) == "function",
    Notify            = type(API.Notify) == "function",
    SetTheme          = type(API.SetTheme) == "function",
    GetTheme          = type(API.GetTheme) == "function",
    CreateImageCard   = type(API.CreateImageCard) == "function",
}

local LocalControlRegistry = {}

local function registerControl(tbl, key, ctrl)
    if not tbl or not key or not ctrl then return end
    LocalControlRegistry[tbl] = LocalControlRegistry[tbl] or {}
    LocalControlRegistry[tbl][key] = ctrl
    if HAS.RegisterControl then
        pcall(API.RegisterControl, API, tbl, key, ctrl)
    end
end

local function syncUIControls()
    if HAS.SyncUIControls then
        pcall(API.SyncUIControls, API)
        return
    end
    for tbl, keys in pairs(LocalControlRegistry) do
        for key, ctrl in pairs(keys) do
            local val = tbl[key]
            if val ~= nil then
                if ctrl.SetState then
                    pcall(function() ctrl:SetState(val, true) end)
                elseif ctrl.SetValue then
                    pcall(function() ctrl:SetValue(val) end)
                end
            end
        end
    end
end

local function notify(msg, dur)
    if HAS.Notify then
        API:Notify(msg, dur)
    end
end

local function getCurrentTheme()
    if HAS.GetTheme then
        local ok, t = pcall(function() return API:GetTheme() end)
        if ok and t then return t end
    end
    return "Green"
end

local function setTheme(name)
    if not HAS.SetTheme then return end
    pcall(function() API:SetTheme(name) end)
end

local ICONS = {
    Home = "131878842124084",
    Aim  = "119272570124806",
    Vis  = "13321848320",
    Plr  = "16485180075",
    Mov  = "112623004490927",
    Misc = "109962716823639",
    Avt  = "116651535114885",
    Farm = "74133076168703",
}

local EMOTES = {
    { name = "Take the L",       id = "74430100028293" },
    { name = "Fly",              id = "77529400769588" },
    { name = "Zombie Walk",      id = "81931167118728" },
    { name = "Jamal Brasil",     id = "83796130837213" },
    { name = "Headless Korblox", id = "84323682148776" },
    { name = "Insane Bug",       id = "86036950557685" },
    { name = "Kick",             id = "92249489340640" },
    { name = "Mini Box",         id = "113994067684875" },
    { name = "Gamgam Style",     id = "129764254213842" },
}

local MUSIC_TRACKS = {
    { name = "Companion",         id = "98012717802240" },
    { name = "Her Boyfriend",     id = "105828916140935" },
    { name = "I Stalk Ur Socials", id = "96622114113241" },
    { name = "EYUHH!",            id = "16190782181" },
    { name = "Low Cortisol",      id = "110919391228823" },
}

local CUSTOM_ANIMS = {
    idle  = { id = "rbxassetid://130192584268621", priority = Enum.AnimationPriority.Action  },
    walk  = { id = "rbxassetid://81802706102899",  priority = Enum.AnimationPriority.Action2 },
    run   = { id = "rbxassetid://79725699626716",  priority = Enum.AnimationPriority.Action3 },
    fall  = { id = "rbxassetid://10921159222",     priority = Enum.AnimationPriority.Action3 },
    climb = { id = "rbxassetid://132811676666245", priority = Enum.AnimationPriority.Action4 },
    jump  = { id = "rbxassetid://10921160088",     priority = Enum.AnimationPriority.Action4 },
}

local MINI_BOX_ANIM_ID = "rbxassetid://89158965064756"

local AimbotSettings = {
    MM2LockOn = false, MM2Smooth = 8, MM2Range = 500, MM2Target = "Head",
    TriggerBot = false, TriggerRange = 150, AutoFire = false, WallCheck = true,
    FOVCircle = false, FOVRadius = 120, AutoKillMurderer = false,
}
local VisualSettings = { MM2ESP = false, OGESP = false, NameTags = false, GunESP = false, Beam = false }
local MiscSettings = {
    InfJump = false, AntiAFK = false, AutoTpGun = false,
    SilentAim = false, MusicCompanion = false, AntiVoid = false,
    SelectedMusic = "Companion",
}
local MovementSettings = {
    Noclip = false, God = false, Fly = false, WalkSpeed = 16, JumpPower = 50,
    FlySpeed = 20, AntiFling = false, Fling = false, TPAll = false,
    FlingTarget = false, FlingDuration = 3, FlingDistance = 500,
}
local AvatarSettings = { Korblox = false, AnimPack = false }
local FarmSettings = { AutoFarm = false, CoinCooldown = 1.5, UltraOpt = true }

local BEAM_CLEAR = Color3.fromRGB(0, 255, 100)
local BEAM_WALL  = Color3.fromRGB(255, 50, 50)
local BEAM_INNO  = Color3.fromRGB(255, 130, 0)

local AntiVoidSettings = { Threshold = -30, SafeY = 10 }

local WALL_GRACE_TIME = 0.2
local TargetVisibility = {}
local MurdererCache = { plr = nil, time = 0 }
local VisCache = {}
local VIS_TTL = 0.05
local MURDERER_TTL = 0.4

local FARM_GOAL = 50
local FARM_TOUCH_RADIUS = 25
local FARM_ARRIVE_DIST = 5
local FARM_CLUSTER_RADIUS = 22
local FARM_FLY_SPEED = 28
local FARM_DANGER_DIST = 20
local FARM_NEAR_DIST = 38
local FARM_GROUND_OFFSET = -1.5
local FARM_STALL_TIMEOUT = 15
local FARM_TOUCH_COOLDOWN = 0.28
local FARM_FALLBACK_TIMEOUT = 14
local FARM_FALLBACK_COOLDOWN = 3.5
local FARM_FALLBACK_MIN_SAFE = 30
local FARM_STUCK_TIME = 1.6
local FARM_STUCK_DIST = 2.5

local YARHM_SHOOT_OFFSET = 2.8

local S = {
    noclipConn = nil, godConn = nil, antiAFKConn = nil,
    flyConn = nil, flyBV = nil, flyBG = nil,
    mm2Conn = nil, triggerBotConn = nil, autoFireConn = nil,
    autoKillConn = nil, antiVoidConn = nil, lastSafeCFrame = nil,
    autoTpGunThread = nil, flingTask = nil, tpAllTask = nil,
    nameTagUpdater = nil, mm2PeriodicThread = nil, gunESPThread = nil,
    fovConn = nil, fovGui = nil, fovFrame = nil,
    flingTargetThread = nil, flingTargetRunning = false,
    flingOriginalCFrame = nil, flingOriginalPosition = nil,
    flingWasFlingOn = false,
    antiFlingConnections = {}, antiFlingActive = false,
    flingRunning = false, tpAllRunning = false, killAllRunning = false,
    musicSound = nil,
    currentEmoteTrack = nil,
    miniBoxTrack = nil,
    animPriorityConn = nil,
    korbloxPart = nil,
    mobileFlyVec = Vector3.zero, mobileFlyDragging = false,
    beamData = { segments = {}, updateConn = nil, lastTick = 0 },
    coinCollecting = false, coinConnection = nil, coinGyro = nil,
    roundActive = false, bagProgress = {}, totalCoins = 0,
    coinStatusSetter = nil, coinCountSetter = nil,
    roleCache = {},
    heroWatcher = { active = false, thread = nil, originalSheriffName = nil },
    gunESP = { active = false, highlights = {}, billboards = {}, trackedGun = nil },
    hitboxExpander = { active = false, savedSizes = {}, size = Vector3.new(40, 40, 40) },
    fadeConn = nil, tpEvent = nil,
    silentAimHookInstalled = false, hookNamecall = nil, getNamecall = nil,
    lastMobileShot = 0,
    spectating = false, spectateTarget = nil, spectateDefaultSubject = nil,
    lastCollectTime = 0,
    lastCamUpdate = 0,
    autoKillAll = false, killAllTask = nil,
    evasionThread = nil,
    ultraOptActive = false,
    savedLighting = nil,
    savedLightingEffects = nil,
    savedFarmStates = nil,
    farmTargetCoin = nil,
    farmTouchedCoins = {},
    farmWalkBV = nil,
    farmLastCollectAt = 0,
    farmStartedAt = 0,
    farmLastFallbackAt = 0,
    farmLastPos = nil,
    farmLastPosTime = 0,
    lastGyroUpdate = 0,
}

local UI = {}

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function isGunTool(t)
    if not t or not t:IsA("Tool") then return false end
    local name = t.Name:lower()
    return name:find("gun", 1, true) ~= nil
        or name:find("pistol", 1, true) ~= nil
        or name:find("revolver", 1, true) ~= nil
        or name:find("sheriff", 1, true) ~= nil
end

local function findGunEquipped()
    local char = LocalPlayer.Character
    if not char then return nil end
    local direct = char:FindFirstChild("Gun")
    if direct and direct:IsA("Tool") then
        return direct
    end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and isGunTool(t) then
            return t
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local eq = hum:FindFirstChildWhichIsA("Tool")
        if eq and isGunTool(eq) then
            return eq
        end
    end
    return nil
end

local function findGunInBackpack()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then return nil end
    local direct = bp:FindFirstChild("Gun")
    if direct and direct:IsA("Tool") then
        return direct
    end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and isGunTool(t) then
            return t
        end
    end
    return nil
end

local function ensureGunReady()
    local equipped = findGunEquipped()
    if equipped and equipped.Parent == LocalPlayer.Character then
        return equipped, "already in rig"
    end
    local inBag = findGunInBackpack()
    if not inBag then
        return nil, "no gun in rig or backpack"
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil, "no humanoid" end
    pcall(function() hum:EquipTool(inBag) end)
    local waited = char:WaitForChild("Gun", 2)
    if waited and waited:IsA("Tool") and waited.Parent == char then
        return waited, "equipped from backpack"
    end
    local deadline = tick() + 0.5
    while tick() < deadline do
        local eq = findGunEquipped()
        if eq and eq.Parent == char then
            return eq, "equipped from backpack"
        end
        task.wait(0.05)
    end
    return nil, "equip timeout"
end

local function isGunRelatedRemote(remote)
    if not remote or not remote:IsA("RemoteEvent") then return false end
    local parent = remote.Parent
    if not parent then return false end
    if parent:IsA("Tool") and isGunTool(parent) then return true end
    if parent.Parent and parent.Parent:IsA("Tool") and isGunTool(parent.Parent) then return true end
    return false
end

local function isGunShootRemote(remote)
    if not remote or not remote:IsA("RemoteEvent") then return false end
    if remote.Name:lower():find("shoot", 1, true) then return true end
    return isGunRelatedRemote(remote)
end

local function spectatePlayer(plr)
    if not plr or not plr.Character then return end
    local theirHum = plr.Character:FindFirstChildOfClass("Humanoid")
    if not theirHum then return end
    if not S.spectating then
        local cam = workspace.CurrentCamera
        S.spectateDefaultSubject = cam and cam.CameraSubject or nil
    end
    local cam = workspace.CurrentCamera
    if cam then
        cam.CameraSubject = theirHum
        cam.CameraType = Enum.CameraType.Custom
    end
    S.spectating = true
    S.spectateTarget = plr
end

local function stopSpectating()
    local cam = workspace.CurrentCamera
    if cam then
        local myHum = getHumanoid()
        if myHum then
            cam.CameraSubject = myHum
        elseif S.spectateDefaultSubject then
            cam.CameraSubject = S.spectateDefaultSubject
        else
            cam.CameraSubject = nil
        end
        cam.CameraType = Enum.CameraType.Custom
    end
    S.spectating = false
    S.spectateTarget = nil
    S.spectateDefaultSubject = nil
end

local GunShootBindable = nil
local GunShootLastArgs = nil
local GunShootHandlerHooked = false

local function hookGunShootEvent(bindable)
    if not bindable or not bindable:IsA("BindableEvent") then return end
    if GunShootHandlerHooked and GunShootBindable == bindable then return end
    if type(getconnections) ~= "function" or type(hookfunction) ~= "function" then return end

    GunShootBindable = bindable
    getgenv().HH_GunShootBindable = bindable
    GunShootHandlerHooked = false

    for _, conn in ipairs(getconnections(bindable.Event)) do
        if conn.Function then
            local old
            old = hookfunction(conn.Function, function(...)
                local args = table.pack(...)
                GunShootLastArgs = args

                if MiscSettings.SilentAim then
                    local murderer = getMurdererCached()
                    if isTargetSafe(murderer) then
                        local targetPart = getMM2TargetPart(murderer.Character)
                        if targetPart then
                            local newTargetCF = predictAim(targetPart)
                            if newTargetCF then
                                for i = 2, math.min(5, args.n) do
                                    if typeof(args[i]) == "CFrame" then
                                        args[i] = newTargetCF
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                return old(table.unpack(args, 1, args.n))
            end)
            GunShootHandlerHooked = true
            break
        end
    end
end

local function scanForGunShoot()
    local char = LocalPlayer.Character
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and isGunTool(tool) then
            local ev = tool:FindFirstChild("Shoot")
            if ev and ev:IsA("BindableEvent") then
                hookGunShootEvent(ev)
                return
            end
        end
    end
end

if isMobile then
    trackThread(task.spawn(function()
        while true do
            task.wait(0.4)
            scanForGunShoot()
        end
    end))
end

local function findGunDrop()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("gundrop") then return obj end
        if obj:IsA("Model") then
            local found = obj:FindFirstChild("GunDrop", true)
            if found and found:IsA("BasePart") then return found end
        end
    end
    local gd = workspace:FindFirstChild("GunDrop", true)
    if gd and gd:IsA("BasePart") then return gd end
    return nil
end

local function hasTool(parent, toolName)
    if not parent then return false end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Tool") then
            local name = child.Name:lower()
            if name == toolName:lower() or name:find(toolName:lower(), 1, true) then return true end
        end
    end
    return false
end

local function getRoleFromCache(plr)
    local info = S.roleCache[plr.Name]
    if info and info.Role then return info.Role end
    return nil
end

local function isLocalSheriffOrHero()
    local cached = getRoleFromCache(LocalPlayer)
    if cached == "Sheriff" or cached == "Hero" then return true end
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if hasTool(char, "Gun") or hasTool(bp, "Gun") then return true end
    return false
end

local function isPlrMurderer(plr)
    if not plr then return false end
    if plr == LocalPlayer then return false end
    if not plr.Parent then return false end
    local cached = getRoleFromCache(plr)
    if cached == "Murderer" then return true end
    local char = plr.Character
    local bp = plr:FindFirstChildOfClass("Backpack")
    if (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) then
        return true
    end
    return false
end

local function isTargetSafe(plr)
    if not plr then return false end
    if plr == LocalPlayer then return false end
    if not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not isPlrMurderer(plr) then return false end
    return true
end

local function getMM2Role(plr)
    if plr == LocalPlayer then return "Innocent" end
    local cached = getRoleFromCache(plr)
    if cached then
        if cached == "Hero" then return "Hero" end
        if cached == "Sheriff" then return "Sheriff" end
        if cached == "Murderer" then return "Murderer" end
    end
    local char = plr.Character
    local bp = plr:FindFirstChildOfClass("Backpack")
    if hasTool(char, "Knife") or hasTool(bp, "Knife") then return "Murderer" end
    if hasTool(char, "Gun") or hasTool(bp, "Gun") then
        local sheriffAlive = false
        for _, info in pairs(S.roleCache) do
            if info.Role == "Sheriff" then
                if not info.Dead then sheriffAlive = true end
                break
            end
        end
        if sheriffAlive then return "Sheriff" end
        return "Hero"
    end
    return "Innocent"
end

local function getMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if getRoleFromCache(plr) == "Murderer" then return plr end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local bp = plr:FindFirstChild("Backpack")
            if (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) then
                return plr
            end
        end
    end
    return nil
end

local function getMurdererCached()
    local now = tick()
    local cached = MurdererCache.plr
    if cached and cached.Parent and cached.Character and (now - MurdererCache.time) < MURDERER_TTL then
        return cached
    end
    local fresh = getMurderer()
    MurdererCache.plr = fresh
    MurdererCache.time = now
    return fresh
end

local function getSheriff()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if getRoleFromCache(plr) == "Sheriff" then return plr end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if getRoleFromCache(plr) == "Hero" then return plr end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local bp = plr:FindFirstChild("Backpack")
            if (char and char:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun")) then
                return plr
            end
        end
    end
    return nil
end

local function getHero()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if getRoleFromCache(plr) == "Hero" then return plr end
        end
    end
    return nil
end

local function isLocalMurderer()
    local cached = getRoleFromCache(LocalPlayer)
    if cached == "Murderer" then return true end
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) then return true end
    return false
end

local function getMM2TargetPart(character)
    if not character then return nil end
    local mode = AimbotSettings.MM2Target
    if mode == "Head" then
        return character:FindFirstChild("Head")
    elseif mode == "Torso" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
    else
        return character:FindFirstChild("HumanoidRootPart")
    end
end

local function getGunRaycastCFrame()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local att = hrp:FindFirstChild("GunRaycastAttachment")
    if att then return att.WorldCFrame end
    local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
    if hand then return CFrame.new(hand.Position) end
    return hrp.CFrame
end

local function getEquippedGun()
    return findGunEquipped() or findGunInBackpack()
end

local function predictAim(targetPart)
    if not targetPart then return nil end
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if not ok or not ping or ping <= 0 then ping = 0.05 end
    local vel = targetPart.AssemblyLinearVelocity
    return CFrame.new(targetPart.Position + vel * (ping * 1.15))
end

local function getPredictedPosition(plr, shootOffset)
    if not plr or not plr.Character then return nil end
    local torso = plr.Character:FindFirstChild("UpperTorso") or plr.Character:FindFirstChild("HumanoidRootPart")
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if not torso or not hum then return nil end
    local offset = shootOffset or YARHM_SHOOT_OFFSET
    local vel = torso.AssemblyLinearVelocity
    local moveDir = hum.MoveDirection
    return torso.Position
        + ((vel * Vector3.new(0.75, 0.5, 0.75)) * (offset / 15))
        + moveDir * offset
end

local function getCharacterFromPart(part)
    if not part then return nil end
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") then
            local plr = Players:GetPlayerFromCharacter(current)
            if plr then return plr end
        end
        current = current.Parent
    end
    return nil
end

local function classifyPathHit(originPos, targetPos, targetChar)
    local dir = targetPos - originPos
    local dist = dir.Magnitude
    if dist < 0.5 then return "clear", nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { workspace.CurrentCamera }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    local result = workspace:Raycast(originPos, dir.Unit * (dist + 1), params)
    if not result then return "clear", nil end
    if targetChar and (result.Instance:IsDescendantOf(targetChar) or result.Instance == targetChar) then
        return "target", nil
    end
    local hitPlr = getCharacterFromPart(result.Instance)
    if hitPlr and hitPlr ~= LocalPlayer then
        local role = getMM2Role(hitPlr)
        if role ~= "Murderer" then return "innocent", hitPlr end
        return "clear", nil
    end
    return "wall", nil
end

local function applyGracePeriod(plr, isCurrentlyVisible)
    if not plr then return isCurrentlyVisible end
    local now = tick()
    local tv = TargetVisibility[plr]
    if not tv then
        tv = { wasHidden = false, visibleSince = nil }
        TargetVisibility[plr] = tv
    end
    if isCurrentlyVisible then
        if tv.wasHidden then
            if not tv.visibleSince then tv.visibleSince = now end
            if (now - tv.visibleSince) >= WALL_GRACE_TIME then
                tv.wasHidden = false
                tv.visibleSince = nil
                return true
            end
            return false
        end
        return true
    else
        tv.wasHidden = true
        tv.visibleSince = nil
        return false
    end
end

local function isVisibleForShot(originPos, targetPos, targetChar, targetPlr)
    local hitType = classifyPathHit(originPos, targetPos, targetChar)
    if hitType == "innocent" then
        if targetPlr then
            local tv = TargetVisibility[targetPlr]
            if tv then
                tv.wasHidden = true
                tv.visibleSince = nil
            end
        end
        return false
    end
    if not AimbotSettings.WallCheck then return true end
    if hitType == "wall" then return applyGracePeriod(targetPlr, false) end
    return applyGracePeriod(targetPlr, true)
end

local function isVisible(originPos, targetPos, targetChar)
    local dir = targetPos - originPos
    local dist = dir.Magnitude
    if dist < 0.5 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { workspace.CurrentCamera }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    local result = workspace:Raycast(originPos, dir.Unit * (dist + 1), params)
    if not result then return true end
    if targetChar and (result.Instance:IsDescendantOf(targetChar) or result.Instance == targetChar) then
        return true
    end
    return false
end

local function buildBeamPath(fromPos, toPos, targetChar)
    local waypoints = { fromPos }
    local current = fromPos
    local iterations = 0
    while iterations < 14 do
        iterations = iterations + 1
        local diff = toPos - current
        local dist = diff.Magnitude
        if dist < 1 then break end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = { workspace.CurrentCamera }
        if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = true
        local result = workspace:Raycast(current, diff, params)
        if not result then
            table.insert(waypoints, toPos)
            break
        end
        if targetChar and (result.Instance:IsDescendantOf(targetChar) or result.Instance == targetChar) then
            table.insert(waypoints, toPos)
            break
        end
        local hitPlr = getCharacterFromPart(result.Instance)
        if hitPlr and hitPlr ~= LocalPlayer then
            local role = getMM2Role(hitPlr)
            if role == "Murderer" then
                table.insert(waypoints, toPos)
                break
            end
        end
        local hitPos = result.Position
        local normal = result.Normal
        local travel = hitPos - current
        local travelMag = travel.Magnitude
        if travelMag < 0.1 then
            table.insert(waypoints, toPos)
            break
        end
        local perp = normal:Cross(Vector3.yAxis)
        if perp.Magnitude < 0.01 then perp = normal:Cross(Vector3.xAxis) end
        perp = perp.Unit
        local offset = 3
        local sideA = hitPos + perp * offset
        local sideB = hitPos - perp * offset
        local distA = (sideA - toPos).Magnitude
        local distB = (sideB - toPos).Magnitude
        local chosen
        if distA < distB then
            chosen = sideA + travel.Unit * 0.5
        else
            chosen = sideB + travel.Unit * 0.5
        end
        local newPoint = chosen
        if (newPoint - current).Magnitude < 0.5 then
            newPoint = current + travel.Unit * 1
        end
        table.insert(waypoints, newPoint)
        current = newPoint
    end
    if (waypoints[#waypoints] - toPos).Magnitude > 1 then
        table.insert(waypoints, toPos)
    end
    return waypoints
end

local function yarhmFireAt(targetPlr, targetPart)
    if not targetPlr or not targetPlr.Character then return false, "no target" end
    local char = LocalPlayer.Character
    if not char then return false, "no character" end

    local gun, gunHow = ensureGunReady()
    if not gun then return false, "gun: " .. tostring(gunHow) end
    if gun.Parent ~= char then return false, "gun not in rig" end

    local shootEv = gun:FindFirstChild("Shoot")
    if not shootEv then return false, "no Shoot child" end

    local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
    if not hand then return false, "no hand" end
    local originCF = CFrame.new(hand.Position)

    local targetPos = getPredictedPosition(targetPlr, YARHM_SHOOT_OFFSET)
    if not targetPos then return false, "no predicted pos" end
    local targetCF = CFrame.new(targetPos)
    if targetPart then
        local predCF = predictAim(targetPart)
        if predCF then targetCF = predCF end
    end

    local ok, err = pcall(function()
        shootEv:FireServer(originCF, targetCF)
    end)
    if not ok then return false, "FireServer: " .. tostring(err) end
    return true, "shot via " .. gun.Name .. ".Shoot"
end

local function yarhmInstakill(targetPlr)
    if not targetPlr or not targetPlr.Character then return false, "no target" end
    local char = LocalPlayer.Character
    if not char then return false, "no character" end

    local gun, gunHow = ensureGunReady()
    if not gun then return false, "gun: " .. tostring(gunHow) end
    if gun.Parent ~= char then return false, "gun not in rig" end

    local shootEv = gun:FindFirstChild("Shoot")
    if not shootEv then return false, "no Shoot child" end

    local theirHRP = targetPlr.Character:FindFirstChild("HumanoidRootPart")
    if not theirHRP then return false, "no target HRP" end

    local originCF = CFrame.new(theirHRP.Position + Vector3.new(0, 1, 0))
    local targetCF = CFrame.new(theirHRP.Position)

    local ok, err = pcall(function()
        shootEv:FireServer(originCF, targetCF)
    end)
    if not ok then return false, "FireServer: " .. tostring(err) end
    return true, "instakill via " .. gun.Name .. ".Shoot"
end

local function mobileForceShoot()
    local murderer = getMurdererCached()
    if not isTargetSafe(murderer) then
        notify("No murderer", 2)
        return false
    end
    local targetPart = getMM2TargetPart(murderer.Character)
    local ok, info = yarhmFireAt(murderer, targetPart)
    if ok then
        notify("Shot " .. murderer.DisplayName, 1.5)
        return true
    else
        notify("Fire failed: " .. tostring(info), 3)
        return false
    end
end

local function clearBeamPool(pool)
    for _, seg in ipairs(pool.segments) do
        if seg.beam and seg.beam.Parent then seg.beam:Destroy() end
        if seg.att0 and seg.att0.Parent then seg.att0:Destroy() end
        if seg.att1 and seg.att1.Parent then seg.att1:Destroy() end
        if seg.startPart and seg.startPart.Parent then seg.startPart:Destroy() end
        if seg.endPart and seg.endPart.Parent then seg.endPart:Destroy() end
    end
    pool.segments = {}
end

local function createBeamSegment()
    local startPart = Instance.new("Part")
    startPart.Name = "HH_BeamSegStart"
    startPart.Size = Vector3.new(0.1, 0.1, 0.1)
    startPart.Transparency = 1
    startPart.CanCollide = false
    startPart.Anchored = true
    startPart.Massless = true
    startPart.Parent = workspace

    local endPart = Instance.new("Part")
    endPart.Name = "HH_BeamSegEnd"
    endPart.Size = Vector3.new(0.1, 0.1, 0.1)
    endPart.Transparency = 1
    endPart.CanCollide = false
    endPart.Anchored = true
    endPart.Massless = true
    endPart.Parent = workspace

    local att0 = Instance.new("Attachment")
    att0.Parent = startPart
    local att1 = Instance.new("Attachment")
    att1.Parent = endPart

    local beam = Instance.new("Beam")
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.FaceCamera = true
    beam.Width0 = 0.15
    beam.Width1 = 0.15
    beam.Color = ColorSequence.new(BEAM_CLEAR)
    beam.Transparency = NumberSequence.new(0.2)
    beam.LightEmission = 1
    beam.Parent = startPart

    return { beam = beam, att0 = att0, att1 = att1, startPart = startPart, endPart = endPart }
end

local function ensureSegments(pool, count)
    while #pool.segments < count do
        table.insert(pool.segments, createBeamSegment())
    end
    while #pool.segments > count do
        local seg = table.remove(pool.segments)
        if seg.beam then seg.beam:Destroy() end
        if seg.att0 then seg.att0:Destroy() end
        if seg.att1 then seg.att1:Destroy() end
        if seg.startPart then seg.startPart:Destroy() end
        if seg.endPart then seg.endPart:Destroy() end
    end
end

local function renderBeamPath(pool, waypoints, color)
    local needed = #waypoints - 1
    if needed < 1 then
        ensureSegments(pool, 0)
        return
    end
    ensureSegments(pool, needed)
    for i = 1, needed do
        local seg = pool.segments[i]
        local a = waypoints[i]
        local b = waypoints[i + 1]
        seg.startPart.CFrame = CFrame.new(a)
        seg.endPart.CFrame = CFrame.new(b)
        seg.beam.Width0 = 0.15
        seg.beam.Width1 = 0.15
        seg.beam.Color = ColorSequence.new(color)
        seg.beam.Transparency = NumberSequence.new(0.2)
    end
end

local function updateBeam()
    if VisualSettings.Beam then
        local myHRP = getHRP()
        local murderer = getMurdererCached()
        if myHRP and isTargetSafe(murderer) then
            local targetPart = getMM2TargetPart(murderer.Character)
            if targetPart then
                local waypoints = buildBeamPath(myHRP.Position, targetPart.Position, murderer.Character)
                local hitType = classifyPathHit(myHRP.Position, targetPart.Position, murderer.Character)
                local color
                if hitType == "clear" or hitType == "target" then
                    color = BEAM_CLEAR
                elseif hitType == "innocent" then
                    color = BEAM_INNO
                else
                    color = BEAM_WALL
                end
                renderBeamPath(S.beamData, waypoints, color)
            else
                clearBeamPool(S.beamData)
            end
        else
            clearBeamPool(S.beamData)
        end
    elseif #S.beamData.segments > 0 then
        clearBeamPool(S.beamData)
    end
end

local function ensureBeamConn()
    dropConn("beam")
    trackConn("beam", RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - S.beamData.lastTick < 0.08 then return end
        S.beamData.lastTick = now
        updateBeam()
    end))
end

local function stopBeamIfIdle()
    if VisualSettings.Beam then return end
    dropConn("beam")
    clearBeamPool(S.beamData)
end

local function refreshBeam()
    if ConnectionRegistry["beam"] then
        S.beamData.lastTick = 0
        updateBeam()
    end
end

local function startAntiVoid()
    dropConn("antivoid")
    trackConn("antivoid", RunService.Heartbeat:Connect(function()
        if not MiscSettings.AntiVoid then return end
        local hrp = getHRP()
        if not hrp then
            S.lastSafeCFrame = nil
            return
        end
        local pos = hrp.Position
        if pos.Y >= AntiVoidSettings.SafeY then
            S.lastSafeCFrame = hrp.CFrame
        elseif pos.Y <= AntiVoidSettings.Threshold and S.lastSafeCFrame then
            hrp.CFrame = S.lastSafeCFrame
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end
    end))
end

local function stopAntiVoid()
    dropConn("antivoid")
    S.lastSafeCFrame = nil
end

local function playEmote(emoteName, emoteId)
    local char = LocalPlayer.Character
    if not char then notify("No character") return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    if S.currentEmoteTrack then
        pcall(function() S.currentEmoteTrack:Stop(0.1) end)
        S.currentEmoteTrack = nil
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. emoteId
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if ok and track then
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = true
        track:Play(0.1)
        S.currentEmoteTrack = track
        notify("Emote: " .. emoteName, 1.5)
    else
        notify("Failed: " .. emoteName, 2)
    end
end

local function playMiniBoxAnimation()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    if S.miniBoxTrack then
        pcall(function() S.miniBoxTrack:Stop(0.1) end)
        S.miniBoxTrack = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = MINI_BOX_ANIM_ID
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if ok and track then
        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = true
        track:Play(0.1)
        S.miniBoxTrack = track
    end
end

local function stopMiniBoxAnimation()
    if S.miniBoxTrack then
        pcall(function() S.miniBoxTrack:Stop(0.1) end)
        S.miniBoxTrack = nil
    end
end

local function playMusic()
    if not MiscSettings.MusicCompanion then return end
    if S.musicSound then
        S.musicSound:Stop()
        S.musicSound:Destroy()
        S.musicSound = nil
    end
    local selected = MUSIC_TRACKS[1]
    for _, track in ipairs(MUSIC_TRACKS) do
        if track.name == MiscSettings.SelectedMusic then
            selected = track
            break
        end
    end
    S.musicSound = Instance.new("Sound")
    S.musicSound.SoundId = "rbxassetid://" .. selected.id
    S.musicSound.Volume = 10
    S.musicSound.Looped = true
    S.musicSound.Parent = game:GetService("SoundService")
    S.musicSound:Play()
    notify("Playing: " .. selected.name)
end

local function stopMusic()
    if S.musicSound then
        S.musicSound:Stop()
        S.musicSound:Destroy()
        S.musicSound = nil
    end
end

pcall(function()
    S.hookNamecall = hookmetamethod
    S.getNamecall  = getnamecallmethod
end)

if type(S.hookNamecall) == "function" and type(S.getNamecall) == "function" then
    local ok = pcall(function()
        local oldNamecall
        oldNamecall = S.hookNamecall(game, "__namecall", function(self, ...)
            if S.getNamecall() == "FireServer" and self:IsA("RemoteEvent") then
                local args = table.pack(...)

                if MiscSettings.SilentAim and isGunShootRemote(self) then
                    local murderer = getMurdererCached()
                    if isTargetSafe(murderer) then
                        local targetPart = getMM2TargetPart(murderer.Character)
                        if targetPart then
                            local cam = workspace.CurrentCamera
                            local myHRP = getHRP()
                            local origin = (myHRP and myHRP.Position) or cam.CFrame.Position
                            if isVisibleForShot(origin, targetPart.Position, murderer.Character, murderer) then
                                local newTarget = predictAim(targetPart)
                                if newTarget then
                                    for i = 2, math.min(5, args.n) do
                                        if typeof(args[i]) == "CFrame" then
                                            args[i] = newTarget
                                            break
                                        end
                                    end
                                    return oldNamecall(self, table.unpack(args, 1, args.n))
                                end
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end)
    S.silentAimHookInstalled = ok
end

if not isMobile then
    trackConn("silent_click", UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not MiscSettings.SilentAim then return end
        if S.silentAimHookInstalled then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local murderer = getMurdererCached()
        if not isTargetSafe(murderer) then return end
        local targetPart = getMM2TargetPart(murderer.Character)
        if not targetPart then return end
        local myHRP = getHRP()
        if not myHRP then return end
        if not isVisibleForShot(myHRP.Position, targetPart.Position, murderer.Character, murderer) then return end
        trackThread(task.spawn(function()
            yarhmFireAt(murderer, targetPart)
        end))
    end))
end

local function equipKnife()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find("knife", 1, true) then
            return true
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("knife", 1, true) then
                pcall(function() hum:EquipTool(tool) end)
                task.wait(0.3)
                return true
            end
        end
    end
    return false
end

local function getLocalKnife()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find("knife", 1, true) then
            return tool
        end
    end
    return nil
end

local function getTpEvent()
    if S.tpEvent and S.tpEvent.Parent then return S.tpEvent end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    local gameplay = remotes:FindFirstChild("Gameplay")
    if not gameplay then return nil end
    S.tpEvent = gameplay:FindFirstChild("TeleportToPart")
    return S.tpEvent
end

local function fireTeleportToPart(sourcePart, destinationPart)
    local ev = getTpEvent()
    if not ev then return false end
    pcall(function() ev:FireServer(sourcePart, destinationPart) end)
    pcall(function() ev:FireServer(destinationPart, sourcePart) end)
    pcall(function() ev:FireServer(sourcePart, destinationPart.Position) end)
    pcall(function() ev:FireServer(sourcePart.Name, destinationPart) end)
    return true
end

local function teleportToPlayer(targetPlr)
    if not targetPlr then return false end
    local theirHRP = targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
    local myHRP = getHRP()
    if not myHRP or not theirHRP then return false end
    if fireTeleportToPart(myHRP, theirHRP) then
        task.wait(0.03)
        local h = getHRP()
        if h and (h.Position - theirHRP.Position).Magnitude > 5 then
            h.CFrame = theirHRP.CFrame
        end
    else
        myHRP.CFrame = theirHRP.CFrame
    end
    return true
end

local function bringGunToPlayer()
    local gun = findGunDrop()
    if not gun then return false, "no gun" end
    local hrp = getHRP()
    if not hrp then return false, "no hrp" end
    local moved = false
    if fireTeleportToPart(gun, hrp) then moved = true end
    task.wait(0.03)
    if gun and gun.Parent then
        gun.CFrame = hrp.CFrame
        gun.Velocity = Vector3.zero
        gun.RotVelocity = Vector3.zero
        moved = true
    end
    return moved, moved and "remote" or "fallback"
end

local ESP_COLORS = {
    MM2 = {
        Murderer = Color3.fromRGB(255, 0, 0),
        Sheriff  = Color3.fromRGB(0, 132, 255),
        Hero     = Color3.fromRGB(255, 200, 0),
        Innocent = Color3.fromRGB(56, 255, 112),
    },
    OG = Color3.fromRGB(255, 255, 255),
    Gun = Color3.fromRGB(255, 200, 0),
}

local ESP = {
    active = { MM2 = false, OG = false, NameTag = false },
    highlights = { MM2 = {}, OG = {} },
    nameTags = {},
}

local function clearHighlights(plr)
    if ESP.highlights.MM2[plr] then ESP.highlights.MM2[plr]:Destroy(); ESP.highlights.MM2[plr] = nil end
    if ESP.highlights.OG[plr] then ESP.highlights.OG[plr]:Destroy(); ESP.highlights.OG[plr] = nil end
    if ESP.nameTags[plr] then
        if ESP.nameTags[plr].bb and ESP.nameTags[plr].bb.Parent then ESP.nameTags[plr].bb:Destroy() end
        ESP.nameTags[plr] = nil
    end
end

local function clearGunESP()
    for _, h in pairs(S.gunESP.highlights) do
        if h and h.Parent then h:Destroy() end
    end
    for _, bb in pairs(S.gunESP.billboards) do
        if bb and bb.Parent then bb:Destroy() end
    end
    S.gunESP.highlights = {}
    S.gunESP.billboards = {}
    S.gunESP.trackedGun = nil
end

local function applyGunESP()
    if not VisualSettings.GunESP then
        clearGunESP()
        return
    end
    local gun = findGunDrop()
    if not gun then
        clearGunESP()
        return
    end
    if S.gunESP.trackedGun ~= gun then
        clearGunESP()
        S.gunESP.trackedGun = gun
    end
    if not S.gunESP.highlights[gun] then
        local h = Instance.new("Highlight")
        h.Name = "HH_GunESP"
        h.FillColor = ESP_COLORS.Gun
        h.FillTransparency = 0.3
        h.OutlineTransparency = 1
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = gun
        S.gunESP.highlights[gun] = h
    end
    if not S.gunESP.billboards[gun] then
        local bb = Instance.new("BillboardGui")
        bb.Name = "HH_GunTag"
        bb.Size = UDim2.new(0, 160, 0, 24)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = gun
        bb.Parent = gun
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Gun Dropped here!"
        lbl.TextColor3 = ESP_COLORS.Gun
        lbl.FontFace = Font.fromEnum(Enum.Font.Code)
        lbl.TextSize = 13
        lbl.TextStrokeTransparency = 1
        lbl.Parent = bb
        S.gunESP.billboards[gun] = bb
    end
end

local function applyESP(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        clearHighlights(plr)
        return
    end

    if ESP.active.MM2 then
        local role = getMM2Role(plr)
        local color = ESP_COLORS.MM2[role] or ESP_COLORS.MM2.Innocent
        if not ESP.highlights.MM2[plr] then
            local h = Instance.new("Highlight")
            h.Name = "HH_MM2"
            h.FillColor = color
            h.FillTransparency = 0.2
            h.OutlineTransparency = 1
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = char
            ESP.highlights.MM2[plr] = h
        else
            ESP.highlights.MM2[plr].FillColor = color
        end
    elseif ESP.highlights.MM2[plr] then
        ESP.highlights.MM2[plr]:Destroy()
        ESP.highlights.MM2[plr] = nil
    end

    if ESP.active.OG then
        if not ESP.highlights.OG[plr] then
            local h = Instance.new("Highlight")
            h.Name = "HH_OG"
            h.FillColor = ESP_COLORS.OG
            h.FillTransparency = 0.5
            h.OutlineTransparency = 1
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = char
            ESP.highlights.OG[plr] = h
        end
    elseif ESP.highlights.OG[plr] then
        ESP.highlights.OG[plr]:Destroy()
        ESP.highlights.OG[plr] = nil
    end

    if ESP.active.NameTag then
        if not ESP.nameTags[plr] then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bb = Instance.new("BillboardGui")
                bb.Name = "HH_NameTag"
                bb.Size = UDim2.new(0, 140, 0, 32)
                bb.StudsOffset = Vector3.new(0, 3.5, 0)
                bb.AlwaysOnTop = true
                bb.Adornee = hrp
                bb.Parent = hrp
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, 1)
                lbl.BackgroundTransparency = 1
                lbl.TextColor3 = Color3.new(1, 1, 1)
                lbl.FontFace = Font.fromEnum(Enum.Font.Code)
                lbl.TextSize = 13
                lbl.TextStrokeTransparency = 1
                lbl.Parent = bb
                ESP.nameTags[plr] = { bb = bb, lbl = lbl }
            end
        end
    elseif ESP.nameTags[plr] then
        ESP.nameTags[plr].bb:Destroy()
        ESP.nameTags[plr] = nil
    end
end

local function refreshAllESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not plr.Character then clearHighlights(plr) else applyESP(plr) end
        end
    end
    applyGunESP()
end

local function startNameTagUpdater()
    dropConn("nametag")
    trackConn("nametag", RunService.Heartbeat:Connect(function()
        if not ESP.active.NameTag then return end
        local myHRP = getHRP()
        if not myHRP then return end
        for plr, data in pairs(ESP.nameTags) do
            if plr.Character and data.lbl then
                local theirHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                local role = getMM2Role(plr)
                local label
                local color
                if role == "Murderer" then
                    label = "Murderer · " .. plr.DisplayName
                    color = ESP_COLORS.MM2.Murderer
                elseif role == "Sheriff" then
                    label = "Sheriff · " .. plr.DisplayName
                    color = ESP_COLORS.MM2.Sheriff
                elseif role == "Hero" then
                    label = "Hero · " .. plr.DisplayName
                    color = ESP_COLORS.MM2.Hero
                else
                    label = plr.DisplayName
                    color = Color3.fromRGB(255, 255, 255)
                end
                if theirHRP then
                    local dist = math.floor((myHRP.Position - theirHRP.Position).Magnitude)
                    data.lbl.Text = label .. "\n" .. dist .. "m"
                else
                    data.lbl.Text = label
                end
                data.lbl.TextColor3 = color
            end
        end
    end))
end

local function stopNameTagUpdater()
    dropConn("nametag")
end

local function getFadeEvent()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    local gameplay = remotes:FindFirstChild("Gameplay")
    if not gameplay then return nil end
    return gameplay:FindFirstChild("Fade")
end

local function findGunHolder()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local char = plr.Character
            local bp = plr:FindFirstChildOfClass("Backpack")
            if (char and char:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun")) then
                return plr
            end
        end
    end
    return nil
end

local function isSheriffDead()
    for username, info in pairs(S.roleCache) do
        if info.Role == "Sheriff" and info.Dead then
            return true, username
        end
    end
    return false, nil
end

local function clearHeroFlags()
    for username, info in pairs(S.roleCache) do
        if info.Role == "Hero" then
            info.Role = "Innocent"
            info.IsHero = false
        end
    end
end

local function stopHeroWatcher()
    S.heroWatcher.active = false
    if S.heroWatcher.thread then
        pcall(task.cancel, S.heroWatcher.thread)
        S.heroWatcher.thread = nil
    end
end

local function startHeroWatcher()
    if S.heroWatcher.active then return end
    S.heroWatcher.active = true
    S.heroWatcher.thread = trackThread(task.spawn(function()
        while S.heroWatcher.active do
            task.wait(0.4)
            if not S.heroWatcher.active then break end
            local sheriffDead, sheriffName = isSheriffDead()
            if sheriffDead then
                local holder = findGunHolder()
                if holder then
                    local currentInfo = S.roleCache[holder.Name]
                    if currentInfo then
                        if currentInfo.Role == "Sheriff" then
                            task.wait(0.3)
                        else
                            currentInfo.Role = "Hero"
                            currentInfo.IsHero = true
                            S.heroWatcher.originalSheriffName = sheriffName
                            if holder.Character then
                                clearHighlights(holder)
                                applyESP(holder)
                            end
                            S.heroWatcher.active = false
                            break
                        end
                    else
                        S.roleCache[holder.Name] = {
                            UserId = holder.UserId,
                            Role = "Hero",
                            Dead = false,
                            IsHero = true,
                        }
                        if holder.Character then
                            clearHighlights(holder)
                            applyESP(holder)
                        end
                        S.heroWatcher.originalSheriffName = sheriffName
                        S.heroWatcher.active = false
                        break
                    end
                end
            end
        end
        S.heroWatcher.thread = nil
    end))
end

local function onRoundBegin()
    clearHeroFlags()
    stopHeroWatcher()
    task.delay(1.5, function()
        if S.roundActive then startHeroWatcher() end
    end)
end

local function onRoundEnd()
    stopHeroWatcher()
    S.heroWatcher.originalSheriffName = nil
    clearHeroFlags()
    clearGunESP()
    clearBeamPool(S.beamData)
end

local function updateRoleCache(data)
    if type(data) ~= "table" then return end
    for username, info in pairs(data) do
        if type(info) == "table" and info.Role then
            S.roleCache[username] = {
                UserId = info.UserId,
                Role   = info.Role,
                Dead   = info.Dead or false,
                Perk   = info.Perk,
                Knife  = info.Knife,
                Gun    = info.Gun,
                XP     = info.XP,
                Killed = info.Killed or false,
            }
            if info.Role == "Sheriff" and info.Dead then
                task.defer(function()
                    if S.heroWatcher.active == false then startHeroWatcher() end
                end)
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if plr.Character then
                clearHighlights(plr)
                applyESP(plr)
            else
                clearHighlights(plr)
            end
        end
    end
    refreshBeam()
end

local function hookFadeEvent()
    if S.fadeConn then S.fadeConn:Disconnect(); S.fadeConn = nil end
    local ev = getFadeEvent()
    if not ev then return end
    S.fadeConn = ev.OnClientEvent:Connect(function(...)
        updateRoleCache(...)
    end)
end

hookFadeEvent()

trackThread(task.spawn(function()
    while true do
        task.wait(3)
        if not S.fadeConn or not getFadeEvent() then hookFadeEvent() end
    end
end))

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        plr.CharacterAdded:Connect(function()
            task.wait(0.3); clearHighlights(plr); applyESP(plr)
        end)
        plr.CharacterRemoving:Connect(function() clearHighlights(plr) end)
    end
end
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.3); clearHighlights(plr); applyESP(plr)
    end)
end)
Players.PlayerRemoving:Connect(function(plr)
    clearHighlights(plr)
    S.roleCache[plr.Name] = nil
    TargetVisibility[plr] = nil
    VisCache[plr] = nil
end)

local function applyKorblox()
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local function buildKorblox(ru)
        local existing = char:FindFirstChild("HH_KorbloxMesh")
        if existing then existing:Destroy() end
        local newPart = Instance.new("Part")
        newPart.Name = "HH_KorbloxMesh"
        newPart.Size = Vector3.new(1, 2, 1)
        newPart.Transparency = 0
        newPart.CanCollide = false
        newPart.Massless = true
        newPart.Anchored = false
        newPart.Color = Color3.new(1, 1, 1)
        newPart.CFrame = ru.CFrame
        newPart.Parent = char
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://902942096"
        mesh.TextureId = "rbxassetid://902843398"
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Parent = newPart
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = newPart
        weld.Part1 = ru
        weld.Parent = newPart
        S.korbloxPart = newPart
    end
    if hum.RigType == Enum.HumanoidRigType.R15 then
        local rf = char:FindFirstChild("RightFoot")
        local rl = char:FindFirstChild("RightLowerLeg")
        local ru = char:FindFirstChild("RightUpperLeg")
        if ru and rl and rf then
            rf.Transparency = 1
            rl.Transparency = 1
            ru.Transparency = 1
            buildKorblox(ru)
        end
    else
        local rightLeg = char:FindFirstChild("Right Leg")
        if rightLeg then
            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("CharacterMesh") and v.BodyPart == Enum.BodyPart.RightLeg then v:Destroy() end
            end
            local mesh = rightLeg:FindFirstChildOfClass("SpecialMesh")
            if not mesh then mesh = Instance.new("SpecialMesh"); mesh.Parent = rightLeg end
            rightLeg.Color = Color3.fromRGB(64, 64, 64)
            rightLeg.Transparency = 0
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = "rbxassetid://101851696"
            mesh.TextureId = "rbxassetid://101851254"
            mesh.Scale = Vector3.new(1, 1, 1)
        end
    end
end

local function removeKorblox()
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if S.korbloxPart and S.korbloxPart.Parent then S.korbloxPart:Destroy() end
    S.korbloxPart = nil
    if hum.RigType == Enum.HumanoidRigType.R15 then
        local rf = char:FindFirstChild("RightFoot")
        local rl = char:FindFirstChild("RightLowerLeg")
        local ru = char:FindFirstChild("RightUpperLeg")
        if rf then rf.Transparency = 0 end
        if rl then rl.Transparency = 0 end
        if ru then
            ru.Transparency = 0
            local mesh = ru:FindFirstChild("HH_KorbloxMesh")
            if mesh then mesh:Destroy() end
        end
    else
        local rightLeg = char:FindFirstChild("Right Leg")
        if rightLeg then
            local mesh = rightLeg:FindFirstChildOfClass("SpecialMesh")
            if mesh then mesh:Destroy() end
            rightLeg.Color = Color3.fromRGB(163, 162, 165)
        end
    end
end

local function applyAnimPack()
    local char = LocalPlayer.Character; if not char then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    local function replaceFolder(folderName, newId)
        local folder = animate:FindFirstChild(folderName)
        if not folder then return end
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Animation") then child.AnimationId = newId end
        end
    end
    replaceFolder("idle",  CUSTOM_ANIMS.idle.id)
    replaceFolder("walk",  CUSTOM_ANIMS.walk.id)
    replaceFolder("run",   CUSTOM_ANIMS.run.id)
    replaceFolder("fall",  CUSTOM_ANIMS.fall.id)
    replaceFolder("climb", CUSTOM_ANIMS.climb.id)
    replaceFolder("jump",  CUSTOM_ANIMS.jump.id)
    animate.Disabled = true
    task.wait(0.05)
    animate.Disabled = false
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    local function getPriorityForId(id)
        if not id then return nil end
        if id == CUSTOM_ANIMS.idle.id  then return CUSTOM_ANIMS.idle.priority end
        if id == CUSTOM_ANIMS.walk.id  then return CUSTOM_ANIMS.walk.priority end
        if id == CUSTOM_ANIMS.run.id   then return CUSTOM_ANIMS.run.priority end
        if id == CUSTOM_ANIMS.fall.id  then return CUSTOM_ANIMS.fall.priority end
        if id == CUSTOM_ANIMS.climb.id then return CUSTOM_ANIMS.climb.priority end
        if id == CUSTOM_ANIMS.jump.id  then return CUSTOM_ANIMS.jump.priority end
        return nil
    end
    task.wait(0.5)
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local id = track.Animation and track.Animation.AnimationId
        local prio = getPriorityForId(id)
        if prio then pcall(function() track.Priority = prio end) end
    end
    if S.animPriorityConn then S.animPriorityConn:Disconnect(); S.animPriorityConn = nil end
    S.animPriorityConn = animator.AnimationPlayed:Connect(function(track)
        local id = track.Animation and track.Animation.AnimationId
        local prio = getPriorityForId(id)
        if prio then pcall(function() track.Priority = prio end) end
    end)
end

local function getCoinContainer()
    local maps = {
        "ResearchFacility", "House2", "Mansion2", "Hotel", "MilBase", "Bank2",
        "BioLab", "Factory", "Workplace", "PoliceStation", "Office3",
        "Hospital3", "Town", "Town2", "Mansion", "House"
    }
    for _, mapName in ipairs(maps) do
        local map = workspace:FindFirstChild(mapName)
        if map then
            local c = map:FindFirstChild("CoinContainer", true)
            if c then return c end
        end
    end
    local c = workspace:FindFirstChild("CoinContainer", true)
    if c then return c end
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and (child.Name:find("Map") or child.Name:find("map")) then
            local c2 = child:FindFirstChild("CoinContainer", true)
            if c2 then return c2 end
        end
    end
    return nil
end

local FAST_FLAGS = {
    ["DFIntTaskSchedulerTargetFps"]            = "9999",
    ["FFlagTaskSchedulerLimitTargetFpsTo2402"] = "false",
    ["DFIntRenderThrottleMaxFps"]              = "9999",
    ["FFlagDebugDisableShadows"]               = "true",
    ["FIntRenderShadowIntensity"]              = "0",
    ["FFlagAdServiceEnabled"]                  = "false",
    ["DFIntMinimumFrameTime"]                  = "1",
    ["FFlagDisablePostFx"]                     = "true",
    ["FFlagRenderCheckThreading"]              = "true",
    ["DFIntConnectionMTimesBeforeChain"]       = "1",
    ["DFIntSchedulerWaitTime"]                 = "1",
}

local function applyFastFlags()
    if type(setfflag) ~= "function" then return end
    for flag, val in pairs(FAST_FLAGS) do
        pcall(setfflag, flag, val)
    end
end

local function enableUltraOptimization()
    if S.ultraOptActive then return end
    S.ultraOptActive = true
    applyFastFlags()

    local lighting = game:GetService("Lighting")
    S.savedLighting = { GlobalShadows = lighting.GlobalShadows, FogEnd = lighting.FogEnd }
    lighting.GlobalShadows = false
    lighting.FogEnd = 5000

    S.savedLightingEffects = {}
    for _, v in ipairs(lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Sky") then
            S.savedLightingEffects[v] = v.Enabled
            pcall(function() v.Enabled = false end)
        end
    end

    pcall(function()
        workspace.Terrain.WaterWaveSize = 0
        workspace.Terrain.WaterWaveSpeed = 0
        workspace.Terrain.WaterReflectance = 0
        workspace.Terrain.WaterTransparency = 1
    end)
end

local function disableUltraOptimization()
    if not S.ultraOptActive then return end
    S.ultraOptActive = false

    if S.savedLighting then
        local lighting = game:GetService("Lighting")
        for k, v in pairs(S.savedLighting) do
            pcall(function() lighting[k] = v end)
        end
        S.savedLighting = nil
    end

    if S.savedLightingEffects then
        for obj, enabled in pairs(S.savedLightingEffects) do
            if obj and obj.Parent then
                pcall(function() obj.Enabled = enabled end)
            end
        end
        S.savedLightingEffects = nil
    end
end

local function getHelperRefs(name)
    if name == "AntiAFK"   then return UI.afkRef,       MiscSettings,     "AntiAFK"   end
    if name == "AntiFling" then return UI.antiFlingRef, MovementSettings, "AntiFling" end
    if name == "AntiVoid"  then return UI.antiVoidRef,  MiscSettings,     "AntiVoid"  end
    if name == "Noclip"    then return UI.noclipRef,    MovementSettings, "Noclip"    end
    return nil, nil, nil
end

local function ensureHelper(name)
    local ref, tbl, key = getHelperRefs(name)
    if not ref or not tbl or not key then return end
    S.savedFarmStates = S.savedFarmStates or {}
    if S.savedFarmStates[name] == nil then
        S.savedFarmStates[name] = { orig = tbl[key], forced = false }
    end
    local st = S.savedFarmStates[name]
    if not tbl[key] then
        tbl[key] = true
        st.forced = true
        if ref.SetState then
            pcall(function() ref:SetState(true) end)
        end
    end
end

local function restoreHelper(name)
    local ref, tbl, key = getHelperRefs(name)
    if not ref or not tbl or not key then return end
    S.savedFarmStates = S.savedFarmStates or {}
    local st = S.savedFarmStates[name]
    if not st or not st.forced then
        S.savedFarmStates[name] = nil
        return
    end
    if tbl[key] ~= st.orig then
        tbl[key] = st.orig
        if ref.SetState then
            pcall(function() ref:SetState(st.orig) end)
        end
    end
    S.savedFarmStates[name] = nil
end

local function ensureFarmHelpers()
    ensureHelper("AntiAFK")
    ensureHelper("AntiFling")
    ensureHelper("AntiVoid")
end

local function restoreFarmHelpers()
    restoreHelper("AntiAFK")
    restoreHelper("AntiFling")
    restoreHelper("AntiVoid")
end

local function ensureFarmNoclip()
    if not S.roundActive then return end
    ensureHelper("Noclip")
end

local function restoreFarmNoclip()
    restoreHelper("Noclip")
end

local function getAllCoins()
    local cc = getCoinContainer()
    if not cc then return {} end
    local coins = {}
    for _, child in ipairs(cc:GetChildren()) do
        local part = child:IsA("BasePart") and child or (child:IsA("Model") and child.PrimaryPart)
        if part and part:IsA("BasePart") then
            table.insert(coins, part)
        end
    end
    return coins
end

local function countCoinNeighbors(coins, target, radius)
    local n = 0
    for _, other in ipairs(coins) do
        if other ~= target and (other.Position - target.Position).Magnitude <= radius then
            n = n + 1
        end
    end
    return n
end

local function attachFarmGyro()
    local hrp = getHRP()
    if not hrp then return end
    if S.coinGyro then S.coinGyro:Destroy() end
    S.coinGyro = Instance.new("BodyGyro")
    S.coinGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    S.coinGyro.P = 1e5
    S.coinGyro.D = 500
    S.coinGyro.CFrame = CFrame.new(hrp.Position)
    S.coinGyro.Parent = hrp
    S.lastGyroUpdate = tick()
end

local function ensureFarmBodyMovers()
    local hrp = getHRP()
    if not hrp then return end
    local hum = getHumanoid()
    if hum and not hum.PlatformStand then hum.PlatformStand = true end
    if not S.farmWalkBV or not S.farmWalkBV.Parent then
        S.farmWalkBV = Instance.new("BodyVelocity")
        S.farmWalkBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        S.farmWalkBV.P = 500
        S.farmWalkBV.Parent = hrp
    end
end

local function stopFarmBodyMovers()
    if S.farmWalkBV then
        S.farmWalkBV.Velocity = Vector3.zero
        S.farmWalkBV:Destroy()
        S.farmWalkBV = nil
    end
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
    local hrp = getHRP()
    if hrp and hrp.Position.Y < -50 then
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 60, 0)
    end
end

local function stopCoinCollector()
    if not S.coinCollecting then return end
    S.coinCollecting = false
    if S.coinConnection then S.coinConnection:Disconnect(); S.coinConnection = nil end
    if S.coinGyro then S.coinGyro:Destroy(); S.coinGyro = nil end
    stopFarmBodyMovers()
    disableUltraOptimization()
    S.farmTargetCoin = nil
    S.farmTouchedCoins = {}
    S.farmLastCollectAt = 0
    S.farmStartedAt = 0
    S.farmLastFallbackAt = 0
    S.farmLastPos = nil
    S.farmLastPosTime = 0
    S.lastGyroUpdate = 0
    if S.coinStatusSetter then S.coinStatusSetter("Idle") end
    stopMiniBoxAnimation()
    local hrp = getHRP()
    if hrp then
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end
end

local function startCoinCollector()
    if S.coinCollecting then return end
    if not getCoinContainer() then return end
    if not getHRP() then return end

    S.coinCollecting = true
    S.farmTargetCoin = nil
    S.farmTouchedCoins = {}
    S.farmStartedAt = tick()
    S.farmLastCollectAt = tick()
    S.farmLastFallbackAt = tick()
    S.farmLastPos = nil
    S.farmLastPosTime = 0
    if S.coinStatusSetter then S.coinStatusSetter("Flowing") end
    playMiniBoxAnimation()
    ensureFarmHelpers()
    ensureFarmNoclip()
    if FarmSettings.UltraOpt then enableUltraOptimization() end
    attachFarmGyro()
    ensureFarmBodyMovers()

    S.coinConnection = RunService.Heartbeat:Connect(function()
        if not S.coinCollecting then return end
        if not S.roundActive then stopCoinCollector() return end
        if S.totalCoins >= FARM_GOAL then
            if S.coinStatusSetter then S.coinStatusSetter("Goal reached") end
            stopCoinCollector()
            return
        end

        local hrp = getHRP()
        if not hrp then stopCoinCollector() return end

        local now = tick()

        if S.coinGyro and S.coinGyro.Parent then
            if now - S.lastGyroUpdate > 0.15 then
                S.coinGyro.CFrame = CFrame.new(hrp.Position)
                S.lastGyroUpdate = now
            end
        elseif not S.coinGyro then
            attachFarmGyro()
        end

        if now - math.max(S.farmStartedAt, S.lastCollectTime) > FARM_STALL_TIMEOUT then
            if S.coinStatusSetter then S.coinStatusSetter("Stalled") end
            stopCoinCollector()
            return
        end

        if not S.farmWalkBV or not S.farmWalkBV.Parent then
            ensureFarmBodyMovers()
            if not S.farmWalkBV then return end
        end

        local coins = getAllCoins()
        if #coins == 0 then
            S.farmWalkBV.Velocity = Vector3.zero
            return
        end

        local myPos = hrp.Position

        for _, coin in ipairs(coins) do
            if coin and coin.Parent then
                local d = (coin.Position - myPos).Magnitude
                if d <= FARM_TOUCH_RADIUS then
                    local lastTouch = S.farmTouchedCoins[coin]
                    if not lastTouch or now - lastTouch > FARM_TOUCH_COOLDOWN then
                        S.farmTouchedCoins[coin] = now
                        task.spawn(function()
                            pcall(firetouchinterest, hrp, coin, 0)
                            task.wait(0.02)
                            if coin and coin.Parent then
                                pcall(firetouchinterest, hrp, coin, 1)
                            end
                        end)
                    end
                end
            end
        end

        for coin, t in pairs(S.farmTouchedCoins) do
            if now - t > 5 or not coin.Parent then S.farmTouchedCoins[coin] = nil end
        end

        local murderer = getMurdererCached()
        local mHRP = murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
        local distToMurderer = mHRP and (myPos - mHRP.Position).Magnitude or math.huge

        if mHRP and distToMurderer < FARM_DANGER_DIST then
            local awayDir = Vector3.new(myPos.X - mHRP.Position.X, 0, myPos.Z - mHRP.Position.Z)
            if awayDir.Magnitude < 0.1 then awayDir = Vector3.new(1, 0, 0) end
            awayDir = awayDir.Unit
            S.farmWalkBV.Velocity = awayDir * FARM_FLY_SPEED * 2 + Vector3.new(0, 4, 0)
            if S.coinStatusSetter then S.coinStatusSetter("DANGER · evading") end
            return
        end

        local timeSinceCollect = now - math.max(S.farmLastCollectAt, S.farmStartedAt)
        if timeSinceCollect > FARM_FALLBACK_TIMEOUT
            and now - S.farmLastFallbackAt > FARM_FALLBACK_COOLDOWN
            and (not mHRP or distToMurderer > 30) then
            S.farmLastFallbackAt = now
            local minSafeDist = math.max(FARM_FALLBACK_MIN_SAFE, distToMurderer + 10)
            local safeCoins = {}
            for _, coin in ipairs(coins) do
                if coin and coin.Parent then
                    if not mHRP or (coin.Position - mHRP.Position).Magnitude > minSafeDist then
                        table.insert(safeCoins, coin)
                    end
                end
            end
            if #safeCoins > 0 then
                local pick = safeCoins[math.random(1, #safeCoins)]
                local usedRemote = fireTeleportToPart(hrp, pick)
                if not usedRemote then
                    local d = (pick.Position - hrp.Position).Magnitude
                    if d < 60 then
                        hrp.CFrame = CFrame.new(pick.Position + Vector3.new(0, 3, 0))
                    end
                end
                S.farmTargetCoin = nil
                S.farmLastPos = nil
                S.farmLastPosTime = 0
                if S.coinStatusSetter then S.coinStatusSetter("Fallback → safe coin") end
            end
        end

        local target = S.farmTargetCoin
        local needNew = not target or not target.Parent
            or (target.Position - myPos).Magnitude < FARM_ARRIVE_DIST

        if needNew then
            local bestCoin, bestScore = nil, -math.huge
            local evading = distToMurderer < FARM_NEAR_DIST
            for _, coin in ipairs(coins) do
                if coin and coin.Parent then
                    local d = (coin.Position - myPos).Magnitude
                    if d > 1 then
                        local score
                        if evading and mHRP then
                            local dToM = (coin.Position - mHRP.Position).Magnitude
                            score = dToM * 3 - d
                        else
                            local nb = countCoinNeighbors(coins, coin, FARM_CLUSTER_RADIUS)
                            score = nb * 1000 - d
                        end
                        if score > bestScore then
                            bestScore = score
                            bestCoin = coin
                        end
                    end
                end
            end
            target = bestCoin
            S.farmTargetCoin = bestCoin
            S.farmLastPos = nil
            S.farmLastPosTime = 0
        end

        if target and target.Parent then
            local targetPos = target.Position + Vector3.new(0, FARM_GROUND_OFFSET, 0)
            local delta = targetPos - myPos
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            local hDist = horiz.Magnitude
            if hDist > 0.5 then
                local speedMul = distToMurderer < FARM_NEAR_DIST and 1.4 or 1.0
                local speed = math.min(FARM_FLY_SPEED * speedMul, hDist * 5)
                S.farmWalkBV.Velocity = horiz.Unit * speed + Vector3.new(0, math.clamp(delta.Y * 2, -8, 8), 0)
            else
                S.farmWalkBV.Velocity = Vector3.new(0, math.clamp(delta.Y * 2, -8, 8), 0)
            end

            if not S.farmLastPos then
                S.farmLastPos = myPos
                S.farmLastPosTime = now
            elseif (myPos - S.farmLastPos).Magnitude > FARM_STUCK_DIST then
                S.farmLastPos = myPos
                S.farmLastPosTime = now
            elseif now - S.farmLastPosTime > FARM_STUCK_TIME then
                S.farmTargetCoin = nil
                S.farmLastPos = nil
                S.farmLastPosTime = 0
                if S.coinStatusSetter then S.coinStatusSetter("Unsticking · " .. #coins .. " coins") end
            end
        else
            S.farmWalkBV.Velocity = Vector3.zero
        end

        if S.coinStatusSetter then
            if distToMurderer < FARM_NEAR_DIST then
                S.coinStatusSetter("Evading · " .. #coins .. " coins")
            else
                S.coinStatusSetter("Flowing · " .. #coins .. " coins")
            end
        end
    end)
end

local function stopEvasion()
    if S.evasionThread then
        pcall(task.cancel, S.evasionThread)
        S.evasionThread = nil
    end
end

local function startEvasion()
    if S.evasionThread then return end
    S.evasionThread = task.spawn(function()
        while S.roundActive do
            task.wait(0.15)
            if not FarmSettings.AutoFarm then continue end
            if S.coinCollecting then continue end
            local myHRP = getHRP()
            if not myHRP then continue end
            local murderer = getMurdererCached()
            if not murderer or not murderer.Character then continue end
            local murderHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
            if not murderHRP then continue end
            local dist = (myHRP.Position - murderHRP.Position).Magnitude
            if dist < 25 then
                local evadeDir = (myHRP.Position - murderHRP.Position).Unit
                local evadePos = myHRP.Position + evadeDir * 40
                local hum = getHumanoid()
                if hum then
                    pcall(function() hum:MoveTo(evadePos) end)
                end
            end
        end
        S.evasionThread = nil
    end)
end

local function shouldWaitForCoins()
    if not S.coinCollecting then return false end
    if not S.roundActive then return false end
    if S.totalCoins >= FARM_GOAL then return false end
    return true
end

local function getFlingTargetByName(name)
    if not name then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and (plr.Name == name or plr.DisplayName == name) then
            return plr
        end
    end
    return nil
end

local function yarhmFling(targetPlr)
    if not targetPlr or not targetPlr.Character then return false, "no target character" end
    if targetPlr == LocalPlayer then return false, "cannot fling self" end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not (char and hum and root) then return false, "no local character" end

    local tChar = targetPlr.Character
    local tHum = tChar:FindFirstChildOfClass("Humanoid")
    local tRoot = tHum and tHum.RootPart
    local tHead = tChar:FindFirstChild("Head")
    local tAccessory = tChar:FindFirstChildOfClass("Accessory")
    local tHandle = tAccessory and tAccessory:FindFirstChild("Handle")

    if not tChar:FindFirstChildWhichIsA("BasePart") then return false, "target has no parts" end

    local oldFPDH = workspace.FallenPartsDestroyHeight
    local oldPos = root.CFrame
    workspace.FallenPartsDestroyHeight = 0/0

    local oldCamSubject = workspace.CurrentCamera.CameraSubject
    if tHead then
        workspace.CurrentCamera.CameraSubject = tHead
    elseif tHandle then
        workspace.CurrentCamera.CameraSubject = tHandle
    elseif tHum then
        workspace.CurrentCamera.CameraSubject = tHum
    end

    local function FPos(basePart, posOffset, angOffset)
        local newCF = CFrame.new(basePart.Position) * posOffset * angOffset
        root.CFrame = newCF
        pcall(function() char:PivotTo(newCF) end)
        root.Velocity = Vector3.new(9e7, 9e8, 9e7)
        root.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local function SFBasePart(basePart)
        local deadline = tick() + 2
        local angle = 0
        repeat
            if not (root and tHum) then break end
            if basePart.Velocity.Magnitude < 50 then
                angle = angle + 100
                FPos(basePart, CFrame.new(0, 1.5, 0) + tHum.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, -1.5, 0) + tHum.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(2.25, 1.5, -2.25) + tHum.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(-2.25, -1.5, 2.25) + tHum.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, 1.5, 0) + tHum.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, -1.5, 0) + tHum.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
                task.wait()
            else
                FPos(basePart, CFrame.new(0, 1.5, tHum.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, -1.5, -tHum.WalkSpeed), CFrame.Angles(0, 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, 1.5, tHum.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, 1.5, tRoot.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, -1.5, -tRoot.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, 1.5, tRoot.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(-90), 0, 0))
                task.wait()
                FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                task.wait()
            end
        until basePart.Velocity.Magnitude > 500
            or basePart.Parent ~= tChar
            or targetPlr.Parent ~= Players
            or targetPlr.Character ~= tChar
            or tHum.Sit
            or hum.Health <= 0
            or tick() > deadline
    end

    local bv = Instance.new("BodyVelocity")
    bv.Parent = root
    bv.Velocity = Vector3.new(9e8, 9e8, 9e8)
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    local baseToUse
    if tRoot and tHead then
        if (tRoot.CFrame.Position - tHead.CFrame.Position).Magnitude > 5 then
            baseToUse = tHead
        else
            baseToUse = tRoot
        end
    elseif tRoot then
        baseToUse = tRoot
    elseif tHead then
        baseToUse = tHead
    elseif tHandle then
        baseToUse = tHandle
    end

    local success = false
    if baseToUse then
        SFBasePart(baseToUse)
        success = true
    end

    bv:Destroy()
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = oldCamSubject

    local recoverStart = tick()
    repeat
        local h = getHRP()
        if h then
            h.CFrame = oldPos * CFrame.new(0, 0.5, 0)
            h.Velocity = Vector3.zero
            h.RotVelocity = Vector3.zero
        end
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
        task.wait()
    until not getHRP() or (getHRP().Position - oldPos.Position).Magnitude < 25 or tick() > recoverStart + 3

    workspace.FallenPartsDestroyHeight = oldFPDH

    return success
end

local function startFlingTarget(targetPlr)
    if not targetPlr then notify("No target selected") return end
    if targetPlr == LocalPlayer then notify("Cannot fling yourself") return end
    if S.flingTargetRunning then return end
    if not getHRP() then notify("No character") return end

    S.flingTargetRunning = true
    notify("Flinging " .. targetPlr.DisplayName)

    S.flingTargetThread = task.spawn(function()
        local ok = yarhmFling(targetPlr)
        S.flingTargetRunning = false
        S.flingTargetThread = nil
        if ok then
            notify(targetPlr.DisplayName .. " FLINGED!")
        else
            notify(targetPlr.DisplayName .. " not flinged")
        end
    end)
end

local function attachFlyBodyMovers()
    local hrp = getHRP(); local hum = getHumanoid()
    if not hrp or not hum then return end
    hum.PlatformStand = true
    if S.flyBV then S.flyBV:Destroy() end
    if S.flyBG then S.flyBG:Destroy() end
    S.flyBV = Instance.new("BodyVelocity")
    S.flyBV.Velocity = Vector3.zero
    S.flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    S.flyBV.Parent = hrp
    S.flyBG = Instance.new("BodyGyro")
    S.flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    S.flyBG.P = 1e4
    S.flyBG.CFrame = hrp.CFrame
    S.flyBG.Parent = hrp
end

local function detachFlyBodyMovers()
    if S.flyBV then S.flyBV:Destroy(); S.flyBV = nil end
    if S.flyBG then S.flyBG:Destroy(); S.flyBG = nil end
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
end

local function getFlyInput()
    local mv = Vector3.zero
    local cam = workspace.CurrentCamera
    if isMobile then
        local hum = getHumanoid()
        if hum then
            local md = hum.MoveDirection
            if md.Magnitude > 0.1 then mv = md * Vector3.new(1, 0, 1) end
        end
        if S.mobileFlyDragging and S.mobileFlyVec.Magnitude > 0.1 then
            mv = S.mobileFlyVec
        end
        return mv
    end
    local cf = cam.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.yAxis end
    if mv.Magnitude < 0.01 then
        local hum2 = getHumanoid()
        if hum2 then
            local md = hum2.MoveDirection
            if md.Magnitude > 0.1 then mv = md * Vector3.new(1, 0, 1) end
        end
    end
    return mv
end

local function startFly()
    dropConn("fly")
    attachFlyBodyMovers()
    trackConn("fly", RunService.Heartbeat:Connect(function()
        if not MovementSettings.Fly then return end
        local h = getHRP()
        if not h then return end
        if not S.flyBV or not S.flyBV.Parent then attachFlyBodyMovers() end
        if not S.flyBV or not S.flyBG then return end
        local mv = getFlyInput()
        S.flyBV.Velocity = mv.Magnitude > 0 and mv.Unit * MovementSettings.FlySpeed or Vector3.zero
        S.flyBG.CFrame = workspace.CurrentCamera.CFrame
    end))
end

local function stopFly()
    dropConn("fly")
    detachFlyBodyMovers()
end

local function startFOVCircle()
    dropConn("fov")
    if not S.fovGui then
        S.fovGui = Instance.new("ScreenGui")
        S.fovGui.Name = "HH_FOV"
        S.fovGui.ResetOnSpawn = false
        S.fovGui.IgnoreGuiInset = true
        pcall(function() S.fovGui.Parent = game:GetService("CoreGui") end)
        if not S.fovGui.Parent then S.fovGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
        trackGui(S.fovGui)
        S.fovFrame = Instance.new("Frame")
        S.fovFrame.Name = "FOVCircle"
        S.fovFrame.BackgroundTransparency = 1
        S.fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        S.fovFrame.Size = UDim2.new(0, 200, 0, 200)
        S.fovFrame.Parent = S.fovGui
        local stroke = Instance.new("UIStroke")
        stroke.Name = "CircleStroke"
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Transparency = 0.3
        stroke.Parent = S.fovFrame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = S.fovFrame
    end
    S.fovGui.Enabled = true
    trackConn("fov", RunService.RenderStepped:Connect(function()
        if not AimbotSettings.FOVCircle then return end
        if not S.fovFrame then return end
        local radius = AimbotSettings.FOVRadius
        S.fovFrame.Size = UDim2.new(0, radius * 2, 0, radius * 2)
        if isMobile then
            local inset = game:GetService("GuiService"):GetGuiInset()
            local vp = workspace.CurrentCamera.ViewportSize
            local cx = vp.X / 2
            local cy = (vp.Y / 2) + (inset.Y / 2)
            S.fovFrame.Position = UDim2.new(0, cx, 0, cy)
        else
            S.fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        end
    end))
end

local function stopFOVCircle()
    dropConn("fov")
    if S.fovGui then S.fovGui.Enabled = false end
end

local function startMobileFlyDrag()
    if not isMobile then return end
    local dragActive = false
    local dragStart = nil
    UserInputService.TouchStarted:Connect(function(input, gp)
        if gp then return end
        if not MovementSettings.Fly then return end
        dragActive = true
        dragStart = input.Position
        S.mobileFlyDragging = true
    end)
    UserInputService.TouchMoved:Connect(function(input, gp)
        if gp then return end
        if not dragActive then return end
        if not MovementSettings.Fly then return end
        local delta = input.Position - dragStart
        local cam = workspace.CurrentCamera
        local fwd = cam.CFrame.LookVector * (-delta.Y * 0.05)
        local right = cam.CFrame.RightVector * (delta.X * 0.05)
        S.mobileFlyVec = fwd + right
    end)
    UserInputService.TouchEnded:Connect(function()
        dragActive = false
        S.mobileFlyDragging = false
        S.mobileFlyVec = Vector3.zero
    end)
end

window = nil
do
    local ok, err = pcall(function()
        window = API:CreateWindow("Happy Hub", "MM2 · Keyless · by replicatedman")
    end)
    if not ok or not window then
        warn("[HappyHub] CreateWindow failed: " .. tostring(err))
        return
    end
end

homeTab      = window:CreateTab("Home", ICONS.Home)
playersTab   = window:CreateTab("Players", ICONS.Plr)
espTab       = window:CreateTab("Visuals", ICONS.Vis)
movementTab  = window:CreateTab("Movement", ICONS.Mov)
aimbotTab    = window:CreateTab("Combat", ICONS.Aim)
avatarTab    = window:CreateTab("Avatar", ICONS.Avt)
farmTab      = window:CreateTab("Farm", ICONS.Farm)
miscTab      = window:CreateTab("Misc", ICONS.Misc)

window:CreateImageCard(homeTab, {
    Image = "rbxthumb://type=Asset&id=" .. game.PlaceId .. "&w=420&h=420",
    Title = "Murder mistery 2",
    Subtitle = "by Nikilis",
    Description = "Murder Mistery · replicatedman · v11.7 API · Open Source proyect",
    Height = 150,
    ImageWidth = 130,
    OnClick = function()
        API:Notify("Actual game", 2)
    end,
})

window:CreateLabel(homeTab, "Music")
UI.musicTrackDropdown = window:CreateDropdown(homeTab, "Track", {
    "Companion",
    "Her Boyfriend",
    "I Stalk Ur Socials",
    "EYUHH!",
    "Low Cortisol",
}, "Companion", function(v)
    MiscSettings.SelectedMusic = v
    if MiscSettings.MusicCompanion then
        playMusic()
    end
end)

UI.musicToggleRef = window:CreateToggle(homeTab, "Play Music", false, function(v)
    MiscSettings.MusicCompanion = v
    if v then
        playMusic()
    else
        stopMusic()
        notify("Music stopped")
    end
end)
registerControl(MiscSettings, "MusicCompanion", UI.musicToggleRef)

window:CreateLabel(homeTab, "Creators")
window:CreateParagraph(homeTab, "@OverthaneRBX · Developer · Hub Creator")
window:CreateParagraph(homeTab, "@ReplicatedBacon_0 · Co-Owner · Test & Scripts")
window:CreateParagraph(homeTab, "@odecode · Hexagonal Client · Farm Engine")

window:CreateLabel(homeTab, "Features")
window:CreateParagraph(homeTab, "Players · ESP · Movement · Aimbot · Avatar · Farm · Misc · Configs")

window:CreateLabel(playersTab, "Teleport")
UI.tpAllToggleRef = window:CreateToggle(playersTab, "TP All", false, function(v)
    MovementSettings.TPAll = v
    if v then
        S.tpAllRunning = true
        S.tpAllTask = task.spawn(function()
            while S.tpAllRunning do
                for _, plr in ipairs(Players:GetPlayers()) do
                    if not S.tpAllRunning then break end
                    if plr ~= LocalPlayer then
                        teleportToPlayer(plr)
                        task.wait(0.1)
                    end
                end
                task.wait(0.1)
            end
        end)
    else
        S.tpAllRunning = false
        if S.tpAllTask then task.cancel(S.tpAllTask); S.tpAllTask = nil end
    end
end)
registerControl(MovementSettings, "TPAll", UI.tpAllToggleRef)

window:CreateLabel(playersTab, "Role Teleport")
_G.__HH_TpTarget = "Murder"
window:CreateDropdown(playersTab, "Target", { "Murder", "Sheriff", "Hero" }, "Murder", function(v)
    _G.__HH_TpTarget = v
end)

window:CreateButton(playersTab, "Teleport", function()
    local target = _G.__HH_TpTarget
    local plr
    if target == "Sheriff" then plr = getSheriff()
    elseif target == "Hero" then plr = getHero()
    else plr = getMurderer() end
    if teleportToPlayer(plr) then
        notify("Teleported to " .. target)
    else
        notify("No " .. target .. " found")
    end
end)

window:CreateLabel(playersTab, "Fling")
_G.__HH_FlingTarget = nil

local function getFlingList()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    table.sort(names)
    return names
end

flingDropdownRef = window:CreateDropdown(playersTab, "Player", getFlingList(), "", function(v)
    _G.__HH_FlingTarget = v
end)

lastFlingSignature = table.concat(getFlingList(), "|")

local function refreshFlingDropdown(force)
    local names = getFlingList()
    local signature = table.concat(names, "|")
    if not force and signature == lastFlingSignature then return end
    lastFlingSignature = signature
    if flingDropdownRef then
        local refreshed = false
        if type(flingDropdownRef.Refresh) == "function" then
            refreshed = pcall(function() flingDropdownRef:Refresh(names) end)
        end
        if not refreshed and type(flingDropdownRef.SetOptions) == "function" then
            refreshed = pcall(function() flingDropdownRef:SetOptions(names) end)
        end
        if not refreshed and type(flingDropdownRef.UpdateOptions) == "function" then
            pcall(function() flingDropdownRef:UpdateOptions(names) end)
        end
    end
    if _G.__HH_FlingTarget then
        local stillHere = false
        for _, n in ipairs(names) do
            if n == _G.__HH_FlingTarget then stillHere = true; break end
        end
        if not stillHere then _G.__HH_FlingTarget = nil end
    end
end

trackThread(task.spawn(function()
    while true do
        task.wait(0.5)
        refreshFlingDropdown(false)
    end
end))

Players.PlayerAdded:Connect(function(plr)
    task.wait(0.3)
    refreshFlingDropdown(true)
    plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        refreshFlingDropdown(true)
    end)
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.3)
    refreshFlingDropdown(true)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            refreshFlingDropdown(true)
        end)
    end
end

window:CreateButton(playersTab, "Refresh List", function()
    refreshFlingDropdown(true)
    notify("Player list refreshed", 2)
end)

window:CreateButton(playersTab, "Fling Target", function()
    local plr = getFlingTargetByName(_G.__HH_FlingTarget)
    if not plr then notify("Select a player") return end
    startFlingTarget(plr)
end)

window:CreateButton(playersTab, "Fling Murderer", function()
    local plr = getMurderer()
    if not plr then notify("No Murderer found") return end
    startFlingTarget(plr)
end)

window:CreateButton(playersTab, "Fling Sheriff", function()
    local plr = getSheriff()
    if not plr then notify("No Sheriff/Hero found") return end
    startFlingTarget(plr)
end)

window:CreateLabel(playersTab, "Server")
window:CreateButton(playersTab, "Rejoin", function()
    pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end)
window:CreateButton(playersTab, "Server Hop", function()
    pcall(function()
        local data = game:GetService("HttpService"):JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        )
        if data and data.data then
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    return
                end
            end
        end
    end)
end)

window:CreateLabel(espTab, "ESP")
UI.mm2ESPToggleRef = window:CreateToggle(espTab, "Roles", false, function(v)
    ESP.active.MM2 = v
    VisualSettings.MM2ESP = v
    refreshAllESP()
    if v then
        if not ConnectionRegistry["rolesesp"] then
            trackConn("rolesesp", RunService.Heartbeat:Connect(function()
                if ESP.active.MM2 or VisualSettings.GunESP then
                    if ESP.active.MM2 then refreshAllESP() end
                    if VisualSettings.GunESP then applyGunESP() end
                end
            end))
        end
    else
        dropConn("rolesesp")
    end
end)
registerControl(VisualSettings, "MM2ESP", UI.mm2ESPToggleRef)

UI.ogESPToggleRef = window:CreateToggle(espTab, "Neutral", false, function(v)
    ESP.active.OG = v
    VisualSettings.OGESP = v
    refreshAllESP()
end)
registerControl(VisualSettings, "OGESP", UI.ogESPToggleRef)

window:CreateLabel(espTab, "Additional")
UI.nameTagToggleRef = window:CreateToggle(espTab, "Nametag", false, function(v)
    ESP.active.NameTag = v
    VisualSettings.NameTags = v
    refreshAllESP()
    if v then startNameTagUpdater() else stopNameTagUpdater() end
end)
registerControl(VisualSettings, "NameTags", UI.nameTagToggleRef)

UI.gunESPToggleRef = window:CreateToggle(espTab, "Gun", false, function(v)
    VisualSettings.GunESP = v
    applyGunESP()
    if v then
        if not ConnectionRegistry["gunesp"] then
            trackConn("gunesp", RunService.Heartbeat:Connect(function()
                if VisualSettings.GunESP then applyGunESP() end
            end))
        end
    else
        dropConn("gunesp")
        clearGunESP()
    end
end)
registerControl(VisualSettings, "GunESP", UI.gunESPToggleRef)

window:CreateLabel(espTab, "Beam")
UI.beamToggleRef = window:CreateToggle(espTab, "Beam", false, function(v)
    VisualSettings.Beam = v
    if v then ensureBeamConn() end
    stopBeamIfIdle()
end)
registerControl(VisualSettings, "Beam", UI.beamToggleRef)

window:CreateLabel(espTab, "Spectate")
window:CreateButton(espTab, "Spectate Murderer", function()
    local m = getMurderer()
    if not m then notify("No murderer") return end
    spectatePlayer(m)
    notify("Spectating " .. m.DisplayName)
end)

window:CreateButton(espTab, "Spectate Sheriff", function()
    local s = getSheriff()
    if not s then notify("No sheriff") return end
    spectatePlayer(s)
    notify("Spectating " .. s.DisplayName)
end)

window:CreateButton(espTab, "Spectate Hero", function()
    local h = getHero()
    if not h then notify("No hero") return end
    spectatePlayer(h)
    notify("Spectating " .. h.DisplayName)
end)

window:CreateButton(espTab, "Stop Spectating", function()
    stopSpectating()
    notify("Stopped spectating")
end)

window:CreateLabel(movementTab, "Fly")
UI.flyToggleRef = window:CreateToggle(movementTab, "Fly", false, function(v)
    MovementSettings.Fly = v
    if v then startFly() else stopFly() end
end)
registerControl(MovementSettings, "Fly", UI.flyToggleRef)

UI.flySpeedRef = window:CreateSlider(movementTab, "Fly Speed", 5, 200, 40, function(v) MovementSettings.FlySpeed = v end)
registerControl(MovementSettings, "FlySpeed", UI.flySpeedRef)

window:CreateLabel(movementTab, "Speed")
UI.walkSpeedRef = window:CreateSlider(movementTab, "Walk Speed", 4, 150, 16, function(v)
    MovementSettings.WalkSpeed = v
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = v end
end)
registerControl(MovementSettings, "WalkSpeed", UI.walkSpeedRef)

UI.jumpPowerRef = window:CreateSlider(movementTab, "Jump Power", 10, 200, 50, function(v)
    MovementSettings.JumpPower = v
    local hum = getHumanoid()
    if hum then hum.JumpPower = v; hum.UseJumpPower = true end
end)
registerControl(MovementSettings, "JumpPower", UI.jumpPowerRef)

window:CreateLabel(movementTab, "Modifications")
UI.noclipRef = window:CreateToggle(movementTab, "Noclip", false, function(v)
    MovementSettings.Noclip = v
    if v then
        trackConn("noclip", RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end))
    else
        dropConn("noclip")
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end)
registerControl(MovementSettings, "Noclip", UI.noclipRef)

UI.godRef = window:CreateToggle(movementTab, "God Mode", false, function(v)
    MovementSettings.God = v
    if v then
        trackConn("god", RunService.Heartbeat:Connect(function()
            local hum = getHumanoid()
            if hum then hum.Health = hum.MaxHealth end
        end))
    else
        dropConn("god")
    end
end)
registerControl(MovementSettings, "God", UI.godRef)

UI.antiVoidRef = window:CreateToggle(movementTab, "Anti-Void", false, function(v)
    MiscSettings.AntiVoid = v
    if v then startAntiVoid() else stopAntiVoid() end
end)
registerControl(MiscSettings, "AntiVoid", UI.antiVoidRef)

UI.ijRef = window:CreateToggle(movementTab, "Infinite Jump", false, function(v)
    MiscSettings.InfJump = v
end)
registerControl(MiscSettings, "InfJump", UI.ijRef)

trackConn("jump", UserInputService.JumpRequest:Connect(function()
    if MiscSettings.InfJump then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

UI.afkRef = window:CreateToggle(movementTab, "Anti-AFK", false, function(v)
    MiscSettings.AntiAFK = v
    if v then
        local vu = game:GetService("VirtualUser")
        trackConn("antiafk", LocalPlayer.Idled:Connect(function()
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end))
    else
        dropConn("antiafk")
    end
end)
registerControl(MiscSettings, "AntiAFK", UI.afkRef)

UI.antiFlingRef = window:CreateToggle(movementTab, "Anti-Fling", false, function(v)
    MovementSettings.AntiFling = v
    if v then
        S.antiFlingActive = true
        local function disableHRPCollision(plr)
            if plr == LocalPlayer then return end
            local char = plr.Character; if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CanCollide = false end
        end
        for _, plr in ipairs(Players:GetPlayers()) do disableHRPCollision(plr) end
        local conn = Players.PlayerAdded:Connect(function(plr)
            if plr == LocalPlayer then return end
            plr.CharacterAdded:Connect(function(char)
                task.wait(0.1)
                if S.antiFlingActive then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CanCollide = false end
                end
            end)
        end)
        table.insert(S.antiFlingConnections, conn)
    else
        S.antiFlingActive = false
        local function enableHRPCollision(plr)
            if plr == LocalPlayer then return end
            local char = plr.Character; if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CanCollide = true end
        end
        for _, plr in ipairs(Players:GetPlayers()) do enableHRPCollision(plr) end
        for _, c in ipairs(S.antiFlingConnections) do c:Disconnect() end
        S.antiFlingConnections = {}
    end
end)
registerControl(MovementSettings, "AntiFling", UI.antiFlingRef)

window:CreateLabel(movementTab, "Emotes")
for _, emote in ipairs(EMOTES) do
    window:CreateButton(movementTab, emote.name, function()
        playEmote(emote.name, emote.id)
    end)
end

window:CreateButton(movementTab, "Stop Emote", function()
    if S.currentEmoteTrack then
        pcall(function() S.currentEmoteTrack:Stop(0.1) end)
        S.currentEmoteTrack = nil
        notify("Emote stopped", 1.5)
    end
end)

window:CreateLabel(movementTab, "Reset")
window:CreateButton(movementTab, "Autokill", function()
    local hum = getHumanoid()
    if hum then hum.Health = 0 end
end)

window:CreateLabel(movementTab, "Fling")
UI.flingToggleRef = window:CreateToggle(movementTab, "Fling", false, function(v)
    MovementSettings.Fling = v
    if v then
        if S.flingRunning then return end
        S.flingRunning = true
        S.flingTask = task.spawn(function()
            while S.flingRunning do
                task.wait()
                local character = LocalPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local velo = hrp.Velocity
                    hrp.Velocity = velo * 10000 + Vector3.new(0, 10000, 0)
                    RunService.RenderStepped:Wait()
                    hrp.Velocity = velo
                    RunService.Stepped:Wait()
                end
            end
            S.flingTask = nil
        end)
    else
        S.flingRunning = false
        if S.flingTask then task.cancel(S.flingTask); S.flingTask = nil end
        local hrp = getHRP()
        if hrp then hrp.Velocity = Vector3.zero end
    end
end)
registerControl(MovementSettings, "Fling", UI.flingToggleRef)

window:CreateLabel(aimbotTab, "Aimbot")
UI.mm2LockRef = window:CreateToggle(aimbotTab, "Aimbot", false, function(v)
    AimbotSettings.MM2LockOn = v
    if v then
        trackConn("aimbot", RunService.RenderStepped:Connect(function()
            if not AimbotSettings.MM2LockOn then return end
            local murderer = getMurdererCached()
            if not isTargetSafe(murderer) then return end
            local targetPart = getMM2TargetPart(murderer.Character)
            local myHRP = getHRP()
            if not targetPart or not myHRP then return end
            local dist = (myHRP.Position - targetPart.Position).Magnitude
            if dist > AimbotSettings.MM2Range then return end
            if not isVisibleForShot(myHRP.Position, targetPart.Position, murderer.Character, murderer) then return end
            if AimbotSettings.FOVCircle then
                local cam = workspace.CurrentCamera
                if cam then
                    local sp, on = cam:WorldToViewportPoint(targetPart.Position)
                    if on then
                        local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
                        if (Vector2.new(sp.X, sp.Y) - center).Magnitude > AimbotSettings.FOVRadius then return end
                    end
                end
            end
            local camera = workspace.CurrentCamera
            local targetCF = CFrame.new(camera.CFrame.Position, targetPart.Position)
            local alpha = math.clamp(1 / AimbotSettings.MM2Smooth, 0.02, 1)
            camera.CFrame = camera.CFrame:Lerp(targetCF, alpha)
        end))
    else
        dropConn("aimbot")
    end
end)
registerControl(AimbotSettings, "MM2LockOn", UI.mm2LockRef)

UI.mm2SmoothRef = window:CreateSlider(aimbotTab, "Smoothness", 1, 30, 8, function(v) AimbotSettings.MM2Smooth = v end)
registerControl(AimbotSettings, "MM2Smooth", UI.mm2SmoothRef)

UI.mm2RangeRef = window:CreateSlider(aimbotTab, "Distance", 50, 1000, 500, function(v) AimbotSettings.MM2Range = v end)
registerControl(AimbotSettings, "MM2Range", UI.mm2RangeRef)

UI.mm2TargetRef = window:CreateDropdown(aimbotTab, "Target Bone", { "Head", "Torso", "Small Avatar" }, "Head", function(v)
    AimbotSettings.MM2Target = v
end)
registerControl(AimbotSettings, "MM2Target", UI.mm2TargetRef)

UI.fovToggleRef = window:CreateToggle(aimbotTab, "FOV Circle", false, function(v)
    AimbotSettings.FOVCircle = v
    if v then startFOVCircle() else stopFOVCircle() end
end)
registerControl(AimbotSettings, "FOVCircle", UI.fovToggleRef)

UI.fovRadiusRef = window:CreateSlider(aimbotTab, "FOV Radius", 40, 500, 120, function(v) AimbotSettings.FOVRadius = v end)
registerControl(AimbotSettings, "FOVRadius", UI.fovRadiusRef)

window:CreateLabel(aimbotTab, "Trigger Bot")
UI.triggerRef = window:CreateToggle(aimbotTab, "Trigger Bot", false, function(v)
    AimbotSettings.TriggerBot = v
    if v then
        local lastShot = 0
        trackConn("triggerbot", RunService.RenderStepped:Connect(function()
            if not AimbotSettings.TriggerBot then return end
            local murderer = getMurdererCached()
            if not isTargetSafe(murderer) then return end
            local targetPart = getMM2TargetPart(murderer.Character)
            if not targetPart then return end
            local myHRP = getHRP()
            if not myHRP then return end
            if not getEquippedGun() then return end
            local dist = (myHRP.Position - targetPart.Position).Magnitude
            if dist > AimbotSettings.TriggerRange then return end
            if not isVisibleForShot(myHRP.Position, targetPart.Position, murderer.Character, murderer) then return end
            if not isMobile then
                local cam = workspace.CurrentCamera
                local sp, on = cam:WorldToViewportPoint(targetPart.Position)
                if not on then return end
                local mouse = UserInputService:GetMouseLocation()
                if (Vector2.new(sp.X, sp.Y) - mouse).Magnitude >= 12 then return end
            end
            local now = tick()
            if now - lastShot < 0.08 then return end
            lastShot = now
            yarhmFireAt(murderer, targetPart)
        end))
    else
        dropConn("triggerbot")
    end
end)
registerControl(AimbotSettings, "TriggerBot", UI.triggerRef)

UI.triggerRangeRef = window:CreateSlider(aimbotTab, "Trigger Range", 20, 400, 150, function(v) AimbotSettings.TriggerRange = v end)
registerControl(AimbotSettings, "TriggerRange", UI.triggerRangeRef)

window:CreateLabel(aimbotTab, "AutoShoot")
UI.autoFireRef = window:CreateToggle(aimbotTab, "Auto Fire", false, function(v)
    AimbotSettings.AutoFire = v
    if v then
        local lastShot = 0
        trackConn("autofire", RunService.RenderStepped:Connect(function()
            if not AimbotSettings.AutoFire then return end
            if shouldWaitForCoins() then return end
            local murderer = getMurdererCached()
            if not isTargetSafe(murderer) then return end
            local targetPart = getMM2TargetPart(murderer.Character)
            if not targetPart then return end
            local myHRP = getHRP()
            if not myHRP then return end
            if not getEquippedGun() then return end
            if not isVisibleForShot(myHRP.Position, targetPart.Position, murderer.Character, murderer) then return end
            local now = tick()
            if now - lastShot < 0.15 then return end
            lastShot = now
            yarhmFireAt(murderer, targetPart)
        end))
    else
        dropConn("autofire")
    end
end)
registerControl(AimbotSettings, "AutoFire", UI.autoFireRef)

window:CreateLabel(aimbotTab, "Sheriff / Hero")
UI.autoKillRef = window:CreateToggle(aimbotTab, "Auto Kill", false, function(v)
    AimbotSettings.AutoKillMurderer = v
    if v then
        local lastShot = 0
        trackConn("autokill", RunService.RenderStepped:Connect(function()
            if not AimbotSettings.AutoKillMurderer then return end
            if not isLocalSheriffOrHero() then return end
            if shouldWaitForCoins() then return end
            local murderer = getMurdererCached()
            if not isTargetSafe(murderer) then return end
            local now = tick()
            if now - lastShot < 0.15 then return end
            lastShot = now
            yarhmInstakill(murderer)
        end))
    else
        dropConn("autokill")
    end
end)
registerControl(AimbotSettings, "AutoKillMurderer", UI.autoKillRef)

UI.wallCheckRef = window:CreateToggle(aimbotTab, "Wall Check", true, function(v)
    AimbotSettings.WallCheck = v
end)
registerControl(AimbotSettings, "WallCheck", UI.wallCheckRef)

window:CreateLabel(aimbotTab, "Murderer OP")

local function findKnifeRemotes()
    local knife = getLocalKnife()
    if not knife then
        equipKnife()
        task.wait(0.15)
        knife = getLocalKnife()
    end
    if not knife then return nil, nil, nil end
    local events = knife:FindFirstChild("Events")
    if not events then return knife, nil, nil end
    return knife, events:FindFirstChild("KnifeStabbed"), events:FindFirstChild("HandleTouched")
end

local function serverKillAllTick()
    local knife, stabEv, touchEv = findKnifeRemotes()
    if not knife or not stabEv or not touchEv then return false end

    pcall(function() stabEv:FireServer() end)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                local head = plr.Character:FindFirstChild("Head")
                if hrp then pcall(function() touchEv:FireServer(hrp) end) end
                if head then pcall(function() touchEv:FireServer(head) end) end
            end
        end
    end
    return true
end

window:CreateButton(aimbotTab, "Kill Everyone", function()
    if not isLocalMurderer() then notify("You are not the Murderer") return end
    if S.killAllRunning then notify("Already running") return end
    S.killAllRunning = true
    notify("Killing everyone")

    task.spawn(function()
        local startTime = tick()
        while S.killAllRunning and tick() - startTime < 5 do
            serverKillAllTick()
            task.wait(0.03)
        end
        S.killAllRunning = false
        notify("Done")
    end)
end)

UI.autoKillAllRef = window:CreateToggle(aimbotTab, "Auto Kill All", false, function(v)
    S.autoKillAll = v
    if v then
        if S.killAllTask then return end
        S.killAllTask = task.spawn(function()
            while S.autoKillAll do
                if isLocalMurderer() then
                    if not shouldWaitForCoins() then
                        serverKillAllTick()
                    end
                end
                task.wait(0.05)
            end
            S.killAllTask = nil
        end)
        notify("Enabled")
    else
        if S.killAllTask then pcall(task.cancel, S.killAllTask); S.killAllTask = nil end
        notify("Disabled")
    end
end)
registerControl(AimbotSettings, "AutoKillAll", UI.autoKillAllRef)

window:CreateLabel(avatarTab, "Avatar")

UI.korbloxRef = window:CreateToggle(avatarTab, "Korblox", false, function(v)
    AvatarSettings.Korblox = v
    if v then applyKorblox() else removeKorblox() end
end)
registerControl(AvatarSettings, "Korblox", UI.korbloxRef)

window:CreateLabel(avatarTab, "Anims")
UI.animPackRef = window:CreateToggle(avatarTab, "Custom Anims", false, function(v)
    AvatarSettings.AnimPack = v
    if v then
        applyAnimPack()
        notify("Anim pack applied")
    else
        notify("Rejoin to restore anims", 3)
    end
end)
registerControl(AvatarSettings, "AnimPack", UI.animPackRef)

function reapplyActiveFeatures()
    if AimbotSettings.MM2LockOn then
        local tmp = AimbotSettings.MM2LockOn
        AimbotSettings.MM2LockOn = false
        task.wait(0.02)
        AimbotSettings.MM2LockOn = tmp
        if UI.mm2LockRef and UI.mm2LockRef.SetState then
            pcall(function() UI.mm2LockRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.mm2LockRef:SetState(true, true) end)
        end
    end
    if AimbotSettings.TriggerBot then
        if UI.triggerRef and UI.triggerRef.SetState then
            pcall(function() UI.triggerRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.triggerRef:SetState(true, true) end)
        end
    end
    if AimbotSettings.AutoFire then
        if UI.autoFireRef and UI.autoFireRef.SetState then
            pcall(function() UI.autoFireRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.autoFireRef:SetState(true, true) end)
        end
    end
    if AimbotSettings.AutoKillMurderer then
        if UI.autoKillRef and UI.autoKillRef.SetState then
            pcall(function() UI.autoKillRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.autoKillRef:SetState(true, true) end)
        end
    end
    if MovementSettings.Noclip then
        if UI.noclipRef and UI.noclipRef.SetState then
            pcall(function() UI.noclipRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.noclipRef:SetState(true, true) end)
        end
    end
    if MovementSettings.God then
        if UI.godRef and UI.godRef.SetState then
            pcall(function() UI.godRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.godRef:SetState(true, true) end)
        end
    end
    if MiscSettings.AntiAFK then
        if UI.afkRef and UI.afkRef.SetState then
            pcall(function() UI.afkRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.afkRef:SetState(true, true) end)
        end
    end
    if MiscSettings.AntiVoid then
        if UI.antiVoidRef and UI.antiVoidRef.SetState then
            pcall(function() UI.antiVoidRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.antiVoidRef:SetState(true, true) end)
        end
    end
    if MovementSettings.Fly then
        if UI.flyToggleRef and UI.flyToggleRef.SetState then
            pcall(function() UI.flyToggleRef:SetState(false, true) end)
            task.wait(0.05)
            pcall(function() UI.flyToggleRef:SetState(true, true) end)
        end
    end
    if VisualSettings.Beam then
        if UI.beamToggleRef and UI.beamToggleRef.SetState then
            pcall(function() UI.beamToggleRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.beamToggleRef:SetState(true, true) end)
        end
    end
    if VisualSettings.NameTags then
        if UI.nameTagToggleRef and UI.nameTagToggleRef.SetState then
            pcall(function() UI.nameTagToggleRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.nameTagToggleRef:SetState(true, true) end)
        end
    end
    if VisualSettings.GunESP then
        if UI.gunESPToggleRef and UI.gunESPToggleRef.SetState then
            pcall(function() UI.gunESPToggleRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.gunESPToggleRef:SetState(true, true) end)
        end
    end
    if VisualSettings.MM2ESP then
        if UI.mm2ESPToggleRef and UI.mm2ESPToggleRef.SetState then
            pcall(function() UI.mm2ESPToggleRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.mm2ESPToggleRef:SetState(true, true) end)
        end
    end
    if AimbotSettings.FOVCircle then
        if UI.fovToggleRef and UI.fovToggleRef.SetState then
            pcall(function() UI.fovToggleRef:SetState(false, true) end)
            task.wait(0.02)
            pcall(function() UI.fovToggleRef:SetState(true, true) end)
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    MurdererCache.plr = nil
    MurdererCache.time = 0
    for k in pairs(TargetVisibility) do TargetVisibility[k] = nil end
    for k in pairs(VisCache) do VisCache[k] = nil end
    S.korbloxPart = nil
    S.lastSafeCFrame = nil
    S.currentEmoteTrack = nil
    S.miniBoxTrack = nil
    S.flingOriginalCFrame = nil
    S.flingOriginalPosition = nil
    S.flingTargetRunning = false
    S.killAllRunning = false
    S.flingRunning = false
    S.spectating = false
    S.spectateTarget = nil
    S.spectateDefaultSubject = nil
    S.lastCollectTime = 0
    S.lastCamUpdate = 0
    S.autoKillAll = false
    S.farmTargetCoin = nil
    S.farmTouchedCoins = {}
    S.farmWalkBV = nil
    S.farmLastCollectAt = 0
    S.farmStartedAt = 0
    S.farmLastFallbackAt = 0
    S.farmLastPos = nil
    S.farmLastPosTime = 0
    S.lastGyroUpdate = 0
    if S.killAllTask then pcall(task.cancel, S.killAllTask); S.killAllTask = nil end
    if S.animPriorityConn then S.animPriorityConn:Disconnect(); S.animPriorityConn = nil end
    if S.flingTargetThread then pcall(task.cancel, S.flingTargetThread); S.flingTargetThread = nil end
    if S.flingTask then pcall(task.cancel, S.flingTask); S.flingTask = nil end
    stopFarmBodyMovers()
    stopEvasion()
    clearBeamPool(S.beamData)
    task.wait(0.6)
    if isMobile then scanForGunShoot() end
    if MovementSettings.Fly then attachFlyBodyMovers() end
    if AvatarSettings.Korblox then pcall(applyKorblox) end
    if AvatarSettings.AnimPack then pcall(applyAnimPack) end
    if FarmSettings.AutoFarm and S.roundActive then
        task.wait(0.5)
        if not S.coinCollecting then startCoinCollector() end
    end
    task.wait(0.2)
    reapplyActiveFeatures()
end)

window:CreateLabel(farmTab, "Coin Farm")

UI.autoFarmRef = window:CreateToggle(farmTab, "Auto Farm", false, function(v)
    FarmSettings.AutoFarm = v
    if v then
        ensureFarmHelpers()
        ensureFarmNoclip()
        if S.roundActive and not S.coinCollecting then startCoinCollector() end
    else
        stopCoinCollector()
        stopEvasion()
        restoreFarmNoclip()
        restoreFarmHelpers()
    end
end)
registerControl(FarmSettings, "AutoFarm", UI.autoFarmRef)

window:CreateParagraph(farmTab, "Flows through coins · auto-evades murderer · fallback TP if stuck")

window:CreateLabel(farmTab, "Stats")
local coinCountFrame = window:CreateParagraph(farmTab, "0")
local coinCountLabel = coinCountFrame:FindFirstChildOfClass("TextLabel")
local statusFrame = window:CreateParagraph(farmTab, "Idle")
local statusLabel = statusFrame:FindFirstChildOfClass("TextLabel")

S.coinCountSetter = function(n)
    if coinCountLabel then coinCountLabel.Text = "" .. tostring(n) end
end
S.coinStatusSetter = function(txt)
    if statusLabel then statusLabel.Text = "" .. txt end
end

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local gameplay = remotes and remotes:FindFirstChild("Gameplay")
local coinsStartedEvent = gameplay and gameplay:FindFirstChild("CoinsStarted")
local coinCollectedEvent = gameplay and gameplay:FindFirstChild("CoinCollected")
local roundEndFadeEvent = gameplay and gameplay:FindFirstChild("RoundEndFade")
local roundStartEvent = gameplay and gameplay:FindFirstChild("RoundStart")

if coinsStartedEvent then
    coinsStartedEvent.OnClientEvent:Connect(function(data)
        S.bagProgress = {}
        if type(data) == "table" and data.Coin then
            if data.Coin.CollectionLimit then
                FARM_GOAL = data.Coin.CollectionLimit
            end
        end
        S.totalCoins = 0
        if S.coinCountSetter then S.coinCountSetter(0) end
        S.roundActive = true
        if FarmSettings.AutoFarm then
            ensureFarmNoclip()
            if not S.coinCollecting then startCoinCollector() end
        end
    end)
end

if coinCollectedEvent then
    coinCollectedEvent.OnClientEvent:Connect(function(bagName, currentCoins)
        S.lastCollectTime = tick()
        S.farmLastCollectAt = tick()
        if type(bagName) == "string" and type(currentCoins) == "number" then
            S.bagProgress[bagName] = currentCoins
        end
        S.totalCoins = 0
        for _, v in pairs(S.bagProgress) do
            if type(v) == "number" then
                S.totalCoins = S.totalCoins + v
            end
        end
        if S.coinCountSetter then S.coinCountSetter(S.totalCoins) end
    end)
end

if roundStartEvent then
    roundStartEvent.OnClientEvent:Connect(function()
        S.bagProgress = {}
        S.totalCoins = 0
        S.roundActive = true
        if S.coinCountSetter then S.coinCountSetter(0) end
        task.wait(0.1)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then applyESP(plr) end
        end
        refreshBeam()
        onRoundBegin()
        if FarmSettings.AutoFarm then
            ensureFarmNoclip()
            task.wait(0.5)
            if not S.coinCollecting then startCoinCollector() end
            startEvasion()
        end
        task.wait(0.3)
        reapplyActiveFeatures()
    end)
end

if roundEndFadeEvent then
    roundEndFadeEvent.OnClientEvent:Connect(function()
        S.roundActive = false
        S.roleCache = {}
        stopCoinCollector()
        stopEvasion()
        onRoundEnd()
        if FarmSettings.AutoFarm then
            restoreFarmNoclip()
        end
        task.wait(0.05)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then clearHighlights(plr) end
        end
    end)
end

trackThread(task.spawn(function()
    while true do
        task.wait(0.5)
        if FarmSettings.AutoFarm and S.roundActive and not S.coinCollecting then
            startCoinCollector()
        end
    end
end))

window:CreateLabel(miscTab, "Gun")
window:CreateButton(miscTab, "Pick up Gun", function()
    local ok, reason = bringGunToPlayer()
    if ok then notify("Gun incoming")
    else notify("Failed: " .. tostring(reason)) end
end)

UI.autoTpGunRef = window:CreateToggle(miscTab, "Auto Gun", false, function(v)
    MiscSettings.AutoTpGun = v
    if v then
        if S.autoTpGunThread then return end
        S.autoTpGunThread = task.spawn(function()
            while MiscSettings.AutoTpGun do
                task.wait(0.5)
                if not MiscSettings.AutoTpGun then break end
                bringGunToPlayer()
            end
            S.autoTpGunThread = nil
        end)
    else
        if S.autoTpGunThread then task.cancel(S.autoTpGunThread); S.autoTpGunThread = nil end
    end
end)
registerControl(MiscSettings, "AutoTpGun", UI.autoTpGunRef)

window:CreateLabel(miscTab, "Silent Aim")
UI.silentRef = window:CreateToggle(miscTab, "Silent Aim", false, function(v)
    MiscSettings.SilentAim = v
end)
registerControl(MiscSettings, "SilentAim", UI.silentRef)

window:CreateLabel(miscTab, "Debug")
window:CreateButton(miscTab, "Check Gun Status", function()
    local char = LocalPlayer.Character
    if not char then notify("No character", 3) return end
    local rigGun = findGunEquipped()
    local bagGun = findGunInBackpack()
    local hum = char:FindFirstChildOfClass("Humanoid")
    local equipped = hum and hum:FindFirstChildWhichIsA("Tool")
    local msg = {}
    table.insert(msg, "Rig: " .. (rigGun and rigGun.Name or "no"))
    table.insert(msg, "Bag: " .. (bagGun and bagGun.Name or "no"))
    table.insert(msg, "Equipped: " .. (equipped and equipped.Name or "no"))
    notify(table.concat(msg, " | "), 6)
end)

function toggleESPAll()
    local anyOn = VisualSettings.MM2ESP or VisualSettings.NameTags or VisualSettings.GunESP or VisualSettings.Beam
    local newState = not anyOn

    VisualSettings.MM2ESP   = newState
    VisualSettings.NameTags = newState
    VisualSettings.GunESP   = newState
    VisualSettings.Beam     = newState
    VisualSettings.OGESP    = false

    ESP.active.MM2     = newState
    ESP.active.NameTag = newState
    ESP.active.OG      = false

    refreshAllESP()
    applyGunESP()

    if newState then
        if not ConnectionRegistry["nametag"] then startNameTagUpdater() end
        ensureBeamConn()
    else
        stopNameTagUpdater()
        stopBeamIfIdle()
        clearGunESP()
        clearBeamPool(S.beamData)
    end

    if UI.mm2ESPToggleRef and UI.mm2ESPToggleRef.SetState then pcall(function() UI.mm2ESPToggleRef:SetState(newState, true) end) end
    if UI.nameTagToggleRef and UI.nameTagToggleRef.SetState then pcall(function() UI.nameTagToggleRef:SetState(newState, true) end) end
    if UI.gunESPToggleRef and UI.gunESPToggleRef.SetState then pcall(function() UI.gunESPToggleRef:SetState(newState, true) end) end
    if UI.beamToggleRef and UI.beamToggleRef.SetState then pcall(function() UI.beamToggleRef:SetState(newState, true) end) end
    if UI.ogESPToggleRef and UI.ogESPToggleRef.SetState then pcall(function() UI.ogESPToggleRef:SetState(false, true) end) end

    for plr, h in pairs(ESP.highlights.OG) do
        if h and h.Parent then h:Destroy() end
        ESP.highlights.OG[plr] = nil
    end

    notify("ESP " .. (newState and "ON" or "OFF"), 2)
end

function createReopenButton()
    if not isMobile then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "HH_ReopenUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    trackGui(gui)

    local btn = Instance.new("TextButton")
    btn.Name = "ReopenBtn"
    btn.Size = UDim2.new(0, 56, 0, 56)
    btn.Position = UDim2.new(0, 20, 0, 200)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    btn.TextColor3 = Color3.fromRGB(0, 220, 130)
    btn.Text = "UI"
    btn.TextSize = 18
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Active = true
    btn.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 220, 130)
    stroke.Thickness = 2
    stroke.Parent = btn

    local dragging = false
    local dragStart = nil
    local startPos = nil

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragStart = input.Position
            startPos = btn.Position
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragStart then return end
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            if delta.Magnitude > 6 then
                dragging = true
                btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragStart = nil
            dragging = false
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if dragging then return end
        pcall(function()
            if window and type(window.ToggleUI) == "function" then
                window:ToggleUI()
            end
        end)
    end)
end

function setupMobileButtons()
    if not isMobile then return end

    if type(window.AddMobileButton) == "function" then
        pcall(function() window:ClearMobileButtons() end)

        pcall(function()
            window:AddMobileButton({
                OnClick = function() task.spawn(mobileForceShoot) end,
                Icon = "rbxassetid://12804017021",
                Tooltip = "Shoot Murderer"
            })
        end)

        pcall(function()
            window:AddMobileButton({
                OnClick = function() toggleESPAll() end,
                Icon = "rbxassetid://12804017021",
                Tooltip = "Toggle ESP"
            })
        end)
    end

    if type(window._makeMobileBtn) == "function" then
        pcall(function()
            window._makeMobileBtn("AIM", function()
                if UI.mm2LockRef and UI.mm2LockRef.SetState and UI.mm2LockRef.GetState then
                    local current = false
                    pcall(function() current = UI.mm2LockRef:GetState() end)
                    pcall(function() UI.mm2LockRef:SetState(not current) end)
                end
            end)
        end)
        pcall(function()
            window._makeMobileBtn("ESP", function()
                toggleESPAll()
            end)
        end)
        pcall(function()
            window._makeMobileBtn("UI", function()
                if window and type(window.ToggleUI) == "function" then
                    window:ToggleUI()
                end
            end)
        end)
    end

    createReopenButton()
end

setupMobileButtons()
startMobileFlyDrag()

trackConn("hotkeys", UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if isMobile then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.T then
        if UI.mm2LockRef then UI.mm2LockRef.SetState(not UI.mm2LockRef.GetState()) end
    elseif input.KeyCode == Enum.KeyCode.O then
        if UI.mm2ESPToggleRef then UI.mm2ESPToggleRef.SetState(not UI.mm2ESPToggleRef.GetState()) end
    elseif input.KeyCode == Enum.KeyCode.B then
        if UI.autoFireRef then UI.autoFireRef.SetState(not UI.autoFireRef.GetState()) end
    end
end))

function snapshotSettings()
    return {
        Aimbot = {
            MM2LockOn   = AimbotSettings.MM2LockOn,
            MM2Smooth   = AimbotSettings.MM2Smooth,
            MM2Range    = AimbotSettings.MM2Range,
            MM2Target   = AimbotSettings.MM2Target,
            TriggerBot  = AimbotSettings.TriggerBot,
            TriggerRange= AimbotSettings.TriggerRange,
            AutoFire    = AimbotSettings.AutoFire,
            AutoKillMurderer = AimbotSettings.AutoKillMurderer,
            WallCheck   = AimbotSettings.WallCheck,
            FOVCircle   = AimbotSettings.FOVCircle,
            FOVRadius   = AimbotSettings.FOVRadius,
        },
        Visual = {
            MM2ESP   = VisualSettings.MM2ESP,
            OGESP    = VisualSettings.OGESP,
            NameTags = VisualSettings.NameTags,
            GunESP   = VisualSettings.GunESP,
            Beam     = VisualSettings.Beam,
        },
        Misc = {
            InfJump        = MiscSettings.InfJump,
            AntiAFK        = MiscSettings.AntiAFK,
            AntiVoid       = MiscSettings.AntiVoid,
            AutoTpGun      = MiscSettings.AutoTpGun,
            SilentAim      = MiscSettings.SilentAim,
            MusicCompanion = MiscSettings.MusicCompanion,
            SelectedMusic  = MiscSettings.SelectedMusic,
        },
        Movement = {
            Noclip       = MovementSettings.Noclip,
            God          = MovementSettings.God,
            Fly          = MovementSettings.Fly,
            WalkSpeed    = MovementSettings.WalkSpeed,
            JumpPower    = MovementSettings.JumpPower,
            FlySpeed     = MovementSettings.FlySpeed,
            AntiFling    = MovementSettings.AntiFling,
            Fling        = MovementSettings.Fling,
            TPAll        = MovementSettings.TPAll,
            FlingTarget  = MovementSettings.FlingTarget,
            FlingDuration= MovementSettings.FlingDuration,
            FlingDistance= MovementSettings.FlingDistance,
        },
        Avatar = {
            Korblox   = AvatarSettings.Korblox,
            AnimPack  = AvatarSettings.AnimPack,
        },
        Farm = {
            AutoFarm = FarmSettings.AutoFarm,
        },
        AntiVoid = {
            Threshold = AntiVoidSettings.Threshold,
            SafeY = AntiVoidSettings.SafeY,
        },
        Theme = getCurrentTheme(),
    }
end

function applyConfig(data)
    if not data then return end
    if data.Aimbot then
        for k, v in pairs(data.Aimbot) do AimbotSettings[k] = v end
    end
    if data.Visual then
        for k, v in pairs(data.Visual) do VisualSettings[k] = v end
    end
    if data.Misc then
        for k, v in pairs(data.Misc) do MiscSettings[k] = v end
    end
    if data.Movement then
        for k, v in pairs(data.Movement) do MovementSettings[k] = v end
    end
    if data.Avatar then
        for k, v in pairs(data.Avatar) do AvatarSettings[k] = v end
    end
    if data.Farm and data.Farm.AutoFarm ~= nil then
        FarmSettings.AutoFarm = data.Farm.AutoFarm
    end
    if data.AntiVoid then
        for k, v in pairs(data.AntiVoid) do AntiVoidSettings[k] = v end
    end
    if data.Theme and data.Theme ~= getCurrentTheme() then setTheme(data.Theme) end
    reapplyActiveFeatures()
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = MovementSettings.WalkSpeed
        hum.JumpPower = MovementSettings.JumpPower
        hum.UseJumpPower = true
    end
    if AvatarSettings.Korblox then pcall(applyKorblox) else pcall(removeKorblox) end
    if AvatarSettings.AnimPack then pcall(applyAnimPack) end
    if FarmSettings.AutoFarm then
        ensureFarmHelpers()
        ensureFarmNoclip()
        if S.roundActive and not S.coinCollecting then startCoinCollector() end
        if S.roundActive then startEvasion() end
    else
        stopCoinCollector()
        stopEvasion()
        restoreFarmNoclip()
        restoreFarmHelpers()
    end
    if MiscSettings.MusicCompanion then playMusic() else stopMusic() end
    syncUIControls()
    if window.UpdateThemeButtons then window:UpdateThemeButtons() end
end

window:SetConfigSnapshot(snapshotSettings)
window:SetConfigApply(applyConfig)
window:BuildConfigPage()

task.delay(2, function()
    if isMobile then
        notify("Mobile loaded", 4)
    else
        notify("PC loaded", 4)
    end
end)

notify("Hello again "..LocalPlayer.DisplayName, 3)
