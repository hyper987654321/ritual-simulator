local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local BoostConfig = require(Config:WaitForChild("BoostConfig"))
local PresentationEventConfig = require(Config:WaitForChild("PresentationEventConfig"))
local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local RuneFocusConfig = require(Config:WaitForChild("RuneFocusConfig"))

local Systems = script.Parent.Parent
local PlayerFeedbackQueue = require(Systems:WaitForChild("Player"):WaitForChild("PlayerFeedbackQueue"))

local RuneFocusProgress = {}

RuneFocusProgress.CapacityStates = {
	Available = "available",
	FullCharging = "full_charging",
	FullPaused = "full_paused",
}

RuneFocusProgress.PauseReasons = {
	Locked = "rune_focus_locked",
	SelectionRequired = "rune_focus_selection_required",
	ActiveFocusMaxed = "rune_focus_maxed",
}

local chargeFeedbackStateByProfile = setmetatable({}, { __mode = "k" })

local function getSafeInteger(value, maximum)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(math.floor(value), 0, maximum)
end

local function getFeedbackState(profile)
	local state = chargeFeedbackStateByProfile[profile]

	if state == nil then
		state = {
			PendingChargeByFocus = {},
			LastChargePublishedAt = nil,
		}
		chargeFeedbackStateByProfile[profile] = state
	end

	return state
end

local function ensureRuneFocus(profile)
	local runeFocus = if typeof(profile.RuneFocus) == "table" then profile.RuneFocus else {}
	local levels = if typeof(runeFocus.Levels) == "table" then runeFocus.Levels else {}
	local charge = if typeof(runeFocus.Charge) == "table" then runeFocus.Charge else {}

	for _, focusId in ipairs(RuneFocusConfig.FocusOrder) do
		local focus = RuneFocusConfig.getFocus(focusId)
		local level = getSafeInteger(levels[focusId], focus.MaxLevel)

		levels[focusId] = level

		if level >= focus.MaxLevel then
			charge[focusId] = 0
		else
			local requirement = RuneFocusConfig.getRequiredCharge(focusId, level) or 1
			charge[focusId] = getSafeInteger(charge[focusId], math.max(0, requirement - 1))
		end
	end

	runeFocus.Version = 1
	runeFocus.ActiveId = if RuneFocusConfig.getFocus(runeFocus.ActiveId) ~= nil then runeFocus.ActiveId else nil
	runeFocus.Levels = levels
	runeFocus.Charge = charge
	profile.RuneFocus = runeFocus

	return runeFocus
end

function RuneFocusProgress.getChargeEligibility(profile)
	if not RuneFocusConfig.canUseFocus(profile.UnlockedZones, profile.Rebirths) then
		return false, RuneFocusProgress.PauseReasons.Locked
	end

	local runeFocus = ensureRuneFocus(profile)
	local activeId = runeFocus.ActiveId
	local focus = RuneFocusConfig.getFocus(activeId)

	if focus == nil then
		return false, RuneFocusProgress.PauseReasons.SelectionRequired
	end

	if runeFocus.Levels[activeId] >= focus.MaxLevel then
		return false, RuneFocusProgress.PauseReasons.ActiveFocusMaxed
	end

	return true, nil
end

function RuneFocusProgress.getCapacityState(profile, stats)
	local capacity = getSafeInteger(
		typeof(stats) == "table" and stats.Capacity or 0,
		ProfileContract.MaximumExactInteger
	)
	local essence = getSafeInteger(profile.Essence, ProfileContract.MaximumExactInteger)

	if essence < capacity then
		return RuneFocusProgress.CapacityStates.Available, nil
	end

	local canCharge, pauseReason = RuneFocusProgress.getChargeEligibility(profile)

	if canCharge then
		return RuneFocusProgress.CapacityStates.FullCharging, nil
	end

	return RuneFocusProgress.CapacityStates.FullPaused, pauseReason
end

function RuneFocusProgress.getCurrentChargeMultiplier(profile, stats, actualCrystalReward)
	local safeStats = if typeof(stats) == "table" then stats else {}
	local canCharge = RuneFocusProgress.getChargeEligibility(profile)

	if not canCharge then
		return 0
	end

	local capacity = getSafeInteger(safeStats.Capacity, ProfileContract.MaximumExactInteger)
	local essence = getSafeInteger(profile.Essence, ProfileContract.MaximumExactInteger)
	local availableCapacity = math.max(0, capacity - essence)
	local safeReward = math.max(1, getSafeInteger(actualCrystalReward, ProfileContract.MaximumExactInteger))
	local storedFraction = math.clamp(availableCapacity / safeReward, 0, 1)
	local capacityMultiplier = RuneFocusConfig.OnlineCharge.FullCapacityMultiplier
		+ (1 - RuneFocusConfig.OnlineCharge.FullCapacityMultiplier) * storedFraction

	return (safeStats.RebirthRuneChargeMultiplier or 1)
		* (safeStats.AscensionRuneChargeMultiplier or 1)
		* BoostConfig.getActiveBoostMultiplier(profile.ActiveBoosts, BoostConfig.BoostIds.RuneChargeMultiplier)
		* capacityMultiplier
end

function RuneFocusProgress.selectFocus(profile, focusId, now)
	if
		typeof(focusId) ~= "string"
		or #focusId == 0
		or #focusId > ProfileContract.MaximumIdentifierLength
		or RuneFocusConfig.getFocus(focusId) == nil
	then
		return {
			Ok = false,
			Changed = false,
			Code = "invalid_rune_focus",
			Message = "Choose a configured Rune Focus.",
		}
	end

	if not RuneFocusConfig.canUseFocus(profile.UnlockedZones, profile.Rebirths) then
		return {
			Ok = false,
			Changed = false,
			Code = "rune_focus_locked",
			Message = "Rune Focus requires one Rebirth and Zone 3 in this run.",
		}
	end

	local runeFocus = ensureRuneFocus(profile)

	if runeFocus.ActiveId == focusId then
		return {
			Ok = true,
			Changed = false,
			Code = "rune_focus_already_selected",
			Message = "That Rune Focus is already active.",
		}
	end

	local focus = RuneFocusConfig.getFocus(focusId)

	if runeFocus.Levels[focusId] >= focus.MaxLevel then
		return {
			Ok = false,
			Changed = false,
			Code = "rune_focus_maxed",
			Message = "That Rune Focus is already at maximum level.",
		}
	end

	local hasActiveFocus = runeFocus.ActiveId ~= nil

	if hasActiveFocus and profile.CrystalFarmingActive == true then
		return {
			Ok = false,
			Changed = false,
			Code = "rune_focus_farming_active",
			Message = "Leave the crystal area before changing Rune Focus.",
		}
	end

	local currentTime = if typeof(now) == "number" and now == now and math.abs(now) ~= math.huge then now else os.clock()
	local readyAt = if typeof(profile.RuneFocusSelectionReadyAt) == "number"
		and profile.RuneFocusSelectionReadyAt == profile.RuneFocusSelectionReadyAt
		and math.abs(profile.RuneFocusSelectionReadyAt) ~= math.huge
		then profile.RuneFocusSelectionReadyAt
		else 0
	local retryAfter = math.max(0, readyAt - currentTime)

	if hasActiveFocus and retryAfter > 0 then
		return {
			Ok = false,
			Changed = false,
			Code = "rune_focus_cooldown",
			Message = "Rune Focus is still settling.",
			RetryAfter = retryAfter,
		}
	end

	runeFocus.ActiveId = focusId
	profile.RuneFocusSelectionReadyAt = currentTime + RuneFocusConfig.SelectionCooldownSeconds
	PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.RuneFocusSelected, {
		FocusId = focusId,
	})

	return {
		Ok = true,
		Changed = true,
		Code = "rune_focus_selected",
		Message = focus.DisplayName .. " selected.",
	}
end

function RuneFocusProgress.grantOnlineCrystalBreak(profile, context)
	local canCharge, pauseReason = RuneFocusProgress.getChargeEligibility(profile)

	if not canCharge then
		return {
			Changed = false,
			PauseReason = pauseReason,
			ChargeApplied = 0,
			LevelsGained = 0,
		}
	end

	local source = if typeof(context) == "table" then context else {}
	local runeFocus = ensureRuneFocus(profile)
	local focusId = runeFocus.ActiveId
	local focus = RuneFocusConfig.getFocus(focusId)
	local level = runeFocus.Levels[focusId]
	local currentCharge = runeFocus.Charge[focusId]
	local chargeGain = RuneFocusConfig.calculateOnlineBreakCharge({
		ZoneId = source.ZoneId,
		BaseCrystalReward = source.BaseCrystalReward,
		ActualCrystalReward = source.ActualCrystalReward,
		EssenceAwarded = source.EssenceAwarded,
		RebirthChargeMultiplier = source.RebirthChargeMultiplier,
		AscensionChargeMultiplier = source.AscensionChargeMultiplier,
		ActiveRunePotionMultiplier = BoostConfig.getActiveBoostMultiplier(
			profile.ActiveBoosts,
			BoostConfig.BoostIds.RuneChargeMultiplier
		),
	})
	local acceptedChargeGain = math.min(
		chargeGain,
		math.max(0, ProfileContract.MaximumExactInteger - currentCharge)
	)
	local carriedCharge = currentCharge + acceptedChargeGain
	local levelsGained = 0
	local consumedCharge = 0

	while level < focus.MaxLevel do
		local requirement = RuneFocusConfig.getRequiredCharge(focusId, level)

		if requirement == nil or requirement <= 0 or carriedCharge < requirement then
			break
		end

		carriedCharge -= requirement
		consumedCharge += requirement
		level += 1
		levelsGained += 1
	end

	if level >= focus.MaxLevel then
		carriedCharge = 0
	end

	local chargeApplied = math.clamp(consumedCharge + carriedCharge - currentCharge, 0, acceptedChargeGain)

	runeFocus.Levels[focusId] = level
	runeFocus.Charge[focusId] = carriedCharge

	local feedbackState = getFeedbackState(profile)
	local pending = feedbackState.PendingChargeByFocus[focusId]

	if pending == nil then
		pending = {
			ChargeApplied = 0,
		}
		feedbackState.PendingChargeByFocus[focusId] = pending
	end

	pending.ChargeApplied = math.min(
		ProfileContract.MaximumExactInteger,
		pending.ChargeApplied + chargeApplied
	)
	pending.Level = level
	pending.Charge = carriedCharge
	pending.RequiredCharge = RuneFocusConfig.getRequiredCharge(focusId, level) or 0

	if levelsGained > 0 then
		PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.RuneLevelUp, {
			FocusId = focusId,
			LevelsGained = levelsGained,
			Level = level,
		})
	end

	return {
		Changed = chargeApplied > 0 or levelsGained > 0,
		FocusId = focusId,
		ChargeApplied = chargeApplied,
		LevelsGained = levelsGained,
		Level = level,
		Charge = carriedCharge,
		RequiredCharge = RuneFocusConfig.getRequiredCharge(focusId, level) or 0,
		CapacityBonusGained = if focus.BonusKind == "Capacity" then focus.BonusPerLevel * levelsGained else 0,
	}
end

function RuneFocusProgress.grantOfflineCharge(profile, focusId, requestedCharge)
	local focus = RuneFocusConfig.getFocus(focusId)
	local amount = getSafeInteger(requestedCharge, ProfileContract.MaximumExactInteger)
	if focus == nil or amount <= 0 or not RuneFocusConfig.canUseFocus(profile.UnlockedZones, profile.Rebirths) then
		return { Changed = false, ChargeApplied = 0, LevelsGained = 0, Source = "offline" }
	end

	local runeFocus = ensureRuneFocus(profile)
	local level = runeFocus.Levels[focusId]
	local currentCharge = runeFocus.Charge[focusId]
	if level >= focus.MaxLevel then
		return { Changed = false, FocusId = focusId, ChargeApplied = 0, LevelsGained = 0, Level = level, Charge = 0, Source = "offline" }
	end
	local acceptedCharge = math.min(amount, ProfileContract.MaximumExactInteger - currentCharge)
	local carriedCharge = currentCharge + acceptedCharge
	local levelsGained = 0
	local consumedCharge = 0
	while level < focus.MaxLevel do
		local requirement = RuneFocusConfig.getRequiredCharge(focusId, level)
		if requirement == nil or requirement <= 0 or carriedCharge < requirement then break end
		carriedCharge -= requirement
		consumedCharge += requirement
		level += 1
		levelsGained += 1
	end
	if level >= focus.MaxLevel then carriedCharge = 0 end
	local chargeApplied = math.clamp(consumedCharge + carriedCharge - currentCharge, 0, acceptedCharge)
	runeFocus.Levels[focusId] = level
	runeFocus.Charge[focusId] = carriedCharge
	local pending = getFeedbackState(profile).PendingChargeByFocus[focusId]
	if pending == nil then pending = { ChargeApplied = 0 }; getFeedbackState(profile).PendingChargeByFocus[focusId] = pending end
	pending.ChargeApplied = math.min(ProfileContract.MaximumExactInteger, pending.ChargeApplied + chargeApplied)
	pending.Level = level
	pending.Charge = carriedCharge
	pending.RequiredCharge = RuneFocusConfig.getRequiredCharge(focusId, level) or 0
	if levelsGained > 0 then
		PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.RuneLevelUp, { FocusId = focusId, LevelsGained = levelsGained, Level = level })
	end
	return { Changed = chargeApplied > 0 or levelsGained > 0, FocusId = focusId, ChargeApplied = chargeApplied, LevelsGained = levelsGained, Level = level, Charge = carriedCharge, Source = "offline" }
end

function RuneFocusProgress.queueCapacityFull(profile, canContinueForRune, pauseReason)
	PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.CapacityFull, {
		CanContinueForRune = canContinueForRune == true,
		PauseReason = pauseReason,
	})
end

function RuneFocusProgress.hasReadyFeedback(profile, now)
	if PlayerFeedbackQueue.hasReady(profile) then
		return true
	end

	local state = chargeFeedbackStateByProfile[profile]

	if state == nil then
		return false
	end

	if next(state.PendingChargeByFocus) == nil then
		return false
	end

	local currentTime = if typeof(now) == "number" then now else os.clock()

	return state.LastChargePublishedAt == nil
		or currentTime - state.LastChargePublishedAt >= PresentationEventConfig.ChargeBatchSeconds
end

function RuneFocusProgress.drainFeedback(profile, now, maximumRecords)
	local state = chargeFeedbackStateByProfile[profile]

	if state ~= nil then
		local currentTime = if typeof(now) == "number" then now else os.clock()
		local canPublishCharge = state.LastChargePublishedAt == nil
			or currentTime - state.LastChargePublishedAt >= PresentationEventConfig.ChargeBatchSeconds

		if canPublishCharge then
			local publishedCharge = false

			for _, focusId in ipairs(RuneFocusConfig.FocusOrder) do
				local pending = state.PendingChargeByFocus[focusId]

				if pending ~= nil and pending.ChargeApplied > 0 then
					local record = PlayerFeedbackQueue.queue(
						profile,
						PresentationEventConfig.EventIds.RuneCharge,
						{
							FocusId = focusId,
							ChargeApplied = pending.ChargeApplied,
							Level = pending.Level,
							Charge = pending.Charge,
							RequiredCharge = pending.RequiredCharge,
						}
					)

					if record ~= nil then
						state.PendingChargeByFocus[focusId] = nil
						publishedCharge = true
					end
				end
			end

			if publishedCharge then
				state.LastChargePublishedAt = currentTime
			end
		end
	end

	return PlayerFeedbackQueue.drain(profile, maximumRecords)
end

function RuneFocusProgress.clearChargeFeedback(profile)
	chargeFeedbackStateByProfile[profile] = nil
end

function RuneFocusProgress.clearFeedback(profile)
	RuneFocusProgress.clearChargeFeedback(profile)
	PlayerFeedbackQueue.clear(profile)
end

return RuneFocusProgress
