local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local PetConfig = require(Config:WaitForChild("PetConfig"))

local PetInventoryProgress = {}

local function isInteger(value)
	return typeof(value) == "number"
		and value == value
		and math.abs(value) ~= math.huge
		and value % 1 == 0
end

local function cloneArray(values)
	local copy = {}

	for index, value in ipairs(values or {}) do
		copy[index] = value
	end

	return copy
end

local function getCanonicalPetId(petId)
	if typeof(petId) ~= "string" or petId == "" then
		return nil, "invalid_pet_id"
	end

	local canonicalPetId = PetConfig.getCanonicalPetId(petId)

	if canonicalPetId == nil or canonicalPetId ~= petId or PetConfig.getPet(canonicalPetId) == nil then
		return nil, "pet_id_not_canonical"
	end

	return canonicalPetId
end

local function getMaximumEquipped(profile)
	local maximum = if typeof(profile) == "table" and isInteger(profile.MaxEquippedPets)
		then profile.MaxEquippedPets
		else PetConfig.MAX_EQUIPPED

	return math.max(0, math.min(PetConfig.MAX_EQUIPPED, maximum))
end

local function getOwnedCount(profile, petId)
	local pets = if typeof(profile.Pets) == "table" then profile.Pets else {}
	local count = pets[petId]

	if not isInteger(count) or count < 0 then
		return 0
	end

	return count
end

local function getEquippedCount(equippedPetIds, petId)
	local count = 0

	for _, equippedPetId in ipairs(equippedPetIds or {}) do
		if equippedPetId == petId then
			count += 1
		end
	end

	return count
end

local function getChangedSlotIndexes(previous, next)
	local changed = {}
	local maximum = math.max(#previous, #next)

	for slotIndex = 1, maximum do
		if previous[slotIndex] ~= next[slotIndex] then
			table.insert(changed, slotIndex)
		end
	end

	return changed
end

local function result(success, reason, petId, equippedCount, changedSlotIndexes)
	return {
		Success = success,
		Reason = reason,
		PetId = petId,
		EquippedCount = equippedCount,
		ChangedSlotIndexes = changedSlotIndexes or {},
	}
end

local function replaceEquippedPetIds(profile, nextEquippedPetIds, petId)
	local previous = cloneArray(profile.EquippedPetIds)
	profile.EquippedPetIds = nextEquippedPetIds

	return result(
		true,
		nil,
		petId,
		getEquippedCount(nextEquippedPetIds, petId),
		getChangedSlotIndexes(previous, nextEquippedPetIds)
	)
end

function PetInventoryProgress.setEquippedCount(profile, petId, equippedCount)
	if typeof(profile) ~= "table" then
		return result(false, "invalid_profile")
	end

	local canonicalPetId, idReason = getCanonicalPetId(petId)

	if canonicalPetId == nil then
		return result(false, idReason, petId)
	end

	if not isInteger(equippedCount) or equippedCount < 0 then
		return result(false, "invalid_equipped_count", canonicalPetId)
	end

	local pets = if typeof(profile.Pets) == "table" then profile.Pets else {}
	local equippedPetIds = if typeof(profile.EquippedPetIds) == "table" then profile.EquippedPetIds else {}
	profile.Pets = pets
	profile.EquippedPetIds = equippedPetIds
	local ownedCount = getOwnedCount(profile, canonicalPetId)
	local maximumEquipped = getMaximumEquipped(profile)
	local otherEquippedCount = #equippedPetIds - getEquippedCount(equippedPetIds, canonicalPetId)

	if equippedCount > ownedCount then
		return result(false, "equipped_count_exceeds_owned", canonicalPetId)
	end

	if otherEquippedCount + equippedCount > maximumEquipped then
		return result(false, "maximum_equipped_exceeded", canonicalPetId)
	end

	local nextEquippedPetIds = {}
	local remaining = equippedCount

	for _, equippedPetId in ipairs(equippedPetIds) do
		if equippedPetId ~= canonicalPetId then
			table.insert(nextEquippedPetIds, equippedPetId)
		elseif remaining > 0 then
			table.insert(nextEquippedPetIds, canonicalPetId)
			remaining -= 1
		end
	end

	while remaining > 0 do
		table.insert(nextEquippedPetIds, canonicalPetId)
		remaining -= 1
	end

	return replaceEquippedPetIds(profile, nextEquippedPetIds, canonicalPetId)
end

function PetInventoryProgress.unequip(profile, petId)
	return PetInventoryProgress.setEquippedCount(profile, petId, 0)
end

local function sortPetIds(left, right)
	local leftPower = PetConfig.getPetPower(left)
	local rightPower = PetConfig.getPetPower(right)

	if leftPower ~= rightPower then
		return leftPower > rightPower
	end

	local leftRarity = PetConfig.getRarityScore(left)
	local rightRarity = PetConfig.getRarityScore(right)

	if leftRarity ~= rightRarity then
		return leftRarity > rightRarity
	end

	return left < right
end

function PetInventoryProgress.equipBest(profile)
	if typeof(profile) ~= "table" or typeof(profile.Pets) ~= "table" then
		return result(false, "invalid_profile")
	end

	local maximumEquipped = getMaximumEquipped(profile)
	local petIds = {}

	for petId, count in pairs(profile.Pets) do
		local canonicalPetId = if typeof(petId) == "string" then PetConfig.getCanonicalPetId(petId) else nil

		if canonicalPetId == petId and PetConfig.getPet(petId) ~= nil and isInteger(count) and count > 0 then
			table.insert(petIds, petId)
		end
	end

	table.sort(petIds, sortPetIds)

	local desiredCounts = {}
	local desiredTotal = 0

	for _, petId in ipairs(petIds) do
		local amount = math.min(getOwnedCount(profile, petId), maximumEquipped - desiredTotal)

		if amount > 0 then
			desiredCounts[petId] = amount
			desiredTotal += amount
		end

		if desiredTotal >= maximumEquipped then
			break
		end
	end

	local previousEquippedPetIds = if typeof(profile.EquippedPetIds) == "table" then profile.EquippedPetIds else {}
	local nextSlots = {}
	local remainingCounts = {}

	for petId, count in pairs(desiredCounts) do
		remainingCounts[petId] = count
	end

	for slotIndex, petId in ipairs(previousEquippedPetIds) do
		local remaining = remainingCounts[petId] or 0

		if slotIndex <= maximumEquipped and remaining > 0 then
			nextSlots[slotIndex] = petId
			remainingCounts[petId] = remaining - 1
		end
	end

	for _, petId in ipairs(petIds) do
		local remaining = remainingCounts[petId] or 0

		while remaining > 0 do
			local openSlot

			for slotIndex = 1, maximumEquipped do
				if nextSlots[slotIndex] == nil then
					openSlot = slotIndex
					break
				end
			end

			if openSlot == nil then
				break
			end

			nextSlots[openSlot] = petId
			remaining -= 1
		end
	end

	local nextEquippedPetIds = {}

	for slotIndex = 1, maximumEquipped do
		if nextSlots[slotIndex] ~= nil then
			table.insert(nextEquippedPetIds, nextSlots[slotIndex])
		end
	end

	return replaceEquippedPetIds(profile, nextEquippedPetIds)
end

PetInventoryProgress.SetEquippedCount = PetInventoryProgress.setEquippedCount
PetInventoryProgress.Unequip = PetInventoryProgress.unequip
PetInventoryProgress.EquipBest = PetInventoryProgress.equipBest

return PetInventoryProgress
