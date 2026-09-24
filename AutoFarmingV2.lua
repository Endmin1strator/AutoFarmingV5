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

--==============================================================
--// LAYERS
--//
--// Every function in this file lives on one of the tables below.
--// A layer only ever calls downward in this list, never upward,
--// so the dependency direction stays readable at a glance.
--//
--//
--// The tables are declared up front and filled in further down, so
--// call order between layers does not depend on definition order.
--==============================================================
local AFConfig = {}
local AFProfile = {}
local AFCombatUtils = {}
local AFCombat = {}
local AFFeature = {}
local AFUI = {}
local AFDebug = {}

--// Every module keeps its mutable state on its own S table. Ownership is
--// then obvious from the name alone, resetting a whole area is one
--// table.clear, and none of it costs a local register, which is what put
--// this file into the compiler limit before.
AFProfile.S = {}
AFCombat.S = {}
AFCombatUtils.S = {}
AFFeature.S = {}
AFUI.S = {}
AFDebug.S = {}

--// Luau allows 200 local registers in a chunk and this file had reached
--// exactly that, which the compiler rejects outright, so nothing loaded at
--// all. Related state lives on a table instead of one register each: the UI
--// handles and everything the patrol keeps between frames.
local UIRef = {}
local PatrolState = {}

--// Utils is expected to be a ModuleScript named "Utils" under ReplicatedStorage.
local Utils = loadstring(game:HttpGet("https://raw.githubusercontent.com/zeroschth38-jpg/AutoFarmingV5/refs/heads/master/main/Utils.lua"))()
local UI = Utils.new("AUTO FARMING v2.31")

local function NotifyAction(Action, Message, Duration)
	if UI and type(UI.Notify) == "function" then
		UI:Notify(Action, Message, Duration or 2.5)
	end
end

--======================================================================
--// SECTION 1  ::  CONFIGURATION AND STATE
--// Pure data and every top-level variable, declared before any layer runs.
--======================================================================


local CONFIG = {
	CURRENT_WAYPOINT_TARGET = 1,
	MAX_SERVER_AGE = 7 * 60 * 60,

	TARGET_ENTITY_PRIORITY = {
		[1] = "Goblin",
		[2] = "Leader Goblin",
	},

	--// Below this share of its health a target is finished off instead of
	--// retreated from. An enemy skill still overrides it, since eating the
	--// skill to land one more hit is not a trade worth making.
	EXECUTE_CHARGE_HP_PERCENT = 0,

	--// Roblox disconnects an idle client after about twenty minutes. The
	--// script drives the character, not the mouse, so the idle timer keeps
	--// running. Nudged well inside that window.
	ANTI_AFK_INTERVAL = 480,

	--// Tie break between mobs of equal priority.
	--// "Disabled" keeps the original nearest-first behaviour.
	TARGET_HP_MODE = "Disabled",

	--// UserIds that are allowed to share the server. Auto Block ignores
	--// these players entirely and only reacts to anyone else.
	BLOCK_WHITELIST = {},

	--// Saved arrangement of the pinned item panel: which items, whether it
	--// has been popped out of the window, and where it was left.
	PINNED_STATE = {},

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
	--// GetLivingGoblins walks the whole mob folder, and the retreat solver
	--// calls it once per candidate, so one solve used to rescan the folder
	--// dozens of times. The list cannot meaningfully change inside this.
	LIVING_MOB_CACHE_INTERVAL = 0.1,
	DISTANCE_Y_CALCULATE = false,
	--// How long to keep trying to reach a mob before concluding there is no
	--// route to it, and how long to leave it alone afterwards. Without the
	--// second value the target is dropped and then immediately reselected,
	--// so the character runs at something it can never reach forever.
	TARGET_UNREACHABLE_TIMEOUT = 6,
	UNREACHABLE_COOLDOWN = 15,
	TARGET_REPOSITION_INTERVAL = 0.3,
	TARGET_PATH_RECALCULATE_INTERVAL = 0.5,
	TARGET_PATH_WAYPOINT_DISTANCE = 3,
	TARGET_REPOSITION_RADIUS = 12,
	TARGET_REPOSITION_DIRECTIONS = 16,
	SAFE_COMBAT_DIRECTIONS = 12,
	SAFE_COMBAT_MAX_PATH_TESTS = 4,
	--// Cost added to a combat position the mob cannot be seen from. Losing
	--// sight behind a pillar should cost a detour, not the whole candidate.
	BLIND_POSITION_PENALTY = 14,

	--// Jumping is only useful against something that can be jumped over, so
	--// movement probes ahead instead of hopping on every frame. A hit low
	--// down with clear space above it is a ledge or a rock; a hit at both
	--// heights is a wall, which a jump does not solve.
	JUMP_PROBE_DISTANCE = 4.5,
	JUMP_PROBE_LOW_OFFSET = 0.6,
	JUMP_PROBE_HIGH_OFFSET = 3.2,
	JUMP_STEP_HEIGHT = 1.2,
	--// How far outside the farm zone the return may still pathfind from.
	FARM_RETURN_PATH_DISTANCE = 220,
	OTHER_ATTACKER_SIDE_SWITCH_MIN = 0.1,
	OTHER_ATTACKER_SIDE_SWITCH_MAX = 0.3,
	OTHER_PLAYER_DETOUR_DISTANCE = 4,

	RETREAT_DISTANCE = 60,
	RETREAT_DIRECTIONS = 16,
	RETREAT_RECALCULATE_INTERVAL = 0.12,
	RETREAT_NO_POSITION_TIMEOUT = 1.5,
	SKILL_RETREAT_DISTANCE = 60,
	SKILL_RETREAT_PATH_TIMEOUT = 0.35,

	--// Enemy skill reaction. Detection covers every nearby mob, not just the
	--// current target, because a skill from a mob we are not fighting still
	--// connects. The hold keeps the dodge running for a moment after the
	--// signal clears, so a flickering sound or emitter cannot drop us back
	--// into the attack halfway through the escape.
	SKILL_DETECT_DISTANCE = 45,
	SKILL_DODGE_HOLD = 0.75,
	SKILL_DODGE_DISTANCE = 26,
	SKILL_DODGE_FALLBACK_DISTANCE = 14,
	SKILL_DODGE_DIRECTIONS = 9,
	SKILL_DODGE_SPREAD = 110,
	--// The pathfinding retreat solver is expensive enough to stall frames, so
	--// during a dodge it is a fallback that runs at most this often.
	SKILL_SOLVER_INTERVAL = 0.6,

	--// Sheathing and drawing the weapon both play an animation. Without a
	--// floor between toggles the script can flap once per frame.
	EQUIP_TOGGLE_COOLDOWN = 0.35,

	ATTACK_INTERVAL = 0.16,
	SKILL_INTERVAL = 3,
	COMBAT_ATTACK_RANGE = 14.5,
	COMBAT_SKILL_RANGE = 15,
	COMBAT_FACE_RANGE = 22,
	COMBAT_TARGET_GRACE = 0.45,
	COMBAT_LOW_HP_PERCENT = 35,
	COMBAT_SKILL_MIN_HP_PERCENT = 50,
	COMBAT_ACTION_JITTER = 0.025,
	COMBAT_TARGET_RECHECK = 0.08,
	COMBAT_STICKY_DISTANCE_BONUS = 6,
	COMBAT_FINISHER_HP_PERCENT = 18,
	COMBAT_FINISHER_RANGE_BONUS = 1.5,
	COMBAT_ENGAGE_MAX_DISTANCE = 50,
	COMBAT_POSITION_ARRIVAL = 2,
	APPROACH_ARRIVAL_DISTANCE = 3,
	SAFE_ENEMY_RANGE_ARRIVAL = 2,
	CONSUME_INTERVAL = 10,
	MINIMUM_WALKSPEED = 28,
	MAXIMUM_WALKSPEED = 38,
	HIGH_LEVEL_THRESHOLD = 300,
	STAT_RESET_THRESHOLD = 500,
	INTERACTION_INTERVAL = 0.5,
	TEXT_UPDATE_INTERVAL = 0.5,
	PROFILE_SAVE_DEBOUNCE = 0.5,

	DEBUG_VISUALIZE_WAYPOINTS = true,
	DEBUG_WAYPOINT_MAX_DISTANCE = 500,
	DEBUG_WAYPOINT_SIZE = 0.75,
	DEBUG_ZONE_HEIGHT = 0.15,

	SAFECOMBAT_INTERVAL = 0.25,
	BLADE_PART_CACHE_INTERVAL = 0.2,
	COMBAT_GROUP_CACHE_INTERVAL = 0.15,
	DIRECT_PATH_CACHE_INTERVAL = 0.12,

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

	--// A person walking somewhere does not move in one unbroken line to a
	--// point and stop dead. They pause partway, change their mind about how
	--// far to go, and do not stop at exactly the same distance every time.
	PATROL_MIDWALK_PAUSE_CHANCE = 0.18,
	PATROL_MIDWALK_PAUSE_MIN = 0.4,
	PATROL_MIDWALK_PAUSE_MAX = 1.5,
	PATROL_MIDWALK_ROLL_INTERVAL = 1.1,
	PATROL_SHORT_LEG_CHANCE = 0.22,
	PATROL_SHORT_LEG_SCALE = 0.45,
	PATROL_ARRIVAL_JITTER = 2.5,

	--// A patrol runs several legs back to back before resting, the number
	--// picked per rest, rather than stopping at every single point.
	PATROL_LEGS_MIN = 1,
	PATROL_LEGS_MAX = 4,

	--// Direction changes are steered rather than switched. The heading turns
	--// at a limited rate toward the new bearing and the character walks at a
	--// point just ahead of itself, which traces an arc instead of pivoting on
	--// the spot. Lower turn rate means a wider curve.
	PATROL_TURN_RATE = 150,
	PATROL_LOOKAHEAD = 11,
	PATROL_CURVE_MIN_ANGLE = 12,

	--// Occasionally lean the heading off the direct bearing for a moment, so
	--// a leg wanders instead of running dead straight. Rolled on an interval
	--// and deliberately uncommon; a constant weave looks worse than a
	--// straight line.
	PATROL_RANDOM_CURVE_CHANCE = 0.22,
	PATROL_RANDOM_CURVE_ROLL_INTERVAL = 2.6,
	PATROL_RANDOM_CURVE_MIN_TIME = 1.2,
	PATROL_RANDOM_CURVE_MAX_TIME = 2.5,

	--// The wander is described by the radius of the arc it walks rather than
	--// by an angle. Radius is what is actually visible: a small one is a
	--// tight loop around something, a large one is a barely perceptible
	--// drift. Turn rate follows from it and the walk speed, so the arc holds
	--// its shape whatever the character is moving at.
	PATROL_CURVE_RADIUS_MIN = 12,
	PATROL_CURVE_RADIUS_MAX = 55,
	--// Cap on how far the bearing may sweep off course, so a long curve
	--// bends the route instead of turning it into a circle.
	PATROL_CURVE_MAX_SWEEP = 48,
	PATROL_SMOOTH_SNAP_DISTANCE = 7,

	--// Movement only jumps when it is genuinely stuck: barely moving while
	--// actively trying to. Checked over this window.
	STUCK_SAMPLE_INTERVAL = 0.35,
	STUCK_MIN_PROGRESS = 0.6,

	FARM_RETURN_CANDIDATES = 24,
	FARM_RETURN_RADIUS_MIN = 10,
	FARM_RETURN_RADIUS_MAX = 20,
	FARM_RETURN_RECALCULATE_INTERVAL = 0.75,
	FARM_RETURN_MIN_SPREAD = 4,
	FARM_RETURN_ARRIVAL_DISTANCE = 4,
	FARM_RETURN_CENTER_DISTANCE = 5,

	--// Zones are cylinders: the radius check ignores height so that sloped
	--// ground inside one zone still counts. On a multi-floor map that lets a
	--// mob one floor above or below match a zone it is not really in. Set a
	--// positive value to also require the point to be within this many studs
	--// of the zone centre vertically. 0 keeps the original flat behaviour.
	ZONE_MAX_HEIGHT_DIFFERENCE = 0,

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

local PlaceConfig

--//==============================================================
--// Profile Store
--// Profiles are stored per PlaceId. The last used profile for the
--// current place is restored automatically on the next execution.
--//==============================================================
local PROFILE_FOLDER = "AutoFarmProfiles"
local PROFILE_FILE

AFProfile.S.ActiveProfileName = nil
AFProfile.S.ProfileSaveQueued = false
AFProfile.S.ProfileData = nil
UIRef.ProfileDropdown = nil
UIRef.ProfileNameBox = nil
UIRef.ImportDataBox = nil
UIRef.ProfileStatusLabel = nil
UIRef.ReachDistanceBox = nil

AFFeature.S.DeadzoneEscapePosition = nil
PatrolState.PatrolPosition = nil
PatrolState.LastPatrolCalculateTime = 0
PatrolState.PatrolDirection = nil
PatrolState.PatrolPauseUntil = 0
PatrolState.PatrolLastPosition = nil
PatrolState.PatrolLastDistance = 0
PatrolState.PatrolMidwalkRollTime = 0
PatrolState.PatrolArrivalDistance = 0
PatrolState.PatrolLegsRemaining = 0
PatrolState.PatrolHeading = nil
PatrolState.PatrolSteerTime = 0
PatrolState.PatrolCurveBias = 0
PatrolState.PatrolCurveUntil = 0
PatrolState.PatrolCurveRollTime = 0
AFFeature.S.LastAntiAfkTime = 0
AFCombatUtils.S.StuckSampleTime = 0
AFCombatUtils.S.StuckSamplePosition = nil
AFCombatUtils.S.StuckStrikes = 0
AFFeature.S.FarmReturnPosition = nil
AFFeature.S.LastFarmReturnCalculateTime = 0
AFProfile.S.SelectedFarmZoneIndex = 1
AFProfile.S.SelectedDeadzoneIndex = 1

local BasePlaceConfig


local Character
local Humanoid
local RootPart
--// Character handles shared by several modules, in the same class as the
--// three above: nothing owns the character, so nothing owns these.
local FaceOrientation
local InputBindableFunction

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

AFCombat.S.ClosestTarget = nil
AFFeature.S.DEATH_COUNT = 0
AFCombat.S.LAST_MOB_VALIDATION_TIME = 0
AFCombat.S.TargetUnreachableSince = nil
AFCombat.S.TargetApproachPosition = nil
AFCombat.S.TargetApproachMob = nil
AFCombat.S.LastTargetRepositionTime = 0

AFCombat.S.TargetPath = nil
AFCombat.S.TargetPathMob = nil
AFCombat.S.TargetPathDestination = nil
AFCombat.S.TargetPathWaypoint = 1
AFCombat.S.LastTargetPathTime = 0
AFCombat.S.TargetPathBlockedSince = nil

AFCombat.S.ValidMobs = {}
AFCombat.S.UnreachableMobs = {}
AFCombat.S.LivingGoblinCache = nil
AFCombat.S.LivingGoblinCacheTime = 0

AFCombat.S.RETREATING = false
AFCombat.S.LastRetreatPosition = nil
AFCombat.S.LastRetreatCalculateTime = 0
AFCombat.S.RetreatNoPositionSince = nil
AFCombat.S.SkillRetreatPosition = nil
AFCombat.S.LastSkillRetreatTime = 0
AFCombat.S.SkillThreatUntil = 0
AFCombat.S.LastSkillSolverTime = 0
AFFeature.S.LAST_EQUIP_TIME = 0

AFCombat.S.LAST_ATTACK_TIME = 0
AFCombat.S.LAST_SKILL_TIME = 0
AFCombat.S.LAST_COMBAT_TARGET_CHECK = 0
AFCombat.S.COMBAT_TARGET_LOST_SINCE = nil
AFCombat.S.COMBAT_TARGET_SCORE = math.huge
AFCombat.S.COMBAT_ATTACK_PHASE = 0
AFCombat.S.COMBAT_NEXT_ATTACK_TIME = 0
AFCombat.S.COMBAT_NEXT_SKILL_TIME = 0

--// Potion Consume

AFFeature.S.LAST_CONSUME_TIME = 0
AFFeature.S.LAST_INTERACTION_TIME = 0
AFUI.S.LAST_TEXT_UPDATE_TIME = 0
AFCombatUtils.S.LAST_STUCK_TIME = 0
AFCombatUtils.S.LAST_STUCK_POSITION = nil

AFCombat.S.CACHED_SAFECOMBAT_POSITION = nil
AFCombat.S.CACHED_SAFECOMBAT_TARGET = nil
AFCombat.S.LAST_SAFECOMBAT_TIME = 0
AFCombat.S.LastAttackerCombatMob = nil
AFCombat.S.LastAttackerCombatSide = 1
AFCombat.S.LastAttackerCombatSwitchTime = 0
AFCombat.S.LastAttackerCombatPosition = nil

AFCombatUtils.S.BladePartCache = {}
AFCombat.S.CombatGroupCache = {}
AFCombat.S.CombatBladeCache = {}

AFCombat.S.LastDirectPathCheckTime = 0
AFCombat.S.LastDirectPathTarget = nil
AFCombat.S.LastDirectPathPosition = nil
AFCombat.S.LastDirectPathBlocked = false

AFFeature.S.LastDeadzoneEscapeTime = 0

--// Debug Visualizer
AFCombatUtils.S.DebugFolder = nil
AFDebug.S.DebugWaypointData = {}
AFDebug.S.DebugFarmZone = nil
AFDebug.S.DebugDeadzone = nil
AFDebug.S.DebugZoneSignature = nil
AFDebug.S.DebugWaypointSignature = nil

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
AFFeature.S.BlockValue = nil

AFFeature.S.WaypointEnabled = true
AFFeature.S.Enabled = true
AFFeature.S.Equipped = false
AFUI.S.TargetCurrency = "Golden Shell"
AFUI.S.LastInventory = nil
AFUI.S.EventCurrency = 0

AFFeature.S.BlockCache = {}
AFFeature.S.BlockEnabled = true
AFCombat.S.SafeCombatPositionEnabled = true


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

AFFeature.S.StaminaConnection = nil
AFFeature.S.BoosterConnections = {}



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





--// Live status labels

--// Detected Entity List
AFCombat.S.DetectedEntities = {}

--// Priority component

UIRef.WhitelistPlayerOptions = {}

--// Keep Utils priority actions synchronized with the farm state and target dropdown.

--//==============================================================
--// Profile Settings
--//==============================================================





--// Mob Watcher
AFCombat.S.MobConnections = {}
AFCombat.S.MobFolderConnections = {}


--======================================================================
--// SECTION 2  ::  LAYERS
--// Function definitions only. No layer runs anything at load time.
--======================================================================


------------------------------------------------------------------------
--// AFConfig
--//
--// place presets and config normalisation
--//
--// 2 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------

------------------------------------------------------------------------
--// AFConfig  ::  place presets and CONFIG normalisation
--// 2 function(s)
------------------------------------------------------------------------
function AFConfig.IsValidPlace(id: number)
	if PLACE_CONFIG[id] then
		return PLACE_CONFIG[id]
	end
	return false
end

function AFConfig.NormalizePlaceConfig(Config)
	Config = Config or {}

	local Waypoints = AFConfig.CloneVectorList(Config.WAYPOINTS)
	local FarmZones = AFConfig.CloneZoneList(Config.FARM_ZONES)
	local Deadzones = AFConfig.CloneZoneList(Config.DEADZONES)

	--// Backwards compatibility with the existing place_config format.
	if #FarmZones == 0 and Config.FARM_CENTER then
		table.insert(FarmZones, {
			Center = AFConfig.DecodeVector3(Config.FARM_CENTER),
			Radius = math.max(0, tonumber(Config.FARM_RADIUS) or 0),
		})
	end

	if #Deadzones == 0 and Config.FARM_DEADZONE_CENTER then
		local Radius = tonumber(Config.FARM_DEADZONE_RADIUS) or 0

		if Radius > 0 then
			table.insert(Deadzones, {
				Center = AFConfig.DecodeVector3(Config.FARM_DEADZONE_CENTER),
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

function AFConfig.EncodeVector3(Value)
	if typeof(Value) ~= "Vector3" then
		return { X = 0, Y = 0, Z = 0 }
	end

	return {
		X = Value.X,
		Y = Value.Y,
		Z = Value.Z,
	}
end

function AFConfig.DecodeVector3(Value)
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

function AFConfig.CloneVectorList(List)
	local Result = {}

	for _, Value in ipairs(List or {}) do
		table.insert(Result, AFConfig.DecodeVector3(Value))
	end

	return Result
end

function AFConfig.CloneZoneList(List)
	local Result = {}

	for _, Zone in ipairs(List or {}) do
		if type(Zone) == "table" and Zone.Center then
			table.insert(Result, {
				Center = AFConfig.DecodeVector3(Zone.Center),
				Radius = math.max(0, tonumber(Zone.Radius) or 0),
			})
		end
	end

	return Result
end

function AFConfig.SerializeVectorList(List)
	local Result = {}

	for _, Value in ipairs(List or {}) do
		table.insert(Result, AFConfig.EncodeVector3(Value))
	end

	return Result
end

function AFConfig.SerializeZoneList(List)
	local Result = {}

	for _, Zone in ipairs(List or {}) do
		if Zone and Zone.Center then
			table.insert(Result, {
				Center = AFConfig.EncodeVector3(Zone.Center),
				Radius = tonumber(Zone.Radius) or 0,
			})
		end
	end

	return Result
end
------------------------------------------------------------------------
--// AFProfile
--//
--// profile serialise, file IO, import and export
--//
--// 32 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------

------------------------------------------------------------------------
--// AFStorage  ::  profile serialise / file IO / import / export
--// 32 function(s)
------------------------------------------------------------------------
------------------------------------------------------------------------
--// AFProfile
--//
--// profile serialise, file IO, import and export
--//
--// 32 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------
------------------------------------------------------------------------
--// AFStorage  ::  profile serialise / file IO / import / export
--// 32 function(s)
------------------------------------------------------------------------
function AFProfile.CanUseFileStorage()
	return type(readfile) == "function"
		and type(writefile) == "function"
		and type(isfile) == "function"
end

function AFProfile.EnsureProfileFolder()
	if type(makefolder) ~= "function" then
		return
	end

	pcall(function()
		makefolder(PROFILE_FOLDER)
	end)
end

function AFProfile.SerializeConfigValue(Value)
	if typeof(Value) == "Vector3" then
		return AFConfig.EncodeVector3(Value)
	end

	if type(Value) ~= "table" then
		return Value
	end

	local Result = {}
	for Key, Item in pairs(Value) do
		Result[Key] = AFProfile.SerializeConfigValue(Item)
	end
	return Result
end

function AFProfile.DeserializeConfigValue(Value)
	if type(Value) ~= "table" then
		return Value
	end

	if Value.X ~= nil and Value.Y ~= nil and Value.Z ~= nil
		and type(Value.X) == "number"
		and type(Value.Y) == "number"
		and type(Value.Z) == "number"
	then
		return AFConfig.DecodeVector3(Value)
	end

	local Result = {}
	for Key, Item in pairs(Value) do
		Result[Key] = AFProfile.DeserializeConfigValue(Item)
	end
	return Result
end

function AFProfile.MergeConfig(Base, Override)
	local Result = {}

	for Key, Value in pairs(Base or {}) do
		Result[Key] = AFProfile.DeserializeConfigValue(AFProfile.SerializeConfigValue(Value))
	end

	for Key, Value in pairs(Override or {}) do
		if type(Value) == "table" and type(Result[Key]) == "table" then
			Result[Key] = AFProfile.MergeConfig(Result[Key], Value)
		else
			Result[Key] = AFProfile.DeserializeConfigValue(Value)
		end
	end

	return Result
end

function AFProfile.BuildDefaultProfile()
	return {
		Name = "",
		PlaceId = game.PlaceId,
		--// Keep the complete place_config/default config inside the profile.
		PLACE_CONFIG = AFProfile.SerializeConfigValue(BasePlaceConfig),
		WAYPOINTS = AFConfig.CloneVectorList(BasePlaceConfig.WAYPOINTS),
		FARM_ZONES = AFConfig.CloneZoneList(BasePlaceConfig.FARM_ZONES),
		DEADZONES = AFConfig.CloneZoneList(BasePlaceConfig.DEADZONES),
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

function AFProfile.ReadProfileStore()
	if not AFProfile.CanUseFileStorage() then
		return {
			Profiles = {},
			LastUsed = nil,
		}
	end

	AFProfile.EnsureProfileFolder()

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

function AFProfile.WriteProfileStore()
	if not AFProfile.CanUseFileStorage() then
		return false
	end

	AFProfile.EnsureProfileFolder()

	local Success, Raw = pcall(function()
		return HttpService:JSONEncode(AFProfile.S.ProfileStore)
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

function AFProfile.CaptureFeatureState()
	local Result = {
		AutoFarm = AFFeature.S.Enabled,
	}

	for Name, Data in pairs(Feature) do
		if type(Data) == "table" and type(Data.Enabled) == "boolean" then
			Result[Name] = Data.Enabled
		end
	end

	return Result
end

function AFProfile.ApplyFeatureState(State)
	if type(State) ~= "table" then
		return
	end

	if type(State.AutoFarm) == "boolean" then
		AFFeature.S.Enabled = State.AutoFarm
	end

	for Name, Data in pairs(Feature) do
		if type(Data) == "table"
			and type(State[Name]) == "boolean"
		then
			Data.Enabled = State[Name]
		end
	end

	if type(State.AutoBlock) == "boolean" then
		AFFeature.S.BlockEnabled = State.AutoBlock
	end

	if type(State.SafeCombat) == "boolean" then
		AFCombat.S.SafeCombatPositionEnabled = State.SafeCombat
	end

	if type(State.AutoFind) == "boolean" then
		AFFeature.S.WaypointEnabled = not State.AutoFind
	end
end

function AFProfile.CaptureCurrentProfile(Name)
	local FarmConfig = AFConfig.NormalizePlaceConfig(PlaceConfig)

	return {
		Name = Name or AFProfile.S.ActiveProfileName or "",
		PlaceId = game.PlaceId,
		PLACE_CONFIG = AFProfile.SerializeConfigValue(FarmConfig),
		WAYPOINTS = AFConfig.SerializeVectorList(FarmConfig.WAYPOINTS),
		FARM_ZONES = AFConfig.SerializeZoneList(FarmConfig.FARM_ZONES),
		DEADZONES = AFConfig.SerializeZoneList(FarmConfig.DEADZONES),
		DEFAULT_TARGET_PRIORITY = table.clone(CONFIG.TARGET_ENTITY_PRIORITY or {}),
		FEATURES = AFProfile.CaptureFeatureState(),
		SETTINGS = {
			REACH_DISTANCE = tonumber(FarmConfig.REACH_DISTANCE) or 5,
			AUTOBLOCK = AFFeature.S.BlockEnabled == true,
			RETREAT_HEALTH_PERCENT = math.clamp(tonumber(CONFIG.RETREAT_HEALTH_PERCENT) or 40, 30, 80),
			AUTO_HEAL_HEALTH_PERCENT = math.clamp(tonumber(CONFIG.AUTO_HEAL_HEALTH_PERCENT) or 65, 30, 80),
			SAFE_ENEMY_RANGE = math.clamp(tonumber(CONFIG.SAFE_ENEMY_RANGE) or 4, 0, 30),
			TARGET_HP_MODE = tostring(CONFIG.TARGET_HP_MODE or "Disabled"),
			EXECUTE_CHARGE_HP_PERCENT = math.clamp(tonumber(CONFIG.EXECUTE_CHARGE_HP_PERCENT) or 0, 0, 90),
			--// Read from the panel when it exists, so a drag or a pop out is
			--// captured without the panel having to announce every change.
			PINNED_STATE = UIRef.PinPanel
				and UIRef.PinPanel:GetState()
				or CONFIG.PINNED_STATE,
			BLOCK_WHITELIST = table.clone(CONFIG.BLOCK_WHITELIST or {}),
		},
	}
end

function AFProfile.AreSerializedValuesEqual(A, B)
	local TypeA = type(A)
	local TypeB = type(B)

	if TypeA ~= TypeB then
		return false
	end

	if TypeA ~= "table" then
		return A == B
	end

	for Key, Value in pairs(A) do
		if not AFProfile.AreSerializedValuesEqual(Value, B[Key]) then
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

function AFProfile.IsArrayTable(Value)
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

function AFProfile.BuildCompactConfig(Base, Current)
	local BaseData = AFProfile.SerializeConfigValue(Base or {})
	local CurrentData = AFProfile.SerializeConfigValue(Current or {})

	local function Diff(BaseValue, CurrentValue)
		if type(CurrentValue) ~= "table" then
			if AFProfile.AreSerializedValuesEqual(BaseValue, CurrentValue) then
				return nil
			end
			return CurrentValue
		end

		if AFProfile.IsArrayTable(CurrentValue) or AFProfile.IsArrayTable(BaseValue) then
			if AFProfile.AreSerializedValuesEqual(BaseValue, CurrentValue) then
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

function AFProfile.BuildCompactProfile(Name)
	local Full = AFProfile.CaptureCurrentProfile(Name)
	local BasePriority = BasePlaceConfig.DEFAULT_TARGET_PRIORITY
		or CONFIG.TARGET_ENTITY_PRIORITY
		or {}

	local Compact = {
		n = Full.Name,
		p = Full.PlaceId,
		c = AFProfile.BuildCompactConfig(BasePlaceConfig, PlaceConfig),
		s = Full.SETTINGS,
	}

	if not AFProfile.AreSerializedValuesEqual(Full.DEFAULT_TARGET_PRIORITY, BasePriority) then
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

function AFProfile.ExpandCompactProfile(Data)
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

		local Config = AFProfile.DeserializeConfigValue(Data.c or {})
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

function AFProfile.ExportActiveProfile()
	if not AFProfile.S.ActiveProfileName then
		return false, "EXPORT FAILED: No active profile"
	end

	if type(setclipboard) ~= "function" then
		return false, "EXPORT FAILED: setclipboard is unavailable"
	end

	local ExportData = AFProfile.BuildCompactProfile(AFProfile.S.ActiveProfileName)
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

function AFProfile.ImportProfileFromText(Raw)
	if type(Raw) ~= "string" or Raw == "" then
		return false, "IMPORT FAILED: Import textbox is empty"
	end

	local DecodeSuccess, Data = pcall(function()
		return HttpService:JSONDecode(Raw)
	end)

	if not DecodeSuccess or type(Data) ~= "table" then
		return false, "IMPORT FAILED: Invalid JSON"
	end

	local ExpandedData, ExpandError = AFProfile.ExpandCompactProfile(Data)
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
	while AFProfile.S.ProfileStore.Profiles[Name] do
		Name = BaseName .. " " .. tostring(Suffix)
		Suffix += 1
	end

	ExpandedData.Name = Name
	ExpandedData.PlaceId = game.PlaceId
	AFProfile.S.ProfileStore.Profiles[Name] = ExpandedData
	AFProfile.S.ProfileStore.LastUsed = Name

	if not AFProfile.WriteProfileStore() then
		AFProfile.S.ProfileStore.Profiles[Name] = nil
		return false, "IMPORT FAILED: Could not save profile"
	end

	if not AFProfile.LoadProfile(Name) then
		return false, "IMPORT FAILED: Could not load profile"
	end

	return true, Name
end

function AFProfile.SaveActiveProfile()
	if not AFProfile.S.ActiveProfileName then
		return false
	end

	AFProfile.S.ProfileData = AFProfile.CaptureCurrentProfile(AFProfile.S.ActiveProfileName)
	AFProfile.S.ProfileStore.Profiles[AFProfile.S.ActiveProfileName] = AFProfile.S.ProfileData
	AFProfile.S.ProfileStore.LastUsed = AFProfile.S.ActiveProfileName

	return AFProfile.WriteProfileStore()
end

--// Sliders fire their callback on every step of a drag. Saving straight to
--// disk from there means dozens of writefile calls for one gesture, so
--// continuous controls queue a save instead of performing one.
function AFProfile.QueueProfileSave()
	if not AFProfile.S.ActiveProfileName or AFProfile.S.ProfileSaveQueued then
		return
	end

	AFProfile.S.ProfileSaveQueued = true

	task.delay(CONFIG.PROFILE_SAVE_DEBOUNCE, function()
		AFProfile.S.ProfileSaveQueued = false
		AFProfile.SaveActiveProfile()
	end)
end

function AFProfile.ApplyProfileData(Data)
	if type(Data) ~= "table" then
		return false
	end

	local StoredPlaceConfig = AFProfile.DeserializeConfigValue(Data.PLACE_CONFIG)
	local FarmConfig = AFProfile.MergeConfig(BasePlaceConfig, StoredPlaceConfig)

	--// Backwards compatibility for profiles created before PLACE_CONFIG existed.
	FarmConfig.WAYPOINTS = AFConfig.CloneVectorList(Data.WAYPOINTS or FarmConfig.WAYPOINTS)
	FarmConfig.FARM_ZONES = AFConfig.CloneZoneList(Data.FARM_ZONES or FarmConfig.FARM_ZONES)
	FarmConfig.DEADZONES = AFConfig.CloneZoneList(Data.DEADZONES or FarmConfig.DEADZONES)
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

	--// Anything unrecognised falls back to Disabled rather than leaving the
	--// selector showing a mode the code does not implement.
	local StoredMode = Data.SETTINGS and Data.SETTINGS.TARGET_HP_MODE

	if StoredMode == "Highest HP" or StoredMode == "Lowest HP" then
		CONFIG.TARGET_HP_MODE = StoredMode
	else
		CONFIG.TARGET_HP_MODE = "Disabled"
	end

	CONFIG.EXECUTE_CHARGE_HP_PERCENT = math.clamp(
		type(Data.SETTINGS and Data.SETTINGS.EXECUTE_CHARGE_HP_PERCENT) == "number"
			and Data.SETTINGS.EXECUTE_CHARGE_HP_PERCENT
			or 0,
		0,
		90
	)

	local StoredPinned = Data.SETTINGS and Data.SETTINGS.PINNED_STATE

	if type(StoredPinned) == "table" then
		CONFIG.PINNED_STATE = {
			Items = type(StoredPinned.Items) == "table" and StoredPinned.Items or {},
			Floating = StoredPinned.Floating == true,
			X = tonumber(StoredPinned.X),
			Y = tonumber(StoredPinned.Y),
		}
	else
		CONFIG.PINNED_STATE = {}
	end

	local StoredWhitelist = Data.SETTINGS and Data.SETTINGS.BLOCK_WHITELIST
	local Whitelist = {}

	if type(StoredWhitelist) == "table" then
		for _, Entry in ipairs(StoredWhitelist) do
			local Id = AFFeature.NormalizeUserId(Entry)

			if Id then
				table.insert(Whitelist, Id)
			end
		end
	end

	CONFIG.BLOCK_WHITELIST = Whitelist

	PlaceConfig = AFConfig.NormalizePlaceConfig(FarmConfig)

	CONFIG.TARGET_ENTITY_PRIORITY = table.clone(
		Data.DEFAULT_TARGET_PRIORITY
			or BasePlaceConfig.DEFAULT_TARGET_PRIORITY
			or {}
	)

	Feature.AutoBlock.Enabled = PlaceConfig.AUTOBLOCK
	AFFeature.S.BlockEnabled = PlaceConfig.AUTOBLOCK

	AFProfile.ApplyFeatureState(Data.FEATURES)

	CONFIG.CURRENT_WAYPOINT_TARGET = 1
	AFCombat.ResetTargetReposition()
	AFFeature.S.DeadzoneEscapePosition = nil
	PatrolState.PatrolPosition = nil
	AFFeature.S.FarmReturnPosition = nil
	AFProfile.S.SelectedFarmZoneIndex = 1
	AFProfile.S.SelectedDeadzoneIndex = 1
	PatrolState.LastPatrolCalculateTime = 0
	AFFeature.S.LastFarmReturnCalculateTime = 0

	return true
end

function AFProfile.LoadProfile(Name)
	local Data = AFProfile.S.ProfileStore.Profiles[Name]

	if type(Data) ~= "table" then
		return false
	end

	if AFProfile.ApplyProfileData(Data) then
		AFProfile.S.ActiveProfileName = Name
		AFProfile.S.ProfileData = Data
		AFProfile.S.ProfileStore.LastUsed = Name
		AFProfile.WriteProfileStore()
		return true
	end

	return false
end

function AFProfile.DeleteProfile(Name)
	if not Name or not AFProfile.S.ProfileStore.Profiles[Name] then
		return false
	end

	AFProfile.S.ProfileStore.Profiles[Name] = nil

	if AFProfile.S.ProfileStore.LastUsed == Name then
		AFProfile.S.ProfileStore.LastUsed = nil
	end

	if AFProfile.S.ActiveProfileName == Name then
		AFProfile.S.ActiveProfileName = nil
		AFProfile.S.ProfileData = nil
		PlaceConfig = AFConfig.NormalizePlaceConfig(AFConfig.IsValidPlace(game.PlaceId) or {})
		CONFIG.TARGET_ENTITY_PRIORITY = table.clone(
			BasePlaceConfig.DEFAULT_TARGET_PRIORITY
				or {}
		)
		Feature.AutoBlock.Enabled = BasePlaceConfig.AUTOBLOCK == true
		AFFeature.S.BlockEnabled = BasePlaceConfig.AUTOBLOCK == true
		CONFIG.CURRENT_WAYPOINT_TARGET = 1
	end

	AFProfile.WriteProfileStore()
	return true
end

function AFProfile.CreateProfile(Name)
	Name = tostring(Name or ""):gsub("^%s+", ""):gsub("%s+$", "")

	if Name == "" or #Name > 32 then
		return false, "Invalid profile name"
	end

	if Name:find("[/\\:%*%?\"<>|]") then
		return false, "Invalid profile name"
	end

	if AFProfile.S.ProfileStore.Profiles[Name] then
		return false, "Profile already exists"
	end

	AFProfile.S.ActiveProfileName = Name
	AFProfile.S.ProfileData = AFProfile.BuildDefaultProfile()
	AFProfile.S.ProfileData.Name = Name

	AFProfile.ApplyProfileData(AFProfile.S.ProfileData)

	AFProfile.S.ProfileStore.Profiles[Name] = AFProfile.CaptureCurrentProfile(Name)
	AFProfile.S.ProfileStore.LastUsed = Name
	AFProfile.WriteProfileStore()

	return true
end

function AFProfile.GetProfileNames()
	local Names = {}

	for Name in pairs(AFProfile.S.ProfileStore.Profiles) do
		table.insert(Names, Name)
	end

	table.sort(Names, function(A, B)
		return string.lower(A) < string.lower(B)
	end)

	return Names
end

function AFProfile.ApplyDefaultPlaceConfig()
	AFProfile.S.ActiveProfileName = nil
	AFProfile.S.ProfileData = nil

	--// Never create a fake Vector3.zero farm zone. If the place config
	--// has no zones, NormalizePlaceConfig keeps the lists empty.
	PlaceConfig = AFConfig.NormalizePlaceConfig(AFProfile.DeserializeConfigValue(AFProfile.SerializeConfigValue(BasePlaceConfig)))

	CONFIG.TARGET_ENTITY_PRIORITY = table.clone(
		BasePlaceConfig.DEFAULT_TARGET_PRIORITY
			or {}
	)

	Feature.AutoBlock.Enabled = BasePlaceConfig.AUTOBLOCK == true
	AFFeature.S.BlockEnabled = BasePlaceConfig.AUTOBLOCK == true
	CONFIG.CURRENT_WAYPOINT_TARGET = 1
	CONFIG.RETREAT_HEALTH_PERCENT = 40
	CONFIG.AUTO_HEAL_HEALTH_PERCENT = 65
	CONFIG.SAFE_ENEMY_RANGE = 4
	CONFIG.TARGET_HP_MODE = "Disabled"
	CONFIG.BLOCK_WHITELIST = {}
	CONFIG.EXECUTE_CHARGE_HP_PERCENT = 0
	CONFIG.PINNED_STATE = {}

	AFCombat.ResetTargetReposition()
	AFFeature.S.DeadzoneEscapePosition = nil
	PatrolState.PatrolPosition = nil
	AFFeature.S.FarmReturnPosition = nil
	PatrolState.LastPatrolCalculateTime = 0
	AFFeature.S.LastFarmReturnCalculateTime = 0

	return true
end
------------------------------------------------------------------------
--// AFCombatUtils
--//
--// geometry, world queries, blade maths, movement primitives
--//
--// 29 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------

--// Real stuck detection: barely moving while actively trying to move. Two
--// consecutive samples so a single frame against a corner does not count.
------------------------------------------------------------------------
--// AFCombatUtils
--//
--// geometry, world queries, blade maths, movement primitives
--//
--// 29 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------
--// Real stuck detection: barely moving while actively trying to move. Two
--// consecutive samples so a single frame against a corner does not count.
------------------------------------------------------------------------
--// AFCombatUtils
--//
--// geometry, world queries, blade maths, movement primitives
--//
--// 29 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------
--// Real stuck detection: barely moving while actively trying to move. Two
--// consecutive samples so a single frame against a corner does not count.
------------------------------------------------------------------------
--// AFCombatUtils
--//
--// geometry, world queries, blade maths, movement primitives
--//
--// 29 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------
--// Real stuck detection: barely moving while actively trying to move. Two
--// consecutive samples so a single frame against a corner does not count.
function AFCombatUtils.UpdateStuckTracker(now, IsMoving)
	if not RootPart then
		return
	end

	if not IsMoving then
		AFCombatUtils.S.StuckSamplePosition = nil
		AFCombatUtils.S.StuckStrikes = 0
		return
	end

	if now - AFCombatUtils.S.StuckSampleTime < (tonumber(CONFIG.STUCK_SAMPLE_INTERVAL) or 0.35) then
		return
	end

	AFCombatUtils.S.StuckSampleTime = now

	if AFCombatUtils.S.StuckSamplePosition then
		local Moved = (RootPart.Position - AFCombatUtils.S.StuckSamplePosition).Magnitude

		if Moved < (tonumber(CONFIG.STUCK_MIN_PROGRESS) or 0.6) then
			AFCombatUtils.S.StuckStrikes += 1
		else
			AFCombatUtils.S.StuckStrikes = 0
		end
	end

	AFCombatUtils.S.StuckSamplePosition = RootPart.Position
end

function AFCombatUtils.IsStuck()
	return AFCombatUtils.S.StuckStrikes >= 2
end

function AFCombatUtils.DoJumpIfObstacle(TargetPosition)
	if not Humanoid then
		return false
	end

	if not AFCombatUtils.IsJumpableObstacleAhead(TargetPosition) then
		return false
	end

	AFCombatUtils.DoJump()
	return true
end

function AFCombatUtils.DoJump()
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

------------------------------------------------------------------------
--// AFWorld  ::  zones, water, ground, line of sight, path clearance
--// 12 function(s)
------------------------------------------------------------------------
--// Farm Area Check
--// Shared cylinder test for farm zones and deadzones.
function AFCombatUtils.IsPositionInsideZone(Position, Zone)
	if not Position or not Zone or not Zone.Center then
		return false
	end

	local Offset = Position - Zone.Center
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if Distance > (tonumber(Zone.Radius) or 0) then
		return false
	end

	local MaxHeight = tonumber(CONFIG.ZONE_MAX_HEIGHT_DIFFERENCE) or 0

	if MaxHeight > 0 and math.abs(Offset.Y) > MaxHeight then
		return false
	end

	return true
end

function AFCombatUtils.IsInsideFarmDeadzone(Position)
	if not Position or not PlaceConfig then
		return false
	end

	for _, Zone in ipairs(PlaceConfig.DEADZONES or {}) do
		if AFCombatUtils.IsPositionInsideZone(Position, Zone) then
			return true
		end
	end

	return false
end

function AFCombatUtils.IsInsideFarmArea(Position)
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
		return not AFCombatUtils.IsInsideFarmDeadzone(Position)
	end

	local InsideAnyFarmZone = false

	for _, Zone in ipairs(FarmZones) do
		if AFCombatUtils.IsPositionInsideZone(Position, Zone) then
			InsideAnyFarmZone = true
			break
		end
	end

	if not InsideAnyFarmZone then
		return false
	end

	return not AFCombatUtils.IsInsideFarmDeadzone(Position)
end

--// Water Check
function AFCombatUtils.IsWaterAtPosition(Position, IgnoreModel)
	if not Position then
		return false
	end

	local FilterInstances = {
		Character,
	}

	if IgnoreModel then
		table.insert(FilterInstances, IgnoreModel)
	end
	if AFCombatUtils.S.DebugFolder then
		table.insert(FilterInstances, AFCombatUtils.S.DebugFolder)
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = FilterInstances

	local Origin    = Position + Vector3.new(0, 10, 0)
	local Direction = Vector3.new(0, -30, 0)

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result and Result.Material == Enum.Material.Water
end

function AFCombatUtils.IsPathThroughWater(TargetPosition)
	if not RootPart then
		return true
	end

	local Origin   = RootPart.Position
	local Offset   = TargetPosition - Origin
	local Distance = Offset.Magnitude

	if Distance <= 0 then
		return AFCombatUtils.IsWaterAtPosition(TargetPosition)
	end

	local Direction = Offset.Unit

	for DistanceTravelled = 0, Distance, CONFIG.WATER_SAMPLE_DISTANCE do
		local Position = Origin + Direction * DistanceTravelled

		if AFCombatUtils.IsWaterAtPosition(Position) then
			return true
		end
	end

	return AFCombatUtils.IsWaterAtPosition(TargetPosition)
end

--// Deadzone Path Check
function AFCombatUtils.IsPathThroughDeadzone(TargetPosition)
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
		return AFCombatUtils.IsInsideFarmDeadzone(Origin)
	end

	local Direction = Offset.Unit

	for DistanceTravelled = 0, Distance, CONFIG.DEADZONE_SAMPLE_DISTANCE do
		local Position = Origin + Direction * DistanceTravelled

		if AFCombatUtils.IsInsideFarmDeadzone(Position) then
			return true
		end
	end

	return AFCombatUtils.IsInsideFarmDeadzone(TargetPosition)
end

--// Line Of Sight
function AFCombatUtils.CanSeeGoblin(Goblin)
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
	if AFCombatUtils.S.DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, AFCombatUtils.S.DebugFolder)
	end

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	if not Result then
		return true
	end

	return Result.Instance:IsDescendantOf(Goblin)
end

--// ============================================================
--// COMBAT BLADE SYSTEM
--// ============================================================
function AFCombatUtils.GetHorizontalDistance(PositionA, PositionB)
	local Offset = PositionA - PositionB

	return Vector3.new(
		Offset.X,
		0,
		Offset.Z
	).Magnitude
end

--// Retreat Obstacle Check
function AFCombatUtils.IsPathClear(TargetPosition)
	if not RootPart then
		return false
	end

	if AFCombatUtils.IsWaterAtPosition(TargetPosition) then
		return false
	end

	if AFCombatUtils.IsPathThroughWater(TargetPosition) then
		return false
	end

	if AFCombatUtils.IsPathThroughDeadzone(TargetPosition) then
		return false
	end

	local Origin    = RootPart.Position
	local Direction = TargetPosition - Origin

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {
		Character,
	}
	if AFCombatUtils.S.DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, AFCombatUtils.S.DebugFolder)
	end

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result == nil
end

function AFCombatUtils.IsEscapePathClear(TargetPosition)
	if not RootPart or not TargetPosition then
		return false
	end

	if not AFCombatUtils.IsInsideFarmArea(TargetPosition) then
		return false
	end

	if AFCombatUtils.IsWaterAtPosition(TargetPosition) then
		return false
	end

	if AFCombatUtils.IsPathThroughWater(TargetPosition) then
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
	if AFCombatUtils.S.DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, AFCombatUtils.S.DebugFolder)
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

function AFCombatUtils.CanSeeGoblinFromPosition(Position, Goblin)
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
	if AFCombatUtils.S.DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, AFCombatUtils.S.DebugFolder)
	end

	local Result = workspace:Raycast(Position, Direction, RaycastParams)

	return Result == nil
end

--// ============================================================
--// AUTO PATROL
--// ============================================================
--// True when something in the way can actually be jumped over.
--//
--// Two probes at different heights: a hit low down with clear space above it
--// is a ledge, a step or a rock, and a jump clears it. A hit at both heights
--// is a wall, where jumping achieves nothing. Nothing at either height means
--// the path is open and there is no reason to leave the ground.
--//
--// Also treats ground that steps up sharply just ahead as jumpable, since a
--// short ledge can sit below the low probe.
function AFCombatUtils.IsJumpableObstacleAhead(TargetPosition)
	if not RootPart or not TargetPosition then
		return false
	end

	local Origin = RootPart.Position
	local Offset = TargetPosition - Origin
	local Flat = Vector3.new(Offset.X, 0, Offset.Z)

	if Flat.Magnitude <= 0.01 then
		return false
	end

	local Direction = Flat.Unit * (tonumber(CONFIG.JUMP_PROBE_DISTANCE) or 4.5)

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	local Filter = { Character }

	--// Mobs and other players are not obstacles to jump over.
	local MobFolder = workspace:FindFirstChild("Mobs")
	if MobFolder then
		table.insert(Filter, MobFolder)
	end
	for _, OtherPlayer in ipairs(Players:GetPlayers()) do
		if OtherPlayer.Character and OtherPlayer.Character ~= Character then
			table.insert(Filter, OtherPlayer.Character)
		end
	end
	if AFCombatUtils.S.DebugFolder then
		table.insert(Filter, AFCombatUtils.S.DebugFolder)
	end
	Params.FilterDescendantsInstances = Filter

	local HalfHeight = RootPart.Size.Y * 0.5
	local Feet = Origin - Vector3.new(0, HalfHeight, 0)

	local LowOrigin = Feet + Vector3.new(0, tonumber(CONFIG.JUMP_PROBE_LOW_OFFSET) or 0.6, 0)
	local HighOrigin = Feet + Vector3.new(0, tonumber(CONFIG.JUMP_PROBE_HIGH_OFFSET) or 3.2, 0)

	local LowHit = workspace:Raycast(LowOrigin, Direction, Params)
	local HighHit = workspace:Raycast(HighOrigin, Direction, Params)

	if LowHit and not HighHit then
		return true
	end

	if LowHit and HighHit then
		--// Solid from the ground up. Jumping will not get us past it.
		return false
	end

	--// Nothing hit either probe. Check for a step up that both probes passed
	--// over, by sampling the ground a little way ahead.
	local AheadOrigin = Origin + Flat.Unit * (tonumber(CONFIG.JUMP_PROBE_DISTANCE) or 4.5)
	local Down = workspace:Raycast(
		AheadOrigin + Vector3.new(0, HalfHeight, 0),
		Vector3.new(0, -(HalfHeight * 2 + 6), 0),
		Params
	)

	if not Down then
		return false
	end

	local StepUp = Down.Position.Y - Feet.Y

	return StepUp >= (tonumber(CONFIG.JUMP_STEP_HEIGHT) or 1.2)
end

function AFCombatUtils.GetPatrolGroundPosition(Position)
	if not Position or not RootPart then
		return nil
	end

	if not AFCombatUtils.IsInsideFarmArea(Position) then
		return nil
	end

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = {Character}
	if AFCombatUtils.S.DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, AFCombatUtils.S.DebugFolder)
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

	if AFCombatUtils.IsWaterAtPosition(GroundPosition)
		or AFCombatUtils.IsInsideFarmDeadzone(GroundPosition)
	then
		return nil
	end

	return GroundPosition
end

function AFCombatUtils.GetMobDistance(Mob)
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

function AFCombatUtils.GetMobHealth(Mob)
	local MobHumanoid = Mob and Mob:FindFirstChildOfClass("Humanoid")

	if not MobHumanoid then
		return 0
	end

	return MobHumanoid.Health
end

------------------------------------------------------------------------
--// AFBlade  ::  enemy weapon hitboxes and danger geometry
--// 8 function(s)
------------------------------------------------------------------------
--// Get every BladePart inside one Mob.
function AFCombatUtils.GetBladeParts(Mob)
	if not Mob then
		return {}
	end

	local now = os.clock()
	local Cached = AFCombatUtils.S.BladePartCache[Mob]

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

	AFCombatUtils.S.BladePartCache[Mob] = {
		Time  = now,
		Parts = BladeParts,
	}

	return BladeParts
end

--// Finds the closest point on an actual BladePart box.
--// This is much more accurate than simply using BladePart.Position.
function AFCombatUtils.GetClosestPointOnBlade(BladePart, Position)
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

function AFCombatUtils.GetBladeDangerDistance()
	return CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + CONFIG.ENEMY_BLADE_PADDING
end

--// Walks a computed path toward a destination. Used when the straight line
--// is blocked: the farm zone return had no pathfinding at all, so a wall or
--// a ledge between the character and the zone left it walking into geometry.
function AFCombatUtils.MoveAlongPathTo(Destination, AllowOutsideFarmArea)
	if not RootPart or not Humanoid or not Destination then
		return false
	end

	local Path = PathfindingService:CreatePath({
		AgentRadius     = math.max(RootPart.Size.X * 0.5, 2),
		AgentHeight     = math.max(RootPart.Size.Y, 5),
		AgentCanJump    = true,
		WaypointSpacing = 4,
	})

	local Success = pcall(function()
		Path:ComputeAsync(RootPart.Position, Destination)
	end)

	if not Success or Path.Status ~= Enum.PathStatus.Success then
		return false
	end

	local Waypoints = Path:GetWaypoints()

	if #Waypoints < 2 then
		return false
	end

	for Index = 2, #Waypoints do
		local Waypoint = Waypoints[Index]

		--// Returning to the zone starts outside it by definition, so that
		--// caller opts out of the containment check.
		if not AllowOutsideFarmArea
			and not AFCombatUtils.IsInsideFarmArea(Waypoint.Position)
		then
			return false
		end

		if AFCombatUtils.IsInsideFarmDeadzone(Waypoint.Position) then
			return false
		end
	end

	for Index = 2, #Waypoints do
		local Waypoint = Waypoints[Index]
		local Offset = Waypoint.Position - RootPart.Position
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		if Distance > CONFIG.TARGET_PATH_WAYPOINT_DISTANCE then
			--// The pathfinder marks jumps generously, including on flat ground.
			--// Only take them when something is actually in the way, or when the
			--// character has stopped making progress.
			if Waypoint.Action == Enum.PathWaypointAction.Jump
				and (AFCombatUtils.IsJumpableObstacleAhead(Waypoint.Position) or AFCombatUtils.IsStuck())
			then
				AFCombatUtils.DoJump()
			end

			Humanoid.AutoRotate = true
			Humanoid:MoveTo(Waypoint.Position)
			return true
		end
	end

	return false
end
------------------------------------------------------------------------
--// AFCombat
--//
--// targeting, approach, retreat and attack execution
--//
--// 49 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------

--// Target Reposition
function AFCombat.ResetTargetReposition()
	AFCombat.S.TargetUnreachableSince   = nil
	AFCombat.S.TargetApproachPosition   = nil
	AFCombat.S.TargetApproachMob        = nil
	AFCombat.S.LastTargetRepositionTime = 0
	AFCombat.S.CACHED_SAFECOMBAT_POSITION = nil
	AFCombat.S.CACHED_SAFECOMBAT_TARGET = nil
	AFCombat.S.LastAttackerCombatMob = nil
	AFCombat.S.LastAttackerCombatPosition = nil
	AFCombat.S.LastAttackerCombatSwitchTime = 0
	AFCombat.S.LAST_SAFECOMBAT_TIME = 0
	AFCombat.S.LastDirectPathTarget = nil
	AFCombat.S.LastDirectPathPosition = nil
	AFCombat.S.CombatBladeCache = {}
end

function AFCombat.ResetTargetState()
	AFCombat.S.ClosestTarget = nil
	AFCombat.ClearUnreachableMobs()
	table.clear(AFCombat.S.ValidMobs)
	table.clear(AFCombat.S.CombatGroupCache)
	AFCombat.S.COMBAT_TARGET_LOST_SINCE = nil
	AFCombat.S.COMBAT_TARGET_SCORE = math.huge
	AFCombat.S.LAST_COMBAT_TARGET_CHECK = 0
	AFCombat.S.COMBAT_ATTACK_PHASE = 0
	AFCombat.S.COMBAT_NEXT_ATTACK_TIME = 0
	AFCombat.S.COMBAT_NEXT_SKILL_TIME = 0
	AFCombat.ResetTargetReposition()
end

------------------------------------------------------------------------
--// AFEntity  ::  mob discovery, validation, priority, target selection
--// 15 function(s)
------------------------------------------------------------------------
function AFCombat.GetDetectedEnemyEntities()
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

function AFCombat.IsEntityInPriority(EntityName: string): boolean
	return table.find(CONFIG.TARGET_ENTITY_PRIORITY, EntityName) ~= nil
end

--// Raised whenever the set of mobs, or the entity a mob reports, changes.
--// Nothing here knows who listens; the UI assigns OnMobSetChanged so the
--// picker can rebuild without this module depending on the UI at all.
function AFCombat.NotifyMobSetChanged()
	if AFCombat.OnMobSetChanged then
		AFCombat.OnMobSetChanged()
	end
end

function AFCombat.DisconnectMob(Mob)
	local Connections = AFCombat.S.MobConnections[Mob]

	if not Connections then
		return
	end

	for _, Connection in Connections do
		Connection:Disconnect()
	end

	AFCombat.S.MobConnections[Mob] = nil
	AFCombat.S.UnreachableMobs[Mob] = nil
	AFCombatUtils.S.BladePartCache[Mob] = nil
	AFCombat.S.CombatGroupCache[Mob] = nil
	AFCombat.S.CombatBladeCache[Mob] = nil
end

function AFCombat.WatchMob(Mob)
	if not Mob:IsA("Model") then
		return
	end

	AFCombat.DisconnectMob(Mob)

	local Connections = {}
	AFCombat.S.MobConnections[Mob] = Connections

	local function WatchConfig(Config)
		if not Config then
			return
		end

		local Entity = Config:FindFirstChild("Entity")

		if Entity and Entity:IsA("StringValue") then
			table.insert(Connections, Entity:GetPropertyChangedSignal("Value"):Connect(function()
				AFCombat.NotifyMobSetChanged()

				AFCombat.S.ValidMobs[Mob] = nil

				if AFCombat.S.ClosestTarget == Mob and not AFCombat.IsEntityInPriority(Entity.Value) then
					AFCombat.S.ClosestTarget = nil
				end
			end))
		end

		table.insert(Connections, Config.ChildAdded:Connect(function(Child)
			if Child.Name ~= "Entity" then
				return
			end

			if Child:IsA("StringValue") then
				table.insert(Connections, Child:GetPropertyChangedSignal("Value"):Connect(function()
					AFCombat.NotifyMobSetChanged()
					AFCombat.S.ValidMobs[Mob] = nil

					if AFCombat.S.ClosestTarget == Mob and not AFCombat.IsEntityInPriority(Child.Value) then
						AFCombat.S.ClosestTarget = nil
					end
				end))
			end

			AFCombat.NotifyMobSetChanged()
			AFCombat.S.ValidMobs[Mob] = nil
		end))

		table.insert(Connections, Config.ChildRemoved:Connect(function(Child)
			if Child.Name == "Entity" then
				AFCombat.S.ValidMobs[Mob] = nil

				if AFCombat.S.ClosestTarget == Mob then
					AFCombat.S.ClosestTarget = nil
				end

				AFCombat.NotifyMobSetChanged()
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
			AFCombat.NotifyMobSetChanged()
			AFCombat.S.ValidMobs[Mob] = nil
		end
	end))

	table.insert(Connections, Mob.ChildRemoved:Connect(function(Child)
		if Child.Name == "Config" then
			AFCombat.S.ValidMobs[Mob] = nil

			if AFCombat.S.ClosestTarget == Mob then
				AFCombat.S.ClosestTarget = nil
			end

			AFCombat.NotifyMobSetChanged()
		end
	end))

	AFCombat.NotifyMobSetChanged()
end

function AFCombat.WatchMobFolder(MobFolder)
	for _, Connection in AFCombat.S.MobFolderConnections do
		Connection:Disconnect()
	end

	table.clear(AFCombat.S.MobFolderConnections)

	for Mob in AFCombat.S.MobConnections do
		AFCombat.DisconnectMob(Mob)
	end

	for _, Mob in MobFolder:GetChildren() do
		AFCombat.WatchMob(Mob)
	end

	table.insert(AFCombat.S.MobFolderConnections, MobFolder.ChildAdded:Connect(function(Mob)
		AFCombat.WatchMob(Mob)
		AFCombat.NotifyMobSetChanged()
	end))

	table.insert(AFCombat.S.MobFolderConnections, MobFolder.ChildRemoved:Connect(function(Mob)
		AFCombat.DisconnectMob(Mob)
		AFCombat.S.ValidMobs[Mob] = nil

		if AFCombat.S.ClosestTarget == Mob then
			AFCombat.S.ClosestTarget = nil
		end

		AFCombat.NotifyMobSetChanged()
	end))
end

--// Target Lock Validation
--// Mobs with no route to them are remembered for a while. Dropping the
--// target without this just hands the same unreachable mob straight back on
--// the next selection, which is how the character ends up sprinting at a
--// ledge it cannot climb for as long as the mob lives.
function AFCombat.MarkMobUnreachable(Mob)
	if not Mob then
		return
	end

	AFCombat.S.UnreachableMobs[Mob] = os.clock() + (tonumber(CONFIG.UNREACHABLE_COOLDOWN) or 15)
end

function AFCombat.IsMobUnreachable(Mob)
	local Expiry = AFCombat.S.UnreachableMobs[Mob]

	if not Expiry then
		return false
	end

	if os.clock() >= Expiry then
		AFCombat.S.UnreachableMobs[Mob] = nil
		return false
	end

	return true
end

function AFCombat.ClearUnreachableMobs()
	table.clear(AFCombat.S.UnreachableMobs)
end

function AFCombat.IsTargetLockValid(Mob)
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

	if not AFCombat.IsEntityInPriority(Entity.Value) then
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

	if not AFCombatUtils.IsInsideFarmArea(MobRoot.Position) then
		return false
	end

	if AFCombatUtils.IsWaterAtPosition(MobRoot.Position, Mob) then
		return false
	end

	--// Recently proven to have no route. IsInsideFarmArea above already
	--// rejects anything outside the farm zone or inside a deadzone, unless
	--// Ignore Farm Zone is on.
	if AFCombat.IsMobUnreachable(Mob) then
		return false
	end

	return true
end

--// Validate Mob
--// IsValidMob and IsTargetLockValid applied exactly the same 12 checks.
--// Keeping two copies meant a rule change had to be made twice, so the
--// cache filter now delegates to the single canonical implementation.
function AFCombat.IsValidMob(Mob)
	return AFCombat.IsTargetLockValid(Mob)
end

--// Update Realtime Valid Mob List
function AFCombat.UpdateValidMobs()
	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder or not RootPart then
		table.clear(AFCombat.S.ValidMobs)

		if AFCombat.S.ClosestTarget and not AFCombat.IsTargetLockValid(AFCombat.S.ClosestTarget) then
			AFCombat.S.ClosestTarget = nil
		end

		return
	end

	local CurrentMobs = {}

	for _, Mob in MobFolder:GetChildren() do
		CurrentMobs[Mob] = true

		if AFCombat.IsValidMob(Mob) then
			AFCombat.S.ValidMobs[Mob] = true
		else
			AFCombat.S.ValidMobs[Mob] = nil
		end
	end

	for Mob in AFCombat.S.ValidMobs do
		if not CurrentMobs[Mob] then
			AFCombat.S.ValidMobs[Mob] = nil
		end
	end

	if AFCombat.S.ClosestTarget and not AFCombat.IsTargetLockValid(AFCombat.S.ClosestTarget) then
		AFCombat.S.ClosestTarget = nil
	end
end

--// Closest Visible Goblin
function AFCombat.GetMobPriority(Mob)
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

--// Priority always decides first. Target Type only breaks ties between mobs
--// of the same priority, and "Disabled" leaves that tie to distance, which
--// is the original behaviour.
function AFCombat.IsBetterTarget(Priority, Distance, Health, BestPriority, BestDistance, BestHealth)
	if Priority < BestPriority then
		return true
	end

	if Priority > BestPriority then
		return false
	end

	local Mode = tostring(CONFIG.TARGET_HP_MODE or "Disabled")

	if Mode == "Highest HP" then
		if Health > BestHealth then
			return true
		end

		if Health < BestHealth then
			return false
		end
	elseif Mode == "Lowest HP" then
		if Health < BestHealth then
			return true
		end

		if Health > BestHealth then
			return false
		end
	end

	return Distance < BestDistance
end

function AFCombat.GetClosestGoblin()
	if not RootPart then
		return nil
	end

	local BestTarget   = nil
	local BestPriority = math.huge
	local BestDistance = math.huge
	local BestHealth   = nil

	--// Primary source: realtime validated mob cache.
	for Mob in AFCombat.S.ValidMobs do
		if not AFCombat.IsTargetLockValid(Mob) then
			AFCombat.S.ValidMobs[Mob] = nil
			continue
		end

		local Priority = AFCombat.GetMobPriority(Mob)
		local Distance = AFCombatUtils.GetMobDistance(Mob)
		local Health = AFCombatUtils.GetMobHealth(Mob)

		if Priority
			and (not BestTarget
				or AFCombat.IsBetterTarget(
					Priority, Distance, Health,
					BestPriority, BestDistance, BestHealth or 0
				))
		then
			BestPriority = Priority
			BestDistance = Distance
			BestHealth = Health
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
				if AFCombat.IsTargetLockValid(Mob) then
					local Priority = AFCombat.GetMobPriority(Mob)
					local Distance = AFCombatUtils.GetMobDistance(Mob)
					local Health = AFCombatUtils.GetMobHealth(Mob)

					if Priority
						and (not BestTarget
							or AFCombat.IsBetterTarget(
								Priority, Distance, Health,
								BestPriority, BestDistance, BestHealth or 0
							))
					then
						BestPriority = Priority
						BestDistance = Distance
						BestHealth = Health
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
function AFCombat.GetNearbyThreatMob(TargetMob)
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

	for Mob in AFCombat.S.ValidMobs do
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

function AFCombat.GetThreatEscapePosition(TargetMob, ThreatMob)
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

	local CurrentTargetDistance = AFCombatUtils.GetHorizontalDistance(Origin, TargetRoot.Position)
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

		if not AFCombatUtils.IsInsideFarmArea(Candidate)
			or AFCombatUtils.IsWaterAtPosition(Candidate, TargetMob)
			or AFCombatUtils.IsPathThroughWater(Candidate)
			or AFCombatUtils.IsPathThroughDeadzone(Candidate)
			or AFCombat.IsPathThroughBladeGroupDanger(Candidate, TargetMob)
			or not AFCombatUtils.IsEscapePathClear(Candidate)
		then
			continue
		end

		--// Keep enough space from the threat while avoiding a huge
		--// increase in distance from the primary target.
		local ThreatDistance = AFCombatUtils.GetHorizontalDistance(Candidate, ThreatRoot.Position)
		local TargetDistance = AFCombatUtils.GetHorizontalDistance(Candidate, TargetRoot.Position)

		--// Penalize positions that move much farther from the primary target.
		local TargetDistancePenalty = math.max(0, TargetDistance - CurrentTargetDistance) * 0.35

		--// Prefer directions closer to directly away from the threat.
		local DirectionPenalty = (1 - math.clamp(AwayDirection:Dot(Direction), -1, 1)) * 2

		local Score = TargetDistancePenalty + DirectionPenalty + Index * 0.01

		--// The old build tested THREAT_DETECTION_DISTANCE first and then
		--// ENEMY_ATTACK_SAFE_DISTANCE in an elseif with an identical body.
		--// The first condition is a subset of the second, so only the
		--// smaller threshold ever decided anything.
		if ThreatDistance > CONFIG.ENEMY_ATTACK_SAFE_DISTANCE
			and Score < BestScore
		then
			BestScore = Score
			BestPosition = Candidate
		end
	end

	return BestPosition
end

--// Combat Target Validation
function AFCombat.IsCombatTargetValid(Mob)
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

	if not AFCombat.IsEntityInPriority(Entity.Value) then
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

	return Distance <= CONFIG.COMBAT_ENGAGE_MAX_DISTANCE
end

------------------------------------------------------------------------
--// AFNav  ::  combat positioning, pathfinding, retreat, patrol
--// 26 function(s)
------------------------------------------------------------------------
--// Find a short detour when another player is physically blocking the route.
function AFCombat.GetOtherPlayerDetourPosition(TargetPosition, Goblin)
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
	if AFCombatUtils.S.DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, AFCombatUtils.S.DebugFolder)
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
		local GroundCandidate = AFCombatUtils.GetPatrolGroundPosition(Candidate) or Candidate
		if AFCombatUtils.IsInsideFarmArea(GroundCandidate)
			and not AFCombatUtils.IsInsideFarmDeadzone(GroundCandidate)
			and not AFCombatUtils.IsWaterAtPosition(GroundCandidate, Goblin)
			and not AFCombatUtils.IsPathThroughWater(GroundCandidate)
			and not AFCombatUtils.IsPathThroughDeadzone(GroundCandidate)
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
function AFCombat.IsSafeCombatPathClear(TargetPosition, Goblin)
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

	if AFCombatUtils.S.DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, AFCombatUtils.S.DebugFolder)
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
function AFCombat.GetSafeCombatPosition(TargetMob)
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
	if AFCombat.S.LastAttackerCombatMob ~= TargetMob then
		AFCombat.S.LastAttackerCombatMob = TargetMob
		AFCombat.S.LastAttackerCombatSide = math.random(0, 1) == 0 and -1 or 1
		AFCombat.S.LastAttackerCombatSwitchTime = os.clock() + math.random() * (CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MAX - CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MIN) + CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MIN
		AFCombat.S.LastAttackerCombatPosition = nil
	elseif os.clock() >= AFCombat.S.LastAttackerCombatSwitchTime then
		AFCombat.S.LastAttackerCombatSide *= -1
		AFCombat.S.LastAttackerCombatSwitchTime = os.clock() + math.random() * (CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MAX - CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MIN) + CONFIG.OTHER_ATTACKER_SIDE_SWITCH_MIN
		AFCombat.S.LastAttackerCombatPosition = nil
	end

	if OtherAttacker then
		CombatDistance = math.max(CombatDistance, CONFIG.GOBLIN_REACH_DISTANCE)
	end

	for _, BladePart in AFCombat.GetCombatBladeParts(TargetMob) do
		local BladeOffset = BladePart.Position - TargetRoot.Position
		local HorizontalBladeOffset = Vector3.new(BladeOffset.X, 0, BladeOffset.Z)
		local BladeDistance = HorizontalBladeOffset.Magnitude
		CombatDistance = math.max(
			CombatDistance,
			BladeDistance + AFCombatUtils.GetBladeDangerDistance()
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
	local Side = Vector3.new(Right.X, 0, Right.Z) * AFCombat.S.LastAttackerCombatSide
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
			if AFCombatUtils.IsInsideFarmArea(CandidatePosition)
				and not AFCombatUtils.IsWaterAtPosition(CandidatePosition, TargetMob)
				and not AFCombatUtils.IsPathThroughDeadzone(CandidatePosition)
				and AFCombat.IsPositionSafeFromBladeGroup(CandidatePosition, TargetMob)
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
			if not AFCombatUtils.IsInsideFarmArea(CandidatePosition)
				or AFCombatUtils.IsWaterAtPosition(CandidatePosition, TargetMob)
				or AFCombatUtils.IsPathThroughDeadzone(CandidatePosition)
				or not AFCombat.IsPositionSafeFromBladeGroup(CandidatePosition, TargetMob)
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

	--// A spot the mob cannot be seen from is worse, not unusable. Rejecting
	--// it outright meant a pillar or a rock between us was enough to leave
	--// the solver with no answer at all, when walking around it was always
	--// an option. Sight is preferred; blocked sight is kept as a fallback
	--// and the pathfinder routes to it.
	local BlindFallback = nil

	for Index = 1, MaxPathTests do
		local CandidatePosition = Candidates[Index].Position

		if AFCombatUtils.IsPathThroughWater(CandidatePosition)
			or AFCombat.IsPathThroughBladeGroupDanger(CandidatePosition, TargetMob)
		then
			continue
		end

		if AFCombatUtils.CanSeeGoblinFromPosition(CandidatePosition, TargetMob)
			and AFCombat.IsSafeCombatPathClear(CandidatePosition, TargetMob)
		then
			return CandidatePosition
		end

		if not BlindFallback then
			BlindFallback = CandidatePosition
		end
	end

	return BlindFallback
end

--// Calculate Retreat Position
function AFCombat.IsRetreatPositionReachable(TargetPosition, RequirePathfinding)
	if not RootPart or not TargetPosition then
		return false
	end

	if not AFCombatUtils.IsInsideFarmArea(TargetPosition)
		or AFCombatUtils.IsWaterAtPosition(TargetPosition)
		or AFCombatUtils.IsPathThroughWater(TargetPosition)
		or AFCombatUtils.IsPathThroughDeadzone(TargetPosition)
	then
		return false
	end

	if not AFCombatUtils.IsPathClear(TargetPosition) then
		return false
	end

	--// A retreat position is only useful if it is outside every active
	--// enemy blade danger area, and the route does not cross one.
	for _, Goblin in AFCombat.GetLivingGoblins() do
		if AFCombat.IsPositionSafeFromBladeGroup(TargetPosition, Goblin) == false
			or AFCombat.IsPathThroughBladeGroupDanger(TargetPosition, Goblin)
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

		if not AFCombatUtils.IsInsideFarmArea(Position)
			or AFCombatUtils.IsWaterAtPosition(Position)
			or AFCombatUtils.IsPathThroughDeadzone(Position)
		then
			return false
		end
	end

	return true
end

function AFCombat.GetEnemySkillRetreatPosition()
	if not RootPart then
		return nil
	end

	local Threats = AFCombat.GetLivingGoblins()

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

			if not AFCombat.IsRetreatPositionReachable(Candidate, true) then
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
			if AFCombat.IsRetreatPositionReachable(Candidate, false) then
				BestPosition = Candidate
				break
			end
		end
	end

	return BestPosition
end

function AFCombat.GetRetreatPosition()
	if not RootPart then
		return nil
	end

	local Goblins = AFCombat.GetLivingGoblins()

	if #Goblins == 0 then
		return nil
	end

	local RetreatDirection = Vector3.zero

	if AFCombat.S.ClosestTarget
		and AFCombat.S.ClosestTarget:IsDescendantOf(workspace)
	then
		local TargetHumanoid = AFCombat.S.ClosestTarget:FindFirstChildOfClass("Humanoid")
		local TargetRoot     = AFCombat.S.ClosestTarget:FindFirstChild("HumanoidRootPart")

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

	--// Only the full retreat distance used to be tried. Near a zone edge, or
	--// with any wall inside sixty studs, every direction failed and the
	--// caller was left standing in the damage. Shorter hops are worth far
	--// more than no movement at all.
	local Distances = {
		CONFIG.RETREAT_DISTANCE,
		45,
		32,
		22,
		14,
	}

	for _, Distance in ipairs(Distances) do
		for Index = 0, CONFIG.RETREAT_DIRECTIONS - 1 do
			local Angle = (math.pi * 2 / CONFIG.RETREAT_DIRECTIONS) * Index

			local Direction = Vector3.new(
				math.cos(Angle),
				0,
				math.sin(Angle)
			)

			local TargetPosition = RootPart.Position + Direction * Distance

			if AFCombatUtils.IsInsideFarmArea(TargetPosition)
				and AFCombatUtils.IsPathClear(TargetPosition)
			then
				local Score = Direction:Dot(RetreatDirection)

				if Score > BestScore then
					BestScore    = Score
					BestPosition = TargetPosition
				end
			end
		end

		--// Prefer the longest distance that produced anything.
		if BestPosition then
			return BestPosition
		end
	end

	return BestPosition
end

--// Direction away from the nearest threat, with no validation at all. Used
--// as the last resort when every vetted escape has failed: walking into a
--// wall still beats standing still while a mob swings.
function AFCombat.GetRawAwayDirection()
	if not RootPart then
		return nil
	end

	local Origin = RootPart.Position
	local Nearest = nil
	local NearestDistance = math.huge

	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder then
		return nil
	end

	for _, Mob in MobFolder:GetChildren() do
		if Mob:IsA("Model") then
			local MobRoot = Mob:FindFirstChild("HumanoidRootPart")
			local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")

			if MobRoot and MobHumanoid and MobHumanoid.Health > 0 then
				local Distance = AFCombatUtils.GetHorizontalDistance(Origin, MobRoot.Position)

				if Distance < NearestDistance then
					NearestDistance = Distance
					Nearest = MobRoot
				end
			end
		end
	end

	if not Nearest then
		return nil
	end

	local Offset = Origin - Nearest.Position
	local Flat = Vector3.new(Offset.X, 0, Offset.Z)

	if Flat.Magnitude <= 0.01 then
		return nil
	end

	return Flat.Unit
end

--// Check whether any living priority mob is close enough to justify retreat movement.
--// Distance to the nearest living mob of any kind. The priority list decides
--// what to attack, not what can hurt us: a mob outside it swings just as hard,
--// and keying "am I safe to stand still" off the priority list meant the
--// script would hold position while something not on the list beat on it.
function AFCombat.GetNearestHostileDistance()
	if not RootPart then
		return math.huge
	end

	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder then
		return math.huge
	end

	local Nearest = math.huge

	for _, Mob in MobFolder:GetChildren() do
		if Mob:IsA("Model") then
			local MobRoot = Mob:FindFirstChild("HumanoidRootPart")
			local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")

			if MobRoot and MobHumanoid and MobHumanoid.Health > 0 then
				local Distance = AFCombatUtils.GetHorizontalDistance(RootPart.Position, MobRoot.Position)

				if Distance < Nearest then
					Nearest = Distance
				end
			end
		end
	end

	return Nearest
end

function AFCombat.GetNearestLivingGoblinDistance()
	if not RootPart then
		return math.huge
	end

	local NearestDistance = math.huge

	for _, Goblin in AFCombat.GetLivingGoblins() do
		local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

		if MobRoot then
			local Distance = AFCombatUtils.GetHorizontalDistance(RootPart.Position, MobRoot.Position)

			if Distance < NearestDistance then
				NearestDistance = Distance
			end
		end
	end

	return NearestDistance
end

--// Retreat
--// Dodging a skill is a race, and the pathfinding solver is not fast enough
--// to win it: sixteen directions by five distances is up to eighty
--// ComputeAsync calls plus hundreds of samples, which stalls frames badly
--// enough that the character appears to crawl.
--//
--// This picks a direction away from the whole group and validates it with
--// nothing but a farm-zone test, a ground ray and one body-width blockcast.
--// It is allowed to be imperfect; moving now beats moving well later.
function AFCombat.GetImmediateEscapePosition()
	if not RootPart then
		return nil
	end

	local Origin = RootPart.Position
	local Away = Vector3.zero

	for _, Goblin in AFCombat.GetLivingGoblins() do
		local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

		if MobRoot then
			local Offset = Origin - MobRoot.Position
			local Flat = Vector3.new(Offset.X, 0, Offset.Z)
			local Distance = Flat.Magnitude

			if Distance > 0.01 then
				--// Inverse distance: the mob about to hit us dominates.
				Away += Flat.Unit / math.max(Distance, 4)
			end
		end
	end

	if Away.Magnitude <= 0.01 then
		Away = -Vector3.new(
			RootPart.CFrame.LookVector.X,
			0,
			RootPart.CFrame.LookVector.Z
		)

		if Away.Magnitude <= 0.01 then
			return nil
		end
	end

	Away = Away.Unit

	local DirectionCount = math.max(1, tonumber(CONFIG.SKILL_DODGE_DIRECTIONS) or 9)
	local Spread = tonumber(CONFIG.SKILL_DODGE_SPREAD) or 110
	local Distances = {
		tonumber(CONFIG.SKILL_DODGE_DISTANCE) or 26,
		tonumber(CONFIG.SKILL_DODGE_FALLBACK_DISTANCE) or 14,
	}

	for _, Distance in ipairs(Distances) do
		for Index = 0, DirectionCount - 1 do
			--// Straight away first, then alternating outward to either side.
			local Step = math.ceil(Index / 2)
			local Sign = (Index % 2 == 0) and 1 or -1
			local Angle = math.rad((Spread / math.max(1, DirectionCount - 1)) * Step * Sign)
			local Direction = CFrame.fromAxisAngle(Vector3.yAxis, Angle):VectorToWorldSpace(Away)

			Direction = Vector3.new(Direction.X, 0, Direction.Z)

			if Direction.Magnitude > 0.01 then
				Direction = Direction.Unit

				local Candidate = AFCombatUtils.GetPatrolGroundPosition(Origin + Direction * Distance)

				if Candidate
					and AFCombatUtils.IsInsideFarmArea(Candidate)
					and not AFCombatUtils.IsInsideFarmDeadzone(Candidate)
					and AFCombatUtils.IsEscapePathClear(Candidate)
				then
					return Candidate
				end
			end
		end
	end

	return nil
end

function AFCombat.RetreatFromGoblins(IsEnemySkill)
	local RetreatPosition = nil
	local now = os.clock()

	--// Normal retreat only triggers movement/jump when a mob is within
	--// the configured nearby distance. Enemy skill retreat is different:
	--// if a mob is actively using a skill, keep the skill-escape logic
	--// even when that mob is farther than the normal 30-stud trigger.
	if not IsEnemySkill then
		--// Any living mob counts here, not just the ones we would attack.
		local NearestMobDistance = AFCombat.GetNearestHostileDistance()
		if NearestMobDistance > CONFIG.RETREAT_NEARBY_MOB_DISTANCE then
			Humanoid.AutoRotate = false
			Humanoid:Move(Vector3.zero)
			return false
		end
	end

	if IsEnemySkill then
		--// Keep running toward the position already chosen while it is still
		--// worth reaching, so the character commits to one escape instead of
		--// re-deciding every frame and shuffling on the spot.
		if AFCombat.S.SkillRetreatPosition
			and now - AFCombat.S.LastSkillRetreatTime < CONFIG.RETREAT_RECALCULATE_INTERVAL
			and AFCombatUtils.GetHorizontalDistance(RootPart.Position, AFCombat.S.SkillRetreatPosition) > 3
			and AFCombatUtils.IsInsideFarmArea(AFCombat.S.SkillRetreatPosition)
			and not AFCombatUtils.IsInsideFarmDeadzone(AFCombat.S.SkillRetreatPosition)
		then
			RetreatPosition = AFCombat.S.SkillRetreatPosition
		else
			--// Cheap solver first. It answers in a handful of raycasts.
			RetreatPosition = AFCombat.GetImmediateEscapePosition()

			--// Only when there is no room at all does the expensive
			--// pathfinding solver run, and then no more than once every
			--// SKILL_SOLVER_INTERVAL so it cannot stall frame after frame.
			if not RetreatPosition
				and now - AFCombat.S.LastSkillSolverTime >= (tonumber(CONFIG.SKILL_SOLVER_INTERVAL) or 0.6)
			then
				AFCombat.S.LastSkillSolverTime = now
				RetreatPosition = AFCombat.GetEnemySkillRetreatPosition()
			end

			if RetreatPosition then
				AFCombat.S.SkillRetreatPosition = RetreatPosition
				AFCombat.S.LastSkillRetreatTime = now
			else
				AFCombat.S.SkillRetreatPosition = nil
			end
		end
	else
		if AFCombat.S.LastRetreatPosition
			and now - AFCombat.S.LastRetreatCalculateTime < CONFIG.RETREAT_RECALCULATE_INTERVAL
		then
			RetreatPosition = AFCombat.S.LastRetreatPosition
		else
			RetreatPosition = AFCombat.GetRetreatPosition()

			--// Same cheap solver the skill dodge uses. It accepts ground the
			--// vetted search rejects, which is the difference between moving
			--// and standing still.
			if not RetreatPosition then
				RetreatPosition = AFCombat.GetImmediateEscapePosition()
			end

			if RetreatPosition then
				AFCombat.S.LastRetreatPosition      = RetreatPosition
				AFCombat.S.LastRetreatCalculateTime = now
				AFCombat.S.RetreatNoPositionSince   = nil
			elseif not AFCombat.S.RetreatNoPositionSince then
				AFCombat.S.RetreatNoPositionSince = now
			end
		end
	end

	if RetreatPosition then
		AFCombat.S.RetreatNoPositionSince = nil

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

		AFCombatUtils.DoJumpIfObstacle(RetreatPosition)
		return true
	end

	--// Nothing passed any check. Standing still here is the worst possible
	--// answer and is exactly what the script used to do: it would hold
	--// position, still flagged as retreating, and take hits until it died.
	if not AFCombat.S.RetreatNoPositionSince then
		AFCombat.S.RetreatNoPositionSince = now
	end

	if now - AFCombat.S.RetreatNoPositionSince < (tonumber(CONFIG.RETREAT_NO_POSITION_TIMEOUT) or 1.5) then
		local Away = AFCombat.GetRawAwayDirection()

		if Away then
			Humanoid.AutoRotate = false
			local RawTarget = RootPart.Position + Away * CONFIG.SKILL_DODGE_FALLBACK_DISTANCE
			Humanoid:MoveTo(RawTarget)
			AFCombatUtils.DoJumpIfObstacle(RawTarget)
			return true
		end
	else
		--// Boxed in for long enough that retreating is clearly not working.
		--// Fighting back beats being a stationary target, so hand control
		--// back to the combat loop.
		AFCombat.S.RETREATING = false
		AFCombat.S.RetreatNoPositionSince = nil
		AFCombat.S.SkillRetreatPosition = nil
		AFCombat.S.LastRetreatPosition = nil
	end

	Humanoid.AutoRotate = false
	Humanoid:Move(Vector3.zero)
	return false
end

--// Approach Position Check
function AFCombat.IsApproachPositionClear(TargetPosition, Goblin)
	if not RootPart or not TargetPosition then
		return false
	end

	if not AFCombatUtils.IsInsideFarmArea(TargetPosition) then
		return false
	end

	if AFCombatUtils.IsWaterAtPosition(TargetPosition, Goblin) then
		return false
	end

	if AFCombatUtils.IsPathThroughWater(TargetPosition) then
		return false
	end

	if AFCombatUtils.IsPathThroughDeadzone(TargetPosition) then
		return false
	end

	--// Never select a position inside any BladePart danger zone
	--// around the target group.
	if AFCombat.S.SafeCombatPositionEnabled
		and Goblin
		and not AFCombat.IsPositionSafeFromBladeGroup(TargetPosition, Goblin)
	then
		return false
	end

	--// Also make sure the route itself doesn't pass through
	--// an enemy BladePart danger zone.
	if AFCombat.S.SafeCombatPositionEnabled
		and Goblin
		and AFCombat.IsPathThroughBladeGroupDanger(TargetPosition, Goblin)
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
	if AFCombatUtils.S.DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, AFCombatUtils.S.DebugFolder)
	end

	local Result = workspace:Raycast(Origin, Direction, RaycastParams)

	return Result == nil
end

--// Target Reposition
function AFCombat.GetTargetRepositionPosition(Goblin)
	if not RootPart or not Goblin then
		return nil
	end

	local MobRoot = Goblin:FindFirstChild("HumanoidRootPart")

	if not MobRoot then
		return nil
	end

	--// Calculate the minimum safe radius around the target.
	local SafeRadius = CONFIG.PLAYER_ATTACK_DISTANCE

	if AFCombat.S.SafeCombatPositionEnabled then
		for _, BladePart in AFCombat.GetCombatBladeParts(Goblin) do
			local Offset = BladePart.Position - MobRoot.Position
			local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)
			local BladeDistance = HorizontalOffset.Magnitude

			SafeRadius = math.max(
				SafeRadius,
				BladeDistance + AFCombatUtils.GetBladeDangerDistance()
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

		if not AFCombat.IsApproachPositionClear(CandidatePosition, Goblin) then
			continue
		end

		if AFCombat.S.SafeCombatPositionEnabled
			and not AFCombat.IsPositionSafeFromBladeGroup(CandidatePosition, Goblin)
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

		--// Penalise rather than discard a spot with no view of the mob, so a
		--// wall in the way costs a detour instead of the whole candidate set.
		if not AFCombatUtils.CanSeeGoblinFromPosition(CandidatePosition, Goblin) then
			Score += CONFIG.BLIND_POSITION_PENALTY
		end

		if Score < BestScore then
			BestScore    = Score
			BestPosition = CandidatePosition
		end
	end

	return BestPosition
end

function AFCombat.FaceGoblin(Goblin)
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

function AFCombat.IsSafeCombatDirectPathBlocked(Goblin, TargetPosition, now)
	if not RootPart or not Goblin or not TargetPosition then
		return true
	end

	if AFCombat.S.LastDirectPathTarget == Goblin
		and AFCombat.S.LastDirectPathPosition == TargetPosition
		and now - AFCombat.S.LastDirectPathCheckTime < CONFIG.DIRECT_PATH_CACHE_INTERVAL
	then
		return AFCombat.S.LastDirectPathBlocked
	end

	AFCombat.S.LastDirectPathCheckTime = now
	AFCombat.S.LastDirectPathTarget = Goblin
	AFCombat.S.LastDirectPathPosition = TargetPosition

	AFCombat.S.LastDirectPathBlocked =
		not AFCombatUtils.CanSeeGoblin(Goblin)
		or not AFCombat.IsSafeCombatPathClear(TargetPosition, Goblin)
		or AFCombatUtils.IsPathThroughWater(TargetPosition)
		or AFCombatUtils.IsPathThroughDeadzone(TargetPosition)
		or AFCombat.IsPathThroughBladeGroupDanger(TargetPosition, Goblin)

	return AFCombat.S.LastDirectPathBlocked
end

--// ============================================================
--// TARGET PATHFINDING
--// ============================================================
function AFCombat.ResetTargetPath()
	AFCombat.S.TargetPath             = nil
	AFCombat.S.TargetPathMob          = nil
	AFCombat.S.TargetPathDestination  = nil
	AFCombat.S.TargetPathWaypoint     = 1
	AFCombat.S.LastTargetPathTime     = 0
	AFCombat.S.TargetPathBlockedSince = nil
end

function AFCombat.ComputeTargetPath(Goblin, Destination)
	if not RootPart or not Goblin or not Destination then
		AFCombat.ResetTargetPath()
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
		AFCombat.ResetTargetPath()
		return false
	end

	local Waypoints = Path:GetWaypoints()

	if #Waypoints < 2 then
		AFCombat.ResetTargetPath()
		return false
	end

	--// Never follow a path that leaves the FarmZone, and never one that cuts
	--// through a deadzone. IsInsideFarmArea covers both, but it short
	--// circuits to true when Ignore Farm Zone is on, so the deadzone test is
	--// spelled out for the case where only the zone restriction is waived.
	for Index = 2, #Waypoints do
		local Position = Waypoints[Index].Position

		if not AFCombatUtils.IsInsideFarmArea(Position) then
			AFCombat.ResetTargetPath()
			return false
		end

		if not Feature.IgnoreFarmZone.Enabled
			and AFCombatUtils.IsInsideFarmDeadzone(Position)
		then
			AFCombat.ResetTargetPath()
			return false
		end
	end

	AFCombat.S.TargetPath             = Path
	AFCombat.S.TargetPathMob          = Goblin
	AFCombat.S.TargetPathDestination  = Destination
	AFCombat.S.TargetPathWaypoint     = 2
	AFCombat.S.LastTargetPathTime     = os.clock()
	AFCombat.S.TargetPathBlockedSince = nil

	return true
end

function AFCombat.MoveAlongTargetPath(Goblin, Destination)
	if not RootPart or not Goblin or not Destination then
		return false
	end

	local now = os.clock()
	local NeedRecalculate =
		AFCombat.S.TargetPath == nil
		or AFCombat.S.TargetPathMob ~= Goblin
		or not AFCombat.S.TargetPathDestination
		or (AFCombat.S.TargetPathDestination - Destination).Magnitude > 5
		or now - AFCombat.S.LastTargetPathTime >= CONFIG.TARGET_PATH_RECALCULATE_INTERVAL

	if NeedRecalculate then
		if not AFCombat.ComputeTargetPath(Goblin, Destination) then
			if not AFCombat.S.TargetPathBlockedSince then
				AFCombat.S.TargetPathBlockedSince = now
			end

			return false
		end
	end

	local Waypoints = AFCombat.S.TargetPath:GetWaypoints()

	while AFCombat.S.TargetPathWaypoint <= #Waypoints do
		local Waypoint = Waypoints[AFCombat.S.TargetPathWaypoint]
		local Offset = Waypoint.Position - RootPart.Position
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		if Distance <= CONFIG.TARGET_PATH_WAYPOINT_DISTANCE then
			AFCombat.S.TargetPathWaypoint += 1
			continue
		end

		--// The pathfinder marks jumps generously, including on flat ground.
		--// Only take them when something is actually in the way, or when the
		--// character has stopped making progress.
		if Waypoint.Action == Enum.PathWaypointAction.Jump
			and (AFCombatUtils.IsJumpableObstacleAhead(Waypoint.Position) or AFCombatUtils.IsStuck())
		then
			AFCombatUtils.DoJump()
		end

		Humanoid.AutoRotate = false
		Humanoid:MoveTo(Waypoint.Position)
		AFCombat.FaceGoblin(Goblin)
		return true
	end

	--// Path reached its final waypoint. Let combat positioning decide
	--// whether we should attack or make a final adjustment.
	AFCombat.ResetTargetPath()
	return false
end

--// ============================================================
--// SAFE ENEMY RANGE
--// ============================================================
function AFCombat.GetSafeEnemyRangePosition(Goblin)
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

	local BladeParts = AFCombat.GetCombatBladeParts(Goblin)
	if #BladeParts == 0 then
		return nil
	end

	local LastAttacker = Goblin:FindFirstChild("LastAttacker")
	local IsPlayerAttacker = LastAttacker and LastAttacker.Value == Player

	local ClosestBlade = nil
	local ClosestPoint = nil
	local ClosestDistance = math.huge

	for _, BladePart in ipairs(BladeParts) do
		local Point, Distance = AFCombatUtils.GetClosestPointOnBlade(BladePart, RootPart.Position)
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
		if AFCombatUtils.IsInsideFarmArea(Candidate) and not AFCombatUtils.IsInsideFarmDeadzone(Candidate) then
			local SafeFromAllBlades = true
			for _, BladePart in ipairs(BladeParts) do
				local _, Distance = AFCombatUtils.GetClosestPointOnBlade(BladePart, Candidate)
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
function AFCombat.MoveToGoblin(Goblin)
	local now = os.clock()
	if not Goblin or not RootPart then
		return
	end

	if not AFCombat.IsTargetLockValid(Goblin) then
		if AFCombat.S.ClosestTarget == Goblin then
			AFCombat.S.ClosestTarget = nil
		end

		AFCombat.ResetTargetReposition()
		AFCombat.ResetTargetPath()
		return
	end

	local MobHumanoid = Goblin:FindFirstChildOfClass("Humanoid")
	local MobRoot     = Goblin:FindFirstChild("HumanoidRootPart")

	--// Secondary threat handling:
	--// Keep the current target locked, but make room if another mob
	--// closes in from the player's side or rear.
	local ThreatMob, ThreatDistance = AFCombat.GetNearbyThreatMob(Goblin)
	if ThreatMob and ThreatDistance <= CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + CONFIG.THREAT_ESCAPE_DISTANCE then
		local ThreatEscapePosition = AFCombat.GetThreatEscapePosition(Goblin, ThreatMob)

		if ThreatEscapePosition then
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(ThreatEscapePosition)
			AFCombat.FaceGoblin(Goblin)
			return
		end
	end

	if not MobHumanoid
		or not MobRoot
		or MobHumanoid.Health <= 0
	then
		if AFCombat.S.ClosestTarget == Goblin then
			AFCombat.S.ClosestTarget = nil
		end

		AFCombat.S.ValidMobs[Goblin] = nil
		AFCombat.ResetTargetReposition()
		AFCombat.ResetTargetPath()

		return
	end

	--// Safe Enemy Range has its own lightweight rule set.
	--// It only cares about BladePart distance, FarmZone, and Deadzone.
	--// It does not use CanSeeGoblin, water checks, path checks, or SafeCombat.
	local SafeEnemyRangePosition = AFCombat.GetSafeEnemyRangePosition(Goblin)
	if SafeEnemyRangePosition then
		local SafeEnemyOffset = SafeEnemyRangePosition - RootPart.Position
		local SafeEnemyDistance = Vector3.new(SafeEnemyOffset.X, 0, SafeEnemyOffset.Z).Magnitude

		if SafeEnemyDistance > CONFIG.SAFE_ENEMY_RANGE_ARRIVAL then
			AFCombat.ResetTargetPath()
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(SafeEnemyRangePosition)
			AFCombat.FaceGoblin(Goblin)
			return
		end
	end

	--// Safe Combat Position disabled:
	--// simply move directly toward the target.
	if not AFCombat.S.SafeCombatPositionEnabled then
		AFCombat.ResetTargetReposition()
		AFCombat.ResetTargetPath()
		Humanoid.AutoRotate = false
		Humanoid:MoveTo(MobRoot.Position)
		AFCombat.FaceGoblin(Goblin)
		return
	end

	if AFCombat.S.TargetApproachMob ~= Goblin then
		AFCombat.ResetTargetReposition()
		AFCombat.S.TargetApproachMob = Goblin
		AFCombat.S.CACHED_SAFECOMBAT_POSITION = nil
		AFCombat.S.CACHED_SAFECOMBAT_TARGET = Goblin
		AFCombat.S.LAST_SAFECOMBAT_TIME = 0
	end

	--// ========================================================
	--// FIRST PRIORITY:
	--// Get away from ANY BladePart that is currently too close.
	--// ========================================================

	local PushDirection, ClosestEffectiveDistance, ClosestBlade = AFCombat.GetBladeDangerData(Goblin)

	if ClosestEffectiveDistance <= 0 then
		if PushDirection.Magnitude > 0 then
			local RetreatDistance = math.abs(ClosestEffectiveDistance) + CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + 2
			local RetreatPosition = RootPart.Position + PushDirection * RetreatDistance

			if AFCombatUtils.IsInsideFarmArea(RetreatPosition)
				and not AFCombatUtils.IsWaterAtPosition(RetreatPosition, Goblin)
				and not AFCombatUtils.IsPathThroughWater(RetreatPosition)
				and not AFCombatUtils.IsPathThroughDeadzone(RetreatPosition)
				and not AFCombat.IsPathThroughBladeGroupDanger(RetreatPosition, Goblin)
				and AFCombatUtils.IsEscapePathClear(RetreatPosition)
			then
				Humanoid.AutoRotate = false
				Humanoid:MoveTo(RetreatPosition)
				AFCombat.FaceGoblin(Goblin)
			else
				local MoveDistance  = math.abs(ClosestEffectiveDistance) + CONFIG.ENEMY_ATTACK_SAFE_DISTANCE + 2
				local MovePosition  = RootPart.Position + PushDirection * MoveDistance

				if AFCombatUtils.IsInsideFarmArea(MovePosition)
					and not AFCombatUtils.IsWaterAtPosition(MovePosition, Goblin)
					and not AFCombatUtils.IsPathThroughWater(MovePosition)
					and not AFCombatUtils.IsPathThroughDeadzone(MovePosition)
				then
					Humanoid.AutoRotate = false
					Humanoid:MoveTo(MovePosition)
					AFCombat.FaceGoblin(Goblin)
				else
					Humanoid.AutoRotate = true
					Humanoid:Move(Vector3.zero)
					AFCombat.FaceGoblin(Goblin)
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

	local SafeCombatPosition = AFCombat.S.CACHED_SAFECOMBAT_POSITION
	if AFCombat.S.CACHED_SAFECOMBAT_TARGET ~= Goblin
		or now - AFCombat.S.LAST_SAFECOMBAT_TIME >= CONFIG.SAFECOMBAT_INTERVAL
		or (SafeCombatPosition and not AFCombatUtils.IsInsideFarmArea(SafeCombatPosition))
	then
		AFCombat.S.LAST_SAFECOMBAT_TIME = now
		AFCombat.S.CACHED_SAFECOMBAT_TARGET = Goblin
		SafeCombatPosition = AFCombat.GetSafeCombatPosition(Goblin)
		AFCombat.S.CACHED_SAFECOMBAT_POSITION = SafeCombatPosition
	end

	if SafeCombatPosition then
		local Offset = SafeCombatPosition - RootPart.Position
		local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

		--// Already at the desired safe position.
		if Distance <= CONFIG.COMBAT_POSITION_ARRIVAL then
			--// Stop movement but keep the character locked onto the target.
			Humanoid.AutoRotate = false
			Humanoid:Move(Vector3.zero)
			AFCombat.FaceGoblin(Goblin)

			AFCombat.S.TargetUnreachableSince = nil
			AFCombat.S.TargetApproachPosition = nil

			return
		end

		local DirectPathBlocked = AFCombat.IsSafeCombatDirectPathBlocked(Goblin, SafeCombatPosition, now)

		if not DirectPathBlocked then
			AFCombat.ResetTargetPath()
			AFCombat.S.TargetUnreachableSince = nil
			AFCombat.S.TargetApproachPosition = nil

			Humanoid.AutoRotate = false
			Humanoid:MoveTo(SafeCombatPosition)
			AFCombat.FaceGoblin(Goblin)
			return
		end
	end

	--// ========================================================
	--// THIRD PRIORITY:
	--// Use real pathfinding when an object blocks the direct route.
	--// A blocked line of sight does NOT mean the target is unreachable.
	--// ========================================================

	local PathDestination = SafeCombatPosition or MobRoot.Position

	local OtherPlayerDetour = AFCombat.GetOtherPlayerDetourPosition(PathDestination, Goblin)
	if OtherPlayerDetour then
		AFCombat.ResetTargetPath()
		Humanoid.AutoRotate = true
		Humanoid:MoveTo(OtherPlayerDetour)
		return
	end

	if AFCombat.MoveAlongTargetPath(Goblin, PathDestination) then
		AFCombat.S.TargetUnreachableSince = nil
		AFCombat.S.TargetApproachPosition = nil
		return
	end

	--// The chosen combat spot may be unreachable while the mob itself is
	--// perfectly walkable, so try routing to the mob before treating the
	--// target as out of reach. An obstacle between us is a detour, not a
	--// reason to drop the target.
	if PathDestination ~= MobRoot.Position
		and AFCombat.MoveAlongTargetPath(Goblin, MobRoot.Position)
	then
		AFCombat.S.TargetUnreachableSince = nil
		AFCombat.S.TargetApproachPosition = nil
		return
	end

	--// ========================================================
	--// FOURTH PRIORITY:
	--// Reposition around the entire enemy group.
	--// ========================================================

	if not AFCombat.S.TargetUnreachableSince then
		AFCombat.S.TargetUnreachableSince = now
	end

	if not AFCombat.S.TargetApproachPosition
		or now - AFCombat.S.LastTargetRepositionTime >= CONFIG.TARGET_REPOSITION_INTERVAL
	then
		AFCombat.S.LastTargetRepositionTime = now
		AFCombat.S.TargetApproachPosition = AFCombat.GetTargetRepositionPosition(Goblin)
	end

	if AFCombat.S.TargetApproachPosition then
		local ApproachOffset = AFCombat.S.TargetApproachPosition - RootPart.Position
		local ApproachDistance = Vector3.new(ApproachOffset.X, 0, ApproachOffset.Z).Magnitude

		if ApproachDistance <= CONFIG.APPROACH_ARRIVAL_DISTANCE then
			AFCombat.S.TargetApproachPosition = nil
		else
			Humanoid.AutoRotate = false
			Humanoid:MoveTo(AFCombat.S.TargetApproachPosition)
			AFCombat.FaceGoblin(Goblin)
			return
		end
	end

	--// No safe combat position was found. Do not make the target appear
	--// invisible just because the safe-position solver failed. If the direct
	--// route is clear, move toward the actual mob and let the blade-danger check
	--// above keep us from standing inside the enemy weapon range.
	if AFCombat.IsSafeCombatPathClear(MobRoot.Position, Goblin)
		and not AFCombatUtils.IsPathThroughWater(MobRoot.Position)
		and not AFCombatUtils.IsPathThroughDeadzone(MobRoot.Position)
	then
		AFCombat.S.TargetUnreachableSince = nil
		Humanoid.AutoRotate = false
		Humanoid:MoveTo(MobRoot.Position)
		AFCombat.FaceGoblin(Goblin)
		return
	end

	--// The mob is still a valid target even when the safe-position solver
	--// cannot find a perfect attack point. Keep the target locked while the
	--// pathfinding/reposition logic retries instead of dropping visibility.
	Humanoid.AutoRotate = true
	Humanoid:Move(Vector3.zero)

	if now - AFCombat.S.TargetUnreachableSince >= CONFIG.TARGET_UNREACHABLE_TIMEOUT then
		--// Nothing worked: no safe spot, no path to one, no path to the mob
		--// and no clear line. Remember that, or the next selection hands the
		--// same mob back and the whole attempt repeats forever.
		AFCombat.MarkMobUnreachable(Goblin)

		if AFCombat.S.ClosestTarget == Goblin then
			AFCombat.S.ClosestTarget = nil
		end

		AFCombat.ResetTargetReposition()
		AFCombat.ResetTargetPath()
	end
end

------------------------------------------------------------------------
--// AFCombat  ::  target acquisition and attack / skill execution
--// 8 function(s)
------------------------------------------------------------------------
--// PRO COMBAT ACTION ENGINE
function AFCombat.GetCombatHealthPercent()
	if not Humanoid or Humanoid.MaxHealth <= 0 then
		return 100
	end

	return (Humanoid.Health / Humanoid.MaxHealth) * 100
end

function AFCombat.IsEnemyUsingSkill(Mob)
	if not Mob then
		return false
	end

	local EnemySword = Mob:FindFirstChild("Sword")
	local BladePart = EnemySword and EnemySword:FindFirstChild("BladePart")
	local SkillObject = Mob:FindFirstChild("Skill", true)
	local Sparkles = BladePart and BladePart:FindFirstChild("Sparkles", true)

	local SkillSoundActive = SkillObject
		and SkillObject:IsA("Sound")
		and SkillObject.IsPlaying

	local SparklesActive = Sparkles
		and Sparkles:IsA("ParticleEmitter")
		and Sparkles.Enabled

	return SkillSoundActive or SparklesActive or false
end

--// Scan every nearby living priority mob, not only the current target. A
--// skill from a mob we are not fighting lands just the same, and the old
--// check missed it entirely.
function AFCombat.GetSkillThreat()
	if not RootPart then
		return false, nil
	end

	local Range = tonumber(CONFIG.SKILL_DETECT_DISTANCE) or 45
	local Closest = nil
	local ClosestDistance = math.huge

	local function Consider(Mob)
		local MobRoot = Mob:FindFirstChild("HumanoidRootPart")
		local MobHumanoid = Mob:FindFirstChildOfClass("Humanoid")

		if not MobRoot or not MobHumanoid or MobHumanoid.Health <= 0 then
			return
		end

		--// Distance first: it is far cheaper than walking the mob for a
		--// sound and an emitter, and this runs every frame.
		local Distance = AFCombatUtils.GetHorizontalDistance(RootPart.Position, MobRoot.Position)

		if Distance > Range or Distance >= ClosestDistance then
			return
		end

		if AFCombat.IsEnemyUsingSkill(Mob) then
			Closest = Mob
			ClosestDistance = Distance
		end
	end

	--// Only whether a skill is in progress matters, not which mob is closest,
	--// so this stops at the first hit instead of ranking them. It runs every
	--// heartbeat, so the saving is worth having.
	for Mob in AFCombat.S.ValidMobs do
		if Mob:IsDescendantOf(workspace) then
			Consider(Mob)

			if Closest then
				return true, Closest
			end
		end
	end

	--// ValidMobs lags a freshly spawned mob by up to one validation tick, so
	--// also look straight at the folder.
	local MobFolder = workspace:FindFirstChild("Mobs")

	if MobFolder then
		for _, Mob in MobFolder:GetChildren() do
			if Mob:IsA("Model") and not AFCombat.S.ValidMobs[Mob] then
				local Config = Mob:FindFirstChild("Config")
				local Entity = Config and Config:FindFirstChild("Entity")

				if Entity
					and Entity:IsA("StringValue")
					and AFCombat.IsEntityInPriority(Entity.Value)
				then
					Consider(Mob)

					if Closest then
						return true, Closest
					end
				end
			end
		end
	end

	return Closest ~= nil, Closest
end

--// Latches the dodge on for a short hold. The sound and the emitter both
--// flicker, and without this the script would step back into the attack
--// between two frames of the same skill.
function AFCombat.UpdateSkillThreat(now)
	local Detected = AFCombat.GetSkillThreat()

	if Detected then
		AFCombat.S.SkillThreatUntil = now + (tonumber(CONFIG.SKILL_DODGE_HOLD) or 0.75)
	end

	return now < AFCombat.S.SkillThreatUntil
end

function AFCombat.GetCombatAttackRange(TargetMob)
	local Range = CONFIG.COMBAT_ATTACK_RANGE

	if not TargetMob then
		return Range
	end

	local MobHumanoid = TargetMob:FindFirstChildOfClass("Humanoid")
	if MobHumanoid and MobHumanoid.MaxHealth > 0 then
		local HP = (MobHumanoid.Health / MobHumanoid.MaxHealth) * 100
		if HP <= CONFIG.COMBAT_FINISHER_HP_PERCENT then
			Range += CONFIG.COMBAT_FINISHER_RANGE_BONUS
		end
	end

	return Range
end

function AFCombat.FaceCombatTarget(TargetMob)
	if not RootPart or not TargetMob then
		return
	end

	local TargetRoot = TargetMob:FindFirstChild("HumanoidRootPart")
	if not TargetRoot then
		return
	end

	local Offset = TargetRoot.Position - RootPart.Position
	local Flat = Vector3.new(Offset.X, 0, Offset.Z)
	if Flat.Magnitude <= 0.01 then
		return
	end

	if FaceOrientation then
		FaceOrientation.CFrame = CFrame.lookAt(
			RootPart.Position,
			RootPart.Position + Flat.Unit
		)
		FaceOrientation.Enabled = true
	end
end

function AFCombat.InvokeCombatInput(InputName)
	if not InputBindableFunction then
		return false
	end

	local Success = pcall(function()
		InputBindableFunction:Invoke(
			InputName,
			Enum.UserInputState.Begin
		)
	end)

	return Success
end

function AFCombat.CanCombatAttack(TargetMob, now)
	if not TargetMob or not RootPart then
		return false
	end

	local MobHumanoid = TargetMob:FindFirstChildOfClass("Humanoid")
	local MobRoot = TargetMob:FindFirstChild("HumanoidRootPart")
	if not MobHumanoid or not MobRoot or MobHumanoid.Health <= 0 then
		return false
	end

	local Offset = MobRoot.Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if CONFIG.DISTANCE_Y_CALCULATE then
		Distance = Offset.Magnitude
	end

	return Distance <= AFCombat.GetCombatAttackRange(TargetMob)
		and now >= AFCombat.S.COMBAT_NEXT_ATTACK_TIME
end

function AFCombat.PerformCombatActions(TargetMob, now)
	if not TargetMob or not AFCombat.IsCombatTargetValid(TargetMob) then
		return
	end

	local MobRoot = TargetMob:FindFirstChild("HumanoidRootPart")
	local MobHumanoid = TargetMob:FindFirstChildOfClass("Humanoid")
	if not MobRoot or not MobHumanoid or MobHumanoid.Health <= 0 then
		return
	end

	local Offset = MobRoot.Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if CONFIG.DISTANCE_Y_CALCULATE then
		Distance = Offset.Magnitude
	end

	local EnemySkill = AFCombat.IsEnemyUsingSkill(TargetMob)
	local PlayerHP = AFCombat.GetCombatHealthPercent()

	if Distance <= CONFIG.COMBAT_FACE_RANGE then
		AFCombat.FaceCombatTarget(TargetMob)
	end

	if Feature.AutoSkill.Enabled
		and Distance <= CONFIG.COMBAT_SKILL_RANGE
		and PlayerHP >= CONFIG.COMBAT_SKILL_MIN_HP_PERCENT
		and not EnemySkill
		and now >= AFCombat.S.COMBAT_NEXT_SKILL_TIME
	then
		if AFCombat.InvokeCombatInput("SkillButton") then
			AFCombat.S.LAST_SKILL_TIME = now
			AFCombat.S.COMBAT_NEXT_SKILL_TIME = now + CONFIG.SKILL_INTERVAL
			AFCombat.S.COMBAT_NEXT_ATTACK_TIME = math.max(AFCombat.S.COMBAT_NEXT_ATTACK_TIME, now + 0.08)
		end
	end

	if AFCombat.CanCombatAttack(TargetMob, now) then
		if AFCombat.InvokeCombatInput("AttackButton") then
			AFCombat.S.LAST_ATTACK_TIME = now
			AFCombat.S.COMBAT_ATTACK_PHASE = (AFCombat.S.COMBAT_ATTACK_PHASE % 2) + 1

			local PhaseJitter = (AFCombat.S.COMBAT_ATTACK_PHASE == 1)
				and CONFIG.COMBAT_ACTION_JITTER
				or 0

			AFCombat.S.COMBAT_NEXT_ATTACK_TIME = now
				+ CONFIG.ATTACK_INTERVAL
				+ PhaseJitter
		end
	end
end

function AFCombat.AcquireCombatTarget(now)
	if not RootPart then
		return nil
	end

	if AFCombat.S.ClosestTarget
		and AFCombat.IsTargetLockValid(AFCombat.S.ClosestTarget)
		and now - AFCombat.S.LAST_COMBAT_TARGET_CHECK < CONFIG.COMBAT_TARGET_RECHECK
	then
		return AFCombat.S.ClosestTarget
	end

	AFCombat.S.LAST_COMBAT_TARGET_CHECK = now

	local Current = AFCombat.S.ClosestTarget
	local Candidate = AFCombat.GetClosestGoblin()

	if Current and AFCombat.IsTargetLockValid(Current) then
		local CurrentDistance = AFCombatUtils.GetMobDistance(Current)
		local CandidateDistance = Candidate and AFCombatUtils.GetMobDistance(Candidate) or math.huge
		local CurrentPriority = AFCombat.GetMobPriority(Current) or math.huge
		local CandidatePriority = Candidate and (AFCombat.GetMobPriority(Candidate) or math.huge) or math.huge

		local BetterPriority = CandidatePriority < CurrentPriority
		local MeaningfullyCloser =
			CandidateDistance + CONFIG.COMBAT_STICKY_DISTANCE_BONUS < CurrentDistance

		if not BetterPriority and not MeaningfullyCloser then
			return Current
		end
	end

	if Candidate then
		AFCombat.S.COMBAT_TARGET_LOST_SINCE = nil
		AFCombat.S.COMBAT_TARGET_SCORE = AFCombatUtils.GetMobDistance(Candidate)
		return Candidate
	end

	if Current and AFCombat.IsTargetLockValid(Current) then
		if not AFCombat.S.COMBAT_TARGET_LOST_SINCE then
			AFCombat.S.COMBAT_TARGET_LOST_SINCE = now
		end

		if now - AFCombat.S.COMBAT_TARGET_LOST_SINCE <= CONFIG.COMBAT_TARGET_GRACE then
			return Current
		end
	end

	AFCombat.S.COMBAT_TARGET_LOST_SINCE = nil
	AFCombat.S.COMBAT_TARGET_SCORE = math.huge
	return nil
end

--// Get All Living Goblins
function AFCombat.GetLivingGoblins()
	--// Cached for a fraction of a second. The retreat solver asks for this
	--// once per candidate position, which meant rescanning the entire mob
	--// folder tens of times for a single decision.
	local now = os.clock()

	if AFCombat.S.LivingGoblinCache
		and now - AFCombat.S.LivingGoblinCacheTime < (tonumber(CONFIG.LIVING_MOB_CACHE_INTERVAL) or 0.1)
	then
		return AFCombat.S.LivingGoblinCache
	end

	local MobFolder = workspace:FindFirstChild("Mobs")

	if not MobFolder then
		AFCombat.S.LivingGoblinCache = {}
		AFCombat.S.LivingGoblinCacheTime = now
		return AFCombat.S.LivingGoblinCache
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

		if not AFCombat.IsEntityInPriority(Entity.Value) then
			continue
		end

		if MobHumanoid.Health <= 0 then
			continue
		end

		table.insert(Goblins, Mob)
	end

	AFCombat.S.LivingGoblinCache = Goblins
	AFCombat.S.LivingGoblinCacheTime = now

	return Goblins
end

--// Return all mobs around the current combat group.
function AFCombat.GetNearbyCombatMobs(TargetMob)
	if not TargetMob then
		return {}
	end

	local TargetRoot = TargetMob:FindFirstChild("HumanoidRootPart")

	if not TargetRoot then
		return {}
	end

	local now = os.clock()
	local Cached = AFCombat.S.CombatGroupCache[TargetMob]

	if Cached
		and now - Cached.Time < CONFIG.COMBAT_GROUP_CACHE_INTERVAL
	then
		return Cached.Mobs
	end

	local NearbyMobs = {
		[TargetMob] = true,
	}

	local TargetPosition = TargetRoot.Position

	for Mob in AFCombat.S.ValidMobs do
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

		local Distance = AFCombatUtils.GetHorizontalDistance(TargetPosition, MobRoot.Position)

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
				or not AFCombat.IsEntityInPriority(Entity.Value)
			then
				continue
			end

			local Distance = AFCombatUtils.GetHorizontalDistance(TargetPosition, MobRoot.Position)

			if Distance <= CONFIG.GROUP_DANGER_DISTANCE then
				NearbyMobs[Mob] = true
			end
		end
	end

	local Result = {}

	for Mob in NearbyMobs do
		table.insert(Result, Mob)
	end

	AFCombat.S.CombatGroupCache[TargetMob] = {
		Time = now,
		Mobs = Result,
	}

	return Result
end

--// Return cached BladeParts for the entire combat group.
function AFCombat.GetCombatBladeParts(TargetMob)
	if not TargetMob then
		return {}
	end

	local now = os.clock()
	local Cached = AFCombat.S.CombatBladeCache[TargetMob]

	if Cached
		and now - Cached.Time < CONFIG.COMBAT_GROUP_CACHE_INTERVAL
	then
		return Cached.Parts
	end

	local BladeParts = {}

	for _, Mob in AFCombat.GetNearbyCombatMobs(TargetMob) do
		for _, BladePart in AFCombatUtils.GetBladeParts(Mob) do
			if BladePart:IsDescendantOf(workspace) then
				table.insert(BladeParts, BladePart)
			end
		end
	end

	AFCombat.S.CombatBladeCache[TargetMob] = {
		Time  = now,
		Parts = BladeParts,
	}

	return BladeParts
end

--// Checks every BladePart in the combat group.
function AFCombat.GetBladeDangerData(TargetMob)
	if not RootPart or not TargetMob then
		return Vector3.zero, math.huge, nil
	end

	local PushDirection            = Vector3.zero
	local ClosestEffectiveDistance = math.huge
	local ClosestBlade             = nil
	local DangerDistance           = AFCombatUtils.GetBladeDangerDistance()

	for _, BladePart in AFCombat.GetCombatBladeParts(TargetMob) do
		local ClosestPoint, Distance = AFCombatUtils.GetClosestPointOnBlade(BladePart, RootPart.Position)

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
function AFCombat.IsPositionSafeFromBladeGroup(Position, TargetMob)
	if not Position or not TargetMob then
		return true
	end

	local DangerDistance = AFCombatUtils.GetBladeDangerDistance()

	for _, BladePart in AFCombat.GetCombatBladeParts(TargetMob) do
		local _, Distance = AFCombatUtils.GetClosestPointOnBlade(BladePart, Position)

		if Distance <= DangerDistance then
			return false
		end
	end

	return true
end

--// Checks whether a movement line crosses a BladePart danger zone.
function AFCombat.IsPathThroughBladeGroupDanger(TargetPosition, TargetMob)
	if not RootPart or not TargetPosition or not TargetMob then
		return false
	end

	local Origin = RootPart.Position
	local Offset = TargetPosition - Origin
	local Distance = Offset.Magnitude
	local DangerDistance = AFCombatUtils.GetBladeDangerDistance()
	local BladeParts = AFCombat.GetCombatBladeParts(TargetMob)

	if Distance <= 0.01 then
		for _, BladePart in BladeParts do
			local _, BladeDistance = AFCombatUtils.GetClosestPointOnBlade(BladePart, TargetPosition)

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
			local _, BladeDistance = AFCombatUtils.GetClosestPointOnBlade(BladePart, Position)

			if BladeDistance <= DangerDistance then
				return true
			end
		end
	end

	return false
end
------------------------------------------------------------------------
--// AFFeature
--//
--// standalone behaviours: route, patrol, zones, blocking, upkeep
--//
--// 22 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------

------------------------------------------------------------------------
--// AFState  ::  character handle, player stats, shared resets
--// 9 function(s)
------------------------------------------------------------------------
--// Character
function AFFeature.updateCharacter()
	Character = Player.Character

	if not Character then
		Humanoid = nil
		RootPart = nil
		return
	end

	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	RootPart = Character:FindFirstChild("HumanoidRootPart")

	if not AFFeature.S.FaceAttachment then
		AFFeature.S.FaceAttachment = Instance.new("Attachment")
		AFFeature.S.FaceAttachment.Name = "FaceGoblinAttachment"
		AFFeature.S.FaceAttachment.Parent = RootPart
	end

	if not FaceOrientation then
		FaceOrientation = Instance.new("AlignOrientation")
		FaceOrientation.Name = "FaceGoblin"
		FaceOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		FaceOrientation.Attachment0 = AFFeature.S.FaceAttachment
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

--// PlayerStats children replicate asynchronously, so any of them can be
--// missing during the first frames after joining or respawning. Reading
--// them directly throws and kills the whole connection, so go through here.
function AFFeature.GetPlayerStatValue(Name, Default)
	local PlayerStats = Player:FindFirstChild("PlayerStats")
	local Stat = PlayerStats and PlayerStats:FindFirstChild(Name)

	if not Stat then
		return Default
	end

	return tonumber(Stat.Value) or Default
end

function AFFeature.GetPlayerLevel()
	return AFFeature.GetPlayerStatValue("Level", 0)
end

--// Toggle Screen GUI
function AFFeature.CreateToggleContainer()
end

function AFFeature.RegenStamina()
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

		--// Both values are required. Without MaxStamina there is no target
		--// value to restore, so the connection would error on every change.
		if not Stamina or not MaxStamina then
			return
		end

		AFFeature.S.StaminaConnection = Stamina:GetPropertyChangedSignal("Value"):Connect(function()
			if Stamina.Value < MaxStamina.Value then
				Stamina.Value = MaxStamina.Value
			end
		end)
	end)
end

function AFFeature.AutoRefillBooster()
	task.spawn(function()
		local PlayerStats = Player:FindFirstChild("PlayerStats")
		if not PlayerStats then
			repeat task.wait(1) until Player:FindFirstChild("PlayerStats")
			PlayerStats = Player:FindFirstChild("PlayerStats")
		end
		local ExpBoost = PlayerStats:FindFirstChild("Boost")
		local DropBoost = PlayerStats:FindFirstChild("BoostDrops")

		--// Resetting on boost-out is opt-in. The connection stays alive for the
		--// whole session, so the toggle has to be read at fire time, not here.
		local function ResetOnBoostOut(Value)
			if not Feature.ResetOnBoostOut.Enabled then
				return
			end

			if Value.Value ~= 0 then
				return
			end

			if Humanoid then
				Humanoid.Health = 0
			end
		end

		if ExpBoost then
			AFFeature.S.BoosterConnections[#AFFeature.S.BoosterConnections + 1] =
				ExpBoost:GetPropertyChangedSignal("Value"):Connect(function()
					ResetOnBoostOut(ExpBoost)
				end)
		end

		if DropBoost then
			AFFeature.S.BoosterConnections[#AFFeature.S.BoosterConnections + 1] =
				DropBoost:GetPropertyChangedSignal("Value"):Connect(function()
					ResetOnBoostOut(DropBoost)
				end)
		end
	end)
end

--// Jump only when something jumpable is actually in the way. Movement used
--// to hop on every frame of a retreat and whenever the next waypoint sat
--// higher, including on a smooth ramp where the jump did nothing but slow
--// the character down.
--// Roblox disconnects a client it considers idle. The script moves the
--// character through the Humanoid, which does not count as input, so the
--// idle timer runs even while the bot is busy. Player.Idled fires shortly
--// before the disconnect and a synthetic click clears it.
function AFFeature.SetupAntiAfk()
	local Ok, VirtualUser = pcall(function()
		return game:GetService("VirtualUser")
	end)

	if not Ok or not VirtualUser then
		return false
	end

	local function Nudge()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end

	pcall(function()
		Player.Idled:Connect(Nudge)
	end)

	--// Backstop on a timer as well, in case Idled does not fire in this
	--// environment. Far inside the twenty minute window either way.
	task.spawn(function()
		while true do
			task.wait(tonumber(CONFIG.ANTI_AFK_INTERVAL) or 480)
			AFFeature.S.LastAntiAfkTime = os.clock()
			Nudge()
		end
	end)

	return true
end

function AFFeature.GetDeadzoneEscapePosition()
	if not RootPart then
		return nil
	end

	local now = os.clock()

	if AFFeature.S.DeadzoneEscapePosition
		and now - AFFeature.S.LastDeadzoneEscapeTime < CONFIG.DEADZONE_ESCAPE_INTERVAL
	then
		return AFFeature.S.DeadzoneEscapePosition
	end

	AFFeature.S.LastDeadzoneEscapeTime = now
	AFFeature.S.DeadzoneEscapePosition = nil


	local Origin = RootPart.Position

	for Index = 1, CONFIG.DEADZONE_ESCAPE_DIRECTIONS do
		local Angle = (Index / CONFIG.DEADZONE_ESCAPE_DIRECTIONS) * math.pi * 2

		local Direction = Vector3.new(
			math.cos(Angle),
			0,
			math.sin(Angle)
		)

		local Candidate = Origin + Direction * CONFIG.DEADZONE_ESCAPE_DISTANCE

		if AFCombatUtils.IsEscapePathClear(Candidate) then
			AFFeature.S.DeadzoneEscapePosition = Candidate
			return Candidate
		end
	end

	return nil
end

function AFFeature.IsPatrolPathClear(TargetPosition)
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
	if AFCombatUtils.S.DebugFolder then
		table.insert(RaycastParams.FilterDescendantsInstances, AFCombatUtils.S.DebugFolder)
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

function AFFeature.IsPatrolPathInsideFarmArea(TargetPosition)
	if not RootPart or not TargetPosition then
		return false
	end

	local Origin = RootPart.Position
	local Offset = TargetPosition - Origin
	local HorizontalOffset = Vector3.new(Offset.X, 0, Offset.Z)

	local Distance = HorizontalOffset.Magnitude

	if Distance <= 0.01 then
		return AFCombatUtils.IsInsideFarmArea(Origin)
	end

	local Direction = HorizontalOffset.Unit
	local SampleDistance = 4

	for CurrentDistance = 0, Distance, SampleDistance do
		local SamplePosition = Origin + Direction * math.min(CurrentDistance, Distance)

		if not AFCombatUtils.IsInsideFarmArea(SamplePosition)
			or AFCombatUtils.IsInsideFarmDeadzone(SamplePosition)
		then
			return false
		end
	end

	return true
end

function AFFeature.HasPatrolEscapeSpace(Position)
	if not Position then
		return false
	end

	local Distance = CONFIG.PATROL_ESCAPE_DISTANCE
	local DirectionCount = CONFIG.PATROL_ESCAPE_DIRECTIONS

	for Index = 0, DirectionCount - 1 do
		local Angle = (math.pi * 2 / DirectionCount) * Index
		local Direction = Vector3.new(math.cos(Angle), 0, math.sin(Angle))
		local EscapePosition = Position + Direction * Distance

		if AFCombatUtils.IsInsideFarmArea(EscapePosition)
			and not AFCombatUtils.IsInsideFarmDeadzone(EscapePosition)
			and not AFCombatUtils.IsWaterAtPosition(EscapePosition)
			and AFCombatUtils.GetPatrolGroundPosition(EscapePosition)
			and AFFeature.IsPatrolPathClear(EscapePosition)
		then
			return true
		end
	end

	return false
end

function AFFeature.GetAutoPatrolPosition()
	if not RootPart then
		return nil
	end

	local now = os.clock()

	if PatrolState.PatrolPauseUntil > now then
		return nil
	end

	if PatrolState.PatrolPosition and now - PatrolState.LastPatrolCalculateTime < CONFIG.PATROL_RECALCULATE_INTERVAL then
		return PatrolState.PatrolPosition
	end

	PatrolState.LastPatrolCalculateTime = now
	PatrolState.PatrolPosition = nil

	local Origin = RootPart.Position
	--// With Ignore Farm Zone on there is no zone to stay near, so roaming is
	--// measured from where the character already is. Keeping the farm centre
	--// as the anchor would pull it back every cycle and defeat the point.
	local Center
	if Feature.IgnoreFarmZone.Enabled then
		Center = (RootPart and RootPart.Position) or Vector3.zero
	else
		Center = (PlaceConfig and PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Center)
			or (RootPart and RootPart.Position)
			or Vector3.zero
	end
	local Candidates = {}

	--// Keep some directional memory so patrol does not look like a random
	--// teleport between directions every cycle.
	local DirectionCount = CONFIG.PATROL_DIRECTIONS
	local PreviousDirection = PatrolState.PatrolDirection
	local BaseAngle = PreviousDirection
		and math.atan2(PreviousDirection.Z, PreviousDirection.X)
		or math.random() * math.pi * 2

	--// Humans tend to vary their walking distance. Do not always use the
	--// exact same radius or the exact same angle spacing.
	local Radius = math.random(
		math.floor(CONFIG.PATROL_MIN_DISTANCE),
		math.floor(CONFIG.PATROL_MAX_DISTANCE)
	)

	--// Sometimes just shuffle a few steps rather than crossing the area.
	--// Always walking a long leg is one of the more obvious tells.
	if math.random() < (tonumber(CONFIG.PATROL_SHORT_LEG_CHANCE) or 0.22) then
		Radius = math.max(
			CONFIG.PATROL_ARRIVAL_DISTANCE + 3,
			math.floor(Radius * (tonumber(CONFIG.PATROL_SHORT_LEG_SCALE) or 0.45))
		)
	end

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

		local Candidate = AFCombatUtils.GetPatrolGroundPosition(Origin + Direction * CandidateRadius)

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

			if PatrolState.PatrolLastPosition then
				local SinceLast = Vector3.new(
					Candidate.X - PatrolState.PatrolLastPosition.X,
					0,
					Candidate.Z - PatrolState.PatrolLastPosition.Z
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

		if AFFeature.IsPatrolPathInsideFarmArea(Candidate.Position)
			and AFFeature.IsPatrolPathClear(Candidate.Position)
			and AFFeature.HasPatrolEscapeSpace(Candidate.Position)
		then
			if Index == CandidateIndex or ChoiceCount == 1 then
				PatrolState.PatrolPosition = Candidate.Position
				PatrolState.PatrolDirection = Candidate.Direction
				PatrolState.PatrolLastDistance = (Candidate.Position - Origin).Magnitude
				return Candidate.Position
			end
		end
	end

	--// Fallback: use the first valid candidate if the random choice failed
	--// because one of the preferred candidates became invalid.
	for _, Candidate in ipairs(Candidates) do
		if AFFeature.IsPatrolPathInsideFarmArea(Candidate.Position)
			and AFFeature.IsPatrolPathClear(Candidate.Position)
		then
			PatrolState.PatrolPosition = Candidate.Position
			PatrolState.PatrolDirection = Candidate.Direction
			PatrolState.PatrolLastDistance = (Candidate.Position - Origin).Magnitude
			return Candidate.Position
		end
	end

	return nil
end

--// Drops everything the patrol was in the middle of. Combat outranks
--// patrolling, but the patrol state used to survive the interruption, so
--// after a fight the character could sit out a pause it had started before
--// the fight, or carry on a leg chain and a heading that no longer meant
--// anything.
function AFFeature.CancelPatrol()
	PatrolState.PatrolPosition = nil
	PatrolState.PatrolPauseUntil = 0
	PatrolState.PatrolLegsRemaining = 0
	PatrolState.PatrolHeading = nil
	PatrolState.PatrolArrivalDistance = 0
	PatrolState.PatrolCurveUntil = 0
	PatrolState.PatrolCurveBias = 0
	PatrolState.PatrolCurveRadius = 0
	PatrolState.LastPatrolCalculateTime = 0
end

function AFFeature.MoveToPatrol()
	if not Feature.AutoPatrol.Enabled or not RootPart or not Humanoid then
		PatrolState.PatrolPosition = nil
		PatrolState.PatrolPauseUntil = 0
		PatrolState.PatrolHeading = nil
		PatrolState.PatrolLegsRemaining = 0
		return false
	end

	local now = os.clock()

	--// Short natural pauses between patrol destinations.
	if PatrolState.PatrolPauseUntil > now then
		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	local Position = AFFeature.GetAutoPatrolPosition()

	if not Position then
		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	local Offset = Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	--// Stop partway now and then without abandoning the destination, the way
	--// someone pauses mid walk. Rolled on an interval rather than per frame,
	--// otherwise the odds compound into stopping constantly.
	if now - PatrolState.PatrolMidwalkRollTime >= (tonumber(CONFIG.PATROL_MIDWALK_ROLL_INTERVAL) or 1.1) then
		PatrolState.PatrolMidwalkRollTime = now

		if Distance > CONFIG.PATROL_ARRIVAL_DISTANCE * 2
			and math.random() < (tonumber(CONFIG.PATROL_MIDWALK_PAUSE_CHANCE) or 0.18)
		then
			local Low = tonumber(CONFIG.PATROL_MIDWALK_PAUSE_MIN) or 0.4
			local High = tonumber(CONFIG.PATROL_MIDWALK_PAUSE_MAX) or 1.5

			PatrolState.PatrolPauseUntil = now + Low + math.random() * math.max(0, High - Low)

			FaceOrientation.Enabled = false
			Humanoid.AutoRotate = true
			Humanoid:Move(Vector3.zero)
			return false
		end
	end

	--// Nobody stops at exactly the same distance every time.
	if PatrolState.PatrolArrivalDistance <= 0 then
		PatrolState.PatrolArrivalDistance = CONFIG.PATROL_ARRIVAL_DISTANCE
			+ math.random() * (tonumber(CONFIG.PATROL_ARRIVAL_JITTER) or 2.5)
	end

	if Distance <= PatrolState.PatrolArrivalDistance then
		PatrolState.PatrolLastPosition = Position
		PatrolState.PatrolPosition = nil
		PatrolState.LastPatrolCalculateTime = 0
		PatrolState.PatrolArrivalDistance = 0

		--// Walk several legs back to back before resting. Stopping at every
		--// single point is the giveaway; a person crossing an area passes
		--// through corners without pausing at each one.
		if PatrolState.PatrolLegsRemaining > 0 then
			PatrolState.PatrolLegsRemaining -= 1
		end

		if PatrolState.PatrolLegsRemaining > 0 then
			--// Straight on to the next leg, no pause and no reset of the
			--// smoothed aim point, so the corner is taken as a turn.
			return false
		end

		--// Vary the idle time. Occasionally make the pause a little longer,
		--// similar to someone briefly deciding where to go next.
		local Pause = math.random() * (CONFIG.PATROL_PAUSE_MAX - CONFIG.PATROL_PAUSE_MIN)
			+ CONFIG.PATROL_PAUSE_MIN

		if math.random() < 0.12 then
			Pause += math.random() * 1.5
		end

		PatrolState.PatrolPauseUntil = now + Pause
		PatrolState.PatrolLegsRemaining = math.random(
			math.max(1, tonumber(CONFIG.PATROL_LEGS_MIN) or 1),
			math.max(1, tonumber(CONFIG.PATROL_LEGS_MAX) or 4)
		)

		--// A rest ends the chain, so the next leg starts from a fresh bearing
		--// rather than curving out of a direction it is no longer walking.
		PatrolState.PatrolHeading = nil
		PatrolState.PatrolCurveUntil = 0
		PatrolState.PatrolCurveBias = 0
		PatrolState.PatrolCurveRadius = 0

		FaceOrientation.Enabled = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	if not AFCombatUtils.IsInsideFarmArea(RootPart.Position) or AFCombatUtils.IsInsideFarmDeadzone(RootPart.Position) then
		PatrolState.PatrolPosition = nil
		PatrolState.LastPatrolCalculateTime = 0
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	if not AFFeature.IsPatrolPathInsideFarmArea(Position) then
		PatrolState.PatrolPosition = nil
		PatrolState.LastPatrolCalculateTime = 0
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	FaceOrientation.Enabled = false
	Humanoid.AutoRotate = true

	--// Switching destinations outright makes the character snap round on the
	--// spot. Walking at a point that eases toward the real destination turns
	--// that into a curve, which is also how a person changes direction.
	if PatrolState.PatrolLegsRemaining <= 0 then
		PatrolState.PatrolLegsRemaining = math.random(
			math.max(1, tonumber(CONFIG.PATROL_LEGS_MIN) or 1),
			math.max(1, tonumber(CONFIG.PATROL_LEGS_MAX) or 4)
		)
	end

	local SnapDistance = tonumber(CONFIG.PATROL_SMOOTH_SNAP_DISTANCE) or 7
	local Desired = Vector3.new(Offset.X, 0, Offset.Z)

	--// Close in, or with no bearing yet, walk straight at it. Steering near
	--// the destination would only orbit it.
	if Distance <= SnapDistance or Desired.Magnitude <= 0.01 then
		PatrolState.PatrolHeading = Desired.Magnitude > 0.01 and Desired.Unit or PatrolState.PatrolHeading
		PatrolState.PatrolSteerTime = now
		Humanoid:MoveTo(Position)
		return true
	end

	Desired = Desired.Unit

	--// Time step for the sweep and the steering below. Clamped so a frame
	--// spike cannot swing the bearing in one go. Taken before either uses it.
	local Delta = math.clamp(now - PatrolState.PatrolSteerTime, 0, 0.25)
	PatrolState.PatrolSteerTime = now

	--// Now and then walk an arc instead of the straight bearing, described by
	--// the radius it is walked at. Radius is the part that shows: a small one
	--// loops tightly, a large one is barely a drift. The turn rate that holds
	--// a radius is speed over radius, so the shape survives any walk speed
	--// rather than changing with it.
	if now - PatrolState.PatrolCurveRollTime >= (tonumber(CONFIG.PATROL_RANDOM_CURVE_ROLL_INTERVAL) or 2.6) then
		PatrolState.PatrolCurveRollTime = now

		if now >= PatrolState.PatrolCurveUntil
			and math.random() < (tonumber(CONFIG.PATROL_RANDOM_CURVE_CHANCE) or 0.22)
		then
			local MinRadius = math.max(1, tonumber(CONFIG.PATROL_CURVE_RADIUS_MIN) or 12)
			local MaxRadius = math.max(MinRadius, tonumber(CONFIG.PATROL_CURVE_RADIUS_MAX) or 55)
			local MinTime = tonumber(CONFIG.PATROL_RANDOM_CURVE_MIN_TIME) or 1.2
			local MaxTime = tonumber(CONFIG.PATROL_RANDOM_CURVE_MAX_TIME) or 2.5

			PatrolState.PatrolCurveRadius = MinRadius + math.random() * (MaxRadius - MinRadius)
			PatrolState.PatrolCurveSide = math.random(0, 1) == 0 and -1 or 1
			PatrolState.PatrolCurveUntil = now + MinTime + math.random() * math.max(0, MaxTime - MinTime)
			PatrolState.PatrolCurveBias = 0
		end
	end

	local CurveRadius = math.max(tonumber(PatrolState.PatrolCurveRadius) or 0, 0)
	local CurveBias = tonumber(PatrolState.PatrolCurveBias) or 0
	local MaxSweep = math.rad(tonumber(CONFIG.PATROL_CURVE_MAX_SWEEP) or 48)
	local Speed = math.max(Humanoid.WalkSpeed, 1)

	if now < PatrolState.PatrolCurveUntil and CurveRadius > 0 then
		--// Capped, so a long curve bends the route instead of closing it
		--// into a circle.
		CurveBias = math.clamp(
			CurveBias + (Speed / CurveRadius) * Delta * (PatrolState.PatrolCurveSide or 1),
			-MaxSweep,
			MaxSweep
		)
	elseif CurveBias ~= 0 then
		--// Unwind at the rate it was wound on, so the route eases back onto
		--// the bearing rather than snapping straight.
		local Unwind = (Speed / math.max(CurveRadius, 1)) * Delta

		if math.abs(CurveBias) <= Unwind then
			CurveBias = 0
			PatrolState.PatrolCurveRadius = 0
		else
			CurveBias -= Unwind * (CurveBias > 0 and 1 or -1)
		end
	end

	PatrolState.PatrolCurveBias = CurveBias

	if CurveBias ~= 0 then
		local Biased = CFrame.fromAxisAngle(Vector3.yAxis, CurveBias):VectorToWorldSpace(Desired)
		Biased = Vector3.new(Biased.X, 0, Biased.Z)

		if Biased.Magnitude > 0.01 then
			Desired = Biased.Unit
		end
	end

	if not PatrolState.PatrolHeading then
		PatrolState.PatrolHeading = Desired
	end

	--// Turn the heading toward the new bearing at a limited rate. Walking at
	--// a point a short way along that heading is what draws the arc: the
	--// character leans into the turn instead of rotating on the spot.

	local Dot = math.clamp(PatrolState.PatrolHeading:Dot(Desired), -1, 1)
	local Angle = math.acos(Dot)

	if Angle > math.rad(tonumber(CONFIG.PATROL_CURVE_MIN_ANGLE) or 12) then
		--// Sign of the Y component of the cross product gives the turn side.
		local Side = PatrolState.PatrolHeading:Cross(Desired).Y < 0 and -1 or 1
		local MaxStep = math.rad(tonumber(CONFIG.PATROL_TURN_RATE) or 150) * Delta
		local Step = math.min(Angle, MaxStep) * Side

		local Turned = CFrame.fromAxisAngle(Vector3.yAxis, Step):VectorToWorldSpace(PatrolState.PatrolHeading)
		Turned = Vector3.new(Turned.X, 0, Turned.Z)

		if Turned.Magnitude > 0.01 then
			PatrolState.PatrolHeading = Turned.Unit
		end
	else
		--// Near enough to straight: stop steering and commit to the bearing.
		PatrolState.PatrolHeading = Desired
	end

	local Aim = RootPart.Position + PatrolState.PatrolHeading * math.min(
		tonumber(CONFIG.PATROL_LOOKAHEAD) or 11,
		Distance
	)

	--// The arc must not curve into ground the patrol is not allowed on. If it
	--// would, give up the curve for this frame and head straight at the
	--// destination, which is already known to be valid.
	if not AFCombatUtils.IsInsideFarmArea(Aim) or AFCombatUtils.IsInsideFarmDeadzone(Aim) then
		PatrolState.PatrolHeading = Desired
		Humanoid:MoveTo(Position)
		return true
	end

	Humanoid:MoveTo(Aim)

	return true
end

function AFFeature.GetFarmReturnPosition()
	if not RootPart or Feature.IgnoreFarmZone.Enabled or not PlaceConfig then
		return nil
	end

	local now = os.clock()

	if AFFeature.S.FarmReturnPosition
		and now - AFFeature.S.LastFarmReturnCalculateTime < CONFIG.FARM_RETURN_RECALCULATE_INTERVAL
	then
		return AFFeature.S.FarmReturnPosition
	end

	AFFeature.S.LastFarmReturnCalculateTime = now
	local PreviousReturnPosition = AFFeature.S.FarmReturnPosition
	AFFeature.S.FarmReturnPosition = nil

	local FarmCenter = (PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Center) or RootPart.Position
	local Origin = RootPart.Position
	local Candidates = {}

	--// Return to a randomized point 10-20 studs away from the farm center.
	--// This prevents the character from repeatedly standing on the same spot.
	for Index = 1, CONFIG.FARM_RETURN_CANDIDATES do
		local Angle = math.random() * math.pi * 2
		local Radius = CONFIG.FARM_RETURN_RADIUS_MIN
			+ math.random() * (CONFIG.FARM_RETURN_RADIUS_MAX - CONFIG.FARM_RETURN_RADIUS_MIN)
		local Offset = Vector3.new(
			math.cos(Angle) * Radius,
			0,
			math.sin(Angle) * Radius
		)

		local Candidate = AFCombatUtils.GetPatrolGroundPosition(FarmCenter + Offset)

		if Candidate
			and AFCombatUtils.IsInsideFarmArea(Candidate)
			and not AFCombatUtils.IsInsideFarmDeadzone(Candidate)
		then
			table.insert(Candidates, Candidate)
		end
	end

	if #Candidates > 0 then
		--// Prefer a point that is not almost identical to the previous return spot.
		local Filtered = {}
		for _, Candidate in ipairs(Candidates) do
			if not PreviousReturnPosition
				or (Candidate - PreviousReturnPosition).Magnitude >= CONFIG.FARM_RETURN_MIN_SPREAD
			then
				table.insert(Filtered, Candidate)
			end
		end

		if #Filtered > 0 then
			Candidates = Filtered
		end

		AFFeature.S.FarmReturnPosition = Candidates[math.random(1, #Candidates)]
		return AFFeature.S.FarmReturnPosition
	end

	return nil
end

function AFFeature.MoveBackToFarmZone()
	if not Feature.ReturnToFarmZone.Enabled or not RootPart or not Humanoid then
		AFFeature.S.FarmReturnPosition = nil
		return false
	end

	if Feature.IgnoreFarmZone.Enabled then
		AFFeature.S.FarmReturnPosition = nil
		return false
	end

	local FarmCenter = (PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Center) or RootPart.Position
	local CenterOffset = RootPart.Position - FarmCenter
	local CenterDistance = Vector3.new(CenterOffset.X, 0, CenterOffset.Z).Magnitude

	--// Stop returning once we are close enough to the farm centre.
	if CenterDistance <= CONFIG.FARM_RETURN_CENTER_DISTANCE then
		AFFeature.S.FarmReturnPosition = nil
		AFFeature.S.LastFarmReturnCalculateTime = 0
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero)
		return false
	end

	--// No sampled point inside the zone passed its checks. Heading for the
	--// centre is still better than the old answer, which was to stand
	--// outside the zone doing nothing.
	local Position = AFFeature.GetFarmReturnPosition() or FarmCenter

	local Offset = Position - RootPart.Position
	local Distance = Vector3.new(Offset.X, 0, Offset.Z).Magnitude

	if Distance <= CONFIG.FARM_RETURN_ARRIVAL_DISTANCE then
		AFFeature.S.FarmReturnPosition = nil
		AFFeature.S.LastFarmReturnCalculateTime = 0
		return false
	end

	FaceOrientation.Enabled = false

	--// Straight line first, since it is free. If something is in the way,
	--// route around it rather than pressing into the obstacle.
	if AFCombatUtils.IsPathClear(Position) then
		Humanoid.AutoRotate = true
		Humanoid:MoveTo(Position)
		return true
	end

	if CenterDistance <= CONFIG.FARM_RETURN_PATH_DISTANCE
		and AFCombatUtils.MoveAlongPathTo(Position, true)
	then
		return true
	end

	--// Pathfinding refused as well. Keep walking at the target anyway; the
	--// stuck check and the jump will usually free the character.
	Humanoid.AutoRotate = true
	Humanoid:MoveTo(Position)
	return true
end

function AFFeature.HandleDeadzoneEscape()
	if Feature.IgnoreFarmZone.Enabled then
		AFFeature.S.DeadzoneEscapePosition = nil

		return false
	end

	if not RootPart or not Humanoid then
		return false
	end

	if not AFCombatUtils.IsInsideFarmDeadzone(RootPart.Position) then
		AFFeature.S.DeadzoneEscapePosition = nil


		return false
	end

	local EscapePosition = AFFeature.GetDeadzoneEscapePosition()

	if EscapePosition then
		Humanoid:MoveTo(EscapePosition)
		return true
	end

	return false
end

------------------------------------------------------------------------
--// AFSession  ::  server hop and player blocking
--// 3 function(s)
------------------------------------------------------------------------
--// Teleport
function AFFeature.TeleportToPlace(placeId: number?)
	local TeleportService = game:GetService("TeleportService")

	TeleportService:Teleport(placeId or game.PlaceId, Player)
end

--// Block
--// UserIds are compared as strings because the whitelist is typed in by
--// hand, and a textbox gives back text.
function AFFeature.NormalizeUserId(Value)
	local Text = tostring(Value or ""):gsub("%s+", "")

	if Text == "" or not Text:match("^%d+$") then
		return nil
	end

	return Text
end

function AFFeature.IsWhitelisted(userId)
	local Id = AFFeature.NormalizeUserId(userId)

	if not Id then
		return false
	end

	for _, Entry in ipairs(CONFIG.BLOCK_WHITELIST or {}) do
		if AFFeature.NormalizeUserId(Entry) == Id then
			return true
		end
	end

	return false
end

function AFFeature.isBlocked(userId)
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

function AFFeature.promptBlockPlayer(plr)
	local userId = plr.UserId

	if AFFeature.S.BlockCache[userId] then
		return
	end

	if AFFeature.isBlocked(userId) then
		return
	end

	AFFeature.S.BlockCache[userId] = true

	local success, err = pcall(function()
		StarterGui:SetCore("PromptBlockPlayer", plr)
	end)

	if not success then
		warn("PromptBlockPlayer failed:", err)
		AFFeature.S.BlockCache[userId] = nil
		return
	end

	task.delay(CONFIG.BLOCK_COOLDOWN, function()
		AFFeature.S.BlockCache[userId] = nil
	end)
end
------------------------------------------------------------------------
--// AFUI
--//
--// tabs, controls, status readouts
--//
--// 26 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------

------------------------------------------------------------------------
--// AFUI  ::  tabs, controls, status readouts
--// 25 function(s)
------------------------------------------------------------------------
function AFUI.CreateFeature(Name, Default, Callback)
	local Component = UIRef.FeatureSection:AddToggle(Name, Default, Callback)

	return Component
end

function AFUI.SetFeatureComponent(Name, Value)
	local Data = Feature[Name]

	if Data and Data.Button then
		Data.Button:Set(Value, false)
	end
end

--// Picker of everyone currently in the server, built the same way as the
--// enemy target dropdown. The label carries the display name so it can be
--// recognised, and the UserId is looked up from it on selection, since the
--// whitelist stores ids rather than names.
function AFUI.RefreshWhitelistPlayerDropdown()
	if not UIRef.BlockSection then
		return
	end

	table.clear(UIRef.WhitelistPlayerOptions)

	local Options = {}

	for _, Other in ipairs(Players:GetPlayers()) do
		if Other ~= Player and not AFFeature.IsWhitelisted(Other.UserId) then
			local Label = string.format("%s (@%s)  %d", Other.DisplayName, Other.Name, Other.UserId)

			UIRef.WhitelistPlayerOptions[Label] = tostring(Other.UserId)
			table.insert(Options, Label)
		end
	end

	table.sort(Options, function(A, B)
		return string.lower(A) < string.lower(B)
	end)

	if #Options == 0 then
		Options = { "No other players" }
	end

	if UIRef.WhitelistPlayerDropdown then
		if UIRef.WhitelistPlayerDropdown.Popup then
			UIRef.WhitelistPlayerDropdown.Popup:Destroy()
		end

		if UIRef.WhitelistPlayerDropdown.Frame then
			UIRef.WhitelistPlayerDropdown.Frame:Destroy()
		end
	end

	UIRef.WhitelistPlayerDropdown = UIRef.BlockSection:AddDropdown(
		"Add Player In Server",
		Options,
		function(Value)
			local Id = UIRef.WhitelistPlayerOptions[Value]

			if not Id then
				return
			end

			if AFFeature.IsWhitelisted(Id) then
				return
			end

			UIRef.BlockWhitelistComponent:Add(Id)
			CONFIG.BLOCK_WHITELIST = UIRef.BlockWhitelistComponent.Priority
			AFProfile.SaveActiveProfile()
			NotifyAction("Whitelist", "Added " .. tostring(Value))
			AFUI.RefreshWhitelistPlayerDropdown()
		end
	)
end

function AFUI.RefreshTargetDropdown()
	AFCombat.S.DetectedEntities = AFCombat.GetDetectedEnemyEntities()

	local Options = {}

	for _, Name in ipairs(AFCombat.S.DetectedEntities) do
		if not AFCombat.IsEntityInPriority(Name) then
			table.insert(Options, Name)
		end
	end

	if #Options == 0 then
		Options = {"No detected enemies"}
	end

	if UIRef.TargetDropdown then
		if UIRef.TargetDropdown.Popup then
			UIRef.TargetDropdown.Popup:Destroy()
		end

		if UIRef.TargetDropdown.Frame then
			UIRef.TargetDropdown.Frame:Destroy()
		end
	end

	UIRef.TargetDropdown = UIRef.TargetSection:AddDropdown("Add Target", Options, function(Value)
		AFUI.S.AddPriorityTarget(Value)
	end)
end

function AFUI.SyncPriorityState(RefreshDropdown)
	CONFIG.TARGET_ENTITY_PRIORITY = UIRef.PriorityComponent.Priority
	AFCombat.ResetTargetState()

	if RefreshDropdown then
		AFUI.RefreshTargetDropdown()
	end

	AFProfile.SaveActiveProfile()
end

--// Utility UI status helpers
function AFUI.updateFeatureButtons()
	--// Called from every path that loads, creates, imports or deletes a
	--// profile, so the two new controls are resynced from here rather than
	--// repeating the call at each of those sites.
	--// SetState resolves every count through the bound inventory, so no
	--// separate refresh is needed here any more.
	if UIRef.PinPanel and type(CONFIG.PINNED_STATE) == "table" then
		UIRef.PinPanel:SetState(CONFIG.PINNED_STATE)
	end

	if UIRef.ExecuteChargeSlider then
		UIRef.ExecuteChargeSlider:Set(
			math.clamp(tonumber(CONFIG.EXECUTE_CHARGE_HP_PERCENT) or 0, 0, 90),
			false
		)
	end

	if UIRef.TargetTypeDropdown then
		UIRef.TargetTypeDropdown:Set(tostring(CONFIG.TARGET_HP_MODE or "Disabled"), false)
	end

	if UIRef.BlockWhitelistComponent then
		UIRef.BlockWhitelistComponent:SetPriority(table.clone(CONFIG.BLOCK_WHITELIST or {}))
		CONFIG.BLOCK_WHITELIST = UIRef.BlockWhitelistComponent.Priority
		AFUI.RefreshWhitelistPlayerDropdown()
	end

	AFUI.SetFeatureComponent("AutoFarm", AFFeature.S.Enabled)
	AFUI.SetFeatureComponent("AutoBlock", Feature.AutoBlock.Enabled)
	AFUI.SetFeatureComponent("SafeCombat", Feature.SafeCombat.Enabled)
	AFUI.SetFeatureComponent("AutoSkill", Feature.AutoSkill.Enabled)
	AFUI.SetFeatureComponent("AutoFind", Feature.AutoFind.Enabled)
	AFUI.SetFeatureComponent("IgnoreFarmZone", Feature.IgnoreFarmZone.Enabled)
	AFUI.SetFeatureComponent("AutoPatrol", Feature.AutoPatrol.Enabled)
	AFUI.SetFeatureComponent("ReturnToFarmZone", Feature.ReturnToFarmZone.Enabled)
	AFUI.SetFeatureComponent("ResetOnBoostOut", Feature.ResetOnBoostOut.Enabled)
	if Feature.DebugWaypoints.Button then Feature.DebugWaypoints.Button:Set(Feature.DebugWaypoints.Enabled, false) end
	if Feature.DebugFarmZones.Button then Feature.DebugFarmZones.Button:Set(Feature.DebugFarmZones.Enabled, false) end
	if Feature.DebugDeadzones.Button then Feature.DebugDeadzones.Button:Set(Feature.DebugDeadzones.Enabled, false) end
	if Feature.DebugRadiusLabels.Button then Feature.DebugRadiusLabels.Button:Set(Feature.DebugRadiusLabels.Enabled, false) end
end

function AFUI.updateButton()
	Feature.AutoFarm.Enabled = AFFeature.S.Enabled
	AFUI.SetFeatureComponent("AutoFarm", AFFeature.S.Enabled)
end

function AFUI.FormatVector3(Position)
	if typeof(Position) ~= "Vector3" then
		return "0, 0, 0"
	end

	return string.format("%.1f, %.1f, %.1f", Position.X, Position.Y, Position.Z)
end

function AFUI.BuildWaypointLabels()
	local Labels = {}

	for Index, Position in ipairs(PlaceConfig.WAYPOINTS or {}) do
		Labels[Index] = string.format("#%d  (%s)", Index, AFUI.FormatVector3(Position))
	end

	return Labels
end

function AFUI.BuildZoneLabels(Zones, Prefix)
	local Labels = {}

	for Index, Zone in ipairs(Zones or {}) do
		Labels[Index] = string.format(
			"#%d  R:%g  (%s)",
			Index,
			tonumber(Zone.Radius) or 0,
			AFUI.FormatVector3(Zone.Center)
		)
	end

	return Labels
end

function AFUI.ReplacePriorityList(Component, Values)
	if not Component then
		return
	end

	Component:SetPriority(Values)
end

function AFUI.RefreshWaypointList()
	AFUI.ReplacePriorityList(UIRef.WaypointListComponent, AFUI.BuildWaypointLabels())
end

function AFUI.RefreshFarmZoneList()
	AFUI.ReplacePriorityList(
		UIRef.FarmZoneListComponent,
		AFUI.BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm")
	)
end

function AFUI.RefreshDeadzoneList()
	AFUI.ReplacePriorityList(
		UIRef.DeadzoneListComponent,
		AFUI.BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone")
	)
end

function AFUI.GetZonePickerOptions(Zones, Prefix)
	local Options = {}

	for Index in ipairs(Zones or {}) do
		table.insert(Options, string.format("#%d", Index))
	end

	if #Options == 0 then
		Options = {"No " .. Prefix .. " Zones"}
	end

	return Options
end

function AFUI.RefreshFarmZonePicker()
	local Options = AFUI.GetZonePickerOptions(PlaceConfig.FARM_ZONES, "Farm")

	if UIRef.FarmZonePicker then
		if UIRef.FarmZonePicker.Popup then UIRef.FarmZonePicker.Popup:Destroy() end
		if UIRef.FarmZonePicker.Frame then UIRef.FarmZonePicker.Frame:Destroy() end
	end

	AFProfile.S.SelectedFarmZoneIndex = math.clamp(AFProfile.S.SelectedFarmZoneIndex, 1, math.max(1, #PlaceConfig.FARM_ZONES))
	local SelectedOption = Options[AFProfile.S.SelectedFarmZoneIndex] or Options[1]

	UIRef.FarmZonePicker = UIRef.ZoneSection:AddDropdown("Edit Farm Zone", Options, function(Value)
		if Value == "No Farm Zones" then return end
		local Index = table.find(Options, Value)
		if not Index or not PlaceConfig.FARM_ZONES[Index] then return end

		AFProfile.S.SelectedFarmZoneIndex = Index
		UIRef.FarmRadiusSlider:Set(tonumber(PlaceConfig.FARM_ZONES[Index].Radius) or 100, false)
	end)

	if SelectedOption then UIRef.FarmZonePicker:Set(SelectedOption) end
end

function AFUI.RefreshDeadzonePicker()
	local Options = AFUI.GetZonePickerOptions(PlaceConfig.DEADZONES, "Deadzone")

	if UIRef.DeadzonePicker then
		if UIRef.DeadzonePicker.Popup then UIRef.DeadzonePicker.Popup:Destroy() end
		if UIRef.DeadzonePicker.Frame then UIRef.DeadzonePicker.Frame:Destroy() end
	end

	AFProfile.S.SelectedDeadzoneIndex = math.clamp(AFProfile.S.SelectedDeadzoneIndex, 1, math.max(1, #PlaceConfig.DEADZONES))
	local SelectedOption = Options[AFProfile.S.SelectedDeadzoneIndex] or Options[1]

	UIRef.DeadzonePicker = UIRef.ZoneSection:AddDropdown("Edit Deadzone", Options, function(Value)
		if Value == "No Deadzone Zones" then return end
		local Index = table.find(Options, Value)
		if not Index or not PlaceConfig.DEADZONES[Index] then return end

		AFProfile.S.SelectedDeadzoneIndex = Index
		UIRef.DeadzoneRadiusSlider:Set(tonumber(PlaceConfig.DEADZONES[Index].Radius) or 35, false)
	end)

	if SelectedOption then UIRef.DeadzonePicker:Set(SelectedOption) end
end

function AFUI.SetProfileStatus(Text)
	if UIRef.ProfileStatusLabel then
		UIRef.ProfileStatusLabel.Text = "STATUS:  " .. tostring(Text)
	end
end

function AFUI.GetCurrentProfileNames()
	local Names = AFProfile.GetProfileNames()

	--// Default Config is always available for the current PlaceId.
	--// It is read-only and is not stored inside ProfileStore.Profiles.
	table.insert(Names, 1, "Default Config")

	return Names
end

function AFUI.RefreshProfileDropdown()
	local Options = AFUI.GetCurrentProfileNames()

	if UIRef.ProfileDropdown then
		if UIRef.ProfileDropdown.Popup then
			UIRef.ProfileDropdown.Popup:Destroy()
		end

		if UIRef.ProfileDropdown.Frame then
			UIRef.ProfileDropdown.Frame:Destroy()
		end
	end

	UIRef.ProfileDropdown = UIRef.ProfilesSection:AddDropdown(
		"Profile",
		Options,
		function(Value)
			if Value == "Default Config" then
				AFProfile.ApplyDefaultPlaceConfig()
				UIRef.ProfileNameBox:Set("")
				UIRef.ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
				UIRef.FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
				UIRef.DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
				UIRef.RetreatHealthSlider:Set(CONFIG.RETREAT_HEALTH_PERCENT, false)
				UIRef.AutoHealHealthSlider:Set(CONFIG.AUTO_HEAL_HEALTH_PERCENT, false)
				UIRef.SafeEnemyRangeSlider:Set(CONFIG.SAFE_ENEMY_RANGE, false)
				AFUI.RefreshWaypointList()
				AFUI.RefreshFarmZoneList()
				AFUI.RefreshDeadzoneList()
				AFUI.RefreshFarmZonePicker()
				AFUI.RefreshDeadzonePicker()
				UIRef.PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY))
				AFUI.updateFeatureButtons()
				AFUI.RefreshTargetDropdown()
				AFCombat.ResetTargetState()
				AFDebug.UpdateDebugVisualizer()
				AFUI.SetProfileStatus("DEFAULT CONFIG (READ-ONLY)")
				return
			end

			if AFProfile.LoadProfile(Value) then
				UIRef.ProfileNameBox:Set(Value)
				UIRef.ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
				UIRef.FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
				UIRef.DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
				UIRef.RetreatHealthSlider:Set(CONFIG.RETREAT_HEALTH_PERCENT, false)
				UIRef.AutoHealHealthSlider:Set(CONFIG.AUTO_HEAL_HEALTH_PERCENT, false)
				UIRef.SafeEnemyRangeSlider:Set(CONFIG.SAFE_ENEMY_RANGE, false)
				AFUI.RefreshWaypointList()
				AFUI.RefreshFarmZoneList()
				AFUI.RefreshDeadzoneList()
				AFUI.RefreshFarmZonePicker()
				AFUI.RefreshDeadzonePicker()
				Feature.AutoBlock.Enabled = AFFeature.S.BlockEnabled
				UIRef.PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY))
				AFUI.updateFeatureButtons()
				AFUI.RefreshTargetDropdown()
				AFCombat.ResetTargetState()
				AFDebug.UpdateDebugVisualizer()
				AFUI.SetProfileStatus("LOADED " .. Value)
			else
				AFUI.SetProfileStatus("LOAD FAILED")
			end
		end
	)

	if AFProfile.S.ActiveProfileName and table.find(Options, AFProfile.S.ActiveProfileName) then
		UIRef.ProfileDropdown:Set(AFProfile.S.ActiveProfileName, false)
	else
		UIRef.ProfileDropdown:Set("Default Config", false)
	end
end

--// UI stats
function AFUI.neededExp(lvl)
	lvl = lvl - 1

	local total = 9

	for i = 1, lvl do
		total = total + (6 * (i + 2))
	end

	return total
end

function AFUI.GetItem(String, ItemName)
	for Item in string.gmatch(String, "([^,]+)") do
		local Name, Amount = string.match(Item, "([^|]+)|(.+)")

		if Name == ItemName then
			return Name, tonumber(Amount) or 0
		end
	end

	return ItemName, 0
end

function AFUI.updateEventCurrency()
	local PlayerStats = Player:FindFirstChild("PlayerStats")

	if not PlayerStats then
		AFUI.S.EventCurrency = 0
		UIRef.EventCurrencyLabel.Text = "EVENT CURRENCY  0"
		UIRef.ExpLabel.Text = "EXP            0/0"
		AFUI.S.LastInventory = nil
		return
	end

	local PlayerLvl = PlayerStats:FindFirstChild("Level")
	local PlayerExp = PlayerStats:FindFirstChild("EXP")

	if PlayerLvl and PlayerExp then
		UIRef.ExpLabel.Text = "EXP            " .. PlayerExp.Value .. "/" .. AFUI.neededExp(PlayerLvl.Value)
	else
		UIRef.ExpLabel.Text = "EXP            0/0"
	end

	local Inventory = PlayerStats:FindFirstChild("Inventory")

	if not Inventory then
		AFUI.S.EventCurrency = 0
		UIRef.EventCurrencyLabel.Text = "EVENT CURRENCY  0"
		return
	end

	local InventoryValue = Inventory.Value

	if InventoryValue == AFUI.S.LastInventory then
		return
	end

	AFUI.S.LastInventory = InventoryValue

	local _, Amount = AFUI.GetItem(InventoryValue, AFUI.S.TargetCurrency)

	AFUI.S.EventCurrency = Amount
	UIRef.EventCurrencyLabel.Text = "EVENT CURRENCY  " .. tostring(AFUI.S.EventCurrency)
end

function AFUI.updatePlayTime()
	local ServerAge = math.floor(workspace.DistributedGameTime)

	local Hours   = math.floor(ServerAge / 3600)
	local Minutes = math.floor((ServerAge % 3600) / 60)
	local Seconds = ServerAge % 60

	UIRef.ServerAgeLabel.Text = "PLAY TIME      " .. string.format("%02d:%02d:%02d", Hours, Minutes, Seconds)
end

function AFUI.updatePosition()
	if RootPart then
		local Position = RootPart.Position

		UIRef.PositionLabel.Text = string.format(
			"POSITION       %.1f, %.1f, %.1f",
			Position.X,
			Position.Y,
			Position.Z
		)
	else
		UIRef.PositionLabel.Text = "POSITION       --"
	end
end

--// Refresh the dropdown whenever the mob set changes.
--// Subscribes the picker to the mob watcher. Assigned here rather than
--// called from there, so the dependency runs UI -> Combat only.
AFCombat.OnMobSetChanged = function()
	AFUI.RefreshEnemyPicker()
end

function AFUI.RefreshEnemyPicker()
	AFUI.RefreshTargetDropdown()
end
------------------------------------------------------------------------
--// AFDebug
--//
--// in-world waypoint and zone visualiser
--//
--// 10 function(s). Definitions only; nothing here runs
--// at load time.
------------------------------------------------------------------------

------------------------------------------------------------------------
--// AFDebug  ::  in-world waypoint and zone visualiser
--// 10 function(s)
------------------------------------------------------------------------
--// ============================================================
--// DEBUG VISUALIZER
--// ============================================================
function AFDebug.GetDebugAdorneeParent()
	if not AFCombatUtils.S.DebugFolder then
		AFCombatUtils.S.DebugFolder = Instance.new("Folder")
		AFCombatUtils.S.DebugFolder.Name = "AutoFarmDebug"
		AFCombatUtils.S.DebugFolder.Parent = workspace
	end

	return AFCombatUtils.S.DebugFolder
end

function AFDebug.SetDebugVisualizerVisible(Visible)
	if not AFCombatUtils.S.DebugFolder then
		return
	end

	AFCombatUtils.S.DebugFolder.Parent = Visible and workspace or nil
end

function AFDebug.CreateDebugZone(Name, Center, Radius, Color, ZoneType, Index)
	if not Center or not Radius or Radius <= 0 then
		return nil
	end

	local ZoneFolder = Instance.new("Folder")
	ZoneFolder.Name = Name
	ZoneFolder.Parent = AFDebug.GetDebugAdorneeParent()

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

function AFDebug.CreateDebugWaypoint(Index, Position)
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
	MarkerPart.Parent = AFDebug.GetDebugAdorneeParent()

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

	AFDebug.S.DebugWaypointData[Index] = {
		MarkerPart = MarkerPart,
		Billboard = Billboard,
		Accent = Accent,
		Label = Label,
		State = State,
		Visited = false,
		NextBeam = nil,
		Arrow = nil,
	}

	return AFDebug.S.DebugWaypointData[Index]
end

function AFDebug.CreateDebugWaypointLink(Index, FromData, ToData)
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
		Arrow.Parent = AFDebug.GetDebugAdorneeParent()

		FromData.Arrow = Arrow
	end

	FromData.NextBeam = Beam
end

function AFDebug.ResetDebugWaypoints()
	for _, Data in AFDebug.S.DebugWaypointData do
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

function AFDebug.UpdateDebugWaypointColors()
	for Index, Data in AFDebug.S.DebugWaypointData do
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
	for Index = 1, #AFDebug.S.DebugWaypointData - 1 do
		AFDebug.CreateDebugWaypointLink(Index, AFDebug.S.DebugWaypointData[Index], AFDebug.S.DebugWaypointData[Index + 1])
	end

	if AFDebug.S.DebugWaypointData[#AFDebug.S.DebugWaypointData] then
		local LastData = AFDebug.S.DebugWaypointData[#AFDebug.S.DebugWaypointData]
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

function AFDebug.DestroyDebugZones()
	AFDebug.S.DebugZoneSignature = nil

	if AFDebug.S.DebugFarmZone then
		AFDebug.S.DebugFarmZone:Destroy()
		AFDebug.S.DebugFarmZone = nil
	end

	if AFDebug.S.DebugDeadzone then
		AFDebug.S.DebugDeadzone:Destroy()
		AFDebug.S.DebugDeadzone = nil
	end
end

function AFDebug.RebuildDebugZones()
	if not PlaceConfig then
		AFDebug.DestroyDebugZones()
		return
	end

	--// Rebuild all farm/dead zones. Profiles can contain multiple zones.
	if AFDebug.S.DebugFarmZone then
		AFDebug.S.DebugFarmZone:Destroy()
		AFDebug.S.DebugFarmZone = nil
	end

	if AFDebug.S.DebugDeadzone then
		AFDebug.S.DebugDeadzone:Destroy()
		AFDebug.S.DebugDeadzone = nil
	end

	AFDebug.S.DebugZoneSignature = nil

	local ZoneContainer = AFDebug.GetDebugAdorneeParent()

	local FarmZonesFolder = Instance.new("Folder")
	FarmZonesFolder.Name = "FarmZones"
	FarmZonesFolder.Parent = ZoneContainer

	if Feature.DebugFarmZones.Enabled then
		for Index, Zone in ipairs(PlaceConfig.FARM_ZONES or {}) do
			local ZoneFolder = AFDebug.CreateDebugZone(
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
			local ZoneFolder = AFDebug.CreateDebugZone(
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

	AFDebug.S.DebugFarmZone = FarmZonesFolder
	AFDebug.S.DebugDeadzone = DeadzonesFolder
	AFDebug.S.DebugZoneSignature = "MULTI|" .. tostring(#(PlaceConfig.FARM_ZONES or {})) .. "|" .. tostring(#(PlaceConfig.DEADZONES or {}))
end

function AFDebug.UpdateDebugVisualizer()
	if not PlaceConfig or not Feature.DebugVisualizer.Enabled then
		AFDebug.SetDebugVisualizerVisible(false)
		return
	end

	AFDebug.GetDebugAdorneeParent()

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

	if AFDebug.S.DebugWaypointSignature ~= CurrentWaypointSignature
		or #AFDebug.S.DebugWaypointData ~= WaypointCount
	then
		for _, Data in AFDebug.S.DebugWaypointData do
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

		table.clear(AFDebug.S.DebugWaypointData)
		AFDebug.S.DebugWaypointSignature = nil

		if Feature.DebugWaypoints.Enabled then
			for Index, Position in ipairs(PlaceConfig.WAYPOINTS) do
				AFDebug.CreateDebugWaypoint(Index, Position)
			end
		end

		AFDebug.S.DebugWaypointSignature = CurrentWaypointSignature
	end

	AFDebug.RebuildDebugZones()
	AFDebug.UpdateDebugWaypointColors()
	AFDebug.SetDebugVisualizerVisible(true)
end
------------------------------------------------------------------------
--// Build
--//
--// Composition root. Creates the window, every control and the debug
--// visualiser, then restores the last used profile. Nothing here runs
--// per frame.
------------------------------------------------------------------------

--======================================================================
--// SECTION 3  ::  BOOTSTRAP AND RUNTIME
--// Everything that actually executes, in its original order.
--======================================================================


PlaceConfig = AFConfig.IsValidPlace(game.PlaceId)
PROFILE_FILE = PROFILE_FOLDER .. "/" .. tostring(game.PlaceId) .. ".json"

PlaceConfig = AFConfig.NormalizePlaceConfig(PlaceConfig or {})

BasePlaceConfig = AFConfig.NormalizePlaceConfig(AFConfig.IsValidPlace(game.PlaceId) or {})

AFProfile.S.ProfileStore = AFProfile.ReadProfileStore()



if PlaceConfig then
	CONFIG.TARGET_ENTITY_PRIORITY = PlaceConfig.DEFAULT_TARGET_PRIORITY
	Feature.AutoBlock.Enabled = PlaceConfig.AUTOBLOCK
	AFFeature.S.BlockEnabled = PlaceConfig.AUTOBLOCK
end

AFFeature.updateCharacter()

AFFeature.CreateToggleContainer()
AFFeature.RegenStamina()
AFFeature.SetupAntiAfk()

Player.CharacterAdded:Connect(function()
	task.wait()

	AFFeature.S.DEATH_COUNT += 1
	CONFIG.CURRENT_WAYPOINT_TARGET = 1
	AFDebug.ResetDebugWaypoints()
	AFDebug.UpdateDebugWaypointColors()
	AFCombat.S.ClosestTarget = nil
	InputBindableFunction = nil
	AFFeature.S.BlockValue = nil
	AFFeature.S.Equipped = false
	AFCombat.S.RETREATING = false
	AFCombat.S.SkillRetreatPosition = nil
	AFCombat.S.LastSkillRetreatTime = 0
	AFCombat.S.SkillThreatUntil = 0
	AFCombat.S.LastSkillSolverTime = 0
	AFFeature.S.LAST_EQUIP_TIME = 0
	PatrolState.PatrolLegsRemaining = 0
	PatrolState.PatrolHeading = nil
	AFCombatUtils.S.StuckSamplePosition = nil
	AFCombatUtils.S.StuckStrikes = 0
	AFCombat.S.LAST_ATTACK_TIME = 0
	AFCombat.S.LAST_SKILL_TIME = 0
	AFCombat.S.LAST_COMBAT_TARGET_CHECK = 0
	AFCombat.S.COMBAT_TARGET_LOST_SINCE = nil
	AFCombat.S.COMBAT_TARGET_SCORE = math.huge
	AFCombat.S.COMBAT_ATTACK_PHASE = 0
	AFCombat.S.COMBAT_NEXT_ATTACK_TIME = 0
	AFCombat.S.COMBAT_NEXT_SKILL_TIME = 0
	AFFeature.S.LAST_CONSUME_TIME = 0
	AFFeature.S.LAST_INTERACTION_TIME = 0
	AFCombatUtils.S.LAST_STUCK_POSITION = nil
	AFFeature.S.FaceAttachment = nil
	FaceOrientation = nil

	if AFCombatUtils.S.DebugFolder then
		--// Keep the debug instances, but reset their state/colors for the new life.
		for Index, Data in AFDebug.S.DebugWaypointData do
			if Data.Label then
				Data.Label.TextColor3 = DEBUG_COLORS.WaypointPending
			end
			if Data.Marker then
				Data.Marker.BackgroundColor3 = DEBUG_COLORS.WaypointPending
			end
		end
	end

	if AFFeature.S.StaminaConnection then
		AFFeature.S.StaminaConnection:Disconnect()
		AFFeature.S.StaminaConnection = nil
	end

	table.clear(AFCombat.S.ValidMobs)
	table.clear(AFCombat.S.CombatGroupCache)
	table.clear(AFCombat.S.CombatBladeCache)
	table.clear(AFCombatUtils.S.BladePartCache)
	AFCombat.ClearUnreachableMobs()

	task.delay(0.5, function()
		AFFeature.S.Equipped = false
	end)

	AFFeature.updateCharacter()
	AFCombat.ResetTargetReposition()
	AFFeature.CreateToggleContainer()
	AFFeature.RegenStamina()
end)
AFFeature.AutoRefillBooster()



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

UIRef.FarmTab = UI:AddTab("Farm")
UIRef.StatusTab = UI:AddTab("Status")
UIRef.DebugTab = UI:AddTab("Debug")

UIRef.FeatureSection = UIRef.FarmTab:AddSection("Features")
UIRef.TargetSection  = UIRef.FarmTab:AddSection("Targeting")
UIRef.BlockSection   = UIRef.FarmTab:AddSection("Auto Block")
UIRef.StatusSection  = UIRef.StatusTab:AddSection("Live Status")
UIRef.DebugSection   = UIRef.DebugTab:AddSection("Debug Visualizer")

--// Feature toggles
Feature.AutoFarm.Button = AFUI.CreateFeature("Auto Farm", AFFeature.S.Enabled, function(Value)
	AFFeature.S.Enabled = Value
	Feature.AutoFarm.Enabled = Value
	AFProfile.SaveActiveProfile()
end)

Feature.AutoBlock.Button = AFUI.CreateFeature("Auto Block", Feature.AutoBlock.Enabled, function(Value)
	Feature.AutoBlock.Enabled = Value
	AFFeature.S.BlockEnabled = Value
	AFProfile.SaveActiveProfile()
end)

Feature.SafeCombat.Button = AFUI.CreateFeature("Safe Combat", Feature.SafeCombat.Enabled, function(Value)
	Feature.SafeCombat.Enabled = Value
	AFCombat.S.SafeCombatPositionEnabled = Value

	AFCombat.ResetTargetReposition()
	AFProfile.SaveActiveProfile()
end)

Feature.AutoSkill.Button = AFUI.CreateFeature("Auto Skill", Feature.AutoSkill.Enabled, function(Value)
	Feature.AutoSkill.Enabled = Value
	AFProfile.SaveActiveProfile()
end)

Feature.AutoFind.Button = AFUI.CreateFeature("Auto Find", Feature.AutoFind.Enabled, function(Value)
	Feature.AutoFind.Enabled = Value
	AFFeature.S.WaypointEnabled = not Value

	AFCombat.S.ClosestTarget = nil
	table.clear(AFCombat.S.ValidMobs)
	table.clear(AFCombat.S.CombatGroupCache)

	AFCombat.ResetTargetReposition()
	AFCombat.UpdateValidMobs()
	AFCombat.S.ClosestTarget = AFCombat.AcquireCombatTarget(now)
	AFProfile.SaveActiveProfile()
end)

Feature.IgnoreFarmZone.Button = AFUI.CreateFeature("Ignore Farm Zone", Feature.IgnoreFarmZone.Enabled, function(Value)
	Feature.IgnoreFarmZone.Enabled = Value

	AFCombat.S.ClosestTarget = nil
	table.clear(AFCombat.S.ValidMobs)
	table.clear(AFCombat.S.CombatGroupCache)

	AFCombat.ResetTargetReposition()

	AFFeature.S.DeadzoneEscapePosition = nil
	PatrolState.PatrolPosition = nil
	PatrolState.LastPatrolCalculateTime = 0
	AFFeature.S.FarmReturnPosition = nil
	AFFeature.S.LastFarmReturnCalculateTime = 0

	AFCombat.UpdateValidMobs()
	AFCombat.S.ClosestTarget = AFCombat.GetClosestGoblin()
	AFProfile.SaveActiveProfile()
end)

Feature.AutoPatrol.Button = AFUI.CreateFeature("Auto Patrol", Feature.AutoPatrol.Enabled, function(Value)
	Feature.AutoPatrol.Enabled = Value

	PatrolState.PatrolPosition = nil
	PatrolState.LastPatrolCalculateTime = 0
	PatrolState.PatrolDirection = nil
	PatrolState.PatrolPauseUntil = 0
	PatrolState.PatrolLastPosition = nil
	PatrolState.PatrolLastDistance = 0
	AFProfile.SaveActiveProfile()
end)

Feature.ReturnToFarmZone.Button = AFUI.CreateFeature("Return To Farm Zone", Feature.ReturnToFarmZone.Enabled, function(Value)
	Feature.ReturnToFarmZone.Enabled = Value

	AFFeature.S.FarmReturnPosition = nil
	AFFeature.S.LastFarmReturnCalculateTime = 0
	AFProfile.SaveActiveProfile()
end)

Feature.ResetOnBoostOut.Button = AFUI.CreateFeature("Refill Booster", Feature.ResetOnBoostOut.Enabled, function(Value)
	Feature.ResetOnBoostOut.Enabled = Value
	AFProfile.SaveActiveProfile()
end)

Feature.ResetStats.Button = UIRef.FeatureSection:AddButton("Reset Stats", function()
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
			local StatValue = PlayerStats:FindFirstChild(stat)

			if not StatValue then
				continue
			end

			if StatValue.Value >= CONFIG.STAT_RESET_THRESHOLD then
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

UIRef.ExecuteChargeSlider = UIRef.FeatureSection:AddSlider(
	"Execute Charge at Enemy HP %",
	math.clamp(tonumber(CONFIG.EXECUTE_CHARGE_HP_PERCENT) or 0, 0, 90),
	0,
	90,
	function(Value)
		--// 0 turns it off. Above that, a target at or below this share of
		--// its health is finished rather than retreated from.
		CONFIG.EXECUTE_CHARGE_HP_PERCENT = math.clamp(math.floor(tonumber(Value) or 0), 0, 90)
		AFProfile.QueueProfileSave()
	end
)

UIRef.RetreatHealthSlider = UIRef.FeatureSection:AddSlider(
	"Retreat At Health %",
	math.clamp(tonumber(CONFIG.RETREAT_HEALTH_PERCENT) or 40, 30, 80),
	30,
	80,
	function(Value)
		CONFIG.RETREAT_HEALTH_PERCENT = math.clamp(math.floor(tonumber(Value) or 40), 30, 80)
		AFProfile.QueueProfileSave()
	end
)

UIRef.AutoHealHealthSlider = UIRef.FeatureSection:AddSlider(
	"Auto Heal at HP",
	math.clamp(tonumber(CONFIG.AUTO_HEAL_HEALTH_PERCENT) or 65, 30, 80),
	30,
	80,
	function(Value)
		CONFIG.AUTO_HEAL_HEALTH_PERCENT = math.clamp(math.floor(tonumber(Value) or 65), 30, 80)
		AFProfile.QueueProfileSave()
	end
)

UIRef.SafeEnemyRangeSlider = UIRef.TargetSection:AddSlider(
	"Safe Enemy Range",
	math.clamp(tonumber(CONFIG.SAFE_ENEMY_RANGE) or 4, 0, 30),
	0,
	30,
	function(Value)
		CONFIG.SAFE_ENEMY_RANGE = math.clamp(tonumber(Value) or 4, 0, 30)
		AFProfile.QueueProfileSave()
	end
)

Feature.DebugVisualizer.Button = UIRef.FeatureSection:AddToggle(
	"Debug Visualizer",
	Feature.DebugVisualizer.Enabled,
	function(Value)
		Feature.DebugVisualizer.Enabled = Value

		task.defer(function()
			if Value then
				AFDebug.UpdateDebugVisualizer()
			else
				AFDebug.SetDebugVisualizerVisible(false)
			end
		end)

		AFProfile.SaveActiveProfile()
	end
)

--// Debug controls live in their own tab. The master visualizer toggle remains
--// on the Farm tab for quick enable/disable. These controls decide which
--// debug layers are actually rendered.
Feature.DebugWaypoints.Button = UIRef.DebugSection:AddToggle(
	"Debug Waypoints",
	Feature.DebugWaypoints.Enabled,
	function(Value)
		Feature.DebugWaypoints.Enabled = Value
		AFDebug.UpdateDebugVisualizer()
		AFProfile.SaveActiveProfile()
	end
)

Feature.DebugFarmZones.Button = UIRef.DebugSection:AddToggle(
	"Debug Farm Zones",
	Feature.DebugFarmZones.Enabled,
	function(Value)
		Feature.DebugFarmZones.Enabled = Value
		AFDebug.UpdateDebugVisualizer()
		AFProfile.SaveActiveProfile()
	end
)

Feature.DebugDeadzones.Button = UIRef.DebugSection:AddToggle(
	"Debug Deadzones",
	Feature.DebugDeadzones.Enabled,
	function(Value)
		Feature.DebugDeadzones.Enabled = Value
		AFDebug.UpdateDebugVisualizer()
		AFProfile.SaveActiveProfile()
	end
)

Feature.DebugRadiusLabels.Button = UIRef.DebugSection:AddToggle(
	"Radius Billboard Labels",
	Feature.DebugRadiusLabels.Enabled,
	function(Value)
		Feature.DebugRadiusLabels.Enabled = Value
		AFDebug.UpdateDebugVisualizer()
		AFProfile.SaveActiveProfile()
	end
)

--// Live status labels
UIRef.PlaceIDLabel       = UIRef.StatusSection:AddLabel("PLACE ID       " .. tostring(game.PlaceId))
UIRef.WalkSpeedLabel     = UIRef.StatusSection:AddLabel("WALKSPEED      0")
UIRef.WayPointLabel      = UIRef.StatusSection:AddLabel("WAYPOINTS:  0/" .. (PlaceConfig and #PlaceConfig.WAYPOINTS or 0))
UIRef.EventCurrencyLabel = UIRef.StatusSection:AddLabel("EVENT CURRENCY  0")
UIRef.ServerAgeLabel     = UIRef.StatusSection:AddLabel("PLAY TIME      00:00:00")
UIRef.PositionLabel      = UIRef.StatusSection:AddLabel("POSITION       --")
UIRef.DeathLabel         = UIRef.StatusSection:AddLabel("DEATH          0")
UIRef.ExpLabel           = UIRef.StatusSection:AddLabel("EXP            0/0")

--// Priority component
UIRef.PriorityComponent = UIRef.TargetSection:AddPriority(
	"Enemy Priority",
	CONFIG.TARGET_ENTITY_PRIORITY
)

-- Keep CONFIG and the Utils priority component on the same table.
CONFIG.TARGET_ENTITY_PRIORITY = UIRef.PriorityComponent.Priority

--// Capture the stock methods before the overrides below replace them.
AFUI.S.OriginalPriorityAdd      = UIRef.PriorityComponent.Add
AFUI.S.OriginalPriorityRemove   = UIRef.PriorityComponent.Remove
AFUI.S.OriginalPriorityMoveUp   = UIRef.PriorityComponent.MoveUp
AFUI.S.OriginalPriorityMoveDown = UIRef.PriorityComponent.MoveDown

function UIRef.PriorityComponent:Add(EntityName)
	if not AFProfile.S.ActiveProfileName then
		return false
	end

	local Changed = AFUI.S.OriginalPriorityAdd(self, EntityName)

	if Changed then
		AFUI.SyncPriorityState(true)
	end

	return Changed
end

function UIRef.PriorityComponent:Remove(EntityName)
	if not AFProfile.S.ActiveProfileName then
		return false
	end

	local Changed = AFUI.S.OriginalPriorityRemove(self, EntityName)

	if Changed then
		AFUI.SyncPriorityState(true)
	end

	return Changed
end

function UIRef.PriorityComponent:MoveUp(EntityName)
	if not AFProfile.S.ActiveProfileName then
		return
	end

	AFUI.S.OriginalPriorityMoveUp(self, EntityName)
	AFUI.SyncPriorityState(true)
end

function UIRef.PriorityComponent:MoveDown(EntityName)
	if not AFProfile.S.ActiveProfileName then
		return
	end

	AFUI.S.OriginalPriorityMoveDown(self, EntityName)
	AFUI.SyncPriorityState(true)
end

AFUI.S.AddPriorityTarget = function(EntityName)
	if not EntityName or EntityName == "" or EntityName == "No detected enemies" then
		return
	end

	if AFCombat.IsEntityInPriority(EntityName) then
		return
	end

	UIRef.PriorityComponent:Add(EntityName)
end

UIRef.TargetRefreshButton = UIRef.TargetSection:AddButton("Refresh Detected Targets", function()
	AFUI.RefreshTargetDropdown()
end)

--// Breaks ties between mobs of equal priority. Disabled keeps nearest first.
UIRef.TargetTypeDropdown = UIRef.TargetSection:AddDropdown(
	"Target Type",
	{ "Disabled", "Highest HP", "Lowest HP" },
	function(Value)
		CONFIG.TARGET_HP_MODE = tostring(Value or "Disabled")
		AFCombat.ResetTargetState()
		AFProfile.SaveActiveProfile()
	end
)

UIRef.TargetTypeDropdown:Set(tostring(CONFIG.TARGET_HP_MODE or "Disabled"), false)

--//==============================================================
--// Auto Block whitelist
--//
--// Players on this list are treated as if they were not there. Auto Block
--// only reacts to someone who is not on it, and then blocks that one player
--// rather than everybody in the server.
--//==============================================================
UIRef.BlockWhitelistComponent = UIRef.BlockSection:AddPriority(
	"Block Whitelist",
	CONFIG.BLOCK_WHITELIST
)

CONFIG.BLOCK_WHITELIST = UIRef.BlockWhitelistComponent.Priority

UIRef.BlockWhitelistBox = UIRef.BlockSection:AddTextbox("User ID", "", function() end)

UIRef.BlockSection:AddButton("Add User ID", function()
	local Raw = UIRef.BlockWhitelistBox:Get()
	local Id = AFFeature.NormalizeUserId(Raw)

	if not Id then
		NotifyAction("Whitelist", "Enter a numeric UserId")
		return
	end

	if AFFeature.IsWhitelisted(Id) then
		NotifyAction("Whitelist", Id .. " is already on the list")
		return
	end

	UIRef.BlockWhitelistComponent:Add(Id)
	CONFIG.BLOCK_WHITELIST = UIRef.BlockWhitelistComponent.Priority
	UIRef.BlockWhitelistBox:Set("")
	AFProfile.SaveActiveProfile()
	NotifyAction("Whitelist", "Added " .. Id)
	AFUI.RefreshWhitelistPlayerDropdown()
end)

--//==============================================================
--// Pinned items
--//
--// Lives outside the tabs in its own panel so it can be dragged clear of the
--// window and left on screen. The library only knows names and numbers: the
--// counts and the searchable list both come from the inventory string here.
--//==============================================================
UIRef.PinPanel = UI:AddPin("Pinned Items")

--// Pinning, removing, reordering, popping out and dragging all land here.
UIRef.PinPanel.OnChanged = function()
	AFProfile.QueueProfileSave()
end

task.spawn(function()
	local PlayerStats = Player:WaitForChild("PlayerStats", 30)
	local Inventory = PlayerStats and PlayerStats:WaitForChild("Inventory", 30)

	if Inventory then
		--// One call installs the search source, the count source and the
		--// change watcher. The inventory format lives in the library now.
		UI:BindPinToValue(UIRef.PinPanel, Inventory)
	end
end)

AFUI.RefreshWhitelistPlayerDropdown()

UIRef.BlockSection:AddButton("Refresh Player List", function()
	AFUI.RefreshWhitelistPlayerDropdown()
end)

--// The roster changes while the menu is open, so the picker follows it
--// instead of showing whoever happened to be here when it was built.
Players.PlayerAdded:Connect(function()
	AFUI.RefreshWhitelistPlayerDropdown()
end)

Players.PlayerRemoving:Connect(function()
	task.defer(AFUI.RefreshWhitelistPlayerDropdown)
end)

UIRef.BlockSection:AddButton("Add Everyone Here", function()
	local Added = 0

	for _, Other in ipairs(Players:GetPlayers()) do
		if Other ~= Player and not AFFeature.IsWhitelisted(Other.UserId) then
			UIRef.BlockWhitelistComponent:Add(tostring(Other.UserId))
			Added += 1
		end
	end

	CONFIG.BLOCK_WHITELIST = UIRef.BlockWhitelistComponent.Priority
	AFProfile.SaveActiveProfile()
	NotifyAction("Whitelist", "Added " .. tostring(Added) .. " player(s)")
	AFUI.RefreshWhitelistPlayerDropdown()
end)

UIRef.BlockSection:AddButton("Clear Whitelist", function()
	UIRef.BlockWhitelistComponent:SetPriority({})
	CONFIG.BLOCK_WHITELIST = UIRef.BlockWhitelistComponent.Priority
	AFProfile.SaveActiveProfile()
	NotifyAction("Whitelist", "Cleared")
	AFUI.RefreshWhitelistPlayerDropdown()
end)

do
	--// The list component owns the table, so every edit made through it has
	--// to write the profile back or the change is lost on reload.
	local OriginalRemove = UIRef.BlockWhitelistComponent.Remove
	local OriginalMoveUp = UIRef.BlockWhitelistComponent.MoveUp
	local OriginalMoveDown = UIRef.BlockWhitelistComponent.MoveDown

	function UIRef.BlockWhitelistComponent:Remove(Entry)
		local Changed = OriginalRemove(self, Entry)
		CONFIG.BLOCK_WHITELIST = self.Priority
		AFProfile.SaveActiveProfile()
		AFUI.RefreshWhitelistPlayerDropdown()
		return Changed
	end

	function UIRef.BlockWhitelistComponent:MoveUp(Entry)
		OriginalMoveUp(self, Entry)
		CONFIG.BLOCK_WHITELIST = self.Priority
		AFProfile.SaveActiveProfile()
	end

	function UIRef.BlockWhitelistComponent:MoveDown(Entry)
		OriginalMoveDown(self, Entry)
		CONFIG.BLOCK_WHITELIST = self.Priority
		AFProfile.SaveActiveProfile()
	end
end

AFUI.RefreshTargetDropdown()

AFUI.updateFeatureButtons()

--//==============================================================
--// Profile Settings
--//==============================================================
UIRef.ProfileTab = UI:AddTab("Profile Settings")
UIRef.ProfilesSection = UIRef.ProfileTab:AddSection("Profiles")
UIRef.WaypointSection = UIRef.ProfileTab:AddSection("Waypoints")
UIRef.ZoneSection = UIRef.ProfileTab:AddSection("Farm / Deadzone")

UIRef.ProfileStatusLabel = UIRef.ProfilesSection:AddLabel("STATUS:  DEFAULT PLACE_CONFIG (READ-ONLY)")

UIRef.ProfileNameBox = UIRef.ProfilesSection:AddTextbox(
	"Profile Name",
	"",
	function(Value)
		--// The textbox is used as the source for Create Profile.
	end
)

UIRef.ImportDataBox = UIRef.ProfilesSection:AddTextbox(
	"Import Data",
	"",
	function(Value)
		--// Paste JSON here, then press Import Save.
	end
)

UIRef.ProfilesSection:AddButton("Create New Profile", function()
	local Name = UIRef.ProfileNameBox:Get()

	if Name == "" then
		AFUI.SetProfileStatus("ENTER PROFILE NAME")
		return
	end

	local Success, ErrorMessage = AFProfile.CreateProfile(Name)

	if not Success then
		AFUI.SetProfileStatus(ErrorMessage or "CREATE FAILED")
		return
	end

	UIRef.ProfileNameBox:Set(Name)
	UIRef.ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
	UIRef.FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
	UIRef.DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
	UIRef.RetreatHealthSlider:Set(CONFIG.RETREAT_HEALTH_PERCENT, false)
	UIRef.AutoHealHealthSlider:Set(CONFIG.AUTO_HEAL_HEALTH_PERCENT, false)
	UIRef.SafeEnemyRangeSlider:Set(CONFIG.SAFE_ENEMY_RANGE, false)
	AFUI.RefreshWaypointList()
	AFUI.RefreshFarmZoneList()
	AFUI.RefreshDeadzoneList()
	AFUI.RefreshProfileDropdown()
	UIRef.ProfileDropdown:Set(Name, false)
	--// A new profile can replace CONFIG.TARGET_ENTITY_PRIORITY.
	--// Sync the Utils priority component before rebuilding the target dropdown,
	--// otherwise it may still hold the previous profile's priority list.
	UIRef.PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY or {}))
	AFUI.updateFeatureButtons()
	AFUI.RefreshTargetDropdown()
	AFDebug.UpdateDebugVisualizer()
	AFUI.SetProfileStatus("CREATED " .. Name)
	NotifyAction("Profile", "Created " .. Name)
end)

UIRef.ProfilesSection:AddButton("Save Profile", function()
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("NO ACTIVE PROFILE")
		return
	end

	if AFProfile.SaveActiveProfile() then
		AFUI.SetProfileStatus("SAVED " .. AFProfile.S.ActiveProfileName)
		NotifyAction("Save", "Saved " .. AFProfile.S.ActiveProfileName)
	else
		AFUI.SetProfileStatus("SAVE FAILED")
	end
end)

UIRef.ProfilesSection:AddButton("Export Save", function()
	local Success, Result = AFProfile.ExportActiveProfile()

	if Success then
		AFUI.SetProfileStatus("EXPORTED " .. tostring(AFProfile.S.ActiveProfileName))
		NotifyAction("Export", "Copied " .. tostring(AFProfile.S.ActiveProfileName) .. " to clipboard")
	else
		AFUI.SetProfileStatus(Result or "EXPORT FAILED")
	end
end)

UIRef.ProfilesSection:AddButton("Import Save", function()
	local Success, Result = AFProfile.ImportProfileFromText(UIRef.ImportDataBox:Get())

	if not Success then
		AFUI.SetProfileStatus(Result or "IMPORT FAILED")
		return
	end

	UIRef.ProfileNameBox:Set(Result)
	UIRef.ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
	UIRef.FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
	UIRef.DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
	UIRef.RetreatHealthSlider:Set(CONFIG.RETREAT_HEALTH_PERCENT, false)
	UIRef.AutoHealHealthSlider:Set(CONFIG.AUTO_HEAL_HEALTH_PERCENT, false)
	UIRef.SafeEnemyRangeSlider:Set(CONFIG.SAFE_ENEMY_RANGE, false)
	AFUI.RefreshWaypointList()
	AFUI.RefreshFarmZoneList()
	AFUI.RefreshDeadzoneList()
	AFUI.RefreshProfileDropdown()
	UIRef.ProfileDropdown:Set(Result, false)
	AFUI.RefreshFarmZonePicker()
	AFUI.RefreshDeadzonePicker()
	UIRef.PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY))
	Feature.AutoBlock.Enabled = AFFeature.S.BlockEnabled
	AFUI.updateFeatureButtons()
	AFUI.RefreshTargetDropdown()
	AFCombat.ResetTargetState()
	AFDebug.UpdateDebugVisualizer()
	AFUI.SetProfileStatus("IMPORTED " .. Result)
	NotifyAction("Import", "Imported " .. tostring(Result))
end)

UIRef.ProfilesSection:AddButton("Delete Profile", function()
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("NO ACTIVE PROFILE")
		return
	end

	local Name = AFProfile.S.ActiveProfileName

	if AFProfile.DeleteProfile(Name) then
		UIRef.ProfileNameBox:Set("")
		UIRef.ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
		UIRef.FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
		UIRef.DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
		AFUI.RefreshWaypointList()
		AFUI.RefreshFarmZoneList()
		AFUI.RefreshDeadzoneList()
		AFUI.RefreshProfileDropdown()
		UIRef.PriorityComponent:SetPriority(table.clone(
			BasePlaceConfig.DEFAULT_TARGET_PRIORITY
				or CONFIG.TARGET_ENTITY_PRIORITY
				or {}
		))
		CONFIG.TARGET_ENTITY_PRIORITY = UIRef.PriorityComponent.Priority
		AFUI.updateFeatureButtons()
		AFUI.RefreshTargetDropdown()
		AFDebug.UpdateDebugVisualizer()
		AFUI.SetProfileStatus("DELETED " .. Name)
		NotifyAction("Profile", "Deleted " .. Name)
	else
		AFUI.SetProfileStatus("DELETE FAILED")
	end
end)

UIRef.WaypointSection:AddButton("Add Waypoint Here", function()
	if not RootPart then
		AFUI.SetProfileStatus("CHARACTER NOT READY")
		return
	end

	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	table.insert(PlaceConfig.WAYPOINTS, RootPart.Position)
	CONFIG.CURRENT_WAYPOINT_TARGET = math.clamp(
		CONFIG.CURRENT_WAYPOINT_TARGET,
		1,
		math.max(1, #PlaceConfig.WAYPOINTS)
	)

	AFUI.RefreshWaypointList()
	AFDebug.ResetDebugWaypoints()
	AFDebug.UpdateDebugVisualizer()
	AFProfile.SaveActiveProfile()
	AFUI.SetProfileStatus("WAYPOINT ADDED #" .. tostring(#PlaceConfig.WAYPOINTS))
	NotifyAction("Waypoint", "Added waypoint #" .. tostring(#PlaceConfig.WAYPOINTS))
end)

UIRef.WaypointSection:AddButton("Clear Waypoints", function()
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	table.clear(PlaceConfig.WAYPOINTS)
	CONFIG.CURRENT_WAYPOINT_TARGET = 1

	AFUI.RefreshWaypointList()
	AFDebug.ResetDebugWaypoints()
	AFDebug.UpdateDebugVisualizer()
	AFProfile.SaveActiveProfile()
	AFUI.SetProfileStatus("WAYPOINTS CLEARED")
	NotifyAction("Waypoint", "Cleared all waypoints")
end)

UIRef.WaypointListComponent = UIRef.WaypointSection:AddPriority("All Waypoints", AFUI.BuildWaypointLabels())

AFUI.S.OriginalWaypointMoveUp = UIRef.WaypointListComponent.MoveUp
AFUI.S.OriginalWaypointMoveDown = UIRef.WaypointListComponent.MoveDown
AFUI.S.OriginalWaypointRemove = UIRef.WaypointListComponent.Remove

function UIRef.WaypointListComponent:MoveUp(Label)
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(AFUI.BuildWaypointLabels(), Label)

	if Index and Index > 1 then
		PlaceConfig.WAYPOINTS[Index], PlaceConfig.WAYPOINTS[Index - 1] =
			PlaceConfig.WAYPOINTS[Index - 1], PlaceConfig.WAYPOINTS[Index]

		AFUI.S.OriginalWaypointMoveUp(self, Label)
		CONFIG.CURRENT_WAYPOINT_TARGET = math.clamp(
			CONFIG.CURRENT_WAYPOINT_TARGET,
			1,
			math.max(1, #PlaceConfig.WAYPOINTS)
		)
		AFUI.RefreshWaypointList()
		AFDebug.ResetDebugWaypoints()
		AFDebug.UpdateDebugVisualizer()
		AFProfile.SaveActiveProfile()
		AFUI.SetProfileStatus("WAYPOINT MOVED UP")
		NotifyAction("Waypoint", "Moved up")
	end
end

function UIRef.WaypointListComponent:MoveDown(Label)
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(AFUI.BuildWaypointLabels(), Label)

	if Index and Index < #PlaceConfig.WAYPOINTS then
		PlaceConfig.WAYPOINTS[Index], PlaceConfig.WAYPOINTS[Index + 1] =
			PlaceConfig.WAYPOINTS[Index + 1], PlaceConfig.WAYPOINTS[Index]

		AFUI.S.OriginalWaypointMoveDown(self, Label)
		CONFIG.CURRENT_WAYPOINT_TARGET = math.clamp(
			CONFIG.CURRENT_WAYPOINT_TARGET,
			1,
			math.max(1, #PlaceConfig.WAYPOINTS)
		)
		AFUI.RefreshWaypointList()
		AFDebug.ResetDebugWaypoints()
		AFDebug.UpdateDebugVisualizer()
		AFProfile.SaveActiveProfile()
		AFUI.SetProfileStatus("WAYPOINT MOVED DOWN")
		NotifyAction("Waypoint", "Moved down")
	end
end

function UIRef.WaypointListComponent:Remove(Label)
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(AFUI.BuildWaypointLabels(), Label)

	if Index then
		table.remove(PlaceConfig.WAYPOINTS, Index)
		AFUI.S.OriginalWaypointRemove(self, Label)
		CONFIG.CURRENT_WAYPOINT_TARGET = math.clamp(
			CONFIG.CURRENT_WAYPOINT_TARGET,
			1,
			math.max(1, #PlaceConfig.WAYPOINTS)
		)
		AFUI.RefreshWaypointList()
		AFDebug.ResetDebugWaypoints()
		AFDebug.UpdateDebugVisualizer()
		AFProfile.SaveActiveProfile()
		AFUI.SetProfileStatus("WAYPOINT REMOVED #" .. tostring(Index))
	end
end

UIRef.FarmRadiusSlider = UIRef.ZoneSection:AddSlider(
	"Farm Radius",
	100,
	1,
	500,
	function(Value)
		local Zone = PlaceConfig and PlaceConfig.FARM_ZONES
			and PlaceConfig.FARM_ZONES[AFProfile.S.SelectedFarmZoneIndex]

		if not Zone or not AFProfile.S.ActiveProfileName then return end

		Zone.Radius = Value
		AFUI.RefreshFarmZoneList()
		AFDebug.UpdateDebugVisualizer()
		AFProfile.QueueProfileSave()
	end
)

UIRef.DeadzoneRadiusSlider = UIRef.ZoneSection:AddSlider(
	"Deadzone Radius",
	35,
	1,
	250,
	function(Value)
		local Zone = PlaceConfig and PlaceConfig.DEADZONES
			and PlaceConfig.DEADZONES[AFProfile.S.SelectedDeadzoneIndex]

		if not Zone or not AFProfile.S.ActiveProfileName then return end

		Zone.Radius = Value
		AFUI.RefreshDeadzoneList()
		AFDebug.UpdateDebugVisualizer()
		AFProfile.QueueProfileSave()
	end
)

AFUI.RefreshFarmZonePicker()
AFUI.RefreshDeadzonePicker()

UIRef.ReachDistanceBox = UIRef.ZoneSection:AddTextbox(
	"Waypoint Reach Distance",
	tostring(PlaceConfig.REACH_DISTANCE or 5),
	function(Value)
		if not AFProfile.S.ActiveProfileName then
			return
		end

		local Number = tonumber(Value)

		if Number and Number > 0 then
			PlaceConfig.REACH_DISTANCE = Number
			AFProfile.SaveActiveProfile()
			AFUI.SetProfileStatus("REACH DISTANCE SAVED")
		end
	end
)

UIRef.ZoneSection:AddButton("Add Farm Zone Here", function()
	if not RootPart then
		AFUI.SetProfileStatus("CHARACTER NOT READY")
		return
	end

	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	local Radius = UIRef.FarmRadiusSlider:Get()

	table.insert(PlaceConfig.FARM_ZONES, {
		Center = RootPart.Position,
		Radius = Radius,
	})

	PlaceConfig = AFConfig.NormalizePlaceConfig(PlaceConfig)
	AFUI.RefreshFarmZoneList()
	AFProfile.S.SelectedFarmZoneIndex = #PlaceConfig.FARM_ZONES
	AFUI.RefreshFarmZonePicker()
	AFProfile.SaveActiveProfile()
	AFDebug.UpdateDebugVisualizer()
	AFUI.SetProfileStatus("FARM ZONE ADDED #" .. tostring(#PlaceConfig.FARM_ZONES))
end)

UIRef.ZoneSection:AddButton("Add Deadzone Here", function()
	if not RootPart then
		AFUI.SetProfileStatus("CHARACTER NOT READY")
		return
	end

	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	local Radius = UIRef.DeadzoneRadiusSlider:Get()

	table.insert(PlaceConfig.DEADZONES, {
		Center = RootPart.Position,
		Radius = Radius,
	})

	PlaceConfig = AFConfig.NormalizePlaceConfig(PlaceConfig)
	AFUI.RefreshDeadzoneList()
	AFProfile.S.SelectedDeadzoneIndex = #PlaceConfig.DEADZONES
	AFUI.RefreshDeadzonePicker()
	AFProfile.SaveActiveProfile()
	AFDebug.UpdateDebugVisualizer()
	AFUI.SetProfileStatus("DEADZONE ADDED #" .. tostring(#PlaceConfig.DEADZONES))
end)

UIRef.ZoneSection:AddButton("Clear Farm Zones", function()
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	table.clear(PlaceConfig.FARM_ZONES)
	PlaceConfig = AFConfig.NormalizePlaceConfig(PlaceConfig)
	AFProfile.S.SelectedFarmZoneIndex = 1
	AFUI.RefreshFarmZoneList()
	AFUI.RefreshFarmZonePicker()
	AFProfile.SaveActiveProfile()
	AFDebug.UpdateDebugVisualizer()
	AFUI.SetProfileStatus("FARM ZONES CLEARED")
	NotifyAction("Farm Zone", "Cleared all farm zones")
end)

UIRef.ZoneSection:AddButton("Clear Deadzones", function()
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("CREATE / LOAD PROFILE FIRST")
		return
	end

	table.clear(PlaceConfig.DEADZONES)
	PlaceConfig = AFConfig.NormalizePlaceConfig(PlaceConfig)
	AFProfile.S.SelectedDeadzoneIndex = 1
	AFUI.RefreshDeadzoneList()
	AFUI.RefreshDeadzonePicker()
	AFProfile.SaveActiveProfile()
	AFDebug.UpdateDebugVisualizer()
	AFUI.SetProfileStatus("DEADZONES CLEARED")
	NotifyAction("Deadzone", "Cleared all deadzones")
end)

UIRef.FarmZoneListComponent = UIRef.ZoneSection:AddPriority(
	"All Farm Zones",
	AFUI.BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm")
)

UIRef.DeadzoneListComponent = UIRef.ZoneSection:AddPriority(
	"All Deadzones",
	AFUI.BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone")
)

AFUI.S.OriginalFarmZoneMoveUp = UIRef.FarmZoneListComponent.MoveUp
AFUI.S.OriginalFarmZoneMoveDown = UIRef.FarmZoneListComponent.MoveDown
AFUI.S.OriginalFarmZoneRemove = UIRef.FarmZoneListComponent.Remove

AFUI.S.OriginalDeadzoneMoveUp = UIRef.DeadzoneListComponent.MoveUp
AFUI.S.OriginalDeadzoneMoveDown = UIRef.DeadzoneListComponent.MoveDown
AFUI.S.OriginalDeadzoneRemove = UIRef.DeadzoneListComponent.Remove

function UIRef.FarmZoneListComponent:MoveUp(Label)
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(AFUI.BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm"), Label)

	if Index and Index > 1 then
		PlaceConfig.FARM_ZONES[Index], PlaceConfig.FARM_ZONES[Index - 1] =
			PlaceConfig.FARM_ZONES[Index - 1], PlaceConfig.FARM_ZONES[Index]
		AFUI.S.OriginalFarmZoneMoveUp(self, Label)
		AFUI.RefreshFarmZoneList()
		AFProfile.S.SelectedFarmZoneIndex = math.max(1, Index - 1)
		AFUI.RefreshFarmZonePicker()
		AFProfile.SaveActiveProfile()
		AFDebug.UpdateDebugVisualizer()
		AFUI.SetProfileStatus("FARM ZONE MOVED UP")
		NotifyAction("Farm Zone", "Moved up")
	end
end

function UIRef.FarmZoneListComponent:MoveDown(Label)
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(AFUI.BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm"), Label)

	if Index and Index < #PlaceConfig.FARM_ZONES then
		PlaceConfig.FARM_ZONES[Index], PlaceConfig.FARM_ZONES[Index + 1] =
			PlaceConfig.FARM_ZONES[Index + 1], PlaceConfig.FARM_ZONES[Index]
		AFUI.S.OriginalFarmZoneMoveDown(self, Label)
		AFUI.RefreshFarmZoneList()
		AFProfile.S.SelectedFarmZoneIndex = math.min(#PlaceConfig.FARM_ZONES, Index + 1)
		AFUI.RefreshFarmZonePicker()
		AFProfile.SaveActiveProfile()
		AFDebug.UpdateDebugVisualizer()
		AFUI.SetProfileStatus("FARM ZONE MOVED DOWN")
		NotifyAction("Farm Zone", "Moved down")
	end
end

function UIRef.FarmZoneListComponent:Remove(Label)
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(AFUI.BuildZoneLabels(PlaceConfig.FARM_ZONES, "Farm"), Label)

	if Index then
		table.remove(PlaceConfig.FARM_ZONES, Index)
		AFUI.S.OriginalFarmZoneRemove(self, Label)
		PlaceConfig = AFConfig.NormalizePlaceConfig(PlaceConfig)
		AFProfile.S.SelectedFarmZoneIndex = math.clamp(Index, 1, math.max(1, #PlaceConfig.FARM_ZONES))
		AFUI.RefreshFarmZoneList()
		AFUI.RefreshFarmZonePicker()
		AFProfile.SaveActiveProfile()
		AFDebug.UpdateDebugVisualizer()
		AFUI.SetProfileStatus("FARM ZONE REMOVED #" .. tostring(Index))
	end
end

function UIRef.DeadzoneListComponent:MoveUp(Label)
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(AFUI.BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone"), Label)

	if Index and Index > 1 then
		PlaceConfig.DEADZONES[Index], PlaceConfig.DEADZONES[Index - 1] =
			PlaceConfig.DEADZONES[Index - 1], PlaceConfig.DEADZONES[Index]
		AFUI.S.OriginalDeadzoneMoveUp(self, Label)
		AFUI.RefreshDeadzoneList()
		AFProfile.S.SelectedDeadzoneIndex = math.max(1, Index - 1)
		AFUI.RefreshDeadzonePicker()
		AFProfile.SaveActiveProfile()
		AFDebug.UpdateDebugVisualizer()
		AFUI.SetProfileStatus("DEADZONE MOVED UP")
		NotifyAction("Deadzone", "Moved up")
	end
end

function UIRef.DeadzoneListComponent:MoveDown(Label)
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(AFUI.BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone"), Label)

	if Index and Index < #PlaceConfig.DEADZONES then
		PlaceConfig.DEADZONES[Index], PlaceConfig.DEADZONES[Index + 1] =
			PlaceConfig.DEADZONES[Index + 1], PlaceConfig.DEADZONES[Index]
		AFUI.S.OriginalDeadzoneMoveDown(self, Label)
		AFUI.RefreshDeadzoneList()
		AFProfile.S.SelectedDeadzoneIndex = math.min(#PlaceConfig.DEADZONES, Index + 1)
		AFUI.RefreshDeadzonePicker()
		AFProfile.SaveActiveProfile()
		AFDebug.UpdateDebugVisualizer()
		AFUI.SetProfileStatus("DEADZONE MOVED DOWN")
		NotifyAction("Deadzone", "Moved down")
	end
end

function UIRef.DeadzoneListComponent:Remove(Label)
	if not AFProfile.S.ActiveProfileName then
		AFUI.SetProfileStatus("DEFAULT PLACE_CONFIG IS READ-ONLY")
		return
	end

	local Index = table.find(AFUI.BuildZoneLabels(PlaceConfig.DEADZONES, "Deadzone"), Label)

	if Index then
		table.remove(PlaceConfig.DEADZONES, Index)
		AFUI.S.OriginalDeadzoneRemove(self, Label)
		PlaceConfig = AFConfig.NormalizePlaceConfig(PlaceConfig)
		AFProfile.S.SelectedDeadzoneIndex = math.clamp(Index, 1, math.max(1, #PlaceConfig.DEADZONES))
		AFUI.RefreshDeadzoneList()
		AFUI.RefreshDeadzonePicker()
		AFProfile.SaveActiveProfile()
		AFDebug.UpdateDebugVisualizer()
		AFUI.SetProfileStatus("DEADZONE REMOVED #" .. tostring(Index))
	end
end

AFUI.RefreshWaypointList()
AFUI.RefreshFarmZoneList()
AFUI.RefreshDeadzoneList()

AFUI.updatePosition()

--// Initial debug setup.
AFDebug.UpdateDebugVisualizer()

--// Load the most recently used profile for this PlaceId.
--// If none exists, keep the place_config defaults. If the place has no
--// place_config, the profile starts with zero waypoints/zones.
if AFProfile.S.ProfileStore.LastUsed
	and AFProfile.S.ProfileStore.Profiles[AFProfile.S.ProfileStore.LastUsed]
then
	local LastUsed = AFProfile.S.ProfileStore.LastUsed
	AFProfile.S.ActiveProfileName = LastUsed

	if not AFProfile.LoadProfile(LastUsed) then
		AFProfile.S.ActiveProfileName = nil
		AFProfile.S.ProfileData = nil
	end
end

if AFProfile.S.ActiveProfileName then
	UIRef.ProfileNameBox:Set(AFProfile.S.ActiveProfileName)
	UIRef.ReachDistanceBox:Set(tostring(PlaceConfig.REACH_DISTANCE or 5))
	UIRef.FarmRadiusSlider:Set((PlaceConfig.FARM_ZONES[1] and PlaceConfig.FARM_ZONES[1].Radius) or 100, false)
	UIRef.DeadzoneRadiusSlider:Set((PlaceConfig.DEADZONES[1] and PlaceConfig.DEADZONES[1].Radius) or 35, false)
	AFUI.RefreshWaypointList()
	AFUI.RefreshFarmZoneList()
	AFUI.RefreshDeadzoneList()
	UIRef.PriorityComponent:SetPriority(table.clone(CONFIG.TARGET_ENTITY_PRIORITY))
	CONFIG.TARGET_ENTITY_PRIORITY = UIRef.PriorityComponent.Priority
	AFUI.updateFeatureButtons()
	AFUI.RefreshTargetDropdown()
	AFDebug.UpdateDebugVisualizer()
end

AFUI.RefreshProfileDropdown()

if AFProfile.S.ActiveProfileName then
	UIRef.ProfileDropdown:Set(AFProfile.S.ActiveProfileName, false)
	AFUI.SetProfileStatus("AUTO LOADED " .. AFProfile.S.ActiveProfileName)
end

------------------------------------------------------------------------
--// Wire
--//
--// Subscriptions to the world: the mob folder and its replacement, which
--// have to be watched rather than polled.
------------------------------------------------------------------------

AFCombat.S.ExistingMobFolder = workspace:FindFirstChild("Mobs")

if AFCombat.S.ExistingMobFolder then
	AFCombat.WatchMobFolder(AFCombat.S.ExistingMobFolder)
end

workspace.ChildAdded:Connect(function(Child)
	if Child.Name == "Mobs" then
		AFCombat.WatchMobFolder(Child)
		AFUI.RefreshEnemyPicker()
	end
end)

workspace.ChildRemoved:Connect(function(Child)
	if Child.Name ~= "Mobs" then
		return
	end

	for _, Connection in AFCombat.S.MobFolderConnections do
		Connection:Disconnect()
	end

	table.clear(AFCombat.S.MobFolderConnections)

	for Mob in AFCombat.S.MobConnections do
		AFCombat.DisconnectMob(Mob)
	end

	table.clear(AFCombat.S.ValidMobs)

	AFCombat.S.ClosestTarget = nil

	AFUI.RefreshEnemyPicker()
end)

------------------------------------------------------------------------
--// Main
--//
--// The two frame loops and nothing else. RenderStepped keeps the readout
--// and walk speed current; Heartbeat is the decision loop.
------------------------------------------------------------------------

--// Position Update
RunService.RenderStepped:Connect(function()
	AFUI.updatePosition()

	if Humanoid then
		if AFFeature.GetPlayerLevel() >= CONFIG.HIGH_LEVEL_THRESHOLD then
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
		AFFeature.updateCharacter()
		table.clear(AFCombat.S.ValidMobs)
		AFCombat.S.ClosestTarget = nil
		return
	end

	if Humanoid.Health <= 0 then
		AFDebug.ResetDebugWaypoints()
		CONFIG.CURRENT_WAYPOINT_TARGET = 1
		table.clear(AFCombat.S.ValidMobs)
		AFCombat.S.ClosestTarget = nil
		return
	end

	if now - AFUI.S.LAST_TEXT_UPDATE_TIME >= CONFIG.TEXT_UPDATE_INTERVAL then
		AFUI.S.LAST_TEXT_UPDATE_TIME = now
		AFUI.updatePlayTime()
		AFUI.updateEventCurrency()

		UIRef.WayPointLabel.Text = "WAYPOINTS:  ".. CONFIG.CURRENT_WAYPOINT_TARGET .. "/" .. (PlaceConfig and #PlaceConfig.WAYPOINTS or 0)
		UIRef.WalkSpeedLabel.Text = "WALKSPEED:  " .. tostring(math.floor(Humanoid.WalkSpeed + 0.5))
		UIRef.DeathLabel.Text = "DEATH:  " .. tostring(AFFeature.S.DEATH_COUNT)
	end

	if Feature.DebugVisualizer.Enabled then
		AFDebug.UpdateDebugWaypointColors()
	end

	--// Feeds the jump logic. Only counts while the character is actually
	--// trying to move, so standing still on purpose is not read as stuck.
	AFCombatUtils.UpdateStuckTracker(now, Humanoid.MoveDirection.Magnitude > 0.1)

	--// Realtime Mob Validation
	if now - AFCombat.S.LAST_MOB_VALIDATION_TIME >= CONFIG.MOB_VALIDATION_INTERVAL then
		AFCombat.S.LAST_MOB_VALIDATION_TIME = now
		AFCombat.UpdateValidMobs()
	end

	if not AFFeature.S.Enabled then
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

	if AFFeature.HandleDeadzoneEscape() then
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

	--// Watches every nearby mob rather than only the current target, and
	--// latches for a short hold so a flickering sound or emitter cannot drop
	--// the dodge partway through.
	local EnemyUsingSkill = AFCombat.UpdateSkillThreat(now)

	if EnemyUsingSkill then
		AFCombat.S.RETREATING = true
	end

	--// Execute: a target this close to death is finished instead of retreated
	--// from, at any health of our own. An enemy skill still overrides it,
	--// because eating a skill to land one more hit is not a good trade.
	local ExecuteCharge = false
	local ExecutePercent = math.clamp(tonumber(CONFIG.EXECUTE_CHARGE_HP_PERCENT) or 0, 0, 90)

	if ExecutePercent > 0 and not EnemyUsingSkill and AFCombat.S.ClosestTarget then
		local TargetHumanoid = AFCombat.S.ClosestTarget:FindFirstChildOfClass("Humanoid")

		if TargetHumanoid
			and TargetHumanoid.MaxHealth > 0
			and TargetHumanoid.Health > 0
		then
			ExecuteCharge =
				(TargetHumanoid.Health / TargetHumanoid.MaxHealth) * 100 <= ExecutePercent
		end
	end

	--// Retreat is a health decision only. The old build also entered retreat
	--// whenever WalkSpeed had not been raised yet, but RenderStepped restores
	--// WalkSpeed every frame, so that clause only produced random retreats.
	if ExecuteCharge then
		AFCombat.S.RETREATING = false
	elseif EmergencyHealth then
		AFCombat.S.RETREATING = true
	elseif AFCombat.S.RETREATING and Humanoid.Health >= Humanoid.MaxHealth * (RecoverHealthPercent / 100) and not EnemyUsingSkill then
		AFCombat.S.RETREATING = false

		--// Re-acquire a valid target immediately after healing so the
		--// combat loop does not wait for another target cycle.
		if not AFCombat.IsTargetLockValid(AFCombat.S.ClosestTarget) then
			AFCombat.S.ClosestTarget = AFCombat.GetClosestGoblin()
		end
	end

	if AFCombat.S.RETREATING then
		--// PlayerStats is already resolved above in this same handler.
		local UseConsumable = Replicated:FindFirstChild("UseConsumable", true)

		AFCombat.RetreatFromGoblins(EnemyUsingSkill)

		local LastConsumed = PlayerStats and PlayerStats:FindFirstChild("LastConsumed")
		local WantsConsume = UseConsumable
			and LastConsumed
			and LastConsumed.Value ~= ""
			and (EmergencyHealth or ShouldHeal)
			and now - AFFeature.S.LAST_CONSUME_TIME >= CONFIG.CONSUME_INTERVAL
			--// Never stop to drink mid-dodge. Getting out of the skill first
			--// is worth more than the heal, and sheathing costs an animation.
			and not EnemyUsingSkill

		--// Sheathe only when a potion is actually about to be drunk. The old
		--// build sheathed on every retreat frame and drew again as soon as
		--// the retreat ended, which is where the constant draw/sheathe came
		--// from, and each toggle also threw away the frame it happened on.
		if WantsConsume
			and InputBindableFunction
			and (AFFeature.S.Equipped or (MainWeld.Part1 and MainWeld.Part1.Name ~= "UpperTorso"))
			and now - AFFeature.S.LAST_EQUIP_TIME >= CONFIG.EQUIP_TOGGLE_COOLDOWN
		then
			AFFeature.S.Equipped = false
			AFFeature.S.LAST_EQUIP_TIME = now

			InputBindableFunction:Invoke(
				"EquipButton",
				Enum.UserInputState.Begin
			)

			return
		end

		if WantsConsume and not AFFeature.S.Equipped then
			AFFeature.S.LAST_CONSUME_TIME = now
			UseConsumable:InvokeServer(LastConsumed.Value)
		end

		return
	end

	--// Enemy skill retreat speed is temporary. Once retreating ends,
	--// return to the normal movement cap on the next heartbeat.
	if not EnemyUsingSkill and Humanoid.WalkSpeed > CONFIG.MAXIMUM_WALKSPEED then
		Humanoid.WalkSpeed = CONFIG.MAXIMUM_WALKSPEED
	end

	--// Player Check
	--// Whitelisted players are ignored entirely, so a server holding only
	--// them is left alone. Anyone else is blocked individually and then the
	--// server is abandoned; the whole lobby is no longer blocked one by one.
	if AFFeature.S.BlockEnabled then
		local Intruder = nil

		for _, plr in Players:GetPlayers() do
			if plr ~= Player and not AFFeature.IsWhitelisted(plr.UserId) then
				Intruder = plr
				break
			end
		end

		if Intruder then
			if not AFFeature.isBlocked(Intruder.UserId) then
				AFFeature.promptBlockPlayer(Intruder)
				return
			end

			AFFeature.S.BlockCache[Intruder.UserId] = nil
			AFFeature.TeleportToPlace()
			return
		end
	end

	--// Play Time
	if workspace.DistributedGameTime >= CONFIG.MAX_SERVER_AGE then
		AFFeature.TeleportToPlace()
		return
	end

	--// Movement
	--// Waypoint route always has priority over combat/patrol.
	--// Combat target acquisition is completely disabled until the route is finished.
	local HasWaypoints = PlaceConfig and type(PlaceConfig.WAYPOINTS) == "table" and #PlaceConfig.WAYPOINTS > 0
	local WaypointIndex = tonumber(CONFIG.CURRENT_WAYPOINT_TARGET) or 1
	local target = nil

	if HasWaypoints then
		if WaypointIndex < 1 then
			WaypointIndex = 1
			CONFIG.CURRENT_WAYPOINT_TARGET = 1
		end

		local WaypointCount = #PlaceConfig.WAYPOINTS
		local AtLastWaypoint = WaypointIndex > WaypointCount
		target = not AtLastWaypoint and PlaceConfig.WAYPOINTS[WaypointIndex] or nil

		--// Route mode: never let combat target state leak into waypoint movement.
		if not Feature.AutoFind.Enabled and target then
			AFCombat.S.ClosestTarget = nil
			AFCombat.S.TargetPath = nil
			AFCombat.S.TargetPathMob = nil
			AFCombat.S.TargetApproachMob = nil
			AFCombat.S.TargetApproachPosition = nil
			AFCombat.S.RETREATING = false

			local WaypointOffset = target - RootPart.Position
			local WaypointHorizontalDistance = Vector3.new(
				WaypointOffset.X,
				0,
				WaypointOffset.Z
			).Magnitude
			local WaypointVerticalDistance = math.abs(WaypointOffset.Y)
			local ReachDistance = tonumber(PlaceConfig.REACH_DISTANCE) or 5

			if WaypointHorizontalDistance <= ReachDistance
				and WaypointVerticalDistance <= math.max(ReachDistance, CONFIG.JUMP_HEIGHT + 2)
			then
				CONFIG.CURRENT_WAYPOINT_TARGET = WaypointIndex + 1
				AFCombatUtils.S.LAST_STUCK_POSITION = nil
				AFCombatUtils.S.LAST_STUCK_TIME = now
				AFDebug.UpdateDebugWaypointColors()

				WaypointIndex = CONFIG.CURRENT_WAYPOINT_TARGET
				target = PlaceConfig.WAYPOINTS[WaypointIndex]
			end

			if target then
				FaceOrientation.Enabled = false
				Humanoid.AutoRotate = true
				Humanoid:MoveTo(target)
			end

			if now - AFCombatUtils.S.LAST_STUCK_TIME >= CONFIG.STUCK_CHECK_INTERVAL then
				AFCombatUtils.S.LAST_STUCK_TIME = now
				if AFCombatUtils.S.LAST_STUCK_POSITION
					and (RootPart.Position - AFCombatUtils.S.LAST_STUCK_POSITION).Magnitude < 1
				then
					AFCombatUtils.DoJump()
				else
					AFCombatUtils.S.LAST_STUCK_POSITION = RootPart.Position
				end
			end

		else
			--// Final waypoint reached: only now allow farm-zone return/combat/patrol.
			local OutsideFarmZone = not AFCombatUtils.IsInsideFarmArea(RootPart.Position)
			local InFarmDeadzone = AFCombatUtils.IsInsideFarmDeadzone(RootPart.Position)

			if Feature.ReturnToFarmZone.Enabled
				and not Feature.IgnoreFarmZone.Enabled
				and (OutsideFarmZone or InFarmDeadzone)
			then
				AFCombat.S.ClosestTarget = nil
				AFFeature.CancelPatrol()
				AFFeature.MoveBackToFarmZone()
			else
				if not AFCombat.S.ClosestTarget or not AFCombat.IsTargetLockValid(AFCombat.S.ClosestTarget) then
					AFCombat.S.ClosestTarget = AFCombat.AcquireCombatTarget(now)
				else
					local LockedTarget = AFCombat.AcquireCombatTarget(now)
					if LockedTarget then
						AFCombat.S.ClosestTarget = LockedTarget
					end
				end

				if AFCombat.S.ClosestTarget then
					--// Combat outranks patrolling, so drop whatever the
					--// patrol was doing rather than leaving a pause or a leg
					--// chain to resume once the fight is over.
					AFFeature.CancelPatrol()
					AFCombat.MoveToGoblin(AFCombat.S.ClosestTarget)
				elseif Feature.AutoPatrol.Enabled then
					AFFeature.MoveToPatrol()
				else
					PatrolState.PatrolPosition = nil
					AFFeature.S.FarmReturnPosition = nil
					FaceOrientation.Enabled = false
					Humanoid.AutoRotate = true
					Humanoid:Move(Vector3.zero)
				end
			end
		end

	else
		--// No configured waypoints: preserve the original combat/patrol flow.
		local OutsideFarmZone = not AFCombatUtils.IsInsideFarmArea(RootPart.Position)
		local InFarmDeadzone = AFCombatUtils.IsInsideFarmDeadzone(RootPart.Position)

		if Feature.ReturnToFarmZone.Enabled
			and not Feature.IgnoreFarmZone.Enabled
			and (OutsideFarmZone or InFarmDeadzone)
		then
			AFCombat.S.ClosestTarget = nil
			AFFeature.CancelPatrol()
			AFFeature.MoveBackToFarmZone()
		else
			if not AFCombat.S.ClosestTarget or not AFCombat.IsTargetLockValid(AFCombat.S.ClosestTarget) then
				AFCombat.S.ClosestTarget = AFCombat.AcquireCombatTarget(now)
			else
				local LockedTarget = AFCombat.AcquireCombatTarget(now)
				if LockedTarget then
					AFCombat.S.ClosestTarget = LockedTarget
				end
			end

			if AFCombat.S.ClosestTarget then
				--// Combat outranks patrolling, so drop whatever the patrol
				--// was doing rather than leaving a pause or a leg chain to
				--// resume once the fight is over.
				AFFeature.CancelPatrol()
				AFCombat.MoveToGoblin(AFCombat.S.ClosestTarget)
			elseif Feature.AutoPatrol.Enabled then
				AFFeature.MoveToPatrol()
			else
				PatrolState.PatrolPosition = nil
				AFFeature.S.FarmReturnPosition = nil
				FaceOrientation.Enabled = false
				Humanoid.AutoRotate = true
				Humanoid:Move(Vector3.zero)
			end
		end
	end

	--// Jump. A waypoint sitting higher is not a reason on its own: a ramp
	--// climbs fine on foot, and hopping up one only costs speed. Probe for
	--// something actually in the way instead.
	if PlaceConfig and not Feature.AutoFind.Enabled and target then
		AFCombatUtils.DoJumpIfObstacle(target)
	end

	--// Swim Recovery
	if Humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		AFCombatUtils.DoJump()
		return
	end

	if Humanoid.Sit == true then
		Humanoid.Sit = false
		AFCombatUtils.DoJump()
		return
	end

	--// Combat
	--// Never enter combat while a configured waypoint route is still active.
	local WaypointRouteFinished = not HasWaypoints
		or (tonumber(CONFIG.CURRENT_WAYPOINT_TARGET) or 1) > #PlaceConfig.WAYPOINTS

	if WaypointRouteFinished
		and (Feature.AutoFind.Enabled or not HasWaypoints or (AFCombat.S.ClosestTarget and not Feature.IgnoreFarmZone.Enabled)) then
		if AFCombat.S.ClosestTarget then
			if not AFCombat.IsTargetLockValid(AFCombat.S.ClosestTarget) then
				AFCombat.S.ClosestTarget = nil
				return
			end

			if not AFCombat.IsCombatTargetValid(AFCombat.S.ClosestTarget) then
				FaceOrientation.Enabled = false
				Humanoid.AutoRotate = true
				Humanoid:Move(Vector3.zero)
				return
			end

			if (not AFFeature.S.Equipped or (MainWeld.Part1 and MainWeld.Part1.Name == "UpperTorso"))
				and now - AFFeature.S.LAST_EQUIP_TIME >= CONFIG.EQUIP_TOGGLE_COOLDOWN
			then
				AFFeature.S.Equipped = true
				AFFeature.S.LAST_EQUIP_TIME = now

				InputBindableFunction:Invoke(
					"EquipButton",
					Enum.UserInputState.Begin
				)

				return
			end

			local MobHumanoid = AFCombat.S.ClosestTarget:FindFirstChildOfClass("Humanoid")
			local MobRoot     = AFCombat.S.ClosestTarget:FindFirstChild("HumanoidRootPart")

			if MobHumanoid and MobRoot and MobHumanoid.Health > 0 then
				AFCombat.PerformCombatActions(AFCombat.S.ClosestTarget, now)
			else
				AFCombat.S.ValidMobs[AFCombat.S.ClosestTarget] = nil
				AFCombat.S.ClosestTarget = nil
			end
		end
	else
		if now - AFFeature.S.LAST_INTERACTION_TIME >= CONFIG.INTERACTION_INTERVAL then
			AFFeature.S.LAST_INTERACTION_TIME = now

			InputBindableFunction:Invoke(
				"InteractButton",
				Enum.UserInputState.Begin
			)
		end
	end
end)

