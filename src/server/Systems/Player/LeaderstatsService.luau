local LeaderstatsService = {}

local function getOrCreateIntValue(parent, name)
	local value = parent:FindFirstChild(name)

	if value == nil then
		value = Instance.new("IntValue")
		value.Name = name
		value.Parent = parent
	end

	return value
end

local function removeValue(parent, name)
	local value = parent:FindFirstChild(name)

	if value ~= nil then
		value:Destroy()
	end
end

function LeaderstatsService.ensure(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats == nil then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	getOrCreateIntValue(leaderstats, "Power")
	getOrCreateIntValue(leaderstats, "Rebirths")
	getOrCreateIntValue(leaderstats, "Rolls")
	removeValue(leaderstats, "Essence")

	return leaderstats
end

function LeaderstatsService.update(player, snapshot)
	if snapshot == nil then
		return false
	end

	local leaderstats = LeaderstatsService.ensure(player)

	leaderstats.Power.Value = snapshot.RitualPower
	leaderstats.Rebirths.Value = snapshot.Rebirths
	leaderstats.Rolls.Value = snapshot.Rolls

	return true
end

return LeaderstatsService
