local API = loadstring(game:HttpGet("https://raw.githubusercontent.com/overthcode2011-stack/HHB/refs/heads/main/API"))()
API.Config.SupportedGames = { 17625359962 }
API.Config.KeySystem.Enabled = false

local UserInputService     = game:GetService("UserInputService")
local RunService           = game:GetService("RunService")
local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local VirtualUser          = game:GetService("VirtualUser")
local LocalPlayer          = Players.LocalPlayer
local Camera               = workspace.CurrentCamera

local mousemoverel = mousemoverel or MouseMoveRel or (syn and syn.mousemoverel) or (fluxus and fluxus.mousemoverel)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local AimbotSettings = {
    Enabled = false, SilentAim = false, FOV = 150, Smoothing = 0.35,
    WallCheck = false, MaxDistance = 150, Target = "Head", ShowFOV = false,
    TeamCheck = false, TriggerBot = false, TriggerRange = 150, AutoFire = false,
}
local VisualSettings   = { RivalsESP = false, NameTags = false, Tracers = false, Skeleton = true, HealthBar = true }
local MiscSettings     = { InfJump = false, AntiAFK = false, FullOptimized = false }
local MovementSettings = { Noclip = false, God = false, Fly = false, FlySpeed = 60 }

local lockedTarget = nil
local silentAimEnabled = false
local noclipConn, godConn, antiAFKConn, flyConn = nil, nil, nil, nil
local triggerBotConn, autoFireConn = nil, nil
local fovCircle = nil
local flyState = { enabled = false, speed = 60 }
local activeFighters = {}

local function markActive(name)
    if typeof(name) == "string" and #name > 0 then
        activeFighters[name] = os.clock()
    end
end

local function walkForPlayers(value, depth)
    depth = depth or 0
    if depth > 6 then return end
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
        if ev then ev.OnClientEvent:Connect(function(...) for _, a in ipairs({...}) do walkForPlayers(a) end end) end
    end
    local fighter = rep:FindFirstChild("Fighter")
    if fighter then
        local ev = fighter:FindFirstChild("UpdateCameraRotations")
        if ev then ev.OnClientEvent:Connect(function(...) for _, a in ipairs({...}) do walkForPlayers(a) end end) end
    end
end)

local function isActiveFighter(p)
    if not p then return false end
    local t = activeFighters[p.Name]
    if not t then return false end
    if os.clock() - t > 30 then activeFighters[p.Name] = nil; return false end
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

local function getCrosshairPosition()
    local cam = workspace.CurrentCamera
    if not cam then return Vector2.new(0, 0) end
    return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
end

local function getTargetPart(character)
    if not character then return nil end
    if AimbotSettings.Target == "Head" then return character:FindFirstChild("Head")
    elseif AimbotSettings.Target == "Torso" then
        return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    elseif AimbotSettings.Target == "Random" then
        if math.random(1, 2) == 1 then
            return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        else
            return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
        end
    end
    return character:FindFirstChild("Head")
end

local teamCache, teamCacheTime = {}, {}

local function normalizeTeam(v)
    if v == nil then return nil end
    local t = typeof(v)
    if t == "Instance" then return v end
    if t == "Color3" then return string.format("c:%.3f:%.3f:%.3f", v.R, v.G, v.B) end
    if t == "BrickColor" then return "b:" .. v.Name end
    if t == "string" then return v == "" and nil or "s:" .. v end
    if t == "number" then return "n:" .. tostring(v) end
    return nil
end

local function isTeamName(n)
    if typeof(n) ~= "string" then return false end
    local l = string.gsub(string.lower(n), "[%s_%-]", "")
    return l == "team" or l == "teamid" or l == "teamindex" or l == "teamcolor" or l == "teamcolour"
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
    if teamCache[p] ~= nil and teamCacheTime[p] and now - teamCacheTime[p] < 0.25 then return teamCache[p] end
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
    if not isActiveFighter(p) then return false end
    if not AimbotSettings.TeamCheck then return true end
    return not isTeammate(p)
end

local enemyCache, lastEnemyUpdate = {}, 0

local function refreshEnemies()
    local l = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and isEnemy(p) then
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then l[#l + 1] = p end
        end
    end
    enemyCache = l
end

local function getEnemiesCached()
    local now = os.clock()
    if now - lastEnemyUpdate > 0.05 then refreshEnemies(); lastEnemyUpdate = now end
    return enemyCache
end

local function getAimTarget(crosshair)
    local lc = LocalPlayer.Character
    if not lc then return nil end
    local lr = lc:FindFirstChild("HumanoidRootPart")
    if not lr then return nil end
    local cam = workspace.CurrentCamera
    if not cam then return nil end

    if lockedTarget then
        local c = lockedTarget.Character
        local part = c and getTargetPart(c)
        local hu = c and c:FindFirstChildOfClass("Humanoid")
        if part and hu and hu.Health > 0 and isEnemy(lockedTarget) then
            local d = (lr.Position - part.Position).Magnitude
            if d <= AimbotSettings.MaxDistance then
                if not AimbotSettings.WallCheck or hasLineOfSight(part) then return part end
            end
        end
        lockedTarget = nil
    end

    local best, bestD = nil, AimbotSettings.FOV
    for _, p in ipairs(getEnemiesCached()) do
        local c = p.Character
        if c then
            local part = getTargetPart(c)
            if part then
                local d3 = (lr.Position - part.Position).Magnitude
                if d3 <= AimbotSettings.MaxDistance then
                    local sp, on = cam:WorldToViewportPoint(part.Position)
                    if on and sp.Z > 0 then
                        local d2 = (Vector2.new(sp.X, sp.Y) - crosshair).Magnitude
                        if d2 <= bestD then
                            if not AimbotSettings.WallCheck or hasLineOfSight(part) then
                                bestD = d2
                                best = p
                            end
                        end
                    end
                end
            end
        end
    end

    if best then
        lockedTarget = best
        return getTargetPart(best.Character)
    end
    return nil
end

local function rotateRigTowards(part)
    if not part or not part.Parent then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local deltaX = part.Position.X - hrp.Position.X
    local deltaZ = part.Position.Z - hrp.Position.Z
    local desiredYaw = math.atan2(-deltaX, -deltaZ)
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
    local dX = screenPos.X - vp.X / 2
    local dY = screenPos.Y - vp.Y / 2
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

local mt = getrawmetatable and getrawmetatable(game)
if mt and setreadonly and hookmetamethod then
    setreadonly(mt, false)
    local oldNamecall = mt.__namecall
    mt.__namecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if silentAimEnabled and not UserInputService:GetFocusedTextBox() then
            if method == "Raycast" and self == workspace then
                local origin, direction, params = ...
                if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                    local curCam = workspace.CurrentCamera
                    local camPos = curCam and curCam.CFrame.Position
                    if camPos and (origin - camPos).Magnitude < 15 then
                        local crosshair = getCrosshairPosition()
                        local target = getAimTarget(crosshair)
                        if target then
                            local dir = target.Position - origin
                            if dir.Magnitude > 0 then
                                local newDir = dir.Unit * direction.Magnitude
                                return oldNamecall(self, origin, newDir, params)
                            end
                        end
                    end
                end
            elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                local crosshair = getCrosshairPosition()
                local target = getAimTarget(crosshair)
                if target then
                    local cam = workspace.CurrentCamera
                    local newRay = Ray.new(cam.CFrame.Position, (target.Position - cam.CFrame.Position).Unit * 1000)
                    return oldNamecall(self, newRay, ...)
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

pcall(function()
    if Drawing then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 2
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Filled = false
        fovCircle.Visible = false
        fovCircle.NumSides = 60
    end
end)

local function healthColor(ratio)
    ratio = math.clamp(ratio, 0, 1)
    if ratio > 0.5 then
        return Color3.new(2 - ratio * 2, 1, 0)
    else
        return Color3.new(1, ratio * 2, 0)
    end
end

local R15_BONES = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
}
local R6_BONES = {
    {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"},
    {"Torso","Left Leg"}, {"Torso","Right Leg"},
}

local ESP = {
    active = false,
    boxes = {}, skeletons = {}, tracers = {}, names = {}, hpbars = {},
    heartbeat = nil, refreshTask = nil,
}

local function newGlowLine(color, coreThickness)
    local glow1 = Drawing.new("Line")
    glow1.Color = color
    glow1.Thickness = coreThickness * 4
    glow1.Transparency = 0.85
    glow1.Visible = false

    local glow2 = Drawing.new("Line")
    glow2.Color = color
    glow2.Thickness = coreThickness * 2
    glow2.Transparency = 0.55
    glow2.Visible = false

    local core = Drawing.new("Line")
    core.Color = Color3.new(1, 1, 1)
    core.Thickness = coreThickness
    core.Transparency = 1
    core.Visible = false

    return { glow1 = glow1, glow2 = glow2, core = core }
end

local function destroyGlowLine(g)
    if not g then return end
    for _, obj in ipairs({ g.glow1, g.glow2, g.core }) do
        if obj and obj.Remove then pcall(obj.Remove, obj) end
    end
end

local function setGlowVisible(g, visible)
    if not g then return end
    g.glow1.Visible = visible
    g.glow2.Visible = visible
    g.core.Visible = visible
end

local function setGlowPoints(g, from, to)
    if not g then return end
    g.glow1.From = from; g.glow1.To = to
    g.glow2.From = from; g.glow2.To = to
    g.core.From = from;  g.core.To = to
end

local function createBox(plr)
    if plr == LocalPlayer or ESP.boxes[plr] then return end
    local box = {
        TL_H = newGlowLine(Color3.new(1, 1, 1), 1.5),
        TL_V = newGlowLine(Color3.new(1, 1, 1), 1.5),
        TR_H = newGlowLine(Color3.new(1, 1, 1), 1.5),
        TR_V = newGlowLine(Color3.new(1, 1, 1), 1.5),
        BL_H = newGlowLine(Color3.new(1, 1, 1), 1.5),
        BL_V = newGlowLine(Color3.new(1, 1, 1), 1.5),
        BR_H = newGlowLine(Color3.new(1, 1, 1), 1.5),
        BR_V = newGlowLine(Color3.new(1, 1, 1), 1.5),
    }
    ESP.boxes[plr] = box
end

local function destroyBox(plr)
    local box = ESP.boxes[plr]
    if not box then return end
    for _, g in pairs(box) do destroyGlowLine(g) end
    ESP.boxes[plr] = nil
end

local function updateBox(plr, cam)
    local box = ESP.boxes[plr]
    if not box then return end
    local char = plr.Character
    if not char then
        for _, g in pairs(box) do setGlowVisible(g, false) end
        return
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        for _, g in pairs(box) do setGlowVisible(g, false) end
        return
    end
    local screen, onScreen = cam:WorldToViewportPoint(root.Position)
    if not onScreen then
        for _, g in pairs(box) do setGlowVisible(g, false) end
        return
    end

    local dist = (root.Position - cam.CFrame.Position).Magnitude
    if dist < 1 then dist = 1 end
    local ppS = (cam.ViewportSize.Y / 2) / (dist * math.tan(math.rad(cam.FieldOfView) / 2))
    local w = 3 * ppS
    local h = 5 * ppS
    local x = screen.X - w / 2
    local y = screen.Y - h / 2
    local c = math.min(w, h) * 0.22

    setGlowPoints(box.TL_H, Vector2.new(x, y), Vector2.new(x + c, y))
    setGlowPoints(box.TL_V, Vector2.new(x, y), Vector2.new(x, y + c))
    setGlowPoints(box.TR_H, Vector2.new(x + w - c, y), Vector2.new(x + w, y))
    setGlowPoints(box.TR_V, Vector2.new(x + w, y), Vector2.new(x + w, y + c))
    setGlowPoints(box.BL_H, Vector2.new(x, y + h), Vector2.new(x + c, y + h))
    setGlowPoints(box.BL_V, Vector2.new(x, y + h - c), Vector2.new(x, y + h))
    setGlowPoints(box.BR_H, Vector2.new(x + w - c, y + h), Vector2.new(x + w, y + h))
    setGlowPoints(box.BR_V, Vector2.new(x + w, y + h - c), Vector2.new(x + w, y + h))

    for _, g in pairs(box) do setGlowVisible(g, true) end
end

local function createSkeleton(plr)
    if plr == LocalPlayer or ESP.skeletons[plr] then return end
    local char = plr.Character
    if not char then return end
    local bones = char:FindFirstChild("UpperTorso") and R15_BONES
              or char:FindFirstChild("Torso") and R6_BONES
    if not bones then return end

    local lines = {}
    for _, bone in ipairs(bones) do
        local g = newGlowLine(Color3.new(1, 1, 1), 1.2)
        table.insert(lines, { g = g, a = bone[1], b = bone[2] })
    end
    ESP.skeletons[plr] = lines
end

local function destroySkeleton(plr)
    local lines = ESP.skeletons[plr]
    if not lines then return end
    for _, l in ipairs(lines) do destroyGlowLine(l.g) end
    ESP.skeletons[plr] = nil
end

local function updateSkeleton(plr, cam)
    local lines = ESP.skeletons[plr]
    if not lines then return end
    local char = plr.Character
    if not char then
        for _, l in ipairs(lines) do setGlowVisible(l.g, false) end
        return
    end
    for _, l in ipairs(lines) do
        local pa = char:FindFirstChild(l.a)
        local pb = char:FindFirstChild(l.b)
        if pa and pb then
            local sa, onA = cam:WorldToViewportPoint(pa.Position)
            local sb, onB = cam:WorldToViewportPoint(pb.Position)
            if onA and onB then
                setGlowPoints(l.g, Vector2.new(sa.X, sa.Y), Vector2.new(sb.X, sb.Y))
                setGlowVisible(l.g, true)
            else
                setGlowVisible(l.g, false)
            end
        else
            setGlowVisible(l.g, false)
        end
    end
end

local function createTracer(plr)
    if plr == LocalPlayer or ESP.tracers[plr] then return end
    ESP.tracers[plr] = newGlowLine(Color3.new(1, 1, 1), 1.2)
end

local function destroyTracer(plr)
    local g = ESP.tracers[plr]
    if g then destroyGlowLine(g); ESP.tracers[plr] = nil end
end

local function updateTracer(plr, cam)
    local g = ESP.tracers[plr]
    if not g then return end
    local char = plr.Character
    if not char then setGlowVisible(g, false); return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then setGlowVisible(g, false); return end
    local sp, on = cam:WorldToViewportPoint(root.Position)
    if not on then setGlowVisible(g, false); return end
    setGlowPoints(g, Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y), Vector2.new(sp.X, sp.Y))
    setGlowVisible(g, true)
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
    local txt = ESP.names[plr]
    if txt and txt.Remove then pcall(txt.Remove, txt) end
    ESP.names[plr] = nil
end

local function updateNameTag(plr, cam)
    local txt = ESP.names[plr]
    if not txt then return end
    local char = plr.Character
    if not char then txt.Visible = false; return end
    local head = char:FindFirstChild("Head")
    if not head then txt.Visible = false; return end
    local sp, on = cam:WorldToViewportPoint(head.Position)
    if not on then txt.Visible = false; return end
    txt.Position = Vector2.new(sp.X, sp.Y - 20)
    txt.Text = plr.DisplayName
    txt.Visible = true
end

local function createHealthBar(plr)
    if plr == LocalPlayer or ESP.hpbars[plr] then return end
    local bg = Drawing.new("Line")
    bg.Color = Color3.fromRGB(20, 20, 20)
    bg.Thickness = 3
    bg.Transparency = 0.5
    bg.Visible = false
    local fill = Drawing.new("Line")
    fill.Color = Color3.fromRGB(0, 255, 100)
    fill.Thickness = 3
    fill.Transparency = 1
    fill.Visible = false
    ESP.hpbars[plr] = { bg = bg, fill = fill }
end

local function destroyHealthBar(plr)
    local hb = ESP.hpbars[plr]
    if hb then
        if hb.bg.Remove then pcall(hb.bg.Remove, hb.bg) end
        if hb.fill.Remove then pcall(hb.fill.Remove, hb.fill) end
        ESP.hpbars[plr] = nil
    end
end

local function updateHealthBar(plr, cam)
    local hb = ESP.hpbars[plr]
    if not hb then return end
    local char = plr.Character
    if not char then hb.bg.Visible = false; hb.fill.Visible = false; return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.MaxHealth <= 0 then
        hb.bg.Visible = false; hb.fill.Visible = false; return
    end
    local screen, on = cam:WorldToViewportPoint(root.Position)
    if not on then hb.bg.Visible = false; hb.fill.Visible = false; return end
    local dist = (root.Position - cam.CFrame.Position).Magnitude
    if dist < 1 then dist = 1 end
    local ppS = (cam.ViewportSize.Y / 2) / (dist * math.tan(math.rad(cam.FieldOfView) / 2))
    local barH = 5 * ppS * 0.7
    local x = screen.X - (3 * ppS) / 2 - 6
    local yTop = screen.Y - barH / 2
    local yBot = screen.Y + barH / 2

    hb.bg.From = Vector2.new(x, yTop)
    hb.bg.To   = Vector2.new(x, yBot)
    hb.bg.Visible = true

    local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
    local yFill = yBot - (yBot - yTop) * ratio
    hb.fill.From = Vector2.new(x, yFill)
    hb.fill.To   = Vector2.new(x, yBot)
    hb.fill.Color = healthColor(ratio)
    hb.fill.Visible = true
end

local function syncESP()
    if not ESP.active then return end
    local active = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        active[plr] = true
        if plr ~= LocalPlayer and isActiveFighter(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local alive = char and hum and hum.Health > 0

            if alive then
                if VisualSettings.RivalsESP then
                    if not ESP.boxes[plr] then createBox(plr) end
                else
                    destroyBox(plr)
                end
                if VisualSettings.Skeleton then
                    if not ESP.skeletons[plr] then createSkeleton(plr) end
                else
                    destroySkeleton(plr)
                end
                if VisualSettings.Tracers then
                    if not ESP.tracers[plr] then createTracer(plr) end
                else
                    destroyTracer(plr)
                end
                if VisualSettings.NameTags then
                    if not ESP.names[plr] then createNameTag(plr) end
                else
                    destroyNameTag(plr)
                end
                if VisualSettings.HealthBar then
                    if not ESP.hpbars[plr] then createHealthBar(plr) end
                else
                    destroyHealthBar(plr)
                end
            else
                destroyBox(plr); destroySkeleton(plr); destroyTracer(plr)
                destroyNameTag(plr); destroyHealthBar(plr)
            end
        else
            destroyBox(plr); destroySkeleton(plr); destroyTracer(plr)
            destroyNameTag(plr); destroyHealthBar(plr)
        end
    end
    for plr in pairs(ESP.boxes) do if not active[plr] then destroyBox(plr) end end
    for plr in pairs(ESP.skeletons) do if not active[plr] then destroySkeleton(plr) end end
    for plr in pairs(ESP.tracers) do if not active[plr] then destroyTracer(plr) end end
    for plr in pairs(ESP.names) do if not active[plr] then destroyNameTag(plr) end end
    for plr in pairs(ESP.hpbars) do if not active[plr] then destroyHealthBar(plr) end end
end

local function startESP()
    if ESP.active then return end
    ESP.active = true
    syncESP()
    if not ESP.heartbeat then
        ESP.heartbeat = RunService.RenderStepped:Connect(function()
            if not ESP.active then return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            syncESP()
            for plr in pairs(ESP.boxes) do updateBox(plr, cam) end
            for plr in pairs(ESP.skeletons) do updateSkeleton(plr, cam) end
            for plr in pairs(ESP.tracers) do updateTracer(plr, cam) end
            for plr in pairs(ESP.names) do updateNameTag(plr, cam) end
            for plr in pairs(ESP.hpbars) do updateHealthBar(plr, cam) end
        end)
    end
    if not ESP.refreshTask then
        ESP.refreshTask = task.spawn(function()
            while ESP.active do
                task.wait(0.5)
                if ESP.active then syncESP() end
            end
            ESP.refreshTask = nil
        end)
    end
end

local function stopESP()
    ESP.active = false
    if ESP.refreshTask then pcall(task.cancel, ESP.refreshTask); ESP.refreshTask = nil end
    if ESP.heartbeat then ESP.heartbeat:Disconnect(); ESP.heartbeat = nil end
    for plr in pairs(ESP.boxes) do destroyBox(plr) end
    for plr in pairs(ESP.skeletons) do destroySkeleton(plr) end
    for plr in pairs(ESP.tracers) do destroyTracer(plr) end
    for plr in pairs(ESP.names) do destroyNameTag(plr) end
    for plr in pairs(ESP.hpbars) do destroyHealthBar(plr) end
    ESP.boxes = {}; ESP.skeletons = {}; ESP.tracers = {}; ESP.names = {}; ESP.hpbars = {}
end

local function anyVisualOn()
    return VisualSettings.RivalsESP or VisualSettings.Skeleton
        or VisualSettings.Tracers or VisualSettings.NameTags
        or VisualSettings.HealthBar
end

local function refreshESPState()
    if anyVisualOn() then
        if not ESP.active then startESP() end
    else
        if ESP.active then stopESP() end
    end
end

-- ============================================================
-- FULL OPTIMIZED (FFlags)
-- ============================================================
local FULL_OPTIMIZED_FLAGS = {
    -- Renderizado
    ["DFIntCSGLevelOfDetailSwitchingDistance"] = "0",
    ["DFIntCSGLevelOfDetailSwitchingDistanceL12"] = "0",
    ["DFIntCSGLevelOfDetailSwitchingDistanceL23"] = "0",
    ["DFIntCSGLevelOfDetailSwitchingDistanceL34"] = "0",
    ["DFIntDebugFRMQualityLevelOverride"] = "1",
    ["FFlagDebugGraphicsPreferD3D11"] = "True",
    ["FFlagDebugSkyGray"] = "True",
    ["DFFlagDebugRenderForceTechnologyVoxel"] = "True",
    ["FIntRenderShadowIntensity"] = "0",
    ["FFlagDisablePostFx"] = "True",
    ["FIntDebugForceMSAASamples"] = "0",
    ["FIntFRMMinGrassDistance"] = "0",
    ["FIntFRMMaxGrassDistance"] = "0",
    ["FIntRenderGrassDetailStrands"] = "0",
    ["FIntRenderGrassHeightScaler"] = "0",
    -- Texturas
    ["DFFlagTextureQualityOverrideEnabled"] = "True",
    ["DFIntTextureQualityOverride"] = "0",
    ["FIntDebugTextureManagerSkipMips"] = "8",
    ["DFIntTextureCompositorActiveJobs"] = "0",
    -- FPS / Scheduler
    ["DFIntTaskSchedulerTargetFps"] = "999999",
    ["FFlagTaskSchedulerLimitTargetFpsTo2402"] = "False",
    -- Telemetría / Red
    ["FFlagDebugDisableTelemetryEventIngest"] = "True",
    ["FFlagDebugDisableTelemetryPoint"] = "True",
    ["FFlagDebugDisableTelemetryEphemeralCounter"] = "True",
    ["FFlagDebugDisableTelemetryV2Stat"] = "True",
    ["FFlagDebugDisableTelemetryV2Counter"] = "True",
    ["DFStringTelemetryV2Url"] = "null",
    ["DFStringTelegrafHTTPTransportUrl"] = "null",
    ["DFStringRobloxAnalyticsURL"] = "null",
    ["FLogNetwork"] = "7",
    -- Misc
    ["DFFlagDebugPauseVoxelizer"] = "True",
    ["FFlagHandleAltEnterFullscreenManually"] = "False",
    ["FIntFullscreenTitleBarTriggerDelayMillis"] = "3600000",
}

local function applyFullOptimized()
    if not setfflag then
        API:Notify("setfflag no disponible en este executor")
        return false
    end
    local ok = 0
    for flag, value in pairs(FULL_OPTIMIZED_FLAGS) do
        local success = pcall(setfflag, flag, value)
        if success then ok = ok + 1 end
    end
    API:Notify(string.format("Full Optimized aplicado (%d/%d flags)", ok, #FULL_OPTIMIZED_FLAGS))
    return true
end

-- ============================================================
-- FLY
-- ============================================================
local function startFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, o in ipairs(hrp:GetChildren()) do
        if o.Name == "HH_Fly" then o:Destroy() end
    end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "HH_Fly"
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    local bg = Instance.new("BodyGyro")
    bg.Name = "HH_Fly"
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
                if o.Name == "HH_Fly" then o:Destroy() end
            end
        end
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
end

-- ============================================================
-- UI
-- ============================================================
local win = API:CreateWindow("Happy Hub", "Rivals · Keyless · by replicatedman")
if not win then return end

local homeTab       = win:CreateTab("Home",       API.Icons.Home   or "rbxassetid://109951566071454")
local aimbotTab     = win:CreateTab("Aimbot",     API.Icons.Combat or "rbxassetid://93310349660228")
local visualsTab    = win:CreateTab("Visuals",    "rbxassetid://13321848320")
local playerListTab = win:CreateTab("PlayerList", API.Icons.User   or "rbxassetid://122086195900803")
local miscTab       = win:CreateTab("Misc",       API.Icons.Misc   or "rbxassetid://109962716823639")

local aimbotToggleRef, espToggleRef
local silentAimRef, fovRef, smoothingRef, maxDistRef
local wallCheckRef, teamCheckRef, showFovRef, targetDropRef
local triggerBotRef, triggerRangeRef, autoFireRef
local nameTagsRef, tracersRef, skeletonRef, healthBarRef
local infJumpRef, noclipRef, godRef, antiAFKRef, flyRef, flySpeedRef, fullOptimizedRef

win:CreateImageCard(homeTab, {
    Image = "rbxthumb://type=Asset&id=" .. game.PlaceId .. "&w=420&h=420",
    Title = "Keyless · free hub",
    Subtitle = "by replicatedscripts",
    Description = "Enjoy the free features.",
    Height = 140,
    ImageWidth = 120,
})

win:CreateLabel(aimbotTab, "Aimbot Settings")

aimbotToggleRef = win:CreateToggle(aimbotTab, "Enabled [T]", AimbotSettings.Enabled, function(v)
    AimbotSettings.Enabled = v
    local hum = getHumanoid()
    if not v then
        lockedTarget = nil
        if hum then hum.AutoRotate = true end
    else
        if hum then hum.AutoRotate = false end
    end
    API:Notify(v and "Aimbot enabled" or "Aimbot disabled")
end)

silentAimRef = win:CreateToggle(aimbotTab, "Silent Aim", AimbotSettings.SilentAim, function(v)
    AimbotSettings.SilentAim = v
    silentAimEnabled = v
    API:Notify(v and "Silent Aim on" or "Silent Aim off")
end)

fovRef = win:CreateSlider(aimbotTab, "FOV", 20, 800, AimbotSettings.FOV, function(v) AimbotSettings.FOV = v end)
smoothingRef = win:CreateSlider(aimbotTab, "Smoothing", 0.05, 1, AimbotSettings.Smoothing, function(v) AimbotSettings.Smoothing = v end)
maxDistRef = win:CreateSlider(aimbotTab, "Max Distance", 100, 2000, AimbotSettings.MaxDistance, function(v) AimbotSettings.MaxDistance = v end)

wallCheckRef = win:CreateToggle(aimbotTab, "Wall Check", AimbotSettings.WallCheck, function(v) AimbotSettings.WallCheck = v end)
teamCheckRef = win:CreateToggle(aimbotTab, "Team Check", AimbotSettings.TeamCheck, function(v) AimbotSettings.TeamCheck = v end)
showFovRef = win:CreateToggle(aimbotTab, "Show FOV Circle", AimbotSettings.ShowFOV, function(v) AimbotSettings.ShowFOV = v end)

targetDropRef = win:CreateDropdown(aimbotTab, "Target", { "Head", "Torso", "Random" }, "Head", function(sel)
    AimbotSettings.Target = sel
    API:Notify("Target: " .. sel)
end)

win:CreateLabel(aimbotTab, "Trigger Bot Settings")

triggerBotRef = win:CreateToggle(aimbotTab, "Trigger Bot", AimbotSettings.TriggerBot, function(v)
    AimbotSettings.TriggerBot = v
    if triggerBotConn then triggerBotConn:Disconnect(); triggerBotConn = nil end
    if v then
        triggerBotConn = RunService.RenderStepped:Connect(function()
            if not AimbotSettings.TriggerBot then return end
            local crosshair = getCrosshairPosition()
            local target = getAimTarget(crosshair)
            if not target then return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            local sp, on = cam:WorldToViewportPoint(target.Position)
            if not on then return end
            local mouse = UserInputService:GetMouseLocation()
            if (Vector2.new(sp.X, sp.Y) - mouse).Magnitude < AimbotSettings.TriggerRange then
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.03)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end)
            end
        end)
    end
end)

triggerRangeRef = win:CreateSlider(aimbotTab, "Trigger Range", 20, 400, AimbotSettings.TriggerRange, function(v) AimbotSettings.TriggerRange = v end)

autoFireRef = win:CreateToggle(aimbotTab, "Auto Fire", AimbotSettings.AutoFire, function(v)
    AimbotSettings.AutoFire = v
    if autoFireConn then autoFireConn:Disconnect(); autoFireConn = nil end
    if v then
        autoFireConn = RunService.RenderStepped:Connect(function()
            if not AimbotSettings.AutoFire then return end
            local crosshair = getCrosshairPosition()
            local target = getAimTarget(crosshair)
            if not target then return end
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end)
    end
end)

win:CreateLabel(visualsTab, "Visual Settings")

espToggleRef = win:CreateToggle(visualsTab, "Rivals ESP [O]", VisualSettings.RivalsESP, function(v)
    VisualSettings.RivalsESP = v
    refreshESPState()
    API:Notify(v and "ESP enabled" or "ESP disabled")
end)

nameTagsRef = win:CreateToggle(visualsTab, "Name Tags", VisualSettings.NameTags, function(v)
    VisualSettings.NameTags = v
    refreshESPState()
end)

tracersRef = win:CreateToggle(visualsTab, "Tracers", VisualSettings.Tracers, function(v)
    VisualSettings.Tracers = v
    refreshESPState()
end)

skeletonRef = win:CreateToggle(visualsTab, "Skeleton R15", VisualSettings.Skeleton, function(v)
    VisualSettings.Skeleton = v
    refreshESPState()
end)

healthBarRef = win:CreateToggle(visualsTab, "Health Bar", VisualSettings.HealthBar, function(v)
    VisualSettings.HealthBar = v
    refreshESPState()
end)

win:CreateLabel(miscTab, "Movement")

flyRef = win:CreateToggle(miscTab, "Fly", MovementSettings.Fly, function(v)
    MovementSettings.Fly = v
    if v then startFly(); API:Notify("Fly enabled") else stopFly(); API:Notify("Fly disabled") end
end)

flySpeedRef = win:CreateSlider(miscTab, "Fly Speed", 10, 500, MovementSettings.FlySpeed, function(v)
    MovementSettings.FlySpeed = v
    flyState.speed = v
end)

infJumpRef = win:CreateToggle(miscTab, "Infinite Jump", MiscSettings.InfJump, function(v)
    MiscSettings.InfJump = v
    API:Notify(v and "Infinite Jump enabled" or "Infinite Jump disabled")
end)

noclipRef = win:CreateToggle(miscTab, "Noclip", MovementSettings.Noclip, function(v)
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

godRef = win:CreateToggle(miscTab, "God Mode", MovementSettings.God, function(v)
    MovementSettings.God = v
    if godConn then godConn:Disconnect(); godConn = nil end
    if v then
        godConn = RunService.Heartbeat:Connect(function()
            local hum = getHumanoid()
            if hum then hum.Health = hum.MaxHealth end
        end)
    end
end)

antiAFKRef = win:CreateToggle(miscTab, "Anti-AFK", MiscSettings.AntiAFK, function(v)
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

win:CreateLabel(miscTab, "Performance")

fullOptimizedRef = win:CreateToggle(miscTab, "Full Optimized (FFlags)", false, function(v)
    MiscSettings.FullOptimized = v
    if v then
        applyFullOptimized()
    else
        API:Notify("Reinicia el cliente para revertir FFlags")
    end
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

-- ============================================================
-- PLAYER LIST
-- ============================================================
local playerInfoContainer = Instance.new("Frame")
playerInfoContainer.Name = "PlayerInfoContainer"
playerInfoContainer.Size = UDim2.new(1, -40, 0, 0)
playerInfoContainer.AutomaticSize = Enum.AutomaticSize.Y
playerInfoContainer.BackgroundTransparency = 1
playerInfoContainer.Position = UDim2.new(0, 20, 0, 20)
playerInfoContainer.Parent = playerListTab.Content

local infoLayout = Instance.new("UIListLayout")
infoLayout.Padding = UDim.new(0, 6)
infoLayout.SortOrder = Enum.SortOrder.LayoutOrder
infoLayout.Parent = playerInfoContainer

local playerRows = {}

local function buildRow(plr)
    local row = Instance.new("Frame")
    row.Name = "Row_" .. plr.Name
    row.Size = UDim2.new(1, 0, 0, 62)
    row.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    row.BackgroundTransparency = 0.15
    row.BorderSizePixel = 0
    row.Parent = playerInfoContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row

    local avatar = Instance.new("Frame")
    avatar.Size = UDim2.fromOffset(38, 38)
    avatar.Position = UDim2.new(0, 10, 0.5, -19)
    avatar.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
    avatar.BackgroundTransparency = 0.7
    avatar.BorderSizePixel = 0
    avatar.Parent = row

    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(0, 19)
    ac.Parent = avatar

    local img = Instance.new("ImageLabel")
    img.Name = "Avatar"
    img.Size = UDim2.new(1, -4, 1, -4)
    img.Position = UDim2.new(0, 2, 0, 2)
    img.BackgroundTransparency = 1
    img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=150&h=150"
    img.ScaleType = Enum.ScaleType.Fit
    img.Parent = avatar

    local ic = Instance.new("UICorner")
    ic.CornerRadius = UDim.new(0, 19)
    ic.Parent = img

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.Size = UDim2.new(1, -70, 0, 16)
    nameLbl.Position = UDim2.new(0, 58, 0, 10)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.Font = Enum.Font.GothamSemibold
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = row

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Name = "Info"
    infoLbl.Size = UDim2.new(1, -70, 0, 14)
    infoLbl.Position = UDim2.new(0, 58, 0, 28)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = ""
    infoLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
    infoLbl.Font = Enum.Font.Gotham
    infoLbl.TextSize = 10
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
    infoLbl.Parent = row

    local badge = Instance.new("TextLabel")
    badge.Name = "Badge"
    badge.Size = UDim2.fromOffset(70, 18)
    badge.Position = UDim2.new(1, -78, 0, 8)
    badge.BackgroundTransparency = 1
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 10
    badge.Text = ""
    badge.TextXAlignment = Enum.TextXAlignment.Right
    badge.Parent = row

    return { row = row, avatar = avatar, name = nameLbl, info = infoLbl, badge = badge }
end

local function updateRow(refs, plr, myHRP)
    refs.name.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
    local dist, hp, maxHp = 0, 0, 100
    if plr.Character then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then hp = math.floor(hum.Health); maxHp = math.floor(hum.MaxHealth) end
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp and myHRP then dist = (myHRP.Position - hrp.Position).Magnitude end
    end
    local team = plr.Team and plr.Team.Name or "No Team"
    refs.info.Text = string.format("%.0fm · %d/%d HP · %s", dist, hp, maxHp, team)

    if plr == LocalPlayer then
        refs.badge.Text = "You"
        refs.badge.TextColor3 = Color3.fromRGB(0, 255, 100)
    elseif isTeammate(plr) then
        refs.badge.Text = "Ally"
        refs.badge.TextColor3 = Color3.fromRGB(60, 160, 255)
    elseif isActiveFighter(plr) then
        refs.badge.Text = "Enemy"
        refs.badge.TextColor3 = Color3.fromRGB(255, 60, 60)
    else
        refs.badge.Text = "Lobby"
        refs.badge.TextColor3 = Color3.fromRGB(140, 140, 140)
    end
end

local function refreshPlayerList()
    local current = {}
    for _, p in ipairs(Players:GetPlayers()) do current[p] = true end
    for p, refs in pairs(playerRows) do
        if not current[p] then
            if refs.row and refs.row.Parent then refs.row:Destroy() end
            playerRows[p] = nil
        end
    end
    local myHRP = getHRP()
    for idx, plr in ipairs(Players:GetPlayers()) do
        local refs = playerRows[plr]
        if not refs then
            refs = buildRow(plr)
            playerRows[plr] = refs
        end
        refs.row.LayoutOrder = idx
        updateRow(refs, plr, myHRP)
    end
end

refreshPlayerList()

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        refreshPlayerList()
    end)
    task.wait(0.2)
    refreshPlayerList()
end)

Players.PlayerRemoving:Connect(function(plr)
    destroyBox(plr)
    destroySkeleton(plr)
    destroyTracer(plr)
    destroyNameTag(plr)
    destroyHealthBar(plr)
    task.wait(0.1)
    refreshPlayerList()
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        plr.CharacterAdded:Connect(function()
            task.wait(0.3)
            refreshPlayerList()
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(refreshPlayerList)
    end
end)

-- ============================================================
-- KEYBINDS
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.T then
        if aimbotToggleRef then
            aimbotToggleRef:SetState(not AimbotSettings.Enabled)
        end
    elseif input.KeyCode == Enum.KeyCode.O then
        if espToggleRef then
            espToggleRef:SetState(not VisualSettings.RivalsESP)
        end
    end
end)

if isMobile then
    win:AddMobileButton({
        Icon = "rbxassetid://93310349660228",
        Tooltip = "Toggle Aimbot",
        OnClick = function()
            if aimbotToggleRef then aimbotToggleRef:SetState(not AimbotSettings.Enabled) end
        end,
    })
    win:AddMobileButton({
        Icon = "rbxassetid://13321848320",
        Tooltip = "Toggle ESP",
        OnClick = function()
            if espToggleRef then espToggleRef:SetState(not VisualSettings.RivalsESP) end
        end,
    })
    win:AddMobileButton({
        Icon = "rbxassetid://115558082558028",
        Tooltip = "Toggle UI",
        OnClick = function() win:ToggleUI() end,
    })
end

-- ============================================================
-- CHARACTER HOOKS
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function(char)
    lockedTarget = nil
    rayParams.FilterDescendantsInstances = {}
    silentAimEnabled = AimbotSettings.SilentAim
    local hum = char:WaitForChild("Humanoid", 3)
    if hum and AimbotSettings.Enabled then hum.AutoRotate = false end
    task.wait(0.1)
    rebuildRayFilter()
    refreshPlayerList()
end)

LocalPlayer.CharacterRemoving:Connect(function()
    lockedTarget = nil
    rayParams.FilterDescendantsInstances = {}
    stopFly()
end)

-- ============================================================
-- RENDER LOOP
-- ============================================================
local frameCounter = 0

local function onRenderStep()
    Camera = workspace.CurrentCamera
    if not Camera then return end
    frameCounter = frameCounter + 1
    if frameCounter % 5 == 0 then rebuildRayFilter() end
    if not LocalPlayer.Character then
        if fovCircle then fovCircle.Visible = false end
        return
    end
    local crosshair = getCrosshairPosition()
    if fovCircle then
        if AimbotSettings.Enabled and AimbotSettings.ShowFOV then
            fovCircle.Position = crosshair
            fovCircle.Radius = AimbotSettings.FOV
            fovCircle.Color = Color3.fromRGB(255, 255, 255)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
    if AimbotSettings.Enabled then
        local targetPart = getAimTarget(crosshair)
        if targetPart then aimViaMouse(targetPart) end
    else
        lockedTarget = nil
    end
end

RunService:BindToRenderStep("HappyHub", Enum.RenderPriority.Camera.Value + 1, onRenderStep)

-- ============================================================
-- CONFIG
-- ============================================================
win:SetConfigSnapshot(function()
    return {
        AimEnabled   = aimbotToggleRef:GetState(),
        SilentAim    = silentAimRef:GetState(),
        FOV          = fovRef:GetValue(),
        Smoothing    = smoothingRef:GetValue(),
        MaxDistance  = maxDistRef:GetValue(),
        WallCheck    = wallCheckRef:GetState(),
        TeamCheck    = teamCheckRef:GetState(),
        ShowFOV      = showFovRef:GetState(),
        Target       = targetDropRef:GetValue(),
        TriggerBot   = triggerBotRef:GetState(),
        TriggerRange = triggerRangeRef:GetValue(),
        AutoFire     = autoFireRef:GetState(),
        RivalsESP    = espToggleRef:GetState(),
        NameTags     = nameTagsRef:GetState(),
        Tracers      = tracersRef:GetState(),
        Skeleton     = skeletonRef:GetState(),
        HealthBar    = healthBarRef:GetState(),
        InfJump      = infJumpRef:GetState(),
        Noclip       = noclipRef:GetState(),
        God          = godRef:GetState(),
        AntiAFK      = antiAFKRef:GetState(),
        Fly          = flyRef:GetState(),
        FlySpeed     = flySpeedRef:GetValue(),
        FullOptimized = fullOptimizedRef:GetState(),
        Theme        = API:GetTheme(),
    }
end)

win:SetConfigApply(function(d)
    if not d then return end
    if d.Theme then API:SetTheme(d.Theme) end
    if d.AimEnabled   ~= nil and aimbotToggleRef   then aimbotToggleRef:SetState(d.AimEnabled, true) end
    if d.SilentAim    ~= nil and silentAimRef      then silentAimRef:SetState(d.SilentAim, true) end
    if d.FOV          then fovRef:SetValue(d.FOV) end
    if d.Smoothing    then smoothingRef:SetValue(d.Smoothing) end
    if d.MaxDistance  then maxDistRef:SetValue(d.MaxDistance) end
    if d.WallCheck    ~= nil and wallCheckRef      then wallCheckRef:SetState(d.WallCheck, true) end
    if d.TeamCheck    ~= nil and teamCheckRef      then teamCheckRef:SetState(d.TeamCheck, true) end
    if d.ShowFOV      ~= nil and showFovRef        then showFovRef:SetState(d.ShowFOV, true) end
    if d.Target       then targetDropRef:SetValue(d.Target) end
    if d.TriggerBot   ~= nil and triggerBotRef     then triggerBotRef:SetState(d.TriggerBot, true) end
    if d.TriggerRange then triggerRangeRef:SetValue(d.TriggerRange) end
    if d.AutoFire     ~= nil and autoFireRef       then autoFireRef:SetState(d.AutoFire, true) end
    if d.RivalsESP    ~= nil and espToggleRef      then espToggleRef:SetState(d.RivalsESP, true) end
    if d.NameTags     ~= nil and nameTagsRef       then nameTagsRef:SetState(d.NameTags, true) end
    if d.Tracers      ~= nil and tracersRef        then tracersRef:SetState(d.Tracers, true) end
    if d.Skeleton     ~= nil and skeletonRef       then skeletonRef:SetState(d.Skeleton, true) end
    if d.HealthBar    ~= nil and healthBarRef      then healthBarRef:SetState(d.HealthBar, true) end
    if d.InfJump      ~= nil and infJumpRef        then infJumpRef:SetState(d.InfJump, true) end
    if d.Noclip       ~= nil and noclipRef         then noclipRef:SetState(d.Noclip, true) end
    if d.God          ~= nil and godRef            then godRef:SetState(d.God, true) end
    if d.AntiAFK      ~= nil and antiAFKRef        then antiAFKRef:SetState(d.AntiAFK, true) end
    if d.Fly          ~= nil and flyRef            then flyRef:SetState(d.Fly, true) end
    if d.FlySpeed     then flySpeedRef:SetValue(d.FlySpeed) end
    if d.FullOptimized ~= nil and fullOptimizedRef then fullOptimizedRef:SetState(d.FullOptimized, true) end
end)

win:BuildConfigPage()

API:Notify("Hello " .. LocalPlayer.DisplayName)
