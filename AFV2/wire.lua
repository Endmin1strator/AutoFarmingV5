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

