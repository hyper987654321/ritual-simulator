local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MapGen = Shared:WaitForChild("MapGen")

local AscensionConfig = require(Config:WaitForChild("AscensionConfig"))
local BoostConfig = require(Config:WaitForChild("BoostConfig"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local PotionConfig = require(Config:WaitForChild("PotionConfig"))
local RitualRushConfig = require(Config:WaitForChild("RitualRushConfig"))
local ShopProductConfig = require(Config:WaitForChild("ShopProductConfig"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local RuneConfig = require(Config:WaitForChild("RuneConfig"))
local TutorialConfig = require(Config:WaitForChild("TutorialConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local GeneratedMapRuntime = require(MapGen:WaitForChild("GeneratedMapRuntime"))
local LeaderstatsService = require(script.Parent:WaitForChild("LeaderstatsService"))
local ProfilePersistence = require(script.Parent:WaitForChild("ProfilePersistence"))
local PlayerPublicVisualSignal = require(script.Parent:WaitForChild("PlayerPublicVisualSignal"))
local PlayerDerivedState = require(script.Parent:WaitForChild("PlayerDerivedState"))
local CrystalCombat = require(script.Parent.Parent:WaitForChild("Ritual"):WaitForChild("CrystalCombat"))
local RitualRushProgress = require(script.Parent.Parent:WaitForChild("Ritual"):WaitForChild("RitualRushProgress"))

local PlayerStateService = {}

local PROFILE_LOAD_TIMEOUT_SECONDS = 10
local AUTOSAVE_SECONDS = 60

local profilesByPlayer = {}
local profileOperationQueuesByPlayer = {}
local random = Random.new()
local hasStarted = false

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

local function createDefaultRuneLevels()
	return {
		capacity = 0,
		luck = 0,
		ritual_speed = 0,
		pet_power = 0,
	}
end

local function getNonNegativeInteger(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.max(0, math.floor(value))
end

local function getPetCount(profile, petId)
	return math.max(0, math.floor(profile.Pets[petId] or 0))
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

			reconciledPets[resolvedPetId] = (reconciledPets[resolvedPetId] or 0) + safeCount

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

	profile.BestRitualPower = math.max(profile.BestRitualPower or 0, ritualPower)
	profile.HighestCapacity = math.max(profile.HighestCapacity or 0, stats.Capacity)

	if rarestPetScore > (profile.RarestPetScore or 0) then
		profile.RarestPetId = rarestPetId
		profile.RarestPetScore = rarestPetScore
	end
end

local function ensureTutorialCompletedSteps(profile)
	if profile.TutorialCompletedSteps == nil then
		profile.TutorialCompletedSteps = {}
	end

	return profile.TutorialCompletedSteps
end

local function completeTutorialStep(profile, stepId)
	if not TutorialConfig.isStepId(stepId) then
		return false
	end

	local completedSteps = ensureTutorialCompletedSteps(profile)

	if completedSteps[stepId] == true then
		return false
	end

	completedSteps[stepId] = true

	return true
end

local function completeTutorialThroughStep(profile, stepId)
	local stepIndex = TutorialConfig.getStepIndex(stepId)

	if stepIndex == nil then
		return false
	end

	local didComplete = false

	for index, orderedStepId in ipairs(TutorialConfig.StepOrder) do
		if index > stepIndex then
			break
		end

		didComplete = completeTutorialStep(profile, orderedStepId) or didComplete
	end

	return didComplete
end

local function backfillTutorialProgress(profile)
	if profile.Rebirths > 0 then
		completeTutorialThroughStep(profile, TutorialConfig.StepIds.FirstRebirth)
	elseif RitualStoneConfig.getTotalUpgradeLevels(profile.StoneLevels) > 0 then
		completeTutorialThroughStep(profile, TutorialConfig.StepIds.FirstStoneUpgrade)
	elseif profile.Rolls > 0 then
		completeTutorialThroughStep(profile, TutorialConfig.StepIds.FirstRoll)
	end
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
	local count = getPetCount(profile, petId) + 1

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

local function commitProgressRecords(profile)
	local _, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local ritualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths)

	updateProgressRecords(profile, stats, ritualPower)

	return stats, equippedPetPower, ritualPower
end

local function commitProfileForPersistence(profile)
	local didReconcilePets = reconcilePetIds(profile)
	local _, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local ritualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths)

	CrystalCombat.ensureState(profile)
	if didReconcilePets then
		CrystalCombat.clearAttackRuntime(profile)
	end
	RitualRushProgress.ensureProgress(profile)
	profile.ActiveBoosts = BoostConfig.normalizeActiveBoosts(profile.ActiveBoosts)
	profile.Potions = PotionConfig.normalizeInventory(profile.Potions)
	profile.Ascensions = getNonNegativeInteger(profile.Ascensions)
	profile.AscensionStars = getNonNegativeInteger(profile.AscensionStars)
	profile.AscensionUpgrades = if typeof(profile.AscensionUpgrades) == "table" then profile.AscensionUpgrades else {}
	updateProgressRecords(profile, stats, ritualPower)

	return stats, equippedPetPower, ritualPower
end

local function collectCrystalRewardWithRush(profile, stats)
	local didCollect, awardedEssence, reward = CrystalCombat.collectFinishedReward(profile, stats)

	if didCollect == true and awardedEssence > 0 and reward > 0 then
		RitualRushProgress.awardPoints(profile, RitualRushConfig.PointSources.CrystalBroken)
	end

	return didCollect, awardedEssence, reward
end

local function syncAndCollectCrystalReward(profile)
	local _, stats = PlayerDerivedState.getCurrentRitualRuntime(profile)

	return collectCrystalRewardWithRush(profile, stats)
end

local function getAvailableEssenceCapacity(profile, stats)
	local capacity = if typeof(stats) == "table" and typeof(stats.Capacity) == "number" then stats.Capacity else 0
	local essence = if typeof(profile.Essence) == "number" then profile.Essence else 0

	return math.max(0, capacity - math.max(0, math.floor(essence)))
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

local function reconcilePotions(profile)
	profile.Potions = PotionConfig.normalizeInventory(profile.Potions)

	return profile.Potions
end

local function applyRitualGemGrant(profile, ritualGems)
	local amount = getPositiveInteger(ritualGems)

	if amount == nil then
		return 0
	end

	profile.RitualGems = math.max(0, math.floor(profile.RitualGems or 0)) + amount

	return amount
end

local function applyRitualRushPremiumGrant(profile)
	local progress = RitualRushProgress.ensureProgress(profile)

	if progress == nil then
		return false
	end

	progress.PremiumUnlocked = true

	return true
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
	local reward = {}
	local didGrant = false

	local ritualGemsGranted = applyRitualGemGrant(profile, grant.RitualGems)

	if ritualGemsGranted > 0 then
		reward.RitualGems = ritualGemsGranted
		didGrant = true
	end

	if grant.RitualRushPremium == true then
		if not applyRitualRushPremiumGrant(profile) then
			return false, "RitualRushProgressMissing"
		end

		reward.RitualRushPremium = true
		didGrant = true
	end

	if grant.Boost ~= nil then
		local didApplyBoost, boostReward = applyBoostGrant(profile, grant.Boost)

		if not didApplyBoost then
			return false, boostReward
		end

		reward.Boost = boostReward
		didGrant = true
	end

	if not didGrant then
		return false, "ProductGrantEmpty"
	end

	return true, reward
end

local function saveProfileForPurchase(player, profile)
	local success, result = pcall(function()
		commitProfileForPersistence(profile)

		return ProfilePersistence.save(player, profile)
	end)

	return success and result == true
end

local function applyRitualRushReward(profile, reward, stats)
	local essenceReward = math.max(0, math.floor(reward.Essence or 0))
	local ritualGemsAwarded = math.max(0, math.floor(reward.RitualGems or 0))
	local potionRewards = {}

	local essenceAwarded = 0

	if essenceReward > 0 then
		essenceAwarded = math.min(essenceReward, getAvailableEssenceCapacity(profile, stats))
		profile.Essence = math.max(0, math.floor(profile.Essence or 0)) + essenceAwarded
	end

	if ritualGemsAwarded > 0 then
		profile.RitualGems = math.max(0, math.floor(profile.RitualGems or 0)) + ritualGemsAwarded
	end

	if typeof(reward.Potions) == "table" then
		for _, potionGrant in ipairs(reward.Potions) do
			local didApplyPotion, potionReward = applyPotionGrant(profile, potionGrant)

			if didApplyPotion then
				table.insert(potionRewards, potionReward)
			end
		end
	end

	return {
		Essence = essenceAwarded,
		RitualGems = ritualGemsAwarded,
		Potions = potionRewards,
	}
end

local function hasRitualRushRewardValue(reward)
	if typeof(reward) ~= "table" then
		return false
	end

	local potionCount = if typeof(reward.Potions) == "table" then #reward.Potions else 0

	return (reward.Essence or 0) > 0 or (reward.RitualGems or 0) > 0 or potionCount > 0
end

local function addRitualRushReward(totalReward, reward)
	totalReward.Essence += math.max(0, math.floor(reward.Essence or 0))
	totalReward.RitualGems += math.max(0, math.floor(reward.RitualGems or 0))

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

function PlayerStateService.getProfile(player)
	return profilesByPlayer[player]
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

	local ok, result = pcall(callback)

	table.remove(queue, 1)

	if #queue == 0 then
		profileOperationQueuesByPlayer[player] = nil
	end

	if not ok then
		error(result, 2)
	end

	return result
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

function PlayerStateService.getSnapshot(player)
	local profile = PlayerStateService.getProfile(player)

	return PlayerDerivedState.getSnapshot(profile)
end

function PlayerStateService.getPublicVisual(player)
	local profile = PlayerStateService.getProfile(player)

	return PlayerDerivedState.getPublicVisual(profile)
end

function PlayerStateService.publishPublicVisual(player)
	local publicVisual = PlayerStateService.getPublicVisual(player)

	if publicVisual == nil then
		return nil
	end

	PlayerPublicVisualSignal.fire(player, publicVisual)

	return publicVisual
end

function PlayerStateService.getCrystalUpdate(player)
	local profile = PlayerStateService.getProfile(player)

	return PlayerDerivedState.getCrystalUpdate(profile)
end

function PlayerStateService.updateLeaderstatsFromProfile(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return false
	end

	local leaderstatsPayload = PlayerDerivedState.getLeaderstatsPayload(profile)

	return LeaderstatsService.update(player, leaderstatsPayload)
end

function PlayerStateService.subscribePublicVisualChanged(listener)
	return PlayerPublicVisualSignal.subscribe(listener)
end

function PlayerStateService.advanceSnapshotRevision(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return nil
	end

	profile.SnapshotRevision = (profile.SnapshotRevision or 0) + 1

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

	if ok then
		CrystalCombat.ensureState(profile)
	end

	return {
		Ok = ok,
		Changed = zoneChanged or activeChanged,
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
	local farmingStep = CrystalCombat.step(profile, stats, runeBonuses, now)
	local rushPointsAwarded = 0

	if (farmingStep.BreakCount or 0) > 0 then
		rushPointsAwarded = RitualRushProgress.awardPoints(
			profile,
			RitualRushConfig.PointSources.CrystalBroken,
			farmingStep.BreakCount
		)
	end

	return {
		Ok = true,
		Changed = farmingStep.Changed == true or rushPointsAwarded > 0,
		Reason = farmingStep.Reason,
		ZoneId = farmingStep.ZoneId,
		AttackCount = farmingStep.AttackCount,
		BreakCount = farmingStep.BreakCount,
	}
end

function PlayerStateService.syncProfile(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return false
	end

	commitProfileForPersistence(profile)

	return ProfilePersistence.sync(player, profile)
end

function PlayerStateService.savePlayer(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return false
	end

	commitProfileForPersistence(profile)

	return ProfilePersistence.save(player, profile)
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

	if typeof(purchaseId) ~= "string" or purchaseId == "" then
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

	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Reason = "ProfileNotReady",
		}
	end

	local processedPurchaseIds = ensureProcessedPurchaseIds(profile)

	if processedPurchaseIds[purchaseId] == true then
		if not saveProfileForPurchase(player, profile) then
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
	profile.SnapshotRevision = (profile.SnapshotRevision or 0) + 1

	if not saveProfileForPurchase(player, profile) then
		return {
			Ok = false,
			Reason = "ProfileSaveFailed",
			ShopProductId = product.ShopProductId,
			RobloxProductId = productRobloxProductId,
		}
	end

	PlayerStateService.updateLeaderstatsFromProfile(player)
	PlayerStateService.publishPublicVisual(player)

	return {
		Ok = true,
		ShopProductId = product.ShopProductId,
		RobloxProductId = productRobloxProductId,
		Reward = reward,
	}
end

function PlayerStateService.completeTutorialStep(player, stepId, completionMode)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Message = "Player profile is not ready.",
		}
	end

	if typeof(stepId) ~= "string" or not TutorialConfig.isStepId(stepId) then
		return {
			Ok = false,
			Message = "Invalid tutorial step.",
		}
	end

	local resolvedCompletionMode = completionMode or TutorialConfig.CompletionModes.Complete

	if
		resolvedCompletionMode ~= TutorialConfig.CompletionModes.Complete
		and resolvedCompletionMode ~= TutorialConfig.CompletionModes.Skip
	then
		return {
			Ok = false,
			Message = "Invalid tutorial completion mode.",
		}
	end

	local completedSteps = ensureTutorialCompletedSteps(profile)

	if completedSteps[stepId] == true then
		return {
			Ok = true,
		}
	end

	if TutorialConfig.getNextStepId(completedSteps) ~= stepId then
		return {
			Ok = false,
			Message = "Tutorial step is not active.",
		}
	end

	if resolvedCompletionMode == TutorialConfig.CompletionModes.Skip then
		if not TutorialConfig.isSkippable(stepId) then
			return {
				Ok = false,
				Message = "Tutorial step cannot be skipped.",
			}
		end

		completeTutorialStep(profile, stepId)

		return {
			Ok = true,
			Message = "Tutorial skipped.",
		}
	end

	if not TutorialConfig.isClientCompletable(stepId) then
		return {
			Ok = false,
			Message = "Tutorial step is completed by gameplay.",
		}
	end

	completeTutorialStep(profile, stepId)

	return {
		Ok = true,
	}
end

function PlayerStateService.claimRitualRushReward(player, milestoneId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Message = "Player profile is not ready.",
		}
	end

	if typeof(milestoneId) ~= "string" then
		return {
			Ok = false,
			Message = "Invalid Ritual Rush reward.",
		}
	end

	local milestone = RitualRushConfig.getMilestone(milestoneId)

	if milestone == nil then
		return {
			Ok = false,
			Message = "Ritual Rush reward is not configured.",
		}
	end

	syncAndCollectCrystalReward(profile)

	local progress = RitualRushProgress.ensureProgress(profile)

	if progress.Points < milestone.RequiredPoints then
		return {
			Ok = false,
			Message = "Ritual Rush milestone is locked.",
			MilestoneId = milestone.MilestoneId,
		}
	end

	local claimedTracks = {}
	local totalReward = {
		Essence = 0,
		RitualGems = 0,
		Potions = {},
	}

	if progress.ClaimedFreeMilestones[milestone.MilestoneId] ~= true then
		if not hasRitualRushRewardValue(milestone.FreeReward) then
			return {
				Ok = false,
				Message = "Ritual Rush reward is not configured.",
				MilestoneId = milestone.MilestoneId,
			}
		end

		addRitualRushReward(totalReward, milestone.FreeReward)
		claimedTracks.Free = true
	end

	if progress.PremiumUnlocked == true and progress.ClaimedPremiumMilestones[milestone.MilestoneId] ~= true then
		if not hasRitualRushRewardValue(milestone.PremiumReward) then
			return {
				Ok = false,
				Message = "Ritual Rush reward is not configured.",
				MilestoneId = milestone.MilestoneId,
			}
		end

		addRitualRushReward(totalReward, milestone.PremiumReward)
		claimedTracks.Premium = true
	end

	if claimedTracks.Free ~= true and claimedTracks.Premium ~= true then
		return {
			Ok = false,
			Message = "Ritual Rush reward is already claimed.",
			MilestoneId = milestone.MilestoneId,
		}
	end

	local _, stats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local appliedReward = applyRitualRushReward(profile, totalReward, stats)

	if claimedTracks.Free == true then
		progress.ClaimedFreeMilestones[milestone.MilestoneId] = true
	end

	if claimedTracks.Premium == true then
		progress.ClaimedPremiumMilestones[milestone.MilestoneId] = true
	end

	return {
		Ok = true,
		Message = "Ritual Rush reward claimed.",
		MilestoneId = milestone.MilestoneId,
		ClaimedTracks = claimedTracks,
		Reward = appliedReward,
	}
end

function PlayerStateService.claimRitualRushFreeReward(player, milestoneId)
	return PlayerStateService.claimRitualRushReward(player, milestoneId)
end

function PlayerStateService.usePotion(player, potionId)
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

	reconcilePotions(profile)

	local potion = PotionConfig.getPotion(potionId)

	if potion == nil then
		return {
			Ok = false,
			Message = "Potion is not configured.",
		}
	end

	local boostGrant = PotionConfig.getPotionBoostGrant(potion.PotionId)

	if boostGrant == nil then
		return {
			Ok = false,
			Message = "Potion effect is not configured.",
			PotionId = potion.PotionId,
		}
	end

	syncAndCollectCrystalReward(profile)

	local didConsumePotion, consumeResult, potions = PotionConfig.consumePotion(profile.Potions, potion.PotionId)
	profile.Potions = potions

	if not didConsumePotion then
		local message = if consumeResult == "PotionNotOwned" then "You do not own this potion." else "Potion cannot be used."

		return {
			Ok = false,
			Message = message,
			PotionId = potion.PotionId,
		}
	end

	local didApplyBoost, boostReward = applyBoostGrant(profile, boostGrant)

	if not didApplyBoost then
		applyPotionGrant(profile, {
			PotionId = potion.PotionId,
			Count = 1,
		})

		return {
			Ok = false,
			Message = "Potion effect could not be applied.",
			PotionId = potion.PotionId,
		}
	end

	local remainingCount = profile.Potions[potion.PotionId] or 0

	return {
		Ok = true,
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

	reconcilePotions(profile)

	local potion = PotionConfig.getPotion(potionId)

	if potion == nil or potion.IsShopEnabled ~= true then
		return {
			Ok = false,
			Message = "Potion is not available.",
		}
	end

	local gemCost = getPositiveInteger(potion.GemCost)

	if gemCost == nil then
		return {
			Ok = false,
			Message = "Potion price is not configured.",
			PotionId = potion.PotionId,
		}
	end

	local ritualGems = math.max(0, math.floor(profile.RitualGems or 0))

	if ritualGems < gemCost then
		return {
			Ok = false,
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
		profile.RitualGems += gemCost

		return {
			Ok = false,
			Message = "Potion could not be added.",
			PotionId = potion.PotionId,
		}
	end

	return {
		Ok = true,
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
			Message = "Player profile is not ready.",
		}
	end

	syncAndCollectCrystalReward(profile)

	local rebirthRequirement = RitualStoneConfig.getRebirthRequirement(profile.Rebirths)

	if not PlayerDerivedState.canRebirth(profile, rebirthRequirement) then
		return {
			Ok = false,
			Message = "Rebirth requirement is not met.",
		}
	end

	profile.Rebirths += 1
	completeTutorialThroughStep(profile, TutorialConfig.StepIds.FirstRebirth)
	RitualRushProgress.awardPoints(profile, RitualRushConfig.PointSources.Rebirth)
	profile.Essence = 0
	profile.CurrentZone = 1
	profile.UnlockedZones = {
		[1] = true,
	}
	profile.StoneLevels = createDefaultStoneLevels()
	CrystalCombat.resetState(profile, 1)
	CrystalCombat.setFarmingActive(profile, false)
	task.defer(teleportPlayerToZone, player, 1)

	return {
		Ok = true,
		Message = "Rebirth complete. Permanent power increased.",
	}
end

function PlayerStateService.ascend(player)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Message = "Player profile is not ready.",
		}
	end

	syncAndCollectCrystalReward(profile)

	local ascension = AscensionConfig.getSnapshot(profile)

	if ascension.RequiredZoneExists ~= true then
		return {
			Ok = false,
			Message = "The next Ascension zone is not available yet.",
			Ascension = ascension,
		}
	end

	if ascension.CanAscend ~= true then
		return {
			Ok = false,
			Message = "Reach Zone " .. tostring(ascension.RequiredZone) .. " to ascend.",
			Ascension = ascension,
		}
	end

	if not isPositionNearAscensionStatue(ascension.RequiredZone, getLivingCharacterRootPosition(player)) then
		return {
			Ok = false,
			Message = "Move closer to the Ascension Statue.",
			Ascension = ascension,
		}
	end

	local currentAscensions = getNonNegativeInteger(profile.Ascensions)
	local nextAscensions = currentAscensions + 1
	local starReward = AscensionConfig.getStarReward(currentAscensions)

	profile.Ascensions = nextAscensions
	profile.AscensionStars = getNonNegativeInteger(profile.AscensionStars) + starReward
	profile.Essence = 0
	profile.CurrentZone = 1
	profile.UnlockedZones = {
		[1] = true,
	}
	profile.StoneLevels = createDefaultStoneLevels()
	profile.RuneLevels = createDefaultRuneLevels()

	CrystalCombat.resetState(profile, 1)
	CrystalCombat.setFarmingActive(profile, false)
	task.defer(teleportPlayerToZone, player, 1)

	return {
		Ok = true,
		Message = "Ascension complete. Your next run is stronger.",
		Ascension = AscensionConfig.getSnapshot(profile),
		StarReward = starReward,
	}
end

function PlayerStateService.buyRune(player, runeId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Message = "Player profile is not ready.",
		}
	end

	if typeof(runeId) ~= "string" then
		return {
			Ok = false,
			Message = "Invalid rune upgrade request.",
		}
	end

	if not RuneConfig.canUseRunes(profile.UnlockedZones, profile.Rebirths) then
		return {
			Ok = false,
			Message = "Runes unlock in Zone 3 after your first Rebirth.",
		}
	end

	local rune = RuneConfig.getRune(runeId)

	if rune == nil then
		return {
			Ok = false,
			Message = "Rune is not configured.",
		}
	end

	syncAndCollectCrystalReward(profile)

	local level = profile.RuneLevels[runeId] or 0

	if level >= rune.MaxLevel then
		return {
			Ok = false,
			Message = "Rune is already maxed.",
		}
	end

	local cost = RuneConfig.getUpgradeCost(runeId, level)

	if profile.Essence < cost then
		return {
			Ok = false,
			Message = "Not enough Ritual Essence.",
		}
	end

	profile.Essence -= cost
	profile.RuneLevels[runeId] = level + 1

	local _, updatedStats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	collectCrystalRewardWithRush(profile, updatedStats)

	return {
		Ok = true,
		Message = "Rune upgraded.",
	}
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

	profile.Essence -= zone.UnlockCost
	profile.UnlockedZones[zoneId] = true
	RitualRushProgress.awardPoints(profile, RitualRushConfig.PointSources.UnlockZone)

	return {
		Ok = true,
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
			Message = "Player profile is not ready.",
		}
	end

	local now = os.clock()

	local _, stats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local rollState = PlayerDerivedState.getRollState(profile, now)

	if rollState.IsBusy then
		return {
			Ok = false,
			Message = "Ritual is already opening.",
			RetryAfter = rollState.RetryAfter,
			Roll = rollState,
		}
	end

	syncAndCollectCrystalReward(profile)

	local activeBoosts = reconcileActiveBoosts(profile)
	local rollLuckMultiplier = BoostConfig.getActiveBoostMultiplier(activeBoosts, BoostConfig.BoostIds.LuckMultiplier)
	local rollLuck = stats.Luck * rollLuckMultiplier
	local petId = PetConfig.roll(rollLuck, random)

	if petId == nil then
		return {
			Ok = false,
			Message = "No pets are configured for rolling.",
		}
	end

	profile.RollReadyAt = now + RitualStoneConfig.getRollOpeningCadence(stats.RollSpeedPercent)
	profile.Rolls += 1
	completeTutorialThroughStep(profile, TutorialConfig.StepIds.FirstRoll)

	local petInstance = addPet(profile, petId)
	RitualRushProgress.awardPoints(profile, RitualRushConfig.PointSources.RollPet)

	return {
		Ok = true,
		Message = "Ritual complete.",
		Pet = {
			PetId = petInstance.PetId,
			Count = petInstance.Count,
		},
		Roll = PlayerDerivedState.getRollState(profile, now),
	}
end

function PlayerStateService.buyStoneUpgrade(player, upgradeId)
	local profile = PlayerStateService.getProfile(player)

	if profile == nil then
		return {
			Ok = false,
			Message = "Player profile is not ready.",
		}
	end

	if RitualStoneConfig.Upgrades[upgradeId] == nil then
		return {
			Ok = false,
			Message = "Unknown stone upgrade.",
		}
	end

	local currentLevel = profile.StoneLevels[upgradeId] or 0
	local cost = RitualStoneConfig.getUpgradeCost(upgradeId, currentLevel)

	syncAndCollectCrystalReward(profile)

	if profile.Essence < cost then
		return {
			Ok = false,
			Message = "Not enough Ritual Essence.",
		}
	end

	profile.Essence -= cost
	profile.StoneLevels[upgradeId] = currentLevel + 1
	completeTutorialThroughStep(profile, TutorialConfig.StepIds.FirstStoneUpgrade)
	RitualRushProgress.awardPoints(profile, RitualRushConfig.PointSources.BuyStoneUpgrade)

	local _, updatedStats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	collectCrystalRewardWithRush(profile, updatedStats)

	return {
		Ok = true,
		Message = "Ritual Stone upgraded.",
		UpgradeId = upgradeId,
	}
end

local function handleProfileSessionEnded(player)
	profilesByPlayer[player] = nil

	if player.Parent == Players then
		player:Kick("Your data session ended. Please rejoin.")
	end
end

local function loadProfileForPlayer(player)
	local profile = ProfilePersistence.startSession(player, handleProfileSessionEnded)

	if player.Parent ~= Players then
		ProfilePersistence.releaseSession(player)
		return
	end

	if profile == nil then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	reconcilePetIds(profile)
	backfillTutorialProgress(profile)
	CrystalCombat.ensureState(profile)
	CrystalCombat.clearRuntime(profile)
	commitProgressRecords(profile)
	ProfilePersistence.sync(player, profile)

	profilesByPlayer[player] = profile
	PlayerStateService.updateLeaderstatsFromProfile(player)
	PlayerStateService.publishPublicVisual(player)
	teleportPlayerToZone(player, profile.CurrentZone)
end

local function releaseProfileForPlayer(player)
	local profile = profilesByPlayer[player]

	if profile ~= nil then
		commitProfileForPersistence(profile)
	end

	profilesByPlayer[player] = nil
	ProfilePersistence.releaseSession(player, profile)
end

function PlayerStateService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfileForPlayer, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local ok, err = pcall(PlayerStateService.withProfileLock, player, function()
			releaseProfileForPlayer(player)
		end)

		if not ok then
			warn("[PlayerStateService] Failed to release profile:", err)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadProfileForPlayer, player)
	end

	task.spawn(function()
		while hasStarted do
			task.wait(AUTOSAVE_SECONDS)

			for player in pairs(profilesByPlayer) do
				local ok, err = pcall(PlayerStateService.withProfileLock, player, function()
					PlayerStateService.savePlayer(player)
				end)

				if not ok then
					warn("[PlayerStateService] Autosave failed:", err)
				end
			end
		end
	end)
end

return PlayerStateService
