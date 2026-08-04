local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local Network = require(Shared:WaitForChild("Net"):WaitForChild("Network"))
local PresentationEventConfig = require(Config:WaitForChild("PresentationEventConfig"))

local ClientStateStore = {}

local INITIAL_SNAPSHOT_RETRY_SECONDS = 1
local RESYNC_COOLDOWN_SECONDS = 1
local MAX_FORCED_RESYNC_ATTEMPTS = 2
local SNAPSHOT_SCHEMA_VERSION = 1
local RUNE_FOCUS_REFRESH_EPSILON_SECONDS = 0.15
local SNAPSHOT_SECTION_KEYS = {
	ProgressionEpoch = true,
	ServerNowUnix = true,
	Essence = true,
	RitualGems = true,
	Rolls = true,
	BestRitualPower = true,
	HighestCapacity = true,
	RarestPetId = true,
	RarestPetScore = true,
	CurrentZone = true,
	Zones = true,
	StoneLevels = true,
	StoneStats = true,
	NextUpgradeCosts = true,
	Rebirth = true,
	Ascension = true,
	Automation = true,
	RuneFocus = true,
	Roll = true,
	RitualRush = true,
	DailyRewards = true,
	AwayRewards = true,
	Onboarding = true,
	Social = true,
	ActiveBoosts = true,
	Potions = true,
	Crystal = true,
	Pets = true,
	EquippedPetIds = true,
	EquippedPets = true,
	MaxEquippedPets = true,
	RitualPower = true,

	-- Transitional snapshot aliases remain accepted until every publisher removes them.
	RebirthRequirement = true,
	Rebirths = true,
	Ascensions = true,
	AscensionStars = true,
	AscensionUpgrades = true,
	RuneUnlock = true,
	Runes = true,
	Tutorial = true,
}
local CRYSTAL_STATE_KEYS = {
	Essence = true,
	RitualGems = true,
	CurrentZone = true,
	Zones = true,
	RebirthRequirement = true,
	Rebirth = true,
	StoneStats = true,
	StoneLevels = true,
	NextUpgradeCosts = true,
	RuneFocus = true,
	RuneUnlock = true,
	Runes = true,
	Ascensions = true,
	AscensionStars = true,
	AscensionUpgrades = true,
	Ascension = true,
	Automation = true,
	RitualRush = true,
	Onboarding = true,
	Tutorial = true,
	ActiveBoosts = true,
	Potions = true,
	Crystal = true,
	Roll = true,
	RitualPower = true,
}
local CRYSTAL_UPDATE_KEYS = {
	SchemaVersion = true,
	Revision = true,
	Feedback = true,
}
local PLAYER_STATE_UPDATE_KEYS = {
	SchemaVersion = true,
	Revision = true,
	Sections = true,
	Feedback = true,
}

for key in pairs(CRYSTAL_STATE_KEYS) do
	CRYSTAL_UPDATE_KEYS[key] = true
end

local listeners = {}
local feedbackListeners = {}
local feedbackQueue = {}
local rememberedFeedbackKeys = {}
local rememberedFeedbackOrder = {}
local feedbackExpiryThreads = {}
local lastFeedbackSequence = 0
local snapshot = nil
local snapshotRevision = -1
local hasStarted = false
local isRequestingSnapshot = false
local isResyncScheduled = false
local pendingResyncAttempt = nil
local lastResyncRequestAt = -math.huge
local runeFocusRefreshThread = nil
local scheduledRuneFocusId = nil

local requestSnapshotRemote = nil
local requestActionRemote = nil
local requestServerSnapshot = nil
local requestBoundedResync = nil
local schedulePendingResync = nil

local function shallowCopy(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function notify()
	for listener in pairs(listeners) do
		listener(snapshot)
	end
end

local function cloneArray(source)
	local copy = {}

	for index, value in ipairs(source or {}) do
		copy[index] = value
	end

	return copy
end

local function notifyFeedback()
	local queueSnapshot = cloneArray(feedbackQueue)

	for listener in pairs(feedbackListeners) do
		listener(queueSnapshot)
	end
end

local function rememberFeedbackKey(dedupeKey)
	if rememberedFeedbackKeys[dedupeKey] == true then
		return false
	end

	rememberedFeedbackKeys[dedupeKey] = true
	table.insert(rememberedFeedbackOrder, dedupeKey)

	while #rememberedFeedbackOrder > PresentationEventConfig.MaxRememberedDedupeKeys do
		local expiredKey = table.remove(rememberedFeedbackOrder, 1)
		rememberedFeedbackKeys[expiredKey] = nil
	end

	return true
end

local function cancelDelayedThread(thread)
	if typeof(thread) == "thread" then
		pcall(task.cancel, thread)
	end
end

local function removeFeedbackAt(index, cancelExpiry)
	local record = table.remove(feedbackQueue, index)

	if record == nil then
		return nil
	end

	local expiryThread = feedbackExpiryThreads[record.DedupeKey]
	feedbackExpiryThreads[record.DedupeKey] = nil

	if cancelExpiry then
		cancelDelayedThread(expiryThread)
	end

	return record
end

local function expireFeedback(dedupeKey, expectedThread)
	if feedbackExpiryThreads[dedupeKey] ~= expectedThread then
		return
	end

	feedbackExpiryThreads[dedupeKey] = nil

	for index, record in ipairs(feedbackQueue) do
		if record.DedupeKey == dedupeKey then
			table.remove(feedbackQueue, index)
			notifyFeedback()
			return
		end
	end
end

local function insertVisibleFeedback(record)
	if #feedbackQueue >= PresentationEventConfig.MaxClientToasts then
		local newPriority = PresentationEventConfig.getClientPriority(record.EventId)
		local lowestPriority = math.huge
		local replacementIndex = nil

		for index, queuedRecord in ipairs(feedbackQueue) do
			local priority = PresentationEventConfig.getClientPriority(queuedRecord.EventId)

			if priority < lowestPriority then
				lowestPriority = priority
				replacementIndex = index
			end
		end

		if replacementIndex == nil or newPriority < lowestPriority then
			return false
		end

		removeFeedbackAt(replacementIndex, true)
	end

	table.insert(feedbackQueue, record)

	local expiryThread = nil
	expiryThread = task.delay(PresentationEventConfig.getClientDurationSeconds(record.EventId), function()
		expireFeedback(record.DedupeKey, expiryThread)
	end)
	feedbackExpiryThreads[record.DedupeKey] = expiryThread

	return true
end

local function applyFeedback(records)
	local changed = false
	local sanitized = PresentationEventConfig.sanitizeRecords(records)

	table.sort(sanitized, function(first, second)
		return first.Sequence < second.Sequence
	end)

	for _, record in ipairs(sanitized) do
		if record.Sequence > lastFeedbackSequence then
			lastFeedbackSequence = record.Sequence

			if rememberFeedbackKey(record.DedupeKey) then
				changed = insertVisibleFeedback(record) or changed
			end
		end
	end

	if changed then
		notifyFeedback()
	end
end

local function isValidRevision(value)
	return typeof(value) == "number"
		and value == value
		and math.abs(value) ~= math.huge
		and value == math.floor(value)
		and value >= 0
end

local function hasUnknownKey(source, allowlist)
	for key in pairs(source) do
		if allowlist[key] ~= true then
			return true
		end
	end

	return false
end

local function hasAuthoritativeCrystalState(update)
	for key in pairs(update) do
		if CRYSTAL_STATE_KEYS[key] == true then
			return true
		end
	end

	return false
end

local function cancelRuneFocusRefresh(clearScheduledId)
	cancelDelayedThread(runeFocusRefreshThread)
	runeFocusRefreshThread = nil

	if clearScheduledId then
		scheduledRuneFocusId = nil
	end
end

local function scheduleRuneFocusRefresh(nextSnapshot)
	local runeFocus = if typeof(nextSnapshot.RuneFocus) == "table" then nextSnapshot.RuneFocus else nil
	local retryAfter = if runeFocus ~= nil then runeFocus.SelectionRetryAfter else nil

	if
		runeFocus == nil
		or typeof(retryAfter) ~= "number"
		or retryAfter ~= retryAfter
		or math.abs(retryAfter) == math.huge
		or retryAfter <= 0
	then
		cancelRuneFocusRefresh(true)
		return
	end

	local focusId = if typeof(runeFocus.ActiveId) == "string" then runeFocus.ActiveId else ""

	if scheduledRuneFocusId == focusId then
		return
	end

	cancelRuneFocusRefresh(true)
	scheduledRuneFocusId = focusId
	runeFocusRefreshThread = task.delay(retryAfter + RUNE_FOCUS_REFRESH_EPSILON_SECONDS, function()
		runeFocusRefreshThread = nil
		scheduledRuneFocusId = nil

		if hasStarted and requestServerSnapshot ~= nil then
			requestServerSnapshot(true)
		end
	end)
end

local function setSnapshot(nextSnapshot)
	if typeof(nextSnapshot) ~= "table" or nextSnapshot.SchemaVersion ~= SNAPSHOT_SCHEMA_VERSION then
		return false
	end

	local nextRevision = nextSnapshot.Revision

	if not isValidRevision(nextRevision) or nextRevision < snapshotRevision then
		return false
	end

	snapshotRevision = nextRevision
	snapshot = nextSnapshot
	scheduleRuneFocusRefresh(nextSnapshot)
	notify()

	return true
end

local function applyCrystalUpdate(update)
	if typeof(update) ~= "table" then
		return
	end

	-- Presentation records use their own sequence and must survive equal-revision replays.
	applyFeedback(update.Feedback)

	if update.SchemaVersion ~= SNAPSHOT_SCHEMA_VERSION then
		if requestBoundedResync ~= nil then
			requestBoundedResync()
		end

		return
	end

	if hasUnknownKey(update, CRYSTAL_UPDATE_KEYS) then
		if requestBoundedResync ~= nil then
			requestBoundedResync()
		end

		return
	end

	local nextRevision = update.Revision

	if not hasAuthoritativeCrystalState(update) then
		if not isValidRevision(nextRevision) then
			if requestBoundedResync ~= nil then
				requestBoundedResync()
			end

			return
		end

		if snapshot == nil then
			if requestServerSnapshot ~= nil then
				requestServerSnapshot(false)
			end

			return
		end

		if nextRevision > snapshotRevision and requestServerSnapshot ~= nil then
			requestBoundedResync()
		end

		return
	end

	if snapshot == nil then
		if requestServerSnapshot ~= nil then
			requestServerSnapshot(false)
		end

		return
	end

	if not isValidRevision(nextRevision) or nextRevision <= snapshotRevision then
		return
	end

	if nextRevision > snapshotRevision + 1 then
		if requestBoundedResync ~= nil then
			requestBoundedResync()
		end

		return
	end

	local nextSnapshot = shallowCopy(snapshot)

	nextSnapshot.Revision = nextRevision

	for key in pairs(CRYSTAL_STATE_KEYS) do
		if update[key] ~= nil then
			nextSnapshot[key] = update[key]
		end
	end

	setSnapshot(nextSnapshot)
end

local function applyPlayerStateUpdate(update)
	if typeof(update) ~= "table" then
		return
	end

	-- Feedback is sequenced independently from snapshot revisions.
	applyFeedback(update.Feedback)

	if update.SchemaVersion ~= SNAPSHOT_SCHEMA_VERSION or hasUnknownKey(update, PLAYER_STATE_UPDATE_KEYS) then
		if requestBoundedResync ~= nil then
			requestBoundedResync()
		end

		return
	end

	local nextRevision = update.Revision
	local sections = update.Sections

	if not isValidRevision(nextRevision) or typeof(sections) ~= "table" then
		if requestBoundedResync ~= nil then
			requestBoundedResync()
		end

		return
	end

	if snapshot == nil then
		if requestServerSnapshot ~= nil then
			requestServerSnapshot(false)
		end

		return
	end

	if nextRevision <= snapshotRevision then
		return
	end

	if nextRevision > snapshotRevision + 1 then
		if requestBoundedResync ~= nil then
			requestBoundedResync()
		end

		return
	end

	local nextSnapshot = shallowCopy(snapshot)
	local hasKnownSection = false
	local hasUnknownSection = false

	for key, value in pairs(sections) do
		if SNAPSHOT_SECTION_KEYS[key] == true then
			nextSnapshot[key] = value
			hasKnownSection = true
		else
			hasUnknownSection = true
		end
	end

	if hasKnownSection then
		nextSnapshot.Revision = nextRevision
		setSnapshot(nextSnapshot)
	elseif nextRevision > snapshotRevision then
		hasUnknownSection = true
	end

	if hasUnknownSection and requestBoundedResync ~= nil then
		requestBoundedResync()
	end
end

local function applyActionResult(result)
	if typeof(result) == "table" then
		applyFeedback(result.Feedback)
	end

	if typeof(result) == "table" and result.Snapshot ~= nil then
		setSnapshot(result.Snapshot)
	end

	return result
end

local function requestAction(actionName, payload)
	if not hasStarted or requestActionRemote == nil then
		return {
			Ok = false,
			Message = "Client action service is not ready.",
		}
	end

	local ok, result = pcall(function()
		return requestActionRemote:InvokeServer(actionName, payload or {})
	end)

	if not ok then
		return {
			Ok = false,
			Message = "Could not complete action request.",
			Error = result,
		}
	end

	return applyActionResult(result)
end

local function queueResyncAttempt(attempt)
	if not hasStarted then
		return
	end

	-- Collapse repeated signals into one pending request without resetting a retry's
	-- bounded attempt count. A signal received after an attempt starts gets a fresh slot.
	if pendingResyncAttempt == nil then
		pendingResyncAttempt = attempt
	end

	if schedulePendingResync ~= nil then
		schedulePendingResync()
	end
end

requestServerSnapshot = function(force, forcedResyncAttempt)
	if isRequestingSnapshot or not hasStarted or requestSnapshotRemote == nil or (not force and snapshot ~= nil) then
		return
	end

	isRequestingSnapshot = true

	task.spawn(function()
		local requestSucceeded = false

		repeat
			local ok, nextSnapshot = pcall(function()
				return requestSnapshotRemote:InvokeServer()
			end)

			if ok and setSnapshot(nextSnapshot) then
				requestSucceeded = true
				break
			end

			if force then
				break
			end

			task.wait(INITIAL_SNAPSHOT_RETRY_SECONDS)
		until not hasStarted or snapshot ~= nil or requestSnapshotRemote == nil

		isRequestingSnapshot = false

		if
			forcedResyncAttempt ~= nil
			and not requestSucceeded
			and forcedResyncAttempt < MAX_FORCED_RESYNC_ATTEMPTS
		then
			queueResyncAttempt(forcedResyncAttempt + 1)
		elseif schedulePendingResync ~= nil then
			schedulePendingResync()
		end
	end)
end

schedulePendingResync = function()
	if not hasStarted then
		pendingResyncAttempt = nil
		return
	end

	if pendingResyncAttempt == nil or isRequestingSnapshot or isResyncScheduled then
		return
	end

	local waitSeconds = math.max(0, RESYNC_COOLDOWN_SECONDS - (os.clock() - lastResyncRequestAt))
	isResyncScheduled = true

	task.delay(waitSeconds, function()
		isResyncScheduled = false

		if not hasStarted then
			pendingResyncAttempt = nil
			return
		end

		-- Keep the pending attempt intact. The active request's completion drains it.
		if isRequestingSnapshot then
			return
		end

		local attempt = pendingResyncAttempt
		pendingResyncAttempt = nil
		lastResyncRequestAt = os.clock()
		requestServerSnapshot(true, attempt)
	end)
end

requestBoundedResync = function()
	queueResyncAttempt(1)
end

function ClientStateStore.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local crystalStateUpdated = Network.getRemoteEvent(Network.RemoteEvents.CrystalStateUpdated)
	local playerStateUpdated = Network.getRemoteEvent(Network.RemoteEvents.PlayerStateUpdated)
	requestActionRemote = Network.getRemoteFunction(Network.RemoteFunctions.RequestAction)
	requestSnapshotRemote = Network.getRemoteFunction(Network.RemoteFunctions.RequestSnapshot)

	crystalStateUpdated.OnClientEvent:Connect(function(update)
		applyCrystalUpdate(update)
	end)
	playerStateUpdated.OnClientEvent:Connect(function(update)
		applyPlayerStateUpdate(update)
	end)

	requestServerSnapshot(false)
end

function ClientStateStore.getSnapshot()
	return snapshot
end

function ClientStateStore.subscribe(listener)
	listeners[listener] = true

	if snapshot ~= nil then
		listener(snapshot)
	end

	return function()
		listeners[listener] = nil
	end
end

function ClientStateStore.getFeedback()
	return cloneArray(feedbackQueue)
end

function ClientStateStore.subscribeFeedback(listener)
	feedbackListeners[listener] = true
	listener(cloneArray(feedbackQueue))

	return function()
		feedbackListeners[listener] = nil
	end
end

function ClientStateStore.rollPet()
	return requestAction(Network.Actions.RollPet)
end

function ClientStateStore.buyStoneUpgrade(upgradeId)
	return requestAction(Network.Actions.BuyStoneUpgrade, {
		UpgradeId = upgradeId,
	})
end

function ClientStateStore.unlockZone(zoneId)
	return requestAction(Network.Actions.UnlockZone, {
		ZoneId = zoneId,
	})
end

function ClientStateStore.selectZone(zoneId)
	return requestAction(Network.Actions.SelectZone, {
		ZoneId = zoneId,
	})
end

function ClientStateStore.rebirth()
	return requestAction(Network.Actions.Rebirth)
end

function ClientStateStore.ascend()
	return requestAction(Network.Actions.Ascend)
end

function ClientStateStore.buyRune(runeId)
	return requestAction(Network.Actions.BuyRune, {
		RuneId = runeId,
	})
end

function ClientStateStore.selectRuneFocus(focusId)
	return requestAction(Network.Actions.SelectRuneFocus, {
		FocusId = focusId,
	})
end

function ClientStateStore.setAutoCapacity(enabled)
	return requestAction(Network.Actions.SetAutoCapacity, {
		Enabled = enabled,
	})
end

function ClientStateStore.buyAscensionUpgrade(upgradeId)
	return requestAction(Network.Actions.BuyAscensionUpgrade, {
		UpgradeId = upgradeId,
	})
end

function ClientStateStore.completeTutorialStep(stepId, completionMode)
	return requestAction(Network.Actions.CompleteTutorialStep, {
		StepId = stepId,
		CompletionMode = completionMode,
	})
end

function ClientStateStore.claimRitualRushReward(milestoneId, track)
	if track ~= "free" and track ~= "premium" then
		return {
			Ok = false,
			Changed = false,
			Code = "invalid_ritual_rush_track",
			Message = "Choose a valid Ritual Rush reward track.",
		}
	end

	return requestAction(Network.Actions.ClaimRitualRushReward, {
		MilestoneId = milestoneId,
		Track = track,
	})
end

function ClientStateStore.claimRitualRushFreeReward(milestoneId)
	return ClientStateStore.claimRitualRushReward(milestoneId, "free")
end

function ClientStateStore.usePotion(potionId)
	return requestAction(Network.Actions.UsePotion, {
		PotionId = potionId,
	})
end

function ClientStateStore.buyPotionWithGems(potionId)
	return requestAction(Network.Actions.BuyPotionWithGems, {
		PotionId = potionId,
	})
end

return ClientStateStore
