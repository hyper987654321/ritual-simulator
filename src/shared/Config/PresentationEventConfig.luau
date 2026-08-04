local ProfileContract = require(script.Parent:WaitForChild("ProfileContract"))

local PresentationEventConfig = {}

PresentationEventConfig.SchemaVersion = 1
PresentationEventConfig.MaxRecordsPerPacket = 8
PresentationEventConfig.MaxQueuedRecords = 64
PresentationEventConfig.MaxClientToasts = 3
PresentationEventConfig.MaxRememberedDedupeKeys = 64
PresentationEventConfig.MaxArgsPerRecord = 8
PresentationEventConfig.MaxDedupeKeyLength = 160
PresentationEventConfig.ChargeBatchSeconds = 2
PresentationEventConfig.DefaultClientDurationSeconds = 3
PresentationEventConfig.MaximumClientDurationSeconds = 6

PresentationEventConfig.ClientPriorities = {
	Routine = 1,
	Normal = 2,
	Important = 3,
	Critical = 4,
}

PresentationEventConfig.Kinds = {
	Info = "info",
	Success = "success",
	Warning = "warning",
	Reward = "reward",
}

PresentationEventConfig.EventIds = {
	RuneCharge = "rune_charge",
	RuneLevelUp = "rune_level_up",
	RuneFocusSelected = "rune_focus_selected",
	CapacityFull = "capacity_full",
	StoneUpgrade = "stone_upgrade",
	AutoCapacityPurchase = "auto_capacity_purchase",
	RebirthReady = "rebirth_ready",
	AscensionReady = "ascension_ready",
	RebirthComplete = "rebirth_complete",
	AscensionComplete = "ascension_complete",
	AscensionUpgrade = "ascension_upgrade",
	DailyRewardReady = "daily_reward_ready",
	DailyRewardClaimed = "daily_reward_claimed",
	FirstRebirthDailyBonus = "first_rebirth_daily_bonus",
	AwayRewardReady = "away_reward_ready",
	AwayRewardClaimed = "away_reward_claimed",
	PetRollReveal = "pet_roll_reveal",
	CrystalHit = "crystal_hit",
	CrystalBreak = "crystal_break",
	ZoneUnlocked = "zone_unlocked",
	RitualRushMilestoneReady = "ritual_rush_milestone_ready",
	RitualRushRewardClaimed = "ritual_rush_reward_claimed",
	PotionPurchased = "potion_purchased",
	PotionUsed = "potion_used",
	OnboardingMilestoneComplete = "onboarding_milestone_complete",
	FirstCoplayReward = "first_coplay_reward",
}

PresentationEventConfig.Events = {
	[PresentationEventConfig.EventIds.RuneCharge] = {
		Kind = PresentationEventConfig.Kinds.Info,
		ClientPriority = PresentationEventConfig.ClientPriorities.Routine,
		ClientDurationSeconds = 2,
	},
	[PresentationEventConfig.EventIds.RuneLevelUp] = {
		Kind = PresentationEventConfig.Kinds.Success,
		ClientPriority = PresentationEventConfig.ClientPriorities.Critical,
		ClientDurationSeconds = 3,
	},
	[PresentationEventConfig.EventIds.RuneFocusSelected] = {
		Kind = PresentationEventConfig.Kinds.Success,
		ClientPriority = PresentationEventConfig.ClientPriorities.Important,
		ClientDurationSeconds = 2.5,
	},
	[PresentationEventConfig.EventIds.CapacityFull] = {
		Kind = PresentationEventConfig.Kinds.Warning,
		ClientPriority = PresentationEventConfig.ClientPriorities.Important,
		ClientDurationSeconds = 4,
	},
	[PresentationEventConfig.EventIds.StoneUpgrade] = { Kind = PresentationEventConfig.Kinds.Success },
	[PresentationEventConfig.EventIds.AutoCapacityPurchase] = { Kind = PresentationEventConfig.Kinds.Info },
	[PresentationEventConfig.EventIds.RebirthReady] = { Kind = PresentationEventConfig.Kinds.Info },
	[PresentationEventConfig.EventIds.AscensionReady] = { Kind = PresentationEventConfig.Kinds.Info },
	[PresentationEventConfig.EventIds.RebirthComplete] = { Kind = PresentationEventConfig.Kinds.Success },
	[PresentationEventConfig.EventIds.AscensionComplete] = { Kind = PresentationEventConfig.Kinds.Success },
	[PresentationEventConfig.EventIds.AscensionUpgrade] = { Kind = PresentationEventConfig.Kinds.Success },
	[PresentationEventConfig.EventIds.DailyRewardReady] = { Kind = PresentationEventConfig.Kinds.Info },
	[PresentationEventConfig.EventIds.DailyRewardClaimed] = { Kind = PresentationEventConfig.Kinds.Reward },
	[PresentationEventConfig.EventIds.FirstRebirthDailyBonus] = { Kind = PresentationEventConfig.Kinds.Reward },
	[PresentationEventConfig.EventIds.AwayRewardReady] = { Kind = PresentationEventConfig.Kinds.Info },
	[PresentationEventConfig.EventIds.AwayRewardClaimed] = { Kind = PresentationEventConfig.Kinds.Reward },
	[PresentationEventConfig.EventIds.PetRollReveal] = { Kind = PresentationEventConfig.Kinds.Reward },
	[PresentationEventConfig.EventIds.CrystalHit] = { Kind = PresentationEventConfig.Kinds.Info },
	[PresentationEventConfig.EventIds.CrystalBreak] = { Kind = PresentationEventConfig.Kinds.Success },
	[PresentationEventConfig.EventIds.ZoneUnlocked] = { Kind = PresentationEventConfig.Kinds.Success },
	[PresentationEventConfig.EventIds.RitualRushMilestoneReady] = { Kind = PresentationEventConfig.Kinds.Info },
	[PresentationEventConfig.EventIds.RitualRushRewardClaimed] = { Kind = PresentationEventConfig.Kinds.Reward },
	[PresentationEventConfig.EventIds.PotionPurchased] = { Kind = PresentationEventConfig.Kinds.Success },
	[PresentationEventConfig.EventIds.PotionUsed] = { Kind = PresentationEventConfig.Kinds.Info },
	[PresentationEventConfig.EventIds.OnboardingMilestoneComplete] = { Kind = PresentationEventConfig.Kinds.Success },
	[PresentationEventConfig.EventIds.FirstCoplayReward] = { Kind = PresentationEventConfig.Kinds.Reward },
}

local argSchemas = {
	[PresentationEventConfig.EventIds.RuneCharge] = {
		FocusId = "string",
		ChargeApplied = "integer",
		Level = "integer",
		Charge = "integer",
		RequiredCharge = "integer",
	},
	[PresentationEventConfig.EventIds.RuneLevelUp] = {
		FocusId = "string",
		LevelsGained = "integer",
		Level = "integer",
	},
	[PresentationEventConfig.EventIds.RuneFocusSelected] = {
		FocusId = "string",
	},
	[PresentationEventConfig.EventIds.CapacityFull] = {
		CanContinueForRune = "boolean",
		PauseReason = "string",
	},
	[PresentationEventConfig.EventIds.StoneUpgrade] = {
		UpgradeId = "string",
		LevelsBought = "integer",
		Level = "integer",
		EssenceSpent = "integer",
	},
	[PresentationEventConfig.EventIds.AutoCapacityPurchase] = {
		UpgradeId = "string",
		LevelsBought = "integer",
		Level = "integer",
		EssenceSpent = "integer",
	},
	[PresentationEventConfig.EventIds.RebirthReady] = {
		Rebirths = "integer",
		RequiredEssence = "integer",
		RequiredZone = "integer",
	},
	[PresentationEventConfig.EventIds.AscensionReady] = {
		Ascensions = "integer",
		RequiredRebirths = "integer",
		RequiredZone = "integer",
		StarReward = "integer",
	},
	[PresentationEventConfig.EventIds.RebirthComplete] = {
		Rebirths = "integer",
	},
	[PresentationEventConfig.EventIds.AscensionComplete] = {
		Ascensions = "integer",
		StarReward = "integer",
	},
	[PresentationEventConfig.EventIds.AscensionUpgrade] = {
		UpgradeId = "string",
		Level = "integer",
		StarsSpent = "integer",
	},
}

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function sanitizeArg(value, expectedType)
	if expectedType == "string" then
		if typeof(value) ~= "string" or #value > ProfileContract.MaximumIdentifierLength then
			return nil
		end

		return value
	elseif expectedType == "boolean" then
		return if typeof(value) == "boolean" then value else nil
	elseif expectedType == "integer" then
		if not isFiniteNumber(value) then
			return nil
		end

		return math.clamp(math.floor(value), 0, ProfileContract.MaximumExactInteger)
	end

	return nil
end

local function sanitizeArgs(eventId, args)
	local schema = argSchemas[eventId]

	if schema == nil or typeof(args) ~= "table" then
		return nil
	end

	local sanitized = {}
	local count = 0

	for key, expectedType in pairs(schema) do
		local value = sanitizeArg(args[key], expectedType)

		if value ~= nil and count < PresentationEventConfig.MaxArgsPerRecord then
			sanitized[key] = value
			count += 1
		end
	end

	return if count > 0 then sanitized else nil
end

function PresentationEventConfig.getEvent(eventId)
	if typeof(eventId) ~= "string" then
		return nil
	end

	return PresentationEventConfig.Events[eventId]
end

function PresentationEventConfig.getClientPriority(eventId)
	local definition = PresentationEventConfig.getEvent(eventId)
	local priority = if definition ~= nil then definition.ClientPriority else nil

	if typeof(priority) ~= "number" then
		return PresentationEventConfig.ClientPriorities.Normal
	end

	return math.clamp(
		math.floor(priority),
		PresentationEventConfig.ClientPriorities.Routine,
		PresentationEventConfig.ClientPriorities.Critical
	)
end

function PresentationEventConfig.getClientDurationSeconds(eventId)
	local definition = PresentationEventConfig.getEvent(eventId)
	local duration = if definition ~= nil then definition.ClientDurationSeconds else nil

	if typeof(duration) ~= "number" or duration ~= duration or math.abs(duration) == math.huge then
		return PresentationEventConfig.DefaultClientDurationSeconds
	end

	return math.clamp(duration, 0.5, PresentationEventConfig.MaximumClientDurationSeconds)
end

function PresentationEventConfig.sanitizeRecord(record)
	if typeof(record) ~= "table" then
		return nil
	end

	local eventId = record.EventId
	local definition = PresentationEventConfig.getEvent(eventId)
	local sequence = record.Sequence
	local dedupeKey = record.DedupeKey

	if
		definition == nil
		or not isFiniteNumber(sequence)
		or sequence ~= math.floor(sequence)
		or sequence < 1
		or sequence > ProfileContract.MaximumExactInteger
		or record.Kind ~= definition.Kind
		or typeof(dedupeKey) ~= "string"
		or #dedupeKey == 0
		or #dedupeKey > PresentationEventConfig.MaxDedupeKeyLength
	then
		return nil
	end

	return {
		Sequence = sequence,
		EventId = eventId,
		DedupeKey = dedupeKey,
		Kind = definition.Kind,
		Args = sanitizeArgs(eventId, record.Args),
	}
end

function PresentationEventConfig.sanitizeRecords(records)
	local sanitized = {}

	if typeof(records) ~= "table" then
		return sanitized
	end

	for index = 1, math.min(#records, PresentationEventConfig.MaxRecordsPerPacket) do
		local record = PresentationEventConfig.sanitizeRecord(records[index])

		if record ~= nil then
			table.insert(sanitized, record)
		end
	end

	return sanitized
end

return PresentationEventConfig
