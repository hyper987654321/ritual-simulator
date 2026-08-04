local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local AscensionConfig = require(Config:WaitForChild("AscensionConfig"))
local BoostConfig = require(Config:WaitForChild("BoostConfig"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local PotionConfig = require(Config:WaitForChild("PotionConfig"))
local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local RitualRushConfig = require(Config:WaitForChild("RitualRushConfig"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local RuneFocusConfig = require(Config:WaitForChild("RuneFocusConfig"))
local TutorialConfig = require(Config:WaitForChild("TutorialConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local CrystalCombat = require(script.Parent.Parent:WaitForChild("Ritual"):WaitForChild("CrystalCombat"))
local RuneFocusProgress = require(script.Parent.Parent:WaitForChild("Ritual"):WaitForChild("RuneFocusProgress"))

local PlayerDerivedState = {}

PlayerDerivedState.PlayerStateSectionAllowlist = {
	SchemaVersion = true,
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
	-- Transitional snapshot aliases remain explicitly allowlisted while known
	-- clients migrate to their canonical roots.
	RebirthRequirement = true,
	Rebirths = true,
	Ascensions = true,
	AscensionStars = true,
	AscensionUpgrades = true,
	Tutorial = true,
}

local function getSafeInteger(value, maximum)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(math.floor(value), 0, maximum)
end

local function getFiniteNonNegativeNumber(value, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end

	return math.clamp(value, 0, ProfileContract.MaximumExactInteger)
end

local function hasPendingAwayClaim(profile)
	return typeof(profile) == "table"
		and typeof(profile.AwayRewards) == "table"
		and typeof(profile.AwayRewards.Pending) == "table"
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

local function boundedAdd(...)
	local total = 0

	for index = 1, select("#", ...) do
		local value = getFiniteNonNegativeNumber(select(index, ...), 0)

		total += math.min(value, ProfileContract.MaximumExactInteger - total)

		if total >= ProfileContract.MaximumExactInteger then
			return ProfileContract.MaximumExactInteger
		end
	end

	return total
end

local function cloneArray(array)
	local clone = {}

	for index, value in ipairs(array) do
		clone[index] = value
	end

	return clone
end

local function getPetCount(profile, petId)
	return getSafeInteger(profile.Pets[petId], ProfileContract.MaximumExactInteger)
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
		equippedPetPower = boundedAdd(
			equippedPetPower,
			PetConfig.getPetDamage(petId, petPowerMultiplier)
		)
	end

	return equippedPetPower
end

function PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, rebirths)
	local rawPower = boundedAdd(
		getFiniteNonNegativeNumber(stats.Capacity, 0),
		boundedMultiply(stats.Luck, 120),
		boundedMultiply(equippedPetPower, 18),
		boundedMultiply(rebirths, 650),
		boundedMultiply(stats.Ascensions, 4_000),
		boundedMultiply(stats.TotalRuneFocusLevels, 120),
		boundedMultiply(stats.HighestUnlockedZone, 200)
	)

	return math.clamp(math.floor(rawPower), 0, ProfileContract.MaximumExactInteger)
end

function PlayerDerivedState.getCurrentRitualRuntime(profile)
	local runeFocus = if typeof(profile.RuneFocus) == "table" then profile.RuneFocus else {}
	local runeBonuses = RuneFocusConfig.getBonuses(runeFocus.Levels)
	local ascensionBonuses = AscensionConfig.getStatBonuses(profile)
	local stats = RitualStoneConfig.getStats(profile.StoneLevels, profile.Rebirths, runeBonuses, ascensionBonuses)
	local activeBoosts = BoostConfig.normalizeActiveBoosts(profile.ActiveBoosts)

	stats.RollSpeedPercent = math.clamp(
		boundedMultiply(
			stats.RollSpeedPercent,
			BoostConfig.getActiveBoostMultiplier(activeBoosts, BoostConfig.BoostIds.RollSpeedMultiplier)
		),
		RitualStoneConfig.MinimumRollSpeedPercent,
		RitualStoneConfig.MaximumRollSpeedPercent
	)
	runeBonuses.PetPowerMultiplier = boundedMultiply(
		runeBonuses.PetPowerMultiplier,
		stats.RebirthPetPowerMultiplier,
		stats.AscensionPetPowerMultiplier,
		BoostConfig.getActiveBoostMultiplier(activeBoosts, BoostConfig.BoostIds.PetPowerMultiplier)
	)
	stats.Ascensions = ascensionBonuses.Ascensions
	stats.TotalRuneFocusLevels = runeBonuses.TotalLevels
	stats.HighestUnlockedZone = RuneFocusConfig.getHighestUnlockedZone(profile.UnlockedZones)
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
	return not hasPendingAwayClaim(profile)
		and profile.Essence >= rebirthRequirement.RequiredEssence
		and profile.UnlockedZones[rebirthRequirement.RequiredZone] == true
end

function PlayerDerivedState.getAscensionSnapshot(profile)
	local ascension = AscensionConfig.getSnapshot(profile)
	local awayClaimPending = hasPendingAwayClaim(profile)

	ascension.HasPendingAwayClaim = awayClaimPending
	ascension.CanAscend = ascension.CanAscend == true and not awayClaimPending

	return ascension
end

function PlayerDerivedState.getRollCooldownState(profile, now)
	local currentTime = if typeof(now) == "number" and now == now and math.abs(now) ~= math.huge
		then now
		else os.clock()
	local rollReadyAt = if typeof(profile.RollReadyAt) == "number"
		and profile.RollReadyAt == profile.RollReadyAt
		and math.abs(profile.RollReadyAt) ~= math.huge
		then profile.RollReadyAt
		else 0
	local retryAfter = math.max(0, rollReadyAt - currentTime)

	return {
		IsBusy = retryAfter > 0,
		RetryAfter = retryAfter,
	}
end

function PlayerDerivedState.getCurrentRollLuck(profile, stats)
	local resolvedStats = stats

	if typeof(resolvedStats) ~= "table" then
		local _, currentStats = PlayerDerivedState.getCurrentRitualRuntime(profile)

		resolvedStats = currentStats
	end

	return boundedMultiply(
		resolvedStats.Luck,
		BoostConfig.getActiveBoostMultiplier(profile.ActiveBoosts, BoostConfig.BoostIds.LuckMultiplier)
	)
end

function PlayerDerivedState.getRollState(profile, now, stats, runeBonuses)
	local cooldown = PlayerDerivedState.getRollCooldownState(profile, now)
	local resolvedRuneBonuses = runeBonuses
	local resolvedStats = stats

	if typeof(resolvedStats) ~= "table" or typeof(resolvedRuneBonuses) ~= "table" then
		resolvedRuneBonuses, resolvedStats = PlayerDerivedState.getCurrentRitualRuntime(profile)
	end

	local currentLuck = PlayerDerivedState.getCurrentRollLuck(profile, resolvedStats)
	local preview = PetConfig.getAdjustedRollPreview(currentLuck, resolvedRuneBonuses.PetPowerMultiplier)

	return {
		IsBusy = cooldown.IsBusy,
		RetryAfter = cooldown.RetryAfter,
		Luck = currentLuck,
		LuckBucket = preview.LuckBucket,
		PetPowerMultiplier = resolvedRuneBonuses.PetPowerMultiplier,
		Preview = preview,
	}
end

local function getTutorialSnapshot(profile)
	local onboarding = if typeof(profile.Onboarding) == "table" then profile.Onboarding else {}
	local milestones = if typeof(onboarding.Milestones) == "table" then onboarding.Milestones else {}
	local completedSteps = {
		[TutorialConfig.StepIds.Intro] = onboarding.IntroSeen == true,
		[TutorialConfig.StepIds.FirstRoll] = milestones.first_roll == true,
		[TutorialConfig.StepIds.FirstStoneUpgrade] = milestones.first_stone_upgrade == true,
		[TutorialConfig.StepIds.FirstRebirth] = milestones.first_rebirth == true,
	}

	return {
		CurrentStepId = TutorialConfig.getNextStepId(completedSteps),
		IsComplete = TutorialConfig.areAllStepsComplete(completedSteps),
		CompletedStepIds = TutorialConfig.getCompletedStepIds(completedSteps),
		Steps = TutorialConfig.getStepSnapshots(completedSteps),
	}
end

local function getNextUpgradeCosts(profile)
	local stoneLevels = if typeof(profile.StoneLevels) == "table" then profile.StoneLevels else {}
	local costs = {}

	for _, upgradeId in ipairs(RitualStoneConfig.UpgradeOrder) do
		costs[upgradeId] = RitualStoneConfig.getUpgradeCost(upgradeId, stoneLevels[upgradeId] or 0)
	end

	if costs.RollSpeed ~= nil then
		local runeFocus = if typeof(profile.RuneFocus) == "table" then profile.RuneFocus else {}
		local runeBonuses = RuneFocusConfig.getBonuses(runeFocus.Levels)
		local ascensionBonuses = AscensionConfig.getStatBonuses(profile)
		local currentLevel = getSafeInteger(
			stoneLevels.RollSpeed,
			RitualStoneConfig.Upgrades.RollSpeed.MaxLevel
		)
		local simulatedLevels = table.clone(stoneLevels)

		simulatedLevels.RollSpeed = currentLevel + 1

		local currentStats = RitualStoneConfig.getStats(
			stoneLevels,
			profile.Rebirths,
			runeBonuses,
			ascensionBonuses
		)
		local nextStats = RitualStoneConfig.getStats(
			simulatedLevels,
			profile.Rebirths,
			runeBonuses,
			ascensionBonuses
		)

		if nextStats.RollSpeedPercent <= currentStats.RollSpeedPercent then
			costs.RollSpeed = nil
		end
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

local function getRuneFocusSnapshot(profile, stats)
	local runeFocus = if typeof(profile.RuneFocus) == "table" then profile.RuneFocus else {}
	local levels = if typeof(runeFocus.Levels) == "table" then runeFocus.Levels else {}
	local charge = if typeof(runeFocus.Charge) == "table" then runeFocus.Charge else {}
	local activeId = if RuneFocusConfig.getFocus(runeFocus.ActiveId) ~= nil then runeFocus.ActiveId else nil
	local isUnlocked = RuneFocusConfig.canUseFocus(profile.UnlockedZones, profile.Rebirths)
	local selectionReadyAt = if typeof(profile.RuneFocusSelectionReadyAt) == "number"
		and profile.RuneFocusSelectionReadyAt == profile.RuneFocusSelectionReadyAt
		and math.abs(profile.RuneFocusSelectionReadyAt) ~= math.huge
		then profile.RuneFocusSelectionReadyAt
		else 0
	local selectionRetryAfter = math.max(0, selectionReadyAt - os.clock())
	local capacityState = RuneFocusProgress.getCapacityState(profile, stats)
	local currentCrystalReward = CrystalCombat.getCurrentReward(profile, stats)
	local focuses = {}
	local hasSelectableFocus = false

	for _, focusId in ipairs(RuneFocusConfig.FocusOrder) do
		local focus = RuneFocusConfig.getFocus(focusId)
		local level = getSafeInteger(levels[focusId], focus.MaxLevel)
		local isMaxed = level >= focus.MaxLevel
		local requiredCharge = RuneFocusConfig.getRequiredCharge(focusId, level) or 0
		local currentCharge = if isMaxed
			then 0
			else getSafeInteger(charge[focusId], math.max(0, requiredCharge - 1))

		if not isMaxed and focusId ~= activeId then
			hasSelectableFocus = true
		end

		table.insert(focuses, {
			FocusId = focusId,
			DisplayName = focus.DisplayName,
			Description = focus.Description,
			Level = level,
			MaxLevel = focus.MaxLevel,
			Charge = currentCharge,
			RequiredCharge = requiredCharge,
			Progress = if isMaxed then 1 else math.clamp(currentCharge / math.max(1, requiredCharge), 0, 1),
			IsActive = activeId == focusId,
			IsMaxed = isMaxed,
			BonusText = focus.BonusText,
		})
	end

	return {
		IsUnlocked = isUnlocked,
		RequiredZone = RuneFocusConfig.Unlock.RequiredZone,
		RequiredRebirths = RuneFocusConfig.Unlock.RequiredRebirths,
		ActiveId = activeId,
		CanSelect = isUnlocked
			and hasSelectableFocus
			and (
				activeId == nil
				or (profile.CrystalFarmingActive ~= true and selectionRetryAfter <= 0)
			),
		SelectionRetryAfter = selectionRetryAfter,
		CapacityState = capacityState,
		ChargeMultiplier = RuneFocusProgress.getCurrentChargeMultiplier(profile, stats, currentCrystalReward),
		ProgressSequence = profile.SnapshotRevision or 0,
		Focuses = focuses,
	}
end

local function getOnboardingSnapshot(profile)
	local source = if typeof(profile.Onboarding) == "table" then profile.Onboarding else {}
	local sourceMilestones = if typeof(source.Milestones) == "table" then source.Milestones else {}
	local milestones = {}
	local completedMilestoneIds = {}

	for _, milestoneId in ipairs(ProfileContract.OnboardingMilestoneOrder) do
		local isComplete = sourceMilestones[milestoneId] == true
		milestones[milestoneId] = isComplete

		if isComplete then
			table.insert(completedMilestoneIds, milestoneId)
		end
	end

	local rewarded = {}
	local sourceRewarded = if typeof(source.Rewarded) == "table" then source.Rewarded else {}

	for _, milestoneId in ipairs(ProfileContract.OnboardingRewardedOrder) do
		rewarded[milestoneId] = sourceRewarded[milestoneId] == true
	end

	return {
		IntroSeen = source.IntroSeen == true,
		GuidanceHidden = source.GuidanceHidden == true,
		IsOnboardingComplete = #completedMilestoneIds == #ProfileContract.OnboardingMilestoneOrder,
		CompletedMilestoneIds = completedMilestoneIds,
		Milestones = milestones,
		Rewarded = rewarded,
		CurrentGoal = nil,
	}
end

local function getAutomationSnapshot(profile)
	local automation = if typeof(profile.Automation) == "table" then profile.Automation else {}
	local rebirths = getSafeInteger(profile.Rebirths, ProfileContract.MaximumExactInteger)

	return {
		AutoCapacityUnlocked = rebirths >= RitualStoneConfig.AutoCapacity.RequiredRebirths,
		AutoCapacityEnabled = rebirths >= RitualStoneConfig.AutoCapacity.RequiredRebirths
			and automation.AutoCapacityEnabled == true,
	}
end

local function getDailyRewardsSnapshot(profile, nowUnix)
	local source = if typeof(profile.DailyRewards) == "table" then profile.DailyRewards else {}
	local dayIndex = math.floor(nowUnix / 86_400)

	return {
		DayIndex = dayIndex,
		StartsAtUnix = dayIndex * 86_400,
		EndsAtUnix = (dayIndex + 1) * 86_400,
		LastClaimedDay = source.LastClaimedDay or -1,
		CurrentCycleDay = source.CycleDay or 0,
		FirstRebirthRewardDay = source.FirstRebirthRewardDay or -1,
		IsClaimedToday = source.LastClaimedDay == dayIndex,
		FirstRebirthRewardClaimed = source.FirstRebirthRewardDay == dayIndex,
	}
end

local function getAwayRewardsSnapshot(profile)
	local source = if typeof(profile.AwayRewards) == "table" then profile.AwayRewards else {}
	local pending = if typeof(source.Pending) == "table" then source.Pending else nil

	if pending == nil then
		return {
			HasPendingClaim = false,
		}
	end

	local runeChargeByFocus = {}
	local sourceCharge = if typeof(pending.RuneChargeByFocus) == "table" then pending.RuneChargeByFocus else {}

	for _, focusId in ipairs(RuneFocusConfig.FocusOrder) do
		runeChargeByFocus[focusId] = getSafeInteger(
			sourceCharge[focusId],
			ProfileContract.MaximumExactInteger
		)
	end

	return {
		HasPendingClaim = true,
		Sequence = getSafeInteger(pending.Sequence, ProfileContract.MaximumExactInteger),
		ObservedMinutes = getSafeInteger(pending.ObservedMinutes, ProfileContract.MaximumExactInteger),
		EligibleMinutes = getSafeInteger(pending.EligibleMinutes, ProfileContract.MaximumExactInteger),
		WasTimeCapped = pending.WasTimeCapped == true,
		EssenceOffered = getSafeInteger(pending.PotentialEssence, ProfileContract.MaximumExactInteger),
		RuneChargeByFocus = runeChargeByFocus,
	}
end

local function getSocialSnapshot(profile)
	local social = if typeof(profile.Social) == "table" then profile.Social else {}

	return {
		VerifiedFriendCount = 0,
		FirstCoPlayRewarded = social.FirstCoPlayRewarded == true,
		RequiredSeconds = 120,
		RemainingSeconds = if social.FirstCoPlayRewarded == true then 0 else 120,
	}
end

function PlayerDerivedState.getPetSnapshotFacts(petId, luck, petPowerMultiplier)
	local adjustedChance = PetConfig.getAdjustedPetChance(petId, luck)
	local basePower = PetConfig.getPetPower(petId)
	local power = PetConfig.getPetDamage(petId, petPowerMultiplier)

	return {
		BasePower = basePower,
		Power = power,
		Damage = power,
		AdjustedChance = adjustedChance,
		Chance = adjustedChance,
		OddsText = PetConfig.getChanceOddsText(adjustedChance),
	}
end

local function getEquippedPetSnapshots(profile, petPowerMultiplier, includePower)
	local equippedPets = {}

	for slotIndex, petId in ipairs(profile.EquippedPetIds) do
		if PetConfig.getPet(petId) ~= nil and getPetCount(profile, petId) > 0 then
			local snapshot = {
				Uid = slotIndex,
				SlotId = slotIndex,
				PetId = petId,
			}

			if includePower == true then
				local basePower = PetConfig.getPetPower(petId)
				local power = PetConfig.getPetDamage(petId, petPowerMultiplier)

				snapshot.BasePower = basePower
				snapshot.Power = power
				snapshot.Damage = power
			end

			table.insert(equippedPets, snapshot)
		end
	end

	return equippedPets
end

local function getPetSnapshots(profile, rollSnapshot, petPowerMultiplier)
	local pets = {}

	for _, petId in ipairs(PetConfig.RollOrder) do
		local count = getPetCount(profile, petId)

		if count > 0 then
			local equippedCount = getEquippedPetCount(profile, petId)
			local petFacts = PlayerDerivedState.getPetSnapshotFacts(
				petId,
				rollSnapshot.Luck,
				petPowerMultiplier
			)
			local petSnapshot = {
				PetId = petId,
				Count = count,
				EquippedCount = equippedCount,
				StoredCount = math.max(0, count - equippedCount),
				IsEquipped = equippedCount > 0,
			}

			for key, value in pairs(petFacts) do
				petSnapshot[key] = value
			end

			table.insert(pets, petSnapshot)
		end
	end

	return pets
end

function PlayerDerivedState.getSnapshot(profile)
	if profile == nil then
		return nil
	end

	local pets = {}
	local stoneLevels = {}
	local runeBonuses, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local rebirthRequirement = RitualStoneConfig.getRebirthRequirement(profile.Rebirths)
	local ritualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths)
	local runeFocusSnapshot = getRuneFocusSnapshot(profile, stats)
	local serverNowUnix = DateTime.now().UnixTimestamp
	local canRebirth = PlayerDerivedState.canRebirth(profile, rebirthRequirement)
	local ascensionSnapshot = PlayerDerivedState.getAscensionSnapshot(profile)
	local rollSnapshot = PlayerDerivedState.getRollState(profile, nil, stats, runeBonuses)

	pets = getPetSnapshots(profile, rollSnapshot, runeBonuses.PetPowerMultiplier)

	for _, upgradeId in ipairs(RitualStoneConfig.UpgradeOrder) do
		stoneLevels[upgradeId] = profile.StoneLevels[upgradeId] or 0
	end

	return {
		SchemaVersion = 1,
		Revision = profile.SnapshotRevision or 0,
		ProgressionEpoch = profile.ProgressionEpoch or 0,
		ServerNowUnix = serverNowUnix,
		Essence = profile.Essence,
		RitualGems = profile.RitualGems or 0,
		Rolls = profile.Rolls,
		CurrentZone = profile.CurrentZone,
		Zones = getZoneSnapshots(profile),
		StoneLevels = stoneLevels,
		StoneStats = stats,
		RebirthRequirement = {
			RequiredEssence = rebirthRequirement.RequiredEssence,
			RequiredZone = rebirthRequirement.RequiredZone,
			HasPendingAwayClaim = hasPendingAwayClaim(profile),
			CanRebirth = canRebirth,
		},
		Rebirth = {
			Count = profile.Rebirths,
			RequiredEssence = rebirthRequirement.RequiredEssence,
			RequiredZone = rebirthRequirement.RequiredZone,
			HasRequiredEssence = profile.Essence >= rebirthRequirement.RequiredEssence,
			HasRequiredZone = profile.UnlockedZones[rebirthRequirement.RequiredZone] == true,
			HasPendingAwayClaim = hasPendingAwayClaim(profile),
			CanRebirth = canRebirth,
		},
		NextUpgradeCosts = getNextUpgradeCosts(profile),
		Roll = rollSnapshot,
		RuneFocus = runeFocusSnapshot,
		Rebirths = profile.Rebirths,
		Ascensions = profile.Ascensions or 0,
		AscensionStars = profile.AscensionStars or 0,
		AscensionUpgrades = ascensionSnapshot.AscensionUpgrades,
		Ascension = ascensionSnapshot,
		Automation = getAutomationSnapshot(profile),
		RitualRush = RitualRushConfig.getSnapshot(profile.RitualRush, serverNowUnix),
		DailyRewards = getDailyRewardsSnapshot(profile, serverNowUnix),
		AwayRewards = getAwayRewardsSnapshot(profile),
		Onboarding = getOnboardingSnapshot(profile),
		Social = getSocialSnapshot(profile),
		ActiveBoosts = BoostConfig.getActiveBoostSnapshots(profile.ActiveBoosts, serverNowUnix),
		Potions = PotionConfig.getPotionSnapshots(profile.Potions),
		Tutorial = getTutorialSnapshot(profile),
		Crystal = CrystalCombat.getSnapshot(profile, stats),
		BestRitualPower = profile.BestRitualPower,
		HighestCapacity = profile.HighestCapacity,
		RarestPetId = profile.RarestPetId,
		RarestPetScore = profile.RarestPetScore,
		Pets = pets,
		EquippedPetIds = cloneArray(profile.EquippedPetIds),
		EquippedPets = getEquippedPetSnapshots(profile, runeBonuses.PetPowerMultiplier, true),
		MaxEquippedPets = PetConfig.MAX_EQUIPPED,
		RitualPower = ritualPower,
	}
end

function PlayerDerivedState.getPlayerStateSections(profile, requestedSections)
	if profile == nil or typeof(requestedSections) ~= "table" then
		return nil
	end

	local delta = PlayerDerivedState.getCrystalUpdate(profile, requestedSections)

	if delta == nil then
		return nil
	end

	local sections = {}

	for sectionName, isRequested in pairs(requestedSections) do
		if isRequested == true and PlayerDerivedState.PlayerStateSectionAllowlist[sectionName] == true then
			local value = delta[sectionName]

			if value == nil then
				-- Optional nil roots cannot be represented in a Luau map. Refuse a
				-- partial push so the caller can retain the prior state and resync.
				return nil
			end

			sections[sectionName] = value
		end
	end

	return sections
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

function PlayerDerivedState.getCrystalUpdate(profile, requestedSections)
	if profile == nil then
		return nil
	end

	local sections = if typeof(requestedSections) == "table" then requestedSections else {
		Essence = true,
		CurrentZone = true,
		Zones = true,
		StoneLevels = true,
		StoneStats = true,
		Rebirth = true,
		RuneFocus = true,
		Ascension = true,
		Automation = true,
		RitualRush = true,
		Onboarding = true,
		Crystal = true,
		Roll = true,
		RitualPower = true,
	}
	local runeBonuses, stats, equippedPetPower = PlayerDerivedState.getCurrentRitualRuntime(profile)
	local serverNowUnix = DateTime.now().UnixTimestamp
	local update = {
		SchemaVersion = 1,
		Revision = profile.SnapshotRevision or 0,
	}
	local rollSnapshot = nil

	local function getResolvedRollSnapshot()
		if rollSnapshot == nil then
			rollSnapshot = PlayerDerivedState.getRollState(profile, nil, stats, runeBonuses)
		end

		return rollSnapshot
	end

	if sections.ProgressionEpoch == true then
		update.ProgressionEpoch = profile.ProgressionEpoch or 0
	end

	if sections.ServerNowUnix == true then
		update.ServerNowUnix = serverNowUnix
	end

	if sections.Essence == true then
		update.Essence = profile.Essence
	end

	if sections.RitualGems == true then
		update.RitualGems = profile.RitualGems or 0
	end

	if sections.Rolls == true then
		update.Rolls = profile.Rolls or 0
	end

	if sections.BestRitualPower == true then
		update.BestRitualPower = profile.BestRitualPower or 0
	end

	if sections.HighestCapacity == true then
		update.HighestCapacity = profile.HighestCapacity or 0
	end

	if sections.RarestPetId == true and profile.RarestPetId ~= nil then
		update.RarestPetId = profile.RarestPetId
	end

	if sections.RarestPetScore == true then
		update.RarestPetScore = profile.RarestPetScore or 0
	end

	if sections.CurrentZone == true then
		update.CurrentZone = profile.CurrentZone
	end

	if sections.Zones == true then
		update.Zones = getZoneSnapshots(profile)
	end

	if sections.StoneLevels == true then
		update.StoneLevels = table.clone(profile.StoneLevels)
	end

	if sections.StoneStats == true then
		update.StoneStats = stats
	end

	if sections.NextUpgradeCosts == true then
		update.NextUpgradeCosts = getNextUpgradeCosts(profile)
	end

	if sections.Rebirth == true or sections.RebirthRequirement == true then
		local rebirthRequirement = RitualStoneConfig.getRebirthRequirement(profile.Rebirths)
		local canRebirth = PlayerDerivedState.canRebirth(profile, rebirthRequirement)
		local rebirth = {
			Count = profile.Rebirths,
			RequiredEssence = rebirthRequirement.RequiredEssence,
			RequiredZone = rebirthRequirement.RequiredZone,
			HasRequiredEssence = profile.Essence >= rebirthRequirement.RequiredEssence,
			HasRequiredZone = profile.UnlockedZones[rebirthRequirement.RequiredZone] == true,
			HasPendingAwayClaim = hasPendingAwayClaim(profile),
			CanRebirth = canRebirth,
		}

		if sections.Rebirth == true then
			update.Rebirth = rebirth
		end

		if sections.RebirthRequirement == true then
			update.RebirthRequirement = {
				RequiredEssence = rebirthRequirement.RequiredEssence,
				RequiredZone = rebirthRequirement.RequiredZone,
				HasPendingAwayClaim = hasPendingAwayClaim(profile),
				CanRebirth = canRebirth,
			}
		end
	end

	if
		sections.Ascension == true
		or sections.Ascensions == true
		or sections.AscensionStars == true
		or sections.AscensionUpgrades == true
	then
		local ascension = PlayerDerivedState.getAscensionSnapshot(profile)

		if sections.Ascension == true then
			update.Ascension = ascension
		end
		if sections.Ascensions == true then
			update.Ascensions = profile.Ascensions or 0
		end
		if sections.AscensionStars == true then
			update.AscensionStars = profile.AscensionStars or 0
		end
		if sections.AscensionUpgrades == true then
			update.AscensionUpgrades = ascension.AscensionUpgrades
		end
	end

	if sections.Automation == true then
		update.Automation = getAutomationSnapshot(profile)
	end

	if sections.RuneFocus == true then
		update.RuneFocus = getRuneFocusSnapshot(profile, stats)
	end

	if sections.RitualRush == true then
		update.RitualRush = RitualRushConfig.getSnapshot(profile.RitualRush, serverNowUnix)
	end

	if sections.Onboarding == true then
		update.Onboarding = getOnboardingSnapshot(profile)
	end

	if sections.Tutorial == true then
		update.Tutorial = getTutorialSnapshot(profile)
	end

	if sections.ActiveBoosts == true then
		update.ActiveBoosts = BoostConfig.getActiveBoostSnapshots(profile.ActiveBoosts, serverNowUnix)
	end

	if sections.Potions == true then
		update.Potions = PotionConfig.getPotionSnapshots(profile.Potions)
	end

	if sections.Crystal == true then
		update.Crystal = CrystalCombat.getSnapshot(profile, stats)
	end

	if sections.Roll == true then
		update.Roll = getResolvedRollSnapshot()
	end

	if sections.DailyRewards == true then
		update.DailyRewards = getDailyRewardsSnapshot(profile, serverNowUnix)
	end

	if sections.AwayRewards == true then
		update.AwayRewards = getAwayRewardsSnapshot(profile)
	end

	if sections.Social == true then
		update.Social = getSocialSnapshot(profile)
	end

	if sections.Pets == true then
		update.Pets = getPetSnapshots(
			profile,
			getResolvedRollSnapshot(),
			runeBonuses.PetPowerMultiplier
		)
	end

	if sections.EquippedPetIds == true then
		update.EquippedPetIds = cloneArray(profile.EquippedPetIds)
	end

	if sections.EquippedPets == true then
		update.EquippedPets = getEquippedPetSnapshots(profile, runeBonuses.PetPowerMultiplier, true)
	end

	if sections.MaxEquippedPets == true then
		update.MaxEquippedPets = PetConfig.MAX_EQUIPPED
	end

	if sections.Rebirths == true then
		update.Rebirths = profile.Rebirths or 0
	end

	if sections.RitualPower == true then
		update.RitualPower = PlayerDerivedState.calculateRitualPower(stats, equippedPetPower, profile.Rebirths)
	end

	return update
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
