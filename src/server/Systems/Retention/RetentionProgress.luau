local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local PotionConfig = require(Config:WaitForChild("PotionConfig"))
local RetentionConfig = require(Config:WaitForChild("RetentionConfig"))

local RetentionProgress = {}
RetentionProgress.SecondsPerDay = RetentionConfig.SecondsPerDay
RetentionProgress.ActiveTickSeconds = RetentionConfig.ActiveTickSeconds
RetentionProgress.MaximumExactInteger = RetentionConfig.MaximumExactInteger

local function safeInteger(value, minimum, maximum, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge or value % 1 ~= 0 then
		return fallback
	end
	return math.clamp(value, minimum, maximum)
end

local function nowUnix(value)
	if typeof(value) == "number" and value == value and math.abs(value) ~= math.huge then
		return math.max(0, math.floor(value))
	end
	return DateTime.now().UnixTimestamp
end

local function dayIndex(value)
	return math.floor(nowUnix(value) / RetentionConfig.SecondsPerDay)
end

local function boundedAdd(left, right)
	local current = safeInteger(left, 0, RetentionConfig.MaximumExactInteger, 0)
	local amount = safeInteger(right, 0, RetentionConfig.MaximumExactInteger, 0)
	return math.min(RetentionConfig.MaximumExactInteger, current + amount)
end

local function getState(profile, currentDay)
	local state = if typeof(profile.Retention) == "table" then profile.Retention else {}
	profile.Retention = state
	state.Version = 1
	state.DayIndex = safeInteger(state.DayIndex, 0, RetentionConfig.MaximumExactInteger, currentDay)
	state.DailyProgress = if typeof(state.DailyProgress) == "table" then state.DailyProgress else {}
	state.DailyClaimed = if typeof(state.DailyClaimed) == "table" then state.DailyClaimed else {}
	state.ActiveSecondsToday = safeInteger(state.ActiveSecondsToday, 0, RetentionConfig.MaximumExactInteger, 0)
	state.PlaytimeClaimed = if typeof(state.PlaytimeClaimed) == "table" then state.PlaytimeClaimed else {}
	state.AchievementClaimed = if typeof(state.AchievementClaimed) == "table" then state.AchievementClaimed else {}

	if state.DayIndex ~= currentDay then
		state.DayIndex = currentDay
		state.DailyProgress = {}
		state.DailyClaimed = {}
		state.ActiveSecondsToday = 0
		state.PlaytimeClaimed = {}
	end
	return state
end

local function copyReward(reward)
	return if typeof(reward) == "table" then table.clone(reward) else {}
end

local function applyReward(profile, reward)
	if typeof(reward) ~= "table" then
		return false
	end
	if reward.RitualGems ~= nil then
		profile.RitualGems = boundedAdd(profile.RitualGems, reward.RitualGems)
		return safeInteger(reward.RitualGems, 0, RetentionConfig.MaximumExactInteger, 0) > 0
	end
	if reward.PotionId ~= nil then
		local ok, _, normalized = PotionConfig.addPotionGrant(profile.Potions, reward)
		if ok then
			profile.Potions = normalized
		end
		return ok
	end
	return false
end

function RetentionProgress.getDayWindow(serverNowUnix)
	local currentDay = dayIndex(serverNowUnix)
	local startsAt = currentDay * RetentionConfig.SecondsPerDay
	return { DayIndex = currentDay, StartsAtUnix = startsAt, EndsAtUnix = startsAt + RetentionConfig.SecondsPerDay }
end

function RetentionProgress.recordEvent(profile, eventId, amount, serverNowUnix)
	local state = getState(profile, dayIndex(serverNowUnix))
	local safeAmount = safeInteger(amount, 1, RetentionConfig.MaximumExactInteger, 0)
	if typeof(eventId) ~= "string" or safeAmount <= 0 then
		return { Ok = false, Changed = false, Code = "invalid_event" }
	end

	local changed = false
	for _, deedId in ipairs(RetentionConfig.DeedOrder) do
		local deed = RetentionConfig.Deeds[deedId]
		if deed.EventId == eventId then
			local current = safeInteger(state.DailyProgress[deedId], 0, deed.Requirement, 0)
			local nextValue = math.min(deed.Requirement, current + safeAmount)
			changed = nextValue ~= current or changed
			state.DailyProgress[deedId] = nextValue
		end
	end
	return { Ok = true, Changed = changed, Snapshot = RetentionProgress.buildSnapshot(profile, serverNowUnix) }
end

function RetentionProgress.advanceActiveTime(profile, elapsedSeconds, serverNowUnix)
	local state = getState(profile, dayIndex(serverNowUnix))
	local step = safeInteger(elapsedSeconds, 0, RetentionConfig.ActiveTickSeconds, 0)
	if step <= 0 then
		return { Ok = false, Changed = false, Code = "invalid_active_step" }
	end
	state.ActiveSecondsToday = boundedAdd(state.ActiveSecondsToday, step)
	return { Ok = true, Changed = true, ActiveSecondsToday = state.ActiveSecondsToday }
end

local function achievementProgress(profile, definition)
	if definition.SourceField == "UnlockedZones" then
		local count = 0
		for zoneId, unlocked in pairs(if typeof(profile.UnlockedZones) == "table" then profile.UnlockedZones else {}) do
			if typeof(zoneId) == "number" and zoneId % 1 == 0 and zoneId >= 1 and unlocked == true then
				count += 1
			end
		end
		return math.min(definition.Threshold, count)
	end
	return safeInteger(profile[definition.SourceField], 0, RetentionConfig.MaximumExactInteger, 0)
end

local function claimResult(code, snapshot)
	return { Ok = code == "claimed" or code == "already_claimed", Changed = code == "claimed", Code = code, Snapshot = snapshot }
end

function RetentionProgress.claim(profile, requestedId, serverNowUnix)
	local state = getState(profile, dayIndex(serverNowUnix))
	local definition = RetentionConfig.Deeds[requestedId]
	local kind = "deed"
	if definition == nil then
		definition = RetentionConfig.PlaytimeMilestones[requestedId]
		kind = "playtime"
	end
	if definition == nil then
		definition = RetentionConfig.Achievements[requestedId]
		kind = "achievement"
	end
	if definition == nil then
		return claimResult("unknown_id", RetentionProgress.buildSnapshot(profile, serverNowUnix))
	end

	local claimed = if kind == "deed" then state.DailyClaimed elseif kind == "playtime" then state.PlaytimeClaimed else state.AchievementClaimed
	if claimed[requestedId] == true then
		return claimResult("already_claimed", RetentionProgress.buildSnapshot(profile, serverNowUnix))
	end
	local ready = if kind == "deed"
		then safeInteger(state.DailyProgress[requestedId], 0, definition.Requirement, 0) >= definition.Requirement
		elseif kind == "playtime"
		then state.ActiveSecondsToday >= definition.ActiveSeconds
		else achievementProgress(profile, definition) >= definition.Threshold
	if not ready then
		return claimResult("not_ready", RetentionProgress.buildSnapshot(profile, serverNowUnix))
	end
	if not applyReward(profile, definition.Reward) then
		return claimResult("reward_unavailable", RetentionProgress.buildSnapshot(profile, serverNowUnix))
	end
	claimed[requestedId] = true
	return claimResult("claimed", RetentionProgress.buildSnapshot(profile, serverNowUnix))
end

function RetentionProgress.claimLocked(withProfileLock, requestedId, serverNowUnix, saveConfirmed)
	if typeof(withProfileLock) ~= "function" or typeof(saveConfirmed) ~= "function" then
		return { Ok = false, Changed = false, Code = "integration_required" }
	end
	return withProfileLock(function(profile)
		local function deepCopy(value)
			if typeof(value) ~= "table" then return value end
			local result = {}
			for key, child in pairs(value) do result[key] = deepCopy(child) end
			return result
		end
		local beforeRetention = deepCopy(profile.Retention)
		local beforePotions = if typeof(profile.Potions) == "table" then table.clone(profile.Potions) else nil
		local beforeGems = profile.RitualGems
		local result = RetentionProgress.claim(profile, requestedId, serverNowUnix)
		if result.Code ~= "claimed" then
			return result
		end
		if saveConfirmed(profile, requestedId) ~= true then
			profile.Retention = beforeRetention
			profile.Potions = beforePotions
			profile.RitualGems = beforeGems
			return { Ok = false, Changed = false, Code = "save_failed" }
		end
		return result
	end)
end

function RetentionProgress.buildSnapshot(profile, serverNowUnix)
	local state = getState(profile, dayIndex(serverNowUnix))
	local snapshot = RetentionProgress.getDayWindow(serverNowUnix)
	snapshot.ActiveSecondsToday = state.ActiveSecondsToday
	snapshot.Deeds = {}
	snapshot.Playtime = {}
	snapshot.Achievements = {}
	snapshot.ReadyCount = 0
	for _, id in ipairs(RetentionConfig.DeedOrder) do
		local definition = RetentionConfig.Deeds[id]
		local progress = safeInteger(state.DailyProgress[id], 0, definition.Requirement, 0)
		local card = { Id = id, Progress = progress, Requirement = definition.Requirement, Claimed = state.DailyClaimed[id] == true, Reward = copyReward(definition.Reward) }
		card.Ready = not card.Claimed and progress >= card.Requirement
		if card.Ready then snapshot.ReadyCount += 1 end
		table.insert(snapshot.Deeds, card)
	end
	for _, id in ipairs(RetentionConfig.PlaytimeOrder) do
		local definition = RetentionConfig.PlaytimeMilestones[id]
		local card = { Id = id, Progress = math.min(state.ActiveSecondsToday, definition.ActiveSeconds), Requirement = definition.ActiveSeconds, Claimed = state.PlaytimeClaimed[id] == true, Reward = copyReward(definition.Reward) }
		card.Ready = not card.Claimed and state.ActiveSecondsToday >= card.Requirement
		if card.Ready then snapshot.ReadyCount += 1 end
		table.insert(snapshot.Playtime, card)
	end
	for _, id in ipairs(RetentionConfig.AchievementOrder) do
		local definition = RetentionConfig.Achievements[id]
		local progress = math.min(definition.Threshold, achievementProgress(profile, definition))
		local card = { Id = id, Progress = progress, Requirement = definition.Threshold, Claimed = state.AchievementClaimed[id] == true, Reward = copyReward(definition.Reward) }
		card.Ready = not card.Claimed and progress >= card.Requirement
		if card.Ready then snapshot.ReadyCount += 1 end
		table.insert(snapshot.Achievements, card)
	end
	return snapshot
end

RetentionProgress.getSnapshot = RetentionProgress.buildSnapshot

return RetentionProgress
