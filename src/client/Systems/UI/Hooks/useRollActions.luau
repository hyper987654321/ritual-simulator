local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))

local Systems = script.Parent.Parent.Parent
local ClientStateStore = require(Systems:WaitForChild("State"):WaitForChild("ClientStateStore"))

local AUTO_ROLL_NEXT_ROLL_DELAY_SECONDS = 0.2
local AUTO_ROLL_RETRY_DELAY_SECONDS = 0.25
local AUTO_ROLL_MAX_BACKOFF_DELAY_SECONDS = 8
local AUTO_ROLL_MAX_SERVER_RETRY_SECONDS = 30
local AUTO_ROLL_MAX_BACKOFF_STEP = 5
local ROLL_ROULETTE_LAND_OFFSET_MIN = 12
local ROLL_ROULETTE_LAND_OFFSET_MAX = 46
local ROLL_ROULETTE_SETTLE_SECONDS = 0.22

local rollVisualRandom = Random.new()
local player = Players.LocalPlayer

local TERMINAL_SESSION_CODES = {
	profile_not_ready = true,
	profile_session_inactive = true,
	profile_session_ended = true,
	session_inactive = true,
}

local function mergeTable(baseTable, extraTable)
	local result = {}

	for key, value in pairs(baseTable or {}) do
		result[key] = value
	end

	for key, value in pairs(extraTable or {}) do
		result[key] = value
	end

	return result
end

local function lerpNumber(startValue, endValue, alpha)
	return startValue + (endValue - startValue) * alpha
end

local function easeOutCubic(alpha)
	local resolvedAlpha = math.clamp(alpha or 1, 0, 1)

	return 1 - ((1 - resolvedAlpha) ^ 3)
end

local function easeOutQuint(alpha)
	local resolvedAlpha = math.clamp(alpha or 1, 0, 1)

	return 1 - ((1 - resolvedAlpha) ^ 5)
end

local function getFiniteNonNegativeNumber(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge or value < 0 then
		return nil
	end

	return value
end

local function getRollRetryDelay(result, failureCount)
	local backoffStep = math.clamp(math.floor((failureCount or 1) - 1), 0, AUTO_ROLL_MAX_BACKOFF_STEP)
	local retryDelay = math.min(
		AUTO_ROLL_MAX_BACKOFF_DELAY_SECONDS,
		AUTO_ROLL_RETRY_DELAY_SECONDS * (2 ^ backoffStep)
	)

	if typeof(result) == "table" then
		local serverRetryAfter = getFiniteNonNegativeNumber(result.RetryAfter)

		if serverRetryAfter == nil and typeof(result.Roll) == "table" then
			serverRetryAfter = getFiniteNonNegativeNumber(result.Roll.RetryAfter)
		end

		if serverRetryAfter ~= nil then
			retryDelay = math.max(retryDelay, math.min(serverRetryAfter, AUTO_ROLL_MAX_SERVER_RETRY_SECONDS))
		end
	end

	return retryDelay
end

local function isTerminalSessionResult(result)
	if typeof(result) ~= "table" then
		return false
	end

	local code = if typeof(result.Code) == "string" then result.Code else result.Reason

	return typeof(code) == "string" and TERMINAL_SESSION_CODES[code] == true
end

local function useRollActions(options)
	local resolvedOptions = options or {}
	local autoRollEnabled, setAutoRollEnabledState = React.useState(false)
	local rollAnimation, setRollAnimationState = React.useState(nil)
	local activeRollAnimationTokenRef = React.useRef(0)
	local activeAutoRollSessionTokenRef = React.useRef(0)
	local isMountedRef = React.useRef(true)
	local progressionEpoch = resolvedOptions.ProgressionEpoch
	local progressionEpochRef = React.useRef(progressionEpoch)

	local getSnapshot = resolvedOptions.GetSnapshot or ClientStateStore.getSnapshot
	local rollPet = resolvedOptions.RollPet or ClientStateStore.rollPet
	local getRollPreviewData = resolvedOptions.GetRollPreviewData
	local getRollAnimationDurationScale = resolvedOptions.GetRollAnimationDurationScale
	local buildRollRouletteTrack = resolvedOptions.BuildRollRouletteTrack
	local getRollRouletteTargetOffset = resolvedOptions.GetRollRouletteTargetOffset
	local getRollOpeningDurationFromScale = resolvedOptions.GetRollOpeningDurationFromScale

	local function setStateIfMounted(setter, value)
		if isMountedRef.current then
			setter(value)
		end
	end

	local function cancelActiveWork()
		activeRollAnimationTokenRef.current += 1
		activeAutoRollSessionTokenRef.current += 1
	end

	local function terminateRollSession()
		cancelActiveWork()
		setStateIfMounted(setRollAnimationState, nil)
		setStateIfMounted(setAutoRollEnabledState, false)
	end

	local function isCurrentRollAnimation(token)
		return isMountedRef.current and player.Parent ~= nil and activeRollAnimationTokenRef.current == token
	end

	local function setRollAnimationForToken(token, updater)
		if not isMountedRef.current then
			return
		end

		setRollAnimationState(function(current)
			if current == nil or current.Token ~= token then
				return current
			end

			return updater(current)
		end)
	end

	local function startRollAnimation()
		activeRollAnimationTokenRef.current += 1

		local token = activeRollAnimationTokenRef.current
		local currentSnapshot = getSnapshot()
		local previewData = if getRollPreviewData ~= nil then getRollPreviewData(currentSnapshot) else { Entries = {} }
		local durationScale = if getRollAnimationDurationScale ~= nil then getRollAnimationDurationScale(currentSnapshot) else 1

		setStateIfMounted(setRollAnimationState, {
			Token = token,
			Phase = "Rolling",
			Sequence = previewData.Entries,
			Index = 1,
			Step = 1,
			DelayScale = durationScale,
		})

		return token, durationScale
	end

	local function playRollAnimation(token, result, durationScale)
		local resolvedDurationScale = durationScale or 1
		local currentSnapshot = getSnapshot()
		local previewData = if getRollPreviewData ~= nil then getRollPreviewData(currentSnapshot) else { Entries = {} }
		local track, targetIndex = buildRollRouletteTrack(previewData.Entries, result.Pet)
		local targetOffset = getRollRouletteTargetOffset(targetIndex)
		local duration = getRollOpeningDurationFromScale(resolvedDurationScale)
		local settleDuration = math.min(ROLL_ROULETTE_SETTLE_SECONDS, duration * 0.3)
		local spinDuration = math.max(0.05, duration - settleDuration)
		local landingDirection = if rollVisualRandom:NextNumber() < 0.5 then -1 else 1
		local landingDistance = rollVisualRandom:NextNumber(ROLL_ROULETTE_LAND_OFFSET_MIN, ROLL_ROULETTE_LAND_OFFSET_MAX)
		local landingOffset = targetOffset + landingDirection * landingDistance
		local startedAt = os.clock()

		setRollAnimationForToken(token, function(current)
			return mergeTable(current, {
				Track = track,
				TargetIndex = targetIndex,
				TrackOffset = 0,
			})
		end)

		while isCurrentRollAnimation(token) do
			local elapsed = os.clock() - startedAt
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local trackOffset = targetOffset
			local step = RitualStoneConfig.RollOpening.FlashSteps

			if elapsed < spinDuration then
				local spinAlpha = math.clamp(elapsed / spinDuration, 0, 1)
				local easedSpinAlpha = easeOutQuint(spinAlpha)
				local spinWobble = math.sin(spinAlpha * math.pi * 9) * (1 - spinAlpha) * 7

				trackOffset = landingOffset * easedSpinAlpha + spinWobble
				step = math.max(1, math.floor(spinAlpha * RitualStoneConfig.RollOpening.FlashSteps * 0.9))
			elseif settleDuration > 0 then
				local settleAlpha = math.clamp((elapsed - spinDuration) / settleDuration, 0, 1)
				local easedSettleAlpha = easeOutCubic(settleAlpha)
				local settleWobble = math.sin(settleAlpha * math.pi * 2) * (1 - settleAlpha) * 2

				trackOffset = lerpNumber(landingOffset, targetOffset, easedSettleAlpha) + settleWobble
				step = math.max(1, math.floor((0.9 + settleAlpha * 0.1) * RitualStoneConfig.RollOpening.FlashSteps))
			end

			setRollAnimationForToken(token, function(current)
				if current.Phase ~= "Rolling" then
					return current
				end

				return mergeTable(current, {
					TrackOffset = trackOffset,
					Step = step,
				})
			end)

			if alpha >= 1 then
				break
			end

			RunService.Heartbeat:Wait()
		end

		if not isCurrentRollAnimation(token) then
			return
		end

		setRollAnimationForToken(token, function(current)
			return mergeTable(current, {
				Phase = "Reveal",
				Pet = result.Pet,
				ResultInfo = track[targetIndex],
				Track = track,
				TargetIndex = targetIndex,
				TrackOffset = targetOffset,
				Step = RitualStoneConfig.RollOpening.FlashSteps,
			})
		end)

		task.delay(RitualStoneConfig.RollOpening.PetRevealSeconds, function()
			if isCurrentRollAnimation(token) then
				setRollAnimationForToken(token, function()
					return nil
				end)
			end
		end)
	end

	local function requestRoll(shouldContinue)
		local requestEpoch = progressionEpochRef.current
		local ok, result = pcall(rollPet)

		if not ok then
			warn(result)

			return {
				Ok = false,
				Code = "client_roll_request_failed",
			}
		end

		if shouldContinue ~= nil and not shouldContinue() then
			return result
		end

		if isTerminalSessionResult(result) or player.Parent == nil then
			terminateRollSession()
			return result
		end

		local latestSnapshot = getSnapshot()
		local latestEpoch = if typeof(latestSnapshot) == "table" then latestSnapshot.ProgressionEpoch else nil

		if typeof(requestEpoch) == "number" and typeof(latestEpoch) == "number" and latestEpoch ~= requestEpoch then
			progressionEpochRef.current = latestEpoch
			terminateRollSession()
			return result
		end

		if typeof(result) ~= "table" or result.Pet == nil then
			return result
		end

		local token, durationScale = startRollAnimation()
		playRollAnimation(token, result, durationScale)

		return result
	end

	React.useEffect(function()
		isMountedRef.current = true

		return function()
			isMountedRef.current = false
			cancelActiveWork()
		end
	end, {})

	React.useEffect(function()
		local previousEpoch = progressionEpochRef.current
		progressionEpochRef.current = progressionEpoch

		if
			typeof(previousEpoch) == "number"
			and typeof(progressionEpoch) == "number"
			and progressionEpoch ~= previousEpoch
		then
			terminateRollSession()
		end
	end, { progressionEpoch })

	React.useEffect(function()
		if not autoRollEnabled then
			return
		end

		local cancelled = false
		activeAutoRollSessionTokenRef.current += 1

		local sessionToken = activeAutoRollSessionTokenRef.current
		local sessionEpoch = progressionEpochRef.current
		local function isCurrentAutoSession()
			return isMountedRef.current
				and player.Parent ~= nil
				and not cancelled
				and activeAutoRollSessionTokenRef.current == sessionToken
				and progressionEpochRef.current == sessionEpoch
		end

		task.spawn(function()
			local failureCount = 0

			while isCurrentAutoSession() do
				local result = requestRoll(isCurrentAutoSession)

				if not isCurrentAutoSession() then
					break
				end

				if typeof(result) == "table" and result.Pet ~= nil then
					failureCount = 0
					task.wait(RitualStoneConfig.RollOpening.PetRevealSeconds + AUTO_ROLL_NEXT_ROLL_DELAY_SECONDS)
				else
					if isTerminalSessionResult(result) then
						terminateRollSession()
						break
					end

					failureCount += 1
					task.wait(getRollRetryDelay(result, failureCount))
				end
			end

			if player.Parent == nil then
				terminateRollSession()
			end
		end)

		return function()
			cancelled = true

			if activeAutoRollSessionTokenRef.current == sessionToken then
				activeAutoRollSessionTokenRef.current += 1
			end
		end
	end, { autoRollEnabled })

	local function toggleAutoRoll()
		setStateIfMounted(setAutoRollEnabledState, function(currentValue)
			return not currentValue
		end)
	end

	return {
		AutoRollEnabled = autoRollEnabled,
		RollAnimation = rollAnimation,
		RollPet = function()
			task.spawn(function()
				requestRoll()
			end)

			return true
		end,
		ToggleAutoRoll = toggleAutoRoll,
	}
end

return useRollActions
