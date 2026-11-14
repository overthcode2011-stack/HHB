local API = getgenv().HappyHubAPI
local Cfg = getgenv().HH_CONFIG
local HH = getgenv().HH_LOGIC
local S = HH.S
local AimbotSettings, VisualSettings, MiscSettings, MovementSettings, AvatarSettings, FarmSettings = Cfg.AimbotSettings, Cfg.VisualSettings, Cfg.MiscSettings, Cfg.MovementSettings, Cfg.AvatarSettings, Cfg.FarmSettings
local ICONS, EMOTES = Cfg.ICONS, Cfg.EMOTES
local Players, RunService, UserInputService, LocalPlayer, isMobile = HH.Players, HH.RunService, HH.UserInputService, HH.LocalPlayer, HH.isMobile

local function notify(m, d) if API.Notify then API:Notify(m, d) end end
getgenv().HH_UI = { Notify = notify }

local function initUI()
    local window = API:CreateWindow("Happy Hub", "MM2 · Keyless · by replicatedman")
    if not window then return end

    local homeTab, playersTab, espTab, movementTab, aimbotTab, avatarTab, farmTab, miscTab
    homeTab = window:CreateTab("Home", ICONS.Home)
    playersTab = window:CreateTab("Players", ICONS.Plr)
    espTab = window:CreateTab("Visuals", ICONS.Vis)
    movementTab = window:CreateTab("Movement", ICONS.Mov)
    aimbotTab = window:CreateTab("Combat", ICONS.Aim)
    avatarTab = window:CreateTab("Avatar", ICONS.Avt)
    farmTab = window:CreateTab("Farm", ICONS.Farm)
    miscTab = window:CreateTab("Misc", ICONS.Misc)

    window:CreateImageCard(homeTab, { Image = "rbxthumb://type=Asset&id=" .. game.PlaceId .. "&w=420&h=420", Title = "Murder mistery 2", Subtitle = "by Nikilis", Description = "Murder Mistery · replicatedman · v11.7 API", Height = 150, ImageWidth = 130, OnClick = function() notify("Actual game", 2) end })
    window:CreateLabel(homeTab, "Music")
    window:CreateDropdown(homeTab, "Track", { "Companion", "Her Boyfriend", "I Stalk Ur Socials", "EYUHH!", "Low Cortisol" }, "Companion", function(v) MiscSettings.SelectedMusic = v if MiscSettings.MusicCompanion then HH.playMusic() end end)
    window:CreateToggle(homeTab, "Play Music", false, function(v) MiscSettings.MusicCompanion = v if v then HH.playMusic() else HH.stopMusic() notify("Music stopped") end end)
    window:CreateLabel(homeTab, "Creators")
    window:CreateParagraph(homeTab, "@replicatedman · Developer · Hub Creator")
    window:CreateParagraph(homeTab, "@odecode · Hexagonal Client · Farm Engine")

    window:CreateLabel(playersTab, "Teleport")
    window:CreateToggle(playersTab, "TP All", false, function(v)
        MovementSettings.TPAll = v
        if v then
            S.tpAllRunning = true
            S.tpAllTask = task.spawn(function() while S.tpAllRunning do for _, p in ipairs(Players:GetPlayers()) do if not S.tpAllRunning then break end if p ~= LocalPlayer then HH.teleportToPlayer(p) task.wait(0.1) end end task.wait(0.1) end end)
        else S.tpAllRunning = false if S.tpAllTask then task.cancel(S.tpAllTask) S.tpAllTask = nil end end
    end)
    window:CreateLabel(playersTab, "Role Teleport")
    _G.__HH_TpTarget = "Murder"
    window:CreateDropdown(playersTab, "Target", { "Murder", "Sheriff", "Hero" }, "Murder", function(v) _G.__HH_TpTarget = v end)
    window:CreateButton(playersTab, "Teleport", function()
        local t = _G.__HH_TpTarget local p
        if t == "Sheriff" then p = HH.getSheriff() elseif t == "Hero" then p = HH.getHero() else p = HH.getMurderer() end
        if HH.teleportToPlayer(p) then notify("Teleported to " .. t) else notify("No " .. t) end
    end)

    window:CreateLabel(espTab, "ESP")
    window:CreateToggle(espTab, "Roles", false, function(v)
        HH.ESP.active.MM2 = v VisualSettings.MM2ESP = v HH.refreshAllESP()
        if v then
            if not HH.ConnectionRegistry["rolesesp"] then
                local last = 0
                HH.trackConn("rolesesp", RunService.Heartbeat:Connect(function()
                    local n = tick() if n - last < 0.4 then return end last = n
                    if HH.ESP.active.MM2 or VisualSettings.GunESP then if HH.ESP.active.MM2 then HH.refreshAllESP() end if VisualSettings.GunESP then HH.applyGunESP() end end
                end))
            end
        else HH.dropConn("rolesesp") end
    end)
    window:CreateToggle(espTab, "Neutral", false, function(v) HH.ESP.active.OG = v VisualSettings.OGESP = v HH.refreshAllESP() end)
    window:CreateToggle(espTab, "Nametag", false, function(v) HH.ESP.active.NameTag = v VisualSettings.NameTags = v HH.refreshAllESP() if v then HH.startNameTagUpdater() else HH.stopNameTagUpdater() end end)
    window:CreateToggle(espTab, "Gun", false, function(v)
        VisualSettings.GunESP = v HH.applyGunESP()
        if v then
            if not HH.ConnectionRegistry["gunesp"] then
                local last = 0
                HH.trackConn("gunesp", RunService.Heartbeat:Connect(function() local n = tick() if n - last < 0.5 then return end last = n if VisualSettings.GunESP then HH.applyGunESP() end end))
            end
        else HH.dropConn("gunesp") HH.clearGunESP() end
    end)
    window:CreateToggle(espTab, "Beam", false, function(v) VisualSettings.Beam = v if v then HH.ensureBeamConn() end HH.stopBeamIfIdle() end)

    window:CreateLabel(movementTab, "Fly")
    window:CreateToggle(movementTab, "Fly", false, function(v) MovementSettings.Fly = v if v then HH.startFly() else HH.stopFly() end end)
    window:CreateSlider(movementTab, "Fly Speed", 5, 200, 40, function(v) MovementSettings.FlySpeed = v end)
    window:CreateLabel(movementTab, "Speed")
    window:CreateSlider(movementTab, "Walk Speed", 4, 150, 16, function(v) MovementSettings.WalkSpeed = v local h = HH.getHumanoid() if h then h.WalkSpeed = v end end)
    window:CreateSlider(movementTab, "Jump Power", 10, 200, 50, function(v) MovementSettings.JumpPower = v local h = HH.getHumanoid() if h then h.JumpPower = v h.UseJumpPower = true end end)
    window:CreateLabel(movementTab, "Modifications")
    window:CreateToggle(movementTab, "Noclip", false, function(v)
        MovementSettings.Noclip = v
        if v then
            HH.trackConn("noclip", RunService.Stepped:Connect(function() local c = LocalPlayer.Character if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end))
        else
            HH.dropConn("noclip") local c = LocalPlayer.Character if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
        end
    end)
    window:CreateToggle(movementTab, "God Mode", false, function(v) MovementSettings.God = v if v then HH.trackConn("god", RunService.Heartbeat:Connect(function() local h = HH.getHumanoid() if h then h.Health = h.MaxHealth end end)) else HH.dropConn("god") end end)
    window:CreateToggle(movementTab, "Anti-Void", false, function(v) MiscSettings.AntiVoid = v if v then HH.startAntiVoid() else HH.stopAntiVoid() end end)
    window:CreateToggle(movementTab, "Infinite Jump", false, function(v) MiscSettings.InfJump = v end)
    HH.trackConn("jump", UserInputService.JumpRequest:Connect(function() if MiscSettings.InfJump then local h = HH.getHumanoid() if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end))
    window:CreateToggle(movementTab, "Anti-AFK", false, function(v)
        MiscSettings.AntiAFK = v
        if v then
            local vu = game:GetService("VirtualUser")
            HH.trackConn("antiafk", LocalPlayer.Idled:Connect(function() vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame) task.wait(1) vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame) end))
        else HH.dropConn("antiafk") end
    end)

    window:CreateLabel(aimbotTab, "Aimbot")
    window:CreateToggle(aimbotTab, "Aimbot", false, function(v)
        AimbotSettings.MM2LockOn = v
        if v then
            HH.trackConn("aimbot", RunService.RenderStepped:Connect(function()
                if not AimbotSettings.MM2LockOn then return end
                local m = HH.getMurdererCached() if not HH.isTargetSafe(m) then return end
                local t = HH.getMM2TargetPart(m.Character) local h = HH.getHRP() if not t or not h then return end
                if (h.Position - t.Position).Magnitude > AimbotSettings.MM2Range then return end
                if not HH.isVisibleForShot(h.Position, t.Position, m.Character, m) then return end
                if AimbotSettings.FOVCircle then
                    local c = workspace.CurrentCamera if c then local sp, on = c:WorldToViewportPoint(t.Position) if on then local ce = Vector2.new(c.ViewportSize.X / 2, c.ViewportSize.Y / 2) if (Vector2.new(sp.X, sp.Y) - ce).Magnitude > AimbotSettings.FOVRadius then return end end end
                end
                local c = workspace.CurrentCamera c.CFrame = c.CFrame:Lerp(CFrame.new(c.CFrame.Position, t.Position), math.clamp(1 / AimbotSettings.MM2Smooth, 0.02, 1))
            end))
        else HH.dropConn("aimbot") end
    end)
    window:CreateSlider(aimbotTab, "Smoothness", 1, 30, 8, function(v) AimbotSettings.MM2Smooth = v end)
    window:CreateSlider(aimbotTab, "Distance", 50, 1000, 500, function(v) AimbotSettings.MM2Range = v end)
    window:CreateDropdown(aimbotTab, "Target Bone", { "Head", "Torso", "Small Avatar" }, "Head", function(v) AimbotSettings.MM2Target = v end)
    window:CreateToggle(aimbotTab, "FOV Circle", false, function(v) AimbotSettings.FOVCircle = v if v then HH.startFOVCircle() else HH.stopFOVCircle() end end)
    window:CreateSlider(aimbotTab, "FOV Radius", 40, 500, 120, function(v) AimbotSettings.FOVRadius = v end)
    window:CreateLabel(aimbotTab, "Trigger Bot")
    window:CreateToggle(aimbotTab, "Trigger Bot", false, function(v)
        AimbotSettings.TriggerBot = v
        if v then
            local last = 0
            HH.trackConn("triggerbot", RunService.RenderStepped:Connect(function()
                if not AimbotSettings.TriggerBot then return end
                local m = HH.getMurdererCached() if not HH.isTargetSafe(m) then return end
                local t = HH.getMM2TargetPart(m.Character) if not t then return end
                local h = HH.getHRP() if not h then return end
                if not HH.findGunEquipped() and not HH.findGunInBackpack() then return end
                if (h.Position - t.Position).Magnitude > AimbotSettings.TriggerRange then return end
                if not HH.isVisibleForShot(h.Position, t.Position, m.Character, m) then return end
                if not isMobile then local c = workspace.CurrentCamera local sp, on = c:WorldToViewportPoint(t.Position) if not on then return end local mo = UserInputService:GetMouseLocation() if (Vector2.new(sp.X, sp.Y) - mo).Magnitude >= 12 then return end end
                local n = tick() if n - last < 0.08 then return end last = n HH.yarhmFireAt(m, t)
            end))
        else HH.dropConn("triggerbot") end
    end)
    window:CreateSlider(aimbotTab, "Trigger Range", 20, 400, 150, function(v) AimbotSettings.TriggerRange = v end)

    window:CreateLabel(avatarTab, "Avatar")
    window:CreateToggle(avatarTab, "Korblox", false, function(v) AvatarSettings.Korblox = v if v then HH.applyKorblox() else HH.removeKorblox() end end)
    window:CreateToggle(avatarTab, "Custom Anims", false, function(v) AvatarSettings.AnimPack = v if v then HH.applyAnimPack() notify("Anim pack applied") else notify("Rejoin to restore anims", 3) end end)

    window:CreateLabel(farmTab, "Coin Farm")
    window:CreateToggle(farmTab, "Auto Farm", false, function(v)
        FarmSettings.AutoFarm = v
        if v then HH.ensureFarmHelpers() HH.ensureFarmNoclip() if S.roundActive and not S.coinCollecting then HH.startCoinCollector() end
        else HH.stopCoinCollector() HH.restoreFarmNoclip() HH.restoreFarmHelpers() end
    end)
    window:CreateSlider(farmTab, "Farm Speed", 8, 40, 18, function(v) FarmSettings.FarmSpeed = v end)
    window:CreateParagraph(farmTab, "Farm speed is separate from Fly")
    window:CreateLabel(farmTab, "Stats")
    local statFrame = window:CreateParagraph(farmTab, "0")
    local statLabel = statFrame:FindFirstChildOfClass("TextLabel")
    local statusFrame = window:CreateParagraph(farmTab, "Idle")
    local statusLabel = statusFrame:FindFirstChildOfClass("TextLabel")
    S.coinCountSetter = function(n) if statLabel then statLabel.Text = "" .. tostring(n) end end
    S.coinStatusSetter = function(t) if statusLabel then statusLabel.Text = "" .. t end end

    window:CreateLabel(miscTab, "Gun")
    window:CreateButton(miscTab, "Pick up Gun", function() local ok = HH.bringGunToPlayer() if ok then notify("Gun incoming") else notify("Failed") end end)
    window:CreateToggle(miscTab, "Auto Gun", false, function(v)
        MiscSettings.AutoTpGun = v
        if v then
            if S.autoTpGunThread then return end
            S.autoTpGunThread = task.spawn(function() while MiscSettings.AutoTpGun do task.wait(0.5) if not MiscSettings.AutoTpGun then break end HH.bringGunToPlayer() end S.autoTpGunThread = nil end)
        else if S.autoTpGunThread then task.cancel(S.autoTpGunThread) S.autoTpGunThread = nil end end
    end)
    window:CreateLabel(miscTab, "Silent Aim")
    window:CreateToggle(miscTab, "Silent Aim", false, function(v) MiscSettings.SilentAim = v if v and not S.silentAimHookInstalled then notify("Silent Aim unavailable", 2) end end)
    window:CreateLabel(miscTab, "Knife Dodge")
    window:CreateToggle(miscTab, "Dodge Knives", true, function(v) MiscSettings.KnifeDodge = v if v then if not HH.ConnectionRegistry["knife_dodge"] then HH.setupKnifeDodgeHook() end else HH.dropConn("knife_dodge") end end)
    HH.setupKnifeDodgeHook()

    window:CreateLabel(miscTab, "Debug")
    window:CreateButton(miscTab, "Check Gun Status", function()
        local c = LocalPlayer.Character if not c then notify("No character", 3) return end
        local r, b, h = HH.findGunEquipped(), HH.findGunInBackpack(), c:FindFirstChildOfClass("Humanoid")
        local eq = h and h:FindFirstChildWhichIsA("Tool")
        notify("Rig: " .. (r and r.Name or "no") .. " | Bag: " .. (b and b.Name or "no") .. " | Equipped: " .. (eq and eq.Name or "no"), 6)
    end)

    function window.UpdateThemeButtons() end
end

initUI()
