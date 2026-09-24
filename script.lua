local Players              = game:GetService("Players")
local Replicated           = game:GetService("ReplicatedStorage")
local StarterGui           = game:GetService("StarterGui")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local MarketplaceService   = game:GetService("MarketplaceService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10)

local Targets = {
	Vector3.new(-778, 176, 25),
	Vector3.new(-462, 174, -220),
	Vector3.new(-150, 139, -609),
	Vector3.new(222, 154, -1054),
	Vector3.new(357, 141, -1201),
	Vector3.new(379, 84, -1226),
	Vector3.new(321, 59, -1321),
	Vector3.new(269, 59, -1438),
}

local VERSION = "v0.77"

local REACH_DISTANCE = 5
local JUMP_HEIGHT    = 3
local BLOCK_COOLDOWN = 3

local Character
local Humanoid
local RootPart

local currentTarget = 1
local Enabled       = true

local Equipped       = false
local AttackInterval = 0.5
local LastAttack     = 0

local TargetCurrency = "Golden Shell"
local LastInventory  = nil
local EventCurrency  = 0

local TotalBlock = 0

local TargetPlaceID = 4737916764
local MAX_SERVER_AGE = 7 * 60 * 60

local BlockCache  = {}
local BlockEnabled = true

--// Character
local function updateCharacter()
	Character = Player.Character

	if not Character then
		Humanoid = nil
		RootPart = nil
		return
	end

	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	RootPart = Character:FindFirstChild("HumanoidRootPart")

	task.defer(function()
		if not Humanoid then
			return
		end

		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	end)
end

updateCharacter()

local StaminaConnection = nil
function RegenStamina()
	task.spawn(function()
		local PlayerStats = Player:FindFirstChild("PlayerStats")
		if not PlayerStats then
			repeat task.wait(0.5) until Player:FindFirstChild("PlayerStats")
			PlayerStats = Player:FindFirstChild("PlayerStats")
		end
		local GameGui = PlayerGui:FindFirstChild("GameGui")
		if not GameGui then
			repeat task.wait(0.5) until PlayerGui:FindFirstChild("GameGui")
			GameGui = PlayerGui:FindFirstChild("GameGui")
		end
		local Stamina = GameGui:FindFirstChild("Stamina")
		local MaxStamina = PlayerStats:FindFirstChild("MaxStamina")
		if not Stamina then
			return
		end

		StaminaConnection = Stamina:GetPropertyChangedSignal("Value"):Connect(function()
			if Stamina.Value < MaxStamina.Value then
				Stamina.Value = MaxStamina.Value
			end
		end)
	end)
end
RegenStamina()

Player.CharacterAdded:Connect(function()
	task.wait()

	currentTarget = 1
	Equipped = false

	if StaminaConnection then
		StaminaConnection:Disconnect()
		StaminaConnection = nil
	end
	RegenStamina()
	
	updateCharacter()
end)

local function ResetOnBoostOut()
	local PlayerStats = Player:FindFirstChild("PlayerStats")
	if not PlayerStats then
		repeat task.wait(1) until Player:FindFirstChild("PlayerStats")
		PlayerStats = Player:FindFirstChild("PlayerStats")
	end
	local ExpBoost = PlayerStats:FindFirstChild("Boost")
	local DropBoost = PlayerStats:FindFirstChild("BoostDrops")
	ExpBoost:GetPropertyChangedSignal("Value"):Connect(function()
		if ExpBoost.Value == 0 then
			Humanoid.Health = 0
		end
	end)
	DropBoost:GetPropertyChangedSignal("Value"):Connect(function()
		if DropBoost.Value == 0 then
			Humanoid.Health = 0
		end
	end)
end
ResetOnBoostOut()

--// UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFarmUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
ScreenGui.Parent = PlayerGui

if game.PlaceId == TargetPlaceID then
	ScreenGui.DisplayOrder = 1
end

--// Theme
local UI_PANEL   = Color3.fromRGB(22, 23, 29)
local UI_SURFACE = Color3.fromRGB(29, 31, 38)
local UI_HOVER   = Color3.fromRGB(38, 40, 48)
local UI_BORDER  = Color3.fromRGB(55, 58, 68)
local UI_TEXT    = Color3.fromRGB(238, 239, 244)
local UI_MUTED   = Color3.fromRGB(145, 149, 162)
local UI_ACCENT  = Color3.fromRGB(112, 126, 255)

--// Panel
local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(1, 0.5)
Panel.Size = UDim2.fromScale(0.25, 0.70)
Panel.Position = UDim2.fromScale(0.95, 0.55)
Panel.BackgroundColor3 = UI_PANEL
Panel.BorderSizePixel = 0
Panel.ClipsDescendants = true
Panel.Parent = ScreenGui

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 1)
PanelCorner.Parent = Panel

local PanelStroke = Instance.new("UIStroke")
PanelStroke.Color = UI_BORDER
PanelStroke.Thickness = 1
PanelStroke.Transparency = 0.1
PanelStroke.Parent = Panel

--// Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.fromScale(1, 0.1346)
Header.BackgroundColor3 = UI_SURFACE
Header.BorderSizePixel = 0
Header.Parent = Panel

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0.25, 0)
HeaderCorner.Parent = Header

local HeaderMask = Instance.new("Frame")
HeaderMask.Size = UDim2.fromScale(1, 0.25)
HeaderMask.Position = UDim2.fromScale(1, -0.25)
HeaderMask.BackgroundColor3 = UI_SURFACE
HeaderMask.BorderSizePixel = 0
HeaderMask.Parent = Header

local Accent = Instance.new("Frame")
Accent.Size = UDim2.fromScale(0.0103, 0.6667)
Accent.Position = UDim2.fromScale(0.0359, 0.1667)
Accent.BackgroundColor3 = UI_ACCENT
Accent.BorderSizePixel = 0
Accent.Parent = Header

local AccentCorner = Instance.new("UICorner")
AccentCorner.CornerRadius = UDim.new(1, 0)
AccentCorner.Parent = Accent

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.fromScale(0.8205, 0.3889)
Title.Position = UDim2.fromScale(0.0769, 0.1528)
Title.BackgroundTransparency = 1
Title.Text = "AUTO FARMING (F8)"
Title.TextColor3 = UI_TEXT
Title.TextScaled = true
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextTruncate = Enum.TextTruncate.AtEnd
Title.Parent = Header

local PlaceNameLabel = Instance.new("TextLabel")
PlaceNameLabel.Name = "PlaceName"
PlaceNameLabel.Size = UDim2.fromScale(0.8205, 0.25)
PlaceNameLabel.Position = UDim2.fromScale(0.0769, 0.5556)
PlaceNameLabel.BackgroundTransparency = 1
PlaceNameLabel.TextColor3 = UI_MUTED
PlaceNameLabel.TextScaled = true
PlaceNameLabel.Font = Enum.Font.GothamMedium
PlaceNameLabel.TextXAlignment = Enum.TextXAlignment.Left
PlaceNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
PlaceNameLabel.Parent = Header

task.spawn(function()
	local Success, ProductInfo = pcall(function()
		return MarketplaceService:GetProductInfoAsync(TargetPlaceID)
	end)

	if Success and ProductInfo then
		PlaceNameLabel.Text = ProductInfo.Name .. "  •  " .. VERSION
	else
		PlaceNameLabel.Text = "Place ID " .. TargetPlaceID .. "  •  " .. VERSION
	end
end)

local DragHint = Instance.new("TextLabel")
DragHint.Size = UDim2.fromScale(0.0821, 0.3889)
DragHint.Position = UDim2.fromScale(0.8897, 0.3056)
DragHint.BackgroundTransparency = 1
DragHint.Text = "⋮⋮"
DragHint.TextColor3 = UI_MUTED
DragHint.TextScaled = true
DragHint.Font = Enum.Font.GothamBold
DragHint.Parent = Header

--// Content
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.fromScale(0.9385, 0.843)
Content.Position = UDim2.fromScale(0.0308, 0.1458)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = UI_BORDER
Content.CanvasSize = UDim2.fromScale(0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.Parent = Panel

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingLeft = UDim.new(0.005, 0)
ContentPadding.PaddingRight = UDim.new(0.005, 0)
ContentPadding.PaddingBottom = UDim.new(0, 0)
ContentPadding.Parent = Content

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 5)
ContentLayout.Parent = Content

--// Main Toggle
local Toggle = Instance.new("TextButton")
Toggle.Name = "Toggle"
Toggle.LayoutOrder = 1
Toggle.Size = UDim2.fromScale(0.9949, 0.0822)
Toggle.BorderSizePixel = 0
Toggle.TextColor3 = UI_TEXT
Toggle.TextScaled = true
Toggle.Font = Enum.Font.GothamBold
Toggle.AutoButtonColor = false
Toggle.Parent = Content

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0.205, 0)
ToggleCorner.Parent = Toggle

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = UI_BORDER
ToggleStroke.Thickness = 1
ToggleStroke.Transparency = 0.3
ToggleStroke.Parent = Toggle

local Status = Instance.new("TextLabel")
Status.Name = "Status"
Status.LayoutOrder = 2
Status.Size = UDim2.fromScale(0.9949, 0.0374)
Status.BackgroundTransparency = 1
Status.TextColor3 = UI_MUTED
Status.TextScaled = true
Status.Font = Enum.Font.GothamMedium
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Content

--// Live Status
local StatsCollapsed = false

local StatsHeader = Instance.new("TextButton")
StatsHeader.Name = "StatsHeader"
StatsHeader.LayoutOrder = 3
StatsHeader.Size = UDim2.fromScale(0.9949, 0.0374)
StatsHeader.BackgroundTransparency = 1
StatsHeader.Text = "LIVE STATUS  ▼"
StatsHeader.TextColor3 = UI_TEXT
StatsHeader.TextScaled = true
StatsHeader.Font = Enum.Font.GothamBold
StatsHeader.TextXAlignment = Enum.TextXAlignment.Left
StatsHeader.AutoButtonColor = false
StatsHeader.Parent = Content

local Stats = Instance.new("Frame")
Stats.Name = "Stats"
Stats.LayoutOrder = 4
Stats.Size = UDim2.fromScale(0.9949, 0)
Stats.BackgroundTransparency = 1
Stats.Parent = Content

local StatsGrid = Instance.new("UIGridLayout")
StatsGrid.CellSize = UDim2.fromScale(0.5, 0.5)
StatsGrid.CellPadding = UDim2.fromScale(0, 0.005)
StatsGrid.SortOrder = Enum.SortOrder.LayoutOrder
StatsGrid.Parent = Stats

local function UpdateStatsLayout()
	if StatsCollapsed then
		return
	end

	local CardCount = 0

	for _, Child in Stats:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= StatsGrid then
			CardCount += 1
		end
	end

	if CardCount <= 0 then
		Stats.Size = UDim2.fromScale(0.9949, 0)
		return
	end

	local ColumnCount = 2
	local RowCount    = math.ceil(CardCount / ColumnCount)

	local BaseHeight = 0.095
	local PaddingY   = 0.005

	local StatsHeight = (BaseHeight * RowCount) + (PaddingY * (RowCount - 1))

	Stats.Size = UDim2.fromScale(0.9949, StatsHeight)

	local CellHeight = BaseHeight / StatsHeight
	local CellPadding = PaddingY / StatsHeight

	StatsGrid.CellSize = UDim2.fromScale(0.5, CellHeight)
	StatsGrid.CellPadding = UDim2.fromScale(0, CellPadding)
end

local function SetStatsCollapsed(Collapsed)
	StatsCollapsed = Collapsed

	if StatsCollapsed then
		StatsHeader.Text = "LIVE STATUS  ▶"
		Stats.Visible = false
	else
		StatsHeader.Text = "LIVE STATUS  ▼"
		Stats.Visible = true
		UpdateStatsLayout()
	end
end

StatsHeader.Activated:Connect(function()
	SetStatsCollapsed(not StatsCollapsed)
end)

local function CreateStat(Name, DefaultText, Order)
	local Card = Instance.new("Frame")
	Card.Name = Name
	Card.LayoutOrder = Order
	Card.BackgroundColor3 = UI_SURFACE
	Card.BorderSizePixel = 0
	Card.Parent = Stats

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0.02, 0)
	Corner.Parent = Card

	local Label = Instance.new("TextLabel")
	Label.Name = "Label"
	Label.Size = UDim2.fromScale(0.9158, 0.2826)
	Label.Position = UDim2.fromScale(0.0421, 0.1087)
	Label.BackgroundTransparency = 1
	Label.Text = Name
	Label.TextColor3 = UI_MUTED
	Label.TextScaled = true
	Label.Font = Enum.Font.GothamMedium
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Card

	local Value = Instance.new("TextLabel")
	Value.Name = "Value"
	Value.Size = UDim2.fromScale(0.9158, 0.4130)
	Value.Position = UDim2.fromScale(0.0421, 0.4348)
	Value.BackgroundTransparency = 1
	Value.Text = DefaultText
	Value.TextColor3 = UI_TEXT
	Value.TextScaled = true
	Value.Font = Enum.Font.GothamBold
	Value.TextXAlignment = Enum.TextXAlignment.Left
	Value.TextTruncate = Enum.TextTruncate.AtEnd
	Value.Parent = Card

	return Value
end

local PlaceIDLabel       = CreateStat("PLACE ID", tostring(game.PlaceId), 1)
local WalkSpeedLabel     = CreateStat("WALKSPEED", "0", 2)
local WayPointLabel      = CreateStat("WAYPOINT", "0/" .. #Targets, 3)
local EventCurrencyLabel = CreateStat("EVENT CURRENCY", "0", 4)
local ServerAgeLabel     = CreateStat("SERVER AGE", "00:00:00", 5)
local PositionLabel      = CreateStat("POSITION", "--", 6)

UpdateStatsLayout()

Stats.ChildAdded:Connect(function(Child)
	if Child:IsA("GuiObject") and Child ~= StatsGrid then
		task.defer(UpdateStatsLayout)
	end
end)

Stats.ChildRemoved:Connect(function(Child)
	if Child:IsA("GuiObject") and Child ~= StatsGrid then
		task.defer(UpdateStatsLayout)
	end
end)

--// Block Toggle
local BlockToggle = Instance.new("TextButton")
BlockToggle.Name = "BlockToggle"
BlockToggle.LayoutOrder = 5
BlockToggle.Size = UDim2.fromScale(0.9949, 0.0785)
BlockToggle.BorderSizePixel = 0
BlockToggle.TextColor3 = UI_TEXT
BlockToggle.TextScaled = true
BlockToggle.Font = Enum.Font.GothamBold
BlockToggle.AutoButtonColor = false
BlockToggle.Parent = Content

local BlockToggleCorner = Instance.new("UICorner")
BlockToggleCorner.CornerRadius = UDim.new(0.205, 0)
BlockToggleCorner.Parent = BlockToggle

local BlockToggleStroke = Instance.new("UIStroke")
BlockToggleStroke.Color = UI_BORDER
BlockToggleStroke.Thickness = 1
BlockToggleStroke.Transparency = 0.3
BlockToggleStroke.Parent = BlockToggle

--// UI Toggle Container
local ToggleScreenGUI = PlayerGui:FindFirstChild("ToggleScreenGUI")

if not ToggleScreenGUI then
	ToggleScreenGUI = Instance.new("ScreenGui")
	ToggleScreenGUI.Name = "ToggleScreenGUI"
	ToggleScreenGUI.IgnoreGuiInset = true
	ToggleScreenGUI.Parent = PlayerGui
end

local ToggleContainer = ToggleScreenGUI:FindFirstChild("ToggleContainer")

if not ToggleContainer then
	ToggleContainer = Instance.new("Frame")
	ToggleContainer.Name = "ToggleContainer"
	ToggleContainer.Size = UDim2.new(1, -4, 0, 48)
	ToggleContainer.Position = UDim2.fromOffset(0, 10)
	ToggleContainer.BackgroundTransparency = 1
	ToggleContainer.Parent = ToggleScreenGUI
end

local ToggleUIListLayout = ToggleContainer:FindFirstChild("UIListLayout")

if not ToggleUIListLayout then
	ToggleUIListLayout = Instance.new("UIListLayout")
	ToggleUIListLayout.Padding = UDim.new(0, 10)
	ToggleUIListLayout.FillDirection = Enum.FillDirection.Horizontal
	ToggleUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ToggleUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ToggleUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	ToggleUIListLayout.Parent = ToggleContainer
end

--// GUI Toggle
local GUIToggle = Instance.new("TextButton")
GUIToggle.Name = "GUIToggle"
GUIToggle.Size = UDim2.fromOffset(44, 44)
GUIToggle.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
GUIToggle.BackgroundTransparency = 0.08
GUIToggle.BorderSizePixel = 0
GUIToggle.Text = "≡"
GUIToggle.TextColor3 = UI_TEXT
GUIToggle.TextScaled = true
GUIToggle.LayoutOrder = 8
GUIToggle.Font = Enum.Font.Gotham
GUIToggle.AutoButtonColor = true
GUIToggle.Parent = ToggleContainer

local GUIToggleCorner = Instance.new("UICorner")
GUIToggleCorner.CornerRadius = UDim.new(0, 8)
GUIToggleCorner.Parent = GUIToggle

local GUIVisible = true

GUIToggle.Activated:Connect(function()
	GUIVisible = not GUIVisible
	Panel.Visible = GUIVisible
end)

--// Panel Dragging
local Dragging     = false
local DragStart    = nil
local StartPosition = nil

Header.InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1
		or Input.UserInputType == Enum.UserInputType.Touch
	then
		Dragging = true
		DragStart = Input.Position
		StartPosition = Panel.Position

		Input.Changed:Connect(function()
			if Input.UserInputState == Enum.UserInputState.End then
				Dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(Input)
	if not Dragging then
		return
	end

	if Input.UserInputType ~= Enum.UserInputType.MouseMovement
		and Input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end

	local Delta = Input.Position - DragStart
	local Camera = workspace.CurrentCamera

	if not Camera then
		return
	end

	local Viewport = Camera.ViewportSize

	local DeltaScaleX = Delta.X / Viewport.X
	local DeltaScaleY = Delta.Y / Viewport.Y

	Panel.Position = UDim2.fromScale(
		StartPosition.X.Scale + DeltaScaleX,
		StartPosition.Y.Scale + DeltaScaleY
	)
end)

--// Block UI
local function updateBlockButton()
	if BlockEnabled then
		BlockToggle.Text = "●  AUTO BLOCKING  •  ENABLED"
		BlockToggle.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
	else
		BlockToggle.Text = "●  AUTO BLOCKING  •  DISABLED"
		BlockToggle.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
	end
end

BlockToggle.Activated:Connect(function()
	BlockEnabled = not BlockEnabled
	updateBlockButton()
end)

updateBlockButton()

--// UI Update
local function updateButton()
	if Enabled then
		Toggle.Text = "●  AUTO FARMING  •  ENABLED"
		Toggle.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Status.Text = "Farming system is active"
	else
		Toggle.Text = "●  AUTO FARMING  •  DISABLED"
		Toggle.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Status.Text = "Farming system is paused"
	end
end

local function GetItem(String, ItemName)
	for Item in string.gmatch(String, "([^,]+)") do
		local Name, Amount = string.match(Item, "([^|]+)|(.+)")

		if Name == ItemName then
			return Name, tonumber(Amount) or 0
		end
	end

	return ItemName, 0
end

local function updateEventCurrency()
	local PlayerStats = Player:FindFirstChild("PlayerStats")

	if not PlayerStats then
		EventCurrency = 0
		EventCurrencyLabel.Text = "0"
		return
	end

	local Inventory = PlayerStats:FindFirstChild("Inventory")

	if not Inventory then
		EventCurrency = 0
		EventCurrencyLabel.Text = "0"
		return
	end

	local InventoryValue = Inventory.Value

	if InventoryValue == LastInventory then
		return
	end

	LastInventory = InventoryValue

	local _, Amount = GetItem(InventoryValue, TargetCurrency)

	EventCurrency = Amount
	EventCurrencyLabel.Text = tostring(EventCurrency)
end

local function updateServerAge()
	local ServerAge = math.floor(workspace.DistributedGameTime)

	local Hours   = math.floor(ServerAge / 3600)
	local Minutes = math.floor((ServerAge % 3600) / 60)
	local Seconds = ServerAge % 60

	ServerAgeLabel.Text = string.format(
		"%02d:%02d:%02d",
		Hours,
		Minutes,
		Seconds
	)
end

local function updatePosition()
	if RootPart then
		local Position = RootPart.Position

		PositionLabel.Text = string.format(
			"%.1f, %.1f, %.1f",
			Position.X,
			Position.Y,
			Position.Z
		)
	else
		PositionLabel.Text = "--"
	end
end

PlaceIDLabel.Text = `{game.PlaceId} {game.PlaceId ~= TargetPlaceID and "(NOT MATCH)" or ""}`

Toggle.Activated:Connect(function()
	Enabled = not Enabled
	updateButton()
end)

updateButton()
updatePosition()

--// Teleport
local function TeleportToPlace(placeId: number?)
	local TeleportService = game:GetService("TeleportService")

	TeleportService:Teleport(placeId or game.PlaceId, Player)
end

--// Block
local function isBlocked(userId)
	local success, blockedUserIds = pcall(function()
		return StarterGui:GetCore("GetBlockedUserIds")
	end)

	if not success or not blockedUserIds then
		return false
	end

	for _, blockedUserId in blockedUserIds do
		if blockedUserId == userId then
			return true
		end
	end

	return false
end

local function promptBlockPlayer(plr)
	local userId = plr.UserId

	if BlockCache[userId] then
		return
	end

	if isBlocked(userId) then
		return
	end

	BlockCache[userId] = true

	local success, err = pcall(function()
		StarterGui:SetCore("PromptBlockPlayer", plr)
	end)

	if not success then
		warn("PromptBlockPlayer failed:", err)
		BlockCache[userId] = nil
		return
	end

	TotalBlock += 1

	task.delay(BLOCK_COOLDOWN, function()
		BlockCache[userId] = nil
	end)
end

--// Position Update
RunService.RenderStepped:Connect(function()
	updatePosition()
end)

--// Movement + Block
RunService.Heartbeat:Connect(function()
	if game.PlaceId ~= TargetPlaceID then
		Enabled = false
		updateButton()
		return
	end

	if not Humanoid or not RootPart then
		updateCharacter()
		return
	end

	if Humanoid.Health <= 0 then
		return
	end

	updateServerAge()
	updateEventCurrency()

	WayPointLabel.Text = currentTarget .. "/" .. #Targets
	WalkSpeedLabel.Text = tostring(Humanoid.WalkSpeed)

	if not Enabled then
		Humanoid:MoveTo(RootPart.Position)
		return
	end

	--// Block
	if BlockEnabled then
		local HasOtherPlayer  = false
		local HasBlockedPlayer = false

		for _, plr in Players:GetPlayers() do
			if plr == Player then
				continue
			end

			HasOtherPlayer = true

			if isBlocked(plr.UserId) then
				HasBlockedPlayer = true
				BlockCache[plr.UserId] = nil
				break
			end
		end

		if HasBlockedPlayer then
			TeleportToPlace()
			return
		end

		if HasOtherPlayer then
			for _, plr in Players:GetPlayers() do
				if plr == Player then
					continue
				end

				if not isBlocked(plr.UserId) then
					promptBlockPlayer(plr)
					return
				end
			end
		end
	end

	--// Server Age
	if workspace.DistributedGameTime >= MAX_SERVER_AGE then
		TeleportToPlace()
		return
	end

	--// Movement
	local target = Targets[currentTarget]

	if (RootPart.Position - target).Magnitude <= REACH_DISTANCE then
		if currentTarget < #Targets then
			currentTarget += 1
		end

		target = Targets[currentTarget]
	end

	--// Jump
	if currentTarget ~= #Targets then
		local heightDifference = target.Y - RootPart.Position.Y

		if heightDifference >= JUMP_HEIGHT
			and Humanoid.FloorMaterial ~= Enum.Material.Air
			and Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
		then
			Humanoid.Jump = true
			Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	else
		local InputBindableFunction = PlayerGui:FindFirstChild("InputBindableFunction", true) :: BindableFunction

		if not InputBindableFunction then
			return
		end

		if not Equipped then
			InputBindableFunction:Invoke("EquipButton", Enum.UserInputState.Begin)
			Equipped = true
		else
			if os.clock() - LastAttack >= AttackInterval then
				InputBindableFunction:Invoke("AttackButton", Enum.UserInputState.Begin)
				InputBindableFunction:Invoke("SkillButton", Enum.UserInputState.Begin)
				LastAttack = os.clock()
			end
		end
	end

	Humanoid.WalkSpeed = 38
	Humanoid:MoveTo(target)
end)
