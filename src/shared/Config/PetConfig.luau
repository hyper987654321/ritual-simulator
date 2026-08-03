local PetConfig = {}

local Util = script.Parent.Parent:WaitForChild("Util")
local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))

PetConfig.MAX_EQUIPPED = 3
PetConfig.RollDisplayName = "All Pets"
PetConfig.BaseAttackInterval = 2

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
		Damage = 2,
		Color = Color3.fromRGB(255, 137, 74),
	},
	sun_sprite = {
		DisplayName = "Sun Sprite",
		Rarity = "Common",
		RollChance = 0.16,
		Damage = 4,
		Color = Color3.fromRGB(255, 225, 92),
	},
	moon_sprite = {
		DisplayName = "Moon Sprite",
		Rarity = "Common",
		RollChance = 0.12,
		Damage = 6,
		Color = Color3.fromRGB(143, 221, 255),
	},
	crystal_sprite = {
		DisplayName = "Crystal Sprite",
		Rarity = "Rare",
		RollChance = 0.055,
		Damage = 15,
		Color = Color3.fromRGB(119, 217, 255),
	},
	crescent_sprite = {
		DisplayName = "Crescent Sprite",
		Rarity = "Rare",
		RollChance = 0.04,
		Damage = 20,
		Color = Color3.fromRGB(101, 153, 255),
	},
	rune_stone = {
		DisplayName = "Rune Stone",
		Rarity = "Rare",
		RollChance = 0.019,
		Damage = 44,
		Color = Color3.fromRGB(116, 169, 210),
	},
	crimson_glyph = {
		DisplayName = "Crimson Glyph",
		Rarity = "Mythic",
		RollChance = 0.0004,
		Damage = 560,
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
		ChanceDivisor = 1,
		DamageMultiplier = 1,
		Scale = 1,
	},
	big = {
		DisplayName = "Big",
		ChanceDivisor = 1.5,
		DamageMultiplier = 1.5,
		Scale = 1.35,
		Color = Color3.fromRGB(73, 207, 255),
	},
	huge = {
		DisplayName = "Huge",
		ChanceDivisor = 2,
		DamageMultiplier = 2,
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
local totalBaseChance = 0
local totalAuraChance = 0
local totalSizeWeight = 0

local function getWeight(config)
	return 1 / math.max(0.000001, config.ChanceDivisor or 1)
end

local function getChance(config)
	return math.max(0, config.Chance or 0)
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
	if typeof(luck) ~= "number" or luck ~= luck then
		return 1
	end

	return math.max(1, luck)
end

function PetConfig.getFinalPetId(basePetId, auraRarityId, sizeId)
	return getComposedPetId(basePetId, getResolvedAuraRarityId(auraRarityId), sizeId or "normal")
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
		totalSizeWeight += getWeight(size)
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
	local sizeChance = getWeight(size) / math.max(totalSizeWeight, 0.000001)

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

	local damage = math.max(1, math.floor((basePet.Damage or 0) * (auraRarity.DamageMultiplier or 1) * (size.DamageMultiplier or 1) + 0.5))
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
		ChanceDivisor = (1 / math.max(getChance(auraRarity), 0.000001)) * (size.ChanceDivisor or 1),
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

	return pet.Damage * (damageMultiplier or 1)
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
	if typeof(chance) ~= "number" or chance <= 0 then
		return "0%"
	end

	local denominator = 1 / chance

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

function PetConfig.getRollPreview()
	local entries = PetConfig.getRollEntries()
	local preview = {
		DisplayName = PetConfig.RollDisplayName,
	}

	for _, entry in ipairs(entries) do
		local pet = PetConfig.getPet(entry.PetId)

		if pet ~= nil then
			table.insert(preview, {
				PetId = entry.PetId,
				DisplayName = pet.DisplayName,
				Rarity = pet.Rarity,
				AuraRarity = pet.AuraRarity,
				AuraRarityId = pet.AuraRarityId,
				AuraRevealTier = pet.AuraRevealTier,
				Chance = entry.Chance or 0,
				OddsText = PetConfig.getChanceOddsText(entry.Chance or 0),
				Power = PetConfig.getPetPower(entry.PetId),
				Color = pet.Color,
				AuraColor = pet.AuraColor,
				AuraAccentColor = pet.AuraAccentColor,
			})
		end
	end

	return preview
end

local function rollSingleEntry(entries, random)
	local totalChance = 0

	for _, entry in ipairs(entries) do
		totalChance += entry.Chance or 0
	end

	if totalChance <= 0 then
		return nil
	end

	local target = random:NextNumber(0, totalChance)
	local runningChance = 0

	for _, entry in ipairs(entries) do
		runningChance += entry.Chance or 0

		if target <= runningChance then
			return entry
		end
	end

	return entries[#entries]
end

local function getRollAttemptCount(luck, random)
	local safeLuck = getSafeLuck(luck)
	local attempts = math.max(1, math.floor(safeLuck))
	local fractionalAttemptChance = safeLuck - attempts

	if fractionalAttemptChance > 0 and random:NextNumber() < fractionalAttemptChance then
		attempts += 1
	end

	return attempts
end

function PetConfig.roll(luck, random)
	local entries = PetConfig.getRollEntries()

	if #entries == 0 then
		return nil
	end

	local rng = random or Random.new()
	local attempts = getRollAttemptCount(luck, rng)
	local bestEntry = nil
	local bestScore = -math.huge

	for _ = 1, attempts do
		local entry = rollSingleEntry(entries, rng)

		if entry ~= nil then
			local score = PetConfig.getRarityScore(entry.PetId)

			if score > bestScore then
				bestEntry = entry
				bestScore = score
			end
		end
	end

	return if bestEntry ~= nil then bestEntry.PetId else nil
end

return PetConfig
