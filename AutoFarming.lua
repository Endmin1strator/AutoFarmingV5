local Players            = game:GetService("Players")
local Replicated         = game:GetService("ReplicatedStorage")
local StarterGui         = game:GetService("StarterGui")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local PathfindingService  = game:GetService("PathfindingService")
local HttpService        = game:GetService("HttpService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10)

--// Utils is expected to be a ModuleScript named "Utils" under ReplicatedStorage.
local Utils = loadstring(game:HttpGet("https://raw.githubusercontent.com/Endmin1strator/AutoFarmingV5/refs/heads/master/Utils.lua"))()
local UI = Utils.new("AUTO FARMING v2.12")

local function NotifyAction(Action, Message, Duration)
	if UI and type(UI.Notify) == "function" then
		UI:Notify(Action, Message, Duration or 2.5)
	end
end

local CONFIG = {
	CURRENT_WAYPOINT_TARGET = 1,
	MAX_SERVER_AGE = 7 * 60 * 60,

	TARGET_ENTITY_PRIORITY = {
		[1] = "Goblin",
		[2] = "Leader Goblin",
	},

	GOBLIN_REACH_DISTANCE = 8,
	PLAYER_ATTACK_DISTANCE = 12,
	ENEMY_ATTACK_SAFE_DISTANCE = 2,
	ENEMY_BLADE_PADDING = 2,
	SAFE_ENEMY_RANGE = 4,
	GROUP_DANGER_DISTANCE = 22,
	THREAT_DETECTION_DISTANCE = 12,
	THREAT_ANGLE = 65,
	THREAT_ESCAPE_DISTANCE = 20,
	RETREAT_NEARBY_MOB_DISTANCE = 30,
	RETREAT_HEALTH_PERCENT = 40,
	AUTO_HEAL_HEALTH_PERCENT = 65,

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
	OTHER_ATTACKER_SIDE_SWITCH_MIN = 0.1,
	OTHER_ATTACKER_SIDE_SWITCH_MAX = 0.3,
	OTHER_PLAYER_DETOUR_DISTANCE = 4,

	RETREAT_DISTANCE = 60,
	RETREAT_DIRECTIONS = 16,
	RETREAT_RECALCULATE_INTERVAL = 0.12,
	RETREAT_NO_POSITION_TIMEOUT = 1.5,
	SKILL_RETREAT_DISTANCE = 60,
	SKILL_RETREAT_PATH_TIMEOUT = 0.35,

	ATTACK_INTERVAL = 0.2,
	SKILL_INTERVAL = 3,
	CONSUME_INTERVAL = 10,
	MINIMUM_WALKSPEED = 28,
	MAXIMUM_WALKSPEED = 38,
	INTERACTION_INTERVAL = 0.5,
	TEXT_UPDATE_INTERVAL = 0.5,

	DEBUG_VISUALIZE_WAYPOINTS = true,
	DEBUG_WAYPOINT_MAX_DISTANCE = 500,
	DEBUG_WAYPOINT_SIZE = 0.75,
	DEBUG_ZONE_HEIGHT = 0.15,

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
			[4] = "Marina the South Sea Commander",
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

--//==============================================================
--// Profile Store
--// Profiles are stored per PlaceId. The last used profile for the
--// current place is restored automatically on the next execution.
--//==============================================================
local PROFILE_FOLDER = "AutoFarmProfiles"
local PROFILE_FILE = PROFILE_FOLDER .. "/" .. tostring(game.PlaceId) .. ".json"

local ActiveProfileName = nil
local ProfileData = nil
local ProfileDropdown = nil
local ProfileNameBox = nil
local ImportDataBox = nil
local ProfileStatusLabel = nil
local ReachDistanceBox = nil

local DeadzoneEscapePosition = nil
local PatrolPosition              = nil
local LastPatrolCalculateTime     = 0
local PatrolDirection             = nil
local PatrolPauseUntil            = 0
local PatrolLastPosition          = nil
local PatrolLastDistance           = 0
local FarmReturnPosition          = nil
local LastFarmReturnCalculateTime = 0
local FarmZonePicker
local DeadzonePicker
local SelectedFarmZoneIndex = 1
local SelectedDeadzoneIndex = 1
local FarmRadiusSlider
local DeadzoneRadiusSlider
local SafeEnemyRangeSlider


function CanUseFileStorage()
	return type(readfile) == "function"
		and type(writefile) == "function"
		and type(isfile) == "function"
end

function EnsureProfileFolder()
	if type(makefolder) ~= "function" then
		return
	end

	pcall(function()
		makefolder(PROFILE_FOLDER)
	end)
end

function EncodeVector3(Value)
	if typeof(Value) ~= "Vector3" then
		return { X = 0, Y = 0, Z = 0 }
	end

	return {
		X = Value.X,
		Y = Value.Y,
		Z = Value.Z,
	}
end

function DecodeVector3(Value)
	if typeof(Value) == "Vector3" then
		return Value
	end

	if type(Value) ~= "table" then
		return Vector3.zero
	end

	return Vector3.new(
		tonumber(Value.X) or 0,
		tonumber(Value.Y) or 0,
		tonumber(Value.Z) or 0
	)
end

function CloneVectorList(List)
	local Result = {}

	for _, Value in ipairs(List or {}) do
		table.insert(Result, DecodeVector3(Value))
	end

	return Result
end

function CloneZoneList(List)
	local Result = {}

	for _, Zone in ipairs(List or {}) do
		if type(Zone) == "table" and Zone.Center then
			table.insert(Result, {
				Center = DecodeVector3(Zone.Center),
				Radius = math.max(0, tonumber(Zone.Radius) or 0),
			})
		end
	end

	return Result
end

function SerializeVectorList(List)
	local Result = {}

	for _, Value in ipairs(List or {}) do
		table.insert(Result, EncodeVector3(Value))
	end

	return Result
end

function SerializeZoneList(List)
	local Result = {}

	for _, Zone in ipairs(List or {}) do
		if Zone and Zone.Center then
			table.insert(Result, {
				Center = EncodeVector3(Zone.Center),
				Radius = tonumber(Zone.Radius) or 0,
			})
		end
	end

	return Result
end

function NormalizePlaceConfig(Config)
	Config = Config or {}

	local Waypoints = CloneVectorList(Config.WAYPOINTS)
	local FarmZones = CloneZoneList(Config.FARM_ZONES)
	local Deadzones = CloneZoneList(Config.DEADZONES)

	--// Backwards compatibility with the existing place_config format.
	if #FarmZones == 0 and Config.FARM_CENTER then
		table.insert(FarmZones, {
			Center = DecodeVector3(Config.FARM_CENTER),
			Radius = math.max(0, tonumber(Config.FARM_RADIUS) or 0),
		})
	end

	if #Deadzones == 0 and Config.FARM_DEADZONE_CENTER then
		local Radius = tonumber(Config.FARM_DEADZONE_RADIUS) or 0

		if Radius > 0 then
			table.insert(Deadzones, {
				Center = DecodeVector3(Config.FARM_DEADZONE_CENTER),
				Radius = Radius,
			})
		end
	end

	local FirstFarm = FarmZones[1]
	local FirstDeadzone = Deadzones[1]

	Config.WAYPOINTS = Waypoints
	Config.FARM_ZONES = FarmZones
	Config.DEADZONES = Deadzones

	--// Legacy aliases remain available to old code while the actual logic
	--// supports multiple zones.
	--// Do not manufacture Vector3.zero when a zone does not exist.
	--// Missing zones stay nil so farm logic never treats (0, 0, 0) as a real zone.
	Config.FARM_CENTER = FirstFarm and FirstFarm.Center or nil
	Config.FARM_RADIUS = FirstFarm and FirstFarm.Radius or nil
	Config.FARM_DEADZONE_CENTER = FirstDeadzone and FirstDeadzone.Center or nil
	Config.FARM_DEADZONE_RADIUS = FirstDeadzone and FirstDeadzone.Radius or nil

	Config.REACH_DISTANCE = tonumber(Config.REACH_DISTANCE) or 5
	Config.AUTOBLOCK = Config.AUTOBLOCK == true

	return Config
end

PlaceConfig = NormalizePlaceConfig(PlaceConfig or {})

local BasePlaceConfig = NormalizePlaceConfig(IsValidPlace(game.PlaceId) or {})

function SerializeConfigValue(Value)
	if typeof(Value) == "Vector3" then
		return EncodeVector3(Value)
	end

	if type(Value) ~= "table" then
		return Value
	end

	local Result = {}
	for Key, Item in pairs(Value) do
		Result[Key] = SerializeConfigValue(Item)
	end
	return Result
end

function DeserializeConfigValue(Value)
	if type(Value) ~= "table" then
		return Value
	end

	if Value.X ~= nil and Value.Y ~= nil and Value.Z ~= nil
		and type(Value.X) == "number"
		and type(Value.Y) == "number"
		and type(Value.Z) == "number"
	then
		return DecodeVector3(Value)
	end

	local Result = {}
	for Key, Item in pairs(Value) do
		Result[Key] = DeserializeConfigValue(Item)
	end
	return Result
end

function MergeConfig(Base, Override)
	local Result = {}

	for Key, Value in pairs(Base or {}) do
		Result[Key] = DeserializeConfigValue(SerializeConfigValue(Value))
	end

	for Key, Value in pairs(Override or {}) do
		if type(Value) == "table" and type(Result[Key]) == "table" then
			Result[Key] = MergeConfig(Result[Key], Value)
		else
			Result[Key] = DeserializeConfigValue(Value)
		end
	end

	return Result
end

function BuildDefaultProfile()
	return {
		Name = "",
		PlaceId = game.PlaceId,
		--// Keep the complete place_config/default config inside the profile.
		PLACE_CONFIG = SerializeConfigValue(BasePlaceConfig),
		WAYPOINTS = CloneVectorList(BasePlaceConfig.WAYPOINTS),
		FARM_ZONES = CloneZoneList(BasePlaceConfig.FARM_ZONES),
		DEADZONES = CloneZoneList(BasePlaceConfig.DEADZONES),
		DEFAULT_TARGET_PRIORITY = table.clone(
			BasePlaceConfig.DEFAULT_TARGET_PRIORITY
				or CONFIG.TARGET_ENTITY_PRIORITY
				or {}
		),
		FEATURES = {},
		SETTINGS = {
			REACH_DISTANCE = BasePlaceConfig.REACH_DISTANCE or 5,
			AUTOBLOCK = BasePlaceConfig.AUTOBLOCK == true,
		},
	}
end

function ReadProfileStore()
	if not CanUseFileStorage() then
		return {
			Profiles = {},
			LastUsed = nil,
		}
	end

	EnsureProfileFolder()

	if not isfile(PROFILE_FILE) then
		return {
			Profiles = {},
			LastUsed = nil,
		}
	end

	local Success, Raw = pcall(readfile, PROFILE_FILE)

	if not Success or type(Raw) ~= "string" or Raw == "" then
		return {
			Profiles = {},
			LastUsed = nil,
		}
	end

	local DecodeSuccess, Data = pcall(function()
		return HttpService:JSONDecode(Raw)
	end)

	if not DecodeSuccess or type(Data) ~= "table" then
		return {
			Profiles = {},
			LastUsed = nil,
		}
	end

	Data.Profiles = type(Data.Profiles) == "table" and Data.Profiles or {}
	return Data
end

local ProfileStore = ReadProfileStore()

function WriteProfileStore()
	if not CanUseFileStorage() then
		return false
	end

	EnsureProfileFolder()

	local Success, Raw = pcall(function()
		return HttpService:JSONEncode(ProfileStore)
	end)

	if not Success then
		warn("AutoFarm profile encode failed:", Raw)
		return false
	end

	local WriteSuccess, WriteError = pcall(writefile, PROFILE_FILE, Raw)

	if not WriteSuccess then
		warn("AutoFarm profile save failed:", WriteError)
		return false
	end

	return true
end

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
	DebugVisualizer = {
		Enabled = CONFIG.DEBUG_VISUALIZE_WAYPOINTS,
		Button = nil,
		Status = nil,
	},
	DebugWaypoints = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	DebugFarmZones = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	DebugDeadzones = {
		Enabled = true,
		Button = nil,
		Status = nil,
	},
	DebugRadiusLabels = {
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
local SkillRetreatPosition      = nil
local LastSkillRetreatTime      = 0

local LAST_ATTACK_TIME = 0
local LAST_SKILL_TIME  = 0

--// Potion Consume

local LAST_CONSUME_TIME = 0
local LAST_INTERACTION_TIME = 0
local LAST_TEXT_UPDATE_TIME = 0
local LAST_STUCK_TIME = 0
local LAST_STUCK_POSITION = nil

local CACHED_SAFECOMBAT_POSITION = nil
local CACHED_SAFECOMBAT_TARGET   = nil
local LAST_SAFECOMBAT_TIME       = 0
local LastAttackerCombatMob = nil
local LastAttackerCombatSide = 1
local LastAttackerCombatSwitchTime = 0
local LastAttackerCombatPosition = nil

local BladePartCache   = {}
local CombatGroupCache = {}
local CombatBladeCache = {}

local LastDirectPathCheckTime = 0
local LastDirectPathTarget = nil
local LastDirectPathPosition = nil
local LastDirectPathBlocked = false

local LastDeadzoneEscapeTime = 0

--// Debug Visualizer
local DebugFolder       = nil
local DebugWaypointData = {}
local DebugFarmZone     = nil
local DebugDeadzone     = nil
local DebugZoneSignature = nil
local DebugWaypointSignature = nil

local DEBUG_COLORS = {
	WaypointPending = Color3.fromRGB(108, 119, 117),
	WaypointCurrent = Color3.fromRGB(220, 205, 0),
	WaypointVisited = Color3.fromRGB(165, 195, 170),
	WaypointLine    = Color3.fromRGB(220, 205, 0),
	FarmZone        = Color3.fromRGB(80, 125, 95),
	Deadzone        = Color3.fromRGB(150, 65, 65),
	BillboardPanel  = Color3.fromRGB(27, 32, 33),
	BillboardBorder = Color3.fromRGB(79, 91, 91),
	BillboardText   = Color3.fromRGB(232, 237, 235),
	BillboardMuted  = Color3.fromRGB(171, 181, 179),
}

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

function CaptureFeatureState()
	local Result = {
		AutoFarm = Enabled,
	}

	for Name, Data in pairs(Feature) do
		if type(Data) == "table" and type(Data.Enabled) == "boolean" then
			Result[Name] = Data.Enabled
		end
	end

	return Result
end

function ApplyFeatureState(State)
	if type(State) ~= "table" then
		return
	end

	if type(State.AutoFarm) == "boolean" then
		Enabled = State.AutoFarm
	end

	for Name, Data in pairs(Feature) do
		if type(Data) == "table"
			and type(State[Name]) == "boolean"
		then
			Data.Enabled = State[Name]
		end
	end

	if type(State.AutoBlock) == "boolean" then
		BlockEnabled = State.AutoBlock
	end

	if type(State.SafeCombat) == "boolean" then
		SafeCombatPositionEnabled = State.SafeCombat
	end

	if type(State.AutoFind) == "boolean" then
		WaypointEnabled = not State.AutoFind
	end
end

function CaptureCurrentProfile(Name)
	local FarmConfig = NormalizePlaceConfig(PlaceConfig)

	return {
		Name = Name or ActiveProfileName or "",
		PlaceId = game.PlaceId,
		PLACE_CONFIG = SerializeConfigValue(FarmConfig),
		WAYPOINTS = SerializeVectorList(FarmConfig.WAYPOINTS),
		FARM_ZONES = SerializeZoneList(FarmConfig.FARM_ZONES),
		DEADZONES = SerializeZoneList(FarmConfig.DEADZONES),
		DEFAULT_TARGET_PRIORITY = table.clone(CONFIG.TARGET_ENTITY_PRIORITY or {}),
		FEATURES = CaptureFeatureState(),
		SETTINGS = {
			REACH_DISTANCE = tonumber(FarmConfig.REACH_DISTANCE) or 5,
			AUTOBLOCK = BlockEnabled == true,
			RETREAT_HEALTH_PERCENT = math.clamp(tonumber(CONFIG.RETREAT_HEALTH_PERCENT) or 40, 30, 80),
			AUTO_HEAL_HEALTH_PERCENT = math.clamp(tonumber(CONFIG.AUTO_HEAL_HEALTH_PERCENT) or 65, 30, 80),
			SAFE_ENEMY_RANGE = math.clamp(tonumber(CONFIG.SAFE_ENEMY_RANGE) or 4, 0, 30),
		},
	}
end

function AreSerializedValuesEqual(A, B)
	local TypeA = type(A)
	local TypeB = type(B)

	if TypeA ~= TypeB then
		return false
	end

	if TypeA ~= "table" then
		return A == B
	end

	for Key, Value in pairs(A) do
		if not AreSerializedValuesEqual(Value, B[Key]) then
			return false
		end
	end

	for Key in pairs(B) do
		if A[Key] == nil then
			return false
		end
	end

	return true
end

function IsArrayTable(Value)
	if type(Value) ~= "table" then
		return false
	end

	for Key in pairs(Value) do
		if type(Key) ~= "number" then
			return false
		end
	end

	return true
end

function BuildCompactConfig(Base, Current)
	local BaseData = SerializeConfigValue(Base or {})
	local CurrentData = SerializeConfigValue(Current or {})

	local function Diff(BaseValue, CurrentValue)
		if type(CurrentValue) ~= "table" then
			if AreSerializedValuesEqual(BaseValue, CurrentValue) then
				return nil
			end
			return CurrentValue
		end

		if IsArrayTable(CurrentValue) or IsArrayTable(BaseValue) then
			if AreSerializedValuesEqual(BaseValue, CurrentValue) then
				return nil
			end
			return CurrentValue
		end

		local Result = {}
		local Changed = false

		for Key, Value in pairs(CurrentValue) do
			local Difference = Diff(BaseValue and BaseValue[Key], Value)
			if Difference ~= nil then
				Result[Key] = Difference
				Changed = true
			end
		end

		return Changed and Result or nil
	end

	return Diff(BaseData, CurrentData) or {}
end

local COMPACT_FEATURE_KEYS = {
	AutoFarm = "a",
	AutoBlock = "b",
	SafeCombat = "c",
	AutoFind = "d",
	IgnoreFarmZone = "e",
	AutoPatrol = "f",
	ReturnToFarmZone = "g",
	AutoSkill = "h",
	ResetOnBoostOut = "i",
	ResetStats = "j",
	DebugVisualizer = "k",
}

function BuildCompactProfile(Name)
	local Full = CaptureCurrentProfile(Name)
	local BasePriority = BasePlaceConfig.DEFAULT_TARGET_PRIORITY
		or CONFIG.TARGET_ENTITY_PRIORITY
		or {}

	local Compact = {
		n = Full.Name,
		p = Full.PlaceId,
		c = BuildCompactConfig(BasePlaceConfig, PlaceConfig),
		s = Full.SETTINGS,
	}

	if not AreSerializedValuesEqual(Full.DEFAULT_TARGET_PRIORITY, BasePriority) then
		Compact.t = Full.DEFAULT_TARGET_PRIORITY
	end

	local Features = {}
	for NameKey, CompactKey in pairs(COMPACT_FEATURE_KEYS) do
		local Value = Full.FEATURES and Full.FEATURES[NameKey]
		if type(Value) == "boolean" then
			Features[CompactKey] = Value
		end
	end

	if next(Features) then
		Compact.f = Features
	end

	return Compact
end

function ExpandCompactProfile(Data)
	if type(Data) ~= "table" then
		return nil, "IMPORT FAILED: Invalid JSON"
	end

	--// New compact format.
	if Data.n ~= nil or Data.c ~= nil or Data.f ~= nil or Data.t ~= nil then
		local Features = {}
		for NameKey, CompactKey in pairs(COMPACT_FEATURE_KEYS) do
			if type(Data.f) == "table" and type(Data.f[CompactKey]) == "boolean" then
				Features[NameKey] = Data.f[CompactKey]
			end
		end

		local Config = DeserializeConfigValue(Data.c or {})
		local Settings = type(Data.s) == "table" and Data.s or {}
		if Config.REACH_DISTANCE ~= nil then
			Settings.REACH_DISTANCE = tonumber(Config.REACH_DISTANCE)
		end
		if Config.AUTOBLOCK ~= nil then
			Settings.AUTOBLOCK = Config.AUTOBLOCK == true
		end

		return {
			Name = Data.n,
			PlaceId = Data.p,
			PLACE_CONFIG = Data.c or {},
			DEFAULT_TARGET_PRIORITY = Data.t,
			FEATURES = Features,
			SETTINGS = Settings,
		}, nil
	end

	--// Backwards compatibility: allow importing the old full JSON format.
	return Data, nil
end

function ExportActiveProfile()
	if not ActiveProfileName then
		return false, "EXPORT FAILED: No active profile"
	end

	if type(setclipboard) ~= "function" then
		return false, "EXPORT FAILED: setclipboard is unavailable"
	end

	local ExportData = BuildCompactProfile(ActiveProfileName)
	local Success, Raw = pcall(function()
		return HttpService:JSONEncode(ExportData)
	end)

	if not Success then
		return false, "EXPORT FAILED: JSON encode error"
	end

	local ClipboardSuccess, ClipboardError = pcall(setclipboard, Raw)
	if not ClipboardSuccess then
		return false, "EXPORT FAILED: " .. tostring(ClipboardError)
	end

	return true, Raw
end

function ImportProfileFromText(Raw)
	if type(Raw) ~= "string" or Raw == "" then
		return false, "IMPORT FAILED: Import textbox is empty"
	end

	local DecodeSuccess, Data = pcall(function()
		return HttpService:JSONDecode(Raw)
	end)

	if not DecodeSuccess or type(Data) ~= "table" then
		return false, "IMPORT FAILED: Invalid JSON"
	end

	local ExpandedData, ExpandError = ExpandCompactProfile(Data)
	if not ExpandedData then
		return false, ExpandError or "IMPORT FAILED: Invalid profile data"
	end

	if tonumber(ExpandedData.PlaceId) ~= tonumber(game.PlaceId) then
		return false, "IMPORT FAILED: PlaceId mismatch"
	end

	local Name = tostring(ExpandedData.Name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if Name == "" then
		Name = "Imported Profile"
	end

	local BaseName = Name
	local Suffix = 2
	while ProfileStore.Profiles[Name] do
		Name = BaseName .. " " .. tostring(Suffix)
		Suffix += 1
	end

	ExpandedData.Name = Name
	ExpandedData.PlaceId = game.PlaceId
	ProfileStore.Profiles[Name] = ExpandedData
	ProfileStore.LastUsed = Name

	if not WriteProfileStore() then
		ProfileStore.Profiles[Name] = nil
		return false, "IMPORT FAILED: Could not save profile"
	end

	if not LoadProfile(Name) then
		return false, "IMPORT FAILED: Could not load profile"
	end

	return true, Name
end

function SaveActiveProfile()
	if not ActiveProfileName then
		return false
	end

	ProfileData = CaptureCurrentProfile(ActiveProfileName)
	ProfileStore.Profiles[ActiveProfileName] = ProfileData
	ProfileStore.LastUsed = ActiveProfileName

	return WriteProfileStore()
end

function ApplyProfileData(Data)
	if type(Data) ~= "table" then
		return false
	end

	local StoredPlaceConfig = DeserializeConfigValue(Data.PLACE_CONFIG)
	local FarmConfig = MergeConfig(BasePlaceConfig, StoredPlaceConfig)

	--// Backwards compatibility for profiles created before PLACE_CONFIG existed.
	FarmConfig.WAYPOINTS = CloneVectorList(Data.WAYPOINTS or FarmConfig.WAYPOINTS)
	FarmConfig.FARM_ZONES = CloneZoneList(Data.FARM_ZONES or FarmConfig.FARM_ZONES)
	FarmConfig.DEADZONES = CloneZoneList(Data.DEADZONES or FarmConfig.DEADZONES)
	FarmConfig.REACH_DISTANCE = tonumber(Data.SETTINGS and Data.SETTINGS.REACH_DISTANCE)
		or tonumber(FarmConfig.REACH_DISTANCE)
		or 5
	if Data.SETTINGS and type(Data.SETTINGS.AUTOBLOCK) == "boolean" then
		FarmConfig.AUTOBLOCK = Data.SETTINGS.AUTOBLOCK
	else
		FarmConfig.AUTOBLOCK = FarmConfig.AUTOBLOCK == true
	end

	CONFIG.RETREAT_HEALTH_PERCENT = math.clamp(
		type(Data.SETTINGS and Data.SETTINGS.RETREAT_HEALTH_PERCENT) == "number"
			and Data.SETTINGS.RETREAT_HEALTH_PERCENT
			or 40,
		30,
		80
	)

	CONFIG.AUTO_HEAL_HEALTH_PERCENT = math.clamp(
		type(Data.SETTINGS and Data.SETTINGS.AUTO_HEAL_HEALTH_PERCENT) == "number"
			and Data.SETTINGS.AUTO_HEAL_HEALTH_PERCENT
			or 65,
		30,
		80
	)

	CONFIG.SAFE_ENEMY_RANGE = math.clamp(
		type(Data.SETTINGS and Data.SETTINGS.SAFE_ENEMY_RANGE) == "number"
			and Data.SETTINGS.SAFE_ENEMY_RANGE
			or 4,
		0,
		30
	)

	PlaceConfig = NormalizePlaceConfig(FarmConfig)

	CONFIG.TARGET_ENTITY_PRIORITY = table.clone(
		Data.DEFAULT_TARGET_PRIORITY
			or BasePlaceConfig.DEFAULT_TARGET_PRIORITY
			or {}
	)

	Feature.AutoBlock.Enabled = PlaceConfig.AUTOBLOCK
	BlockEnabled = PlaceConfig.AUTOBLOCK

	ApplyFeatureState(Data.FEATURES)

	CONFIG.CURRENT_WAYPOINT_TARGET = 1
	ResetTargetReposition()
	DeadzoneEscapePosition = nil
	PatrolPosition = nil
	FarmReturnPosition = nil
	SelectedFarmZoneIndex = 1
	SelectedDeadzoneIndex = 1
	LastPatrolCalculateTime = 0
	LastFarmReturnCalculateTime = 0

	return true
end

function LoadProfile(Name)
	local Data = ProfileStore.Profiles[Name]

	if type(Data) ~= "table" then
		return false
	end

	if ApplyProfileData(Data) then
		ActiveProfileName = Name
		ProfileData = Data
		ProfileStore.LastUsed = Name
		WriteProfileStore()
		return true
	end

	return false
end

function DeleteProfile(Name)
	if not Name or not ProfileStore.Profiles[Name] then
		return false
	end

	ProfileStore.Profiles[Name] = nil

	if ProfileStore.LastUsed == Name then
		ProfileStore.LastUsed = nil
	end

	if ActiveProfileName == Name then
		ActiveProfileName = nil
		ProfileData = nil
		PlaceConfig = NormalizePlaceConfig(IsValidPlace(game.PlaceId) or {})
		CONFIG.TARGET_ENTITY_PRIORITY = table.clone(
			BasePlaceConfig.DEFAULT_TARGET_PRIORITY
				or {}
		)
		Feature.AutoBlock.Enabled = BasePlaceConfig.AUTOBLOCK == true
		BlockEnabled = BasePlaceConfig.AUTOBLOCK == true
		CONFIG.CURRENT_WAYPOINT_TARGET = 1
	end

	WriteProfileStore()
	return true
end

function CreateProfile(Name)
	Name = tostring(Name or ""):gsub("^%s+", ""):gsub("%s+$", "")

	if Name == "" or #Name > 32 then
		return false, "Invalid profile name"
	end

	if Name:find("[/\\:%*%?\"<>|]") then
		return false, "Invalid profile name"
	end

	if ProfileStore.Profiles[Name] then
		return false, "Profile already exists"
	end

	ActiveProfileName = Name
	ProfileData = BuildDefaultProfile()
	ProfileData.Name = Name

	ApplyProfileData(ProfileData)

	ProfileStore.Profiles[Name] = CaptureCurrentProfile(Name)
	ProfileStore.LastUsed = Name
	WriteProfileStore()

	return true
end

function GetProfileNames()
	local Names = {}

	for Name in pairs(ProfileStore.Profiles) do
		table.insert(Names, Name)
	end

	table.sort(Names, function(A, B)
		return string.lower(A) < string.lower(B)
	end)

	return Names
end



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
	CACHED_SAFECOMBAT_POSITION = nil
	CACHED_SAFECOMBAT_TARGET = nil
	LastAttackerCombatMob = nil
	LastAttackerCombatPosition = nil
	LastAttackerCombatSwitchTime = 0
	LAST_SAFECOMBAT_TIME = 0
	LastDirectPathTarget = nil
	LastDirectPathPosition = nil
	CombatBladeCache = {}
end


--// Toggle Screen GUI
function CreateToggleContainer()
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
	ResetDebugWaypoints()
	UpdateDebugWaypointColors()
	ClosestTarget = nil
	InputBindableFunction = nil
	BlockValue = nil
	Equipped = false
	RETREATING = false
	SkillRetreatPosition = nil
	LastSkillRetreatTime = 0
	LAST_ATTACK_TIME = 0
	LAST_SKILL_TIME = 0
	LAST_CONSUME_TIME = 0
	LAST_INTERACTION_TIME = 0
	LAST_STUCK_POSITION = nil
	FaceAttachment = nil
	FaceOrientation = nil

	if DebugFolder then
		--// Keep the debug instances, but reset their state/colors for the new life.
		for Index, Data in DebugWaypointData do
			if Data.Label then
				Data.Label.TextColor3 = DEBUG_COLORS.WaypointPending
			end
			if Data.Marker then
				Data.Marker.BackgroundColor3 = DEBUG_COLORS.WaypointPending
			end
		end
	end

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

function AutoRefillBooster()
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



--//==============================================================
--// Utility UI
--//==============================================================

--UI:SetTheme({
--	Background      = CONFIG.UI_PANEL,
--	BackgroundLight = CONFIG.UI_SURFACE,
--	Panel           = CONFIG.UI_SURFACE,
--	PanelLight      = CONFIG.UI_HOVER,
--	PanelHover      = Color3.fromRGB(48, 50, 60),
--	Element         = CONFIG.UI_SURFACE,
--	ElementHover    = CONFIG.UI_HOVER,
--	Text            = CONFIG.UI_TEXT,
--	TextSecondary   = Color3.fromRGB(190, 193, 204),
--	TextMuted       = CONFIG.UI_MUTED,
--	Cyan            = CONFIG.UI_ACCENT,
--	CyanDark        = Color3.fromRGB(80, 90, 190),
--	CyanDim         = Color3.fromRGB(150, 160, 255),
--	White           = CONFIG.UI_TEXT,
--	Border          = CONFIG.UI_BORDER,
--	BorderDim       = Color3.fromRGB(45, 48, 58),
--	Danger          = Color3.fromRGB(255, 65, 65),
--	Warning         = Color3.fromRGB(255, 180, 0),
--	Black           = Color3.fromRGB(10, 10, 14),
--})

local FarmTab = UI:AddTab("Farm")
local StatusTab = UI:AddTab("Status")
local DebugTab = UI:AddTab("Debug")

local FeatureSection = FarmTab:AddSection("Features")
local TargetSection  = FarmTab:AddSection("Targeting")
local StatusSection  = StatusTab:AddSection("Live Status")
local DebugSection   = DebugTab:AddSection("Debug Visualizer")

function CreateFeature(Name, Default, Callback)
	local Component = FeatureSection:AddToggle(Name, Default, Callback)

	return Component
end

function SetFeatureComponent(Name, Value)
	local Data = Feature[Name]

	if Data and Data.Button then
		Data.Button:Set(Value, false)
	end
end

--// Feature toggles
Feature.AutoFarm.Button = CreateFeature("Auto Farm", Enabled, function(Value)
	Enabled = Value
	Feature.AutoFarm.Enabled = Value
	SaveActiveProfile()
end)

Feature.AutoBlock.Button = CreateFeature("Auto Block", Feature.AutoBlock.Enabled, function(Value)
	Feature.AutoBlock.Enabled = Value
	BlockEnabled = Value
	SaveActiveProfile()
end)

Feature.SafeCombat.Button = CreateFeature("Safe Combat", Feature.SafeCombat.Enabled, function(Value)
	Feature.SafeCombat.Enabled = Value
	SafeCombatPositionEnabled = Value

	ResetTargetReposition()
	SaveActiveProfile()
end)

Feature.AutoSkill.Button = CreateFeature("Auto Skill", Feature.AutoSkill.Enabled, function(Value)
	Feature.AutoSkill.Enabled = Value
	SaveActiveProfile()
end)

Feature.AutoFind.Button = CreateFeature("Auto Find", Feature.AutoFind.Enabled, function(Value)
	Feature.AutoFind.Enabled = Value
	WaypointEnabled = not Value

	ClosestTarget = nil
	table.clear(ValidMobs)
	table.clear(CombatGroupCache)

	ResetTargetReposition()
	UpdateValidMobs()
	ClosestTarget = GetClosestGoblin()
	SaveActiveProfile()
end)

Feature.IgnoreFarmZone.Button = CreateFeature("Ignore Farm Zone", Feature.IgnoreFarmZone.Enabled, function(Value)
	Feature.IgnoreFarmZone.Enabled = Value

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
	SaveActiveProfile()
end)

Feature.AutoPatrol.Button = CreateFeature("Auto Patrol", Feature.AutoPatrol.Enabled, function(Value)
	Feature.AutoPatrol.Enabled = Value

	PatrolPosition = nil
	LastPatrolCalculateTime = 0
	PatrolDirection = nil
	PatrolPauseUntil = 0
	PatrolLastPosition = nil
	PatrolLastDistance = 0
	SaveActiveProfile()
end)

Feature.ReturnToFarmZone.Button = CreateFeature("Return To Farm Zone", Feature.ReturnToFarmZone.Enabled, function(Value)
	Feature.ReturnToFarmZone.Enabled = Value

	FarmReturnPosition = nil
	LastFarmReturnCalculateTime = 0
	SaveActiveProfile()
end)

Feature.ResetOnBoostOut.Button = CreateFeature("Refill Booster", Feature.ResetOnBoostOut.Enabled, function(Value)
	Feature.ResetOnBoostOut.Enabled = Value
	SaveActiveProfile()
end)

Feature.ResetStats.Button = FeatureSection:AddButton("Reset Stats", function()
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

Feature.ResetStats.Enabled = true

local RetreatHealthSlider = FeatureSection:AddSlider(
	"Retreat At Health %",
	math.clamp(tonumber(CONFIG.RETREAT_HEALTH_PERCENT) or 40, 30, 80),
	30,
	80,
	function(Value)
		CONFIG.RETREAT_HEALTH_PERCENT = math.clamp(math.floor(tonumber(Value) or 40), 30, 80)
		SaveActiveProfile()
	end
)

local AutoHealHealthSlider = FeatureSection:AddSlider(
	"Auto Heal at HP",
	math.clamp(tonumber(CONFIG.AUTO_HEAL_HEALTH_PERCENT) or 65, 30, 80),
	30,
	80,
	function(Value)
		CONFIG.AUTO_HEAL_HEALTH_PERCENT = math.clamp(math.floor(tonumber(Value) or 65), 30, 80)
		SaveActiveProfile()
	end
)

SafeEnemyRangeSlider = TargetSection:AddSlider(
	"Safe Enemy Range",
	math.clamp(tonumber(CONFIG.SAFE_ENEMY_RANGE) or 4, 0, 30),
	0,
	30,
	function(Value)
		CONFIG.SAFE_ENEMY_RANGE = math.clamp(tonumber(Value) or 4, 0, 30)
		SaveActiveProfile()
	end
)

Feature.DebugVisualizer.Button = FeatureSection:AddToggle(
	"Debug Visualizer",
	Feature.DebugVisualizer.Enabled,
	function(Value)
		Feature.DebugVisualizer.Enabled = Value

		task.defer(function()
			if Value then
				UpdateDebugVisualizer()
			else
				SetDebugVisualizerVisible(false)
			end
		end)

		SaveActiveProfile()
	end
)

--// Debug controls live in their own tab. The master visualizer toggle remains
--// on the Farm tab for quick enable/disable. These controls decide which
--// debug layers are actually rendered.
Feature.DebugWaypoints.Button = DebugSection:AddToggle(
	"Debug Waypoints",
	Feature.DebugWaypoints.Enabled,
	function(Value)
		Feature.DebugWaypoints.Enabled = Value
		UpdateDebugVisualizer()
		SaveActiveProfile()
	end
)

Feature.DebugFarmZones.Button = DebugSection:AddToggle(
	"Debug Farm Zones",
	Feature.DebugFarmZones.Enabled,
	function(Value)
		Feature.DebugFarmZones.Enabled = Value
		UpdateDebugVisualizer()
		SaveActiveProfile()
	end
)

Feature.DebugDeadzones.Button = DebugSection:AddToggle(
	"Debug Deadzones",
	Feature.DebugDeadzones.Enabled,
	function(Value)
		Feature.DebugDeadzones.Enabled = Value
		UpdateDebugVisualizer()
		SaveActiveProfile()
	end
)

Feature.DebugRadiusLabels.Button = DebugSection:AddToggle(
	"Radius Billboard Labels",
	Feature.DebugRadiusLabels.Enabled,
	function(Value)
		Feature.DebugRadiusLabels.Enabled = Value
		UpdateDebugVisualizer()
		SaveActiveProfile()
	end
)

--// Live status labels
local PlaceIDLabel       = StatusSection:AddLabel("PLACE ID       " .. tostring(game.PlaceId))
local WalkSpeedLabel     = StatusSection:AddLabel("WALKSPEED      0")
local WayPointLabel      = StatusSection:AddLabel("WAYPOINTS:  0/" .. (PlaceConfig and #PlaceConfig.WAYPOINTS or 0))
local EventCurrencyLabel = StatusSection:AddLabel("EVENT CURRENCY  0")
local ServerAgeLabel     = StatusSection:AddLabel("PLAY TIME      00:00:00")
local PositionLabel      = StatusSection:AddLabel("POSITION       --")
local DeathLabel         = StatusSection:AddLabel("DEATH          0")
local ExpLabel           = StatusSection:AddLabel("EXP            0/0")

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

		if typeof(Entity.Value) ~= "string" or Entity.Value == "" then
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

function IsEntityInPriority(EntityName: string): boolean
	return table.find(CONFIG.TARGET_ENTITY_PRIORITY, EntityName) ~= nil
end

--// Priority component
local PriorityComponent = TargetSection:AddPriority(
	"Enemy Priority",
	CONFIG.TARGET_ENTITY_PRIORITY
)

-- Keep CONFIG and the Utils priority component on the same table.
CONFIG.TARGET_ENTITY_PRIORITY = PriorityComponent.Priority

local TargetDropdown
local TargetRefreshButton
local AddPriorityTarget

function ResetTargetState()
	ClosestTarget = nil
	table.clear(ValidMobs)
	table.clear(CombatGroupCache)
	ResetTargetReposition()
end

function RefreshTargetDropdown()
	DetectedEntities = GetDetectedEnemyEntities()

	local Options = {}

	for _, Name in ipairs(DetectedEntities) do
		if not IsEntityInPriority(Name) then
			table.insert(Options, Name)
		end
	end

	if #Options == 0 then
		Options = {"No detected enemies"}
	end

	if TargetDropdown then
		if TargetDropdown.Popup then
			TargetDropdown.Popup:Destroy()
		end

		if TargetDropdown.Frame then
			TargetDropdown.Frame:Destroy()
		end
	end

	TargetDropdown = TargetSection:AddDropdown("Add Target", Options, function(Value)
		AddPriorityTarget(Value)
	end)
end

--// Keep Utils priority actions synchronized with the farm state and target dropdown.
local OriginalPriorityAdd      = PriorityComponent.Add
local OriginalPriorityRemove   = PriorityComponent.Remove
local OriginalPriorityMoveUp   = PriorityComponent.MoveUp
local OriginalPriorityMoveDown = PriorityComponent.MoveDown

function SyncPriorityState(RefreshDropdown)
	CONFIG.TARGET_ENTITY_PRIORITY = PriorityComponent.Priority
	ResetTargetState()

	if RefreshDropdown then
		RefreshTargetDropdown()
	end

	SaveActiveProfile()
end

function PriorityComponent:Add(EntityName)
	if not ActiveProfileName then
		return false
	end

	local Changed = OriginalPriorityAdd(self, EntityName)

	if Changed then
		SyncPriorityState(true)
	end

	return Changed
end

function PriorityComponent:Remove(EntityName)
	if not ActiveProfileName then
		return false
	end

	local Changed = OriginalPriorityRemove(self, EntityName)

	if Changed then
		SyncPriorityState(true)
	end

	return Changed
end

function PriorityComponent:MoveUp(EntityName)
	if not ActiveProfileName then
		return
	end

	OriginalPriorityMoveUp(self, EntityName)
	SyncPriorityState(true)
end

function PriorityComponent:MoveDown(EntityName)
	if not ActiveProfileName then
		return
	end

	OriginalPriorityMoveDown(self, EntityName)
	SyncPriorityState(true)
end

AddPriorityTarget = function(EntityName)
	if not EntityName or EntityName == "" or EntityName == "No detected enemies" then
		return
	end

	if IsEntityInPriority(EntityName) then
		return
	end

	PriorityComponent:Add(EntityName)
end

TargetRefreshButton = TargetSection:AddButton("Refresh Detected Targets", function()
	RefreshTargetDropdown()
end)

RefreshTargetDropdown()

--// Utility UI status helpers
function updateFeatureButtons()
	SetFeatureComponent("AutoFarm", Enabled)
	SetFeatureComponent("AutoBlock", Feature.AutoBlock.Enabled)
	SetFeatureComponent("SafeCombat", Feature.SafeCombat.Enabled)
	SetFeatureComponent("AutoSkill", Feature.AutoSkill.Enabled)
	SetFeatureComponent("AutoFind", Feature.AutoFind.Enabled)
	SetFeatureComponent("IgnoreFarmZone", Feature.IgnoreFarmZone.Enabled)
	SetFeatureComponent("AutoPatrol", Feature.AutoPatrol.Enabled)
	SetFeatureComponent("ReturnToFarmZone", Feature.ReturnToFarmZone.Enabled)
	SetFeatureComponent("ResetOnBoostOut", Feature.ResetOnBoostOut.Enabled)
	if Feature.DebugWaypoints.Button then Feature.DebugWaypoints.Button:Set(Feature.DebugWaypoints.Enabled, false) end
	if Feature.DebugFarmZones.Button then Feature.DebugFarmZones.Button:Set(Feature.DebugFarmZones.Enabled, false) end
	if Feature.DebugDeadzones.Button then Feature.DebugDeadzones.Button:Set(Feature.DebugDeadzones.Enabled, false) end
	if Feature.DebugRadiusLabels.Button then Feature.DebugRadiusLabels.Button:Set(Feature.DebugRadiusLabels.Enabled, false) end
end

function updateButton()
	Feature.AutoFarm.Enabled = Enabled
	SetFeatureComponent("AutoFarm", Enabled)
end

updateFeatureButtons()

--//==============================================================
--// Profile Settings
--//==============================================================
local ProfileTab = UI:AddTab("Profile Settings")
local ProfilesSection = ProfileTab:AddSection("Profiles")
local WaypointSection = ProfileTab:AddSection("Waypoints")
local ZoneSection = ProfileTab:AddSection("Farm / Deadzone")

local WaypointListComponent
local FarmZoneListComponent
local DeadzoneListComponent

function FormatVector3(Position)
	if typeof(Position) ~= "Vector3" then
		return "0, 0, 0"
	end

	return string.format("%.1f, %.1f, %.1f", Position.X, Position.Y, Position.Z)
end

function BuildWaypointLabels()
	local Labels = {}

	for Index, Position in ipairs(PlaceConfig.WAYPOINTS or {}) do
		Labels[Index] = string.format("#%d  (%s)", Index, FormatVector3(Position))
	end

	return Labels
end

function BuildZoneLabels(Zones, Prefix)
	local Labels = {}

	for Index, Zone in ipairs(Zones or {}) do
		Labels[Index] = string.format(
			"#%d  R:%g  (%s)",
			Index,
			tonumber(Zone.Radius) or 0,
			FormatVector3(Zone.Center)
		)
	end

	return Labels
end

function ReplacePriorityList(Component, Values)
	if not Component then
		return
	end

	Component:SetPriority(Values)
end

function RefreshWaypointList()
	ReplacePriorityList(WaypointListComponent, BuildWaypointLabels())
end

function RefreshFarmZoneList()
	ReplacePriorityList(
		FarmZoneListComponent,
		BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm")
	)
end

function RefreshDeadzoneList()
	ReplacePriorityList(
		DeadzoneListComponent,
		BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone")
	)
end

function GetZonePickerOptions(Zones, Prefix)
	local Options = {}

	for Index in ipairs(Zones or {}) do
		table.insert(Options, string.format("#%d", Index))
	end

	if #Options == 0 then
		Options = {"No " .. Prefix .. " Zones"}
	end

	return Options
end


function RefreshFarmZonePicker()
	local Options = GetZonePickerOptions(PlaceConfig.FARM_ZONES, "Farm")

	if FarmZonePicker then
		if FarmZonePicker.Popup then FarmZonePicker.Popup:Destroy() end
		if FarmZonePicker.Frame then FarmZonePicker.Frame:Destroy() end
	end

	SelectedFarmZoneIndex = math.clamp(SelectedFarmZoneIndex, 1, math.max(1, #PlaceConfig.FARM_ZONES))
	local SelectedOption = Options[SelectedFarmZoneIndex] or Options[1]

	FarmZonePicker = ZoneSection:AddDropdown("Edit Farm Zone", Options, function(Value)
		if Value == "No Farm Zones" then return end
		local Index = table.find(Options, Value)
		if not Index or not PlaceConfig.FARM_ZONES[Index] then return end

		SelectedFarmZoneIndex = Index
		FarmRadiusSlider:Set(tonumber(PlaceConfig.FARM_ZONES[Index].Radius) or 100, false)
	end)

	if SelectedOption then FarmZonePicker:Set(SelectedOption) end
end

function RefreshDeadzonePicker()
	local Options = GetZonePickerOptions(PlaceConfig.DEADZONES, "Deadzone")

	if DeadzonePicker then
		if DeadzonePicker.Popup then DeadzonePicker.Popup:Destroy() end
		if DeadzonePicker.Frame then DeadzonePicker.Frame:Destroy() end
	end

	SelectedDeadzoneIndex = math.clamp(SelectedDeadzoneIndex, 1, math.max(1, #PlaceConfig.DEADZONES))
	local SelectedOption = Options[SelectedDeadzoneIndex] or Options[1]

	DeadzonePicker = ZoneSection:AddDropdown("Edit Deadzone", Options, function(Value)
		if Value == "No Deadzone Zones" then return end
		local Index = table.find(Options, Value)
		if not Index or not PlaceConfig.DEADZONES[Index] then return end

		SelectedDeadzoneIndex = Index
		DeadzoneRadiusSlider:Set(tonumber(PlaceConfig.DEADZONES[Index].Radius) or 35, false)
	end)

	if SelectedOption then DeadzonePicker:Set(SelectedOption) end
end

function SetProfileStatus(Text)
	if ProfileStatusLabel then
		ProfileStatusLabel.Text = "STATUS:  " .. tostring(Text)
	end
end

function GetCurrentProfileNames()
	local Names = GetProfileNames()

	--// Default Config is always available for the current PlaceId.
	--// It is read-only and is not stored inside ProfileStore.Profiles.
	table.insert(Names, 1, "Default Config")

	return Names
end

function ApplyDefaultPlaceConfig()
	ActiveProfileName = nil
	ProfileData = nil

	--// Never create a fake Vector3.zero farm zone. If the place config
	--// has no zones, NormalizePlaceConfig keeps the lists empty.
	PlaceConfig = NormalizePlaceConfig(DeserializeConfigValue(SerializeConfigValue(BasePlaceConfig)))

	CONFIG.TARGET_ENTITY_PRIORITY = table.clone(
		BasePlaceConfig.DEFAULT_TARGET_PRIORITY
			or {}
	)

	Feature.AutoBlock.Enabled = BasePlaceConfig.AUTOBLOCK == true
	BlockEnabled = BasePlaceConfig.AUTOBLOCK == true
	CONFIG.CURRENT_WAYPOINT_TARGET = 1
	CONFIG.RETREAT_HEALTH_PERCENT = 40
	CONFIG.AUTO_HEAL_HEALTH_PERCENT = 65
	CONFIG.SAFE_ENEMY_RANGE = 4

	ResetTargetReposition()
	DeadzoneEscapePosition = nil
	PatrolPosition = nil
	FarmReturnPosition = nil
	LastPatrolCalculateTime = 0
	LastFarmReturnCalculateTime = 0

	return true
end

function RefreshProfileDropdown()
	local Options = GetCurrentProfileNames()

	if ProfileDropdown then
		if ProfileDropdown.Popup then
			ProfileDropdown.Popup:Destroy()
		end

		if ProfileDropdown.Frame then
			ProfileDropdown.Frame:Destroy()
		end
	end

	ProfileDropdown = ProfilesSection:AddDropdown(
		"Profile",
		Options,
		function(Value)
			if Value == "Default Config" then
				ApplyDefaultPlaceConfig()
				ProfileNameBox:Set("")
				ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
				FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
				DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
				RetreatHealthSlider:Set(CONFIG.RETREAT_HEALTH_PERCENT, false)
				AutoHealHealthSlider:Set(CONFIG.AUTO_HEAL_HEALTH_PERCENT, false)
				SafeEnemyRangeSlider:Set(CONFIG.SAFE_ENEMY_RANGE, false)
				RefreshWaypointList()
				RefreshFarmZoneList()
				RefreshDeadzoneList()
				RefreshFarmZonePicker()
				RefreshDeadzonePicker()
				PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY))
				updateFeatureButtons()
				RefreshTargetDropdown()
				ResetTargetState()
				UpdateDebugVisualizer()
				SetProfileStatus("DEFAULT CONFIG (READ-ONLY)")
				return
			end

			if LoadProfile(Value) then
				ProfileNameBox:Set(Value)
				ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
				FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
				DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
				RetreatHealthSlider:Set(CONFIG.RETREAT_HEALTH_PERCENT, false)
				AutoHealHealthSlider:Set(CONFIG.AUTO_HEAL_HEALTH_PERCENT, false)
				SafeEnemyRangeSlider:Set(CONFIG.SAFE_ENEMY_RANGE, false)
				RefreshWaypointList()
				RefreshFarmZoneList()
				RefreshDeadzoneList()
				RefreshFarmZonePicker()
				RefreshDeadzonePicker()
				Feature.AutoBlock.Enabled = BlockEnabled
				PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY))
				updateFeatureButtons()
				RefreshTargetDropdown()
				ResetTargetState()
				UpdateDebugVisualizer()
				SetProfileStatus("LOADED " .. Value)
			else
				SetProfileStatus("LOAD FAILED")
			end
		end
	)

	if ActiveProfileName and table.find(Options, ActiveProfileName) then
		ProfileDropdown:Set(ActiveProfileName, false)
	else
		ProfileDropdown:Set("Default Config", false)
	end
end

ProfileStatusLabel = ProfilesSection:AddLabel("STATUS:  DEFAULT PLACE_CONFIG (READ-ONLY)")

ProfileNameBox = ProfilesSection:AddTextbox(
	"Profile Name",
	"",
	function(Value)
		--// The textbox is used as the source for Create Profile.
	end
)

ImportDataBox = ProfilesSection:AddTextbox(
	"Import Data",
	"",
	function(Value)
		--// Paste JSON here, then press Import Save.
	end
)

ProfilesSection:AddButton("Create New Profile", function()
	local Name = ProfileNameBox:Get()

	if Name == "" then
		SetProfileStatus("ENTER PROFILE NAME")
		return
	end

	local Success, ErrorMessage = CreateProfile(Name)

	if not Success then
		SetProfileStatus(ErrorMessage or "CREATE FAILED")
		return
	end

	ProfileNameBox:Set(Name)
	ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
	FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
	DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
	RetreatHealthSlider:Set(CONFIG.RETREAT_HEALTH_PERCENT, false)
	AutoHealHealthSlider:Set(CONFIG.AUTO_HEAL_HEALTH_PERCENT, false)
	SafeEnemyRangeSlider:Set(CONFIG.SAFE_ENEMY_RANGE, false)
	RefreshWaypointList()
	RefreshFarmZoneList()
	RefreshDeadzoneList()
	RefreshProfileDropdown()
	ProfileDropdown:Set(Name, false)
	--// A new profile can replace CONFIG.TARGET_ENTITY_PRIORITY.
	--// Sync the Utils priority component before rebuilding the target dropdown,
	--// otherwise it may still hold the previous profile's priority list.
	PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY or {}))
	updateFeatureButtons()
	RefreshTargetDropdown()
	UpdateDebugVisualizer()
	SetProfileStatus("CREATED " .. Name)
	NotifyAction("Profile", "Created " .. Name)
end)

ProfilesSection:AddButton("Save Profile", function()
	if not ActiveProfileName then
		SetProfileStatus("NO ACTIVE PROFILE")
		return
	end

	if SaveActiveProfile() then
		SetProfileStatus("SAVED " .. ActiveProfileName)
		NotifyAction("Save", "Saved " .. ActiveProfileName)
	else
		SetProfileStatus("SAVE FAILED")
	end
end)

ProfilesSection:AddButton("Export Save", function()
	local Success, Result = ExportActiveProfile()

	if Success then
		SetProfileStatus("EXPORTED " .. tostring(ActiveProfileName))
		NotifyAction("Export", "Copied " .. tostring(ActiveProfileName) .. " to clipboard")
	else
		SetProfileStatus(Result or "EXPORT FAILED")
	end
end)

ProfilesSection:AddButton("Import Save", function()
	local Success, Result = ImportProfileFromText(ImportDataBox:Get())

	if not Success then
		SetProfileStatus(Result or "IMPORT FAILED")
		return
	end

	ProfileNameBox:Set(Result)
	ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
	FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
	DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
	RetreatHealthSlider:Set(CONFIG.RETREAT_HEALTH_PERCENT, false)
	AutoHealHealthSlider:Set(CONFIG.AUTO_HEAL_HEALTH_PERCENT, false)
	SafeEnemyRangeSlider:Set(CONFIG.SAFE_ENEMY_RANGE, false)
	RefreshWaypointList()
	RefreshFarmZoneList()
	RefreshDeadzoneList()
	RefreshProfileDropdown()
	ProfileDropdown:Set(Result, false)
	RefreshFarmZonePicker()
	RefreshDeadzonePicker()
	PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY))
	Feature.AutoBlock.Enabled = BlockEnabled
	updateFeatureButtons()
	RefreshTargetDropdown()
	ResetTargetState()
	UpdateDebugVisualizer()
	SetProfileStatus("IMPORTED " .. Result)
	NotifyAction("Import", "Imported " .. tostring(Result))
end)

ProfilesSection:AddButton("Delete Profile", function()
	if not ActiveProfileName then
		SetProfileStatus("NO ACTIVE PROFILE")
		return
	end

	local Name = ActiveProfileName

	if DeleteProfile(Name) then
		ProfileNameBox:Set("")
		ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
		FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
		DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
		RefreshWaypointList()
		RefreshFarmZoneList()
		RefreshDeadzoneList()
		RefreshProfileDropdown()
		PriorityComponent:SetPriority(table.clone(
			BasePlaceConfig.DEFAULT_TARGET_PRIORITY
				or CONFIG.TARGET_ENTITY_PRIORITY
				or {}
		))
		CONFIG.TARGET_ENTITY_PRIORITY = PriorityComponent.Priority
		updateFeatureButtons()
		RefreshTargetDropdown()
		UpdateDebugVisualizer()
		SetProfileStatus("DELETED " .. Name)
		NotifyAction("Profile", "Deleted " .. Name)
	else
		SetProfileStatus("DELETE FAILED")
	end
end)

WaypointSection:AddButton("Add Waypoint Here", function()
	if not RootPart then
		SetProfileStatus("CHARACTER NOT READY")
		return
	end

	if not ActiveProfileName then
		SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	table.insert(PlaceConfig.WAYPOINTS, RootPart.Position)
	CONFIG.CURRENT_WAYPOINT_TARGET = math.clamp(
		CONFIG.CURRENT_WAYPOINT_TARGET,
		1,
		math.max(1, #PlaceConfig.WAYPOINTS)
	)

	RefreshWaypointList()
	ResetDebugWaypoints()
	UpdateDebugVisualizer()
	SaveActiveProfile()
	SetProfileStatus("WAYPOINT ADDED #" .. tostring(#PlaceConfig.WAYPOINTS))
	NotifyAction("Waypoint", "Added waypoint #" .. tostring(#PlaceConfig.WAYPOINTS))
end)

WaypointSection:AddButton("Clear Waypoints", function()
	if not ActiveProfileName then
		SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	table.clear(PlaceConfig.WAYPOINTS)
	CONFIG.CURRENT_WAYPOINT_TARGET = 1

	RefreshWaypointList()
	ResetDebugWaypoints()
	UpdateDebugVisualizer()
	SaveActiveProfile()
	SetProfileStatus("WAYPOINTS CLEARED")
	NotifyAction("Waypoint", "Cleared all waypoints")
end)

WaypointListComponent = WaypointSection:AddPriority("All Waypoints", BuildWaypointLabels())

local OriginalWaypointMoveUp = WaypointListComponent.MoveUp
local OriginalWaypointMoveDown = WaypointListComponent.MoveDown
local OriginalWaypointRemove = WaypointListComponent.Remove

function WaypointListComponent:MoveUp(Label)
	if not ActiveProfileName then
		SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(BuildWaypointLabels(), Label)

	if Index and Index > 1 then
		PlaceConfig.WAYPOINTS[Index], PlaceConfig.WAYPOINTS[Index - 1] =
			PlaceConfig.WAYPOINTS[Index - 1], PlaceConfig.WAYPOINTS[Index]

		OriginalWaypointMoveUp(self, Label)
		CONFIG.CURRENT_WAYPOINT_TARGET = math.clamp(
			CONFIG.CURRENT_WAYPOINT_TARGET,
			1,
			math.max(1, #PlaceConfig.WAYPOINTS)
		)
		RefreshWaypointList()
		ResetDebugWaypoints()
		UpdateDebugVisualizer()
		SaveActiveProfile()
		SetProfileStatus("WAYPOINT MOVED UP")
		NotifyAction("Waypoint", "Moved up")
	end
end

function WaypointListComponent:MoveDown(Label)
	if not ActiveProfileName then
		SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(BuildWaypointLabels(), Label)

	if Index and Index < #PlaceConfig.WAYPOINTS then
		PlaceConfig.WAYPOINTS[Index], PlaceConfig.WAYPOINTS[Index + 1] =
			PlaceConfig.WAYPOINTS[Index + 1], PlaceConfig.WAYPOINTS[Index]

		OriginalWaypointMoveDown(self, Label)
		CONFIG.CURRENT_WAYPOINT_TARGET = math.clamp(
			CONFIG.CURRENT_WAYPOINT_TARGET,
			1,
			math.max(1, #PlaceConfig.WAYPOINTS)
		)
		RefreshWaypointList()
		ResetDebugWaypoints()
		UpdateDebugVisualizer()
		SaveActiveProfile()
		SetProfileStatus("WAYPOINT MOVED DOWN")
		NotifyAction("Waypoint", "Moved down")
	end
end

function WaypointListComponent:Remove(Label)
	if not ActiveProfileName then
		SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(BuildWaypointLabels(), Label)

	if Index then
		table.remove(PlaceConfig.WAYPOINTS, Index)
		OriginalWaypointRemove(self, Label)
		CONFIG.CURRENT_WAYPOINT_TARGET = math.clamp(
			CONFIG.CURRENT_WAYPOINT_TARGET,
			1,
			math.max(1, #PlaceConfig.WAYPOINTS)
		)
		RefreshWaypointList()
		ResetDebugWaypoints()
		UpdateDebugVisualizer()
		SaveActiveProfile()
		SetProfileStatus("WAYPOINT REMOVED #" .. tostring(Index))
	end
end

FarmRadiusSlider = ZoneSection:AddSlider(
	"Farm Radius",
	100,
	1,
	500,
	function(Value)
		local Zone = PlaceConfig and PlaceConfig.FARM_ZONES
			and PlaceConfig.FARM_ZONES[SelectedFarmZoneIndex]

		if not Zone or not ActiveProfileName then return end

		Zone.Radius = Value
		RefreshFarmZoneList()
		UpdateDebugVisualizer()
		SaveActiveProfile()
	end
)

DeadzoneRadiusSlider = ZoneSection:AddSlider(
	"Deadzone Radius",
	35,
	1,
	250,
	function(Value)
		local Zone = PlaceConfig and PlaceConfig.DEADZONES
			and PlaceConfig.DEADZONES[SelectedDeadzoneIndex]

		if not Zone or not ActiveProfileName then return end

		Zone.Radius = Value
		RefreshDeadzoneList()
		UpdateDebugVisualizer()
		SaveActiveProfile()
	end
)

RefreshFarmZonePicker()
RefreshDeadzonePicker()

ReachDistanceBox = ZoneSection:AddTextbox(
	"Waypoint Reach Distance",
	tostring(PlaceConfig.REACH_DISTANCE or 5),
	function(Value)
		if not ActiveProfileName then
			return
		end

		local Number = tonumber(Value)

		if Number and Number > 0 then
			PlaceConfig.REACH_DISTANCE = Number
			SaveActiveProfile()
			SetProfileStatus("REACH DISTANCE SAVED")
		end
	end
)

ZoneSection:AddButton("Add Farm Zone Here", function()
	if not RootPart then
		SetProfileStatus("CHARACTER NOT READY")
		return
	end

	if not ActiveProfileName then
		SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	local Radius = FarmRadiusSlider:Get()

	table.insert(PlaceConfig.FARM_ZONES, {
		Center = RootPart.Position,
		Radius = Radius,
	})

	PlaceConfig = NormalizePlaceConfig(PlaceConfig)
	RefreshFarmZoneList()
	SelectedFarmZoneIndex = #PlaceConfig.FARM_ZONES
	RefreshFarmZonePicker()
	SaveActiveProfile()
	UpdateDebugVisualizer()
	SetProfileStatus("FARM ZONE ADDED #" .. tostring(#PlaceConfig.FARM_ZONES))
end)

ZoneSection:AddButton("Add Deadzone Here", function()
	if not RootPart then
		SetProfileStatus("CHARACTER NOT READY")
		return
	end

	if not ActiveProfileName then
		SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	local Radius = DeadzoneRadiusSlider:Get()

	table.insert(PlaceConfig.DEADZONES, {
		Center = RootPart.Position,
		Radius = Radius,
	})

	PlaceConfig = NormalizePlaceConfig(PlaceConfig)
	RefreshDeadzoneList()
	SelectedDeadzoneIndex = #PlaceConfig.DEADZONES
	RefreshDeadzonePicker()
	SaveActiveProfile()
	UpdateDebugVisualizer()
	SetProfileStatus("DEADZONE ADDED #" .. tostring(#PlaceConfig.DEADZONES))
end)

ZoneSection:AddButton("Clear Farm Zones", function()
	if not ActiveProfileName then
		SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	table.clear(PlaceConfig.FARM_ZONES)
	PlaceConfig = NormalizePlaceConfig(PlaceConfig)
	SelectedFarmZoneIndex = 1
	RefreshFarmZoneList()
	RefreshFarmZonePicker()
	SaveActiveProfile()
	UpdateDebugVisualizer()
	SetProfileStatus("FARM ZONES CLEARED")
	NotifyAction("Farm Zone", "Cleared all farm zones")
end)

ZoneSection:AddButton("Clear Deadzones", function()
	if not ActiveProfileName then
		SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	table.clear(PlaceConfig.DEADZONES)
	PlaceConfig = NormalizePlaceConfig(PlaceConfig)
	SelectedDeadzoneIndex = 1
	RefreshDeadzoneList()
	RefreshDeadzonePicker()
	SaveActiveProfile()
	UpdateDebugVisualizer()
	SetProfileStatus("DEADZONES CLEARED")
	NotifyAction("Deadzone", "Cleared all deadzones")
end)

FarmZoneListComponent = ZoneSection:AddPriority(
	"All Farm Zones",
	BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm")
)

DeadzoneListComponent = ZoneSection:AddPriority(
	"All Deadzones",
	BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone")
)

local OriginalFarmZoneMoveUp = FarmZoneListComponent.MoveUp
local OriginalFarmZoneMoveDown = FarmZoneListComponent.MoveDown
local OriginalFarmZoneRemove = FarmZoneListComponent.Remove

function FarmZoneListComponent:MoveUp(Label)
	if not ActiveProfileName then
		SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm"), Label)

	if Index and Index > 1 then
		PlaceConfig.FARM_ZONES[Index], PlaceConfig.FARM_ZONES[Index - 1] =
			PlaceConfig.FARM_ZONES[Index - 1], PlaceConfig.FARM_ZONES[Index]
		OriginalFarmZoneMoveUp(self, Label)
		RefreshFarmZoneList()
		SelectedFarmZoneIndex = math.max(1, Index - 1)
		RefreshFarmZonePicker()
		SaveActiveProfile()
		UpdateDebugVisualizer()
		SetProfileStatus("FARM ZONE MOVED UP")
		NotifyAction("Farm Zone", "Moved up")
	end
end

function FarmZoneListComponent:MoveDown(Label)
	if not ActiveProfileName then
		SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm"), Label)

	if Index and Index < #PlaceConfig.FARM_ZONES then
		PlaceConfig.FARM_ZONES[Index], PlaceConfig.FARM_ZONES[Index + 1] =
			PlaceConfig.FARM_ZONES[Index + 1], PlaceConfig.FARM_ZONES[Index]
		OriginalFarmZoneMoveDown(self, Label)
		RefreshFarmZoneList()
		SelectedFarmZoneIndex = math.min(#PlaceConfig.FARM_ZONES, Index + 1)
		RefreshFarmZonePicker()
		SaveActiveProfile()
		UpdateDebugVisualizer()
		SetProfileStatus("FARM ZONE MOVED DOWN")
		NotifyAction("Farm Zone", "Moved down")
	end
end

function FarmZoneListComponent:Remove(Label)
	if not ActiveProfileName then
		SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm"), Label)

	if Index then
		table.remove(PlaceConfig.FARM_ZONES, Index)
		OriginalFarmZoneRemove(self, Label)
		PlaceConfig = NormalizePlaceConfig(PlaceConfig)
		SelectedFarmZoneIndex = math.clamp(Index, 1, math.max(1, #PlaceConfig.FARM_ZONES))
		RefreshFarmZoneList()
		RefreshFarmZonePicker()
		SaveActiveProfile()
		UpdateDebugVisualizer()
		SetProfileStatus("FARM ZONE REMOVED #" .. tostring(Index))
	end
end

local OriginalDeadzoneMoveUp = DeadzoneListComponent.MoveUp
local OriginalDeadzoneMoveDown = DeadzoneListComponent.MoveDown
local OriginalDeadzoneRemove = DeadzoneListComponent.Remove

function DeadzoneListComponent:MoveUp(Label)
	if not ActiveProfileName then
		SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone"), Label)

	if Index and Index > 1 then
		PlaceConfig.DEADZONES[Index], PlaceConfig.DEADZONES[Index - 1] =
			PlaceConfig.DEADZONES[Index - 1], PlaceConfig.DEADZONES[Index]
		OriginalDeadzoneMoveUp(self, Label)
		RefreshDeadzoneList()
		SelectedDeadzoneIndex = math.max(1, Index - 1)
		RefreshDeadzonePicker()
		SaveActiveProfile()
		UpdateDebugVisualizer()
		SetProfileStatus("DEADZONE MOVED UP")
		NotifyAction("Deadzone", "Moved up")
	end
end

function DeadzoneListComponent:MoveDown(Label)
	if not ActiveProfileName then
		SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone"), Label)

	if Index and Index < #PlaceConfig.DEADZONES then
		PlaceConfig.DEADZONES[Index], PlaceConfig.DEADZONES[Index + 1] =
			PlaceConfig.DEADZONES[Index + 1], PlaceConfig.DEADZONES[Index]
		OriginalDeadzoneMoveDown(self, Label)
		RefreshDeadzoneList()
		SelectedDeadzoneIndex = math.min(#PlaceConfig.DEADZONES, Index + 1)
		RefreshDeadzonePicker()
		SaveActiveProfile()
		UpdateDebugVisualizer()
		SetProfileStatus("DEADZONE MOVED DOWN")
		NotifyAction("Deadzone", "Moved down")
	end
end

function DeadzoneListComponent:Remove(Label)
	if not ActiveProfileName then
		SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone"), Label)

	if Index then
		table.remove(PlaceConfig.DEADZONES, Index)
		OriginalDeadzoneRemove(self, Label)
		PlaceConfig = NormalizePlaceConfig(PlaceConfig)
		SelectedDeadzoneIndex = math.clamp(Index, 1, math.max(1, #PlaceConfig.DEADZONES))
		RefreshDeadzoneList()
		RefreshDeadzonePicker()
		SaveActiveProfile()
		UpdateDebugVisualizer()
		SetProfileStatus("DEADZONE REMOVED #" .. tostring(Index))
	end
end

RefreshWaypointList()
RefreshFarmZoneList()
RefreshDeadzoneList()

--// UI stats
function neededExp(lvl)
	lvl = lvl - 1

	local total = 9

	for i = 1, lvl do
		total = total + (6 * (i + 2))
	end

	return total
end

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
		EventCurrencyLabel.Text = "EVENT CURRENCY  0"
		ExpLabel.Text = "EXP            0/0"
		LastInventory = nil
		return
	end

	local PlayerLvl = PlayerStats:FindFirstChild("Level")
	local PlayerExp = PlayerStats:FindFirstChild("EXP")

	if PlayerLvl and PlayerExp then
		ExpLabel.Text = "EXP            " .. PlayerExp.Value .. "/" .. neededExp(PlayerLvl.Value)
	else
		ExpLabel.Text = "EXP            0/0"
	end

	local Inventory = PlayerStats:FindFirstChild("Inventory")

	if not Inventory then
		EventCurrency = 0
		EventCurrencyLabel.Text = "EVENT CURRENCY  0"
		return
	end

	local InventoryValue = Inventory.Value

	if InventoryValue == LastInventory then
		return
	end

	LastInventory = InventoryValue

	local _, Amount = GetItem(InventoryValue, TargetCurrency)

	EventCurrency = Amount
	EventCurrencyLabel.Text = "EVENT CURRENCY  " .. tostring(EventCurrency)
end

function updatePlayTime()
	local ServerAge = math.floor(workspace.DistributedGameTime)

	local Hours   = math.floor(ServerAge / 3600)
	local Minutes = math.floor((ServerAge % 3600) / 60)
	local Seconds = ServerAge % 60

	ServerAgeLabel.Text = "PLAY TIME      " .. string.format("%02d:%02d:%02d", Hours, Minutes, Seconds)
end

function updatePosition()
	if RootPart then
		local Position = RootPart.Position

		PositionLabel.Text = string.format(
			"POSITION       %.1f, %.1f, %.1f",
			Position.X,
			Position.Y,
			Position.Z
		)
	else
		PositionLabel.Text = "POSITION       --"
	end
end

updatePosition()

--// ============================================================
--// DEBUG VISUALIZER
--// ============================================================

function GetDebugAdorneeParent()
	if not DebugFolder then
		DebugFolder = Instance.new("Folder")
		DebugFolder.Name = "AutoFarmDebug"
		DebugFolder.Parent = workspace
	end

	return DebugFolder
end

function SetDebugVisualizerVisible(Visible)
	if not DebugFolder then
		return
	end

	DebugFolder.Parent = Visible and workspace or nil
end

function CreateDebugZone(Name, Center, Radius, Color, ZoneType, Index)
	if not Center or not Radius or Radius <= 0 then
		return nil
	end

	local ZoneFolder = Instance.new("Folder")
	ZoneFolder.Name = Name
	ZoneFolder.Parent = GetDebugAdorneeParent()

	--// Radius ring.
	local Ring = Instance.new("Part")
	Ring.Name = "Radius"
	Ring.Anchored = true
	Ring.CanCollide = false
	Ring.CanTouch = false
	Ring.CanQuery = false
	Ring.CastShadow = false
	Ring.Transparency = 0.35
	Ring.Material = Enum.Material.Neon
	Ring.Color = Color
	Ring.Shape = Enum.PartType.Cylinder
	Ring.Size = Vector3.new(CONFIG.DEBUG_ZONE_HEIGHT, Radius * 2, Radius * 2)
	Ring.CFrame = CFrame.new(Center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	Ring.Parent = ZoneFolder

	local Surface = Instance.new("Part")
	Surface.Name = "Surface"
	Surface.Anchored = true
	Surface.CanCollide = false
	Surface.CanTouch = false
	Surface.CanQuery = false
	Surface.CastShadow = false
	Surface.Transparency = 0.94
	Surface.Material = Enum.Material.SmoothPlastic
	Surface.Color = Color
	Surface.Shape = Enum.PartType.Cylinder
	Surface.Size = Vector3.new(0.04, Radius * 2, Radius * 2)
	Surface.CFrame = CFrame.new(Center + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
	Surface.Parent = ZoneFolder

	--// Center marker + billboard so each radius can be identified in-world.
	local Marker = Instance.new("Part")
	Marker.Name = "Center"
	Marker.Anchored = true
	Marker.CanCollide = false
	Marker.CanTouch = false
	Marker.CanQuery = false
	Marker.CastShadow = false
	Marker.Transparency = 1
	Marker.Size = Vector3.new(0.5, 0.5, 0.5)
	Marker.Position = Center + Vector3.new(0, 0.15, 0)
	Marker.Parent = ZoneFolder

	local Billboard = Instance.new("BillboardGui")
	Billboard.Name = "RadiusBillboard"
	Billboard.Adornee = Marker
	Billboard.AlwaysOnTop = true
	Billboard.LightInfluence = 0
	Billboard.MaxDistance = 180
	Billboard.Size = UDim2.fromScale(4.2, 1.25)
	Billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.0, 0)
	Billboard.Enabled = Feature.DebugRadiusLabels.Enabled
	Billboard.Parent = Marker

	local Container = Instance.new("Frame")
	Container.BackgroundColor3 = DEBUG_COLORS.BillboardPanel
	Container.BackgroundTransparency = 0.05
	Container.BorderSizePixel = 0
	Container.Size = UDim2.fromScale(1, 1)
	Container.Parent = Billboard

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 3)
	Corner.Parent = Container

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color
	Stroke.Thickness = 1
	Stroke.Transparency = 0.1
	Stroke.Parent = Container

	local Label = Instance.new("TextLabel")
	Label.BackgroundTransparency = 1
	Label.Size = UDim2.fromScale(1, 0.52)
	Label.Position = UDim2.fromScale(0, 0.03)
	Label.Font = Enum.Font.GothamMedium
	Label.Text = string.format("%s #%02d", ZoneType or "ZONE", Index or 0)
	Label.TextColor3 = DEBUG_COLORS.BillboardText
	Label.TextScaled = true
	Label.Parent = Container

	local RadiusLabel = Instance.new("TextLabel")
	RadiusLabel.BackgroundTransparency = 1
	RadiusLabel.Size = UDim2.fromScale(1, 0.4)
	RadiusLabel.Position = UDim2.fromScale(0, 0.55)
	RadiusLabel.Font = Enum.Font.GothamMedium
	RadiusLabel.Text = string.format("RADIUS  %.0f", Radius)
	RadiusLabel.TextColor3 = DEBUG_COLORS.BillboardMuted
	RadiusLabel.TextScaled = true
	RadiusLabel.Parent = Container

	return ZoneFolder
end

function CreateDebugWaypoint(Index, Position)
	local MarkerPart = Instance.new("Part")
	MarkerPart.Name = "Waypoint_" .. Index
	MarkerPart.Anchored = true
	MarkerPart.CanCollide = false
	MarkerPart.CanTouch = false
	MarkerPart.CanQuery = false
	MarkerPart.CastShadow = false
	MarkerPart.Transparency = 1
	MarkerPart.Size = Vector3.new(1, 1, 1)
	MarkerPart.Position = Position + Vector3.new(0, 0.1, 0)
	MarkerPart.Parent = GetDebugAdorneeParent()

	local Billboard = Instance.new("BillboardGui")
	Billboard.Name = "WaypointBillboard"
	Billboard.Adornee = MarkerPart
	Billboard.AlwaysOnTop = false
	Billboard.LightInfluence = 1
	Billboard.MaxDistance = 140
	Billboard.Size = UDim2.fromScale(2.8, 0.72)
	Billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.25, 0)
	Billboard.Parent = MarkerPart

	--// Match the Utils UI: compact dark panel, thin border, bright primary text,
	--// and a small accent instead of the old oversized pill.
	local Container = Instance.new("Frame")
	Container.Name = "Container"
	Container.AnchorPoint = Vector2.new(0.5, 0.5)
	Container.Position = UDim2.fromScale(0.5, 0.5)
	Container.Size = UDim2.fromScale(1, 1)
	Container.BackgroundColor3 = DEBUG_COLORS.BillboardPanel
	Container.BackgroundTransparency = 0.04
	Container.BorderSizePixel = 0
	Container.Parent = Billboard

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 3)
	Corner.Parent = Container

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = DEBUG_COLORS.BillboardBorder
	Stroke.Thickness = 1
	Stroke.Transparency = 0.05
	Stroke.Parent = Container

	local Accent = Instance.new("Frame")
	Accent.Name = "Accent"
	Accent.Position = UDim2.fromScale(0, 0.16)
	Accent.Size = UDim2.fromScale(0.035, 0.68)
	Accent.BackgroundColor3 = DEBUG_COLORS.WaypointPending
	Accent.BorderSizePixel = 0
	Accent.Parent = Container

	local AccentCorner = Instance.new("UICorner")
	AccentCorner.CornerRadius = UDim.new(0, 2)
	AccentCorner.Parent = Accent

	local Label = Instance.new("TextLabel")
	Label.Name = "Label"
	Label.BackgroundTransparency = 1
	Label.Position = UDim2.fromScale(0.10, 0)
	Label.Size = UDim2.fromScale(0.56, 1)
	Label.Font = Enum.Font.GothamMedium
	Label.Text = string.format("WP %02d", Index)
	Label.TextColor3 = DEBUG_COLORS.BillboardText
	Label.TextScaled = true
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Center
	Label.Parent = Container

	local State = Instance.new("TextLabel")
	State.Name = "State"
	State.BackgroundTransparency = 1
	State.Position = UDim2.fromScale(0.68, 0)
	State.Size = UDim2.fromScale(0.25, 1)
	State.Font = Enum.Font.GothamMedium
	State.Text = "NEXT"
	State.TextColor3 = DEBUG_COLORS.BillboardMuted
	State.TextScaled = true
	State.TextXAlignment = Enum.TextXAlignment.Right
	State.TextYAlignment = Enum.TextYAlignment.Center
	State.Parent = Container

	DebugWaypointData[Index] = {
		MarkerPart = MarkerPart,
		Billboard = Billboard,
		Accent = Accent,
		Label = Label,
		State = State,
		Visited = false,
		NextBeam = nil,
		Arrow = nil,
	}

	return DebugWaypointData[Index]
end

function CreateDebugWaypointLink(Index, FromData, ToData)
	if not FromData or not ToData then
		return
	end

	if FromData.NextBeam then
		FromData.NextBeam:Destroy()
		FromData.NextBeam = nil
	end

	if FromData.Arrow then
		FromData.Arrow:Destroy()
		FromData.Arrow = nil
	end

	local FromPart = FromData.MarkerPart
	local ToPart = ToData.MarkerPart

	if not FromPart or not ToPart then
		return
	end

	local FromAttachment = FromPart:FindFirstChild("NextAttachment")
	if not FromAttachment then
		FromAttachment = Instance.new("Attachment")
		FromAttachment.Name = "NextAttachment"
		FromAttachment.Position = Vector3.new(0, -0.1, 0)
		FromAttachment.Parent = FromPart
	end

	local ToAttachment = ToPart:FindFirstChild("PreviousAttachment")
	if not ToAttachment then
		ToAttachment = Instance.new("Attachment")
		ToAttachment.Name = "PreviousAttachment"
		ToAttachment.Position = Vector3.new(0, -0.1, 0)
		ToAttachment.Parent = ToPart
	end

	local Beam = Instance.new("Beam")
	Beam.Name = "WaypointPath"
	Beam.Attachment0 = FromAttachment
	Beam.Attachment1 = ToAttachment
	Beam.FaceCamera = true
	Beam.LightEmission = 0.65
	Beam.LightInfluence = 0
	Beam.Segments = 1
	Beam.Width0 = 0.045
	Beam.Width1 = 0.045
	Beam.Transparency = NumberSequence.new(0.15)
	Beam.Color = ColorSequence.new(DEBUG_COLORS.WaypointLine)
	Beam.Parent = FromPart

	--// Small directional cone at the destination so the route visibly points
	--// from this waypoint to the next one.
	local DirectionVector = ToPart.Position - FromPart.Position
	local Distance = DirectionVector.Magnitude

	if Distance > 0.1 then
		local Direction = DirectionVector.Unit
		local Arrow = Instance.new("Part")
		Arrow.Name = "WaypointArrow"
		Arrow.Anchored = true
		Arrow.CanCollide = false
		Arrow.CanTouch = false
		Arrow.CanQuery = false
		Arrow.CastShadow = false
		Arrow.Material = Enum.Material.Neon
		Arrow.Color = DEBUG_COLORS.WaypointLine
		Arrow.Shape = Enum.PartType.Wedge
		Arrow.Size = Vector3.new(0.16, 0.42, 0.16)
		Arrow.CFrame = CFrame.lookAt(ToPart.Position - Direction * 0.32, ToPart.Position) * CFrame.Angles(math.rad(90), 0, 0)
		Arrow.Parent = GetDebugAdorneeParent()

		FromData.Arrow = Arrow
	end

	FromData.NextBeam = Beam
end

function ResetDebugWaypoints()
	for _, Data in DebugWaypointData do
		Data.Visited = false

		if Data.Label then
			Data.Label.TextColor3 = DEBUG_COLORS.BillboardText
		end

		if Data.State then
			Data.State.Text = "NEXT"
			Data.State.TextColor3 = DEBUG_COLORS.BillboardMuted
		end

		if Data.Accent then
			Data.Accent.BackgroundColor3 = DEBUG_COLORS.WaypointPending
		end

		if Data.NextBeam then
			Data.NextBeam.Color = ColorSequence.new(DEBUG_COLORS.WaypointLine)
		end
	end
end

function UpdateDebugWaypointColors()
	for Index, Data in DebugWaypointData do
		local AccentColor = DEBUG_COLORS.WaypointPending
		local TextColor = DEBUG_COLORS.BillboardText
		local StateText = "NEXT"
		local StateColor = DEBUG_COLORS.BillboardMuted

		if PlaceConfig and Index < CONFIG.CURRENT_WAYPOINT_TARGET then
			AccentColor = DEBUG_COLORS.WaypointVisited
			TextColor = DEBUG_COLORS.WaypointVisited
			StateText = "DONE"
			StateColor = DEBUG_COLORS.WaypointVisited
			Data.Visited = true
		elseif PlaceConfig and Index == CONFIG.CURRENT_WAYPOINT_TARGET then
			AccentColor = DEBUG_COLORS.WaypointCurrent
			TextColor = DEBUG_COLORS.BillboardText
			StateText = "CURRENT"
			StateColor = DEBUG_COLORS.WaypointCurrent
			Data.Visited = false
		else
			Data.Visited = false
		end

		if Data.Label then
			Data.Label.TextColor3 = TextColor
		end

		if Data.State then
			Data.State.Text = StateText
			Data.State.TextColor3 = StateColor
		end

		if Data.Accent then
			Data.Accent.BackgroundColor3 = AccentColor
		end
	end

	--// Route direction is always WP 1 -> WP 2 -> WP 3 -> ...
	for Index = 1, #DebugWaypointData - 1 do
		CreateDebugWaypointLink(Index, DebugWaypointData[Index], DebugWaypointData[Index + 1])
	end

	if DebugWaypointData[#DebugWaypointData] then
		local LastData = DebugWaypointData[#DebugWaypointData]
		if LastData.NextBeam then
			LastData.NextBeam:Destroy()
			LastData.NextBeam = nil
		end
		if LastData.Arrow then
			LastData.Arrow:Destroy()
			LastData.Arrow = nil
		end
	end
end

function DestroyDebugZones()
	DebugZoneSignature = nil

	if DebugFarmZone then
		DebugFarmZone:Destroy()
		DebugFarmZone = nil
	end

	if DebugDeadzone then
		DebugDeadzone:Destroy()
		DebugDeadzone = nil
	end
end

function RebuildDebugZones()
	if not PlaceConfig then
		DestroyDebugZones()
		return
	end

	--// Rebuild all farm/dead zones. Profiles can contain multiple zones.
	if DebugFarmZone then
		DebugFarmZone:Destroy()
		DebugFarmZone = nil
	end

	if DebugDeadzone then
		DebugDeadzone:Destroy()
		DebugDeadzone = nil
	end

	DebugZoneSignature = nil

	local ZoneContainer = GetDebugAdorneeParent()

	local FarmZonesFolder = Instance.new("Folder")
	FarmZonesFolder.Name = "FarmZones"
	FarmZonesFolder.Parent = ZoneContainer

	if Feature.DebugFarmZones.Enabled then
		for Index, Zone in ipairs(PlaceConfig.FARM_ZONES or {}) do
			local ZoneFolder = CreateDebugZone(
				"FarmZone_" .. Index,
				Zone.Center,
				Zone.Radius,
				DEBUG_COLORS.FarmZone,
				"FARM",
				Index
			)

			if ZoneFolder then
				ZoneFolder.Parent = FarmZonesFolder
			end
		end
	end

	local DeadzonesFolder = Instance.new("Folder")
	DeadzonesFolder.Name = "Deadzones"
	DeadzonesFolder.Parent = ZoneContainer

	if Feature.DebugDeadzones.Enabled then
		for Index, Zone in ipairs(PlaceConfig.DEADZONES or {}) do
			local ZoneFolder = CreateDebugZone(
				"Deadzone_" .. Index,
				Zone.Center,
				Zone.Radius,
				DEBUG_COLORS.Deadzone,
				"DEAD",
				Index
			)

			if ZoneFolder then
				ZoneFolder.Parent = DeadzonesFolder
			end
		end
	end

	DebugFarmZone = FarmZonesFolder
	DebugDeadzone = DeadzonesFolder
	DebugZoneSignature = "MULTI|" .. tostring(#(PlaceConfig.FARM_ZONES or {})) .. "|" .. tostring(#(PlaceConfig.DEADZONES or {}))
end
function UpdateDebugVisualizer()
	if not PlaceConfig or not Feature.DebugVisualizer.Enabled then
		SetDebugVisualizerVisible(false)
		return
	end

	GetDebugAdorneeParent()

	--// Rebuild waypoints if the place configuration changed.
	local WaypointCount = Feature.DebugWaypoints.Enabled and #PlaceConfig.WAYPOINTS or 0
	local WaypointParts = {}

	for Index, Position in ipairs(PlaceConfig.WAYPOINTS) do
		WaypointParts[Index] = string.format(
			"%.3f:%.3f:%.3f",
			Position.X,
			Position.Y,
			Position.Z
		)
	end

	local CurrentWaypointSignature = table.concat(WaypointParts, "|")

	if DebugWaypointSignature ~= CurrentWaypointSignature
		or #DebugWaypointData ~= WaypointCount
	then
		for _, Data in DebugWaypointData do
			if Data.NextBeam then
				Data.NextBeam:Destroy()
			end
			if Data.Arrow then
				Data.Arrow:Destroy()
			end
			if Data.MarkerPart then
				Data.MarkerPart:Destroy()
			end
		end

		table.clear(DebugWaypointData)
		DebugWaypointSignature = nil

		if Feature.DebugWaypoints.Enabled then
			for Index, Position in ipairs(PlaceConfig.WAYPOINTS) do
				CreateDebugWaypoint(Index, Position)
			end
		end

		DebugWaypointSignature = CurrentWaypointSignature
	end

	RebuildDebugZones()
	UpdateDebugWaypointColors()
	SetDebugVisualizerVisible(true)
end

--// Initial debug setup.
UpdateDebugVisualizer()

--// Load the most recently used profile for this PlaceId.
--// If none exists, keep the place_config defaults. If the place has no
--// place_config, the profile starts with zero waypoints/zones.
if ProfileStore.LastUsed
	and ProfileStore.Profiles[ProfileStore.LastUsed]
then
	local LastUsed = ProfileStore.LastUsed
	ActiveProfileName = LastUsed

	if not LoadProfile(LastUsed) then
		ActiveProfileName = nil
		ProfileData = nil
	end
end

if ActiveProfileName then
	ProfileNameBox:Set(ActiveProfileName)
	ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
	FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
	DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
	RefreshWaypointList()
	RefreshFarmZoneList()
	RefreshDeadzoneList()
	PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY))
	CONFIG.TARGET_ENTITY_PRIORITY = PriorityComponent.Priority
	updateFeatureButtons()
	RefreshTargetDropdown()
	UpdateDebugVisualizer()
end

RefreshProfileDropdown()

if ActiveProfileName then
	ProfileDropdown:Set(ActiveProfileName, false)
	SetProfileStatus("AUTO LOADED " .. ActiveProfileName)
end

--// Refresh the dropdown whenever the mob set changes.
function RefreshEnemyPicker()
	RefreshTargetDropdown()
end

--// Mob Watcher
local MobConnections       = {}
local MobFolderConnections = {}

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
				RefreshEnemyPicker()

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
					RefreshEnemyPicker()
					ValidMobs[Mob] = nil

					if ClosestTarget == Mob and not IsEntityInPriority(Child.Value) then
						ClosestTarget = nil
					end
				end))
			end

			RefreshEnemyPicker()
			ValidMobs[Mob] = nil
		end))

		table.insert(Connections, Config.ChildRemoved:Connect(function(Child)
			if Child.Name == "Entity" then
				ValidMobs[Mob] = nil

				if ClosestTarget == Mob then
					ClosestTarget = nil
				end

				RefreshEnemyPicker()
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
			RefreshEnemyPicker()
			ValidMobs[Mob] = nil
		end
	end))

	table.insert(Connections, Mob.ChildRemoved:Connect(function(Child)
		if Child.Name == "Config" then
			ValidMobs[Mob] = nil

			if ClosestTarget == Mob then
				ClosestTarget = nil
			end

			RefreshEnemyPicker()
		end
	end))

	RefreshEnemyPicker()
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
		RefreshEnemyPicker()
	end))

	table.insert(MobFolderConnections, MobFolder.ChildRemoved:Connect(function(Mob)
		DisconnectMob(Mob)
		ValidMobs[Mob] = nil

		if ClosestTarget == Mob then
			ClosestTarget = nil
		end

		RefreshEnemyPicker()
	end))
end

local ExistingMobFolder = workspace:FindFirstChild("Mobs")

if ExistingMobFolder then
	WatchMobFolder(ExistingMobFolder)
end

workspace.ChildAdded:Connect(function(Child)
	if Child.Name == "Mobs" then
		WatchMobFolder(Child)
		RefreshEnemyPicker()
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

	RefreshEnemyPicker()
end)

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
function IsInsideFarmDeadzone(Position)
	if not Position or not PlaceConfig then
		return false
	end

	for _, Zone in ipairs(PlaceConfig.DEADZONES or {}) do
		local Offset = Position - Zone.Center
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		if Distance <= Zone.Radius then
			return true
		end
	end

	return false
end

function IsInsideFarmArea(Position)
	if Feature.IgnoreFarmZone.Enabled or not PlaceConfig then
		return true
	end

	if not Position then
		return false
	end

	local FarmZones = PlaceConfig.FARM_ZONES or {}

	--// No farm zones means the profile does not constrain the farm area.
	--// Deadzones can still be used independently.
	if #FarmZones == 0 then
		return not IsInsideFarmDeadzone(Position)
	end

	local InsideAnyFarmZone = false

	for _, Zone in ipairs(FarmZones) do
		local Offset = Position - Zone.Center
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		if Distance <= Zone.Radius then
			InsideAnyFarmZone = true
			break
		end
	end

	if not InsideAnyFarmZone then
		return false
	end

	return not IsInsideFarmDeadzone(Position)
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
	if DebugFolder then
		table.insert(FilterInstances, DebugFolder)
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
		return IsInsideFarmDeadzone(Origin)
	end

	local Direction = Offset.Unit

	for DistanceTravelled = 0, Distance, CONFIG.DEADZONE_SAMPLE_DISTANCE do
		local Position = Origin + Direction * DistanceTravelled

		if IsInsideFarmDeadzone(Position) then
			return true
		end
	end

	return IsInsideFarmDeadzone(TargetPosition)
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
	if DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, DebugFolder)
	end

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

--// Find a short detour when another player is physically blocking the route.
function GetOtherPlayerDetourPosition(TargetPosition, Goblin)
	if not RootPart or not TargetPosition then
		return nil
	end

	local Origin = RootPart.Position
	local Direction = TargetPosition - Origin
	if Direction.Magnitude <= 0.01 then
		return nil
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		Goblin,
	}
	if DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, DebugFolder)
	end

	local Hit = workspace:Raycast(Origin, Direction, RaycastParams)
	if not Hit then
		return nil
	end

	local Blocker = Hit.Instance and Hit.Instance:FindFirstAncestorOfClass("Model")
	local BlockerPlayer = Blocker and Players:GetPlayerFromCharacter(Blocker)
	if not BlockerPlayer or BlockerPlayer == Player then
		return nil
	end

	local BlockerRoot = Blocker:FindFirstChild("HumanoidRootPart")
	if not BlockerRoot then
		return nil
	end

	local FlatDirection = Vector3.new(Direction.X, 0, Direction.Z)
	if FlatDirection.Magnitude <= 0.01 then
		return nil
	end
	FlatDirection = FlatDirection.Unit

	local Side = Vector3.new(-FlatDirection.Z, 0, FlatDirection.X)
	local DetourDistance = CONFIG.OTHER_PLAYER_DETOUR_DISTANCE
	local Candidates = {
		BlockerRoot.Position + Side * DetourDistance,
		BlockerRoot.Position - Side * DetourDistance,
	}

	for _, Candidate in ipairs(Candidates) do
		local GroundCandidate = GetPatrolGroundPosition(Candidate) or Candidate
		if IsInsideFarmArea(GroundCandidate)
			and not IsInsideFarmDeadzone(GroundCandidate)
			and not IsWaterAtPosition(GroundCandidate, Goblin)
			and not IsPathThroughWater(GroundCandidate)
			and not IsPathThroughDeadzone(GroundCandidate)
		then
			local ToDetour = GroundCandidate - Origin
			local DetourHit = workspace:Raycast(Origin, ToDetour, RaycastParams)
			if not DetourHit then
				return GroundCandidate
			end
		end
	end

	return nil
end

--// Get a safe combat position around the Target.
function IsSafeCombatPathClear(TargetPosition, Goblin)
	if not RootPart or not TargetPosition then
		return false
	end

	local Origin    = RootPart.Position + Vector3.new(0, 1.5, 0)
	local Direction = (TargetPosition - RootPart.Position)

	if Direction.Magnitude <= 0.01 then
		return true
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
		Goblin,   --// เพิ่ม Goblin เข้า exclude ด้วย กันโดนตัวมอนเองที่กำลังจะเดินเข้าหา
	}

	--// Ignore every player's character so other players do not block SafeCombat raycasts.
	for _, OtherPlayer in ipairs(Players:GetPlayers()) do
		if OtherPlayer.Character and OtherPlayer.Character ~= Character then
			table.insert(RaycastParams.FilterDescendantsInstances, OtherPlayer.Character)
		end
	end

	if DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, DebugFolder)
	end

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	if Result then
		--print("[SafeCombat] blocked by:", Result.Instance:GetFullName())
		return false
	end

	return true
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
	local LastAttackerValue = LastAttacker and LastAttacker.Value
	local OtherAttacker = LastAttackerValue and LastAttackerValue ~= Player

	--// Always approach from behind first, regardless of who the LastAttacker is.
	--// When another player is attacking, also alternate the side used for the
	--// approach so the player does not stay on one predictable side.
	if LastAttackerCombatMob ~= TargetMob then
		LastAttackerCombatMob = TargetMob
		LastAttackerCombatSide = math.random(0, 1) == 0 and -1 or 1
		LastAttackerCombatSwitchTime = os.clock() + math.random() * (CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MAX - CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MIN) + CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MIN
		LastAttackerCombatPosition = nil
	elseif os.clock() >= LastAttackerCombatSwitchTime then
		LastAttackerCombatSide *= -1
		LastAttackerCombatSwitchTime = os.clock() + math.random() * (CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MAX - CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MIN) + CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MIN
		LastAttackerCombatPosition = nil
	end

	if OtherAttacker then
		CombatDistance = math.max(CombatDistance, CONFIG.GOBLIN_REACH_DISTANCE)
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
	local PreferredDirections = {}

	--// Farm Zone can make the normal attack radius unreachable when the mob
	--// is close to the edge of the zone. Try progressively closer combat
	--// positions instead of giving up at PLAYER_ATTACK_DISTANCE.
	local CombatDistances = {
		CombatDistance,
		math.max(CONFIG.GOBLIN_REACH_DISTANCE, CombatDistance - 2),
		math.max(CONFIG.GOBLIN_REACH_DISTANCE, CombatDistance - 4),
		math.max(CONFIG.GOBLIN_REACH_DISTANCE, CombatDistance - 6),
		math.max(CONFIG.GOBLIN_REACH_DISTANCE, CombatDistance - 8),
	}

	--// Always prefer the mob's rear. This applies both when LastAttacker is
	--// the local player and when another player is the current attacker.
	local Look = TargetRoot.CFrame.LookVector
	local Right = TargetRoot.CFrame.RightVector
	local Back = Vector3.new(-Look.X, 0, -Look.Z)
	local Side = Vector3.new(Right.X, 0, Right.Z) * LastAttackerCombatSide
	if Back.Magnitude > 0.01 then
		Back = Back.Unit
	end
	if Side.Magnitude > 0.01 then
		Side = Side.Unit
	end
	PreferredDirections = {
		Back,
		Side,
		-Side,
	}

	for _, Direction in ipairs(PreferredDirections) do
		for _, CandidateDistance in ipairs(CombatDistances) do
			local CandidatePosition = TargetRoot.Position + Direction * CandidateDistance
			if IsInsideFarmArea(CandidatePosition)
				and not IsWaterAtPosition(CandidatePosition, TargetMob)
				and not IsPathThroughDeadzone(CandidatePosition)
				and IsPositionSafeFromBladeGroup(CandidatePosition, TargetMob)
			then
				local Dot = math.clamp(CurrentDirection:Dot(Direction), -1, 1)
				local DirectionPenalty = (1 - Dot) * CandidateDistance * 0.2
				table.insert(Candidates, {
					Position = CandidatePosition,
					Score = (CandidatePosition - RootPart.Position).Magnitude + DirectionPenalty - 20,
				})
			end
		end
	end

	for Index = 0, DirectionCount - 1 do
		local Angle = (math.pi * 2 / DirectionCount) * Index
		local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))

		for _, CandidateDistance in ipairs(CombatDistances) do
			local CandidatePosition = TargetRoot.Position + Direction * CandidateDistance

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
			local DirectionPenalty = (1 - Dot) * CandidateDistance * 0.35
			local TravelDistance = (CandidatePosition - RootPart.Position).Magnitude

			table.insert(Candidates, {
				Position = CandidatePosition,
				Score = TravelDistance + DirectionPenalty,
			})
		end
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
	if DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, DebugFolder)
	end

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result == nil
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
	if DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, DebugFolder)
	end

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
function IsRetreatPositionReachable(TargetPosition, RequirePathfinding)
	if not RootPart or not TargetPosition then
		return false
	end

	if not IsInsideFarmArea(TargetPosition)
		or IsWaterAtPosition(TargetPosition)
		or IsPathThroughWater(TargetPosition)
		or IsPathThroughDeadzone(TargetPosition)
	then
		return false
	end

	if not IsPathClear(TargetPosition) then
		return false
	end

	--// A retreat position is only useful if it is outside every active
	--// enemy blade danger area, and the route does not cross one.
	for _, Goblin in GetLivingGoblins() do
		if IsPositionSafeFromBladeGroup(TargetPosition, Goblin) == false
			or IsPathThroughBladeGroupDanger(TargetPosition, Goblin)
		then
			return false
		end
	end

	if not RequirePathfinding then
		return true
	end

	local Path = PathfindingService:CreatePath({
		AgentRadius    = math.max(RootPart.Size.X * 0.5, 2),
		AgentHeight    = math.max(RootPart.Size.Y, 5),
		AgentCanJump   = true,
		WaypointSpacing = 4,
	})

	local Success = pcall(function()
		Path:ComputeAsync(RootPart.Position, TargetPosition)
	end)

	if not Success or Path.Status ~= Enum.PathStatus.Success then
		return false
	end

	local Waypoints = Path:GetWaypoints()

	if #Waypoints < 2 then
		return false
	end

	for Index = 2, #Waypoints do
		local Position = Waypoints[Index].Position

		if not IsInsideFarmArea(Position)
			or IsWaterAtPosition(Position)
			or IsPathThroughDeadzone(Position)
		then
			return false
		end
	end

	return true
end

function GetEnemySkillRetreatPosition()
	if not RootPart then
		return nil
	end

	local Threats = GetLivingGoblins()

	if #Threats == 0 then
		return nil
	end

	local Origin = RootPart.Position
	local Away = Vector3.zero

	--// Weight every nearby enemy by inverse distance.
	--// This makes the retreat direction react to the whole group instead
	--// of blindly running directly away from the current target.
	for _, Goblin in Threats do
		local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

		if MobRoot then
			local Offset = Origin - MobRoot.Position
			local Horizontal = Vector3.new(Offset.X, 0, Offset.Z)
			local Distance = Horizontal.Magnitude

			if Distance > 0.01 then
				Away += Horizontal.Unit / math.max(Distance, 4)
			end
		end
	end

	if Away.Magnitude <= 0.01 then
		return nil
	end

	Away = Away.Unit

	local Directions = {}

	--// Test the direct escape first, then progressively wider angles.
	--// The longer candidates are preferred so the player gets out of
	--// the skill range quickly instead of stopping after a tiny step.
	for Index = 0, CONFIG.RETREAT_DIRECTIONS - 1 do
		local Angle = (math.pi * 2 / CONFIG.RETREAT_DIRECTIONS) * Index
		local Direction = CFrame.fromAxisAngle(Vector3.yAxis, Angle):VectorToWorldSpace(Away)

		table.insert(Directions, Direction)
	end

	local BestPosition = nil
	local BestScore = -math.huge

	for _, Direction in ipairs(Directions) do
		Direction = Vector3.new(Direction.X, 0, Direction.Z)

		if Direction.Magnitude <= 0.01 then
			continue
		end

		Direction = Direction.Unit

		for _, Distance in ipairs({
			CONFIG.SKILL_RETREAT_DISTANCE,
			48,
			36,
			28,
			20,
			}) do
			local Candidate = Origin + Direction * Distance

			if not IsRetreatPositionReachable(Candidate, true) then
				continue
			end

			local DirectionScore = Away:Dot(Direction)
			local DistanceScore = Distance / CONFIG.SKILL_RETREAT_DISTANCE

			--// Strongly prefer getting farther away, but only after the
			--// candidate has passed the actual reachability/safety checks.
			local Score = DirectionScore * 5 + DistanceScore * 3

			if Score > BestScore then
				BestScore = Score
				BestPosition = Candidate
			end

			--// Once a safe long route exists in this direction, don't
			--// waste pathfinding calls on the shorter candidates.
			break
		end
	end

	--// Emergency local fallback: if every long retreat candidate is
	--// rejected, still try a short escape around the player. This does
	--// not use PathfindingService, but it still respects FarmZone,
	--// Deadzone, water and blade-safety checks.
	if not BestPosition then
		for _, Distance in ipairs({12, 8, 5}) do
			local Candidate = Origin + Away * Distance
			if IsRetreatPositionReachable(Candidate, false) then
				BestPosition = Candidate
				break
			end
		end
	end

	return BestPosition
end

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

--// Check whether any living priority mob is close enough to justify retreat movement.
function GetNearestLivingGoblinDistance()
	if not RootPart then
		return math.huge
	end

	local NearestDistance = math.huge

	for _, Goblin in GetLivingGoblins() do
		local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

		if MobRoot then
			local Distance = GetHorizontalDistance(RootPart.Position, MobRoot.Position)

			if Distance < NearestDistance then
				NearestDistance = Distance
			end
		end
	end

	return NearestDistance
end

--// Retreat
function RetreatFromGoblins(IsEnemySkill)
	local RetreatPosition = nil
	local now = os.clock()

	--// Normal retreat only triggers movement/jump when a mob is within
	--// the configured nearby distance. Enemy skill retreat is different:
	--// if a mob is actively using a skill, keep the skill-escape logic
	--// even when that mob is farther than the normal 30-stud trigger.
	if not IsEnemySkill then
		local NearestMobDistance = GetNearestLivingGoblinDistance()
		if NearestMobDistance > CONFIG.RETREAT_NEARBY_MOB_DISTANCE then
			Humanoid.AutoRotate = false
			Humanoid:Move(Vector3.zero)
			return false
		end
	end

	if IsEnemySkill then
		if SkillRetreatPosition
			and now - LastSkillRetreatTime < CONFIG.RETREAT_RECALCULATE_INTERVAL
			and IsRetreatPositionReachable(SkillRetreatPosition, false)
		then
			RetreatPosition = SkillRetreatPosition
		else
			RetreatPosition = GetEnemySkillRetreatPosition()

			if RetreatPosition then
				SkillRetreatPosition = RetreatPosition
				LastSkillRetreatTime = now
			else
				SkillRetreatPosition = nil
			end
		end
	else
		if LastRetreatPosition
			and now - LastRetreatCalculateTime < CONFIG.RETREAT_RECALCULATE_INTERVAL
		then
			RetreatPosition = LastRetreatPosition
		else
			RetreatPosition = GetRetreatPosition()

			if RetreatPosition then
				LastRetreatPosition      = RetreatPosition
				LastRetreatCalculateTime = now
				RetreatNoPositionSince   = nil
			elseif not RetreatNoPositionSince then
				RetreatNoPositionSince = now
			end
		end
	end

	if RetreatPosition then
		--// Face the actual retreat direction instead of the target.
		Humanoid.AutoRotate = false
		Humanoid:MoveTo(RetreatPosition)

		local RootPosition = RootPart.Position
		local RetreatDirection = Vector3.new(
			RetreatPosition.X - RootPosition.X,
			0,
			RetreatPosition.Z - RootPosition.Z
		)

		if RetreatDirection.Magnitude > 0.01 then
			FaceOrientation.CFrame = CFrame.lookAt(
				RootPosition,
				RootPosition + RetreatDirection.Unit
			)
			FaceOrientation.Enabled = true
		end

		DoJump()
		return true
	end

	Humanoid.AutoRotate = false
	Humanoid:Move(Vector3.zero)
	return false
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
	if DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, DebugFolder)
	end

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
	if DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, DebugFolder)
	end

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
--// SAFE ENEMY RANGE
--// ============================================================

function GetSafeEnemyRangePosition(Goblin)
	if not RootPart or not Goblin then
		return nil
	end

	local SafeRange = math.max(tonumber(CONFIG.SAFE_ENEMY_RANGE) or 0, 0)
	if SafeRange <= 0 then
		return nil
	end

	local TargetRoot = Goblin:FindFirstChild("HumanoidRootPart")
	if not TargetRoot then
		return nil
	end

	local BladeParts = GetCombatBladeParts(Goblin)
	if #BladeParts == 0 then
		return nil
	end

	local LastAttacker = Goblin:FindFirstChild("LastAttacker")
	local IsPlayerAttacker = LastAttacker and LastAttacker.Value == Player

	local ClosestBlade = nil
	local ClosestPoint = nil
	local ClosestDistance = math.huge

	for _, BladePart in ipairs(BladeParts) do
		local Point, Distance = GetClosestPointOnBlade(BladePart, RootPart.Position)
		if Point and Distance < ClosestDistance then
			ClosestBlade = BladePart
			ClosestPoint = Point
			ClosestDistance = Distance
		end
	end

	if not ClosestBlade or not ClosestPoint then
		return nil
	end

	local CurrentPosition = RootPart.Position

	--// When the local player is the LastAttacker, prefer the mob's rear
	--// first, then the two sides. No visibility/path/water checks are used.
	local Look = TargetRoot.CFrame.LookVector
	local Right = TargetRoot.CFrame.RightVector
	local Back = Vector3.new(-Look.X, 0, -Look.Z)
	local Side = Vector3.new(Right.X, 0, Right.Z)

	if Back.Magnitude > 0.01 then
		Back = Back.Unit
	else
		Back = Vector3.zAxis
	end

	if Side.Magnitude > 0.01 then
		Side = Side.Unit
	else
		Side = Vector3.xAxis
	end

	local AwayFromBlade = CurrentPosition - ClosestPoint
	local FlatAwayFromBlade = Vector3.new(AwayFromBlade.X, 0, AwayFromBlade.Z)
	if FlatAwayFromBlade.Magnitude > 0.01 then
		FlatAwayFromBlade = FlatAwayFromBlade.Unit
	else
		FlatAwayFromBlade = Back
	end

	local Directions
	if IsPlayerAttacker then
		Directions = {
			Back,
			Side,
			-Side,
			FlatAwayFromBlade,
		}
	else
		Directions = {
			FlatAwayFromBlade,
			Back,
			Side,
			-Side,
		}
	end

	for _, Direction in ipairs(Directions) do
		local Candidate = ClosestPoint + Direction * SafeRange

		--// The only environment checks for Safe Enemy Range:
		--// stay inside FarmZone and never enter a Deadzone.
		if IsInsideFarmArea(Candidate) and not IsInsideFarmDeadzone(Candidate) then
			local SafeFromAllBlades = true
			for _, BladePart in ipairs(BladeParts) do
				local _, Distance = GetClosestPointOnBlade(BladePart, Candidate)
				if Distance < SafeRange then
					SafeFromAllBlades = false
					break
				end
			end

			if SafeFromAllBlades then
				return Candidate
			end
		end
	end

	return nil
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

	--// Safe Enemy Range has its own lightweight rule set.
	--// It only cares about BladePart distance, FarmZone, and Deadzone.
	--// It does not use CanSeeGoblin, water checks, path checks, or SafeCombat.
	local SafeEnemyRangePosition = GetSafeEnemyRangePosition(Goblin)
	if SafeEnemyRangePosition then
		local SafeEnemyOffset = SafeEnemyRangePosition - RootPart.Position
		local SafeEnemyDistance = Vector3.new(SafeEnemyOffset.X, 0, SafeEnemyOffset.Z).Magnitude

		if SafeEnemyDistance > 2 then
			ResetTargetPath()
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(SafeEnemyRangePosition)
			FaceGoblin(Goblin)
			return
		end
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
		CACHED_SAFECOMBAT_POSITION = nil
		CACHED_SAFECOMBAT_TARGET = Goblin
		LAST_SAFECOMBAT_TIME = 0
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

	local SafeCombatPosition = CACHED_SAFECOMBAT_POSITION
	if CACHED_SAFECOMBAT_TARGET ~= Goblin
		or now - LAST_SAFECOMBAT_TIME >= CONFIG.SAFECOMBAT_INTERVAL
		or (SafeCombatPosition and not IsInsideFarmArea(SafeCombatPosition))
	then
		LAST_SAFECOMBAT_TIME = now
		CACHED_SAFECOMBAT_TARGET = Goblin
		SafeCombatPosition = GetSafeCombatPosition(Goblin)
		CACHED_SAFECOMBAT_POSITION = SafeCombatPosition
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

	local OtherPlayerDetour = GetOtherPlayerDetourPosition(PathDestination, Goblin)
	if OtherPlayerDetour then
		ResetTargetPath()
		Humanoid.AutoRotate = true
		Humanoid:MoveTo(OtherPlayerDetour)
		return
	end

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

	--// No safe combat position was found. Do not make the target appear
	--// invisible just because the safe-position solver failed. If the direct
	--// route is clear, move toward the actual mob and let the blade-danger check
	--// above keep us from standing inside the enemy weapon range.
	if IsSafeCombatPathClear(MobRoot.Position, Goblin)
		and not IsPathThroughWater(MobRoot.Position)
		and not IsPathThroughDeadzone(MobRoot.Position)
	then
		TargetUnreachableSince = nil
		Humanoid.AutoRotate = false
		Humanoid:MoveTo(MobRoot.Position)
		FaceGoblin(Goblin)
		return
	end

	--// The mob is still a valid target even when the safe-position solver
	--// cannot find a perfect attack point. Keep the target locked while the
	--// pathfinding/reposition logic retries instead of dropping visibility.
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
	if DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, DebugFolder)
	end

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
	if DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, DebugFolder)
	end

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
	local Center = (PlaceConfig and PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Center) or (RootPart and RootPart.Position) or Vector3.zero
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
	local PreviousReturnPosition = FarmReturnPosition
	FarmReturnPosition = nil

	local FarmCenter = (PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Center) or RootPart.Position
	local Origin = RootPart.Position
	local Candidates = {}

	--// Return to a randomized point 10-20 studs away from the farm center.
	--// This prevents the character from repeatedly standing on the same spot.
	for Index = 1, 24 do
		local Angle = math.random() * math.pi * 2
		local Radius = 10 + math.random() * 10
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
			table.insert(Candidates, Candidate)
		end
	end

	if #Candidates > 0 then
		--// Prefer a point that is not almost identical to the previous return spot.
		local Filtered = {}
		for _, Candidate in ipairs(Candidates) do
			if not PreviousReturnPosition
				or (Candidate - PreviousReturnPosition).Magnitude >= 4
			then
				table.insert(Filtered, Candidate)
			end
		end

		if #Filtered > 0 then
			Candidates = Filtered
		end

		FarmReturnPosition = Candidates[math.random(1, #Candidates)]
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

	local FarmCenter = (PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Center) or RootPart.Position
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

	--// Auto Block is controlled by the active profile/default config.
	--// Do not gate it by the static PLACE_CONFIG table because profiles can
	--// enable Auto Block even when the current PlaceId has no built-in config.
	--if IsValidPlace(game.PlaceId) then
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
		ResetDebugWaypoints()
		CONFIG.CURRENT_WAYPOINT_TARGET = 1
		table.clear(ValidMobs)
		ClosestTarget = nil
		return
	end

	if now - LAST_TEXT_UPDATE_TIME >= CONFIG.TEXT_UPDATE_INTERVAL then
		LAST_TEXT_UPDATE_TIME = now
		updatePlayTime()
		updateEventCurrency()

		WayPointLabel.Text = "WAYPOINTS:  ".. CONFIG.CURRENT_WAYPOINT_TARGET .. "/" .. (PlaceConfig and #PlaceConfig.WAYPOINTS or 0)
		WalkSpeedLabel.Text = "WALKSPEED:  " .. tostring(math.floor(Humanoid.WalkSpeed + 0.5))
		DeathLabel.Text = "DEATH:  " .. tostring(DEATH_COUNT)
	end

	if Feature.DebugVisualizer.Enabled then
		UpdateDebugWaypointColors()
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
	local RetreatHealthPercent = math.clamp(tonumber(CONFIG.RETREAT_HEALTH_PERCENT) or 40, 30, 80)
	local AutoHealHealthPercent = math.clamp(tonumber(CONFIG.AUTO_HEAL_HEALTH_PERCENT) or 65, 30, 80)
	local RetreatHealthRatio = RetreatHealthPercent / 100
	local AutoHealHealthRatio = AutoHealHealthPercent / 100
	local RecoverHealthPercent = math.min(95, math.max(70, RetreatHealthPercent + 10))
	local EmergencyHealth = Humanoid.Health <= Humanoid.MaxHealth * RetreatHealthRatio
	local ShouldHeal      = Humanoid.Health <= Humanoid.MaxHealth * AutoHealHealthRatio

	local EnemyUsingSkill = false
	if ClosestTarget then
		local EnemySword = ClosestTarget:FindFirstChild("Sword")
		local EnemyRootPart = ClosestTarget:FindFirstChild("HumanoidRootPart")
		local BladePart = EnemySword and EnemySword:FindFirstChild("BladePart")
		local SkillObject = ClosestTarget:FindFirstChild("Skill", true)
		local Sparkles = BladePart and BladePart:FindFirstChild("Sparkles", true)

		--// Skill is a Sound: only treat it as active while it is actually playing.
		local SkillSoundActive = SkillObject
			and SkillObject:IsA("Sound")
			and SkillObject.IsPlaying

		--// Sparkles is a ParticleEmitter: only treat it as active when enabled.
		local SparklesActive = Sparkles
			and Sparkles:IsA("ParticleEmitter")
			and Sparkles.Enabled

		EnemyUsingSkill = SkillSoundActive or SparklesActive or false

		if EnemyUsingSkill then
			RETREATING = true
		end
	end

	if EmergencyHealth or (PlayerStats.Level.Value >= 300 and Humanoid.WalkSpeed < CONFIG.MAXIMUM_WALKSPEED) then
		RETREATING = true
	elseif RETREATING and Humanoid.Health >= Humanoid.MaxHealth * (RecoverHealthPercent / 100) and not EnemyUsingSkill then
		RETREATING = false

		--// Re-acquire a valid target immediately after healing so the
		--// combat loop does not wait for another target cycle.
		if not IsTargetLockValid(ClosestTarget) then
			ClosestTarget = GetClosestGoblin()
		end
	end

	if RETREATING then
		local UseConsumable = Replicated:FindFirstChild("UseConsumable", true)
		local PlayerStats   = Player:FindFirstChild("PlayerStats")

		RetreatFromGoblins(EnemyUsingSkill)

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

	--// Enemy skill retreat speed is temporary. Once retreating ends,
	--// return to the normal movement cap on the next heartbeat.
	if not EnemyUsingSkill and Humanoid.WalkSpeed > CONFIG.MAXIMUM_WALKSPEED then
		Humanoid.WalkSpeed = CONFIG.MAXIMUM_WALKSPEED
	end

	--// Player Check
	if BlockEnabled then
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
	local HasWaypoints = PlaceConfig and #PlaceConfig.WAYPOINTS > 0
	local AtLastWaypoint = not HasWaypoints
		or CONFIG.CURRENT_WAYPOINT_TARGET > #PlaceConfig.WAYPOINTS
	local target = HasWaypoints and PlaceConfig.WAYPOINTS[CONFIG.CURRENT_WAYPOINT_TARGET] or nil

	local OutsideFarmZone = not IsInsideFarmArea(RootPart.Position)
	local InFarmDeadzone = IsInsideFarmDeadzone(RootPart.Position)

	--// FarmZone return is handled first when the player is outside the allowed area.
	if PlaceConfig
		and Feature.ReturnToFarmZone.Enabled
		and not Feature.IgnoreFarmZone.Enabled
		and AtLastWaypoint
		and (OutsideFarmZone or InFarmDeadzone)
	then
		ClosestTarget = nil
		MoveBackToFarmZone()

	--// IMPORTANT: while there are still waypoints remaining, NEVER search for or
	--// move toward mobs. Complete the waypoint route first.
	elseif PlaceConfig and not Feature.AutoFind.Enabled and not AtLastWaypoint and target then
		ClosestTarget = nil

		local WaypointOffset = target - RootPart.Position
		local WaypointHorizontalDistance = Vector3.new(WaypointOffset.X, 0, WaypointOffset.Z).Magnitude
		local WaypointVerticalDistance = math.abs(WaypointOffset.Y)
		local ReachDistance = tonumber(PlaceConfig.REACH_DISTANCE) or 5

		if WaypointHorizontalDistance <= ReachDistance
			and WaypointVerticalDistance <= math.max(ReachDistance, CONFIG.JUMP_HEIGHT + 2)
		then
			CONFIG.CURRENT_WAYPOINT_TARGET += 1
			LAST_STUCK_POSITION = nil
			LAST_STUCK_TIME = now
			target = PlaceConfig.WAYPOINTS[CONFIG.CURRENT_WAYPOINT_TARGET]
			UpdateDebugWaypointColors()
		end

		if target then
			FaceOrientation.Enabled = false
			Humanoid.AutoRotate = true
			Humanoid:MoveTo(target)
		end

		if now - LAST_STUCK_TIME >= CONFIG.STUCK_CHECK_INTERVAL then
			LAST_STUCK_TIME = now
			if LAST_STUCK_POSITION and (RootPart.Position - LAST_STUCK_POSITION).Magnitude < 1 then
				DoJump()
			else
				LAST_STUCK_POSITION = RootPart.Position
			end
		end

	else
		--// Only after the final waypoint may mob detection begin.
		if not ClosestTarget then
			ClosestTarget = GetClosestGoblin()
		end

		if ClosestTarget and ClosestTarget.Parent and not IsTargetLockValid(ClosestTarget) then
			ClosestTarget = nil
		end

		if ClosestTarget then
			MoveToGoblin(ClosestTarget)
		elseif Feature.AutoPatrol.Enabled and (Feature.AutoFind.Enabled or AtLastWaypoint) then
			MoveToPatrol()
		elseif not Feature.ReturnToFarmZone.Enabled and not Feature.IgnoreFarmZone.Enabled then
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
	end

	--// Jump
	if PlaceConfig and not Feature.AutoFind.Enabled and target then
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
	--// A valid target inside FarmZone is also allowed to attack before
	--// the final waypoint; FarmZone restriction is handled by movement above.
	if Feature.AutoFind.Enabled or AtLastWaypoint or (ClosestTarget and not Feature.IgnoreFarmZone.Enabled) then
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
