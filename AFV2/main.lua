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


