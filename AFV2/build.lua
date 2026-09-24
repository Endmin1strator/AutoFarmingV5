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

UIRef.StatusTab = UI:AddTab("Status")
UIRef.FarmTab = UI:AddTab("Farming")
UIRef.MineTab = UI:AddTab("Mining")
UIRef.CraftTab = UI:AddTab("Crafting")
UIRef.PartyTab = UI:AddTab("Party")
UIRef.DebugTab = UI:AddTab("Debug")

UIRef.FeatureSection  = UIRef.FarmTab:AddSection("Features")
UIRef.TargetSection   = UIRef.FarmTab:AddSection("Targeting")
UIRef.BlockSection    = UIRef.FarmTab:AddSection("Auto Block")
UIRef.StatusSection   = UIRef.StatusTab:AddSection("Live Status")
UIRef.DebugSection    = UIRef.DebugTab:AddSection("Debug Visualizer")
UIRef.MineSection     = UIRef.MineTab:AddSection("Mine Zone")
UIRef.CraftSection    = UIRef.CraftTab:AddSection("Auto Crafting")
UIRef.PartySection    = UIRef.PartyTab:AddSection("Party System")

--// Mining Dropdown
UIRef.OreDropdown = UIRef.MineSection:AddDropdown(
	"Add Ores",
	CONFIG.PREFERED_ORES,
	function(Value)
		--TODO
	end
)

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

			if StatValue.Value < CONFIG.STAT_RESET_THRESHOLD then
				StatsEvent:FireServer(stat, 0)
			else
				NotifyAction("RESET STATS", `Cannot reset "{stat}" exceeded {CONFIG.STAT_RESET_THRESHOLD}.`)
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

