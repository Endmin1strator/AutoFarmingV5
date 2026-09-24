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
