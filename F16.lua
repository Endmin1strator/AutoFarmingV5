local Players            = game:GetService("Players")
local Replicated         = game:GetService("ReplicatedStorage")
local StarterGui         = game:GetService("StarterGui")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local PathfindingService  = game:GetService("PathfindingService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10)

local CONFIG = {
	VERSION = "v1.62",

	CURRENT_WAYPOINT_TARGET = 1,
	MAX_SERVER_AGE = 7 * 60 * 60,

	TARGET_ENTITY_PRIORITY = {
		[1] = "Goblin",
		[2] = "Leader Goblin",
	},

	GOBLIN_REACH_DISTANCE = 8,
	PLAYER_ATTACK_DISTANCE = 8,
	ENEMY_ATTACK_SAFE_DISTANCE = 2,
	ENEMY_BLADE_PADDING = 2,
	GROUP_DANGER_DISTANCE = 22,
	THREAT_DETECTION_DISTANCE = 12,
	THREAT_ANGLE = 65,
	THREAT_ESCAPE_DISTANCE = 20,

	DEADZONE_ESCAPE_DISTANCE = 45,
	DEADZONE_ESCAPE_DIRECTIONS = 16,
	DEADZONE_ESCAPE_INTERVAL = 0.3,

	JUMP_HEIGHT = 2,
	STUCK_CHECK_INTERVAL = 0.5,
	BLOCK_COOLDOWN = 3,

	MOB_DETECTION_DISTANCE = 200,
	MOB_VALIDATION_INTERVAL = 0.15,
	DISTANCE_Y_CALCULATE = false,
	TARGET_UNREACHABLE_TIMEOUT = 10,
	TARGET_REPOSITION_INTERVAL = 0.3,
	TARGET_PATH_RECALCULATE_INTERVAL = 0.5,
	TARGET_PATH_WAYPOINT_DISTANCE = 3,
	TARGET_REPOSITION_RADIUS = 12,
	TARGET_REPOSITION_DIRECTIONS = 16,
	SAFE_COMBAT_DIRECTIONS = 12,
	SAFE_COMBAT_MAX_PATH_TESTS = 4,

	RETREAT_DISTANCE = 60,
	RETREAT_DIRECTIONS = 16,
	RETREAT_RECALCULATE_INTERVAL = 0.5,
	RETREAT_NO_POSITION_TIMEOUT = 1.5,

	ATTACK_INTERVAL = 0.2,
	SKILL_INTERVAL = 3,
	CONSUME_INTERVAL = 10,
	MINIMUM_WALKSPEED = 28,
	MAXIMUM_WALKSPEED = 38,
	INTERACTION_INTERVAL = 0.5,
	TEXT_UPDATE_INTERVAL = 0.5,

	SAFECOMBAT_INTERVAL = 0.25,
	BLADE_PART_CACHE_INTERVAL = 0.2,
	COMBAT_GROUP_CACHE_INTERVAL = 0.15,
	DIRECT_PATH_CACHE_INTERVAL = 0.12,

	PATROL_RADIUS_MIN = 28,
	PATROL_RADIUS_MAX = 60,
	PATROL_DIRECTIONS = 12,
	PATROL_RECALCULATE_INTERVAL = 12,
	PATROL_MIN_DISTANCE = 24,
	PATROL_MAX_DISTANCE = 58,
	PATROL_ARRIVAL_DISTANCE = 4,
	PATROL_PAUSE_MIN = 0.8,
	PATROL_PAUSE_MAX = 2.8,
	PATROL_DIRECTION_MEMORY = 0.65,
	PATROL_ESCAPE_DISTANCE = 10,
	PATROL_ESCAPE_DIRECTIONS = 4,

	WATER_SAMPLE_DISTANCE = 4,
	DEADZONE_SAMPLE_DISTANCE = 2,

	UI_PANEL = Color3.fromRGB(22, 23, 29),
	UI_SURFACE = Color3.fromRGB(29, 31, 38),
	UI_HOVER = Color3.fromRGB(38, 40, 48),
	UI_BORDER = Color3.fromRGB(55, 58, 68),
	UI_TEXT = Color3.fromRGB(238, 239, 244),
	UI_MUTED = Color3.fromRGB(145, 149, 162),
	UI_ACCENT = Color3.fromRGB(112, 126, 255),
}

local PLACE_CONFIG = {
	[10299594856] = { --// Event Floor
		DEFAULT_TARGET_PRIORITY = {
			[1] = "Karkinos the Visceral",
			[2] = "Water Style Disciple",
			[3] = "Drake the North Sea Commander",
		},
		WAYPOINTS = {
			Vector3.new(1773, 61, 336),
			Vector3.new(1778, 61, 536),
			Vector3.new(1810, 61, 703),
			Vector3.new(1652, 71, 809),
			Vector3.new(1652, 99, 735),
			Vector3.new(1600, 118, 737),
			Vector3.new(1605, 125, 770),
			Vector3.new(1533, 110, 778),
			Vector3.new(1466, 102, 726),
			Vector3.new(1427, 86, 664),
			Vector3.new(1410, 83, 712),
			Vector3.new(1455, 72, 720),
			Vector3.new(1533, 57, 588),
			Vector3.new(1474, 57, 553),
			Vector3.new(1442, 61, 517),
			Vector3.new(1438, 61, 504),
		},
		FARM_CENTER = Vector3.new(1442, 61, 517),
		FARM_RADIUS = 100,
		FARM_DEADZONE_CENTER = Vector3.zero,
		FARM_DEADZONE_RADIUS = 35,

		REACH_DISTANCE = 5,
		AUTOBLOCK = false,
	},
	[11987539001] = {
		DEFAULT_TARGET_PRIORITY = { --// F16
			[1] = "Goblin",
			[2] = "Leader Goblin",
		},
		WAYPOINTS = {
			Vector3.new(-2326, 163, -1412),
			Vector3.new(-2271, 148, -1298),
			Vector3.new(-2171, 168, -914),
			Vector3.new(-2044, 167, -429),
			Vector3.new(-1971, 157, 59),
			Vector3.new(-1831, 164, 168),
			Vector3.new(-1681, 184, 879),
			Vector3.new(-1520, 179, 1452),
			Vector3.new(-1409, 179, 1846),
			Vector3.new(-1365, 179, 1905),
			Vector3.new(-1364, 172, 1962),
			Vector3.new(-1363, 174, 2068),
			Vector3.new(-1437, 176, 2494),
			Vector3.new(-1654, 174, 2619),
			Vector3.new(-1792, 175, 2769),
		},
		FARM_CENTER = Vector3.new(-1715, 173, 2798),
		FARM_RADIUS = 200,
		FARM_DEADZONE_CENTER = Vector3.new(-1681, 173, 2821),
		FARM_DEADZONE_RADIUS = 35,

		REACH_DISTANCE = 5,
		AUTOBLOCK = true,
	}
}

function IsValidPlace(id: number)
	if PLACE_CONFIG[id] then
		return PLACE_CONFIG[id]
	end
	return false
end

local PlaceConfig = IsValidPlace(game.PlaceId)

local Character
local Humanoid
local RootPart

local Feature = {
	AutoFarm = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	AutoBlock = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	SafeCombat = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	AutoFind = {
		Enabled = false,
		Button = nil,
		Status = nil,
	},
	IgnoreFarmZone = {
		Enabled = false,
		Button = nil,
		Status = nil,
	},
	AutoPatrol = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	ReturnToFarmZone = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	AutoSkill = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	ResetOnBoostOut = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	ResetStats = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
}

local ClosestTarget = nil
local DEATH_COUNT    = 0
local LAST_MOB_VALIDATION_TIME     = 0
local TargetUnreachableSince   = nil
local TargetApproachPosition   = nil
local TargetApproachMob        = nil
local LastTargetRepositionTime = 0

local TargetPath             = nil
local TargetPathMob          = nil
local TargetPathDestination  = nil
local TargetPathWaypoint     = 1
local LastTargetPathTime     = 0
local TargetPathBlockedSince = nil

local ValidMobs = {}

local RETREATING         = false
local LastRetreatPosition      = nil
local LastRetreatCalculateTime = 0
local RetreatNoPositionSince   = nil

local LAST_ATTACK_TIME = 0
local LAST_SKILL_TIME  = 0

--// Potion Consume

local LAST_CONSUME_TIME = 0
local LAST_INTERACTION_TIME = 0
local LAST_TEXT_UPDATE_TIME = 0
local LAST_STUCK_TIME = 0
local LAST_STUCK_POSITION = nil

local CAHCED_SAFECOMBAT_POSITION = nil
local LAST_SAFECOMBAT_TIME       = 0

local BladePartCache   = {}
local CombatGroupCache = {}
local CombatBladeCache = {}

local LastDirectPathCheckTime = 0
local LastDirectPathTarget = nil
local LastDirectPathPosition = nil
local LastDirectPathBlocked = false

local LastDeadzoneEscapeTime = 0
local DeadzoneEscapePosition = nil

local PatrolPosition              = nil
local LastPatrolCalculateTime     = 0
local PatrolDirection             = nil
local PatrolPauseUntil            = 0
local PatrolLastPosition          = nil
local PatrolLastDistance           = 0
local FarmReturnPosition          = nil
local LastFarmReturnCalculateTime = 0

--// InputBindableFunction
local InputBindableFunction = nil
local BlockValue            = nil

local WaypointEnabled = true
local Enabled        = true
local Equipped       = false
local TargetCurrency = "Golden Shell"
local LastInventory  = nil
local EventCurrency  = 0

local BlockCache                = {}
local BlockEnabled              = true
local SafeCombatPositionEnabled = true

local FaceAttachment
local FaceOrientation

if PlaceConfig then
	CONFIG.TARGET_ENTITY_PRIORITY = PlaceConfig.DEFAULT_TARGET_PRIORITY
	Feature.AutoBlock.Enabled = PlaceConfig.AUTOBLOCK
	BlockEnabled = PlaceConfig.AUTOBLOCK
end

--// Character
function updateCharacter()
	Character = Player.Character

	if not Character then
		Humanoid = nil
		RootPart = nil
		return
	end

	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	RootPart = Character:FindFirstChild("HumanoidRootPart")

	if not FaceAttachment then
		FaceAttachment = Instance.new("Attachment")
		FaceAttachment.Name = "FaceGoblinAttachment"
		FaceAttachment.Parent = RootPart
	end

	if not FaceOrientation then
		FaceOrientation = Instance.new("AlignOrientation")
		FaceOrientation.Name = "FaceGoblin"
		FaceOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		FaceOrientation.Attachment0 = FaceAttachment
		FaceOrientation.RigidityEnabled = false
		FaceOrientation.Responsiveness = 25
		FaceOrientation.MaxTorque = math.huge
		FaceOrientation.Enabled = false
		FaceOrientation.Parent = RootPart
	end

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

--// Target Reposition
function ResetTargetReposition()
	TargetUnreachableSince   = nil
	TargetApproachPosition   = nil
	TargetApproachMob        = nil
	LastTargetRepositionTime = 0
	CAHCED_SAFECOMBAT_POSITION = nil
	LAST_SAFECOMBAT_TIME = 0
	LastDirectPathTarget = nil
	LastDirectPathPosition = nil
	CombatBladeCache = {}
end

--// Toggle Screen GUI
local ToggleScreenGUI
local ToggleContainer
local ToggleUIListLayout

function CreateToggleContainer()
	if not ToggleScreenGUI then
		ToggleScreenGUI = Instance.new("ScreenGui")
		ToggleScreenGUI.Name = "ToggleScreenGUI"
		ToggleScreenGUI.ResetOnSpawn = false
		ToggleScreenGUI.IgnoreGuiInset = true
		ToggleScreenGUI.Parent = PlayerGui
	end

	if not ToggleContainer then
		ToggleContainer = Instance.new("Frame")
		ToggleContainer.Name = "ToggleContainer"
		ToggleContainer.Size = UDim2.new(1, -10, 0, 48)
		ToggleContainer.Position = UDim2.fromOffset(0, 10)
		ToggleContainer.BackgroundTransparency = 1
		ToggleContainer.Parent = ToggleScreenGUI
	end

	if not ToggleUIListLayout then
		ToggleUIListLayout = Instance.new("UIListLayout")
		ToggleUIListLayout.Padding = UDim.new(0, 10)
		ToggleUIListLayout.FillDirection = Enum.FillDirection.Horizontal
		ToggleUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ToggleUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		ToggleUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		ToggleUIListLayout.Parent = ToggleContainer
	end
end
CreateToggleContainer()

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

	DEATH_COUNT += 1
	CONFIG.CURRENT_WAYPOINT_TARGET = 1
	ClosestTarget = nil
	InputBindableFunction = nil
	BlockValue = nil
	Equipped = false
	RETREATING = false
	LAST_ATTACK_TIME = 0
	LAST_SKILL_TIME = 0
	LAST_CONSUME_TIME = 0
	LAST_INTERACTION_TIME = 0
	LAST_STUCK_POSITION = nil
	FaceAttachment = nil
	FaceOrientation = nil

	if StaminaConnection then
		StaminaConnection:Disconnect()
		StaminaConnection = nil
	end

	table.clear(ValidMobs)
	table.clear(CombatGroupCache)
	table.clear(CombatBladeCache)
	table.clear(BladePartCache)

	task.delay(0.5, function()
		Equipped = false
	end)

	updateCharacter()
	ResetTargetReposition()
	CreateToggleContainer()
	RegenStamina()
end)

local function AutoRefillBooster()
	task.spawn(function()
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
	end)
end
AutoRefillBooster()

--// UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFarmUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
ScreenGui.Parent = PlayerGui

if IsValidPlace(game.PlaceId) then
	ScreenGui.DisplayOrder = 1
end

--// Theme
local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(1, 0.5)
Panel.Size = UDim2.fromScale(0.25, 0.70)
Panel.Position = UDim2.fromScale(0.95, 0.55)
Panel.BackgroundColor3 = CONFIG.UI_PANEL
Panel.BorderSizePixel = 0
Panel.ClipsDescendants = true
Panel.Parent = ScreenGui

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 1)
PanelCorner.Parent = Panel

local PanelStroke = Instance.new("UIStroke")
PanelStroke.Color = CONFIG.UI_BORDER
PanelStroke.Thickness = 1
PanelStroke.Transparency = 0.1
PanelStroke.Parent = Panel

--// Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.fromScale(1, 0.1346)
Header.BackgroundColor3 = CONFIG.UI_SURFACE
Header.BorderSizePixel = 0
Header.Parent = Panel

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0.25, 0)
HeaderCorner.Parent = Header

local HeaderMask = Instance.new("Frame")
HeaderMask.Size = UDim2.fromScale(1, 0.25)
HeaderMask.Position = UDim2.fromScale(0, 0)
HeaderMask.BackgroundColor3 = CONFIG.UI_SURFACE
HeaderMask.BorderSizePixel = 0
HeaderMask.Parent = Header

local Accent = Instance.new("Frame")
Accent.Size = UDim2.fromScale(0.0103, 0.6667)
Accent.Position = UDim2.fromScale(0.0359, 0.1667)
Accent.BackgroundColor3 = CONFIG.UI_ACCENT
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
Title.Text = "AUTO FARMING (F16)"
Title.TextColor3 = CONFIG.UI_TEXT
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
PlaceNameLabel.Text = MarketplaceService:GetProductInfoAsync(game.PlaceId).Name .. "  •  " .. CONFIG.VERSION
PlaceNameLabel.TextColor3 = CONFIG.UI_MUTED
PlaceNameLabel.TextScaled = true
PlaceNameLabel.Font = Enum.Font.GothamMedium
PlaceNameLabel.TextXAlignment = Enum.TextXAlignment.Left
PlaceNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
PlaceNameLabel.Parent = Header

local DragHint = Instance.new("TextLabel")
DragHint.Size = UDim2.fromScale(0.0821, 0.3889)
DragHint.Position = UDim2.fromScale(0.8897, 0.3056)
DragHint.BackgroundTransparency = 1
DragHint.Text = "⋮⋮"
DragHint.TextColor3 = CONFIG.UI_MUTED
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
Content.ScrollBarImageColor3 = CONFIG.UI_BORDER
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

--// Features
local FeaturesCollapsed = false

local FeaturesHeader = Instance.new("TextButton")
FeaturesHeader.Name = "FeaturesHeader"
FeaturesHeader.LayoutOrder = 1
FeaturesHeader.Size = UDim2.fromScale(0.9949, 0.0374)
FeaturesHeader.BackgroundTransparency = 1
FeaturesHeader.Text = "FEATURES  ▼"
FeaturesHeader.TextColor3 = CONFIG.UI_TEXT
FeaturesHeader.TextScaled = true
FeaturesHeader.Font = Enum.Font.GothamBold
FeaturesHeader.TextXAlignment = Enum.TextXAlignment.Left
FeaturesHeader.AutoButtonColor = false
FeaturesHeader.Parent = Content

local Features = Instance.new("Frame")
Features.Name = "Features"
Features.LayoutOrder = 2
Features.Size = UDim2.fromScale(0.9949, 0.19)
Features.BackgroundTransparency = 1
Features.Parent = Content

local FeaturesGrid = Instance.new("UIGridLayout")
FeaturesGrid.CellSize = UDim2.fromScale(0.5, 0.5)
FeaturesGrid.CellPadding = UDim2.fromScale(0, 0.005)
FeaturesGrid.SortOrder = Enum.SortOrder.LayoutOrder
FeaturesGrid.Parent = Features

function UpdateFeaturesLayout()
	if FeaturesCollapsed then
		return
	end

	local CardCount = 0

	for _, Child in Features:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= FeaturesGrid then
			CardCount += 1
		end
	end

	if CardCount <= 0 then
		Features.Size = UDim2.fromScale(0.9949, 0)
		return
	end

	local ColumnCount = 2
	local RowCount    = math.ceil(CardCount / ColumnCount)
	local BaseHeight  = 0.12
	local PaddingY    = 0.005
	local FeaturesHeight = (BaseHeight * RowCount) + (PaddingY * (RowCount - 1))

	Features.Size = UDim2.fromScale(0.9949, FeaturesHeight)

	local CellHeight = BaseHeight / FeaturesHeight
	FeaturesGrid.CellSize = UDim2.fromScale(0.5, CellHeight)
	FeaturesGrid.CellPadding = UDim2.fromScale(0, PaddingY / FeaturesHeight)
end

function SetFeaturesCollapsed(Collapsed)
	FeaturesCollapsed = Collapsed
	Features.Visible = not Collapsed
	FeaturesHeader.Text = Collapsed and "FEATURES  ▶" or "FEATURES  ▼"

	if not Collapsed then
		UpdateFeaturesLayout()
	end
end

function CreateFeatureCard(Name, Order)
	local Card = Instance.new("Frame")
	Card.Name = Name
	Card.LayoutOrder = Order
	Card.BackgroundColor3 = CONFIG.UI_SURFACE
	Card.BorderSizePixel = 0
	Card.Parent = Features

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0.02, 0)
	Corner.Parent = Card

	local Button = Instance.new("TextButton")
	Button.Name = "Toggle"
	Button.Size = UDim2.fromScale(0.94, 0.52)
	Button.Position = UDim2.fromScale(0.03, 0.08)
	Button.BackgroundColor3 = CONFIG.UI_HOVER
	Button.BorderSizePixel = 0
	Button.TextColor3 = CONFIG.UI_TEXT
	Button.TextScaled = true
	Button.Font = Enum.Font.GothamBold
	Button.AutoButtonColor = false
	Button.Parent = Card

	local ButtonCorner = Instance.new("UICorner")
	ButtonCorner.CornerRadius = UDim.new(0.12, 0)
	ButtonCorner.Parent = Button

	local Status = Instance.new("TextLabel")
	Status.Name = "Status"
	Status.Size = UDim2.fromScale(0.94, 0.24)
	Status.Position = UDim2.fromScale(0.03, 0.68)
	Status.BackgroundTransparency = 1
	Status.TextColor3 = CONFIG.UI_MUTED
	Status.TextScaled = true
	Status.Font = Enum.Font.GothamMedium
	Status.TextXAlignment = Enum.TextXAlignment.Left
	Status.TextTruncate = Enum.TextTruncate.AtEnd
	Status.Parent = Card

	return Button, Status
end

Feature.AutoFarm.Button, Feature.AutoFarm.Status = CreateFeatureCard("AutoFarm", 1)
Feature.AutoBlock.Button, Feature.AutoBlock.Status = CreateFeatureCard("AutoBlock", 2)
Feature.SafeCombat.Button, Feature.SafeCombat.Status = CreateFeatureCard("SafeCombat", 3)
Feature.AutoSkill.Button, Feature.AutoSkill.Status = CreateFeatureCard("AutoSkill", 4)
Feature.AutoFind.Button, Feature.AutoFind.Status = CreateFeatureCard("AutoFind", 5)
Feature.IgnoreFarmZone.Button, Feature.IgnoreFarmZone.Status = CreateFeatureCard("IgnoreFarmZone", 6)
Feature.AutoPatrol.Button, Feature.AutoPatrol.Status = CreateFeatureCard("AutoPatrol", 7)
Feature.ReturnToFarmZone.Button, Feature.ReturnToFarmZone.Status = CreateFeatureCard("ReturnToFarmZone", 8)
Feature.ResetOnBoostOut.Button, Feature.ResetOnBoostOut.Status = CreateFeatureCard("ResetOnBoostOut", 9)
Feature.ResetStats.Button, Feature.ResetStats.Status = CreateFeatureCard("ResetStats", 10)

FeaturesHeader.Activated:Connect(function()
	SetFeaturesCollapsed(not FeaturesCollapsed)
end)

UpdateFeaturesLayout()

Features.ChildAdded:Connect(function(Child)
	if Child:IsA("GuiObject") and Child ~= FeaturesGrid then
		task.defer(UpdateFeaturesLayout)
	end
end)

Features.ChildRemoved:Connect(function(Child)
	if Child:IsA("GuiObject") and Child ~= FeaturesGrid then
		task.defer(UpdateFeaturesLayout)
	end
end)

--// Live Status
local StatsCollapsed = false

local StatsHeader = Instance.new("TextButton")
StatsHeader.Name = "StatsHeader"
StatsHeader.LayoutOrder = 3
StatsHeader.Size = UDim2.fromScale(0.9949, 0.0374)
StatsHeader.BackgroundTransparency = 1
StatsHeader.Text = "LIVE STATUS  ▼"
StatsHeader.TextColor3 = CONFIG.UI_TEXT
StatsHeader.TextScaled = true
StatsHeader.Font = Enum.Font.GothamBold
StatsHeader.TextXAlignment = Enum.TextXAlignment.Left
StatsHeader.AutoButtonColor = false
StatsHeader.Parent = Content

local Stats = Instance.new("Frame")
Stats.Name = "Stats"
Stats.LayoutOrder = 4
Stats.Size = UDim2.fromScale(0.9949, 0.2766)
Stats.BackgroundTransparency = 1
Stats.Parent = Content

local StatsGrid = Instance.new("UIGridLayout")
StatsGrid.CellSize = UDim2.fromScale(0.5, 0.3108)
StatsGrid.CellPadding = UDim2.fromScale(0, 0.005)
StatsGrid.SortOrder = Enum.SortOrder.LayoutOrder
StatsGrid.Parent = Stats

function UpdateStatsLayout()
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

	StatsGrid.CellSize    = UDim2.fromScale(0.5, CellHeight)
	StatsGrid.CellPadding = UDim2.fromScale(0, PaddingY / StatsHeight)
end

function SetStatsCollapsed(Collapsed)
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

function CreateStat(Name, DefaultText, Order)
	local Card = Instance.new("Frame")
	Card.Name = Name
	Card.LayoutOrder = Order
	Card.BackgroundColor3 = CONFIG.UI_SURFACE
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
	Label.TextColor3 = CONFIG.UI_MUTED
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
	Value.TextColor3 = CONFIG.UI_TEXT
	Value.TextScaled = true
	Value.Font = Enum.Font.GothamBold
	Value.TextXAlignment = Enum.TextXAlignment.Left
	Value.TextTruncate = Enum.TextTruncate.AtEnd
	Value.Parent = Card

	return Value
end

function neededExp(lvl)
	lvl = lvl - 1

	local total = 9

	for i = 1, lvl do
		total = total + (6 * (i + 2))
	end

	return total
end

local PlaceIDLabel       = CreateStat("PLACE ID", tostring(game.PlaceId), 1)
local WalkSpeedLabel     = CreateStat("WALKSPEED", "0", 2)
local WayPointLabel      = CreateStat("WAYPOINT", "0/" .. (IsValidPlace(game.PlaceId) and #IsValidPlace(game.PlaceId).WAYPOINTS or 0) , 3)
local EventCurrencyLabel = CreateStat("EVENT CURRENCY", "0", 4)
local ServerAgeLabel     = CreateStat("PLAY TIME", "00:00:00", 5)
local PositionLabel      = CreateStat("POSITION", "--", 6)
local DeathLabel         = CreateStat("DEATH", "0", 7)
local ExpLabel           = CreateStat("EXP", "0/0", 8)

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

--// Enemy Priority
local PriorityHeader = Instance.new("TextLabel")
PriorityHeader.Name = "PriorityHeader"
PriorityHeader.LayoutOrder = 7
PriorityHeader.Size = UDim2.fromScale(0.9949, 0.0374)
PriorityHeader.BackgroundTransparency = 1
PriorityHeader.Text = "ENEMY PRIORITY"
PriorityHeader.TextColor3 = CONFIG.UI_TEXT
PriorityHeader.TextScaled = true
PriorityHeader.Font = Enum.Font.GothamBold
PriorityHeader.TextXAlignment = Enum.TextXAlignment.Left
PriorityHeader.Parent = Content

local PriorityHint = Instance.new("TextLabel")
PriorityHint.Name = "PriorityHint"
PriorityHint.LayoutOrder = 8
PriorityHint.Size = UDim2.fromScale(0.9949, 0.0318)
PriorityHint.BackgroundTransparency = 1
PriorityHint.Text = "▲ / ▼   Change targeting order"
PriorityHint.TextColor3 = CONFIG.UI_MUTED
PriorityHint.TextScaled = true
PriorityHint.Font = Enum.Font.GothamMedium
PriorityHint.TextXAlignment = Enum.TextXAlignment.Left
PriorityHint.Parent = Content

local PriorityRows = {}

local AddEnemyButton
local EnemyPicker
local EnemyPickerList
local EnemyPickerListLayout
local EnemyPickerPadding


function IsEntityInPriority(EntityName: string): boolean
	for _, PriorityName in ipairs(CONFIG.TARGET_ENTITY_PRIORITY) do
		if PriorityName == EntityName then
			return true
		end
	end

	return false
end

function CreatePriorityRow(Index)
	local Row = Instance.new("Frame")
	Row.Name = "Priority" .. Index
	Row.LayoutOrder = 8 + Index
	Row.Size = UDim2.fromScale(0.9949, 0.0822)
	Row.BackgroundColor3 = CONFIG.UI_SURFACE
	Row.BorderSizePixel = 0
	Row.Parent = Content

	local RowCorner = Instance.new("UICorner")
	RowCorner.CornerRadius = UDim.new(0.02, 0)
	RowCorner.Parent = Row

	local NumberLabel = Instance.new("TextLabel")
	NumberLabel.Name = "Number"
	NumberLabel.Size = UDim2.fromScale(0.0872, 1)
	NumberLabel.Position = UDim2.fromScale(0.0205, 0)
	NumberLabel.BackgroundTransparency = 1
	NumberLabel.TextColor3 = CONFIG.UI_ACCENT
	NumberLabel.TextScaled = true
	NumberLabel.Font = Enum.Font.GothamBold
	NumberLabel.TextXAlignment = Enum.TextXAlignment.Center
	NumberLabel.Parent = Row

	local NameLabel = Instance.new("TextLabel")
	NameLabel.Name = "Name"
	NameLabel.Size = UDim2.fromScale(0.5687, 1)
	NameLabel.Position = UDim2.fromScale(0.1231, 0)
	NameLabel.BackgroundTransparency = 1
	NameLabel.TextColor3 = CONFIG.UI_TEXT
	NameLabel.TextSize = 14
	NameLabel.Font = Enum.Font.GothamMedium
	NameLabel.TextXAlignment = Enum.TextXAlignment.Left
	NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	NameLabel.Parent = Row

	local RemoveButton = Instance.new("TextButton")
	RemoveButton.Name = "Remove"
	RemoveButton.Size = UDim2.fromScale(0.0821, 0.6818)
	RemoveButton.Position = UDim2.fromScale(0.708, 0.1591)
	RemoveButton.BackgroundColor3 = CONFIG.UI_HOVER
	RemoveButton.BorderSizePixel = 0
	RemoveButton.Text = "×"
	RemoveButton.TextColor3 = CONFIG.UI_TEXT
	RemoveButton.TextScaled = true
	RemoveButton.Font = Enum.Font.GothamBold
	RemoveButton.AutoButtonColor = true
	RemoveButton.Parent = Row

	local RemoveCorner = Instance.new("UICorner")
	RemoveCorner.CornerRadius = UDim.new(0.159, 0)
	RemoveCorner.Parent = RemoveButton

	local UpButton = Instance.new("TextButton")
	UpButton.Name = "Up"
	UpButton.Size = UDim2.fromScale(0.0821, 0.6818)
	UpButton.Position = UDim2.fromScale(0.8051, 0.1591)
	UpButton.BackgroundColor3 = CONFIG.UI_HOVER
	UpButton.BorderSizePixel = 0
	UpButton.Text = "▲"
	UpButton.TextColor3 = CONFIG.UI_TEXT
	UpButton.TextScaled = true
	UpButton.Font = Enum.Font.GothamBold
	UpButton.AutoButtonColor = true
	UpButton.Parent = Row

	local UpCorner = Instance.new("UICorner")
	UpCorner.CornerRadius = UDim.new(0.159, 0)
	UpCorner.Parent = UpButton

	local DownButton = Instance.new("TextButton")
	DownButton.Name = "Down"
	DownButton.Size = UDim2.fromScale(0.0821, 0.6818)
	DownButton.Position = UDim2.fromScale(0.9026, 0.1591)
	DownButton.BackgroundColor3 = CONFIG.UI_HOVER
	DownButton.BorderSizePixel = 0
	DownButton.Text = "▼"
	DownButton.TextColor3 = CONFIG.UI_TEXT
	DownButton.TextScaled = true
	DownButton.Font = Enum.Font.GothamBold
	DownButton.AutoButtonColor = true
	DownButton.Parent = Row

	local DownCorner = Instance.new("UICorner")
	DownCorner.CornerRadius = UDim.new(0.159, 0)
	DownCorner.Parent = DownButton

	PriorityRows[Index] = {
		Row    = Row,
		Number = NumberLabel,
		Name   = NameLabel,
		Remove = RemoveButton,
		Up     = UpButton,
		Down   = DownButton,
	}

	RemoveButton.Activated:Connect(function()
		if not CONFIG.TARGET_ENTITY_PRIORITY[Index] then
			return
		end

		local WasPickerVisible = EnemyPicker.Visible

		table.remove(CONFIG.TARGET_ENTITY_PRIORITY, Index)

		ClosestTarget = nil
		table.clear(ValidMobs)
		table.clear(CombatGroupCache)

		for _, RowData in PriorityRows do
			RowData.Row:Destroy()
		end

		table.clear(PriorityRows)

		for NewIndex = 1, #CONFIG.TARGET_ENTITY_PRIORITY do
			CreatePriorityRow(NewIndex)
		end

		AddEnemyButton.LayoutOrder = 9 + #CONFIG.TARGET_ENTITY_PRIORITY
		EnemyPicker.LayoutOrder = 10 + #CONFIG.TARGET_ENTITY_PRIORITY

		updatePriorityUI()

		if WasPickerVisible then
			EnemyPicker.Visible = true
			RefreshEnemyPicker()
		end
	end)

	UpButton.Activated:Connect(function()
		if Index <= 1 then
			return
		end

		CONFIG.TARGET_ENTITY_PRIORITY[Index], CONFIG.TARGET_ENTITY_PRIORITY[Index - 1] =
			CONFIG.TARGET_ENTITY_PRIORITY[Index - 1], CONFIG.TARGET_ENTITY_PRIORITY[Index]

		ClosestTarget = nil
		table.clear(ValidMobs)
		table.clear(CombatGroupCache)

		updatePriorityUI()

		if EnemyPicker.Visible then
			RefreshEnemyPicker()
		end
	end)

	DownButton.Activated:Connect(function()
		if Index >= #CONFIG.TARGET_ENTITY_PRIORITY then
			return
		end

		CONFIG.TARGET_ENTITY_PRIORITY[Index], CONFIG.TARGET_ENTITY_PRIORITY[Index + 1] =
			CONFIG.TARGET_ENTITY_PRIORITY[Index + 1], CONFIG.TARGET_ENTITY_PRIORITY[Index]

		ClosestTarget = nil
		table.clear(ValidMobs)
		table.clear(CombatGroupCache)

		updatePriorityUI()

		if EnemyPicker.Visible then
			RefreshEnemyPicker()
		end
	end)
end

function updatePriorityUI()
	for Index, RowData in PriorityRows do
		RowData.Number.Text = tostring(Index)
		RowData.Name.Text = CONFIG.TARGET_ENTITY_PRIORITY[Index] or "--"

		local IsFirst = Index == 1
		local IsLast  = Index == #CONFIG.TARGET_ENTITY_PRIORITY

		RowData.Up.Active = not IsFirst
		RowData.Down.Active = not IsLast

		RowData.Up.TextTransparency = IsFirst and 0.65 or 0
		RowData.Down.TextTransparency = IsLast and 0.65 or 0
	end
end

for Index = 1, #CONFIG.TARGET_ENTITY_PRIORITY do
	CreatePriorityRow(Index)
end

updatePriorityUI()

--// Add Enemy
AddEnemyButton = Instance.new("TextButton")
AddEnemyButton.Name = "AddEnemy"
AddEnemyButton.LayoutOrder = 9 + #CONFIG.TARGET_ENTITY_PRIORITY
AddEnemyButton.Size = UDim2.fromScale(0.9949, 0.0785)
AddEnemyButton.BackgroundColor3 = CONFIG.UI_SURFACE
AddEnemyButton.BorderSizePixel = 0
AddEnemyButton.Text = "+  ADD ENEMY TO PRIORITY"
AddEnemyButton.TextColor3 = CONFIG.UI_TEXT
AddEnemyButton.TextScaled = true
AddEnemyButton.Font = Enum.Font.GothamBold
AddEnemyButton.AutoButtonColor = true
AddEnemyButton.Parent = Content

local AddEnemyCorner = Instance.new("UICorner")
AddEnemyCorner.CornerRadius = UDim.new(0.205, 0)
AddEnemyCorner.Parent = AddEnemyButton

local AddEnemyStroke = Instance.new("UIStroke")
AddEnemyStroke.Color = CONFIG.UI_BORDER
AddEnemyStroke.Thickness = 1
AddEnemyStroke.Transparency = 0.3
AddEnemyStroke.Parent = AddEnemyButton

--// Enemy Picker
EnemyPicker = Instance.new("Frame")
EnemyPicker.Name = "EnemyPicker"
EnemyPicker.LayoutOrder = 10 + #CONFIG.TARGET_ENTITY_PRIORITY
EnemyPicker.Size = UDim2.fromScale(0.9949, 0)
EnemyPicker.BackgroundColor3 = CONFIG.UI_SURFACE
EnemyPicker.BorderSizePixel = 0
EnemyPicker.Visible = false
EnemyPicker.ClipsDescendants = true
EnemyPicker.Parent = Content

local EnemyPickerCorner = Instance.new("UICorner")
EnemyPickerCorner.CornerRadius = UDim.new(0.02, 0)
EnemyPickerCorner.Parent = EnemyPicker

local EnemyPickerStroke = Instance.new("UIStroke")
EnemyPickerStroke.Color = CONFIG.UI_BORDER
EnemyPickerStroke.Thickness = 1
EnemyPickerStroke.Transparency = 0.2
EnemyPickerStroke.Parent = EnemyPicker

EnemyPickerList = Instance.new("Frame")
EnemyPickerList.Name = "List"
EnemyPickerList.Size = UDim2.fromScale(0.958, 1)
EnemyPickerList.Position = UDim2.fromScale(0.021, 0)
EnemyPickerList.BackgroundTransparency = 1
EnemyPickerList.BorderSizePixel = 0
EnemyPickerList.Parent = EnemyPicker

EnemyPickerListLayout = Instance.new("UIGridLayout")
EnemyPickerListLayout.CellSize = UDim2.fromScale(1, 1)
EnemyPickerListLayout.CellPadding = UDim2.fromScale(0, 0.005)
EnemyPickerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
EnemyPickerListLayout.Parent = EnemyPickerList

EnemyPickerPadding = Instance.new("UIPadding")
EnemyPickerPadding.PaddingLeft = UDim.new(0, 5)
EnemyPickerPadding.PaddingRight = UDim.new(0, 5)
EnemyPickerPadding.Parent = EnemyPickerList

function GetItem(String, ItemName)
	for Item in string.gmatch(String, "([^,]+)") do
		local Name, Amount = string.match(Item, "([^|]+)|(.+)")

		if Name == ItemName then
			return Name, tonumber(Amount) or 0
		end
	end

	return ItemName, 0
end

function updateEventCurrency()
	local PlayerStats = Player:FindFirstChild("PlayerStats")

	if not PlayerStats then
		EventCurrency = 0
		EventCurrencyLabel.Text = "0"
		ExpLabel.Text = "0/0"
		LastInventory = nil
		return
	end

	local PlayerLvl = PlayerStats:FindFirstChild("Level")
	local PlayerExp = PlayerStats:FindFirstChild("EXP")

	if PlayerLvl and PlayerExp then
		ExpLabel.Text = PlayerExp.Value .. "/" .. neededExp(PlayerLvl.Value)
	else
		ExpLabel.Text = "0/0"
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

function updatePlayTime()
	local ServerAge = math.floor(workspace.DistributedGameTime)

	local Hours   = math.floor(ServerAge / 3600)
	local Minutes = math.floor((ServerAge % 3600) / 60)
	local Seconds = ServerAge % 60

	ServerAgeLabel.Text = string.format("%02d:%02d:%02d", Hours, Minutes, Seconds)
end

function updatePosition()
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

--// Detected Entity List
local DetectedEntities = {}

function GetDetectedEnemyEntities()
	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder then
		return {}
	end

	local EntitySet = {}

	for _, Mob in MobFolder:GetChildren() do
		if not Mob:IsA("Model") then
			continue
		end

		local Config = Mob:FindFirstChild("Config")

		if not Config then
			continue
		end

		local Entity = Config:FindFirstChild("Entity")

		if not Entity then
			continue
		end

		if typeof(Entity.Value) ~= "string" then
			continue
		end

		if Entity.Value == "" then
			continue
		end

		EntitySet[Entity.Value] = true
	end

	local Result = {}

	for EntityName in EntitySet do
		table.insert(Result, EntityName)
	end

	table.sort(Result, function(A, B)
		local APriority = table.find(CONFIG.TARGET_ENTITY_PRIORITY, A)
		local BPriority = table.find(CONFIG.TARGET_ENTITY_PRIORITY, B)

		if APriority and BPriority then
			return APriority < BPriority
		end

		if APriority then
			return true
		end

		if BPriority then
			return false
		end

		return A < B
	end)

	return Result
end

--// Auto Scale Enemy Picker
function UpdateEnemyPickerLayout()
	local CardCount = 0

	for _, Child in EnemyPickerList:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= EnemyPickerListLayout then
			CardCount += 1
		end
	end

	if CardCount <= 0 then
		EnemyPicker.Size = UDim2.fromScale(0.9949, 0)
		return
	end

	local ColumnCount = 1
	local RowCount    = math.ceil(CardCount / ColumnCount)
	local BaseHeight  = 0.0822
	local PaddingY    = 0.005

	local EnemyPickerHeight = (BaseHeight * RowCount) + (PaddingY * (RowCount - 1))

	EnemyPicker.Size = UDim2.fromScale(0.9949, EnemyPickerHeight)
	EnemyPickerList.Size = UDim2.fromScale(0.958, 1)

	local CellHeight = BaseHeight / EnemyPickerHeight

	EnemyPickerListLayout.CellSize = UDim2.fromScale(1, CellHeight)
	EnemyPickerListLayout.CellPadding = UDim2.fromScale(0, PaddingY / EnemyPickerHeight)
end

function CreateEnemyPickerRow(EntityName, Index)
	local Row = Instance.new("TextButton")
	Row.Name = "Enemy_" .. EntityName
	Row.LayoutOrder = Index
	Row.Size = UDim2.fromScale(1, 0.0822)
	Row.BackgroundColor3 = CONFIG.UI_PANEL
	Row.BorderSizePixel = 0
	Row.Text = ""
	Row.AutoButtonColor = false
	Row.Parent = EnemyPickerList

	local RowCorner = Instance.new("UICorner")
	RowCorner.CornerRadius = UDim.new(0.02, 0)
	RowCorner.Parent = Row

	local NameLabel = Instance.new("TextLabel")
	NameLabel.Name = "Name"
	NameLabel.Size = UDim2.fromScale(0.68, 1)
	NameLabel.Position = UDim2.fromScale(0.025, 0)
	NameLabel.BackgroundTransparency = 1
	NameLabel.Text = EntityName
	NameLabel.TextColor3 = CONFIG.UI_TEXT
	NameLabel.TextScaled = false
	NameLabel.TextSize = 14
	NameLabel.Font = Enum.Font.GothamMedium
	NameLabel.TextXAlignment = Enum.TextXAlignment.Left
	NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	NameLabel.Parent = Row

	local IsPriority = IsEntityInPriority(EntityName)

	local ActionLabel = Instance.new("TextLabel")
	ActionLabel.Name = "Action"
	ActionLabel.Size = UDim2.fromScale(0.265, 1)
	ActionLabel.Position = UDim2.fromScale(0.71, 0)
	ActionLabel.BackgroundTransparency = 1
	ActionLabel.Text = IsPriority and "✓  IN PRIORITY" or "+  ADD"
	ActionLabel.TextColor3 = IsPriority and CONFIG.UI_MUTED or CONFIG.UI_ACCENT
	ActionLabel.TextScaled = true
	ActionLabel.Font = Enum.Font.GothamBold
	ActionLabel.TextXAlignment = Enum.TextXAlignment.Right
	ActionLabel.Parent = Row

	Row.MouseEnter:Connect(function()
		Row.BackgroundColor3 = CONFIG.UI_HOVER
	end)

	Row.MouseLeave:Connect(function()
		Row.BackgroundColor3 = CONFIG.UI_PANEL
	end)

	Row.Activated:Connect(function()
		if IsEntityInPriority(EntityName) then
			return
		end

		table.insert(CONFIG.TARGET_ENTITY_PRIORITY, EntityName)

		ClosestTarget = nil
		table.clear(ValidMobs)

		for _, RowData in PriorityRows do
			RowData.Row:Destroy()
		end

		table.clear(PriorityRows)

		for NewIndex = 1, #CONFIG.TARGET_ENTITY_PRIORITY do
			CreatePriorityRow(NewIndex)
		end

		AddEnemyButton.LayoutOrder = 9 + #CONFIG.TARGET_ENTITY_PRIORITY
		EnemyPicker.LayoutOrder = 10 + #CONFIG.TARGET_ENTITY_PRIORITY

		updatePriorityUI()
		RefreshEnemyPicker()
	end)

	UpdateEnemyPickerLayout()
end

function ClearEnemyPicker()
	for _, Child in EnemyPickerList:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= EnemyPickerListLayout then
			Child:Destroy()
		end
	end
end

function RefreshEnemyPicker()
	if not EnemyPicker.Visible then
		return
	end

	ClearEnemyPicker()

	DetectedEntities = GetDetectedEnemyEntities()

	for Index, EntityName in ipairs(DetectedEntities) do
		CreateEnemyPickerRow(EntityName, Index)
	end

	task.defer(UpdateEnemyPickerLayout)
end

AddEnemyButton.Activated:Connect(function()
	EnemyPicker.Visible = not EnemyPicker.Visible

	if EnemyPicker.Visible then
		RefreshEnemyPicker()
	else
		EnemyPicker.Size = UDim2.fromScale(0.9949, 0)
	end
end)

--// Mob Watcher
local MobConnections       = {}
local MobFolderConnections = {}
local RefreshQueued        = false

function QueueEnemyPickerRefresh()
	if not EnemyPicker.Visible then
		return
	end

	if RefreshQueued then
		return
	end

	RefreshQueued = true

	task.defer(function()
		RefreshQueued = false

		if EnemyPicker.Visible then
			RefreshEnemyPicker()
		end
	end)
end

function DisconnectMob(Mob)
	local Connections = MobConnections[Mob]

	if not Connections then
		return
	end

	for _, Connection in Connections do
		Connection:Disconnect()
	end

	MobConnections[Mob] = nil
	BladePartCache[Mob] = nil
	CombatGroupCache[Mob] = nil
	CombatBladeCache[Mob] = nil
end

function WatchMob(Mob)
	if not Mob:IsA("Model") then
		return
	end

	DisconnectMob(Mob)

	local Connections = {}
	MobConnections[Mob] = Connections

	local function WatchConfig(Config)
		if not Config then
			return
		end

		local Entity = Config:FindFirstChild("Entity")

		if Entity and Entity:IsA("StringValue") then
			table.insert(Connections, Entity:GetPropertyChangedSignal("Value"):Connect(function()
				QueueEnemyPickerRefresh()

				ValidMobs[Mob] = nil

				if ClosestTarget == Mob and not IsEntityInPriority(Entity.Value) then
					ClosestTarget = nil
				end
			end))
		end

		table.insert(Connections, Config.ChildAdded:Connect(function(Child)
			if Child.Name ~= "Entity" then
				return
			end

			if Child:IsA("StringValue") then
				table.insert(Connections, Child:GetPropertyChangedSignal("Value"):Connect(function()
					QueueEnemyPickerRefresh()
					ValidMobs[Mob] = nil

					if ClosestTarget == Mob and not IsEntityInPriority(Child.Value) then
						ClosestTarget = nil
					end
				end))
			end

			QueueEnemyPickerRefresh()
			ValidMobs[Mob] = nil
		end))

		table.insert(Connections, Config.ChildRemoved:Connect(function(Child)
			if Child.Name == "Entity" then
				ValidMobs[Mob] = nil

				if ClosestTarget == Mob then
					ClosestTarget = nil
				end

				QueueEnemyPickerRefresh()
			end
		end))
	end

	local Config = Mob:FindFirstChild("Config")

	if Config then
		WatchConfig(Config)
	end

	table.insert(Connections, Mob.ChildAdded:Connect(function(Child)
		if Child.Name == "Config" then
			WatchConfig(Child)
			QueueEnemyPickerRefresh()
			ValidMobs[Mob] = nil
		end
	end))

	table.insert(Connections, Mob.ChildRemoved:Connect(function(Child)
		if Child.Name == "Config" then
			ValidMobs[Mob] = nil

			if ClosestTarget == Mob then
				ClosestTarget = nil
			end

			QueueEnemyPickerRefresh()
		end
	end))

	QueueEnemyPickerRefresh()
end

function WatchMobFolder(MobFolder)
	for _, Connection in MobFolderConnections do
		Connection:Disconnect()
	end

	table.clear(MobFolderConnections)

	for Mob in MobConnections do
		DisconnectMob(Mob)
	end

	for _, Mob in MobFolder:GetChildren() do
		WatchMob(Mob)
	end

	table.insert(MobFolderConnections, MobFolder.ChildAdded:Connect(function(Mob)
		WatchMob(Mob)
		QueueEnemyPickerRefresh()
	end))

	table.insert(MobFolderConnections, MobFolder.ChildRemoved:Connect(function(Mob)
		DisconnectMob(Mob)
		ValidMobs[Mob] = nil

		if ClosestTarget == Mob then
			ClosestTarget = nil
		end

		QueueEnemyPickerRefresh()
	end))
end

local ExistingMobFolder = workspace:FindFirstChild("Mobs")

if ExistingMobFolder then
	WatchMobFolder(ExistingMobFolder)
end

workspace.ChildAdded:Connect(function(Child)
	if Child.Name == "Mobs" then
		WatchMobFolder(Child)
		QueueEnemyPickerRefresh()
	end
end)

workspace.ChildRemoved:Connect(function(Child)
	if Child.Name ~= "Mobs" then
		return
	end

	for _, Connection in MobFolderConnections do
		Connection:Disconnect()
	end

	table.clear(MobFolderConnections)

	for Mob in MobConnections do
		DisconnectMob(Mob)
	end

	table.clear(ValidMobs)

	ClosestTarget = nil

	QueueEnemyPickerRefresh()
end)

--// GUI Toggle
local GUIToggle = Instance.new("TextButton")
GUIToggle.Name = "GUIToggle"
GUIToggle.Size = UDim2.new(0, 44, 0, 44)
GUIToggle.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
GUIToggle.BackgroundTransparency = 0.08
GUIToggle.BorderSizePixel = 0
GUIToggle.Text = "≡"
GUIToggle.LayoutOrder = 16
GUIToggle.TextTransparency = 0
GUIToggle.TextColor3 = CONFIG.UI_TEXT
GUIToggle.TextScaled = true
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
local Dragging      = false
local DragStart     = nil
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

--// Feature Buttons
function updateFeatureButtons()
	if Feature.AutoFarm.Enabled then
		Feature.AutoFarm.Button.Text = "●  AUTO FARMING  •  ENABLED"
		Feature.AutoFarm.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoFarm.Status.Text = "Farming system is active"
	else
		Feature.AutoFarm.Button.Text = "●  AUTO FARMING  •  DISABLED"
		Feature.AutoFarm.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoFarm.Status.Text = "Farming system is paused"
	end

	if Feature.AutoBlock.Enabled then
		Feature.AutoBlock.Button.Text = "●  AUTO BLOCKING  •  ENABLED"
		Feature.AutoBlock.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoBlock.Status.Text = "Automatic player blocking is active"
	else
		Feature.AutoBlock.Button.Text = "●  AUTO BLOCKING  •  DISABLED"
		Feature.AutoBlock.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoBlock.Status.Text = "Automatic player blocking is paused"
	end

	if Feature.SafeCombat.Enabled then
		Feature.SafeCombat.Button.Text = "●  SAFE COMBAT  •  ENABLED"
		Feature.SafeCombat.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.SafeCombat.Status.Text = "Safe positioning is active"
	else
		Feature.SafeCombat.Button.Text = "●  SAFE COMBAT  •  DISABLED"
		Feature.SafeCombat.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.SafeCombat.Status.Text = "Direct target movement is active"
	end

	if Feature.AutoFind.Enabled then
		Feature.AutoFind.Button.Text = "●  AUTO FIND  •  ENABLED"
		Feature.AutoFind.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoFind.Status.Text = "Ignoring waypoint route • finding mobs"
	else
		Feature.AutoFind.Button.Text = "●  AUTO FIND  •  DISABLED"
		Feature.AutoFind.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoFind.Status.Text = "Following waypoint route"
	end

	if Feature.IgnoreFarmZone.Enabled then
		Feature.IgnoreFarmZone.Button.Text = "●  IGNORE FARM ZONE  •  ENABLED"
		Feature.IgnoreFarmZone.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.IgnoreFarmZone.Status.Text = "Farm zone checks are bypassed"
	else
		Feature.IgnoreFarmZone.Button.Text = "●  IGNORE FARM ZONE  •  DISABLED"
		Feature.IgnoreFarmZone.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.IgnoreFarmZone.Status.Text = "Farm zone checks are active"
	end

	if Feature.AutoPatrol.Enabled then
		Feature.AutoPatrol.Button.Text = "●  AUTO PATROL  •  ENABLED"
		Feature.AutoPatrol.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoPatrol.Status.Text = "Patrolling safe open areas when no mob is found"
	else
		Feature.AutoPatrol.Button.Text = "●  AUTO PATROL  •  DISABLED"
		Feature.AutoPatrol.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoPatrol.Status.Text = "Stops when no target is available"
	end

	if Feature.ReturnToFarmZone.Enabled then
		Feature.ReturnToFarmZone.Button.Text = "●  RETURN TO FARMZONE  •  ENABLED"
		Feature.ReturnToFarmZone.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.ReturnToFarmZone.Status.Text = "Returns near Farm Center when no priority mob is found"
	else
		Feature.ReturnToFarmZone.Button.Text = "●  RETURN TO FARMZONE  •  DISABLED"
		Feature.ReturnToFarmZone.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.ReturnToFarmZone.Status.Text = "Keeps current patrol behavior when no target is found"
	end

	if Feature.AutoSkill.Enabled then
		Feature.AutoSkill.Button.Text = "●  AUTO SKILL  •  ENABLED"
		Feature.AutoSkill.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.AutoSkill.Status.Text = "Automatic use skill is active"
	else
		Feature.AutoSkill.Button.Text = "●  AUTO SKILL  •  DISABLED"
		Feature.AutoSkill.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.AutoSkill.Status.Text = "Automatic use skill is inactive"
	end

	if Feature.ResetOnBoostOut.Enabled then
		Feature.ResetOnBoostOut.Button.Text = "●  REFILL BOOSTER  •  ENABLED"
		Feature.ResetOnBoostOut.Button.BackgroundColor3 = Color3.fromRGB(60, 125, 50)
		Feature.ResetOnBoostOut.Status.Text = "Automatic reset when booster ends is active"
	else
		Feature.ResetOnBoostOut.Button.Text = "●  REFILL BOOSTER  •  DISABLED"
		Feature.ResetOnBoostOut.Button.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
		Feature.ResetOnBoostOut.Status.Text = "Automatic reset when booster ends is inactive"
	end

	Feature.ResetStats.Button.Text = "●  RESET STATS  •  [???]"
	Feature.ResetStats.Button.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	Feature.ResetStats.Status.Text = "Reset player stats"
end

Feature.AutoBlock.Button.Activated:Connect(function()
	Feature.AutoBlock.Enabled = not Feature.AutoBlock.Enabled
	BlockEnabled = Feature.AutoBlock.Enabled
	updateFeatureButtons()
end)

Feature.SafeCombat.Button.Activated:Connect(function()
	Feature.SafeCombat.Enabled = not Feature.SafeCombat.Enabled
	SafeCombatPositionEnabled = Feature.SafeCombat.Enabled
	ResetTargetReposition()
	updateFeatureButtons()
end)

Feature.AutoFind.Button.Activated:Connect(function()
	Feature.AutoFind.Enabled = not Feature.AutoFind.Enabled
	WaypointEnabled = not Feature.AutoFind.Enabled
	ClosestTarget = nil
	table.clear(ValidMobs)
	table.clear(CombatGroupCache)
	ResetTargetReposition()
	UpdateValidMobs()
	ClosestTarget = GetClosestGoblin()
	updateFeatureButtons()
end)

Feature.IgnoreFarmZone.Button.Activated:Connect(function()
	Feature.IgnoreFarmZone.Enabled = not Feature.IgnoreFarmZone.Enabled
	ClosestTarget = nil
	table.clear(ValidMobs)
	table.clear(CombatGroupCache)
	ResetTargetReposition()
	DeadzoneEscapePosition = nil
	PatrolPosition = nil
	LastPatrolCalculateTime = 0
	FarmReturnPosition = nil
	LastFarmReturnCalculateTime = 0

	UpdateValidMobs()
	ClosestTarget = GetClosestGoblin()
	updateFeatureButtons()
end)

Feature.AutoPatrol.Button.Activated:Connect(function()
	Feature.AutoPatrol.Enabled = not Feature.AutoPatrol.Enabled
	PatrolPosition = nil
	LastPatrolCalculateTime = 0
	PatrolDirection = nil
	PatrolPauseUntil = 0
	PatrolLastPosition = nil
	PatrolLastDistance = 0
	updateFeatureButtons()
end)

Feature.ReturnToFarmZone.Button.Activated:Connect(function()
	Feature.ReturnToFarmZone.Enabled = not Feature.ReturnToFarmZone.Enabled
	FarmReturnPosition = nil
	LastFarmReturnCalculateTime = 0
	updateFeatureButtons()
end)

Feature.AutoSkill.Button.Activated:Connect(function()
	Feature.AutoSkill.Enabled = not Feature.AutoSkill.Enabled
	updateFeatureButtons()
end)

Feature.ResetOnBoostOut.Button.Activated:Connect(function()
	Feature.ResetOnBoostOut.Enabled = not Feature.ResetOnBoostOut.Enabled
	updateFeatureButtons()
end)

Feature.ResetStats.Button.Activated:Connect(function()
	Feature.ResetStats.Enabled = not Feature.ResetStats.Enabled
	updateFeatureButtons()

	task.spawn(function()
		local PlayerStats = Player:WaitForChild("PlayerStats")
		local StatsEvent = Replicated:FindFirstChild("StatsEvent", true)
		if not StatsEvent then
			return print(`StatsEvent is not valid.`)
		end
		local Stats = {
			"Vitality",
			"Agility",
			"Luck",
			"Strength",
			"Defense",
		}
		for _, stat in ipairs(Stats) do
			if PlayerStats[stat].Value >= 500 then
				StatsEvent:FireServer(stat, -1)
				task.delay(0.35, function()
					StatsEvent:FireServer(stat, 0)
				end)
			else
				StatsEvent:FireServer(stat, 0)
			end
		end
	end)
end)

--// Farm Button
function updateButton()
	Feature.AutoFarm.Enabled = Enabled
	updateFeatureButtons()
end

Toggle = Feature.AutoFarm.Button
Status = Feature.AutoFarm.Status

Toggle.Activated:Connect(function()
	Enabled = not Enabled
	Feature.AutoFarm.Enabled = Enabled
	updateFeatureButtons()
end)

updateFeatureButtons()
updatePosition()

--// Teleport
function TeleportToPlace(placeId: number?)
	local TeleportService = game:GetService("TeleportService")

	TeleportService:Teleport(placeId or game.PlaceId, Player)
end

--// Block
function isBlocked(userId)
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

function promptBlockPlayer(plr)
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

	task.delay(CONFIG.BLOCK_COOLDOWN, function()
		BlockCache[userId] = nil
	end)
end

--// Farm Area Check
function IsInsideFarmArea(Position)
	if Feature.IgnoreFarmZone.Enabled or not PlaceConfig then
		return true
	end

	if not Position then
		return false
	end

	local Offset = Position - PlaceConfig.FARM_CENTER
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if Distance > PlaceConfig.FARM_RADIUS then
		return false
	end

	local DeadzoneOffset = Position - PlaceConfig.FARM_DEADZONE_CENTER
	local DeadzoneDistance = Vector3.new(DeadzoneOffset.X, 0, DeadzoneOffset.Z).Magnitude

	if DeadzoneDistance <= PlaceConfig.FARM_DEADZONE_RADIUS then
		return false
	end

	return true
end

--// Water Check


function IsWaterAtPosition(Position, IgnoreModel)
	if not Position then
		return false
	end

	local FilterInstances = {
		Character,
	}

	if IgnoreModel then
		table.insert(FilterInstances, IgnoreModel)
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = FilterInstances

	local Origin    = Position + Vector3.new(0, 10, 0)
	local Direction = Vector3.new(0, -30, 0)

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result and Result.Material == Enum.Material.Water
end

function IsPathThroughWater(TargetPosition)
	if not RootPart then
		return true
	end

	local Origin   = RootPart.Position
	local Offset   = TargetPosition - Origin
	local Distance = Offset.Magnitude

	if Distance <= 0 then
		return IsWaterAtPosition(TargetPosition)
	end

	local Direction = Offset.Unit

	for DistanceTravelled = 0, Distance, CONFIG.WATER_SAMPLE_DISTANCE do
		local Position = Origin + Direction * DistanceTravelled

		if IsWaterAtPosition(Position) then
			return true
		end
	end

	return IsWaterAtPosition(TargetPosition)
end

--// Deadzone Path Check


function IsPathThroughDeadzone(TargetPosition)
	if Feature.IgnoreFarmZone.Enabled then
		return false
	end

	if not RootPart or not TargetPosition or not PlaceConfig then
		return false
	end

	local Origin   = RootPart.Position
	local Offset   = TargetPosition - Origin
	local Distance = Offset.Magnitude

	if Distance <= 0 then
		local DeadzoneOffset = Origin - PlaceConfig.FARM_DEADZONE_CENTER
		local DeadzoneDistance = Vector3.new(DeadzoneOffset.X, 0, DeadzoneOffset.Z).Magnitude
		return DeadzoneDistance <= PlaceConfig.FARM_DEADZONE_RADIUS
	end

	local Direction = Offset.Unit

	for DistanceTravelled = 0, Distance, CONFIG.DEADZONE_SAMPLE_DISTANCE do
		local Position = Origin + Direction * DistanceTravelled
		local DeadzoneOffset = Position - PlaceConfig.FARM_DEADZONE_CENTER
		local DeadzoneDistance = Vector3.new(DeadzoneOffset.X, 0, DeadzoneOffset.Z).Magnitude

		if DeadzoneDistance <= PlaceConfig.FARM_DEADZONE_RADIUS then
			return true
		end
	end

	return false
end

--// Line Of Sight
function CanSeeGoblin(Goblin)
	if not RootPart or not Goblin then
		return false
	end

	local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

	if not MobRoot then
		return false
	end

	local Origin    = RootPart.Position
	local Direction = MobRoot.Position - Origin

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
	}

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	if not Result then
		return true
	end

	return Result.Instance:IsDescendantOf(Goblin)
end

--// Target Lock Validation
function IsTargetLockValid(Mob)
	if not Mob or not Mob:IsA("Model") then
		return false
	end

	if not Mob:IsDescendantOf(workspace) then
		return false
	end

	if not RootPart then
		return false
	end

	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder or not Mob:IsDescendantOf(MobFolder) then
		return false
	end

	local Config = Mob:FindFirstChild("Config")

	if not Config then
		return false
	end

	local Entity = Config:FindFirstChild("Entity")

	if not Entity or not Entity:IsA("StringValue") then
		return false
	end

	if not IsEntityInPriority(Entity.Value) then
		return false
	end

	local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
	local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

	if not MobHumanoid or not MobRoot then
		return false
	end

	if MobHumanoid.Health <= 0 then
		return false
	end

	local Offset   = MobRoot.Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if CONFIG.DISTANCE_Y_CALCULATE then
		Distance = Offset.Magnitude
	end

	if Distance > CONFIG.MOB_DETECTION_DISTANCE then
		return false
	end

	if not IsInsideFarmArea(MobRoot.Position) then
		return false
	end

	if IsWaterAtPosition(MobRoot.Position, Mob) then
		return false
	end

	return true
end

--// Validate Mob
function IsValidMob(Mob)
	if not Mob or not Mob:IsA("Model") then
		return false
	end

	if not Mob:IsDescendantOf(workspace) then
		return false
	end

	if not RootPart then
		return false
	end

	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder or not Mob:IsDescendantOf(MobFolder) then
		return false
	end

	local Config = Mob:FindFirstChild("Config")

	if not Config then
		return false
	end

	local Entity = Config:FindFirstChild("Entity")

	if not Entity or not Entity:IsA("StringValue") then
		return false
	end

	if not IsEntityInPriority(Entity.Value) then
		return false
	end

	local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
	local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

	if not MobHumanoid or not MobRoot then
		return false
	end

	if MobHumanoid.Health <= 0 then
		return false
	end

	local Offset   = MobRoot.Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if CONFIG.DISTANCE_Y_CALCULATE then
		Distance = Offset.Magnitude
	end

	if Distance > CONFIG.MOB_DETECTION_DISTANCE then
		return false
	end

	if not IsInsideFarmArea(MobRoot.Position) then
		return false
	end

	if IsWaterAtPosition(MobRoot.Position, Mob) then
		return false
	end

	--// Do not use line-of-sight or path checks here.
	--// A mob can temporarily fail those checks while it is still a valid
	--// combat target. Path/visibility checks are handled by movement logic.
	return true
end

--// Update Realtime Valid Mob List
function UpdateValidMobs()
	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder or not RootPart then
		table.clear(ValidMobs)

		if ClosestTarget and not IsTargetLockValid(ClosestTarget) then
			ClosestTarget = nil
		end

		return
	end

	local CurrentMobs = {}

	for _, Mob in MobFolder:GetChildren() do
		CurrentMobs[Mob] = true

		if IsValidMob(Mob) then
			ValidMobs[Mob] = true
		else
			ValidMobs[Mob] = nil
		end
	end

	for Mob in ValidMobs do
		if not CurrentMobs[Mob] then
			ValidMobs[Mob] = nil
		end
	end

	if ClosestTarget and not IsTargetLockValid(ClosestTarget) then
		ClosestTarget = nil
	end
end

--// Closest Visible Goblin
function GetMobPriority(Mob)
	local Config = Mob:FindFirstChild("Config")

	if not Config then
		return nil
	end

	local Entity = Config:FindFirstChild("Entity")

	if not Entity then
		return nil
	end

	return table.find(CONFIG.TARGET_ENTITY_PRIORITY, Entity.Value)
end

function GetMobDistance(Mob)
	local MobRoot = Mob:FindFirstChild("HumanoidRootPart")

	if not MobRoot or not RootPart then
		return math.huge
	end

	local Offset = MobRoot.Position - RootPart.Position

	if CONFIG.DISTANCE_Y_CALCULATE then
		return Offset.Magnitude
	end

	return Vector3.new(Offset.X, 0, Offset.Z).Magnitude
end

function GetClosestGoblin()
	if not RootPart then
		return nil
	end

	local BestTarget   = nil
	local BestPriority = math.huge
	local BestDistance = math.huge

	--// Primary source: realtime validated mob cache.
	for Mob in ValidMobs do
		if not IsTargetLockValid(Mob) then
			ValidMobs[Mob] = nil
			continue
		end

		local Priority = GetMobPriority(Mob)
		local Distance = GetMobDistance(Mob)

		if Priority
			and (Priority < BestPriority
				or (Priority == BestPriority and Distance < BestDistance))
		then
			BestPriority = Priority
			BestDistance = Distance
			BestTarget = Mob
		end
	end

	--// Fallback: scan the actual Mobs folder.
	--// This covers spawn/replication timing and prevents a transient
	--// validation failure from making the target completely invisible.
	if not BestTarget then
		local MobFolder = workspace:FindFirstChild("Mobs")

		if MobFolder then
			for _, Mob in MobFolder:GetChildren() do
				if IsTargetLockValid(Mob) then
					local Priority = GetMobPriority(Mob)
					local Distance = GetMobDistance(Mob)

					if Priority
						and (Priority < BestPriority
							or (Priority == BestPriority and Distance < BestDistance))
					then
						BestPriority = Priority
						BestDistance = Distance
						BestTarget = Mob
					end
				end
			end
		end
	end

	return BestTarget
end

--// Detect a secondary mob approaching from the side or behind.
--// The primary target is never replaced by this system.
function GetNearbyThreatMob(TargetMob)
	if not RootPart or not TargetMob then
		return nil
	end

	local BestThreat = nil
	local BestDistance = math.huge
	local LookVector = Vector3.new(RootPart.CFrame.LookVector.X, 0, RootPart.CFrame.LookVector.Z)

	if LookVector.Magnitude <= 0.01 then
		return nil
	end

	LookVector = LookVector.Unit

	for Mob in ValidMobs do
		if Mob == TargetMob then
			continue
		end

		local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
		local MobRoot = Mob:FindFirstChild("HumanoidRootPart")

		if not MobHumanoid or not MobRoot or MobHumanoid.Health <= 0 then
			continue
		end

		local Offset = MobRoot.Position - RootPart.Position
		local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)
		local Distance = HorizontalOffset.Magnitude

		if Distance <= 0.01 or Distance > CONFIG.THREAT_DETECTION_DISTANCE then
			continue
		end

		local Direction = HorizontalOffset.Unit
		local Dot = math.clamp(LookVector:Dot(Direction), -1, 1)
		local Angle = math.deg(math.acos(Dot))

		--// 0 = directly in front, 90 = side, 180 = behind.
		if Angle >= CONFIG.THREAT_ANGLE and Distance < BestDistance then
			BestThreat = Mob
			BestDistance = Distance
		end
	end

	return BestThreat, BestDistance
end

function GetThreatEscapePosition(TargetMob, ThreatMob)
	if not RootPart or not ThreatMob then
		return nil
	end

	local ThreatRoot = ThreatMob:FindFirstChild("HumanoidRootPart")
	local TargetRoot = TargetMob and TargetMob:FindFirstChild("HumanoidRootPart")

	if not ThreatRoot or not TargetRoot then
		return nil
	end

	local Origin = RootPart.Position
	local Away = Origin - ThreatRoot.Position
	local AwayDirection = Vector3.new(Away.X, 0, Away.Z)

	if AwayDirection.Magnitude <= 0.01 then
		return nil
	end

	AwayDirection = AwayDirection.Unit

	--// Try several directions instead of blindly retreating straight back.
	--// This prevents Safe Distance from pushing the player into a wall,
	--// corner, or narrow gap when the direct retreat path is blocked.
	local Directions = {
		AwayDirection,
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(45)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-45)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(90)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-90)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(135)):VectorToWorldSpace(AwayDirection),
		CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-135)):VectorToWorldSpace(AwayDirection),
	}

	local CurrentTargetDistance = GetHorizontalDistance(Origin, TargetRoot.Position)
	local BestPosition = nil
	local BestScore = math.huge

	for Index, Direction in ipairs(Directions) do
		Direction = Vector3.new(Direction.X, 0, Direction.Z)

		if Direction.Magnitude <= 0.01 then
			continue
		end

		Direction = Direction.Unit

		--// Prefer shorter movement when multiple escape directions are safe.
		local Candidate = Origin + Direction * CONFIG.THREAT_ESCAPE_DISTANCE

		if not IsInsideFarmArea(Candidate)
			or IsWaterAtPosition(Candidate, TargetMob)
			or IsPathThroughWater(Candidate)
			or IsPathThroughDeadzone(Candidate)
			or IsPathThroughBladeGroupDanger(Candidate, TargetMob)
			or not IsEscapePathClear(Candidate)
		then
			continue
		end

		--// Keep enough space from the threat while avoiding a huge
		--// increase in distance from the primary target.
		local ThreatDistance = GetHorizontalDistance(Candidate, ThreatRoot.Position)
		local TargetDistance = GetHorizontalDistance(Candidate, TargetRoot.Position)

		--// Penalize positions that move much farther from the primary target.
		local TargetDistancePenalty = math.max(0, TargetDistance - CurrentTargetDistance) * 0.35

		--// Prefer directions closer to directly away from the threat.
		local DirectionPenalty = (1 - math.clamp(AwayDirection:Dot(Direction), -1, 1)) * 2

		local Score = TargetDistancePenalty + DirectionPenalty + Index * 0.01

		if ThreatDistance > CONFIG.THREAT_DETECTION_DISTANCE
			and Score < BestScore
		then
			BestScore = Score
			BestPosition = Candidate
		elseif ThreatDistance > CONFIG.ENEMY_ATTACK_SAFE_DISTANCE
			and Score < BestScore
		then
			BestScore = Score
			BestPosition = Candidate
		end
	end

	return BestPosition
end

--// ============================================================
--// COMBAT BLADE SYSTEM
--// ============================================================

function GetHorizontalDistance(PositionA, PositionB)
	local Offset = PositionA - PositionB

	return Vector3.new(
		Offset.X,
		0,
		Offset.Z
	).Magnitude
end

--// Get every BladePart inside one Mob.
function GetBladeParts(Mob)
	if not Mob then
		return {}
	end

	local now = os.clock()
	local Cached = BladePartCache[Mob]

	if Cached
		and now - Cached.Time < CONFIG.BLADE_PART_CACHE_INTERVAL
	then
		return Cached.Parts
	end

	local BladeParts = {}

	for _, Descendant in Mob:GetDescendants() do
		if Descendant:IsA("BasePart") and Descendant.Name == "BladePart" then
			table.insert(BladeParts, Descendant)
		end
	end

	BladePartCache[Mob] = {
		Time  = now,
		Parts = BladeParts,
	}

	return BladeParts
end

--// Finds the closest point on an actual BladePart box.
--// This is much more accurate than simply using BladePart.Position.
function GetClosestPointOnBlade(BladePart, Position)
	if not BladePart or not BladePart:IsA("BasePart") then
		return nil, math.huge
	end

	local LocalPosition = BladePart.CFrame:PointToObjectSpace(Position)
	local HalfSize      = BladePart.Size * 0.5

	local ClosestLocal = Vector3.new(
		math.clamp(LocalPosition.X, -HalfSize.X, HalfSize.X),
		math.clamp(LocalPosition.Y, -HalfSize.Y, HalfSize.Y),
		math.clamp(LocalPosition.Z, -HalfSize.Z, HalfSize.Z)
	)

	local ClosestWorld = BladePart.CFrame:PointToWorldSpace(ClosestLocal)
	local Distance     = (Position - ClosestWorld).Magnitude

	return ClosestWorld, Distance
end

function GetBladeDangerDistance()
	return CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + CONFIG.ENEMY_BLADE_PADDING
end

--// Return all mobs around the current combat group.
function GetNearbyCombatMobs(TargetMob)
	if not TargetMob then
		return {}
	end

	local TargetRoot = TargetMob:FindFirstChild("HumanoidRootPart")

	if not TargetRoot then
		return {}
	end

	local now = os.clock()
	local Cached = CombatGroupCache[TargetMob]

	if Cached
		and now - Cached.Time < CONFIG.COMBAT_GROUP_CACHE_INTERVAL
	then
		return Cached.Mobs
	end

	local NearbyMobs = {
		[TargetMob] = true,
	}

	local TargetPosition = TargetRoot.Position

	for Mob in ValidMobs do
		if Mob == TargetMob then
			continue
		end

		if not Mob:IsDescendantOf(workspace) then
			continue
		end

		local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
		local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

		if not MobHumanoid
			or not MobRoot
			or MobHumanoid.Health <= 0
		then
			continue
		end

		local Distance = GetHorizontalDistance(TargetPosition, MobRoot.Position)

		if Distance <= CONFIG.GROUP_DANGER_DISTANCE then
			NearbyMobs[Mob] = true
		end
	end

	--// Also inspect Mobs directly from workspace so a newly spawned
	--// mob that has not entered ValidMobs yet can still be considered.
	local MobFolder = workspace:FindFirstChild("Mobs")

	if MobFolder then
		for _, Mob in MobFolder:GetChildren() do
			if NearbyMobs[Mob] or not Mob:IsA("Model") then
				continue
			end

			local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
			local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

			if not MobHumanoid
				or not MobRoot
				or MobHumanoid.Health <= 0
			then
				continue
			end

			local Config = Mob:FindFirstChild("Config")
			local Entity = Config and Config:FindFirstChild("Entity")

			if not Entity
				or not Entity:IsA("StringValue")
				or not IsEntityInPriority(Entity.Value)
			then
				continue
			end

			local Distance = GetHorizontalDistance(TargetPosition, MobRoot.Position)

			if Distance <= CONFIG.GROUP_DANGER_DISTANCE then
				NearbyMobs[Mob] = true
			end
		end
	end

	local Result = {}

	for Mob in NearbyMobs do
		table.insert(Result, Mob)
	end

	CombatGroupCache[TargetMob] = {
		Time = now,
		Mobs = Result,
	}

	return Result
end

--// Return cached BladeParts for the entire combat group.
function GetCombatBladeParts(TargetMob)
	if not TargetMob then
		return {}
	end

	local now = os.clock()
	local Cached = CombatBladeCache[TargetMob]

	if Cached
		and now - Cached.Time < CONFIG.COMBAT_GROUP_CACHE_INTERVAL
	then
		return Cached.Parts
	end

	local BladeParts = {}

	for _, Mob in GetNearbyCombatMobs(TargetMob) do
		for _, BladePart in GetBladeParts(Mob) do
			if BladePart:IsDescendantOf(workspace) then
				table.insert(BladeParts, BladePart)
			end
		end
	end

	CombatBladeCache[TargetMob] = {
		Time  = now,
		Parts = BladeParts,
	}

	return BladeParts
end

--// Checks every BladePart in the combat group.
function GetBladeDangerData(TargetMob)
	if not RootPart or not TargetMob then
		return Vector3.zero, math.huge, nil
	end

	local PushDirection            = Vector3.zero
	local ClosestEffectiveDistance = math.huge
	local ClosestBlade             = nil
	local DangerDistance           = GetBladeDangerDistance()

	for _, BladePart in GetCombatBladeParts(TargetMob) do
		local ClosestPoint, Distance = GetClosestPointOnBlade(BladePart, RootPart.Position)

		if not ClosestPoint then
			continue
		end

		local EffectiveDistance = Distance - DangerDistance

		if EffectiveDistance < ClosestEffectiveDistance then
			ClosestEffectiveDistance = EffectiveDistance
			ClosestBlade = BladePart
		end

		if Distance <= DangerDistance then
			local Offset = RootPart.Position - ClosestPoint
			local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)

			if HorizontalOffset.Magnitude > 0.01 then
				local Strength = math.max(DangerDistance - Distance, 0.1)
				PushDirection += HorizontalOffset.Unit * Strength
			end
		end
	end

	if PushDirection.Magnitude > 0.01 then
		PushDirection = PushDirection.Unit
	end

	return PushDirection, ClosestEffectiveDistance, ClosestBlade
end

--// Check whether a position is safe from every BladePart
--// in the nearby enemy group.
function IsPositionSafeFromBladeGroup(Position, TargetMob)
	if not Position or not TargetMob then
		return true
	end

	local DangerDistance = GetBladeDangerDistance()

	for _, BladePart in GetCombatBladeParts(TargetMob) do
		local _, Distance = GetClosestPointOnBlade(BladePart, Position)

		if Distance <= DangerDistance then
			return false
		end
	end

	return true
end

--// Checks whether a movement line crosses a BladePart danger zone.
function IsPathThroughBladeGroupDanger(TargetPosition, TargetMob)
	if not RootPart or not TargetPosition or not TargetMob then
		return false
	end

	local Origin = RootPart.Position
	local Offset = TargetPosition - Origin
	local Distance = Offset.Magnitude
	local DangerDistance = GetBladeDangerDistance()
	local BladeParts = GetCombatBladeParts(TargetMob)

	if Distance <= 0.01 then
		for _, BladePart in BladeParts do
			local _, BladeDistance = GetClosestPointOnBlade(BladePart, TargetPosition)

			if BladeDistance <= DangerDistance then
				return true
			end
		end

		return false
	end

	local Direction = Offset.Unit
	local SampleDistance = 2

	for DistanceTravelled = 0, Distance, SampleDistance do
		local Position = Origin + Direction * DistanceTravelled

		for _, BladePart in BladeParts do
			local _, BladeDistance = GetClosestPointOnBlade(BladePart, Position)

			if BladeDistance <= DangerDistance then
				return true
			end
		end
	end

	return false
end

--// Get a safe combat position around the Target.
function IsSafeCombatPathClear(TargetPosition, Goblin)
	if not RootPart or not TargetPosition then
		return false
	end

	local Origin    = RootPart.Position
	local Direction = TargetPosition - Origin

	if Direction.Magnitude <= 0.01 then
		return true
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		Goblin,
	}

	if workspace:Raycast(Origin, Direction, RaycastParams) then
		return false
	end

	local BlockcastSize = Vector3.new(
		math.max(RootPart.Size.X, 2.5),
		math.max(RootPart.Size.Y, 4),
		math.max(RootPart.Size.Z, 2.5)
	)

	return workspace:Blockcast(
		CFrame.new(Origin),
		BlockcastSize,
		Direction,
		RaycastParams
	) == nil
end

--// Get a safe combat position around the Target.
--// Cheap checks are performed first. Expensive path/visibility checks are
--// only run for the best few candidates to reduce physics-query spikes.
function GetSafeCombatPosition(TargetMob)
	if not RootPart or not TargetMob then
		return nil
	end

	local TargetRoot = TargetMob:FindFirstChild("HumanoidRootPart")
	if not TargetRoot then
		return nil
	end

	local Offset = RootPart.Position - TargetRoot.Position
	local CurrentDirection = Vector3.new(Offset.X, 0, Offset.Z)

	if CurrentDirection.Magnitude <= 0.01 then
		CurrentDirection = Vector3.zAxis
	else
		CurrentDirection = CurrentDirection.Unit
	end

	local CombatDistance = CONFIG.PLAYER_ATTACK_DISTANCE
	local LastAttacker = TargetMob:FindFirstChild("LastAttacker")

	if LastAttacker and LastAttacker.Value ~= Player then
		CombatDistance /= 2
	end

	for _, BladePart in GetCombatBladeParts(TargetMob) do
		local BladeOffset = BladePart.Position - TargetRoot.Position
		local HorizontalBladeOffset = Vector3.new(BladeOffset.X, 0, BladeOffset.Z)
		local BladeDistance = HorizontalBladeOffset.Magnitude
		CombatDistance = math.max(
			CombatDistance,
			BladeDistance + GetBladeDangerDistance()
		)
	end

	local Candidates = {}
	local DirectionCount = CONFIG.SAFE_COMBAT_DIRECTIONS

	for Index = 0, DirectionCount - 1 do
		local Angle = (math.pi * 2 / DirectionCount) * Index
		local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))
		local CandidatePosition = TargetRoot.Position + Direction * CombatDistance

		--// Cheap checks first. These avoid expensive raycasts for obviously
		--// invalid positions.
		if not IsInsideFarmArea(CandidatePosition)
			or IsWaterAtPosition(CandidatePosition, TargetMob)
			or IsPathThroughDeadzone(CandidatePosition)
			or not IsPositionSafeFromBladeGroup(CandidatePosition, TargetMob)
		then
			continue
		end

		local Dot = math.clamp(CurrentDirection:Dot(Direction), -1, 1)
		local DirectionPenalty = (1 - Dot) * CombatDistance * 0.35
		local TravelDistance = (CandidatePosition - RootPart.Position).Magnitude

		table.insert(Candidates, {
			Position = CandidatePosition,
			Score = TravelDistance + DirectionPenalty,
		})
	end

	table.sort(Candidates, function(A, B)
		return A.Score < B.Score
	end)

	local MaxPathTests = math.min(CONFIG.SAFE_COMBAT_MAX_PATH_TESTS, #Candidates)

	for Index = 1, MaxPathTests do
		local CandidatePosition = Candidates[Index].Position

		if not IsSafeCombatPathClear(CandidatePosition, TargetMob) then
			continue
		end

		if IsPathThroughWater(CandidatePosition)
			or IsPathThroughBladeGroupDanger(CandidatePosition, TargetMob)
		then
			continue
		end

		if not CanSeeGoblinFromPosition(CandidatePosition, TargetMob) then
			continue
		end

		return CandidatePosition
	end

	return nil
end

--// Retreat Obstacle Check
function IsPathClear(TargetPosition)
	if not RootPart then
		return false
	end

	if IsWaterAtPosition(TargetPosition) then
		return false
	end

	if IsPathThroughWater(TargetPosition) then
		return false
	end

	if IsPathThroughDeadzone(TargetPosition) then
		return false
	end

	local Origin    = RootPart.Position
	local Direction = TargetPosition - Origin

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
	}

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result == nil
end

function IsInsideFarmDeadzone(Position)
	if not PlaceConfig then
		return false
	end

	local Offset = Vector3.new(
		Position.X - PlaceConfig.FARM_DEADZONE_CENTER.X,
		0,
		Position.Z - PlaceConfig.FARM_DEADZONE_CENTER.Z
	)

	return Offset.Magnitude <= PlaceConfig.FARM_DEADZONE_RADIUS
end

function IsEscapePathClear(TargetPosition)
	if not RootPart or not TargetPosition then
		return false
	end

	if not IsInsideFarmArea(TargetPosition) then
		return false
	end

	if IsWaterAtPosition(TargetPosition) then
		return false
	end

	if IsPathThroughWater(TargetPosition) then
		return false
	end

	local Origin = RootPart.Position
	local Direction = TargetPosition - Origin

	if Direction.Magnitude <= 0.01 then
		return false
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
	}

	if workspace:Raycast(Origin, Direction, RaycastParams) then
		return false
	end

	--// Also check the character's physical width so the center point
	--// cannot pass a wall while the character body gets stuck on it.
	local BlockcastSize = Vector3.new(
		math.max(RootPart.Size.X, 2.5),
		math.max(RootPart.Size.Y, 4),
		math.max(RootPart.Size.Z, 2.5)
	)

	local BlockcastCFrame = CFrame.new(Origin)
	local BlockcastResult = workspace:Blockcast(
		BlockcastCFrame,
		BlockcastSize,
		Direction,
		RaycastParams
	)

	return BlockcastResult == nil
end

function GetDeadzoneEscapePosition()
	if not RootPart then
		return nil
	end

	local now = os.clock()

	if DeadzoneEscapePosition
		and now - LastDeadzoneEscapeTime < CONFIG.DEADZONE_ESCAPE_INTERVAL
	then
		return DeadzoneEscapePosition
	end

	LastDeadzoneEscapeTime = now
	DeadzoneEscapePosition = nil


	local Origin = RootPart.Position

	for Index = 1, CONFIG.DEADZONE_ESCAPE_DIRECTIONS do
		local Angle = (Index / CONFIG.DEADZONE_ESCAPE_DIRECTIONS) * math.pi * 2

		local Direction = Vector3.new(
			math.cos(Angle),
			0,
			math.sin(Angle)
		)

		local Candidate = Origin + Direction * CONFIG.DEADZONE_ESCAPE_DISTANCE

		if IsEscapePathClear(Candidate) then
			DeadzoneEscapePosition = Candidate
			return Candidate
		end
	end

	return nil
end

--// Get All Living Goblins
function GetLivingGoblins()
	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder then
		return {}
	end

	local Goblins = {}

	for _, Mob in MobFolder:GetChildren() do
		if not Mob:IsA("Model") then
			continue
		end

		local Config      = Mob:FindFirstChild("Config")
		local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
		local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

		if not Config or not MobHumanoid or not MobRoot then
			continue
		end

		local Entity = Config:FindFirstChild("Entity")

		if not Entity then
			continue
		end

		if not IsEntityInPriority(Entity.Value) then
			continue
		end

		if MobHumanoid.Health <= 0 then
			continue
		end

		table.insert(Goblins, Mob)
	end

	return Goblins
end

--// Calculate Retreat Position
function GetRetreatPosition()
	if not RootPart then
		return nil
	end

	local Goblins = GetLivingGoblins()

	if #Goblins == 0 then
		return nil
	end

	local RetreatDirection = Vector3.zero

	if ClosestTarget
		and ClosestTarget:IsDescendantOf(workspace)
	then
		local TargetHumanoid = ClosestTarget:FindFirstChildOfClass("Humanoid")
		local TargetRoot     = ClosestTarget:FindFirstChild("HumanoidRootPart")

		if TargetHumanoid
			and TargetRoot
			and TargetHumanoid.Health > 0
		then
			local Offset = RootPart.Position - TargetRoot.Position
			local Distance = Offset.Magnitude

			if Distance > 0 then
				RetreatDirection = Offset.Unit
			end
		end
	end

	if RetreatDirection.Magnitude <= 0 then
		for _, Goblin in Goblins do
			local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

			if MobRoot then
				local Offset = RootPart.Position - MobRoot.Position
				local Distance = Offset.Magnitude

				if Distance > 0 then
					RetreatDirection += Offset.Unit / math.max(Distance, 1)
				end
			end
		end

		if RetreatDirection.Magnitude <= 0 then
			return nil
		end

		RetreatDirection = RetreatDirection.Unit
	end

	local BestPosition = nil
	local BestScore    = -math.huge

	for Index = 0, CONFIG.RETREAT_DIRECTIONS - 1 do
		local Angle = (math.pi * 2 / CONFIG.RETREAT_DIRECTIONS) * Index

		local Direction = Vector3.new(
			math.cos(Angle),
			0,
			math.sin(Angle)
		)

		local TargetPosition = RootPart.Position + Direction * CONFIG.RETREAT_DISTANCE

		if not IsInsideFarmArea(TargetPosition) then
			continue
		end

		if not IsPathClear(TargetPosition) then
			continue
		end

		local Score = Direction:Dot(RetreatDirection)

		if Score > BestScore then
			BestScore    = Score
			BestPosition = TargetPosition
		end
	end

	return BestPosition
end

--// Retreat
function RetreatFromGoblins()
	local RetreatPosition = nil

	if LastRetreatPosition
		and os.clock() - LastRetreatCalculateTime < CONFIG.RETREAT_RECALCULATE_INTERVAL
	then
		RetreatPosition = LastRetreatPosition
	else
		RetreatPosition = GetRetreatPosition()

		if RetreatPosition then
			LastRetreatPosition      = RetreatPosition
			LastRetreatCalculateTime = os.clock()
			RetreatNoPositionSince   = nil
		elseif not RetreatNoPositionSince then
			RetreatNoPositionSince = os.clock()
		end
	end

	if RetreatPosition then
		--FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:MoveTo(RetreatPosition)
		DoJump()
	else
		--FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
	end
end

--// Approach Position Check
function IsApproachPositionClear(TargetPosition, Goblin)
	if not RootPart or not TargetPosition then
		return false
	end

	if not IsInsideFarmArea(TargetPosition) then
		return false
	end

	if IsWaterAtPosition(TargetPosition, Goblin) then
		return false
	end

	if IsPathThroughWater(TargetPosition) then
		return false
	end

	if IsPathThroughDeadzone(TargetPosition) then
		return false
	end

	--// Never select a position inside any BladePart danger zone
	--// around the target group.
	if SafeCombatPositionEnabled
		and Goblin
		and not IsPositionSafeFromBladeGroup(TargetPosition, Goblin)
	then
		return false
	end

	--// Also make sure the route itself doesn't pass through
	--// an enemy BladePart danger zone.
	if SafeCombatPositionEnabled
		and Goblin
		and IsPathThroughBladeGroupDanger(TargetPosition, Goblin)
	then
		return false
	end

	local Origin    = RootPart.Position
	local Direction = TargetPosition - Origin

	if Direction.Magnitude <= 0 then
		return true
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		Goblin,
	}

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result == nil
end

function CanSeeGoblinFromPosition(Position, Goblin)
	if not Position or not Goblin then
		return false
	end

	local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

	if not MobRoot then
		return false
	end

	local Direction = MobRoot.Position - Position

	if Direction.Magnitude <= 0 then
		return true
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		Goblin,
	}

	local Result = workspace:Raycast(Position, Direction, RaycastParams)

	return Result == nil
end

--// Target Reposition
function GetTargetRepositionPosition(Goblin)
	if not RootPart or not Goblin then
		return nil
	end

	local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

	if not MobRoot then
		return nil
	end

	--// Calculate the minimum safe radius around the target.
	local SafeRadius = CONFIG.PLAYER_ATTACK_DISTANCE

	if SafeCombatPositionEnabled then
		for _, BladePart in GetCombatBladeParts(Goblin) do
			local Offset = BladePart.Position - MobRoot.Position
			local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)
			local BladeDistance = HorizontalOffset.Magnitude

			SafeRadius = math.max(
				SafeRadius,
				BladeDistance + GetBladeDangerDistance()
			)
		end
	end

	--// Never make the radius absurdly small.
	SafeRadius = math.max(SafeRadius, CONFIG.GOBLIN_REACH_DISTANCE)

	local BestPosition = nil
	local BestScore    = math.huge

	for Index = 0, CONFIG.TARGET_REPOSITION_DIRECTIONS - 1 do
		local Angle = (math.pi * 2 / CONFIG.TARGET_REPOSITION_DIRECTIONS) * Index

		local Direction = Vector3.new(
			math.cos(Angle),
			0,
			math.sin(Angle)
		)

		local CandidatePosition = MobRoot.Position + Direction * SafeRadius

		if not IsApproachPositionClear(CandidatePosition, Goblin) then
			continue
		end

		if not CanSeeGoblinFromPosition(CandidatePosition, Goblin) then
			continue
		end

		if SafeCombatPositionEnabled
			and not IsPositionSafeFromBladeGroup(CandidatePosition, Goblin)
		then
			continue
		end

		local Offset = CandidatePosition - RootPart.Position
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		--// Prefer positions closer to the current player
		--// while still maintaining safety.
		local TargetOffset = CandidatePosition - MobRoot.Position
		local TargetDistance = Vector3.new(TargetOffset.X, 0, TargetOffset.Z).Magnitude

		local Score = Distance + TargetDistance * 0.15

		if Score < BestScore then
			BestScore    = Score
			BestPosition = CandidatePosition
		end
	end

	return BestPosition
end

function FaceGoblin(Goblin)
	if not RootPart or not Goblin then
		return
	end

	local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

	if not MobRoot then
		return
	end

	local RootPosition = RootPart.Position
	local TargetPosition = MobRoot.Position

	local Direction = Vector3.new(
		TargetPosition.X - RootPosition.X,
		0,
		TargetPosition.Z - RootPosition.Z
	)

	if Direction.Magnitude <= 0.01 then
		return
	end

	FaceOrientation.CFrame = CFrame.lookAt(
		RootPosition,
		RootPosition + Direction
	)

	FaceOrientation.Enabled = true
end

function IsSafeCombatDirectPathBlocked(Goblin, TargetPosition, now)
	if not RootPart or not Goblin or not TargetPosition then
		return true
	end

	if LastDirectPathTarget == Goblin
		and LastDirectPathPosition == TargetPosition
		and now - LastDirectPathCheckTime < CONFIG.DIRECT_PATH_CACHE_INTERVAL
	then
		return LastDirectPathBlocked
	end

	LastDirectPathCheckTime = now
	LastDirectPathTarget = Goblin
	LastDirectPathPosition = TargetPosition

	LastDirectPathBlocked =
		not CanSeeGoblin(Goblin)
		or not IsSafeCombatPathClear(TargetPosition, Goblin)
		or IsPathThroughWater(TargetPosition)
		or IsPathThroughDeadzone(TargetPosition)
		or IsPathThroughBladeGroupDanger(TargetPosition, Goblin)

	return LastDirectPathBlocked
end

--// ============================================================
--// TARGET PATHFINDING
--// ============================================================

function ResetTargetPath()
	TargetPath             = nil
	TargetPathMob          = nil
	TargetPathDestination  = nil
	TargetPathWaypoint     = 1
	LastTargetPathTime     = 0
	TargetPathBlockedSince = nil
end

function ComputeTargetPath(Goblin, Destination)
	if not RootPart or not Goblin or not Destination then
		ResetTargetPath()
		return false
	end

	local Path = PathfindingService:CreatePath({
		AgentRadius = math.max(RootPart.Size.X * 0.5, 2),
		AgentHeight = math.max(RootPart.Size.Y, 5),
		AgentCanJump = true,
		WaypointSpacing = 4,
	})

	local Success = pcall(function()
		Path:ComputeAsync(RootPart.Position, Destination)
	end)

	if not Success or Path.Status ~= Enum.PathStatus.Success then
		ResetTargetPath()
		return false
	end

	local Waypoints = Path:GetWaypoints()

	if #Waypoints < 2 then
		ResetTargetPath()
		return false
	end

	--// Never follow a path that leaves the FarmZone.
	for Index = 2, #Waypoints do
		if not IsInsideFarmArea(Waypoints[Index].Position) then
			ResetTargetPath()
			return false
		end
	end

	TargetPath             = Path
	TargetPathMob          = Goblin
	TargetPathDestination  = Destination
	TargetPathWaypoint     = 2
	LastTargetPathTime     = os.clock()
	TargetPathBlockedSince = nil

	return true
end

function MoveAlongTargetPath(Goblin, Destination)
	if not RootPart or not Goblin or not Destination then
		return false
	end

	local now = os.clock()
	local NeedRecalculate =
		TargetPath == nil
		or TargetPathMob ~= Goblin
		or not TargetPathDestination
		or (TargetPathDestination - Destination).Magnitude > 5
		or now - LastTargetPathTime >= CONFIG.TARGET_PATH_RECALCULATE_INTERVAL

	if NeedRecalculate then
		if not ComputeTargetPath(Goblin, Destination) then
			if not TargetPathBlockedSince then
				TargetPathBlockedSince = now
			end

			return false
		end
	end

	local Waypoints = TargetPath:GetWaypoints()

	while TargetPathWaypoint <= #Waypoints do
		local Waypoint = Waypoints[TargetPathWaypoint]
		local Offset = Waypoint.Position - RootPart.Position
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		if Distance <= CONFIG.TARGET_PATH_WAYPOINT_DISTANCE then
			TargetPathWaypoint += 1
			continue
		end

		if Waypoint.Action == Enum.PathWaypointAction.Jump then
			DoJump()
		end

		Humanoid.AutoRotate = false
		Humanoid:MoveTo(Waypoint.Position)
		FaceGoblin(Goblin)
		return true
	end

	--// Path reached its final waypoint. Let combat positioning decide
	--// whether we should attack or make a final adjustment.
	ResetTargetPath()
	return false
end

--// ============================================================
--// MOVE TO GOBLIN
--// ============================================================

function MoveToGoblin(Goblin)
	local now = os.clock()
	if not Goblin or not RootPart then
		return
	end

	if not IsTargetLockValid(Goblin) then
		if ClosestTarget == Goblin then
			ClosestTarget = nil
		end

		ResetTargetReposition()
		ResetTargetPath()
		return
	end

	local MobHumanoid = Goblin:FindFirstChildOfClass("Humanoid")
	local MobRoot     = Goblin:FindFirstChild("HumanoidRootPart")

	--// Secondary threat handling:
	--// Keep the current target locked, but make room if another mob
	--// closes in from the player's side or rear.
	local ThreatMob, ThreatDistance = GetNearbyThreatMob(Goblin)
	if ThreatMob and ThreatDistance <= CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + CONFIG.THREAT_ESCAPE_DISTANCE then
		local ThreatEscapePosition = GetThreatEscapePosition(Goblin, ThreatMob)

		if ThreatEscapePosition then
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(ThreatEscapePosition)
			FaceGoblin(Goblin)
			return
		end
	end

	if not MobHumanoid
		or not MobRoot
		or MobHumanoid.Health <= 0
	then
		if ClosestTarget == Goblin then
			ClosestTarget = nil
		end

		ValidMobs[Goblin] = nil
		ResetTargetReposition()
		ResetTargetPath()

		return
	end

	--// Safe Combat Position disabled:
	--// simply move directly toward the target.
	if not SafeCombatPositionEnabled then
		ResetTargetReposition()
		ResetTargetPath()
		Humanoid.AutoRotate = false
		Humanoid:MoveTo(MobRoot.Position)
		FaceGoblin(Goblin)
		return
	end

	if TargetApproachMob ~= Goblin then
		ResetTargetReposition()
		TargetApproachMob = Goblin
	end

	--// ========================================================
	--// FIRST PRIORITY:
	--// Get away from ANY BladePart that is currently too close.
	--// ========================================================

	local PushDirection, ClosestEffectiveDistance, ClosestBlade = GetBladeDangerData(Goblin)

	if ClosestEffectiveDistance <= 0 then
		if PushDirection.Magnitude > 0 then
			local RetreatDistance = math.abs(ClosestEffectiveDistance) + CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + 2
			local RetreatPosition = RootPart.Position + PushDirection * RetreatDistance

			if IsInsideFarmArea(RetreatPosition)
				and not IsWaterAtPosition(RetreatPosition, Goblin)
				and not IsPathThroughWater(RetreatPosition)
				and not IsPathThroughDeadzone(RetreatPosition)
				and not IsPathThroughBladeGroupDanger(RetreatPosition, Goblin)
				and IsEscapePathClear(RetreatPosition)
			then
				Humanoid.AutoRotate = false
				Humanoid:MoveTo(RetreatPosition)
				FaceGoblin(Goblin)
			else
				local MoveDistance  = math.abs(ClosestEffectiveDistance) + CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + 2
				local MovePosition  = RootPart.Position + PushDirection * MoveDistance

				if IsInsideFarmArea(MovePosition)
					and not IsWaterAtPosition(MovePosition, Goblin)
					and not IsPathThroughWater(MovePosition)
					and not IsPathThroughDeadzone(MovePosition)
				then
					Humanoid.AutoRotate = false
					Humanoid:MoveTo(PushDirection)
					FaceGoblin(Goblin)
				else
					Humanoid.AutoRotate = true
					Humanoid:Move(Vector3.zero)
					FaceGoblin(Goblin)
				end
			end
		else
			--FaceOrientation.Enabled = false
			Humanoid.AutoRotate = true
			Humanoid:Move(Vector3.zero)
		end

		return
	end

	--// ========================================================
	--// SECOND PRIORITY:
	--// Move to a safe attack position.
	--// ========================================================

	local SafeCombatPosition = CAHCED_SAFECOMBAT_POSITION
	if now - LAST_SAFECOMBAT_TIME >= CONFIG.SAFECOMBAT_INTERVAL then
		LAST_SAFECOMBAT_TIME = now
		SafeCombatPosition = GetSafeCombatPosition(Goblin)
		CAHCED_SAFECOMBAT_POSITION = SafeCombatPosition
	end

	if SafeCombatPosition then
		local Offset = SafeCombatPosition - RootPart.Position
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		--// Already at the desired safe position.
		if Distance <= 2 then
			--// Stop movement but keep the character locked onto the target.
			Humanoid.AutoRotate = false
			Humanoid:Move(Vector3.zero)
			FaceGoblin(Goblin)

			TargetUnreachableSince = nil
			TargetApproachPosition = nil

			return
		end

		local DirectPathBlocked = IsSafeCombatDirectPathBlocked(Goblin, SafeCombatPosition, now)

		if not DirectPathBlocked then
			ResetTargetPath()
			TargetUnreachableSince = nil
			TargetApproachPosition = nil

			Humanoid.AutoRotate = false
			Humanoid:MoveTo(SafeCombatPosition)
			FaceGoblin(Goblin)
			return
		end
	end

	--// ========================================================
	--// THIRD PRIORITY:
	--// Use real pathfinding when an object blocks the direct route.
	--// A blocked line of sight does NOT mean the target is unreachable.
	--// ========================================================

	local PathDestination = SafeCombatPosition or MobRoot.Position

	if MoveAlongTargetPath(Goblin, PathDestination) then
		TargetUnreachableSince = nil
		TargetApproachPosition = nil
		return
	end

	--// ========================================================
	--// FOURTH PRIORITY:
	--// Reposition around the entire enemy group.
	--// ========================================================

	if not TargetUnreachableSince then
		TargetUnreachableSince = os.clock()
	end

	local now = os.clock()

	if not TargetApproachPosition
		or now - LastTargetRepositionTime >= CONFIG.TARGET_REPOSITION_INTERVAL
	then
		LastTargetRepositionTime = now
		TargetApproachPosition = GetTargetRepositionPosition(Goblin)
	end

	if TargetApproachPosition then
		local ApproachOffset = TargetApproachPosition - RootPart.Position
		local ApproachDistance = Vector3.new(ApproachOffset.X, 0, ApproachOffset.Z).Magnitude

		if ApproachDistance <= 3 then
			TargetApproachPosition = nil
		else
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(TargetApproachPosition)
			FaceGoblin(Goblin)
			return
		end
	end

	--// No safe position available.
	--FaceOrientation.Enabled = false
	Humanoid.AutoRotate = true
	Humanoid:Move(Vector3.zero)

	if now - TargetUnreachableSince >= CONFIG.TARGET_UNREACHABLE_TIMEOUT then
		if ClosestTarget == Goblin then
			ClosestTarget = nil
		end

		ResetTargetReposition()
		ResetTargetPath()
	end
end

--// ============================================================
--// AUTO PATROL
--// ============================================================

function GetPatrolGroundPosition(Position)
	if not Position or not RootPart then
		return nil
	end

	if not IsInsideFarmArea(Position) then
		return nil
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {Character}

	--// เพิ่มความสูงเริ่มยิงและระยะยิงให้ครอบคลุมภูมิประเทศที่สูง/ต่ำกว่าเดิมมาก
	local Origin = Vector3.new(Position.X, RootPart.Position.Y + 60, Position.Z)
	local Result = workspace:Raycast(Origin, Vector3.new(0, -250, 0), RaycastParams)

	if not Result then
		return nil
	end

	if Result.Material == Enum.Material.Water then
		return nil
	end

	if Result.Normal.Y < 0.5 then
		return nil
	end

	local GroundPosition = Vector3.new(
		Position.X,
		Result.Position.Y + RootPart.Size.Y * 0.5,
		Position.Z
	)

	if IsWaterAtPosition(GroundPosition)
		or IsInsideFarmDeadzone(GroundPosition)
	then
		return nil
	end

	return GroundPosition
end

function IsPatrolPathClear(TargetPosition)
	if not RootPart or not TargetPosition then
		return false
	end

	local Origin = RootPart.Position
	local Direction = TargetPosition - Origin

	if Direction.Magnitude <= 0.01 then
		return true
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		workspace:FindFirstChild("Mobs"),
	}

	local RayOrigin = Origin + Vector3.new(0, 1.5, 0)
	local RayDirection = Vector3.new(Direction.X, 0, Direction.Z)

	local Result = workspace:Raycast(RayOrigin, RayDirection, RaycastParams)

	if Result then
		--print("[PatrolPath] blocked by:", Result.Instance:GetFullName(), "at", Result.Position)
		return false
	end

	return true
end

function IsPatrolPathInsideFarmArea(TargetPosition)
	if not RootPart or not TargetPosition then
		return false
	end

	local Origin = RootPart.Position
	local Offset = TargetPosition - Origin
	local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)

	local Distance = HorizontalOffset.Magnitude

	if Distance <= 0.01 then
		return IsInsideFarmArea(Origin)
	end

	local Direction = HorizontalOffset.Unit
	local SampleDistance = 4

	for CurrentDistance = 0, Distance, SampleDistance do
		local SamplePosition = Origin + Direction * math.min(CurrentDistance, Distance)

		if not IsInsideFarmArea(SamplePosition)
			or IsInsideFarmDeadzone(SamplePosition)
		then
			return false
		end
	end

	return true
end

function HasPatrolEscapeSpace(Position)
	if not Position then
		return false
	end

	local Distance = CONFIG.PATROL_ESCAPE_DISTANCE
	local DirectionCount = CONFIG.PATROL_ESCAPE_DIRECTIONS

	for Index = 0, DirectionCount - 1 do
		local Angle = (math.pi * 2 / DirectionCount) * Index
		local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))
		local EscapePosition = Position + Direction * Distance

		if IsInsideFarmArea(EscapePosition)
			and not IsWaterAtPosition(EscapePosition)
			and GetPatrolGroundPosition(EscapePosition)
			and IsPatrolPathClear(EscapePosition)
		then
			return true
		end
	end

	return false
end

function GetAutoPatrolPosition()
	if not RootPart then
		return nil
	end

	local now = os.clock()

	if PatrolPauseUntil > now then
		return nil
	end

	if PatrolPosition and now - LastPatrolCalculateTime < CONFIG.PATROL_RECALCULATE_INTERVAL then
		return PatrolPosition
	end

	LastPatrolCalculateTime = now
	PatrolPosition = nil

	local Origin = RootPart.Position
	local Center = IsValidPlace(game.PlaceId).FARM_CENTER
	local Candidates = {}

	--// Keep some directional memory so patrol does not look like a random
	--// teleport between directions every cycle.
	local DirectionCount = CONFIG.PATROL_DIRECTIONS
	local PreviousDirection = PatrolDirection
	local BaseAngle = PreviousDirection
		and math.atan2(PreviousDirection.Z, PreviousDirection.X)
		or math.random() * math.pi * 2

	--// Humans tend to vary their walking distance. Do not always use the
	--// exact same radius or the exact same angle spacing.
	local Radius = math.random(
		math.floor(CONFIG.PATROL_MIN_DISTANCE),
		math.floor(CONFIG.PATROL_MAX_DISTANCE)
	)

	for Index = 0, DirectionCount - 1 do
		local StepAngle = (math.pi * 2 / DirectionCount) * Index
		local AngleJitter = math.rad(math.random(-14, 14))
		local Angle = BaseAngle + StepAngle + AngleJitter
		local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))

		--// Add a few distance variations instead of creating a perfect ring.
		local DistanceJitter = math.random(-10, 10)
		local CandidateRadius = math.clamp(
			Radius + DistanceJitter,
			CONFIG.PATROL_MIN_DISTANCE,
			CONFIG.PATROL_MAX_DISTANCE
		)

		local Candidate = GetPatrolGroundPosition(Origin + Direction * CandidateRadius)

		if Candidate then
			local TravelDistance = Vector3.new(
				Candidate.X - Origin.X,
				0,
				Candidate.Z - Origin.Z
			).Magnitude

			local ToCandidate = Vector3.new(
				Candidate.X - Origin.X,
				0,
				Candidate.Z - Origin.Z
			)

			local DirectionScore = 0

			if PreviousDirection and ToCandidate.Magnitude > 0.01 then
				--// Prefer continuing roughly in the previous direction, but only
				--// as a soft preference. A person can change direction naturally.
				DirectionScore = PreviousDirection:Dot(ToCandidate.Unit) * CONFIG.PATROL_DIRECTION_MEMORY
			end

			local CenterDistance = Vector3.new(
				Candidate.X - Center.X,
				0,
				Candidate.Z - Center.Z
			).Magnitude

			local RepeatPenalty = 0

			if PatrolLastPosition then
				local SinceLast = Vector3.new(
					Candidate.X - PatrolLastPosition.X,
					0,
					Candidate.Z - PatrolLastPosition.Z
				).Magnitude

				if SinceLast < CONFIG.PATROL_MIN_DISTANCE * 0.75 then
					RepeatPenalty = 18
				end
			end

			table.insert(Candidates, {
				Position = Candidate,
				Direction = ToCandidate.Magnitude > 0.01 and ToCandidate.Unit or Direction,
				Score = TravelDistance * 0.20
				- DirectionScore * 12
					+ CenterDistance * 0.08
					+ RepeatPenalty
					+ math.random() * 8,
			})
		end
	end

	table.sort(Candidates, function(A, B)
		return A.Score < B.Score
	end)

	if #Candidates == 0 then
		return nil
	end

	--// Do not always choose the mathematically best candidate. Choosing from
	--// the first few valid candidates creates natural variation while keeping
	--// the patrol inside safe areas.
	local ChoiceCount = math.min(4, #Candidates)
	local CandidateIndex = math.random(1, ChoiceCount)

	for Index = 1, ChoiceCount do
		local Candidate = Candidates[Index]

		if IsPatrolPathInsideFarmArea(Candidate.Position)
			and IsPatrolPathClear(Candidate.Position)
			and HasPatrolEscapeSpace(Candidate.Position)
		then
			if Index == CandidateIndex or ChoiceCount == 1 then
				PatrolPosition = Candidate.Position
				PatrolDirection = Candidate.Direction
				PatrolLastDistance = (Candidate.Position - Origin).Magnitude
				return Candidate.Position
			end
		end
	end

	--// Fallback: use the first valid candidate if the random choice failed
	--// because one of the preferred candidates became invalid.
	for _, Candidate in ipairs(Candidates) do
		if IsPatrolPathInsideFarmArea(Candidate.Position)
			and IsPatrolPathClear(Candidate.Position)
		then
			PatrolPosition = Candidate.Position
			PatrolDirection = Candidate.Direction
			PatrolLastDistance = (Candidate.Position - Origin).Magnitude
			return Candidate.Position
		end
	end

	return nil
end

function MoveToPatrol()
	if not Feature.AutoPatrol.Enabled or not RootPart or not Humanoid then
		PatrolPosition = nil
		PatrolPauseUntil = 0
		return false
	end

	local now = os.clock()

	--// Short natural pauses between patrol destinations.
	if PatrolPauseUntil > now then
		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	local Position = GetAutoPatrolPosition()

	if not Position then
		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	local Offset = Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if Distance <= CONFIG.PATROL_ARRIVAL_DISTANCE then
		PatrolLastPosition = Position
		PatrolPosition = nil
		LastPatrolCalculateTime = 0

		--// Vary the idle time. Occasionally make the pause a little longer,
		--// similar to someone briefly deciding where to go next.
		local Pause = math.random() * (CONFIG.PATROL_PAUSE_MAX - CONFIG.PATROL_PAUSE_MIN)
			+ CONFIG.PATROL_PAUSE_MIN

		if math.random() < 0.12 then
			Pause += math.random() * 1.5
		end

		PatrolPauseUntil = now + Pause

		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	if not IsInsideFarmArea(RootPart.Position) or IsInsideFarmDeadzone(RootPart.Position) then
		PatrolPosition = nil
		LastPatrolCalculateTime = 0
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	if not IsPatrolPathInsideFarmArea(Position) then
		PatrolPosition = nil
		LastPatrolCalculateTime = 0
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	FaceOrientation.Enabled = false
	Humanoid.AutoRotate = true
	Humanoid:MoveTo(Position)

	return true
end

function GetFarmReturnPosition()
	if not RootPart or Feature.IgnoreFarmZone.Enabled or not PlaceConfig then
		return nil
	end

	local now = os.clock()

	if FarmReturnPosition
		and now - LastFarmReturnCalculateTime < 0.75
	then
		return FarmReturnPosition
	end

	LastFarmReturnCalculateTime = now
	FarmReturnPosition = nil

	local FarmCenter = PlaceConfig.FARM_CENTER
	local Candidates = {}
	local Origin = RootPart.Position

	--// Pick a random point within 10 studs of the Farm Center.
	--// Never intentionally use the exact Farm Center as the destination.
	for Index = 1, 18 do
		local Angle = math.random() * math.pi * 2
		local Radius = math.sqrt(math.random()) * 10
		local Offset = Vector3.new(
			math.cos(Angle) * Radius,
			0,
			math.sin(Angle) * Radius
		)

		local Candidate = GetPatrolGroundPosition(FarmCenter + Offset)

		if Candidate
			and IsInsideFarmArea(Candidate)
			and not IsInsideFarmDeadzone(Candidate)
		then
			local Distance = (Candidate - Origin).Magnitude
			local CenterDistance = Vector3.new(
				Candidate.X - FarmCenter.X,
				0,
				Candidate.Z - FarmCenter.Z
			).Magnitude

			table.insert(Candidates, {
				Position = Candidate,
				Distance = Distance,
				CenterDistance = CenterDistance,
			})
		end
	end

	--// Prefer a candidate that is close enough to the center while still
	--// giving the return movement a natural/random destination.
	table.sort(Candidates, function(A, B)
		if math.abs(A.CenterDistance - B.CenterDistance) > 1 then
			return A.CenterDistance < B.CenterDistance
		end

		return A.Distance < B.Distance
	end)

	if Candidates[1] then
		FarmReturnPosition = Candidates[1].Position
		return FarmReturnPosition
	end

	return nil
end

function MoveBackToFarmZone()
	if not Feature.ReturnToFarmZone.Enabled or not RootPart or not Humanoid then
		FarmReturnPosition = nil
		return false
	end

	if Feature.IgnoreFarmZone.Enabled then
		FarmReturnPosition = nil
		return false
	end

	local FarmCenter = PlaceConfig.FARM_CENTER
	local CenterOffset = RootPart.Position - FarmCenter
	local CenterDistance = Vector3.new(CenterOffset.X, 0, CenterOffset.Z).Magnitude

	--// Stop returning once we are within 10 studs of Farm Center.
	if CenterDistance <= 5 then
		FarmReturnPosition = nil
		LastFarmReturnCalculateTime = 0
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	local Position = GetFarmReturnPosition()

	if not Position then
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	local Offset = Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if Distance <= 4 then
		FarmReturnPosition = nil
		LastFarmReturnCalculateTime = 0
		return false
	end

	FaceOrientation.Enabled = false
	Humanoid.AutoRotate = true
	Humanoid:MoveTo(Position)
	return true
end

--// Combat Target Validation
function IsCombatTargetValid(Mob)
	if not Mob or not Mob:IsA("Model") then
		return false
	end

	if not Mob:IsDescendantOf(workspace) then
		return false
	end

	if not RootPart then
		return false
	end

	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder
		or not Mob:IsDescendantOf(MobFolder)
	then
		return false
	end

	local Config      = Mob:FindFirstChild("Config")
	local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")
	local MobRoot     = Mob:FindFirstChild("HumanoidRootPart")

	if not Config
		or not MobHumanoid
		or not MobRoot
	then
		return false
	end

	local Entity = Config:FindFirstChild("Entity")

	if not Entity
		or not Entity:IsA("StringValue")
	then
		return false
	end

	if not IsEntityInPriority(Entity.Value) then
		return false
	end

	if MobHumanoid.Health <= 0 then
		return false
	end

	local Offset = MobRoot.Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if CONFIG.DISTANCE_Y_CALCULATE then
		Distance = Offset.Magnitude
	end

	return Distance <= 50
end

function HandleDeadzoneEscape()
	if Feature.IgnoreFarmZone.Enabled then
		DeadzoneEscapePosition = nil

		return false
	end

	if not RootPart or not Humanoid then
		return false
	end

	if not IsInsideFarmDeadzone(RootPart.Position) then
		DeadzoneEscapePosition = nil


		return false
	end

	local EscapePosition = GetDeadzoneEscapePosition()

	if EscapePosition then
		Humanoid:MoveTo(EscapePosition)
		return true
	end

	return false
end

function DoJump()
	if not Humanoid then
		return
	end

	if Humanoid.FloorMaterial ~= Enum.Material.Air
		and Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
	then
		Humanoid.Jump = true
		Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

--// Position Update
RunService.RenderStepped:Connect(function()
	updatePosition()

	local PlayerStats = Player:FindFirstChild("PlayerStats")
	if Humanoid then
		if PlayerStats and PlayerStats.Level.Value >= 300 then
			if Humanoid.WalkSpeed < CONFIG.MAXIMUM_WALKSPEED then
				Humanoid.WalkSpeed = CONFIG.MAXIMUM_WALKSPEED
			end
		elseif Humanoid.WalkSpeed < CONFIG.MINIMUM_WALKSPEED then
			Humanoid.WalkSpeed = CONFIG.MINIMUM_WALKSPEED
		end
	end
end)

--// Movement + Block
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local isTargetPlace = IsValidPlace(game.PlaceId)

	--if isTargetPlace then
	--	Enabled = false
	--	updateButton()
	--	return
	--end

	if not Humanoid or not RootPart then
		updateCharacter()
		table.clear(ValidMobs)
		ClosestTarget = nil
		return
	end

	if Humanoid.Health <= 0 then
		table.clear(ValidMobs)
		ClosestTarget = nil
		return
	end

	if now - LAST_TEXT_UPDATE_TIME >= CONFIG.TEXT_UPDATE_INTERVAL then
		LAST_TEXT_UPDATE_TIME = now
		updatePlayTime()
		updateEventCurrency()

		WayPointLabel.Text = CONFIG.CURRENT_WAYPOINT_TARGET .. "/" .. (IsValidPlace(game.PlaceId) and #IsValidPlace(game.PlaceId).WAYPOINTS or 0)
		WalkSpeedLabel.Text = tostring(math.floor(Humanoid.WalkSpeed + 0.5))
		DeathLabel.Text = tostring(DEATH_COUNT)
	end

	--// Realtime Mob Validation
	if now - LAST_MOB_VALIDATION_TIME >= CONFIG.MOB_VALIDATION_INTERVAL then
		LAST_MOB_VALIDATION_TIME = now
		UpdateValidMobs()
	end

	if not Enabled then
		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return
	end

	if not InputBindableFunction then
		InputBindableFunction = PlayerGui:FindFirstChild("InputBindableFunction", true) :: BindableFunction
		return
	end

	local PlayerStats = Player:FindFirstChild("PlayerStats")
	local Sword = Character:FindFirstChild("Sword")

	if not Sword or not Sword:FindFirstChild("MainWeld", true) or not PlayerStats then
		return
	end

	local MainWeld = Sword:FindFirstChild("MainWeld", true)

	if HandleDeadzoneEscape() then
		return
	end

	--// Emergency Retreat
	local EmergencyHealth = Humanoid.Health <= Humanoid.MaxHealth * 0.4
	local ShouldHeal      = Humanoid.Health <= Humanoid.MaxHealth * 0.65

	if EmergencyHealth or (PlayerStats.Level.Value >= 300 and Humanoid.WalkSpeed < CONFIG.MAXIMUM_WALKSPEED) then
		RETREATING = true
	elseif RETREATING and Humanoid.Health >= Humanoid.MaxHealth * 0.7 then
		RETREATING = false
	end

	if RETREATING then
		local UseConsumable = Replicated:FindFirstChild("UseConsumable", true)
		local PlayerStats   = Player:FindFirstChild("PlayerStats")

		RetreatFromGoblins()

		if InputBindableFunction and ( Equipped or ( MainWeld.Part1 and MainWeld.Part1.Name ~= "UpperTorso" ) ) then
			Equipped = false

			InputBindableFunction:Invoke(
				"EquipButton",
				Enum.UserInputState.Begin
			)

			return
		end

		if UseConsumable
			and PlayerStats
			and not Equipped
			and (EmergencyHealth or ShouldHeal)
		then
			local LastConsumed = PlayerStats:FindFirstChild("LastConsumed")

			if LastConsumed
				and LastConsumed.Value ~= ""
				and now - LAST_CONSUME_TIME >= CONFIG.CONSUME_INTERVAL
			then
				LAST_CONSUME_TIME = now
				UseConsumable:InvokeServer(LastConsumed.Value)
			end
		end

		return
	end

	--// Player Check
	if BlockEnabled and isTargetPlace then
		local HasOtherPlayer   = false
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

	--// Play Time
	if workspace.DistributedGameTime >= CONFIG.MAX_SERVER_AGE then
		TeleportToPlace()
		return
	end

	--// Movement
	local AtLastWaypoint = not PlaceConfig or CONFIG.CURRENT_WAYPOINT_TARGET >= #PlaceConfig.WAYPOINTS
	local target = PlaceConfig and PlaceConfig.WAYPOINTS[CONFIG.CURRENT_WAYPOINT_TARGET] or nil

	if not ClosestTarget then
		ClosestTarget = GetClosestGoblin()
	end

	if ClosestTarget and ClosestTarget.Parent and not IsTargetLockValid(ClosestTarget) then
		ClosestTarget = nil
	end

	if PlaceConfig
		and Feature.ReturnToFarmZone.Enabled
		and not ClosestTarget
		and (Feature.AutoFind.Enabled or AtLastWaypoint)
		and not Feature.IgnoreFarmZone.Enabled
		and (not IsInsideFarmArea(RootPart.Position) or IsInsideFarmDeadzone(RootPart.Position))
	then
		MoveBackToFarmZone()
	elseif PlaceConfig and not Feature.AutoFind.Enabled and not AtLastWaypoint then
		if (RootPart.Position - target).Magnitude <= PlaceConfig.REACH_DISTANCE then
			CONFIG.CURRENT_WAYPOINT_TARGET += 1
			target = PlaceConfig.WAYPOINTS[CONFIG.CURRENT_WAYPOINT_TARGET]
		end

		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:MoveTo(target)
		if now - LAST_STUCK_TIME >= CONFIG.STUCK_CHECK_INTERVAL then
			LAST_STUCK_TIME = now
			if LAST_STUCK_POSITION and (RootPart.Position - LAST_STUCK_POSITION).Magnitude < 1 then
				DoJump()
			else
				LAST_STUCK_POSITION = RootPart.Position
			end
		end
	elseif ClosestTarget then
		MoveToGoblin(ClosestTarget)
	elseif Feature.AutoPatrol.Enabled and (Feature.AutoFind.Enabled or AtLastWaypoint) then
		MoveToPatrol()
	elseif not ClosestTarget and not Feature.ReturnToFarmZone.Enabled and not Feature.IgnoreFarmZone.Enabled then
		PatrolPosition = nil
		FarmReturnPosition = nil
		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
	else
		PatrolPosition = nil
		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
	end

	--// Jump
	if PlaceConfig and not Feature.AutoFind.Enabled and not AtLastWaypoint then
		local heightDifference = target.Y - RootPart.Position.Y

		if heightDifference >= CONFIG.JUMP_HEIGHT then
			DoJump()
		end
	end

	--// Swim Recovery
	if Humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		DoJump()
		return
	end

	if Humanoid.Sit == true then
		Humanoid.Sit = false
		DoJump()
		return
	end

	--// Combat
	if Feature.AutoFind.Enabled or AtLastWaypoint then
		if ClosestTarget then
			if not IsTargetLockValid(ClosestTarget) then
				ClosestTarget = nil
				return
			end

			if not IsCombatTargetValid(ClosestTarget) then
				FaceOrientation.Enabled = false
				Humanoid.AutoRotate = true
				Humanoid:Move(Vector3.zero)
				return
			end

			if not Equipped or ( MainWeld.Part1 and MainWeld.Part1.Name == "UpperTorso" ) then
				Equipped = true

				InputBindableFunction:Invoke(
					"EquipButton",
					Enum.UserInputState.Begin
				)

				return
			end

			local MobHumanoid = ClosestTarget:FindFirstChildOfClass("Humanoid")
			local MobRoot     = ClosestTarget:FindFirstChild("HumanoidRootPart")

			if MobHumanoid and MobRoot and MobHumanoid.Health > 0 then
				local Offset = MobRoot.Position - RootPart.Position
				local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

				if CONFIG.DISTANCE_Y_CALCULATE then
					Distance = Offset.Magnitude
				end

				local AttackDistance = 30

				if Distance <= AttackDistance and now - LAST_ATTACK_TIME >= CONFIG.ATTACK_INTERVAL then
					LAST_ATTACK_TIME = now

					InputBindableFunction:Invoke(
						"AttackButton",
						Enum.UserInputState.Begin
					)
				end

				--// SKILL
				if Distance <= 15 and Feature.AutoSkill.Enabled then
					if now - LAST_SKILL_TIME >= CONFIG.SKILL_INTERVAL then
						LAST_SKILL_TIME = now

						InputBindableFunction:Invoke(
							"SkillButton",
							Enum.UserInputState.Begin
						)
					end
				end
			else
				ValidMobs[ClosestTarget] = nil
				ClosestTarget = nil
			end
		end
	else
		if now - LAST_INTERACTION_TIME >= CONFIG.INTERACTION_INTERVAL then
			LAST_INTERACTION_TIME = now

			InputBindableFunction:Invoke(
				"InteractButton",
				Enum.UserInputState.Begin
			)
		end
	end
end)
