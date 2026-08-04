local ProfileContract = require(script.Parent:WaitForChild("ProfileContract"))

local RuneFocusConfig = {}

RuneFocusConfig.Unlock = {
	RequiredZone = 3,
	RequiredRebirths = 1,
}

RuneFocusConfig.SelectionCooldownSeconds = 30
RuneFocusConfig.FocusOrder = table.clone(ProfileContract.RuneFocusOrder)
RuneFocusConfig.OnlineCharge = {
	BaseAmount = 4,
	ZoneAmount = 2.5,
	BaseRewardSquareRootAmount = 0.75,
	FullCapacityMultiplier = 0.55,
}

RuneFocusConfig.Focuses = {
	capacity = {
		FocusId = "capacity",
		DisplayName = "Vessel Focus",
		Description = "Build a larger Essence vessel for longer farming runs.",
		BaseCharge = 120,
		ChargeGrowth = 1.55,
		MaxLevel = 15,
		BonusPerLevel = 90,
		BonusKind = "Capacity",
		BonusText = "+90 Capacity per level",
	},
	pet_power = {
		FocusId = "pet_power",
		DisplayName = "Power Focus",
		Description = "Strengthen every equipped pet against crystals.",
		BaseCharge = 140,
		ChargeGrowth = 1.60,
		MaxLevel = 20,
		BonusPerLevel = 0.045,
		BonusKind = "PetPowerMultiplier",
		BonusText = "+4.5% pet power per level",
	},
	ritual_speed = {
		FocusId = "ritual_speed",
		DisplayName = "Flow Focus",
		Description = "Open ritual rolls faster without changing their rewards.",
		BaseCharge = 160,
		ChargeGrowth = 1.60,
		MaxLevel = 15,
		BonusPerLevel = 2,
		BonusKind = "RollSpeedPercent",
		BonusText = "+2% roll speed per level",
	},
	luck = {
		FocusId = "luck",
		DisplayName = "Fortune Focus",
		Description = "Improve the quality of future ritual rolls.",
		BaseCharge = 190,
		ChargeGrowth = 1.65,
		MaxLevel = 15,
		BonusPerLevel = 0.07,
		BonusKind = "Luck",
		BonusText = "+0.07 Luck per level",
	},
}

local function getSafeInteger(value, minimum, maximum)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return minimum
	end

	return math.clamp(math.floor(value), minimum, maximum)
end

local function getFiniteNonNegativeNumber(value, defaultValue)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return defaultValue
	end

	return math.max(0, value)
end

function RuneFocusConfig.getFocus(focusId)
	if typeof(focusId) ~= "string" then
		return nil
	end

	return RuneFocusConfig.Focuses[focusId]
end

function RuneFocusConfig.getRequiredCharge(focusId, currentLevel)
	local focus = RuneFocusConfig.getFocus(focusId)

	if focus == nil then
		return nil
	end

	local level = getSafeInteger(currentLevel, 0, focus.MaxLevel)

	if level >= focus.MaxLevel then
		return 0
	end

	return math.min(
		ProfileContract.MaximumExactInteger,
		math.floor(focus.BaseCharge * (focus.ChargeGrowth ^ level))
	)
end

function RuneFocusConfig.getBaseChargePerBreak(zoneId, baseCrystalReward)
	local safeZoneId = getSafeInteger(zoneId, 1, ProfileContract.MaximumExactInteger)
	local safeBaseReward = getFiniteNonNegativeNumber(baseCrystalReward, 0)
	local tuning = RuneFocusConfig.OnlineCharge

	return math.max(
		1,
		math.floor(
			tuning.BaseAmount
				+ tuning.ZoneAmount * safeZoneId
				+ tuning.BaseRewardSquareRootAmount * math.sqrt(safeBaseReward)
		)
	)
end

function RuneFocusConfig.getCapacityStateMultiplier(essenceAwarded, actualCrystalReward)
	local safeAwarded = getFiniteNonNegativeNumber(essenceAwarded, 0)
	local safeReward = math.max(1, getFiniteNonNegativeNumber(actualCrystalReward, 0))
	local storedFraction = math.clamp(safeAwarded / safeReward, 0, 1)
	local fullMultiplier = RuneFocusConfig.OnlineCharge.FullCapacityMultiplier

	return fullMultiplier + (1 - fullMultiplier) * storedFraction
end

function RuneFocusConfig.calculateOnlineBreakCharge(context)
	local source = if typeof(context) == "table" then context else {}
	local baseCharge = RuneFocusConfig.getBaseChargePerBreak(source.ZoneId, source.BaseCrystalReward)
	local capacityMultiplier = RuneFocusConfig.getCapacityStateMultiplier(
		source.EssenceAwarded,
		source.ActualCrystalReward
	)
	local rebirthMultiplier = getFiniteNonNegativeNumber(source.RebirthChargeMultiplier, 1)
	local ascensionMultiplier = getFiniteNonNegativeNumber(source.AscensionChargeMultiplier, 1)
	local potionMultiplier = getFiniteNonNegativeNumber(source.ActiveRunePotionMultiplier, 1)
	local rawCharge = baseCharge
		* rebirthMultiplier
		* ascensionMultiplier
		* potionMultiplier
		* capacityMultiplier

	if rawCharge ~= rawCharge or math.abs(rawCharge) == math.huge then
		return ProfileContract.MaximumExactInteger
	end

	return math.max(1, math.floor(math.min(ProfileContract.MaximumExactInteger, rawCharge)))
end

function RuneFocusConfig.getHighestUnlockedZone(unlockedZones)
	local highestZone = 0

	if typeof(unlockedZones) ~= "table" then
		return highestZone
	end

	for zoneId, isUnlocked in pairs(unlockedZones) do
		if
			isUnlocked == true
			and typeof(zoneId) == "number"
			and zoneId == math.floor(zoneId)
			and zoneId > highestZone
		then
			highestZone = zoneId
		end
	end

	return highestZone
end

function RuneFocusConfig.canUseFocus(unlockedZones, rebirths)
	local safeRebirths = getSafeInteger(rebirths, 0, ProfileContract.MaximumExactInteger)

	return safeRebirths >= RuneFocusConfig.Unlock.RequiredRebirths
		and RuneFocusConfig.getHighestUnlockedZone(unlockedZones) >= RuneFocusConfig.Unlock.RequiredZone
end

function RuneFocusConfig.getBonuses(levels)
	local source = if typeof(levels) == "table" then levels else {}
	local bonuses = {
		Capacity = 0,
		Luck = 0,
		RollSpeedPercent = 0,
		PetPowerMultiplier = 1,
		TotalLevels = 0,
	}

	for _, focusId in ipairs(RuneFocusConfig.FocusOrder) do
		local focus = RuneFocusConfig.Focuses[focusId]
		local level = getSafeInteger(source[focusId], 0, focus.MaxLevel)
		local amount = focus.BonusPerLevel * level

		bonuses.TotalLevels += level

		if focus.BonusKind == "Capacity" then
			bonuses.Capacity += amount
		elseif focus.BonusKind == "Luck" then
			bonuses.Luck += amount
		elseif focus.BonusKind == "RollSpeedPercent" then
			bonuses.RollSpeedPercent += amount
		elseif focus.BonusKind == "PetPowerMultiplier" then
			bonuses.PetPowerMultiplier += amount
		end
	end

	return bonuses
end

return RuneFocusConfig
