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
		Humanoid.AutoRotate = false
		Humanoid:MoveTo(OtherPlayerDetour)
		AFCombat.FaceGoblin(Goblin)
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
