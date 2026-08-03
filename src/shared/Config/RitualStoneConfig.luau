local RitualStoneConfig = {}

RitualStoneConfig.BaseStats = {
	Capacity = 100,
	Luck = 1,
	RollSpeedPercent = 100,
}

RitualStoneConfig.MinimumRollSpeedPercent = 25
RitualStoneConfig.MaximumRollSpeedPercent = 400

RitualStoneConfig.RollOpening = {
	FlashSteps = 16,
	BaseStepDelay = 0.045,
	StepDelayGrowth = 0.009,
	MinDurationScale = 0.25,
	MaxDurationScale = 1.75,
	PetRevealSeconds = 1,
}

RitualStoneConfig.Rebirth = {
	BaseEssenceRequirement = 180,
	EssenceGrowth = 1.65,
	MultiplierPerRebirth = 0.25,
	LuckPerRebirth = 0.05,
}

RitualStoneConfig.Upgrades = {
	Capacity = {
		DisplayName = "Capacity",
		Description = "Store more Ritual Essence.",
		BaseCost = 12,
		CostGrowth = 1.35,
		Amount = 75,
	},
	Luck = {
		DisplayName = "Luck",
		Description = "Improve rare pet roll weights.",
		BaseCost = 18,
		CostGrowth = 1.42,
		Amount = 0.1,
	},
	RollSpeed = {
		DisplayName = "Roll Speed",
		Description = "Speed up pet roll openings.",
		BaseCost = 22,
		CostGrowth = 1.45,
		Amount = 5,
	},
}

RitualStoneConfig.UpgradeOrder = {
	"Capacity",
	"Luck",
	"RollSpeed",
}

function RitualStoneConfig.getUpgradeCost(upgradeId, currentLevel)
	local upgrade = RitualStoneConfig.Upgrades[upgradeId]

	if upgrade == nil then
		return nil
	end

	local level = math.max(0, currentLevel or 0)

	return math.floor(upgrade.BaseCost * (upgrade.CostGrowth ^ level))
end

function RitualStoneConfig.getStats(levels, rebirths, runeBonuses, ascensionBonuses)
	local safeLevels = levels or {}
	local safeRebirths = rebirths or 0
	local safeRuneBonuses = runeBonuses or {}
	local safeAscensionBonuses = ascensionBonuses or {}
	local capacityLevel = safeLevels.Capacity or 0
	local luckLevel = safeLevels.Luck or 0
	local rollSpeedLevel = safeLevels.RollSpeed or 0
	local rebirthMultiplier = 1 + safeRebirths * RitualStoneConfig.Rebirth.MultiplierPerRebirth
	local ascensionEssenceMultiplier = safeAscensionBonuses.CrystalEssenceMultiplier or 1

	local stats = {
		Capacity = RitualStoneConfig.BaseStats.Capacity
			+ capacityLevel * RitualStoneConfig.Upgrades.Capacity.Amount
			+ (safeRuneBonuses.Capacity or 0),
		Luck = RitualStoneConfig.BaseStats.Luck
			+ luckLevel * RitualStoneConfig.Upgrades.Luck.Amount
			+ safeRebirths * RitualStoneConfig.Rebirth.LuckPerRebirth
			+ (safeRuneBonuses.Luck or 0),
		RollSpeedPercent = RitualStoneConfig.BaseStats.RollSpeedPercent
			+ rollSpeedLevel * RitualStoneConfig.Upgrades.RollSpeed.Amount
			+ (safeRuneBonuses.RollSpeedPercent or 0),
		RebirthMultiplier = rebirthMultiplier,
		AscensionEssenceMultiplier = ascensionEssenceMultiplier,
		EssenceMultiplier = rebirthMultiplier * ascensionEssenceMultiplier,
		RitualPowerBonus = safeAscensionBonuses.RitualPower or 0,
	}

	stats.Luck += safeAscensionBonuses.Luck or 0

	stats.RollSpeedPercent = math.clamp(
		stats.RollSpeedPercent,
		RitualStoneConfig.MinimumRollSpeedPercent,
		RitualStoneConfig.MaximumRollSpeedPercent
	)

	return stats
end

function RitualStoneConfig.getRollOpeningDurationScale(rollSpeedPercent)
	local speedPercent = rollSpeedPercent or RitualStoneConfig.BaseStats.RollSpeedPercent

	if speedPercent <= 0 then
		return 1
	end

	return math.clamp(
		RitualStoneConfig.BaseStats.RollSpeedPercent / speedPercent,
		RitualStoneConfig.RollOpening.MinDurationScale,
		RitualStoneConfig.RollOpening.MaxDurationScale
	)
end

function RitualStoneConfig.getRollOpeningDuration(rollSpeedPercent)
	local durationScale = RitualStoneConfig.getRollOpeningDurationScale(rollSpeedPercent)
	local duration = 0

	for step = 1, RitualStoneConfig.RollOpening.FlashSteps do
		duration += (
			RitualStoneConfig.RollOpening.BaseStepDelay
			+ step * RitualStoneConfig.RollOpening.StepDelayGrowth
		) * durationScale
	end

	return duration
end

function RitualStoneConfig.getRollOpeningCadence(rollSpeedPercent)
	return RitualStoneConfig.getRollOpeningDuration(rollSpeedPercent) + RitualStoneConfig.RollOpening.PetRevealSeconds
end

function RitualStoneConfig.getRollOpeningSpeedPercent(rollSpeedPercent)
	local durationScale = RitualStoneConfig.getRollOpeningDurationScale(rollSpeedPercent)

	return math.floor((1 / math.max(durationScale, 0.01)) * 100 + 0.5)
end

function RitualStoneConfig.getTotalUpgradeLevels(levels)
	local total = 0

	for _, upgradeId in ipairs(RitualStoneConfig.UpgradeOrder) do
		total += (levels and levels[upgradeId]) or 0
	end

	return total
end

function RitualStoneConfig.getRebirthRequirement(rebirths)
	local safeRebirths = rebirths or 0

	return {
		RequiredEssence = math.floor(RitualStoneConfig.Rebirth.BaseEssenceRequirement
			* (RitualStoneConfig.Rebirth.EssenceGrowth ^ safeRebirths)),
	}
end

return RitualStoneConfig
