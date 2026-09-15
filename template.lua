local Library = {}
Library.__index = Library

local UserInputService      = game:GetService("UserInputService")
local TweenService          = game:GetService("TweenService")
local RunService            = game:GetService("RunService")
local Players               = game:GetService("Players")
local HttpService           = game:GetService("HttpService")
local SoundService          = game:GetService("SoundService")
local LocalPlayer           = Players.LocalPlayer
local Camera                = workspace.CurrentCamera

local hasFileSystem = (writefile and readfile and isfile and isfolder and makefolder)
if hasFileSystem then
    pcall(function()
        if not isfolder("HappyHub") then makefolder("HappyHub") end
        if not isfolder("HappyHub/Configs") then makefolder("HappyHub/Configs") end
    end)
end

local MAIN_ICON  = "rbxassetid://104348663064077"
local CLOSE_ICON = "rbxassetid://130629964514885"
local MIN_ICON   = "rbxassetid://115558082558028"
local NOTIF_ICON = "rbxassetid://111849828445660"
local CFG_ICON   = "rbxassetid://111467744253591"
local TYPING_SOUND_ID = "rbxassetid://140036379967302"
local NOTIF_SOUND_ID  = "rbxassetid://97455084935031"

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local PANEL_SIZE_OPEN    = isMobile and UDim2.new(0.6, 0, 0.8, 0) or UDim2.new(0, 700, 0, 450)
local PANEL_SIZE_MIN     = isMobile and UDim2.new(0.6, 0, 0, 56)  or UDim2.new(0, 700, 0, 56)
local PANEL_POSITION     = UDim2.new(0.5, 0, 0.5, 0)
local PANEL_ANCHOR       = Vector2.new(0.5, 0.5)
local PANEL_TRANSPARENCY = 0.15

local SIDEBAR_RATIO = 0.32
local SIDEBAR_FIXED = 200
local SIDEBAR_PAD   = isMobile and 6 or 8

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

local UIControls = {}
local openDropdowns = {}
local typingTokens = {}
local notifOrder = 0
local screenGui, mainFrame, tabContainer, contentArea, playerCard, keybindsPanel, dragBar
local toggleBtn = nil
local currentWindow = nil
local configsTabRef = nil

local function register(list, obj)
    table.insert(list, obj)
    return obj
end

local function registerControl(settingsTable, key, control)
    table.insert(UIControls, { table = settingsTable, key = key, control = control })
end

local function makeCorner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p
    return c
end

local function closeAllDropdowns()
    for _, fn in ipairs(openDropdowns) do pcall(fn) end
    openDropdowns = {}
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
        local pill, getState = d[1], d[2]
        if pill and pill.Parent then pill.BackgroundColor3 = getState() and th.ToggleOn or th.ToggleOff end
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
        local b, list, btns, getSel = d[1], d[2], d[3], d[4]
        if b and b.Parent then
            b.BackgroundColor3 = th.Panel
            b.TextColor3 = th.Text
        end
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
end

local function Notify(text, duration)
    if suppressNotify then return end
    duration = duration or 3
    if not screenGui or not screenGui.Parent then return end
    notifOrder = notifOrder + 1
    pcall(function() notifSound:Play() end)

    local frame = Instance.new("Frame")
    frame.Name = "Notification"
    frame.Size = UDim2.new(0, 0, 0, 56)
    frame.Position = UDim2.new(1, 20, 0, 12 + ((notifOrder - 1) * 64))
    frame.BackgroundColor3 = Colors.Panel
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    makeCorner(frame, 8)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, -16)
    accent.Position = UDim2.new(0, 0, 0, 8)
    accent.BackgroundColor3 = Colors.Accent
    accent.BorderSizePixel = 0
    accent.Parent = frame
    makeCorner(accent, 2)

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.fromOffset(30, 30)
    icon.Position = UDim2.new(0, 14, 0.5, -15)
    icon.BackgroundTransparency = 1
    icon.Image = NOTIF_ICON
    icon.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -70, 0, 20)
    title.Position = UDim2.new(0, 54, 0, 10)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextColor3 = Colors.Accent
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Happy Hub"
    title.Parent = frame

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, -70, 0, 18)
    msg.Position = UDim2.new(0, 54, 0, 28)
    msg.BackgroundTransparency = 1
    msg.Font = Enum.Font.GothamMedium
    msg.TextSize = 12
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

    icon.ImageTransparency = 1
    title.TextTransparency = 1
    msg.TextTransparency = 1
    accent.BackgroundTransparency = 1
    barBg.BackgroundTransparency = 1
    bar.BackgroundTransparency = 1

    local targetW = math.clamp(#tostring(text) * 8 + 90, 200, 420)
    TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, targetW, 0, 56),
        Position = UDim2.new(1, -targetW - 20, 0, 12 + ((notifOrder - 1) * 64)),
        BackgroundTransparency = 0.1
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
            Position = UDim2.new(1, 20, 0, frame.Position.Y.Offset),
            BackgroundTransparency = 1
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

local function syncUIControls()
    suppressNotify = true
    for _, entry in ipairs(UIControls) do
        local val = entry.table[entry.key]
        if val ~= nil and entry.control then
            if entry.control.SetState then
                entry.control.SetState(val)
            elseif entry.control.SetValue then
                entry.control.SetValue(val)
            end
        end
    end
    suppressNotify = false
end

function Library:GetUIControls() return UIControls end
function Library:SyncUIControls() syncUIControls() end
function Library:RegisterControl(t, key, ctrl) registerControl(t, key, ctrl) end
function Library:GetScreenGui() return screenGui end
function Library:GetWindow() return currentWindow end
function Library:GetConfigsTab() return configsTabRef end
function Library:IsMobile() return isMobile end
function Library:SuppressNotify() suppressNotify = true end
function Library:UnsuppressNotify() suppressNotify = false end

function Library:SetTheme(name)
    if not THEMES[name] then return end
    currentThemeName = name
    for k, v in pairs(THEMES[name]) do Colors[k] = v end
    applyTheme()
    if hasFileSystem then
        pcall(function() writefile("HappyHub/theme.txt", currentThemeName) end)
    end
end
function Library:GetTheme() return currentThemeName end
function Library:GetThemes()
    local list = {}
    for k in pairs(THEMES) do list[#list+1] = k end
    return list
end
function Library:Notify(text, duration) Notify(text, duration) end

function Library:CreateWindow(title, subtitle)
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HappyHub"
    screenGui.Parent = (gethui and pcall(gethui) and gethui()) or game:GetService("CoreGui")
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 100
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = true

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = PANEL_SIZE_OPEN
    mainFrame.Position = PANEL_POSITION
    mainFrame.AnchorPoint = PANEL_ANCHOR
    mainFrame.BackgroundColor3 = Colors.Background
    mainFrame.BackgroundTransparency = PANEL_TRANSPARENCY
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = true
    mainFrame.Active = true
    mainFrame.ClipsDescendants = true
    mainFrame.ZIndex = 1
    mainFrame.Parent = screenGui
    makeCorner(mainFrame, 12)
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
    makeCorner(Shadow, 12)

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 56)
    TopBar.Position = UDim2.new(0, 0, 0, 0)
    TopBar.BackgroundColor3 = Colors.Panel
    TopBar.BackgroundTransparency = 0.1
    TopBar.BorderSizePixel = 0
    TopBar.Active = true
    TopBar.ZIndex = 2
    TopBar.Parent = mainFrame
    makeCorner(TopBar, 12)
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
    TopIcon.Position = UDim2.new(0, isMobile and 12 or 16, 0.5, isMobile and -13 or -16)
    TopIcon.BackgroundTransparency = 1
    TopIcon.Image = MAIN_ICON
    TopIcon.ImageColor3 = Colors.Accent
    TopIcon.ZIndex = 4
    TopIcon.Parent = TopBar
    makeCorner(TopIcon, 8)
    register(reg.accentIcons, TopIcon)

    local titleOffsetX = isMobile and 46 or 58
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Size = UDim2.new(1, -titleOffsetX - 100, 0, 18)
    TitleLabel.Position = UDim2.new(0, titleOffsetX, 0, 10)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = isMobile and 14 or 16
    TitleLabel.TextColor3 = Colors.Text
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TitleLabel.Text = title or "Happy Hub"
    TitleLabel.ZIndex = 4
    TitleLabel.Parent = TopBar
    register(reg.texts, TitleLabel)

    local SubTitleLabel = Instance.new("TextLabel")
    SubTitleLabel.Name = "SubTitle"
    SubTitleLabel.Size = UDim2.new(1, -titleOffsetX - 100, 0, 14)
    SubTitleLabel.Position = UDim2.new(0, titleOffsetX, 0, 30)
    SubTitleLabel.BackgroundTransparency = 1
    SubTitleLabel.Font = Enum.Font.Gotham
    SubTitleLabel.TextSize = isMobile and 9 or 10
    SubTitleLabel.TextColor3 = Colors.TextSecondary
    SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubTitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    SubTitleLabel.Text = subtitle or "Keyless"
    SubTitleLabel.ZIndex = 4
    SubTitleLabel.Parent = TopBar
    register(reg.subtexts, SubTitleLabel)

    local btnSize = isMobile and 28 or 32
    local MinimizeButton = Instance.new("TextButton")
    MinimizeButton.Size = UDim2.fromOffset(btnSize, btnSize)
    MinimizeButton.Position = UDim2.new(1, -(btnSize * 2 + 12), 0.5, -btnSize/2)
    MinimizeButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.Text = ""
    MinimizeButton.AutoButtonColor = false
    MinimizeButton.ZIndex = 4
    MinimizeButton.Parent = TopBar
    makeCorner(MinimizeButton, 8)
    register(reg.panels, MinimizeButton)

    local MinimizeIcon = Instance.new("ImageLabel")
    MinimizeIcon.Size = UDim2.fromOffset(isMobile and 14 or 16, isMobile and 14 or 16)
    MinimizeIcon.Position = UDim2.new(0.5, isMobile and -7 or -8, 0.5, isMobile and -7 or -8)
    MinimizeIcon.BackgroundTransparency = 1
    MinimizeIcon.Image = MIN_ICON
    MinimizeIcon.ImageColor3 = Colors.TextSecondary
    MinimizeIcon.ZIndex = 5
    MinimizeIcon.Parent = MinimizeButton

    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.fromOffset(btnSize, btnSize)
    CloseButton.Position = UDim2.new(1, -(btnSize + 8), 0.5, -btnSize/2)
    CloseButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    CloseButton.BorderSizePixel = 0
    CloseButton.Text = ""
    CloseButton.AutoButtonColor = false
    CloseButton.ZIndex = 4
    CloseButton.Parent = TopBar
    makeCorner(CloseButton, 8)
    register(reg.panels, CloseButton)

    local CloseIcon = Instance.new("ImageLabel")
    CloseIcon.Size = UDim2.fromOffset(isMobile and 14 or 16, isMobile and 14 or 16)
    CloseIcon.Position = UDim2.new(0.5, isMobile and -7 or -8, 0.5, isMobile and -7 or -8)
    CloseIcon.BackgroundTransparency = 1
    CloseIcon.Image = CLOSE_ICON
    CloseIcon.ImageColor3 = Colors.TextSecondary
    CloseIcon.ZIndex = 5
    CloseIcon.Parent = CloseButton

    local sidebarSize
    if isMobile then
        sidebarSize = UDim2.new(SIDEBAR_RATIO, 0, 1, -145)
    else
        sidebarSize = UDim2.new(0, SIDEBAR_FIXED, 1, -145)
    end
    tabContainer = Instance.new("ScrollingFrame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = sidebarSize
    tabContainer.Position = UDim2.new(0, SIDEBAR_PAD, 0, 61)
    tabContainer.BackgroundColor3 = Colors.Panel
    tabContainer.BackgroundTransparency = 0.2
    tabContainer.BorderSizePixel = 0
    tabContainer.ClipsDescendants = true
    tabContainer.ZIndex = 2
    tabContainer.ScrollBarThickness = isMobile and 5 or 3
    tabContainer.ScrollBarImageColor3 = Colors.Accent
    tabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabContainer.ScrollingDirection = Enum.ScrollingDirection.Y
    tabContainer.Parent = mainFrame
    makeCorner(tabContainer, 10)
    register(reg.panels, tabContainer)
    register(reg.scrollBars, tabContainer)
    reg.tabContainer = tabContainer

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, isMobile and 6 or 8)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabContainer

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, isMobile and 8 or 10)
    tabPad.PaddingBottom = UDim.new(0, isMobile and 8 or 10)
    tabPad.PaddingLeft = UDim.new(0, isMobile and 6 or 10)
    tabPad.PaddingRight = UDim.new(0, isMobile and 6 or 10)
    tabPad.Parent = tabContainer

    local contentSize, contentPos
    if isMobile then
        contentSize = UDim2.new(1 - SIDEBAR_RATIO, -SIDEBAR_PAD * 2, 1, -73)
        contentPos  = UDim2.new(SIDEBAR_RATIO, SIDEBAR_PAD, 0, 61)
    else
        contentSize = UDim2.new(1, -224, 1, -73)
        contentPos  = UDim2.new(0, 216, 0, 61)
    end
    contentArea = Instance.new("Frame")
    contentArea.Size = contentSize
    contentArea.Position = contentPos
    contentArea.BackgroundColor3 = Colors.Background
    contentArea.BackgroundTransparency = 0.4
    contentArea.BorderSizePixel = 0
    contentArea.ClipsDescendants = true
    contentArea.ZIndex = 2
    contentArea.Parent = mainFrame
    makeCorner(contentArea, 10)
    register(reg.panels, contentArea)
    reg.contentArea = contentArea

    local cardSize
    if isMobile then
        cardSize = UDim2.new(SIDEBAR_RATIO, 0, 0, 60)
    else
        cardSize = UDim2.new(0, SIDEBAR_FIXED, 0, 64)
    end
    playerCard = Instance.new("Frame")
    playerCard.Name = "PlayerCard"
    playerCard.Size = cardSize
    playerCard.Position = UDim2.new(0, SIDEBAR_PAD, 1, -68)
    playerCard.BackgroundColor3 = Colors.Panel
    playerCard.BackgroundTransparency = 0.15
    playerCard.BorderSizePixel = 0
    playerCard.ZIndex = 5
    playerCard.Parent = mainFrame
    makeCorner(playerCard, 10)
    register(reg.panels, playerCard)
    reg.playerCard = playerCard

    local pfpSize = isMobile and 34 or 44
    local pfpFrame = Instance.new("Frame")
    pfpFrame.Size = UDim2.fromOffset(pfpSize, pfpSize)
    pfpFrame.Position = UDim2.new(0, isMobile and 6 or 10, 0.5, -pfpSize/2)
    pfpFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    pfpFrame.BorderSizePixel = 0
    pfpFrame.Parent = playerCard
    makeCorner(pfpFrame, pfpSize/2)

    local pfp = Instance.new("ImageLabel")
    pfp.Size = UDim2.new(1, 0, 1, 0)
    pfp.BackgroundTransparency = 1
    pfp.BorderSizePixel = 0
    pfp.ScaleType = Enum.ScaleType.Crop
    pfp.Parent = pfpFrame
    makeCorner(pfp, pfpSize/2)

    local onlineDot = Instance.new("Frame")
    onlineDot.Size = UDim2.fromOffset(10, 10)
    onlineDot.Position = UDim2.new(1, -10, 1, -10)
    onlineDot.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    onlineDot.BorderSizePixel = 0
    onlineDot.ZIndex = 6
    onlineDot.Parent = pfpFrame
    makeCorner(onlineDot, 5)

    local nameOffsetX = pfpSize + (isMobile and 12 or 18)
    local pfpName = Instance.new("TextLabel")
    pfpName.Size = UDim2.new(1, -nameOffsetX - 6, 0, 18)
    pfpName.Position = UDim2.new(0, nameOffsetX, 0, isMobile and 10 or 14)
    pfpName.BackgroundTransparency = 1
    pfpName.Font = Enum.Font.GothamBold
    pfpName.TextSize = isMobile and 11 or 13
    pfpName.TextColor3 = Colors.Text
    pfpName.TextXAlignment = Enum.TextXAlignment.Left
    pfpName.TextTruncate = Enum.TextTruncate.AtEnd
    pfpName.Text = LocalPlayer.DisplayName
    pfpName.Parent = playerCard
    register(reg.texts, pfpName)

    local pfpUser = Instance.new("TextLabel")
    pfpUser.Size = UDim2.new(1, -nameOffsetX - 6, 0, 14)
    pfpUser.Position = UDim2.new(0, nameOffsetX, 0, isMobile and 30 or 32)
    pfpUser.BackgroundTransparency = 1
    pfpUser.Font = Enum.Font.Gotham
    pfpUser.TextSize = isMobile and 9 or 11
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

    keybindsPanel = Instance.new("Frame")
    keybindsPanel.Name = "KeybindsPanel"
    keybindsPanel.Size = UDim2.new(0, 140, 0, 128)
    keybindsPanel.Position = UDim2.new(1, 10, 0, 70)
    keybindsPanel.BackgroundColor3 = Colors.Panel
    keybindsPanel.BackgroundTransparency = 0.15
    keybindsPanel.BorderSizePixel = 0
    keybindsPanel.ZIndex = 5
    keybindsPanel.Visible = not isMobile
    keybindsPanel.Parent = mainFrame
    makeCorner(keybindsPanel, 10)
    register(reg.panels, keybindsPanel)

    local KeybindsTitle = Instance.new("TextLabel")
    KeybindsTitle.Size = UDim2.new(1, -16, 0, 20)
    KeybindsTitle.Position = UDim2.new(0, 8, 0, 6)
    KeybindsTitle.BackgroundTransparency = 1
    KeybindsTitle.Font = Enum.Font.GothamBold
    KeybindsTitle.TextSize = 11
    KeybindsTitle.TextColor3 = Colors.Accent
    KeybindsTitle.TextXAlignment = Enum.TextXAlignment.Left
    KeybindsTitle.Text = "LEFT KEYBINDS"
    KeybindsTitle.ZIndex = 6
    KeybindsTitle.Parent = keybindsPanel
    register(reg.accentTexts, KeybindsTitle)

    local function makeKeybindRow(parent, key, label, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -16, 0, 22)
        row.Position = UDim2.new(0, 8, 0, 28 + ((order - 1) * 24))
        row.BackgroundTransparency = 1
        row.ZIndex = 6
        row.Parent = parent
        local keyBadge = Instance.new("TextLabel")
        keyBadge.Size = UDim2.new(0, 22, 0, 18)
        keyBadge.Position = UDim2.new(0, 0, 0.5, -9)
        keyBadge.BackgroundColor3 = Colors.Accent
        keyBadge.Text = key
        keyBadge.TextColor3 = Colors.Background
        keyBadge.Font = Enum.Font.GothamBold
        keyBadge.TextSize = 11
        keyBadge.BorderSizePixel = 0
        keyBadge.ZIndex = 6
        keyBadge.Parent = row
        makeCorner(keyBadge, 4)
        register(reg.accentBgs, keyBadge)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -28, 1, 0)
        lbl.Position = UDim2.new(0, 28, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 11
        lbl.TextColor3 = Colors.TextSecondary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label
        lbl.ZIndex = 6
        lbl.Parent = row
        register(reg.subtexts, lbl)
    end

    makeKeybindRow(keybindsPanel, "T", "Toggle Aimbot", 1)
    makeKeybindRow(keybindsPanel, "O", "Toggle ESP", 2)
    makeKeybindRow(keybindsPanel, "F3", "Toggle UI", 3)

    dragBar = Instance.new("Frame")
    dragBar.Name = "DragBar"
    dragBar.Size = UDim2.new(0.12, 0, 0, 4)
    dragBar.AnchorPoint = Vector2.new(0.5, 1)
    dragBar.Position = UDim2.new(0.5, 0, 1, -6)
    dragBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dragBar.BackgroundTransparency = 0.3
    dragBar.BorderSizePixel = 0
    dragBar.Active = true
    dragBar.ZIndex = 4
    dragBar.Parent = mainFrame
    makeCorner(dragBar, 2)

    local window = {
        ScreenGui = screenGui, MainFrame = mainFrame, TabContainer = tabContainer,
        ContentArea = contentArea, PlayerCard = playerCard, Tabs = {}, ActiveTab = nil,
        IsVisible = true, Minimized = false, ConfigsTab = nil, FirstSelected = false,
        _mobileButtons = {},
    }

    local dragging, dragStart, startPos = false, nil, nil

    local function beginDrag(input)
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
    local function updateDrag(input)
        if not dragging then return end
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    local function endDrag() dragging = false end

    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)
    dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(input)
        end
    end)
    dragBar.MouseEnter:Connect(function()
        TweenService:Create(dragBar, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end)
    dragBar.MouseLeave:Connect(function()
        TweenService:Create(dragBar, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play()
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            updateDrag(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            endDrag()
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

    CloseButton.MouseEnter:Connect(function()
        TweenService:Create(CloseButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 0, 0)}):Play()
        TweenService:Create(CloseIcon, TweenInfo.new(0.15), {ImageColor3 = Color3.fromRGB(255, 80, 80)}):Play()
    end)
    CloseButton.MouseLeave:Connect(function()
        TweenService:Create(CloseButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(15, 15, 15)}):Play()
        TweenService:Create(CloseIcon, TweenInfo.new(0.15), {ImageColor3 = Colors.TextSecondary}):Play()
    end)
    CloseButton.MouseButton1Click:Connect(hideUI)

    MinimizeButton.MouseEnter:Connect(function()
        TweenService:Create(MinimizeButton, TweenInfo.new(0.15), {BackgroundColor3 = Colors.Hover}):Play()
    end)
    MinimizeButton.MouseLeave:Connect(function()
        TweenService:Create(MinimizeButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(15, 15, 15)}):Play()
    end)

    MinimizeButton.MouseButton1Click:Connect(function()
        closeAllDropdowns()
        window.Minimized = not window.Minimized

        if window.Minimized then
            tabContainer.Visible = false
            contentArea.Visible = false
            playerCard.Visible = false
            keybindsPanel.Visible = false
            dragBar.Visible = false
            TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = PANEL_SIZE_MIN
            }):Play()
        else
            local vp = workspace.CurrentCamera.ViewportSize
            local newW = isMobile and (vp.X * 0.6) or 700
            local newH = isMobile and (vp.Y * 0.8) or 450
            local maxOffX = math.max(0, (vp.X - newW) / 2)
            local maxOffY = math.max(0, (vp.Y - newH) / 2)
            local offX = math.clamp(mainFrame.Position.X.Offset, -maxOffX, maxOffX)
            local offY = math.clamp(mainFrame.Position.Y.Offset, -maxOffY, maxOffY)
            mainFrame.Position = UDim2.new(0.5, offX, 0.5, offY)

            tabContainer.Visible = true
            contentArea.Visible = true
            playerCard.Visible = true
            keybindsPanel.Visible = not isMobile
            dragBar.Visible = true

            TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = PANEL_SIZE_OPEN
            }):Play()
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.F3 then
            closeAllDropdowns()
            if window.IsVisible then hideUI() else showUI() end
        end
    end)

    function window:CreateTab(name, iconId, isConfigs)
        if name == "Configs" and self.ConfigsTab then
            return self.ConfigsTab
        end

        local TabButton = Instance.new("TextButton")
        TabButton.Size = UDim2.new(1, 0, 0, isMobile and 36 or 40)
        TabButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        TabButton.BackgroundTransparency = 0.35
        TabButton.BorderSizePixel = 0
        TabButton.Font = Enum.Font.GothamSemibold
        TabButton.TextSize = isMobile and 11 or 15
        TabButton.TextColor3 = Colors.Text
        TabButton.Text = ""
        TabButton.TextXAlignment = Enum.TextXAlignment.Left
        TabButton.AutoButtonColor = false
        TabButton.ZIndex = 3
        TabButton.Parent = self.TabContainer
        makeCorner(TabButton, 8)

        local iconSize = isMobile and 16 or 22
        local icon = Instance.new("ImageLabel")
        icon.Name = "TabIcon"
        icon.Size = UDim2.fromOffset(iconSize, iconSize)
        icon.Position = UDim2.new(0, isMobile and 8 or 14, 0.5, -iconSize/2)
        icon.BackgroundTransparency = 1
        icon.Image = iconId and ("rbxassetid://" .. tostring(iconId)) or ""
        icon.ImageColor3 = Colors.TextSecondary
        icon.ScaleType = Enum.ScaleType.Fit
        icon.ZIndex = 4
        icon.Parent = TabButton

        local txt = Instance.new("TextLabel")
        txt.Name = "TabText"
        txt.Size = UDim2.new(1, isMobile and -30 or -55, 1, 0)
        txt.Position = UDim2.new(0, isMobile and 30 or 55, 0, 0)
        txt.BackgroundTransparency = 1
        txt.Font = Enum.Font.GothamSemibold
        txt.TextSize = isMobile and 11 or 15
        txt.TextColor3 = Colors.Text
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.Text = name
        txt.TextTruncate = Enum.TextTruncate.AtEnd
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
        makeCorner(TabContent, 8)
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

        if isConfigs or name == "Configs" then
            TabButton.LayoutOrder = 999999
            self.ConfigsTab = tab
            configsTabRef = tab
        else
            TabButton.LayoutOrder = #self.Tabs + 1
            table.insert(self.Tabs, tab)
            if not self.FirstSelected then
                self.FirstSelected = true
                task.defer(function() self:SelectTab(tab) end)
            end
        end

        return tab
    end

    function window:SelectTab(tab)
        closeAllDropdowns()
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
        _G.__activeTabName = tab.Name
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
        el.Position = UDim2.new(0, isMobile and 10 or 20, 0, tab.YOffset)
        el.Parent = tab.Content
        tab.YOffset += el.Size.Y.Offset + (isMobile and 8 or 10)
        tab.Content.CanvasSize = UDim2.new(0, 0, 0, tab.YOffset + 30)
        table.insert(tab.Elements, el)
        return el
    end

    window._addElement = addElement
    window._register = register
    window._reg = reg

    function window:CreateLabel(tab, text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, isMobile and -20 or -40, 0, isMobile and 22 or 25)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = isMobile and 14 or 16
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
        p.Size = UDim2.new(1, isMobile and -20 or -40, 0, 30)
        p.AutomaticSize = Enum.AutomaticSize.Y
        p.BackgroundColor3 = Colors.Panel
        p.BackgroundTransparency = 0.3
        p.BorderSizePixel = 0
        p.ZIndex = 3
        makeCorner(p, 8)
        register(reg.panels, p)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 0)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.Position = UDim2.new(0, 10, 0, 6)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = isMobile and 11 or 12
        l.TextColor3 = Colors.TextSecondary
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Top
        l.TextWrapped = true
        l.Text = text
        l.ZIndex = 4
        l.Parent = p
        register(reg.subtexts, l)
        local pad = Instance.new("UIPadding")
        pad.PaddingBottom = UDim.new(0, 6)
        pad.Parent = p
        return addElement(tab, p)
    end

    function window:CreateButton(tab, text, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, isMobile and -20 or -40, 0, isMobile and 40 or 35)
        b.BackgroundColor3 = Colors.Panel
        b.BackgroundTransparency = 0.3
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = isMobile and 13 or 14
        b.TextColor3 = Colors.Text
        b.Text = text
        b.AutoButtonColor = false
        b.ZIndex = 3
        makeCorner(b, 8)
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
        return addElement(tab, b)
    end

    function window:CreateToggle(tab, text, default, cb)
        local c = Instance.new("Frame")
        c.Size = UDim2.new(1, isMobile and -20 or -40, 0, isMobile and 40 or 35)
        c.BackgroundTransparency = 1
        c.ZIndex = 3
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.7, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamSemibold
        l.TextSize = isMobile and 13 or 14
        l.TextColor3 = Colors.Text
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = text
        l.ZIndex = 3
        l.Parent = c
        register(reg.texts, l)
        registerTyping(l, text)
        local tSize = isMobile and 36 or 30
        local t = Instance.new("TextButton")
        t.Size = UDim2.fromOffset(tSize, tSize)
        t.Position = UDim2.new(1, -tSize, 0.5, -tSize/2)
        t.BackgroundColor3 = default and Colors.ToggleOn or Colors.ToggleOff
        t.BorderSizePixel = 0
        t.Text = ""
        t.AutoButtonColor = false
        t.ZIndex = 3
        t.Parent = c
        makeCorner(t, 8)
        local state = default or false
        local function setVisual(v)
            state = v
            t.BackgroundColor3 = v and Colors.ToggleOn or Colors.ToggleOff
        end
        t.MouseButton1Click:Connect(function()
            setVisual(not state)
            if cb then cb(state) end
        end)
        addElement(tab, c)
        register(reg.pills, {t, function() return state end})
        return {
            SetState = function(v, silent)
                setVisual(v)
                if not silent and cb then cb(v) end
            end,
            GetState = function() return state end,
        }
    end

    function window:CreateSlider(tab, text, min, max, default, cb)
        local c = Instance.new("Frame")
        c.Size = UDim2.new(1, isMobile and -20 or -40, 0, isMobile and 56 or 50)
        c.BackgroundTransparency = 1
        c.ZIndex = 3
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 25)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamSemibold
        l.TextSize = isMobile and 13 or 14
        l.TextColor3 = Colors.Text
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = text .. ": " .. tostring(default)
        l.ZIndex = 3
        l.Parent = c
        register(reg.texts, l)
        registerTyping(l, text .. ": " .. tostring(default))
        local trackH = isMobile and 8 or 6
        local sf = Instance.new("Frame")
        sf.Size = UDim2.new(1, 0, 0, trackH)
        sf.Position = UDim2.new(0, 0, 1, isMobile and -22 or -15)
        sf.BackgroundColor3 = Colors.ToggleOff
        sf.BorderSizePixel = 0
        sf.ZIndex = 3
        sf.Parent = c
        makeCorner(sf, trackH/2)
        local f = Instance.new("Frame")
        f.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
        f.BackgroundColor3 = Colors.Accent
        f.BorderSizePixel = 0
        f.ZIndex = 3
        f.Parent = sf
        makeCorner(f, trackH/2)
        register(reg.sliderFills, f)
        local kSize = isMobile and 22 or 14
        local k = Instance.new("TextButton")
        k.Size = UDim2.fromOffset(kSize, kSize)
        k.Position = UDim2.new((default-min)/(max-min), -kSize/2, 0.5, -kSize/2)
        k.BackgroundColor3 = Colors.Text
        k.BorderSizePixel = 0
        k.Text = ""
        k.AutoButtonColor = false
        k.ZIndex = 4
        k.Parent = sf
        makeCorner(k, kSize/2)
        register(reg.sliderHandles, k)
        local val = default
        local drag = false
        local function apply(v)
            v = math.clamp(v, min, max)
            val = math.floor(v * 100) / 100
            local p = (val - min) / (max - min)
            f.Size = UDim2.new(p, 0, 1, 0)
            k.Position = UDim2.new(p, -kSize/2, 0.5, -kSize/2)
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
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then drag = false end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not drag then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromInput(UserInputService:GetMouseLocation().X)
            elseif i.UserInputType == Enum.UserInputType.Touch then
                updateFromInput(i.Position.X)
            end
        end)
        addElement(tab, c)
        return {
            SetValue = function(v)
                apply(v)
                if cb then cb(val) end
            end,
            GetValue = function() return val end,
        }
    end

    function window:CreateDropdown(tab, text, options, default, cb)
        local c = Instance.new("Frame")
        c.Size = UDim2.new(1, isMobile and -20 or -40, 0, isMobile and 54 or 60)
        c.BackgroundTransparency = 1
        c.ClipsDescendants = false
        c.ZIndex = 10
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.5, 0, 0, isMobile and 26 or 30)
        l.Position = UDim2.new(0, 0, 0.5, isMobile and -13 or -15)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamSemibold
        l.TextSize = isMobile and 13 or 14
        l.TextColor3 = Colors.Text
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = text
        l.ZIndex = 10
        l.Parent = c
        register(reg.texts, l)
        registerTyping(l, text)
        local btnH = isMobile and 36 or 40
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.5, -10, 0, btnH)
        b.Position = UDim2.new(0.5, 10, 0.5, -btnH/2)
        b.BackgroundColor3 = Colors.Panel
        b.BackgroundTransparency = 0.3
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = isMobile and 12 or 14
        b.TextColor3 = Colors.Text
        b.Text = default or options[1] or ""
        b.AutoButtonColor = false
        b.ZIndex = 10
        b.TextTruncate = Enum.TextTruncate.AtEnd
        b.Parent = c
        makeCorner(b, 8)
        local itemH = isMobile and 32 or 36
        local list = Instance.new("Frame")
        list.Size = UDim2.new(0.5, -10, 0, (#options * itemH) + 10)
        list.Position = UDim2.new(0.5, 10, 1, 5)
        list.BackgroundColor3 = Colors.Panel
        list.BackgroundTransparency = 0.1
        list.BorderSizePixel = 0
        list.Visible = false
        list.ZIndex = 50
        list.ClipsDescendants = false
        list.Parent = c
        makeCorner(list, 8)
        local listPad = Instance.new("UIPadding")
        listPad.PaddingTop = UDim.new(0, 5)
        listPad.PaddingBottom = UDim.new(0, 5)
        listPad.Parent = list
        local sel = default or options[1] or ""
        local function closeDropdown() list.Visible = false end
        table.insert(openDropdowns, closeDropdown)
        local optionButtons = {}
        for i, opt in ipairs(options) do
            local ob = Instance.new("TextButton")
            ob.Size = UDim2.new(1, -10, 0, isMobile and 28 or 30)
            ob.Position = UDim2.new(0, 5, 0, 5 + ((i-1) * itemH))
            ob.BackgroundColor3 = (opt == sel) and Colors.Accent or Colors.Panel
            ob.BackgroundTransparency = (opt == sel) and 0 or 0.2
            ob.BorderSizePixel = 0
            ob.Font = Enum.Font.GothamSemibold
            ob.TextSize = isMobile and 12 or 14
            ob.TextColor3 = (opt == sel) and Colors.Background or Colors.Text
            ob.Text = opt
            ob.AutoButtonColor = false
            ob.ZIndex = 51
            ob.Parent = list
            makeCorner(ob, 6)
            table.insert(optionButtons, ob)
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
                list.Visible = false
                for _, ch in ipairs(optionButtons) do
                    if ch.Text == sel then
                        ch.BackgroundColor3 = Colors.Accent
                        ch.BackgroundTransparency = 0
                        ch.TextColor3 = Colors.Background
                    else
                        ch.BackgroundColor3 = Colors.Panel
                        ch.BackgroundTransparency = 0.2
                        ch.TextColor3 = Colors.Text
                    end
                end
                if cb then cb(sel) end
            end)
        end
        register(reg.dropdowns, { b, list, optionButtons, function() return sel end })
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
            local listHeight = list.Size.Y.Offset + 8
            local tabContent = tab.Content
            local cAbsY = c.AbsolutePosition.Y
            local cAbsH = c.AbsoluteSize.Y
            local tabAbsY = tabContent.AbsolutePosition.Y
            local tabAbsH = tabContent.AbsoluteSize.Y
            local bottomSpace = (tabAbsY + tabAbsH) - (cAbsY + cAbsH)
            if bottomSpace < listHeight then
                list.Position = UDim2.new(0.5, 10, 0, -listHeight + 5)
            else
                list.Position = UDim2.new(0.5, 10, 1, 5)
            end
            list.Visible = true
        end)
        addElement(tab, c)
        return {
            SetValue = function(v)
                if not v then return end
                sel = v
                b.Text = v
                for _, ch in ipairs(optionButtons) do
                    if ch.Text == sel then
                        ch.BackgroundColor3 = Colors.Accent
                        ch.BackgroundTransparency = 0
                        ch.TextColor3 = Colors.Background
                    else
                        ch.BackgroundColor3 = Colors.Panel
                        ch.BackgroundTransparency = 0.2
                        ch.TextColor3 = Colors.Text
                    end
                end
                if cb then cb(sel) end
            end,
            GetValue = function() return sel end,
        }
    end

    local toggleBtnSize = isMobile and 54 or 50
    toggleBtn = Instance.new("ImageButton")
    toggleBtn.Name = "HappyHubToggle"
    toggleBtn.Size = UDim2.fromOffset(toggleBtnSize, toggleBtnSize)
    toggleBtn.Position = UDim2.new(1, -(toggleBtnSize + 20), 1, -(toggleBtnSize + 30))
    toggleBtn.BackgroundColor3 = Colors.Background
    toggleBtn.BackgroundTransparency = 0.15
    toggleBtn.Image = MAIN_ICON
    toggleBtn.ImageColor3 = Colors.Accent
    toggleBtn.ScaleType = Enum.ScaleType.Fit
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 3
    toggleBtn.Parent = screenGui
    makeCorner(toggleBtn, 12)
    register(reg.panels, toggleBtn)
    register(reg.accentIcons, toggleBtn)

    local tDrag, tStart, tStartPos = false, nil, nil
    local tMoved = false
    toggleBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            tDrag = true
            tMoved = false
            tStart = i.Position
            tStartPos = toggleBtn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not tDrag then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - tStart
            if d.Magnitude > 6 then tMoved = true end
            toggleBtn.Position = UDim2.new(
                tStartPos.X.Scale, tStartPos.X.Offset + d.X,
                tStartPos.Y.Scale, tStartPos.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            tDrag = false
        end
    end)
    toggleBtn.MouseButton1Click:Connect(function()
        if tMoved then tMoved = false; return end
        if window.IsVisible then hideUI() else showUI() end
    end)

    function window:CreateMobileButton(label, callback)
        if not isMobile then return nil end
        if #self._mobileButtons >= 3 then
            warn("[HappyHub] Max 3 mobile buttons allowed.")
            return nil
        end
        local index = #self._mobileButtons + 1
        local size = 58
        local gap = 8
        local baseX = -(toggleBtnSize + 20)
        local baseY = -(toggleBtnSize + 30) - (size + gap) * index

        local btn = Instance.new("TextButton")
        btn.Name = "HappyHubMobileBtn" .. index
        btn.Size = UDim2.fromOffset(size, size)
        btn.Position = UDim2.new(1, baseX + (toggleBtnSize - size) / 2, 1, baseY)
        btn.BackgroundColor3 = Colors.Panel
        btn.BackgroundTransparency = 0.15
        btn.Text = tostring(label or "BTN")
        btn.TextColor3 = Colors.Accent
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextWrapped = true
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.ZIndex = 90
        btn.Parent = screenGui
        makeCorner(btn, 14)
        local stroke = Instance.new("UIStroke")
        stroke.Color = Colors.Accent
        stroke.Thickness = 1
        stroke.Transparency = 0.5
        stroke.Parent = btn
        register(reg.panels, btn)

        local isDragging, wasMoved = false, false
        local dragStart, startPos
        btn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                isDragging = true
                wasMoved = false
                dragStart = i.Position
                startPos = btn.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not isDragging then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch then
                local d = i.Position - dragStart
                if d.Magnitude > 6 then wasMoved = true end
                btn.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                isDragging = false
            end
        end)
        btn.MouseButton1Click:Connect(function()
            if wasMoved then wasMoved = false; return end
            if callback then pcall(callback) end
        end)

        local handle = { _btn = btn, _index = index, _active = false }
        function handle.SetText(_, text)
            btn.Text = tostring(text or "")
        end
        function handle.GetText()
            return btn.Text
        end
        function handle.SetActive(_, active)
            handle._active = active and true or false
            if handle._active then
                btn.BackgroundColor3 = Colors.Accent
                btn.TextColor3 = Colors.Background
                stroke.Color = Colors.Accent
                stroke.Transparency = 0
            else
                btn.BackgroundColor3 = Colors.Panel
                btn.TextColor3 = Colors.Accent
                stroke.Color = Colors.Accent
                stroke.Transparency = 0.5
            end
        end
        function handle.IsActive()
            return handle._active
        end
        function handle.Destroy()
            if btn and btn.Parent then btn:Destroy() end
        end

        table.insert(self._mobileButtons, handle)
        return handle
    end

    window:CreateTab("Configs", CFG_ICON, true)

    currentWindow = window
    applyTheme()
    return window
end

_G.HappyHubLibrary = Library
return Library