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
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local HOME_ICON = "131878842124084"
local AIM_ICON  = "119272570124806"
local VIS_ICON  = "13321848320"
local PLR_ICON  = "16485180075"
local MOV_ICON  = "112623004490927"
local MISC_ICON = "109962716823639"
local AVT_ICON  = "116651535114885"
local FARM_ICON = "74133076168703"

local Settings = {
    Aimbot = { Camera = false, Smooth = 8, Range = 500, Target = "Head", WallCheck = true, FOV = false, FOVRadius = 120 },
    Silent = { Enabled = false, Mode = "Murderer", Bone = "Head", FOV = 150, UseFOV = true, Wall = true, Predict = 0.12, Key = Enum.KeyCode.Q, KeyMode = "Hold" },
    Trigger = { Enabled = false, Range = 150, Delay = 0.1, UseSilent = true, Wall = true },
    Auto = { Enabled = false, Range = 500, Delay = 0.1, UseSilent = true, Wall = true },
    Visual = { Roles = false, Neutral = false, NameTags = false, Health = true, Tracer = false, Gun = false, GunBeam = false },
    Misc = { InfJump = false, AntiAFK = false, AutoGun = false, Music = false },
    Move = { Noclip = false, God = false, Fly = false, WalkSpeed = 16, JumpPower = 50, FlySpeed = 40, AntiFling = false, Fling = false, TPAll = false },
    Avatar = { Korblox = false, Shoulder = false, Invisible = false, NoobFace = false, Rainbow = false },
    Farm = { Enabled = false, Speed = 25, Evade = true, AutoRestart = true },
}

local function notify(msg, dur) pcall(function() API:Notify(msg, dur or 3) end) end
local function registerControl(t, k, c) pcall(function() API:RegisterControl(t, k, c) end) end
local function getHRP() local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = LocalPlayer.Character; return c and c:FindFirstChildOfClass("Humanoid") end

local RoleCache = {}
local HeroWatcher = { active = false, thread = nil }
local ESP = { highlights = { MM2 = {}, OG = {} }, tags = {}, tracers = {}, gunTags = {}, gunHighlights = {}, healthBars = {} }
local GunESP = { tracked = nil }
local FOVGui, FOVFrame, FOVConn

local CONN = {}
local noclipConn, godConn, antiAFKConn, flyConn, flyBV, flyBG
local camConn, silentConn, triggerConn, autoConn
local farmThread, farmConn, farmBV, farmBG
local autoGunThread, antiFlingConns = {}
local flingRunning, flingTask
local tpAllRunning, tpAllTask
local killAllRunning = false
local musicSound, currentIdle
local _origTransp, _origColors = {}, {}
local HitboxExpand = { saved = {} }

local flingToggleRef, mm2ESPToggleRef, mm2LockRef, autoFireRef, silentToggleRef, farmToggleRef

local function hasTool(parent, name)
    if not parent then return false end
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find(name:lower(), 1, true) then return true end
    end
    return false
end

local function roleOf(plr)
    if plr == LocalPlayer then return "Innocent" end
    local c = RoleCache[plr.Name]
    if c and c.Role then return c.Role end
    local char, bp = plr.Character, plr:FindFirstChildOfClass("Backpack")
    if hasTool(char, "Knife") or hasTool(bp, "Knife") then return "Murderer" end
    if hasTool(char, "Gun") or hasTool(bp, "Gun") then
        for _, i in pairs(RoleCache) do if i.Role == "Sheriff" and not i.Dead then return "Sheriff" end end
        return "Hero"
    end
    return "Innocent"
end

local function getMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and roleOf(p) == "Murderer" then return p end
    end
    return nil
end

local function getSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and roleOf(p) == "Sheriff" then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and roleOf(p) == "Hero" then return p end
    end
    return nil
end

local function getHero()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and roleOf(p) == "Hero" then return p end
    end
    return nil
end

local function getClosest()
    local hrp = getHRP(); if not hrp then return nil end
    local best, bd = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local h = p.Character:FindFirstChild("HumanoidRootPart")
            if h then local d = (hrp.Position - h.Position).Magnitude; if d < bd then bd = d; best = p end end
        end
    end
    return best
end

local function isMurdererLocal()
    return roleOf(LocalPlayer) == "Murderer" or hasTool(LocalPlayer.Character, "Knife") or hasTool(LocalPlayer:FindFirstChildOfClass("Backpack"), "Knife")
end

local function boneOf(char, mode)
    if not char then return nil end
    if mode == "Head" then return char:FindFirstChild("Head") end
    if mode == "Torso" then return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart") end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getSilentTarget()
    local mode = Settings.Silent.Mode
    local t
    if mode == "Murderer" then t = getMurderer()
    elseif mode == "Sheriff" then t = getSheriff()
    elseif mode == "Hero" then t = getHero()
    else t = getClosest() end
    if not t or not t.Character then return nil end
    local part = boneOf(t.Character, Settings.Silent.Bone)
    if not part then return nil end
    if Settings.Silent.UseFOV and Camera then
        local sp, on = Camera:WorldToViewportPoint(part.Position)
        if not on then return nil end
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        if (Vector2.new(sp.X, sp.Y) - center).Magnitude > Settings.Silent.FOV then return nil end
    end
    if Settings.Silent.Wall and not isVisible(Camera.CFrame.Position, part.Position, t.Character) then return nil end
    return t, part
end

function isVisible(from, to, char)
    local dir = to - from
    local dist = dir.Magnitude
    if dist < 0.5 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { Camera }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    local r = workspace:Raycast(from, dir.Unit * (dist + 1), params)
    if not r then return true end
    if char and (r.Instance:IsDescendantOf(char) or r.Instance == char) then return true end
    return false
end

local silentActive = false
local silentTarget, silentPart
local raycastHook, namecallHook

local function silentGetAimPos()
    if not silentPart then return nil end
    local hum = silentTarget and silentTarget.Character and silentTarget.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return silentPart.Position end
    local ping = 0
    pcall(function() ping = LocalPlayer:GetNetworkPing() end)
    local pred = Settings.Silent.Predict + ping
    if pred > 0 then
        return silentPart.Position + hum.MoveDirection * hum.WalkSpeed * pred
    end
    return silentPart.Position
end

local function installSilentHooks()
    if raycastHook then return end
    pcall(function()
        local old
        old = hookfunction(workspace.Raycast, function(origin, dir, params)
            if silentActive and silentPart then
                local ap = silentGetAimPos()
                if ap then
                    local nd = ap - origin
                    if nd.Magnitude > 0.01 then dir = nd end
                end
            end
            return old(origin, dir, params)
        end)
        raycastHook = old
    end)
    pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            local m = getnamecallmethod()
            if silentActive and silentPart and (m == "Raycast" or m == "FindPartOnRay" or m == "FindPartOnRayWithIgnoreList" or m == "FindPartOnRayWithWhitelist") then
                local args = { ... }
                if typeof(args[1]) == "Vector3" then
                    local ap = silentGetAimPos()
                    if ap then
                        local nd = ap - args[1]
                        if nd.Magnitude > 0.01 then args[2] = nd end
                    end
                elseif typeof(args[1]) == "CFrame" then
                    local ap = silentGetAimPos()
                    if ap then args[1] = CFrame.new(args[1].Position, ap) end
                end
                return old(self, unpack(args))
            end
            return old(self, ...)
        end)
        namecallHook = old
    end)
end

local function uninstallSilentHooks()
    pcall(function() if raycastHook then hookfunction(workspace.Raycast, raycastHook) end end)
    pcall(function() if namecallHook then hookmetamethod(game, "__namecall", namecallHook) end end)
    raycastHook = nil
    namecallHook = nil
end

local function setSilent(state)
    if state == silentActive then return end
    silentActive = state
    Settings.Silent.Enabled = state
    if state then
        installSilentHooks()
        task.spawn(function()
            while silentActive do
                local t, p = getSilentTarget()
                silentTarget = t
                silentPart = p
                task.wait(0.03)
            end
        end)
    else
        silentTarget, silentPart = nil, nil
        uninstallSilentHooks()
    end
end

local ESP_COLORS = {
    Murderer = Color3.fromRGB(255, 60, 60),
    Sheriff  = Color3.fromRGB(60, 150, 255),
    Hero     = Color3.fromRGB(255, 200, 0),
    Innocent = Color3.fromRGB(70, 255, 120),
    Neutral  = Color3.fromRGB(255, 255, 255),
    Gun      = Color3.fromRGB(255, 200, 0),
}

local function createTag(plr, char)
    if ESP.tags[plr] then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "HH_Tag"
    bb.Size = UDim2.new(0, 200, 0, 56)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = hrp
    bb.MaxDistance = 500
    bb.Parent = hrp

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 1, 0)
    holder.BackgroundTransparency = 1
    holder.Parent = bb

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.Position = UDim2.new(0, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 14
    nameLbl.TextStrokeTransparency = 0.3
    nameLbl.TextColor3 = Color3.new(1, 1, 1)
    nameLbl.Parent = holder

    local roleLbl = Instance.new("TextLabel")
    roleLbl.Name = "Role"
    roleLbl.Size = UDim2.new(1, 0, 0, 14)
    roleLbl.Position = UDim2.new(0, 0, 0, 16)
    roleLbl.BackgroundTransparency = 1
    roleLbl.Font = Enum.Font.Gotham
    roleLbl.TextSize = 12
    roleLbl.TextStrokeTransparency = 0.4
    roleLbl.Parent = holder

    local distLbl = Instance.new("TextLabel")
    distLbl.Name = "Dist"
    distLbl.Size = UDim2.new(1, 0, 0, 14)
    distLbl.Position = UDim2.new(0, 0, 0, 30)
    distLbl.BackgroundTransparency = 1
    distLbl.Font = Enum.Font.Code
    distLbl.TextSize = 12
    distLbl.TextStrokeTransparency = 0.4
    distLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    distLbl.Parent = holder

    local hpBg = Instance.new("Frame")
    hpBg.Name = "HPBg"
    hpBg.Size = UDim2.new(0.7, 0, 0, 4)
    hpBg.Position = UDim2.new(0.15, 0, 1, -6)
    hpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    hpBg.BorderSizePixel = 0
    hpBg.Parent = holder
    local hpBorder = Instance.new("UIStroke")
    hpBorder.Thickness = 1
    hpBorder.Color = Color3.fromRGB(0, 0, 0)
    hpBorder.Transparency = 0.4
    hpBorder.Parent = hpBg

    local hpFill = Instance.new("Frame")
    hpFill.Name = "HPFill"
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(70, 255, 120)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg

    ESP.tags[plr] = { bb = bb, name = nameLbl, role = roleLbl, dist = distLbl, hp = hpFill }
end

local function updateTag(plr)
    local data = ESP.tags[plr]
    if not data then return end
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local myHRP = getHRP()
    if not hum or not hrp or not myHRP then return end
    local role = roleOf(plr)
    local col = ESP_COLORS[role] or ESP_COLORS.Innocent
    data.name.Text = plr.DisplayName
    data.role.Text = role
    data.role.TextColor3 = col
    data.dist.Text = math.floor((myHRP.Position - hrp.Position).Magnitude) .. " studs"
    local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
    data.hp.Size = UDim2.new(pct, 0, 1, 0)
    if pct > 0.6 then data.hp.BackgroundColor3 = Color3.fromRGB(70, 255, 120)
    elseif pct > 0.3 then data.hp.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    else data.hp.BackgroundColor3 = Color3.fromRGB(255, 60, 60) end
end

local function applyESP(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    if Settings.Visual.Roles then
        local role = roleOf(plr)
        local col = ESP_COLORS[role] or ESP_COLORS.Innocent
        if not ESP.highlights.MM2[plr] then
            local h = Instance.new("Highlight")
            h.Name = "HH_MM2"
            h.FillColor = col
            h.FillTransparency = 0.25
            h.OutlineColor = col
            h.OutlineTransparency = 0.4
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = char
            ESP.highlights.MM2[plr] = h
        else
            ESP.highlights.MM2[plr].FillColor = col
            ESP.highlights.MM2[plr].OutlineColor = col
        end
    elseif ESP.highlights.MM2[plr] then
        ESP.highlights.MM2[plr]:Destroy()
        ESP.highlights.MM2[plr] = nil
    end

    if Settings.Visual.Neutral then
        if not ESP.highlights.OG[plr] then
            local h = Instance.new("Highlight")
            h.Name = "HH_OG"
            h.FillColor = Color3.new(1, 1, 1)
            h.FillTransparency = 0.65
            h.OutlineColor = Color3.new(1, 1, 1)
            h.OutlineTransparency = 0.3
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = char
            ESP.highlights.OG[plr] = h
        end
    elseif ESP.highlights.OG[plr] then
        ESP.highlights.OG[plr]:Destroy()
        ESP.highlights.OG[plr] = nil
    end

    if Settings.Visual.NameTags then
        createTag(plr, char)
    elseif ESP.tags[plr] then
        if ESP.tags[plr].bb then ESP.tags[plr].bb:Destroy() end
        ESP.tags[plr] = nil
    end
end

local function clearESP(plr)
    if ESP.highlights.MM2[plr] then ESP.highlights.MM2[plr]:Destroy(); ESP.highlights.MM2[plr] = nil end
    if ESP.highlights.OG[plr] then ESP.highlights.OG[plr]:Destroy(); ESP.highlights.OG[plr] = nil end
    if ESP.tags[plr] then if ESP.tags[plr].bb then ESP.tags[plr].bb:Destroy() end ESP.tags[plr] = nil end
    if ESP.tracers[plr] then if ESP.tracers[plr].Parent then ESP.tracers[plr]:Destroy() end ESP.tracers[plr] = nil end
end

local function clearGunESP()
    for _, v in pairs(ESP.gunTags) do if v and v.Parent then v:Destroy() end end
    for _, v in pairs(ESP.gunHighlights) do if v and v.Parent then v:Destroy() end end
    ESP.gunTags = {}
    ESP.gunHighlights = {}
    GunESP.tracked = nil
end

local function findGunDrop()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("gundrop") then return obj end
        if obj:IsA("Model") then
            local f = obj:FindFirstChild("GunDrop", true)
            if f and f:IsA("BasePart") then return f end
        end
    end
    local g = workspace:FindFirstChild("GunDrop", true)
    if g and g:IsA("BasePart") then return g end
end

local function applyGunESP()
    if not Settings.Visual.Gun then clearGunESP(); return end
    local gun = findGunDrop()
    if not gun then clearGunESP(); return end
    if GunESP.tracked ~= gun then clearGunESP(); GunESP.tracked = gun end

    if not ESP.gunHighlights[gun] then
        local h = Instance.new("Highlight")
        h.Name = "HH_GunH"
        h.FillColor = ESP_COLORS.Gun
        h.FillTransparency = 0.3
        h.OutlineColor = Color3.new(1, 1, 1)
        h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = gun
        ESP.gunHighlights[gun] = h
    end

    if not ESP.gunTags[gun] then
        local bb = Instance.new("BillboardGui")
        bb.Name = "HH_GunTag"
        bb.Size = UDim2.new(0, 180, 0, 32)
        bb.StudsOffset = Vector3.new(0, 4, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = gun
        bb.Parent = gun

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "⚡ GUN DROP"
        lbl.TextColor3 = ESP_COLORS.Gun
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 16
        lbl.TextStrokeTransparency = 0.2
        lbl.Parent = bb
        ESP.gunTags[gun] = bb
    end
end

local function refreshAllESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if p.Character then applyESP(p) else clearESP(p) end
        end
    end
    applyGunESP()
end

local function setupPlayerHooks(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function() task.wait(0.4); clearESP(plr); applyESP(plr) end)
    plr.CharacterRemoving:Connect(function() clearESP(plr) end)
end

for _, p in ipairs(Players:GetPlayers()) do setupPlayerHooks(p) end
Players.PlayerAdded:Connect(setupPlayerHooks)
Players.PlayerRemoving:Connect(function(p) clearESP(p); RoleCache[p.Name] = nil end)

local fadeConn
local function hookFade()
    if fadeConn then fadeConn:Disconnect(); fadeConn = nil end
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    local g = r and r:FindFirstChild("Gameplay")
    local ev = g and g:FindFirstChild("Fade")
    if not ev then return end
    fadeConn = ev.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        for name, info in pairs(data) do
            if type(info) == "table" and info.Role then
                RoleCache[name] = { Role = info.Role, Dead = info.Dead or false, UserId = info.UserId }
            end
        end
        refreshAllESP()
    end)
end
hookFade()
task.spawn(function()
    while true do task.wait(3); if not fadeConn then hookFade() end end
end)

local function getTpEvent()
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    local g = r and r:FindFirstChild("Gameplay")
    return g and g:FindFirstChild("TeleportToPart")
end

local function fireTP(a, b)
    local ev = getTpEvent()
    if not ev then return false end
    pcall(function() ev:FireServer(a, b) end)
    pcall(function() ev:FireServer(b, a) end)
    pcall(function() ev:FireServer(a, b.Position) end)
    return true
end

local function teleportTo(plr)
    if not plr then return false end
    local h = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    local m = getHRP()
    if not h or not m then return false end
    if not fireTP(m, h) then m.CFrame = h.CFrame end
    task.wait(0.03)
    local m2 = getHRP()
    if m2 and (m2.Position - h.Position).Magnitude > 5 then m2.CFrame = h.CFrame end
    return true
end

local function getCoinContainer()
    local maps = { "ResearchFacility","House2","Mansion2","Hotel","MilBase","Bank2","BioLab","Factory","Workplace","PoliceStation","Office3","Hospital3","Town","Town2","Mansion","House" }
    for _, n in ipairs(maps) do
        local m = workspace:FindFirstChild(n)
        if m then local c = m:FindFirstChild("CoinContainer", true); if c then return c end end
    end
    local c = workspace:FindFirstChild("CoinContainer", true)
    if c then return c end
    for _, ch in ipairs(workspace:GetChildren()) do
        if ch:IsA("Model") and (ch.Name:find("Map") or ch.Name:find("map")) then
            local c2 = ch:FindFirstChild("CoinContainer", true)
            if c2 then return c2 end
        end
    end
end

local function getBestCoin()
    local cc = getCoinContainer()
    if not cc then return nil end
    local h = getHRP()
    if not h then return nil end
    local best, bd = nil, math.huge
    for _, ch in ipairs(cc:GetChildren()) do
        local part = ch:IsA("BasePart") and ch or (ch:IsA("Model") and ch.PrimaryPart)
        if part and part:IsA("BasePart") then
            local d = (part.Position - h.Position).Magnitude
            if d < bd then bd = d; best = part end
        end
    end
    return best
end

local farmStatus = nil
local farmCount = nil

local function stopFarm()
    if farmConn then farmConn:Disconnect(); farmConn = nil end
    if farmBV then farmBV:Destroy(); farmBV = nil end
    if farmBG then farmBG:Destroy(); farmBG = nil end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
    if currentIdle then pcall(function() currentIdle:Stop() end); currentIdle = nil end
    if farmStatus then farmStatus("Idle") end
end

local function startFarm()
    if farmConn then return end
    if farmStatus then farmStatus("Starting") end
    farmConn = RunService.Heartbeat:Connect(function()
        if not Settings.Farm.Enabled then stopFarm(); return end
        local h = getHRP()
        local hum = getHum()
        if not h or not hum then return end

        hum.PlatformStand = true

        if not farmBV or not farmBV.Parent then
            farmBV = Instance.new("BodyVelocity")
            farmBV.MaxForce = Vector3.new(1e5,1e5,1e5)
            farmBV.P = 1250
            farmBV.Parent = h
        end
        if not farmBG or not farmBG.Parent then
            farmBG = Instance.new("BodyGyro")
            farmBG.MaxTorque = Vector3.new(1e5,1e5,1e5)
            farmBG.P = 1e4
            farmBG.D = 500
            farmBG.Parent = h
        end

        if Settings.Farm.Evade then
            local m = getMurderer()
            if m and m.Character and m ~= LocalPlayer then
                local mh = m.Character:FindFirstChild("HumanoidRootPart")
                if mh and (h.Position - mh.Position).Magnitude < 22 then
                    local ev = (h.Position - mh.Position).Unit
                    farmBV.Velocity = ev * math.min(Settings.Farm.Speed * 1.6, 80)
                    farmBG.CFrame = CFrame.lookAt(h.Position, h.Position + ev)
                    if farmStatus then farmStatus("Evading") end
                    return
                end
            end
        end

        local coin = getBestCoin()
        if not coin then
            farmBV.Velocity = Vector3.zero
            if farmStatus then farmStatus("No coins") end
            return
        end

        local dir = coin.Position - h.Position
        local dist = dir.Magnitude
        local speed = Settings.Farm.Speed
        if dist < 5 then speed = Settings.Farm.Speed * 0.4
        elseif dist < 15 then speed = Settings.Farm.Speed * 0.7 end
        farmBV.Velocity = dir.Unit * speed
        farmBG.CFrame = CFrame.lookAt(h.Position, coin.Position)
        if farmStatus then farmStatus("Collecting") end
    end)
end

local function getFlingTarget(name)
    if not name then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and (p.Name == name or p.DisplayName == name) then return p end
    end
end

local function startFling(plr)
    if not plr or plr == LocalPlayer then notify("Invalid target"); return end
    local h = getHRP(); if not h then notify("No HRP"); return end
    if flingRunning then return end
    flingRunning = true
    notify("Flinging " .. plr.DisplayName)
    task.spawn(function()
        local start = tick()
        while flingRunning and tick() - start < 3 do
            local h2 = getHRP()
            local th = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if not h2 or not th then break end
            local velo = h2.Velocity
            h2.Velocity = velo * 5000 + (th.Position - h2.Position).Unit * 20000 + Vector3.new(0, 8000, 0)
            h2.RotVelocity = Vector3.new(300, 300, 300)
            RunService.RenderStepped:Wait()
            h2.Velocity = velo
            h2.RotVelocity = Vector3.zero
            RunService.Stepped:Wait()
        end
        flingRunning = false
    end)
end

local function attachFly()
    local h, hum = getHRP(), getHum()
    if not h or not hum then return end
    hum.PlatformStand = true
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
    flyBV = Instance.new("BodyVelocity"); flyBV.Velocity = Vector3.zero; flyBV.MaxForce = Vector3.new(1e5,1e5,1e5); flyBV.Parent = h
    flyBG = Instance.new("BodyGyro"); flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); flyBG.P = 1e4; flyBG.CFrame = h.CFrame; flyBG.Parent = h
end

local function detachFly()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    local hum = getHum(); if hum then hum.PlatformStand = false end
end

local function startFly()
    if flyConn then return end
    attachFly()
    flyConn = RunService.Heartbeat:Connect(function()
        if not Settings.Move.Fly then return end
        local h = getHRP(); if not h then return end
        if not flyBV or not flyBV.Parent then attachFly() end
        if not flyBV then return end
        local cf = Camera.CFrame
        local mv = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.yAxis end
        flyBV.Velocity = mv.Magnitude > 0 and mv.Unit * Settings.Move.FlySpeed or Vector3.zero
        flyBG.CFrame = cf
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    detachFly()
end

local function startFOV()
    if FOVConn then return end
    if not FOVGui then
        FOVGui = Instance.new("ScreenGui")
        FOVGui.Name = "HH_FOV"
        FOVGui.ResetOnSpawn = false
        FOVGui.IgnoreGuiInset = true
        pcall(function() FOVGui.Parent = game:GetService("CoreGui") end)
        if not FOVGui.Parent then FOVGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
        FOVFrame = Instance.new("Frame")
        FOVFrame.BackgroundTransparency = 1
        FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        FOVFrame.Parent = FOVGui
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.5
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Transparency = 0.4
        stroke.Parent = FOVFrame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = FOVFrame
    end
    FOVGui.Enabled = true
    FOVConn = RunService.RenderStepped:Connect(function()
        if not Settings.Aimbot.FOV then return end
        local r = Settings.Aimbot.FOVRadius
        FOVFrame.Size = UDim2.new(0, r*2, 0, r*2)
    end)
end

local function stopFOV()
    if FOVConn then FOVConn:Disconnect(); FOVConn = nil end
    if FOVGui then FOVGui.Enabled = false end
end

local window
do
    local ok, err = pcall(function()
        window = API:CreateWindow("Happy Hub", "MM2 · Keyless · v12")
    end)
    if not ok or not window then warn("[HappyHub] " .. tostring(err)); return end
end

local homeTab    = window:CreateTab("Home", HOME_ICON)
local playersTab = window:CreateTab("Players", PLR_ICON)
local espTab     = window:CreateTab("Visuals", VIS_ICON)
local movementTab= window:CreateTab("Movement", MOV_ICON)
local aimbotTab  = window:CreateTab("Combat", AIM_ICON)
local avatarTab  = window:CreateTab("Avatar", AVT_ICON)
local farmTab    = window:CreateTab("Farm", FARM_ICON)
local miscTab    = window:CreateTab("Misc", MISC_ICON)

window:CreateLabel(homeTab, "Happy Hub v12")
window:CreateParagraph(homeTab, "Best free MM2 hub · Keyless · Continuous Farm · Silent Aim")

local musicRef = window:CreateToggle(homeTab, "Music Companion", false, function(v)
    Settings.Misc.Music = v
    if v then
        if musicSound then musicSound:Destroy() end
        musicSound = Instance.new("Sound")
        musicSound.SoundId = "rbxassetid://98012717802240"
        musicSound.Volume = 5
        musicSound.Looped = true
        musicSound.Parent = SoundService
        musicSound:Play()
    else
        if musicSound then musicSound:Stop(); musicSound:Destroy(); musicSound = nil end
    end
end)
registerControl(Settings.Misc, "Music", musicRef)

window:CreateLabel(playersTab, "Teleport")
local tpAllRef = window:CreateToggle(playersTab, "TP All (Loop)", false, function(v)
    Settings.Move.TPAll = v
    if v then
        tpAllRunning = true
        tpAllTask = task.spawn(function()
            while tpAllRunning do
                for _, p in ipairs(Players:GetPlayers()) do
                    if not tpAllRunning then break end
                    if p ~= LocalPlayer then teleportTo(p); task.wait(0.08) end
                end
                task.wait(0.1)
            end
        end)
    else
        tpAllRunning = false
        if tpAllTask then task.cancel(tpAllTask); tpAllTask = nil end
    end
end)
registerControl(Settings.Move, "TPAll", tpAllRef)

_G.__TPTarget = "Murder"
window:CreateDropdown(playersTab, "Teleport Target", { "Murder", "Sheriff", "Hero" }, "Murder", function(v) _G.__TPTarget = v end)
window:CreateButton(playersTab, "Teleport to Target", function()
    local t = _G.__TPTarget
    local p = t == "Sheriff" and getSheriff() or t == "Hero" and getHero() or getMurderer()
    if teleportTo(p) then notify("Teleported to " .. t) else notify("No " .. t .. " found") end
end)

window:CreateLabel(playersTab, "Fling")
_G.__FlingTarget = nil
local flingDD = window:CreateDropdown(playersTab, "Player", (function()
    local n = {}; for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(n, p.Name) end end; return n
end)(), "", function(v) _G.__FlingTarget = v end)

window:CreateButton(playersTab, "Fling Target", function()
    local p = getFlingTarget(_G.__FlingTarget)
    if p then startFling(p) else notify("Select a player") end
end)
window:CreateButton(playersTab, "Fling Murderer", function()
    local p = getMurderer(); if p then startFling(p) else notify("No Murderer") end
end)
window:CreateButton(playersTab, "Fling Sheriff", function()
    local p = getSheriff(); if p then startFling(p) else notify("No Sheriff/Hero") end
end)

window:CreateLabel(playersTab, "Server")
window:CreateButton(playersTab, "Rejoin", function()
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end)
window:CreateButton(playersTab, "Server Hop", function()
    pcall(function()
        local data = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
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

window:CreateLabel(espTab, "Player ESP")
mm2ESPToggleRef = window:CreateToggle(espTab, "Role Highlight", false, function(v)
    Settings.Visual.Roles = v
    refreshAllESP()
    if v and not CONN.mm2Loop then
        CONN.mm2Loop = RunService.Heartbeat:Connect(function()
            if not Settings.Visual.Roles and not Settings.Visual.Neutral and not Settings.Visual.NameTags and not Settings.Visual.Gun then return end
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and p.Character then applyESP(p) end end
        end)
    end
end)
registerControl(Settings.Visual, "Roles", mm2ESPToggleRef)

local ogRef = window:CreateToggle(espTab, "Neutral Highlight", false, function(v)
    Settings.Visual.Neutral = v
    refreshAllESP()
end)
registerControl(Settings.Visual, "Neutral", ogRef)

local tagRef = window:CreateToggle(espTab, "Name Tags", false, function(v)
    Settings.Visual.NameTags = v
    refreshAllESP()
    if v and not CONN.tagLoop then
        CONN.tagLoop = RunService.Heartbeat:Connect(function()
            if not Settings.Visual.NameTags then return end
            for plr in pairs(ESP.tags) do updateTag(plr) end
        end)
    end
end)
registerControl(Settings.Visual, "NameTags", tagRef)

window:CreateLabel(espTab, "Objects")
local gunRef = window:CreateToggle(espTab, "Gun ESP", false, function(v)
    Settings.Visual.Gun = v
    applyGunESP()
    if v and not CONN.gunLoop then
        CONN.gunLoop = RunService.Heartbeat:Connect(function()
            if Settings.Visual.Gun then applyGunESP() end
        end)
    end
    if not v then clearGunESP() end
end)
registerControl(Settings.Visual, "Gun", gunRef)

window:CreateLabel(movementTab, "Fly")
local flyRef = window:CreateToggle(movementTab, "Fly", false, function(v)
    Settings.Move.Fly = v
    if v then startFly() else stopFly() end
end)
registerControl(Settings.Move, "Fly", flyRef)
local flySpd = window:CreateSlider(movementTab, "Fly Speed", 5, 200, 40, function(v) Settings.Move.FlySpeed = v end)
registerControl(Settings.Move, "FlySpeed", flySpd)
window:CreateParagraph(movementTab, "WASD + Space / LeftControl")

window:CreateLabel(movementTab, "Speed")
local wsRef = window:CreateSlider(movementTab, "Walk Speed", 4, 150, 16, function(v)
    Settings.Move.WalkSpeed = v
    local h = getHum(); if h then h.WalkSpeed = v end
end)
registerControl(Settings.Move, "WalkSpeed", wsRef)
local jpRef = window:CreateSlider(movementTab, "Jump Power", 10, 200, 50, function(v)
    Settings.Move.JumpPower = v
    local h = getHum(); if h then h.JumpPower = v; h.UseJumpPower = true end
end)
registerControl(Settings.Move, "JumpPower", jpRef)

window:CreateLabel(movementTab, "Mods")
local ncRef = window:CreateToggle(movementTab, "Noclip", false, function(v)
    Settings.Move.Noclip = v
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    if v then
        noclipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
        end)
    end
end)
registerControl(Settings.Move, "Noclip", ncRef)

local godRef = window:CreateToggle(movementTab, "God Mode", false, function(v)
    Settings.Move.God = v
    if godConn then godConn:Disconnect(); godConn = nil end
    if v then
        godConn = RunService.Heartbeat:Connect(function()
            local h = getHum(); if h then h.Health = h.MaxHealth end
        end)
    end
end)
registerControl(Settings.Move, "God", godRef)

local ijRef = window:CreateToggle(movementTab, "Infinite Jump", false, function(v) Settings.Misc.InfJump = v end)
registerControl(Settings.Misc, "InfJump", ijRef)
UserInputService.JumpRequest:Connect(function()
    if Settings.Misc.InfJump then
        local h = getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local afkRef = window:CreateToggle(movementTab, "Anti-AFK", false, function(v)
    Settings.Misc.AntiAFK = v
    if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
    if v then
        local vu = game:GetService("VirtualUser")
        antiAFKConn = LocalPlayer.Idled:Connect(function()
            vu:Button2Down(Vector2.new(0,0), Camera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0,0), Camera.CFrame)
        end)
    end
end)
registerControl(Settings.Misc, "AntiAFK", afkRef)

window:CreateLabel(movementTab, "Fling")
flingToggleRef = window:CreateToggle(movementTab, "Touch Fling", false, function(v)
    Settings.Move.Fling = v
    if v then
        if flingRunning then return end
        flingRunning = true
        flingTask = task.spawn(function()
            while flingRunning do
                local h = getHRP()
                if h then
                    local velo = h.Velocity
                    h.Velocity = velo * 10000 + Vector3.new(0, 10000, 0)
                    RunService.RenderStepped:Wait()
                    h.Velocity = velo
                    RunService.Stepped:Wait()
                end
            end
        end)
    else
        flingRunning = false
        if flingTask then task.cancel(flingTask); flingTask = nil end
    end
end)
registerControl(Settings.Move, "Fling", flingToggleRef)

window:CreateButton(movementTab, "Autokill (Reset)", function()
    local h = getHum(); if h then h.Health = 0 end
end)

window:CreateLabel(aimbotTab, "Camera Aimbot")
mm2LockRef = window:CreateToggle(aimbotTab, "Aimbot", false, function(v)
    Settings.Aimbot.Camera = v
    if camConn then camConn:Disconnect(); camConn = nil end
    if v then
        camConn = RunService.RenderStepped:Connect(function()
            if not Settings.Aimbot.Camera then return end
            local m = getMurderer()
            if not m or not m.Character then return end
            local part = boneOf(m.Character, Settings.Aimbot.Target)
            local hrp = getHRP()
            if not part or not hrp then return end
            if (hrp.Position - part.Position).Magnitude > Settings.Aimbot.Range then return end
            if Settings.Aimbot.WallCheck and not isVisible(Camera.CFrame.Position, part.Position, m.Character) then return end
            if Settings.Aimbot.FOV then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if not on then return end
                local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                if (Vector2.new(sp.X, sp.Y) - c).Magnitude > Settings.Aimbot.FOVRadius then return end
            end
            local target = CFrame.new(Camera.CFrame.Position, part.Position)
            Camera.CFrame = Camera.CFrame:Lerp(target, math.clamp(1/Settings.Aimbot.Smooth, 0.02, 1))
        end)
    end
end)
registerControl(Settings.Aimbot, "Camera", mm2LockRef)

local smoothRef = window:CreateSlider(aimbotTab, "Smoothness", 1, 30, 8, function(v) Settings.Aimbot.Smooth = v end)
registerControl(Settings.Aimbot, "Smooth", smoothRef)
local rangeRef = window:CreateSlider(aimbotTab, "Aimbot Range", 50, 1000, 500, function(v) Settings.Aimbot.Range = v end)
registerControl(Settings.Aimbot, "Range", rangeRef)
local boneRef = window:CreateDropdown(aimbotTab, "Bone", { "Head", "Torso", "HumanoidRootPart" }, "Head", function(v) Settings.Aimbot.Target = v end)
registerControl(Settings.Aimbot, "Target", boneRef)
local fovTogRef = window:CreateToggle(aimbotTab, "FOV Circle", false, function(v)
    Settings.Aimbot.FOV = v
    if v then startFOV() else stopFOV() end
end)
registerControl(Settings.Aimbot, "FOV", fovTogRef)
local fovRadRef = window:CreateSlider(aimbotTab, "FOV Radius", 40, 500, 120, function(v) Settings.Aimbot.FOVRadius = v end)
registerControl(Settings.Aimbot, "FOVRadius", fovRadRef)
local aimWallRef = window:CreateToggle(aimbotTab, "Aimbot Wall Check", true, function(v) Settings.Aimbot.WallCheck = v end)
registerControl(Settings.Aimbot, "WallCheck", aimWallRef)

window:CreateLabel(aimbotTab, "Silent Aim")
silentToggleRef = window:CreateToggle(aimbotTab, "Silent Aim", false, function(v) setSilent(v) end)
registerControl(Settings.Silent, "Enabled", silentToggleRef)
window:CreateDropdown(aimbotTab, "Silent Key", { "Q", "E", "F", "G", "H", "C", "V" }, "Q", function(v) Settings.Silent.Key = Enum.KeyCode[v] end)
window:CreateDropdown(aimbotTab, "Key Mode", { "Hold", "Toggle" }, "Hold", function(v) Settings.Silent.KeyMode = v end)
window:CreateDropdown(aimbotTab, "Silent Target", { "Murderer", "Sheriff", "Hero", "Closest" }, "Murderer", function(v) Settings.Silent.Mode = v end)
window:CreateDropdown(aimbotTab, "Silent Bone", { "Head", "Torso", "HumanoidRootPart" }, "Head", function(v) Settings.Silent.Bone = v end)
window:CreateSlider(aimbotTab, "Silent FOV", 10, 500, 150, function(v) Settings.Silent.FOV = v end)
window:CreateSlider(aimbotTab, "Prediction", 0, 0.5, 0.12, function(v) Settings.Silent.Predict = v end)
window:CreateToggle(aimbotTab, "Silent Use FOV", true, function(v) Settings.Silent.UseFOV = v end)
window:CreateToggle(aimbotTab, "Silent Wall Check", true, function(v) Settings.Silent.Wall = v end)

window:CreateLabel(aimbotTab, "Trigger Bot")
local trigRef = window:CreateToggle(aimbotTab, "Trigger Bot", false, function(v)
    Settings.Trigger.Enabled = v
    if triggerConn then triggerConn:Disconnect(); triggerConn = nil end
    if v then
        triggerConn = RunService.RenderStepped:Connect(function()
            if not Settings.Trigger.Enabled then return end
            local t, part
            if Settings.Trigger.UseSilent and silentPart then t, part = silentTarget, silentPart
            else
                t = getMurderer()
                if t and t.Character then part = boneOf(t.Character, Settings.Aimbot.Target) end
            end
            if not part or not t then return end
            local hrp = getHRP(); if not hrp then return end
            if (hrp.Position - part.Position).Magnitude > Settings.Trigger.Range then return end
            if Settings.Trigger.Wall and not isVisible(Camera.CFrame.Position, part.Position, t.Character) then return end
            local sp, on = Camera:WorldToViewportPoint(part.Position)
            if not on then return end
            local mouse = UserInputService:GetMouseLocation()
            if (Vector2.new(sp.X, sp.Y) - mouse).Magnitude < 20 then
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.02)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end)
                task.wait(Settings.Trigger.Delay)
            end
        end)
    end
end)
registerControl(Settings.Trigger, "Enabled", trigRef)
window:CreateSlider(aimbotTab, "Trigger Range", 20, 500, 150, function(v) Settings.Trigger.Range = v end)
window:CreateSlider(aimbotTab, "Trigger Delay", 0.03, 0.5, 0.1, function(v) Settings.Trigger.Delay = v end)
window:CreateToggle(aimbotTab, "Trigger Use Silent", true, function(v) Settings.Trigger.UseSilent = v end)
window:CreateToggle(aimbotTab, "Trigger Wall Check", true, function(v) Settings.Trigger.Wall = v end)

window:CreateLabel(aimbotTab, "Auto Fire")
autoFireRef = window:CreateToggle(aimbotTab, "Auto Fire [B]", false, function(v)
    Settings.Auto.Enabled = v
    if autoConn then autoConn:Disconnect(); autoConn = nil end
    if v then
        autoConn = RunService.RenderStepped:Connect(function()
            if not Settings.Auto.Enabled then return end
            local t, part
            if Settings.Auto.UseSilent and silentPart then t, part = silentTarget, silentPart
            else
                t = getMurderer()
                if t and t.Character then part = boneOf(t.Character, Settings.Aimbot.Target) end
            end
            if not part or not t then return end
            local hrp = getHRP(); if not hrp then return end
            if (hrp.Position - part.Position).Magnitude > Settings.Auto.Range then return end
            if Settings.Auto.Wall and not isVisible(Camera.CFrame.Position, part.Position, t.Character) then return end
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
            task.wait(Settings.Auto.Delay)
        end)
    end
end)
registerControl(Settings.Auto, "Enabled", autoFireRef)
window:CreateSlider(aimbotTab, "Auto Fire Range", 50, 1000, 500, function(v) Settings.Auto.Range = v end)
window:CreateSlider(aimbotTab, "Auto Fire Delay", 0.03, 0.5, 0.1, function(v) Settings.Auto.Delay = v end)
window:CreateToggle(aimbotTab, "Auto Use Silent", true, function(v) Settings.Auto.UseSilent = v end)
window:CreateToggle(aimbotTab, "Auto Wall Check", true, function(v) Settings.Auto.Wall = v end)

window:CreateLabel(aimbotTab, "Murderer OP")
window:CreateButton(aimbotTab, "Kill Everyone", function()
    if not isMurdererLocal() then notify("You are not Murderer"); return end
    if killAllRunning then return end
    killAllRunning = true
    notify("Killing everyone")
    task.spawn(function()
        local start = tick()
        while killAllRunning and tick() - start < 5 do
            for _, p in ipairs(Players:GetPlayers()) do
                if not killAllRunning then break end
                if p ~= LocalPlayer and p.Character then
                    local h = p.Character:FindFirstChild("HumanoidRootPart")
                    local m = getHRP()
                    if h and m then
                        m.CFrame = CFrame.new(h.Position, h.Position + h.CFrame.LookVector)
                        task.wait(0.08)
                        pcall(function()
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            task.wait(0.02)
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        end)
                    end
                end
            end
            task.wait(0.05)
        end
        killAllRunning = false
        notify("Done")
    end)
end)

window:CreateLabel(avatarTab, "Avatar")
window:CreateParagraph(avatarTab, "Local effects · Re-apply on respawn")

local function applyKorblox()
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.RigType == Enum.HumanoidRigType.R15 then
        local rf, rl, ru = char:FindFirstChild("RightFoot"), char:FindFirstChild("RightLowerLeg"), char:FindFirstChild("RightUpperLeg")
        if ru and rl and rf then
            rf.Transparency = 1; rl.Transparency = 1
            local mesh = ru:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh", ru)
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = "rbxassetid://902942096"
            mesh.TextureId = "rbxassetid://902843398"
            mesh.Scale = Vector3.new(1,1,1)
            ru.Color = Color3.new(1,1,1)
            ru.Transparency = 0
        end
    else
        local rl = char:FindFirstChild("Right Leg"); if not rl then return end
        for _, v in ipairs(char:GetChildren()) do if v:IsA("CharacterMesh") and v.BodyPart == Enum.BodyPart.RightLeg then v:Destroy() end end
        local mesh = rl:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh", rl)
        rl.Color = Color3.fromRGB(64,64,64); rl.Transparency = 0
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://101851696"
        mesh.TextureId = "rbxassetid://101851254"
    end
end

local function removeKorblox()
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.RigType == Enum.HumanoidRigType.R15 then
        local rf, rl, ru = char:FindFirstChild("RightFoot"), char:FindFirstChild("RightLowerLeg"), char:FindFirstChild("RightUpperLeg")
        if rf then rf.Transparency = 0 end
        if rl then rl.Transparency = 0 end
        if ru then local m = ru:FindFirstChildOfClass("SpecialMesh"); if m then m:Destroy() end end
    else
        local rl = char:FindFirstChild("Right Leg"); if not rl then return end
        local m = rl:FindFirstChildOfClass("SpecialMesh"); if m then m:Destroy() end
        rl.Color = Color3.fromRGB(163,162,165)
    end
end

local korRef = window:CreateToggle(avatarTab, "Korblox Deathspeaker", false, function(v)
    Settings.Avatar.Korblox = v
    if v then applyKorblox() else removeKorblox() end
end)
registerControl(Settings.Avatar, "Korblox", korRef)

local shRef = window:CreateToggle(avatarTab, "Shoulder Accessory", false, function(v)
    Settings.Avatar.Shoulder = v
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    for _, a in ipairs(char:GetChildren()) do if a:IsA("Accessory") and a.Name == "HH_Shoulder" then a:Destroy() end end
    if v then
        local acc = Instance.new("Accessory", char)
        acc.Name = "HH_Shoulder"
        local handle = Instance.new("Part", acc)
        handle.Name = "Handle"; handle.Size = Vector3.new(1,1,1); handle.CanCollide = false
        local mesh = Instance.new("SpecialMesh", handle)
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://110121730336323"
        local att = Instance.new("Attachment", handle); att.Name = "BodyFrontAttachment"
        pcall(function() hum:AddAccessory(acc) end)
    end
end)
registerControl(Settings.Avatar, "Shoulder", shRef)

local invRef = window:CreateToggle(avatarTab, "Invisible", false, function(v)
    Settings.Avatar.Invisible = v
    local char = LocalPlayer.Character; if not char then return end
    if v then
        _origTransp = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then _origTransp[p] = p.Transparency; p.Transparency = 1 end
        end
    else
        for p, t in pairs(_origTransp) do if p and p.Parent then p.Transparency = t end end
        _origTransp = {}
    end
end)
registerControl(Settings.Avatar, "Invisible", invRef)

local nfRef = window:CreateToggle(avatarTab, "Classic Noob Face", false, function(v)
    Settings.Avatar.NoobFace = v
    local char = LocalPlayer.Character; if not char then return end
    local head = char:FindFirstChild("Head"); if not head then return end
    local face = head:FindFirstChildOfClass("Decal") or Instance.new("Decal", head)
    face.Name = "face"
    face.Texture = v and "rbxassetid://1079" or "rbxassetid://1369239677"
end)
registerControl(Settings.Avatar, "NoobFace", nfRef)

local rbRef = window:CreateToggle(avatarTab, "Rainbow Body", false, function(v)
    Settings.Avatar.Rainbow = v
    local char = LocalPlayer.Character; if not char then return end
    if v then
        _origColors = {}
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") then _origColors[p.Name] = p.Color; p.Color = Color3.fromHSV(math.random(), 0.9, 1) end
        end
        if not CONN.rainbow then
            CONN.rainbow = RunService.Heartbeat:Connect(function()
                if not Settings.Avatar.Rainbow then return end
                local c = LocalPlayer.Character; if not c then return end
                for _, p in ipairs(c:GetChildren()) do if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Color = Color3.fromHSV((tick()*0.3) % 1, 0.9, 1) end end
            end)
        end
    else
        for n, c in pairs(_origColors) do
            local p = char:FindFirstChild(n); if p and p:IsA("BasePart") then p.Color = c end
        end
        _origColors = {}
        if CONN.rainbow then CONN.rainbow:Disconnect(); CONN.rainbow = nil end
    end
end)
registerControl(Settings.Avatar, "Rainbow", rbRef)

window:CreateButton(avatarTab, "Remove All Mods", function()
    if korRef then korRef.SetState(false) end
    if shRef then shRef.SetState(false) end
    if invRef then invRef.SetState(false) end
    if nfRef then nfRef.SetState(false) end
    if rbRef then rbRef.SetState(false) end
end)

window:CreateLabel(farmTab, "Continuous Farm")
window:CreateParagraph(farmTab, "Runs 24/7. Never stops. Auto-evade murderer.")

farmToggleRef = window:CreateToggle(farmTab, "Auto Farm (Continuous)", false, function(v)
    Settings.Farm.Enabled = v
    if v then
        if farmStatus then farmStatus("Starting") end
        startFarm()
    else
        stopFarm()
    end
end)
registerControl(Settings.Farm, "Enabled", farmToggleRef)

local evadeRef = window:CreateToggle(farmTab, "Auto Evade Murderer", true, function(v) Settings.Farm.Evade = v end)
registerControl(Settings.Farm, "Evade", evadeRef)

local farmSpdRef = window:CreateSlider(farmTab, "Farm Speed", 10, 80, 25, function(v) Settings.Farm.Speed = v end)
registerControl(Settings.Farm, "Speed", farmSpdRef)

window:CreateLabel(farmTab, "Live")
local farmCountFrame = window:CreateParagraph(farmTab, "0 coins")
local farmCountLbl = farmCountFrame:FindFirstChildOfClass("TextLabel")
local farmStatusFrame = window:CreateParagraph(farmTab, "Idle")
local farmStatusLbl = farmStatusFrame:FindFirstChildOfClass("TextLabel")

farmStatus = function(txt) if farmStatusLbl then farmStatusLbl.Text = txt end end
farmCount = function(n) if farmCountLbl then farmCountLbl.Text = n .. " coins" end end

task.spawn(function()
    while true do
        task.wait(0.5)
        if Settings.Farm.Enabled and not farmConn then startFarm() end
    end
end)

local r = ReplicatedStorage:FindFirstChild("Remotes")
local g = r and r:FindFirstChild("Gameplay")
if g then
    local cs = g:FindFirstChild("CoinsStarted")
    if cs then cs.OnClientEvent:Connect(function() if Settings.Farm.Enabled and not farmConn then startFarm() end end) end
    local cc = g:FindFirstChild("CoinCollected")
    if cc then cc.OnClientEvent:Connect(function(bagName, n)
        total = (total or 0) + n
        if farmCount then farmCount(total) end
    end) end
    local re = g:FindFirstChild("RoundEndFade")
    if re then re.OnClientEvent:Connect(function()
        if Settings.Farm.Enabled then task.wait(1); if Settings.Farm.Enabled and not farmConn then startFarm() end end
    end) end
end

window:CreateLabel(miscTab, "Gun")
window:CreateButton(miscTab, "Pick up Gun", function()
    local gun = findGunDrop()
    local hrp = getHRP()
    if not gun or not hrp then notify("No gun/HRP"); return end
    if not fireTP(gun, hrp) then gun.CFrame = hrp.CFrame end
    task.wait(0.03)
    if gun and gun.Parent then gun.CFrame = hrp.CFrame; gun.Velocity = Vector3.zero end
    notify("Gun incoming")
end)

local agRef = window:CreateToggle(miscTab, "Auto Pick up Gun", false, function(v)
    Settings.Misc.AutoGun = v
    if v then
        if autoGunThread then return end
        autoGunThread = task.spawn(function()
            while Settings.Misc.AutoGun do
                task.wait(0.4)
                local gun = findGunDrop()
                local hrp = getHRP()
                if gun and hrp then
                    if not fireTP(gun, hrp) then gun.CFrame = hrp.CFrame end
                    task.wait(0.05)
                    if gun and gun.Parent then gun.CFrame = hrp.CFrame; gun.Velocity = Vector3.zero end
                end
            end
            autoGunThread = nil
        end)
    else
        if autoGunThread then task.cancel(autoGunThread); autoGunThread = nil end
    end
end)
registerControl(Settings.Misc, "AutoGun", agRef)

window:CreateLabel(miscTab, "Animations")
window:CreateButton(miscTab, "Laugh", function()
    local tcs = TextChatService
    if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
        local ch = tcs.TextChannels:FindFirstChild("RBXGeneral")
        if ch then pcall(function() ch:SendAsync("/e laugh") end) end
    else
        local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if ev then local sr = ev:FindFirstChild("SayMessageRequest"); if sr then pcall(function() sr:FireServer("/e laugh", "All") end) end end
    end
end)

if window._makeMobileBtn and isMobile then
    window._makeMobileBtn("AIM", function() if mm2LockRef then mm2LockRef.SetState(not mm2LockRef.GetState()) end end)
    window._makeMobileBtn("ESP", function() if mm2ESPToggleRef then mm2ESPToggleRef.SetState(not mm2ESPToggleRef.GetState()) end end)
    window._makeMobileBtn("FARM", function() if farmToggleRef then farmToggleRef.SetState(not farmToggleRef.GetState()) end end)
    window._makeMobileBtn("UI", function() window.ToggleUI() end)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Settings.Silent.Key then
        if Settings.Silent.KeyMode == "Toggle" then
            setSilent(not silentActive)
            if silentToggleRef then silentToggleRef.SetState(silentActive) end
        else
            setSilent(true)
        end
    elseif input.KeyCode == Enum.KeyCode.T then
        if mm2LockRef then mm2LockRef.SetState(not mm2LockRef.GetState()) end
    elseif input.KeyCode == Enum.KeyCode.O then
        if mm2ESPToggleRef then mm2ESPToggleRef.SetState(not mm2ESPToggleRef.GetState()) end
    elseif input.KeyCode == Enum.KeyCode.B then
        if autoFireRef then autoFireRef.SetState(not autoFireRef.GetState()) end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Settings.Silent.Key and Settings.Silent.KeyMode == "Hold" then
        setSilent(false)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.6)
    if Settings.Move.Fly then attachFly() end
    if Settings.Avatar.Korblox then pcall(applyKorblox) end
    if Settings.Farm.Enabled and not farmConn then startFarm() end
end)

window:SetConfigSnapshot(function()
    return {
        Aimbot = Settings.Aimbot,
        Silent = { Enabled = Settings.Silent.Enabled, Mode = Settings.Silent.Mode, Bone = Settings.Silent.Bone, FOV = Settings.Silent.FOV, UseFOV = Settings.Silent.UseFOV, Wall = Settings.Silent.Wall, Predict = Settings.Silent.Predict, Key = Settings.Silent.Key.Name, KeyMode = Settings.Silent.KeyMode },
        Trigger = Settings.Trigger,
        Auto = Settings.Auto,
        Visual = Settings.Visual,
        Misc = Settings.Misc,
        Move = Settings.Move,
        Avatar = Settings.Avatar,
        Farm = Settings.Farm,
        Theme = API:GetTheme(),
    }
end)

window:SetConfigApply(function(data)
    if not data then return end
    if data.Aimbot then for k, v in pairs(data.Aimbot) do Settings.Aimbot[k] = v end end
    if data.Silent then
        for k, v in pairs(data.Silent) do
            if k == "Key" then Settings.Silent.Key = Enum.KeyCode[v] or Enum.KeyCode.Q
            else Settings.Silent[k] = v end
        end
        setSilent(Settings.Silent.Enabled)
    end
    if data.Trigger then for k, v in pairs(data.Trigger) do Settings.Trigger[k] = v end end
    if data.Auto then for k, v in pairs(data.Auto) do Settings.Auto[k] = v end end
    if data.Visual then for k, v in pairs(data.Visual) do Settings.Visual[k] = v end end
    if data.Misc then for k, v in pairs(data.Misc) do Settings.Misc[k] = v end end
    if data.Move then for k, v in pairs(data.Move) do Settings.Move[k] = v end end
    if data.Avatar then for k, v in pairs(data.Avatar) do Settings.Avatar[k] = v end end
    if data.Farm then
        for k, v in pairs(data.Farm) do Settings.Farm[k] = v end
        if Settings.Farm.Enabled then startFarm() else stopFarm() end
    end
    if data.Theme and data.Theme ~= API:GetTheme() then API:SetTheme(data.Theme) end
    refreshAllESP()
    applyGunESP()
    API:SyncUIControls()
end)

window:BuildConfigPage()

API:Notify("Welcome back, " .. LocalPlayer.DisplayName, 3)
