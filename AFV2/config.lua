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
