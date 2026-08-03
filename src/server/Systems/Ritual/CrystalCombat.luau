local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MapGen = Shared:WaitForChild("MapGen")

local BoostConfig = require(Config:WaitForChild("BoostConfig"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local GeneratedMapRuntime = require(MapGen:WaitForChild("GeneratedMapRuntime"))

local CrystalCombat = {}

local random = Random.new()

local function getAvailableCapacity(profile, stats)
	local capacity = if typeof(stats) == "table" and typeof(stats.Capacity) == "number" then stats.Capacity else 0

	return math.max(0, capacity - profile.Essence)
end

local function awardEssence(profile, amount, stats)
	local previousEssence = profile.Essence
	local capacity = if typeof(stats) == "table" and typeof(stats.Capacity) == "number" then stats.Capacity else 0

	profile.Essence = math.min(capacity, profile.Essence + math.max(0, amount))

	return profile.Essence - previousEssence
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

	return math.floor(zone.CrystalEssenceReward * runMultiplier * essenceMultiplier)
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

	state.NextCrystalId += 1
	state.Crystals[index] = crystal

	return crystal
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

local function processAttacks(profile, stats, runeBonuses, now, state, zone)
	local resolvedRuneBonuses = if typeof(runeBonuses) == "table" then runeBonuses else {}
	local reward = getCrystalReward(zone, stats, profile)
	local attackState = cleanupPetAttackState(profile)
	local attacks = {}
	local targetChanged = false

	if getAvailableCapacity(profile, stats) <= 0 then
		return attacks, "StoneCapacityFull", targetChanged
	end

	for slotId, petId in ipairs(profile.EquippedPetIds) do
		if getAvailableCapacity(profile, stats) <= 0 then
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
					local awarded = awardEssence(profile, reward, stats)
					local newCrystal = respawnCrystal(profile, state, targetIndex)

					attack.DidBreak = true
					attack.EssenceAwarded = awarded
					attack.RespawnedCrystalId = newCrystal.CrystalId
				end

				table.insert(attacks, attack)

				attackRecord.NextAttackAt = now + interval

				if attack.DidBreak == true and retargetPetsTargetingCrystal(profile, state, oldCrystalId, now) then
					targetChanged = true
				end
			end
		end
	end

	return attacks, nil, targetChanged
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
			state.NextCrystalId += 1
			state.Crystals[index] = crystal
		end

		if typeof(crystal.CrystalId) ~= "number" then
			crystal.CrystalId = state.NextCrystalId
			state.NextCrystalId += 1
		end

		if crystal.CrystalId >= state.NextCrystalId then
			state.NextCrystalId = crystal.CrystalId + 1
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
	local currentCrystalReward = getCrystalReward(zone, stats, profile)
	local isFarmingActive = profile.CrystalFarmingActive == true
	local petTargets = {}
	local crystals = {}

	if typeof(state) == "table" and state.ZoneId == zoneId and typeof(state.Crystals) == "table" then
		for _, crystal in ipairs(state.Crystals) do
			table.insert(crystals, cloneCrystalRecord(crystal, zone))
		end
	end

	if isFarmingActive and availableCapacity > 0 then
		petTargets = getPetTargetSnapshot(profile, state)
	end

	return {
		ZoneId = zoneId,
		IsFarmingActive = isFarmingActive,
		Crystals = crystals,
		CurrentCrystalReward = currentCrystalReward,
		CanStoreCurrentCrystalReward = availableCapacity > 0,
		AvailableCapacity = availableCapacity,
		MissingCapacity = math.max(0, currentCrystalReward - availableCapacity),
		AttackSequence = profile.CrystalAttackSequence or 0,
		LastAttacks = profile.LastCrystalAttacks or {},
		PetTargets = petTargets,
	}
end

function CrystalCombat.collectFinishedReward(profile, stats)
	local state, zone = CrystalCombat.ensureState(profile)
	local reward = getCrystalReward(zone, stats, profile)

	for index, crystal in ipairs(state.Crystals) do
		if crystal.Health <= 0 then
			if getAvailableCapacity(profile, stats) <= 0 then
				return false, 0, reward
			end

			local awarded = awardEssence(profile, reward, stats)

			respawnCrystal(profile, state, index)

			return true, awarded, reward
		end
	end

	return true, 0, 0
end

function CrystalCombat.step(profile, stats, runeBonuses, now)
	local stateBefore, zoneBefore = CrystalCombat.ensureState(profile)
	local beforeZoneId = stateBefore.ZoneId
	local beforeNextCrystalId = stateBefore.NextCrystalId
	local beforeEssence = profile.Essence
	local attacks, reason, targetChanged = processAttacks(profile, stats, runeBonuses, now, stateBefore, zoneBefore)
	local stateAfter = CrystalCombat.ensureState(profile)
	local didChangeCrystal = beforeZoneId ~= stateAfter.ZoneId or beforeNextCrystalId ~= stateAfter.NextCrystalId
	local didChangeEssence = beforeEssence ~= profile.Essence
	local breakCount = 0

	for _, attack in ipairs(attacks) do
		if attack.DidBreak == true then
			breakCount += 1
		end
	end

	if #attacks > 0 then
		profile.CrystalAttackSequence = (profile.CrystalAttackSequence or 0) + 1
	end

	profile.LastCrystalAttacks = attacks

	return {
		Changed = didChangeCrystal or didChangeEssence or targetChanged == true or #attacks > 0,
		Reason = reason,
		ZoneId = stateAfter.ZoneId,
		AttackCount = #attacks,
		BreakCount = breakCount,
	}
end

return CrystalCombat
