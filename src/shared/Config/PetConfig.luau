local MAXIMUM_PET_DAMAGE = 9_007_199_254_740_991
local ROLL_DISTRIBUTION_CACHE_CAPACITY = 128
local LUCK_QUALITY_MAXIMUM = 0.35
local LUCK_QUALITY_FALLOFF = 18

local PetConfig = {}

local Util = script.Parent.Parent:WaitForChild("Util")
local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))

PetConfig.MAX_EQUIPPED = 3
PetConfig.RollDisplayName = "All Pets"
PetConfig.BaseAttackInterval = 2
PetConfig.MaximumPetDamage = MAXIMUM_PET_DAMAGE
PetConfig.RollDistributionCacheCapacity = ROLL_DISTRIBUTION_CACHE_CAPACITY
PetConfig.LuckQualityMaximum = LUCK_QUALITY_MAXIMUM
PetConfig.LuckQualityFalloff = LUCK_QUALITY_FALLOFF

PetConfig.RarityColors = {
	Common = Color3.fromRGB(120, 120, 130),
	Rare = Color3.fromRGB(70, 170, 255),
	Epic = Color3.fromRGB(160, 112, 255),
	Mythic = Color3.fromRGB(255, 205, 72),
}

PetConfig.BasePets = {
	ember_sprite = {
		DisplayName = "Ember Sprite",
		Rarity = "Common",
		RollChance = 0.22,
		Damage = 3,
		Color = Color3.fromRGB(255, 137, 74),
	},
	sun_sprite = {
		DisplayName = "Sun Sprite",
		Rarity = "Common",
		RollChance = 0.16,
		Damage = 5,
		Color = Color3.fromRGB(255, 225, 92),
	},
	moon_sprite = {
		DisplayName = "Moon Sprite",
		Rarity = "Common",
		RollChance = 0.12,
		Damage = 8,
		Color = Color3.fromRGB(143, 221, 255),
	},
	crystal_sprite = {
		DisplayName = "Crystal Sprite",
		Rarity = "Rare",
		RollChance = 0.055,
		Damage = 14,
		Color = Color3.fromRGB(119, 217, 255),
	},
	crescent_sprite = {
		DisplayName = "Crescent Sprite",
		Rarity = "Rare",
		RollChance = 0.04,
		Damage = 22,
		Color = Color3.fromRGB(101, 153, 255),
	},
	rune_stone = {
		DisplayName = "Rune Stone",
		Rarity = "Rare",
		RollChance = 0.019,
		Damage = 38,
		Color = Color3.fromRGB(116, 169, 210),
	},
	crimson_glyph = {
		DisplayName = "Crimson Glyph",
		Rarity = "Mythic",
		RollChance = 0.0004,
		Damage = 110,
		Color = Color3.fromRGB(255, 83, 160),
	},
}

PetConfig.Pets = PetConfig.BasePets

PetConfig.BaseRollOrder = {
	"ember_sprite",
	"sun_sprite",
	"moon_sprite",
	"crystal_sprite",
	"crescent_sprite",
	"rune_stone",
	"crimson_glyph",
}

PetConfig.AuraRarities = {
	plain = {
		DisplayName = "Plain",
		Prefix = "",
		Chance = 0.45,
		DamageMultiplier = 1,
		Vfx = "None",
		UiColor = Color3.fromRGB(150, 150, 162),
		RevealTier = 1,
	},
	glowing = {
		DisplayName = "Glowing",
		Prefix = "Glowing",
		Chance = 0.25,
		DamageMultiplier = 1.15,
		Vfx = "SoftGlow",
		UiColor = Color3.fromRGB(125, 238, 255),
		RevealTier = 2,
	},
	flaming = {
		DisplayName = "Flaming",
		Prefix = "Flaming",
		Chance = 0.16,
		DamageMultiplier = 1.35,
		Vfx = "FlameAura",
		UiColor = Color3.fromRGB(255, 142, 58),
		RevealTier = 3,
	},
	radiant = {
		DisplayName = "Radiant",
		Prefix = "Radiant",
		Chance = 0.08,
		DamageMultiplier = 1.6,
		Vfx = "RadiantRings",
		UiColor = Color3.fromRGB(205, 142, 255),
		AccentColor = Color3.fromRGB(255, 221, 112),
		RevealTier = 4,
	},
	rainbow = {
		DisplayName = "Rainbow",
		Prefix = "Rainbow",
		Chance = 0.06,
		DamageMultiplier = 1.9,
		Vfx = "RainbowAura",
		UiColor = Color3.fromRGB(255, 116, 212),
		AccentColor = Color3.fromRGB(103, 226, 255),
		RevealTier = 5,
	},
}

PetConfig.AuraRarityOrder = {
	"plain",
	"glowing",
	"flaming",
	"radiant",
	"rainbow",
}

PetConfig.LegacyAuraRarityIds = {
	normal = "plain",
	glowy = "glowing",
	golden = "flaming",
	shadow = "radiant",
}

PetConfig.LegacyAuraRarityOrder = {
	"normal",
	"glowy",
	"golden",
	"shadow",
}

-- Backward-compatible names for older call sites that still refer to pet variants.
PetConfig.Variants = PetConfig.AuraRarities
PetConfig.VariantOrder = PetConfig.AuraRarityOrder

PetConfig.Sizes = {
	normal = {
		DisplayName = "",
		Chance = 0.57,
		ChanceDivisor = 1 / 0.57,
		DamageMultiplier = 1,
		Scale = 1,
	},
	big = {
		DisplayName = "Big",
		Chance = 0.28,
		ChanceDivisor = 1 / 0.28,
		DamageMultiplier = 1.35,
		Scale = 1.35,
		Color = Color3.fromRGB(73, 207, 255),
	},
	huge = {
		DisplayName = "Huge",
		Chance = 0.15,
		ChanceDivisor = 1 / 0.15,
		DamageMultiplier = 1.75,
		Scale = 1.8,
		Color = Color3.fromRGB(255, 92, 194),
	},
}

PetConfig.SizeOrder = {
	"normal",
	"big",
	"huge",
}

local finalPetPartsById = {}
local finalPetCache = {}
local rollDistributionCache = {}
local rollDistributionCacheCount = 0
local totalBaseChance = 0
local totalAuraChance = 0
local totalSizeChance = 0

local function getChance(config)
	return math.max(0, config.Chance or 0)
end

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function getDisplayName(parts)
	return table.concat(parts, " ")
end

local function getResolvedAuraRarityId(auraRarityId)
	if typeof(auraRarityId) ~= "string" or auraRarityId == "" then
		return "plain"
	end

	if PetConfig.AuraRarities[auraRarityId] ~= nil then
		return auraRarityId
	end

	return PetConfig.LegacyAuraRarityIds[auraRarityId] or auraRarityId
end

local function getComposedPetId(basePetId, auraRarityId, sizeId)
	local prefixes = {}
	local resolvedAuraRarityId = auraRarityId or "plain"
	local resolvedSizeId = sizeId or "normal"

	if resolvedSizeId ~= "normal" then
		table.insert(prefixes, resolvedSizeId)
	end

	if resolvedAuraRarityId ~= "plain" then
		table.insert(prefixes, resolvedAuraRarityId)
	end

	if #prefixes == 0 then
		return basePetId
	end

	return table.concat(prefixes, "_") .. "_" .. basePetId
end

local function getLegacyComposedPetId(basePetId, legacyAuraRarityId, sizeId)
	local prefixes = {}
	local resolvedLegacyAuraRarityId = legacyAuraRarityId or "normal"
	local resolvedSizeId = sizeId or "normal"

	if resolvedSizeId ~= "normal" then
		table.insert(prefixes, resolvedSizeId)
	end

	if resolvedLegacyAuraRarityId ~= "normal" then
		table.insert(prefixes, resolvedLegacyAuraRarityId)
	end

	if #prefixes == 0 then
		return basePetId
	end

	return table.concat(prefixes, "_") .. "_" .. basePetId
end

local function getSafeLuck(luck)
	if not isFiniteNumber(luck) then
		return 1
	end

	return math.max(1, luck)
end

local function getLuckBucket(luck)
	local safeLuck = getSafeLuck(luck)
	local scaledLuck = safeLuck * 10

	if not isFiniteNumber(scaledLuck) then
		-- At this magnitude, adjacent finite doubles are already much farther apart than 0.1.
		return safeLuck
	end

	return math.floor(scaledLuck + 0.5) / 10
end

function PetConfig.getFinalPetId(basePetId, auraRarityId, sizeId)
	return getComposedPetId(basePetId, getResolvedAuraRarityId(auraRarityId), sizeId or "normal")
end

function PetConfig.getLuckBucket(luck)
	return getLuckBucket(luck)
end

for _, basePetId in ipairs(PetConfig.BaseRollOrder) do
	local basePet = PetConfig.BasePets[basePetId]

	if basePet ~= nil then
		totalBaseChance += math.max(0, basePet.RollChance or 0)
	end
end

for _, auraRarityId in ipairs(PetConfig.AuraRarityOrder) do
	local auraRarity = PetConfig.AuraRarities[auraRarityId]

	if auraRarity ~= nil then
		totalAuraChance += getChance(auraRarity)
	end
end

for _, sizeId in ipairs(PetConfig.SizeOrder) do
	local size = PetConfig.Sizes[sizeId]

	if size ~= nil then
		totalSizeChance += getChance(size)
	end
end

PetConfig.RollOrder = {}

for _, basePetId in ipairs(PetConfig.BaseRollOrder) do
	for _, auraRarityId in ipairs(PetConfig.AuraRarityOrder) do
		for _, sizeId in ipairs(PetConfig.SizeOrder) do
			local finalPetId = PetConfig.getFinalPetId(basePetId, auraRarityId, sizeId)

			finalPetPartsById[finalPetId] = {
				BasePetId = basePetId,
				AuraRarityId = auraRarityId,
				AuraId = auraRarityId,
				VariantId = auraRarityId,
				SizeId = sizeId,
				CanonicalPetId = finalPetId,
			}
			table.insert(PetConfig.RollOrder, finalPetId)
		end
	end
end

for _, basePetId in ipairs(PetConfig.BaseRollOrder) do
	for _, legacyAuraRarityId in ipairs(PetConfig.LegacyAuraRarityOrder) do
		local auraRarityId = PetConfig.LegacyAuraRarityIds[legacyAuraRarityId]

		for _, sizeId in ipairs(PetConfig.SizeOrder) do
			local legacyPetId = getLegacyComposedPetId(basePetId, legacyAuraRarityId, sizeId)
			local canonicalPetId = PetConfig.getFinalPetId(basePetId, auraRarityId, sizeId)

			if legacyPetId ~= canonicalPetId then
				finalPetPartsById[legacyPetId] = {
					BasePetId = basePetId,
					AuraRarityId = auraRarityId,
					AuraId = auraRarityId,
					VariantId = auraRarityId,
					SizeId = sizeId,
					CanonicalPetId = canonicalPetId,
					LegacyAuraRarityId = legacyAuraRarityId,
				}
			end
		end
	end
end

function PetConfig.getBasePet(basePetId)
	return PetConfig.BasePets[basePetId]
end

function PetConfig.getAuraRarity(auraRarityId)
	return PetConfig.AuraRarities[getResolvedAuraRarityId(auraRarityId)]
end

function PetConfig.getVariant(variantId)
	return PetConfig.getAuraRarity(variantId)
end

function PetConfig.getSize(sizeId)
	return PetConfig.Sizes[sizeId]
end

function PetConfig.getRarityColor(rarity)
	return PetConfig.RarityColors[rarity] or PetConfig.RarityColors.Common
end

function PetConfig.getPetParts(petId)
	return finalPetPartsById[petId]
end

function PetConfig.getCanonicalPetId(petId)
	local parts = PetConfig.getPetParts(petId)

	if parts == nil then
		return nil
	end

	return parts.CanonicalPetId or petId
end

function PetConfig.getPetChance(petId)
	local parts = PetConfig.getPetParts(petId)

	if parts == nil then
		return 0
	end

	local basePet = PetConfig.getBasePet(parts.BasePetId)
	local auraRarity = PetConfig.getAuraRarity(parts.AuraRarityId or parts.VariantId)
	local size = PetConfig.getSize(parts.SizeId)

	if basePet == nil or auraRarity == nil or size == nil or totalBaseChance <= 0 then
		return 0
	end

	local baseChance = math.max(0, basePet.RollChance or 0) / totalBaseChance
	local auraChance = getChance(auraRarity) / math.max(totalAuraChance, 0.000001)
	local sizeChance = getChance(size) / math.max(totalSizeChance, 0.000001)

	return baseChance * auraChance * sizeChance
end

function PetConfig.getPet(petId)
	if finalPetCache[petId] ~= nil then
		return finalPetCache[petId]
	end

	local parts = PetConfig.getPetParts(petId)

	if parts == nil then
		return nil
	end

	local basePet = PetConfig.getBasePet(parts.BasePetId)
	local auraRarity = PetConfig.getAuraRarity(parts.AuraRarityId or parts.VariantId)
	local size = PetConfig.getSize(parts.SizeId)

	if basePet == nil or auraRarity == nil or size == nil then
		return nil
	end

	local nameParts = {}

	if size.DisplayName ~= nil and size.DisplayName ~= "" then
		table.insert(nameParts, size.DisplayName)
	end

	if auraRarity.Prefix ~= nil and auraRarity.Prefix ~= "" then
		table.insert(nameParts, auraRarity.Prefix)
	elseif auraRarity.DisplayName ~= nil and auraRarity.DisplayName ~= "" and auraRarity.DisplayName ~= "Plain" then
		table.insert(nameParts, auraRarity.DisplayName)
	end

	table.insert(nameParts, basePet.DisplayName)

	local damage = math.max(
		1,
		math.floor((basePet.Damage or 0) * (auraRarity.DamageMultiplier or 1) * (size.DamageMultiplier or 1) + 0.5)
	)
	local auraRarityId = parts.AuraRarityId or parts.VariantId
	local finalPet = {
		PetId = petId,
		CanonicalPetId = parts.CanonicalPetId or petId,
		BasePetId = parts.BasePetId,
		AuraRarityId = auraRarityId,
		AuraId = auraRarityId,
		VariantId = auraRarityId,
		SizeId = parts.SizeId,
		DisplayName = getDisplayName(nameParts),
		Rarity = basePet.Rarity,
		AuraRarity = auraRarity.DisplayName,
		AuraDisplayName = auraRarity.DisplayName,
		AuraPrefix = auraRarity.Prefix or auraRarity.DisplayName,
		AuraRevealTier = auraRarity.RevealTier or 1,
		AuraVfx = auraRarity.Vfx or "None",
		RollChance = PetConfig.getPetChance(petId),
		Damage = damage,
		BaseColor = basePet.Color,
		Color = auraRarity.UiColor or basePet.Color,
		AuraColor = auraRarity.UiColor or basePet.Color,
		AuraAccentColor = auraRarity.AccentColor,
		Scale = size.Scale or 1,
		ChanceDivisor = 1 / math.max(getChance(auraRarity) * getChance(size), 0.000001),
	}

	finalPetCache[petId] = finalPet

	return finalPet
end

function PetConfig.getPetPower(petId)
	local pet = PetConfig.getPet(petId)

	if pet == nil then
		return 0
	end

	return pet.Damage or 0
end

function PetConfig.getPetDamage(petId, damageMultiplier)
	local pet = PetConfig.getPet(petId)

	if pet == nil then
		return 0
	end

	local safeMultiplier = 1

	if damageMultiplier ~= nil and isFiniteNumber(damageMultiplier) then
		safeMultiplier = math.max(0, damageMultiplier)
	end

	local baseDamage = if isFiniteNumber(pet.Damage) then math.max(0, pet.Damage) else 0
	local boundedMultiplier = math.min(safeMultiplier, MAXIMUM_PET_DAMAGE / math.max(1, baseDamage))

	return math.min(MAXIMUM_PET_DAMAGE, baseDamage * boundedMultiplier)
end

function PetConfig.getPetRevealDisplayName(petId)
	local pet = PetConfig.getPet(petId)

	if pet == nil then
		return petId
	end

	if pet.AuraRarityId == "rainbow" then
		return string.gsub(pet.DisplayName, "Rainbow", "RAINBOW", 1)
	end

	return pet.DisplayName
end

function PetConfig.getPetAttackInterval()
	return PetConfig.BaseAttackInterval
end

function PetConfig.getRarityScore(petId)
	local chance = PetConfig.getPetChance(petId)

	if chance <= 0 then
		return 0
	end

	return math.floor((1 / chance) + 0.5)
end

function PetConfig.getChanceOddsText(chance)
	if not isFiniteNumber(chance) or chance <= 0 then
		return "0%"
	end

	local denominator = 1 / math.min(1, chance)

	return "1/" .. NumberFormatter.compactLower(denominator)
end

function PetConfig.getRollEntries()
	local entries = {}

	for _, petId in ipairs(PetConfig.RollOrder) do
		local chance = PetConfig.getPetChance(petId)

		if chance > 0 then
			table.insert(entries, {
				PetId = petId,
				Chance = chance,
			})
		end
	end

	return entries
end

local function getQualityPower(luckBucket)
	return LUCK_QUALITY_MAXIMUM * (1 - math.exp(-(math.max(1, luckBucket) - 1) / LUCK_QUALITY_FALLOFF))
end

local function createRollDistribution(luckBucket)
	local qualityPower = getQualityPower(luckBucket)
	local entries = {}
	local totalAdjustedWeight = 0

	for _, petId in ipairs(PetConfig.RollOrder) do
		local baseFinalChance = PetConfig.getPetChance(petId)
		local adjustedWeight = if baseFinalChance > 0 then baseFinalChance ^ (1 - qualityPower) else 0

		totalAdjustedWeight += adjustedWeight
		table.insert(entries, {
			PetId = petId,
			BaseFinalChance = baseFinalChance,
			AdjustedWeight = adjustedWeight,
		})
	end

	if totalAdjustedWeight <= 0 then
		return {
			LuckBucket = luckBucket,
			QualityPower = qualityPower,
			Entries = {},
			ChanceByPetId = {},
		}
	end

	local cumulativeChance = 0
	local chanceByPetId = {}

	for index, entry in ipairs(entries) do
		local chance = entry.AdjustedWeight / totalAdjustedWeight

		if index == #entries then
			chance = math.max(0, 1 - cumulativeChance)
		end

		cumulativeChance += chance
		entry.Chance = chance
		entry.CumulativeChance = if index == #entries then 1 else math.min(1, cumulativeChance)
		chanceByPetId[entry.PetId] = chance
	end

	return {
		LuckBucket = luckBucket,
		QualityPower = qualityPower,
		Entries = entries,
		ChanceByPetId = chanceByPetId,
	}
end

local function getRollDistribution(luck)
	local luckBucket = getLuckBucket(luck)
	local cachedDistribution = rollDistributionCache[luckBucket]

	if cachedDistribution ~= nil then
		return cachedDistribution
	end

	if rollDistributionCacheCount >= ROLL_DISTRIBUTION_CACHE_CAPACITY then
		table.clear(rollDistributionCache)
		rollDistributionCacheCount = 0
	end

	local distribution = createRollDistribution(luckBucket)

	rollDistributionCache[luckBucket] = distribution
	rollDistributionCacheCount += 1

	return distribution
end

function PetConfig.getAdjustedPetChance(petId, luck)
	local canonicalPetId = PetConfig.getCanonicalPetId(petId)

	if canonicalPetId == nil then
		return 0
	end

	return getRollDistribution(luck).ChanceByPetId[canonicalPetId] or 0
end

function PetConfig.getAdjustedRollPreview(luck, damageMultiplier)
	local distribution = getRollDistribution(luck)
	local entries = {}

	for _, distributionEntry in ipairs(distribution.Entries) do
		local pet = PetConfig.getPet(distributionEntry.PetId)
		local parts = PetConfig.getPetParts(distributionEntry.PetId)

		if pet ~= nil and parts ~= nil then
			local basePet = PetConfig.getBasePet(parts.BasePetId)
			local auraRarity = PetConfig.getAuraRarity(parts.AuraRarityId or parts.VariantId)
			local size = PetConfig.getSize(parts.SizeId)
			local power = PetConfig.getPetDamage(distributionEntry.PetId, damageMultiplier)

			if basePet ~= nil and auraRarity ~= nil and size ~= nil then
				table.insert(entries, {
					PetId = distributionEntry.PetId,
					CanonicalPetId = pet.CanonicalPetId,
					DisplayName = pet.DisplayName,
					BasePetId = parts.BasePetId,
					BaseDisplayName = basePet.DisplayName,
					BasePetDisplayName = basePet.DisplayName,
					BasePetDamage = basePet.Damage,
					SizeId = parts.SizeId,
					SizeDisplayName = if size.DisplayName == "" then "Normal" else size.DisplayName,
					AuraRarityId = pet.AuraRarityId,
					AuraId = pet.AuraRarityId,
					AuraDisplayName = auraRarity.DisplayName,
					Rarity = pet.Rarity,
					AuraRarity = pet.AuraRarity,
					AuraRevealTier = pet.AuraRevealTier,
					BaseFinalChance = distributionEntry.BaseFinalChance,
					AdjustedChance = distributionEntry.Chance,
					Chance = distributionEntry.Chance,
					OddsText = PetConfig.getChanceOddsText(distributionEntry.Chance),
					BasePower = PetConfig.getPetPower(distributionEntry.PetId),
					Power = power,
					Damage = power,
					Color = pet.Color,
					AuraColor = pet.AuraColor,
					AuraAccentColor = pet.AuraAccentColor,
					Scale = pet.Scale,
				})
			end
		end
	end

	return {
		DisplayName = PetConfig.RollDisplayName,
		LuckBucket = distribution.LuckBucket,
		QualityPower = distribution.QualityPower,
		OutcomeCount = #entries,
		Entries = entries,
	}
end

function PetConfig.getRollPreview(luck, damageMultiplier)
	local adjustedPreview = PetConfig.getAdjustedRollPreview(luck, damageMultiplier)
	local entries = adjustedPreview.Entries

	-- Preserve the legacy mixed-table metadata for existing local call sites.
	entries.DisplayName = adjustedPreview.DisplayName
	entries.LuckBucket = adjustedPreview.LuckBucket
	entries.QualityPower = adjustedPreview.QualityPower

	return entries
end

function PetConfig.roll(luck, random)
	local distribution = getRollDistribution(luck)

	if #distribution.Entries == 0 then
		return nil
	end

	local rng = random or Random.new()
	local target = rng:NextNumber()

	if not isFiniteNumber(target) then
		target = 0
	else
		target = math.clamp(target, 0, 1)
	end

	for _, entry in ipairs(distribution.Entries) do
		if target <= entry.CumulativeChance then
			return entry.PetId
		end
	end

	return distribution.Entries[#distribution.Entries].PetId
end

return PetConfig
