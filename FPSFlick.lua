local hiddenFolder = Instance.new("Folder")
hiddenFolder.Name = "\u{200B}\u{200C}\u{200D}\u{FEFF}\u{200B}"
hiddenFolder.Parent = gethui and gethui() or game:GetService("CoreGui")
local Hometabicon = "130068439240504"

pcall(function()
    local FFlags = {
        ["DFIntDebugDynamicRenderKiloPixels"] = "1",
        ["DFIntCSGLevelOfDetailSwitchingDistance"] = "0",
        ["DFIntCSGLevelOfDetailSwitchingDistanceL12"] = "0",
        ["DFIntCSGLevelOfDetailSwitchingDistanceL23"] = "0",
        ["DFIntCSGLevelOfDetailSwitchingDistanceL34"] = "0",
        ["FIntFRMMaxGrassDistance"] = "0",
        ["DFIntDebugFRMQualityLevelOverride"] = "1",
        ["FFlagDebugDisableTelemetryEventIngest"] = "True",
        ["FIntDebugForceMSAASamples"] = "1",
    }
    for flag, value in pairs(FFlags) do
        if setfflag then pcall(setfflag, flag, value) end
    end
end)

local success, API = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/overthcode2011-stack/HHB/refs/heads/main/API'))()
end)
if not success or not API then
    game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Error", Text = "API failed."})
    return
end

API.Config.SupportedGames = { 136801880565837 }
API.Config.KeySystem.Enabled = false
local window = API:CreateWindow("Happy Hub", "[FPS] Flick · By @replicatedman · Fully Free")
if not window then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local AimActive = false
local EspActive = false
local AimRadius = 150
local AimSpeed = 20      
local Prediction = 0.15
local HitPart = "Head"
local espCache = {}

local function IsInLobby(player)
    if player.Team and string.find(string.lower(player.Team.Name), "lobby") then
        return true
    end
    
    if player.Character and player.Character.Parent then
        local parentName = string.lower(player.Character.Parent.Name)
        if string.find(parentName, "lobby") or string.find(parentName, "spectator") then
            return true
        end
    end
    
    if player:GetAttribute("InLobby") == true or player:GetAttribute("Team") == "Lobby" then
        return true
    end
    
    return false
end

local function UpdateESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not IsInLobby(player) then
            local char = player.Character
            local hum = char:FindFirstChild("Humanoid")
            
            if hum and hum.Health > 0 and not espCache[char] then
                local hl = char:FindFirstChild("Highlight")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "Highlight"
                    hl.Adornee = char
                    hl.Parent = char
                end
                hl.Enabled = true
                hl.FillColor = Color3.fromRGB(255, 255, 255)
                hl.OutlineTransparency = 1
                hl.FillTransparency = 0.4
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                espCache[char] = hl
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.5) do
        if EspActive then UpdateESP() end
    end
end)

local function ClearESP()
    for char, hl in pairs(espCache) do
        if hl and hl:IsA("Highlight") then
            hl.Enabled = false
            hl.FillColor = Color3.fromRGB(255, 0, 0)
            hl.OutlineTransparency = 0
            hl.FillTransparency = 0.5
        end
    end
    espCache = {}
end

local function GetTarget()
    local closest = nil
    local shortest = AimRadius
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not IsInLobby(player) then
            local hum = player.Character:FindFirstChild("Humanoid")
            
            if hum and hum.Health > 0 then
                local part = player.Character:FindFirstChild(HitPart) or player.Character:FindFirstChild("HumanoidRootPart")
                if part then
                    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                        if dist < shortest then
                            shortest = dist
                            closest = part
                        end
                    end
                end
            end
        end
    end
    return closest
end

RunService:BindToRenderStep("HappyAimFilter", Enum.RenderPriority.Camera.Value + 10, function(dt)
    if not AimActive then return end

    local target = GetTarget()
    if target then
        local myPos = Camera.CFrame.Position
        local targetPos = target.Position
        
        local distance = (targetPos - myPos).Magnitude
        local travelTime = distance / 300 
        local velocity = target.AssemblyLinearVelocity
        local predictedPos = targetPos + (velocity * travelTime * Prediction)

        if (predictedPos - myPos).Magnitude > 2 then
            local targetCFrame = CFrame.new(myPos, predictedPos)
            local alpha = 1 - math.exp(-AimSpeed * dt)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, alpha)
        end
    end
end)

local uiSuccess = pcall(function()
    local homeTab = window:CreateTab("Home",HomeTabicon )
    local combatTab = window:CreateTab("Combat", API.Icons.Combat)
    local visualTab = window:CreateTab("Visual", API.Icons.Visual)

    window:CreateImageCard(homeTab, {
    Image = "rbxthumb://type=Asset&id=" .. game.PlaceId .. "&w=420&h=420",
    Title = "[FPS] Flick",
    Subtitle = "by replicatedscripts",
    Description = "Enjoy the free features.",
    Height = 140,
    ImageWidth = 120,
    OnClick = function() API:Notify("actual game playing") end
})

    window:CreateLabel(combatTab, "Aimbot & Configs")
    window:CreateToggle(combatTab, "Aimbot", false, function(s) 
        AimActive = s 
    end, "Aimbot always enabled")

    window:CreateSlider(combatTab, "FOV Radius", 20, 300, 150, function(v) 
        AimRadius = v 
    end, "Radio desde el centro de la pantalla")

    window:CreateSlider(combatTab, "Aim Speed", 1, 3, 2, function(v) 
        AimSpeed = v * 10 
    end, "1,2 and 3")

    window:CreateSlider(combatTab, "Prediction", 0, 1, 0.15, function(v) 
        Prediction = v 
    end, "Anticipation of movement")

    window:CreateDropdown(combatTab, "Target Part", {"Head", "HumanoidRootPart", "UpperTorso"}, "Head", function(v) 
        HitPart = v 
    end, "Body part to target")

    window:CreateLabel(visualTab, "ESP")
    window:CreateToggle(visualTab, "Highlight", false, function(s) 
        EspActive = s
        if not s then ClearESP() end
    end, "Highlight only players currently in a match")

    window:BuildConfigPage()
end)

if not uiSuccess then
    game:GetService("StarterGui"):SetCore("SendNotification", {Title = "UI Error", Text = "The UI failed to load."})
end

API:Notify("Hello again "..LocalPlayer.DisplayName, 3)
