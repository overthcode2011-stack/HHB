local API_URL = "https://raw.githubusercontent.com/overthcode2011-stack/HHB/refs/heads/main/API"

local ok, API = pcall(function()
    local src = game:HttpGet(API_URL)
    if not src or #src < 50 then error("No URL") end
    return loadstring(src)()
end)
if not ok or type(API) ~= "table" then
    warn("[Happy Hub] API fail:", API); return
end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams             = game:GetService("Teams")
local VIM               = game:GetService("VirtualInputManager")
local Lighting          = game:GetService("Lighting")
local LocalPlayer       = Players.LocalPlayer

local window    = API:CreateWindow("Happy Hub", "prison life")
local visualTab = window:CreateTab("Visuals",  API.Icons and API.Icons.Visual or nil)
local combatTab = window:CreateTab("Combat",   API.Icons and API.Icons.Misc   or nil)
local escapeTab = window:CreateTab("Escape",   API.Icons and API.Icons.Misc   or nil)
local moveTab   = window:CreateTab("Movement", API.Icons and API.Icons.Misc   or nil)

local function Try(fn, ...)
    local o, e = pcall(fn, ...)
    if not o then warn("[Happy Hub]", e) end
end

local function GetTeam(name)
    if not name then return nil end
    local t = Teams:FindFirstChild(name); if t then return t end
    for _, c in ipairs(Teams:GetChildren()) do
        if c:IsA("Team") and c.Name:lower():gsub("%s+","") == name:lower():gsub("%s+","") then return c end
    end
end

local function CanBeDamaged(plr)
    if plr == LocalPlayer then return false end
    if plr.Team == LocalPlayer.Team then return false end
    local char = plr.Character; if not char then return false end
    local guards, inmates = GetTeam("Guards"), GetTeam("Inmates")
    if guards and inmates and LocalPlayer.Team == guards and plr.Team == inmates
       and not char:GetAttribute("Hostile") then return false end
    if char:FindFirstChildOfClass("ForceField") then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return true
end

local function GetTargetPos(plr)
    local char = plr.Character; if not char then return nil end
    local head = char:FindFirstChild("Head"); if not head then return nil end
    return head.Position, head
end

local function IsVisible(plr)
    local cam = workspace.CurrentCamera; if not cam then return false end
    local char = plr.Character; if not char then return false end
    local head = char:FindFirstChild("Head"); if not head then return false end
    local origin = cam.CFrame.Position
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LocalPlayer.Character or workspace}
    local hit = workspace:Raycast(origin, head.Position - origin, rp)
    return hit and hit.Instance and hit.Instance:IsDescendantOf(char) or false
end

local function GetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local ESP = { Enabled=true, Tracers=true, Box=true, Skeleton=false,
              Health=false, Name=true, TeamColor=true, Drawings={} }

if Drawing and Drawing.new then
    Try(window.CreateToggle, window, visualTab, "ESP", true, function(v)
        ESP.Enabled = v
        if not v then for p in pairs(ESP.Drawings) do ESP:RemoveDrawings(p) end end
    end)
    Try(window.CreateToggle, window, visualTab, "Tracers",  true,  function(v) ESP.Tracers  = v end)
    Try(window.CreateToggle, window, visualTab, "Box",      true,  function(v) ESP.Box      = v end)
    Try(window.CreateToggle, window, visualTab, "Skeleton", false, function(v) ESP.Skeleton = v end)
    Try(window.CreateToggle, window, visualTab, "Health",   false, function(v) ESP.Health   = v end)
    Try(window.CreateToggle, window, visualTab, "Name",     true,  function(v) ESP.Name     = v end)
    Try(window.CreateToggle, window, visualTab, "Team Color", true, function(v) ESP.TeamColor = v end)

    local COLOR_ALLY, COLOR_ENEMY, COLOR_NOTEAM =
        Color3.fromRGB(0,255,0), Color3.fromRGB(255,60,60), Color3.fromRGB(200,200,200)
    local teamCache = {}
    local function teamColor(t)
        if not t then return COLOR_NOTEAM end
        if teamCache[t] then return teamCache[t] end
        local c = (t.TeamColor and t.TeamColor.Color) or COLOR_NOTEAM
        teamCache[t] = c; return c
    end
    task.spawn(function() while task.wait(5) do teamCache = {} end end)

    local function colorOf(plr)
        if ESP.TeamColor then return plr.Team and teamColor(plr.Team) or COLOR_NOTEAM end
        return (plr.Team and plr.Team == LocalPlayer.Team) and COLOR_ALLY or COLOR_ENEMY
    end

    local function valid(plr)
        if plr == LocalPlayer then return false end
        local c = plr.Character; if not c then return false end
        local h = c:FindFirstChildOfClass("Humanoid")
        return c:FindFirstChild("HumanoidRootPart") and c:FindFirstChild("Head") and h and h.Health > 0
    end

    function ESP:CreateDrawings(plr)
        if self.Drawings[plr] then return end
        local d = {
            Box=Drawing.new("Square"), Tracer=Drawing.new("Line"),
            Name=Drawing.new("Text"), HealthBar=Drawing.new("Square"),
            HealthBG=Drawing.new("Square"), HealthText=Drawing.new("Text"), Skeleton={},
        }
        d.Box.Thickness=1; d.Box.Filled=false; d.Box.Transparency=1
        d.Tracer.Thickness=1; d.Tracer.Transparency=1
        d.Name.Size=14; d.Name.Center=true; d.Name.Outline=true
        d.Name.OutlineColor=Color3.new(0,0,0); d.Name.Transparency=1
        d.HealthBG.Filled=true; d.HealthBG.Color=Color3.new(0,0,0)
        d.HealthBG.Transparency=0.6; d.HealthBG.Thickness=1
        d.HealthBar.Filled=true; d.HealthBar.Transparency=0.2; d.HealthBar.Thickness=1
        d.HealthText.Size=12; d.HealthText.Center=true; d.HealthText.Outline=true
        d.HealthText.OutlineColor=Color3.new(0,0,0); d.HealthText.Transparency=1
        self.Drawings[plr] = d
    end

    function ESP:RemoveDrawings(plr)
        local d = self.Drawings[plr]; if not d then return end
        for _, k in ipairs({"Box","Tracer","Name","HealthBar","HealthBG","HealthText"}) do
            if d[k] then pcall(function() d[k]:Remove() end) end
        end
        for _, l in ipairs(d.Skeleton) do pcall(function() l:Remove() end) end
        self.Drawings[plr] = nil
    end

    function ESP:Update()
        if not self.Enabled then return end
        local cam = workspace.CurrentCamera; if not cam then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if not valid(plr) then
                if self.Drawings[plr] then self:RemoveDrawings(plr) end
            else
                self:CreateDrawings(plr)
                local d = self.Drawings[plr]
                local c = plr.Character
                local hrp, head = c.HumanoidRootPart, c.Head
                local hum = c:FindFirstChildOfClass("Humanoid")
                local hp, on = cam:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
                local fp = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0,3,0))
                if not on then
                    for _, k in ipairs({"Box","Tracer","Name","HealthBar","HealthBG","HealthText"}) do d[k].Visible = false end
                    for _, l in ipairs(d.Skeleton) do l.Visible = false end
                else
                    local col = colorOf(plr)
                    local h = math.abs(fp.Y - hp.Y); local w = h * 0.5
                    local tx, ty = hp.X - w/2, hp.Y
                    d.Box.Visible = self.Box
                    if self.Box then d.Box.Color=col; d.Box.Size=Vector2.new(w,h); d.Box.Position=Vector2.new(tx,ty) end
                    d.Tracer.Visible = self.Tracers
                    if self.Tracers then
                        d.Tracer.Color=col
                        d.Tracer.From=Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y)
                        d.Tracer.To=Vector2.new(hp.X,hp.Y)
                    end
                    d.Name.Visible = self.Name
                    if self.Name then
                        d.Name.Color=col
                        d.Name.Text=string.format("[%s] %s", plr.Team and plr.Team.Name or "none", plr.Name)
                        d.Name.Position=Vector2.new(hp.X, ty-18)
                    end
                    d.HealthBar.Visible=self.Health; d.HealthBG.Visible=self.Health; d.HealthText.Visible=self.Health
                    if self.Health then
                        local pct = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
                        d.HealthBG.Size=Vector2.new(4,h); d.HealthBG.Position=Vector2.new(tx-7,ty)
                        local hc = Color3.fromRGB(255*(1-pct), 255*pct, 0)
                        d.HealthBar.Color=hc; d.HealthBar.Size=Vector2.new(4,h*pct)
                        d.HealthBar.Position=Vector2.new(tx-7, ty + h*(1-pct))
                        d.HealthText.Color=hc; d.HealthText.Text=tostring(math.floor(hum.Health))
                        d.HealthText.Position=Vector2.new(tx-18, ty + h/2)
                    end
                    if self.Skeleton then
                        local parts = {
                            head=head, torso=c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"),
                            larm=c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm"),
                            rarm=c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"),
                            lleg=c:FindFirstChild("LeftFoot") or c:FindFirstChild("Left Leg"),
                            rleg=c:FindFirstChild("RightFoot") or c:FindFirstChild("Right Leg"),
                        }
                        local conns = {{"head","torso"},{"torso","larm"},{"torso","rarm"},{"torso","lleg"},{"torso","rleg"}}
                        if #d.Skeleton == 0 then
                            for _ = 1, #conns do
                                local l = Drawing.new("Line")
                                l.Thickness=1; l.Transparency=1; l.Visible=false
                                table.insert(d.Skeleton, l)
                            end
                        end
                        for i, cn in ipairs(conns) do
                            local p1, p2 = parts[cn[1]], parts[cn[2]]
                            local ln = d.Skeleton[i]
                            if p1 and p2 then
                                local s1,o1 = cam:WorldToViewportPoint(p1.Position)
                                local s2,o2 = cam:WorldToViewportPoint(p2.Position)
                                ln.Visible = o1 and o2
                                if ln.Visible then
                                    ln.Color=col
                                    ln.From=Vector2.new(s1.X,s1.Y)
                                    ln.To=Vector2.new(s2.X,s2.Y)
                                end
                            else ln.Visible = false end
                        end
                    else
                        for _, l in ipairs(d.Skeleton) do l.Visible = false end
                    end
                end
            end
        end
    end

    RunService.RenderStepped:Connect(function() pcall(function() ESP:Update() end) end)
    Players.PlayerRemoving:Connect(function(p) ESP:RemoveDrawings(p) end)
end

local Aimbot = {
    Enabled=false, AutoFire=false, FOV=250, WallCheck=true,
    Smoothness=0, CameraLock=true, BulletRedirect=true,
}

local function GetAimbotTarget()
    local cam = workspace.CurrentCamera; if not cam then return nil end
    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    local best, bestD = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if CanBeDamaged(plr) then
            local pos = GetTargetPos(plr)
            if pos then
                local sp, on = cam:WorldToViewportPoint(pos)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= Aimbot.FOV and d < bestD then
                        if not Aimbot.WallCheck or IsVisible(plr) then best, bestD = plr, d end
                    end
                end
            end
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if not Aimbot.Enabled or not Aimbot.CameraLock then return end
    local tgt = GetAimbotTarget(); if not tgt then return end
    local pos = GetTargetPos(tgt); if not pos then return end
    local cam = workspace.CurrentCamera; if not cam then return end
    local origin = cam.CFrame.Position
    local newCF = CFrame.new(origin, origin + (pos - origin).Unit)
    if Aimbot.Smoothness > 0 then
        cam.CFrame = cam.CFrame:Lerp(newCF, math.clamp(1 - Aimbot.Smoothness, 0.01, 1))
    else
        cam.CFrame = newCF
    end
end)

RunService.RenderStepped:Connect(function()
    if not Aimbot.Enabled or not Aimbot.AutoFire then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if not GetAimbotTarget() then return end
    pcall(function()
        if mouse1click then mouse1click()
        elseif mouse1press and mouse1release then mouse1press(); mouse1release()
        else
            VIM:SendMouseButtonEvent(0,0,0,true,game,1)
            VIM:SendMouseButtonEvent(0,0,0,false,game,1)
        end
    end)
end)

pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and self.Name == "ShootEvent"
           and Aimbot.Enabled and Aimbot.BulletRedirect then
            local args = {...}
            local bullets = args[1]
            if type(bullets) == "table" then
                local tgt = GetAimbotTarget()
                if tgt then
                    local pos, headInst = GetTargetPos(tgt)
                    if pos and headInst then
                        for _, b in ipairs(bullets) do
                            if type(b) == "table" and #b >= 3 then
                                b[2] = pos; b[3] = headInst
                            end
                        end
                    end
                end
            end
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end)

Try(window.CreateToggle, window, combatTab, "Aimbot", false, function(v) Aimbot.Enabled = v end)
Try(window.CreateToggle, window, combatTab, "Camera Lock", true, function(v) Aimbot.CameraLock = v end)
Try(window.CreateToggle, window, combatTab, "Bullet Redirect", true, function(v) Aimbot.BulletRedirect = v end)
Try(window.CreateToggle, window, combatTab, "Auto Fire", false, function(v) Aimbot.AutoFire = v end)
Try(window.CreateToggle, window, combatTab, "Wall Check", true, function(v) Aimbot.WallCheck = v end)
Try(window.CreateSlider, window, combatTab, "FOV", 50, 800, 250, function(v) Aimbot.FOV = v end)
Try(window.CreateSlider, window, combatTab, "Smoothness", 0, 0.9, 0, function(v) Aimbot.Smoothness = v end)

local AutoEscape = { Enabled=false, EscapeCF=CFrame.new(484, 98, 2217),
                     InmateTeam="Inmates", Cooldown=5, LastAttempt=0 }
local ESCAPE_DELAY = 3

local function teamMatch(team, name)
    if not team or not team.Name then return false end
    local a = team.Name:lower():gsub("%s+","")
    local b = name:lower():gsub("%s+","")
    return a == b or a:find(b, 1, true) ~= nil
end

local function DoEscape()
    local char = LocalPlayer.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    pcall(function()
        hrp.CFrame = AutoEscape.EscapeCF
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < ESCAPE_DELAY do
            if not AutoEscape.Enabled then return end
            local c2 = LocalPlayer.Character
            local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
            if not h2 then return end
            pcall(function()
                h2.CFrame = AutoEscape.EscapeCF
                h2.AssemblyLinearVelocity = Vector3.zero
            end)
            task.wait(0.1)
        end
        if not teamMatch(LocalPlayer.Team, AutoEscape.InmateTeam) then return end
        local c3 = LocalPlayer.Character
        local hum2 = c3 and c3:FindFirstChildOfClass("Humanoid")
        if hum2 then pcall(function() hum2.Health = 0 end) end
    end)
end

task.spawn(function()
    while task.wait(0.5) do
        if not AutoEscape.Enabled then continue end
        local team = LocalPlayer.Team; if not team then continue end
        if not teamMatch(team, AutoEscape.InmateTeam) then continue end
        if tick() - AutoEscape.LastAttempt < AutoEscape.Cooldown then continue end
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then continue end
        AutoEscape.LastAttempt = tick()
        DoEscape()
    end
end)

Try(window.CreateToggle, window, escapeTab, "Auto Escape", false, function(v)
    AutoEscape.Enabled = v
    if v then AutoEscape.LastAttempt = 0 end
end)
Try(window.CreateInput, window, escapeTab, "Escape X", "484", function(t)
    local n = tonumber(t); if n then
        local p = AutoEscape.EscapeCF.Position
        AutoEscape.EscapeCF = CFrame.new(n, p.Y, p.Z) end
end)
Try(window.CreateInput, window, escapeTab, "Escape Y", "98", function(t)
    local n = tonumber(t); if n then
        local p = AutoEscape.EscapeCF.Position
        AutoEscape.EscapeCF = CFrame.new(p.X, n, p.Z) end
end)
Try(window.CreateInput, window, escapeTab, "Escape Z", "2217", function(t)
    local n = tonumber(t); if n then
        local p = AutoEscape.EscapeCF.Position
        AutoEscape.EscapeCF = CFrame.new(p.X, p.Y, n) end
end)

local function GiveKeyCard()
    local tools = ReplicatedStorage:FindFirstChild("Tools")
    if not tools then return end
    local key = tools:FindFirstChild("Key card")
    if not key then return end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then return end
    key:Clone().Parent = bp
end

Try(window.CreateButton, window, escapeTab, "Give Key Card", function() GiveKeyCard() end)
Try(window.CreateButton, window, escapeTab, "Give & Equip", function()
    GiveKeyCard()
    task.wait(0.2)
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local c = LocalPlayer.Character
    if bp and c then
        local k = bp:FindFirstChild("Key card")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if k and hum then hum:EquipTool(k) end
    end
end)

local GunRemotes = ReplicatedStorage:FindFirstChild("GunRemotes")
local ReplicateEvent = GunRemotes and GunRemotes:FindFirstChild("ReplicateEvent")
local WeaponState = { original = {} }

local function GetWeaponParts()
    local children = workspace:GetChildren()
    local found = {}
    for _, idx in ipairs({188, 184}) do
        local obj = children[idx]
        if obj then
            local tg = obj:FindFirstChild("TouchGiver")
            if tg then
                for _, d in ipairs(tg:GetDescendants()) do
                    if d:IsA("BasePart") then table.insert(found, d) end
                end
                if tg:IsA("BasePart") then table.insert(found, tg) end
            end
            if obj:IsA("BasePart") then table.insert(found, obj) end
        end
    end
    return found
end

local function TeleportWeapons()
    if not ReplicateEvent then return end
    local hrp = GetHRP(); if not hrp then return end
    local parts = GetWeaponParts()
    if #parts == 0 then return end
    local targetPos = hrp.Position
    for _, part in ipairs(parts) do
        if not WeaponState.original[part] then
            WeaponState.original[part] = {
                cf = part.CFrame,
                transparency = part.Transparency,
                cancollide = part.CanCollide,
            }
        end
        local origin = part.Position
        pcall(function()
            if firesignal then
                firesignal(ReplicateEvent.OnClientEvent, {
                    { origin, targetPos, "Pickup" }
                })
            end
        end)
        pcall(function()
            part.CFrame = hrp.CFrame
            part.Transparency = 1
            part.CanCollide = false
            part.Massless = true
        end)
    end
end

local function ReturnWeapons()
    for part, saved in pairs(WeaponState.original) do
        if typeof(part) == "Instance" and part.Parent then
            pcall(function()
                part.CFrame = saved.cf
                part.Transparency = saved.transparency
                part.CanCollide = saved.cancollide
                part.Massless = false
            end)
        end
    end
    WeaponState.original = {}
end

Try(window.CreateButton, window, escapeTab, "Grab Weapons", function() TeleportWeapons() end)
Try(window.CreateButton, window, escapeTab, "Return Weapons", function() ReturnWeapons() end)
Try(window.CreateButton, window, escapeTab, "Grab + Return (1.5s)", function()
    TeleportWeapons()
    task.delay(1.5, ReturnWeapons)
end)

local Invis = { Running=false, RealChar=nil, FakeChar=nil,
                FixConn=nil, DiedConn=nil,
                VoidThreshold = workspace.FallenPartsDestroyHeight }

local function StopInvisible()
    if not Invis.Running then return end
    local player = LocalPlayer
    local fake = Invis.FakeChar
    local real = Invis.RealChar
    if Invis.FixConn then Invis.FixConn:Disconnect(); Invis.FixConn = nil end
    if Invis.DiedConn then Invis.DiedConn:Disconnect(); Invis.DiedConn = nil end
    pcall(function()
        if fake and fake.Parent then
            local fakeHRP = fake:FindFirstChild("HumanoidRootPart")
            if real and real.Parent then
                local realHRP = real:FindFirstChild("HumanoidRootPart")
                if fakeHRP and realHRP then realHRP.CFrame = fakeHRP.CFrame end
            end
            fake:Destroy()
        end
        if real and real.Parent then
            real.Parent = workspace
            local hum = real:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
        player.Character = nil
    end)
    Invis.RealChar = nil
    Invis.FakeChar = nil
    Invis.Running = false
end

local function StartInvisible()
    if Invis.Running then return end
    local player = LocalPlayer
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    char.Archivable = true
    local savedCF = hrp.CFrame
    local clone = char:Clone()
    clone.Name = ""

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Transparency = 1
            d.CanCollide = false
            d.Massless = true
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency = 1
        end
    end

    pcall(function()
        hrp.CFrame = CFrame.new(0, Invis.VoidThreshold - 100, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    task.wait(0.15)
    char.Parent = Lighting
    clone.Parent = workspace
    pcall(function() player.Character = clone end)
    local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
    if cloneHRP then cloneHRP.CFrame = savedCF end
    workspace.CurrentCamera.CameraSubject = clone:FindFirstChildOfClass("Humanoid")
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom

    local animate = clone:FindFirstChild("Animate")
    if animate then
        animate.Disabled = true
        task.wait()
        animate.Disabled = false
    end

    Invis.RealChar = char
    Invis.FakeChar = clone
    Invis.Running = true

    Invis.FixConn = RunService.Stepped:Connect(function()
        if not Invis.Running then return end
        local fake = Invis.FakeChar
        if not fake or not fake.Parent then StopInvisible(); return end
        local fakeHRP = fake:FindFirstChild("HumanoidRootPart")
        if fakeHRP and fakeHRP.Position.Y < Invis.VoidThreshold + 50 then
            fakeHRP.CFrame = CFrame.new(savedCF.Position)
            fakeHRP.AssemblyLinearVelocity = Vector3.zero
        end
    end)

    local cloneHum = clone:FindFirstChildOfClass("Humanoid")
    if cloneHum then
        Invis.DiedConn = cloneHum.Died:Connect(function() StopInvisible() end)
    end
end

Try(window.CreateButton, window, moveTab, "Invisible ON", function() StartInvisible() end)
Try(window.CreateButton, window, moveTab, "Invisible OFF", function() StopInvisible() end)
Try(window.CreateToggle, window, moveTab, "Invisible", false, function(v)
    if v then StartInvisible() else StopInvisible() end
end)

local SmartNC = { Active=false, Conn=nil, Saved={} }

local function restoreSmartNC()
    for part, orig in pairs(SmartNC.Saved) do
        if typeof(part) == "Instance" and part.Parent then
            pcall(function() part.CanCollide = orig end)
        end
    end
    SmartNC.Saved = {}
end

local function smartNCStep()
    local char = LocalPlayer.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    restoreSmartNC()
    local origin = hrp.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    params.IgnoreWater = true
    local dirs = {
        hrp.CFrame.LookVector, -hrp.CFrame.LookVector,
        hrp.CFrame.RightVector, -hrp.CFrame.RightVector,
        Vector3.yAxis,
    }
    local vel = hrp.Velocity
    if vel.Magnitude > 0.5 then
        table.insert(dirs, vel.Unit * Vector3.new(1, 0, 1))
    end
    for _, dir in ipairs(dirs) do
        local result = workspace:Raycast(origin, dir * 6, params)
        if result and result.Instance then
            local part = result.Instance
            if not SmartNC.Saved[part] then
                SmartNC.Saved[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end
end

local function startSmartNC()
    if SmartNC.Active then return end
    SmartNC.Active = true
    SmartNC.Conn = RunService.Stepped:Connect(smartNCStep)
end
local function stopSmartNC()
    SmartNC.Active = false
    if SmartNC.Conn then SmartNC.Conn:Disconnect(); SmartNC.Conn = nil end
    restoreSmartNC()
end

Try(window.CreateToggle, window, moveTab, "Noclip", false, function(v)
    if v then startSmartNC() else stopSmartNC() end
end)

local Fly = { Active=false, Conn=nil, BV=nil, BG=nil, Speed=50 }

local function attachFly()
    local hrp, hum = GetHRP(), GetHumanoid()
    if not hrp or not hum then return end
    hum.PlatformStand = true
    if Fly.BV then Fly.BV:Destroy() end
    if Fly.BG then Fly.BG:Destroy() end
    Fly.BV = Instance.new("BodyVelocity")
    Fly.BV.Velocity = Vector3.zero
    Fly.BV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    Fly.BV.Parent = hrp
    Fly.BG = Instance.new("BodyGyro")
    Fly.BG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    Fly.BG.P = 1e4
    Fly.BG.CFrame = hrp.CFrame
    Fly.BG.Parent = hrp
end

local function detachFly()
    if Fly.BV then Fly.BV:Destroy(); Fly.BV = nil end
    if Fly.BG then Fly.BG:Destroy(); Fly.BG = nil end
    local hum = GetHumanoid()
    if hum then hum.PlatformStand = false end
end

local function getFlyInput()
    local mv = Vector3.zero
    local cam = workspace.CurrentCamera
    local cf = cam.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then mv = mv + Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then mv = mv - Vector3.yAxis end
    if mv.Magnitude < 0.01 then
        local hum2 = GetHumanoid()
        if hum2 then
            local md = hum2.MoveDirection
            if md.Magnitude > 0.1 then mv = md * Vector3.new(1, 0, 1) end
        end
    end
    return mv
end

local function startFly()
    if Fly.Active then return end
    Fly.Active = true
    attachFly()
    Fly.Conn = RunService.Heartbeat:Connect(function()
        if not Fly.Active then return end
        local h = GetHRP(); if not h then return end
        if not Fly.BV or not Fly.BV.Parent then attachFly() end
        if not Fly.BV or not Fly.BG then return end
        local mv = getFlyInput()
        Fly.BV.Velocity = mv.Magnitude > 0 and mv.Unit * Fly.Speed or Vector3.zero
        Fly.BG.CFrame = workspace.CurrentCamera.CFrame
    end)
end

local function stopFly()
    Fly.Active = false
    if Fly.Conn then Fly.Conn:Disconnect(); Fly.Conn = nil end
    detachFly()
end

Try(window.CreateToggle, window, moveTab, "Fly", false, function(v)
    if v then startFly() else stopFly() end
end)
Try(window.CreateSlider, window, moveTab, "Fly Speed", 10, 300, 50, function(v) Fly.Speed = v end)

local Float = { Active=false, Part=nil, Conn=nil }
local FLOAT_OFFSET = -3.2

local function startFloat()
    if Float.Active then return end
    local hrp = GetHRP(); if not hrp then return end

    Float.Part = Instance.new("Part")
    Float.Part.Name = "HH_FloatPad"
    Float.Part.Size = Vector3.new(6, 0.2, 6)
    Float.Part.Anchored = true
    Float.Part.CanCollide = true
    Float.Part.Transparency = 0.4
    Float.Part.Color = Color3.fromRGB(0, 255, 150)
    Float.Part.Material = Enum.Material.Neon
    Float.Part.Parent = workspace
    Float.Part.CFrame = hrp.CFrame * CFrame.new(0, FLOAT_OFFSET, 0)

    Float.Active = true

    Float.Conn = RunService.Heartbeat:Connect(function()
        if not Float.Active then return end
        local h = GetHRP()
        if not h then return end
        if not Float.Part or not Float.Part.Parent then return end
        Float.Part.CFrame = CFrame.new(
            h.Position.X,
            h.Position.Y + FLOAT_OFFSET,
            h.Position.Z
        )
    end)
end

local function stopFloat()
    Float.Active = false
    if Float.Conn then Float.Conn:Disconnect(); Float.Conn = nil end
    if Float.Part then Float.Part:Destroy(); Float.Part = nil end
end

Try(window.CreateToggle, window, moveTab, "Float", false, function(v)
    if v then startFloat() else stopFloat() end
end)

task.defer(function()
    if type(window.BuildConfigPage) == "function" then
        pcall(function() window:BuildConfigPage() end)
    end
end)
