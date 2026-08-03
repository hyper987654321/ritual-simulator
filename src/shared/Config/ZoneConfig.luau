local ZoneConfig = {}

local ZONE_SPACING = 172

local ZONE_DEFINITIONS = {
	{
		DisplayName = "Sprout Meadow",
		Family = "Nature",
		Tier = 1,
		UnlockCost = 0,
		BoundsSize = Vector3.new(156, 0, 136),
		CrystalAreaSize = Vector3.new(46, 0, 42),
		CrystalHealth = 12,
		CrystalEssenceReward = 6,
		CrystalColor = Color3.fromRGB(103, 228, 255),
	},
	{
		DisplayName = "Bloom Grove",
		Family = "Nature",
		Tier = 2,
		UnlockCost = 200,
		BoundsSize = Vector3.new(144, 0, 136),
		CrystalAreaSize = Vector3.new(50, 0, 44),
		CrystalHealth = 34,
		CrystalEssenceReward = 28,
		CrystalColor = Color3.fromRGB(113, 231, 255),
	},
	{
		DisplayName = "Elderwood Garden",
		Family = "Nature",
		Tier = 3,
		UnlockCost = 600,
		BoundsSize = Vector3.new(148, 0, 140),
		CrystalAreaSize = Vector3.new(52, 0, 46),
		CrystalHealth = 95,
		CrystalEssenceReward = 82,
		CrystalColor = Color3.fromRGB(255, 176, 74),
	},
	{
		DisplayName = "Stone Quarry",
		Family = "Mines",
		Tier = 1,
		UnlockCost = 1600,
		BoundsSize = Vector3.new(120, 0, 122),
		CrystalAreaSize = Vector3.new(52, 0, 48),
		CrystalHealth = 260,
		CrystalEssenceReward = 220,
		CrystalColor = Color3.fromRGB(155, 171, 255),
	},
	{
		DisplayName = "Crystal Mine",
		Family = "Mines",
		Tier = 2,
		UnlockCost = 4200,
		BoundsSize = Vector3.new(124, 0, 124),
		CrystalAreaSize = Vector3.new(54, 0, 50),
		CrystalHealth = 720,
		CrystalEssenceReward = 620,
		CrystalColor = Color3.fromRGB(120, 214, 255),
	},
	{
		DisplayName = "Deepcore Vein",
		Family = "Mines",
		Tier = 3,
		UnlockCost = 10000,
		BoundsSize = Vector3.new(128, 0, 126),
		CrystalAreaSize = Vector3.new(56, 0, 52),
		CrystalHealth = 1800,
		CrystalEssenceReward = 1500,
		CrystalColor = Color3.fromRGB(86, 232, 255),
	},
	{
		DisplayName = "Broken Courtyard",
		Family = "Ruins",
		Tier = 1,
		UnlockCost = 24000,
		BoundsSize = Vector3.new(128, 0, 128),
		CrystalAreaSize = Vector3.new(56, 0, 52),
		CrystalHealth = 4600,
		CrystalEssenceReward = 3800,
		CrystalColor = Color3.fromRGB(185, 116, 255),
	},
	{
		DisplayName = "Ancient Sanctum",
		Family = "Ruins",
		Tier = 2,
		UnlockCost = 56000,
		BoundsSize = Vector3.new(132, 0, 130),
		CrystalAreaSize = Vector3.new(58, 0, 54),
		CrystalHealth = 11500,
		CrystalEssenceReward = 9600,
		CrystalColor = Color3.fromRGB(221, 167, 255),
	},
	{
		DisplayName = "Relic Terrace",
		Family = "Ruins",
		Tier = 3,
		UnlockCost = 130000,
		BoundsSize = Vector3.new(136, 0, 132),
		CrystalAreaSize = Vector3.new(60, 0, 56),
		CrystalHealth = 28500,
		CrystalEssenceReward = 24000,
		CrystalColor = Color3.fromRGB(255, 218, 92),
	},
	{
		DisplayName = "Ash Flats",
		Family = "Infernal",
		Tier = 1,
		UnlockCost = 300000,
		BoundsSize = Vector3.new(136, 0, 134),
		CrystalAreaSize = Vector3.new(60, 0, 56),
		CrystalHealth = 70000,
		CrystalEssenceReward = 58000,
		CrystalColor = Color3.fromRGB(255, 132, 100),
	},
	{
		DisplayName = "Magma Quarry",
		Family = "Infernal",
		Tier = 2,
		UnlockCost = 700000,
		BoundsSize = Vector3.new(140, 0, 136),
		CrystalAreaSize = Vector3.new(62, 0, 58),
		CrystalHealth = 170000,
		CrystalEssenceReward = 140000,
		CrystalColor = Color3.fromRGB(255, 88, 82),
	},
	{
		DisplayName = "Hellbone Gate",
		Family = "Infernal",
		Tier = 3,
		UnlockCost = 1600000,
		BoundsSize = Vector3.new(144, 0, 138),
		CrystalAreaSize = Vector3.new(64, 0, 60),
		CrystalHealth = 420000,
		CrystalEssenceReward = 350000,
		CrystalColor = Color3.fromRGB(255, 45, 74),
	},
	{
		DisplayName = "Snowfield",
		Family = "Frost",
		Tier = 1,
		UnlockCost = 3600000,
		BoundsSize = Vector3.new(140, 0, 136),
		CrystalAreaSize = Vector3.new(62, 0, 58),
		CrystalHealth = 1000000,
		CrystalEssenceReward = 850000,
		CrystalColor = Color3.fromRGB(215, 255, 253),
	},
	{
		DisplayName = "Glacier Grove",
		Family = "Frost",
		Tier = 2,
		UnlockCost = 8000000,
		BoundsSize = Vector3.new(144, 0, 138),
		CrystalAreaSize = Vector3.new(64, 0, 60),
		CrystalHealth = 2400000,
		CrystalEssenceReward = 2000000,
		CrystalColor = Color3.fromRGB(107, 241, 255),
	},
	{
		DisplayName = "Frozen Spire",
		Family = "Frost",
		Tier = 3,
		UnlockCost = 18000000,
		BoundsSize = Vector3.new(148, 0, 140),
		CrystalAreaSize = Vector3.new(66, 0, 62),
		CrystalHealth = 6000000,
		CrystalEssenceReward = 5000000,
		CrystalColor = Color3.fromRGB(72, 220, 255),
	},
}

ZoneConfig.ZoneOrder = {}
ZoneConfig.Zones = {}

for zoneId, definition in ipairs(ZONE_DEFINITIONS) do
	table.insert(ZoneConfig.ZoneOrder, zoneId)

	ZoneConfig.Zones[zoneId] = {
		DisplayName = definition.DisplayName,
		Family = definition.Family,
		Tier = definition.Tier,
		UnlockCost = definition.UnlockCost,
		Origin = Vector3.new(0, 0, -(zoneId - 1) * ZONE_SPACING),
		BoundsOffset = Vector3.new(0, 0, 0),
		BoundsSize = definition.BoundsSize,
		CrystalAreaOffset = Vector3.new(0, 0, -8),
		CrystalAreaSize = definition.CrystalAreaSize,
		CrystalHealth = definition.CrystalHealth,
		CrystalEssenceReward = definition.CrystalEssenceReward,
		CrystalColor = definition.CrystalColor,
		CrystalCount = 5,
		CrystalSpawnHeight = 2,
		CrystalSpawnPadding = 7 + math.floor((definition.Tier - 1) / 2),
	}
end

ZoneConfig.Zones[1].MapFeatures = {
	{
		Id = "Leaderboard",
		Type = "Leaderboard",
		Offset = Vector3.new(-58, 0, 34),
		Size = Vector3.new(22, 0, 12),
		Facing = "East",
	},
}

ZoneConfig.UnlockWallHeight = 15
ZoneConfig.UnlockWallThickness = 3
ZoneConfig.UnlockWallWidth = 30
ZoneConfig.UnlockPromptDistance = 18

function ZoneConfig.getZone(zoneId)
	return ZoneConfig.Zones[zoneId]
end

function ZoneConfig.getZoneIds()
	local zoneIds = {}

	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		table.insert(zoneIds, zoneId)
	end

	return zoneIds
end

function ZoneConfig.getZoneMapFeatures(zoneId)
	local zone = ZoneConfig.getZone(zoneId)

	return if zone ~= nil and zone.MapFeatures ~= nil then zone.MapFeatures else {}
end

function ZoneConfig.getPreviousZoneId(zoneId)
	for index, orderedZoneId in ipairs(ZoneConfig.ZoneOrder) do
		if orderedZoneId == zoneId then
			return ZoneConfig.ZoneOrder[index - 1]
		end
	end

	return nil
end

function ZoneConfig.getCrystalCount(zoneId)
	local zone = ZoneConfig.getZone(zoneId)

	return if zone ~= nil then math.max(1, zone.CrystalCount or 5) else 0
end

function ZoneConfig.getZoneBounds(zoneId)
	local zone = ZoneConfig.getZone(zoneId)

	if zone == nil then
		return nil
	end

	local origin = zone.Origin or Vector3.new(0, 0, 0)
	local boundsOffset = zone.BoundsOffset or Vector3.new(0, 0, -5)
	local boundsSize = zone.BoundsSize or Vector3.new(58, 0, 66)

	return {
		Center = origin + boundsOffset,
		Size = boundsSize,
	}
end

function ZoneConfig.isPositionInsideBounds(zoneId, position)
	if typeof(position) ~= "Vector3" then
		return false
	end

	local bounds = ZoneConfig.getZoneBounds(zoneId)

	if bounds == nil then
		return false
	end

	local halfSize = bounds.Size / 2
	local delta = position - bounds.Center
	-- A zero-height bounds size means the zone is an X/Z area.
	local isInsideY = bounds.Size.Y <= 0 or math.abs(delta.Y) <= halfSize.Y

	return math.abs(delta.X) <= halfSize.X and isInsideY and math.abs(delta.Z) <= halfSize.Z
end

function ZoneConfig.getCrystalArea(zoneId)
	local zone = ZoneConfig.getZone(zoneId)
	local bounds = ZoneConfig.getZoneBounds(zoneId)

	if zone == nil or bounds == nil then
		return nil
	end

	local areaSize = zone.CrystalAreaSize or Vector3.new(
		math.min(52, bounds.Size.X * 0.46),
		0,
		math.min(48, bounds.Size.Z * 0.42)
	)
	local areaOffset = zone.CrystalAreaOffset or Vector3.new(0, 0, -bounds.Size.Z * 0.08)

	return {
		Center = bounds.Center + areaOffset,
		Size = areaSize,
	}
end

function ZoneConfig.isPositionInsideCrystalArea(zoneId, position, margin)
	if typeof(position) ~= "Vector3" then
		return false
	end

	local area = ZoneConfig.getCrystalArea(zoneId)

	if area == nil then
		return false
	end

	local safeMargin = margin or 0
	local halfSize = area.Size / 2
	local delta = position - area.Center

	return math.abs(delta.X) <= halfSize.X + safeMargin and math.abs(delta.Z) <= halfSize.Z + safeMargin
end

function ZoneConfig.getZoneIdForPosition(position)
	for _, zoneId in ipairs(ZoneConfig.ZoneOrder) do
		if ZoneConfig.isPositionInsideBounds(zoneId, position) then
			return zoneId
		end
	end

	return nil
end

function ZoneConfig.getUnlockWall(zoneId)
	local previousZoneId = ZoneConfig.getPreviousZoneId(zoneId)

	if previousZoneId == nil then
		return nil
	end

	local previousBounds = ZoneConfig.getZoneBounds(previousZoneId)
	local zoneBounds = ZoneConfig.getZoneBounds(zoneId)

	if previousBounds == nil or zoneBounds == nil then
		return nil
	end

	local delta = zoneBounds.Center - previousBounds.Center
	local height = ZoneConfig.UnlockWallHeight
	local thickness = ZoneConfig.UnlockWallThickness
	local width = ZoneConfig.UnlockWallWidth
	local center = nil
	local size = nil

	if math.abs(delta.X) >= math.abs(delta.Z) then
		local direction = if delta.X >= 0 then 1 else -1
		local previousEdge = previousBounds.Center.X + direction * previousBounds.Size.X / 2
		local zoneEdge = zoneBounds.Center.X - direction * zoneBounds.Size.X / 2

		center = Vector3.new((previousEdge + zoneEdge) / 2, height / 2, (previousBounds.Center.Z + zoneBounds.Center.Z) / 2)
		size = Vector3.new(thickness, height, width)
	else
		local direction = if delta.Z >= 0 then 1 else -1
		local previousEdge = previousBounds.Center.Z + direction * previousBounds.Size.Z / 2
		local zoneEdge = zoneBounds.Center.Z - direction * zoneBounds.Size.Z / 2

		center = Vector3.new((previousBounds.Center.X + zoneBounds.Center.X) / 2, height / 2, (previousEdge + zoneEdge) / 2)
		size = Vector3.new(width, height, thickness)
	end

	return {
		Center = center,
		Size = size,
		PromptDistance = ZoneConfig.UnlockPromptDistance,
	}
end

function ZoneConfig.isPositionNearUnlockWall(zoneId, position)
	if typeof(position) ~= "Vector3" then
		return false
	end

	local wall = ZoneConfig.getUnlockWall(zoneId)

	if wall == nil then
		return false
	end

	local deltaX = position.X - wall.Center.X
	local deltaZ = position.Z - wall.Center.Z
	local promptDistance = wall.PromptDistance or ZoneConfig.UnlockPromptDistance

	return deltaX * deltaX + deltaZ * deltaZ <= promptDistance * promptDistance
end

function ZoneConfig.getRandomCrystalPosition(zoneId, random)
	local zone = ZoneConfig.getZone(zoneId)
	local area = ZoneConfig.getCrystalArea(zoneId)

	if zone == nil or area == nil then
		return Vector3.new(0, 2, 0)
	end

	local rng = random or Random.new()
	local padding = zone.CrystalSpawnPadding or 7
	local halfX = math.max(1, area.Size.X / 2 - padding)
	local halfZ = math.max(1, area.Size.Z / 2 - padding)
	local x = rng:NextNumber(area.Center.X - halfX, area.Center.X + halfX)
	local z = rng:NextNumber(area.Center.Z - halfZ, area.Center.Z + halfZ)
	local y = (zone.Origin or Vector3.new()).Y + (zone.CrystalSpawnHeight or 2)

	return Vector3.new(x, y, z)
end

function ZoneConfig.getTeleportPosition(zoneId)
	local zone = ZoneConfig.getZone(zoneId) or ZoneConfig.getZone(1)
	local bounds = ZoneConfig.getZoneBounds(zoneId) or ZoneConfig.getZoneBounds(1)
	local origin = if zone ~= nil then zone.Origin or Vector3.new(0, 0, 0) else Vector3.new(0, 0, 0)
	local center = if bounds ~= nil then bounds.Center else origin
	local fallbackSpawnZ = if bounds ~= nil then bounds.Size.Z / 2 - 18 else 32
	local offset = if zone ~= nil and zone.SpawnOffset ~= nil then zone.SpawnOffset else Vector3.new(0, 0, fallbackSpawnZ)

	return Vector3.new(center.X + offset.X, origin.Y + 4, center.Z + offset.Z)
end

function ZoneConfig.getTeleportCFrame(zoneId)
	local spawnPosition = ZoneConfig.getTeleportPosition(zoneId)
	local crystalArea = ZoneConfig.getCrystalArea(zoneId)
	local lookAtPosition = if crystalArea ~= nil
		then Vector3.new(crystalArea.Center.X, spawnPosition.Y, crystalArea.Center.Z)
		else spawnPosition + Vector3.new(0, 0, -1)

	return CFrame.lookAt(spawnPosition, lookAtPosition)
end

function ZoneConfig.getSpawnPosition(zoneId)
	return ZoneConfig.getTeleportPosition(zoneId)
end

function ZoneConfig.getSpawnCFrame(zoneId)
	return ZoneConfig.getTeleportCFrame(zoneId)
end

return ZoneConfig
