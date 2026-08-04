local ProfileContract = require(script.Parent:WaitForChild("ProfileContract"))

local RitualStoneConfig = {}

RitualStoneConfig.BaseStats = {
	Capacity = 120,
	Luck = 1,
	RollSpeedPercent = 100,
}

RitualStoneConfig.MinimumRollSpeedPercent = 100
RitualStoneConfig.MaximumRollSpeedPercent = 400

RitualStoneConfig.AutoCapacity = {
	RequiredRebirths = 1,
	MaxPurchasesPerInvocation = 8,
}

RitualStoneConfig.RollOpening = {
	FlashSteps = 16,
	BaseStepDelay = 0.045,
	StepDelayGrowth = 0.009,
	MinDurationScale = 0.25,
	MaxDurationScale = 1.75,
	PetRevealSeconds = 1,
}

RitualStoneConfig.Rebirth = {
	BaseEssenceRequirement = 1_700,
	EssenceGrowth = 1.72,
	MultiplierPerRebirth = 0.25,
	LuckPerRebirth = 0.05,
	PetPowerMultiplierPerRebirth = 0.03,
	RuneChargeMultiplierPerRebirth = 0.025,
	MaximumRuneChargeMultiplierBonus = 0.40,
}

RitualStoneConfig.Upgrades = {
	Capacity = {
		DisplayName = "Capacity",
		Description = "Store more Ritual Essence.",
		BaseCost = 12,
		CostGrowth = 1.18,
		MaxLevel = 100,
	},
	Luck = {
		DisplayName = "Luck",
		Description = "Improve rare pet roll weights.",
		BaseCost = 25,
		CostGrowth = 1.35,
		MaxLevel = 60,
	},
	RollSpeed = {
		DisplayName = "Roll Speed",
		Description = "Speed up pet roll openings.",
		BaseCost = 20,
		CostGrowth = 1.32,
		MaxLevel = 43,
	},
}

RitualStoneConfig.UpgradeOrder = table.clone(ProfileContract.StoneUpgradeOrder)

local function getFiniteNumber(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end

	return value
end

local function getSafeInteger(value, maximum)
	local finiteValue = getFiniteNumber(value, 0)

	return math.clamp(math.floor(finiteValue), 0, maximum)
end

local function getFiniteNonNegativeNumber(value, fallback)
	return math.clamp(getFiniteNumber(value, fallback), 0, ProfileContract.MaximumExactInteger)
end

local function boundedAdd(...)
	local total = 0

	for index = 1, select("#", ...) do
		total = math.min(
			ProfileContract.MaximumExactInteger,
			total + getFiniteNonNegativeNumber(select(index, ...), 0)
		)
	end

	return total
end

local function boundedMultiply(left, right)
	local safeLeft = getFiniteNonNegativeNumber(left, 0)
	local safeRight = getFiniteNonNegativeNumber(right, 0)

	if safeLeft == 0 or safeRight == 0 then
		return 0
	end

	if safeLeft >= ProfileContract.MaximumExactInteger / safeRight then
		return ProfileContract.MaximumExactInteger
	end

	return math.min(ProfileContract.MaximumExactInteger, safeLeft * safeRight)
end

local function boundedExponential(base, growth, exponent)
	if base <= 0 or growth <= 0 then
		return 0
	end

	local maximumExponent = math.log(ProfileContract.MaximumExactInteger / base) / math.log(growth)

	if exponent >= maximumExponent then
		return ProfileContract.MaximumExactInteger
	end

	return math.min(ProfileContract.MaximumExactInteger, base * (growth ^ exponent))
end

local function nice(value)
	local safeValue = math.clamp(math.floor(getFiniteNumber(value, 1)), 1, ProfileContract.MaximumExactInteger)
	local digitCount = math.floor(math.log(safeValue) / math.log(10)) + 1
	local roundingUnit = 10 ^ math.max(0, digitCount - 2)

	return math.min(
		ProfileContract.MaximumExactInteger,
		math.max(1, math.floor(safeValue / roundingUnit + 0.5) * roundingUnit)
	)
end

function RitualStoneConfig.getUpgradeCost(upgradeId, currentLevel)
	local upgrade = RitualStoneConfig.Upgrades[upgradeId]

	if upgrade == nil then
		return nil
	end

	local level = getSafeInteger(currentLevel, upgrade.MaxLevel)

	if level >= upgrade.MaxLevel then
		return nil
	end

	return math.floor(boundedExponential(upgrade.BaseCost, upgrade.CostGrowth, level))
end

function RitualStoneConfig.getStats(levels, rebirths, runeBonuses, ascensionBonuses)
	local safeLevels = if typeof(levels) == "table" then levels else {}
	local safeRuneBonuses = if typeof(runeBonuses) == "table" then runeBonuses else {}
	local safeAscensionBonuses = if typeof(ascensionBonuses) == "table" then ascensionBonuses else {}
	local capacityLevel = getSafeInteger(safeLevels.Capacity, RitualStoneConfig.Upgrades.Capacity.MaxLevel)
	local luckLevel = getSafeInteger(safeLevels.Luck, RitualStoneConfig.Upgrades.Luck.MaxLevel)
	local rollSpeedLevel = getSafeInteger(safeLevels.RollSpeed, RitualStoneConfig.Upgrades.RollSpeed.MaxLevel)
	local safeRebirths = getSafeInteger(rebirths, ProfileContract.MaximumExactInteger)
	local rebirthMultiplier = boundedAdd(
		1,
		boundedMultiply(safeRebirths, RitualStoneConfig.Rebirth.MultiplierPerRebirth)
	)
	local ascensionEssenceMultiplier = getFiniteNonNegativeNumber(
		safeAscensionBonuses.CrystalEssenceMultiplier,
		1
	)
	local capacity = math.floor(boundedAdd(
		boundedExponential(RitualStoneConfig.BaseStats.Capacity, 1.16, capacityLevel),
		boundedMultiply(220, capacityLevel),
		getFiniteNonNegativeNumber(safeRuneBonuses.Capacity, 0),
		getFiniteNonNegativeNumber(safeAscensionBonuses.StartingCapacityBonus, 0)
	))
	local rebirthPetPowerMultiplier = boundedAdd(
		1,
		boundedMultiply(safeRebirths, RitualStoneConfig.Rebirth.PetPowerMultiplierPerRebirth)
	)
	local rebirthRuneChargeMultiplier = boundedAdd(
		1,
		math.min(
			RitualStoneConfig.Rebirth.MaximumRuneChargeMultiplierBonus,
			boundedMultiply(safeRebirths, RitualStoneConfig.Rebirth.RuneChargeMultiplierPerRebirth)
		)
	)
	local ascensionPetPowerMultiplier = getFiniteNonNegativeNumber(
		safeAscensionBonuses.PetPowerMultiplier,
		1
	)
	local ascensionRuneChargeMultiplier = getFiniteNonNegativeNumber(
		safeAscensionBonuses.RuneChargeMultiplier,
		1
	)

	local stats = {
		Capacity = math.clamp(capacity, 1, ProfileContract.MaximumExactInteger),
		Luck = boundedAdd(
			RitualStoneConfig.BaseStats.Luck,
			boundedMultiply(0.12, luckLevel),
			boundedMultiply(safeRebirths, RitualStoneConfig.Rebirth.LuckPerRebirth),
			getFiniteNonNegativeNumber(safeRuneBonuses.Luck, 0),
			getFiniteNonNegativeNumber(safeAscensionBonuses.Luck, 0)
		),
		RollSpeedPercent = boundedAdd(
			RitualStoneConfig.BaseStats.RollSpeedPercent,
			boundedMultiply(7, rollSpeedLevel),
			getFiniteNonNegativeNumber(safeRuneBonuses.RollSpeedPercent, 0),
			getFiniteNonNegativeNumber(safeAscensionBonuses.RollSpeedPercent, 0)
		),
		RebirthMultiplier = rebirthMultiplier,
		RebirthPetPowerMultiplier = rebirthPetPowerMultiplier,
		RebirthRuneChargeMultiplier = rebirthRuneChargeMultiplier,
		AscensionEssenceMultiplier = ascensionEssenceMultiplier,
		AscensionPetPowerMultiplier = ascensionPetPowerMultiplier,
		AscensionRuneChargeMultiplier = ascensionRuneChargeMultiplier,
		EssenceMultiplier = boundedMultiply(rebirthMultiplier, ascensionEssenceMultiplier),
		RitualPowerBonus = getFiniteNonNegativeNumber(safeAscensionBonuses.RitualPower, 0),
	}

	stats.RollSpeedPercent = math.clamp(
		stats.RollSpeedPercent,
		RitualStoneConfig.MinimumRollSpeedPercent,
		RitualStoneConfig.MaximumRollSpeedPercent
	)

	return stats
end

function RitualStoneConfig.getRollOpeningDurationScale(rollSpeedPercent)
	local speedPercent = getFiniteNumber(rollSpeedPercent, RitualStoneConfig.BaseStats.RollSpeedPercent)

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
	local source = if typeof(levels) == "table" then levels else {}
	local total = 0

	for _, upgradeId in ipairs(RitualStoneConfig.UpgradeOrder) do
		local upgrade = RitualStoneConfig.Upgrades[upgradeId]
		total += getSafeInteger(source[upgradeId], upgrade.MaxLevel)
	end

	return total
end

function RitualStoneConfig.getRebirthRequirement(rebirths)
	local safeRebirths = getSafeInteger(rebirths, ProfileContract.MaximumExactInteger)

	return {
		RequiredEssence = nice(boundedExponential(
			RitualStoneConfig.Rebirth.BaseEssenceRequirement,
			RitualStoneConfig.Rebirth.EssenceGrowth,
			safeRebirths
		)),
		RequiredZone = math.min(5, 3 + math.floor(safeRebirths / 2)),
	}
end

return RitualStoneConfig
