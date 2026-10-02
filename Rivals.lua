local API = loadstring(game:HttpGet("https://raw.githubusercontent.com/overthcode2011-stack/HHB-MM2-/refs/heads/main/template.lua"))()

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local mousemoverel = mousemoverel or MouseMoveRel or (syn and syn.mousemoverel) or (fluxus and fluxus.mousemoverel)

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local AimbotSettings = {
    Enabled = false, SilentAim = false, FOV = 150, Smoothing = 0.35,
    WallCheck = false, MaxDistance = 150, Target = "Head", ShowFOV = false,
    TeamCheck = false, RotateRig = true, TriggerBot = false, TriggerRange = 150, AutoFire = false,
    MatchOnly = true,
}
local VisualSettings = { RivalsESP = false, NameTags = false }
local MiscSettings = { InfJump = false, AntiAFK = false }
local MovementSettings = { Noclip = false, God = false }

local lockedTarget = nil
local silentAimEnabled = false
local noclipConn, godConn, antiAFKConn = nil, nil, nil
local triggerBotConn = nil
local autoFireConn = nil
local fovCircle = nil

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
        if value:IsA("Player") then
            markActive(value.Name)
        end
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
                for _, a in ipairs({ ... }) do
                    walkForPlayers(a)
                end
            end)
        end
    end

    local fighter = rep:FindFirstChild("Fighter")
    if fighter then
        local ev = fighter:FindFirstChild("UpdateCameraRotations")
        if ev then
            ev.OnClientEvent:Connect(function(...)
                for _, a in ipairs({ ... }) do
                    walkForPlayers(a)
                end
            end)
        end
    end
end)

local function isActiveFighter(p)
    if not p then return false end
    local t = activeFighters[p.Name]
    if not t then return false end
    if os.clock() - t > 30 then
        activeFighters[p.Name] = nil
        return false
    end
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
    if not part or not Camera then return false end
    local cp = Camera.CFrame.Position
    local off = part.Position - cp
    local d = off.Magnitude
    if d <= 0 then return false end
    local hit = workspace:Raycast(cp, off.Unit * d, rayParams)
    if not hit then return true end
    return hit.Instance and (hit.Instance:IsDescendantOf(part.Parent) or hit.Instance == part)
end

local function getCrosshairPosition()
    if not Camera then return Vector2.new(0, 0) end
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function getTargetPart(character)
    if not character then return nil end
    if AimbotSettings.Target == "Head" then
        return character:FindFirstChild("Head")
    elseif AimbotSettings.Target == "Torso" then
        return character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
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
        if isTeamName(n) then
            local r = normalizeTeam(v)
            if r then return r end
        end
    end
end

local function getTeamVal(c)
    if not c then return nil end
    for _, o in ipairs(c:GetChildren()) do
        if isTeamName(o.Name) then
            local r = normalizeTeam(o.Value)
            if r then return r end
        end
    end
end

local function getTeamSig(p)
    if not p then return nil end
    local now = os.clock()
    if teamCache[p] ~= nil and teamCacheTime[p] and now - teamCacheTime[p] < 0.25 then
        return teamCache[p]
    end
    local s = p.Team or getTeamAttr(p) or getTeamVal(p)
        or (p.Character and getTeamAttr(p.Character))
        or (p.Character and getTeamVal(p.Character))
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
    if AimbotSettings.MatchOnly and not isActiveFighter(p) then return false end
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
    if now - lastEnemyUpdate > 0.05 then
        refreshEnemies()
        lastEnemyUpdate = now
    end
    return enemyCache
end

local function getAimTarget(crosshair)
    local lc = LocalPlayer.Character
    if not lc then return nil end
    local lr = lc:FindFirstChild("HumanoidRootPart")
    if not lr then return nil end

    if lockedTarget then
        local c = lockedTarget.Character
        local part = c and getTargetPart(c)
        local hu = c and c:FindFirstChildOfClass("Humanoid")
        if part and hu and hu.Health > 0 and isEnemy(lockedTarget) then
            local d = (lr.Position - part.Position).Magnitude
            if d <= AimbotSettings.MaxDistance then
                if not AimbotSettings.WallCheck or hasLineOfSight(part) then
                    return part
                end
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
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
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
    if not AimbotSettings.RotateRig then return end
    if not part or not part.Parent then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local myPos = hrp.Position
    local targetPos = part.Position
    local deltaX = targetPos.X - myPos.X
    local deltaZ = targetPos.Z - myPos.Z
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
    local camera = workspace.CurrentCamera
    if not camera then return end
    local screenPos = camera:WorldToViewportPoint(part.Position)
    if not screenPos then return end
    local vp = camera.ViewportSize
    local centerX = vp.X / 2
    local centerY = vp.Y / 2
    local deltaX = screenPos.X - centerX
    local deltaY = screenPos.Y - centerY
    local dist = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    if dist < 1 then return end
    local smooth = AimbotSettings.Smoothing
    if smooth <= 0 then smooth = 1 end
    local moveX = deltaX * smooth
    local moveY = deltaY * smooth
    if dist > 200 then
        moveX = moveX * 0.7
        moveY = moveY * 0.7
    end
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
                    local camPos = Camera and Camera.CFrame.Position
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
        fovCircle.Color = Color3.fromRGB(0, 255, 63)
        fovCircle.Filled = false
        fovCircle.Visible = false
        fovCircle.NumSides = 60
    end
end)

local ESP_COLORS = {
    Enemy = Color3.fromRGB(255, 60, 60),
    Ally = Color3.fromRGB(60, 160, 255),
    Self = Color3.fromRGB(0, 255, 63),
}

local function getRivalsESPColor(plr)
    if plr == LocalPlayer then return ESP_COLORS.Self end
    if isTeammate(plr) then return ESP_COLORS.Ally end
    return ESP_COLORS.Enemy
end

local RivalsESP = {
    active = false, boxes = {}, updaters = {}, heartbeat = nil, refreshThread = nil,
}

local function clearRivalsBox(plr)
    local data = RivalsESP.boxes[plr]
    if data then
        if data.bb and data.bb.Parent then data.bb:Destroy() end
        RivalsESP.boxes[plr] = nil
    end
    RivalsESP.updaters[plr] = nil
end

local function applyBoxColor(data, color)
    for _, l in ipairs(data.lines) do
        if l and l.Parent then l.BackgroundColor3 = color end
    end
    if data.nameTag and data.nameTag.Parent then
        data.nameTag.TextColor3 = color
    end
end

local function createRivalsBox(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local color = getRivalsESPColor(plr)

    local bb = Instance.new("BillboardGui")
    bb.Name = "HappyHub_Box"
    bb.AlwaysOnTop = true
    bb.Adornee = hrp
    bb.LightInfluence = 0
    bb.ResetOnSpawn = false
    bb.Size = UDim2.fromOffset(60, 100)
    bb.Parent = hrp

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.Size = UDim2.new(1, 0, 1, 0)
    box.Parent = bb

    local t = 2

    local function makeLine(n, size, pos)
        local l = Instance.new("Frame")
        l.Name = n
        l.Size = size
        l.Position = pos
        l.BackgroundColor3 = color
        l.BorderSizePixel = 0
        l.Parent = box
        return l
    end

    local top = makeLine("Top", UDim2.new(1, 0, 0, t), UDim2.new(0, 0, 0, 0))
    local bottom = makeLine("Bottom", UDim2.new(1, 0, 0, t), UDim2.new(0, 0, 1, -t))
    local left = makeLine("Left", UDim2.new(0, t, 1, 0), UDim2.new(0, 0, 0, 0))
    local right = makeLine("Right", UDim2.new(0, t, 1, 0), UDim2.new(1, -t, 0, 0))

    local nameTag = nil
    if VisualSettings.NameTags then
        nameTag = Instance.new("TextLabel")
        nameTag.Name = "NameTag"
        nameTag.Size = UDim2.new(1, 0, 0, 14)
        nameTag.Position = UDim2.new(0, 0, 1, 3)
        nameTag.BackgroundTransparency = 1
        nameTag.TextColor3 = color
        nameTag.Font = Enum.Font.GothamBold
        nameTag.TextSize = 12
        nameTag.TextStrokeTransparency = 0.4
        nameTag.TextStrokeColor3 = Color3.new(0, 0, 0)
        nameTag.Text = plr.DisplayName
        nameTag.Parent = bb
    end

    RivalsESP.boxes[plr] = {
        bb = bb,
        box = box,
        lines = { top, bottom, left, right },
        nameTag = nameTag,
    }

    local function updateSize()
        local data = RivalsESP.boxes[plr]
        if not data or not data.bb or not data.bb.Parent then
            RivalsESP.updaters[plr] = nil
            return
        end
        local c = plr.Character
        if not c then return end
        local root = c:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local dist = (root.Position - cam.CFrame.Position).Magnitude
        if dist < 1 then dist = 1 end
        local vpY = cam.ViewportSize.Y
        local fovRad = math.rad(cam.FieldOfView)
        local pixelsPerStud = (vpY / 2) / (dist * math.tan(fovRad / 2))
        local pixW = 3 * pixelsPerStud
        local pixH = 5 * pixelsPerStud
        data.bb.Size = UDim2.fromOffset(pixW, pixH)
    end

    RivalsESP.updaters[plr] = updateSize
    updateSize()
end

local function refreshAllRivalsESP()
    if not RivalsESP.active then return end
    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            seen[plr] = true
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                if not RivalsESP.boxes[plr] then
                    createRivalsBox(plr)
                else
                    applyBoxColor(RivalsESP.boxes[plr], getRivalsESPColor(plr))
                end
            else
                clearRivalsBox(plr)
            end
        end
    end
    for plr in pairs(RivalsESP.boxes) do
        if not seen[plr] then clearRivalsBox(plr) end
    end
end

local function startRivalsESP()
    RivalsESP.active = true
    refreshAllRivalsESP()
    if not RivalsESP.heartbeat then
        RivalsESP.heartbeat = RunService.RenderStepped:Connect(function()
            if not RivalsESP.active then return end
            local myHRP = getHRP()
            for plr, updater in pairs(RivalsESP.updaters) do
                pcall(updater)
                local data = RivalsESP.boxes[plr]
                if data and data.nameTag and data.nameTag.Parent and myHRP and plr.Character then
                    local theirHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                    if theirHRP then
                        local d = math.floor((myHRP.Position - theirHRP.Position).Magnitude)
                        data.nameTag.Text = plr.DisplayName .. " [" .. d .. "m]"
                    end
                end
            end
        end)
    end
    if not RivalsESP.refreshThread then
        RivalsESP.refreshThread = task.spawn(function()
            while RivalsESP.active do
                task.wait(0.5)
                if RivalsESP.active then refreshAllRivalsESP() end
            end
            RivalsESP.refreshThread = nil
        end)
    end
end

local function stopRivalsESP()
    RivalsESP.active = false
    if RivalsESP.refreshThread then
        task.cancel(RivalsESP.refreshThread)
        RivalsESP.refreshThread = nil
    end
    if RivalsESP.heartbeat then
        RivalsESP.heartbeat:Disconnect()
        RivalsESP.heartbeat = nil
    end
    for plr in pairs(RivalsESP.boxes) do
        clearRivalsBox(plr)
    end
    RivalsESP.boxes = {}
    RivalsESP.updaters = {}
end

local function updateNameTagVisibility()
    for plr, data in pairs(RivalsESP.boxes) do
        if VisualSettings.NameTags then
            if not data.nameTag or not data.nameTag.Parent then
                local nt = Instance.new("TextLabel")
                nt.Name = "NameTag"
                nt.Size = UDim2.new(1, 0, 0, 14)
                nt.Position = UDim2.new(0, 0, 1, 3)
                nt.BackgroundTransparency = 1
                nt.TextColor3 = getRivalsESPColor(plr)
                nt.Font = Enum.Font.GothamBold
                nt.TextSize = 12
                nt.TextStrokeTransparency = 0.4
                nt.TextStrokeColor3 = Color3.new(0, 0, 0)
                nt.Text = plr.DisplayName
                nt.Parent = data.bb
                data.nameTag = nt
            end
        else
            if data.nameTag and data.nameTag.Parent then
                data.nameTag:Destroy()
                data.nameTag = nil
            end
        end
    end
end

local function setupAutoReload()
    local queue = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if not queue then return end
    local src = nil
    pcall(function()
        local genv = getgenv and getgenv() or _G
        src = genv.__HAPPYHUB_SOURCE
    end)
    if not src then
        pcall(function()
            local info = debug.getinfo(1, "s")
            if info and info.source then
                local s = info.source
                if s:sub(1, 1) == "@" or s:sub(1, 1) == "=" then
                    s = s:sub(2)
                    if isfile and isfile(s) then src = readfile(s) end
                end
            end
        end)
    end
    if src and #src > 100 then
        pcall(function() queue(src) end)
    end
end

local win = API:CreateWindow("Happy Hub", "Rivals · Keyless · by replicatedman")

local aimbotTab = win:CreateTab("Aimbot", "93310349660228")
local visualsTab = win:CreateTab("Visuals", "13321848320")
local playerListTab = win:CreateTab("PlayerList", "122086195900803")
local miscTab = win:CreateTab("Misc", "109962716823639")

local aimbotToggleRef, espToggleRef

win:CreateLabel(aimbotTab, "Aimbot Settings")

aimbotToggleRef = win:CreateToggle(aimbotTab, "Enabled (T)", AimbotSettings.Enabled, function(v)
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

win:CreateToggle(aimbotTab, "Silent Aim", AimbotSettings.SilentAim, function(v)
    AimbotSettings.SilentAim = v
    silentAimEnabled = v
    API:Notify(v and "Silent Aim on" or "Silent Aim off")
end)

win:CreateToggle(aimbotTab, "Match Only", AimbotSettings.MatchOnly, function(v)
    AimbotSettings.MatchOnly = v
    lockedTarget = nil
    API:Notify(v and "Match filter on" or "Match filter off")
end)

win:CreateSlider(aimbotTab, "FOV", 20, 800, AimbotSettings.FOV, function(v)
    AimbotSettings.FOV = v
end)

win:CreateSlider(aimbotTab, "Smoothing", 0.05, 1, AimbotSettings.Smoothing, function(v)
    AimbotSettings.Smoothing = v
end)

win:CreateSlider(aimbotTab, "Max Distance", 100, 2000, AimbotSettings.MaxDistance, function(v)
    AimbotSettings.MaxDistance = v
end)

win:CreateToggle(aimbotTab, "Wall Check", AimbotSettings.WallCheck, function(v)
    AimbotSettings.WallCheck = v
end)

win:CreateToggle(aimbotTab, "Team Check", AimbotSettings.TeamCheck, function(v)
    AimbotSettings.TeamCheck = v
end)

win:CreateToggle(aimbotTab, "Show FOV Circle", AimbotSettings.ShowFOV, function(v)
    AimbotSettings.ShowFOV = v
end)

win:CreateToggle(aimbotTab, "Rotate Rig", AimbotSettings.RotateRig, function(v)
    AimbotSettings.RotateRig = v
end)

win:CreateDropdown(aimbotTab, "Target", { "Head", "Torso", "Random" }, "Head", function(sel)
    AimbotSettings.Target = sel
    API:Notify("Target: " .. sel)
end)

win:CreateLabel(aimbotTab, "Trigger Bot")

win:CreateToggle(aimbotTab, "Trigger Bot", AimbotSettings.TriggerBot, function(v)
    AimbotSettings.TriggerBot = v
    if triggerBotConn then
        triggerBotConn:Disconnect()
        triggerBotConn = nil
    end
    if v then
        triggerBotConn = RunService.RenderStepped:Connect(function()
            if not AimbotSettings.TriggerBot then return end
            local crosshair = getCrosshairPosition()
            local target = getAimTarget(crosshair)
            if not target then return end
            local sp, on = Camera:WorldToViewportPoint(target.Position)
            if not on then return end
            local mouse = UserInputService:GetMouseLocation()
            if (Vector2.new(sp.X, sp.Y) - mouse).Magnitude < 12 then
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.03)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end)
            end
        end)
    end
end)

win:CreateSlider(aimbotTab, "Trigger Range", 20, 400, AimbotSettings.TriggerRange, function(v)
    AimbotSettings.TriggerRange = v
end)

win:CreateToggle(aimbotTab, "Auto Fire", AimbotSettings.AutoFire, function(v)
    AimbotSettings.AutoFire = v
    if autoFireConn then
        autoFireConn:Disconnect()
        autoFireConn = nil
    end
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

espToggleRef = win:CreateToggle(visualsTab, "Rivals ESP (O)", VisualSettings.RivalsESP, function(v)
    VisualSettings.RivalsESP = v
    if v then
        startRivalsESP()
    else
        stopRivalsESP()
    end
    API:Notify(v and "ESP enabled" or "ESP disabled")
end)

win:CreateToggle(visualsTab, "Name Tags", VisualSettings.NameTags, function(v)
    VisualSettings.NameTags = v
    updateNameTagVisibility()
end)

win:CreateLabel(miscTab, "Movement")

win:CreateToggle(miscTab, "Infinite Jump", MiscSettings.InfJump, function(v)
    MiscSettings.InfJump = v
    API:Notify(v and "Infinite Jump enabled" or "Infinite Jump disabled")
end)

win:CreateToggle(miscTab, "Noclip", MovementSettings.Noclip, function(v)
    MovementSettings.Noclip = v
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
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
    if godConn then
        godConn:Disconnect()
        godConn = nil
    end
    if v then
        godConn = RunService.Heartbeat:Connect(function()
            local hum = getHumanoid()
            if hum then hum.Health = hum.MaxHealth end
        end)
    end
end)

win:CreateToggle(miscTab, "Anti-AFK", MiscSettings.AntiAFK, function(v)
    MiscSettings.AntiAFK = v
    if antiAFKConn then
        antiAFKConn:Disconnect()
        antiAFKConn = nil
    end
    if v then
        local vu = game:GetService("VirtualUser")
        antiAFKConn = LocalPlayer.Idled:Connect(function()
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
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

win:CreateLabel(playerListTab, "Players in Server")

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

    return {
        row = row,
        avatar = avatar,
        name = nameLbl,
        info = infoLbl,
        badge = badge,
    }
end

local function updateRow(refs, plr, myHRP)
    refs.name.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
    local dist = 0
    local health = 0
    local maxHealth = 100
    if plr.Character then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            health = math.floor(hum.Health)
            maxHealth = math.floor(hum.MaxHealth)
        end
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp and myHRP then
            dist = (myHRP.Position - hrp.Position).Magnitude
        end
    end
    local team = "No Team"
    if plr.Team then team = plr.Team.Name end
    refs.info.Text = string.format("%.0fm · %d/%d HP · %s", dist, health, maxHealth, team)

    if plr == LocalPlayer then
        refs.badge.Text = "YOU"
        refs.badge.TextColor3 = Color3.fromRGB(0, 255, 100)
    elseif isTeammate(plr) then
        refs.badge.Text = "ALLY"
        refs.badge.TextColor3 = Color3.fromRGB(60, 160, 255)
    elseif AimbotSettings.MatchOnly and isActiveFighter(plr) then
        refs.badge.Text = "ENEMY"
        refs.badge.TextColor3 = Color3.fromRGB(255, 60, 60)
    elseif isActiveFighter(plr) then
        refs.badge.Text = "FIGHT"
        refs.badge.TextColor3 = Color3.fromRGB(255, 180, 60)
    else
        refs.badge.Text = "LOBBY"
        refs.badge.TextColor3 = Color3.fromRGB(140, 140, 140)
    end
end

local function refreshPlayerList()
    local current = {}
    for _, p in ipairs(Players:GetPlayers()) do
        current[p] = true
    end

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
        if RivalsESP.active then refreshAllRivalsESP() end
    end)
    task.wait(0.2)
    refreshPlayerList()
end)

Players.PlayerRemoving:Connect(function(plr)
    clearRivalsBox(plr)
    task.wait(0.1)
    refreshPlayerList()
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(refreshPlayerList)
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.T then
        local newState = not AimbotSettings.Enabled
        if aimbotToggleRef and aimbotToggleRef.SetState then aimbotToggleRef.SetState(newState) end
        API:Notify(newState and "Aimbot enabled (T)" or "Aimbot disabled (T)")
    elseif input.KeyCode == Enum.KeyCode.O then
        local newState = not VisualSettings.RivalsESP
        if espToggleRef and espToggleRef.SetState then espToggleRef.SetState(newState) end
        API:Notify(newState and "ESP enabled (O)" or "ESP disabled (O)")
    end
end)

if isMobile then
    win:AddMobileButton({
        Icon = "rbxassetid://93310349660228",
        Tooltip = "Toggle Aimbot",
        OnClick = function()
            local newState = not AimbotSettings.Enabled
            if aimbotToggleRef and aimbotToggleRef.SetState then aimbotToggleRef.SetState(newState) end
            API:Notify(newState and "Aimbot enabled" or "Aimbot disabled")
        end,
    })
    win:AddMobileButton({
        Icon = "rbxassetid://13321848320",
        Tooltip = "Toggle ESP",
        OnClick = function()
            local newState = not VisualSettings.RivalsESP
            if espToggleRef and espToggleRef.SetState then espToggleRef.SetState(newState) end
            API:Notify(newState and "ESP enabled" or "ESP disabled")
        end,
    })
    win:AddMobileButton({
        Icon = "rbxassetid://115558082558028",
        Tooltip = "Toggle UI",
        OnClick = function()
            win:ToggleUI()
        end,
    })
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if MovementSettings.Noclip then
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    end
    if MovementSettings.God then
        if godConn then godConn:Disconnect() end
        godConn = RunService.Heartbeat:Connect(function()
            local hum = getHumanoid()
            if hum then hum.Health = hum.MaxHealth end
        end)
    end
end)

local frameCounter = 0

local function onRenderStep()
    if not LocalPlayer.Character then return end
    Camera = workspace.CurrentCamera
    if not Camera then return end

    frameCounter = frameCounter + 1
    if frameCounter % 5 == 0 then rebuildRayFilter() end

    local crosshair = getCrosshairPosition()

    if fovCircle then
        if AimbotSettings.Enabled and AimbotSettings.ShowFOV then
            fovCircle.Position = crosshair
            fovCircle.Radius = AimbotSettings.FOV
            fovCircle.Color = Color3.fromRGB(0, 255, 63)
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end

    if AimbotSettings.Enabled then
        local targetPart = getAimTarget(crosshair)
        if targetPart then
            aimViaMouse(targetPart)
        elseif AimbotSettings.RotateRig then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local camLook = Camera.CFrame.LookVector
                local targetYaw = math.atan2(-camLook.X, -camLook.Z)
                local currentYaw = math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z)
                local diff = math.atan2(math.sin(targetYaw - currentYaw), math.cos(targetYaw - currentYaw))
                local newYaw = currentYaw + diff * 0.4
                local look = Vector3.new(-math.sin(newYaw), 0, -math.cos(newYaw))
                local right = Vector3.new(math.cos(newYaw), 0, -math.sin(newYaw))
                hrp.CFrame = CFrame.fromMatrix(hrp.CFrame.Position, right, Vector3.new(0, 1, 0), -look)
            end
        end
    else
        lockedTarget = nil
    end
end

RunService:BindToRenderStep("HappyHub", Enum.RenderPriority.Camera.Value + 1, onRenderStep)

setupAutoReload()

win:BuildConfigPage()

API:Notify("Happy Hub loaded")
