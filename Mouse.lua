local API = loadstring(game:HttpGet("https://raw.githubusercontent.com/overthcode2011-stack/HHB/refs/heads/main/API"))()

API.Config.SupportedGames = {}
API.Config.KeySystem.Enabled = false

local window = API:CreateWindow("Happy Hub", "By replicatedman")
if not window then
    warn("[Happy Hub] Window failed to create")
    return
end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Market     = game:GetService("MarketplaceService")
local LP         = Players.LocalPlayer
local Camera     = workspace.CurrentCamera

local State = {
    ESP         = true,
    ESPColor    = Color3.fromRGB(255, 60, 60),
    ESPFill     = 0.55,
    UWU         = true,
    UWUVolume   = 0.55,
    UWUId       = "rbxassetid://139219844119994",
    Noclip      = true,
    DroppedKeys = false,
    KeysRange   = 50,
    Subtitles   = true,
}

local function getChar()
    local c = LP.Character
    return c, c and c:FindFirstChild("HumanoidRootPart")
end

local function getMickeyRig()
    local rig = workspace:FindFirstChild("MickeyVisual")
    if rig and rig:IsA("Model") then return rig end
end

local function mickeyAlive()
    local rig = getMickeyRig()
    if not rig then return false end
    local hum = rig:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health > 0 end
    return true
end

local currentHL, currentRig

local function removeHighlight()
    if currentHL then pcall(function() currentHL:Destroy() end) end
    currentHL, currentRig = nil, nil
end

local function ensureHighlight()
    if not State.ESP then return removeHighlight() end
    local rig = getMickeyRig()
    if not (rig and mickeyAlive()) then return removeHighlight() end

    if currentRig ~= rig or not currentHL or not currentHL.Parent then
        removeHighlight()
        local hl   = Instance.new("Highlight")
        hl.Name    = "HH_Highlight"
        hl.Adornee = rig
        hl.Parent  = rig
        currentHL, currentRig = hl, rig
    end
    currentHL.FillColor           = State.ESPColor
    currentHL.FillTransparency    = State.ESPFill
    currentHL.OutlineTransparency = 1
    currentHL.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
end
task.spawn(function() while task.wait(0.5) do ensureHighlight() end end)

local function applyUWU()
    if not State.UWU then return end
    local m    = workspace:FindFirstChild("Mickey")
    local root = m and m:FindFirstChild("Root")
    local s    = root and root:FindFirstChild("MonsterWillieScream")
    if s and s:IsA("Sound") and s.SoundId ~= State.UWUId then
        s.SoundId = State.UWUId
        s.Volume  = State.UWUVolume
        API:Notify("UWU scream applied", 2)
    elseif s and s:IsA("Sound") then
        s.Volume = State.UWUVolume
    end
end
task.spawn(function() while task.wait(1) do applyUWU() end end)
applyUWU()

local function setCharCollision(collide)
    local char = LP.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = collide end
        end
    end
end

local function applyNoclip()
    if not State.Noclip then return end
    setCharCollision(false)
    local bacon = workspace:FindFirstChild("ReplicatedBacon_0")
    local cp = bacon and bacon:FindFirstChild("CollisionPart")
    if cp and cp:IsA("BasePart") then cp.CanCollide = false end
end
LP.CharacterAdded:Connect(function() task.wait(0.2); applyNoclip() end)
task.spawn(function() while task.wait(0.1) do applyNoclip() end end)

task.spawn(function()
    while task.wait(0.3) do
        if not State.DroppedKeys then continue end
        local folder = workspace:FindFirstChild("DroppedKeys")
        if not folder then continue end
        local _, hrp = getChar()
        if not hrp then continue end
        for _, k in ipairs(folder:GetChildren()) do
            local base = k:IsA("BasePart") and k
                      or k.PrimaryPart
                      or k:FindFirstChildWhichIsA("BasePart", true)
            if base then
                base.CanCollide = false
                if (base.Position - hrp.Position).Magnitude <= State.KeysRange then
                    base.CFrame = CFrame.new(
                        hrp.Position + Vector3.new(math.random(-3,3), 2, math.random(-3,3))
                    )
                end
            end
        end
    end
end)

workspace.ChildAdded:Connect(function(c)
    if c.Name == "MickeyVisual"      then task.wait(0.1); ensureHighlight() end
    if c.Name == "Mickey"            then task.wait(0.2); applyUWU()        end
    if c.Name == "ReplicatedBacon_0" then task.wait(0.1); applyNoclip()     end
end)
workspace.ChildRemoved:Connect(function(c)
    if c.Name == "MickeyVisual" then removeHighlight() end
end)

local subtitle = Drawing.new("Text")
subtitle.Size         = 24
subtitle.Color        = Color3.fromRGB(255, 105, 180)
subtitle.Outline      = true
subtitle.OutlineColor = Color3.fromRGB(80, 0, 40)
subtitle.Center       = true
subtitle.Visible      = false

local subPhrases = { "UwU", "Nya" }
local subLast    = 0
local subIdx     = 0

RunService.RenderStepped:Connect(function()
    if not State.Subtitles then subtitle.Visible = false; return end

    local rig = getMickeyRig()
    local _, hrp = getChar()
    if not (rig and hrp) then subtitle.Visible = false; return end

    local head = rig:FindFirstChild("Head") or rig:FindFirstChild("HumanoidRootPart")
    if not head or not head:IsA("BasePart") then subtitle.Visible = false; return end

    if (hrp.Position - head.Position).Magnitude > 45 then
        subtitle.Visible = false
        return
    end

    local now = os.clock()
    if now - subLast > 1.5 then
        subLast = now
        subIdx = (subIdx % #subPhrases) + 1
        subtitle.Text = subPhrases[subIdx]
    end

    local sp, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2.5, 0))
    if not onScreen then subtitle.Visible = false; return end

    subtitle.Position = Vector2.new(sp.X + math.random(-3, 3), sp.Y + math.random(-3, 3))
    subtitle.Visible  = true
end)

local home = window:CreateTab("Home", API.Icons.Home)

local function getThumb()
    local ok, img = pcall(function()
        return Market:GetGameIconAsync(game.PlaceId, Enum.AssetType.ImageSize.Size420x420)
    end)
    if ok then return img end
    local ok2, img2 = pcall(function()
        return Market:GetGameIconAsync(game.PlaceId)
    end)
    if ok2 then return img2 end
end

local thumb = getThumb()
window:CreateImageCard(home, {
    Image       = thumb,
    Title       = "RATON",
    Subtitle    = "Happy Hub",
    Description = "Highlight ESP, noclip, UWU scream and dropped-key magnet. Toggle any feature below.",
    Height      = 240,
    OnClick     = function() end,
})

window:CreateParagraph(home,
    "Press F3 to toggle the UI. Open the Settings tab to save your current toggles as a preset.")

window:CreateLabel(home, "Quick toggles")
window:CreateButton(home, "Reapply highlight", function()
    removeHighlight(); ensureHighlight()
    API:Notify("Highlight refreshed", 2)
end, "Forces the highlight to rebuild on the current rig")

window:CreateButton(home, "Reset UWU sound", function()
    State.UWUId = "rbxassetid://139219844119994"
    applyUWU()
    API:Notify("UWU sound reset", 2)
end, "Restores the default UWU audio id")

local tab = window:CreateTab("Main", API.Icons.Visual)

window:CreateLabel(tab, "Visual")
local espToggle = window:CreateToggle(tab, "Highlight MickeyVisual", State.ESP, function(v)
    State.ESP = v
    if v then ensureHighlight() else removeHighlight() end
end, "Outline-free highlight on Mickey's rig", "ESP on/off")

local subToggle = window:CreateToggle(tab, "UwU / Nya subtitles", State.Subtitles, function(v)
    State.Subtitles = v
    if not v then subtitle.Visible = false end
end, "Pink shaking text above Mickey's head", "tsundere pink")

window:CreateLabel(tab, "Audio")
local uwuToggle = window:CreateToggle(tab, "UWU scream", State.UWU, function(v)
    State.UWU = v
    if v then applyUWU() end
end, "Replaces MonsterWillieScream with a cute scream", "Monster audio")

local uwuVolSlider = window:CreateSlider(tab, "UWU volume", 0, 1, State.UWUVolume, function(v)
    State.UWUVolume = v
    applyUWU()
end, "Volume of the replaced scream")

window:CreateLabel(tab, "Movement")
local noclipToggle = window:CreateToggle(tab, "Noclip", State.Noclip, function(v)
    State.Noclip = v
    if v then
        applyNoclip()
    else
        setCharCollision(true)
        local bacon = workspace:FindFirstChild("ReplicatedBacon_0")
        local cp = bacon and bacon:FindFirstChild("CollisionPart")
        if cp and cp:IsA("BasePart") then cp.CanCollide = true end
    end
end, "Walk through walls (includes Server Authority bypass)", "Noclip")

window:CreateLabel(tab, "Keys")
local keysToggle = window:CreateToggle(tab, "Dropped-key magnet", State.DroppedKeys, function(v)
    State.DroppedKeys = v
end, "Keys inside DroppedKeys follow the player")

local keysRangeSlider = window:CreateSlider(tab, "Magnet range", 10, 200, State.KeysRange, function(v)
    State.KeysRange = v
end, "Max distance for pulling keys")

window:SetConfigSnapshot(function()
    return {
        ESP         = espToggle:GetState(),
        Subtitles   = subToggle:GetState(),
        UWU         = uwuToggle:GetState(),
        UWUVolume   = uwuVolSlider:GetValue(),
        Noclip      = noclipToggle:GetState(),
        DroppedKeys = keysToggle:GetState(),
        KeysRange   = keysRangeSlider:GetValue(),
        Theme       = API:GetTheme(),
    }
end)

window:SetConfigApply(function(data)
    if data.ESP ~= nil then
        espToggle:SetState(data.ESP, true); State.ESP = data.ESP
        if data.ESP then ensureHighlight() else removeHighlight() end
    end
    if data.Subtitles ~= nil then
        subToggle:SetState(data.Subtitles, true); State.Subtitles = data.Subtitles
        if not data.Subtitles then subtitle.Visible = false end
    end
    if data.UWU ~= nil then
        uwuToggle:SetState(data.UWU, true); State.UWU = data.UWU
    end
    if data.UWUVolume ~= nil then
        uwuVolSlider:SetValue(data.UWUVolume, true); State.UWUVolume = data.UWUVolume
    end
    if data.Noclip ~= nil then
        noclipToggle:SetState(data.Noclip, true); State.Noclip = data.Noclip
        if data.Noclip then applyNoclip() else setCharCollision(true) end
    end
    if data.DroppedKeys ~= nil then
        keysToggle:SetState(data.DroppedKeys, true); State.DroppedKeys = data.DroppedKeys
    end
    if data.KeysRange ~= nil then
        keysRangeSlider:SetValue(data.KeysRange, true); State.KeysRange = data.KeysRange
    end
    if data.Theme then API:SetTheme(data.Theme) end
end)

window:BuildConfigPage()

API:Notify("Happy Hub loaded", 4)
