local SeededRandom = require(script.Parent:WaitForChild("SeededRandom"))
local Util = require(script.Parent:WaitForChild("BlockWriterUtil"))

local ZoneBlockWriter = {}

local function createBlock(parent, plan, zonePlan, kind, name, position, size, color)
	local part = Util.createPart(parent, plan, zonePlan.ZoneId, kind, name, {
		Color = color,
		Material = Enum.Material.Plastic,
		Size = size,
		Position = position,
	})

	Util.setStudSurfaces(part)

	return part
end

local function createWallCap(parent, plan, zonePlan, name, position, size, color)
	local sections = plan.Preset.Sections
	local capHeight = sections.WallCapHeight or 2
	local overhang = sections.WallCapOverhang or 2
	local cap = Util.createPart(parent, plan, zonePlan.ZoneId, "WallCap", name .. "_Cap", {
		Color = color,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(size.X + overhang * 2, capHeight, size.Z + overhang * 2),
		Position = Vector3.new(position.X, position.Y + size.Y / 2 + capHeight / 2, position.Z),
	})

	Util.setStudSurfaces(cap)
end

local function getWallNormal(orientation)
	if orientation == "North" then
		return 0, -1
	elseif orientation == "South" then
		return 0, 1
	elseif orientation == "West" then
		return -1, 0
	end

	return 1, 0
end

local function createWallDrips(parent, plan, zonePlan, name, orientation, position, size, color, rng)
	local sections = plan.Preset.Sections
	local length = if orientation == "North" or orientation == "South" then size.X else size.Z
	local maxDrips = sections.WallDripCount or 8
	local dripCount = math.max(1, math.min(maxDrips, math.floor(length / 14)))
	local normalX, normalZ = getWallNormal(orientation)

	for dripIndex = 1, dripCount do
		local dripLength = rng:NextNumber(2.2, math.max(2.4, math.min(8.5, size.Y - 1.5)))
		local dripWidth = rng:NextNumber(1.3, 3.6)
		local dripX = position.X
		local dripZ = position.Z
		local dripSize = nil

		if orientation == "North" or orientation == "South" then
			dripX = rng:NextNumber(position.X - size.X / 2 + 2, position.X + size.X / 2 - 2)
			dripZ = position.Z + normalZ * (size.Z / 2 + 0.32)
			dripSize = Vector3.new(dripWidth, dripLength, 0.72)
		else
			dripX = position.X + normalX * (size.X / 2 + 0.32)
			dripZ = rng:NextNumber(position.Z - size.Z / 2 + 2, position.Z + size.Z / 2 - 2)
			dripSize = Vector3.new(0.72, dripLength, dripWidth)
		end

		local drip = Util.createPart(parent, plan, zonePlan.ZoneId, "WallDrip", name .. "_Drip_" .. tostring(dripIndex), {
			CanCollide = false,
			Color = color,
			Material = Enum.Material.Plastic,
			Size = dripSize,
			Position = Vector3.new(dripX, position.Y + size.Y / 2 - dripLength / 2 + rng:NextNumber(-0.45, 0.45), dripZ),
		})

		Util.setStudSurfaces(drip)
	end
end

local function createWallFaceBlocks(parent, plan, zonePlan, name, orientation, position, size, color, rng)
	local sections = plan.Preset.Sections
	local length = if orientation == "North" or orientation == "South" then size.X else size.Z
	local maxBlocks = sections.WallFaceBlockCount or 4
	local blockCount = math.max(1, math.min(maxBlocks, math.floor(length / 8)))
	local normalX, normalZ = getWallNormal(orientation)

	for blockIndex = 1, blockCount do
		local blockLength = rng:NextNumber(2.0, 4.8)
		local blockHeight = rng:NextNumber(1.0, 2.2)
		local blockY = rng:NextNumber(position.Y - size.Y * 0.22, position.Y + size.Y * 0.22)
		local blockX = position.X
		local blockZ = position.Z
		local blockSize = nil

		if orientation == "North" or orientation == "South" then
			blockX = rng:NextNumber(position.X - size.X / 2 + 2, position.X + size.X / 2 - 2)
			blockZ = position.Z + normalZ * (size.Z / 2 + 0.24)
			blockSize = Vector3.new(blockLength, blockHeight, 0.48)
		else
			blockX = position.X + normalX * (size.X / 2 + 0.24)
			blockZ = rng:NextNumber(position.Z - size.Z / 2 + 2, position.Z + size.Z / 2 - 2)
			blockSize = Vector3.new(0.48, blockHeight, blockLength)
		end

		local detail = Util.createPart(parent, plan, zonePlan.ZoneId, "WallFaceBlock", name .. "_Face_" .. tostring(blockIndex), {
			CanCollide = false,
			Color = color,
			Material = Enum.Material.Plastic,
			Size = blockSize,
			Position = Vector3.new(blockX, blockY, blockZ),
			Transparency = rng:NextNumber(0.04, 0.16),
		})

		Util.setStudSurfaces(detail)
	end
end

local function createVisibleWallSegment(parent, plan, zonePlan, name, orientation, position, size, wallColor, capColor, rng)
	createBlock(parent, plan, zonePlan, "VisibleWall", name, position, size, wallColor)
	createWallCap(parent, plan, zonePlan, name, position, size, capColor)
	createWallDrips(parent, plan, zonePlan, name, orientation, position, size, capColor, rng)
	createWallFaceBlocks(parent, plan, zonePlan, name, orientation, position, size, wallColor:Lerp(capColor, 0.16), rng)
end

local function getIntervals(minValue, maxValue, openingCenter, openingWidth)
	if openingWidth <= 0 then
		return {
			{ Min = minValue, Max = maxValue },
		}
	end

	local openMin = math.clamp(openingCenter - openingWidth / 2, minValue, maxValue)
	local openMax = math.clamp(openingCenter + openingWidth / 2, minValue, maxValue)
	local intervals = {}

	if openMin - minValue > 4 then
		table.insert(intervals, {
			Min = minValue,
			Max = openMin,
		})
	end

	if maxValue - openMax > 4 then
		table.insert(intervals, {
			Min = openMax,
			Max = maxValue,
		})
	end

	return intervals
end

local function nextChunkLength(rng, remaining, minLength, maxLength)
	local length = math.min(rng:NextNumber(minLength, maxLength), remaining)

	if remaining - length < minLength * 0.5 then
		return remaining
	end

	return length
end

local function createHorizontalWallChunks(parent, plan, zonePlan, name, side, z, minX, maxX, openingCenterX, openingWidth, thickness, height, wallColor, capColor, rng)
	local sections = plan.Preset.Sections
	local topY = Util.getZoneTopY(plan)
	local minLength = sections.WallChunkMinLength or 12
	local maxLength = sections.WallChunkMaxLength or 24
	local chunkOverlap = sections.WallChunkOverlap or 0.4
	local heightJitter = sections.WallHeightJitter or 1.8
	local thicknessJitter = sections.WallThicknessJitter or 0.8
	local insetJitter = sections.WallInsetJitter or 1.2

	for intervalIndex, interval in ipairs(getIntervals(minX, maxX, openingCenterX, openingWidth)) do
		local cursor = interval.Min
		local chunkIndex = 0

		while cursor < interval.Max - 4 do
			local remaining = interval.Max - cursor
			local length = nextChunkLength(rng, remaining, minLength, maxLength)
			local localHeight = math.max(5, height + rng:NextNumber(-heightJitter, heightJitter))
			local localThickness = math.max(3, thickness + rng:NextNumber(-thicknessJitter, thicknessJitter))
			local centerX = cursor + length / 2
			local localZ = z + rng:NextNumber(-insetJitter, insetJitter)
			local localY = topY + localHeight / 2

			chunkIndex += 1
			createVisibleWallSegment(
				parent,
				plan,
				zonePlan,
				name .. "_" .. tostring(intervalIndex) .. "_" .. tostring(chunkIndex),
				side,
				Vector3.new(centerX, localY, localZ),
				Vector3.new(length, localHeight, localThickness),
				wallColor,
				capColor,
				rng
			)

			cursor += math.max(length - chunkOverlap, 4)
		end
	end
end

local function createVerticalWallChunks(parent, plan, zonePlan, name, side, x, minZ, maxZ, openingCenterZ, openingWidth, thickness, height, wallColor, capColor, rng)
	local sections = plan.Preset.Sections
	local topY = Util.getZoneTopY(plan)
	local minLength = sections.WallChunkMinLength or 12
	local maxLength = sections.WallChunkMaxLength or 24
	local chunkOverlap = sections.WallChunkOverlap or 0.4
	local heightJitter = sections.WallHeightJitter or 1.8
	local thicknessJitter = sections.WallThicknessJitter or 0.8
	local insetJitter = sections.WallInsetJitter or 1.2

	for intervalIndex, interval in ipairs(getIntervals(minZ, maxZ, openingCenterZ, openingWidth)) do
		local cursor = interval.Min
		local chunkIndex = 0

		while cursor < interval.Max - 4 do
			local remaining = interval.Max - cursor
			local length = nextChunkLength(rng, remaining, minLength, maxLength)
			local localHeight = math.max(5, height + rng:NextNumber(-heightJitter, heightJitter))
			local localThickness = math.max(3, thickness + rng:NextNumber(-thicknessJitter, thicknessJitter))
			local centerZ = cursor + length / 2
			local localX = x + rng:NextNumber(-insetJitter, insetJitter)
			local localY = topY + localHeight / 2

			chunkIndex += 1
			createVisibleWallSegment(
				parent,
				plan,
				zonePlan,
				name .. "_" .. tostring(intervalIndex) .. "_" .. tostring(chunkIndex),
				side,
				Vector3.new(localX, localY, centerZ),
				Vector3.new(localThickness, localHeight, length),
				wallColor,
				capColor,
				rng
			)

			cursor += math.max(length - chunkOverlap, 4)
		end
	end
end

local function createInvisibleWallSegment(parent, plan, zonePlan, name, position, size)
	Util.createPart(parent, plan, zonePlan.ZoneId, "InvisibleWall", name, {
		CanQuery = false,
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.ForceField,
		Size = size,
		Position = position,
		Transparency = 1,
	})
end

function ZoneBlockWriter.createSectionFloor(plan, zonePlan, blocksFolder)
	local sections = plan.Preset.Sections
	local theme = zonePlan.Theme
	local bounds = Util.getBounds(plan, zonePlan)
	local topY = Util.getZoneTopY(plan)
	local mainColor = Util.getColor(theme, "BlockTop", Color3.fromRGB(132, 236, 67))
	local altColor = Util.getColor(theme, "BlockTopAlt", Color3.fromRGB(105, 213, 57))
	local floor = Util.createPart(blocksFolder, plan, zonePlan.ZoneId, "Floor", "SectionFloor", {
		Color = mainColor,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(bounds.SizeX, sections.FloorThickness, bounds.SizeZ),
		Position = Vector3.new(zonePlan.BoundsCenter.X, topY - sections.FloorThickness / 2, zonePlan.BoundsCenter.Z),
	})

	Util.setStudSurfaces(floor)

	local rng = SeededRandom.create(plan.Seed, zonePlan.ZoneId, 3101)
	local accentCount = sections.TileAccentCount or 0

	for index = 1, accentCount do
		local tileWidth = sections.TileSize * rng:NextInteger(1, 2)
		local tileDepth = sections.TileSize * rng:NextInteger(1, 2)
		local x = rng:NextNumber(bounds.MinX + tileWidth / 2, bounds.MaxX - tileWidth / 2)
		local z = rng:NextNumber(bounds.MinZ + tileDepth / 2, bounds.MaxZ - tileDepth / 2)
		local accent = Util.createPart(blocksFolder, plan, zonePlan.ZoneId, "FloorAccent", "TileAccent_" .. tostring(index), {
			CanCollide = false,
			Color = altColor,
			Material = Enum.Material.Plastic,
			Size = Vector3.new(tileWidth, 0.16, tileDepth),
			Position = Vector3.new(x, topY + 0.08, z),
			Transparency = rng:NextNumber(0.08, 0.22),
		})

		accent.TopSurface = Enum.SurfaceType.Studs
		accent.BottomSurface = Enum.SurfaceType.Smooth
	end
end

function ZoneBlockWriter.createBoundaryWalls(plan, zonePlan, wallsFolder, barriersFolder)
	local sections = plan.Preset.Sections
	local theme = zonePlan.Theme
	local bounds = Util.getBounds(plan, zonePlan)
	local sideColor = Util.getColor(theme, "BlockSide", Color3.fromRGB(215, 121, 94))
	local sideAltColor = Util.getColor(theme, "BlockSideAlt", Color3.fromRGB(177, 69, 67))
	local capColor = Util.getColor(theme, "BlockTop", Color3.fromRGB(132, 236, 67))
	local wallHeight = sections.VisibleWallHeight or 8
	local wallThickness = sections.VisibleWallThickness or 6
	local gateWidth = sections.WallGateWidth or (sections.BridgeWidth or 18) + 4
	local rng = SeededRandom.create(plan.Seed, zonePlan.ZoneId, 3201)

	createHorizontalWallChunks(
		wallsFolder,
		plan,
		zonePlan,
		"NorthVisibleWall",
		"North",
		bounds.MinZ + wallThickness / 2,
		bounds.MinX,
		bounds.MaxX,
		zonePlan.BoundsCenter.X,
		if Util.hasConnectionOnSide(plan, zonePlan, "North") then gateWidth else 0,
		wallThickness,
		wallHeight,
		sideAltColor,
		capColor,
		rng
	)
	createHorizontalWallChunks(
		wallsFolder,
		plan,
		zonePlan,
		"SouthVisibleWall",
		"South",
		bounds.MaxZ - wallThickness / 2,
		bounds.MinX,
		bounds.MaxX,
		zonePlan.BoundsCenter.X,
		if Util.hasConnectionOnSide(plan, zonePlan, "South") then gateWidth else 0,
		wallThickness,
		wallHeight,
		sideAltColor,
		capColor,
		rng
	)
	createVerticalWallChunks(
		wallsFolder,
		plan,
		zonePlan,
		"WestVisibleWall",
		"West",
		bounds.MinX + wallThickness / 2,
		bounds.MinZ,
		bounds.MaxZ,
		zonePlan.BoundsCenter.Z,
		if Util.hasConnectionOnSide(plan, zonePlan, "West") then gateWidth else 0,
		wallThickness,
		wallHeight,
		sideColor,
		capColor,
		rng
	)
	createVerticalWallChunks(
		wallsFolder,
		plan,
		zonePlan,
		"EastVisibleWall",
		"East",
		bounds.MaxX - wallThickness / 2,
		bounds.MinZ,
		bounds.MaxZ,
		zonePlan.BoundsCenter.Z,
		if Util.hasConnectionOnSide(plan, zonePlan, "East") then gateWidth else 0,
		wallThickness,
		wallHeight,
		sideColor,
		capColor,
		rng
	)

	local topY = Util.getZoneTopY(plan)
	local height = sections.InvisibleWallHeight
	local thickness = sections.InvisibleWallThickness
	local y = topY + height / 2

	local function createHorizontalBarrier(name, z, hasOpening)
		local function createSegment(segmentName, fromX, toX)
			local length = toX - fromX

			if length <= 4 then
				return
			end

			createInvisibleWallSegment(
				barriersFolder,
				plan,
				zonePlan,
				segmentName,
				Vector3.new((fromX + toX) / 2, y, z),
				Vector3.new(length, height, thickness)
			)
		end

		if not hasOpening then
			createSegment(name, bounds.MinX - thickness, bounds.MaxX + thickness)
			return
		end

		local openMin = math.clamp(zonePlan.BoundsCenter.X - gateWidth / 2, bounds.MinX - thickness, bounds.MaxX + thickness)
		local openMax = math.clamp(zonePlan.BoundsCenter.X + gateWidth / 2, bounds.MinX - thickness, bounds.MaxX + thickness)

		createSegment(name .. "_A", bounds.MinX - thickness, openMin)
		createSegment(name .. "_B", openMax, bounds.MaxX + thickness)
	end

	local function createVerticalBarrier(name, x, hasOpening)
		local function createSegment(segmentName, fromZ, toZ)
			local length = toZ - fromZ

			if length <= 4 then
				return
			end

			createInvisibleWallSegment(
				barriersFolder,
				plan,
				zonePlan,
				segmentName,
				Vector3.new(x, y, (fromZ + toZ) / 2),
				Vector3.new(thickness, height, length)
			)
		end

		if not hasOpening then
			createSegment(name, bounds.MinZ - thickness, bounds.MaxZ + thickness)
			return
		end

		local openMin = math.clamp(zonePlan.BoundsCenter.Z - gateWidth / 2, bounds.MinZ - thickness, bounds.MaxZ + thickness)
		local openMax = math.clamp(zonePlan.BoundsCenter.Z + gateWidth / 2, bounds.MinZ - thickness, bounds.MaxZ + thickness)

		createSegment(name .. "_A", bounds.MinZ - thickness, openMin)
		createSegment(name .. "_B", openMax, bounds.MaxZ + thickness)
	end

	createHorizontalBarrier("NorthInvisibleWall", bounds.MinZ - thickness / 2, Util.hasConnectionOnSide(plan, zonePlan, "North"))
	createHorizontalBarrier("SouthInvisibleWall", bounds.MaxZ + thickness / 2, Util.hasConnectionOnSide(plan, zonePlan, "South"))
	createVerticalBarrier("WestInvisibleWall", bounds.MinX - thickness / 2, Util.hasConnectionOnSide(plan, zonePlan, "West"))
	createVerticalBarrier("EastInvisibleWall", bounds.MaxX + thickness / 2, Util.hasConnectionOnSide(plan, zonePlan, "East"))
end

function ZoneBlockWriter.createBridgeBetweenZones(plan, previousZonePlan, nextZonePlan, root)
	local sections = plan.Preset.Sections
	local zonesFolder = root:WaitForChild("Zones")
	local nextFolder = zonesFolder:WaitForChild("Zone_" .. tostring(nextZonePlan.ZoneId))
	local blocksFolder = nextFolder:WaitForChild("Blocks")
	local wallsFolder = nextFolder:WaitForChild("Walls")
	local previousBounds = Util.getBounds(plan, previousZonePlan)
	local nextBounds = Util.getBounds(plan, nextZonePlan)
	local delta = nextZonePlan.BoundsCenter - previousZonePlan.BoundsCenter
	local isHorizontalBridge = math.abs(delta.X) >= math.abs(delta.Z)
	local bridgeSize = nil
	local bridgePosition = nil

	if isHorizontalBridge then
		local fromX = if delta.X >= 0 then previousBounds.MaxX else nextBounds.MaxX
		local toX = if delta.X >= 0 then nextBounds.MinX else previousBounds.MinX
		local widthX = toX - fromX

		if widthX <= 0 then
			return
		end

		bridgeSize = Vector3.new(widthX, sections.FloorThickness, sections.BridgeWidth or sections.WallGateWidth or 18)
		bridgePosition = Vector3.new((fromX + toX) / 2, Util.getZoneTopY(plan) - sections.FloorThickness / 2, (previousZonePlan.BoundsCenter.Z + nextZonePlan.BoundsCenter.Z) / 2)
	else
		local fromZ = if delta.Z >= 0 then previousBounds.MaxZ else nextBounds.MaxZ
		local toZ = if delta.Z >= 0 then nextBounds.MinZ else previousBounds.MinZ
		local widthZ = toZ - fromZ

		if widthZ <= 0 then
			return
		end

		bridgeSize = Vector3.new(sections.BridgeWidth or sections.WallGateWidth or 18, sections.FloorThickness, widthZ)
		bridgePosition = Vector3.new((previousZonePlan.BoundsCenter.X + nextZonePlan.BoundsCenter.X) / 2, Util.getZoneTopY(plan) - sections.FloorThickness / 2, (fromZ + toZ) / 2)
	end

	local bridge = Util.createPart(blocksFolder, plan, nextZonePlan.ZoneId, "Bridge", "BridgeFromZone_" .. tostring(previousZonePlan.ZoneId), {
		Color = Util.getColor(nextZonePlan.Theme, "Stone", Color3.fromRGB(115, 119, 120)),
		Material = Enum.Material.Plastic,
		Size = bridgeSize,
		Position = bridgePosition,
	})

	Util.setStudSurfaces(bridge)

	local bridgeWallHeight = sections.VisibleWallHeight or 15
	local bridgeWallThickness = sections.VisibleWallThickness or 6
	local bridgeWallY = Util.getZoneTopY(plan) + bridgeWallHeight / 2
	local wallColor = Util.getColor(previousZonePlan.Theme, "BlockSide", Color3.fromRGB(215, 121, 94))
	local wallAltColor = Util.getColor(previousZonePlan.Theme, "BlockSideAlt", Color3.fromRGB(177, 69, 67))
	local capColor = Util.getColor(previousZonePlan.Theme, "BlockTop", Color3.fromRGB(132, 236, 67))
	local rng = SeededRandom.create(plan.Seed, previousZonePlan.ZoneId, 4401 + nextZonePlan.ZoneId)

	for sideIndex, direction in ipairs({ -1, 1 }) do
		local orientation = nil
		local wallSize = nil
		local wallOffset = nil
		local color = if sideIndex == 1 then wallColor else wallAltColor

		if isHorizontalBridge then
			orientation = if direction < 0 then "North" else "South"
			wallSize = Vector3.new(bridgeSize.X, bridgeWallHeight, bridgeWallThickness)
			wallOffset = Vector3.new(0, 0, direction * (bridgeSize.Z / 2 + bridgeWallThickness / 2))
		else
			orientation = if direction < 0 then "West" else "East"
			wallSize = Vector3.new(bridgeWallThickness, bridgeWallHeight, bridgeSize.Z)
			wallOffset = Vector3.new(direction * (bridgeSize.X / 2 + bridgeWallThickness / 2), 0, 0)
		end

		createVisibleWallSegment(
			wallsFolder,
			plan,
			nextZonePlan,
			"BridgeSideWall_" .. tostring(previousZonePlan.ZoneId) .. "_" .. tostring(sideIndex),
			orientation,
			Vector3.new(bridgePosition.X + wallOffset.X, bridgeWallY, bridgePosition.Z + wallOffset.Z),
			wallSize,
			color,
			capColor,
			rng
		)
	end
end

function ZoneBlockWriter.createDebugBounds(plan, zonePlan, debugFolder, visible)
	if visible ~= true then
		return
	end

	local bounds = Util.getBounds(plan, zonePlan)

	Util.createPart(debugFolder, plan, zonePlan.ZoneId, "DebugBounds", "ZoneBounds", {
		CanCollide = false,
		CanQuery = false,
		Color = Util.getColor(zonePlan.Theme, "Barrier", Color3.fromRGB(156, 244, 255)),
		Material = Enum.Material.ForceField,
		Size = Vector3.new(bounds.SizeX, 0.18, bounds.SizeZ),
		Position = Vector3.new(zonePlan.BoundsCenter.X, Util.getZoneTopY(plan) + 0.15, zonePlan.BoundsCenter.Z),
		Transparency = 0.78,
	})
end

return ZoneBlockWriter
