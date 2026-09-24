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
