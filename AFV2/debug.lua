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
	Ring.CFrame = CFrame.new(Center + Vector3.new(0, -2, 0)) * CFrame.Angles(0, 0, math.rad(90))
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
	Surface.CFrame = CFrame.new(Center + Vector3.new(0, -2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	Surface.Parent = ZoneFolder

	local Highlight = Instance.new("Highlight")
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.FillColor = Color
	Highlight.FillTransparency = 0.5
	Highlight.OutlineTransparency = 1
	Highlight.Adornee = Ring
	Highlight.Parent = Ring

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
