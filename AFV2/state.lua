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

	PREFERED_ORES = { "Iron Ore", "Copper Ore", },

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
		Enabled = false,
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

local MiningFeature = {
	AutoMining = {
		Enabled = false,
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


