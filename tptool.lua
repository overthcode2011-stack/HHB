local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

local Previous = CoreGui:FindFirstChild("TeleportTool")
if Previous then
	Previous:Destroy()
end

local Config = {
	Background = Color3.fromRGB(13, 13, 17),
	Header = Color3.fromRGB(19, 19, 25),
	Surface = Color3.fromRGB(24, 24, 31),
	Card = Color3.fromRGB(29, 29, 37),
	Accent = Color3.fromRGB(143, 99, 255),
	Text = Color3.fromRGB(240, 240, 245),
	Muted = Color3.fromRGB(130, 130, 145),
	Border = Color3.fromRGB(48, 48, 60)
}

local Icons = {
	Teleport = "rbxassetid://94142568413546",
	Close = "rbxassetid://76491990024731"
}

local Connections = {}
local CardConnections = {}
local Destroyed = false
local Minimized = false
local Dragging = false
local DragStart
local StartPosition
local DragInput

local OriginalMouseBehavior = UserInputService.MouseBehavior
local OriginalMouseIcon = UserInputService.MouseIconEnabled

local function Connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Connections, connection)
	return connection
end

local function ConnectCard(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(CardConnections, connection)
	return connection
end

local function ClearCardConnections()
	for _, connection in ipairs(CardConnections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(CardConnections)
end

local function Create(class, properties, parent)
	local object = Instance.new(class)
	for property, value in pairs(properties) do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local function Animate(object, properties, duration)
	local tween = TweenService:Create(
		object,
		TweenInfo.new(
			duration or 0.18,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		),
		properties
	)
	tween:Play()
	return tween
end

local GUI = Create("ScreenGui", {
	Name = "TeleportTool",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, CoreGui)

local Main = Create("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(320, 370),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = Config.Background,
	BorderSizePixel = 0,
	Active = true,
	ZIndex = 2
}, GUI)

Create("UIStroke", {
	Color = Config.Border,
	Thickness = 1,
	Transparency = 0.15
}, Main)

local Header = Create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 39),
	BackgroundColor3 = Config.Header,
	BorderSizePixel = 0,
	Active = true
}, Main)

local Title = Create("TextLabel", {
	Position = UDim2.fromOffset(13, 0),
	Size = UDim2.new(1, -65, 1, 0),
	BackgroundTransparency = 1,
	Text = "Teleport Tool",
	TextColor3 = Config.Text,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left
}, Header)

Create("UIStroke", {
	Color = Config.Border,
	Thickness = 1,
	Transparency = 0.6
}, Header)

local CloseButton = Create("ImageButton", {
	Name = "Minimize",
	Size = UDim2.fromOffset(23, 23),
	Position = UDim2.new(1, -31, 0, 8),
	BackgroundTransparency = 1,
	Image = Icons.Close,
	ScaleType = Enum.ScaleType.Fit,
	AutoButtonColor = false,
	ZIndex = 3
}, Header)

local Search = Create("TextBox", {
	Name = "Search",
	Position = UDim2.fromOffset(12, 51),
	Size = UDim2.new(1, -24, 0, 30),
	BackgroundColor3 = Config.Surface,
	BorderSizePixel = 0,
	PlaceholderText = "Search player...",
	PlaceholderColor3 = Config.Muted,
	Text = "",
	TextColor3 = Config.Text,
	Font = Enum.Font.Gotham,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false
}, Main)

Create("UIPadding", {
	PaddingLeft = UDim.new(0, 9),
	PaddingRight = UDim.new(0, 9)
}, Search)

Create("UIStroke", {
	Color = Config.Border,
	Thickness = 1,
	Transparency = 0.5
}, Search)

local PlayerCount = Create("TextLabel", {
	Position = UDim2.fromOffset(13, 87),
	Size = UDim2.new(1, -26, 0, 17),
	BackgroundTransparency = 1,
	Text = "PLAYERS  |  0",
	TextColor3 = Config.Muted,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left
}, Main)

local List = Create("ScrollingFrame", {
	Name = "PlayerList",
	Position = UDim2.fromOffset(12, 109),
	Size = UDim2.new(1, -24, 0, 221),
	BackgroundColor3 = Config.Surface,
	BorderSizePixel = 0,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = Config.Accent,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.None
}, Main)

local Layout = Create("UIListLayout", {
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder
}, List)

Create("UIPadding", {
	PaddingTop = UDim.new(0, 7),
	PaddingBottom = UDim.new(0, 7),
	PaddingLeft = UDim.new(0, 7),
	PaddingRight = UDim.new(0, 7)
}, List)

local Status = Create("TextLabel", {
	Position = UDim2.fromOffset(13, 340),
	Size = UDim2.new(1, -26, 0, 18),
	BackgroundTransparency = 1,
	Text = "Status: Ready",
	TextColor3 = Config.Muted,
	Font = Enum.Font.Gotham,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left
}, Main)

local OpenBar = Create("TextButton", {
	Name = "OpenBar",
	Size = UDim2.fromOffset(230, 32),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	BackgroundColor3 = Config.Background,
	BorderSizePixel = 0,
	Text = "Press 'I' to Open",
	TextColor3 = Config.Text,
	Font = Enum.Font.GothamMedium,
	TextScaled = true,
	Visible = false,
	AutoButtonColor = false,
	ZIndex = 10,
	Active = true
}, GUI)

Create("UIStroke", {
	Color = Config.Accent,
	Thickness = 1,
	Transparency = 0.25
}, OpenBar)

local function SetMouseUnlocked()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function RestoreMouse()
	UserInputService.MouseBehavior = OriginalMouseBehavior
	UserInputService.MouseIconEnabled = OriginalMouseIcon
end

local function SetMinimized(state)
	if Destroyed then
		return
	end

	Minimized = state
	Main.Visible = not state
	OpenBar.Visible = state

	if state then
		RestoreMouse()
		Status.Text = "Status: Minimized"
	else
		SetMouseUnlocked()
		Status.Text = "Status: Ready"
	end
end

local function TeleportTo(target)
	if Destroyed or not target or target == LocalPlayer then
		return
	end

	if target.Parent ~= Players then
		Status.Text = "Status: Player unavailable"
		return
	end

	local character = LocalPlayer.Character
	local targetCharacter = target.Character

	local root = character and character:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

	if not root or not targetRoot then
		Status.Text = "Status: Character unavailable"
		return
	end

	local success = pcall(function()
		root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
	end)

	if success then
		Status.Text = "Status: Teleport attempted"
	else
		Status.Text = "Status: Teleport failed"
	end
end

local function LoadThumbnail(player, image)
	task.spawn(function()
		local success, thumbnail = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)

		if success and image.Parent and not Destroyed then
			image.Image = thumbnail
		end
	end)
end

local function BuildPlayers()
	if Destroyed then
		return
	end

	ClearCardConnections()

	for _, child in ipairs(List:GetChildren()) do
		if child:IsA("Frame") or child.Name == "EmptyState" then
			child:Destroy()
		end
	end

	local query = Search.Text:lower()
	local playerList = Players:GetPlayers()

	table.sort(playerList, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)

	local visibleCount = 0

	for _, player in ipairs(playerList) do
		local matches =
			player ~= LocalPlayer
			and (
				query == ""
				or player.Name:lower():find(query, 1, true)
				or player.DisplayName:lower():find(query, 1, true)
			)

		if matches then
			visibleCount += 1

			local Card = Create("Frame", {
				Name = "PlayerCard_" .. player.UserId,
				Size = UDim2.new(1, -2, 0, 43),
				BackgroundColor3 = Config.Card,
				BorderSizePixel = 0,
				LayoutOrder = visibleCount
			}, List)

			local Avatar = Create("ImageLabel", {
				Name = "Avatar",
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.fromOffset(31, 31),
				BackgroundColor3 = Config.Surface,
				BorderSizePixel = 0,
				Image = "",
				ScaleType = Enum.ScaleType.Crop
			}, Card)

			local DisplayName = Create("TextLabel", {
				Position = UDim2.fromOffset(44, 5),
				Size = UDim2.new(1, -85, 0, 17),
				BackgroundTransparency = 1,
				Text = player.DisplayName,
				TextColor3 = Config.Text,
				Font = Enum.Font.GothamSemibold,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left
			}, Card)

			local Username = Create("TextLabel", {
				Position = UDim2.fromOffset(44, 23),
				Size = UDim2.new(1, -85, 0, 13),
				BackgroundTransparency = 1,
				Text = "@" .. player.Name,
				TextColor3 = Config.Muted,
				Font = Enum.Font.Gotham,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left
			}, Card)

			local TeleportButton = Create("ImageButton", {
				Name = "TeleportButton",
				Position = UDim2.new(1, -34, 0, 8),
				Size = UDim2.fromOffset(27, 27),
				BackgroundColor3 = Config.Surface,
				BorderSizePixel = 0,
				Image = Icons.Teleport,
				ScaleType = Enum.ScaleType.Fit,
				AutoButtonColor = false
			}, Card)

			Create("UIStroke", {
				Color = Config.Border,
				Thickness = 1,
				Transparency = 0.4
			}, Card)

			LoadThumbnail(player, Avatar)

			ConnectCard(TeleportButton.MouseButton1Click, function()
				TeleportTo(player)
			end)

			ConnectCard(TeleportButton.MouseEnter, function()
				Animate(TeleportButton, {
					BackgroundColor3 = Config.Accent
				})
			end)

			ConnectCard(TeleportButton.MouseLeave, function()
				Animate(TeleportButton, {
					BackgroundColor3 = Config.Surface
				})
			end)
		end
	end

	PlayerCount.Text = "PLAYERS  |  " .. visibleCount

	if visibleCount == 0 then
		Create("TextLabel", {
			Name = "EmptyState",
			Size = UDim2.new(1, -4, 0, 45),
			BackgroundTransparency = 1,
			Text = "No players found",
			TextColor3 = Config.Muted,
			Font = Enum.Font.Gotham,
			TextScaled = true,
			LayoutOrder = 1
		}, List)
	end
end

Connect(Layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
	List.CanvasSize = UDim2.fromOffset(
		0,
		Layout.AbsoluteContentSize.Y + 14
	)
end)

Connect(Search:GetPropertyChangedSignal("Text"), BuildPlayers)
Connect(Players.PlayerAdded, BuildPlayers)
Connect(Players.PlayerRemoving, BuildPlayers)

Connect(CloseButton.MouseButton1Click, function()
	SetMinimized(true)
end)

Connect(OpenBar.MouseButton1Click, function()
	SetMinimized(false)
end)

Connect(UserInputService.InputBegan, function(input, gameProcessed)
	if Destroyed then
		return
	end

	if input.KeyCode == Enum.KeyCode.I then
		if UserInputService:GetFocusedTextBox() then
			return
		end

		if Minimized then
			SetMinimized(false)
		end
	end
end)

Connect(Header.InputBegan, function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	if input.Position.X >= Header.AbsolutePosition.X + Header.AbsoluteSize.X - 42 then
		return
	end

	Dragging = true
	DragStart = input.Position
	StartPosition = Main.Position

	if input.UserInputType == Enum.UserInputType.Touch then
		DragInput = input
	end
end)

Connect(UserInputService.InputChanged, function(input)
	if not Dragging then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input == DragInput then

		local delta = input.Position - DragStart

		Main.Position = UDim2.new(
			StartPosition.X.Scale,
			StartPosition.X.Offset + delta.X,
			StartPosition.Y.Scale,
			StartPosition.Y.Offset + delta.Y
		)
	end
end)

Connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input == DragInput then

		Dragging = false
		DragInput = nil
	end
end)

Connect(LocalPlayer.Idled, function()
	if Destroyed then
		return
	end

	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)
end)

local function Cleanup()
	if Destroyed then
		return
	end

	Destroyed = true
	Dragging = false

	RestoreMouse()
	ClearCardConnections()

	for _, connection in ipairs(Connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end

	table.clear(Connections)

	pcall(function()
		RunService:UnbindFromRenderStep("TeleportTool_MouseControl")
	end)
end

GUI.Destroying:Connect(Cleanup)

RunService:BindToRenderStep(
	"TeleportTool_MouseControl",
	Enum.RenderPriority.Last.Value,
	function()
		if Destroyed then
			return
		end

		if Minimized then
			UserInputService.MouseBehavior = OriginalMouseBehavior
			UserInputService.MouseIconEnabled = OriginalMouseIcon
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	end
)

BuildPlayers()
SetMinimized(false)
