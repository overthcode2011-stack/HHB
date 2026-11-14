do
    local oldState = getgenv and getgenv().__HH_STATE
    if oldState then
        pcall(function()
            for _, c in ipairs(oldState.connections or {}) do pcall(function() c:Disconnect() end) end
            for _, t in ipairs(oldState.threads or {}) do pcall(task.cancel, t) end
            for _, g in ipairs(oldState.screenGuis or {}) do pcall(function() g:Destroy() end) end
        end)
        if getgenv then getgenv().__HH_STATE = nil end
        task.wait(0.3)
    end
end

getgenv().__HH_STATE = { connections = {}, threads = {}, screenGuis = {}, startedAt = tick() }
local ConnectionRegistry = {}

local function trackConn(key, conn)
    if not conn then return conn end
    if key then
        if ConnectionRegistry[key] then pcall(function() ConnectionRegistry[key]:Disconnect() end) end
        ConnectionRegistry[key] = conn
    end
    local list = getgenv().__HH_STATE.connections
    if #list > 80 then
        local alive = {}
        for i = 1, #list do
            local c = list[i]
            if c then
                local ok, connected = pcall(function() return c.Connected end)
                if ok and connected then alive[#alive + 1] = c end
            end
        end
        getgenv().__HH_STATE.connections = alive
        list = alive
    end
    table.insert(list, conn)
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
        local list = getgenv().__HH_STATE.threads
        if #list > 40 then
            local alive = {}
            for i = 1, #list do
                local th = list[i]
                if th then
                    local ok, status = pcall(function() return coroutine.status(th) end)
                    if ok and status ~= "dead" then alive[#alive + 1] = th end
                end
            end
            getgenv().__HH_STATE.threads = alive
            list = alive
        end
        table.insert(list, t)
    end
    return t
end

local function trackGui(g)
    if g then table.insert(getgenv().__HH_STATE.screenGuis, g) end
    return g
end

local Cfg = getgenv().HH_CONFIG
local AimbotSettings = Cfg.AimbotSettings
local VisualSettings = Cfg.VisualSettings
local MiscSettings = Cfg.MiscSettings
local MovementSettings = Cfg.MovementSettings
local AvatarSettings = Cfg.AvatarSettings
local FarmSettings = Cfg.FarmSettings
local C = Cfg.C
local BEAM = Cfg.BEAM
local AntiVoidSettings = Cfg.AntiVoidSettings

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local MurdererCache = { plr = nil, time = 0 }
local TargetVisibility = {}
local VisCache = {}

local S = {
    noclipConn = nil, godConn = nil, antiAFKConn = nil, flyConn = nil, flyBV = nil, flyBG = nil,
    mm2Conn = nil, triggerBotConn = nil, autoFireConn = nil, autoKillConn = nil, antiVoidConn = nil, lastSafeCFrame = nil,
    autoTpGunThread = nil, flingTask = nil, tpAllTask = nil, nameTagUpdater = nil, mm2PeriodicThread = nil, gunESPThread = nil,
    fovConn = nil, fovGui = nil, fovFrame = nil, flingTargetThread = nil, flingTargetRunning = false,
    flingOriginalCFrame = nil, flingOriginalPosition = nil, flingWasFlingOn = false, antiFlingConnections = {}, antiFlingActive = false,
    flingRunning = false, tpAllRunning = false, killAllRunning = false, musicSound = nil, currentEmoteTrack = nil,
    miniBoxTrack = nil, animPriorityConn = nil, korbloxPart = nil, mobileFlyVec = Vector3.zero, mobileFlyDragging = false,
    beamData = { segments = {}, updateConn = nil, lastTick = 0 }, coinCollecting = false, coinConnection = nil, coinGyro = nil,
    roundActive = false, bagProgress = {}, totalCoins = 0, coinStatusSetter = nil, coinCountSetter = nil, roleCache = {},
    heroWatcher = { active = false, thread = nil, originalSheriffName = nil }, gunESP = { active = false, highlights = {}, billboards = {}, trackedGun = nil },
    hitboxExpander = { active = false, savedSizes = {}, size = Vector3.new(40, 40, 40) }, fadeConn = nil, tpEvent = nil,
    silentAimHookInstalled = false, hookNamecall = nil, getNamecall = nil, lastMobileShot = 0, spectating = false, spectateTarget = nil, spectateDefaultSubject = nil,
    lastCollectTime = 0, lastCamUpdate = 0, autoKillAll = false, killAllTask = nil, ultraOptActive = false, savedLighting = nil,
    savedLightingEffects = nil, savedFarmStates = nil, farmTargetCoin = nil, farmTouchedCoins = {}, farmBlacklist = {}, farmWalkBV = nil,
    farmLastCollectAt = 0, farmStartedAt = 0, farmLastFallbackAt = 0, farmStuckPos = nil, farmStuckAt = 0, farmUnstickAttempts = 0,
    farmLastCollectSpeedAt = 0, farmTargetStartedAt = 0, lastGyroUpdate = 0, lastKnifeDodge = 0, fadeReceivedAt = 0,
    roundStartedAt = 0, rerolling = false
}

local ESP_COLORS = { MM2 = { Murderer = Color3.fromRGB(255, 0, 0), Sheriff = Color3.fromRGB(0, 132, 255), Hero = Color3.fromRGB(255, 200, 0), Innocent = Color3.fromRGB(56, 255, 112) }, OG = Color3.fromRGB(255, 255, 255), Gun = Color3.fromRGB(255, 200, 0) }
local ESP = { active = { MM2 = false, OG = false, NameTag = false }, highlights = { MM2 = {}, OG = {} }, nameTags = {} }

local function getHRP() local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHumanoid() local c = LocalPlayer.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function markRoundStarted() if S.roundStartedAt == 0 or (tick() - S.roundStartedAt) > 15 then S.roundStartedAt = tick() end end
local function isCoinValid(c) if not c or not c.Parent then return false end if c:GetAttribute("Collected") then return false end return c:FindFirstChildWhichIsA("TouchTransmitter") ~= nil end
local function isCoinBlacklisted(c) local t = S.farmBlacklist[c] if not t then return false end if tick() - t > C.FARM_BLACKLIST_TIME then S.farmBlacklist[c] = nil return false end return true end
local function blacklistCoin(c) if c then S.farmBlacklist[c] = tick() end end
local function getFarmSpeed() local s = FarmSettings.FarmSpeed if type(s) == "number" and s >= 5 then return math.clamp(s, 5, 60) end return C.FARM_FLY_SPEED end
local function getNearBoost() local b = FarmSettings.NearBoost if type(b) == "number" and b >= 1 then return math.clamp(b, 1, 2) end return C.FARM_NEAR_BOOST end

local function tryDodgeKnife(p1, p2)
    if not MiscSettings.KnifeDodge or typeof(p1) ~= "Vector3" or typeof(p2) ~= "Vector3" then return end
    local now = tick() if now - S.lastKnifeDodge < C.KNIFE_DODGE_COOLDOWN then return end
    local myHRP = getHRP() if not myHRP then return end
    local myPos = myHRP.Position if (p1 - myPos).Magnitude < 8 then return end
    local dir = p2 - p1 local len = dir.Magnitude if len < 5 then return end
    local unit = dir.Unit local toMe = myPos - p1 local proj = toMe:Dot(unit)
    if proj < -10 or proj > len + 30 then return end
    local closest = p1 + unit * math.clamp(proj, 0, len)
    if (myPos - closest).Magnitude > C.KNIFE_DODGE_MIN_DIST or math.abs(closest.Y - myPos.Y) > 10 then return end
    local perp = unit:Cross(Vector3.yAxis) if perp.Magnitude < 0.1 then perp = unit:Cross(Vector3.xAxis) end
    perp = Vector3.new(perp.X, 0, perp.Z) if perp.Magnitude < 0.1 then return end
    perp = perp.Unit local sideSign = 1 if (myPos - closest):Dot(perp) < 0 then sideSign = -1 end
    local dodgePos = Vector3.new(myPos.X + perp.X * sideSign * C.KNIFE_DODGE_OFFSET, myPos.Y + 3, myPos.Z + perp.Z * sideSign * C.KNIFE_DODGE_OFFSET)
    myHRP.CFrame = CFrame.new(dodgePos) myHRP.Velocity = Vector3.zero myHRP.RotVelocity = Vector3.zero
    S.lastKnifeDodge = now if S.coinCollecting then if S.farmWalkBV then S.farmWalkBV.Velocity = Vector3.zero end S.farmTargetCoin = nil S.farmStuckPos = nil S.farmStuckAt = 0 end
    pcall(function() getgenv().HH_UI.Notify("Knife dodged", 1) end)
end

local function setupKnifeDodgeHook()
    local cs = ReplicatedStorage:FindFirstChild("ClientServices") if not cs then return end
    local ws = cs:FindFirstChild("WeaponService") if not ws then return end
    local gunFired = ws:FindFirstChild("GunFired") if not gunFired or not gunFired:IsA("RemoteEvent") then return end
    trackConn("knife_dodge", gunFired.OnClientEvent:Connect(function(handle, p1, p2, part)
        if typeof(p1) ~= "Vector3" or typeof(p2) ~= "Vector3" then return end
        task.spawn(tryDodgeKnife, p1, p2)
    end))
end

local function isGunTool(t)
    if not t or not t:IsA("Tool") then return false end
    if t:FindFirstChild("Shoot") or t:FindFirstChild("Shoot", true) then return true end
    local name = t.Name:lower()
    return name:find("gun", 1, true) ~= nil or name:find("pistol", 1, true) ~= nil or name:find("revolver", 1, true) ~= nil or name:find("sheriff", 1, true) ~= nil
end

local function findGunEquipped()
    local char = LocalPlayer.Character if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") and isGunTool(t) then return t end end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then local eq = hum:FindFirstChildWhichIsA("Tool") if eq and isGunTool(eq) then return eq end end
    return nil
end

local function findGunInBackpack()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack") if not bp then return nil end
    for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and isGunTool(t) then return t end end
    return nil
end

local function waitForGunAttachment(timeout)
    local deadline = tick() + (timeout or 1.2)
    while tick() < deadline do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local att = hrp and hrp:FindFirstChild("GunRaycastAttachment")
        if att and att:IsA("Attachment") then return att end
        task.wait(0.05)
    end
    return nil
end

local function ensureGunReady()
    local char = LocalPlayer.Character if not char then return nil, "no character" end
    local equipped = findGunEquipped() if equipped and equipped.Parent == char then waitForGunAttachment(0.6) return equipped, "already in rig" end
    local inBag = findGunInBackpack() if not inBag then return nil, "no gun" end
    local hum = char:FindFirstChildOfClass("Humanoid") if not hum then return nil, "no humanoid" end
    pcall(function() if inBag.Parent ~= char then inBag.Parent = char end end)
    pcall(function() hum:EquipTool(inBag) end)
    local deadline = tick() + 1.5
    while tick() < deadline do
        local eq = findGunEquipped()
        if eq and eq.Parent == char then waitForGunAttachment(0.8) return eq, "equipped" end
        task.wait(0.05)
    end
    return nil, "timeout"
end

local UNC = { hookmetamethod = type(hookmetamethod) == "function", getnamecallmethod = type(getnamecallmethod) == "function", getconnections = type(getconnections) == "function", hookfunction = type(hookfunction) == "function", firetouchinterest = type(firetouchinterest) == "function" }

local function isGunRelatedRemote(r)
    if not r or not (r:IsA("RemoteEvent") or r:IsA("RemoteFunction") or r:IsA("BindableEvent")) then return false end
    local p = r.Parent if not p then return false end
    if p:IsA("Tool") and isGunTool(p) then return true end
    if p.Parent and p.Parent:IsA("Tool") and isGunTool(p.Parent) then return true end
    return false
end

local function isGunShootRemote(r)
    if not r or not (r:IsA("RemoteEvent") or r:IsA("RemoteFunction") or r:IsA("BindableEvent")) then return false end
    local n = r.Name:lower() if n:find("shoot", 1, true) or n:find("fire", 1, true) then return true end
    return isGunRelatedRemote(r)
end

local function collectShootChannels(gun)
    local channels = {} if not gun then return channels end
    local function push(o, k) if o then table.insert(channels, { obj = o, kind = k }) end end
    for _, c in ipairs(gun:GetChildren()) do
        local n = c.Name:lower()
        if n == "shoot" or n == "fire" or n == "gunshoot" then
            if c:IsA("RemoteEvent") then push(c, "RemoteEvent") elseif c:IsA("BindableEvent") then push(c, "BindableEvent") elseif c:IsA("RemoteFunction") then push(c, "RemoteFunction") end
        end
    end
    for _, d in ipairs(gun:GetDescendants()) do
        if d ~= gun then
            local n = d.Name:lower() local pn = d.Parent and d.Parent.Name:lower() or ""
            if n:find("shoot", 1, true) or (n == "fire" and pn:find("event")) then
                if d:IsA("RemoteEvent") then push(d, "RemoteEvent") elseif d:IsA("BindableEvent") then push(d, "BindableEvent") elseif d:IsA("RemoteFunction") then push(d, "RemoteFunction") end
            end
        end
    end
    local seen, unique = {}, {}
    for _, ch in ipairs(channels) do if not seen[ch.obj] then seen[ch.obj] = true unique[#unique + 1] = ch end end
    return unique
end

local function fireGunChannels(gun, originCF, targetCF)
    if not gun or not originCF or not targetCF then return false, "bad args" end
    local channels = collectShootChannels(gun)
    local deep = gun:FindFirstChild("Shoot", true)
    if deep then
        local already = false for _, ch in ipairs(channels) do if ch.obj == deep then already = true break end end
        if not already then
            if deep:IsA("RemoteEvent") then table.insert(channels, 1, { obj = deep, kind = "RemoteEvent" }) elseif deep:IsA("BindableEvent") then table.insert(channels, 1, { obj = deep, kind = "BindableEvent" }) elseif deep:IsA("RemoteFunction") then table.insert(channels, 1, { obj = deep, kind = "RemoteFunction" }) end
        end
    end
    if #channels == 0 then return false, "no shoot channel" end
    local any, lastErr = false, nil
    pcall(function() gun:Activate() end)
    for _, ch in ipairs(channels) do
        local obj, kind = ch.obj, ch.kind
        if kind == "RemoteEvent" then
            local ok, err = pcall(function() obj:FireServer(originCF, targetCF) end) if ok then any = true else lastErr = err end
            pcall(function() obj:FireServer(targetCF, originCF) end) pcall(function() obj:FireServer(targetCF) end) pcall(function() obj:FireServer(originCF.Position, targetCF.Position) end)
        elseif kind == "BindableEvent" then
            local ok, err = pcall(function() obj:Fire(originCF, targetCF) end) if ok then any = true else lastErr = err end
            pcall(function() obj:Fire(targetCF) end) pcall(function() obj:Fire(originCF, targetCF, true) end)
        elseif kind == "RemoteFunction" then
            local ok, err = pcall(function() obj:InvokeServer(originCF, targetCF) end) if ok then any = true else lastErr = err end
            pcall(function() obj:InvokeServer(targetCF) end)
        end
    end
    return any, tostring(lastErr or "done")
end

local function spectatePlayer(plr)
    if not plr or not plr.Character then return end
    local theirHum = plr.Character:FindFirstChildOfClass("Humanoid") if not theirHum then return end
    if not S.spectating then S.spectateDefaultSubject = workspace.CurrentCamera and workspace.CurrentCamera.CameraSubject or nil end
    local cam = workspace.CurrentCamera if cam then cam.CameraSubject = theirHum cam.CameraType = Enum.CameraType.Custom end
    S.spectating = true S.spectateTarget = plr
end

local function stopSpectating()
    local cam = workspace.CurrentCamera if cam then
        local myHum = getHumanoid()
        if myHum then cam.CameraSubject = myHum elseif S.spectateDefaultSubject then cam.CameraSubject = S.spectateDefaultSubject else cam.CameraSubject = nil end
        cam.CameraType = Enum.CameraType.Custom
    end
    S.spectating = false S.spectateTarget = nil S.spectateDefaultSubject = nil
end

local GunShootBindable = nil local GunShootLastArgs = nil local GunShootHandlerHooked = false

local function hookGunShootEvent(bindable)
    if not bindable or not bindable:IsA("BindableEvent") then return end
    if GunShootHandlerHooked and GunShootBindable == bindable then return end
    if type(getconnections) ~= "function" or type(hookfunction) ~= "function" then return end
    GunShootBindable = bindable getgenv().HH_GunShootBindable = bindable GunShootHandlerHooked = false
    for _, conn in ipairs(getconnections(bindable.Event)) do
        if conn.Function then
            local old
            old = hookfunction(conn.Function, function(...)
                local args = table.pack(...) GunShootLastArgs = args
                if MiscSettings.SilentAim then
                    local murderer = getMurdererCached()
                    if isTargetSafe(murderer) then
                        local targetPart = getMM2TargetPart(murderer.Character)
                        if targetPart then
                            local newTargetCF = predictAim(targetPart)
                            if newTargetCF then
                                for i = 2, math.min(5, args.n) do if typeof(args[i]) == "CFrame" then args[i] = newTargetCF break end end
                            end
                        end
                    end
                end
                return old(table.unpack(args, 1, args.n))
            end)
            GunShootHandlerHooked = true break
        end
    end
end

local function scanForGunShoot()
    local char = LocalPlayer.Character if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and isGunTool(tool) then
            local ev = tool:FindFirstChild("Shoot")
            if ev and ev:IsA("BindableEvent") then hookGunShootEvent(ev) return end
        end
    end
end

local function findGunDrop()
    for _, o in ipairs(workspace:GetChildren()) do
        if o:IsA("BasePart") and o.Name:lower():find("gundrop") then return o end
        if o:IsA("Model") then local f = o:FindFirstChild("GunDrop", true) if f and f:IsA("BasePart") then return f end end
    end
    local gd = workspace:FindFirstChild("GunDrop", true) if gd and gd:IsA("BasePart") then return gd end
    return nil
end

local function hasTool(parent, name)
    if not parent then return false end
    for _, c in ipairs(parent:GetChildren()) do if c:IsA("Tool") then local n = c.Name:lower() if n == name:lower() or n:find(name:lower(), 1, true) then return true end end end
    return false
end

local function getRoleFromCache(plr) local i = S.roleCache[plr.Name] if i and i.Role then return i.Role end return nil end

local function isLocalSheriffOrHero()
    local c = getRoleFromCache(LocalPlayer) if c == "Sheriff" or c == "Hero" then return true end
    local char, bp = LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")
    if hasTool(char, "Gun") or hasTool(bp, "Gun") then return true end
    return false
end

local function isPlrMurderer(plr)
    if not plr or plr == LocalPlayer or not plr.Parent then return false end
    if getRoleFromCache(plr) == "Murderer" then return true end
    local char, bp = plr.Character, plr:FindFirstChildOfClass("Backpack")
    if (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) then return true end
    return false
end

local function isTargetSafe(plr)
    if not plr or plr == LocalPlayer or not plr.Character then return false end
    local h = plr.Character:FindFirstChildOfClass("Humanoid") if not h or h.Health <= 0 then return false end
    if not isPlrMurderer(plr) then return false end
    return true
end

local function getMM2Role(plr)
    if plr == LocalPlayer then return "Innocent" end
    local c = getRoleFromCache(plr) if c then return c end
    local char, bp = plr.Character, plr:FindFirstChildOfClass("Backpack")
    if hasTool(char, "Knife") or hasTool(bp, "Knife") then return "Murderer" end
    if hasTool(char, "Gun") or hasTool(bp, "Gun") then
        for _, i in pairs(S.roleCache) do if i.Role == "Sheriff" and not i.Dead then return "Sheriff" end end
        return "Hero"
    end
    return "Innocent"
end

local function getMurderer()
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and getRoleFromCache(p) == "Murderer" then return p end end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then local c, b = p.Character, p:FindFirstChild("Backpack") if (c and c:FindFirstChild("Knife")) or (b and b:FindFirstChild("Knife")) then return p end end
    end
    return nil
end

local function getMurdererCached()
    local now = tick() local c = MurdererCache.plr
    if c and c.Parent and c.Character and (now - MurdererCache.time) < C.MURDERER_TTL then return c end
    local f = getMurderer() MurdererCache.plr = f MurdererCache.time = now
    return f
end

local function getSheriff()
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and getRoleFromCache(p) == "Sheriff" then return p end end
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and getRoleFromCache(p) == "Hero" then return p end end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then local c, b = p.Character, p:FindFirstChild("Backpack") if (c and c:FindFirstChild("Gun")) or (b and b:FindFirstChild("Gun")) then return p end end
    end
    return nil
end

local function getHero() for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and getRoleFromCache(p) == "Hero" then return p end end return nil end

local function isLocalMurderer()
    if getRoleFromCache(LocalPlayer) == "Murderer" then return true end
    local c, b = LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack")
    if (c and c:FindFirstChild("Knife")) or (b and b:FindFirstChild("Knife")) then return true end
    return false
end

local function getMM2TargetPart(c)
    if not c then return nil end
    if AimbotSettings.MM2Target == "Head" then return c:FindFirstChild("Head")
    elseif AimbotSettings.MM2Target == "Torso" then return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
    else return c:FindFirstChild("HumanoidRootPart") end
end

local function predictAim(t)
    if not t then return nil end
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if not ok or not ping or ping <= 0 then ping = 0.05 end
    return CFrame.new(t.Position + t.AssemblyLinearVelocity * (ping * 1.15))
end

local function getPredictedPosition(p, o)
    if not p or not p.Character then return nil end
    local t = p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("HumanoidRootPart")
    local h = p.Character:FindFirstChildOfClass("Humanoid") if not t or not h then return nil end
    local off = o or C.YARHM_SHOOT_OFFSET
    return t.Position + ((t.AssemblyLinearVelocity * Vector3.new(0.75, 0.5, 0.75)) * (off / 15)) + h.MoveDirection * off
end

local function getCharacterFromPart(p)
    if not p then return nil end
    local c = p
    while c and c ~= workspace do if c:IsA("Model") then local plr = Players:GetPlayerFromCharacter(c) if plr then return plr end end c = c.Parent end
    return nil
end

local function classifyPathHit(o, t, c)
    local d = t - o local dist = d.Magnitude if dist < 0.5 then return "clear", nil end
    local params = RaycastParams.new() params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { workspace.CurrentCamera } if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    params.FilterDescendantsInstances = ignore params.IgnoreWater = true
    local r = workspace:Raycast(o, d.Unit * (dist + 1), params)
    if not r then return "clear", nil end
    if c and (r.Instance:IsDescendantOf(c) or r.Instance == c) then return "target", nil end
    local h = getCharacterFromPart(r.Instance)
    if h and h ~= LocalPlayer then if getMM2Role(h) ~= "Murderer" then return "innocent", h end return "clear", nil end
    return "wall", nil
end

local function applyGracePeriod(p, v)
    if not p then return v end
    local now = tick() local tv = TargetVisibility[p]
    if not tv then tv = { wasHidden = false, visibleSince = nil } TargetVisibility[p] = tv end
    if v then
        if tv.wasHidden then
            if not tv.visibleSince then tv.visibleSince = now end
            if (now - tv.visibleSince) >= C.WALL_GRACE_TIME then tv.wasHidden = false tv.visibleSince = nil return true end
            return false
        end
        return true
    else tv.wasHidden = true tv.visibleSince = nil return false end
end

local function isVisibleForShot(o, t, c, p)
    local h = classifyPathHit(o, t, c)
    if h == "innocent" then if p then local tv = TargetVisibility[p] if tv then tv.wasHidden = true tv.visibleSince = nil end end return false end
    if not AimbotSettings.WallCheck then return true end
    if h == "wall" then return applyGracePeriod(p, false) end
    return applyGracePeriod(p, true)
end

local function buildBeamPath(f, t, c)
    local w = { f } local cur = f local iter = 0
    while iter < 14 do
        iter = iter + 1 local diff = t - cur local dist = diff.Magnitude if dist < 1 then break end
        local params = RaycastParams.new() params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = { workspace.CurrentCamera } if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
        params.FilterDescendantsInstances = ignore params.IgnoreWater = true
        local r = workspace:Raycast(cur, diff, params)
        if not r then table.insert(w, t) break end
        if c and (r.Instance:IsDescendantOf(c) or r.Instance == c) then table.insert(w, t) break end
        local hp = getCharacterFromPart(r.Instance)
        if hp and hp ~= LocalPlayer and getMM2Role(hp) == "Murderer" then table.insert(w, t) break end
        local hitPos = r.Position local normal = r.Normal local travel = hitPos - cur
        local travelMag = travel.Magnitude if travelMag < 0.1 then table.insert(w, t) break end
        local perp = normal:Cross(Vector3.yAxis) if perp.Magnitude < 0.01 then perp = normal:Cross(Vector3.xAxis) end
        perp = perp.Unit
        local a, b = hitPos + perp * 3, hitPos - perp * 3
        local chosen = (a - t).Magnitude < (b - t).Magnitude and (a + travel.Unit * 0.5) or (b + travel.Unit * 0.5)
        local newP = chosen if (newP - cur).Magnitude < 0.5 then newP = cur + travel.Unit * 1 end
        table.insert(w, newP) cur = newP
    end
    if (w[#w] - t).Magnitude > 1 then table.insert(w, t) end
    return w
end

local function getGunRaycastOrigin()
    local c = LocalPlayer.Character if not c then return nil end
    local h = c:FindFirstChild("HumanoidRootPart") if not h then return nil end
    local a = h:FindFirstChild("GunRaycastAttachment") or waitForGunAttachment(0.5)
    if a and a:IsA("Attachment") then return a.WorldCFrame end
    local hand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
    if hand then return hand.CFrame end
    return h.CFrame
end

local function getWallbangOrigin(c, t)
    local p = t or (c and (c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")))
    if not p then return nil end
    local pos = p.Position local h = getHRP() local f = h and h.Position or pos
    local d = pos - f if d.Magnitude < 0.1 then d = Vector3.new(0, 0, -1) else d = d.Unit end
    return CFrame.new(pos - d * 2.2 + Vector3.new(0, 0.35, 0))
end

local function pathBlockedTo(c, t)
    local o = getGunRaycastOrigin() if not o or not t then return false end
    local h = classifyPathHit(o.Position, t.Position, c)
    return h == "wall" or h == "innocent"
end

local function fireGunShootRemote(g, o, t)
    if not g or not o or not t then return false end
    local s = g:FindFirstChild("Shoot") or g:FindFirstChild("Shoot", true)
    if not s then return false end
    if s:IsA("RemoteEvent") then
        local ok = pcall(function() s:FireServer(o, t) end) if ok then pcall(function() s:FireServer(o, t) end) return true end return false
    end
    if s:IsA("BindableEvent") then
        local ok = pcall(function() s:Fire(o, t) end) if ok then return true end
        if type(firesignal) == "function" then pcall(function() firesignal(s.Event, o, t) end) return true end
        return false
    end
    return fireGunChannels(g, o, t)
end

local function buildTargetCF(p, t)
    if t then local pr = predictAim(t) if pr then return pr end return CFrame.new(t.Position) end
    local pos = getPredictedPosition(p, C.YARHM_SHOOT_OFFSET)
    if pos then return CFrame.new(pos) end
    local h = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if h then return CFrame.new(h.Position) end
    return nil
end

local function prepareGun()
    local c = LocalPlayer.Character if not c then return nil end
    local g, how = ensureGunReady() if not g then return nil end
    if g.Parent ~= c then pcall(function() g.Parent = c end) task.wait(0.08) if g.Parent ~= c then return nil end end
    return g
end

local function shootAt(p, t, wb)
    if not p or not p.Character then return false end
    local g = prepareGun() if not g then return false end
    local tCF = buildTargetCF(p, t) if not tCF then return false end
    local oCF
    if wb or pathBlockedTo(p.Character, t or p.Character:FindFirstChild("HumanoidRootPart")) then oCF = getWallbangOrigin(p.Character, t) end
    if not oCF then oCF = getGunRaycastOrigin() end
    if not oCF then return false end
    return fireGunShootRemote(g, oCF, tCF)
end

local function yarhmFireAt(p, t) return shootAt(p, t, not AimbotSettings.WallCheck) end
local function mobileForceShoot()
    local m = getMurdererCached() if not isTargetSafe(m) then return false end
    local t = getMM2TargetPart(m.Character)
    local ok = shootAt(m, t, true)
    if ok then pcall(function() getgenv().HH_UI.Notify("Shot", 1.5) end) end
    return ok
end

local function clearBeamPool(pool)
    for _, s in ipairs(pool.segments) do if s.beam then s.beam:Destroy() end if s.att0 then s.att0:Destroy() end if s.att1 then s.att1:Destroy() end if s.startPart then s.startPart:Destroy() end if s.endPart then s.endPart:Destroy() end end
    pool.segments = {}
end

local function createBeamSegment()
    local sp = Instance.new("Part") sp.Size = Vector3.new(0.1, 0.1, 0.1) sp.Transparency = 1 sp.Anchored = true sp.CanCollide = false sp.Parent = workspace
    local ep = Instance.new("Part") ep.Size = Vector3.new(0.1, 0.1, 0.1) ep.Transparency = 1 ep.Anchored = true ep.CanCollide = false ep.Parent = workspace
    local a0 = Instance.new("Attachment") a0.Parent = sp
    local a1 = Instance.new("Attachment") a1.Parent = ep
    local b = Instance.new("Beam") b.Attachment0 = a0 b.Attachment1 = a1 b.FaceCamera = true b.Width0 = 0.15 b.Width1 = 0.15 b.Color = ColorSequence.new(BEAM.CLEAR) b.Transparency = NumberSequence.new(0.2) b.LightEmission = 1 b.Parent = sp
    return { beam = b, att0 = a0, att1 = a1, startPart = sp, endPart = ep }
end

local function ensureSegments(pool, count)
    while #pool.segments < count do table.insert(pool.segments, createBeamSegment()) end
    while #pool.segments > count do local s = table.remove(pool.segments) if s.beam then s.beam:Destroy() end if s.att0 then s.att0:Destroy() end if s.att1 then s.att1:Destroy() end if s.startPart then s.startPart:Destroy() end if s.endPart then s.endPart:Destroy() end end
end

local function renderBeamPath(pool, w, color)
    local n = #w - 1 if n < 1 then ensureSegments(pool, 0) return end
    ensureSegments(pool, n)
    for i = 1, n do
        local s = pool.segments[i]
        s.startPart.CFrame = CFrame.new(w[i])
        s.endPart.CFrame = CFrame.new(w[i + 1])
        s.beam.Color = ColorSequence.new(color)
    end
end

local function updateBeam()
    if VisualSettings.Beam then
        local h = getHRP() local m = getMurdererCached()
        if h and isTargetSafe(m) then
            local t = getMM2TargetPart(m.Character)
            if t then
                local w = buildBeamPath(h.Position, t.Position, m.Character)
                local hit = classifyPathHit(h.Position, t.Position, m.Character)
                local c = (hit == "clear" or hit == "target") and BEAM.CLEAR or (hit == "innocent" and BEAM.INNO or BEAM.WALL)
                renderBeamPath(S.beamData, w, c)
                return
            end
        end
        clearBeamPool(S.beamData)
    elseif #S.beamData.segments > 0 then
        clearBeamPool(S.beamData)
    end
end

local function ensureBeamConn()
    dropConn("beam")
    trackConn("beam", RunService.Heartbeat:Connect(function()
        local now = tick() if now - S.beamData.lastTick < 0.08 then return end
        S.beamData.lastTick = now updateBeam()
    end))
end

local function stopBeamIfIdle()
    if VisualSettings.Beam then return end
    dropConn("beam") clearBeamPool(S.beamData)
end

local function startAntiVoid()
    dropConn("antivoid")
    trackConn("antivoid", RunService.Heartbeat:Connect(function()
        if not MiscSettings.AntiVoid then return end
        local h = getHRP() if not h then S.lastSafeCFrame = nil return end
        if h.Position.Y >= AntiVoidSettings.SafeY then S.lastSafeCFrame = h.CFrame
        elseif h.Position.Y <= AntiVoidSettings.Threshold and S.lastSafeCFrame then h.CFrame = S.lastSafeCFrame h.Velocity = Vector3.zero h.RotVelocity = Vector3.zero end
    end))
end

local function stopAntiVoid() dropConn("antivoid") S.lastSafeCFrame = nil end

local function playEmote(name, id)
    local c = LocalPlayer.Character if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid") if not h then return end
    local a = h:FindFirstChildOfClass("Animator") if not a then return end
    if S.currentEmoteTrack then pcall(function() S.currentEmoteTrack:Stop(0.1) end) S.currentEmoteTrack = nil end
    local anim = Instance.new("Animation") anim.AnimationId = "rbxassetid://" .. id
    local ok, tr = pcall(function() return a:LoadAnimation(anim) end)
    if ok and tr then tr.Priority = Enum.AnimationPriority.Action tr.Looped = true tr:Play(0.1) S.currentEmoteTrack = tr end
end

local function playMiniBoxAnimation()
    local c = LocalPlayer.Character if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid") if not h then return end
    local a = h:FindFirstChildOfClass("Animator") if not a then return end
    if S.miniBoxTrack then pcall(function() S.miniBoxTrack:Stop(0.1) end) S.miniBoxTrack = nil end
    local anim = Instance.new("Animation") anim.AnimationId = Cfg.MINI_BOX_ANIM_ID
    local ok, tr = pcall(function() return a:LoadAnimation(anim) end)
    if ok and tr then tr.Priority = Enum.AnimationPriority.Action4 tr.Looped = true tr:Play(0.1) S.miniBoxTrack = tr end
end

local function stopMiniBoxAnimation() if S.miniBoxTrack then pcall(function() S.miniBoxTrack:Stop(0.1) end) S.miniBoxTrack = nil end end

local function playMusic()
    if not MiscSettings.MusicCompanion then return end
    if S.musicSound then S.musicSound:Stop() S.musicSound:Destroy() S.musicSound = nil end
    local sel = Cfg.MUSIC_TRACKS[1]
    for _, t in ipairs(Cfg.MUSIC_TRACKS) do if t.name == MiscSettings.SelectedMusic then sel = t break end end
    S.musicSound = Instance.new("Sound") S.musicSound.SoundId = "rbxassetid://" .. sel.id S.musicSound.Volume = 10 S.musicSound.Looped = true S.musicSound.Parent = game:GetService("SoundService") S.musicSound:Play()
end

local function stopMusic() if S.musicSound then S.musicSound:Stop() S.musicSound:Destroy() S.musicSound = nil end end

local function equipKnife()
    local c = LocalPlayer.Character if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid") if not h then return false end
    for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t.Name:lower():find("knife", 1, true) then return true end end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and t.Name:lower():find("knife", 1, true) then pcall(function() h:EquipTool(t) end) task.wait(0.3) return true end end end
    return false
end

local function getLocalKnife()
    local c = LocalPlayer.Character if not c then return nil end
    for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t.Name:lower():find("knife", 1, true) then return t end end
    return nil
end

local function getTpEvent()
    if S.tpEvent and S.tpEvent.Parent then return S.tpEvent end
    local r = ReplicatedStorage:FindFirstChild("Remotes") if not r then return nil end
    local g = r:FindFirstChild("Gameplay") if not g then return nil end
    S.tpEvent = g:FindFirstChild("TeleportToPart") return S.tpEvent
end

local function fireTeleportToPart(s, d)
    local ev = getTpEvent() if not ev then return false end
    pcall(function() ev:FireServer(s, d) end) pcall(function() ev:FireServer(d, s) end) pcall(function() ev:FireServer(s, d.Position) end) pcall(function() ev:FireServer(s.Name, d) end)
    return true
end

local function teleportToPlayer(p)
    if not p then return false end
    local th = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    local mh = getHRP() if not mh or not th then return false end
    if fireTeleportToPart(mh, th) then task.wait(0.03) local h = getHRP() if h and (h.Position - th.Position).Magnitude > 5 then h.CFrame = th.CFrame end
    else mh.CFrame = th.CFrame end
    return true
end

local function bringGunToPlayer()
    local g = findGunDrop() if not g then return false end
    local h = getHRP() if not h then return false end
    local moved = false if fireTeleportToPart(g, h) then moved = true end
    task.wait(0.03) if g and g.Parent then g.CFrame = h.CFrame g.Velocity = Vector3.zero g.RotVelocity = Vector3.zero moved = true end
    return moved
end

local function clearHighlights(p)
    if ESP.highlights.MM2[p] then ESP.highlights.MM2[p]:Destroy() ESP.highlights.MM2[p] = nil end
    if ESP.highlights.OG[p] then ESP.highlights.OG[p]:Destroy() ESP.highlights.OG[p] = nil end
    if ESP.nameTags[p] then if ESP.nameTags[p].bb and ESP.nameTags[p].bb.Parent then ESP.nameTags[p].bb:Destroy() end ESP.nameTags[p] = nil end
end

local function clearGunESP()
    for _, h in pairs(S.gunESP.highlights) do if h and h.Parent then h:Destroy() end end
    for _, bb in pairs(S.gunESP.billboards) do if bb and bb.Parent then bb:Destroy() end end
    S.gunESP.highlights = {} S.gunESP.billboards = {} S.gunESP.trackedGun = nil
end

local function applyGunESP()
    if not VisualSettings.GunESP then clearGunESP() return end
    local g = findGunDrop() if not g then clearGunESP() return end
    if S.gunESP.trackedGun ~= g then clearGunESP() S.gunESP.trackedGun = g end
    if not S.gunESP.highlights[g] then
        local h = Instance.new("Highlight") h.FillColor = ESP_COLORS.Gun h.FillTransparency = 0.3 h.OutlineTransparency = 1 h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop h.Parent = g S.gunESP.highlights[g] = h
    end
    if not S.gunESP.billboards[g] then
        local bb = Instance.new("BillboardGui") bb.Size = UDim2.new(0, 160, 0, 24) bb.StudsOffset = Vector3.new(0, 3, 0) bb.AlwaysOnTop = true bb.Adornee = g bb.Parent = g
        local l = Instance.new("TextLabel") l.Size = UDim2.new(1, 0, 1, 0) l.BackgroundTransparency = 1 l.Text = "Gun Dropped here!" l.TextColor3 = ESP_COLORS.Gun l.FontFace = Font.fromEnum(Enum.Font.Code) l.TextSize = 13 l.TextStrokeTransparency = 1 l.Parent = bb
        S.gunESP.billboards[g] = bb
    end
end

local function applyESP(p)
    if p == LocalPlayer then return end
    local c = p.Character if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid") if not h or h.Health <= 0 then clearHighlights(p) return end
    if ESP.active.MM2 then
        local role = getMM2Role(p) local color = ESP_COLORS.MM2[role] or ESP_COLORS.MM2.Innocent
        if not ESP.highlights.MM2[p] then
            local hi = Instance.new("Highlight") hi.FillColor = color hi.FillTransparency = 0.2 hi.OutlineTransparency = 1 hi.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop hi.Parent = c ESP.highlights.MM2[p] = hi
        else ESP.highlights.MM2[p].FillColor = color end
    elseif ESP.highlights.MM2[p] then ESP.highlights.MM2[p]:Destroy() ESP.highlights.MM2[p] = nil end
    if ESP.active.OG then
        if not ESP.highlights.OG[p] then
            local hi = Instance.new("Highlight") hi.FillColor = ESP_COLORS.OG hi.FillTransparency = 0.5 hi.OutlineTransparency = 1 hi.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop hi.Parent = c ESP.highlights.OG[p] = hi
        end
    elseif ESP.highlights.OG[p] then ESP.highlights.OG[p]:Destroy() ESP.highlights.OG[p] = nil end
    if ESP.active.NameTag then
        if not ESP.nameTags[p] then
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bb = Instance.new("BillboardGui") bb.Size = UDim2.new(0, 140, 0, 32) bb.StudsOffset = Vector3.new(0, 3.5, 0) bb.AlwaysOnTop = true bb.Adornee = hrp bb.Parent = hrp
                local l = Instance.new("TextLabel") l.Size = UDim2.new(1, 0, 1, 1) l.BackgroundTransparency = 1 l.TextColor3 = Color3.new(1, 1, 1) l.FontFace = Font.fromEnum(Enum.Font.Code) l.TextSize = 13 l.TextStrokeTransparency = 1 l.Parent = bb
                ESP.nameTags[p] = { bb = bb, lbl = l }
            end
        end
    elseif ESP.nameTags[p] then ESP.nameTags[p].bb:Destroy() ESP.nameTags[p] = nil end
end

local function refreshAllESP()
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then if not p.Character then clearHighlights(p) else applyESP(p) end end end
    applyGunESP()
end

local function startNameTagUpdater()
    dropConn("nametag")
    trackConn("nametag", RunService.Heartbeat:Connect(function()
        if not ESP.active.NameTag then return end
        local mh = getHRP() if not mh then return end
        for p, d in pairs(ESP.nameTags) do
            if p.Character and d.lbl then
                local th = p.Character:FindFirstChild("HumanoidRootPart") local role = getMM2Role(p)
                local label, color = p.DisplayName, Color3.new(1, 1, 1)
                if role == "Murderer" then label = "Murderer · " .. p.DisplayName color = ESP_COLORS.MM2.Murderer
                elseif role == "Sheriff" then label = "Sheriff · " .. p.DisplayName color = ESP_COLORS.MM2.Sheriff
                elseif role == "Hero" then label = "Hero · " .. p.DisplayName color = ESP_COLORS.MM2.Hero end
                if th then d.lbl.Text = label .. "\n" .. math.floor((mh.Position - th.Position).Magnitude) .. "m" else d.lbl.Text = label end
                d.lbl.TextColor3 = color
            end
        end
    end))
end

local function stopNameTagUpdater() dropConn("nametag") end

local function getFadeEvent()
    local r = ReplicatedStorage:FindFirstChild("Remotes") if not r then return nil end
    local g = r:FindFirstChild("Gameplay") if not g then return nil end
    return g:FindFirstChild("Fade")
end

local function findGunHolder()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local c, b = p.Character, p:FindFirstChildOfClass("Backpack")
            if (c and c:FindFirstChild("Gun")) or (b and b:FindFirstChild("Gun")) then return p end
        end
    end
    return nil
end

local function isSheriffDead()
    for u, i in pairs(S.roleCache) do if i.Role == "Sheriff" and i.Dead then return true, u end end
    return false, nil
end

local function clearHeroFlags() for u, i in pairs(S.roleCache) do if i.Role == "Hero" then i.Role = "Innocent" i.IsHero = false end end end

local function stopHeroWatcher()
    S.heroWatcher.active = false
    if S.heroWatcher.thread then pcall(task.cancel, S.heroWatcher.thread) S.heroWatcher.thread = nil end
end

local function startHeroWatcher()
    if S.heroWatcher.active then return end
    S.heroWatcher.active = true
    S.heroWatcher.thread = trackThread(task.spawn(function()
        while S.heroWatcher.active do
            task.wait(0.4) if not S.heroWatcher.active then break end
            local dead, name = isSheriffDead()
            if dead then
                local h = findGunHolder()
                if h then
                    local info = S.roleCache[h.Name]
                    if info then
                        if info.Role == "Sheriff" then task.wait(0.3)
                        else
                            info.Role = "Hero" info.IsHero = true S.heroWatcher.originalSheriffName = name
                            if h.Character then clearHighlights(h) applyESP(h) end
                            S.heroWatcher.active = false break
                        end
                    else
                        S.roleCache[h.Name] = { UserId = h.UserId, Role = "Hero", Dead = false, IsHero = true }
                        if h.Character then clearHighlights(h) applyESP(h) end
                        S.heroWatcher.originalSheriffName = name S.heroWatcher.active = false break
                    end
                end
            end
        end
        S.heroWatcher.thread = nil
    end))
end

local function onRoundBegin() clearHeroFlags() stopHeroWatcher() task.delay(1.5, function() if S.roundActive then startHeroWatcher() end end) end
local function onRoundEnd() stopHeroWatcher() S.heroWatcher.originalSheriffName = nil clearHeroFlags() clearGunESP() clearBeamPool(S.beamData) end

local function updateRoleCache(data)
    if type(data) ~= "table" then return end
    for u, i in pairs(data) do
        if type(i) == "table" and i.Role then
            S.roleCache[u] = { UserId = i.UserId, Role = i.Role, Dead = i.Dead or false, Perk = i.Perk, Knife = i.Knife, Gun = i.Gun, XP = i.XP, Killed = i.Killed or false }
            if i.Role == "Sheriff" and i.Dead then task.defer(function() if S.heroWatcher.active == false then startHeroWatcher() end end) end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then if p.Character then clearHighlights(p) applyESP(p) else clearHighlights(p) end end end
    if ConnectionRegistry["beam"] then S.beamData.lastTick = 0 updateBeam() end
end

local function hookFadeEvent()
    if S.fadeConn then S.fadeConn:Disconnect() S.fadeConn = nil end
    local ev = getFadeEvent() if not ev then return end
    S.fadeConn = ev.OnClientEvent:Connect(function(...) S.fadeReceivedAt = tick() updateRoleCache(...) end)
end

local function applyKorblox()
    local c = LocalPlayer.Character if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid") if not h then return end
    local function build(ru)
        local e = c:FindFirstChild("HH_KorbloxMesh") if e then e:Destroy() end
        local p = Instance.new("Part") p.Name = "HH_KorbloxMesh" p.Size = Vector3.new(1, 2, 1) p.CanCollide = false p.Massless = true p.Anchored = false p.Color = Color3.new(1, 1, 1) p.CFrame = ru.CFrame p.Parent = c
        local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.FileMesh m.MeshId = "rbxassetid://902942096" m.TextureId = "rbxassetid://902843398" m.Scale = Vector3.new(1, 1, 1) m.Parent = p
        local w = Instance.new("WeldConstraint") w.Part0 = p w.Part1 = ru w.Parent = p S.korbloxPart = p
    end
    if h.RigType == Enum.HumanoidRigType.R15 then
        local rf, rl, ru = c:FindFirstChild("RightFoot"), c:FindFirstChild("RightLowerLeg"), c:FindFirstChild("RightUpperLeg")
        if ru and rl and rf then rf.Transparency = 1 rl.Transparency = 1 ru.Transparency = 1 build(ru) end
    else
        local rl = c:FindFirstChild("Right Leg")
        if rl then
            for _, v in ipairs(c:GetChildren()) do if v:IsA("CharacterMesh") and v.BodyPart == Enum.BodyPart.RightLeg then v:Destroy() end end
            local m = rl:FindFirstChildOfClass("SpecialMesh") if not m then m = Instance.new("SpecialMesh") m.Parent = rl end
            rl.Color = Color3.fromRGB(64, 64, 64) rl.Transparency = 0 m.MeshType = Enum.MeshType.FileMesh m.MeshId = "rbxassetid://101851696" m.TextureId = "rbxassetid://101851254" m.Scale = Vector3.new(1, 1, 1)
        end
    end
end

local function removeKorblox()
    local c = LocalPlayer.Character if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid") if not h then return end
    if S.korbloxPart and S.korbloxPart.Parent then S.korbloxPart:Destroy() end S.korbloxPart = nil
    if h.RigType == Enum.HumanoidRigType.R15 then
        local rf, rl, ru = c:FindFirstChild("RightFoot"), c:FindFirstChild("RightLowerLeg"), c:FindFirstChild("RightUpperLeg")
        if rf then rf.Transparency = 0 end if rl then rl.Transparency = 0 end
        if ru then ru.Transparency = 0 local m = ru:FindFirstChild("HH_KorbloxMesh") if m then m:Destroy() end end
    else
        local rl = c:FindFirstChild("Right Leg")
        if rl then local m = rl:FindFirstChildOfClass("SpecialMesh") if m then m:Destroy() end rl.Color = Color3.fromRGB(163, 162, 165) end
    end
end

local function applyAnimPack()
    local c = LocalPlayer.Character if not c then return end
    local a = c:FindFirstChild("Animate") if not a then return end
    local function replace(f, id) local fo = a:FindFirstChild(f) if not fo then return end for _, ch in ipairs(fo:GetChildren()) do if ch:IsA("Animation") then ch.AnimationId = id end end end
    replace("idle", Cfg.CUSTOM_ANIMS.idle.id) replace("walk", Cfg.CUSTOM_ANIMS.walk.id) replace("run", Cfg.CUSTOM_ANIMS.run.id) replace("fall", Cfg.CUSTOM_ANIMS.fall.id) replace("climb", Cfg.CUSTOM_ANIMS.climb.id) replace("jump", Cfg.CUSTOM_ANIMS.jump.id)
    a.Disabled = true task.wait(0.05) a.Disabled = false
    local h = c:FindFirstChildOfClass("Humanoid") if not h then return end
    local an = h:FindFirstChildOfClass("Animator") if not an then return end
    local function getPrio(id)
        if not id then return nil end
        if id == Cfg.CUSTOM_ANIMS.idle.id then return Cfg.CUSTOM_ANIMS.idle.priority end
        if id == Cfg.CUSTOM_ANIMS.walk.id then return Cfg.CUSTOM_ANIMS.walk.priority end
        if id == Cfg.CUSTOM_ANIMS.run.id then return Cfg.CUSTOM_ANIMS.run.priority end
        if id == Cfg.CUSTOM_ANIMS.fall.id then return Cfg.CUSTOM_ANIMS.fall.priority end
        if id == Cfg.CUSTOM_ANIMS.climb.id then return Cfg.CUSTOM_ANIMS.climb.priority end
        if id == Cfg.CUSTOM_ANIMS.jump.id then return Cfg.CUSTOM_ANIMS.jump.priority end
        return nil
    end
    task.wait(0.5)
    for _, t in ipairs(an:GetPlayingAnimationTracks()) do local p = getPrio(t.Animation and t.Animation.AnimationId) if p then pcall(function() t.Priority = p end) end end
    if S.animPriorityConn then S.animPriorityConn:Disconnect() S.animPriorityConn = nil end
    S.animPriorityConn = an.AnimationPlayed:Connect(function(t) local p = getPrio(t.Animation and t.Animation.AnimationId) if p then pcall(function() t.Priority = p end) end end)
end

local function getCoinContainer()
    local maps = { "ResearchFacility", "House2", "Mansion2", "Hotel", "MilBase", "Bank2", "BioLab", "Factory", "Workplace", "PoliceStation", "Office3", "Hospital3", "Town", "Town2", "Mansion", "House" }
    for _, m in ipairs(maps) do local ma = workspace:FindFirstChild(m) if ma then local c = ma:FindFirstChild("CoinContainer", true) if c then return c end end end
    local c = workspace:FindFirstChild("CoinContainer", true) if c then return c end
    for _, ch in ipairs(workspace:GetChildren()) do if ch:IsA("Model") and (ch.Name:find("Map") or ch.Name:find("map")) then local c2 = ch:FindFirstChild("CoinContainer", true) if c2 then return c2 end end end
    return nil
end

local FAST_FLAGS = { ["DFIntTaskSchedulerTargetFps"] = "9999", ["FFlagTaskSchedulerLimitTargetFpsTo2402"] = "false", ["DFIntRenderThrottleMaxFps"] = "9999", ["FFlagDebugDisableShadows"] = "true", ["FIntRenderShadowIntensity"] = "0", ["FFlagAdServiceEnabled"] = "false", ["DFIntMinimumFrameTime"] = "1", ["FFlagDisablePostFx"] = "true", ["FFlagRenderCheckThreading"] = "true", ["DFIntConnectionMTimesBeforeChain"] = "1", ["DFIntSchedulerWaitTime"] = "1" }

local function applyFastFlags() if type(setfflag) ~= "function" then return end for f, v in pairs(FAST_FLAGS) do pcall(setfflag, f, v) end end

local function enableUltraOptimization()
    if S.ultraOptActive then return end S.ultraOptActive = true applyFastFlags()
    local l = game:GetService("Lighting") S.savedLighting = { GlobalShadows = l.GlobalShadows, FogEnd = l.FogEnd } l.GlobalShadows = false l.FogEnd = 5000
    S.savedLightingEffects = {}
    for _, v in ipairs(l:GetChildren()) do if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Sky") then S.savedLightingEffects[v] = v.Enabled pcall(function() v.Enabled = false end) end end
    pcall(function() workspace.Terrain.WaterWaveSize = 0 workspace.Terrain.WaterWaveSpeed = 0 workspace.Terrain.WaterReflectance = 0 workspace.Terrain.WaterTransparency = 1 end)
end

local function disableUltraOptimization()
    if not S.ultraOptActive then return end S.ultraOptActive = false
    if S.savedLighting then local l = game:GetService("Lighting") for k, v in pairs(S.savedLighting) do pcall(function() l[k] = v end) end S.savedLighting = nil end
    if S.savedLightingEffects then for o, e in pairs(S.savedLightingEffects) do if o and o.Parent then pcall(function() o.Enabled = e end) end end S.savedLightingEffects = nil end
end

local function getHelperRefs(n)
    if n == "AntiAFK" then return nil, MiscSettings, "AntiAFK" end
    if n == "AntiFling" then return nil, MovementSettings, "AntiFling" end
    if n == "AntiVoid" then return nil, MiscSettings, "AntiVoid" end
    if n == "Noclip" then return nil, MovementSettings, "Noclip" end
    return nil, nil, nil
end

local function ensureHelper(n)
    local _, t, k = getHelperRefs(n) if not t or not k then return end
    S.savedFarmStates = S.savedFarmStates or {} if S.savedFarmStates[n] == nil then S.savedFarmStates[n] = { orig = t[k], forced = false } end
    local st = S.savedFarmStates[n] if not t[k] then t[k] = true st.forced = true end
end

local function restoreHelper(n)
    local _, t, k = getHelperRefs(n) if not t or not k then return end
    S.savedFarmStates = S.savedFarmStates or {} local st = S.savedFarmStates[n]
    if not st or not st.forced then S.savedFarmStates[n] = nil return end
    if t[k] ~= st.orig then t[k] = st.orig end
    S.savedFarmStates[n] = nil
end

local function ensureFarmHelpers() ensureHelper("AntiAFK") ensureHelper("AntiFling") ensureHelper("AntiVoid") end
local function restoreFarmHelpers() restoreHelper("AntiAFK") restoreHelper("AntiFling") restoreHelper("AntiVoid") end
local function ensureFarmNoclip() if not S.roundActive then return end ensureHelper("Noclip") end
local function restoreFarmNoclip() restoreHelper("Noclip") end

local function getAllCoins()
    local c = getCoinContainer() if not c then return {} end
    local t = {}
    for _, ch in ipairs(c:GetChildren()) do
        local p
        if ch:IsA("BasePart") then p = ch elseif ch:IsA("Model") then p = ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart") end
        if p and p:IsA("BasePart") then table.insert(t, p) end
    end
    return t
end

local function attachFarmGyro()
    local h = getHRP() if not h then return end
    if S.coinGyro then S.coinGyro:Destroy() end
    S.coinGyro = Instance.new("BodyGyro") S.coinGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6) S.coinGyro.P = 1e5 S.coinGyro.D = 500 S.coinGyro.CFrame = CFrame.new(h.Position) S.coinGyro.Parent = h S.lastGyroUpdate = tick()
end

local function ensureFarmBodyMovers()
    local h = getHRP() if not h then return end
    local hu = getHumanoid() if hu and not hu.PlatformStand then hu.PlatformStand = true end
    if not S.farmWalkBV or not S.farmWalkBV.Parent then S.farmWalkBV = Instance.new("BodyVelocity") S.farmWalkBV.MaxForce = Vector3.new(1e5, 1e5, 1e5) S.farmWalkBV.P = 500 S.farmWalkBV.Parent = h end
end

local function stopFarmBodyMovers()
    if S.farmWalkBV then S.farmWalkBV.Velocity = Vector3.zero S.farmWalkBV:Destroy() S.farmWalkBV = nil end
    local h = getHumanoid() if h then h.PlatformStand = false end
    local hr = getHRP() if hr and hr.Position.Y < -50 then hr.CFrame = hr.CFrame + Vector3.new(0, 60, 0) end
end

local function stopCoinCollector()
    S.coinCollecting = false
    if S.coinConnection then pcall(function() S.coinConnection:Disconnect() end) S.coinConnection = nil end
    dropConn("farm")
    if S.coinGyro then pcall(function() S.coinGyro:Destroy() end) S.coinGyro = nil end
    stopFarmBodyMovers() disableUltraOptimization()
    S.farmTargetCoin = nil S.farmTouchedCoins = {} S.farmBlacklist = {} S.farmLastCollectAt = 0 S.farmStartedAt = 0 S.farmLastFallbackAt = 0 S.farmStuckPos = nil S.farmStuckAt = 0 S.farmUnstickAttempts = 0 S.farmLastCollectSpeedAt = 0 S.farmTargetStartedAt = 0 S.lastGyroUpdate = 0
    if S.coinStatusSetter then S.coinStatusSetter("Idle") end
    stopMiniBoxAnimation()
    local h = getHRP() if h then h.Velocity = Vector3.zero h.RotVelocity = Vector3.zero end
end

local function startCoinCollector()
    if S.totalCoins >= C.FARM_GOAL then return end
    if not getCoinContainer() then return end
    if not getHRP() then return end
    if S.coinConnection or S.coinCollecting then stopCoinCollector() end
    S.coinCollecting = true S.farmTargetCoin = nil S.farmTouchedCoins = {} S.farmBlacklist = {} S.farmStartedAt = tick() S.farmLastCollectAt = tick() S.farmLastFallbackAt = tick() S.farmStuckPos = nil S.farmStuckAt = 0 S.farmUnstickAttempts = 0 S.farmLastCollectSpeedAt = 0 S.farmTargetStartedAt = 0
    if S.coinStatusSetter then S.coinStatusSetter(isLocalMurderer() and "Murderer · farming..." or "Searching target...") end
    playMiniBoxAnimation() ensureFarmHelpers() ensureFarmNoclip()
    if FarmSettings.UltraOpt then enableUltraOptimization() end
    attachFarmGyro() ensureFarmBodyMovers()
    S.coinConnection = trackConn("farm", RunService.Heartbeat:Connect(function()
        if not S.coinCollecting then return end
        if not S.roundActive then stopCoinCollector() return end
        if S.totalCoins >= C.FARM_GOAL then
            if S.coinStatusSetter then S.coinStatusSetter("Goal reached") end
            stopCoinCollector()
            if isLocalMurderer() then
                if not S.killAllRunning and tick() - S.roundStartedAt >= C.AUTO_KILL_COOLDOWN then
                    S.killAllRunning = true
                    if S.coinStatusSetter then S.coinStatusSetter("Murderer · killing...") end
                    task.spawn(function()
                        local st = tick()
                        while S.killAllRunning and S.roundActive and tick() - st < 6 do serverKillAllTick() task.wait(0.03) end
                        S.killAllRunning = false
                    end)
                end
            elseif not S.rerolling then
                if not isLocalSheriffOrHero() then
                    S.rerolling = true
                    task.delay(0.5, function() local h = getHumanoid() if h and h.Health > 0 then h.Health = 0 end task.delay(3, function() S.rerolling = false end) end)
                end
            end
            return
        end
        local h = getHRP() if not h then return end
        local now = tick() local myPos = h.Position local coins = getAllCoins()
        if S.coinGyro and S.coinGyro.Parent then if now - S.lastGyroUpdate > 0.15 then S.coinGyro.CFrame = CFrame.new(myPos) S.lastGyroUpdate = now end
        elseif not S.coinGyro then attachFarmGyro() end
        if not S.farmWalkBV or not S.farmWalkBV.Parent then ensureFarmBodyMovers() if not S.farmWalkBV then return end end
        for _, coin in ipairs(coins) do
            if coin and coin.Parent and (coin.Position - myPos).Magnitude <= C.FARM_TOUCH_RADIUS then
                local lt = S.farmTouchedCoins[coin]
                if not lt or now - lt > C.FARM_TOUCH_COOLDOWN then
                    S.farmTouchedCoins[coin] = now
                    task.spawn(function() pcall(firetouchinterest, h, coin, 0) task.wait(0.02) if coin and coin.Parent then pcall(firetouchinterest, h, coin, 1) end end)
                end
            end
        end
        local tc = 0 for c, t in pairs(S.farmTouchedCoins) do if now - t > 5 or not c or not c.Parent then S.farmTouchedCoins[c] = nil else tc = tc + 1 end end
        if tc > 40 then S.farmTouchedCoins = {} end
        local bc = 0 for c, t in pairs(S.farmBlacklist) do if now - t > C.FARM_BLACKLIST_TIME + 2 or not c or not c.Parent then S.farmBlacklist[c] = nil else bc = bc + 1 end end
        if bc > 30 then S.farmBlacklist = {} end
        local localM = isLocalMurderer() local m = getMurdererCached() local mh = (not localM) and m and m.Character and m.Character:FindFirstChild("HumanoidRootPart")
        local distM = mh and (myPos - mh.Position).Magnitude or math.huge
        local antiF = (now - S.fadeReceivedAt) < C.ANTI_FOCUS_DURATION local effD = antiF and C.ANTI_FOCUS_RADIUS or C.FARM_DANGER_DIST
        if mh and distM < effD then
            local away = Vector3.new(myPos.X - mh.Position.X, 0, myPos.Z - mh.Position.Z) if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end away = away.Unit
            S.farmWalkBV.Velocity = away * getFarmSpeed() * (antiF and 2.5 or 2) + Vector3.new(0, 4, 0)
            if S.coinStatusSetter then S.coinStatusSetter(antiF and "ANTI-FOCUS · evading" or "DANGER · evading") end
            return
        end
        if S.farmTargetCoin and (now - S.farmTargetStartedAt) > C.FARM_TARGET_TIMEOUT then
            blacklistCoin(S.farmTargetCoin) S.farmTargetCoin = nil S.farmTargetStartedAt = 0 S.farmUnstickAttempts = 0
            if S.coinStatusSetter then S.coinStatusSetter("Target timeout") end
        end
        if not S.farmTargetCoin or not S.farmTargetCoin.Parent or not isCoinValid(S.farmTargetCoin) then
            S.farmTargetCoin = nil local cands = {}
            for _, coin in ipairs(coins) do if isCoinValid(coin) and not isCoinBlacklisted(coin) then table.insert(cands, { coin = coin, dist = (coin.Position - myPos).Magnitude }) end end
            table.sort(cands, function(a, b) return a.dist < b.dist end)
            local best = cands[1] and cands[1].coin or nil
            if not best then
                local bd = math.huge
                for _, coin in ipairs(coins) do if isCoinValid(coin) then local d = (coin.Position - myPos).Magnitude if d < bd then bd = d best = coin end end end
            elseif cands[2] and cands[1].dist < 4 and cands[2].dist < 18 then best = cands[2].coin end
            S.farmTargetCoin = best S.farmTargetStartedAt = tick() S.farmStuckPos = nil S.farmStuckAt = 0 S.farmUnstickAttempts = 0
        end
        local t = S.farmTargetCoin
        if not t then S.farmWalkBV.Velocity = Vector3.zero if S.coinStatusSetter then S.coinStatusSetter("No valid coins") end return end
        local distT = (t.Position - myPos).Magnitude local tp = t.Position + Vector3.new(0, C.FARM_GROUND_OFFSET, 0) local delta = tp - myPos local horiz = Vector3.new(delta.X, 0, delta.Z) local hd = horiz.Magnitude
        if distT < C.FARM_ARRIVE_DIST then
            S.farmWalkBV.Velocity = Vector3.new(delta.X, delta.Y, delta.Z) * 4 S.farmStuckPos = myPos S.farmStuckAt = now
        else
            local bs = getFarmSpeed() local jc = (now - S.farmLastCollectSpeedAt) < C.FARM_COLLECT_SPEED_RESET_TIME
            if not jc and distT < C.FARM_NEAR_RADIUS then bs = bs * getNearBoost() end
            if hd > 0.5 then
                S.farmWalkBV.Velocity = horiz.Unit * math.min(bs, math.max(hd * 4, bs * 0.75)) + Vector3.new(0, math.clamp(delta.Y * 2, -8, 8), 0)
            else
                S.farmWalkBV.Velocity = Vector3.new(0, math.clamp(delta.Y * 2, -8, 8), 0)
            end
        end
        if distT < C.FARM_TOUCH_RADIUS then S.farmStuckPos = myPos S.farmStuckAt = now
        elseif not S.farmStuckPos then S.farmStuckPos = myPos S.farmStuckAt = now
        elseif (myPos - S.farmStuckPos).Magnitude > C.FARM_STUCK_DIST then S.farmStuckPos = myPos S.farmStuckAt = now S.farmUnstickAttempts = 0
        elseif now - S.farmStuckAt > C.FARM_STUCK_TIME then
            S.farmUnstickAttempts = (S.farmUnstickAttempts or 0) + 1
            local angle = math.rad((S.farmUnstickAttempts * 120) % 360) local side = Vector3.new(math.cos(angle), 0, math.sin(angle))
            if S.farmWalkBV then S.farmWalkBV.Velocity = side * getFarmSpeed() * 1.15 + Vector3.new(0, 6, 0) end
            S.farmStuckPos = myPos S.farmStuckAt = now
            if S.farmUnstickAttempts >= C.FARM_UNSTICK_MAX then
                blacklistCoin(S.farmTargetCoin) S.farmTargetCoin = nil S.farmUnstickAttempts = 0 S.farmTargetStartedAt = 0
                if S.coinStatusSetter then S.coinStatusSetter("Stuck · next") end
            else if S.coinStatusSetter then S.coinStatusSetter("Unsticking...") end end
        end
        local tsc = now - math.max(S.farmStartedAt, S.lastCollectTime)
        if tsc > C.FARM_FALLBACK_TIMEOUT and now - S.farmLastFallbackAt > C.FARM_FALLBACK_COOLDOWN and (localM or not mh or distM > 30) then
            S.farmLastFallbackAt = now
            local tc, bd = nil, math.huge
            for _, c in ipairs(coins) do
                if isCoinValid(c) and not isCoinBlacklisted(c) then
                    if localM or not mh or (c.Position - mh.Position).Magnitude > 30 then
                        local d = (c.Position - h.Position).Magnitude if d > 12 and d < bd then bd = d tc = c end
                    end
                end
            end
            if tc and bd > 35 then
                S.farmTargetCoin = tc S.farmTargetStartedAt = tick()
                fireTeleportToPart(h, tc) S.farmStuckPos = nil S.farmStuckAt = 0
                if S.coinStatusSetter then S.coinStatusSetter("Fallback TP") end
            end
        end
        if S.coinStatusSetter then S.coinStatusSetter((localM and "Murderer · " or "") .. "Moving · " .. #coins .. " coins") end
    end))
end

local function shouldWaitForCoins() return FarmSettings.AutoFarm and S.roundActive and S.totalCoins < C.FARM_GOAL end
local function getFlingTargetByName(n) if not n then return nil end for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and (p.Name == n or p.DisplayName == n) then return p end end return nil end

local function yarhmFling(target)
    if not target or not target.Character or target == LocalPlayer then return false end
    local char, hum, root = LocalPlayer.Character, LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"), LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid").RootPart
    if not (char and hum and root) then return false end
    local tChar = target.Character local tHum = tChar:FindFirstChildOfClass("Humanoid") local tRoot = tHum and tHum.RootPart local tHead = tChar:FindFirstChild("Head") local tAcc = tChar:FindFirstChildOfClass("Accessory") local tHandle = tAcc and tAcc:FindFirstChild("Handle")
    if not tChar:FindFirstChildWhichIsA("BasePart") then return false end
    local oldF, oldP = workspace.FallenPartsDestroyHeight, root.CFrame workspace.FallenPartsDestroyHeight = 0/0
    local oldCam = workspace.CurrentCamera.CameraSubject
    if tHead then workspace.CurrentCamera.CameraSubject = tHead elseif tHandle then workspace.CurrentCamera.CameraSubject = tHandle elseif tHum then workspace.CurrentCamera.CameraSubject = tHum end
    local function FPos(bp, po, ao)
        local ncf = CFrame.new(bp.Position) * po * ao root.CFrame = ncf pcall(function() char:PivotTo(ncf) end) root.Velocity = Vector3.new(9e7, 9e8, 9e7) root.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end
    local function SF(bp)
        local dl, ang = tick() + 2, 0
        repeat
            if not (root and tHum) then break end
            if bp.Velocity.Magnitude < 50 then
                ang = ang + 100
                FPos(bp, CFrame.new(0, 1.5, 0) + tHum.MoveDirection * bp.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(ang), 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, -1.5, 0) + tHum.MoveDirection * bp.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(ang), 0, 0)) task.wait()
                FPos(bp, CFrame.new(2.25, 1.5, -2.25) + tHum.MoveDirection * bp.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(ang), 0, 0)) task.wait()
                FPos(bp, CFrame.new(-2.25, -1.5, 2.25) + tHum.MoveDirection * bp.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(ang), 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, 1.5, 0) + tHum.MoveDirection, CFrame.Angles(math.rad(ang), 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, -1.5, 0) + tHum.MoveDirection, CFrame.Angles(math.rad(ang), 0, 0)) task.wait()
            else
                FPos(bp, CFrame.new(0, 1.5, tHum.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, -1.5, -tHum.WalkSpeed), CFrame.Angles(0, 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, 1.5, tHum.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, 1.5, tRoot.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, -1.5, -tRoot.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, 1.5, tRoot.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(-90), 0, 0)) task.wait()
                FPos(bp, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)) task.wait()
            end
        until bp.Velocity.Magnitude > 500 or bp.Parent ~= tChar or target.Parent ~= Players or target.Character ~= tChar or tHum.Sit or hum.Health <= 0 or tick() > dl
    end
    local bv = Instance.new("BodyVelocity") bv.Parent = root bv.Velocity = Vector3.new(9e8, 9e8, 9e8) bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    local base = (tRoot and tHead and (tRoot.CFrame.Position - tHead.CFrame.Position).Magnitude > 5) and tHead or (tRoot or tHead or tHandle)
    local succ = false
    if base then SF(base) succ = true end
    bv:Destroy() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) workspace.CurrentCamera.CameraSubject = oldCam
    local rs = tick()
    repeat
        local h = getHRP() if h then h.CFrame = oldP * CFrame.new(0, 0.5, 0) h.Velocity = Vector3.zero h.RotVelocity = Vector3.zero end
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end) end task.wait()
    until not getHRP() or (getHRP().Position - oldP.Position).Magnitude < 25 or tick() > rs + 3
    workspace.FallenPartsDestroyHeight = oldF
    return succ
end

local function startFlingTarget(t)
    if not t or t == LocalPlayer or S.flingTargetRunning or not getHRP() then return end
    S.flingTargetRunning = true
    S.flingTargetThread = task.spawn(function() local ok = yarhmFling(t) S.flingTargetRunning = false S.flingTargetThread = nil end)
end

local function attachFlyBodyMovers()
    local h, hu = getHRP(), getHumanoid() if not h or not hu then return end
    hu.PlatformStand = true
    if S.flyBV then S.flyBV:Destroy() end if S.flyBG then S.flyBG:Destroy() end
    S.flyBV = Instance.new("BodyVelocity") S.flyBV.Velocity = Vector3.zero S.flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5) S.flyBV.Parent = h
    S.flyBG = Instance.new("BodyGyro") S.flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5) S.flyBG.P = 1e4 S.flyBG.CFrame = h.CFrame S.flyBG.Parent = h
end

local function detachFlyBodyMovers()
    if S.flyBV then S.flyBV:Destroy() S.flyBV = nil end if S.flyBG then S.flyBG:Destroy() S.flyBG = nil end
    local h = getHumanoid() if h then h.PlatformStand = false end
end

local function getFlyInput()
    local mv = Vector3.zero local cam = workspace.CurrentCamera
    if isMobile then
        local hu = getHumanoid() if hu then local md = hu.MoveDirection if md.Magnitude > 0.1 then mv = md * Vector3.new(1, 0, 1) end end
        if S.mobileFlyDragging and S.mobileFlyVec.Magnitude > 0.1 then mv = S.mobileFlyVec end
        return mv
    end
    local cf = cam.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.yAxis end
    if mv.Magnitude < 0.01 then local hu = getHumanoid() if hu then local md = hu.MoveDirection if md.Magnitude > 0.1 then mv = md * Vector3.new(1, 0, 1) end end end
    return mv
end

local function startFly()
    dropConn("fly") attachFlyBodyMovers()
    trackConn("fly", RunService.Heartbeat:Connect(function()
        if not MovementSettings.Fly then return end
        local h = getHRP() if not h then return end
        if not S.flyBV or not S.flyBV.Parent then attachFlyBodyMovers() end
        if not S.flyBV or not S.flyBG then return end
        local mv = getFlyInput() S.flyBV.Velocity = mv.Magnitude > 0 and mv.Unit * MovementSettings.FlySpeed or Vector3.zero
        S.flyBG.CFrame = workspace.CurrentCamera.CFrame
    end))
end

local function stopFly() dropConn("fly") detachFlyBodyMovers() end

local function startFOVCircle()
    dropConn("fov")
    if not S.fovGui then
        S.fovGui = Instance.new("ScreenGui") S.fovGui.Name = "HH_FOV" S.fovGui.ResetOnSpawn = false S.fovGui.IgnoreGuiInset = true
        pcall(function() S.fovGui.Parent = game:GetService("CoreGui") end) if not S.fovGui.Parent then S.fovGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
        trackGui(S.fovGui) S.fovFrame = Instance.new("Frame") S.fovFrame.BackgroundTransparency = 1 S.fovFrame.AnchorPoint = Vector2.new(0.5, 0.5) S.fovFrame.Size = UDim2.new(0, 200, 0, 200) S.fovFrame.Parent = S.fovGui
        local st = Instance.new("UIStroke") st.Thickness = 2 st.Color = Color3.fromRGB(255, 255, 255) st.Transparency = 0.3 st.Parent = S.fovFrame
        local co = Instance.new("UICorner") co.CornerRadius = UDim.new(1, 0) co.Parent = S.fovFrame
    end
    S.fovGui.Enabled = true
    trackConn("fov", RunService.RenderStepped:Connect(function()
        if not AimbotSettings.FOVCircle or not S.fovFrame then return end
        S.fovFrame.Size = UDim2.new(0, AimbotSettings.FOVRadius * 2, 0, AimbotSettings.FOVRadius * 2)
        if isMobile then
            local ins = game:GetService("GuiService"):GetGuiInset() local vp = workspace.CurrentCamera.ViewportSize
            S.fovFrame.Position = UDim2.new(0, vp.X / 2, 0, (vp.Y / 2) + (ins.Y / 2))
        else S.fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0) end
    end))
end

local function stopFOVCircle() dropConn("fov") if S.fovGui then S.fovGui.Enabled = false end end

local function startMobileFlyDrag()
    if not isMobile then return end
    local active, start = false, nil
    UserInputService.TouchStarted:Connect(function(i, gp)
        if gp or not MovementSettings.Fly then return end
        active = true start = i.Position S.mobileFlyDragging = true
    end)
    UserInputService.TouchMoved:Connect(function(i, gp)
        if gp or not active or not MovementSettings.Fly then return end
        local d = i.Position - start local cam = workspace.CurrentCamera
        S.mobileFlyVec = cam.CFrame.LookVector * (-d.Y * 0.05) + cam.CFrame.RightVector * (d.X * 0.05)
    end)
    UserInputService.TouchEnded:Connect(function() active = false S.mobileFlyDragging = false S.mobileFlyVec = Vector3.zero end)
end

local function serverKillAllTick()
    local k, stab, touch, hnd = getLocalKnife(), nil, nil, nil
    if not k then equipKnife() task.wait(0.15) k = getLocalKnife() end
    if not k then return false end
    local ev = k:FindFirstChild("Events") hnd = k:FindFirstChild("Handle")
    if ev then stab = ev:FindFirstChild("KnifeStabbed") touch = ev:FindFirstChild("HandleTouched") end
    if k.Parent ~= LocalPlayer.Character then local h = getHumanoid() if h then pcall(function() h:EquipTool(k) end) end task.wait(0.05) k = getLocalKnife() or k if k then ev = k:FindFirstChild("Events") hnd = k:FindFirstChild("Handle") if ev then stab = ev:FindFirstChild("KnifeStabbed") touch = ev:FindFirstChild("HandleTouched") end end end
    if stab then pcall(function() stab:FireServer() end) end
    if isMobile then
        pcall(function() k:Activate() end)
        local ct = type(firetouchinterest) == "function"
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    local hr = p.Character:FindFirstChild("HumanoidRootPart") local hd = p.Character:FindFirstChild("Head")
                    if touch then if hr then pcall(function() touch:FireServer(hr) end) end if hd then pcall(function() touch:FireServer(hd) end) end end
                    if ct and hnd then
                        if hr then pcall(firetouchinterest, hr, hnd, 0) pcall(firetouchinterest, hr, hnd, 1) pcall(firetouchinterest, hnd, hr, 0) pcall(firetouchinterest, hnd, hr, 1) end
                        if hd then pcall(firetouchinterest, hd, hnd, 0) pcall(firetouchinterest, hd, hnd, 1) end
                    end
                end
            end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    local hr = p.Character:FindFirstChild("HumanoidRootPart") local hd = p.Character:FindFirstChild("Head")
                    if touch then if hr then pcall(function() touch:FireServer(hr) end) end if hd then pcall(function() touch:FireServer(hd) end) end end
                end
            end
        end
    end
    return true
end

local function reapplyActiveFeatures() end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function() task.wait(0.3) clearHighlights(p) applyESP(p) end)
        p.CharacterRemoving:Connect(function() clearHighlights(p) end)
    end
end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() task.wait(0.3) clearHighlights(p) applyESP(p) end) end)
Players.PlayerRemoving:Connect(function(p) clearHighlights(p) S.roleCache[p.Name] = nil TargetVisibility[p] = nil VisCache[p] = nil end)

hookFadeEvent()
task.spawn(function() while true do task.wait(3) if not S.fadeConn or not getFadeEvent() then hookFadeEvent() end end end)

local remotes = ReplicatedStorage:FindFirstChild("Remotes") local gameplay = remotes and remotes:FindFirstChild("Gameplay")
if gameplay then
    local cs = gameplay:FindFirstChild("CoinsStarted") local cc = gameplay:FindFirstChild("CoinCollected") local re = gameplay:FindFirstChild("RoundEndFade") local rs = gameplay:FindFirstChild("RoundStart")
    if cs then cs.OnClientEvent:Connect(function(d) markRoundStarted() stopCoinCollector() S.bagProgress = {} if type(d) == "table" and d.Coin and d.Coin.CollectionLimit then C.FARM_GOAL = d.Coin.CollectionLimit end S.totalCoins = 0 S.farmTargetCoin = nil S.farmBlacklist = {} S.farmTouchedCoins = {} S.farmLastCollectSpeedAt = 0 if S.coinCountSetter then S.coinCountSetter(0) end S.roundActive = true if FarmSettings.AutoFarm then ensureFarmNoclip() startCoinCollector() end end) end
    if cc then cc.OnClientEvent:Connect(function(b, c) S.lastCollectTime = tick() S.farmLastCollectAt = tick() S.farmLastCollectSpeedAt = tick() S.farmTargetCoin = nil S.farmTargetStartedAt = 0 S.farmStuckPos = nil S.farmStuckAt = 0 if type(b) == "string" and type(c) == "number" then S.bagProgress[b] = c end S.totalCoins = 0 for _, v in pairs(S.bagProgress) do S.totalCoins = S.totalCoins + v end if S.coinCountSetter then S.coinCountSetter(S.totalCoins) end end) end
    if rs then rs.OnClientEvent:Connect(function() markRoundStarted() stopCoinCollector() S.bagProgress = {} S.totalCoins = 0 S.farmTargetCoin = nil S.farmBlacklist = {} S.farmTouchedCoins = {} S.farmLastCollectSpeedAt = 0 S.rerolling = false S.killAllRunning = false S.roundActive = true if S.coinCountSetter then S.coinCountSetter(0) end task.wait(0.1) for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and p.Character then applyESP(p) end end onRoundBegin() if FarmSettings.AutoFarm then ensureFarmNoclip() task.wait(0.5) startCoinCollector() end end) end
    if re then re.OnClientEvent:Connect(function() S.roundActive = false S.roundStartedAt = 0 S.fadeReceivedAt = 0 S.roleCache = {} S.rerolling = false stopCoinCollector() onRoundEnd() if FarmSettings.AutoFarm then restoreFarmNoclip() end task.wait(0.05) for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then clearHighlights(p) end end end) end
end

task.spawn(function() while true do task.wait(0.5) if FarmSettings.AutoFarm and S.roundActive and not S.coinCollecting and S.totalCoins < C.FARM_GOAL then startCoinCollector() end end end)
task.spawn(function() while true do task.wait(45) if getgenv().__HH_STATE and #getgenv().__HH_STATE.connections > 60 then local a = {} for _, c in ipairs(getgenv().__HH_STATE.connections) do local ok, co = pcall(function() return c.Connected end) if ok and co then a[#a + 1] = c end end getgenv().__HH_STATE.connections = a end end end)

LocalPlayer.CharacterAdded:Connect(function()
    MurdererCache.plr = nil MurdererCache.time = 0 for k in pairs(TargetVisibility) do TargetVisibility[k] = nil end for k in pairs(VisCache) do VisCache[k] = nil end
    S.korbloxPart = nil S.lastSafeCFrame = nil S.currentEmoteTrack = nil S.miniBoxTrack = nil S.flingOriginalCFrame = nil S.flingOriginalPosition = nil S.flingTargetRunning = false S.killAllRunning = false S.flingRunning = false S.spectating = false S.spectateTarget = nil S.spectateDefaultSubject = nil S.lastCollectTime = 0 S.lastCamUpdate = 0 S.autoKillAll = S.autoKillAll or false S.farmTargetCoin = nil S.farmTouchedCoins = {} S.farmBlacklist = {} S.farmWalkBV = nil S.farmLastCollectAt = 0 S.farmStartedAt = 0 S.farmLastFallbackAt = 0 S.farmStuckPos = nil S.farmStuckAt = 0 S.farmLastCollectSpeedAt = 0 S.farmTargetStartedAt = 0 S.lastGyroUpdate = 0 S.rerolling = false
    if S.killAllTask then pcall(task.cancel, S.killAllTask) S.killAllTask = nil end
    if S.animPriorityConn then S.animPriorityConn:Disconnect() S.animPriorityConn = nil end
    if S.flingTargetThread then pcall(task.cancel, S.flingTargetThread) S.flingTargetThread = nil end
    if S.flingTask then pcall(task.cancel, S.flingTask) S.flingTask = nil end
    stopFarmBodyMovers() clearBeamPool(S.beamData) task.wait(0.6) if isMobile then scanForGunShoot() end if MovementSettings.Fly then attachFlyBodyMovers() end if AvatarSettings.Korblox then pcall(applyKorblox) end if AvatarSettings.AnimPack then pcall(applyAnimPack) end if FarmSettings.AutoFarm and S.roundActive then task.wait(0.5) if not S.coinCollecting then startCoinCollector() end end
end)

getgenv().HH_LOGIC = {
    S = S, ConnectionRegistry = ConnectionRegistry, MurdererCache = MurdererCache, TargetVisibility = TargetVisibility, ESP = ESP,
    trackConn = trackConn, dropConn = dropConn, trackThread = trackThread, trackGui = trackGui,
    getHRP = getHRP, getHumanoid = getHumanoid, isLocalMurderer = isLocalMurderer, isLocalSheriffOrHero = isLocalSheriffOrHero,
    getMurderer = getMurderer, getMurdererCached = getMurdererCached, getSheriff = getSheriff, getHero = getHero,
    isTargetSafe = isTargetSafe, getMM2TargetPart = getMM2TargetPart, isVisibleForShot = isVisibleForShot,
    setupKnifeDodgeHook = setupKnifeDodgeHook, startFly = startFly, stopFly = stopFly, startAntiVoid = startAntiVoid, stopAntiVoid = stopAntiVoid,
    startFOVCircle = startFOVCircle, stopFOVCircle = stopFOVCircle, applyKorblox = applyKorblox, removeKorblox = removeKorblox,
    applyAnimPack = applyAnimPack, playMusic = playMusic, stopMusic = stopMusic, bringGunToPlayer = bringGunToPlayer,
    teleportToPlayer = teleportToPlayer, startCoinCollector = startCoinCollector, stopCoinCollector = stopCoinCollector,
    ensureFarmHelpers = ensureFarmHelpers, ensureFarmNoclip = ensureFarmNoclip, restoreFarmHelpers = restoreFarmHelpers,
    restoreFarmNoclip = restoreFarmNoclip, applyGunESP = applyGunESP, clearGunESP = clearGunESP, applyESP = applyESP,
    refreshAllESP = refreshAllESP, startNameTagUpdater = startNameTagUpdater, stopNameTagUpdater = stopNameTagUpdater,
    ensureBeamConn = ensureBeamConn, stopBeamIfIdle = stopBeamIfIdle, playEmote = playEmote, shouldWaitForCoins = shouldWaitForCoins,
    shootAt = shootAt, yarhmFireAt = yarhmFireAt, findGunEquipped = findGunEquipped, findGunInBackpack = findGunInBackpack,
    serverKillAllTick = serverKillAllTick, startFlingTarget = startFlingTarget, getFlingTargetByName = getFlingTargetByName,
    startMobileFlyDrag = startMobileFlyDrag, spectatePlayer = spectatePlayer, stopSpectating = stopSpectating,
    getRoleFromCache = getRoleFromCache, reapplyActiveFeatures = reapplyActiveFeatures,
    Players = Players, RunService = RunService, UserInputService = UserInputService, LocalPlayer = LocalPlayer, isMobile = isMobile
}
