local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Net"):WaitForChild("Network"))

local Systems = script.Parent.Parent
local PlayerStateService = require(Systems:WaitForChild("Player"):WaitForChild("PlayerStateService"))
local SnapshotPublisher = require(Systems:WaitForChild("Player"):WaitForChild("SnapshotPublisher"))

local RitualService = {}

local hasStarted = false
local rateBucketsByPlayer = {}

local ACTION_RATE_LIMIT = {
	Capacity = 10,
	RefillPerSecond = 5,
}
local BAD_REQUEST_RATE_LIMIT = {
	Capacity = 4,
	RefillPerSecond = 1,
}
local SNAPSHOT_RATE_LIMIT = {
	Capacity = 4,
	RefillPerSecond = 1,
}
local FEATURE_RATE_LIMIT = {
	Capacity = 2,
	RefillPerSecond = 1,
}
local MINIMUM_RETRY_AFTER_SECONDS = 0.05

local function getPayloadValue(payload, key)
	if typeof(payload) ~= "table" then
		return nil
	end

	return payload[key]
end

local function getStrictScalarPayload(payload, key, expectedType)
	if typeof(payload) ~= "table" then return nil end
	for payloadKey in pairs(payload) do
		if payloadKey ~= key then return nil end
	end
	local value = payload[key]
	return if typeof(value) == expectedType then value else nil
end

local function getStrictPetPayload(payload)
	if typeof(payload) ~= "table" then return nil, nil end
	for key in pairs(payload) do
		if key ~= "PetId" and key ~= "EquippedCount" then return nil, nil end
	end
	return if typeof(payload.PetId) == "string" then payload.PetId else nil,
		if typeof(payload.EquippedCount) == "number" then payload.EquippedCount else nil
end

local actionHandlers = {
	[Network.Actions.RollPet] = function(player)
		return PlayerStateService.rollPet(player)
	end,

	[Network.Actions.BuyStoneUpgrade] = function(player, payload)
		return PlayerStateService.buyStoneUpgrade(player, getPayloadValue(payload, "UpgradeId"))
	end,

	[Network.Actions.UnlockZone] = function(player, payload)
		return PlayerStateService.unlockZone(player, getPayloadValue(payload, "ZoneId"))
	end,

	[Network.Actions.SelectZone] = function(player, payload)
		return PlayerStateService.selectZone(player, getPayloadValue(payload, "ZoneId"))
	end,

	[Network.Actions.Rebirth] = function(player)
		return PlayerStateService.rebirth(player)
	end,

	[Network.Actions.Ascend] = function(player)
		return PlayerStateService.ascend(player)
	end,

	[Network.Actions.SelectRuneFocus] = function(player, payload)
		return PlayerStateService.selectRuneFocus(player, getPayloadValue(payload, "FocusId"))
	end,

	[Network.Actions.BuyAscensionUpgrade] = function(player, payload)
		return PlayerStateService.buyAscensionUpgrade(player, getPayloadValue(payload, "UpgradeId"))
	end,

	[Network.Actions.SetAutoCapacity] = function(player, payload)
		return PlayerStateService.setAutoCapacity(player, getPayloadValue(payload, "Enabled"))
	end,

	[Network.Actions.BuyRune] = function(player, payload)
		return PlayerStateService.buyRune(player, getPayloadValue(payload, "RuneId"))
	end,

	[Network.Actions.CompleteTutorialStep] = function(player, payload)
		return PlayerStateService.completeTutorialStep(
			player,
			getPayloadValue(payload, "StepId"),
			getPayloadValue(payload, "CompletionMode")
		)
	end,

	[Network.Actions.ClaimRitualRushReward] = function(player, payload)
		return PlayerStateService.claimRitualRushReward(
			player,
			getPayloadValue(payload, "MilestoneId"),
			getPayloadValue(payload, "Track")
		)
	end,

	[Network.Actions.ClaimRitualRushFreeReward] = function(player, payload)
		return PlayerStateService.claimRitualRushFreeReward(player, getPayloadValue(payload, "MilestoneId"))
	end,

	[Network.Actions.UsePotion] = function(player, payload)
		return PlayerStateService.usePotion(player, getPayloadValue(payload, "PotionId"))
	end,

	[Network.Actions.BuyPotionWithGems] = function(player, payload)
		return PlayerStateService.buyPotionWithGems(player, getPayloadValue(payload, "PotionId"))
	end,

	[Network.Actions.ClaimDailyReward] = function(player, payload)
		return PlayerStateService.claimDailyReward(player, getStrictScalarPayload(payload, "DayIndex", "number"))
	end,

	[Network.Actions.ClaimAwayRewards] = function(player, payload)
		return PlayerStateService.resolveAwayRewards(player, "claimed", getStrictScalarPayload(payload, "Sequence", "number"))
	end,

	[Network.Actions.DismissAwayRewards] = function(player, payload)
		return PlayerStateService.resolveAwayRewards(player, "dismissed", getStrictScalarPayload(payload, "Sequence", "number"))
	end,

	[Network.Actions.UpdateGuidance] = function(player, payload)
		return PlayerStateService.updateGuidance(player, payload)
	end,

	[Network.Actions.SetPetEquippedCount] = function(player, payload)
		local petId, equippedCount = getStrictPetPayload(payload)
		return PlayerStateService.setPetEquippedCount(player, petId, equippedCount)
	end,
	[Network.Actions.UnequipPet] = function(player, payload)
		return PlayerStateService.unequipPet(player, getStrictScalarPayload(payload, "PetId", "string"))
	end,
	[Network.Actions.EquipBestPets] = function(player, payload)
		if typeof(payload) == "table" and next(payload) ~= nil then return { Ok = false, Changed = false, Code = "invalid_payload" } end
		return PlayerStateService.equipBestPets(player)
	end,
	[Network.Actions.ClaimRetention] = function(player, payload)
		return PlayerStateService.claimRetention(player, getStrictScalarPayload(payload, "RetentionId", "string"))
	end,
}

local function getPlayerBuckets(player)
	local buckets = rateBucketsByPlayer[player]

	if buckets == nil then
		buckets = {}
		rateBucketsByPlayer[player] = buckets
	end

	return buckets
end

local function getBucket(player, bucketName, config)
	local buckets = getPlayerBuckets(player)
	local bucket = buckets[bucketName]

	if bucket == nil then
		bucket = {
			Tokens = config.Capacity,
			UpdatedAt = os.clock(),
		}
		buckets[bucketName] = bucket
	end

	return bucket
end

local function consumeRateLimitToken(player, bucketName, config)
	local bucket = getBucket(player, bucketName, config)
	local now = os.clock()
	local elapsed = math.max(0, now - bucket.UpdatedAt)

	bucket.Tokens = math.min(config.Capacity, bucket.Tokens + elapsed * config.RefillPerSecond)
	bucket.UpdatedAt = now

	if bucket.Tokens < 1 then
		local retryAfter = (1 - bucket.Tokens) / math.max(config.RefillPerSecond, 0.001)

		return false, math.max(MINIMUM_RETRY_AFTER_SECONDS, retryAfter)
	end

	bucket.Tokens -= 1

	return true, 0
end

local function getRateLimitedResponse(player, bucketName, config)
	local allowed, retryAfter = consumeRateLimitToken(player, bucketName, config)

	if allowed then
		return nil
	end

	return {
		Ok = false,
		Changed = false,
		Code = "rate_limited",
		Message = "Slow down.",
		RetryAfter = retryAfter,
	}
end

local function normalizeActionResult(result)
	local response = if typeof(result) == "table" then result else {}

	response.Ok = response.Ok == true
	response.Changed = response.Changed == true

	if
		typeof(response.Code) ~= "string"
		or string.match(response.Code, "^[a-z][a-z0-9_]*$") == nil
	then
		if response.Ok then
			response.Code = if response.Changed then "ok" else "no_change"
		else
			response.Code = "action_failed"
		end
	end

	return response
end

local function processAction(player, actionName, payload)
	if typeof(actionName) ~= "string" then
		local rateLimitedResponse = getRateLimitedResponse(player, "BadRequest", BAD_REQUEST_RATE_LIMIT)

		if rateLimitedResponse ~= nil then
			return rateLimitedResponse
		end

		return {
			Ok = false,
			Changed = false,
			Code = "invalid_action_request",
			Message = "Invalid action request.",
		}
	end

	local handler = actionHandlers[actionName]

	if handler == nil then
		local rateLimitedResponse = getRateLimitedResponse(player, "BadRequest", BAD_REQUEST_RATE_LIMIT)

		if rateLimitedResponse ~= nil then
			return rateLimitedResponse
		end

		return {
			Ok = false,
			Changed = false,
			Code = "unknown_action",
			Message = "Unknown action request.",
		}
	end

	local rateLimitedResponse = getRateLimitedResponse(player, "Action", ACTION_RATE_LIMIT)

	if rateLimitedResponse ~= nil then
		return rateLimitedResponse
	end

	if actionName == Network.Actions.ClaimDailyReward
		or actionName == Network.Actions.ClaimAwayRewards
		or actionName == Network.Actions.DismissAwayRewards
		or actionName == Network.Actions.UpdateGuidance
		or actionName == Network.Actions.ClaimRetention
	then
		local featureRateLimitedResponse = getRateLimitedResponse(player, "Retention", FEATURE_RATE_LIMIT)

		if featureRateLimitedResponse ~= nil then
			return featureRateLimitedResponse
		end
	end

	if actionName == Network.Actions.SetPetEquippedCount
		or actionName == Network.Actions.UnequipPet
		or actionName == Network.Actions.EquipBestPets
	then
		local petRateLimitedResponse = getRateLimitedResponse(player, "PetInventory", FEATURE_RATE_LIMIT)

		if petRateLimitedResponse ~= nil then
			return petRateLimitedResponse
		end
	end

	return PlayerStateService.withProfileLock(player, function()
		local result = normalizeActionResult(handler(player, payload))

		if result.Code == "action_failed" and result.Message == nil then
			result = normalizeActionResult({
				Ok = false,
				Changed = false,
				Code = "action_failed",
				Message = "Action failed.",
			})
		end

		return normalizeActionResult(SnapshotPublisher.attach(player, result))
	end)
end

local function invokeAction(player, actionName, payload)
	local ok, result = pcall(processAction, player, actionName, payload)

	if not ok then
		warn(result)

		return {
			Ok = false,
			Changed = false,
			Code = "internal_error",
			Message = "Action failed.",
		}
	end

	return result
end

function RitualService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local requestAction = Network.getRemoteFunction(Network.RemoteFunctions.RequestAction)
	local requestSnapshot = Network.getRemoteFunction(Network.RemoteFunctions.RequestSnapshot)

	requestSnapshot.OnServerInvoke = function(player)
		local snapshotAllowed = consumeRateLimitToken(player, "Snapshot", SNAPSHOT_RATE_LIMIT)

		if not snapshotAllowed then
			return nil
		end

		if PlayerStateService.waitForProfile(player) == nil then
			return nil
		end

		return PlayerStateService.withProfileLock(player, function()
			return PlayerStateService.getSnapshot(player)
		end)
	end

	requestAction.OnServerInvoke = function(player, actionName, payload)
		return invokeAction(player, actionName, payload)
	end

	Players.PlayerRemoving:Connect(function(player)
		rateBucketsByPlayer[player] = nil
	end)
end

return RitualService
