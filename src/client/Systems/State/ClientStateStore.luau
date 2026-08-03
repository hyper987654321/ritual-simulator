local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local Network = require(Shared:WaitForChild("Net"):WaitForChild("Network"))

local ClientStateStore = {}

local INITIAL_SNAPSHOT_RETRY_SECONDS = 1

local listeners = {}
local snapshot = nil
local snapshotRevision = -1
local hasStarted = false
local isRequestingInitialSnapshot = false

local requestSnapshotRemote = nil
local requestActionRemote = nil
local requestInitialSnapshot = nil

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

local function setSnapshot(nextSnapshot)
	if nextSnapshot == nil then
		return
	end

	local nextRevision = nextSnapshot.Revision

	if typeof(nextRevision) == "number" then
		if nextRevision < snapshotRevision then
			return
		end

		snapshotRevision = nextRevision
	end

	snapshot = nextSnapshot
	notify()
end

local function applyCrystalUpdate(update)
	if update == nil then
		return
	end

	if snapshot == nil then
		if requestInitialSnapshot ~= nil then
			requestInitialSnapshot()
		end

		return
	end

	local nextRevision = update.Revision

	if typeof(nextRevision) == "number" then
		if nextRevision < snapshotRevision then
			return
		end

		snapshotRevision = nextRevision
	end

	local nextSnapshot = shallowCopy(snapshot)

	if typeof(nextRevision) == "number" then
		nextSnapshot.Revision = nextRevision
	end

	if update.Essence ~= nil then
		nextSnapshot.Essence = update.Essence
	end

	if update.RitualGems ~= nil then
		nextSnapshot.RitualGems = update.RitualGems
	end

	if update.CurrentZone ~= nil then
		nextSnapshot.CurrentZone = update.CurrentZone
	end

	if update.Zones ~= nil then
		nextSnapshot.Zones = update.Zones
	end

	if update.RebirthRequirement ~= nil then
		nextSnapshot.RebirthRequirement = update.RebirthRequirement
	end

	if update.StoneStats ~= nil then
		nextSnapshot.StoneStats = update.StoneStats
	end

	if update.StoneLevels ~= nil then
		nextSnapshot.StoneLevels = update.StoneLevels
	end

	if update.Ascensions ~= nil then
		nextSnapshot.Ascensions = update.Ascensions
	end

	if update.AscensionStars ~= nil then
		nextSnapshot.AscensionStars = update.AscensionStars
	end

	if update.Ascension ~= nil then
		nextSnapshot.Ascension = update.Ascension
	end

	if update.RitualRush ~= nil then
		nextSnapshot.RitualRush = update.RitualRush
	end

	if update.ActiveBoosts ~= nil then
		nextSnapshot.ActiveBoosts = update.ActiveBoosts
	end

	if update.Potions ~= nil then
		nextSnapshot.Potions = update.Potions
	end

	if update.Crystal ~= nil then
		nextSnapshot.Crystal = update.Crystal
	end

	if update.Roll ~= nil then
		nextSnapshot.Roll = update.Roll
	end

	if update.RitualPower ~= nil then
		nextSnapshot.RitualPower = update.RitualPower
	end

	setSnapshot(nextSnapshot)
end

local function applyActionResult(result)
	if result ~= nil and result.Snapshot ~= nil then
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

requestInitialSnapshot = function()
	if isRequestingInitialSnapshot or not hasStarted or requestSnapshotRemote == nil or snapshot ~= nil then
		return
	end

	isRequestingInitialSnapshot = true

	task.spawn(function()
		while hasStarted and snapshot == nil and requestSnapshotRemote ~= nil do
			local ok, nextSnapshot = pcall(function()
				return requestSnapshotRemote:InvokeServer()
			end)

			if ok and nextSnapshot ~= nil then
				setSnapshot(nextSnapshot)
				break
			end

			task.wait(INITIAL_SNAPSHOT_RETRY_SECONDS)
		end

		isRequestingInitialSnapshot = false
	end)
end

function ClientStateStore.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local crystalStateUpdated = Network.getRemoteEvent(Network.RemoteEvents.CrystalStateUpdated)
	requestActionRemote = Network.getRemoteFunction(Network.RemoteFunctions.RequestAction)
	requestSnapshotRemote = Network.getRemoteFunction(Network.RemoteFunctions.RequestSnapshot)

	crystalStateUpdated.OnClientEvent:Connect(function(update)
		applyCrystalUpdate(update)
	end)

	requestInitialSnapshot()
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

function ClientStateStore.completeTutorialStep(stepId, completionMode)
	return requestAction(Network.Actions.CompleteTutorialStep, {
		StepId = stepId,
		CompletionMode = completionMode,
	})
end

function ClientStateStore.claimRitualRushReward(milestoneId)
	return requestAction(Network.Actions.ClaimRitualRushReward, {
		MilestoneId = milestoneId,
	})
end

function ClientStateStore.claimRitualRushFreeReward(milestoneId)
	return ClientStateStore.claimRitualRushReward(milestoneId)
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
