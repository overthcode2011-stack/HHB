local API
do
    local ok, err = pcall(function()
        API = loadstring(game:HttpGet("https://raw.githubusercontent.com/overthcode2011-stack/HHB-MM2-/refs/heads/main/template.lua"))()
    end)
    if not ok or type(API) ~= "table" then
        warn("[HappyHub] API load failed: " .. tostring(err))
        return
    end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local HAS = {
    RegisterControl   = type(API.RegisterControl) == "function",
    SyncUIControls    = type(API.SyncUIControls) == "function",
    Notify            = type(API.Notify) == "function",
    SetTheme          = type(API.SetTheme) == "function",
    GetTheme          = type(API.GetTheme) == "function",
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

local CUSTOM_ANIMS = {
    idle  = { id = "rbxassetid://130192584268621", priority = Enum.AnimationPriority.Action  },
    walk  = { id = "rbxassetid://81802706102899",  priority = Enum.AnimationPriority.Action2 },
    run   = { id = "rbxassetid://79725699626716",  priority = Enum.AnimationPriority.Action3 },
    fall  = { id = "rbxassetid://10921159222",     priority = Enum.AnimationPriority.Action3 },
    climb = { id = "rbxassetid://132811676666245", priority = Enum.AnimationPriority.Action4 },
    jump  = { id = "rbxassetid://10921160088",     priority = Enum.AnimationPriority.Action4 },
}

local AimbotSettings = {
    MM2LockOn = false, MM2Smooth = 8, MM2Range = 500, MM2Target = "Head",
    TriggerBot = false, TriggerRange = 150, AutoFire = false, WallCheck = true,
    FOVCircle = false, FOVRadius = 120, AutoKillMurderer = false,
}
local VisualSettings = { MM2ESP = false, OGESP = false, NameTags = false, GunESP = false, Beam = false }
local MiscSettings = {
    InfJump = false, AntiAFK = false, AutoTpGun = false,
    SilentAim = false, MusicCompanion = false, AntiVoid = false,
}
local MovementSettings = {
    Noclip = false, God = false, Fly = false, WalkSpeed = 16, JumpPower = 50,
    FlySpeed = 40, AntiFling = false, Fling = false, TPAll = false,
    FlingTarget = false, FlingDuration = 3, FlingDistance = 500,
}
local AvatarSettings = { Korblox = false, AnimPack = false }
local FarmSettings = { AutoFarm = false, ManualCollect = false, CoinSpeed = 20, PickupRadius = 3 }
local BeamSettings = {
    Enabled = false,
    ClearColor = Color3.fromRGB(0, 255, 100),
    WallColor = Color3.fromRGB(255, 50, 50),
    PlayerColor = Color3.fromRGB(255, 130, 0),
    Thickness = 0.15,
    Transparency = 0.2,
    MaxIterations = 14,
    WaypointOffset = 3,
    RefreshRate = 0.033,
}
local AntiVoidSettings = { Threshold = -30, SafeY = 10 }

local WALL_GRACE_TIME = 0.2
local TargetVisibility = {}
local MurdererCache = { plr = nil, time = 0 }
local VisCache = {}
local VIS_TTL = 0.05
local MURDERER_TTL = 0.1

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
    animPriorityConn = nil,
    korbloxPart = nil,
    mobileFlyVec = Vector3.zero, mobileFlyDragging = false,
    beamData = { segments = {}, updateConn = nil, lastTick = 0 },
    coinCollecting = false, coinConnection = nil, coinVelocity = nil,
    coinGyro = nil,
    roundActive = false, bagProgress = {}, totalCoins = 0,
    coinStatusSetter = nil, coinCountSetter = nil, currentIdleTrack = nil,
    roleCache = {},
    heroWatcher = { active = false, thread = nil, originalSheriffName = nil },
    gunESP = { active = false, highlights = {}, billboards = {}, trackedGun = nil },
    hitboxExpander = { active = false, savedSizes = {}, size = Vector3.new(40, 40, 40) },
    fadeConn = nil, tpEvent = nil,
    silentAimHookInstalled = false, hookNamecall = nil, getNamecall = nil,
    lastMobileShot = 0,
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
    return hrp.CFrame
end

local function getEquippedGun()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("gun", 1, true) then
            return t
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find("gun", 1, true) then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function() hum:EquipTool(t) end)
                    task.wait(0.1)
                end
                return t
            end
        end
    end
    return nil
end

local function predictAim(targetPart)
    if not targetPart then return nil end
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if not ok or not ping then ping = 0.05 end
    local vel = targetPart.AssemblyLinearVelocity
    return CFrame.new(targetPart.Position + vel * (ping * 1.15))
end

local function isGunShootRemote(remote)
    if not remote or not remote:IsA("RemoteEvent") then return false end
    if remote.Name ~= "Shoot" then return false end
    local parent = remote.Parent
    if not parent then return false end
    local path = parent.Name:lower()
    if parent:IsA("Tool") then
        return path:find("gun", 1, true) ~= nil
    end
    return path:find("gun", 1, true) ~= nil
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
    while iterations < BeamSettings.MaxIterations do
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
        local offset = BeamSettings.WaypointOffset
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

local function tpRedirectAndShoot(shootRemote, myHRP, targetPart, targetChar)
    local waypoints = buildBeamPath(myHRP.Position, targetPart.Position, targetChar)
    local originalCFrame = myHRP.CFrame
    local fired = false
    for i = #waypoints - 1, 2, -1 do
        local wp = waypoints[i]
        if isVisible(wp + Vector3.new(0, 2, 0), targetPart.Position, targetChar) then
            myHRP.CFrame = CFrame.new(wp + Vector3.new(0, 2.5, 0))
            RunService.RenderStepped:Wait()
            local ro = getGunRaycastCFrame()
            if ro then
                local rtc = predictAim(targetPart)
                if rtc then
                    pcall(function() shootRemote:FireServer(ro, rtc) end)
                    fired = true
                end
            end
            task.wait(0.03)
            local h = getHRP()
            if h then
                h.CFrame = originalCFrame
                h.Velocity = Vector3.zero
                h.RotVelocity = Vector3.zero
            end
            break
        end
    end
    return fired
end

local function fireGunAt(targetPart, targetPlr, useRedirect)
    if targetPlr and not isTargetSafe(targetPlr) then return false end
    local myHRP = getHRP()
    if not myHRP then return false end
    local targetChar = targetPlr and targetPlr.Character
    local hitType = classifyPathHit(myHRP.Position, targetPart.Position, targetChar)
    if hitType == "innocent" then return false end
    local gun = getEquippedGun()
    if not gun then return false end
    local shootRemote = gun:FindFirstChild("Shoot")
    if not shootRemote or not shootRemote:IsA("RemoteEvent") then return false end
    local origin = getGunRaycastCFrame()
    if not origin then return false end
    local targetCF = predictAim(targetPart)
    if not targetCF then return false end
    pcall(function() shootRemote:FireServer(origin, targetCF) end)
    if useRedirect and targetChar and hitType == "wall" then
        tpRedirectAndShoot(shootRemote, myHRP, targetPart, targetChar)
    end
    return true
end

local function mobileForceShoot()
    local murderer = getMurdererCached()
    if not isTargetSafe(murderer) then
        notify("No murderer", 2)
        return false
    end

    local char = LocalPlayer.Character
    if not char then notify("No character", 2) return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then notify("No humanoid", 2) return false end

    local gun = nil
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("gun", 1, true) then
            gun = t
            break
        end
    end
    if not gun then
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") and t.Name:lower():find("gun", 1, true) then
                    pcall(function() hum:EquipTool(t) end)
                    task.wait(0.2)
                    gun = t
                    break
                end
            end
        end
    end
    if not gun then notify("No gun in inventory", 2) return false end

    if gun.Parent ~= char then
        pcall(function() hum:EquipTool(gun) end)
        task.wait(0.2)
    end

    local shootRemote = gun:FindFirstChild("Shoot")
    if not shootRemote then
        for _, r in ipairs(gun:GetChildren()) do
            if r:IsA("RemoteEvent") then
                shootRemote = r
                break
            end
        end
    end
    if not shootRemote then notify("No Shoot remote", 2) return false end

    local targetPart = getMM2TargetPart(murderer.Character)
    if not targetPart then notify("No target part", 2) return false end

    local myHRP = getHRP()
    if not myHRP then notify("No HRP", 2) return false end

    local origin = getGunRaycastCFrame() or myHRP.CFrame
    local targetCF = predictAim(targetPart) or CFrame.new(targetPart.Position)

    local ok, err = pcall(function()
        shootRemote:FireServer(origin, targetCF)
    end)
    if ok then
        notify("Shot " .. murderer.DisplayName, 1.5)
        return true
    else
        notify("Fire error: " .. tostring(err), 3)
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
    beam.Width0 = BeamSettings.Thickness
    beam.Width1 = BeamSettings.Thickness
    beam.Color = ColorSequence.new(BeamSettings.ClearColor)
    beam.Transparency = NumberSequence.new(BeamSettings.Transparency)
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
        seg.beam.Width0 = BeamSettings.Thickness
        seg.beam.Width1 = BeamSettings.Thickness
        seg.beam.Color = ColorSequence.new(color)
        seg.beam.Transparency = NumberSequence.new(BeamSettings.Transparency)
    end
end

local function updateBeam()
    if BeamSettings.Enabled then
        local myHRP = getHRP()
        local murderer = getMurdererCached()
        if myHRP and isTargetSafe(murderer) then
            local targetPart = getMM2TargetPart(murderer.Character)
            if targetPart then
                local waypoints = buildBeamPath(myHRP.Position, targetPart.Position, murderer.Character)
                local hitType = classifyPathHit(myHRP.Position, targetPart.Position, murderer.Character)
                local color
                if hitType == "clear" or hitType == "target" then
                    color = BeamSettings.ClearColor
                elseif hitType == "innocent" then
                    color = BeamSettings.PlayerColor
                else
                    color = BeamSettings.WallColor
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
    if S.beamData.updateConn then return end
    S.beamData.updateConn = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - S.beamData.lastTick < BeamSettings.RefreshRate then return end
        S.beamData.lastTick = now
        updateBeam()
    end)
end

local function stopBeamIfIdle()
    if BeamSettings.Enabled then return end
    if S.beamData.updateConn then
        S.beamData.updateConn:Disconnect()
        S.beamData.updateConn = nil
    end
    clearBeamPool(S.beamData)
end

local function refreshBeam()
    if S.beamData.updateConn then
        S.beamData.lastTick = 0
        updateBeam()
    end
end

local function startAntiVoid()
    if S.antiVoidConn then return end
    S.antiVoidConn = RunService.Heartbeat:Connect(function()
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
    end)
end

local function stopAntiVoid()
    if S.antiVoidConn then
        S.antiVoidConn:Disconnect()
        S.antiVoidConn = nil
    end
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
        track.Looped = false
        track:Play(0.1)
        S.currentEmoteTrack = track
        notify("Emote: " .. emoteName, 1.5)
    else
        notify("Failed: " .. emoteName, 2)
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
            if S.getNamecall() == "FireServer" and isGunShootRemote(self) then
                if MiscSettings.SilentAim then
                    local murderer = getMurdererCached()
                    if isTargetSafe(murderer) then
                        local targetPart = getMM2TargetPart(murderer.Character)
                        if targetPart then
                            local cam = workspace.CurrentCamera
                            local myHRP = getHRP()
                            local origin = (myHRP and myHRP.Position) or cam.CFrame.Position
                            if isVisibleForShot(origin, targetPart.Position, murderer.Character, murderer) then
                                local args = table.pack(...)
                                local newTarget = predictAim(targetPart)
                                if newTarget then
                                    args[2] = newTarget
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
    UserInputService.InputBegan:Connect(function(input, gp)
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
        task.spawn(function()
            fireGunAt(targetPart, murderer, false)
        end)
    end)
end

local function equipKnife()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find("knife", 1, true) then
            hum:EquipTool(tool)
            return true
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("knife", 1, true) then
                hum:EquipTool(tool)
                return true
            end
        end
    end
    return false
end

local function expandHitbox(plr)
    if not plr or plr == LocalPlayer then return end
    if not plr.Character then return end
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if S.hitboxExpander.savedSizes[plr] then return end
    S.hitboxExpander.savedSizes[plr] = {
        size = hrp.Size,
        transparency = hrp.Transparency,
        cancollide = hrp.CanCollide,
        massless = hrp.Massless,
        anchored = hrp.Anchored,
    }
    hrp.Size = S.hitboxExpander.size
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Massless = false
    hrp.Anchored = false
end

local function expandHitboxForAll()
    for _, plr in ipairs(Players:GetPlayers()) do expandHitbox(plr) end
    S.hitboxExpander.active = true
end

local function restoreHitbox(plr)
    local data = S.hitboxExpander.savedSizes[plr]
    if not data then return end
    if plr and plr.Parent and plr.Character then
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Size = data.size
            hrp.Transparency = data.transparency
            hrp.CanCollide = data.cancollide
            hrp.Massless = data.massless
            hrp.Anchored = data.anchored
        end
    end
    S.hitboxExpander.savedSizes[plr] = nil
end

local function restoreHitboxes()
    for plr, _ in pairs(S.hitboxExpander.savedSizes) do restoreHitbox(plr) end
    S.hitboxExpander.savedSizes = {}
    S.hitboxExpander.active = false
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
    if S.nameTagUpdater then return end
    S.nameTagUpdater = RunService.Heartbeat:Connect(function()
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
    end)
end

local function stopNameTagUpdater()
    if S.nameTagUpdater then S.nameTagUpdater:Disconnect(); S.nameTagUpdater = nil end
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
        task.cancel(S.heroWatcher.thread)
        S.heroWatcher.thread = nil
    end
end

local function startHeroWatcher()
    if S.heroWatcher.active then return end
    S.heroWatcher.active = true
    S.heroWatcher.thread = task.spawn(function()
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
    end)
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

task.spawn(function()
    while true do
        task.wait(3)
        if not S.fadeConn or not getFadeEvent() then hookFadeEvent() end
    end
end)

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

local function getBestCoin()
    local coinContainer = getCoinContainer()
    if not coinContainer then return nil end
    local myHRP = getHRP()
    if not myHRP then return nil end
    local myPos = myHRP.Position
    local bestPart, bestDist = nil, math.huge
    for _, child in ipairs(coinContainer:GetChildren()) do
        local part = child:IsA("BasePart") and child or (child:IsA("Model") and child.PrimaryPart)
        if part and part:IsA("BasePart") then
            local d = (part.Position - myPos).Magnitude
            if d < bestDist then
                bestDist = d
                bestPart = part
            end
        end
    end
    return bestPart
end

local function playIdleAnimation(hum)
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    if S.currentIdleTrack then
        pcall(function() S.currentIdleTrack:Stop() end)
        S.currentIdleTrack = nil
    end
    local idleAnim = Instance.new("Animation")
    idleAnim.AnimationId = "rbxassetid://507766666"
    local track = animator:LoadAnimation(idleAnim)
    track.Priority = Enum.AnimationPriority.Idle
    track.Looped = true
    track:Play()
    S.currentIdleTrack = track
    return track
end

local function stopIdleAnimation()
    if S.currentIdleTrack then
        pcall(function() S.currentIdleTrack:Stop() end)
        S.currentIdleTrack = nil
    end
end

local function stopCoinCollector()
    if not S.coinCollecting then return end
    S.coinCollecting = false
    if S.coinConnection then S.coinConnection:Disconnect(); S.coinConnection = nil end
    if S.coinVelocity then S.coinVelocity:Destroy(); S.coinVelocity = nil end
    if S.coinGyro then S.coinGyro:Destroy(); S.coinGyro = nil end
    if S.coinStatusSetter then S.coinStatusSetter("Idle") end
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
    stopIdleAnimation()
    local char = LocalPlayer.Character
    if char then
        local animateScript = char:FindFirstChild("Animate")
        if animateScript then
            pcall(function() animateScript.Disabled = true end)
            task.wait()
            pcall(function() animateScript.Disabled = false end)
        end
    end
end

local function startCoinCollector()
    if S.coinCollecting then return end
    S.coinCollecting = true
    if S.coinStatusSetter then S.coinStatusSetter("Collecting") end
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then S.coinCollecting = false; return end
    hum.PlatformStand = true
    playIdleAnimation(hum)
    S.coinVelocity = Instance.new("BodyVelocity")
    S.coinVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    S.coinVelocity.P = 1250
    S.coinVelocity.Parent = hrp
    S.coinGyro = Instance.new("BodyGyro")
    S.coinGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    S.coinGyro.P = 1e4
    S.coinGyro.D = 500
    S.coinGyro.CFrame = hrp.CFrame
    S.coinGyro.Parent = hrp
    S.coinConnection = RunService.Heartbeat:Connect(function()
        if not S.coinCollecting then return end
        local currentHRP = getHRP()
        local currentHum = getHumanoid()
        if not currentHRP or not currentHum then return end
        if not S.coinVelocity or not S.coinVelocity.Parent then
            S.coinVelocity = Instance.new("BodyVelocity")
            S.coinVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            S.coinVelocity.P = 1250
            S.coinVelocity.Parent = currentHRP
        end
        if not S.coinGyro or not S.coinGyro.Parent then
            S.coinGyro = Instance.new("BodyGyro")
            S.coinGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            S.coinGyro.P = 1e4
            S.coinGyro.D = 500
            S.coinGyro.CFrame = currentHRP.CFrame
            S.coinGyro.Parent = currentHRP
        end
        if currentHum.PlatformStand == false then currentHum.PlatformStand = true end
        local murderer = getMurdererCached()
        local evadeDirection = nil
        if murderer and murderer.Character then
            local murderHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
            if murderHRP then
                local distToMurderer = (currentHRP.Position - murderHRP.Position).Magnitude
                if distToMurderer < 25 then
                    evadeDirection = (currentHRP.Position - murderHRP.Position).Unit
                    if S.coinStatusSetter then S.coinStatusSetter("Evading") end
                end
            end
        end
        if evadeDirection then
            local targetVel = evadeDirection * math.min(FarmSettings.CoinSpeed * 1.5, 75)
            S.coinVelocity.Velocity = targetVel
            S.coinGyro.CFrame = CFrame.lookAt(currentHRP.Position, currentHRP.Position + evadeDirection)
            return
        end
        local target = getBestCoin()
        if not target then
            S.coinVelocity.Velocity = Vector3.zero
            if S.coinStatusSetter then S.coinStatusSetter("Waiting for coins") end
            return
        end
        local direction = (target.Position - currentHRP.Position).Unit
        local distance = (target.Position - currentHRP.Position).Magnitude
        local speed = FarmSettings.CoinSpeed
        if distance < 5 then
            speed = FarmSettings.CoinSpeed * 0.4
        elseif distance < 15 then
            speed = FarmSettings.CoinSpeed * 0.7
        end
        S.coinVelocity.Velocity = direction * speed
        S.coinGyro.CFrame = CFrame.lookAt(currentHRP.Position, target.Position)
        if S.coinStatusSetter then S.coinStatusSetter("Collecting") end
    end)
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

local function autoEnableFling()
    S.flingWasFlingOn = MovementSettings.Fling
    if not MovementSettings.Fling then
        MovementSettings.Fling = true
        if UI.flingToggleRef and UI.flingToggleRef.SetState then
            pcall(function() UI.flingToggleRef.SetState(true) end)
        end
        if not S.flingRunning then
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
        end
    end
end

local function autoDisableFling()
    if not S.flingWasFlingOn then
        MovementSettings.Fling = false
        if UI.flingToggleRef and UI.flingToggleRef.SetState then
            pcall(function() UI.flingToggleRef.SetState(false) end)
        end
        S.flingRunning = false
        if S.flingTask then task.cancel(S.flingTask); S.flingTask = nil end
        local hrp = getHRP()
        if hrp then hrp.Velocity = Vector3.zero end
    end
    S.flingWasFlingOn = false
end

local function stopFlingTarget()
    S.flingTargetRunning = false
    if S.flingTargetThread then
        task.cancel(S.flingTargetThread)
        S.flingTargetThread = nil
    end
    local hrp = getHRP()
    if hrp then
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
        if S.flingOriginalCFrame then hrp.CFrame = S.flingOriginalCFrame end
    end
    S.flingOriginalCFrame = nil
    S.flingOriginalPosition = nil
    autoDisableFling()
end

local function startFlingTarget(targetPlr)
    if not targetPlr then
        notify("No target selected")
        return
    end
    if targetPlr == LocalPlayer then
        notify("Cannot fling yourself")
        return
    end
    if S.flingTargetRunning then stopFlingTarget() end
    local myHRP = getHRP()
    if not myHRP then
        notify("No character")
        return
    end
    S.flingOriginalCFrame = myHRP.CFrame
    S.flingOriginalPosition = myHRP.Position
    autoEnableFling()
    S.flingTargetRunning = true
    notify("Flinging " .. targetPlr.DisplayName)
    S.flingTargetThread = task.spawn(function()
        local startTime = tick()
        local duration = MovementSettings.FlingDuration or 3
        local maxDist = MovementSettings.FlingDistance or 500
        local flinged = false
        while S.flingTargetRunning and tick() - startTime < duration do
            local currentHRP = getHRP()
            local theirHRP = targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
            if not currentHRP or not theirHRP then break end
            local dist = (currentHRP.Position - theirHRP.Position).Magnitude
            if dist >= maxDist then
                flinged = true
                notify(targetPlr.DisplayName .. " FLINGED!")
                break
            end
            local elapsed = tick() - startTime
            local phase = elapsed * 12
            local theirPos = theirHRP.Position
            local baseCFrame = CFrame.new(theirPos) * CFrame.Angles(0, phase * 2, 0)
            if not fireTeleportToPart(currentHRP, theirHRP) then
                currentHRP.CFrame = baseCFrame
            else
                task.wait(0.02)
                local h = getHRP()
                if h then h.CFrame = baseCFrame end
            end
            local velo = currentHRP.Velocity
            currentHRP.Velocity = velo * 5000 + Vector3.new(
                math.sin(phase) * 8000,
                math.cos(phase * 1.3) * 8000 + 5000,
                math.cos(phase) * 8000
            )
            currentHRP.RotVelocity = Vector3.new(
                math.sin(phase * 1.5) * 300,
                math.cos(phase * 1.2) * 300,
                math.sin(phase * 0.9) * 300
            )
            RunService.RenderStepped:Wait()
            currentHRP.Velocity = velo
            currentHRP.RotVelocity = Vector3.zero
            RunService.Stepped:Wait()
        end
        S.flingTargetRunning = false
        if not flinged then notify(targetPlr.DisplayName .. " not flinged (no 500m in 3s)") end
        local h = getHRP()
        if h then
            h.Velocity = Vector3.zero
            h.RotVelocity = Vector3.zero
            if S.flingOriginalCFrame then h.CFrame = S.flingOriginalCFrame end
        end
        S.flingOriginalCFrame = nil
        S.flingOriginalPosition = nil
        S.flingTargetThread = nil
        autoDisableFling()
    end)
end

local function getPlayerNames()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then table.insert(names, plr.Name) end
    end
    return names
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
    if S.flyConn then return end
    attachFlyBodyMovers()
    S.flyConn = RunService.Heartbeat:Connect(function()
        if not MovementSettings.Fly then return end
        local h = getHRP()
        if not h then return end
        if not S.flyBV or not S.flyBV.Parent then attachFlyBodyMovers() end
        if not S.flyBV or not S.flyBG then return end
        local mv = getFlyInput()
        S.flyBV.Velocity = mv.Magnitude > 0 and mv.Unit * MovementSettings.FlySpeed or Vector3.zero
        S.flyBG.CFrame = workspace.CurrentCamera.CFrame
    end)
end

local function stopFly()
    if S.flyConn then S.flyConn:Disconnect(); S.flyConn = nil end
    detachFlyBodyMovers()
end

local function startFOVCircle()
    if S.fovConn then return end
    if not S.fovGui then
        S.fovGui = Instance.new("ScreenGui")
        S.fovGui.Name = "HH_FOV"
        S.fovGui.ResetOnSpawn = false
        S.fovGui.IgnoreGuiInset = true
        pcall(function() S.fovGui.Parent = game:GetService("CoreGui") end)
        if not S.fovGui.Parent then S.fovGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
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
    S.fovConn = RunService.RenderStepped:Connect(function()
        if not AimbotSettings.FOVCircle then return end
        if not S.fovFrame then return end
        local radius = AimbotSettings.FOVRadius
        S.fovFrame.Size = UDim2.new(0, radius * 2, 0, radius * 2)
        if isMobile then
            local inset = GuiService:GetGuiInset()
            local vp = workspace.CurrentCamera.ViewportSize
            local cx = vp.X / 2
            local cy = (vp.Y / 2) + (inset.Y / 2)
            S.fovFrame.Position = UDim2.new(0, cx, 0, cy)
        else
            S.fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        end
    end)
end

local function stopFOVCircle()
    if S.fovConn then S.fovConn:Disconnect(); S.fovConn = nil end
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

local window
do
    local ok, err = pcall(function()
        window = API:CreateWindow("Happy Hub", "MM2 · Keyless · by replicatedman")
    end)
    if not ok or not window then
        warn("[HappyHub] CreateWindow failed: " .. tostring(err))
        return
    end
end

local homeTab      = window:CreateTab("Home", ICONS.Home)
local playersTab   = window:CreateTab("Players", ICONS.Plr)
local espTab       = window:CreateTab("Visuals", ICONS.Vis)
local movementTab  = window:CreateTab("Movement", ICONS.Mov)
local aimbotTab    = window:CreateTab("Combat", ICONS.Aim)
local avatarTab    = window:CreateTab("Avatar", ICONS.Avt)
local farmTab      = window:CreateTab("Farm", ICONS.Farm)
local miscTab      = window:CreateTab("Misc", ICONS.Misc)

window:CreateLabel(homeTab, "Happy Hub")
window:CreateParagraph(homeTab, "Best free hub · Since 2026 · v11.6 Update · MM2 Project")

window:CreateLabel(homeTab, "Music")
UI.musicToggleRef = window:CreateToggle(homeTab, "Companion", false, function(v)
    MiscSettings.MusicCompanion = v
    if v then
        if S.musicSound then S.musicSound:Destroy(); S.musicSound = nil end
        S.musicSound = Instance.new("Sound")
        S.musicSound.SoundId = "rbxassetid://98012717802240"
        S.musicSound.Volume = 10
        S.musicSound.Looped = true
        S.musicSound.Parent = SoundService
        S.musicSound:Play()
        notify("Playing: Companion")
    else
        if S.musicSound then S.musicSound:Stop(); S.musicSound:Destroy(); S.musicSound = nil end
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
UI.tpAllToggleRef = window:CreateToggle(playersTab, "TP All (Loop)", false, function(v)
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

window:CreateButton(playersTab, "Teleport to Target", function()
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
UI.flingDropdownRef = window:CreateDropdown(playersTab, "Player", getPlayerNames(), "", function(v)
    _G.__HH_FlingTarget = v
end)

Players.PlayerAdded:Connect(function()
    task.wait(1)
    if UI.flingDropdownRef and UI.flingDropdownRef.Refresh then
        pcall(function() UI.flingDropdownRef:Refresh(getPlayerNames()) end)
    end
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.2)
    if UI.flingDropdownRef and UI.flingDropdownRef.Refresh then
        pcall(function() UI.flingDropdownRef:Refresh(getPlayerNames()) end)
    end
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
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end)
window:CreateButton(playersTab, "Server Hop", function()
    pcall(function()
        local data = HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        )
        if data and data.data then
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
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
        if not S.mm2PeriodicThread then
            S.mm2PeriodicThread = task.spawn(function()
                while ESP.active.MM2 or VisualSettings.GunESP do
                    task.wait(1)
                    if ESP.active.MM2 then refreshAllESP() end
                    if VisualSettings.GunESP then applyGunESP() end
                end
                S.mm2PeriodicThread = nil
            end)
        end
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
        if not S.gunESPThread then
            S.gunESPThread = task.spawn(function()
                while VisualSettings.GunESP do
                    task.wait(0.5)
                    if VisualSettings.GunESP then applyGunESP() end
                end
                S.gunESPThread = nil
            end)
        end
    else
        clearGunESP()
    end
end)
registerControl(VisualSettings, "GunESP", UI.gunESPToggleRef)

window:CreateLabel(espTab, "Beam")
UI.beamToggleRef = window:CreateToggle(espTab, "Beam to Murderer", false, function(v)
    BeamSettings.Enabled = v
    VisualSettings.Beam = v
    if v then ensureBeamConn() end
    stopBeamIfIdle()
end)
registerControl(VisualSettings, "Beam", UI.beamToggleRef)

window:CreateParagraph(espTab, "Beam colors: green = clear · orange = innocent blocking · red = wall.")

window:CreateLabel(movementTab, "Fly")
UI.flyToggleRef = window:CreateToggle(movementTab, "Active Fly", false, function(v)
    MovementSettings.Fly = v
    if v then startFly() else stopFly() end
end)
registerControl(MovementSettings, "Fly", UI.flyToggleRef)

UI.flySpeedRef = window:CreateSlider(movementTab, "Fly Speed", 5, 200, 40, function(v) MovementSettings.FlySpeed = v end)
registerControl(MovementSettings, "FlySpeed", UI.flySpeedRef)

if isMobile then
    window:CreateParagraph(movementTab, "Fly mobile: drag your finger or use joystick")
else
    window:CreateParagraph(movementTab, "WASD + Space / LeftControl")
end

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
    if S.noclipConn then S.noclipConn:Disconnect(); S.noclipConn = nil end
    if v then
        S.noclipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    else
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
    if S.godConn then S.godConn:Disconnect(); S.godConn = nil end
    if v then
        S.godConn = RunService.Heartbeat:Connect(function()
            local hum = getHumanoid()
            if hum then hum.Health = hum.MaxHealth end
        end)
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

UserInputService.JumpRequest:Connect(function()
    if MiscSettings.InfJump then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

UI.afkRef = window:CreateToggle(movementTab, "Anti-AFK", false, function(v)
    MiscSettings.AntiAFK = v
    if S.antiAFKConn then S.antiAFKConn:Disconnect(); S.antiAFKConn = nil end
    if v then
        local vu = game:GetService("VirtualUser")
        S.antiAFKConn = LocalPlayer.Idled:Connect(function()
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
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

window:CreateLabel(movementTab, "Reset Character")
window:CreateButton(movementTab, "Autokill", function()
    local hum = getHumanoid()
    if hum then hum.Health = 0 end
end)

window:CreateLabel(movementTab, "Fling")
UI.flingToggleRef = window:CreateToggle(movementTab, "Touch fling", false, function(v)
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
UI.mm2LockRef = window:CreateToggle(aimbotTab, "Default aimbot", false, function(v)
    AimbotSettings.MM2LockOn = v
    if S.mm2Conn then S.mm2Conn:Disconnect(); S.mm2Conn = nil end
    if v then
        S.mm2Conn = RunService.RenderStepped:Connect(function()
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
        end)
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

window:CreateParagraph(aimbotTab, "Small Avatar = HumanoidRootPart. Use it for short/tiny avatars.")

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
    if S.triggerBotConn then S.triggerBotConn:Disconnect(); S.triggerBotConn = nil end
    if v then
        local lastShot = 0
        S.triggerBotConn = RunService.RenderStepped:Connect(function()
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
            fireGunAt(targetPart, murderer, false)
        end)
    end
end)
registerControl(AimbotSettings, "TriggerBot", UI.triggerRef)

UI.triggerRangeRef = window:CreateSlider(aimbotTab, "Trigger Range", 20, 400, 150, function(v) AimbotSettings.TriggerRange = v end)
registerControl(AimbotSettings, "TriggerRange", UI.triggerRangeRef)

window:CreateLabel(aimbotTab, "AutoShoot")
UI.autoFireRef = window:CreateToggle(aimbotTab, "Auto Fire  [B]", false, function(v)
    AimbotSettings.AutoFire = v
    if S.autoFireConn then S.autoFireConn:Disconnect(); S.autoFireConn = nil end
    if v then
        local lastShot = 0
        S.autoFireConn = RunService.RenderStepped:Connect(function()
            if not AimbotSettings.AutoFire then return end
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
            fireGunAt(targetPart, murderer, false)
        end)
    end
end)
registerControl(AimbotSettings, "AutoFire", UI.autoFireRef)

window:CreateLabel(aimbotTab, "Sheriff / Hero")
UI.autoKillRef = window:CreateToggle(aimbotTab, "Auto Kill Murderer", false, function(v)
    AimbotSettings.AutoKillMurderer = v
    if S.autoKillConn then S.autoKillConn:Disconnect(); S.autoKillConn = nil end
    if v then
        local lastShot = 0
        S.autoKillConn = RunService.RenderStepped:Connect(function()
            if not AimbotSettings.AutoKillMurderer then return end
            if not isLocalSheriffOrHero() then return end
            local murderer = getMurdererCached()
            if not isTargetSafe(murderer) then return end
            local targetPart = getMM2TargetPart(murderer.Character)
            if not targetPart then return end
            local myHRP = getHRP()
            if not myHRP then return end
            if not getEquippedGun() then return end
            local dist = (myHRP.Position - targetPart.Position).Magnitude
            if dist > AimbotSettings.MM2Range then return end
            local now = tick()
            if now - lastShot < 0.1 then return end
            lastShot = now
            fireGunAt(targetPart, murderer, true)
        end)
    end
end)
registerControl(AimbotSettings, "AutoKillMurderer", UI.autoKillRef)

window:CreateParagraph(aimbotTab, "Auto Kill = only fires if you're Sheriff/Hero with gun equipped.")

UI.wallCheckRef = window:CreateToggle(aimbotTab, "Wall Check", true, function(v)
    AimbotSettings.WallCheck = v
end)
registerControl(AimbotSettings, "WallCheck", UI.wallCheckRef)

window:CreateParagraph(aimbotTab, "Wall Check: 0.2s grace period after leaving cover. Innocents always block shots.")

window:CreateLabel(aimbotTab, "Murderer OP")
window:CreateButton(aimbotTab, "Kill Everyone", function()
    if not isLocalMurderer() then notify("You are not the Murderer") return end
    if S.killAllRunning then return end
    S.killAllRunning = true
    notify("Killing everyone")
    task.spawn(function()
        local startTime = tick()
        local duration = 3
        local spinAngle = 0
        local lastEquip = 0
        local myHRP = getHRP()
        local originalCFrame = myHRP and myHRP.CFrame or nil
        expandHitboxForAll()
        local spinConn = RunService.RenderStepped:Connect(function(dt)
            local hrp = getHRP()
            if not hrp then return end
            spinAngle = spinAngle + (dt * 25)
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, spinAngle, 0)
        end)
        while S.killAllRunning and tick() - startTime < duration do
            local now = tick()
            if now - lastEquip > 0.5 then
                lastEquip = now
                equipKnife()
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if not S.killAllRunning then break end
                if tick() - startTime >= duration then break end
                if plr ~= LocalPlayer and plr.Character then
                    local theirHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                    local curHRP = getHRP()
                    if theirHRP and curHRP then
                        if not fireTeleportToPart(curHRP, theirHRP) then
                            curHRP.CFrame = CFrame.new(theirHRP.Position, theirHRP.Position + theirHRP.CFrame.LookVector)
                        else
                            task.wait(0.03)
                            local h = getHRP()
                            if h and (h.Position - theirHRP.Position).Magnitude > 3 then
                                h.CFrame = CFrame.new(theirHRP.Position, theirHRP.Position + theirHRP.CFrame.LookVector)
                            end
                        end
                        task.wait(0.1)
                        pcall(function()
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            task.wait(0.03)
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        end)
                    end
                end
            end
            task.wait(0.1)
        end
        if spinConn then spinConn:Disconnect() end
        restoreHitboxes()
        local finalHRP = getHRP()
        if finalHRP and originalCFrame then
            finalHRP.Velocity = Vector3.zero
            finalHRP.RotVelocity = Vector3.zero
            finalHRP.CFrame = originalCFrame
            task.wait(0.05)
            finalHRP.Velocity = Vector3.zero
            finalHRP.RotVelocity = Vector3.zero
        end
        S.killAllRunning = false
        notify("Done! Back to origin.")
    end)
end)

window:CreateLabel(avatarTab, "Avatar")
window:CreateParagraph(avatarTab, "Korblox + custom animation pack")

UI.korbloxRef = window:CreateToggle(avatarTab, "Korblox Deathspeaker", false, function(v)
    AvatarSettings.Korblox = v
    if v then applyKorblox() else removeKorblox() end
end)
registerControl(AvatarSettings, "Korblox", UI.korbloxRef)

window:CreateLabel(avatarTab, "Animation Pack")
UI.animPackRef = window:CreateToggle(avatarTab, "Custom Anims", false, function(v)
    AvatarSettings.AnimPack = v
    if v then
        applyAnimPack()
        notify("Anim pack applied")
    else
        notify("Rejoin to restore default anims", 3)
    end
end)
registerControl(AvatarSettings, "AnimPack", UI.animPackRef)

window:CreateParagraph(avatarTab, "Idle · Walk · Run · Fall · Climb · Jump replaced. Re-applies on respawn if active.")

LocalPlayer.CharacterAdded:Connect(function()
    MurdererCache.plr = nil
    MurdererCache.time = 0
    for k in pairs(TargetVisibility) do TargetVisibility[k] = nil end
    for k in pairs(VisCache) do VisCache[k] = nil end
    S.korbloxPart = nil
    S.lastSafeCFrame = nil
    S.currentIdleTrack = nil
    S.currentEmoteTrack = nil
    S.flingOriginalCFrame = nil
    S.flingOriginalPosition = nil
    S.flingTargetRunning = false
    S.killAllRunning = false
    if S.animPriorityConn then S.animPriorityConn:Disconnect(); S.animPriorityConn = nil end
    if S.flingTargetThread then task.cancel(S.flingTargetThread); S.flingTargetThread = nil end
    clearBeamPool(S.beamData)
    task.wait(0.6)
    if MovementSettings.Fly then attachFlyBodyMovers() end
    if AvatarSettings.Korblox then pcall(applyKorblox) end
    if AvatarSettings.AnimPack then pcall(applyAnimPack) end
    if FarmSettings.AutoFarm or FarmSettings.ManualCollect then
        task.wait(0.5)
        if not S.coinCollecting then startCoinCollector() end
    end
end)

window:CreateLabel(farmTab, "Coin Farm")
window:CreateParagraph(farmTab, "Farm engine powered by Hexagonal Client · Made by odecode")

UI.autoFarmRef = window:CreateToggle(farmTab, "Auto Farm", false, function(v)
    FarmSettings.AutoFarm = v
    if v then startCoinCollector()
    else if not FarmSettings.ManualCollect then stopCoinCollector() end end
end)
registerControl(FarmSettings, "AutoFarm", UI.autoFarmRef)

UI.manualCollectRef = window:CreateToggle(farmTab, "Manual Collect", false, function(v)
    FarmSettings.ManualCollect = v
    if v then startCoinCollector()
    else if not FarmSettings.AutoFarm then stopCoinCollector() end end
end)
registerControl(FarmSettings, "ManualCollect", UI.manualCollectRef)

window:CreateLabel(farmTab, "Tuning")
UI.coinSpeedRef = window:CreateSlider(farmTab, "Move Speed", 10, 60, 20, function(v)
    FarmSettings.CoinSpeed = v
end)
registerControl(FarmSettings, "CoinSpeed", UI.coinSpeedRef)

UI.pickupRadiusRef = window:CreateSlider(farmTab, "Pickup Radius", 1, 10, 3, function(v)
    FarmSettings.PickupRadius = v
end)
registerControl(FarmSettings, "PickupRadius", UI.pickupRadiusRef)

window:CreateLabel(farmTab, "Live Stats")
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
        for bagName, _ in pairs(data) do S.bagProgress[bagName] = 0 end
        S.totalCoins = 0
        if S.coinCountSetter then S.coinCountSetter(0) end
        S.roundActive = true
    end)
end

if coinCollectedEvent then
    coinCollectedEvent.OnClientEvent:Connect(function(bagName, currentCoins)
        if S.bagProgress[bagName] ~= nil then
            S.bagProgress[bagName] = currentCoins
            S.totalCoins = 0
            for _, v in pairs(S.bagProgress) do S.totalCoins = S.totalCoins + v end
            if S.coinCountSetter then S.coinCountSetter(S.totalCoins) end
        end
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
    end)
end

if roundEndFadeEvent then
    roundEndFadeEvent.OnClientEvent:Connect(function()
        S.roundActive = false
        S.roleCache = {}
        onRoundEnd()
        task.wait(0.05)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then clearHighlights(plr) end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if (FarmSettings.AutoFarm or FarmSettings.ManualCollect) and not S.coinCollecting then
            startCoinCollector()
        end
    end
end)

window:CreateLabel(miscTab, "Gun")
window:CreateButton(miscTab, "Pick up Gun", function()
    local ok, reason = bringGunToPlayer()
    if ok then notify("Gun incoming (" .. tostring(reason) .. ")")
    else notify("Failed: " .. tostring(reason)) end
end)

UI.autoTpGunRef = window:CreateToggle(miscTab, "Auto pick up Gun", false, function(v)
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

local function toggleESPAll()
    local anyOn = VisualSettings.MM2ESP or VisualSettings.NameTags or VisualSettings.GunESP or VisualSettings.Beam
    local newState = not anyOn

    VisualSettings.MM2ESP  = newState
    VisualSettings.OGESP   = false
    VisualSettings.NameTags = newState
    VisualSettings.GunESP  = newState
    VisualSettings.Beam    = newState

    ESP.active.MM2     = newState
    ESP.active.OG      = false
    ESP.active.NameTag = newState

    refreshAllESP()
    applyGunESP()

    if newState then
        if not S.nameTagUpdater then startNameTagUpdater() end
        ensureBeamConn()
    else
        stopNameTagUpdater()
        stopBeamIfIdle()
        clearGunESP()
        clearBeamPool(S.beamData)
    end

    if UI.mm2ESPToggleRef and UI.mm2ESPToggleRef.SetState then pcall(function() UI.mm2ESPToggleRef:SetState(newState) end) end
    if UI.ogESPToggleRef and UI.ogESPToggleRef.SetState then pcall(function() UI.ogESPToggleRef:SetState(false) end) end
    if UI.nameTagToggleRef and UI.nameTagToggleRef.SetState then pcall(function() UI.nameTagToggleRef:SetState(newState) end) end
    if UI.gunESPToggleRef and UI.gunESPToggleRef.SetState then pcall(function() UI.gunESPToggleRef:SetState(newState) end) end
    if UI.beamToggleRef and UI.beamToggleRef.SetState then pcall(function() UI.beamToggleRef:SetState(newState) end) end

    notify("ESP " .. (newState and "ON" or "OFF"), 2)
end

local function setupMobileButtons()
    if not isMobile then return end
    if type(window.AddMobileButton) ~= "function" then
        warn("[HappyHub] AddMobileButton not available in this API version")
        return
    end

    local ok, err = pcall(function()
        window:AddMobileButton({
            OnClick = function()
                task.spawn(mobileForceShoot)
            end,
            Icon = "rbxassetid://12804017021",
            Tooltip = "Shoot Murderer"
        })
    end)
    if not ok then warn("[HappyHub] AddMobileButton SHOOT failed: " .. tostring(err)) end

    pcall(function()
        window:AddMobileButton({
            OnClick = function()
                toggleESPAll()
            end,
            Icon = "rbxassetid://12804017021",
            Tooltip = "Toggle ESP (all except Neutral)"
        })
    end)

    pcall(function()
        window:AddMobileButton({
            Feature = "Default aimbot",
            Tooltip = "Toggle Aimbot"
        })
    end)
end

if window._makeMobileBtn and isMobile then
    window._makeMobileBtn("AIM", function()
        if UI.mm2LockRef then UI.mm2LockRef.SetState(not UI.mm2LockRef.GetState()) end
    end)
    window._makeMobileBtn("ESP", function()
        toggleESPAll()
    end)
    window._makeMobileBtn("UI", function() window.ToggleUI() end)
end

setupMobileButtons()
startMobileFlyDrag()

UserInputService.InputBegan:Connect(function(input, gp)
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
end)

local function snapshotSettings()
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
            AutoFarm      = FarmSettings.AutoFarm,
            ManualCollect = FarmSettings.ManualCollect,
            CoinSpeed     = FarmSettings.CoinSpeed,
            PickupRadius  = FarmSettings.PickupRadius,
        },
        Beam = {
            Enabled = BeamSettings.Enabled,
            Thickness = BeamSettings.Thickness,
            Transparency = BeamSettings.Transparency,
            MaxIterations = BeamSettings.MaxIterations,
            WaypointOffset = BeamSettings.WaypointOffset,
        },
        AntiVoid = {
            Threshold = AntiVoidSettings.Threshold,
            SafeY = AntiVoidSettings.SafeY,
        },
        Theme = getCurrentTheme(),
    }
end

local function applyConfig(data)
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
    if data.Farm then
        for k, v in pairs(data.Farm) do FarmSettings[k] = v end
    end
    if data.Beam then
        for k, v in pairs(data.Beam) do BeamSettings[k] = v end
    end
    if data.AntiVoid then
        for k, v in pairs(data.AntiVoid) do AntiVoidSettings[k] = v end
    end
    if data.Theme and data.Theme ~= getCurrentTheme() then setTheme(data.Theme) end
    if MovementSettings.Fly then startFly() else stopFly() end
    if MiscSettings.AntiVoid then startAntiVoid() else stopAntiVoid() end
    if MovementSettings.Noclip then
        if S.noclipConn then S.noclipConn:Disconnect() end
        S.noclipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    elseif S.noclipConn then
        S.noclipConn:Disconnect(); S.noclipConn = nil
    end
    if MovementSettings.God then
        if S.godConn then S.godConn:Disconnect() end
        S.godConn = RunService.Heartbeat:Connect(function()
            local hum = getHumanoid()
            if hum then hum.Health = hum.MaxHealth end
        end)
    elseif S.godConn then
        S.godConn:Disconnect(); S.godConn = nil
    end
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = MovementSettings.WalkSpeed
        hum.JumpPower = MovementSettings.JumpPower
        hum.UseJumpPower = true
    end
    ESP.active.MM2     = VisualSettings.MM2ESP
    ESP.active.OG      = VisualSettings.OGESP
    ESP.active.NameTag = VisualSettings.NameTags
    refreshAllESP()
    applyGunESP()
    if VisualSettings.NameTags then startNameTagUpdater() else stopNameTagUpdater() end
    if BeamSettings.Enabled then ensureBeamConn() else stopBeamIfIdle() end
    if AimbotSettings.FOVCircle then startFOVCircle() else stopFOVCircle() end
    if AvatarSettings.Korblox then pcall(applyKorblox) else pcall(removeKorblox) end
    if AvatarSettings.AnimPack then pcall(applyAnimPack) end
    if FarmSettings.AutoFarm or FarmSettings.ManualCollect then
        if not S.coinCollecting then startCoinCollector() end
    else
        stopCoinCollector()
    end
    syncUIControls()
    if window.UpdateThemeButtons then window:UpdateThemeButtons() end
end

window:SetConfigSnapshot(snapshotSettings)
window:SetConfigApply(applyConfig)
window:BuildConfigPage()

task.delay(2, function()
    if isMobile then
        notify("Mobile · 3 botones cargados", 4)
    else
        notify("PC method", 4)
    end
end)

notify("Hello again "..LocalPlayer.DisplayName, 3)
