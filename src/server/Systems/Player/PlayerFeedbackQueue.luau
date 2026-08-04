local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local PresentationEventConfig = require(Config:WaitForChild("PresentationEventConfig"))
local ProfileContract = require(Config:WaitForChild("ProfileContract"))

local PlayerFeedbackQueue = {}

local stateByProfile = setmetatable({}, { __mode = "k" })

local function getSafeInteger(value, maximum)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(math.floor(value), 0, maximum)
end

local function getState(profile)
	local state = stateByProfile[profile]

	if state == nil then
		state = {
			Records = {},
			Readiness = {},
		}
		stateByProfile[profile] = state
	end

	return state
end

function PlayerFeedbackQueue.queue(profile, eventId, args)
	if typeof(profile) ~= "table" then
		return nil
	end

	local definition = PresentationEventConfig.getEvent(eventId)

	if definition == nil then
		return nil
	end

	local state = getState(profile)

	if #state.Records >= PresentationEventConfig.MaxQueuedRecords then
		return nil
	end

	local currentSequence = getSafeInteger(profile.FeedbackSequence, ProfileContract.MaximumExactInteger)

	if currentSequence >= ProfileContract.MaximumExactInteger then
		return nil
	end

	local sequence = currentSequence + 1
	local record = PresentationEventConfig.sanitizeRecord({
		Sequence = sequence,
		EventId = eventId,
		DedupeKey = eventId .. ":" .. tostring(sequence),
		Kind = definition.Kind,
		Args = args,
	})

	if record == nil then
		return nil
	end

	profile.FeedbackSequence = sequence
	table.insert(state.Records, record)

	return record
end

function PlayerFeedbackQueue.updateReadiness(profile, readinessId, isReady, eventId, args)
	if typeof(profile) ~= "table" or typeof(readinessId) ~= "string" then
		return nil
	end

	local state = getState(profile)
	local wasReady = state.Readiness[readinessId]
	local nextReady = isReady == true

	if wasReady == false and nextReady then
		local record = PlayerFeedbackQueue.queue(profile, eventId, args)

		-- A saturated bounded queue retries this transition after space drains.
		state.Readiness[readinessId] = record ~= nil

		return record
	end

	state.Readiness[readinessId] = nextReady

	return nil
end

function PlayerFeedbackQueue.hasReady(profile)
	local state = stateByProfile[profile]

	return state ~= nil and #state.Records > 0
end

function PlayerFeedbackQueue.drain(profile, maximumRecords)
	local state = stateByProfile[profile]
	local records = {}

	if state == nil then
		return records
	end

	local requestedMaximum = getSafeInteger(
		maximumRecords,
		PresentationEventConfig.MaxRecordsPerPacket
	)
	local limit = if maximumRecords == nil
		then PresentationEventConfig.MaxRecordsPerPacket
		else requestedMaximum

	for _ = 1, math.min(limit, #state.Records) do
		table.insert(records, table.remove(state.Records, 1))
	end

	return records
end

function PlayerFeedbackQueue.clear(profile)
	stateByProfile[profile] = nil
end

return PlayerFeedbackQueue
