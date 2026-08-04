local ProfileContract = require(script.Parent:WaitForChild("ProfileContract"))
local ZoneConfig = require(script.Parent:WaitForChild("ZoneConfig"))

local AscensionConfig = {}

AscensionConfig.Milestones = {
	{
		RequiredZone = 5,
		RequiredRebirths = 3,
		StarReward = 1,
	},
	{
		RequiredZone = 10,
		RequiredRebirths = 7,
		StarReward = 2,
	},
	{
		RequiredZone = 15,
		RequiredRebirths = 13,
		StarReward = 3,
	},
}

AscensionConfig.AutomaticBonusPerAscension = {
	EssenceMultiplier = 0.22,
	PetPowerMultiplier = 0.18,
	Luck = 0.35,
	StartingCapacity = 500,
	RuneChargeMultiplier = 0.15,
	OfflineCapMinutes = 120,
}

-- Compatibility name used by older presentation code.
AscensionConfig.BonusPerAscension = {
	Luck = AscensionConfig.AutomaticBonusPerAscension.Luck,
	CrystalEssenceMultiplier = AscensionConfig.AutomaticBonusPerAscension.EssenceMultiplier,
	RitualPower = 4_000,
}

AscensionConfig.UpgradeOrder = table.clone(ProfileContract.AscensionUpgradeOrder)
AscensionConfig.Upgrades = {
	essence_mastery = {
		DisplayName = "Essence Mastery",
		Description = "Increase every persistent Essence multiplier.",
		MaxLevel = 10,
		Costs = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5 },
		EffectPerLevel = 0.06,
		EffectKind = "EssenceMultiplier",
		EffectText = "+6% Essence per level",
	},
	starting_capacity = {
		DisplayName = "Starting Capacity",
		Description = "Start every run with a larger Essence vessel.",
		MaxLevel = 8,
		Costs = { 1, 1, 2, 2, 3, 3, 4, 4 },
		EffectPerLevel = 125,
		EffectKind = "StartingCapacity",
		EffectText = "+125 Capacity per level",
	},
	pet_power = {
		DisplayName = "Pet Power",
		Description = "Increase all equipped pet damage.",
		MaxLevel = 10,
		Costs = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5 },
		EffectPerLevel = 0.05,
		EffectKind = "PetPowerMultiplier",
		EffectText = "+5% pet power per level",
	},
	ritual_luck = {
		DisplayName = "Ritual Luck",
		Description = "Add permanent Luck to ritual rolls.",
		MaxLevel = 8,
		Costs = { 1, 1, 2, 2, 3, 3, 4, 4 },
		EffectPerLevel = 0.12,
		EffectKind = "Luck",
		EffectText = "+0.12 Luck per level",
	},
	roll_flow = {
		DisplayName = "Roll Flow",
		Description = "Open ritual rolls faster.",
		MaxLevel = 8,
		Costs = { 1, 1, 2, 2, 3, 3, 4, 4 },
		EffectPerLevel = 4,
		EffectKind = "RollSpeedPercent",
		EffectText = "+4% roll speed per level",
	},
	rune_flow = {
		DisplayName = "Rune Flow",
		Description = "Charge the active Rune Focus faster.",
		MaxLevel = 8,
		Costs = { 1, 1, 2, 2, 3, 3, 4, 4 },
		EffectPerLevel = 0.05,
		EffectKind = "RuneChargeMultiplier",
		EffectText = "+5% Rune charge per level",
	},
	away_ritual = {
		DisplayName = "Away Ritual",
		Description = "Extend the maximum eligible away interval.",
		MaxLevel = 6,
		Costs = { 1, 2, 2, 3, 3, 4 },
		EffectPerLevel = 30,
		EffectKind = "OfflineCapMinutes",
		EffectText = "+30 away minutes per level",
	},
	rush_focus = {
		DisplayName = "Rush Focus",
		Description = "Increase Ritual Rush points before source caps.",
		MaxLevel = 5,
		Costs = { 1, 2, 3, 4, 5 },
		EffectPerLevel = 0.02,
		EffectKind = "RushPointsMultiplier",
		EffectText = "+2% Rush points per level",
	},
}

AscensionConfig.Statue = {
	PromptDistance = 16,
	Size = Vector3.new(5, 7, 5),
	Color = Color3.fromRGB(255, 218, 92),
	AccentColor = Color3.fromRGB(255, 74, 214),
}

local function getSafeInteger(value, maximum)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(math.floor(value), 0, maximum)
end

local function getUpgradeLevel(upgrades, upgradeId)
	local definition = AscensionConfig.Upgrades[upgradeId]

	if definition == nil then
		return 0
	end

	local source = if typeof(upgrades) == "table" then upgrades else {}

	return getSafeInteger(source[upgradeId], definition.MaxLevel)
end

function AscensionConfig.getUpgradeLevels(upgrades)
	local levels = {}

	for _, upgradeId in ipairs(AscensionConfig.UpgradeOrder) do
		levels[upgradeId] = getUpgradeLevel(upgrades, upgradeId)
	end

	return levels
end

local function getAscensionInputs(profileOrAscensions)
	if typeof(profileOrAscensions) == "table" then
		return getSafeInteger(profileOrAscensions.Ascensions, #AscensionConfig.Milestones),
			profileOrAscensions.AscensionUpgrades
	end

	return getSafeInteger(profileOrAscensions, #AscensionConfig.Milestones), nil
end

function AscensionConfig.getMilestone(ascensions)
	local safeAscensions = getSafeInteger(ascensions, #AscensionConfig.Milestones)

	return AscensionConfig.Milestones[safeAscensions + 1]
end

function AscensionConfig.getRequiredZone(ascensions)
	local milestone = AscensionConfig.getMilestone(ascensions)

	return if milestone ~= nil then milestone.RequiredZone else nil
end

function AscensionConfig.getRequiredRebirths(ascensions)
	local milestone = AscensionConfig.getMilestone(ascensions)

	return if milestone ~= nil then milestone.RequiredRebirths else nil
end

function AscensionConfig.getStarReward(ascensions)
	local milestone = AscensionConfig.getMilestone(ascensions)

	return if milestone ~= nil then milestone.StarReward else 0
end

function AscensionConfig.getUpgrade(upgradeId)
	if typeof(upgradeId) ~= "string" then
		return nil
	end

	return AscensionConfig.Upgrades[upgradeId]
end

function AscensionConfig.getUpgradeCost(upgradeId, currentLevel)
	local definition = AscensionConfig.getUpgrade(upgradeId)

	if definition == nil then
		return nil
	end

	local level = getSafeInteger(currentLevel, definition.MaxLevel)

	return definition.Costs[level + 1]
end

function AscensionConfig.getStatBonuses(profileOrAscensions)
	local ascensions, upgrades = getAscensionInputs(profileOrAscensions)
	local automatic = AscensionConfig.AutomaticBonusPerAscension
	local essenceLevel = getUpgradeLevel(upgrades, "essence_mastery")
	local startingCapacityLevel = getUpgradeLevel(upgrades, "starting_capacity")
	local petPowerLevel = getUpgradeLevel(upgrades, "pet_power")
	local luckLevel = getUpgradeLevel(upgrades, "ritual_luck")
	local rollFlowLevel = getUpgradeLevel(upgrades, "roll_flow")
	local runeFlowLevel = getUpgradeLevel(upgrades, "rune_flow")
	local awayRitualLevel = getUpgradeLevel(upgrades, "away_ritual")
	local rushFocusLevel = getUpgradeLevel(upgrades, "rush_focus")

	return {
		Ascensions = ascensions,
		Luck = automatic.Luck * ascensions + AscensionConfig.Upgrades.ritual_luck.EffectPerLevel * luckLevel,
		CrystalEssenceMultiplier = (1 + automatic.EssenceMultiplier * ascensions)
			* (1 + AscensionConfig.Upgrades.essence_mastery.EffectPerLevel * essenceLevel),
		PetPowerMultiplier = (1 + automatic.PetPowerMultiplier * ascensions)
			* (1 + AscensionConfig.Upgrades.pet_power.EffectPerLevel * petPowerLevel),
		StartingCapacityBonus = automatic.StartingCapacity * ascensions
			+ AscensionConfig.Upgrades.starting_capacity.EffectPerLevel * startingCapacityLevel,
		RollSpeedPercent = AscensionConfig.Upgrades.roll_flow.EffectPerLevel * rollFlowLevel,
		RuneChargeMultiplier = (1 + automatic.RuneChargeMultiplier * ascensions)
			* (1 + AscensionConfig.Upgrades.rune_flow.EffectPerLevel * runeFlowLevel),
		OfflineCapBonusMinutes = automatic.OfflineCapMinutes * ascensions
			+ AscensionConfig.Upgrades.away_ritual.EffectPerLevel * awayRitualLevel,
		RushPointsMultiplier = 1 + AscensionConfig.Upgrades.rush_focus.EffectPerLevel * rushFocusLevel,
		RitualPower = 0,
	}
end

function AscensionConfig.getStatBonusSnapshot(profileOrAscensions)
	return AscensionConfig.getStatBonuses(profileOrAscensions)
end

function AscensionConfig.getStatBonusDelta()
	return {
		Luck = AscensionConfig.AutomaticBonusPerAscension.Luck,
		CrystalEssenceMultiplier = AscensionConfig.AutomaticBonusPerAscension.EssenceMultiplier,
		PetPowerMultiplier = AscensionConfig.AutomaticBonusPerAscension.PetPowerMultiplier,
		StartingCapacityBonus = AscensionConfig.AutomaticBonusPerAscension.StartingCapacity,
		RuneChargeMultiplier = AscensionConfig.AutomaticBonusPerAscension.RuneChargeMultiplier,
		OfflineCapBonusMinutes = AscensionConfig.AutomaticBonusPerAscension.OfflineCapMinutes,
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

	return (position - statuePosition).Magnitude <= AscensionConfig.Statue.PromptDistance
end

local function getUpgradeSnapshots(upgrades)
	local snapshots = {}

	for _, upgradeId in ipairs(AscensionConfig.UpgradeOrder) do
		local definition = AscensionConfig.Upgrades[upgradeId]
		local level = getUpgradeLevel(upgrades, upgradeId)

		table.insert(snapshots, {
			UpgradeId = upgradeId,
			DisplayName = definition.DisplayName,
			Description = definition.Description,
			Level = level,
			MaxLevel = definition.MaxLevel,
			Cost = AscensionConfig.getUpgradeCost(upgradeId, level),
			IsMaxed = level >= definition.MaxLevel,
			EffectKind = definition.EffectKind,
			EffectText = definition.EffectText,
			CurrentEffect = definition.EffectPerLevel * level,
			NextEffect = definition.EffectPerLevel * math.min(definition.MaxLevel, level + 1),
		})
	end

	return snapshots
end

function AscensionConfig.getSnapshot(profile)
	local source = if typeof(profile) == "table" then profile else {}
	local ascensions = getSafeInteger(source.Ascensions, #AscensionConfig.Milestones)
	local rebirths = getSafeInteger(source.Rebirths, ProfileContract.MaximumExactInteger)
	local ascensionStars = getSafeInteger(source.AscensionStars, ProfileContract.MaximumExactInteger)
	local upgrades = AscensionConfig.getUpgradeLevels(source.AscensionUpgrades)
	local unlockedZones = if typeof(source.UnlockedZones) == "table" then source.UnlockedZones else {}
	local milestone = AscensionConfig.getMilestone(ascensions)
	local requiredZone = if milestone ~= nil then milestone.RequiredZone else nil
	local requiredRebirths = if milestone ~= nil then milestone.RequiredRebirths else nil
	local requiredZoneExists = requiredZone ~= nil and ZoneConfig.getZone(requiredZone) ~= nil
	local zoneRequirementMet = requiredZone ~= nil and unlockedZones[requiredZone] == true
	local rebirthRequirementMet = requiredRebirths ~= nil and rebirths >= requiredRebirths
	local currentBonus = AscensionConfig.getStatBonusSnapshot(source)
	local nextBonus = currentBonus

	if milestone ~= nil then
		nextBonus = AscensionConfig.getStatBonusSnapshot({
			Ascensions = ascensions + 1,
			AscensionUpgrades = upgrades,
		})
	end

	return {
		Ascensions = ascensions,
		Count = ascensions,
		AscensionStars = ascensionStars,
		UnspentStars = ascensionStars,
		AscensionUpgrades = upgrades,
		HasNextMilestone = milestone ~= nil,
		IsV1Complete = milestone == nil,
		RequiredZone = requiredZone,
		RequiredRebirths = requiredRebirths,
		RequiredZoneExists = requiredZoneExists,
		IsZoneRequirementMet = zoneRequirementMet,
		IsRebirthRequirementMet = rebirthRequirementMet,
		CanAscend = milestone ~= nil and requiredZoneExists and zoneRequirementMet and rebirthRequirementMet,
		StarReward = if milestone ~= nil then milestone.StarReward else 0,
		Bonus = currentBonus,
		NextBonus = nextBonus,
		BonusDelta = AscensionConfig.getStatBonusDelta(),
		UpgradeOptions = getUpgradeSnapshots(upgrades),
	}
end

return AscensionConfig
