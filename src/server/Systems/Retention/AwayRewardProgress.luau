local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local RuneFocusConfig = require(Config:WaitForChild("RuneFocusConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local PetConfig = require(Config:WaitForChild("PetConfig"))

local AwayRewardProgress = {}

AwayRewardProgress.MaximumAwayMinutes = 480
AwayRewardProgress.EssenceEfficiency = 0.20
AwayRewardProgress.RuneEfficiency = 0.45
AwayRewardProgress.FocusIds = table.clone(RuneFocusConfig.FocusOrder)

local MAXIMUM_EXACT_INTEGER = ProfileContract.MaximumExactInteger

local function finiteNumber(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end

	return math.clamp(value, 0, MAXIMUM_EXACT_INTEGER)
end

local function safeInteger(value, fallback)
	return math.floor(finiteNumber(value, fallback))
end

local function boundedAdd(left, right)
	local safeLeft = safeInteger(left, 0)
	local safeRight = safeInteger(right, 0)

	return math.min(MAXIMUM_EXACT_INTEGER, safeLeft + safeRight)
end

local function boundedMultiply(...)
	local result = 1

	for index = 1, select("#", ...) do
		local factor = finiteNumber(select(index, ...), 0)

		if factor == 0 then
			return 0
		end

		if result >= MAXIMUM_EXACT_INTEGER / factor then
			return MAXIMUM_EXACT_INTEGER
		end

		result *= factor
	end

	return math.min(MAXIMUM_EXACT_INTEGER, result)
end

local function cloneFocusMap(source)
	local result = {}

	for _, focusId in ipairs(AwayRewardProgress.FocusIds) do
		result[focusId] = safeInteger(typeof(source) == "table" and source[focusId] or 0, 0)
	end

	return result
end

local function getAwayRewards(profile)
	local awayRewards = if typeof(profile.AwayRewards) == "table" then profile.AwayRewards else {}
	awayRewards.Version = 1
	awayRewards.NextSequence = math.max(1, safeInteger(awayRewards.NextSequence, 1))
	profile.AwayRewards = awayRewards

	return awayRewards
end

local function getServerUnix(nowUnix)
	if typeof(nowUnix) == "number" and nowUnix == nowUnix and math.abs(nowUnix) ~= math.huge then
		return math.max(0, math.floor(nowUnix))
	end

	return DateTime.now().UnixTimestamp
end

local function getValidZone(context)
	local zoneId = safeInteger(context.ZoneId, 0)
	local zone = ZoneConfig.getZone(zoneId)

	if zone == nil or typeof(context.UnlockedZones) ~= "table" or context.UnlockedZones[zoneId] ~= true then
		return nil, nil
	end

	return zoneId, zone
end

local function getAwayCapMinutes(context)
	return math.clamp(safeInteger(context.AwayCapMinutes, 0), 0, AwayRewardProgress.MaximumAwayMinutes)
end

local function calculateRates(checkpoint)
	local zone = ZoneConfig.getZone(checkpoint.ZoneId)

	if zone == nil then
		return 0, 0
	end

	local effectiveTeamDamage = finiteNumber(checkpoint.EffectiveTeamDamage, 0)
	local petAttackInterval = math.max(0.001, finiteNumber(PetConfig.getPetAttackInterval(), 0.5))
	local breakSeconds = math.ceil(zone.CrystalHealth / math.max(1, effectiveTeamDamage)) * petAttackInterval
	local breaksPerMinute = if effectiveTeamDamage <= 0
		then 0
		else math.min(30, 60 / math.max(petAttackInterval, breakSeconds))
	local rewardPerBreak = math.floor(boundedMultiply(
		zone.CrystalEssenceReward,
		checkpoint.PersistentEssenceMultiplier
	))
	local onlineEssencePerMinute = boundedMultiply(breaksPerMinute, rewardPerBreak)
	local baseRuneChargePerBreak = math.floor(
		4 + 2.5 * checkpoint.ZoneId + 0.75 * math.sqrt(zone.CrystalEssenceReward)
	)
	local onlineRuneChargePerMinute = boundedMultiply(
		breaksPerMinute,
		baseRuneChargePerBreak,
		checkpoint.PersistentRuneChargeMultiplier,
		checkpoint.CapacityStateMultiplier
	)

	return onlineEssencePerMinute, onlineRuneChargePerMinute
end

function AwayRewardProgress.createCheckpoint(context, nowUnix)
	local source = if typeof(context) == "table" then context else {}
	local zoneId, zone = getValidZone(source)

	if zone == nil then
		return {
			Ok = false,
			Code = "invalid_away_zone",
		}
	end

	local capacity = safeInteger(source.Capacity, 0)
	local essence = safeInteger(source.Essence, 0)
	local persistentEssenceMultiplier = finiteNumber(source.PersistentEssenceMultiplier, 1)
	local rewardPerBreak = math.floor(boundedMultiply(zone.CrystalEssenceReward, persistentEssenceMultiplier))
	local storedFraction = math.clamp(
		math.min(rewardPerBreak, math.max(0, capacity - essence)) / math.max(1, rewardPerBreak),
		0,
		1
	)
	local capacityStateMultiplier = 0.55 + 0.45 * storedFraction

	return {
		Ok = true,
		Checkpoint = {
			CapturedAtUnix = getServerUnix(nowUnix),
			ZoneId = zoneId,
			EffectiveTeamDamage = finiteNumber(source.EffectiveTeamDamage, 0),
			Capacity = capacity,
			Essence = essence,
			PersistentEssenceMultiplier = persistentEssenceMultiplier,
			PersistentRuneChargeMultiplier = finiteNumber(source.PersistentRuneChargeMultiplier, 1),
			CapacityStateMultiplier = capacityStateMultiplier,
			ActiveRuneFocusId = if RuneFocusConfig.getFocus(source.ActiveRuneFocusId) ~= nil
				then source.ActiveRuneFocusId
				else nil,
			AwayCapMinutes = getAwayCapMinutes(source),
		},
	}
end

local function publicCheckpoint(checkpoint)
	local result = table.clone(checkpoint)
	result.PetAttackIntervalSeconds = nil
	return result
end

function AwayRewardProgress.calculateOffer(checkpoint, nowUnix)
	if typeof(checkpoint) ~= "table" or ZoneConfig.getZone(checkpoint.ZoneId) == nil then
		return nil
	end

	local now = getServerUnix(nowUnix)
	local capturedAt = safeInteger(checkpoint.CapturedAtUnix, now)
	local observedMinutes = math.floor(math.max(0, now - capturedAt) / 60)
	local eligibleMinutes = math.min(
		observedMinutes,
		math.min(safeInteger(checkpoint.AwayCapMinutes, 0), AwayRewardProgress.MaximumAwayMinutes)
	)
	local onlineEssencePerMinute, onlineRuneChargePerMinute = calculateRates(checkpoint)
	local potentialEssence = math.floor(math.min(
		boundedMultiply(checkpoint.Capacity, 0.65),
		boundedMultiply(onlineEssencePerMinute, eligibleMinutes, AwayRewardProgress.EssenceEfficiency)
	))
	local runeCharge = 0

	if checkpoint.ActiveRuneFocusId ~= nil then
		runeCharge = math.floor(boundedMultiply(
			onlineRuneChargePerMinute,
			eligibleMinutes,
			AwayRewardProgress.RuneEfficiency
		))
	end

	local chargeByFocus = {}

	if checkpoint.ActiveRuneFocusId ~= nil then
		chargeByFocus[checkpoint.ActiveRuneFocusId] = runeCharge
	end

	chargeByFocus = cloneFocusMap(chargeByFocus)

	return {
		FromUnix = math.min(capturedAt, now),
		ToUnix = now,
		ObservedMinutes = observedMinutes,
		EligibleMinutes = eligibleMinutes,
		WasTimeCapped = observedMinutes > eligibleMinutes,
		PotentialEssence = potentialEssence,
		RuneChargeByFocus = chargeByFocus,
		Checkpoint = publicCheckpoint(checkpoint),
	}
end

function AwayRewardProgress.mergePending(pending, offer)
	if typeof(offer) ~= "table" or offer.ObservedMinutes < 1 then
		return pending
	end

	local current = if typeof(pending) == "table" then pending else nil
	local merged = {
		Sequence = if current ~= nil then safeInteger(current.Sequence, 1) else 1,
		FromUnix = if current ~= nil then safeInteger(current.FromUnix, offer.FromUnix) else offer.FromUnix,
		ToUnix = offer.ToUnix,
		ObservedMinutes = if current ~= nil
			then boundedAdd(current.ObservedMinutes, offer.ObservedMinutes)
			else offer.ObservedMinutes,
		EligibleMinutes = if current ~= nil
			then boundedAdd(current.EligibleMinutes, offer.EligibleMinutes)
			else offer.EligibleMinutes,
		WasTimeCapped = (current ~= nil and current.WasTimeCapped == true) or offer.WasTimeCapped == true,
		PotentialEssence = if current ~= nil
			then boundedAdd(current.PotentialEssence, offer.PotentialEssence)
			else offer.PotentialEssence,
		RuneChargeByFocus = cloneFocusMap(current ~= nil and current.RuneChargeByFocus or nil),
	}

	for _, focusId in ipairs(AwayRewardProgress.FocusIds) do
		merged.RuneChargeByFocus[focusId] = boundedAdd(
			merged.RuneChargeByFocus[focusId],
			offer.RuneChargeByFocus[focusId]
		)
	end

	return merged
end

function AwayRewardProgress.captureInterval(profile, checkpoint, nowUnix)
	local awayRewards = getAwayRewards(profile)
	local offer = AwayRewardProgress.calculateOffer(checkpoint, nowUnix)

	if offer == nil then
		return { Ok = false, Code = "invalid_away_checkpoint" }
	end

	if offer.ObservedMinutes >= 1 then
		if typeof(awayRewards.Pending) ~= "table"
			and awayRewards.NextSequence >= MAXIMUM_EXACT_INTEGER
		then
			return { Ok = false, Changed = false, Code = "away_sequence_exhausted" }
		end

		local pending = AwayRewardProgress.mergePending(awayRewards.Pending, offer)
		pending.Sequence = if typeof(awayRewards.Pending) == "table"
			then safeInteger(awayRewards.Pending.Sequence, awayRewards.NextSequence)
			else awayRewards.NextSequence
		awayRewards.Pending = pending
	end

	return {
		Ok = true,
		Changed = offer.ObservedMinutes >= 1,
		Offer = offer,
		Pending = awayRewards.Pending,
	}
end

function AwayRewardProgress.refreshCheckpoint(profile, context, nowUnix)
	local awayRewards = getAwayRewards(profile)
	local previousCheckpoint = awayRewards.Checkpoint
	local intervalResult = nil

	if typeof(previousCheckpoint) == "table" then
		intervalResult = AwayRewardProgress.captureInterval(profile, previousCheckpoint, nowUnix)
		if intervalResult.Ok ~= true then
			return intervalResult
		end
	end

	local checkpointResult = AwayRewardProgress.createCheckpoint(context, nowUnix)
	if checkpointResult.Ok ~= true then
		return checkpointResult
	end

	awayRewards.Checkpoint = checkpointResult.Checkpoint

	return {
		Ok = true,
		Changed = intervalResult ~= nil and intervalResult.Changed == true,
		Offer = if intervalResult ~= nil then intervalResult.Offer else nil,
		Pending = awayRewards.Pending,
		Checkpoint = publicCheckpoint(checkpointResult.Checkpoint),
	}
end

local function resolutionCopy(resolution)
	if typeof(resolution) ~= "table" then
		return nil
	end

	local result = table.clone(resolution)
	result.RuneChargeAppliedByFocus = cloneFocusMap(resolution.RuneChargeAppliedByFocus)
	result.RuneLevelsGainedByFocus = cloneFocusMap(resolution.RuneLevelsGainedByFocus)
	return result
end

function AwayRewardProgress.resolve(profile, kind, sequence, context, applyRuneCharge, nowUnix)
	local awayRewards = getAwayRewards(profile)
	local requestedSequence = safeInteger(sequence, 0)

	if requestedSequence <= 0 or requestedSequence ~= sequence then
		return { Ok = false, Changed = false, Code = "invalid_away_sequence" }
	end

	if typeof(awayRewards.LastResolution) == "table"
		and awayRewards.LastResolution.Sequence == requestedSequence
	then
		return {
			Ok = true,
			Changed = false,
			Code = "away_already_resolved",
			Resolution = resolutionCopy(awayRewards.LastResolution),
		}
	end

	local pending = awayRewards.Pending
	if typeof(pending) ~= "table" or safeInteger(pending.Sequence, 0) ~= requestedSequence then
		return { Ok = false, Changed = false, Code = "away_sequence_mismatch" }
	end

	local safeContext = if typeof(context) == "table" then context else {}
	local currentCapacity = safeInteger(safeContext.Capacity, 0)
	local currentEssence = safeInteger(profile.Essence, safeContext.Essence or 0)
	local pendingChargeByFocus = if typeof(pending.RuneChargeByFocus) == "table"
		then pending.RuneChargeByFocus
		else {}
	local essenceAwarded = 0
	local chargeAppliedByFocus = cloneFocusMap(nil)
	local levelsGainedByFocus = cloneFocusMap(nil)

	if requestedSequence >= MAXIMUM_EXACT_INTEGER then
		return { Ok = false, Changed = false, Code = "away_sequence_exhausted" }
	end

	if kind == "claimed" then
		local hasRuneCharge = false

		for _, focusId in ipairs(AwayRewardProgress.FocusIds) do
			if safeInteger(pendingChargeByFocus[focusId], 0) > 0 then
				hasRuneCharge = true
				break
			end
		end

		if hasRuneCharge and typeof(applyRuneCharge) ~= "function" then
			return { Ok = false, Changed = false, Code = "away_rune_callback_required" }
		end

		essenceAwarded = math.min(
			safeInteger(pending.PotentialEssence, 0),
			math.max(0, currentCapacity - currentEssence)
		)
		profile.Essence = boundedAdd(currentEssence, essenceAwarded)

		for _, focusId in ipairs(AwayRewardProgress.FocusIds) do
			local requestedCharge = safeInteger(pendingChargeByFocus[focusId], 0)
			if requestedCharge > 0 and typeof(applyRuneCharge) == "function" then
				local result = applyRuneCharge(focusId, requestedCharge, "offline")
				if typeof(result) == "table" then
					chargeAppliedByFocus[focusId] = safeInteger(result.ChargeApplied, 0)
					levelsGainedByFocus[focusId] = safeInteger(result.LevelsGained, 0)
				end
			end
		end
	elseif kind ~= "dismissed" then
		return { Ok = false, Changed = false, Code = "invalid_away_resolution" }
	end

	local resolution = {
		Sequence = requestedSequence,
		Kind = kind,
		ResolvedAtUnix = getServerUnix(nowUnix),
		EssenceAwarded = essenceAwarded,
		RuneChargeAppliedByFocus = chargeAppliedByFocus,
		RuneLevelsGainedByFocus = levelsGainedByFocus,
	}
	awayRewards.Pending = nil
	awayRewards.LastResolution = resolutionCopy(resolution)
	awayRewards.NextSequence = math.min(MAXIMUM_EXACT_INTEGER, requestedSequence + 1)

	return {
		Ok = true,
		Changed = true,
		Code = if kind == "claimed" then "away_claimed" else "away_dismissed",
		Resolution = resolutionCopy(resolution),
	}
end

return AwayRewardProgress
