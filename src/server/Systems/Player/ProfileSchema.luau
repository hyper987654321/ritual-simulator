local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local PetConfig = require(Config:WaitForChild("PetConfig"))
local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local RetentionConfig = require(Config:WaitForChild("RetentionConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = ProfileContract.DataVersion
ProfileSchema.MINIMUM_SUPPORTED_VERSION = ProfileContract.MinimumSupportedDataVersion

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, childValue in pairs(value) do
		copy[deepCopy(key)] = deepCopy(childValue)
	end

	return copy
end

local function getNowUnix(nowUnix)
	if typeof(nowUnix) == "number" and nowUnix == nowUnix and math.abs(nowUnix) ~= math.huge then
		return math.max(0, math.floor(nowUnix))
	end

	return DateTime.now().UnixTimestamp
end

local function getInteger(value, minimum, maximum, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end

	return math.clamp(math.floor(value), minimum, maximum)
end

local function getNonNegativeInteger(value, fallback)
	return getInteger(value, 0, ProfileContract.MaximumExactInteger, fallback or 0)
end

local function getPositiveInteger(value)
	local integer = getInteger(value, 0, ProfileContract.MaximumExactInteger, 0)

	return if integer > 0 then integer else nil
end

local function getFiniteNumber(value, minimum, maximum, fallback)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end

	return math.clamp(value, minimum, maximum)
end

local function getBoundedString(value, maximumLength)
	if typeof(value) ~= "string" or value == "" or #value > maximumLength then
		return nil
	end

	return value
end

local function createStoneLevels()
	return {
		Capacity = 0,
		Luck = 0,
		RollSpeed = 0,
	}
end

local function createRuneFocus()
	return {
		Version = 1,
		ActiveId = nil,
		Levels = ProfileContract.createRuneNumberMap(0),
		Charge = ProfileContract.createRuneNumberMap(0),
	}
end

local function createAutomation()
	return {
		Version = 1,
		AutoCapacityEnabled = false,
	}
end

local function getDayIndex(nowUnix)
	return math.floor(getNowUnix(nowUnix) / 86_400)
end

local function getRushEventId(nowUnix)
	return "ritual_rush_" .. tostring(getDayIndex(nowUnix))
end

local function createRitualRush(nowUnix)
	return {
		Version = 1,
		EventId = getRushEventId(nowUnix),
		Points = 0,
		SourcePoints = {},
		PremiumUnlocked = false,
		ClaimedFreeMilestones = {},
		ClaimedPremiumMilestones = {},
	}
end

local function createDailyRewards()
	return {
		Version = 1,
		LastClaimedDay = -1,
		CycleDay = 0,
		FirstRebirthRewardDay = -1,
	}
end

local function createOnboarding()
	return {
		Version = 1,
		IntroSeen = false,
		GuidanceHidden = false,
		Milestones = ProfileContract.createOnboardingMilestoneMap(false),
		Rewarded = ProfileContract.createOnboardingRewardedMap(false),
	}
end

local function createSocial()
	return {
		Version = 1,
		FirstCoPlayRewarded = false,
	}
end

local function createRetention(nowUnix)
	return {
		Version = 1,
		DayIndex = math.floor(getNowUnix(nowUnix) / RetentionConfig.SecondsPerDay),
		DailyProgress = {},
		DailyClaimed = {},
		ActiveSecondsToday = 0,
		PlaytimeClaimed = {},
		AchievementClaimed = {},
	}
end

local function isKnownFocusId(focusId)
	return typeof(focusId) == "string" and ProfileContract.RuneFocusMaxLevels[focusId] ~= nil
end

local function getAwayCapMinutes(profile)
	local upgrades = if typeof(profile.AscensionUpgrades) == "table" then profile.AscensionUpgrades else {}
	local awayLevel = getInteger(
		upgrades.away_ritual,
		0,
		ProfileContract.AscensionUpgradeMaxLevels.away_ritual,
		0
	)

	return math.min(
		480,
		30 + 15 * getNonNegativeInteger(profile.Rebirths) + 120 * getInteger(profile.Ascensions, 0, 3, 0) + 30 * awayLevel
	)
end

local function createSafeAwayCheckpoint(profile, nowUnix)
	local currentZone = if ZoneConfig.getZone(profile.CurrentZone) ~= nil then profile.CurrentZone else 1
	local capacity = math.max(120, getNonNegativeInteger(profile.HighestCapacity, 120))
	local essence = math.min(getNonNegativeInteger(profile.Essence), capacity)
	local rebirths = getNonNegativeInteger(profile.Rebirths)
	local ascensions = getInteger(profile.Ascensions, 0, 3, 0)
	local upgrades = if typeof(profile.AscensionUpgrades) == "table" then profile.AscensionUpgrades else {}
	local essenceMastery = getInteger(
		upgrades.essence_mastery,
		0,
		ProfileContract.AscensionUpgradeMaxLevels.essence_mastery,
		0
	)
	local runeFlow = getInteger(upgrades.rune_flow, 0, ProfileContract.AscensionUpgradeMaxLevels.rune_flow, 0)
	local activeFocusId = if typeof(profile.RuneFocus) == "table" and isKnownFocusId(profile.RuneFocus.ActiveId)
		then profile.RuneFocus.ActiveId
		else nil

	return {
		CapturedAtUnix = getNowUnix(nowUnix),
		ZoneId = currentZone,
		EffectiveTeamDamage = 0,
		Capacity = capacity,
		Essence = essence,
		PersistentEssenceMultiplier = (1 + 0.25 * rebirths)
			* (1 + 0.22 * ascensions)
			* (1 + 0.06 * essenceMastery),
		PersistentRuneChargeMultiplier = (1 + math.min(0.40, 0.025 * rebirths))
			* (1 + 0.15 * ascensions)
			* (1 + 0.05 * runeFlow),
		CapacityStateMultiplier = if essence < capacity then 1 else 0.55,
		ActiveRuneFocusId = activeFocusId,
		AwayCapMinutes = getAwayCapMinutes(profile),
	}
end

local function createAwayRewards()
	return {
		Version = 1,
		NextSequence = 1,
		-- The ProfileStore template is created once per server. Storing a clock
		-- value here would make later new profiles look as if they were away for
		-- the server's entire uptime. Load normalization captures the real time.
		Checkpoint = nil,
		Pending = nil,
		LastResolution = nil,
	}
end

function ProfileSchema.createTemplate(nowUnix)
	local profile = {
		Version = ProfileContract.DataVersion,
		Essence = 0,
		RitualGems = 20,
		Rolls = 0,
		BestRitualPower = 0,
		HighestCapacity = 120,
		RarestPetId = nil,
		RarestPetScore = 0,
		CurrentZone = 1,
		UnlockedZones = {
			[1] = true,
		},
		StoneLevels = createStoneLevels(),
		Rebirths = 0,
		Ascensions = 0,
		AscensionStars = 0,
		AscensionUpgrades = ProfileContract.createAscensionUpgradeMap(0),
		Automation = createAutomation(),
		RuneFocus = createRuneFocus(),
		RitualRush = createRitualRush(nowUnix),
		DailyRewards = createDailyRewards(),
		AwayRewards = nil,
		Onboarding = createOnboarding(),
		Social = createSocial(),
		Retention = createRetention(nowUnix),
		ProcessedPurchaseIds = {},
		ActiveBoosts = {},
		Potions = {},
		Pets = {},
		EquippedPetIds = {},
	}

	profile.AwayRewards = createAwayRewards()

	return profile
end

local function inspectRawVersion(data)
	if typeof(data) ~= "table" then
		return nil, "profile_data_invalid"
	end

	if data.Version == nil then
		return ProfileContract.MinimumSupportedDataVersion
	end

	if
		type(data.Version) ~= "number"
		or data.Version ~= data.Version
		or math.abs(data.Version) == math.huge
		or data.Version % 1 ~= 0
	then
		return nil, "profile_version_invalid"
	end

	if data.Version < ProfileContract.MinimumSupportedDataVersion then
		return nil, "profile_version_unsupported"
	end

	if data.Version > ProfileContract.DataVersion then
		return nil, "profile_version_future"
	end

	return data.Version
end

local function normalizeRuneLevels(levels)
	local normalized = ProfileContract.createRuneNumberMap(0)
	local source = if typeof(levels) == "table" then levels else {}

	for _, focusId in ipairs(ProfileContract.RuneFocusOrder) do
		normalized[focusId] = getInteger(source[focusId], 0, ProfileContract.RuneFocusMaxLevels[focusId], 0)
	end

	return normalized
end

local function migrateRuneFocus(working)
	if working.RuneFocus ~= nil then
		return
	end

	local runeFocus = createRuneFocus()
	runeFocus.Levels = normalizeRuneLevels(if typeof(working.RuneLevels) == "table" then working.RuneLevels else nil)

	local highestLevel = 0

	for _, focusId in ipairs(ProfileContract.RuneFocusOrder) do
		local level = runeFocus.Levels[focusId]

		if level > highestLevel then
			highestLevel = level
			runeFocus.ActiveId = focusId
		end
	end

	working.RuneFocus = runeFocus
end

local function hasAnyPositiveStoneLevel(stoneLevels)
	if typeof(stoneLevels) ~= "table" then
		return false
	end

	for _, upgradeId in ipairs(ProfileContract.StoneUpgradeOrder) do
		if getNonNegativeInteger(stoneLevels[upgradeId]) > 0 then
			return true
		end
	end

	return false
end

local function hasUnlockedZone(unlockedZones, minimumZone)
	if typeof(unlockedZones) ~= "table" then
		return false
	end

	for zoneId in pairs(unlockedZones) do
		if typeof(zoneId) == "number" and zoneId % 1 == 0 and zoneId >= minimumZone and unlockedZones[zoneId] == true then
			return true
		end
	end

	return false
end

local function migrateOnboarding(working)
	if working.Onboarding ~= nil then
		return
	end

	local onboarding = createOnboarding()
	local legacy = if typeof(working.TutorialCompletedSteps) == "table" then working.TutorialCompletedSteps else {}
	local milestones = onboarding.Milestones

	onboarding.IntroSeen = legacy.intro == true
	milestones.first_roll = legacy.first_roll == true or getNonNegativeInteger(working.Rolls) > 0
	milestones.first_stone_upgrade = legacy.first_stone_upgrade == true or hasAnyPositiveStoneLevel(working.StoneLevels)
	milestones.zone_2_unlocked = hasUnlockedZone(working.UnlockedZones, 2)
	milestones.zone_3_unlocked = hasUnlockedZone(working.UnlockedZones, 3)
	milestones.first_rebirth = legacy.first_rebirth == true or getNonNegativeInteger(working.Rebirths) > 0
	milestones.rune_focus_selected = typeof(working.RuneFocus) == "table"
		and isKnownFocusId(working.RuneFocus.ActiveId)

	for _, milestoneId in ipairs(ProfileContract.OnboardingRewardedOrder) do
		if milestones[milestoneId] == true then
			onboarding.Rewarded[milestoneId] = true
		end
	end

	working.Onboarding = onboarding
end

function ProfileSchema.migrateBeforeReconcile(data, nowUnix)
	local version, reason = inspectRawVersion(data)

	if version == nil then
		return nil, reason
	end

	local working = deepCopy(data)

	-- Field presence is authoritative so partially deployed profiles remain
	-- idempotent even when their root version was not advanced correctly.
	migrateRuneFocus(working)

	if working.Automation == nil then
		working.Automation = createAutomation()
	end

	if working.DailyRewards == nil then
		working.DailyRewards = createDailyRewards()
	end

	if working.AwayRewards == nil then
		working.AwayRewards = {
			Version = 1,
			NextSequence = 1,
			Checkpoint = nil,
			Pending = nil,
			LastResolution = nil,
		}
	end

	if working.RitualRush == nil then
		working.RitualRush = createRitualRush(nowUnix)
	elseif typeof(working.RitualRush) == "table" then
		working.RitualRush.Version = 1
		working.RitualRush.SourcePoints = if typeof(working.RitualRush.SourcePoints) == "table"
			then working.RitualRush.SourcePoints
			else {}
	end

	migrateOnboarding(working)

	if working.Social == nil then
		working.Social = createSocial()
	end

	if working.Retention == nil then
		working.Retention = createRetention(nowUnix)
	end

	return working, nil, version
end

function ProfileSchema.applyPreReconcileMigration(target, migrated)
	for key, value in pairs(migrated) do
		target[key] = deepCopy(value)
	end
end

local function normalizeUnlockedZones(unlockedZones)
	local normalized = {
		[1] = true,
	}

	for zoneId = 2, #ZoneConfig.ZoneOrder do
		if typeof(unlockedZones) == "table" and unlockedZones[zoneId] == true then
			normalized[zoneId] = true
		else
			break
		end
	end

	return normalized
end

local function normalizeStoneLevels(stoneLevels)
	local normalized = createStoneLevels()
	local source = if typeof(stoneLevels) == "table" then stoneLevels else {}

	for _, upgradeId in ipairs(ProfileContract.StoneUpgradeOrder) do
		normalized[upgradeId] = getInteger(
			source[upgradeId],
			0,
			ProfileContract.StoneLevelMaxima[upgradeId],
			0
		)
	end

	return normalized
end

local function normalizeAscensionUpgrades(upgrades)
	local normalized = {}
	local source = if typeof(upgrades) == "table" then upgrades else {}

	for key, value in pairs(source) do
		if ProfileContract.AscensionUpgradeMaxLevels[key] == nil then
			normalized[deepCopy(key)] = deepCopy(value)
		end
	end

	for _, upgradeId in ipairs(ProfileContract.AscensionUpgradeOrder) do
		normalized[upgradeId] = getInteger(
			source[upgradeId],
			0,
			ProfileContract.AscensionUpgradeMaxLevels[upgradeId],
			0
		)
	end

	return normalized
end

local function normalizeRuneFocus(runeFocus)
	local normalized = createRuneFocus()
	local source = if typeof(runeFocus) == "table" then runeFocus else {}

	normalized.Levels = normalizeRuneLevels(if typeof(source.Levels) == "table" then source.Levels else nil)
	normalized.ActiveId = if isKnownFocusId(source.ActiveId) then source.ActiveId else nil

	for _, focusId in ipairs(ProfileContract.RuneFocusOrder) do
		local level = normalized.Levels[focusId]
		local maximumLevel = ProfileContract.RuneFocusMaxLevels[focusId]

		if level >= maximumLevel then
			normalized.Charge[focusId] = 0
		else
			local requirement = ProfileContract.RuneFocusRequirements[focusId]
			local nextRequirement = math.max(1, math.floor(requirement.BaseCharge * (requirement.Growth ^ level)))
			normalized.Charge[focusId] = getInteger(
				type(source.Charge) == "table" and source.Charge[focusId] or 0,
				0,
				math.max(0, nextRequirement - 1),
				0
			)
		end
	end

	return normalized
end

local function normalizeClaimReceipts(receipts)
	local normalized = {}

	if typeof(receipts) ~= "table" then
		return normalized
	end

	for receiptId, wasClaimed in pairs(receipts) do
		local safeReceiptId = getBoundedString(receiptId, ProfileContract.MaximumIdentifierLength)

		if safeReceiptId ~= nil and wasClaimed == true then
			normalized[safeReceiptId] = true
		end
	end

	return normalized
end

local function normalizeRitualRush(ritualRush, nowUnix)
	local eventId = getRushEventId(nowUnix)

	if typeof(ritualRush) ~= "table" or ritualRush.EventId ~= eventId then
		return createRitualRush(nowUnix)
	end

	local sourcePoints = {}

	for _, sourceId in ipairs(ProfileContract.RushSourceOrder) do
		local sourceCap = ProfileContract.RushSourceCaps[sourceId]
		local amount = getInteger(
			type(ritualRush.SourcePoints) == "table" and ritualRush.SourcePoints[sourceId] or 0,
			0,
			sourceCap,
			0
		)

		if amount > 0 then
			sourcePoints[sourceId] = amount
		end
	end

	return {
		Version = 1,
		EventId = eventId,
		Points = getNonNegativeInteger(ritualRush.Points),
		SourcePoints = sourcePoints,
		PremiumUnlocked = ritualRush.PremiumUnlocked == true,
		ClaimedFreeMilestones = normalizeClaimReceipts(ritualRush.ClaimedFreeMilestones),
		ClaimedPremiumMilestones = normalizeClaimReceipts(ritualRush.ClaimedPremiumMilestones),
	}
end

local function normalizeDailyRewards(dailyRewards, nowUnix)
	local source = if typeof(dailyRewards) == "table" then dailyRewards else {}
	local today = getDayIndex(nowUnix)
	local lastClaimedDay = getInteger(source.LastClaimedDay, -1, ProfileContract.MaximumExactInteger, -1)
	local firstRebirthRewardDay = getInteger(
		source.FirstRebirthRewardDay,
		-1,
		ProfileContract.MaximumExactInteger,
		-1
	)

	if lastClaimedDay > today then
		lastClaimedDay = today
	end

	if firstRebirthRewardDay > today then
		firstRebirthRewardDay = today
	end

	return {
		Version = 1,
		LastClaimedDay = lastClaimedDay,
		CycleDay = getInteger(source.CycleDay, 0, 7, 0),
		FirstRebirthRewardDay = firstRebirthRewardDay,
	}
end

local function normalizeFocusAmountMap(amounts)
	local normalized = {}

	for _, focusId in ipairs(ProfileContract.RuneFocusOrder) do
		local amount = getNonNegativeInteger(type(amounts) == "table" and amounts[focusId] or 0)

		if amount > 0 then
			normalized[focusId] = amount
		end
	end

	return normalized
end

local function normalizeAwayCheckpoint(checkpoint, profile, nowUnix)
	if typeof(checkpoint) ~= "table" then
		return createSafeAwayCheckpoint(profile, nowUnix)
	end

	local zoneId = getPositiveInteger(checkpoint.ZoneId)

	if zoneId == nil or ZoneConfig.getZone(zoneId) == nil or profile.UnlockedZones[zoneId] ~= true then
		return createSafeAwayCheckpoint(profile, nowUnix)
	end

	local capturedAtUnix = getNonNegativeInteger(checkpoint.CapturedAtUnix, getNowUnix(nowUnix))
	local capacity = getPositiveInteger(checkpoint.Capacity)
	local effectiveTeamDamage = getFiniteNumber(
		checkpoint.EffectiveTeamDamage,
		0,
		ProfileContract.MaximumExactInteger,
		nil
	)
	local essenceMultiplier = getFiniteNumber(checkpoint.PersistentEssenceMultiplier, 0, 1_000_000, nil)
	local runeMultiplier = getFiniteNumber(checkpoint.PersistentRuneChargeMultiplier, 0, 1_000_000, nil)
	local capacityStateMultiplier = getFiniteNumber(checkpoint.CapacityStateMultiplier, 0.55, 1, nil)

	if
		capacity == nil
		or effectiveTeamDamage == nil
		or essenceMultiplier == nil
		or runeMultiplier == nil
		or capacityStateMultiplier == nil
	then
		return createSafeAwayCheckpoint(profile, nowUnix)
	end

	return {
		CapturedAtUnix = math.min(capturedAtUnix, getNowUnix(nowUnix)),
		ZoneId = zoneId,
		EffectiveTeamDamage = effectiveTeamDamage,
		Capacity = capacity,
		Essence = getInteger(checkpoint.Essence, 0, capacity, 0),
		PersistentEssenceMultiplier = essenceMultiplier,
		PersistentRuneChargeMultiplier = runeMultiplier,
		CapacityStateMultiplier = capacityStateMultiplier,
		ActiveRuneFocusId = if isKnownFocusId(checkpoint.ActiveRuneFocusId) then checkpoint.ActiveRuneFocusId else nil,
		AwayCapMinutes = getInteger(checkpoint.AwayCapMinutes, 0, 480, 0),
	}
end

local function normalizeAwayPending(pending)
	if typeof(pending) ~= "table" then
		return nil
	end

	local sequence = getPositiveInteger(pending.Sequence)

	if sequence == nil then
		return nil
	end

	local fromUnix = getNonNegativeInteger(pending.FromUnix)
	local toUnix = math.max(fromUnix, getNonNegativeInteger(pending.ToUnix, fromUnix))

	return {
		Sequence = sequence,
		FromUnix = fromUnix,
		ToUnix = toUnix,
		ObservedMinutes = getInteger(pending.ObservedMinutes, 0, 480, 0),
		EligibleMinutes = getInteger(pending.EligibleMinutes, 0, 480, 0),
		WasTimeCapped = pending.WasTimeCapped == true,
		PotentialEssence = getNonNegativeInteger(pending.PotentialEssence),
		RuneChargeByFocus = normalizeFocusAmountMap(pending.RuneChargeByFocus),
	}
end

local function normalizeAwayResolution(resolution)
	if typeof(resolution) ~= "table" then
		return nil
	end

	local sequence = getPositiveInteger(resolution.Sequence)
	local kind = resolution.Kind

	if sequence == nil or (kind ~= "claimed" and kind ~= "dismissed") then
		return nil
	end

	return {
		Sequence = sequence,
		Kind = kind,
		ResolvedAtUnix = getNonNegativeInteger(resolution.ResolvedAtUnix),
		EssenceAwarded = getNonNegativeInteger(resolution.EssenceAwarded),
		RuneChargeAppliedByFocus = normalizeFocusAmountMap(resolution.RuneChargeAppliedByFocus),
		RuneLevelsGainedByFocus = normalizeFocusAmountMap(resolution.RuneLevelsGainedByFocus),
	}
end

local function normalizeAwayRewards(awayRewards, profile, nowUnix)
	local source = if typeof(awayRewards) == "table" then awayRewards else {}
	local pending = normalizeAwayPending(source.Pending)
	local resolution = normalizeAwayResolution(source.LastResolution)

	if pending ~= nil and resolution ~= nil and pending.Sequence == resolution.Sequence then
		pending = nil
	end

	local highestSequence = math.max(
		pending and pending.Sequence or 0,
		resolution and resolution.Sequence or 0
	)
	local nextAfterHighest = math.min(ProfileContract.MaximumExactInteger, highestSequence + 1)

	return {
		Version = 1,
		NextSequence = math.max(getPositiveInteger(source.NextSequence) or 1, nextAfterHighest),
		Checkpoint = normalizeAwayCheckpoint(source.Checkpoint, profile, nowUnix),
		Pending = pending,
		LastResolution = resolution,
	}
end

local function normalizeOnboarding(onboarding)
	local source = if typeof(onboarding) == "table" then onboarding else {}
	local sourceMilestones = if typeof(source.Milestones) == "table" then source.Milestones else {}
	local sourceRewarded = if typeof(source.Rewarded) == "table" then source.Rewarded else {}
	local milestones = ProfileContract.createOnboardingMilestoneMap(false)
	local rewarded = ProfileContract.createOnboardingRewardedMap(false)

	for _, milestoneId in ipairs(ProfileContract.OnboardingMilestoneOrder) do
		milestones[milestoneId] = sourceMilestones[milestoneId] == true
	end

	for _, milestoneId in ipairs(ProfileContract.OnboardingRewardedOrder) do
		rewarded[milestoneId] = sourceRewarded[milestoneId] == true
	end

	return {
		Version = 1,
		IntroSeen = source.IntroSeen == true,
		GuidanceHidden = source.GuidanceHidden == true,
		Milestones = milestones,
		Rewarded = rewarded,
	}
end

local function normalizeRetention(retention, nowUnix)
	local source = if typeof(retention) == "table" then retention else {}
	local today = math.floor(getNowUnix(nowUnix) / RetentionConfig.SecondsPerDay)
	local sourceDay = getInteger(source.DayIndex, 0, ProfileContract.MaximumExactInteger, today)
	local normalized = createRetention(nowUnix)
	if sourceDay ~= today then
		return normalized
	end
	normalized.DayIndex = sourceDay
	normalized.ActiveSecondsToday = getNonNegativeInteger(source.ActiveSecondsToday)
	for _, id in ipairs(RetentionConfig.DeedOrder) do
		local definition = RetentionConfig.Deeds[id]
		local progress = getInteger(typeof(source.DailyProgress) == "table" and source.DailyProgress[id] or 0, 0, definition.Requirement, 0)
		if progress > 0 then normalized.DailyProgress[id] = progress end
		normalized.DailyClaimed[id] = typeof(source.DailyClaimed) == "table" and source.DailyClaimed[id] == true or false
	end
	for _, id in ipairs(RetentionConfig.PlaytimeOrder) do
		normalized.PlaytimeClaimed[id] = typeof(source.PlaytimeClaimed) == "table" and source.PlaytimeClaimed[id] == true or false
	end
	for _, id in ipairs(RetentionConfig.AchievementOrder) do
		normalized.AchievementClaimed[id] = typeof(source.AchievementClaimed) == "table" and source.AchievementClaimed[id] == true or false
	end
	return normalized
end

local function normalizeProcessedPurchaseIds(receipts)
	local normalized = {}

	if typeof(receipts) ~= "table" then
		return normalized
	end

	for receiptId, wasProcessed in pairs(receipts) do
		local safeReceiptId = getBoundedString(receiptId, ProfileContract.MaximumReceiptLength)

		if safeReceiptId ~= nil and wasProcessed == true then
			normalized[safeReceiptId] = true
		end
	end

	return normalized
end

local function normalizeActiveBoosts(activeBoosts, nowUnix)
	local normalized = {}
	local now = getNowUnix(nowUnix)

	if typeof(activeBoosts) ~= "table" then
		return normalized
	end

	for _, boostId in ipairs(ProfileContract.BoostOrder) do
		local activeBoost = activeBoosts[boostId]

		if typeof(activeBoost) == "table" then
			local endsAtUnix = getPositiveInteger(activeBoost.EndsAtUnix)

			if endsAtUnix ~= nil and endsAtUnix > now then
				normalized[boostId] = {
					BoostId = boostId,
					Multiplier = ProfileContract.BoostMultipliers[boostId],
					EndsAtUnix = math.min(endsAtUnix, now + ProfileContract.MaximumActiveBoostSeconds),
				}
			end
		end
	end

	return normalized
end

local function normalizePotions(potions)
	local normalized = {}

	for _, potionId in ipairs(ProfileContract.PotionOrder) do
		local count = getInteger(
			type(potions) == "table" and potions[potionId] or 0,
			0,
			ProfileContract.MaximumStoredPotions,
			0
		)

		if count > 0 then
			normalized[potionId] = count
		end
	end

	return normalized
end

local function normalizePets(pets)
	local normalized = {}

	if typeof(pets) ~= "table" then
		return normalized
	end

	for petId, rawCount in pairs(pets) do
		local safePetId = getBoundedString(petId, ProfileContract.MaximumIdentifierLength)
		local count = getNonNegativeInteger(rawCount)

		if safePetId ~= nil and count > 0 then
			local canonicalPetId = PetConfig.getCanonicalPetId(safePetId) or safePetId
			normalized[canonicalPetId] = getNonNegativeInteger((normalized[canonicalPetId] or 0) + count)
		end
	end

	return normalized
end

local function normalizeEquippedPets(equippedPetIds, pets)
	local normalized = {}
	local equippedCounts = {}

	if typeof(equippedPetIds) ~= "table" then
		return normalized
	end

	for _, petId in ipairs(equippedPetIds) do
		if #normalized >= ProfileContract.MaximumEquippedPets then
			break
		end

		local canonicalPetId = if typeof(petId) == "string" then PetConfig.getCanonicalPetId(petId) else nil

		if canonicalPetId ~= nil then
			local nextCount = (equippedCounts[canonicalPetId] or 0) + 1

			if nextCount <= (pets[canonicalPetId] or 0) then
				equippedCounts[canonicalPetId] = nextCount
				table.insert(normalized, canonicalPetId)
			end
		end
	end

	return normalized
end

function ProfileSchema.normalizeDurable(data, nowUnix)
	local source = if typeof(data) == "table" then data else {}
	local normalized = ProfileSchema.createTemplate(nowUnix)

	normalized.Essence = getNonNegativeInteger(source.Essence)
	normalized.RitualGems = getNonNegativeInteger(source.RitualGems, 20)
	normalized.Rolls = getNonNegativeInteger(source.Rolls)
	normalized.BestRitualPower = getNonNegativeInteger(source.BestRitualPower)
	normalized.HighestCapacity = math.max(120, getNonNegativeInteger(source.HighestCapacity, 120))
	normalized.RarestPetScore = getNonNegativeInteger(source.RarestPetScore)

	local rarestPetId = getBoundedString(source.RarestPetId, ProfileContract.MaximumIdentifierLength)
	normalized.RarestPetId = if rarestPetId ~= nil then PetConfig.getCanonicalPetId(rarestPetId) or rarestPetId else nil

	normalized.UnlockedZones = normalizeUnlockedZones(source.UnlockedZones)
	local currentZone = getPositiveInteger(source.CurrentZone)
	normalized.CurrentZone = if currentZone ~= nil and normalized.UnlockedZones[currentZone] == true then currentZone else 1
	normalized.StoneLevels = normalizeStoneLevels(source.StoneLevels)
	normalized.Rebirths = getNonNegativeInteger(source.Rebirths)
	normalized.Ascensions = getInteger(source.Ascensions, 0, 3, 0)
	normalized.AscensionStars = getNonNegativeInteger(source.AscensionStars)
	normalized.AscensionUpgrades = normalizeAscensionUpgrades(source.AscensionUpgrades)
	normalized.Automation = {
		Version = 1,
		AutoCapacityEnabled = typeof(source.Automation) == "table" and source.Automation.AutoCapacityEnabled == true,
	}
	normalized.RuneFocus = normalizeRuneFocus(source.RuneFocus)
	normalized.RitualRush = normalizeRitualRush(source.RitualRush, nowUnix)
	normalized.DailyRewards = normalizeDailyRewards(source.DailyRewards, nowUnix)
	normalized.Onboarding = normalizeOnboarding(source.Onboarding)
	normalized.Social = {
		Version = 1,
		FirstCoPlayRewarded = typeof(source.Social) == "table" and source.Social.FirstCoPlayRewarded == true,
	}
	normalized.Retention = normalizeRetention(source.Retention, nowUnix)
	normalized.ProcessedPurchaseIds = normalizeProcessedPurchaseIds(source.ProcessedPurchaseIds)
	normalized.ActiveBoosts = normalizeActiveBoosts(source.ActiveBoosts, nowUnix)
	normalized.Potions = normalizePotions(source.Potions)
	normalized.Pets = normalizePets(source.Pets)
	normalized.EquippedPetIds = normalizeEquippedPets(source.EquippedPetIds, normalized.Pets)
	normalized.AwayRewards = normalizeAwayRewards(source.AwayRewards, normalized, nowUnix)
	normalized.Version = ProfileContract.DataVersion

	return normalized
end

function ProfileSchema.createRuntimeProfile(savedData, nowUnix)
	local profile = ProfileSchema.normalizeDurable(savedData, nowUnix)

	profile.RollReadyAt = 0
	profile.CrystalState = nil
	profile.CrystalAttackState = {}
	profile.CrystalAttackSequence = 0
	profile.LastCrystalAttacks = {}
	profile.CrystalFarmingActive = false
	profile.SnapshotRevision = 0
	profile.ProgressionEpoch = 0
	profile.RuneFocusSelectionReadyAt = 0
	profile.FeedbackSequence = 0

	return profile
end

function ProfileSchema.overlayDurable(target, runtimeProfile, nowUnix)
	local normalized = ProfileSchema.normalizeDurable(runtimeProfile, nowUnix)

	for _, key in ipairs(ProfileContract.DurableRootOrder) do
		target[key] = deepCopy(normalized[key])
	end

	for key in pairs(ProfileContract.LegacyDurableRoots) do
		target[key] = nil
	end

	for key in pairs(ProfileContract.RuntimeRoots) do
		target[key] = nil
	end

	return normalized
end

function ProfileSchema.applyNormalizedDurable(runtimeProfile, normalized)
	for _, key in ipairs(ProfileContract.DurableRootOrder) do
		runtimeProfile[key] = deepCopy(normalized[key])
	end

	for key in pairs(ProfileContract.LegacyDurableRoots) do
		runtimeProfile[key] = nil
	end
end

function ProfileSchema.deepCopy(value)
	return deepCopy(value)
end

return ProfileSchema
