local API
do
    local ok, err = pcall(function()
        API = loadstring(game:HttpGet("https://raw.githubusercontent.com/overthcode2011-stack/HHB-MM2-/refs/heads/main/template.lua"))()
    end)
    if not ok or type(API) ~= "table" then
        warn("[HappyHub] Template load failed: " .. tostring(err))
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
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local HOME_ICON = "131878842124084"
local AIM_ICON  = "119272570124806"
local VIS_ICON  = "13321848320"
local PLR_ICON  = "16485180075"
local MOV_ICON  = "112623004490927"
local MISC_ICON = "109962716823639"
local AVT_ICON  = "116651535114885"
local FARM_ICON = "74133076168703"

local AimbotSettings = {
    MM2LockOn = false, MM2Smooth = 8, MM2Range = 500, MM2Target = "Small Avatar",
    TriggerBot = false, TriggerRange = 150, AutoFire = false, WallCheck = true,
}
local VisualSettings = { MM2ESP = false, OGESP = false, NameTags = false }
local MiscSettings = {
    InfJump = false, AntiAFK = false, AutoTpGun = false,
    SilentAim = false, MusicCompanion = false,
}
local MovementSettings = {
    Noclip = false, God = false, Fly = false, WalkSpeed = 16, JumpPower = 50,
    FlySpeed = 40, AntiFling = false, Fling = false, TPAll = false,
}
local AvatarSettings = { Korblox = false, Shoulder = false, Invisible = false, NoobFace = false, Rainbow = false }
local FarmSettings = { AutoFarm = false, ManualCollect = false, CoinSpeed = 20, PickupRadius = 3 }

local function notify(msg, dur) pcall(function() API:Notify(msg, dur) end) end
local function registerControl(t, k, c) pcall(function() API:RegisterControl(t, k, c) end) end

local noclipConn, godConn, antiAFKConn, flyConn, flyBV, flyBG
local mm2Conn, silentAimConn, triggerBotConn, autoFireConn
local autoTpGunThread, flingTask, tpAllTask, nameTagUpdater, mm2PeriodicThread
local antiFlingConnections = {}
local antiFlingActive = false
local flingRunning = false
local tpAllRunning = false
local killAllRunning = false
local musicSound = nil
local _origTransparencies = {}
local _origBodyColors = {}

local CoinCollecting = false
local CoinConnection = nil
local CoinVelocity = nil
local CoinGyro = nil
local CoinSpeed = 20
local CoinRadius = 3
local roundActive = false
local bagProgress = {}
local totalCoins = 0
local coinStatusSetter = nil
local coinCountSetter = nil

local RoleCache = {}

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
    local info = RoleCache[plr.Name]
    if info and info.Role then return info.Role end
    return nil
end

local function getMM2Role(plr)
    if plr == LocalPlayer then return "Innocent" end
    local cached = getRoleFromCache(plr)
    if cached then return cached end
    local char = plr.Character
    local bp = plr:FindFirstChildOfClass("Backpack")
    if hasTool(char, "Knife") or hasTool(bp, "Knife") then return "Murderer" end
    if hasTool(char, "Gun") or hasTool(bp, "Gun") then return "Sheriff" end
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

local function getSheriff()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if getRoleFromCache(plr) == "Sheriff" then return plr end
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

local function getPlayerWithItem(itemName)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local bp = plr:FindFirstChild("Backpack")
            if (char and char:FindFirstChild(itemName)) or (bp and bp:FindFirstChild(itemName)) then
                return plr
            end
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

local tpEvent = nil
local function getTpEvent()
    if tpEvent and tpEvent.Parent then return tpEvent end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    local gameplay = remotes:FindFirstChild("Gameplay")
    if not gameplay then return nil end
    tpEvent = gameplay:FindFirstChild("TeleportToPart")
    return tpEvent
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
    if fireTeleportToPart(gun, hrp) then
        moved = true
    end

    task.wait(0.03)
    if gun and gun.Parent then
        gun.CFrame = hrp.CFrame
        gun.Velocity = Vector3.zero
        gun.RotVelocity = Vector3.zero
        moved = true
    end

    return moved, moved and "remote" or "fallback"
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

local ESP = {
    active = { MM2 = false, OG = false, NameTag = false },
    highlights = { MM2 = {}, OG = {} },
    nameTags = {},
}
local ESP_COLORS = {
    MM2 = {
        Murderer = Color3.fromRGB(255, 0, 0),
        Sheriff  = Color3.fromRGB(0, 132, 255),
        Innocent = Color3.fromRGB(56, 255, 112),
    },
    OG = Color3.fromRGB(255, 255, 255),
}

local function clearHighlights(plr)
    if ESP.highlights.MM2[plr] then ESP.highlights.MM2[plr]:Destroy(); ESP.highlights.MM2[plr] = nil end
    if ESP.highlights.OG[plr] then ESP.highlights.OG[plr]:Destroy(); ESP.highlights.OG[plr] = nil end
    if ESP.nameTags[plr] then
        if ESP.nameTags[plr].bb and ESP.nameTags[plr].bb.Parent then ESP.nameTags[plr].bb:Destroy() end
        ESP.nameTags[plr] = nil
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
            h.OutlineColor = color
            h.FillTransparency = 0.2
            h.OutlineTransparency = 1
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = char
            ESP.highlights.MM2[plr] = h
        else
            ESP.highlights.MM2[plr].FillColor = color
            ESP.highlights.MM2[plr].OutlineColor = color
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
            h.OutlineColor = ESP_COLORS.OG
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
                lbl.Size = UDim2.new(1, 0, 1, 0)
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
end

local function startNameTagUpdater()
    if nameTagUpdater then return end
    nameTagUpdater = RunService.Heartbeat:Connect(function()
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
    if nameTagUpdater then nameTagUpdater:Disconnect(); nameTagUpdater = nil end
end

local function getFadeEvent()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    local gameplay = remotes:FindFirstChild("Gameplay")
    if not gameplay then return nil end
    return gameplay:FindFirstChild("Fade")
end

local function updateRoleCache(data)
    if type(data) ~= "table" then return end
    for username, info in pairs(data) do
        if type(info) == "table" and info.Role then
            RoleCache[username] = {
                UserId = info.UserId,
                Role   = info.Role,
                Dead   = info.Dead or false,
                Perk   = info.Perk,
                Knife  = info.Knife,
                Gun    = info.Gun,
                XP     = info.XP,
                Killed = info.Killed or false,
            }
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if plr.Character then applyESP(plr) else clearHighlights(plr) end
        end
    end
end

local fadeConn = nil
local function hookFadeEvent()
    if fadeConn then fadeConn:Disconnect(); fadeConn = nil end
    local ev = getFadeEvent()
    if not ev then return end
    fadeConn = ev.OnClientEvent:Connect(function(...)
        updateRoleCache(...)
    end)
end

hookFadeEvent()

task.spawn(function()
    while true do
        task.wait(3)
        if not fadeConn or not getFadeEvent() then
            hookFadeEvent()
        end
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
    RoleCache[plr.Name] = nil
end)

local function applyKorblox()
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.RigType == Enum.HumanoidRigType.R15 then
        local rf = char:FindFirstChild("RightFoot")
        local rl = char:FindFirstChild("RightLowerLeg")
        local ru = char:FindFirstChild("RightUpperLeg")
        if ru and rl and rf then
            rf.Transparency = 1; rl.Transparency = 1
            ru.MeshId = "rbxassetid://902942096"
            ru.TextureID = "rbxassetid://902843398"
            ru.Color = Color3.new(1, 1, 1); ru.Transparency = 0
        end
    else
        local rightLeg = char:FindFirstChild("Right Leg"); if not rightLeg then return end
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("CharacterMesh") and v.BodyPart == Enum.BodyPart.RightLeg then v:Destroy() end
        end
        local mesh = rightLeg:FindFirstChildOfClass("SpecialMesh")
        if not mesh then mesh = Instance.new("SpecialMesh"); mesh.Parent = rightLeg end
        rightLeg.Color = Color3.fromRGB(64, 64, 64); rightLeg.Transparency = 0
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://101851696"
        mesh.TextureId = "rbxassetid://101851254"
        mesh.Scale = Vector3.new(1, 1, 1)
    end
end

local function removeKorblox()
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.RigType == Enum.HumanoidRigType.R15 then
        local rf = char:FindFirstChild("RightFoot")
        local rl = char:FindFirstChild("RightLowerLeg")
        local ru = char:FindFirstChild("RightUpperLeg")
        if rf then rf.Transparency = 0 end
        if rl then rl.Transparency = 0 end
        if ru then ru.MeshId = ""; ru.TextureID = "" end
    else
        local rightLeg = char:FindFirstChild("Right Leg"); if not rightLeg then return end
        local mesh = rightLeg:FindFirstChildOfClass("SpecialMesh")
        if mesh then mesh:Destroy() end
        rightLeg.Color = Color3.fromRGB(163, 162, 165)
    end
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
    local cam = workspace.CurrentCamera
    local camDir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
    local myPos = myHRP.Position
    local bestPart, bestScore = nil, -math.huge
    for _, child in ipairs(coinContainer:GetChildren()) do
        local part = child:IsA("BasePart") and child or (child:IsA("Model") and child.PrimaryPart)
        if part and part:IsA("BasePart") then
            local delta = part.Position - myPos
            local dist = delta.Magnitude
            if dist > 0.1 then
                local dir = delta.Unit
                local dot = dir:Dot(camDir)
                if dot > -0.2 then
                    local score = (dot * 100) - (dist * 0.5)
                    if dot > 0.8 and dist < 15 then score = score + 200 end
                    if score > bestScore then bestScore = score; bestPart = part end
                end
            end
        end
    end
    if not bestPart then
        local closest, minDist = nil, math.huge
        for _, child in ipairs(coinContainer:GetChildren()) do
            local part = child:IsA("BasePart") and child or (child:IsA("Model") and child.PrimaryPart)
            if part and part:IsA("BasePart") then
                local d = (part.Position - myPos).Magnitude
                if d < minDist then minDist = d; closest = part end
            end
        end
        bestPart = closest
    end
    return bestPart
end

local function stopCoinCollector()
    if not CoinCollecting then return end
    CoinCollecting = false
    if CoinConnection then CoinConnection:Disconnect(); CoinConnection = nil end
    if CoinVelocity then CoinVelocity:Destroy(); CoinVelocity = nil end
    if CoinGyro then CoinGyro:Destroy(); CoinGyro = nil end
    if coinStatusSetter then coinStatusSetter("Idle") end
end

local function startCoinCollector()
    if CoinCollecting then return end
    if not getCoinContainer() then
        if coinStatusSetter then coinStatusSetter("No coins") end
        return
    end
    CoinCollecting = true
    if coinStatusSetter then coinStatusSetter("Collecting") end

    local hrp = getHRP()
    if not hrp then stopCoinCollector(); return end

    CoinVelocity = Instance.new("BodyVelocity")
    CoinVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    CoinVelocity.Parent = hrp

    CoinGyro = Instance.new("BodyGyro")
    CoinGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    CoinGyro.P = 1e4
    CoinGyro.CFrame = hrp.CFrame
    CoinGyro.Parent = hrp

    CoinConnection = RunService.Heartbeat:Connect(function()
        local currentHRP = getHRP()
        if not currentHRP then stopCoinCollector(); return end

        local murderer = getMurderer()
        local evadeDirection = nil
        if murderer and murderer.Character then
            local murderHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
            if murderHRP then
                local distToMurderer = (currentHRP.Position - murderHRP.Position).Magnitude
                if distToMurderer < 25 then
                    evadeDirection = (currentHRP.Position - murderHRP.Position).Unit
                    if coinStatusSetter then coinStatusSetter("Evading") end
                end
            end
        end

        if evadeDirection then
            local targetVel = evadeDirection * math.min(CoinSpeed * 1.5, 75)
            CoinVelocity.Velocity = targetVel
            CoinGyro.CFrame = CFrame.lookAt(currentHRP.Position, currentHRP.Position + evadeDirection)
            local cam = workspace.CurrentCamera
            if cam then
                cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(currentHRP.Position, currentHRP.Position + evadeDirection), 0.2)
            end
            return
        end

        local target = getBestCoin()
        if not target then
            CoinVelocity.Velocity = Vector3.zero
            if coinStatusSetter then coinStatusSetter("Idle") end
            stopCoinCollector()
            return
        end

        local direction = (target.Position - currentHRP.Position).Unit
        CoinVelocity.Velocity = direction * CoinSpeed
        CoinGyro.CFrame = CFrame.lookAt(currentHRP.Position, target.Position)
        local cam = workspace.CurrentCamera
        if cam then
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(currentHRP.Position, target.Position), 0.2)
        end
        if coinStatusSetter then coinStatusSetter("Collecting") end
    end)
end

local function attachFlyBodyMovers()
    local hrp = getHRP(); local hum = getHumanoid()
    if not hrp or not hum then return end
    hum.PlatformStand = true
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
    flyBV = Instance.new("BodyVelocity")
    flyBV.Velocity = Vector3.zero
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBG.P = 1e4
    flyBG.CFrame = hrp.CFrame
    flyBG.Parent = hrp
end

local function detachFlyBodyMovers()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    local hum = getHumanoid()
    if hum then hum.PlatformStand = false end
end

local function startFly()
    if flyConn then return end
    attachFlyBodyMovers()
    flyConn = RunService.Heartbeat:Connect(function()
        if not MovementSettings.Fly then return end
        local h = getHRP()
        if not h then return end
        if not flyBV or not flyBV.Parent then attachFlyBodyMovers() end
        if not flyBV or not flyBG then return end

        local cf = workspace.CurrentCamera.CFrame
        local mv = Vector3.zero
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
        flyBV.Velocity = mv.Magnitude > 0 and mv.Unit * MovementSettings.FlySpeed or Vector3.zero
        flyBG.CFrame = cf
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    detachFlyBodyMovers()
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

local homeTab      = window:CreateTab("Home", HOME_ICON)
local playersTab   = window:CreateTab("Players", PLR_ICON)
local espTab       = window:CreateTab("ESP", VIS_ICON)
local movementTab  = window:CreateTab("Movement", MOV_ICON)
local aimbotTab    = window:CreateTab("Aimbot", AIM_ICON)
local avatarTab    = window:CreateTab("Avatar", AVT_ICON)
local farmTab      = window:CreateTab("Farm", FARM_ICON)
local miscTab      = window:CreateTab("Misc", MISC_ICON)

window:CreateLabel(homeTab, "Happy Hub")
window:CreateParagraph(homeTab, "Best free hub · Since 2026 · v11 Update · MM2 Project")

window:CreateLabel(homeTab, "Music")
local musicToggleRef = window:CreateToggle(homeTab, "Companion", false, function(v)
    MiscSettings.MusicCompanion = v
    if v then
        if musicSound then musicSound:Destroy(); musicSound = nil end
        musicSound = Instance.new("Sound")
        musicSound.SoundId = "rbxassetid://98012717802240"
        musicSound.Volume = 10
        musicSound.Looped = true
        musicSound.Parent = SoundService
        musicSound:Play()
        notify("Playing: Companion")
    else
        if musicSound then musicSound:Stop(); musicSound:Destroy(); musicSound = nil end
        notify("Music stopped")
    end
end)
registerControl(MiscSettings, "MusicCompanion", musicToggleRef)

window:CreateLabel(homeTab, "Creators")
window:CreateParagraph(homeTab, "@OverthaneRBX · Developer · Hub Creator")
window:CreateParagraph(homeTab, "@ReplicatedBacon_0 · Co-Owner · Test & Scripts")
window:CreateParagraph(homeTab, "@odecode · Hexagonal Client · Farm Engine")

window:CreateLabel(homeTab, "Features")
window:CreateParagraph(homeTab, "Players · ESP · Movement · Aimbot · Avatar · Farm · Misc · Configs")

window:CreateLabel(playersTab, "Teleport")
local tpAllToggleRef = window:CreateToggle(playersTab, "TP All (Loop)", false, function(v)
    MovementSettings.TPAll = v
    if v then
        tpAllRunning = true
        tpAllTask = task.spawn(function()
            while tpAllRunning do
                for _, plr in ipairs(Players:GetPlayers()) do
                    if not tpAllRunning then break end
                    if plr ~= LocalPlayer then
                        teleportToPlayer(plr)
                        task.wait(0.1)
                    end
                end
                task.wait(0.1)
            end
        end)
    else
        tpAllRunning = false
        if tpAllTask then task.cancel(tpAllTask); tpAllTask = nil end
    end
end)
registerControl(MovementSettings, "TPAll", tpAllToggleRef)

window:CreateLabel(playersTab, "Role Teleport")
_G.__HH_TpTarget = "Murder"
window:CreateDropdown(playersTab, "Target", { "Murder", "Sheriff" }, "Murder", function(v)
    _G.__HH_TpTarget = v
end)

window:CreateButton(playersTab, "Teleport to Target", function()
    local target = _G.__HH_TpTarget
    local plr = (target == "Sheriff") and getSheriff() or getMurderer()
    if teleportToPlayer(plr) then
        notify("Teleported to " .. target)
    else
        notify("No " .. target .. " found")
    end
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

window:CreateLabel(espTab, "Role Viewer")
local mm2ESPToggleRef = window:CreateToggle(espTab, "Murder Mystery 2", false, function(v)
    ESP.active.MM2 = v
    VisualSettings.MM2ESP = v
    refreshAllESP()
    if v then
        if not mm2PeriodicThread then
            mm2PeriodicThread = task.spawn(function()
                while ESP.active.MM2 do
                    task.wait(1)
                    if ESP.active.MM2 then refreshAllESP() end
                end
                mm2PeriodicThread = nil
            end)
        end
    else
        if mm2PeriodicThread then task.cancel(mm2PeriodicThread); mm2PeriodicThread = nil end
    end
end)
registerControl(VisualSettings, "MM2ESP", mm2ESPToggleRef)

local ogESPToggleRef = window:CreateToggle(espTab, "Neutral", false, function(v)
    ESP.active.OG = v
    VisualSettings.OGESP = v
    refreshAllESP()
end)
registerControl(VisualSettings, "OGESP", ogESPToggleRef)

window:CreateLabel(espTab, "Options")
local nameTagToggleRef = window:CreateToggle(espTab, "Nametag", false, function(v)
    ESP.active.NameTag = v
    VisualSettings.NameTags = v
    refreshAllESP()
    if v then startNameTagUpdater() else stopNameTagUpdater() end
end)
registerControl(VisualSettings, "NameTags", nameTagToggleRef)

window:CreateLabel(movementTab, "Fly")
local flyToggleRef = window:CreateToggle(movementTab, "Active Fly", false, function(v)
    MovementSettings.Fly = v
    if v then startFly() else stopFly() end
end)
registerControl(MovementSettings, "Fly", flyToggleRef)

local flySpeedRef = window:CreateSlider(movementTab, "Fly Speed", 5, 200, 40, function(v) MovementSettings.FlySpeed = v end)
registerControl(MovementSettings, "FlySpeed", flySpeedRef)

window:CreateParagraph(movementTab, "WASD + Space / LeftControl")

window:CreateLabel(movementTab, "Speed")
local walkSpeedRef = window:CreateSlider(movementTab, "Walk Speed", 4, 150, 16, function(v)
    MovementSettings.WalkSpeed = v
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = v end
end)
registerControl(MovementSettings, "WalkSpeed", walkSpeedRef)

local jumpPowerRef = window:CreateSlider(movementTab, "Jump Power", 10, 200, 50, function(v)
    MovementSettings.JumpPower = v
    local hum = getHumanoid()
    if hum then hum.JumpPower = v; hum.UseJumpPower = true end
end)
registerControl(MovementSettings, "JumpPower", jumpPowerRef)

window:CreateLabel(movementTab, "Modifications")
local noclipRef = window:CreateToggle(movementTab, "Noclip", false, function(v)
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
    else
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end)
registerControl(MovementSettings, "Noclip", noclipRef)

local godRef = window:CreateToggle(movementTab, "God Mode", false, function(v)
    MovementSettings.God = v
    if godConn then godConn:Disconnect(); godConn = nil end
    if v then
        godConn = RunService.Heartbeat:Connect(function()
            local hum = getHumanoid()
            if hum then hum.Health = hum.MaxHealth end
        end)
    end
end)
registerControl(MovementSettings, "God", godRef)

local ijRef = window:CreateToggle(movementTab, "Infinite Jump", false, function(v)
    MiscSettings.InfJump = v
end)
registerControl(MiscSettings, "InfJump", ijRef)

UserInputService.JumpRequest:Connect(function()
    if MiscSettings.InfJump then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local afkRef = window:CreateToggle(movementTab, "Anti-AFK", false, function(v)
    MiscSettings.AntiAFK = v
    if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
    if v then
        local vu = game:GetService("VirtualUser")
        antiAFKConn = LocalPlayer.Idled:Connect(function()
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end)
registerControl(MiscSettings, "AntiAFK", afkRef)

local antiFlingRef = window:CreateToggle(movementTab, "Anti-Fling", false, function(v)
    MovementSettings.AntiFling = v
    if v then
        antiFlingActive = true
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
                if antiFlingActive then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CanCollide = false end
                end
            end)
        end)
        table.insert(antiFlingConnections, conn)
    else
        antiFlingActive = false
        local function enableHRPCollision(plr)
            if plr == LocalPlayer then return end
            local char = plr.Character; if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CanCollide = true end
        end
        for _, plr in ipairs(Players:GetPlayers()) do enableHRPCollision(plr) end
        for _, c in ipairs(antiFlingConnections) do c:Disconnect() end
        antiFlingConnections = {}
    end
end)
registerControl(MovementSettings, "AntiFling", antiFlingRef)

window:CreateLabel(movementTab, "Animations")
window:CreateButton(movementTab, "Play /e laugh", function()
    local tcs = TextChatService
    if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
        local channel = tcs.TextChannels:FindFirstChild("RBXGeneral")
        if channel then pcall(function() channel:SendAsync("/e laugh") end) end
    else
        local event = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if event then
            local sayReq = event:FindFirstChild("SayMessageRequest")
            if sayReq then pcall(function() sayReq:FireServer("/e laugh", "All") end) end
        end
    end
end)

window:CreateLabel(movementTab, "Reset Character")
window:CreateButton(movementTab, "Autokill", function()
    local hum = getHumanoid()
    if hum then hum.Health = 0 end
end)

window:CreateLabel(movementTab, "Fling")
local flingRef = window:CreateToggle(movementTab, "Fling All", false, function(v)
    MovementSettings.Fling = v
    if v then
        if flingRunning then return end
        flingRunning = true
        flingTask = task.spawn(function()
            while flingRunning do
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
            flingTask = nil
        end)
    else
        flingRunning = false
        if flingTask then task.cancel(flingTask); flingTask = nil end
        local hrp = getHRP()
        if hrp then hrp.Velocity = Vector3.zero end
    end
end)
registerControl(MovementSettings, "Fling", flingRef)

window:CreateLabel(aimbotTab, "Murder Mystery")
local mm2LockRef = window:CreateToggle(aimbotTab, "Lock-On Murderer", false, function(v)
    AimbotSettings.MM2LockOn = v
    if mm2Conn then mm2Conn:Disconnect(); mm2Conn = nil end
    if v then
        mm2Conn = RunService.RenderStepped:Connect(function()
            if not AimbotSettings.MM2LockOn then return end
            local murderer = getMurderer()
            if not murderer or not murderer.Character then return end
            local targetPart = getMM2TargetPart(murderer.Character)
            local myHRP = getHRP()
            if not targetPart or not myHRP then return end
            local dist = (myHRP.Position - targetPart.Position).Magnitude
            if dist > AimbotSettings.MM2Range then return end
            local camera = workspace.CurrentCamera
            local targetCF = CFrame.new(camera.CFrame.Position, targetPart.Position)
            local alpha = math.clamp(1 / AimbotSettings.MM2Smooth, 0.02, 1)
            camera.CFrame = camera.CFrame:Lerp(targetCF, alpha)
        end)
    end
end)
registerControl(AimbotSettings, "MM2LockOn", mm2LockRef)

local mm2SmoothRef = window:CreateSlider(aimbotTab, "Smoothness", 1, 30, 8, function(v) AimbotSettings.MM2Smooth = v end)
registerControl(AimbotSettings, "MM2Smooth", mm2SmoothRef)

local mm2RangeRef = window:CreateSlider(aimbotTab, "Distance", 50, 1000, 500, function(v) AimbotSettings.MM2Range = v end)
registerControl(AimbotSettings, "MM2Range", mm2RangeRef)

local mm2TargetRef = window:CreateDropdown(aimbotTab, "Target Bone", { "Head", "Torso", "Small Avatar" }, "Small Avatar", function(v)
    AimbotSettings.MM2Target = v
end)
registerControl(AimbotSettings, "MM2Target", mm2TargetRef)

window:CreateParagraph(aimbotTab, "Small Avatar = HumanoidRootPart. Use it for short/tiny avatars.")

window:CreateLabel(aimbotTab, "Trigger Bot")
local triggerRef = window:CreateToggle(aimbotTab, "Trigger Bot", false, function(v)
    AimbotSettings.TriggerBot = v
    if triggerBotConn then triggerBotConn:Disconnect(); triggerBotConn = nil end
    if v then
        triggerBotConn = RunService.RenderStepped:Connect(function()
            if not AimbotSettings.TriggerBot then return end
            local murderer = getMurderer()
            if not murderer or not murderer.Character then return end
            local targetPart = getMM2TargetPart(murderer.Character)
            if not targetPart then return end
            local myHRP = getHRP()
            if not myHRP then return end
            if AimbotSettings.WallCheck then
                if not isVisible(workspace.CurrentCamera.CFrame.Position, targetPart.Position, murderer.Character) then return end
            end
            local camera = workspace.CurrentCamera
            local sp, on = camera:WorldToViewportPoint(targetPart.Position)
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
registerControl(AimbotSettings, "TriggerBot", triggerRef)

local triggerRangeRef = window:CreateSlider(aimbotTab, "Trigger Range", 20, 400, 150, function(v) AimbotSettings.TriggerRange = v end)
registerControl(AimbotSettings, "TriggerRange", triggerRangeRef)

window:CreateLabel(aimbotTab, "Auto Fire")
local autoFireRef = window:CreateToggle(aimbotTab, "Auto Fire  [B]", false, function(v)
    AimbotSettings.AutoFire = v
    if autoFireConn then autoFireConn:Disconnect(); autoFireConn = nil end
    if v then
        local lastShotTime = 0
        autoFireConn = RunService.RenderStepped:Connect(function()
            if not AimbotSettings.AutoFire then return end
            local murderer = getMurderer()
            if not murderer or not murderer.Character then return end
            local targetPart = getMM2TargetPart(murderer.Character)
            if not targetPart then return end
            if AimbotSettings.WallCheck then
                local camera = workspace.CurrentCamera
                if not isVisible(camera.CFrame.Position, targetPart.Position, murderer.Character) then return end
            end
            local now = tick()
            if now - lastShotTime < 0.15 then return end
            lastShotTime = now
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.03)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end)
    end
end)
registerControl(AimbotSettings, "AutoFire", autoFireRef)

local wallCheckRef = window:CreateToggle(aimbotTab, "Wall Check", true, function(v)
    AimbotSettings.WallCheck = v
end)
registerControl(AimbotSettings, "WallCheck", wallCheckRef)

window:CreateLabel(aimbotTab, "Kill Everyone")
window:CreateButton(aimbotTab, "Kill Everyone (Murderer only)", function()
    if not isLocalMurderer() then
        notify("You are not the Murderer")
        return
    end
    if killAllRunning then return end
    killAllRunning = true
    notify("Killing everyone...")

    task.spawn(function()
        local startTime = tick()
        local spinAngle = 0

        local spinConn = RunService.RenderStepped:Connect(function(dt)
            local hrp = getHRP()
            if not hrp then return end
            spinAngle = spinAngle + (dt * 25)
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, spinAngle, 0)
        end)

        while killAllRunning and tick() - startTime < 3 do
            for _, plr in ipairs(Players:GetPlayers()) do
                if not killAllRunning then break end
                if plr ~= LocalPlayer and plr.Character then
                    local theirHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                    local myHRP = getHRP()
                    if theirHRP and myHRP then
                        if not fireTeleportToPart(myHRP, theirHRP) then
                            myHRP.CFrame = CFrame.new(theirHRP.Position, theirHRP.Position + theirHRP.CFrame.LookVector)
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
        killAllRunning = false
    end)
end)

window:CreateLabel(avatarTab, "Avatar")
window:CreateParagraph(avatarTab, "Effects are local only. They re-apply on respawn.")

local korbloxRef = window:CreateToggle(avatarTab, "Korblox Deathspeaker", false, function(v)
    AvatarSettings.Korblox = v
    if v then applyKorblox() else removeKorblox() end
end)
registerControl(AvatarSettings, "Korblox", korbloxRef)

local shoulderRef = window:CreateToggle(avatarTab, "Shoulder Accessory", false, function(v)
    AvatarSettings.Shoulder = v
    local char = LocalPlayer.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    for _, a in ipairs(char:GetChildren()) do
        if a:IsA("Accessory") and a.Name == "HH_ShoulderAcc" then a:Destroy() end
    end
    if v then
        local acc = Instance.new("Accessory")
        acc.Name = "HH_ShoulderAcc"
        local handle = Instance.new("Part")
        handle.Name = "Handle"; handle.Size = Vector3.new(1, 1, 1)
        handle.CanCollide = false; handle.Anchored = false
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://110121730336323"
        mesh.Parent = handle
        local att = Instance.new("Attachment")
        att.Name = "BodyFrontAttachment"; att.Parent = handle
        handle.Parent = acc; acc.Parent = char
        hum:AddAccessory(acc)
    end
end)
registerControl(AvatarSettings, "Shoulder", shoulderRef)

local invisibleRef = window:CreateToggle(avatarTab, "Invisible", false, function(v)
    AvatarSettings.Invisible = v
    local char = LocalPlayer.Character; if not char then return end
    if v then
        _origTransparencies = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                _origTransparencies[p] = p.Transparency
                p.Transparency = 1
            end
        end
    else
        for p, t in pairs(_origTransparencies) do
            if p and p.Parent then p.Transparency = t end
        end
        _origTransparencies = {}
    end
end)
registerControl(AvatarSettings, "Invisible", invisibleRef)

local noobFaceRef = window:CreateToggle(avatarTab, "Classic Noob Face", false, function(v)
    AvatarSettings.NoobFace = v
    local char = LocalPlayer.Character; if not char then return end
    local head = char:FindFirstChild("Head"); if not head then return end
    local face = head:FindFirstChildOfClass("Decal")
    if not face then face = Instance.new("Decal"); face.Name = "face"; face.Parent = head end
    if v then face.Texture = "rbxassetid://1079" else face.Texture = "rbxassetid://1369239677" end
end)
registerControl(AvatarSettings, "NoobFace", noobFaceRef)

local rainbowRef = window:CreateToggle(avatarTab, "Rainbow Body", false, function(v)
    AvatarSettings.Rainbow = v
    local char = LocalPlayer.Character; if not char then return end
    if v then
        _origBodyColors = {}
        local parts = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
            "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand",
            "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg",
            "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
        for _, n in ipairs(parts) do
            local p = char:FindFirstChild(n)
            if p and p:IsA("BasePart") then
                _origBodyColors[n] = p.Color
                p.Color = Color3.fromHSV(math.random(), 0.9, 1)
            end
        end
    else
        for n, col in pairs(_origBodyColors) do
            local p = char:FindFirstChild(n)
            if p and p:IsA("BasePart") then p.Color = col end
        end
        _origBodyColors = {}
    end
end)
registerControl(AvatarSettings, "Rainbow", rainbowRef)

window:CreateButton(avatarTab, "Remove All Mods", function()
    if korbloxRef then korbloxRef.SetState(false) end
    if shoulderRef then shoulderRef.SetState(false) end
    if invisibleRef then invisibleRef.SetState(false) end
    if noobFaceRef then noobFaceRef.SetState(false) end
    if rainbowRef then rainbowRef.SetState(false) end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.6)
    if MovementSettings.Fly then attachFlyBodyMovers() end
    if AvatarSettings.Korblox then pcall(applyKorblox) end
    if AvatarSettings.Rainbow then
        local char = LocalPlayer.Character
        if char then
            local parts = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
                "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand",
                "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg",
                "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
            for _, n in ipairs(parts) do
                local p = char:FindFirstChild(n)
                if p and p:IsA("BasePart") then p.Color = Color3.fromHSV(math.random(), 0.9, 1) end
            end
        end
    end
    if AvatarSettings.NoobFace then
        local char = LocalPlayer.Character
        if char then
            local head = char:FindFirstChild("Head")
            if head then
                local face = head:FindFirstChildOfClass("Decal")
                if not face then face = Instance.new("Decal"); face.Name = "face"; face.Parent = head end
                face.Texture = "rbxassetid://1079"
            end
        end
    end
    if AvatarSettings.Shoulder then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local acc = Instance.new("Accessory")
                acc.Name = "HH_ShoulderAcc"
                local handle = Instance.new("Part")
                handle.Name = "Handle"; handle.Size = Vector3.new(1, 1, 1)
                handle.CanCollide = false; handle.Anchored = false
                local mesh = Instance.new("SpecialMesh")
                mesh.MeshType = Enum.MeshType.FileMesh
                mesh.MeshId = "rbxassetid://110121730336323"
                mesh.Parent = handle
                local att = Instance.new("Attachment")
                att.Name = "BodyFrontAttachment"; att.Parent = handle
                handle.Parent = acc; acc.Parent = char
                hum:AddAccessory(acc)
            end
        end
    end
end)

window:CreateLabel(farmTab, "Coin Farm")
window:CreateParagraph(farmTab, "Farm engine powered by Hexagonal Client · Made by odecode")

local autoFarmRef = window:CreateToggle(farmTab, "Auto Farm", false, function(v)
    FarmSettings.AutoFarm = v
    if v then
        if roundActive then startCoinCollector() end
    else
        if not FarmSettings.ManualCollect then stopCoinCollector() end
    end
end)
registerControl(FarmSettings, "AutoFarm", autoFarmRef)

local manualCollectRef = window:CreateToggle(farmTab, "Manual Collect", false, function(v)
    FarmSettings.ManualCollect = v
    if v then
        if not CoinCollecting then startCoinCollector() end
    else
        if not FarmSettings.AutoFarm then stopCoinCollector() end
    end
end)
registerControl(FarmSettings, "ManualCollect", manualCollectRef)

window:CreateLabel(farmTab, "Tuning")
local coinSpeedRef = window:CreateSlider(farmTab, "Move Speed", 10, 60, 20, function(v)
    FarmSettings.CoinSpeed = v
    CoinSpeed = v
end)
registerControl(FarmSettings, "CoinSpeed", coinSpeedRef)

local pickupRadiusRef = window:CreateSlider(farmTab, "Pickup Radius", 1, 10, 3, function(v)
    FarmSettings.PickupRadius = v
    CoinRadius = v
end)
registerControl(FarmSettings, "PickupRadius", pickupRadiusRef)

window:CreateLabel(farmTab, "Live Stats")
local coinCountFrame = window:CreateParagraph(farmTab, "Coins: 0")
local coinCountLabel = coinCountFrame:FindFirstChildOfClass("TextLabel")
local statusFrame = window:CreateParagraph(farmTab, "Status: Idle")
local statusLabel = statusFrame:FindFirstChildOfClass("TextLabel")

coinCountSetter = function(n)
    if coinCountLabel then coinCountLabel.Text = "Coins: " .. tostring(n) end
end
coinStatusSetter = function(txt)
    if statusLabel then statusLabel.Text = "Status: " .. txt end
end

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local gameplay = remotes and remotes:FindFirstChild("Gameplay")
local coinsStartedEvent = gameplay and gameplay:FindFirstChild("CoinsStarted")
local coinCollectedEvent = gameplay and gameplay:FindFirstChild("CoinCollected")
local roundEndFadeEvent = gameplay and gameplay:FindFirstChild("RoundEndFade")
local roundStartEvent = gameplay and gameplay:FindFirstChild("RoundStart")

if coinsStartedEvent then
    coinsStartedEvent.OnClientEvent:Connect(function(data)
        bagProgress = {}
        for bagName, _ in pairs(data) do bagProgress[bagName] = 0 end
        totalCoins = 0
        if coinCountSetter then coinCountSetter(0) end
        roundActive = true
        if FarmSettings.AutoFarm or FarmSettings.ManualCollect then
            task.wait(1); startCoinCollector()
        end
    end)
end

if coinCollectedEvent then
    coinCollectedEvent.OnClientEvent:Connect(function(bagName, currentCoins)
        if bagProgress[bagName] ~= nil then
            bagProgress[bagName] = currentCoins
            totalCoins = 0
            for _, v in pairs(bagProgress) do totalCoins = totalCoins + v end
            if coinCountSetter then coinCountSetter(totalCoins) end
        end
    end)
end

if roundStartEvent then
    roundStartEvent.OnClientEvent:Connect(function()
        bagProgress = {}
        totalCoins = 0
        roundActive = true
        if coinCountSetter then coinCountSetter(0) end
        if FarmSettings.AutoFarm or FarmSettings.ManualCollect then
            task.wait(1); startCoinCollector()
        end
        task.wait(0.1)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                applyESP(plr)
            end
        end
    end)
end

if roundEndFadeEvent then
    roundEndFadeEvent.OnClientEvent:Connect(function()
        roundActive = false
        stopCoinCollector()
        RoleCache = {}
        task.wait(0.05)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                clearHighlights(plr)
            end
        end
    end)
end

window:CreateLabel(miscTab, "Gun")
window:CreateButton(miscTab, "Bring Gun", function()
    local ok, reason = bringGunToPlayer()
    if ok then notify("Gun incoming (" .. tostring(reason) .. ")")
    else notify("Failed: " .. tostring(reason)) end
end)

local autoTpGunRef = window:CreateToggle(miscTab, "Auto Bring Gun", false, function(v)
    MiscSettings.AutoTpGun = v
    if v then
        if autoTpGunThread then return end
        autoTpGunThread = task.spawn(function()
            while MiscSettings.AutoTpGun do
                task.wait(0.5)
                if not MiscSettings.AutoTpGun then break end
                bringGunToPlayer()
            end
            autoTpGunThread = nil
        end)
    else
        if autoTpGunThread then task.cancel(autoTpGunThread); autoTpGunThread = nil end
    end
end)
registerControl(MiscSettings, "AutoTpGun", autoTpGunRef)

window:CreateLabel(miscTab, "Silent Aim")
local silentRef = window:CreateToggle(miscTab, "Silent Aim (Macro)", false, function(v)
    MiscSettings.SilentAim = v
    if silentAimConn then silentAimConn:Disconnect(); silentAimConn = nil end
    if v then
        local lastShot = 0
        silentAimConn = RunService.RenderStepped:Connect(function()
            if not MiscSettings.SilentAim then return end
            local murderer = getMurderer()
            if not murderer or not murderer.Character then return end
            local targetPart = getMM2TargetPart(murderer.Character)
            if not targetPart then return end
            local camera = workspace.CurrentCamera

            if AimbotSettings.WallCheck then
                if not isVisible(camera.CFrame.Position, targetPart.Position, murderer.Character) then return end
            end

            pcall(function()
                local mouse = LocalPlayer:GetMouse()
                mouse.Hit = CFrame.new(camera.CFrame.Position, targetPart.Position)
                mouse.Target = targetPart
            end)

            local now = tick()
            if now - lastShot < 0.15 then return end
            lastShot = now
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.03)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end)
    end
end)
registerControl(MiscSettings, "SilentAim", silentRef)

if window._makeMobileBtn and isMobile then
    window._makeMobileBtn("AIM", function()
        if mm2LockRef then mm2LockRef.SetState(not mm2LockRef.GetState()) end
    end)
    window._makeMobileBtn("ESP", function()
        if mm2ESPToggleRef then mm2ESPToggleRef.SetState(not mm2ESPToggleRef.GetState()) end
    end)
    window._makeMobileBtn("UI", function() window.ToggleUI() end)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.T then
        if mm2LockRef then mm2LockRef.SetState(not mm2LockRef.GetState()) end
    elseif input.KeyCode == Enum.KeyCode.O then
        if mm2ESPToggleRef then mm2ESPToggleRef.SetState(not mm2ESPToggleRef.GetState()) end
    elseif input.KeyCode == Enum.KeyCode.B then
        if autoFireRef then autoFireRef.SetState(not autoFireRef.GetState()) end
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
            WallCheck   = AimbotSettings.WallCheck,
        },
        Visual = {
            MM2ESP   = VisualSettings.MM2ESP,
            OGESP    = VisualSettings.OGESP,
            NameTags = VisualSettings.NameTags,
        },
        Misc = {
            InfJump        = MiscSettings.InfJump,
            AntiAFK        = MiscSettings.AntiAFK,
            AutoTpGun      = MiscSettings.AutoTpGun,
            SilentAim      = MiscSettings.SilentAim,
            MusicCompanion = MiscSettings.MusicCompanion,
        },
        Movement = {
            Noclip    = MovementSettings.Noclip,
            God       = MovementSettings.God,
            Fly       = MovementSettings.Fly,
            WalkSpeed = MovementSettings.WalkSpeed,
            JumpPower = MovementSettings.JumpPower,
            FlySpeed  = MovementSettings.FlySpeed,
            AntiFling = MovementSettings.AntiFling,
            Fling     = MovementSettings.Fling,
            TPAll     = MovementSettings.TPAll,
        },
        Avatar = {
            Korblox   = AvatarSettings.Korblox,
            Shoulder  = AvatarSettings.Shoulder,
            Invisible = AvatarSettings.Invisible,
            NoobFace  = AvatarSettings.NoobFace,
            Rainbow   = AvatarSettings.Rainbow,
        },
        Farm = {
            AutoFarm      = FarmSettings.AutoFarm,
            ManualCollect = FarmSettings.ManualCollect,
            CoinSpeed     = FarmSettings.CoinSpeed,
            PickupRadius  = FarmSettings.PickupRadius,
        },
        Theme = API:GetTheme(),
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

    if data.Theme and data.Theme ~= API:GetTheme() then
        API:SetTheme(data.Theme)
    end

    if MovementSettings.Fly then startFly() else stopFly() end

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
    elseif noclipConn then
        noclipConn:Disconnect(); noclipConn = nil
    end

    if MovementSettings.God then
        if godConn then godConn:Disconnect() end
        godConn = RunService.Heartbeat:Connect(function()
            local hum = getHumanoid()
            if hum then hum.Health = hum.MaxHealth end
        end)
    elseif godConn then
        godConn:Disconnect(); godConn = nil
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
    if VisualSettings.NameTags then startNameTagUpdater() else stopNameTagUpdater() end

    API:SyncUIControls()
    if window.UpdateThemeButtons then window:UpdateThemeButtons() end
end

window:SetConfigSnapshot(snapshotSettings)
window:SetConfigApply(applyConfig)
window:BuildConfigPage()

API:Notify("Happy Hub loaded")
