local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local AscensionConfig = require(Config:WaitForChild("AscensionConfig"))
local BoostConfig = require(Config:WaitForChild("BoostConfig"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local PotionConfig = require(Config:WaitForChild("PotionConfig"))
local RitualRushConfig = require(Config:WaitForChild("RitualRushConfig"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local RuneConfig = require(Config:WaitForChild("RuneConfig"))
local TutorialConfig = require(Config:WaitForChild("TutorialConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local CrystalCombat = require(script.Parent.Parent:WaitForChild("Ritual"):WaitForChild("CrystalCombat"))

local PlayerDerivedState = {}

local function cloneArray(array)
	local clone = {}

	for index, value in ipairs(array) do
		clone[index] = value
	end

	return clone
end

local function getPetCount(profile, petId)
	return math.max(0, math.floor(profile.Pets[petId] or 0))
end

local function getEquippedPetCount(profile, petId)
	local count = 0

	for _, equippedPetId in ipairs(profile.EquippedPetIds) do
		if equippedPetId == petId then
			count += 1
		end
	end

	return count
end

local function calculateEquippedPetPower(profile, runeBonuses)
	local equippedPetPower = 0
	local safeRuneBonuses = runeBonuses or {}
	local petPowerMultiplier = safeRuneBonuses.PetPowerMultiplier or 1

	for _, petId in ipairs(profile.EquippedPetIds) do
		equippedPetPower += PetConfig.getPetPower(petId) * petPowerMultiplier
	end

	return equippedPetPower
end

function PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, rebirths)
	return math.floor(stats.Capacity + stats.Luck * 100 + equippedPetPower * 25 + rebirths * 500 + (stats.RitualPowerBonus or 0))
end

function PlayerDerivedState.getCurrentRitualRuntime(profile)
	local runeBonuses = RuneConfig.getBonuses(profile.RuneLevels)
	local ascensionBonuses = AscensionConfig.getStatBonuses(profile.Ascensions)
	local stats = RitualStoneConfig.getStats(profile.StoneLevels, profile.Rebirths, runeBonuses, ascensionBonuses)
	local equippedPetPower = calculateEquippedPetPower(profile, runeBonuses)

	return runeBonuses, stats, equippedPetPower
end

function PlayerDerivedState.canUnlockZone(profile, zoneId)
	local zone = ZoneConfig.getZone(zoneId)

	if zone == nil or profile.UnlockedZones[zoneId] == true then
		return false
	end

	local previousZoneId = ZoneConfig.getPreviousZoneId(zoneId)

	if previousZoneId ~= nil and profile.UnlockedZones[previousZoneId] ~= true then
		return false
	end

	return profile.Essence >= zone.UnlockCost
end

function PlayerDerivedState.canRebirth(profile, rebirthRequirement)
	return profile.Essence >= rebirthRequirement.RequiredEssence
end

function PlayerDerivedState.getRollState(profile, now)
	local currentTime = now or os.clock()
	local rollReadyAt = profile.RollReadyAt or 0
	local retryAfter = math.max(0, rollReadyAt - currentTime)

	return {
		IsBusy = retryAfter > 0,
		RetryAfter = retryAfter,
	}
end

local function getTutorialSnapshot(profile)
	local completedSteps = profile.TutorialCompletedSteps or {}

	return {
		CurrentStepId = TutorialConfig.getNextStepId(completedSteps),
		IsComplete = TutorialConfig.areAllStepsComplete(completedSteps),
		CompletedStepIds = TutorialConfig.getCompletedStepIds(completedSteps),
		Steps = TutorialConfig.getStepSnapshots(completedSteps),
	}
end

local function getNextUpgradeCosts(stoneLevels)
	local costs = {}

	for _, upgradeId in ipairs(RitualStoneConfig.UpgradeOrder) do
		costs[upgradeId] = RitualStoneConfig.getUpgradeCost(upgradeId, stoneLevels[upgradeId] or 0)
	end

	return costs
end

local function getZoneSnapshots(profile)
	local zones = {}

	for _, zoneId in ipairs(ZoneConfig.getZoneIds()) do
		local zone = ZoneConfig.getZone(zoneId)

		table.insert(zones, {
			ZoneId = zoneId,
			DisplayName = zone.DisplayName,
			IsUnlocked = profile.UnlockedZones[zoneId] == true,
			IsCurrent = profile.CurrentZone == zoneId,
			CanUnlock = PlayerDerivedState.canUnlockZone(profile, zoneId),
			UnlockCost = zone.UnlockCost,
			CrystalHealth = zone.CrystalHealth,
			CrystalEssenceReward = zone.CrystalEssenceReward,
		})
	end

	return zones
end

local function getRuneSnapshots(profile)
	local runes = {}
	local isUnlocked = RuneConfig.canUseRunes(profile.UnlockedZones, profile.Rebirths)

	for _, runeId in ipairs(RuneConfig.RuneOrder) do
		local rune = RuneConfig.getRune(runeId)
		local level = profile.RuneLevels[runeId] or 0

		table.insert(runes, {
			RuneId = runeId,
			DisplayName = rune.DisplayName,
			Description = rune.Description,
			Level = level,
			MaxLevel = rune.MaxLevel,
			NextCost = RuneConfig.getUpgradeCost(runeId, level),
			IsMaxed = level >= rune.MaxLevel,
			IsUnlocked = isUnlocked,
		})
	end

	return runes
end

local function getEquippedPetSnapshots(profile)
	local equippedPets = {}

	for slotIndex, petId in ipairs(profile.EquippedPetIds) do
		if PetConfig.getPet(petId) ~= nil and getPetCount(profile, petId) > 0 then
			table.insert(equippedPets, {
				Uid = slotIndex,
				SlotId = slotIndex,
				PetId = petId,
			})
		end
	end

	return equippedPets
end

function PlayerDerivedState.getSnapshot(profile)
	if profile == nil then
		return nil
	end

	local pets = {}
	local stoneLevels = {}
	local _, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local rebirthRequirement = RitualStoneConfig.getRebirthRequirement(profile.Rebirths)
	local ritualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths)

	for _, petId in ipairs(PetConfig.RollOrder) do
		local count = getPetCount(profile, petId)

		if count > 0 then
			local equippedCount = getEquippedPetCount(profile, petId)

			table.insert(pets, {
				PetId = petId,
				Count = count,
				EquippedCount = equippedCount,
				StoredCount = math.max(0, count - equippedCount),
				IsEquipped = equippedCount > 0,
			})
		end
	end

	for _, upgradeId in ipairs(RitualStoneConfig.UpgradeOrder) do
		stoneLevels[upgradeId] = profile.StoneLevels[upgradeId] or 0
	end

	return {
		Essence = profile.Essence,
		RitualGems = profile.RitualGems or 0,
		Rolls = profile.Rolls,
		CurrentZone = profile.CurrentZone,
		Zones = getZoneSnapshots(profile),
		StoneLevels = stoneLevels,
		StoneStats = stats,
		RebirthRequirement = {
			RequiredEssence = rebirthRequirement.RequiredEssence,
			CanRebirth = PlayerDerivedState.canRebirth(profile, rebirthRequirement),
		},
		NextUpgradeCosts = getNextUpgradeCosts(stoneLevels),
		RuneUnlock = {
			IsUnlocked = RuneConfig.canUseRunes(profile.UnlockedZones, profile.Rebirths),
			RequiredZone = RuneConfig.Unlock.RequiredZone,
			RequiredRebirths = RuneConfig.Unlock.RequiredRebirths,
		},
		Roll = PlayerDerivedState.getRollState(profile),
		Runes = getRuneSnapshots(profile),
		Rebirths = profile.Rebirths,
		Ascensions = profile.Ascensions or 0,
		AscensionStars = profile.AscensionStars or 0,
		Ascension = AscensionConfig.getSnapshot(profile),
		RitualRush = RitualRushConfig.getSnapshot(profile.RitualRush),
		ActiveBoosts = BoostConfig.getActiveBoostSnapshots(profile.ActiveBoosts),
		Potions = PotionConfig.getPotionSnapshots(profile.Potions),
		Tutorial = getTutorialSnapshot(profile),
		Crystal = CrystalCombat.getSnapshot(profile, stats),
		BestRitualPower = profile.BestRitualPower,
		HighestCapacity = profile.HighestCapacity,
		RarestPetId = profile.RarestPetId,
		RarestPetScore = profile.RarestPetScore,
		Pets = pets,
		EquippedPetIds = cloneArray(profile.EquippedPetIds),
		EquippedPets = getEquippedPetSnapshots(profile),
		MaxEquippedPets = PetConfig.MAX_EQUIPPED,
		RitualPower = ritualPower,
		Revision = profile.SnapshotRevision or 0,
	}
end

function PlayerDerivedState.getPublicVisual(profile)
	if profile == nil then
		return nil
	end

	local _, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)

	return {
		Rebirths = profile.Rebirths,
		RitualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths),
		StoneStats = {
			Capacity = stats.Capacity,
		},
		EquippedPets = getEquippedPetSnapshots(profile),
	}
end

function PlayerDerivedState.getCrystalUpdate(profile)
	if profile == nil then
		return nil
	end

	local _, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local rebirthRequirement = RitualStoneConfig.getRebirthRequirement(profile.Rebirths)

	return {
		Essence = profile.Essence,
		RitualGems = profile.RitualGems or 0,
		CurrentZone = profile.CurrentZone,
		Zones = getZoneSnapshots(profile),
		RebirthRequirement = {
			RequiredEssence = rebirthRequirement.RequiredEssence,
			CanRebirth = PlayerDerivedState.canRebirth(profile, rebirthRequirement),
		},
		StoneStats = stats,
		StoneLevels = profile.StoneLevels,
		Ascensions = profile.Ascensions or 0,
		AscensionStars = profile.AscensionStars or 0,
		Ascension = AscensionConfig.getSnapshot(profile),
		RitualRush = RitualRushConfig.getSnapshot(profile.RitualRush),
		ActiveBoosts = BoostConfig.getActiveBoostSnapshots(profile.ActiveBoosts),
		Potions = PotionConfig.getPotionSnapshots(profile.Potions),
		Crystal = CrystalCombat.getSnapshot(profile, stats),
		Roll = PlayerDerivedState.getRollState(profile),
		RitualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths),
		Revision = profile.SnapshotRevision or 0,
	}
end

function PlayerDerivedState.getLeaderstatsPayload(profile)
	if profile == nil then
		return nil
	end

	local _, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)

	return {
		RitualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths),
		Rebirths = profile.Rebirths,
		Rolls = profile.Rolls,
	}
end

return PlayerDerivedState
