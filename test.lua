local API = {}
API.__index = API

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local SoundService     = game:GetService("SoundService")
local LocalPlayer      = Players.LocalPlayer

local hasFileSystem = (writefile and readfile and isfile and isfolder and makefolder and listfiles and delfile)

if hasFileSystem then
    pcall(function()
        if not isfolder("HappyHub") then makefolder("HappyHub") end
        if not isfolder("HappyHub/Configs") then makefolder("HappyHub/Configs") end
    end)
end

local FONT_MAIN           = Font.fromEnum(Enum.Font.Code)
local MAIN_ICON           = "rbxassetid://104348663064077"
local CLOSE_ICON          = "rbxassetid://130629964514885"
local MIN_ICON            = "rbxassetid://115558082558028"
local EXPAND_ICON         = "rbxassetid://138995275916746"
local SEARCH_ICON         = "rbxassetid://118685771787843"
local INFO_ICON           = "rbxassetid://80780628588275"
local NOTIF_ICON          = "rbxassetid://91047500682054"
local DROPDOWN_ARROW_ICON = "rbxassetid://74174300099317"
local OWNER_BADGE_ICON    = "13737813988"
local OWNER_ID            = 10716243983
local TYPING_SOUND_ID     = "rbxassetid://140036379967302"
local NOTIF_SOUND_ID      = "rbxassetid://97455084935031"

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local typingSound = Instance.new("Sound")
typingSound.SoundId = TYPING_SOUND_ID
typingSound.Volume = 0.5
typingSound.Parent = SoundService

local notifSound = Instance.new("Sound")
notifSound.SoundId = NOTIF_SOUND_ID
notifSound.Volume = 1
notifSound.Parent = SoundService

local THEMES = {
    Green = {
        Accent = Color3.fromRGB(0, 255, 63), Background = Color3.fromRGB(0, 0, 0),
        Panel = Color3.fromRGB(8, 8, 8), Text = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(180, 180, 180), Hover = Color3.fromRGB(20, 20, 20),
        ToggleOn = Color3.fromRGB(0, 255, 63), ToggleOff = Color3.fromRGB(40, 40, 40),
    },
    Purple = {
        Accent = Color3.fromRGB(160, 80, 255), Background = Color3.fromRGB(8, 4, 15),
        Panel = Color3.fromRGB(12, 8, 20), Text = Color3.fromRGB(240, 228, 255),
        TextSecondary = Color3.fromRGB(160, 140, 200), Hover = Color3.fromRGB(25, 15, 40),
        ToggleOn = Color3.fromRGB(160, 80, 255), ToggleOff = Color3.fromRGB(55, 35, 80),
    },
    Blue = {
        Accent = Color3.fromRGB(40, 160, 255), Background = Color3.fromRGB(3, 8, 15),
        Panel = Color3.fromRGB(6, 12, 22), Text = Color3.fromRGB(215, 232, 255),
        TextSecondary = Color3.fromRGB(120, 160, 210), Hover = Color3.fromRGB(15, 25, 45),
        ToggleOn = Color3.fromRGB(40, 160, 255), ToggleOff = Color3.fromRGB(25, 45, 80),
    },
    Red = {
        Accent = Color3.fromRGB(230, 50, 50), Background = Color3.fromRGB(10, 3, 3),
        Panel = Color3.fromRGB(15, 5, 5), Text = Color3.fromRGB(255, 228, 228),
        TextSecondary = Color3.fromRGB(190, 140, 140), Hover = Color3.fromRGB(30, 10, 10),
        ToggleOn = Color3.fromRGB(230, 50, 50), ToggleOff = Color3.fromRGB(70, 28, 28),
    },
    Pink = {
        Accent = Color3.fromRGB(255, 105, 180), Background = Color3.fromRGB(15, 5, 12),
        Panel = Color3.fromRGB(22, 8, 18), Text = Color3.fromRGB(255, 220, 240),
        TextSecondary = Color3.fromRGB(200, 150, 180), Hover = Color3.fromRGB(35, 12, 28),
        ToggleOn = Color3.fromRGB(255, 105, 180), ToggleOff = Color3.fromRGB(80, 30, 60),
    },
    Yellow = {
        Accent = Color3.fromRGB(255, 215, 0), Background = Color3.fromRGB(10, 9, 3),
        Panel = Color3.fromRGB(18, 16, 6), Text = Color3.fromRGB(255, 250, 220),
        TextSecondary = Color3.fromRGB(190, 175, 120), Hover = Color3.fromRGB(30, 27, 10),
        ToggleOn = Color3.fromRGB(255, 215, 0), ToggleOff = Color3.fromRGB(70, 60, 20),
    },
    Orange = {
        Accent = Color3.fromRGB(255, 130, 40), Background = Color3.fromRGB(12, 6, 2),
        Panel = Color3.fromRGB(20, 10, 4), Text = Color3.fromRGB(255, 235, 220),
        TextSecondary = Color3.fromRGB(200, 160, 130), Hover = Color3.fromRGB(32, 16, 6),
        ToggleOn = Color3.fromRGB(255, 130, 40), ToggleOff = Color3.fromRGB(80, 40, 15),
    },
    Cyan = {
        Accent = Color3.fromRGB(0, 220, 220), Background = Color3.fromRGB(2, 8, 10),
        Panel = Color3.fromRGB(4, 14, 18), Text = Color3.fromRGB(220, 250, 255),
        TextSecondary = Color3.fromRGB(130, 190, 200), Hover = Color3.fromRGB(6, 22, 28),
        ToggleOn = Color3.fromRGB(0, 220, 220), ToggleOff = Color3.fromRGB(15, 60, 70),
    },
    Creator = {
        Accent = Color3.fromRGB(0, 255, 140), Background = Color3.fromRGB(0, 0, 0),
        Panel = Color3.fromRGB(6, 12, 8), Text = Color3.fromRGB(230, 255, 240),
        TextSecondary = Color3.fromRGB(140, 200, 170), Hover = Color3.fromRGB(10, 20, 14),
        ToggleOn = Color3.fromRGB(0, 255, 140), ToggleOff = Color3.fromRGB(20, 50, 35),
        GradientTop = Color3.fromRGB(0, 0, 0),
        GradientBottom = Color3.fromRGB(20, 120, 70),
        GradientTransparencyTop = 0,
        GradientTransparencyBottom = 0.65,
    },
}

local savedTheme = "Green"
if hasFileSystem then
    pcall(function()
        if isfile("HappyHub/theme.txt") then
            local t = readfile("HappyHub/theme.txt")
            if t and THEMES[t] then savedTheme = t end
        end
    end)
end

local currentThemeName = savedTheme
local Colors = {}
for k, v in pairs(THEMES[currentThemeName]) do Colors[k] = v end

local suppressNotify = false
local activeTabName = ""

local reg = {
    panels = {}, texts = {}, subtexts = {}, accentBgs = {}, accentTexts = {},
    accentStrokes = {}, accentIcons = {}, pills = {}, sliderFills = {},
    sliderHandles = {}, sidebarBtns = {}, sidebarIcons = {}, sidebarTexts = {},
    scrollBars = {}, dropdowns = {}, mainFrame = nil, tabContainer = nil,
    contentArea = nil, playerCard = nil,
}

local openDropdowns = {}
local typingTokens = {}
local notifOrder = 0
local screenGui, mainFrame, tabContainer, contentArea, playerCard
local toggleBtn
local currentWindow = nil
local cleanupConnections = {}
local searchIndex = {}
local NamedControls = {}
local NotifyImpl
local globalClickConn = nil

local function register(list, obj)
    table.insert(list, obj)
    return obj
end

local function makeCorner(p, r)
    local c = Instance.new("UICorner")
    if typeof(r) == "UDim" then
        c.CornerRadius = r
    else
        c.CornerRadius = UDim.new(0, r)
    end
    c.Parent = p
    return c
end

local function attachTooltip(control, text)
    if not control or not text then return end
    if not screenGui or not screenGui.Parent then return end

    local tip = Instance.new("TextLabel")
    tip.Name = "HHTooltip"
    tip.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    tip.BackgroundTransparency = 0.05
    tip.BorderSizePixel = 0
    tip.FontFace = FONT_MAIN
    tip.TextSize = 11
    tip.TextColor3 = Colors.Text
    tip.Text = text
    tip.TextWrapped = true
    tip.Visible = false
    tip.ZIndex = 999
    tip.AutomaticSize = Enum.AutomaticSize.XY
    tip.Size = UDim2.fromOffset(0, 0)
    tip.Parent = screenGui

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = tip

    local sizeConstraint = Instance.new("UITextSizeConstraint")
    sizeConstraint.MaxTextSize = 11
    sizeConstraint.Parent = tip

    makeCorner(tip, 6)

    local conn
    control.MouseEnter:Connect(function()
        tip.Visible = true
        conn = RunService.RenderStepped:Connect(function()
            local mouse = UserInputService:GetMouseLocation()
            tip.Position = UDim2.fromOffset(mouse.X + 14, mouse.Y + 14)
        end)
    end)
    control.MouseLeave:Connect(function()
        tip.Visible = false
        if conn then conn:Disconnect(); conn = nil end
    end)
    control.AncestryChanged:Connect(function()
        if not control:IsDescendantOf(game) then
            tip:Destroy()
            if conn then conn:Disconnect(); conn = nil end
        end
    end)

    return tip
end

local function closeAllDropdowns()
    for _, fn in ipairs(openDropdowns) do pcall(fn) end
end

local function isUIUsable()
    if not mainFrame then return false end
    if not mainFrame.Parent then return false end
    if not mainFrame.Visible then return false end
    if currentWindow and currentWindow.Minimized then return false end
    return true
end

local function registerSearchEntry(name, description, tabName, controlRef, jumpFn)
    table.insert(searchIndex, {
        name = name,
        desc = description or "",
        tab = tabName or "Unknown",
        ref = controlRef,
        jump = jumpFn,
    })
end

local function applyTheme()
    local th = Colors
    if reg.mainFrame then reg.mainFrame.BackgroundColor3 = th.Background end
    for _, o in ipairs(reg.panels)        do if o and o.Parent then o.BackgroundColor3 = th.Panel end end
    for _, o in ipairs(reg.texts)         do if o and o.Parent then o.TextColor3 = th.Text end end
    for _, o in ipairs(reg.subtexts)      do if o and o.Parent then o.TextColor3 = th.TextSecondary end end
    for _, o in ipairs(reg.accentBgs)     do if o and o.Parent then o.BackgroundColor3 = th.Accent end end
    for _, o in ipairs(reg.accentTexts)   do if o and o.Parent then o.TextColor3 = th.Accent end end
    for _, o in ipairs(reg.accentStrokes) do if o and o.Parent then o.Color = th.Accent end end
    for _, o in ipairs(reg.accentIcons)   do if o and o.Parent then o.ImageColor3 = th.Accent end end
    for _, o in ipairs(reg.sliderFills)   do if o and o.Parent then o.BackgroundColor3 = th.Accent end end
    for _, o in ipairs(reg.sliderHandles) do if o and o.Parent then o.BackgroundColor3 = th.Text end end
    for _, o in ipairs(reg.scrollBars)    do if o and o.Parent then o.ScrollBarImageColor3 = th.Accent end end
    for _, d in ipairs(reg.pills) do
        local pill, knob, getState = d[1], d[2], d[3]
        if pill and pill.Parent then
            pill.BackgroundColor3 = getState() and th.ToggleOn or th.ToggleOff
        end
        if knob and knob.Parent then knob.BackgroundColor3 = th.Text end
    end
    for _, d in ipairs(reg.sidebarBtns) do
        local btn, name = d[1], d[2]
        if btn and btn.Parent then
            btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            if name == activeTabName then
                btn.BackgroundTransparency = 0
                btn.TextColor3 = th.Accent
            else
                btn.BackgroundTransparency = 0.35
                btn.TextColor3 = th.Text
            end
        end
    end
    for _, d in ipairs(reg.sidebarIcons) do
        local ic, name = d[1], d[2]
        if ic and ic.Parent then
            ic.ImageColor3 = (name == activeTabName) and th.Accent or th.TextSecondary
        end
    end
    for _, d in ipairs(reg.sidebarTexts) do
        local tx, name = d[1], d[2]
        if tx and tx.Parent then
            tx.TextColor3 = (name == activeTabName) and th.Accent or th.Text
        end
    end
    for _, d in ipairs(reg.dropdowns) do
        local b, list, btns, getSel, arrow = d[1], d[2], d[3], d[4], d[5]
        if b and b.Parent then
            b.BackgroundColor3 = th.Panel
            b.TextColor3 = th.Text
        end
        if arrow and arrow.Parent then arrow.ImageColor3 = th.Text end
        if list and list.Parent then list.BackgroundColor3 = th.Panel end
        local sel = getSel and getSel() or nil
        for _, ob in ipairs(btns) do
            if ob and ob.Parent then
                if ob.Text == sel then
                    ob.BackgroundColor3 = th.Accent
                    ob.BackgroundTransparency = 0
                    ob.TextColor3 = th.Background
                else
                    ob.BackgroundColor3 = th.Panel
                    ob.BackgroundTransparency = 0.2
                    ob.TextColor3 = th.Text
                end
            end
        end
    end

    if reg.mainFrame then
        local existing = reg.mainFrame:FindFirstChild("CreatorGradient")
        if currentThemeName == "Creator" then
            if not existing then
                local grad = Instance.new("UIGradient")
                grad.Name = "CreatorGradient"
                grad.Rotation = 90
                grad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, th.GradientTop or th.Background),
                    ColorSequenceKeypoint.new(1, th.GradientBottom or th.Accent),
                })
                grad.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, th.GradientTransparencyTop or 0),
                    NumberSequenceKeypoint.new(1, th.GradientTransparencyBottom or 0.65),
                })
                grad.Parent = reg.mainFrame
            else
                existing.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, th.GradientTop or th.Background),
                    ColorSequenceKeypoint.new(1, th.GradientBottom or th.Accent),
                })
                existing.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, th.GradientTransparencyTop or 0),
                    NumberSequenceKeypoint.new(1, th.GradientTransparencyBottom or 0.65),
                })
            end
        else
            if existing then existing:Destroy() end
        end
    end
end

local function registerTyping(label, fullText, speed)
    if not label or not fullText then return end
    table.insert(typingTokens, { Label = label, FullText = fullText, Speed = speed or 0.02, Token = {} })
end

local function playTyping(tab)
    if not tab then return end
    pcall(function() typingSound:Play() end)
    for _, entry in ipairs(typingTokens) do
        local lbl = entry.Label
        if lbl and lbl.Parent and lbl:IsDescendantOf(tab.Content) then
            local token = {}
            entry.Token = token
            local full = entry.FullText
            lbl.Text = ""
            task.spawn(function()
                for i = 1, #full do
                    if entry.Token ~= token then return end
                    if not lbl or not lbl.Parent then return end
                    lbl.Text = string.sub(full, 1, i)
                    task.wait(entry.Speed)
                end
                if entry.Token == token and lbl and lbl.Parent then lbl.Text = full end
            end)
        end
    end
end

local function stopAllTyping()
    for _, entry in ipairs(typingTokens) do entry.Token = {} end
end

function API:GetControl(name)
    if not name then return nil end
    if NamedControls[name] then return NamedControls[name] end
    local lower = string.lower(name)
    for k, v in pairs(NamedControls) do
        if string.lower(k) == lower then return v end
    end
    return nil
end

function API:GetControlsByName(name)
    local out = {}
    if not name then return out end
    local lower = string.lower(name)
    for k, v in pairs(NamedControls) do
        if string.find(string.lower(k), lower, 1, true) then
            table.insert(out, v)
        end
    end
    return out
end

function API:GetScreenGui() return screenGui end
function API:GetWindow() return currentWindow end
function API:CloseAllDropdowns() closeAllDropdowns() end
function API:SuppressNotify() suppressNotify = true end
function API:UnsuppressNotify() suppressNotify = false end

function API:SetTheme(name)
    if not THEMES[name] then return end
    currentThemeName = name
    for k, v in pairs(THEMES[name]) do Colors[k] = v end
    applyTheme()
    if hasFileSystem then
        pcall(function() writefile("HappyHub/theme.txt", currentThemeName) end)
    end
end

function API:GetTheme() return currentThemeName end

function API:GetThemes()
    local list = {}
    for k in pairs(THEMES) do list[#list+1] = k end
    return list
end

function API:Notify(text, duration)
    if screenGui and screenGui.Parent and NotifyImpl then
        pcall(function() NotifyImpl(text, duration) end)
    end
end

function API:SaveTheme()
    if hasFileSystem then
        pcall(function() writefile("HappyHub/theme.txt", currentThemeName) end)
    end
end

function API:CreateWindow(title, subtitle)
    local function randomGuiName()
        local names = {
            "BubbleChat", "ChatWindow", "PlayerList",
            "SystemMenu", "Notification", "RobloxLoading",
            "GamepadMenu", "TouchGui"
        }
        return names[math.random(1, #names)] .. tostring(math.random(1000, 9999))
    end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = randomGuiName()
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 0
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = true

    if syn and syn.protect_gui then
        pcall(function() syn.protect_gui(screenGui) end)
    elseif protect_gui then
        pcall(function() protect_gui(screenGui) end)
    end

    local hostParent
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then hostParent = hui end
    end
    if not hostParent then
        hostParent = game:GetService("CoreGui")
    end
    screenGui.Parent = hostParent

    local NotifContainer = Instance.new("Frame")
    NotifContainer.Name = "NotifContainer"
    if isMobile then
        NotifContainer.Size = UDim2.new(0, 220, 0.5, -20)
        NotifContainer.Position = UDim2.new(1, -230, 0, 10)
    else
        NotifContainer.Size = UDim2.new(0, 280, 1, -20)
        NotifContainer.Position = UDim2.new(1, -300, 0, 10)
    end
    NotifContainer.BackgroundTransparency = 1
    NotifContainer.Parent = screenGui

    local NotifLayout = Instance.new("UIListLayout")
    NotifLayout.Padding = UDim.new(0, 8)
    NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NotifLayout.Parent = NotifContainer

    NotifyImpl = function(text, duration)
        if suppressNotify then return end
        duration = duration or 3
        if not screenGui or not screenGui.Parent then return end
        notifOrder = notifOrder + 1
        pcall(function() notifSound:Play() end)
        local frame = Instance.new("Frame")
        frame.Name = "Notification"
        frame.Size = UDim2.new(1, 0, 0, isMobile and 50 or 56)
        frame.BackgroundColor3 = Colors.Panel
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.LayoutOrder = notifOrder
        frame.Parent = NotifContainer
        makeCorner(frame, 8)
        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 3, 1, -16)
        accent.Position = UDim2.new(0, 0, 0, 8)
        accent.BackgroundColor3 = Colors.Accent
        accent.BorderSizePixel = 0
        accent.Parent = frame
        makeCorner(accent, 2)
        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.fromOffset(isMobile and 24 or 30, isMobile and 24 or 30)
        icon.Position = UDim2.new(0, 10, 0.5, isMobile and -12 or -15)
        icon.BackgroundTransparency = 1
        icon.Image = NOTIF_ICON
        icon.Parent = frame
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -50, 0, 18)
        title.Position = UDim2.new(0, 42, 0, 8)
        title.BackgroundTransparency = 1
        title.FontFace = FONT_MAIN
        title.TextSize = isMobile and 12 or 13
        title.TextColor3 = Colors.Accent
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = "Happy Hub"
        title.Parent = frame
        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1, -50, 0, 16)
        msg.Position = UDim2.new(0, 42, 0, 24)
        msg.BackgroundTransparency = 1
        msg.FontFace = FONT_MAIN
        msg.TextSize = isMobile and 11 or 12
        msg.TextColor3 = Colors.TextSecondary
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.TextTruncate = Enum.TextTruncate.AtEnd
        msg.Text = text
        msg.Parent = frame
        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1, -20, 0, 3)
        barBg.Position = UDim2.new(0, 10, 1, -6)
        barBg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        barBg.BorderSizePixel = 0
        barBg.Parent = frame
        makeCorner(barBg, 2)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 1, 0)
        bar.BackgroundColor3 = Colors.Accent
        bar.BorderSizePixel = 0
        bar.Parent = barBg
        makeCorner(bar, 2)
        frame.Position = UDim2.new(1, 300, 0, 0)
        frame.BackgroundTransparency = 1
        icon.ImageTransparency = 1
        title.TextTransparency = 1
        msg.TextTransparency = 1
        accent.BackgroundTransparency = 1
        barBg.BackgroundTransparency = 1
        bar.BackgroundTransparency = 1
        TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.1
        }):Play()
        TweenService:Create(icon, TweenInfo.new(0.3), {ImageTransparency = 0}):Play()
        TweenService:Create(title, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
        TweenService:Create(msg, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
        TweenService:Create(accent, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
        TweenService:Create(barBg, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
        TweenService:Create(bar, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
        TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)}):Play()
        task.delay(duration, function()
            TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 300, 0, 0), BackgroundTransparency = 1
            }):Play()
            TweenService:Create(icon, TweenInfo.new(0.25), {ImageTransparency = 1}):Play()
            TweenService:Create(title, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
            TweenService:Create(msg, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
            TweenService:Create(accent, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
            TweenService:Create(barBg, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
            TweenService:Create(bar, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
            task.wait(0.4)
            frame:Destroy()
        end)
    end

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    if isMobile then
        mainFrame.Size = UDim2.new(0.6, 0, 0.8, 0)
        mainFrame.Position = UDim2.new(0.2, 0, 0.1, 0)
    else
        mainFrame.Size = UDim2.new(0, 700, 0, 450)
        mainFrame.Position = UDim2.new(0.5, -350, 0.5, -225)
    end
    mainFrame.BackgroundColor3 = Colors.Background
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = true
    mainFrame.Active = true
    mainFrame.ClipsDescendants = false
    mainFrame.ZIndex = 1
    mainFrame.Parent = screenGui
    makeCorner(mainFrame, 6)
    reg.mainFrame = mainFrame

    local Shadow = Instance.new("ImageLabel")
    Shadow.Name = "Shadow"
    Shadow.Size = UDim2.new(1, 30, 1, 30)
    Shadow.Position = UDim2.new(0, -15, 0, -15)
    Shadow.BackgroundTransparency = 1
    Shadow.Image = "rbxassetid://5028857084"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.5
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(24, 24, 276, 276)
    Shadow.ZIndex = 0
    Shadow.Parent = mainFrame
    makeCorner(Shadow, 6)

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, isMobile and 46 or 56)
    TopBar.Position = UDim2.new(0, 0, 0, 0)
    TopBar.BackgroundColor3 = Colors.Panel
    TopBar.BackgroundTransparency = 0.1
    TopBar.BorderSizePixel = 0
    TopBar.Active = true
    TopBar.ZIndex = 2
    TopBar.Parent = mainFrame
    makeCorner(TopBar, 6)
    register(reg.panels, TopBar)

    local TopBarGradient = Instance.new("UIGradient")
    TopBarGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Colors.Panel),
        ColorSequenceKeypoint.new(0.5, Colors.Accent),
        ColorSequenceKeypoint.new(1, Colors.Panel),
    })
    TopBarGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.55),
        NumberSequenceKeypoint.new(1, 1),
    })
    TopBarGradient.Rotation = 0
    TopBarGradient.Parent = TopBar

    local TopBarMask = Instance.new("Frame")
    TopBarMask.Size = UDim2.new(1, 0, 0, 12)
    TopBarMask.Position = UDim2.new(0, 0, 1, -12)
    TopBarMask.BackgroundColor3 = Colors.Panel
    TopBarMask.BackgroundTransparency = 0.1
    TopBarMask.BorderSizePixel = 0
    TopBarMask.ZIndex = 3
    TopBarMask.Parent = TopBar
    register(reg.panels, TopBarMask)

    local TopIcon = Instance.new("ImageLabel")
    TopIcon.Name = "TopIcon"
    TopIcon.Size = UDim2.fromOffset(isMobile and 26 or 32, isMobile and 26 or 32)
    TopIcon.Position = UDim2.new(0, isMobile and 10 or 16, 0.5, isMobile and -13 or -16)
    TopIcon.BackgroundTransparency = 1
    TopIcon.Image = MAIN_ICON
    TopIcon.ImageColor3 = Colors.Accent
    TopIcon.ZIndex = 4
    TopIcon.Parent = TopBar
    makeCorner(TopIcon, 4)
    register(reg.accentIcons, TopIcon)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Size = UDim2.new(1, isMobile and -160 or -220, 0, isMobile and 16 or 18)
    TitleLabel.Position = UDim2.new(0, isMobile and 42 or 58, 0, isMobile and 8 or 10)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.FontFace = FONT_MAIN
    TitleLabel.TextSize = isMobile and 13 or 16
    TitleLabel.TextColor3 = Colors.Text
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TitleLabel.Text = title or "Happy Hub"
    TitleLabel.ZIndex = 4
    TitleLabel.Parent = TopBar
    register(reg.texts, TitleLabel)

    local SubTitleLabel = Instance.new("TextLabel")
    SubTitleLabel.Name = "SubTitle"
    SubTitleLabel.Size = UDim2.new(1, isMobile and -160 or -220, 0, 14)
    SubTitleLabel.Position = UDim2.new(0, isMobile and 42 or 58, 0, isMobile and 24 or 30)
    SubTitleLabel.BackgroundTransparency = 1
    SubTitleLabel.FontFace = FONT_MAIN
    SubTitleLabel.TextSize = isMobile and 9 or 10
    SubTitleLabel.TextColor3 = Colors.TextSecondary
    SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubTitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    SubTitleLabel.Text = subtitle or "Keyless"
    SubTitleLabel.ZIndex = 4
    SubTitleLabel.Parent = TopBar
    register(reg.subtexts, SubTitleLabel)

    local btnSize = isMobile and 26 or 32
    local btnY = isMobile and -13 or -16
    local closeSpacing = isMobile and 36 or 44
    local minSpacing = isMobile and 68 or 82
    local searchSpacing = isMobile and 100 or 120

    local SearchButton = Instance.new("TextButton")
    SearchButton.Size = UDim2.new(0, btnSize, 0, btnSize)
    SearchButton.Position = UDim2.new(1, -searchSpacing, 0.5, btnY)
    SearchButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    SearchButton.BackgroundTransparency = 1
    SearchButton.BorderSizePixel = 0
    SearchButton.Text = ""
    SearchButton.AutoButtonColor = false
    SearchButton.ZIndex = 4
    SearchButton.Parent = TopBar

    local SearchIcon = Instance.new("ImageLabel")
    SearchIcon.Size = UDim2.fromOffset(isMobile and 14 or 18, isMobile and 14 or 18)
    SearchIcon.Position = UDim2.new(0.5, isMobile and -7 or -9, 0.5, isMobile and -7 or -9)
    SearchIcon.BackgroundTransparency = 1
    SearchIcon.Image = SEARCH_ICON
    SearchIcon.ImageColor3 = Colors.TextSecondary
    SearchIcon.ScaleType = Enum.ScaleType.Fit
    SearchIcon.ZIndex = 5
    SearchIcon.Parent = SearchButton

    local MinimizeButton = Instance.new("TextButton")
    MinimizeButton.Size = UDim2.new(0, btnSize, 0, btnSize)
    MinimizeButton.Position = UDim2.new(1, -minSpacing, 0.5, btnY)
    MinimizeButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MinimizeButton.BackgroundTransparency = 1
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.Text = ""
    MinimizeButton.AutoButtonColor = false
    MinimizeButton.ZIndex = 4
    MinimizeButton.Parent = TopBar

    local MinimizeIcon = Instance.new("ImageLabel")
    MinimizeIcon.Size = UDim2.fromOffset(isMobile and 12 or 16, isMobile and 12 or 16)
    MinimizeIcon.Position = UDim2.new(0.5, isMobile and -6 or -8, 0.5, isMobile and -6 or -8)
    MinimizeIcon.BackgroundTransparency = 1
    MinimizeIcon.Image = MIN_ICON
    MinimizeIcon.ImageColor3 = Colors.TextSecondary
    MinimizeIcon.ZIndex = 5
    MinimizeIcon.Parent = MinimizeButton

    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, btnSize, 0, btnSize)
    CloseButton.Position = UDim2.new(1, -closeSpacing, 0.5, btnY)
    CloseButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    CloseButton.BackgroundTransparency = 1
    CloseButton.BorderSizePixel = 0
    CloseButton.Text = ""
    CloseButton.AutoButtonColor = false
    CloseButton.ZIndex = 4
    CloseButton.Parent = TopBar

    local CloseIcon = Instance.new("ImageLabel")
    CloseIcon.Size = UDim2.fromOffset(isMobile and 12 or 16, isMobile and 12 or 16)
    CloseIcon.Position = UDim2.new(0.5, isMobile and -6 or -8, 0.5, isMobile and -6 or -8)
    CloseIcon.BackgroundTransparency = 1
    CloseIcon.Image = CLOSE_ICON
    CloseIcon.ImageColor3 = Colors.TextSecondary
    CloseIcon.ZIndex = 5
    CloseIcon.Parent = CloseButton

    local SidebarScroll = Instance.new("ScrollingFrame")
    SidebarScroll.Name = "SidebarScroll"
    if isMobile then
        SidebarScroll.Size = UDim2.new(0.3, 0, 0.55, 0)
        SidebarScroll.Position = UDim2.new(0, 8, 0, 46)
    else
        SidebarScroll.Size = UDim2.new(0, 200, 1, -145)
        SidebarScroll.Position = UDim2.new(0, 8, 0, 61)
    end
    SidebarScroll.BackgroundColor3 = Colors.Panel
    SidebarScroll.BackgroundTransparency = 0.2
    SidebarScroll.BorderSizePixel = 0
    SidebarScroll.ScrollBarThickness = 4
    SidebarScroll.ScrollBarImageColor3 = Colors.Accent
    SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    SidebarScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SidebarScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    SidebarScroll.ClipsDescendants = true
    SidebarScroll.ZIndex = 2
    SidebarScroll.Parent = mainFrame
    makeCorner(SidebarScroll, 5)
    register(reg.panels, SidebarScroll)
    register(reg.scrollBars, SidebarScroll)

    local SidebarLayout = Instance.new("UIListLayout")
    SidebarLayout.FillDirection = Enum.FillDirection.Vertical
    SidebarLayout.Padding = UDim.new(0, 6)
    SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarLayout.Parent = SidebarScroll

    local SidebarPad = Instance.new("UIPadding")
    SidebarPad.PaddingTop = UDim.new(0, 10)
    SidebarPad.PaddingBottom = UDim.new(0, 10)
    SidebarPad.Parent = SidebarScroll

    tabContainer = SidebarScroll
    reg.tabContainer = tabContainer

    contentArea = Instance.new("Frame")
    contentArea.Name = "PageContainer"
    if isMobile then
        contentArea.Size = UDim2.new(0.6, 0, 0.7, 0)
        contentArea.Position = UDim2.new(0.35, 0, 0.202, 0)
    else
        contentArea.Size = UDim2.new(1, -224, 1, -73)
        contentArea.Position = UDim2.new(0, 216, 0, 61)
    end
    contentArea.BackgroundColor3 = Colors.Background
    contentArea.BackgroundTransparency = 0.4
    contentArea.BorderSizePixel = 0
    contentArea.ClipsDescendants = true
    contentArea.ZIndex = 2
    contentArea.Parent = mainFrame
    makeCorner(contentArea, 5)
    register(reg.panels, contentArea)
    reg.contentArea = contentArea

    local SearchOverlay = Instance.new("Frame")
    SearchOverlay.Name = "SearchOverlay"
    SearchOverlay.Size = UDim2.new(1, 0, 0, 46)
    SearchOverlay.Position = UDim2.new(0, 0, 0, 0)
    SearchOverlay.BackgroundColor3 = Colors.Panel
    SearchOverlay.BackgroundTransparency = 0.05
    SearchOverlay.BorderSizePixel = 0
    SearchOverlay.Visible = false
    SearchOverlay.ZIndex = 50
    SearchOverlay.Parent = contentArea
    makeCorner(SearchOverlay, 6)

    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1, -40, 0, 32)
    SearchBox.Position = UDim2.new(0, 20, 0.5, -16)
    SearchBox.BackgroundColor3 = Colors.Background
    SearchBox.BackgroundTransparency = 0.3
    SearchBox.BorderSizePixel = 0
    SearchBox.FontFace = FONT_MAIN
    SearchBox.TextSize = 14
    SearchBox.TextColor3 = Colors.Text
    SearchBox.PlaceholderText = "Search features..."
    SearchBox.PlaceholderColor3 = Colors.TextSecondary
    SearchBox.Text = ""
    SearchBox.ClearTextOnFocus = false
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.ZIndex = 51
    SearchBox.Parent = SearchOverlay
    makeCorner(SearchBox, 4)

    local SearchBoxPad = Instance.new("UIPadding")
    SearchBoxPad.PaddingLeft = UDim.new(0, 10)
    SearchBoxPad.PaddingRight = UDim.new(0, 10)
    SearchBoxPad.Parent = SearchBox

    local SearchResults = Instance.new("ScrollingFrame")
    SearchResults.Name = "SearchResults"
    SearchResults.Size = UDim2.new(1, 0, 1, -46)
    SearchResults.Position = UDim2.new(0, 0, 0, 46)
    SearchResults.BackgroundColor3 = Colors.Panel
    SearchResults.BackgroundTransparency = 0.05
    SearchResults.BorderSizePixel = 0
    SearchResults.Visible = false
    SearchResults.ZIndex = 49
    SearchResults.ScrollBarThickness = 4
    SearchResults.ScrollBarImageColor3 = Colors.Accent
    SearchResults.CanvasSize = UDim2.new(0, 0, 0, 0)
    SearchResults.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SearchResults.Parent = contentArea
    makeCorner(SearchResults, 6)

    local SearchResultsLayout = Instance.new("UIListLayout")
    SearchResultsLayout.Padding = UDim.new(0, 4)
    SearchResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SearchResultsLayout.Parent = SearchResults

    local SearchResultsPad = Instance.new("UIPadding")
    SearchResultsPad.PaddingTop = UDim.new(0, 8)
    SearchResultsPad.PaddingBottom = UDim.new(0, 8)
    SearchResultsPad.PaddingLeft = UDim.new(0, 8)
    SearchResultsPad.PaddingRight = UDim.new(0, 8)
    SearchResultsPad.Parent = SearchResults

    playerCard = Instance.new("Frame")
    playerCard.Name = "PlayerCard"
    if isMobile then
        playerCard.Size = UDim2.new(0.3, 0, 0.22, 0)
        playerCard.Position = UDim2.new(0.015, 0, 0.75, 0)
    else
        playerCard.Size = UDim2.new(0, 200, 0, 64)
        playerCard.Position = UDim2.new(0, 8, 1, -72)
    end
    playerCard.BackgroundColor3 = Colors.Panel
    playerCard.BackgroundTransparency = 0.15
    playerCard.BorderSizePixel = 0
    playerCard.ZIndex = 5
    playerCard.Parent = mainFrame
    makeCorner(playerCard, 5)
    register(reg.panels, playerCard)
    reg.playerCard = playerCard

    local pfpFrame = Instance.new("Frame")
    pfpFrame.Size = UDim2.fromOffset(44, 44)
    pfpFrame.Position = UDim2.new(0, 10, 0.5, -22)
    pfpFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    pfpFrame.BorderSizePixel = 0
    pfpFrame.Parent = playerCard
    makeCorner(pfpFrame, 22)

    local pfp = Instance.new("ImageLabel")
    pfp.Size = UDim2.new(1, 0, 1, 0)
    pfp.BackgroundTransparency = 1
    pfp.BorderSizePixel = 0
    pfp.ScaleType = Enum.ScaleType.Crop
    pfp.Parent = pfpFrame
    makeCorner(pfp, 22)

    local onlineDot = Instance.new("Frame")
    onlineDot.Size = UDim2.fromOffset(12, 12)
    onlineDot.Position = UDim2.new(1, -12, 1, -12)
    onlineDot.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    onlineDot.BorderSizePixel = 0
    onlineDot.ZIndex = 6
    onlineDot.Parent = pfpFrame
    makeCorner(onlineDot, 6)

    local pfpName = Instance.new("TextLabel")
    pfpName.Size = UDim2.new(1, -72, 0, 18)
    pfpName.Position = UDim2.new(0, 62, 0, 14)
    pfpName.BackgroundTransparency = 1
    pfpName.FontFace = FONT_MAIN
    pfpName.TextSize = 13
    pfpName.TextColor3 = Colors.Text
    pfpName.TextXAlignment = Enum.TextXAlignment.Left
    pfpName.TextTruncate = Enum.TextTruncate.AtEnd
    pfpName.RichText = true
    pfpName.Text = LocalPlayer.DisplayName
    pfpName.Parent = playerCard
    register(reg.texts, pfpName)

    if LocalPlayer.UserId == OWNER_ID then
        pfpName.Text = string.format(
            '%s <img src="rbxassetid://%s" width="14" height="14" />',
            LocalPlayer.DisplayName,
            OWNER_BADGE_ICON
        )
    end

    local pfpUser = Instance.new("TextLabel")
    pfpUser.Size = UDim2.new(1, -72, 0, 14)
    pfpUser.Position = UDim2.new(0, 62, 0, 32)
    pfpUser.BackgroundTransparency = 1
    pfpUser.FontFace = FONT_MAIN
    pfpUser.TextSize = 11
    pfpUser.TextColor3 = Colors.TextSecondary
    pfpUser.TextXAlignment = Enum.TextXAlignment.Left
    pfpUser.TextTruncate = Enum.TextTruncate.AtEnd
    pfpUser.Text = "@" .. LocalPlayer.Name
    pfpUser.Parent = playerCard
    register(reg.subtexts, pfpUser)

    task.spawn(function()
        local ok, thumb = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok then pfp.Image = thumb end
    end)

    local KeybindsPanel = Instance.new("Frame")
    KeybindsPanel.Name = "KeybindsPanel"
    KeybindsPanel.Size = UDim2.new(0, 140, 0, 128)
    KeybindsPanel.Position = UDim2.new(1, 10, 0, 70)
    KeybindsPanel.BackgroundColor3 = Colors.Panel
    KeybindsPanel.BackgroundTransparency = 0.15
    KeybindsPanel.BorderSizePixel = 0
    KeybindsPanel.ZIndex = 5
    KeybindsPanel.Parent = mainFrame
    makeCorner(KeybindsPanel, 5)
    register(reg.panels, KeybindsPanel)

    local KeybindsTitle = Instance.new("TextLabel")
    KeybindsTitle.Size = UDim2.new(1, -16, 0, 20)
    KeybindsTitle.Position = UDim2.new(0, 8, 0, 6)
    KeybindsTitle.BackgroundTransparency = 1
    KeybindsTitle.FontFace = FONT_MAIN
    KeybindsTitle.TextSize = 11
    KeybindsTitle.TextColor3 = Colors.Accent
    KeybindsTitle.TextXAlignment = Enum.TextXAlignment.Left
    KeybindsTitle.Text = isMobile and "MOBILE CONTROLS" or "LEFT KEYBINDS"
    KeybindsTitle.ZIndex = 6
    KeybindsTitle.Parent = KeybindsPanel
    register(reg.accentTexts, KeybindsTitle)

    local function makeKeybindRow(parent, key, label, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -16, 0, 22)
        row.Position = UDim2.new(0, 8, 0, 28 + ((order - 1) * 24))
        row.BackgroundTransparency = 1
        row.ZIndex = 6
        row.Parent = parent

        local infoIcon = Instance.new("ImageLabel")
        infoIcon.Size = UDim2.fromOffset(18, 18)
        infoIcon.Position = UDim2.new(0, 2, 0.5, -9)
        infoIcon.BackgroundTransparency = 1
        infoIcon.Image = INFO_ICON
        infoIcon.ImageColor3 = Colors.Accent
        infoIcon.ZIndex = 6
        infoIcon.Parent = row
        register(reg.accentIcons, infoIcon)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -28, 1, 0)
        lbl.Position = UDim2.new(0, 28, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.FontFace = FONT_MAIN
        lbl.TextSize = 11
        lbl.TextColor3 = Colors.TextSecondary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label
        lbl.ZIndex = 6
        lbl.Parent = row
        register(reg.subtexts, lbl)
    end

    makeKeybindRow(KeybindsPanel, isMobile and "BTN" or "T", "Toggle Aimbot", 1)
    makeKeybindRow(KeybindsPanel, isMobile and "BTN" or "O", "Toggle ESP", 2)
    makeKeybindRow(KeybindsPanel, isMobile and "BTN" or "F3", "Toggle UI", 3)

    local DragBar = Instance.new("Frame")
    DragBar.Name = "DragBar"
    DragBar.Size = UDim2.new(0.12, 0, 0, 4)
    DragBar.AnchorPoint = Vector2.new(0.5, 1)
    DragBar.Position = UDim2.new(0.5, 0, 1, -6)
    DragBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    DragBar.BackgroundTransparency = 0.3
    DragBar.BorderSizePixel = 0
    DragBar.Active = true
    DragBar.ZIndex = 4
    DragBar.Parent = mainFrame
    makeCorner(DragBar, 2)

    local window = {
        ScreenGui = screenGui, MainFrame = mainFrame, TabContainer = tabContainer,
        ContentArea = contentArea, PlayerCard = playerCard, Tabs = {}, ActiveTab = nil,
        IsVisible = true, Minimized = false, FullyHidden = false,
    }

    local configSnapshotFn = nil
    local configApplyFn = nil
    local themeDropdownRef = nil

    function window:SetConfigSnapshot(fn) configSnapshotFn = fn end
    function window:SetConfigApply(fn) configApplyFn = fn end

    local function safeFileName(s)
        return (tostring(s):gsub("[^%w_%-%. ]", "_"))
    end

    local function getConfigFolder()
        if not hasFileSystem then return nil end
        if not isfolder("HappyHub") then makefolder("HappyHub") end
        if not isfolder("HappyHub/Configs") then makefolder("HappyHub/Configs") end
        return "HappyHub/Configs"
    end

    local function listConfigs()
        local out = {}
        if not hasFileSystem then return out end
        local folder = getConfigFolder()
        if not folder then return out end
        local ok, files = pcall(function() return listfiles(folder) end)
        if ok and files then
            for _, f in ipairs(files) do
                if f:sub(-5) == ".json" then
                    out[#out+1] = f:match("([^/\\]+)%.json$") or f
                end
            end
        end
        return out
    end

    function window:BuildConfigPage()
        local configTab = self:CreateTab("Settings", "117798608546747")

        self:CreateLabel(configTab, "Theme")
        local themes = API:GetThemes()
        local themeDropdown = self:CreateDropdown(configTab, "Theme", themes, API:GetTheme(), function(v)
            API:SetTheme(v)
        end)
        themeDropdownRef = themeDropdown

        self:CreateLabel(configTab, "Save / Load")
        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(1, -40, 0, 35)
        nameBox.BackgroundColor3 = Colors.Panel
        nameBox.BackgroundTransparency = 0.3
        nameBox.BorderSizePixel = 0
        nameBox.FontFace = FONT_MAIN
        nameBox.TextSize = 14
        nameBox.TextColor3 = Colors.Text
        nameBox.PlaceholderText = "Config name..."
        nameBox.PlaceholderColor3 = Colors.TextSecondary
        nameBox.Text = ""
        nameBox.ClearTextOnFocus = false
        nameBox.ZIndex = 3
        makeCorner(nameBox, 4)
        register(reg.panels, nameBox)
        register(reg.texts, nameBox)
        self._addElement(configTab, nameBox)

        self:CreateButton(configTab, "Save Config", function()
            if not configSnapshotFn then NotifyImpl("No snapshot bound") return end
            if not hasFileSystem then NotifyImpl("No filesystem") return end
            local name = nameBox.Text
            if name == "" then NotifyImpl("Enter a name") return end
            local folder = getConfigFolder()
            if not folder then NotifyImpl("No config folder") return end
            local path = folder .. "/" .. safeFileName(name) .. ".json"
            local ok, encoded = pcall(function()
                return HttpService:JSONEncode(configSnapshotFn())
            end)
            if not ok then NotifyImpl("Encode failed") return end
            local ok2 = pcall(function() writefile(path, encoded) end)
            if ok2 then NotifyImpl("Saved: " .. name) else NotifyImpl("Save failed") end
        end)

        self:CreateButton(configTab, "Load Config", function()
            if not configApplyFn then NotifyImpl("No apply bound") return end
            if not hasFileSystem then NotifyImpl("No filesystem") return end
            local name = nameBox.Text
            if name == "" then NotifyImpl("Enter a name") return end
            local folder = getConfigFolder()
            if not folder then NotifyImpl("No config folder") return end
            local path = folder .. "/" .. safeFileName(name) .. ".json"
            if not isfile(path) then NotifyImpl("Not found: " .. name) return end
            local ok, data = pcall(function()
                return HttpService:JSONDecode(readfile(path))
            end)
            if not ok or type(data) ~= "table" then NotifyImpl("Corrupt config") return end
            local ok2, err = pcall(function() configApplyFn(data) end)
            if ok2 then NotifyImpl("Loaded: " .. name) else NotifyImpl("Apply failed: " .. tostring(err)) end
            if data.Theme and themeDropdown then themeDropdown:SetValue(data.Theme) end
        end)

        self:CreateButton(configTab, "Delete Config", function()
            if not hasFileSystem then NotifyImpl("No filesystem") return end
            local name = nameBox.Text
            if name == "" then NotifyImpl("Enter a name") return end
            local folder = getConfigFolder()
            if not folder then NotifyImpl("No config folder") return end
            local path = folder .. "/" .. safeFileName(name) .. ".json"
            if not isfile(path) then NotifyImpl("Not found") return end
            pcall(function() delfile(path) end)
            NotifyImpl("Deleted: " .. name)
        end)

        self:CreateButton(configTab, "Refresh List", function()
            local list = listConfigs()
            if #list == 0 then NotifyImpl("No configs saved") else NotifyImpl(table.concat(list, ", ")) end
        end)

        self:CreateLabel(configTab, "Reset")
        self:CreateButton(configTab, "Reset All to Default", function()
            if not configApplyFn then return end
            local defaults = {
                Aimbot = {
                    MM2LockOn = false, MM2Smooth = 8, MM2Range = 500, MM2Target = "Small Avatar",
                    TriggerBot = false, TriggerRange = 150, AutoFire = false, WallCheck = true,
                },
                Visual = { MM2ESP = false, OGESP = false, NameTags = false },
                Misc = {
                    InfJump = false, AntiAFK = false, AutoTpGun = false,
                    SilentAim = false, MusicCompanion = false,
                },
                Movement = {
                    Noclip = false, God = false, Fly = false, WalkSpeed = 16, JumpPower = 50,
                    FlySpeed = 40, AntiFling = false, Fling = false, TPAll = false,
                },
                Avatar = { Korblox = false, Shoulder = false, Invisible = false, NoobFace = false, Rainbow = false },
                Farm = { AutoFarm = false, ManualCollect = false, CoinSpeed = 20, PickupRadius = 3 },
                Theme = "Green",
            }
            configApplyFn(defaults)
            if themeDropdown then themeDropdown:SetValue("Green") end
            NotifyImpl("Reset to defaults")
        end)

        self:CreateLabel(configTab, "Danger zone")
        local deleteBtn = self:CreateButton(configTab, "Delete UI", function()
            window.Destroy()
        end, "Completely removes the hub from your screen")
        deleteBtn.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
    end

    function window:UpdateThemeButtons()
        if themeDropdownRef then themeDropdownRef:SetValue(API:GetTheme()) end
    end

    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil

    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = mainFrame.Position
            closeAllDropdowns()
        end
    end

    local function updateDrag(input)
        if not dragging then return end
        if input ~= dragInput then return end
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end

    local function endDrag(input)
        if input and dragInput and input ~= dragInput then return end
        dragging = false
        dragInput = nil
    end

    TopBar.InputBegan:Connect(beginDrag)
    DragBar.InputBegan:Connect(beginDrag)

    DragBar.MouseEnter:Connect(function()
        TweenService:Create(DragBar, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end)
    DragBar.MouseLeave:Connect(function()
        TweenService:Create(DragBar, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
    end)

    table.insert(cleanupConnections, UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end))
    table.insert(cleanupConnections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            endDrag(input)
        end
    end))

    globalClickConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            local mousePos = input.Position
            local clickedInsideAny = false
            for _, obj in ipairs(screenGui:GetDescendants()) do
                if obj.Name == "HHDropdownList" and obj.Visible then
                    local abs = obj.AbsolutePosition
                    local size = obj.AbsoluteSize
                    if mousePos.X >= abs.X and mousePos.X <= abs.X + size.X
                    and mousePos.Y >= abs.Y and mousePos.Y <= abs.Y + size.Y then
                        clickedInsideAny = true
                        break
                    end
                end
            end
            if not clickedInsideAny then
                closeAllDropdowns()
            end
        end
    end)

    local function hideUI()
        closeAllDropdowns()
        window.IsVisible = false
        mainFrame.Visible = false
    end

    local function showUI()
        window.IsVisible = true
        mainFrame.Visible = true
    end

    window.HideUI = hideUI
    window.ShowUI = showUI
    window.ToggleUI = function()
        if window.IsVisible then hideUI() else showUI() end
    end

    window.Destroy = function()
        closeAllDropdowns()
        if globalClickConn then pcall(function() globalClickConn:Disconnect() end); globalClickConn = nil end
        if toggleBtn and toggleBtn.Parent then toggleBtn:Destroy() end
        if screenGui and screenGui.Parent then screenGui:Destroy() end
        for _, conn in ipairs(cleanupConnections) do
            pcall(function() conn:Disconnect() end)
        end
        cleanupConnections = {}
        currentWindow = nil
        _G.HappyHubAPI = nil
        searchIndex = {}
        NamedControls = {}
        openDropdowns = {}
    end

    SearchButton.MouseEnter:Connect(function()
        TweenService:Create(SearchButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.85}):Play()
        TweenService:Create(SearchIcon, TweenInfo.new(0.15), {ImageColor3 = Colors.Accent}):Play()
    end)
    SearchButton.MouseLeave:Connect(function()
        TweenService:Create(SearchButton, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        TweenService:Create(SearchIcon, TweenInfo.new(0.15), {ImageColor3 = Colors.TextSecondary}):Play()
    end)

    CloseButton.MouseEnter:Connect(function()
        TweenService:Create(CloseButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.85, BackgroundColor3 = Color3.fromRGB(40, 0, 0)}):Play()
        TweenService:Create(CloseIcon, TweenInfo.new(0.15), {ImageColor3 = Color3.fromRGB(255, 80, 80)}):Play()
    end)
    CloseButton.MouseLeave:Connect(function()
        TweenService:Create(CloseButton, TweenInfo.new(0.15), {BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(15, 15, 15)}):Play()
        TweenService:Create(CloseIcon, TweenInfo.new(0.15), {ImageColor3 = Colors.TextSecondary}):Play()
    end)

    MinimizeButton.MouseEnter:Connect(function()
        TweenService:Create(MinimizeButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.85}):Play()
        TweenService:Create(MinimizeIcon, TweenInfo.new(0.15), {ImageColor3 = Colors.Accent}):Play()
    end)
    MinimizeButton.MouseLeave:Connect(function()
        TweenService:Create(MinimizeButton, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        TweenService:Create(MinimizeIcon, TweenInfo.new(0.15), {ImageColor3 = Colors.TextSecondary}):Play()
    end)

    local searchOpen = false

    local function clearSearchResults()
        for _, ch in ipairs(SearchResults:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
    end

    local function buildSearchResults(query)
        clearSearchResults()
        if query == "" then
            SearchResults.Visible = false
            return
        end

        local q = query:lower()
        local matches = {}
        for _, entry in ipairs(searchIndex) do
            local hit = entry.name:lower():find(q, 1, true)
            if not hit and entry.desc ~= "" then
                hit = entry.desc:lower():find(q, 1, true)
            end
            if hit then
                table.insert(matches, entry)
            end
        end

        for _, entry in ipairs(matches) do
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, -8, 0, 38)
            row.BackgroundColor3 = Colors.Background
            row.BackgroundTransparency = 0.4
            row.BorderSizePixel = 0
            row.FontFace = FONT_MAIN
            row.TextSize = 13
            row.TextColor3 = Colors.Text
            row.Text = ""
            row.AutoButtonColor = false
            row.ZIndex = 52
            row.Parent = SearchResults
            makeCorner(row, 5)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -20, 0, 18)
            nameLbl.Position = UDim2.new(0, 10, 0, 3)
            nameLbl.BackgroundTransparency = 1
            nameLbl.FontFace = FONT_MAIN
            nameLbl.TextSize = 13
            nameLbl.TextColor3 = Colors.Text
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Text = entry.name
            nameLbl.ZIndex = 53
            nameLbl.Parent = row

            local tabLbl = Instance.new("TextLabel")
            tabLbl.Size = UDim2.new(1, -20, 0, 14)
            tabLbl.Position = UDim2.new(0, 10, 0, 20)
            tabLbl.BackgroundTransparency = 1
            tabLbl.FontFace = FONT_MAIN
            tabLbl.TextSize = 10
            tabLbl.TextColor3 = Colors.TextSecondary
            tabLbl.TextXAlignment = Enum.TextXAlignment.Left
            tabLbl.Text = "in " .. entry.tab
            tabLbl.ZIndex = 53
            tabLbl.Parent = row

            row.MouseEnter:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Hover, BackgroundTransparency = 0.2}):Play()
            end)
            row.MouseLeave:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.4}):Play()
            end)

            row.MouseButton1Click:Connect(function()
                SearchOverlay.Visible = false
                SearchResults.Visible = false
                SearchBox.Text = ""
                searchOpen = false
                clearSearchResults()
                if entry.jump then
                    pcall(entry.jump)
                end
            end)
        end

        if #matches == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, -8, 0, 40)
            empty.BackgroundTransparency = 1
            empty.FontFace = FONT_MAIN
            empty.TextSize = 12
            empty.TextColor3 = Colors.TextSecondary
            empty.TextXAlignment = Enum.TextXAlignment.Center
            empty.TextYAlignment = Enum.TextYAlignment.Center
            empty.Text = "No features found"
            empty.ZIndex = 52
            empty.Parent = SearchResults
        end

        SearchResults.Visible = true
    end

    local function openSearch()
        closeAllDropdowns()
        searchOpen = true
        SearchOverlay.Visible = true
        SearchResults.Visible = false
        SearchBox.Text = ""
        task.defer(function()
            SearchBox:CaptureFocus()
        end)
    end

    local function closeSearch()
        searchOpen = false
        SearchOverlay.Visible = false
        SearchResults.Visible = false
        SearchBox.Text = ""
        clearSearchResults()
        SearchBox:ReleaseFocus()
    end

    SearchButton.MouseButton1Click:Connect(function()
        if searchOpen then closeSearch() else openSearch() end
    end)

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        buildSearchResults(SearchBox.Text)
    end)

    SearchBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            closeSearch()
        end
    end)

    table.insert(cleanupConnections, UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Escape and searchOpen then
            closeSearch()
        end
    end))

    MinimizeButton.MouseButton1Click:Connect(function()
        closeAllDropdowns()
        window.Minimized = not window.Minimized
        MinimizeIcon.Image = window.Minimized and EXPAND_ICON or MIN_ICON

        if window.Minimized then
            tabContainer.Visible = false
            contentArea.Visible = false
            playerCard.Visible = false
            KeybindsPanel.Visible = false
            DragBar.Visible = false
            TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.new(mainFrame.Size.X.Scale, mainFrame.Size.X.Offset, 0, isMobile and 46 or 56)
            }):Play()
        else
            TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = isMobile and UDim2.new(0.6, 0, 0.8, 0) or UDim2.new(0, 700, 0, 450)
            }):Play()
            task.wait(0.35)
            tabContainer.Visible = true
            contentArea.Visible = true
            playerCard.Visible = true
            KeybindsPanel.Visible = true
            DragBar.Visible = true
        end
    end)

    CloseButton.MouseButton1Click:Connect(hideUI)

    table.insert(cleanupConnections, UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.F3 then
            closeAllDropdowns()
            if window.IsVisible then hideUI() else showUI() end
        end
    end))

    function window:CreateTab(name, iconId)
        local TabButton = Instance.new("TextButton")
        TabButton.Size = UDim2.new(1, -20, 0, 40)
        TabButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        TabButton.BackgroundTransparency = 0.35
        TabButton.BorderSizePixel = 0
        TabButton.FontFace = FONT_MAIN
        TabButton.TextSize = 15
        TabButton.TextColor3 = Colors.Text
        TabButton.Text = ""
        TabButton.TextXAlignment = Enum.TextXAlignment.Left
        TabButton.AutoButtonColor = false
        TabButton.ZIndex = 3
        TabButton.LayoutOrder = #self.Tabs + 1
        TabButton.Parent = self.TabContainer
        makeCorner(TabButton, 4)

        local icon = Instance.new("ImageLabel")
        icon.Name = "TabIcon"
        icon.Size = UDim2.fromOffset(22, 22)
        icon.Position = UDim2.new(0, 14, 0.5, -11)
        icon.BackgroundTransparency = 1
        icon.Image = iconId and ("rbxassetid://" .. tostring(iconId)) or ""
        icon.ImageColor3 = Colors.TextSecondary
        icon.ScaleType = Enum.ScaleType.Fit
        icon.ZIndex = 4
        icon.Parent = TabButton

        local txt = Instance.new("TextLabel")
        txt.Name = "TabText"
        txt.Size = UDim2.new(1, -55, 1, 0)
        txt.Position = UDim2.new(0, 55, 0, 0)
        txt.BackgroundTransparency = 1
        txt.FontFace = FONT_MAIN
        txt.TextSize = 15
        txt.TextColor3 = Colors.Text
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.Text = name
        txt.ZIndex = 4
        txt.Parent = TabButton

        register(reg.sidebarBtns, {TabButton, name})
        register(reg.sidebarIcons, {icon, name})
        register(reg.sidebarTexts, {txt, name})

        local TabContent = Instance.new("ScrollingFrame")
        TabContent.Size = UDim2.new(1, -8, 1, -8)
        TabContent.Position = UDim2.new(0, 4, 0, 4)
        TabContent.BackgroundTransparency = 1
        TabContent.BorderSizePixel = 0
        TabContent.ScrollBarThickness = 4
        TabContent.ScrollBarImageColor3 = Colors.Accent
        TabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
        TabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
        TabContent.ClipsDescendants = true
        TabContent.ZIndex = 3
        TabContent.Parent = self.ContentArea
        TabContent.Visible = false
        makeCorner(TabContent, 5)
        register(reg.scrollBars, TabContent)

        local tab = {
            Button = TabButton, Content = TabContent, Elements = {},
            YOffset = 20, Name = name, TextRef = txt, IconRef = icon,
        }

        TabButton.MouseEnter:Connect(function()
            if self.ActiveTab ~= tab then
                TweenService:Create(TabButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
                TweenService:Create(icon, TweenInfo.new(0.15), {ImageColor3 = Colors.Accent}):Play()
                TweenService:Create(txt, TweenInfo.new(0.15), {TextColor3 = Colors.Text}):Play()
            end
        end)
        TabButton.MouseLeave:Connect(function()
            if self.ActiveTab ~= tab then
                TweenService:Create(TabButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 0, 0)}):Play()
                TweenService:Create(icon, TweenInfo.new(0.15), {ImageColor3 = Colors.TextSecondary}):Play()
                TweenService:Create(txt, TweenInfo.new(0.15), {TextColor3 = Colors.Text}):Play()
            end
        end)
        TabButton.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

        table.insert(self.Tabs, tab)
        if #self.Tabs == 1 then self:SelectTab(tab) end
        return tab
    end

    function window:SelectTab(tab)
        closeAllDropdowns()
        if searchOpen then
            searchOpen = false
            SearchOverlay.Visible = false
            SearchResults.Visible = false
            SearchBox.Text = ""
            clearSearchResults()
        end
        if self.ActiveTab then
            self.ActiveTab.Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            self.ActiveTab.Button.BackgroundTransparency = 0.35
            if self.ActiveTab.TextRef then self.ActiveTab.TextRef.TextColor3 = Colors.Text end
            if self.ActiveTab.IconRef then
                TweenService:Create(self.ActiveTab.IconRef, TweenInfo.new(0.15), {ImageColor3 = Colors.TextSecondary}):Play()
            end
            self.ActiveTab.Content.Visible = false
        end
        self.ActiveTab = tab
        activeTabName = tab.Name
        tab.Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        tab.Button.BackgroundTransparency = 0
        if tab.TextRef then tab.TextRef.TextColor3 = Colors.Accent end
        if tab.IconRef then
            TweenService:Create(tab.IconRef, TweenInfo.new(0.15), {ImageColor3 = Colors.Accent}):Play()
        end
        tab.Content.Visible = true
        stopAllTyping()
        task.wait(0.03)
        playTyping(tab)
    end

    local function addElement(tab, el)
        el.Position = UDim2.new(0, 20, 0, tab.YOffset)
        el.Parent = tab.Content
        tab.YOffset += el.Size.Y.Offset + 10
        tab.Content.CanvasSize = UDim2.new(0, 0, 0, tab.YOffset + 30)
        table.insert(tab.Elements, el)
        return el
    end

    window._addElement = addElement

    function window:CreateLabel(tab, text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -40, 0, 25)
        l.BackgroundTransparency = 1
        l.FontFace = FONT_MAIN
        l.TextSize = 16
        l.TextColor3 = Colors.Accent
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = text
        l.ZIndex = 3
        register(reg.accentTexts, l)
        registerTyping(l, text)
        return addElement(tab, l)
    end

    function window:CreateParagraph(tab, text)
        local p = Instance.new("Frame")
        p.Size = UDim2.new(1, -40, 0, 40)
        p.AutomaticSize = Enum.AutomaticSize.Y
        p.BackgroundColor3 = Colors.Panel
        p.BackgroundTransparency = 0.3
        p.BorderSizePixel = 0
        p.ZIndex = 3
        makeCorner(p, 4)
        register(reg.panels, p)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 1, -12)
        l.Position = UDim2.new(0, 10, 0, 6)
        l.BackgroundTransparency = 1
        l.FontFace = FONT_MAIN
        l.TextSize = 12
        l.TextColor3 = Colors.TextSecondary
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Top
        l.TextWrapped = true
        l.Text = text
        l.ZIndex = 4
        l.Parent = p
        register(reg.subtexts, l)
        return addElement(tab, p)
    end

    function window:CreateButton(tab, text, cb, tooltip)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -40, 0, 35)
        b.BackgroundColor3 = Colors.Panel
        b.BackgroundTransparency = 0.3
        b.BorderSizePixel = 0
        b.FontFace = FONT_MAIN
        b.TextSize = 14
        b.TextColor3 = Colors.Text
        b.Text = text
        b.AutoButtonColor = false
        b.ZIndex = 3
        makeCorner(b, 4)
        register(reg.panels, b)
        register(reg.texts, b)
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Hover}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Panel}):Play()
        end)
        b.MouseButton1Click:Connect(function() if cb then cb() end end)
        registerTyping(b, text)
        if tooltip then attachTooltip(b, tooltip) end
        registerSearchEntry(text, tooltip or "", tab.Name, b, function()
            window:SelectTab(tab)
        end)
        NamedControls[text] = { __Name = text, Button = b }
        return addElement(tab, b)
    end

    function window:CreateToggle(tab, text, default, cb, desc, tooltip, style)
        style = style or "pill"
        local isLegacy = (style == "legacy")

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -40, 0, desc and 62 or 50)
        row.BackgroundColor3 = Colors.Panel
        row.BackgroundTransparency = 0.35
        row.BorderSizePixel = 0
        row.ZIndex = 3
        makeCorner(row, 8)
        register(reg.panels, row)

        local lbl = Instance.new("TextLabel")
        if desc then
            lbl.Size = UDim2.new(1, -100, 0, 20)
            lbl.Position = UDim2.new(0, 14, 0, 10)
        else
            lbl.Size = UDim2.new(1, -100, 1, 0)
            lbl.Position = UDim2.new(0, 14, 0, 0)
        end
        lbl.BackgroundTransparency = 1
        lbl.FontFace = FONT_MAIN
        lbl.TextSize = 15
        lbl.TextColor3 = Colors.Text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = text
        lbl.ZIndex = 4
        lbl.Parent = row
        register(reg.texts, lbl)
        registerTyping(lbl, text)

        if desc then
            local sub = Instance.new("TextLabel")
            sub.Size = UDim2.new(1, -100, 0, 16)
            sub.Position = UDim2.new(0, 14, 0, 30)
            sub.BackgroundTransparency = 1
            sub.FontFace = FONT_MAIN
            sub.TextSize = 11
            sub.TextColor3 = Colors.TextSecondary
            sub.TextXAlignment = Enum.TextXAlignment.Left
            sub.Text = desc
            sub.ZIndex = 4
            sub.Parent = row
            register(reg.subtexts, sub)
        end

        if tooltip then
            local infoIcon = Instance.new("TextLabel")
            infoIcon.Name = "HHInfoIcon"
            infoIcon.Size = UDim2.new(0, 16, 0, 16)
            if desc then
                infoIcon.Position = UDim2.new(1, -96, 0, 12)
            else
                infoIcon.Position = UDim2.new(1, -96, 0.5, -8)
            end
            infoIcon.BackgroundTransparency = 1
            infoIcon.FontFace = FONT_MAIN
            infoIcon.TextSize = 13
            infoIcon.Text = "ⓘ"
            infoIcon.TextColor3 = Colors.TextSecondary
            infoIcon.TextXAlignment = Enum.TextXAlignment.Center
            infoIcon.TextYAlignment = Enum.TextYAlignment.Center
            infoIcon.ZIndex = 5
            infoIcon.Parent = row
            register(reg.subtexts, infoIcon)

            attachTooltip(infoIcon, tooltip)

            infoIcon.MouseEnter:Connect(function()
                TweenService:Create(infoIcon, TweenInfo.new(0.15), {TextColor3 = Colors.Accent}):Play()
            end)
            infoIcon.MouseLeave:Connect(function()
                TweenService:Create(infoIcon, TweenInfo.new(0.15), {TextColor3 = Colors.TextSecondary}):Play()
            end)
        end

        local state = default or false
        local pill = Instance.new("TextButton")
        local knob = Instance.new("Frame")
        local pillW, pillH, knobSize, knobOff
        if isLegacy then
            pillW, pillH, knobSize, knobOff = 56, 30, 24, 3
        else
            pillW, pillH, knobSize, knobOff = 36, 20, 16, 2
        end

        pill.Size = UDim2.new(0, pillW, 0, pillH)
        pill.Position = UDim2.new(1, -(pillW + 10), 0.5, -pillH / 2)
        pill.BackgroundColor3 = state and Colors.ToggleOn or Colors.ToggleOff
        pill.Text = ""
        pill.BorderSizePixel = 0
        pill.AutoButtonColor = false
        pill.ZIndex = 4
        pill.Parent = row
        makeCorner(pill, pillH / 2)

        knob.Size = UDim2.fromOffset(knobSize, knobSize)
        knob.Position = state
            and UDim2.new(0, pillW - knobSize - knobOff, 0.5, -knobSize / 2)
            or  UDim2.new(0, knobOff, 0.5, -knobSize / 2)
        knob.BackgroundColor3 = Colors.Text
        knob.BorderSizePixel = 0
        knob.ZIndex = 5
        knob.Parent = pill
        makeCorner(knob, knobSize / 2)

        local function setVisual(v)
            state = v
            TweenService:Create(pill, TweenInfo.new(0.15), {
                BackgroundColor3 = v and Colors.ToggleOn or Colors.ToggleOff
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {
                Position = v
                    and UDim2.new(0, pillW - knobSize - knobOff, 0.5, -knobSize / 2)
                    or  UDim2.new(0, knobOff, 0.5, -knobSize / 2)
            }):Play()
        end

        local lastToggleAt = 0
        local function doToggle()
            local now = os.clock()
            if now - lastToggleAt < 0.1 then return end
            lastToggleAt = now
            setVisual(not state)
            if cb then cb(state) end
        end

        pill.MouseButton1Click:Connect(doToggle)

        row.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                doToggle()
            end
        end)

        addElement(tab, row)
        register(reg.pills, {pill, knob, function() return state end})
        registerSearchEntry(text, desc or tooltip or "", tab.Name, pill, function()
            window:SelectTab(tab)
        end)

        local ctrl = {
            __Name = text,
            SetState = function(v, silent)
                setVisual(v)
                if not silent and cb then cb(v) end
            end,
            GetState = function() return state end,
            Button = pill,
        }
        NamedControls[text] = ctrl
        return ctrl
    end

    function window:CreateSlider(tab, text, min, max, default, cb, tooltip)
        local c = Instance.new("Frame")
        c.Size = UDim2.new(1, -40, 0, 50)
        c.BackgroundTransparency = 1
        c.ZIndex = 3
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 25)
        l.BackgroundTransparency = 1
        l.FontFace = FONT_MAIN
        l.TextSize = 14
        l.TextColor3 = Colors.Text
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = text .. ": " .. tostring(default)
        l.ZIndex = 3
        l.Parent = c
        register(reg.texts, l)
        registerTyping(l, text .. ": " .. tostring(default))
        local sf = Instance.new("Frame")
        sf.Size = UDim2.new(1, 0, 0, 6)
        sf.Position = UDim2.new(0, 0, 1, -15)
        sf.BackgroundColor3 = Colors.ToggleOff
        sf.BorderSizePixel = 0
        sf.ZIndex = 3
        sf.Parent = c
        makeCorner(sf, 3)
        local f = Instance.new("Frame")
        f.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        f.BackgroundColor3 = Colors.Accent
        f.BorderSizePixel = 0
        f.ZIndex = 3
        f.Parent = sf
        makeCorner(f, 3)
        register(reg.sliderFills, f)
        local kSize = 14
        local k = Instance.new("TextButton")
        k.Size = UDim2.fromOffset(kSize, kSize)
        k.Position = UDim2.new((default - min) / (max - min), -kSize / 2, 0.5, -kSize / 2)
        k.BackgroundColor3 = Colors.Text
        k.BorderSizePixel = 0
        k.Text = ""
        k.AutoButtonColor = false
        k.ZIndex = 4
        k.Parent = sf
        makeCorner(k, kSize / 2)
        register(reg.sliderHandles, k)
        local val = default
        local drag = false

        local function apply(v)
            v = math.clamp(v, min, max)
            val = math.floor(v * 100) / 100
            local p = (val - min) / (max - min)
            f.Size = UDim2.new(p, 0, 1, 0)
            k.Position = UDim2.new(p, -kSize / 2, 0.5, -kSize / 2)
            l.Text = text .. ": " .. tostring(val)
        end

        local function updateFromInput(posX)
            local p = math.clamp((posX - sf.AbsolutePosition.X) / sf.AbsoluteSize.X, 0, 1)
            apply(min + (max - min) * p)
            if cb then cb(val) end
        end

        k.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then drag = true end
        end)
        sf.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                drag = true
                updateFromInput(i.Position.X)
            end
        end)
        table.insert(cleanupConnections, UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then drag = false end
        end))
        table.insert(cleanupConnections, UserInputService.InputChanged:Connect(function(i)
            if not drag then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromInput(UserInputService:GetMouseLocation().X)
            elseif i.UserInputType == Enum.UserInputType.Touch then
                updateFromInput(i.Position.X)
            end
        end))
        addElement(tab, c)
        if tooltip then attachTooltip(sf, tooltip) end
        registerSearchEntry(text, tooltip or "", tab.Name, sf, function()
            window:SelectTab(tab)
        end)
        local ctrl = {
            __Name = text,
            SetValue = function(v)
                apply(v)
                if cb then cb(val) end
            end,
            GetValue = function() return val end,
        }
        NamedControls[text] = ctrl
        return ctrl
    end

    function window:CreateDropdown(tab, text, options, default, cb, tooltip)
        local c = Instance.new("Frame")
        c.Size = UDim2.new(1, -40, 0, 60)
        c.BackgroundTransparency = 1
        c.ClipsDescendants = false
        c.ZIndex = 10

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.5, 0, 0, 30)
        l.Position = UDim2.new(0, 0, 0, 15)
        l.BackgroundTransparency = 1
        l.FontFace = FONT_MAIN
        l.TextSize = 14
        l.TextColor3 = Colors.Text
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = text
        l.ZIndex = 10
        l.Parent = c
        register(reg.texts, l)
        registerTyping(l, text)

        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.5, -30, 0, 40)
        b.Position = UDim2.new(0.5, 10, 0, 10)
        b.BackgroundColor3 = Colors.Panel
        b.BackgroundTransparency = 0.3
        b.BorderSizePixel = 0
        b.FontFace = FONT_MAIN
        b.TextSize = 14
        b.TextColor3 = Colors.Text
        b.Text = default or options[1] or ""
        b.AutoButtonColor = false
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.ClipsDescendants = false
        b.ZIndex = 10
        b.Parent = c
        makeCorner(b, 4)

        local bPad = Instance.new("UIPadding")
        bPad.PaddingLeft = UDim.new(0, 10)
        bPad.Parent = b

        local arrowIcon = Instance.new("ImageLabel")
        arrowIcon.Name = "DropdownArrow"
        arrowIcon.Size = UDim2.fromOffset(14, 14)
        arrowIcon.Position = UDim2.new(1, -22, 0.5, -7)
        arrowIcon.BackgroundTransparency = 1
        arrowIcon.Image = DROPDOWN_ARROW_ICON
        arrowIcon.ImageColor3 = Colors.Text
        arrowIcon.Rotation = 0
        arrowIcon.ZIndex = 11
        arrowIcon.Parent = b

        local MAX_HEIGHT = 200
        local ITEM_HEIGHT = 30
        local ITEM_PAD = 4
        local listHeight = math.min(#options * (ITEM_HEIGHT + ITEM_PAD) + 10, MAX_HEIGHT)

        local list = Instance.new("ScrollingFrame")
        list.Name = "HHDropdownList"
        list.AnchorPoint = Vector2.new(0, 0)
        list.Position = UDim2.new(0, 0, 1, 5)
        list.Size = UDim2.new(1, 0, 0, 0)
        list.BackgroundColor3 = Colors.Panel
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.Visible = false
        list.ZIndex = 500
        list.ClipsDescendants = true
        list.ScrollBarThickness = 3
        list.ScrollBarImageColor3 = Colors.Accent
        list.CanvasSize = UDim2.new(0, 0, 0, #options * (ITEM_HEIGHT + ITEM_PAD) + 10)
        list.Parent = b
        makeCorner(list, 4)

        local listPad = Instance.new("UIPadding")
        listPad.PaddingTop = UDim.new(0, 5)
        listPad.PaddingBottom = UDim.new(0, 5)
        listPad.Parent = list

        local sel = default or options[1] or ""
        local opening = false

        local function closeDropdown()
            if not list.Visible or opening then return end
            TweenService:Create(list, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
            }):Play()
            TweenService:Create(arrowIcon, TweenInfo.new(0.2), {Rotation = 0}):Play()
            task.delay(0.18, function()
                if list and list.Parent and list.Size.Y.Offset == 0 then
                    list.Visible = false
                end
            end)
        end
        table.insert(openDropdowns, closeDropdown)

        local optionButtons = {}

        local function styleOptionButton(ob, opt)
            if opt == sel then
                ob.BackgroundColor3 = Colors.Accent
                ob.BackgroundTransparency = 0
                ob.TextColor3 = Colors.Background
            else
                ob.BackgroundColor3 = Colors.Panel
                ob.BackgroundTransparency = 0.2
                ob.TextColor3 = Colors.Text
            end
        end

        local function makeOptionButton(opt, i)
            local ob = Instance.new("TextButton")
            ob.Size = UDim2.new(1, -10, 0, ITEM_HEIGHT)
            ob.Position = UDim2.new(0, 5, 0, 5 + ((i - 1) * (ITEM_HEIGHT + ITEM_PAD)))
            ob.BorderSizePixel = 0
            ob.FontFace = FONT_MAIN
            ob.TextSize = 14
            ob.Text = opt
            ob.AutoButtonColor = false
            ob.ZIndex = 501
            ob.Parent = list
            makeCorner(ob, 3)
            styleOptionButton(ob, opt)

            ob.MouseEnter:Connect(function()
                if ob.Text ~= sel then
                    TweenService:Create(ob, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Hover}):Play()
                end
            end)
            ob.MouseLeave:Connect(function()
                if ob.Text ~= sel then
                    TweenService:Create(ob, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Panel}):Play()
                end
            end)

            ob.MouseButton1Click:Connect(function()
                sel = opt
                b.Text = opt
                for _, ch in ipairs(optionButtons) do
                    styleOptionButton(ch, ch.Text)
                end
                closeDropdown()
                if cb then cb(sel) end
            end)

            return ob
        end

        for i, opt in ipairs(options) do
            table.insert(optionButtons, makeOptionButton(opt, i))
        end

        register(reg.dropdowns, { b, list, optionButtons, function() return sel end, arrowIcon })

        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Hover}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Panel}):Play()
        end)

        b.MouseButton1Click:Connect(function()
            local wasVisible = list.Visible
            closeAllDropdowns()
            if wasVisible then return end
            if not isUIUsable() then return end

            opening = true
            list.Size = UDim2.new(1, 0, 0, 0)
            list.BackgroundTransparency = 1
            list.Visible = true
            TweenService:Create(list, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, listHeight),
                BackgroundTransparency = 0.05,
            }):Play()
            TweenService:Create(arrowIcon, TweenInfo.new(0.25), {Rotation = 180}):Play()
            task.delay(0.25, function()
                opening = false
            end)
        end)

        addElement(tab, c)
        if tooltip then attachTooltip(b, tooltip) end
        registerSearchEntry(text, tooltip or "", tab.Name, b, function()
            window:SelectTab(tab)
        end)

        local ctrl = {
            __Name = text,
            SetValue = function(v)
                if not v then return end
                sel = v
                b.Text = v
                for _, ch in ipairs(optionButtons) do
                    styleOptionButton(ch, ch.Text)
                end
                if cb then cb(sel) end
            end,
            GetValue = function() return sel end,
            SetOptions = function(newOptions)
                if type(newOptions) ~= "table" then return end
                for _, ob in ipairs(optionButtons) do ob:Destroy() end
                optionButtons = {}
                options = newOptions
                listHeight = math.min(#options * (ITEM_HEIGHT + ITEM_PAD) + 10, MAX_HEIGHT)
                list.CanvasSize = UDim2.new(0, 0, 0, #options * (ITEM_HEIGHT + ITEM_PAD) + 10)
                for i, opt in ipairs(options) do
                    table.insert(optionButtons, makeOptionButton(opt, i))
                end
                for _, d in ipairs(reg.dropdowns) do
                    if d[1] == b then d[3] = optionButtons end
                end
                if list.Visible then
                    list.Size = UDim2.new(1, 0, 0, listHeight)
                end
            end,
        }
        ctrl.Refresh = ctrl.SetOptions
        NamedControls[text] = ctrl
        return ctrl
    end

    if isMobile then
        toggleBtn = Instance.new("ImageButton")
        toggleBtn.Name = "HappyHubToggle"
        toggleBtn.Size = UDim2.fromOffset(44, 44)
        toggleBtn.Position = UDim2.new(1, -58, 0, 58)
        toggleBtn.BackgroundColor3 = Colors.Background
        toggleBtn.BackgroundTransparency = 0.15
        toggleBtn.Image = MAIN_ICON
        toggleBtn.ImageColor3 = Colors.Accent
        toggleBtn.ScaleType = Enum.ScaleType.Fit
        toggleBtn.BorderSizePixel = 0
        toggleBtn.AutoButtonColor = false
        toggleBtn.ZIndex = 3
        toggleBtn.Parent = screenGui
        makeCorner(toggleBtn, 6)
        register(reg.panels, toggleBtn)
        register(reg.accentIcons, toggleBtn)

        local tDrag, tStart, tStartPos, tInput, tMoved = false, nil, nil, nil, false

        toggleBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                if tDrag then return end
                tDrag = true
                tInput = i
                tStart = i.Position
                tStartPos = toggleBtn.Position
                tMoved = false
            end
        end)
        table.insert(cleanupConnections, UserInputService.InputChanged:Connect(function(i)
            if not tDrag then return end
            if i ~= tInput then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch then
                local d = i.Position - tStart
                if math.abs(d.X) > 3 or math.abs(d.Y) > 3 then tMoved = true end
                toggleBtn.Position = UDim2.new(
                    tStartPos.X.Scale, tStartPos.X.Offset + d.X,
                    tStartPos.Y.Scale, tStartPos.Y.Offset + d.Y
                )
            end
        end))
        table.insert(cleanupConnections, UserInputService.InputEnded:Connect(function(i)
            if i == tInput then
                tDrag = false
                tInput = nil
            end
        end))
        toggleBtn.MouseButton1Click:Connect(function()
            if tMoved then tMoved = false; return end
            if window.IsVisible then hideUI() else showUI() end
        end)
    end

    currentWindow = window
    applyTheme()
    return window
end

_G.HappyHubAPI = API
return API
