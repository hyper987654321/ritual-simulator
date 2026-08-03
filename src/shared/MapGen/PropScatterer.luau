local MapGenConfig = require(script.Parent:WaitForChild("MapGenConfig"))
local PropDefinitions = require(script.Parent:WaitForChild("PropDefinitions"))
local SeededRandom = require(script.Parent:WaitForChild("SeededRandom"))
local Util = require(script.Parent:WaitForChild("BlockWriterUtil"))

local PropScatterer = {}

local BIG_PROP_EDGE_SIDES = { "West", "East", "North", "South" }
local DIRECTIONAL_PROP_TYPES = {
	AnimalSkull = true,
	OreVein = true,
	RitualLamp = true,
	SignPost = true,
}

local function firstAllowed(allowedTypes, fallback)
	return if typeof(allowedTypes) == "table" and allowedTypes[1] ~= nil then allowedTypes[1] else fallback
end

local function getPropSet(zonePlan)
	return MapGenConfig.getPropSet(zonePlan.Theme.PropSet)
end

local function getYawFacingPosition(position, target, rng)
	local dx = target.X - position.X
	local dz = target.Z - position.Z

	if math.abs(dx) + math.abs(dz) <= 0.001 then
		return rng:NextNumber(0, math.pi * 2)
	end

	return math.atan(-dx, -dz)
end

local function getBuildOptions(propType, zonePlan, position, rng, minScale, maxScale)
	local options = {
		Scale = rng:NextNumber(minScale, maxScale),
	}

	if DIRECTIONAL_PROP_TYPES[propType] == true then
		options.Yaw = getYawFacingPosition(position, zonePlan.BoundsCenter, rng)
	end

	return options
end

local function isNearAnyCrystalAnchor(zonePlan, x, z, radius)
	local radiusSquared = radius * radius

	for _, anchor in ipairs(zonePlan.CrystalAnchors) do
		if Util.distanceSquared2D(anchor.Position, x, z) <= radiusSquared then
			return true
		end
	end

	return false
end

local function getPrimaryTravelAxis(plan, zonePlan)
	local hasVerticalConnection = Util.hasConnectionOnSide(plan, zonePlan, "North") or Util.hasConnectionOnSide(plan, zonePlan, "South")
	local hasHorizontalConnection = Util.hasConnectionOnSide(plan, zonePlan, "East") or Util.hasConnectionOnSide(plan, zonePlan, "West")

	if hasVerticalConnection or not hasHorizontalConnection then
		return "Z"
	end

	return "X"
end

local function isInBigPropClearLane(plan, zonePlan, x, z)
	local sections = plan.Preset.Sections
	local laneWidth = sections.BigPropNoSpawnLaneWidth or math.max(34, (sections.WallGateWidth or 30) + 8)
	local axis = getPrimaryTravelAxis(plan, zonePlan)

	if axis == "Z" then
		return math.abs(x - zonePlan.BoundsCenter.X) <= laneWidth / 2
	end

	return math.abs(z - zonePlan.BoundsCenter.Z) <= laneWidth / 2
end

local function isNearGateOpening(plan, zonePlan, x, z)
	local sections = plan.Preset.Sections
	local gateHalfWidth = (sections.WallGateWidth or sections.BridgeWidth or 18) / 2
	local margin = sections.BigPropExitMargin or 24
	local walls = {}

	if zonePlan.UnlockWall ~= nil then
		table.insert(walls, zonePlan.UnlockWall)
	end

	local nextZonePlan = Util.getNextZonePlan(plan, zonePlan)

	if nextZonePlan ~= nil and nextZonePlan.UnlockWall ~= nil then
		table.insert(walls, nextZonePlan.UnlockWall)
	end

	for _, wall in ipairs(walls) do
		if wall.Size.X >= wall.Size.Z then
			if math.abs(x - wall.Center.X) <= gateHalfWidth + margin and math.abs(z - wall.Center.Z) <= margin then
				return true
			end
		elseif math.abs(z - wall.Center.Z) <= gateHalfWidth + margin and math.abs(x - wall.Center.X) <= margin then
			return true
		end
	end

	return false
end

local function isReservedForPath(plan, x, z, extraPadding)
	local pathPlan = plan.PathPlan
	local props = plan.Preset.Props or {}
	local padding = extraPadding or props.MinimumPathPadding or 5

	return pathPlan:getDistanceToMainPath(x, z) <= pathPlan.MainWidth / 2 + padding
end

local function isReservedForBigProp(plan, zonePlan, x, z)
	local sections = plan.Preset.Sections
	local pathPlan = plan.PathPlan

	if pathPlan:getDistanceToMainPath(x, z) <= (sections.BigPropNoSpawnLaneWidth or pathPlan.MainWidth + 24) / 2 then
		return true
	end

	if isInBigPropClearLane(plan, zonePlan, x, z) then
		return true
	end

	if isNearGateOpening(plan, zonePlan, x, z) then
		return true
	end

	if zonePlan.TeleportPosition ~= nil then
		if Util.distanceSquared2D(zonePlan.TeleportPosition, x, z) <= 24 * 24 then
			return true
		end
	end

	if zonePlan.AscensionPosition ~= nil then
		if Util.distanceSquared2D(zonePlan.AscensionPosition, x, z) <= 18 * 18 then
			return true
		end
	end

	if Util.isInsideArea2D(zonePlan.CrystalArea, x, z, sections.BigPropCrystalMargin or 16) then
		return true
	end

	if isNearAnyCrystalAnchor(zonePlan, x, z, 18) then
		return true
	end

	return false
end

local function isReservedForSmallProp(plan, zonePlan, x, z, footprint)
	local props = plan.Preset.Props or {}

	if isReservedForPath(plan, x, z, (props.MinimumPathPadding or 5) + footprint * 0.2) then
		return true
	end

	if zonePlan.TeleportPosition ~= nil then
		if Util.distanceSquared2D(zonePlan.TeleportPosition, x, z) <= 9 * 9 then
			return true
		end
	end

	if zonePlan.AscensionPosition ~= nil then
		if Util.distanceSquared2D(zonePlan.AscensionPosition, x, z) <= 9 * 9 then
			return true
		end
	end

	if isNearAnyCrystalAnchor(zonePlan, x, z, props.MinimumAnchorPadding or 6) then
		return true
	end

	return false
end

local function isReservedForCrystalDecor(zonePlan, x, z)
	if not Util.isInsideArea2D(zonePlan.CrystalArea, x, z, -2) then
		return true
	end

	if zonePlan.TeleportPosition ~= nil then
		if Util.distanceSquared2D(zonePlan.TeleportPosition, x, z) <= 16 * 16 then
			return true
		end
	end

	return isNearAnyCrystalAnchor(zonePlan, x, z, 5)
end

local function getEdgeBandPosition(plan, zonePlan, rng, side, inset)
	local bounds = Util.getBounds(plan, zonePlan)
	local topY = Util.getZoneTopY(plan)
	local minX = bounds.MinX + inset
	local maxX = bounds.MaxX - inset
	local minZ = bounds.MinZ + inset
	local maxZ = bounds.MaxZ - inset

	if side == "West" then
		return Vector3.new(bounds.MinX + inset + rng:NextNumber(-1.5, 5.5), topY, rng:NextNumber(minZ, maxZ))
	elseif side == "East" then
		return Vector3.new(bounds.MaxX - inset + rng:NextNumber(-5.5, 1.5), topY, rng:NextNumber(minZ, maxZ))
	elseif side == "North" then
		return Vector3.new(rng:NextNumber(minX, maxX), topY, bounds.MinZ + inset + rng:NextNumber(-1.5, 5.5))
	end

	return Vector3.new(rng:NextNumber(minX, maxX), topY, bounds.MaxZ - inset + rng:NextNumber(-5.5, 1.5))
end

local function getClusteredEdgePosition(plan, zonePlan, rng, side, inset, center, radius)
	local bounds = Util.getBounds(plan, zonePlan)
	local topY = Util.getZoneTopY(plan)
	local minX = bounds.MinX + inset
	local maxX = bounds.MaxX - inset
	local minZ = bounds.MinZ + inset
	local maxZ = bounds.MaxZ - inset
	local along = rng:NextNumber(-radius, radius)
	local inward = rng:NextNumber(-2, radius * 0.55)

	if side == "West" then
		return Vector3.new(
			Util.clampWithin(center.X + inward, minX, maxX),
			topY,
			Util.clampWithin(center.Z + along, minZ, maxZ)
		)
	elseif side == "East" then
		return Vector3.new(
			Util.clampWithin(center.X - inward, minX, maxX),
			topY,
			Util.clampWithin(center.Z + along, minZ, maxZ)
		)
	elseif side == "North" then
		return Vector3.new(
			Util.clampWithin(center.X + along, minX, maxX),
			topY,
			Util.clampWithin(center.Z + inward, minZ, maxZ)
		)
	end

	return Vector3.new(
		Util.clampWithin(center.X + along, minX, maxX),
		topY,
		Util.clampWithin(center.Z - inward, minZ, maxZ)
	)
end

local function isFarEnough(slots, position, minSpacing)
	for _, slot in ipairs(slots) do
		local spacing = math.max(minSpacing, slot.Footprint or 0)

		if Util.distanceSquared2D(slot.Position, position.X, position.Z) < spacing * spacing then
			return false
		end
	end

	return true
end

local function addBigPropSlot(plan, zonePlan, rng, propSet, slots, position, minSpacing)
	if isReservedForBigProp(plan, zonePlan, position.X, position.Z) then
		return false
	end

	local propType = PropDefinitions.pickWeighted(rng, zonePlan.Theme.BigPropWeights, firstAllowed(propSet.BigProps, "BlockTree"), propSet.BigProps)
	local footprint = PropDefinitions.getFootprint(propType)
	local spacing = math.max(minSpacing, footprint)

	if not isFarEnough(slots, position, spacing) then
		return false
	end

	table.insert(slots, {
		Footprint = footprint,
		Position = position,
		PropType = propType,
	})

	return true
end

local function getSeededBigPropSlots(plan, zonePlan, rng, propSet, target)
	local sections = plan.Preset.Sections
	local inset = math.max(15, (sections.VisibleWallThickness or 6) + (sections.TreeCanopyRadius or 4.8) + 6)
	local minSpacing = sections.BigPropMinSpacing or 9
	local clusterRadius = sections.BigPropClusterRadius or 14
	local clusterCount = rng:NextInteger(2, 4)
	local slots = {}

	for _ = 1, clusterCount do
		if #slots >= target then
			break
		end

		local side = BIG_PROP_EDGE_SIDES[rng:NextInteger(1, #BIG_PROP_EDGE_SIDES)]
		local center = getEdgeBandPosition(plan, zonePlan, rng, side, inset)
		local clusterSize = rng:NextInteger(1, 3)

		for _ = 1, clusterSize do
			if #slots >= target then
				break
			end

			addBigPropSlot(
				plan,
				zonePlan,
				rng,
				propSet,
				slots,
				getClusteredEdgePosition(plan, zonePlan, rng, side, inset, center, clusterRadius),
				minSpacing
			)
		end
	end

	for _ = 1, target * 12 do
		if #slots >= target then
			break
		end

		local side = BIG_PROP_EDGE_SIDES[rng:NextInteger(1, #BIG_PROP_EDGE_SIDES)]

		addBigPropSlot(plan, zonePlan, rng, propSet, slots, getEdgeBandPosition(plan, zonePlan, rng, side, inset), minSpacing)
	end

	return slots
end

local function createPropModel(parent, plan, zonePlan, name, propType, position)
	local model = Util.createModel(parent, plan, zonePlan.ZoneId, "Prop", name)

	model:SetAttribute("PropType", propType)
	model:SetAttribute("SourceX", position.X)
	model:SetAttribute("SourceZ", position.Z)

	return model
end

local function scatterBigProps(plan, zonePlan, propsFolder, propSet)
	local sections = plan.Preset.Sections
	local rng = SeededRandom.create(plan.Seed, zonePlan.ZoneId, 2401)
	local baseTarget = Util.getZoneNumber(sections.BigPropCountPerZone, zonePlan.ZoneId, sections.DefaultBigPropCount or 6)
	local target = if baseTarget <= 0 then 0 else math.max(0, baseTarget + rng:NextInteger(-2, 2))
	local slots = getSeededBigPropSlots(plan, zonePlan, rng, propSet, target)
	local occupiedSlots = {}
	local placed = 0

	for _, slot in ipairs(slots) do
		if placed >= target then
			break
		end

		local position = slot.Position

		if position ~= nil and not isReservedForBigProp(plan, zonePlan, position.X, position.Z) then
			placed += 1

			local propType = slot.PropType or "BlockTree"
			local propModel = createPropModel(propsFolder, plan, zonePlan, "BigProp_" .. tostring(placed), propType, position)

			table.insert(occupiedSlots, {
				Footprint = slot.Footprint or PropDefinitions.getFootprint(propType),
				Position = position,
			})
			PropDefinitions.build(propType, propModel, plan, zonePlan, position, rng, placed, getBuildOptions(propType, zonePlan, position, rng, 0.9, 1.16))
		end
	end

	return placed, occupiedSlots
end

local function tryPlaceOuterProp(plan, zonePlan, propsFolder, propType, rng, slots, propIndex, attempts)
	local props = plan.Preset.Props or {}
	local bounds = Util.getBounds(plan, zonePlan)
	local footprint = PropDefinitions.getFootprint(propType)
	local inset = math.max(6, footprint)

	for _ = 1, attempts do
		local x = rng:NextNumber(bounds.MinX + inset, bounds.MaxX - inset)
		local z = rng:NextNumber(bounds.MinZ + inset, bounds.MaxZ - inset)
		local position = Vector3.new(x, Util.getZoneTopY(plan), z)

		if not isReservedForSmallProp(plan, zonePlan, x, z, footprint) and isFarEnough(slots, position, math.max(footprint, props.MinimumAnchorPadding or 6)) then
			table.insert(slots, {
				Footprint = footprint,
				Position = position,
			})

			local propModel = createPropModel(propsFolder, plan, zonePlan, "Prop_" .. tostring(propIndex), propType, position)

			PropDefinitions.build(propType, propModel, plan, zonePlan, position, rng, propIndex, getBuildOptions(propType, zonePlan, position, rng, 0.82, 1.12))

			return true
		end
	end

	return false
end

local function scatterOuterProps(plan, zonePlan, propsFolder, propSet, occupiedSlots)
	local sections = plan.Preset.Sections
	local props = plan.Preset.Props or {}
	local rng = SeededRandom.create(plan.Seed, zonePlan.ZoneId, 2301)
	local requiredProps = if typeof(propSet.RequiredProps) == "table" then propSet.RequiredProps else {}
	local target = math.max(Util.getZoneNumber(sections.PropCountPerZone, zonePlan.ZoneId, sections.DefaultPropCount or 16), #requiredProps)
	local slots = occupiedSlots or {}
	local placed = 0
	local attempts = math.max(target, target * (props.MaxAttemptsMultiplier or 8))

	for _, propType in ipairs(requiredProps) do
		if placed >= target then
			break
		end

		if PropDefinitions.get(propType) ~= nil and tryPlaceOuterProp(plan, zonePlan, propsFolder, propType, rng, slots, placed + 1, 48) then
			placed += 1
		end
	end

	for _ = 1, attempts do
		if placed >= target then
			break
		end

		local propType = PropDefinitions.pickWeighted(rng, zonePlan.Theme.PropWeights, firstAllowed(propSet.Props, "RockCluster"), propSet.Props)
		if tryPlaceOuterProp(plan, zonePlan, propsFolder, propType, rng, slots, placed + 1, 1) then
			placed += 1
		end
	end

	return placed, slots
end

local function scatterCrystalDecor(plan, zonePlan, propsFolder, propSet, startIndex, occupiedSlots)
	local sections = plan.Preset.Sections
	local rng = SeededRandom.create(plan.Seed, zonePlan.ZoneId, 2501)
	local target = Util.getZoneNumber(sections.CrystalDecorCountPerZone, zonePlan.ZoneId, sections.DefaultCrystalDecorCount or 8)
	local crystalAreaBounds = Util.getAreaBounds(zonePlan.CrystalArea)
	local slots = occupiedSlots or {}
	local placed = 0

	if crystalAreaBounds == nil then
		return 0
	end

	for _ = 1, target * 12 do
		if placed >= target then
			break
		end

		local x = rng:NextNumber(crystalAreaBounds.MinX + 4, crystalAreaBounds.MaxX - 4)
		local z = rng:NextNumber(crystalAreaBounds.MinZ + 4, crystalAreaBounds.MaxZ - 4)

		local position = Vector3.new(x, Util.getZoneTopY(plan), z)
		local propType = PropDefinitions.pickWeighted(rng, zonePlan.Theme.CrystalDecorWeights, firstAllowed(propSet.CrystalDecor, "CrystalCluster"), propSet.CrystalDecor)
		local footprint = PropDefinitions.getFootprint(propType)

		if not isReservedForCrystalDecor(zonePlan, x, z) and isFarEnough(slots, position, math.max(footprint, 4)) then
			placed += 1

			local propIndex = startIndex + placed
			local propModel = createPropModel(propsFolder, plan, zonePlan, "CrystalDecor_" .. tostring(placed), propType, position)

			table.insert(slots, {
				Footprint = footprint,
				Position = position,
			})
			PropDefinitions.build(propType, propModel, plan, zonePlan, position, rng, propIndex, getBuildOptions(propType, zonePlan, position, rng, 0.62, 0.86))
		end
	end

	return placed, slots
end

function PropScatterer.scatter(plan, zonePlan, propsFolder)
	local propSet = getPropSet(zonePlan)
	local bigCount, occupiedSlots = scatterBigProps(plan, zonePlan, propsFolder, propSet)
	local outerCount
	local crystalCount

	outerCount, occupiedSlots = scatterOuterProps(plan, zonePlan, propsFolder, propSet, occupiedSlots)
	crystalCount = scatterCrystalDecor(plan, zonePlan, propsFolder, propSet, bigCount + outerCount, occupiedSlots)

	return {
		BigProps = bigCount,
		OuterProps = outerCount,
		CrystalDecor = crystalCount,
		Total = bigCount + outerCount + crystalCount,
	}
end

return PropScatterer
