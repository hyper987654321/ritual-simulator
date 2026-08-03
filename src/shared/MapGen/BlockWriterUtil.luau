local CollectionService = game:GetService("CollectionService")

local MapGenConfig = require(script.Parent:WaitForChild("MapGenConfig"))

local BlockWriterUtil = {}

function BlockWriterUtil.addMetadata(instance, plan, zoneId, kind)
	instance:SetAttribute("GeneratedBy", MapGenConfig.GeneratedBy)
	instance:SetAttribute("Seed", plan.Seed)
	instance:SetAttribute("Preset", plan.PresetName)
	instance:SetAttribute("MapStyle", "BlockSections")

	if typeof(zoneId) == "number" then
		instance:SetAttribute("ZoneId", zoneId)
	end

	if kind ~= nil then
		instance:SetAttribute("GeneratedKind", kind)
	end

	CollectionService:AddTag(instance, MapGenConfig.GeneratedTag)
end

function BlockWriterUtil.getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil and existing:IsA(className) then
		return existing
	end

	if existing ~= nil then
		existing:Destroy()
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent

	return instance
end

function BlockWriterUtil.clearChildren(folder)
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

function BlockWriterUtil.prepareZoneFolders(plan, root)
	local zonesFolder = root:WaitForChild("Zones")

	for _, zonePlan in ipairs(plan.ZonePlans) do
		local zoneFolder = zonesFolder:WaitForChild("Zone_" .. tostring(zonePlan.ZoneId))

		for _, folderName in ipairs({ "Blocks", "Walls", "Barriers", "Props", "Structures", "Debug" }) do
			local folder = BlockWriterUtil.getOrCreate(zoneFolder, "Folder", folderName)

			BlockWriterUtil.addMetadata(folder, plan, zonePlan.ZoneId, folderName)
			BlockWriterUtil.clearChildren(folder)
		end
	end
end

function BlockWriterUtil.createPart(parent, plan, zoneId, kind, name, properties)
	local safeProperties = properties or {}
	local className = safeProperties.ClassName or "Part"
	local part = Instance.new(className)

	part.Name = name
	part.Anchored = true
	part.CanCollide = if safeProperties.CanCollide == nil then true else safeProperties.CanCollide
	part.CanQuery = if safeProperties.CanQuery == nil then true else safeProperties.CanQuery
	part.CanTouch = false
	part.Material = safeProperties.Material or Enum.Material.Plastic
	part.Color = safeProperties.Color or Color3.fromRGB(255, 255, 255)
	part.Size = safeProperties.Size or Vector3.new(4, 4, 4)
	part.CFrame = safeProperties.CFrame or CFrame.new(safeProperties.Position or Vector3.zero)
	part.Transparency = safeProperties.Transparency or 0
	part.TopSurface = safeProperties.TopSurface or Enum.SurfaceType.Studs
	part.BottomSurface = safeProperties.BottomSurface or Enum.SurfaceType.Inlet
	part.LeftSurface = safeProperties.LeftSurface or Enum.SurfaceType.Smooth
	part.RightSurface = safeProperties.RightSurface or Enum.SurfaceType.Smooth
	part.FrontSurface = safeProperties.FrontSurface or Enum.SurfaceType.Smooth
	part.BackSurface = safeProperties.BackSurface or Enum.SurfaceType.Smooth

	if safeProperties.Shape ~= nil and part:IsA("Part") then
		part.Shape = safeProperties.Shape
	end

	if safeProperties.CastShadow ~= nil then
		part.CastShadow = safeProperties.CastShadow
	end

	if safeProperties.Reflectance ~= nil then
		part.Reflectance = safeProperties.Reflectance
	end

	part.Parent = parent

	BlockWriterUtil.addMetadata(part, plan, zoneId, kind)

	return part
end

function BlockWriterUtil.createModel(parent, plan, zoneId, kind, name)
	local model = Instance.new("Model")

	model.Name = name
	model.Parent = parent
	BlockWriterUtil.addMetadata(model, plan, zoneId, kind)

	return model
end

function BlockWriterUtil.getColor(theme, key, fallback)
	local colors = theme.Colors or {}

	return colors[key] or fallback
end

function BlockWriterUtil.getZoneTopY(plan)
	return plan.Preset.Sections.TopY
end

function BlockWriterUtil.getBounds(plan, zonePlan)
	local sections = plan.Preset.Sections
	local paddingX = sections.VisualPaddingX or sections.VisualPadding or 0
	local paddingZ = sections.VisualPaddingZ or sections.VisualPadding or 0

	return {
		MinX = zonePlan.BoundsCenter.X - zonePlan.BoundsSize.X / 2 - paddingX,
		MaxX = zonePlan.BoundsCenter.X + zonePlan.BoundsSize.X / 2 + paddingX,
		MinZ = zonePlan.BoundsCenter.Z - zonePlan.BoundsSize.Z / 2 - paddingZ,
		MaxZ = zonePlan.BoundsCenter.Z + zonePlan.BoundsSize.Z / 2 + paddingZ,
		SizeX = zonePlan.BoundsSize.X + paddingX * 2,
		SizeZ = zonePlan.BoundsSize.Z + paddingZ * 2,
	}
end

function BlockWriterUtil.getZoneIndex(plan, zonePlan)
	for index, candidate in ipairs(plan.ZonePlans) do
		if candidate.ZoneId == zonePlan.ZoneId then
			return index
		end
	end

	return nil
end

function BlockWriterUtil.getConnectionSideFromWall(zonePlan, wall)
	if wall == nil then
		return nil
	end

	local delta = wall.Center - zonePlan.BoundsCenter

	if math.abs(delta.X) >= math.abs(delta.Z) then
		return if delta.X >= 0 then "East" else "West"
	end

	return if delta.Z >= 0 then "South" else "North"
end

function BlockWriterUtil.getNextZonePlan(plan, zonePlan)
	local zoneIndex = BlockWriterUtil.getZoneIndex(plan, zonePlan)

	return if zoneIndex ~= nil then plan.ZonePlans[zoneIndex + 1] else nil
end

function BlockWriterUtil.hasConnectionOnSide(plan, zonePlan, side)
	if BlockWriterUtil.getConnectionSideFromWall(zonePlan, zonePlan.UnlockWall) == side then
		return true
	end

	local nextZonePlan = BlockWriterUtil.getNextZonePlan(plan, zonePlan)

	if nextZonePlan ~= nil and BlockWriterUtil.getConnectionSideFromWall(zonePlan, nextZonePlan.UnlockWall) == side then
		return true
	end

	return false
end

function BlockWriterUtil.getAreaBounds(area)
	if area == nil then
		return nil
	end

	return {
		MinX = area.Center.X - area.Size.X / 2,
		MaxX = area.Center.X + area.Size.X / 2,
		MinZ = area.Center.Z - area.Size.Z / 2,
		MaxZ = area.Center.Z + area.Size.Z / 2,
		SizeX = area.Size.X,
		SizeZ = area.Size.Z,
	}
end

function BlockWriterUtil.isInsideArea2D(area, x, z, margin)
	local areaBounds = BlockWriterUtil.getAreaBounds(area)

	if areaBounds == nil then
		return false
	end

	local safeMargin = margin or 0

	return x >= areaBounds.MinX - safeMargin
		and x <= areaBounds.MaxX + safeMargin
		and z >= areaBounds.MinZ - safeMargin
		and z <= areaBounds.MaxZ + safeMargin
end

function BlockWriterUtil.setStudSurfaces(part)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
end

function BlockWriterUtil.distanceSquared2D(position, x, z)
	local dx = x - position.X
	local dz = z - position.Z

	return dx * dx + dz * dz
end

function BlockWriterUtil.clampWithin(value, minValue, maxValue)
	if minValue > maxValue then
		return (minValue + maxValue) / 2
	end

	return math.clamp(value, minValue, maxValue)
end

function BlockWriterUtil.getZoneNumber(value, zoneId, fallback)
	if typeof(value) == "number" then
		return value
	end

	if typeof(value) == "table" then
		local zoneValue = value[zoneId]

		if typeof(zoneValue) == "number" then
			return zoneValue
		end

		if typeof(value.Default) == "number" then
			return value.Default
		end
	end

	return fallback
end

return BlockWriterUtil
