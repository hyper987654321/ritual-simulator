local BoostConfig = {}

BoostConfig.BoostIds = {
	EssenceMultiplier = "EssenceMultiplier",
	LuckMultiplier = "LuckMultiplier",
}

BoostConfig.DefaultDurationSeconds = 15 * 60

BoostConfig.BoostOrder = {
	BoostConfig.BoostIds.EssenceMultiplier,
	BoostConfig.BoostIds.LuckMultiplier,
}

BoostConfig.Boosts = {
	[BoostConfig.BoostIds.EssenceMultiplier] = {
		BoostId = BoostConfig.BoostIds.EssenceMultiplier,
		DisplayName = "2x Essence",
		ShortDisplayName = "2x Essence",
		Description = "Doubles crystal Essence rewards.",
		IconId = "Essence",
		Multiplier = 2,
		DurationSeconds = BoostConfig.DefaultDurationSeconds,
	},
	[BoostConfig.BoostIds.LuckMultiplier] = {
		BoostId = BoostConfig.BoostIds.LuckMultiplier,
		DisplayName = "Lucky Ritual",
		ShortDisplayName = "Luck",
		Description = "Doubles roll luck.",
		IconId = "RollDice",
		Multiplier = 2,
		DurationSeconds = BoostConfig.DefaultDurationSeconds,
	},
}

local function cloneValue(value)
	if typeof(value) ~= "table" then
		return value
	end

	local clone = {}

	for key, nestedValue in pairs(value) do
		clone[key] = cloneValue(nestedValue)
	end

	return clone
end

local function getCurrentUnixTime(nowUnix)
	if typeof(nowUnix) == "number" then
		return math.max(0, math.floor(nowUnix))
	end

	return DateTime.now().UnixTimestamp
end

local function getPositiveInteger(value)
	if typeof(value) ~= "number" then
		return nil
	end

	local integer = math.floor(value)

	if integer <= 0 or integer ~= value then
		return nil
	end

	return integer
end

local function getPositiveMultiplier(value)
	if typeof(value) ~= "number" or value <= 1 then
		return nil
	end

	return value
end

local function getSafeMultiplier(value, fallback)
	local multiplier = getPositiveMultiplier(value)

	if multiplier ~= nil then
		return multiplier
	end

	return fallback
end

function BoostConfig.getBoost(boostId)
	if typeof(boostId) ~= "string" then
		return nil
	end

	return cloneValue(BoostConfig.Boosts[boostId])
end

function BoostConfig.normalizeBoostGrant(boostGrant)
	if typeof(boostGrant) ~= "table" then
		return nil
	end

	local boostId = boostGrant.BoostId

	if typeof(boostId) ~= "string" then
		return nil
	end

	local boostDefinition = BoostConfig.Boosts[boostId]

	if boostDefinition == nil then
		return nil
	end

	local multiplier = getSafeMultiplier(boostGrant.Multiplier, boostDefinition.Multiplier)
	local durationSeconds = getPositiveInteger(boostGrant.DurationSeconds) or boostDefinition.DurationSeconds

	if multiplier == nil or durationSeconds == nil then
		return nil
	end

	return {
		BoostId = boostId,
		Multiplier = multiplier,
		DurationSeconds = durationSeconds,
	}
end

function BoostConfig.normalizeActiveBoosts(activeBoosts, nowUnix)
	local normalized = {}
	local currentUnixTime = getCurrentUnixTime(nowUnix)

	if typeof(activeBoosts) ~= "table" then
		return normalized
	end

	for _, boostId in ipairs(BoostConfig.BoostOrder) do
		local boostDefinition = BoostConfig.Boosts[boostId]
		local activeBoost = activeBoosts[boostId]

		if boostDefinition ~= nil and typeof(activeBoost) == "table" then
			local endsAtUnix = getPositiveInteger(activeBoost.EndsAtUnix)

			if endsAtUnix ~= nil and endsAtUnix > currentUnixTime then
				local multiplier = getSafeMultiplier(activeBoost.Multiplier, boostDefinition.Multiplier)

				if multiplier ~= nil then
					normalized[boostId] = {
						BoostId = boostId,
						Multiplier = multiplier,
						EndsAtUnix = endsAtUnix,
					}
				end
			end
		end
	end

	return normalized
end

function BoostConfig.applyBoostGrant(activeBoosts, boostGrant, nowUnix)
	local normalizedGrant = BoostConfig.normalizeBoostGrant(boostGrant)

	if normalizedGrant == nil then
		return false, "BoostGrantInvalid", BoostConfig.normalizeActiveBoosts(activeBoosts, nowUnix)
	end

	local currentUnixTime = getCurrentUnixTime(nowUnix)
	local normalizedActiveBoosts = BoostConfig.normalizeActiveBoosts(activeBoosts, currentUnixTime)
	local existingBoost = normalizedActiveBoosts[normalizedGrant.BoostId]
	local startsAtUnix = currentUnixTime

	if typeof(existingBoost) == "table" and typeof(existingBoost.EndsAtUnix) == "number" then
		startsAtUnix = math.max(currentUnixTime, math.floor(existingBoost.EndsAtUnix))
	end

	local activeBoost = {
		BoostId = normalizedGrant.BoostId,
		Multiplier = normalizedGrant.Multiplier,
		EndsAtUnix = startsAtUnix + normalizedGrant.DurationSeconds,
	}

	normalizedActiveBoosts[normalizedGrant.BoostId] = activeBoost

	return true, {
		BoostId = activeBoost.BoostId,
		Multiplier = activeBoost.Multiplier,
		DurationSeconds = normalizedGrant.DurationSeconds,
		EndsAtUnix = activeBoost.EndsAtUnix,
	}, normalizedActiveBoosts
end

function BoostConfig.getActiveBoostMultiplier(activeBoosts, boostId, nowUnix)
	local boostDefinition = BoostConfig.Boosts[boostId]

	if boostDefinition == nil or typeof(activeBoosts) ~= "table" then
		return 1
	end

	local activeBoost = activeBoosts[boostId]

	if typeof(activeBoost) ~= "table" then
		return 1
	end

	local currentUnixTime = getCurrentUnixTime(nowUnix)
	local endsAtUnix = getPositiveInteger(activeBoost.EndsAtUnix)

	if endsAtUnix == nil or endsAtUnix <= currentUnixTime then
		return 1
	end

	return getSafeMultiplier(activeBoost.Multiplier, boostDefinition.Multiplier) or 1
end

function BoostConfig.getDurationLabel(durationSeconds)
	local safeDurationSeconds = getPositiveInteger(durationSeconds) or 0
	local hours = math.floor(safeDurationSeconds / 3600)
	local minutes = math.floor((safeDurationSeconds % 3600) / 60)

	if hours > 0 and minutes > 0 then
		return string.format("%dh %dm", hours, minutes)
	end

	if hours > 0 then
		return string.format("%dh", hours)
	end

	if minutes > 0 then
		return string.format("%dm", minutes)
	end

	return string.format("%ds", safeDurationSeconds)
end

function BoostConfig.getBoostGrantDisplayText(boostGrant, compactLabel)
	local normalizedGrant = BoostConfig.normalizeBoostGrant(boostGrant)

	if normalizedGrant == nil then
		return nil
	end

	local boostDefinition = BoostConfig.Boosts[normalizedGrant.BoostId]
	local displayName = if compactLabel == true
		then boostDefinition.ShortDisplayName or boostDefinition.DisplayName
		else boostDefinition.DisplayName

	return string.format("%s %s", displayName, BoostConfig.getDurationLabel(normalizedGrant.DurationSeconds))
end

function BoostConfig.getActiveBoostSnapshots(activeBoosts, nowUnix)
	local currentUnixTime = getCurrentUnixTime(nowUnix)
	local normalizedActiveBoosts = BoostConfig.normalizeActiveBoosts(activeBoosts, currentUnixTime)
	local snapshots = {}

	for _, boostId in ipairs(BoostConfig.BoostOrder) do
		local activeBoost = normalizedActiveBoosts[boostId]
		local boostDefinition = BoostConfig.Boosts[boostId]

		if activeBoost ~= nil and boostDefinition ~= nil then
			table.insert(snapshots, {
				BoostId = boostId,
				DisplayName = boostDefinition.DisplayName,
				ShortDisplayName = boostDefinition.ShortDisplayName,
				Description = boostDefinition.Description,
				IconId = boostDefinition.IconId,
				Multiplier = activeBoost.Multiplier,
				EndsAtUnix = activeBoost.EndsAtUnix,
				RemainingSeconds = math.max(0, activeBoost.EndsAtUnix - currentUnixTime),
			})
		end
	end

	return snapshots
end

return BoostConfig
