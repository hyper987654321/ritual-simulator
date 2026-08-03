local ZoneConfig = require(script.Parent:WaitForChild("ZoneConfig"))

local AscensionConfig = {}

AscensionConfig.BaseRequiredZone = 15
AscensionConfig.RequiredZoneGrowth = 2
AscensionConfig.StarsPerAscension = 1

AscensionConfig.BonusPerAscension = {
	Luck = 0.5,
	CrystalEssenceMultiplier = 0.25,
	RitualPower = 2500,
}

AscensionConfig.Statue = {
	PromptDistance = 16,
	Size = Vector3.new(5, 7, 5),
	Color = Color3.fromRGB(255, 218, 92),
	AccentColor = Color3.fromRGB(255, 74, 214),
}

local function getSafeAscensions(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.max(0, math.floor(value))
end

local function getSafeStars(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.max(0, math.floor(value))
end

function AscensionConfig.getRequiredZone(ascensions)
	return math.floor(AscensionConfig.BaseRequiredZone * (AscensionConfig.RequiredZoneGrowth ^ getSafeAscensions(ascensions)))
end

function AscensionConfig.getStarReward(_ascensions)
	return AscensionConfig.StarsPerAscension
end

function AscensionConfig.getStatBonuses(ascensions)
	local safeAscensions = getSafeAscensions(ascensions)

	return {
		Luck = AscensionConfig.BonusPerAscension.Luck * safeAscensions,
		CrystalEssenceMultiplier = 1 + AscensionConfig.BonusPerAscension.CrystalEssenceMultiplier * safeAscensions,
		RitualPower = AscensionConfig.BonusPerAscension.RitualPower * safeAscensions,
	}
end

function AscensionConfig.getStatBonusSnapshot(ascensions)
	local bonuses = AscensionConfig.getStatBonuses(ascensions)

	return {
		Luck = bonuses.Luck,
		CrystalEssenceMultiplier = bonuses.CrystalEssenceMultiplier,
		RitualPower = bonuses.RitualPower,
	}
end

function AscensionConfig.getStatBonusDelta()
	return {
		Luck = AscensionConfig.BonusPerAscension.Luck,
		CrystalEssenceMultiplier = AscensionConfig.BonusPerAscension.CrystalEssenceMultiplier,
		RitualPower = AscensionConfig.BonusPerAscension.RitualPower,
	}
end

function AscensionConfig.getStatuePosition(zoneId)
	local zone = ZoneConfig.getZone(zoneId)
	local bounds = ZoneConfig.getZoneBounds(zoneId)

	if zone == nil or bounds == nil then
		return nil
	end

	local statueSize = AscensionConfig.Statue.Size
	local y = (zone.Origin or Vector3.new()).Y + statueSize.Y / 2
	local z = bounds.Center.Z - bounds.Size.Z / 2 + 10

	return Vector3.new(bounds.Center.X, y, z)
end

function AscensionConfig.isPositionNearStatue(zoneId, position)
	if typeof(position) ~= "Vector3" then
		return false
	end

	local statuePosition = AscensionConfig.getStatuePosition(zoneId)

	if statuePosition == nil then
		return false
	end

	local promptDistance = AscensionConfig.Statue.PromptDistance

	return (position - statuePosition).Magnitude <= promptDistance
end

function AscensionConfig.getSnapshot(profile)
	local ascensions = getSafeAscensions(if typeof(profile) == "table" then profile.Ascensions else 0)
	local ascensionStars = getSafeStars(if typeof(profile) == "table" then profile.AscensionStars else 0)
	local requiredZone = AscensionConfig.getRequiredZone(ascensions)
	local requiredZoneExists = ZoneConfig.getZone(requiredZone) ~= nil
	local unlockedZones = if typeof(profile) == "table" and typeof(profile.UnlockedZones) == "table"
		then profile.UnlockedZones
		else {}

	return {
		Ascensions = ascensions,
		AscensionStars = ascensionStars,
		RequiredZone = requiredZone,
		RequiredZoneExists = requiredZoneExists,
		CanAscend = requiredZoneExists and unlockedZones[requiredZone] == true,
		StarReward = AscensionConfig.getStarReward(ascensions),
		Bonus = AscensionConfig.getStatBonusSnapshot(ascensions),
		NextBonus = AscensionConfig.getStatBonusSnapshot(ascensions + 1),
		BonusDelta = AscensionConfig.getStatBonusDelta(),
	}
end

return AscensionConfig
