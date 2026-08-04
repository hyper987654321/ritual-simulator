local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MapGen = Shared:WaitForChild("MapGen")

local AscensionConfig = require(Config:WaitForChild("AscensionConfig"))
local BoostConfig = require(Config:WaitForChild("BoostConfig"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local PresentationEventConfig = require(Config:WaitForChild("PresentationEventConfig"))
local PotionConfig = require(Config:WaitForChild("PotionConfig"))
local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local RitualRushConfig = require(Config:WaitForChild("RitualRushConfig"))
local ShopProductConfig = require(Config:WaitForChild("ShopProductConfig"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local RuneFocusConfig = require(Config:WaitForChild("RuneFocusConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local Network = require(Shared:WaitForChild("Net"):WaitForChild("Network"))
local GeneratedMapRuntime = require(MapGen:WaitForChild("GeneratedMapRuntime"))
local LeaderstatsService = require(script.Parent:WaitForChild("LeaderstatsService"))
local ProfilePersistence = require(script.Parent:WaitForChild("ProfilePersistence"))
local PlayerPublicVisualSignal = require(script.Parent:WaitForChild("PlayerPublicVisualSignal"))
local PlayerDerivedState = require(script.Parent:WaitForChild("PlayerDerivedState"))
local PlayerFeedbackQueue = require(script.Parent:WaitForChild("PlayerFeedbackQueue"))
local CrystalCombat = require(script.Parent.Parent:WaitForChild("Ritual"):WaitForChild("CrystalCombat"))
local RuneFocusProgress = require(script.Parent.Parent:WaitForChild("Ritual"):WaitForChild("RuneFocusProgress"))
local RitualRushProgress = require(script.Parent.Parent:WaitForChild("Ritual"):WaitForChild("RitualRushProgress"))
local RitualStoneProgress = require(script.Parent.Parent:WaitForChild("Ritual"):WaitForChild("RitualStoneProgress"))
local DailyRewardProgress = require(script.Parent.Parent:WaitForChild("Retention"):WaitForChild("DailyRewardProgress"))
local AwayRewardProgress = require(script.Parent.Parent:WaitForChild("Retention"):WaitForChild("AwayRewardProgress"))
local OnboardingProgress = require(script.Parent.Parent:WaitForChild("Retention"):WaitForChild("OnboardingProgress"))
local RetentionProgress = require(script.Parent.Parent:WaitForChild("Retention"):WaitForChild("RetentionProgress"))
local PetInventoryProgress = require(script.Parent.Parent:WaitForChild("Pets"):WaitForChild("PetInventoryProgress"))
local LeaderboardService = require(script.Parent.Parent:WaitForChild("Leaderboard"):WaitForChild("LeaderboardService"))

local PlayerStateService = {}

local PROFILE_LOAD_TIMEOUT_SECONDS = ProfileContract.Session.LoadTimeoutSeconds
local PROFILE_SYNC_SECONDS = 60

local profileRecordsByPlayer = {}
local profileLoadTokensByPlayer = {}
local profileOperationQueuesByPlayer = {}
local random = Random.new()
local hasStarted = false
local nextProfileLoadToken = 0
local socialPresenceService = nil

local function cloneValue(value)
	if typeof(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do copy[key] = cloneValue(child) end
	return copy
end

local function recordRetentionEvent(profile, eventId, amount)
	if typeof(profile) == "table" then
		RetentionProgress.recordEvent(profile, eventId, amount or 1, DateTime.now().UnixTimestamp)
	end
end

local function cloneArray(array)
	local clone = {}

	for index, value in ipairs(array) do
		clone[index] = value
	end

	return clone
end

local function createDefaultStoneLevels()
	return {
		Capacity = 0,
		Luck = 0,
		RollSpeed = 0,
	}
end

local function resetRuneFocusForAscension(profile)
	local runeFocus = if typeof(profile.RuneFocus) == "table" then profile.RuneFocus else {}
	local activeId = if RuneFocusConfig.getFocus(runeFocus.ActiveId) ~= nil then runeFocus.ActiveId else nil
	local levels = {}
	local charge = {}

	for _, focusId in ipairs(RuneFocusConfig.FocusOrder) do
		levels[focusId] = 0
		charge[focusId] = 0
	end

	profile.RuneFocus = {
		Version = 1,
		ActiveId = activeId,
		Levels = levels,
		Charge = charge,
	}
end

local function getNonNegativeInteger(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(math.floor(value), 0, ProfileContract.MaximumExactInteger)
end

local function addExactIntegers(left, right)
	local safeLeft = getNonNegativeInteger(left)
	local safeRight = getNonNegativeInteger(right)

	return safeLeft + math.min(safeRight, ProfileContract.MaximumExactInteger - safeLeft)
end

local function getPetCount(profile, petId)
	return getNonNegativeInteger(profile.Pets[petId])
end

local function reconcilePetIds(profile)
	if profile == nil then
		return false
	end

	if typeof(profile.Pets) ~= "table" then
		profile.Pets = {}
	end

	if typeof(profile.EquippedPetIds) ~= "table" then
		profile.EquippedPetIds = {}
	end

	local didChange = false
	local reconciledPets = {}

	for petId, count in pairs(profile.Pets) do
		local safeCount = getNonNegativeInteger(count)

		if safeCount > 0 then
			local canonicalPetId = if typeof(petId) == "string" then PetConfig.getCanonicalPetId(petId) else nil
			local resolvedPetId = canonicalPetId or petId

			reconciledPets[resolvedPetId] = addExactIntegers(reconciledPets[resolvedPetId], safeCount)

			if resolvedPetId ~= petId or safeCount ~= count then
				didChange = true
			end
		else
			didChange = true
		end
	end

	profile.Pets = reconciledPets

	for index, petId in ipairs(profile.EquippedPetIds) do
		local canonicalPetId = if typeof(petId) == "string" then PetConfig.getCanonicalPetId(petId) else nil

		if canonicalPetId ~= nil and canonicalPetId ~= petId then
			profile.EquippedPetIds[index] = canonicalPetId
			didChange = true
		end
	end

	if typeof(profile.RarestPetId) == "string" then
		local canonicalPetId = PetConfig.getCanonicalPetId(profile.RarestPetId)

		if canonicalPetId ~= nil then
			if canonicalPetId ~= profile.RarestPetId then
				profile.RarestPetId = canonicalPetId
				didChange = true
			end

			local rarestPetScore = PetConfig.getRarityScore(canonicalPetId)

			if rarestPetScore ~= (profile.RarestPetScore or 0) then
				profile.RarestPetScore = rarestPetScore
				didChange = true
			end
		end
	end

	return didChange
end

local function sortPetStacksByPower(left, right)
	local leftPower = PetConfig.getPetPower(left.PetId)
	local rightPower = PetConfig.getPetPower(right.PetId)

	if leftPower == rightPower then
		local leftScore = PetConfig.getRarityScore(left.PetId)
		local rightScore = PetConfig.getRarityScore(right.PetId)

		if leftScore == rightScore then
			return left.PetId < right.PetId
		end

		return leftScore > rightScore
	end

	return leftPower > rightPower
end

local function getChangedEquippedSlots(previousEquippedPetIds, nextEquippedPetIds)
	local changedSlots = {}
	local maxSlotCount = math.max(#previousEquippedPetIds, #nextEquippedPetIds)

	for slotId = 1, maxSlotCount do
		if previousEquippedPetIds[slotId] ~= nextEquippedPetIds[slotId] then
			table.insert(changedSlots, slotId)
		end
	end

	return changedSlots
end

local function cloneCounts(counts)
	local clone = {}

	for petId, count in pairs(counts) do
		clone[petId] = count
	end

	return clone
end

local function getFirstOpenSlot(slots)
	for slotId = 1, PetConfig.MAX_EQUIPPED do
		if slots[slotId] == nil then
			return slotId
		end
	end

	return nil
end

local function equipBestPetsForProfile(profile)
	local sortedPets = {}

	for petId, count in pairs(profile.Pets) do
		if count > 0 and PetConfig.getPet(petId) ~= nil then
			table.insert(sortedPets, {
				PetId = petId,
				Count = count,
			})
		end
	end

	table.sort(sortedPets, sortPetStacksByPower)

	local desiredCounts = {}
	local desiredTotal = 0

	for _, petStack in ipairs(sortedPets) do
		for _ = 1, petStack.Count do
			if desiredTotal >= PetConfig.MAX_EQUIPPED then
				break
			end

			desiredCounts[petStack.PetId] = (desiredCounts[petStack.PetId] or 0) + 1
			desiredTotal += 1
		end

		if desiredTotal >= PetConfig.MAX_EQUIPPED then
			break
		end
	end

	local previousEquippedPetIds = cloneArray(profile.EquippedPetIds)
	local remainingCounts = cloneCounts(desiredCounts)
	local nextSlots = {}

	for slotId, petId in ipairs(previousEquippedPetIds) do
		local remainingCount = remainingCounts[petId] or 0

		if remainingCount > 0 and slotId <= PetConfig.MAX_EQUIPPED then
			nextSlots[slotId] = petId
			remainingCounts[petId] = remainingCount - 1
		end
	end

	for _, petStack in ipairs(sortedPets) do
		local remainingCount = remainingCounts[petStack.PetId] or 0

		while remainingCount > 0 do
			local slotId = getFirstOpenSlot(nextSlots)

			if slotId == nil then
				break
			end

			nextSlots[slotId] = petStack.PetId
			remainingCount -= 1
		end

		remainingCounts[petStack.PetId] = remainingCount
	end

	local nextEquippedPetIds = {}

	for slotId = 1, PetConfig.MAX_EQUIPPED do
		if nextSlots[slotId] ~= nil then
			table.insert(nextEquippedPetIds, nextSlots[slotId])
		end
	end

	profile.EquippedPetIds = nextEquippedPetIds

	return getChangedEquippedSlots(previousEquippedPetIds, nextEquippedPetIds)
end

local function getRarestPet(profile)
	local rarestPetId = nil
	local rarestScore = 0

	for petId, count in pairs(profile.Pets) do
		local score = if count > 0 then PetConfig.getRarityScore(petId) else 0

		if score > rarestScore then
			rarestPetId = petId
			rarestScore = score
		end
	end

	return rarestPetId, rarestScore
end

local function updateProgressRecords(profile, stats, ritualPower)
	local rarestPetId, rarestPetScore = getRarestPet(profile)

	profile.BestRitualPower = math.max(getNonNegativeInteger(profile.BestRitualPower), getNonNegativeInteger(ritualPower))
	profile.HighestCapacity = math.max(getNonNegativeInteger(profile.HighestCapacity), getNonNegativeInteger(stats.Capacity))

	if rarestPetScore > getNonNegativeInteger(profile.RarestPetScore) then
		profile.RarestPetId = rarestPetId
		profile.RarestPetScore = rarestPetScore
	end
end

local function completeOnboardingMilestone(profile, milestoneId)
	local _, stats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local result = OnboardingProgress.complete(profile, milestoneId, {
		Authoritative = true,
		Capacity = stats.Capacity,
	})

	if result.Changed == true then
		PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.OnboardingMilestoneComplete, {
			MilestoneId = milestoneId,
			Reward = result.Reward,
		})
	end

	return result.Changed == true
end

local function hasPendingAwayClaim(profile)
	return typeof(profile.AwayRewards) == "table" and typeof(profile.AwayRewards.Pending) == "table"
end

local function getAwayContext(profile)
	local runeBonuses, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile, false)
	local ascensionBonuses = AscensionConfig.getStatBonuses(profile)
	local awayCapMinutes = 30
		+ 15 * getNonNegativeInteger(profile.Rebirths)
		+ getNonNegativeInteger(ascensionBonuses.OfflineCapBonusMinutes)

	return {
		ZoneId = profile.CurrentZone,
		UnlockedZones = profile.UnlockedZones,
		EffectiveTeamDamage = equippedPetPower,
		Capacity = stats.Capacity,
		Essence = profile.Essence,
		PersistentEssenceMultiplier = stats.EssenceMultiplier,
		PersistentRuneChargeMultiplier = stats.RebirthRuneChargeMultiplier
			* stats.AscensionRuneChargeMultiplier,
		CapacityStateMultiplier = 1,
		ActiveRuneFocusId = if typeof(profile.RuneFocus) == "table" then profile.RuneFocus.ActiveId else nil,
		AwayCapMinutes = awayCapMinutes,
	}
end

local function refreshAwayCheckpoint(profile, nowUnix)
	local result = AwayRewardProgress.refreshCheckpoint(profile, getAwayContext(profile), nowUnix)

	if result.Offer ~= nil then
		PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.AwayRewardReady, {
			ObservedMinutes = result.Offer.ObservedMinutes,
			EligibleMinutes = result.Offer.EligibleMinutes,
		})
	end

	return result
end

local function replaceAwayCheckpoint(profile, nowUnix)
	local result = AwayRewardProgress.createCheckpoint(getAwayContext(profile), nowUnix)
	if result.Ok == true then
		profile.AwayRewards = if typeof(profile.AwayRewards) == "table" then profile.AwayRewards else { Version = 1, NextSequence = 1 }
		profile.AwayRewards.Checkpoint = result.Checkpoint
	end
	return result
end

local function getZoneUnlockFailureMessage(profile, zoneId, zone)
	local previousZoneId = ZoneConfig.getPreviousZoneId(zoneId)

	if previousZoneId ~= nil and profile.UnlockedZones[previousZoneId] ~= true then
		local previousZone = ZoneConfig.getZone(previousZoneId)
		local previousZoneName = if previousZone ~= nil then previousZone.DisplayName else "the previous zone"

		return "Unlock " .. previousZoneName .. " first."
	end

	if profile.Essence < zone.UnlockCost then
		return "Not enough Ritual Essence."
	end

	return "Zone cannot be unlocked."
end

local function addPet(profile, petId)
	local count = addExactIntegers(getPetCount(profile, petId), 1)

	profile.Pets[petId] = count

	local changedSlots = equipBestPetsForProfile(profile)

	if #changedSlots > 0 then
		CrystalCombat.clearAttackRuntimeForSlots(profile, changedSlots)
	end

	return {
		PetId = petId,
		Count = count,
	}
end

local function queueProgressionReadiness(profile)
	local rebirthRequirement = RitualStoneConfig.getRebirthRequirement(profile.Rebirths)
	local canRebirth = PlayerDerivedState.canRebirth(profile, rebirthRequirement)

	PlayerFeedbackQueue.updateReadiness(
		profile,
		"rebirth",
		canRebirth,
		PresentationEventConfig.EventIds.RebirthReady,
		{
			Rebirths = getNonNegativeInteger(profile.Rebirths),
			RequiredEssence = rebirthRequirement.RequiredEssence,
			RequiredZone = rebirthRequirement.RequiredZone,
		}
	)

	local ascension = PlayerDerivedState.getAscensionSnapshot(profile)

	PlayerFeedbackQueue.updateReadiness(
		profile,
		"ascension",
		ascension.CanAscend == true,
		PresentationEventConfig.EventIds.AscensionReady,
		{
			Ascensions = getNonNegativeInteger(profile.Ascensions),
			RequiredRebirths = ascension.RequiredRebirths,
			RequiredZone = ascension.RequiredZone,
			StarReward = ascension.StarReward,
		}
	)
end

local function commitProgressRecords(profile)
	local _, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local ritualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths)

	updateProgressRecords(profile, stats, ritualPower)
	queueProgressionReadiness(profile)

	return stats, equippedPetPower, ritualPower
end

local function commitProfileForPersistence(profile)
	local didReconcilePets = reconcilePetIds(profile)
	profile.ActiveBoosts = BoostConfig.normalizeActiveBoosts(profile.ActiveBoosts)
	profile.Potions = PotionConfig.normalizeInventory(profile.Potions)
	profile.Essence = getNonNegativeInteger(profile.Essence)
	profile.RitualGems = getNonNegativeInteger(profile.RitualGems)
	profile.Rolls = getNonNegativeInteger(profile.Rolls)
	profile.Rebirths = getNonNegativeInteger(profile.Rebirths)
	profile.Ascensions = math.min(#AscensionConfig.Milestones, getNonNegativeInteger(profile.Ascensions))
	profile.AscensionStars = getNonNegativeInteger(profile.AscensionStars)
	profile.AscensionUpgrades = if typeof(profile.AscensionUpgrades) == "table" then profile.AscensionUpgrades else {}
	local _, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local ritualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths)

	CrystalCombat.ensureState(profile)
	if didReconcilePets then
		CrystalCombat.clearAttackRuntime(profile)
	end
	RitualRushProgress.ensureProgress(profile)
	updateProgressRecords(profile, stats, ritualPower)
	queueProgressionReadiness(profile)

	return stats, equippedPetPower, ritualPower
end

local function isEssenceCapacityFull(profile, stats)
	local capacity = getNonNegativeInteger(if typeof(stats) == "table" then stats.Capacity else 0)
	local essence = getNonNegativeInteger(profile.Essence)

	return essence >= capacity
end

local function didLockedZoneUnlockEligibilityChange(profile, beforeEssence, afterEssence)
	local safeBeforeEssence = getNonNegativeInteger(beforeEssence)
	local safeAfterEssence = getNonNegativeInteger(afterEssence)

	if safeBeforeEssence == safeAfterEssence then
		return false
	end

	local unlockedZones = if typeof(profile.UnlockedZones) == "table" then profile.UnlockedZones else {}

	for _, zoneId in ipairs(ZoneConfig.getZoneIds()) do
		local zone = ZoneConfig.getZone(zoneId)

		if zone ~= nil and unlockedZones[zoneId] ~= true then
			local previousZoneId = ZoneConfig.getPreviousZoneId(zoneId)
			local prerequisiteMet = previousZoneId == nil or unlockedZones[previousZoneId] == true

			if prerequisiteMet then
				local unlockCost = getNonNegativeInteger(zone.UnlockCost)
				local wasEligible = safeBeforeEssence >= unlockCost
				local isEligible = safeAfterEssence >= unlockCost

				if wasEligible ~= isEligible then
					return true
				end
			end
		end
	end

	return false
end

local function queueCapacityFullTransition(profile, wasFull)
	local _, nextStats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local isFull = isEssenceCapacityFull(profile, nextStats)

	if not wasFull and isFull then
		local capacityState, pauseReason = RuneFocusProgress.getCapacityState(profile, nextStats)

		RuneFocusProgress.queueCapacityFull(
			profile,
			capacityState == RuneFocusProgress.CapacityStates.FullCharging,
			pauseReason
		)
	end

	return nextStats
end

local function awardCrystalBreakRush(profile, breakCount, runeLevelsGained)
	local awardedPoints = 0

	if breakCount > 0 then
		awardedPoints = addExactIntegers(awardedPoints, RitualRushProgress.awardPoints(
			profile,
			RitualRushConfig.PointSources.CrystalBroken,
			breakCount
		))
	end

	if runeLevelsGained > 0 then
		awardedPoints = addExactIntegers(awardedPoints, RitualRushProgress.awardPoints(
			profile,
			RitualRushConfig.PointSources.RuneLevel,
			runeLevelsGained
		))
	end

	return awardedPoints
end

local function collectCrystalRewardWithRush(profile, stats)
	local wasFull = isEssenceCapacityFull(profile, stats)
	local breakResult = CrystalCombat.collectFinishedReward(profile, stats)
	local rushPointsAwarded = 0

	if breakResult.Finalized then
		recordRetentionEvent(profile, "online_crystal_break", 1)
		if (breakResult.RuneLevelsGained or 0) > 0 then
			recordRetentionEvent(profile, "stone_or_rune_upgrade", breakResult.RuneLevelsGained)
		end
		rushPointsAwarded = awardCrystalBreakRush(profile, 1, breakResult.RuneLevelsGained or 0)
		queueCapacityFullTransition(profile, wasFull)
	end

	return breakResult.Changed == true or rushPointsAwarded > 0,
		breakResult.EssenceAwarded or 0,
		breakResult.ActualCrystalReward or 0
end

local function syncAndCollectCrystalReward(profile)
	local _, stats = PlayerDerivedState.getCurrentRitualRuntime(profile)

	return collectCrystalRewardWithRush(profile, stats)
end

local function getAvailableEssenceCapacity(profile, stats)
	local capacity = getNonNegativeInteger(if typeof(stats) == "table" then stats.Capacity else 0)
	local essence = getNonNegativeInteger(profile.Essence)

	return math.max(0, capacity - essence)
end

local function getPositiveInteger(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return nil
	end

	local integer = math.floor(value)

	if integer <= 0 or integer ~= value or integer > ProfileContract.MaximumExactInteger then
		return nil
	end

	return integer
end

local function ensureProcessedPurchaseIds(profile)
	if typeof(profile.ProcessedPurchaseIds) ~= "table" then
		profile.ProcessedPurchaseIds = {}
	end

	return profile.ProcessedPurchaseIds
end

local function reconcileActiveBoosts(profile)
	profile.ActiveBoosts = BoostConfig.normalizeActiveBoosts(profile.ActiveBoosts)

	return profile.ActiveBoosts
end

local function areShallowTablesEqual(left, right)
	if typeof(left) ~= "table" or typeof(right) ~= "table" then
		return false
	end

	for key, value in pairs(left) do
		if right[key] ~= value then
			return false
		end
	end

	for key, value in pairs(right) do
		if left[key] ~= value then
			return false
		end
	end

	return true
end

local function reconcilePotions(profile)
	local previousPotions = profile.Potions
	local normalizedPotions = PotionConfig.normalizeInventory(previousPotions)
	local didChange = not areShallowTablesEqual(previousPotions, normalizedPotions)

	profile.Potions = normalizedPotions

	return normalizedPotions, didChange
end

local function applyBoostGrant(profile, boostGrant)
	local didApplyBoost, boostReward, activeBoosts = BoostConfig.applyBoostGrant(profile.ActiveBoosts, boostGrant)

	profile.ActiveBoosts = activeBoosts

	if not didApplyBoost then
		return false, boostReward
	end

	return true, boostReward
end

local function applyPotionGrant(profile, potionGrant)
	local didApplyPotion, potionReward, potions = PotionConfig.addPotionGrant(profile.Potions, potionGrant)

	profile.Potions = potions

	if not didApplyPotion then
		return false, potionReward
	end

	return true, potionReward
end

local function applyShopProductGrant(profile, product)
	if typeof(product) ~= "table" or typeof(product.Grant) ~= "table" then
		return false, "ProductGrantMissing"
	end

	local grant = product.Grant
	local supportedGrantKeys = {
		RitualGems = true,
		RitualRushPremium = true,
		Boost = true,
	}

	for grantKey in pairs(grant) do
		if supportedGrantKeys[grantKey] ~= true then
			return false, "ProductGrantUnsupported"
		end
	end

	local reward = {}
	local didGrant = false
	local stagedRitualGems = nil
	local stagedRitualRush = nil
	local stagedActiveBoosts = nil

	if grant.RitualGems ~= nil then
		local requestedRitualGems = getPositiveInteger(grant.RitualGems)

		if requestedRitualGems == nil then
			return false, "RitualGemGrantInvalid"
		end

		local currentRitualGems = math.clamp(
			getNonNegativeInteger(profile.RitualGems),
			0,
			ProfileContract.MaximumExactInteger
		)
		local ritualGemsGranted = math.min(
			requestedRitualGems,
			ProfileContract.MaximumExactInteger - currentRitualGems
		)

		stagedRitualGems = currentRitualGems + ritualGemsGranted
		reward.RitualGems = ritualGemsGranted
		didGrant = true
	end

	if grant.RitualRushPremium ~= nil then
		if grant.RitualRushPremium ~= true then
			return false, "RitualRushPremiumGrantInvalid"
		end

		stagedRitualRush = RitualRushConfig.reconcileProgress(profile.RitualRush)
		stagedRitualRush.PremiumUnlocked = true
		reward.RitualRushPremium = true
		didGrant = true
	end

	if grant.Boost ~= nil then
		local didApplyBoost, boostReward, nextActiveBoosts = BoostConfig.applyBoostGrant(
			profile.ActiveBoosts,
			grant.Boost
		)

		if not didApplyBoost then
			return false, boostReward
		end

		stagedActiveBoosts = nextActiveBoosts
		reward.Boost = boostReward
		didGrant = true
	end

	if not didGrant then
		return false, "ProductGrantEmpty"
	end

	-- Commit the complete staged grant without yielding. A malformed future
	-- compound product can never leave a partial unmarked purchase behind.
	if stagedRitualGems ~= nil then
		profile.RitualGems = stagedRitualGems
	end

	if stagedRitualRush ~= nil then
		profile.RitualRush = stagedRitualRush
	end

	if stagedActiveBoosts ~= nil then
		profile.ActiveBoosts = stagedActiveBoosts
	end

	return true, reward
end

local function saveProfileForPurchase(player, profile, purchaseId)
	local callSucceeded, saveSucceeded, reason = pcall(function()
		commitProfileForPersistence(profile)

		return ProfilePersistence.saveConfirmed(player, profile, function(savedData)
			return typeof(savedData) == "table"
				and typeof(savedData.ProcessedPurchaseIds) == "table"
				and savedData.ProcessedPurchaseIds[purchaseId] == true
		end)
	end)

	if not callSucceeded then
		return false, "save_confirmation_failed"
	end

	return saveSucceeded == true, reason
end

local function applyRitualRushReward(profile, reward, stats)
	local wasFull = isEssenceCapacityFull(profile, stats)
	local essenceReward = getNonNegativeInteger(reward.Essence)
	local ritualGemsAwarded = getNonNegativeInteger(reward.RitualGems)
	local potionRewards = {}

	local essenceAwarded = 0
	local autoCapacityResult = {
		Changed = false,
		LevelsBought = 0,
		EssenceSpent = 0,
	}

	if essenceReward > 0 then
		essenceAwarded = math.min(essenceReward, getAvailableEssenceCapacity(profile, stats))
		profile.Essence = addExactIntegers(profile.Essence, essenceAwarded)

		if essenceAwarded > 0 then
			autoCapacityResult = RitualStoneProgress.purchaseAutoCapacity(profile)
		end
	end

	if ritualGemsAwarded > 0 then
		local currentRitualGems = math.clamp(
			getNonNegativeInteger(profile.RitualGems),
			0,
			ProfileContract.MaximumExactInteger
		)

		ritualGemsAwarded = math.min(
			ritualGemsAwarded,
			ProfileContract.MaximumExactInteger - currentRitualGems
		)
		profile.RitualGems = currentRitualGems + ritualGemsAwarded
	end

	if typeof(reward.Potions) == "table" then
		for _, potionGrant in ipairs(reward.Potions) do
			local didApplyPotion, potionReward = applyPotionGrant(profile, potionGrant)

			if didApplyPotion then
				table.insert(potionRewards, potionReward)
			end
		end
	end

	queueCapacityFullTransition(profile, wasFull)

	return {
		Essence = essenceAwarded,
		RitualGems = ritualGemsAwarded,
		Potions = potionRewards,
		AutoCapacity = autoCapacityResult,
	}
end

local function hasRitualRushRewardValue(reward)
	if typeof(reward) ~= "table" then
		return false
	end

	local potionCount = if typeof(reward.Potions) == "table" then #reward.Potions else 0

	return getNonNegativeInteger(reward.Essence) > 0
		or getNonNegativeInteger(reward.RitualGems) > 0
		or potionCount > 0
end

local function addRitualRushReward(totalReward, reward)
	totalReward.Essence = addExactIntegers(totalReward.Essence, reward.Essence)
	totalReward.RitualGems = addExactIntegers(totalReward.RitualGems, reward.RitualGems)

	if typeof(totalReward.Potions) ~= "table" then
		totalReward.Potions = {}
	end

	if typeof(reward.Potions) == "table" then
		for _, potionGrant in ipairs(reward.Potions) do
			local normalizedGrant = PotionConfig.normalizePotionGrant(potionGrant)

			if normalizedGrant ~= nil then
				table.insert(totalReward.Potions, normalizedGrant)
			end
		end
	end
end

local function inspectRitualRushClaim(progress, milestone, track)
	if typeof(progress) ~= "table" or typeof(milestone) ~= "table" then
		return nil, "ritual_rush_reward_not_configured"
	end

	local milestoneId = milestone.MilestoneId
	local requiredPoints = getPositiveInteger(milestone.RequiredPoints)

	if typeof(milestoneId) ~= "string" or requiredPoints == nil then
		return nil, "ritual_rush_reward_not_configured"
	end

	if getNonNegativeInteger(progress.Points) < requiredPoints then
		return nil, "ritual_rush_milestone_locked"
	end

	local claimedFreeMilestones = if typeof(progress.ClaimedFreeMilestones) == "table"
		then progress.ClaimedFreeMilestones
		else {}
	local claimedPremiumMilestones = if typeof(progress.ClaimedPremiumMilestones) == "table"
		then progress.ClaimedPremiumMilestones
		else {}
	local wantsFree = track == nil or track == "free"
	local wantsPremium = track == nil or track == "premium"

	if track == "premium" and progress.PremiumUnlocked ~= true then
		return nil, "ritual_rush_premium_locked"
	end

	local claimFree = wantsFree and claimedFreeMilestones[milestoneId] ~= true
	local claimPremium = wantsPremium
		and progress.PremiumUnlocked == true
		and claimedPremiumMilestones[milestoneId] ~= true

	if claimFree and not hasRitualRushRewardValue(milestone.FreeReward) then
		return nil, "ritual_rush_reward_not_configured"
	end

	if claimPremium and not hasRitualRushRewardValue(milestone.PremiumReward) then
		return nil, "ritual_rush_reward_not_configured"
	end

	if not claimFree and not claimPremium then
		return nil, "ritual_rush_reward_already_claimed"
	end

	return {
		Free = claimFree,
		Premium = claimPremium,
	}, nil
end

local function createRitualRushClaimFailure(code, changed, milestoneId)
	local messages = {
		invalid_ritual_rush_track = "Invalid Ritual Rush reward track.",
		ritual_rush_milestone_locked = "Ritual Rush milestone is locked.",
		ritual_rush_premium_locked = "Premium Ritual Rush is locked.",
		ritual_rush_reward_already_claimed = "Ritual Rush reward is already claimed.",
		ritual_rush_reward_not_configured = "Ritual Rush reward is not configured.",
		ritual_rush_event_changed = "The Ritual Rush event changed before the reward could be claimed.",
	}

	return {
		Ok = false,
		Changed = changed == true,
		Code = code,
		Message = messages[code] or "Ritual Rush reward could not be claimed.",
		MilestoneId = milestoneId,
	}
end

local function getCharacterRootPosition(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	return root.Position
end

local function getLivingCharacterRootPosition(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	return root.Position
end

local function isPositionNearAscensionStatue(zoneId, position)
	if typeof(position) ~= "Vector3" then
		return false
	end

	local statuePosition = GeneratedMapRuntime.getRuntimePosition(zoneId, AscensionConfig.getStatuePosition(zoneId))

	if statuePosition == nil then
		return false
	end

	return (position - statuePosition).Magnitude <= AscensionConfig.Statue.PromptDistance
end

local function switchCurrentZone(profile, zoneId)
	if ZoneConfig.getZone(zoneId) == nil then
		return false, false, "ZoneNotConfigured"
	end

	if profile.CurrentZone == zoneId then
		return true, false, nil
	end

	profile.CurrentZone = zoneId
	CrystalCombat.resetState(profile, zoneId)

	return true, true, nil
end

local function teleportPlayerToZone(player, zoneId)
	local character = player.Character

	if character ~= nil and player.Parent == Players then
		character:PivotTo(GeneratedMapRuntime.getTeleportCFrame(zoneId))
		return true
	end

	task.defer(function()
		local startedAt = os.clock()
		local deferredCharacter = player.Character

		while deferredCharacter == nil and player.Parent == Players and os.clock() - startedAt < 5 do
			task.wait()
			deferredCharacter = player.Character
		end

		if deferredCharacter == nil or player.Parent ~= Players then
			return
		end

		deferredCharacter:PivotTo(GeneratedMapRuntime.getTeleportCFrame(zoneId))
	end)

	return false
end

local function getProfileRecord(player)
	return profileRecordsByPlayer[player]
end

function PlayerStateService.getProfile(player)
	local record = getProfileRecord(player)

	if
		record == nil
		or not ProfilePersistence.isCurrent(player, record.Profile, record.Token)
	then
		return nil
	end

	return record.Profile
end

function PlayerStateService.isCurrentProfile(player, expectedProfile)
	local record = getProfileRecord(player)

	return record ~= nil
		and record.Profile == expectedProfile
		and ProfilePersistence.isCurrent(player, expectedProfile, record.Token)
end

function PlayerStateService.withProfileLock(player, callback)
	if player == nil or callback == nil then
		return nil
	end

	local queue = profileOperationQueuesByPlayer[player]

	if queue == nil then
		queue = {}
		profileOperationQueuesByPlayer[player] = queue
	end

	local token = {}

	table.insert(queue, token)

	while queue[1] ~= token do
		task.wait()
	end

	local ok, result = pcall(callback, PlayerStateService.getProfile(player))

	table.remove(queue, 1)

	if #queue == 0 then
		profileOperationQueuesByPlayer[player] = nil
	end

	if not ok then
		error(result, 2)
	end

	return result
end

function PlayerStateService.grantSocialReward(_player, profile, amount)
	if typeof(profile) ~= "table" then
		return false
	end

	local current = getNonNegativeInteger(profile.RitualGems)
	local granted = math.min(getNonNegativeInteger(amount), ProfileContract.MaximumExactInteger - current)
	profile.RitualGems = current + granted
	PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.FirstCoplayReward, {
		RitualGems = granted,
	})
	profile.SnapshotRevision = addExactIntegers(profile.SnapshotRevision, 1)
	return granted > 0
end

function PlayerStateService.waitForProfile(player, timeoutSeconds)
	local startedAt = os.clock()
	local timeout = timeoutSeconds or PROFILE_LOAD_TIMEOUT_SECONDS
	local profile = PlayerStateService.getProfile(player)

	while profile == nil and player.Parent == Players and os.clock() - startedAt < timeout do
		task.wait()
		profile = PlayerStateService.getProfile(player)
	end

	return profile
end

local function resolveCurrentProfile(player, expectedProfile)
	local profile = expectedProfile or PlayerStateService.getProfile(player)

	if profile == nil or not PlayerStateService.isCurrentProfile(player, profile) then
		return nil
	end

	return profile
end

function PlayerStateService.getSnapshot(player, expectedProfile)
	local profile = resolveCurrentProfile(player, expectedProfile)
	local snapshot = PlayerDerivedState.getSnapshot(profile)
	if snapshot ~= nil and socialPresenceService ~= nil then
		snapshot.Social = socialPresenceService:getSnapshot(player, profile)
	end
	if snapshot ~= nil then snapshot.Leaderboards = LeaderboardService.getSnapshot() end
	return snapshot
end

function PlayerStateService.getCurrentLeaderboardRecords()
	local records = {}
	for player, record in pairs(profileRecordsByPlayer) do
		table.insert(records, { Player = player, Profile = record.Profile, ProfileReady = true })
	end
	return records
end

function PlayerStateService.getPublicVisual(player, expectedProfile)
	local profile = resolveCurrentProfile(player, expectedProfile)

	return PlayerDerivedState.getPublicVisual(profile)
end

function PlayerStateService.publishPublicVisual(player, expectedProfile)
	local publicVisual = PlayerStateService.getPublicVisual(player, expectedProfile)

	if publicVisual == nil then
		return nil
	end

	PlayerPublicVisualSignal.fire(player, publicVisual)

	return publicVisual
end

function PlayerStateService.getCrystalUpdate(player, expectedProfile, requestedSections)
	local profile = resolveCurrentProfile(player, expectedProfile)

	return PlayerDerivedState.getCrystalUpdate(profile, requestedSections)
end

function PlayerStateService.getPlayerStateSections(player, expectedProfile, requestedSections)
	local profile = resolveCurrentProfile(player, expectedProfile)
	local derivedSections = requestedSections
	if typeof(requestedSections) == "table" and requestedSections.Leaderboards == true then
		derivedSections = table.clone(requestedSections)
		derivedSections.Leaderboards = nil
	end
	local sections = PlayerDerivedState.getPlayerStateSections(profile, derivedSections)
	if sections == nil and requestedSections.Leaderboards == true then
		sections = {}
	end
	if sections ~= nil and sections.Social ~= nil and socialPresenceService ~= nil then
		sections.Social = socialPresenceService:getSnapshot(player, profile)
	end
	if sections ~= nil and typeof(requestedSections) == "table" and requestedSections.Leaderboards == true then
		sections.Leaderboards = LeaderboardService.getSnapshot()
	end
	return sections
end

function PlayerStateService.setSocialPresenceService(service)
	socialPresenceService = service
end

function PlayerStateService.takeFeedback(player, expectedProfile, maximumRecords)
	local profile = resolveCurrentProfile(player, expectedProfile)

	if profile == nil then
		return {}
	end

	return RuneFocusProgress.drainFeedback(profile, os.clock(), maximumRecords)
end

function PlayerStateService.hasReadyFeedback(player, expectedProfile)
	local profile = resolveCurrentProfile(player, expectedProfile)

	return profile ~= nil and RuneFocusProgress.hasReadyFeedback(profile, os.clock())
end

function PlayerStateService.updateLeaderstatsFromProfile(player, expectedProfile)
	local profile = resolveCurrentProfile(player, expectedProfile)

	if profile == nil then
		return false
	end

	local leaderstatsPayload = PlayerDerivedState.getLeaderstatsPayload(profile)

	return LeaderstatsService.update(player, leaderstatsPayload)
end

function PlayerStateService.subscribePublicVisualChanged(listener)
	return PlayerPublicVisualSignal.subscribe(listener)
end

function PlayerStateService.advanceSnapshotRevision(player, expectedProfile)
	local profile = resolveCurrentProfile(player, expectedProfile)

	if profile == nil then
		return nil
	end

	profile.SnapshotRevision = addExactIntegers(profile.SnapshotRevision, 1)

	return profile.SnapshotRevision
end

function PlayerStateService.enterActiveZone(player, zoneId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Reason = "ProfileNotReady",
		}
	end

	if typeof(zoneId) ~= "number" or ZoneConfig.getZone(zoneId) == nil then
		return {
			Ok = false,
			Changed = false,
			Reason = "ZoneNotConfigured",
		}
	end

	if profile.UnlockedZones[zoneId] ~= true then
		local activeChanged = CrystalCombat.setFarmingActive(profile, false)

		return {
			Ok = false,
			Changed = activeChanged,
			Reason = "ZoneLocked",
			ZoneId = zoneId,
		}
	end

	local ok, zoneChanged, reason = switchCurrentZone(profile, zoneId)
	local activeChanged = CrystalCombat.setFarmingActive(profile, ok)
	local onboardingChanged = false

	if ok then
		CrystalCombat.ensureState(profile)
		onboardingChanged = completeOnboardingMilestone(profile, "entered_crystal_zone")
	end

	return {
		Ok = ok,
		Changed = zoneChanged or activeChanged or onboardingChanged,
		Reason = reason,
		ZoneId = zoneId,
	}
end

function PlayerStateService.exitActiveZone(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Reason = "ProfileNotReady",
		}
	end

	local activeChanged = CrystalCombat.setFarmingActive(profile, false)

	return {
		Ok = true,
		Changed = activeChanged,
		Reason = "ZoneExited",
		ZoneId = profile.CurrentZone,
	}
end

function PlayerStateService.processCrystalFarming(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Reason = "ProfileNotReady",
		}
	end

	if profile.CrystalFarmingActive ~= true then
		return {
			Ok = true,
			Changed = false,
			Reason = "ZoneInactive",
			ZoneId = profile.CurrentZone,
			AttackCount = 0,
		}
	end

	local now = os.clock()
	local runeBonuses, stats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local beforeEssence = getNonNegativeInteger(profile.Essence)
	local wasFull = isEssenceCapacityFull(profile, stats)
	local farmingStep = CrystalCombat.step(profile, stats, runeBonuses, now)
	local rushPointsAwarded = awardCrystalBreakRush(
		profile,
		farmingStep.BreakCount or 0,
		farmingStep.RuneLevelsGained or 0
	)

	if farmingStep.Changed == true then
		queueCapacityFullTransition(profile, wasFull)
	end

	local breakCount = farmingStep.BreakCount or 0
	local runeLevelsGained = farmingStep.RuneLevelsGained or 0
	if breakCount > 0 then
		recordRetentionEvent(profile, "online_crystal_break", breakCount)
	end
	if runeLevelsGained > 0 then
		recordRetentionEvent(profile, "stone_or_rune_upgrade", runeLevelsGained)
	end
	local autoCapacityLevelsBought = farmingStep.AutoCapacityLevelsBought or 0
	local zoneUnlockEligibilityChanged = didLockedZoneUnlockEligibilityChange(
		profile,
		beforeEssence,
		profile.Essence
	)
	local dirtySections = {
		Crystal = true,
	}

	if zoneUnlockEligibilityChanged then
		dirtySections.Zones = true
	end

	if breakCount > 0 then
		dirtySections.Essence = true
		dirtySections.Rebirth = true
		dirtySections.RuneFocus = true
		dirtySections.RitualRush = true
		dirtySections.RitualPower = true
		dirtySections.Retention = true
	end

	if autoCapacityLevelsBought > 0 then
		dirtySections.Essence = true
		dirtySections.StoneLevels = true
		dirtySections.StoneStats = true
		dirtySections.NextUpgradeCosts = true
		dirtySections.Rebirth = true
		dirtySections.Automation = true
		dirtySections.RuneFocus = true
		dirtySections.RitualRush = true
		dirtySections.Onboarding = true
		dirtySections.Crystal = true
		dirtySections.BestRitualPower = true
		dirtySections.HighestCapacity = true
		dirtySections.RitualPower = true
	end

	if runeLevelsGained > 0 then
		dirtySections.StoneStats = true
		dirtySections.NextUpgradeCosts = true
		dirtySections.Roll = true
		dirtySections.Pets = true
		dirtySections.EquippedPets = true
		dirtySections.BestRitualPower = true
		dirtySections.HighestCapacity = true
		dirtySections.RitualPower = true
		dirtySections.Retention = true
	end

	return {
		Ok = true,
		Changed = farmingStep.Changed == true or rushPointsAwarded > 0,
		Code = if farmingStep.Changed == true or rushPointsAwarded > 0 then "crystal_farming_updated" else "no_change",
		Reason = farmingStep.Reason,
		ZoneId = farmingStep.ZoneId,
		AttackCount = farmingStep.AttackCount,
		BreakCount = farmingStep.BreakCount,
		RuneChargeApplied = farmingStep.RuneChargeApplied,
		RuneLevelsGained = runeLevelsGained,
		AutoCapacityLevelsBought = autoCapacityLevelsBought,
		AutoCapacityEssenceSpent = farmingStep.AutoCapacityEssenceSpent or 0,
		UsePlayerStateUpdated = autoCapacityLevelsBought > 0 or runeLevelsGained > 0 or breakCount > 0,
		DirtySections = dirtySections,
	}
end

function PlayerStateService.syncProfile(player, expectedProfile)
	local profile = resolveCurrentProfile(player, expectedProfile)

	if profile == nil then
		return false
	end

	commitProfileForPersistence(profile)

	if not PlayerStateService.isCurrentProfile(player, profile) then
		return false
	end

	return ProfilePersistence.sync(player, profile)
end

function PlayerStateService.processShopReceipt(player, receiptInfo, product)
	if player == nil or player.Parent ~= Players then
		return {
			Ok = false,
			Reason = "PlayerUnavailable",
		}
	end

	if typeof(receiptInfo) ~= "table" then
		return {
			Ok = false,
			Reason = "ReceiptInvalid",
		}
	end

	local purchaseId = receiptInfo.PurchaseId
	local receiptProductId = getPositiveInteger(receiptInfo.ProductId)
	local productRobloxProductId = ShopProductConfig.getRobloxProductId(product)

	if
		typeof(purchaseId) ~= "string"
		or purchaseId == ""
		or #purchaseId > ProfileContract.MaximumReceiptLength
	then
		return {
			Ok = false,
			Reason = "ReceiptPurchaseIdInvalid",
		}
	end

	if receiptProductId == nil or productRobloxProductId == nil or receiptProductId ~= productRobloxProductId then
		return {
			Ok = false,
			Reason = "ReceiptProductMismatch",
		}
	end

	if receiptInfo.PlayerId ~= player.UserId then
		return {
			Ok = false,
			Reason = "ReceiptPlayerMismatch",
		}
	end

	local profile = resolveCurrentProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Reason = "ProfileNotReady",
		}
	end

	local processedPurchaseIds = ensureProcessedPurchaseIds(profile)

	if processedPurchaseIds[purchaseId] == true then
		local didSave = saveProfileForPurchase(player, profile, purchaseId)

		if not didSave then
			return {
				Ok = false,
				Reason = "ProfileSaveFailed",
			}
		end

		return {
			Ok = true,
			AlreadyProcessed = true,
			ShopProductId = product.ShopProductId,
			RobloxProductId = productRobloxProductId,
		}
	end

	local didGrant, reward = applyShopProductGrant(profile, product)

	if not didGrant then
		return {
			Ok = false,
			Reason = reward,
			ShopProductId = product.ShopProductId,
			RobloxProductId = productRobloxProductId,
		}
	end

	processedPurchaseIds[purchaseId] = true
	profile.SnapshotRevision = addExactIntegers(profile.SnapshotRevision, 1)

	local didSave = saveProfileForPurchase(player, profile, purchaseId)

	if not didSave then
		return {
			Ok = false,
			Reason = "ProfileSaveFailed",
			ShopProductId = product.ShopProductId,
			RobloxProductId = productRobloxProductId,
		}
	end

	PlayerStateService.updateLeaderstatsFromProfile(player, profile)
	PlayerStateService.publishPublicVisual(player, profile)

	return {
		Ok = true,
		ShopProductId = product.ShopProductId,
		RobloxProductId = productRobloxProductId,
		Reward = reward,
	}
end

function PlayerStateService.completeTutorialStep(_player, _stepId, _completionMode)
	return {
		Ok = false,
		Changed = false,
		Code = "deprecated_action",
		Message = "Tutorial completion is now driven by server gameplay milestones.",
	}
end

function PlayerStateService.updateGuidance(player, values)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil or typeof(values) ~= "table" then
		return { Ok = false, Changed = false, Code = "profile_not_ready" }
	end

	local recognized = false
	for key, value in pairs(values) do
		if key ~= "IntroSeen" and key ~= "GuidanceHidden" then
			return { Ok = false, Changed = false, Code = "invalid_guidance_update" }
		end
		if typeof(value) ~= "boolean" then
			return { Ok = false, Changed = false, Code = "invalid_guidance_update" }
		end
		recognized = true
	end

	if not recognized then
		return { Ok = false, Changed = false, Code = "invalid_guidance_update" }
	end

	local changed = OnboardingProgress.updateGuidance(profile, values)
	if changed then
		profile.SnapshotRevision = addExactIntegers(profile.SnapshotRevision, 1)
	end

	return {
		Ok = true,
		Changed = changed,
		Code = if changed then "guidance_updated" else "guidance_unchanged",
	}
end

function PlayerStateService.claimDailyReward(player, requestedDayIndex)
	local profile = PlayerStateService.getProfile(player)
	if profile == nil then
		return { Ok = false, Changed = false, Code = "profile_not_ready" }
	end

	local nowUnix = DateTime.now().UnixTimestamp
	local result = DailyRewardProgress.claim(profile, requestedDayIndex, nowUnix)
	if result.Changed ~= true then
		if result.Code == "already_claimed" then
			local confirmed = ProfilePersistence.saveConfirmed(player, profile, function(data)
				return typeof(data) == "table"
					and typeof(data.DailyRewards) == "table"
					and data.DailyRewards.LastClaimedDay == result.Snapshot.DayIndex
			end)
			if confirmed ~= true then
				return { Ok = false, Changed = false, Code = "save_confirmation_failed", RetryAfter = 1 }
			end
		end
		return result
	end

	profile.SnapshotRevision = addExactIntegers(profile.SnapshotRevision, 1)
	PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.DailyRewardClaimed, result.Reward)
	commitProfileForPersistence(profile)
	local saved = ProfilePersistence.saveConfirmed(player, profile, function(data)
		return typeof(data) == "table"
			and typeof(data.DailyRewards) == "table"
			and data.DailyRewards.LastClaimedDay == result.Snapshot.DayIndex
	end)
	if saved ~= true then
		return { Ok = false, Changed = true, Code = "save_confirmation_failed", RetryAfter = 1 }
	end

	return result
end

function PlayerStateService.resolveAwayRewards(player, kind, sequence)
	local profile = PlayerStateService.getProfile(player)
	if profile == nil then
		return { Ok = false, Changed = false, Code = "profile_not_ready" }
	end

	local result = AwayRewardProgress.resolve(profile, kind, sequence, getAwayContext(profile), function(focusId, requestedCharge)
		return RuneFocusProgress.grantOfflineCharge(profile, focusId, requestedCharge)
	end, DateTime.now().UnixTimestamp)

	if result.Changed ~= true then
		if result.Code == "away_already_resolved" then
			replaceAwayCheckpoint(profile, DateTime.now().UnixTimestamp)
			local confirmed = ProfilePersistence.saveConfirmed(player, profile, function(data)
				return typeof(data) == "table"
					and typeof(data.AwayRewards) == "table"
					and typeof(data.AwayRewards.LastResolution) == "table"
					and data.AwayRewards.LastResolution.Sequence == sequence
			end)
			if confirmed ~= true then
				return { Ok = false, Changed = false, Code = "save_confirmation_failed", RetryAfter = 1 }
			end
		end
		return result
	end

	replaceAwayCheckpoint(profile, DateTime.now().UnixTimestamp)
	profile.SnapshotRevision = addExactIntegers(profile.SnapshotRevision, 1)
	PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.AwayRewardClaimed, result.Resolution)
	commitProfileForPersistence(profile)
	local saved = ProfilePersistence.saveConfirmed(player, profile, function(data)
		return typeof(data) == "table"
			and typeof(data.AwayRewards) == "table"
			and typeof(data.AwayRewards.LastResolution) == "table"
			and data.AwayRewards.LastResolution.Sequence == sequence
	end)
	if saved ~= true then
		return { Ok = false, Changed = true, Code = "save_confirmation_failed", RetryAfter = 1 }
	end

	return result
end

function PlayerStateService.claimRitualRushReward(player, milestoneId, track)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Message = "Player profile is not ready.",
		}
	end

	if
		typeof(milestoneId) ~= "string"
		or #milestoneId == 0
		or #milestoneId > ProfileContract.MaximumIdentifierLength
	then
		return {
			Ok = false,
			Changed = false,
			Code = "invalid_ritual_rush_milestone",
			Message = "Invalid Ritual Rush reward.",
		}
	end

	local milestone = RitualRushConfig.getMilestone(milestoneId)

	if milestone == nil or table.find(RitualRushConfig.MilestoneOrder, milestoneId) == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "ritual_rush_reward_not_configured",
			Message = "Ritual Rush reward is not configured.",
		}
	end

	if track ~= nil and track ~= "free" and track ~= "premium" then
		return createRitualRushClaimFailure(
			"invalid_ritual_rush_track",
			false,
			milestone.MilestoneId
		)
	end

	-- Inspect a reconciled current-event copy without changing the profile. A
	-- locked or fully claimed request cannot use crystal recovery to become valid.
	local inspectedProgress = RitualRushConfig.reconcileProgress(profile.RitualRush)
	local inspectedEventId = inspectedProgress.EventId
	local _, precheckFailure = inspectRitualRushClaim(inspectedProgress, milestone, track)

	if precheckFailure ~= nil then
		return createRitualRushClaimFailure(precheckFailure, false, milestone.MilestoneId)
	end

	local previousRushEventId = if typeof(profile.RitualRush) == "table"
		then profile.RitualRush.EventId
		else nil
	local crystalChanged = syncAndCollectCrystalReward(profile)
	local progress = RitualRushProgress.ensureProgress(profile)
	local rushEventChanged = progress.EventId ~= previousRushEventId
	local changedBeforeClaim = crystalChanged == true or rushEventChanged

	if progress.EventId ~= inspectedEventId then
		return createRitualRushClaimFailure(
			"ritual_rush_event_changed",
			changedBeforeClaim,
			milestone.MilestoneId
		)
	end

	local claimableTracks, revalidationFailure = inspectRitualRushClaim(progress, milestone, track)

	if revalidationFailure ~= nil then
		return createRitualRushClaimFailure(
			revalidationFailure,
			changedBeforeClaim,
			milestone.MilestoneId
		)
	end

	local claimedTracks = {}
	local totalReward = {
		Essence = 0,
		RitualGems = 0,
		Potions = {},
	}

	if claimableTracks.Free == true then
		addRitualRushReward(totalReward, milestone.FreeReward)
		table.insert(claimedTracks, "free")
	end

	if claimableTracks.Premium == true then
		addRitualRushReward(totalReward, milestone.PremiumReward)
		table.insert(claimedTracks, "premium")
	end

	local _, stats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local appliedReward = applyRitualRushReward(profile, totalReward, stats)

	if claimableTracks.Free == true then
		progress.ClaimedFreeMilestones[milestone.MilestoneId] = true
	end

	if claimableTracks.Premium == true then
		progress.ClaimedPremiumMilestones[milestone.MilestoneId] = true
	end

	return {
		Ok = true,
		Changed = true,
		Code = "ritual_rush_reward_claimed",
		Message = "Ritual Rush reward claimed.",
		MilestoneId = milestone.MilestoneId,
		ClaimedTracks = claimedTracks,
		Reward = appliedReward,
	}
end

function PlayerStateService.claimRitualRushFreeReward(player, milestoneId)
	return PlayerStateService.claimRitualRushReward(player, milestoneId, "free")
end

function PlayerStateService.usePotion(player, potionId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "profile_not_ready",
			Message = "Player profile is not ready.",
		}
	end

	if
		typeof(potionId) ~= "string"
		or #potionId == 0
		or #potionId > ProfileContract.MaximumIdentifierLength
	then
		return {
			Ok = false,
			Changed = false,
			Code = "invalid_potion",
			Message = "Invalid potion.",
		}
	end

	local potion = PotionConfig.getPotion(potionId)

	if potion == nil or table.find(PotionConfig.PotionOrder, potionId) == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "potion_not_configured",
			Message = "Potion is not configured.",
		}
	end

	local boostGrant = PotionConfig.getPotionBoostGrant(potion.PotionId)

	if boostGrant == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "potion_effect_not_configured",
			Message = "Potion effect is not configured.",
			PotionId = potion.PotionId,
		}
	end

	-- Validate ownership against a normalized copy before crystal settlement so
	-- an invalid request cannot mutate otherwise unrelated progression.
	local inspectedPotions = PotionConfig.normalizeInventory(profile.Potions)

	if (inspectedPotions[potion.PotionId] or 0) <= 0 then
		return {
			Ok = false,
			Changed = false,
			Code = "potion_not_owned",
			Message = "You do not own this potion.",
			PotionId = potion.PotionId,
		}
	end

	local potionInventoryChanged = not areShallowTablesEqual(profile.Potions, inspectedPotions)

	local crystalChanged = syncAndCollectCrystalReward(profile)

	local didConsumePotion, consumeResult, potions = PotionConfig.consumePotion(profile.Potions, potion.PotionId)

	if not didConsumePotion then
		local message = if consumeResult == "PotionNotOwned" then "You do not own this potion." else "Potion cannot be used."

		return {
			Ok = false,
			Changed = crystalChanged == true,
			Code = if consumeResult == "PotionNotOwned" then "potion_not_owned" else "potion_use_failed",
			Message = message,
			PotionId = potion.PotionId,
		}
	end

	profile.Potions = potions

	local didApplyBoost, boostReward = applyBoostGrant(profile, boostGrant)

	if not didApplyBoost then
		applyPotionGrant(profile, {
			PotionId = potion.PotionId,
			Count = 1,
		})

		return {
			Ok = false,
			Changed = potionInventoryChanged or crystalChanged,
			Code = "potion_effect_apply_failed",
			Message = "Potion effect could not be applied.",
			PotionId = potion.PotionId,
		}
	end

	local remainingCount = profile.Potions[potion.PotionId] or 0

	return {
		Ok = true,
		Changed = true,
		Code = "potion_used",
		Message = "Potion used.",
		Potion = {
			PotionId = potion.PotionId,
			Count = remainingCount,
		},
		Boost = boostReward,
	}
end

function PlayerStateService.buyPotionWithGems(player, potionId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Message = "Player profile is not ready.",
		}
	end

	if typeof(potionId) ~= "string" then
		return {
			Ok = false,
			Message = "Invalid potion.",
		}
	end

	local _, potionInventoryChanged = reconcilePotions(profile)

	local potion = PotionConfig.getPotion(potionId)

	if potion == nil or potion.IsShopEnabled ~= true then
		return {
			Ok = false,
			Changed = potionInventoryChanged,
			Message = "Potion is not available.",
		}
	end

	local gemCost = getPositiveInteger(potion.GemCost)

	if gemCost == nil then
		return {
			Ok = false,
			Changed = potionInventoryChanged,
			Message = "Potion price is not configured.",
			PotionId = potion.PotionId,
		}
	end

	local ritualGems = getNonNegativeInteger(profile.RitualGems)

	if ritualGems < gemCost then
		return {
			Ok = false,
			Changed = potionInventoryChanged,
			Message = "Not enough Ritual Gems.",
			PotionId = potion.PotionId,
			Cost = gemCost,
		}
	end

	profile.RitualGems = ritualGems - gemCost

	local didApplyPotion, potionReward = applyPotionGrant(profile, {
		PotionId = potion.PotionId,
		Count = 1,
	})

	if not didApplyPotion then
		profile.RitualGems = addExactIntegers(profile.RitualGems, gemCost)

		return {
			Ok = false,
			Changed = potionInventoryChanged,
			Message = "Potion could not be added.",
			PotionId = potion.PotionId,
		}
	end

	return {
		Ok = true,
		Changed = true,
		Message = "Potion purchased.",
		Potion = potionReward,
		Cost = gemCost,
	}
end

function PlayerStateService.rebirth(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "profile_not_ready",
			Message = "Player profile is not ready.",
		}
	end

	if hasPendingAwayClaim(profile) then
		return {
			Ok = false,
			Changed = false,
			Code = "away_claim_required",
			Message = "Claim or dismiss your away reward before rebirthing.",
		}
	end

	if getNonNegativeInteger(profile.Rebirths) >= ProfileContract.MaximumExactInteger then
		return {
			Ok = false,
			Changed = false,
			Code = "rebirth_count_maxed",
			Message = "Rebirth count has reached the exact-integer limit.",
		}
	end

	local rebirthRequirement = RitualStoneConfig.getRebirthRequirement(profile.Rebirths)

	if not PlayerDerivedState.canRebirth(profile, rebirthRequirement) then
		return {
			Ok = false,
			Changed = false,
			Code = "rebirth_requirements_not_met",
			Message = "Rebirth requirement is not met.",
		}
	end

	local crystalChanged = syncAndCollectCrystalReward(profile)
	local currentRequirement = RitualStoneConfig.getRebirthRequirement(profile.Rebirths)

	if not PlayerDerivedState.canRebirth(profile, currentRequirement) then
		return {
			Ok = false,
			Changed = crystalChanged == true,
			Code = "rebirth_requirements_changed",
			Message = "Rebirth requirements changed before the reset could complete.",
		}
	end

	local rebirthNowUnix = DateTime.now().UnixTimestamp
	profile.Rebirths = addExactIntegers(profile.Rebirths, 1)
	recordRetentionEvent(profile, "rebirth", 1)
	completeOnboardingMilestone(profile, "first_rebirth")
	RitualRushProgress.awardPoints(profile, RitualRushConfig.PointSources.Rebirth, 1, rebirthNowUnix)
	local dailyBonus = DailyRewardProgress.grantFirstRebirthOfDay(profile, function(dailyProfile, source, count, capturedNow)
		return RitualRushProgress.awardPoints(dailyProfile, source, count, capturedNow)
	end, rebirthNowUnix)
	if dailyBonus.Changed == true then
		PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.FirstRebirthDailyBonus, dailyBonus.Reward)
	end
	profile.Essence = 0
	profile.CurrentZone = 1
	profile.UnlockedZones = {
		[1] = true,
	}
	profile.StoneLevels = createDefaultStoneLevels()
	profile.RollReadyAt = 0
	profile.ProgressionEpoch = addExactIntegers(profile.ProgressionEpoch, 1)
	profile.RuneFocusSelectionReadyAt = 0
	CrystalCombat.resetState(profile, 1)
	CrystalCombat.setFarmingActive(profile, false)
	replaceAwayCheckpoint(profile, DateTime.now().UnixTimestamp)
	PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.RebirthComplete, {
		Rebirths = profile.Rebirths,
	})
	task.defer(teleportPlayerToZone, player, 1)

	return {
		Ok = true,
		Changed = true,
		Code = "rebirth_complete",
		Message = "Rebirth complete. Permanent power increased.",
	}
end

function PlayerStateService.ascend(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "profile_not_ready",
			Message = "Player profile is not ready.",
		}
	end

	if hasPendingAwayClaim(profile) then
		return {
			Ok = false,
			Changed = false,
			Code = "away_claim_required",
			Message = "Claim or dismiss your away reward before ascending.",
		}
	end

	local ascension = PlayerDerivedState.getAscensionSnapshot(profile)

	if ascension.HasNextMilestone ~= true then
		return {
			Ok = false,
			Changed = false,
			Code = "v1_complete",
			Message = "All current Ascension milestones are complete.",
			Ascension = ascension.Count,
		}
	end

	if ascension.RequiredZoneExists ~= true then
		return {
			Ok = false,
			Changed = false,
			Code = "ascension_zone_unavailable",
			Message = "The next Ascension zone is not available yet.",
			Ascension = ascension.Count,
		}
	end

	if ascension.CanAscend ~= true then
		return {
			Ok = false,
			Changed = false,
			Code = "ascension_requirements_not_met",
			Message = "Reach Zone " .. tostring(ascension.RequiredZone) .. " to ascend.",
			Ascension = ascension.Count,
		}
	end

	if not isPositionNearAscensionStatue(ascension.RequiredZone, getLivingCharacterRootPosition(player)) then
		return {
			Ok = false,
			Changed = false,
			Code = "ascension_statue_too_far",
			Message = "Move closer to the Ascension Statue.",
			Ascension = ascension.Count,
		}
	end

	local crystalChanged = syncAndCollectCrystalReward(profile)
	local currentAscension = PlayerDerivedState.getAscensionSnapshot(profile)

	if
		currentAscension.HasNextMilestone ~= true
		or currentAscension.Count ~= ascension.Count
		or currentAscension.CanAscend ~= true
		or not isPositionNearAscensionStatue(
			currentAscension.RequiredZone,
			getLivingCharacterRootPosition(player)
		)
	then
		return {
			Ok = false,
			Changed = crystalChanged == true,
			Code = "ascension_requirements_changed",
			Message = "Ascension requirements changed before the reset could complete.",
			Ascension = currentAscension.Count,
		}
	end

	local currentAscensions = getNonNegativeInteger(profile.Ascensions)
	local nextAscensions = math.min(#AscensionConfig.Milestones, currentAscensions + 1)
	local starReward = AscensionConfig.getStarReward(currentAscensions)

	profile.Ascensions = nextAscensions
	recordRetentionEvent(profile, "ascension", 1)
	profile.AscensionStars = addExactIntegers(profile.AscensionStars, starReward)
	profile.Essence = 0
	profile.CurrentZone = 1
	profile.UnlockedZones = {
		[1] = true,
	}
	profile.StoneLevels = createDefaultStoneLevels()
	RuneFocusProgress.clearChargeFeedback(profile)
	resetRuneFocusForAscension(profile)
	profile.RollReadyAt = 0
	profile.ProgressionEpoch = addExactIntegers(profile.ProgressionEpoch, 1)
	profile.RuneFocusSelectionReadyAt = 0

	CrystalCombat.resetState(profile, 1)
	CrystalCombat.setFarmingActive(profile, false)
	replaceAwayCheckpoint(profile, DateTime.now().UnixTimestamp)
	RitualRushProgress.awardPoints(profile, RitualRushConfig.PointSources.Ascension)
	PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.AscensionComplete, {
		Ascensions = nextAscensions,
		StarReward = starReward,
	})
	task.defer(teleportPlayerToZone, player, 1)

	return {
		Ok = true,
		Changed = true,
		Code = "ascension_complete",
		Message = "Ascension complete. Your next run is stronger.",
		Ascension = nextAscensions,
		StarReward = starReward,
	}
end

function PlayerStateService.buyAscensionUpgrade(player, upgradeId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "profile_not_ready",
			Message = "Player profile is not ready.",
			IncludeSnapshot = true,
		}
	end

	if
		typeof(upgradeId) ~= "string"
		or #upgradeId == 0
		or #upgradeId > ProfileContract.MaximumIdentifierLength
	then
		return {
			Ok = false,
			Changed = false,
			Code = "invalid_ascension_upgrade",
			Message = "Choose a configured Ascension upgrade.",
			IncludeSnapshot = true,
		}
	end

	local upgrade = AscensionConfig.getUpgrade(upgradeId)

	if upgrade == nil or table.find(AscensionConfig.UpgradeOrder, upgradeId) == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "invalid_ascension_upgrade",
			Message = "Choose a configured Ascension upgrade.",
			IncludeSnapshot = true,
		}
	end

	local upgrades = if typeof(profile.AscensionUpgrades) == "table" then profile.AscensionUpgrades else {}
	local currentLevel = math.clamp(getNonNegativeInteger(upgrades[upgradeId]), 0, upgrade.MaxLevel)

	if currentLevel >= upgrade.MaxLevel then
		return {
			Ok = false,
			Changed = false,
			Code = "ascension_upgrade_maxed",
			Message = "That Ascension upgrade is already maxed.",
			UpgradeId = upgradeId,
			IncludeSnapshot = true,
		}
	end

	local cost = AscensionConfig.getUpgradeCost(upgradeId, currentLevel)

	if
		typeof(cost) ~= "number"
		or cost ~= cost
		or math.abs(cost) == math.huge
		or cost ~= math.floor(cost)
		or cost < 1
		or cost > ProfileContract.MaximumExactInteger
	then
		return {
			Ok = false,
			Changed = false,
			Code = "ascension_upgrade_cost_unavailable",
			Message = "That Ascension upgrade has no configured price.",
			UpgradeId = upgradeId,
			IncludeSnapshot = true,
		}
	end

	local stars = getNonNegativeInteger(profile.AscensionStars)

	if stars < cost then
		return {
			Ok = false,
			Changed = false,
			Code = "insufficient_ascension_stars",
			Message = "Not enough Ascension Stars.",
			UpgradeId = upgradeId,
			Cost = cost,
			IncludeSnapshot = true,
		}
	end

	-- Cost, balance, and level commit together without yielding under the
	-- PlayerStateService action lock.
	profile.AscensionStars = stars - cost
	upgrades[upgradeId] = currentLevel + 1
	profile.AscensionUpgrades = upgrades
	PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.AscensionUpgrade, {
		UpgradeId = upgradeId,
		Level = currentLevel + 1,
		StarsSpent = cost,
	})

	return {
		Ok = true,
		Changed = true,
		Code = "ascension_upgrade_purchased",
		Message = "Ascension upgrade purchased.",
		UpgradeId = upgradeId,
		Cost = cost,
		IncludeSnapshot = true,
	}
end

function PlayerStateService.setAutoCapacity(player, enabled)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "profile_not_ready",
			Message = "Player profile is not ready.",
		}
	end

	if typeof(enabled) ~= "boolean" then
		return {
			Ok = false,
			Changed = false,
			Code = "invalid_auto_capacity_setting",
			Message = "Auto Capacity requires a true or false setting.",
		}
	end

	if getNonNegativeInteger(profile.Rebirths) < RitualStoneConfig.AutoCapacity.RequiredRebirths then
		return {
			Ok = false,
			Changed = false,
			Code = "auto_capacity_locked",
			Message = "Auto Capacity unlocks after one Rebirth.",
		}
	end

	local automation = if typeof(profile.Automation) == "table" then profile.Automation else {}
	local wasEnabled = automation.AutoCapacityEnabled == true

	if wasEnabled == enabled then
		return {
			Ok = true,
			Changed = false,
			Code = "auto_capacity_unchanged",
			Message = if enabled then "Auto Capacity is already enabled." else "Auto Capacity is already disabled.",
		}
	end

	automation.Version = 1
	automation.AutoCapacityEnabled = enabled
	profile.Automation = automation

	local autoCapacityResult = if enabled
		then RitualStoneProgress.purchaseAutoCapacity(profile)
		else {
			LevelsBought = 0,
			EssenceSpent = 0,
		}

	return {
		Ok = true,
		Changed = true,
		Code = if enabled then "auto_capacity_enabled" else "auto_capacity_disabled",
		Message = if enabled then "Auto Capacity enabled." else "Auto Capacity disabled.",
		LevelsBought = autoCapacityResult.LevelsBought or 0,
		EssenceSpent = autoCapacityResult.EssenceSpent or 0,
	}
end

function PlayerStateService.buyRune(_player, _runeId)
	return {
		Ok = false,
		Changed = false,
		Code = "deprecated_action",
		Message = "Rune upgrades now charge automatically through Rune Focus.",
	}
end

function PlayerStateService.selectRuneFocus(player, focusId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "profile_not_ready",
			Message = "Player profile is not ready.",
		}
	end

	local result = RuneFocusProgress.selectFocus(profile, focusId, os.clock())

	if result.Changed == true then
		completeOnboardingMilestone(profile, "rune_focus_selected")
	end

	return result
end

function PlayerStateService.unlockZone(player, zoneId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Message = "Player profile is not ready.",
		}
	end

	if typeof(zoneId) ~= "number" then
		return {
			Ok = false,
			Message = "Invalid zone unlock request.",
		}
	end

	local zone = ZoneConfig.getZone(zoneId)

	if zone == nil then
		return {
			Ok = false,
			Message = "Zone is not configured.",
		}
	end

	if profile.UnlockedZones[zoneId] == true then
		return {
			Ok = true,
			Changed = false,
			Message = "Zone is already unlocked.",
		}
	end

	local position = getCharacterRootPosition(player)

	if not GeneratedMapRuntime.isPositionNearUnlockWall(zoneId, position) then
		return {
			Ok = false,
			Message = "Move closer to the zone wall.",
		}
	end

	if not PlayerDerivedState.canUnlockZone(profile, zoneId) then
		return {
			Ok = false,
			Message = getZoneUnlockFailureMessage(profile, zoneId, zone),
		}
	end

	profile.Essence = getNonNegativeInteger(profile.Essence) - getNonNegativeInteger(zone.UnlockCost)
	profile.UnlockedZones[zoneId] = true
	recordRetentionEvent(profile, "zone_unlock", 1)

	if zoneId == 2 then
		completeOnboardingMilestone(profile, "zone_2_unlocked")
	elseif zoneId == 3 then
		completeOnboardingMilestone(profile, "zone_3_unlocked")
	end

	RitualRushProgress.awardPoints(profile, RitualRushConfig.PointSources.UnlockZone)

	return {
		Ok = true,
		Changed = true,
		Message = "Zone unlocked.",
		ZoneId = zoneId,
	}
end

function PlayerStateService.selectZone(player, zoneId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Message = "Player profile is not ready.",
		}
	end

	if typeof(zoneId) ~= "number" or ZoneConfig.getZone(zoneId) == nil then
		return {
			Ok = false,
			Message = "Zone is not configured.",
		}
	end

	if profile.UnlockedZones[zoneId] ~= true then
		return {
			Ok = false,
			Message = "Zone is locked.",
		}
	end

	local currentPositionZoneId = GeneratedMapRuntime.getZoneIdForPosition(getCharacterRootPosition(player))

	if currentPositionZoneId == zoneId and profile.CurrentZone == zoneId and profile.CrystalFarmingActive == true then
		return {
			Ok = true,
			Changed = false,
			Message = "Already in this zone.",
			ZoneId = zoneId,
		}
	end

	local movedImmediately = teleportPlayerToZone(player, zoneId)
	local resolvedZoneId = GeneratedMapRuntime.getZoneIdForPosition(getCharacterRootPosition(player))
	local zoneResult = nil

	if resolvedZoneId ~= nil then
		zoneResult = PlayerStateService.enterActiveZone(player, resolvedZoneId)
	else
		zoneResult = PlayerStateService.exitActiveZone(player)
	end

	local didArriveInRequestedZone = resolvedZoneId == zoneId

	return {
		Ok = true,
		Changed = zoneResult.Changed == true,
		Message = if didArriveInRequestedZone then "Travel complete." else "Travel requested.",
		Reason = zoneResult.Reason,
		ZoneId = zoneId,
		MovedImmediately = movedImmediately,
	}
end

function PlayerStateService.rollPet(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "profile_not_ready",
			Message = "Player profile is not ready.",
		}
	end

	local now = os.clock()

	local rollState = PlayerDerivedState.getRollCooldownState(profile, now)

	if rollState.IsBusy then
		return {
			Ok = false,
			Changed = false,
			Code = "roll_in_progress",
			Message = "Ritual is already opening.",
			RetryAfter = rollState.RetryAfter,
			Roll = rollState,
		}
	end

	if #PetConfig.RollOrder == 0 then
		return {
			Ok = false,
			Changed = false,
			Code = "roll_table_empty",
			Message = "No pets are configured for rolling.",
		}
	end

	local crystalChanged = syncAndCollectCrystalReward(profile)

	reconcileActiveBoosts(profile)
	local runeBonuses, stats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	rollState = PlayerDerivedState.getRollCooldownState(profile, now)
	local rollLuck = PlayerDerivedState.getCurrentRollLuck(profile, stats)

	if rollState.IsBusy then
		return {
			Ok = false,
			Changed = crystalChanged == true,
			Code = "roll_state_changed",
			Message = "Ritual availability changed.",
			RetryAfter = rollState.RetryAfter,
			Roll = rollState,
		}
	end

	local petId = PetConfig.roll(rollLuck, random)

	if petId == nil then
		return {
			Ok = false,
			Changed = crystalChanged == true,
			Code = "roll_table_empty",
			Message = "No pets are configured for rolling.",
		}
	end

	profile.RollReadyAt = now + RitualStoneConfig.getRollOpeningCadence(stats.RollSpeedPercent)
	profile.Rolls = addExactIntegers(profile.Rolls, 1)
	completeOnboardingMilestone(profile, "first_roll")
	if socialPresenceService ~= nil and typeof(socialPresenceService.onFirstRoll) == "function" then
		socialPresenceService:onFirstRoll(player)
	end

	local petInstance = addPet(profile, petId)
	recordRetentionEvent(profile, "successful_pet_roll", 1)
	RitualRushProgress.awardPoints(profile, RitualRushConfig.PointSources.RollPet)
	local petFacts = PlayerDerivedState.getPetSnapshotFacts(
		petId,
		rollLuck,
		runeBonuses.PetPowerMultiplier
	)
	local petResult = {
		PetId = petInstance.PetId,
		Count = petInstance.Count,
	}

	for key, value in pairs(petFacts) do
		petResult[key] = value
	end

	return {
		Ok = true,
		Changed = true,
		Code = "pet_rolled",
		Message = "Ritual complete.",
		Pet = petResult,
		Roll = PlayerDerivedState.getRollCooldownState(profile, now),
	}
end

function PlayerStateService.buyStoneUpgrade(player, upgradeId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Changed = false,
			Code = "profile_not_ready",
			Message = "Player profile is not ready.",
		}
	end

	local initialInspection = RitualStoneProgress.inspectPurchase(profile, upgradeId)

	if initialInspection.Ok ~= true then
		return initialInspection
	end

	local crystalChanged = syncAndCollectCrystalReward(profile)
	local result = RitualStoneProgress.purchase(profile, upgradeId)

	if result.Ok ~= true then
		result.Changed = crystalChanged == true

		return result
	end

	PlayerFeedbackQueue.queue(profile, PresentationEventConfig.EventIds.StoneUpgrade, {
		UpgradeId = result.UpgradeId,
		LevelsBought = result.LevelsBought,
		Level = result.Level,
		EssenceSpent = result.EssenceSpent,
	})
	completeOnboardingMilestone(profile, "first_stone_upgrade")

	local _, updatedStats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	recordRetentionEvent(profile, "stone_or_rune_upgrade", result.LevelsBought or 1)
	collectCrystalRewardWithRush(profile, updatedStats)

	return result
end

function PlayerStateService.setPetEquippedCount(player, petId, equippedCount)
	local profile = PlayerStateService.getProfile(player)
	if profile == nil then return { Ok = false, Changed = false, Code = "profile_not_ready" } end
	local result = PetInventoryProgress.setEquippedCount(profile, petId, equippedCount)
	if result.Success ~= true then
		return { Ok = false, Changed = false, Code = result.Reason or "pet_action_failed" }
	end
	CrystalCombat.clearAttackRuntimeForSlots(profile, result.ChangedSlotIndexes)
	commitProgressRecords(profile)
	return { Ok = true, Changed = #result.ChangedSlotIndexes > 0, Code = "pet_equipped", PetId = result.PetId, EquippedCount = result.EquippedCount }
end

function PlayerStateService.unequipPet(player, petId)
	return PlayerStateService.setPetEquippedCount(player, petId, 0)
end

function PlayerStateService.equipBestPets(player)
	local profile = PlayerStateService.getProfile(player)
	if profile == nil then return { Ok = false, Changed = false, Code = "profile_not_ready" } end
	local previous = cloneArray(profile.EquippedPetIds)
	local result = PetInventoryProgress.equipBest(profile)
	if result.Success ~= true then return { Ok = false, Changed = false, Code = result.Reason or "pet_action_failed" } end
	local changedSlots = getChangedEquippedSlots(previous, profile.EquippedPetIds)
	CrystalCombat.clearAttackRuntimeForSlots(profile, changedSlots)
	commitProgressRecords(profile)
	return { Ok = true, Changed = #changedSlots > 0, Code = "pets_equipped_best", EquippedPetIds = cloneArray(profile.EquippedPetIds) }
end

function PlayerStateService.claimRetention(player, retentionId)
	local profile = PlayerStateService.getProfile(player)
	if profile == nil then return { Ok = false, Changed = false, Code = "profile_not_ready" } end
	local nowUnix = DateTime.now().UnixTimestamp
	local beforeRetention = cloneValue(profile.Retention)
	local beforePotions = cloneValue(profile.Potions)
	local beforeGems = profile.RitualGems
	local result = RetentionProgress.claim(profile, retentionId, nowUnix)
	if result.Code == "claimed" then
		commitProfileForPersistence(profile)
		local saved = ProfilePersistence.saveConfirmed(player, profile, function(data)
			local state = if typeof(data) == "table" and typeof(data.Retention) == "table" then data.Retention else nil
			return state ~= nil and ((state.DailyClaimed and state.DailyClaimed[retentionId] == true)
				or (state.PlaytimeClaimed and state.PlaytimeClaimed[retentionId] == true)
				or (state.AchievementClaimed and state.AchievementClaimed[retentionId] == true))
		end)
		if saved ~= true then
			profile.Retention = beforeRetention
			profile.Potions = beforePotions
			profile.RitualGems = beforeGems
			return { Ok = false, Changed = false, Code = "save_failed", RetryAfter = 1 }
		end
	end
	if result.Changed == true then
		profile.SnapshotRevision = addExactIntegers(profile.SnapshotRevision, 1)
	end
	return result
end

local function clearProfileLoadToken(player, loadToken)
	if profileLoadTokensByPlayer[player] ~= loadToken then
		return false
	end

	profileLoadTokensByPlayer[player] = nil

	return true
end

local function handleProfileSessionEnded(player, endedProfile, endedToken)
	local record = getProfileRecord(player)

	if record == nil or record.Profile ~= endedProfile or record.Token ~= endedToken then
		return
	end

	profileRecordsByPlayer[player] = nil

	if player.Parent == Players then
		player:Kick("Your data session ended. Please rejoin.")
	end
end

local function rejectLoadedProfile(player, profile, sessionToken, loadToken, shouldKick)
	local record = getProfileRecord(player)

	if record ~= nil and record.Profile == profile and record.Token == sessionToken then
		profileRecordsByPlayer[player] = nil
	end

	local ownedLoad = clearProfileLoadToken(player, loadToken)
	ProfilePersistence.releaseSession(player, profile, sessionToken)

	if shouldKick and ownedLoad and player.Parent == Players then
		player:Kick("Could not load your data safely. Please rejoin.")
	end
end

local function loadProfileForPlayer(player, loadToken, loadContext)
	if profileLoadTokensByPlayer[player] ~= loadToken or player.Parent ~= Players then
		return
	end

	local profile, sessionToken, loadReason = ProfilePersistence.startSession(player, handleProfileSessionEnded)

	if profile == nil then
		local ownedLoad = clearProfileLoadToken(player, loadToken)

		if ownedLoad and player.Parent == Players then
			warn("[PlayerStateService] Profile load failed:", loadReason)
			player:Kick("Could not load your data. Please rejoin.")
		end

		return
	end

	loadContext.Profile = profile
	loadContext.SessionToken = sessionToken

	if
		profileLoadTokensByPlayer[player] ~= loadToken
		or player.Parent ~= Players
		or not ProfilePersistence.isCurrent(player, profile, sessionToken)
	then
		rejectLoadedProfile(player, profile, sessionToken, loadToken, true)
		return
	end

	local initialized, initializationError = pcall(function()
		reconcilePetIds(profile)
		CrystalCombat.ensureState(profile)
		CrystalCombat.clearRuntime(profile)
		refreshAwayCheckpoint(profile, DateTime.now().UnixTimestamp)
		commitProgressRecords(profile)

		if not ProfilePersistence.sync(player, profile) then
			error("profile session ended during initialization")
		end
	end)

	if not initialized then
		warn("[PlayerStateService] Profile initialization failed:", initializationError)
		rejectLoadedProfile(player, profile, sessionToken, loadToken, true)
		return
	end

	if
		profileLoadTokensByPlayer[player] ~= loadToken
		or player.Parent ~= Players
		or getProfileRecord(player) ~= nil
		or not ProfilePersistence.isCurrent(player, profile, sessionToken)
	then
		rejectLoadedProfile(player, profile, sessionToken, loadToken, true)
		return
	end

	local record = {
		Profile = profile,
		Token = sessionToken,
	}

	profileRecordsByPlayer[player] = record
	clearProfileLoadToken(player, loadToken)

	local published, publicationError = pcall(function()
		if not PlayerStateService.isCurrentProfile(player, profile) then
			error("profile session ended before publication")
		end

		PlayerStateService.updateLeaderstatsFromProfile(player, profile)
		PlayerStateService.publishPublicVisual(player, profile)
		teleportPlayerToZone(player, profile.CurrentZone)
	end)

	if not published then
		warn("[PlayerStateService] Profile publication failed:", publicationError)

		if getProfileRecord(player) == record then
			profileRecordsByPlayer[player] = nil
		end

		ProfilePersistence.releaseSession(player, profile, sessionToken)

		if player.Parent == Players then
			player:Kick("Could not initialize your player data. Please rejoin.")
		end
	end

	if published and socialPresenceService ~= nil and typeof(socialPresenceService.profileBecameEligible) == "function" then
		socialPresenceService:profileBecameEligible(player)
	end
end

local function queueProfileLoad(player)
	if
		player == nil
		or player.Parent ~= Players
		or getProfileRecord(player) ~= nil
		or profileLoadTokensByPlayer[player] ~= nil
	then
		return false
	end

	nextProfileLoadToken += 1
	local loadToken = nextProfileLoadToken
	local loadContext = {}
	profileLoadTokensByPlayer[player] = loadToken
	task.spawn(function()
		local completed, loadError = pcall(loadProfileForPlayer, player, loadToken, loadContext)

		if completed then
			return
		end

		local profile = loadContext.Profile
		local sessionToken = loadContext.SessionToken
		local record = getProfileRecord(player)
		local ownedRecord = profile ~= nil
			and record ~= nil
			and record.Profile == profile
			and record.Token == sessionToken
		local ownedLoad = clearProfileLoadToken(player, loadToken)
		local ownedSession = profile ~= nil
			and sessionToken ~= nil
			and ProfilePersistence.isCurrent(player, profile, sessionToken)

		if ownedRecord then
			profileRecordsByPlayer[player] = nil
		end

		if profile ~= nil and sessionToken ~= nil then
			local releaseCallSucceeded, released = pcall(
				ProfilePersistence.releaseSession,
				player,
				profile,
				sessionToken
			)

			if not releaseCallSucceeded or (ownedSession and released ~= true) then
				warn("[PlayerStateService] Failed to finalize an interrupted profile load")
			end
		end

		warn("[PlayerStateService] Unexpected profile load failure:", loadError)

		if (ownedLoad or ownedRecord or ownedSession) and player.Parent == Players then
			player:Kick("Could not initialize your player data. Please rejoin.")
		end
	end)

	return true
end

local function releaseProfileForPlayer(player)
	profileLoadTokensByPlayer[player] = nil

	local record = getProfileRecord(player)

	if record == nil then
		return false
	end

	local profile = record.Profile
	local committed, commitError = pcall(function()
		replaceAwayCheckpoint(profile, DateTime.now().UnixTimestamp)
		commitProfileForPersistence(profile)
	end)

	local released = ProfilePersistence.releaseSession(player, profile, record.Token)

	if
		getProfileRecord(player) == record
		and (released or not ProfilePersistence.isCurrent(player, profile, record.Token))
	then
		profileRecordsByPlayer[player] = nil
	end

	if not committed then
		warn("[PlayerStateService] Final profile reconciliation failed:", commitError)
	end

	return released
end

function PlayerStateService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Players.PlayerAdded:Connect(function(player)
		queueProfileLoad(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local callSucceeded, releasedOrError = pcall(PlayerStateService.withProfileLock, player, function()
			return releaseProfileForPlayer(player)
		end)

		if not callSucceeded then
			warn("[PlayerStateService] Failed to release profile:", releasedOrError)
		elseif releasedOrError ~= true then
			warn("[PlayerStateService] Exact profile session was not released")
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		queueProfileLoad(player)
	end
	local SnapshotPublisher = require(script.Parent:WaitForChild("SnapshotPublisher"))

	task.spawn(function()
		while hasStarted do
			task.wait(PROFILE_SYNC_SECONDS)

			for player, record in pairs(profileRecordsByPlayer) do
				local profile = record.Profile

				task.spawn(function()
					local ok, synchronized = pcall(function()
						replaceAwayCheckpoint(profile, DateTime.now().UnixTimestamp)
						return PlayerStateService.syncProfile(player, profile)
					end)

					if not ok or synchronized ~= true then
						warn("[PlayerStateService] Periodic profile synchronization failed")
					end
				end)
			end
		end
	end)

	task.spawn(function()
		while hasStarted do
			task.wait(30)
			for player, record in pairs(profileRecordsByPlayer) do
				task.spawn(function()
					PlayerStateService.withProfileLock(player, function(profile)
						if profile == nil or not PlayerStateService.isCurrentProfile(player, profile) then return end
						local advanced = RetentionProgress.advanceActiveTime(profile, 30, DateTime.now().UnixTimestamp)
						if advanced.Changed == true then
							profile.SnapshotRevision = addExactIntegers(profile.SnapshotRevision, 1)
							local remote = Network.getRemoteEvent(Network.RemoteEvents.PlayerStateUpdated)
							SnapshotPublisher.publishPlayerStateUpdate(player, remote, { Retention = true })
						end
					end)
				end)
			end
		end
	end)
end

return PlayerStateService
