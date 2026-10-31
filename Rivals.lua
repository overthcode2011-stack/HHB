local API = loadstring(game:HttpGet("https://raw.githubusercontent.com/overthcode2011-stack/HHB/refs/heads/main/API"))()
API.Config.SupportedGames = { 17625359962 }
API.Config.KeySystem.Enabled = false

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

local mousemoverel = mousemoverel or MouseMoveRel or (syn and syn.mousemoverel) or (fluxus and fluxus.mousemoverel)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local AimbotSettings = {
    Enabled = false, SilentAim = false, FOV = 150, Smoothing = 0.35,
    WallCheck = false, MaxDistance = 300, Target = "Head", ShowFOV = false,
    TeamCheck = false, TriggerBot = false, TriggerRange = 150,
}
local VisualSettings = { RivalsESP = false, NameTags = false, Tracers = false, Skeleton = true, HealthBar = true, Distance = true, MaxRenderDistance = 500 }
local MiscSettings = { InfJump = false, AntiAFK = false, FullOptimized = false, ShowStats = true }
local MovementSettings = { Noclip = false, God = false, Fly = false, FlySpeed = 60 }

local ESP_RATE = 1 / 20
local AIM_RATE = 1 / 60
local ACTIVE_FIGHTER_TIMEOUT = 300
local RESPAWN_CLEAR_WINDOW = 3
local PROXIMITY_BUFFER = 200

local fovCircle = nil
local noclipConn, godConn, antiAFKConn, flyConn = nil, nil, nil, nil
local flyState = { enabled = false, speed = 60 }
local activeFighters = {}
local lastMatchSignal = os.clock()
local endMatch = nil
local leaveDuelRemote, respawnNowRemote = nil, nil

local function isTooFarFromPlayer(hrp)
    if not hrp then return false end
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    return (hrp.Position - myHRP.Position).Magnitude > (VisualSettings.MaxRenderDistance + PROXIMITY_BUFFER)
end

local function markActive(name)
    if typeof(name) ~= "string" or #name == 0 then return end
    local p = Players:FindFirstChild(name)
    if not p or p == LocalPlayer then return end
    local char = p.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and isTooFarFromPlayer(hrp) then return end
    activeFighters[name] = os.clock()
end

local function walkForPlayers(value, depth)
    depth = depth or 0
    if depth > 5 then return end
    local t = typeof(value)
    if t == "Instance" then
        if value:IsA("Player") then markActive(value.Name) end
    elseif t == "string" then
        local p = Players:FindFirstChild(value)
        if p then markActive(p.Name) end
    elseif t == "table" then
        for k, v in pairs(value) do
            walkForPlayers(k, depth + 1)
            walkForPlayers(v, depth + 1)
        end
    end
end

pcall(function()
    local rep = ReplicatedStorage:FindFirstChild("Remotes")
    rep = rep and rep:FindFirstChild("Replication")
    if not rep then return end
    local duel = rep:FindFirstChild("Duel")
    if duel then
        local ev = duel:FindFirstChild("Replicate")
        if ev then
            ev.OnClientEvent:Connect(function(...)
                lastMatchSignal = os.clock()
                for _, a in ipairs({...}) do walkForPlayers(a) end
            end)
        end
    end
    local fighter = rep:FindFirstChild("Fighter")
    if fighter then
        local ev = fighter:FindFirstChild("UpdateCameraRotations")
        if ev then
            ev.OnClientEvent:Connect(function(...)
                lastMatchSignal = os.clock()
                for _, a in ipairs({...}) do walkForPlayers(a) end
            end)
        end
    end
end)

local function isActiveFighter(p)
    if not p then return false end
    local t = activeFighters[p.Name]
    if not t then return false end
    if os.clock() - t > ACTIVE_FIGHTER_TIMEOUT then activeFighters[p.Name] = nil; return false end
    return true
end

local function isInMatch()
    for _, t in pairs(activeFighters) do
        if os.clock() - t < ACTIVE_FIGHTER_TIMEOUT then return true end
    end
    return false
end

local function isCombatant(plr)
    if not plr or plr == LocalPlayer then return false end
    if not isActiveFighter(plr) then return false end
    local char = plr.Character
    if not char or char.Parent ~= workspace then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if isTooFarFromPlayer(hrp) then return false end
    activeFighters[plr.Name] = os.clock()
    return true
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {}

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function rebuildRayFilter()
    local l = {}
    if LocalPlayer.Character then l[#l + 1] = LocalPlayer.Character end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then l[#l + 1] = p.Character end
    end
    rayParams.FilterDescendantsInstances = l
end

local function hasLineOfSight(part)
    local cam = workspace.CurrentCamera
    if not part or not cam then return false end
    local cp = cam.CFrame.Position
    local off = part.Position - cp
    local d = off.Magnitude
    if d <= 0 then return false end
    local hit = workspace:Raycast(cp, off.Unit * d, rayParams)
    if not hit then return true end
    return hit.Instance and (hit.Instance:IsDescendantOf(part.Parent) or hit.Instance == part)
end

local function getTargetPart(character)
    if not character then return nil end
    if AimbotSettings.Target == "Head" then return character:FindFirstChild("Head")
    elseif AimbotSettings.Target == "Torso" then
        return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    elseif AimbotSettings.Target == "Random" then
        if math.random(1, 2) == 1 then return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        else return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head") end
    end
    return character:FindFirstChild("Head")
end

local teamCache, teamCacheTime = {}, {}

local function normalizeTeam(v)
    if v == nil then return nil end
    local t = typeof(v)
    if t == "Instance" then return v end
    if t == "Color3" then return string.format("c:%.2f:%.2f:%.2f", v.R, v.G, v.B) end
    if t == "BrickColor" then return "b:" .. v.Name end
    if t == "string" then return v == "" and nil or "s:" .. v end
    if t == "number" then return "n:" .. tostring(v) end
    return nil
end

local function isTeamName(n)
    if typeof(n) ~= "string" then return false end
    local l = string.gsub(string.lower(n), "[%s_%-]", "")
    return l == "team" or l == "teamid" or l == "teamindex" or l == "teamcolor"
end

local function getTeamAttr(c)
    if not c then return nil end
    for n, v in pairs(c:GetAttributes()) do
        if isTeamName(n) then local r = normalizeTeam(v); if r then return r end end
    end
end

local function getTeamVal(c)
    if not c then return nil end
    for _, o in ipairs(c:GetChildren()) do
        if isTeamName(o.Name) then local r = normalizeTeam(o.Value); if r then return r end end
    end
end

local function getTeamSig(p)
    if not p then return nil end
    local now = os.clock()
    if teamCache[p] ~= nil and teamCacheTime[p] and now - teamCacheTime[p] < 0.5 then return teamCache[p] end
    local s = p.Team or getTeamAttr(p) or getTeamVal(p)
        or (p.Character and getTeamAttr(p.Character)) or (p.Character and getTeamVal(p.Character))
    if not s and p.TeamColor then
        local n = p.TeamColor.Name
        if n and n ~= "Medium stone grey" then s = "b:" .. n end
    end
    teamCache[p] = s
    teamCacheTime[p] = now
    return s
end

local function isTeammate(p)
    if not p or p == LocalPlayer then return true end
    if p.Team and LocalPlayer.Team then return p.Team == LocalPlayer.Team end
    local ls, ts = getTeamSig(LocalPlayer), getTeamSig(p)
    if ls ~= nil and ts ~= nil then
        if typeof(ls) == "Instance" and typeof(ts) == "Instance" then return ls == ts end
        return tostring(ls) == tostring(ts)
    end
    return false
end

local function isEnemy(p)
    if not p or p == LocalPlayer then return false end
    if AimbotSettings.TeamCheck and isTeammate(p) then return false end
    return true
end

local enemyCache, enemyCacheTime = {}, 0
local function getAliveEnemies()
    local now = os.clock()
    if now - enemyCacheTime < 0.2 then return enemyCache end
    enemyCacheTime = now
    local l = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and isCombatant(p) then
                l[#l + 1] = p
            end
        end
    end
    enemyCache = l
    return l
end

local function findNearest3D()
    local myRoot = getHRP()
    if not myRoot then return nil end
    local best, bestDist = nil, AimbotSettings.MaxDistance
    for _, p in ipairs(getAliveEnemies()) do
        local char = p.Character
        local part = char and getTargetPart(char)
        if part then
            local d = (myRoot.Position - part.Position).Magnitude
            if d <= bestDist then
                if not AimbotSettings.WallCheck or hasLineOfSight(part) then
                    bestDist = d
                    best = part
                end
            end
        end
    end
    return best
end

local function findNearestScreen(maxDist)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local best, bestD = nil, maxDist
    for _, p in ipairs(getAliveEnemies()) do
        local char = p.Character
        local part = char and getTargetPart(char)
        if part then
            local sp, on = cam:WorldToViewportPoint(part.Position)
            if on and sp.Z > 0 then
                local dx, dy = sp.X - cx, sp.Y - cy
                local d = math.sqrt(dx * dx + dy * dy)
                if d <= bestD then
                    if not AimbotSettings.WallCheck or hasLineOfSight(part) then
                        bestD = d
                        best = part
                    end
                end
            end
        end
    end
    return best
end

local function getRedirectTarget()
    if AimbotSettings.SilentAim then
        local t = findNearest3D()
        if t then return t end
    end
    if AimbotSettings.TriggerBot then
        local t = findNearestScreen(AimbotSettings.TriggerRange)
        if t then return t end
    end
    return nil
end

local _rsRemotes = ReplicatedStorage:FindFirstChild("Remotes")
leaveDuelRemote = _rsRemotes and _rsRemotes:FindFirstChild("LeaveDuel")
respawnNowRemote = _rsRemotes and _rsRemotes:FindFirstChild("RespawnNow")

pcall(function()
    local mt = getrawmetatable and getrawmetatable(game)
    if mt and setreadonly and hookmetamethod then
        setreadonly(mt, false)
        local oldNamecall = mt.__namecall
        mt.__namecall = hookmetamethod(game, "__namecall", function(self, ...)
            if self == leaveDuelRemote then
                if endMatch then pcall(endMatch) end
            elseif self == respawnNowRemote then
                if endMatch and (os.clock() - lastMatchSignal > RESPAWN_CLEAR_WINDOW) then
                    pcall(endMatch)
                end
            end

            if self == workspace and (AimbotSettings.SilentAim or AimbotSettings.TriggerBot) then
                local method = getnamecallmethod()
                if method == "Raycast" then
                    local origin, direction, params = ...
                    if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                        local cam = workspace.CurrentCamera
                        local camPos = cam and cam.CFrame.Position
                        if camPos and (origin - camPos).Magnitude < 15 then
                            local target = getRedirectTarget()
                            if target then
                                local newDir = target.Position - origin
                                if newDir.Magnitude > 0 then
                                    return oldNamecall(self, origin, newDir.Unit * direction.Magnitude, params)
                                end
                            end
                        end
                    end
                elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                    local target = getRedirectTarget()
                    if target then
                        local cam = workspace.CurrentCamera
                        if cam then
                            local args = table.pack(...)
                            args[1] = Ray.new(cam.CFrame.Position, (target.Position - cam.CFrame.Position).Unit * 1000)
                            return oldNamecall(self, table.unpack(args, 1, args.n))
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end
end)

pcall(function()
    if Drawing then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Filled = false
        fovCircle.Visible = false
        fovCircle.NumSides = 32
    end
end)

local function rotateRigTowards(part)
    if not part or not part.Parent then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dx = part.Position.X - hrp.Position.X
    local dz = part.Position.Z - hrp.Position.Z
    local desiredYaw = math.atan2(-dx, -dz)
    local currentYaw = math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z)
    local diff = math.atan2(math.sin(desiredYaw - currentYaw), math.cos(desiredYaw - currentYaw))
    local newYaw = currentYaw + diff * math.clamp(AimbotSettings.Smoothing * 1.5, 0, 1)
    local look = Vector3.new(-math.sin(newYaw), 0, -math.cos(newYaw))
    local right = Vector3.new(math.cos(newYaw), 0, -math.sin(newYaw))
    hrp.CFrame = CFrame.fromMatrix(hrp.CFrame.Position, right, Vector3.new(0, 1, 0), -look)
end

local function aimViaMouse(part)
    if not part or not part.Parent then return end
    if not mousemoverel then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local screenPos = cam:WorldToViewportPoint(part.Position)
    if not screenPos then return end
    local vp = cam.ViewportSize
    local dX = screenPos.X - vp.X * 0.5
    local dY = screenPos.Y - vp.Y * 0.5
    local dist = math.sqrt(dX * dX + dY * dY)
    if dist < 1 then return end
    local smooth = AimbotSettings.Smoothing
    if smooth <= 0 then smooth = 1 end
    local moveX = dX * smooth
    local moveY = dY * smooth
    if dist > 200 then moveX = moveX * 0.7; moveY = moveY * 0.7 end
    rotateRigTowards(part)
    pcall(mousemoverel, moveX, moveY)
end

local function healthColor(ratio)
    ratio = math.clamp(ratio, 0, 1)
    if ratio > 0.5 then return Color3.new(2 - ratio * 2, 1, 0)
    else return Color3.new(1, ratio * 2, 0) end
end

local R15_BONES = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},
    {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},
    {"RightUpperArm","RightLowerArm"},
    {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},
    {"RightUpperLeg","RightLowerLeg"},
    {"RightLowerLeg","RightFoot"},
}
local R6_BONES = {
    {"Head","Torso"},
    {"Torso","Left Arm"},
    {"Torso","Right Arm"},
    {"Torso","Left Leg"},
    {"Torso","Right Leg"},
}

local ESP = { active = false, boxes = {}, skeletons = {}, tracers = {}, names = {}, hpbars = {}, dists = {} }

local function newLine(color, thickness, transparency)
    local l = Drawing.new("Line")
    l.Color = color or Color3.new(1, 1, 1)
    l.Thickness = thickness or 1
    l.Transparency = transparency or 1
    l.Visible = false
    return l
end

local function safeRemove(obj)
    if obj and obj.Remove then pcall(obj.Remove, obj) end
end

local function createBox(plr)
    if plr == LocalPlayer or ESP.boxes[plr] then return end
    ESP.boxes[plr] = {
        top = newLine(Color3.new(1, 1, 1), 1, 1),
        right = newLine(Color3.new(1, 1, 1), 1, 1),
        bottom = newLine(Color3.new(1, 1, 1), 1, 1),
        left = newLine(Color3.new(1, 1, 1), 1, 1),
    }
end

local function destroyBox(plr)
    local box = ESP.boxes[plr]
    if not box then return end
    safeRemove(box.top); safeRemove(box.right); safeRemove(box.bottom); safeRemove(box.left)
    ESP.boxes[plr] = nil
end

local function updateBox(plr, cam)
    local box = ESP.boxes[plr]
    if not box then return end
    local char = plr.Character
    if not char then
        if box.top.Visible then box.top.Visible = false; box.right.Visible = false; box.bottom.Visible = false; box.left.Visible = false end
        return
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        if box.top.Visible then box.top.Visible = false; box.right.Visible = false; box.bottom.Visible = false; box.left.Visible = false end
        return
    end
    local screen, onScreen = cam:WorldToViewportPoint(root.Position)
    if not onScreen or screen.Z <= 0 then
        if box.top.Visible then box.top.Visible = false; box.right.Visible = false; box.bottom.Visible = false; box.left.Visible = false end
        return
    end
    local dist = (root.Position - cam.CFrame.Position).Magnitude
    if dist < 1 then dist = 1 end
    local ppS = (cam.ViewportSize.Y * 0.5) / (dist * math.tan(math.rad(cam.FieldOfView) * 0.5))
    local w = 3 * ppS
    local h = 5.2 * ppS
    local x = screen.X - w * 0.5
    local y = screen.Y - h * 0.5
    box.top.From = Vector2.new(x, y);       box.top.To = Vector2.new(x + w, y)
    box.right.From = Vector2.new(x + w, y); box.right.To = Vector2.new(x + w, y + h)
    box.bottom.From = Vector2.new(x + w, y + h); box.bottom.To = Vector2.new(x, y + h)
    box.left.From = Vector2.new(x, y + h);  box.left.To = Vector2.new(x, y)
    box.top.Visible = true; box.right.Visible = true; box.bottom.Visible = true; box.left.Visible = true
end

local function createSkeleton(plr)
    if plr == LocalPlayer or ESP.skeletons[plr] then return end
    local char = plr.Character
    if not char then return end
    local bones = char:FindFirstChild("UpperTorso") and R15_BONES
              or char:FindFirstChild("Torso") and R6_BONES
    if not bones then return end
    local lines = {}
    for i, bone in ipairs(bones) do
        lines[i] = {
            line = newLine(Color3.new(1, 1, 1), 1, 1),
            pa = char:FindFirstChild(bone[1]),
            pb = char:FindFirstChild(bone[2]),
        }
    end
    ESP.skeletons[plr] = lines
end

local function destroySkeleton(plr)
    local lines = ESP.skeletons[plr]
    if not lines then return end
    for _, l in ipairs(lines) do safeRemove(l.line) end
    ESP.skeletons[plr] = nil
end

local function updateSkeleton(plr, cam)
    local lines = ESP.skeletons[plr]
    if not lines then return end
    for _, l in ipairs(lines) do
        local pa, pb = l.pa, l.pb
        if pa and pa.Parent and pb and pb.Parent then
            local sa, onA = cam:WorldToViewportPoint(pa.Position)
            if onA and sa.Z > 0 then
                local sb, onB = cam:WorldToViewportPoint(pb.Position)
                if onB and sb.Z > 0 then
                    l.line.From = Vector2.new(sa.X, sa.Y)
                    l.line.To = Vector2.new(sb.X, sb.Y)
                    l.line.Visible = true
                else
                    l.line.Visible = false
                end
            else
                l.line.Visible = false
            end
        else
            l.line.Visible = false
        end
    end
end

local function createTracer(plr)
    if plr == LocalPlayer or ESP.tracers[plr] then return end
    ESP.tracers[plr] = newLine(Color3.new(1, 1, 1), 1, 1)
end

local function destroyTracer(plr)
    safeRemove(ESP.tracers[plr])
    ESP.tracers[plr] = nil
end

local function updateTracer(plr, cam)
    local g = ESP.tracers[plr]
    if not g then return end
    local char = plr.Character
    if not char then g.Visible = false; return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then g.Visible = false; return end
    local sp, on = cam:WorldToViewportPoint(root.Position)
    if not on or sp.Z <= 0 then g.Visible = false; return end
    g.From = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y)
    g.To = Vector2.new(sp.X, sp.Y)
    g.Visible = true
end

local function createNameTag(plr)
    if plr == LocalPlayer or ESP.names[plr] then return end
    local txt = Drawing.new("Text")
    txt.Color = Color3.new(1, 1, 1)
    txt.Size = 14
    txt.Center = true
    txt.Outline = true
    txt.OutlineColor = Color3.new(0, 0, 0)
    txt.Visible = false
    ESP.names[plr] = txt
end

local function destroyNameTag(plr)
    safeRemove(ESP.names[plr])
    ESP.names[plr] = nil
end

local function updateNameTag(plr, cam)
    local txt = ESP.names[plr]
    if not txt then return end
    local char = plr.Character
    if not char then if txt.Visible then txt.Visible = false end return end
    local head = char:FindFirstChild("Head")
    if not head then if txt.Visible then txt.Visible = false end return end
    local sp, on = cam:WorldToViewportPoint(head.Position)
    if not on or sp.Z <= 0 then if txt.Visible then txt.Visible = false end return end
    txt.Position = Vector2.new(sp.X, sp.Y - 22)
    txt.Text = plr.DisplayName
    txt.Visible = true
end

local function createDistanceTag(plr)
    if plr == LocalPlayer or ESP.dists[plr] then return end
    local txt = Drawing.new("Text")
    txt.Color = Color3.fromRGB(200, 200, 200)
    txt.Size = 12
    txt.Center = true
    txt.Outline = true
    txt.OutlineColor = Color3.new(0, 0, 0)
    txt.Visible = false
    ESP.dists[plr] = txt
end

local function destroyDistanceTag(plr)
    safeRemove(ESP.dists[plr])
    ESP.dists[plr] = nil
end

local function updateDistanceTag(plr, cam, myPos)
    local txt = ESP.dists[plr]
    if not txt then return end
    local char = plr.Character
    if not char then if txt.Visible then txt.Visible = false end return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then if txt.Visible then txt.Visible = false end return end
    local sp, on = cam:WorldToViewportPoint(root.Position)
    if not on or sp.Z <= 0 then if txt.Visible then txt.Visible = false end return end
    local d = myPos and math.floor((myPos - root.Position).Magnitude) or 0
    txt.Position = Vector2.new(sp.X, sp.Y + 40)
    txt.Text = d .. "m"
    txt.Visible = true
end

local function createHealthBar(plr)
    if plr == LocalPlayer or ESP.hpbars[plr] then return end
    ESP.hpbars[plr] = {
        bg = newLine(Color3.fromRGB(20, 20, 20), 3, 0.5),
        fill = newLine(Color3.fromRGB(0, 255, 100), 3, 1),
    }
end

local function destroyHealthBar(plr)
    local hb = ESP.hpbars[plr]
    if hb then safeRemove(hb.bg); safeRemove(hb.fill); ESP.hpbars[plr] = nil end
end

local function updateHealthBar(plr, cam)
    local hb = ESP.hpbars[plr]
    if not hb then return end
    local char = plr.Character
    if not char then
        if hb.bg.Visible then hb.bg.Visible = false; hb.fill.Visible = false end
        return
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.MaxHealth <= 0 then
        if hb.bg.Visible then hb.bg.Visible = false; hb.fill.Visible = false end
        return
    end
    local screen, on = cam:WorldToViewportPoint(root.Position)
    if not on or screen.Z <= 0 then
        if hb.bg.Visible then hb.bg.Visible = false; hb.fill.Visible = false end
        return
    end
    local dist = (root.Position - cam.CFrame.Position).Magnitude
    if dist < 1 then dist = 1 end
    local ppS = (cam.ViewportSize.Y * 0.5) / (dist * math.tan(math.rad(cam.FieldOfView) * 0.5))
    local barH = 5.2 * ppS * 0.7
    local x = screen.X - (3 * ppS) * 0.5 - 8
    local yTop = screen.Y - barH * 0.5
    local yBot = screen.Y + barH * 0.5
    hb.bg.From = Vector2.new(x, yTop)
    hb.bg.To = Vector2.new(x, yBot)
    hb.bg.Visible = true
    local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
    local yFill = yBot - (yBot - yTop) * ratio
    hb.fill.From = Vector2.new(x, yFill)
    hb.fill.To = Vector2.new(x, yBot)
    hb.fill.Color = healthColor(ratio)
    hb.fill.Visible = true
end

local function clearAllESP()
    for plr in pairs(ESP.boxes) do destroyBox(plr) end
    for plr in pairs(ESP.skeletons) do destroySkeleton(plr) end
    for plr in pairs(ESP.tracers) do destroyTracer(plr) end
    for plr in pairs(ESP.names) do destroyNameTag(plr) end
    for plr in pairs(ESP.hpbars) do destroyHealthBar(plr) end
    for plr in pairs(ESP.dists) do destroyDistanceTag(plr) end
    ESP.boxes = {}; ESP.skeletons = {}; ESP.tracers = {}; ESP.names = {}; ESP.hpbars = {}; ESP.dists = {}
end

endMatch = function()
    activeFighters = {}
    enemyCache = {}
    enemyCacheTime = 0
    teamCache = {}
    teamCacheTime = {}
    lastMatchSignal = 0
    clearAllESP()
end

local function shouldRender(plr, myPos)
    if plr == LocalPlayer then return false end
    local char = plr.Character
    if not char or char.Parent ~= workspace then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not isCombatant(plr) then return false end
    if myPos then
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        if (root.Position - myPos).Magnitude > VisualSettings.MaxRenderDistance then return false end
    end
    return true
end

local function syncESP()
    if not ESP.active then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local myHRP = getHRP()
    local myPos = myHRP and myHRP.Position
    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local render = shouldRender(plr, myPos)
            seen[plr] = true
            if render then
                if VisualSettings.RivalsESP then
                    if not ESP.boxes[plr] then createBox(plr) end
                else if ESP.boxes[plr] then destroyBox(plr) end end
                if VisualSettings.Skeleton then
                    if not ESP.skeletons[plr] then createSkeleton(plr) end
                else if ESP.skeletons[plr] then destroySkeleton(plr) end end
                if VisualSettings.Tracers then
                    if not ESP.tracers[plr] then createTracer(plr) end
                else if ESP.tracers[plr] then destroyTracer(plr) end end
                if VisualSettings.NameTags then
                    if not ESP.names[plr] then createNameTag(plr) end
                else if ESP.names[plr] then destroyNameTag(plr) end end
                if VisualSettings.HealthBar then
                    if not ESP.hpbars[plr] then createHealthBar(plr) end
                else if ESP.hpbars[plr] then destroyHealthBar(plr) end end
                if VisualSettings.Distance then
                    if not ESP.dists[plr] then createDistanceTag(plr) end
                else if ESP.dists[plr] then destroyDistanceTag(plr) end end
            else
                if ESP.boxes[plr] then destroyBox(plr) end
                if ESP.skeletons[plr] then destroySkeleton(plr) end
                if ESP.tracers[plr] then destroyTracer(plr) end
                if ESP.names[plr] then destroyNameTag(plr) end
                if ESP.hpbars[plr] then destroyHealthBar(plr) end
                if ESP.dists[plr] then destroyDistanceTag(plr) end
            end
        end
    end
    for plr in pairs(ESP.boxes) do if not seen[plr] then destroyBox(plr) end end
    for plr in pairs(ESP.skeletons) do if not seen[plr] then destroySkeleton(plr) end end
    for plr in pairs(ESP.tracers) do if not seen[plr] then destroyTracer(plr) end end
    for plr in pairs(ESP.names) do if not seen[plr] then destroyNameTag(plr) end end
    for plr in pairs(ESP.hpbars) do if not seen[plr] then destroyHealthBar(plr) end end
    for plr in pairs(ESP.dists) do if not seen[plr] then destroyDistanceTag(plr) end end
end

local function startESP()
    if ESP.active then return end
    ESP.active = true
    syncESP()
end

local function stopESP()
    ESP.active = false
    clearAllESP()
end

local function anyVisualOn()
    return VisualSettings.RivalsESP or VisualSettings.Skeleton
        or VisualSettings.Tracers or VisualSettings.NameTags
        or VisualSettings.HealthBar or VisualSettings.Distance
end

local function refreshESPState()
    if anyVisualOn() then
        if not ESP.active then startESP() end
    else
        if ESP.active then stopESP() end
    end
end

local FF = {
    ["DFIntTaskSchedulerTargetFps"] = "240",
    ["FFlagTaskSchedulerLimitTargetFpsTo2402"] = "False",
    ["DFIntDebugFRMQualityLevelOverride"] = "1",
    ["FFlagDebugSkyGray"] = "True",
    ["FFlagDebugGraphicsPreferD3D11"] = "True",
    ["DFFlagDebugRenderForceTechnologyVoxel"] = "True",
    ["FIntRenderShadowIntensity"] = "0",
    ["DFIntCSGLevelOfDetailSwitchingDistance"] = "0",
    ["DFIntCSGLevelOfDetailSwitchingDistanceL12"] = "0",
    ["DFIntCSGLevelOfDetailSwitchingDistanceL23"] = "0",
    ["DFIntCSGLevelOfDetailSwitchingDistanceL34"] = "0",
    ["FFlagDisablePostFx"] = "True",
    ["FIntDebugForceMSAASamples"] = "0",
    ["FIntFRMMinGrassDistance"] = "0",
    ["FIntFRMMaxGrassDistance"] = "0",
    ["FIntRenderGrassDetailStrands"] = "0",
    ["FIntRenderGrassHeightScaler"] = "0",
    ["DFFlagTextureQualityOverrideEnabled"] = "True",
    ["DFIntTextureQualityOverride"] = "0",
    ["FIntDebugTextureManagerSkipMips"] = "8",
    ["DFIntTextureCompositorActiveJobs"] = "0",
    ["FFlagDebugDisableTelemetryEventIngest"] = "True",
    ["FFlagDebugDisableTelemetryPoint"] = "True",
    ["FFlagDebugDisableTelemetryEphemeralCounter"] = "True",
    ["FFlagDebugDisableTelemetryV2Stat"] = "True",
    ["FFlagDebugDisableTelemetryV2Counter"] = "True",
    ["DFStringTelemetryV2Url"] = "null",
    ["DFStringTelegrafHTTPTransportUrl"] = "null",
    ["DFStringRobloxAnalyticsURL"] = "null",
    ["FLogNetwork"] = "7",
    ["FFlagDebugDisableShadows"] = "True",
    ["FFlagDebugDisableShadowsUGC"] = "True",
    ["FIntRenderLocalLightUpdatesMax"] = "0",
    ["FIntRenderLocalLightUpdatesMin"] = "0",
    ["FIntRenderLocalLightFadeInMs"] = "0",
    ["FFlagDisableRenderLocalLights"] = "True",
    ["FFlagDisableParticleLighting"] = "True",
    ["FFlagDisableDynamicLighting"] = "True",
    ["FFlagDebugDisableSky"] = "True",
    ["FFlagDisableTerrainDetails"] = "True",
    ["FIntTerrainDetailLevelOverride"] = "0",
    ["FFlagDebugDisablePostProcessing"] = "True",
    ["FFlagDisableBloom"] = "True",
    ["FFlagDisableDepthOfField"] = "True",
    ["FFlagDisableSunRays"] = "True",
    ["FFlagDisableVignette"] = "True",
    ["FFlagDisableAtmosphere"] = "True",
    ["FFlagDisableClouds"] = "True",
    ["FFlagFastGPULightCulling3"] = "True",
    ["FFlagDisableClothSimulation"] = "True",
    ["FFlagDisableCharacterShadows"] = "True",
    ["FFlagPlayerShadows"] = "False",
    ["FFlagDebugGraphicsDisableShadows"] = "True",
    ["DFIntMaxParticleCount"] = "0",
    ["DFIntParticleEmissionRateScale"] = "0",
    ["FFlagParticleEmitterUseLighting"] = "False",
    ["DFIntRenderShadowMapSize"] = "0",
    ["FFlagDisableRenderOcclusionCulling"] = "True",
    ["DFIntTerrainLODMax"] = "0",
    ["FFlagDebugDisableWater"] = "True",
    ["FFlagDebugDisableWaterReflection"] = "True",
    ["FFlagDebugDisableReflections"] = "True",
    ["FFlagDisableAllPostEffects"] = "True",
    ["FFlagDisableGrass"] = "True",
    ["FFlagDebugDisableGrass"] = "True",
    ["FFlagRenderGuiInBackground"] = "False",
    ["FFlagDisableTelemetry"] = "True",
    ["FFlagDisableAnalytics"] = "True",
    ["FFlagDisableGamepadController"] = "True",
    ["FFlagDebugDisableAudio"] = "True",
    ["FFlagDisableAudio"] = "True",
}

local function applyFullOptimized()
    if not setfflag then
        API:Notify("setfflag no disponible")
        return false
    end
    local ok, total = 0, 0
    for flag, value in pairs(FF) do
        total = total + 1
        local s = pcall(setfflag, flag, value)
        if s then ok = ok + 1 end
    end
    API:Notify(string.format("FFlags aplicadas (%d/%d)", ok, total))
    return true
end

local function startFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, o in ipairs(hrp:GetChildren()) do
        if o.Name == "RS_Fly" then o:Destroy() end
    end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "RS_Fly"
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    local bg = Instance.new("BodyGyro")
    bg.Name = "RS_Fly"
    bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bg.P = 9000
    bg.Parent = hrp
    flyState.enabled = true
    flyConn = RunService.RenderStepped:Connect(function()
        if not flyState.enabled then return end
        local c = LocalPlayer.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if not root or not bv.Parent then return end
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        bv.Velocity = dir * flyState.speed
        bg.CFrame = cam.CFrame
    end)
end

local function stopFly()
    flyState.enabled = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, o in ipairs(hrp:GetChildren()) do
                if o.Name == "RS_Fly" then o:Destroy() end
            end
        end
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
end

local statsGui = Instance.new("ScreenGui")
statsGui.Name = "RS_Stats"
statsGui.ResetOnSpawn = false
statsGui.IgnoreGuiInset = true
pcall(function() statsGui.Parent = game:GetService("CoreGui") end)
if not statsGui.Parent then
    statsGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(0, 160, 0, 56)
statsFrame.Position = UDim2.new(0, 10, 0, 10)
statsFrame.BackgroundColor3 = Color3.new(0, 0, 0)
statsFrame.BackgroundTransparency = 0.45
statsFrame.BorderSizePixel = 0
statsFrame.Parent = statsGui

local sc = Instance.new("UICorner")
sc.CornerRadius = UDim.new(0, 6)
sc.Parent = statsFrame

local statsText = Instance.new("TextLabel")
statsText.Size = UDim2.new(1, -10, 1, -10)
statsText.Position = UDim2.new(0, 5, 0, 5)
statsText.BackgroundTransparency = 1
statsText.TextColor3 = Color3.new(1, 1, 1)
statsText.Font = Enum.Font.Code
statsText.TextSize = 14
statsText.TextXAlignment = Enum.TextXAlignment.Left
statsText.TextYAlignment = Enum.TextYAlignment.Top
statsText.RichText = true
statsText.Text = "FPS: 0\nPING: 0ms"
statsText.Parent = statsFrame

local fpsCounter, fpsValue = 0, 0

task.spawn(function()
    while task.wait(0.5) do
        if MiscSettings.ShowStats then
            local ping = 0
            pcall(function()
                ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            statsText.Text = string.format("FPS: <font color='#00ff88'>%d</font>\nPING: <font color='#00aaff'>%dms</font>", fpsValue, ping)
            statsFrame.Visible = true
        else
            statsFrame.Visible = false
        end
    end
end)

local deathKeywords = { "you died", "you were", "eliminated", "game over", "defeated", "respawning", "you lost", "you have died", "died", "respawning in" }
local hookedTexts = {}

local function checkDeathText(v)
    if not v or not (v:IsA("TextLabel") or v:IsA("TextButton")) then return end
    pcall(function()
        local txt = string.lower(v.Text)
        if #txt == 0 then return end
        for _, kw in ipairs(deathKeywords) do
            if txt:find(kw, 1, true) then
                v.Text = "replicatedscripts.net"
                return
            end
        end
    end)
end

local function hookText(v)
    if hookedTexts[v] then return end
    hookedTexts[v] = true
    checkDeathText(v)
    pcall(function()
        v:GetPropertyChangedSignal("Text"):Connect(function() checkDeathText(v) end)
    end)
end

local function scanDeathGuis()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local containers = {}
    if pGui then table.insert(containers, pGui) end
    pcall(function() table.insert(containers, game:GetService("CoreGui")) end)
    for _, container in ipairs(containers) do
        pcall(function()
            for _, v in ipairs(container:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextButton") then
                    hookText(v)
                end
            end
        end)
    end
end

task.spawn(function()
    while task.wait(1.5) do
        pcall(scanDeathGuis)
    end
end)

local espAcc, aimAcc, fpsAcc = 0, 0, 0

RunService.RenderStepped:Connect(function(dt)
    fpsCounter = fpsCounter + 1
    fpsAcc = fpsAcc + dt
    if fpsAcc >= 1 then
        fpsValue = fpsCounter
        fpsCounter = 0
        fpsAcc = 0
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    if fovCircle then
        if AimbotSettings.ShowFOV and AimbotSettings.Enabled then
            fovCircle.Position = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
            fovCircle.Radius = AimbotSettings.FOV * 0.5
            fovCircle.Visible = true
        elseif fovCircle.Visible then
            fovCircle.Visible = false
        end
    end

    aimAcc = aimAcc + dt
    if aimAcc >= AIM_RATE and AimbotSettings.Enabled and not AimbotSettings.SilentAim then
        aimAcc = 0
        if isInMatch() then
            local target = findNearestScreen(AimbotSettings.FOV)
            if target then aimViaMouse(target) end
        end
    end

    espAcc = espAcc + dt
    if espAcc >= ESP_RATE and ESP.active then
        espAcc = 0
        local myHRP = getHRP()
        local myPos = myHRP and myHRP.Position
        for plr in pairs(ESP.boxes) do updateBox(plr, cam) end
        for plr in pairs(ESP.skeletons) do updateSkeleton(plr, cam) end
        for plr in pairs(ESP.tracers) do updateTracer(plr, cam) end
        for plr in pairs(ESP.names) do updateNameTag(plr, cam) end
        for plr in pairs(ESP.hpbars) do updateHealthBar(plr, cam) end
        for plr in pairs(ESP.dists) do updateDistanceTag(plr, cam, myPos) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if AimbotSettings.SilentAim or AimbotSettings.TriggerBot then
            rebuildRayFilter()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if ESP.active then syncESP() end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.3)
        if AimbotSettings.SilentAim or AimbotSettings.TriggerBot then
            getAliveEnemies()
        end
    end
end)

local win = API:CreateWindow("Happy Hub", "Rivals · Keyless · replicatedscripts.net")
if not win then return end

local homeTab       = win:CreateTab("Home",       API.Icons.Home   or "rbxassetid://109951566071454")
local aimbotTab     = win:CreateTab("Aimbot",     API.Icons.Combat or "rbxassetid://93310349660228")
local visualsTab    = win:CreateTab("Visuals",    "rbxassetid://13321848320")
local miscTab       = win:CreateTab("Misc",       API.Icons.Misc   or "rbxassetid://109962716823639")

local aimbotToggleRef, espToggleRef

win:CreateImageCard(homeTab, {
    Image = "rbxthumb://type=Asset&id=" .. game.PlaceId .. "&w=420&h=420",
    Title = "Keyless · free hub",
    Subtitle = "replicatedscripts.net",
    Description = "Enjoy the free features.",
    Height = 140,
    ImageWidth = 120,
})

win:CreateLabel(aimbotTab, "Aimbot Settings")

aimbotToggleRef = win:CreateToggle(aimbotTab, "Enabled [T]", AimbotSettings.Enabled, function(v)
    AimbotSettings.Enabled = v
    local hum = getHumanoid()
    if not v then
        if hum then hum.AutoRotate = true end
    else
        if hum then hum.AutoRotate = false end
    end
    API:Notify(v and "Aimbot enabled" or "Aimbot disabled")
end)

win:CreateToggle(aimbotTab, "Silent Aim", AimbotSettings.SilentAim, function(v)
    AimbotSettings.SilentAim = v
    if v then rebuildRayFilter() end
    API:Notify(v and "Silent Aim on" or "Silent Aim off")
end)

win:CreateSlider(aimbotTab, "FOV", 20, 800, AimbotSettings.FOV, function(v) AimbotSettings.FOV = v end)
win:CreateSlider(aimbotTab, "Smoothing", 0.05, 1, AimbotSettings.Smoothing, function(v) AimbotSettings.Smoothing = v end)
win:CreateSlider(aimbotTab, "Max Distance", 50, 2000, AimbotSettings.MaxDistance, function(v) AimbotSettings.MaxDistance = v end)

win:CreateToggle(aimbotTab, "Wall Check", AimbotSettings.WallCheck, function(v) AimbotSettings.WallCheck = v end)
win:CreateToggle(aimbotTab, "Team Check", AimbotSettings.TeamCheck, function(v) AimbotSettings.TeamCheck = v end)
win:CreateToggle(aimbotTab, "Show FOV Circle", AimbotSettings.ShowFOV, function(v) AimbotSettings.ShowFOV = v end)

win:CreateDropdown(aimbotTab, "Target", { "Head", "Torso", "Random" }, "Head", function(sel)
    AimbotSettings.Target = sel
end)

win:CreateLabel(aimbotTab, "Trigger Bot")

win:CreateToggle(aimbotTab, "Trigger Bot", AimbotSettings.TriggerBot, function(v)
    AimbotSettings.TriggerBot = v
    if v then rebuildRayFilter() end
    API:Notify(v and "Trigger Bot on" or "Trigger Bot off")
end)

win:CreateSlider(aimbotTab, "Trigger Range", 20, 400, AimbotSettings.TriggerRange, function(v) AimbotSettings.TriggerRange = v end)

win:CreateLabel(visualsTab, "Visual Settings")

espToggleRef = win:CreateToggle(visualsTab, "Rivals ESP [O]", VisualSettings.RivalsESP, function(v)
    VisualSettings.RivalsESP = v
    refreshESPState()
end)

win:CreateToggle(visualsTab, "Name Tags", VisualSettings.NameTags, function(v)
    VisualSettings.NameTags = v
    refreshESPState()
end)

win:CreateToggle(visualsTab, "Tracers", VisualSettings.Tracers, function(v)
    VisualSettings.Tracers = v
    refreshESPState()
end)

win:CreateToggle(visualsTab, "Skeleton", VisualSettings.Skeleton, function(v)
    VisualSettings.Skeleton = v
    refreshESPState()
end)

win:CreateToggle(visualsTab, "Health Bar", VisualSettings.HealthBar, function(v)
    VisualSettings.HealthBar = v
    refreshESPState()
end)

win:CreateToggle(visualsTab, "Distance", VisualSettings.Distance, function(v)
    VisualSettings.Distance = v
    refreshESPState()
end)

win:CreateSlider(visualsTab, "Max Render Distance", 50, 2000, VisualSettings.MaxRenderDistance, function(v)
    VisualSettings.MaxRenderDistance = v
end)

win:CreateLabel(miscTab, "Movement")

win:CreateToggle(miscTab, "Fly", MovementSettings.Fly, function(v)
    MovementSettings.Fly = v
    if v then startFly() else stopFly() end
end)

win:CreateSlider(miscTab, "Fly Speed", 10, 500, MovementSettings.FlySpeed, function(v)
    MovementSettings.FlySpeed = v
    flyState.speed = v
end)

win:CreateToggle(miscTab, "Infinite Jump", MiscSettings.InfJump, function(v)
    MiscSettings.InfJump = v
end)

win:CreateToggle(miscTab, "Noclip", MovementSettings.Noclip, function(v)
    MovementSettings.Noclip = v
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    if v then
        noclipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    end
end)

win:CreateToggle(miscTab, "God Mode", MovementSettings.God, function(v)
    MovementSettings.God = v
    if godConn then godConn:Disconnect(); godConn = nil end
    if v then
        godConn = RunService.Heartbeat:Connect(function()
            local hum = getHumanoid()
            if hum then hum.Health = hum.MaxHealth end
        end)
    end
end)

win:CreateToggle(miscTab, "Anti-AFK", MiscSettings.AntiAFK, function(v)
    MiscSettings.AntiAFK = v
    if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
    if v then
        antiAFKConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

win:CreateToggle(miscTab, "Show FPS / Ping", MiscSettings.ShowStats, function(v)
    MiscSettings.ShowStats = v
    statsFrame.Visible = v
end)

win:CreateLabel(miscTab, "Performance")

win:CreateToggle(miscTab, "FFlags Optimizer", false, function(v)
    MiscSettings.FullOptimized = v
    if v then applyFullOptimized() else API:Notify("Reinicia el cliente para revertir") end
end)

UserInputService.JumpRequest:Connect(function()
    if MiscSettings.InfJump then
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.T then
        if aimbotToggleRef then aimbotToggleRef:SetState(not AimbotSettings.Enabled) end
    elseif input.KeyCode == Enum.KeyCode.O then
        if espToggleRef then espToggleRef:SetState(not VisualSettings.RivalsESP) end
    end
end)

if isMobile then
    win:AddMobileButton({
        Icon = "rbxassetid://93310349660228",
        Tooltip = "Toggle Aimbot",
        OnClick = function() if aimbotToggleRef then aimbotToggleRef:SetState(not AimbotSettings.Enabled) end end,
    })
    win:AddMobileButton({
        Icon = "rbxassetid://13321848320",
        Tooltip = "Toggle ESP",
        OnClick = function() if espToggleRef then espToggleRef:SetState(not VisualSettings.RivalsESP) end end,
    })
    win:AddMobileButton({
        Icon = "rbxassetid://115558082558028",
        Tooltip = "Toggle UI",
        OnClick = function() win:ToggleUI() end,
    })
end

local function handleCharacterAdded(plr)
    if activeFighters[plr.Name] then
        activeFighters[plr.Name] = os.clock()
    end
    task.spawn(function()
        task.wait(0.5)
        if ESP.skeletons[plr] then
            destroySkeleton(plr)
        end
        if ESP.active and VisualSettings.Skeleton and activeFighters[plr.Name] then
            local char = plr.Character
            if char and char.Parent == workspace then
                createSkeleton(plr)
            end
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    rayParams.FilterDescendantsInstances = {}
    local hum = char:WaitForChild("Humanoid", 3)
    if hum and AimbotSettings.Enabled then hum.AutoRotate = false end
    task.wait(0.1)
    rebuildRayFilter()
end)

LocalPlayer.CharacterRemoving:Connect(function()
    rayParams.FilterDescendantsInstances = {}
    stopFly()
end)

Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer then
        plr.CharacterAdded:Connect(function() handleCharacterAdded(plr) end)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    destroyBox(plr); destroySkeleton(plr); destroyTracer(plr)
    destroyNameTag(plr); destroyHealthBar(plr); destroyDistanceTag(plr)
    activeFighters[plr.Name] = nil
    enemyCache = {}
    enemyCacheTime = 0
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        plr.CharacterAdded:Connect(function() handleCharacterAdded(plr) end)
    end
end
