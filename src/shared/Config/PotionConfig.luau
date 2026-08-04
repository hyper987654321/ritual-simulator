local BoostConfig = require(script.Parent:WaitForChild("BoostConfig"))

local PotionConfig = {}

PotionConfig.MaxStoredCount = 9999

PotionConfig.PotionIds = {
	Essence2x15m = "essence_potion_2x_15m",
	RollFlow1_5x15m = "roll_flow_potion_1_5x_15m",
	PetPower1_5x15m = "pet_power_potion_1_5x_15m",
	RuneFlow1_5x15m = "rune_flow_potion_1_5x_15m",
	Luck2x15m = "luck_potion_2x_15m",
}

PotionConfig.PotionOrder = {
	PotionConfig.PotionIds.Essence2x15m,
	PotionConfig.PotionIds.RollFlow1_5x15m,
	PotionConfig.PotionIds.PetPower1_5x15m,
	PotionConfig.PotionIds.RuneFlow1_5x15m,
	PotionConfig.PotionIds.Luck2x15m,
}

PotionConfig.ShopOrder = {
	PotionConfig.PotionIds.Essence2x15m,
	PotionConfig.PotionIds.RollFlow1_5x15m,
	PotionConfig.PotionIds.PetPower1_5x15m,
	PotionConfig.PotionIds.RuneFlow1_5x15m,
}

PotionConfig.Potions = {
	[PotionConfig.PotionIds.Essence2x15m] = {
		PotionId = PotionConfig.PotionIds.Essence2x15m,
		DisplayName = "2x Essence Potion",
		ShortDisplayName = "2x Essence",
		Description = "Use to double crystal Essence rewards for 15 minutes.",
		IconId = "Essence",
		GemCost = 35,
		IsShopEnabled = true,
		BoostGrant = {
			BoostId = BoostConfig.BoostIds.EssenceMultiplier,
			Multiplier = 2,
			DurationSeconds = BoostConfig.DefaultDurationSeconds,
		},
	},
	[PotionConfig.PotionIds.RollFlow1_5x15m] = {
		PotionId = PotionConfig.PotionIds.RollFlow1_5x15m,
		DisplayName = "Roll Flow Potion",
		ShortDisplayName = "Roll Flow",
		Description = "Use to speed up ritual openings by 50% for 15 minutes.",
		IconId = "AutoRoll",
		GemCost = 30,
		IsShopEnabled = true,
		BoostGrant = {
			BoostId = BoostConfig.BoostIds.RollSpeedMultiplier,
			Multiplier = 1.5,
			DurationSeconds = BoostConfig.DefaultDurationSeconds,
		},
	},
	[PotionConfig.PotionIds.PetPower1_5x15m] = {
		PotionId = PotionConfig.PotionIds.PetPower1_5x15m,
		DisplayName = "Pet Power Potion",
		ShortDisplayName = "Pet Power",
		Description = "Use to increase pet crystal damage by 50% for 15 minutes.",
		IconId = "PetInventory",
		GemCost = 40,
		IsShopEnabled = true,
		BoostGrant = {
			BoostId = BoostConfig.BoostIds.PetPowerMultiplier,
			Multiplier = 1.5,
			DurationSeconds = BoostConfig.DefaultDurationSeconds,
		},
	},
	[PotionConfig.PotionIds.RuneFlow1_5x15m] = {
		PotionId = PotionConfig.PotionIds.RuneFlow1_5x15m,
		DisplayName = "Rune Flow Potion",
		ShortDisplayName = "Rune Flow",
		Description = "Use to increase Rune Focus charge by 50% for 15 minutes.",
		IconId = "RitualCore",
		GemCost = 40,
		IsShopEnabled = true,
		BoostGrant = {
			BoostId = BoostConfig.BoostIds.RuneChargeMultiplier,
			Multiplier = 1.5,
			DurationSeconds = BoostConfig.DefaultDurationSeconds,
		},
	},
	[PotionConfig.PotionIds.Luck2x15m] = {
		PotionId = PotionConfig.PotionIds.Luck2x15m,
		DisplayName = "Lucky Ritual Potion",
		ShortDisplayName = "Lucky Ritual",
		Description = "Use to double roll luck for 15 minutes.",
		IconId = "RollDice",
		GemCost = 45,
		IsShopEnabled = false,
		BoostGrant = {
			BoostId = BoostConfig.BoostIds.LuckMultiplier,
			Multiplier = 2,
			DurationSeconds = BoostConfig.DefaultDurationSeconds,
		},
	},
}

local function cloneValue(value)
	if typeof(value) ~= "table" then
		return value
	end

	local clone = {}

	for key, childValue in pairs(value) do
		clone[key] = cloneValue(childValue)
	end

	return clone
end

local function getSafeCount(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(math.floor(value), 0, PotionConfig.MaxStoredCount)
end

local function getPositiveInteger(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return nil
	end

	local integer = math.floor(value)

	if integer <= 0 or integer ~= value then
		return nil
	end

	return integer
end

function PotionConfig.getPotion(potionId)
	if typeof(potionId) ~= "string" then
		return nil
	end

	return cloneValue(PotionConfig.Potions[potionId])
end

function PotionConfig.normalizeInventory(potions)
	local normalized = {}

	if typeof(potions) ~= "table" then
		return normalized
	end

	for _, potionId in ipairs(PotionConfig.PotionOrder) do
		local count = getSafeCount(potions[potionId])

		if count > 0 then
			normalized[potionId] = count
		end
	end

	return normalized
end

function PotionConfig.normalizePotionGrant(potionGrant)
	if typeof(potionGrant) ~= "table" then
		return nil
	end

	local potionId = potionGrant.PotionId

	if typeof(potionId) ~= "string" or PotionConfig.Potions[potionId] == nil then
		return nil
	end

	local count = 1

	if potionGrant.Count ~= nil then
		count = getPositiveInteger(potionGrant.Count)

		if count == nil then
			return nil
		end
	end

	return {
		PotionId = potionId,
		Count = math.min(count, PotionConfig.MaxStoredCount),
	}
end

function PotionConfig.addPotionGrant(potions, potionGrant)
	local normalizedGrant = PotionConfig.normalizePotionGrant(potionGrant)
	local normalizedPotions = PotionConfig.normalizeInventory(potions)

	if normalizedGrant == nil then
		return false, "PotionGrantInvalid", normalizedPotions
	end

	local currentCount = normalizedPotions[normalizedGrant.PotionId] or 0

	if currentCount >= PotionConfig.MaxStoredCount then
		return false, "PotionStorageFull", normalizedPotions
	end

	local nextCount = math.min(PotionConfig.MaxStoredCount, currentCount + normalizedGrant.Count)
	local appliedCount = nextCount - currentCount

	normalizedPotions[normalizedGrant.PotionId] = nextCount

	return true, {
		PotionId = normalizedGrant.PotionId,
		Count = appliedCount,
		StoredCount = nextCount,
	}, normalizedPotions
end

function PotionConfig.consumePotion(potions, potionId)
	local potion = PotionConfig.getPotion(potionId)
	local normalizedPotions = PotionConfig.normalizeInventory(potions)

	if potion == nil then
		return false, "PotionNotConfigured", normalizedPotions
	end

	local currentCount = normalizedPotions[potion.PotionId] or 0

	if currentCount <= 0 then
		return false, "PotionNotOwned", normalizedPotions
	end

	if currentCount == 1 then
		normalizedPotions[potion.PotionId] = nil
	else
		normalizedPotions[potion.PotionId] = currentCount - 1
	end

	return true, potion, normalizedPotions
end

function PotionConfig.getPotionBoostGrant(potionId)
	local potion = PotionConfig.getPotion(potionId)

	if potion == nil or typeof(potion.BoostGrant) ~= "table" then
		return nil
	end

	return BoostConfig.normalizeBoostGrant(potion.BoostGrant)
end

function PotionConfig.getShopPotionIds()
	local potionIds = {}

	for _, potionId in ipairs(PotionConfig.ShopOrder) do
		local potion = PotionConfig.Potions[potionId]

		if potion ~= nil and potion.IsShopEnabled == true then
			table.insert(potionIds, potionId)
		end
	end

	return potionIds
end

function PotionConfig.getPotionGrantDisplayText(potionGrant, compactLabel)
	local normalizedGrant = PotionConfig.normalizePotionGrant(potionGrant)

	if normalizedGrant == nil then
		return nil
	end

	local potion = PotionConfig.Potions[normalizedGrant.PotionId]
	local displayName = if compactLabel == true
		then potion.ShortDisplayName or potion.DisplayName
		else potion.DisplayName

	if normalizedGrant.Count > 1 then
		return string.format("%s x%d", displayName, normalizedGrant.Count)
	end

	return displayName
end

function PotionConfig.getPotionSnapshots(potions)
	local normalizedPotions = PotionConfig.normalizeInventory(potions)
	local snapshots = {}

	for _, potionId in ipairs(PotionConfig.PotionOrder) do
		local potion = PotionConfig.Potions[potionId]

		if potion ~= nil then
			local boostGrant = BoostConfig.normalizeBoostGrant(potion.BoostGrant)

			table.insert(snapshots, {
				PotionId = potionId,
				DisplayName = potion.DisplayName,
				ShortDisplayName = potion.ShortDisplayName,
				Description = potion.Description,
				IconId = potion.IconId,
				Count = normalizedPotions[potionId] or 0,
				GemCost = potion.GemCost,
				IsShopEnabled = potion.IsShopEnabled == true,
				BoostGrant = boostGrant,
			})
		end
	end

	return snapshots
end

return PotionConfig
