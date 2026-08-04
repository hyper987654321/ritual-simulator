local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MapGen = Shared:WaitForChild("MapGen")

local BoostConfig = require(Config:WaitForChild("BoostConfig"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local GeneratedMapRuntime = require(MapGen:WaitForChild("GeneratedMapRuntime"))
local RuneFocusProgress = require(script.Parent:WaitForChild("RuneFocusProgress"))
local RitualStoneProgress = require(script.Parent:WaitForChild("RitualStoneProgress"))

local CrystalCombat = {}

local random = Random.new()

local function getSafeInteger(value, maximum)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(math.floor(value), 0, maximum)
end

local function incrementExactInteger(value)
	local current = getSafeInteger(value, ProfileContract.MaximumExactInteger)

	return current + math.min(1, ProfileContract.MaximumExactInteger - current)
end

local function getFiniteNonNegativeNumber(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end

	return math.clamp(value, 0, ProfileContract.MaximumExactInteger)
end

local function boundedMultiply(...)
	local product = 1

	for index = 1, select("#", ...) do
		local factor = getFiniteNonNegativeNumber(select(index, ...), 0)

		if factor == 0 then
			return 0
		end

		if product >= ProfileContract.MaximumExactInteger / factor then
			return ProfileContract.MaximumExactInteger
		end

		product *= factor
	end

	return math.min(ProfileContract.MaximumExactInteger, product)
end

local function getAvailableCapacity(profile, stats)
	local capacity = getSafeInteger(
		typeof(stats) == "table" and stats.Capacity or 0,
		ProfileContract.MaximumExactInteger
	)
	local essence = getSafeInteger(profile.Essence, ProfileContract.MaximumExactInteger)

	return math.max(0, capacity - essence)
end

local function awardEssence(profile, amount, stats)
	local capacity = getSafeInteger(
		typeof(stats) == "table" and stats.Capacity or 0,
		ProfileContract.MaximumExactInteger
	)
	local previousEssence = math.min(
		capacity,
		getSafeInteger(profile.Essence, ProfileContract.MaximumExactInteger)
	)
	local reward = getSafeInteger(amount, ProfileContract.MaximumExactInteger)
	local awarded = math.min(reward, capacity - previousEssence)

	profile.Essence = previousEssence + awarded

	return awarded
end

local function createAutoCapacityContext()
	return {
		RemainingPurchases = RitualStoneConfig.AutoCapacity.MaxPurchasesPerInvocation,
		LevelsBought = 0,
		EssenceSpent = 0,
		RushPointsAwarded = 0,
		Level = 0,
	}
end

local function applyAutoCapacity(profile, stats, context)
	local autoContext = context or createAutoCapacityContext()
	local result = RitualStoneProgress.purchaseAutoCapacity(profile, {
		MaxPurchases = autoContext.RemainingPurchases,
		QueueFeedback = false,
	})

	if result.Changed == true and typeof(stats) == "table" then
		stats.Capacity = result.Capacity
	end

	autoContext.RemainingPurchases = math.max(
		0,
		autoContext.RemainingPurchases - getSafeInteger(
			result.LevelsBought,
			RitualStoneConfig.AutoCapacity.MaxPurchasesPerInvocation
		)
	)
	autoContext.LevelsBought = math.min(
		RitualStoneConfig.AutoCapacity.MaxPurchasesPerInvocation,
		autoContext.LevelsBought + getSafeInteger(
			result.LevelsBought,
			RitualStoneConfig.AutoCapacity.MaxPurchasesPerInvocation
		)
	)
	autoContext.EssenceSpent = math.min(
		ProfileContract.MaximumExactInteger,
		autoContext.EssenceSpent + math.min(
			getSafeInteger(result.EssenceSpent, ProfileContract.MaximumExactInteger),
			ProfileContract.MaximumExactInteger - autoContext.EssenceSpent
		)
	)
	autoContext.RushPointsAwarded = math.min(
		ProfileContract.MaximumExactInteger,
		autoContext.RushPointsAwarded + math.min(
			getSafeInteger(result.RushPointsAwarded, ProfileContract.MaximumExactInteger),
			ProfileContract.MaximumExactInteger - autoContext.RushPointsAwarded
		)
	)
	autoContext.Level = result.Level or autoContext.Level

	return result
end

local function applyAutoCapacityBeforeFull(profile, stats, context)
	if getAvailableCapacity(profile, stats) > 0 then
		return {
			Changed = false,
			LevelsBought = 0,
			EssenceSpent = 0,
			RushPointsAwarded = 0,
		}
	end

	return applyAutoCapacity(profile, stats, context)
end

local function getCrystalReward(zone, stats, profile)
	local runMultiplier = 1

	if typeof(stats) == "table" then
		if typeof(stats.EssenceMultiplier) == "number" then
			runMultiplier = stats.EssenceMultiplier
		elseif typeof(stats.RebirthMultiplier) == "number" then
			runMultiplier = stats.RebirthMultiplier
		end
	end

	local essenceMultiplier = 1

	if typeof(profile) == "table" then
		essenceMultiplier = BoostConfig.getActiveBoostMultiplier(
			profile.ActiveBoosts,
			BoostConfig.BoostIds.EssenceMultiplier
		)
	end

	return math.floor(boundedMultiply(zone.CrystalEssenceReward, runMultiplier, essenceMultiplier))
end

function CrystalCombat.getCurrentReward(profile, stats)
	local zone = ZoneConfig.getZone(profile.CurrentZone) or ZoneConfig.getZone(1)

	return getCrystalReward(zone, stats, profile)
end

local function createCrystalRecord(zoneId, crystalId, slotIndex)
	local zone = ZoneConfig.getZone(zoneId) or ZoneConfig.getZone(1)

	return {
		CrystalId = crystalId,
		Health = zone.CrystalHealth,
		Position = GeneratedMapRuntime.getCrystalPosition(zoneId, random, slotIndex),
	}
end

local function createCrystalState(zoneId)
	local resolvedZoneId = if ZoneConfig.getZone(zoneId) ~= nil then zoneId else 1
	local crystals = {}
	local crystalCount = ZoneConfig.getCrystalCount(resolvedZoneId)

	for index = 1, crystalCount do
		table.insert(crystals, createCrystalRecord(resolvedZoneId, index, index))
	end

	return {
		ZoneId = resolvedZoneId,
		Crystals = crystals,
		NextCrystalId = crystalCount + 1,
	}
end

local function cloneCrystalRecord(crystal, zone)
	return {
		CrystalId = crystal.CrystalId,
		Health = crystal.Health,
		MaxHealth = zone.CrystalHealth,
		Position = crystal.Position,
	}
end

local function respawnCrystal(profile, state, index)
	local crystal = createCrystalRecord(profile.CurrentZone, state.NextCrystalId, index)

	state.NextCrystalId = incrementExactInteger(state.NextCrystalId)
	state.Crystals[index] = crystal

	return crystal
end

local function getFarmingPauseReason(profile, stats)
	if getAvailableCapacity(profile, stats) > 0 then
		return nil
	end

	local canCharge, pauseReason = RuneFocusProgress.getChargeEligibility(profile)

	return if canCharge then nil else pauseReason
end

local function createUnfinalizedBreak(reason)
	return {
		Changed = false,
		Finalized = false,
		Reason = reason,
		EssenceAwarded = 0,
		ActualCrystalReward = 0,
		RuneChargeApplied = 0,
		RuneLevelsGained = 0,
		AutoCapacityLevelsBought = 0,
		AutoCapacityEssenceSpent = 0,
		AutoCapacityRushPointsAwarded = 0,
	}
end

local function finalizeBrokenCrystal(profile, stats, state, zone, index, actualReward, autoCapacityContext)
	local crystal = state.Crystals[index]

	if typeof(crystal) ~= "table" or typeof(crystal.Health) ~= "number" or crystal.Health > 0 then
		return createUnfinalizedBreak(nil)
	end

	local pauseReason = getFarmingPauseReason(profile, stats)

	if pauseReason ~= nil then
		return createUnfinalizedBreak(pauseReason)
	end

	local awardedEssence = awardEssence(profile, actualReward, stats)
	local runeResult = RuneFocusProgress.grantOnlineCrystalBreak(profile, {
		ZoneId = state.ZoneId,
		BaseCrystalReward = zone.CrystalEssenceReward,
		ActualCrystalReward = actualReward,
		EssenceAwarded = awardedEssence,
		RebirthChargeMultiplier = stats.RebirthRuneChargeMultiplier,
		AscensionChargeMultiplier = stats.AscensionRuneChargeMultiplier,
	})
	local capacityBonusGained = runeResult.CapacityBonusGained or 0

	-- A Capacity focus level changes the storage truth immediately. Keep this
	-- tick's remaining break finalizations on the same derived value.
	if
		capacityBonusGained > 0
		and typeof(stats) == "table"
		and typeof(stats.Capacity) == "number"
	then
		local currentCapacity = getSafeInteger(stats.Capacity, ProfileContract.MaximumExactInteger)
		local safeBonus = getSafeInteger(capacityBonusGained, ProfileContract.MaximumExactInteger)

		stats.Capacity = currentCapacity
			+ math.min(safeBonus, ProfileContract.MaximumExactInteger - currentCapacity)
	end

	local autoCapacityResult = if awardedEssence > 0
		then applyAutoCapacity(profile, stats, autoCapacityContext)
		else {
			Changed = false,
			LevelsBought = 0,
			EssenceSpent = 0,
			RushPointsAwarded = 0,
		}

	local brokenCrystalId = crystal.CrystalId
	local brokenPosition = crystal.Position
	local newCrystal = respawnCrystal(profile, state, index)

	return {
		Changed = true,
		Finalized = true,
		BrokenCrystalId = brokenCrystalId,
		BrokenPosition = brokenPosition,
		RespawnedCrystalId = newCrystal.CrystalId,
		EssenceAwarded = awardedEssence,
		ActualCrystalReward = actualReward,
		RuneFocusId = runeResult.FocusId,
		RuneChargeApplied = runeResult.ChargeApplied or 0,
		RuneLevelsGained = runeResult.LevelsGained or 0,
		CapacityBonusGained = capacityBonusGained,
		AutoCapacityLevelsBought = autoCapacityResult.LevelsBought or 0,
		AutoCapacityEssenceSpent = autoCapacityResult.EssenceSpent or 0,
		AutoCapacityRushPointsAwarded = autoCapacityResult.RushPointsAwarded or 0,
	}
end

local function finalizeFirstFinishedCrystal(profile, stats, state, zone, actualReward, autoCapacityContext)
	for index, crystal in ipairs(state.Crystals) do
		if typeof(crystal) == "table" and typeof(crystal.Health) == "number" and crystal.Health <= 0 then
			return finalizeBrokenCrystal(profile, stats, state, zone, index, actualReward, autoCapacityContext)
		end
	end

	return createUnfinalizedBreak(nil)
end

local function getAttackableCrystalById(state, crystalId)
	if typeof(crystalId) ~= "number" then
		return nil, nil
	end

	for index, crystal in ipairs(state.Crystals) do
		if crystal.CrystalId == crystalId and crystal.Health > 0 then
			return crystal, index
		end
	end

	return nil, nil
end

local function getRandomAttackableCrystal(state)
	local attackableCrystals = {}

	for index, crystal in ipairs(state.Crystals) do
		if crystal.Health > 0 then
			table.insert(attackableCrystals, {
				Index = index,
				Crystal = crystal,
			})
		end
	end

	if #attackableCrystals == 0 then
		return nil, nil
	end

	local target = attackableCrystals[random:NextInteger(1, #attackableCrystals)]

	return target.Crystal, target.Index
end

local function getPetTargetSnapshot(profile, state)
	local attackState = profile.CrystalAttackState
	local petTargets = {}

	if typeof(state) ~= "table" or typeof(state.Crystals) ~= "table" or typeof(attackState) ~= "table" then
		return petTargets
	end

	for slotId, _ in ipairs(profile.EquippedPetIds) do
		local attackRecord = attackState[slotId]

		if typeof(attackRecord) == "table" then
			local targetCrystal = getAttackableCrystalById(state, attackRecord.TargetCrystalId)

			if targetCrystal ~= nil then
				table.insert(petTargets, {
					PetUid = slotId,
					CrystalId = targetCrystal.CrystalId,
					Position = targetCrystal.Position,
				})
			end
		end
	end

	return petTargets
end

local function getPetAttackRecord(attackState, petUid)
	local attackRecord = attackState[petUid]

	if typeof(attackRecord) ~= "table" then
		attackRecord = {
			NextAttackAt = if typeof(attackRecord) == "number" then attackRecord else nil,
			TargetCrystalId = nil,
		}
		attackState[petUid] = attackRecord
	end

	if typeof(attackRecord.TargetCrystalId) ~= "number" then
		attackRecord.TargetCrystalId = nil
	end

	return attackRecord
end

local function assignRandomPetTarget(attackRecord, state)
	local targetCrystal, targetIndex = getRandomAttackableCrystal(state)
	local previousTargetCrystalId = attackRecord.TargetCrystalId

	if targetCrystal == nil then
		attackRecord.TargetCrystalId = nil
		return nil, nil, previousTargetCrystalId ~= nil
	end

	attackRecord.TargetCrystalId = targetCrystal.CrystalId

	return targetCrystal, targetIndex, previousTargetCrystalId ~= targetCrystal.CrystalId
end

local function getOrAssignPetTarget(attackRecord, state)
	local targetCrystal, targetIndex = getAttackableCrystalById(state, attackRecord.TargetCrystalId)

	if targetCrystal ~= nil then
		return targetCrystal, targetIndex, false
	end

	return assignRandomPetTarget(attackRecord, state)
end

local function cleanupPetAttackState(profile)
	local attackState = profile.CrystalAttackState

	if typeof(attackState) ~= "table" then
		profile.CrystalAttackState = {}
		return profile.CrystalAttackState
	end

	local equippedSlotCount = #profile.EquippedPetIds

	for slotId in pairs(attackState) do
		if typeof(slotId) ~= "number" or slotId < 1 or slotId > equippedSlotCount then
			attackState[slotId] = nil
		end
	end

	return attackState
end

local function retargetPetsTargetingCrystal(profile, state, crystalId, now)
	local attackState = profile.CrystalAttackState

	if typeof(attackState) ~= "table" then
		return false
	end

	local targetChanged = false

	for slotId, petId in ipairs(profile.EquippedPetIds) do
		local attackRecord = attackState[slotId]

		if typeof(attackRecord) == "table" and attackRecord.TargetCrystalId == crystalId then
			local _, _, didAssignTarget = assignRandomPetTarget(attackRecord, state)

			if PetConfig.getPet(petId) ~= nil then
				local interval = PetConfig.getPetAttackInterval()
				local nextAttackAt = attackRecord.NextAttackAt

				if typeof(nextAttackAt) ~= "number" then
					nextAttackAt = now
				end

				attackRecord.NextAttackAt = math.max(nextAttackAt, now + interval)
			end

			if didAssignTarget then
				targetChanged = true
			end
		end
	end

	return targetChanged
end

local function processAttacks(profile, stats, runeBonuses, now, state, zone, autoCapacityContext)
	local resolvedRuneBonuses = if typeof(runeBonuses) == "table" then runeBonuses else {}
	local reward = getCrystalReward(zone, stats, profile)
	local attackState = cleanupPetAttackState(profile)
	local attacks = {}
	local breakResults = {}
	local targetChanged = false
	local pauseReason = getFarmingPauseReason(profile, stats)

	if pauseReason ~= nil then
		return attacks, pauseReason, targetChanged, breakResults
	end

	for slotId, petId in ipairs(profile.EquippedPetIds) do
		pauseReason = getFarmingPauseReason(profile, stats)

		if pauseReason ~= nil then
			break
		end

		local pet = PetConfig.getPet(petId)

		if pet ~= nil then
			local attackRecord = getPetAttackRecord(attackState, slotId)
			local targetCrystal, targetIndex, didAssignTarget = getOrAssignPetTarget(attackRecord, state)
			local interval = PetConfig.getPetAttackInterval()
			local nextAttackAt = attackRecord.NextAttackAt

			if typeof(nextAttackAt) ~= "number" then
				nextAttackAt = now + interval
				attackRecord.NextAttackAt = nextAttackAt
				targetChanged = true
			end

			if didAssignTarget then
				targetChanged = true

				if nextAttackAt <= now then
					nextAttackAt = now + interval
					attackRecord.NextAttackAt = nextAttackAt
				end
			end

			if targetCrystal == nil then
				break
			end

			if nextAttackAt <= now then
				local damage = PetConfig.getPetDamage(petId, resolvedRuneBonuses.PetPowerMultiplier)
				local oldCrystalId = targetCrystal.CrystalId
				local oldPosition = targetCrystal.Position

				targetCrystal.Health = math.max(0, targetCrystal.Health - damage)

				local attack = {
					PetUid = slotId,
					CrystalId = oldCrystalId,
					Damage = damage,
					RemainingHealth = targetCrystal.Health,
					Position = oldPosition,
				}

				if targetCrystal.Health <= 0 then
					local breakResult = finalizeBrokenCrystal(
						profile,
						stats,
						state,
						zone,
						targetIndex,
						reward,
						autoCapacityContext
					)

					if breakResult.Finalized then
						attack.DidBreak = true
						attack.EssenceAwarded = breakResult.EssenceAwarded
						attack.RuneFocusId = breakResult.RuneFocusId
						attack.RuneChargeApplied = breakResult.RuneChargeApplied
						attack.RuneLevelsGained = breakResult.RuneLevelsGained
						attack.RespawnedCrystalId = breakResult.RespawnedCrystalId
						table.insert(breakResults, breakResult)
					else
						pauseReason = breakResult.Reason
					end
				end

				table.insert(attacks, attack)

				attackRecord.NextAttackAt = now + interval

				if attack.DidBreak == true and retargetPetsTargetingCrystal(profile, state, oldCrystalId, now) then
					targetChanged = true
				end
			end
		end
	end

	if pauseReason == nil then
		pauseReason = getFarmingPauseReason(profile, stats)
	end

	return attacks, pauseReason, targetChanged, breakResults
end

function CrystalCombat.clearRuntime(profile)
	profile.CrystalAttackState = {}
	profile.CrystalAttackSequence = 0
	profile.LastCrystalAttacks = {}
	profile.CrystalFarmingActive = false
end

function CrystalCombat.clearAttackRuntime(profile)
	profile.CrystalAttackState = {}
	profile.CrystalAttackSequence = 0
	profile.LastCrystalAttacks = {}
end

function CrystalCombat.clearAttackRuntimeForSlots(profile, slotIds)
	if typeof(slotIds) ~= "table" or #slotIds == 0 then
		return
	end

	local changedSlots = {}

	for _, slotId in ipairs(slotIds) do
		if typeof(slotId) == "number" then
			changedSlots[slotId] = true
		end
	end

	if typeof(profile.CrystalAttackState) ~= "table" then
		profile.CrystalAttackState = {}
	else
		for slotId in pairs(changedSlots) do
			profile.CrystalAttackState[slotId] = nil
		end
	end

	if typeof(profile.LastCrystalAttacks) == "table" then
		local filteredAttacks = {}

		for _, attack in ipairs(profile.LastCrystalAttacks) do
			if typeof(attack) ~= "table" or changedSlots[attack.PetUid] ~= true then
				table.insert(filteredAttacks, attack)
			end
		end

		profile.LastCrystalAttacks = filteredAttacks
	end
end

function CrystalCombat.setFarmingActive(profile, isActive)
	local wasActive = profile.CrystalFarmingActive == true
	local nextActive = isActive == true

	profile.CrystalFarmingActive = nextActive

	return wasActive ~= nextActive
end

function CrystalCombat.ensureState(profile)
	local zone = ZoneConfig.getZone(profile.CurrentZone)
	local state = profile.CrystalState

	if zone == nil then
		profile.CurrentZone = 1
		zone = ZoneConfig.getZone(1)
	end

	if state == nil or state.ZoneId ~= profile.CurrentZone then
		state = createCrystalState(profile.CurrentZone)
		profile.CrystalState = state
	end

	local crystalCount = ZoneConfig.getCrystalCount(profile.CurrentZone)

	if typeof(state.Crystals) ~= "table" then
		state.Crystals = {}
	end

	if typeof(state.NextCrystalId) ~= "number" or state.NextCrystalId < 1 then
		state.NextCrystalId = 1
	end

	for index = #state.Crystals, crystalCount + 1, -1 do
		table.remove(state.Crystals, index)
	end

	for index = 1, crystalCount do
		local crystal = state.Crystals[index]

		if typeof(crystal) ~= "table" then
			crystal = createCrystalRecord(profile.CurrentZone, state.NextCrystalId, index)
			state.NextCrystalId = incrementExactInteger(state.NextCrystalId)
			state.Crystals[index] = crystal
		end

		if typeof(crystal.CrystalId) ~= "number" then
			crystal.CrystalId = state.NextCrystalId
			state.NextCrystalId = incrementExactInteger(state.NextCrystalId)
		end

		if crystal.CrystalId >= state.NextCrystalId then
			state.NextCrystalId = incrementExactInteger(crystal.CrystalId)
		end

		if typeof(crystal.Health) ~= "number" then
			crystal.Health = zone.CrystalHealth
		end

		crystal.Health = math.clamp(crystal.Health, 0, zone.CrystalHealth)

		if typeof(crystal.Position) ~= "Vector3" or not GeneratedMapRuntime.isPositionInsideCrystalArea(profile.CurrentZone, crystal.Position, 2) then
			crystal.Position = GeneratedMapRuntime.getCrystalPosition(profile.CurrentZone, random, index)
		end
	end

	return state, zone
end

function CrystalCombat.resetState(profile, zoneId)
	profile.CrystalState = createCrystalState(zoneId or profile.CurrentZone)
	profile.CrystalAttackState = {}
	profile.LastCrystalAttacks = {}
	profile.CrystalFarmingActive = false
end

function CrystalCombat.getSnapshot(profile, stats)
	local zone = ZoneConfig.getZone(profile.CurrentZone) or ZoneConfig.getZone(1)
	local zoneId = if ZoneConfig.getZone(profile.CurrentZone) ~= nil then profile.CurrentZone else 1
	local state = profile.CrystalState
	local availableCapacity = getAvailableCapacity(profile, stats)
	local currentCrystalReward = CrystalCombat.getCurrentReward(profile, stats)
	local isFarmingActive = profile.CrystalFarmingActive == true
	local fullCapacityPauseReason = getFarmingPauseReason(profile, stats)
	local farmingPauseReason = if isFarmingActive then fullCapacityPauseReason else nil
	local canFarmForRuneCharge = availableCapacity <= 0 and fullCapacityPauseReason == nil
	local petTargets = {}
	local crystals = {}

	if typeof(state) == "table" and state.ZoneId == zoneId and typeof(state.Crystals) == "table" then
		for _, crystal in ipairs(state.Crystals) do
			table.insert(crystals, cloneCrystalRecord(crystal, zone))
		end
	end

	if isFarmingActive and farmingPauseReason == nil then
		petTargets = getPetTargetSnapshot(profile, state)
	end

	return {
		ZoneId = zoneId,
		IsFarmingActive = isFarmingActive,
		Crystals = crystals,
		CurrentCrystalReward = currentCrystalReward,
		CanStoreCurrentCrystalReward = availableCapacity > 0,
		CanFarmForRuneCharge = canFarmForRuneCharge,
		FarmingPauseReason = farmingPauseReason,
		AvailableCapacity = availableCapacity,
		MissingCapacity = math.max(0, currentCrystalReward - availableCapacity),
		AttackSequence = profile.CrystalAttackSequence or 0,
		LastAttacks = profile.LastCrystalAttacks or {},
		PetTargets = petTargets,
	}
end

function CrystalCombat.collectFinishedReward(profile, stats)
	local autoCapacityContext = createAutoCapacityContext()
	local preFullAutoCapacity = applyAutoCapacityBeforeFull(profile, stats, autoCapacityContext)
	local state, zone = CrystalCombat.ensureState(profile)
	local reward = getCrystalReward(zone, stats, profile)
	local breakResult = finalizeFirstFinishedCrystal(profile, stats, state, zone, reward, autoCapacityContext)

	breakResult.Changed = breakResult.Changed == true or preFullAutoCapacity.Changed == true
	breakResult.AutoCapacityLevelsBought = autoCapacityContext.LevelsBought
	breakResult.AutoCapacityEssenceSpent = autoCapacityContext.EssenceSpent
	breakResult.AutoCapacityRushPointsAwarded = autoCapacityContext.RushPointsAwarded
	RitualStoneProgress.queueAutoCapacityFeedback(profile, autoCapacityContext)

	return breakResult
end

function CrystalCombat.step(profile, stats, runeBonuses, now)
	local beforeEssence = getSafeInteger(profile.Essence, ProfileContract.MaximumExactInteger)
	local autoCapacityContext = createAutoCapacityContext()
	local preFullAutoCapacity = applyAutoCapacityBeforeFull(profile, stats, autoCapacityContext)
	local stateBefore, zoneBefore = CrystalCombat.ensureState(profile)
	local beforeZoneId = stateBefore.ZoneId
	local beforeNextCrystalId = stateBefore.NextCrystalId
	local hadLastAttacks = typeof(profile.LastCrystalAttacks) == "table" and #profile.LastCrystalAttacks > 0
	local reward = getCrystalReward(zoneBefore, stats, profile)
	local recoveredBreak = finalizeFirstFinishedCrystal(
		profile,
		stats,
		stateBefore,
		zoneBefore,
		reward,
		autoCapacityContext
	)
	local breakResults = {}
	local attacks = {}
	local reason = recoveredBreak.Reason
	local targetChanged = false

	if recoveredBreak.Finalized then
		table.insert(breakResults, recoveredBreak)
	end

	if reason == nil then
		local attackBreakResults

		attacks, reason, targetChanged, attackBreakResults = processAttacks(
			profile,
			stats,
			runeBonuses,
			now,
			stateBefore,
			zoneBefore,
			autoCapacityContext
		)

		for _, breakResult in ipairs(attackBreakResults) do
			table.insert(breakResults, breakResult)
		end
	end

	local stateAfter = CrystalCombat.ensureState(profile)
	local didChangeCrystal = beforeZoneId ~= stateAfter.ZoneId or beforeNextCrystalId ~= stateAfter.NextCrystalId
	local didChangeEssence = beforeEssence ~= profile.Essence
	local runeChargeApplied = 0
	local runeLevelsGained = 0

	for _, breakResult in ipairs(breakResults) do
		runeChargeApplied = math.min(
			ProfileContract.MaximumExactInteger,
			runeChargeApplied + math.min(
				getSafeInteger(breakResult.RuneChargeApplied, ProfileContract.MaximumExactInteger),
				ProfileContract.MaximumExactInteger - runeChargeApplied
			)
		)
		runeLevelsGained = math.min(
			ProfileContract.MaximumExactInteger,
			runeLevelsGained + math.min(
				getSafeInteger(breakResult.RuneLevelsGained, ProfileContract.MaximumExactInteger),
				ProfileContract.MaximumExactInteger - runeLevelsGained
			)
		)
	end

	RitualStoneProgress.queueAutoCapacityFeedback(profile, autoCapacityContext)

	if #attacks > 0 then
		profile.CrystalAttackSequence = incrementExactInteger(profile.CrystalAttackSequence)
	end

	profile.LastCrystalAttacks = attacks

	return {
		Changed = didChangeCrystal
			or didChangeEssence
			or preFullAutoCapacity.Changed == true
			or targetChanged == true
			or #attacks > 0
			or #breakResults > 0
			or (hadLastAttacks and #attacks == 0),
		Reason = reason,
		ZoneId = stateAfter.ZoneId,
		AttackCount = #attacks,
		BreakCount = #breakResults,
		RuneChargeApplied = runeChargeApplied,
		RuneLevelsGained = runeLevelsGained,
		AutoCapacityLevelsBought = autoCapacityContext.LevelsBought,
		AutoCapacityEssenceSpent = autoCapacityContext.EssenceSpent,
		AutoCapacityRushPointsAwarded = autoCapacityContext.RushPointsAwarded,
	}
end

return CrystalCombat
