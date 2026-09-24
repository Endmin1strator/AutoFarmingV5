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
