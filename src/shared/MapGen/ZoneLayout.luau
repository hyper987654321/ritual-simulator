local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local MapGenConfig = require(script.Parent:WaitForChild("MapGenConfig"))
local SeededRandom = require(script.Parent:WaitForChild("SeededRandom"))

local ZoneLayout = {}

local function withY(position, y)
	return Vector3.new(position.X, y, position.Z)
end

local function getBoundsCornerMin(bounds)
	return Vector3.new(
		bounds.Center.X - bounds.Size.X / 2,
		0,
		bounds.Center.Z - bounds.Size.Z / 2
	)
end

local function getBoundsCornerMax(bounds)
	return Vector3.new(
		bounds.Center.X + bounds.Size.X / 2,
		0,
		bounds.Center.Z + bounds.Size.Z / 2
	)
end

local function getCrystalAnchors(seed, zoneId, zone, crystalArea, theme, preset)
	local crystalCount = ZoneConfig.getCrystalCount(zoneId)
	local rng = SeededRandom.create(seed, zoneId, 401)
	local anchors = {}
	local radius = math.min(crystalArea.Size.X, crystalArea.Size.Z) * 0.32
	local angleOffset = rng:NextNumber(-0.35, 0.35)

	for index = 1, crystalCount do
		local angle = ((index - 1) / crystalCount) * math.pi * 2 + angleOffset + rng:NextNumber(-0.16, 0.16)
		local radialJitter = rng:NextNumber(-1.8, 1.8)
		local x = crystalArea.Center.X + math.cos(angle) * (radius + radialJitter)
		local z = crystalArea.Center.Z + math.sin(angle) * (radius + radialJitter)
		local halfX = crystalArea.Size.X / 2 - (zone.CrystalSpawnPadding or 7)
		local halfZ = crystalArea.Size.Z / 2 - (zone.CrystalSpawnPadding or 7)

		x = math.clamp(x, crystalArea.Center.X - halfX, crystalArea.Center.X + halfX)
		z = math.clamp(z, crystalArea.Center.Z - halfZ, crystalArea.Center.Z + halfZ)

		table.insert(anchors, {
			Name = "Crystal_" .. tostring(index),
			AnchorType = "Crystal",
			Index = index,
			Position = Vector3.new(x, theme.BaseHeight + 1, z),
			Radius = preset.Path.CrystalArenaRadius,
		})
	end

	return anchors
end

local function getFeatureSlots(zoneId, bounds, theme)
	local slots = {}

	for _, feature in ipairs(ZoneConfig.getZoneMapFeatures(zoneId)) do
		local offset = feature.Offset or Vector3.zero
		local position = bounds.Center + offset

		table.insert(slots, {
			Id = feature.Id or feature.Type or "Feature",
			Type = feature.Type or "Feature",
			Position = Vector3.new(position.X, theme.BaseHeight + 1, position.Z),
			Size = feature.Size or Vector3.new(12, 0, 12),
			Facing = feature.Facing or "South",
		})
	end

	return slots
end

function ZoneLayout.build(seed, presetName)
	local preset = MapGenConfig.getPreset(presetName)
	local zonePlans = {}

	for _, zoneId in ipairs(ZoneConfig.getZoneIds()) do
		local zone = ZoneConfig.getZone(zoneId)
		local bounds = ZoneConfig.getZoneBounds(zoneId)
		local crystalArea = ZoneConfig.getCrystalArea(zoneId)

		if zone ~= nil and bounds ~= nil and crystalArea ~= nil then
			local theme = MapGenConfig.getZoneTheme(zoneId)
			local teleportPosition = withY(ZoneConfig.getTeleportCFrame(zoneId).Position, theme.BaseHeight + 1)
			local playerSpawnPosition = if zoneId == 1 then teleportPosition else nil
			local unlockWall = ZoneConfig.getUnlockWall(zoneId)
			local ascensionPosition = nil

			if zoneId == ZoneConfig.ZoneOrder[#ZoneConfig.ZoneOrder] then
				local z = bounds.Center.Z - bounds.Size.Z / 2 + 10
				ascensionPosition = Vector3.new(bounds.Center.X, theme.BaseHeight + 1, z)
			end

			table.insert(zonePlans, {
				ZoneId = zoneId,
				DisplayName = zone.DisplayName,
				Origin = zone.Origin or Vector3.zero,
				BoundsCenter = bounds.Center,
				BoundsSize = bounds.Size,
				BoundsMin = getBoundsCornerMin(bounds),
				BoundsMax = getBoundsCornerMax(bounds),
				CrystalCount = ZoneConfig.getCrystalCount(zoneId),
				CrystalArea = crystalArea,
				Theme = theme,
				TeleportPosition = teleportPosition,
				PlayerSpawnPosition = playerSpawnPosition,
				UnlockWall = unlockWall,
				AscensionPosition = ascensionPosition,
				CrystalAnchors = getCrystalAnchors(seed, zoneId, zone, crystalArea, theme, preset),
				FeatureSlots = getFeatureSlots(zoneId, bounds, theme),
				ArenaRadius = preset.Path.CrystalArenaRadius,
			})
		end
	end

	return zonePlans
end

return ZoneLayout
