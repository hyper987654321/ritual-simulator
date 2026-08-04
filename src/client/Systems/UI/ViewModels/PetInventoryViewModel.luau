local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local PetConfig = require(Config:WaitForChild("PetConfig"))

local PetInventoryViewModel = {}

local RARITY_ORDER = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Mythic = 4,
}

local function safeNumber(value, fallback)
	if typeof(value) == "number" and value == value and math.abs(value) ~= math.huge then
		return value
	end

	return fallback or 0
end

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function getPetFact(petId)
	return PetConfig.getPet(petId) or {
		PetId = petId,
		DisplayName = petId,
		Rarity = "Common",
		Damage = 0,
	}
end

local function getEquippedCounts(snapshot)
	local equippedCounts = {}

	for _, petId in ipairs(snapshot.EquippedPetIds or {}) do
		if typeof(petId) == "string" then
			equippedCounts[petId] = (equippedCounts[petId] or 0) + 1
		end
	end

	for _, petInstance in ipairs(snapshot.EquippedPets or {}) do
		local petId = if typeof(petInstance) == "table" then petInstance.PetId else nil

		if typeof(petId) == "string" and equippedCounts[petId] == nil then
			equippedCounts[petId] = (equippedCounts[petId] or 0) + 1
		end
	end

	return equippedCounts
end

local function compareItems(left, right, sortBy, descending)
	local leftValue
	local rightValue

	if sortBy == "Rarity" then
		leftValue = RARITY_ORDER[left.Rarity] or 0
		rightValue = RARITY_ORDER[right.Rarity] or 0
	elseif sortBy == "Name" then
		leftValue = lower(left.DisplayName)
		rightValue = lower(right.DisplayName)
	else
		leftValue = safeNumber(left.Power)
		rightValue = safeNumber(right.Power)
	end

	if leftValue ~= rightValue then
		if descending then
			return leftValue > rightValue
		end

		return leftValue < rightValue
	end

	local leftName = lower(left.DisplayName)
	local rightName = lower(right.DisplayName)

	if leftName ~= rightName then
		return leftName < rightName
	end

	return left.PetId < right.PetId
end

function PetInventoryViewModel.getItems(snapshot)
	local items = {}
	local equippedCounts = getEquippedCounts(snapshot)

	for _, stack in ipairs(snapshot.Pets or {}) do
		if typeof(stack) == "table" and typeof(stack.PetId) == "string" then
			local pet = getPetFact(stack.PetId)
			local count = math.max(0, math.floor(safeNumber(stack.Count, 0)))
			local equippedCount = math.max(
				0,
				math.floor(safeNumber(stack.EquippedCount, equippedCounts[stack.PetId] or 0))
			)

			table.insert(items, {
				PetId = stack.PetId,
				DisplayName = pet.DisplayName or stack.PetId,
				Rarity = pet.Rarity or "Common",
				Power = safeNumber(stack.Power, safeNumber(pet.Damage)),
				Count = count,
				EquippedCount = math.min(equippedCount, count),
				StoredCount = math.max(0, count - math.min(equippedCount, count)),
				IsEquipped = equippedCount > 0,
			})
		end
	end

	return items
end

function PetInventoryViewModel.sortItems(items, sortBy, descending)
	local sorted = {}

	for _, item in ipairs(items or {}) do
		table.insert(sorted, item)
	end

	table.sort(sorted, function(left, right)
		return compareItems(left, right, sortBy or "Power", descending ~= false)
	end)

	return sorted
end

function PetInventoryViewModel.filterItems(items, text)
	local query = lower(text)

	if query == "" then
		return items
	end

	local filtered = {}

	for _, item in ipairs(items or {}) do
		if string.find(lower(item.DisplayName), query, 1, true)
			or string.find(lower(item.PetId), query, 1, true)
			or string.find(lower(item.Rarity), query, 1, true)
		then
			table.insert(filtered, item)
		end
	end

	return filtered
end

function PetInventoryViewModel.getCounts(items)
	local counts = {
		Owned = 0,
		Equipped = 0,
		Stored = 0,
		VisibleStacks = #items,
		VisibleOwned = 0,
	}

	for _, item in ipairs(items or {}) do
		counts.Owned += item.Count
		counts.Equipped += item.EquippedCount
		counts.Stored += item.StoredCount
	end

	return counts
end

function PetInventoryViewModel.getLayoutFacts(options)
	local resolved = options or {}
	local isMobile = resolved.IsMobile == true

	return {
		IsMobile = isMobile,
		Mode = if isMobile then "List" else "Grid",
		UseCompactRows = isMobile,
		Columns = if isMobile then 1 else math.max(1, math.floor(safeNumber(resolved.Columns, 4))),
	}
end

function PetInventoryViewModel.build(snapshot, options)
	local resolved = options or {}
	local allItems = PetInventoryViewModel.getItems(snapshot or {})
	local filteredItems = PetInventoryViewModel.filterItems(allItems, resolved.FilterText)
	local sortedItems = PetInventoryViewModel.sortItems(
		filteredItems,
		resolved.SortBy or "Power",
		resolved.Descending ~= false
	)
	local counts = PetInventoryViewModel.getCounts(allItems)
	counts.VisibleStacks = #sortedItems
	counts.VisibleOwned = 0

	for _, item in ipairs(sortedItems) do
		counts.VisibleOwned += item.Count
	end

	local selectedItem

	if typeof(resolved.SelectedPetId) == "string" then
		for _, item in ipairs(sortedItems) do
			if item.PetId == resolved.SelectedPetId then
				selectedItem = item
				break
			end
		end
	end

	return {
		Items = sortedItems,
		Counts = counts,
		SelectedPetId = resolved.SelectedPetId,
		SelectedItem = selectedItem,
		MaxEquipped = snapshot and snapshot.MaxEquippedPets or PetConfig.MAX_EQUIPPED,
		Layout = PetInventoryViewModel.getLayoutFacts(resolved),
		HasResults = #sortedItems > 0,
	}
end

PetInventoryViewModel.GetItems = PetInventoryViewModel.getItems
PetInventoryViewModel.SortItems = PetInventoryViewModel.sortItems
PetInventoryViewModel.FilterItems = PetInventoryViewModel.filterItems
PetInventoryViewModel.GetCounts = PetInventoryViewModel.getCounts
PetInventoryViewModel.GetLayoutFacts = PetInventoryViewModel.getLayoutFacts
PetInventoryViewModel.Build = PetInventoryViewModel.build

return PetInventoryViewModel
