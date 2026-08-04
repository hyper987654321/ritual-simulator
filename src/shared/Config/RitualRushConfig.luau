local ProfileContract = require(script.Parent:WaitForChild("ProfileContract"))
local PotionConfig = require(script.Parent:WaitForChild("PotionConfig"))

local RitualRushConfig = {}

RitualRushConfig.EventIdPrefix = "ritual_rush"
RitualRushConfig.EventDurationSeconds = 24 * 60 * 60
RitualRushConfig.DisplayName = "Ritual Rush"

-- These symbolic keys remain for existing server callers while their values
-- move to the frozen snake-case wire/save IDs.
RitualRushConfig.PointSources = {
	RollPet = "roll_pet",
	CrystalBroken = "crystal_break_online",
	BuyStoneUpgrade = "stone_upgrade",
	RuneLevel = "rune_level",
	UnlockZone = "zone_unlock",
	Rebirth = "rebirth",
	FirstRebirthDaily = "first_rebirth_daily",
	Ascension = "ascension",
	OfflineClaim = "offline_claim",
}

RitualRushConfig.PointsBySource = {
	roll_pet = 1,
	crystal_break_online = 2,
	stone_upgrade = 8,
	rune_level = 50,
	zone_unlock = 45,
	rebirth = 125,
	first_rebirth_daily = 75,
	ascension = 500,
	offline_claim = 0,
}

RitualRushConfig.SourceCaps = ProfileContract.RushSourceCaps

RitualRushConfig.MilestoneOrder = {
	"points_25",
	"points_75",
	"points_160",
	"points_325",
	"points_650",
	"points_1100",
	"points_1650",
	"points_2400",
}

RitualRushConfig.Milestones = {
	points_25 = {
		MilestoneId = "points_25",
		RequiredPoints = 25,
		FreeReward = { Essence = 60 },
		PremiumReward = { RitualGems = 3 },
	},
	points_75 = {
		MilestoneId = "points_75",
		RequiredPoints = 75,
		FreeReward = { RitualGems = 5 },
		PremiumReward = { Essence = 100 },
	},
	points_160 = {
		MilestoneId = "points_160",
		RequiredPoints = 160,
		FreeReward = {
			Potions = {
				{ PotionId = PotionConfig.PotionIds.Essence2x15m, Count = 1 },
			},
		},
		PremiumReward = { RitualGems = 8 },
	},
	points_325 = {
		MilestoneId = "points_325",
		RequiredPoints = 325,
		FreeReward = { Essence = 250, RitualGems = 8 },
		PremiumReward = {
			Potions = {
				{ PotionId = PotionConfig.PotionIds.RollFlow1_5x15m, Count = 1 },
			},
		},
	},
	points_650 = {
		MilestoneId = "points_650",
		RequiredPoints = 650,
		FreeReward = { Essence = 700 },
		PremiumReward = { RitualGems = 20 },
	},
	points_1100 = {
		MilestoneId = "points_1100",
		RequiredPoints = 1_100,
		FreeReward = {
			RitualGems = 15,
			Potions = {
				{ PotionId = PotionConfig.PotionIds.Luck2x15m, Count = 1 },
			},
		},
		PremiumReward = {
			RitualGems = 35,
			Potions = {
				{ PotionId = PotionConfig.PotionIds.Essence2x15m, Count = 1 },
			},
		},
	},
	points_1650 = {
		MilestoneId = "points_1650",
		RequiredPoints = 1_650,
		FreeReward = { Essence = 2_000, RitualGems = 30 },
		PremiumReward = { RitualGems = 75 },
	},
	points_2400 = {
		MilestoneId = "points_2400",
		RequiredPoints = 2_400,
		FreeReward = { RitualGems = 50 },
		PremiumReward = {
			RitualGems = 150,
			Potions = {
				{ PotionId = PotionConfig.PotionIds.Essence2x15m, Count = 1 },
				{ PotionId = PotionConfig.PotionIds.RollFlow1_5x15m, Count = 1 },
				{ PotionId = PotionConfig.PotionIds.PetPower1_5x15m, Count = 1 },
				{ PotionId = PotionConfig.PotionIds.RuneFlow1_5x15m, Count = 1 },
			},
		},
	},
}

local function getSafeInteger(value, maximum)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(math.floor(value), 0, maximum or ProfileContract.MaximumExactInteger)
end

local function getCurrentUnixTime(nowUnix)
	if typeof(nowUnix) == "number" and nowUnix == nowUnix and math.abs(nowUnix) ~= math.huge then
		return getSafeInteger(nowUnix)
	end

	return DateTime.now().UnixTimestamp
end

local function cloneRewardPotions(potions)
	local clone = {}

	if typeof(potions) ~= "table" then
		return clone
	end

	for _, potionGrant in ipairs(potions) do
		local normalizedGrant = PotionConfig.normalizePotionGrant(potionGrant)

		if normalizedGrant ~= nil then
			table.insert(clone, normalizedGrant)
		end
	end

	return clone
end

local function cloneReward(reward)
	local source = if typeof(reward) == "table" then reward else {}

	return {
		Essence = getSafeInteger(source.Essence),
		RitualGems = getSafeInteger(source.RitualGems),
		Potions = cloneRewardPotions(source.Potions),
	}
end

local function cloneClaimedMilestones(claimedMilestones)
	local clone = {}

	if typeof(claimedMilestones) ~= "table" then
		return clone
	end

	for milestoneId, wasClaimed in pairs(claimedMilestones) do
		if
			type(milestoneId) == "string"
			and milestoneId ~= ""
			and #milestoneId <= ProfileContract.MaximumIdentifierLength
			and wasClaimed == true
		then
			clone[milestoneId] = true
		end
	end

	return clone
end

local function normalizeSourcePoints(sourcePoints)
	local source = if typeof(sourcePoints) == "table" then sourcePoints else {}
	local normalized = {}

	for _, sourceId in ipairs(ProfileContract.RushSourceOrder) do
		local amount = getSafeInteger(source[sourceId], RitualRushConfig.SourceCaps[sourceId])

		if amount > 0 then
			normalized[sourceId] = amount
		end
	end

	return normalized
end

function RitualRushConfig.getCurrentEventInfo(nowUnix)
	local currentUnixTime = getCurrentUnixTime(nowUnix)
	local eventIndex = math.floor(currentUnixTime / RitualRushConfig.EventDurationSeconds)
	local startsAtUnix = eventIndex * RitualRushConfig.EventDurationSeconds
	local endsAtUnix = startsAtUnix + RitualRushConfig.EventDurationSeconds

	return {
		EventId = RitualRushConfig.EventIdPrefix .. "_" .. tostring(eventIndex),
		StartsAtUnix = startsAtUnix,
		EndsAtUnix = endsAtUnix,
	}
end

function RitualRushConfig.createDefaultProgress(nowUnix)
	local eventInfo = RitualRushConfig.getCurrentEventInfo(nowUnix)

	return {
		Version = 1,
		EventId = eventInfo.EventId,
		Points = 0,
		SourcePoints = {},
		PremiumUnlocked = false,
		ClaimedFreeMilestones = {},
		ClaimedPremiumMilestones = {},
	}
end

function RitualRushConfig.reconcileProgress(progress, nowUnix)
	local eventInfo = RitualRushConfig.getCurrentEventInfo(nowUnix)

	if typeof(progress) ~= "table" or progress.EventId ~= eventInfo.EventId then
		return RitualRushConfig.createDefaultProgress(nowUnix)
	end

	return {
		Version = 1,
		EventId = eventInfo.EventId,
		Points = getSafeInteger(progress.Points),
		SourcePoints = normalizeSourcePoints(progress.SourcePoints),
		PremiumUnlocked = progress.PremiumUnlocked == true,
		ClaimedFreeMilestones = cloneClaimedMilestones(progress.ClaimedFreeMilestones),
		ClaimedPremiumMilestones = cloneClaimedMilestones(progress.ClaimedPremiumMilestones),
	}
end

function RitualRushConfig.getPointAmount(source)
	if typeof(source) ~= "string" then
		return nil
	end

	return RitualRushConfig.PointsBySource[source]
end

function RitualRushConfig.getSourceCap(source)
	if typeof(source) ~= "string" then
		return nil
	end

	return RitualRushConfig.SourceCaps[source]
end

function RitualRushConfig.getMilestones()
	local milestones = {}

	for _, milestoneId in ipairs(RitualRushConfig.MilestoneOrder) do
		local milestone = RitualRushConfig.Milestones[milestoneId]

		table.insert(milestones, {
			MilestoneId = milestone.MilestoneId,
			RequiredPoints = milestone.RequiredPoints,
			FreeReward = cloneReward(milestone.FreeReward),
			PremiumReward = cloneReward(milestone.PremiumReward),
		})
	end

	return milestones
end


function RitualRushConfig.getMilestone(milestoneId)
	if typeof(milestoneId) ~= "string" then
		return nil
	end

	local milestone = RitualRushConfig.Milestones[milestoneId]

	if milestone == nil then
		return nil
	end

	return {
		MilestoneId = milestone.MilestoneId,
		RequiredPoints = milestone.RequiredPoints,
		FreeReward = cloneReward(milestone.FreeReward),
		PremiumReward = cloneReward(milestone.PremiumReward),
	}
end

function RitualRushConfig.getNextMilestone(points)
	local safePoints = getSafeInteger(points)

	for _, milestoneId in ipairs(RitualRushConfig.MilestoneOrder) do
		local milestone = RitualRushConfig.Milestones[milestoneId]

		if safePoints < milestone.RequiredPoints then
			return {
				MilestoneId = milestone.MilestoneId,
				RequiredPoints = milestone.RequiredPoints,
				RemainingPoints = milestone.RequiredPoints - safePoints,
			}
		end
	end

	return nil
end

local function getMilestoneSnapshot(milestone, progress)
	local milestoneId = milestone.MilestoneId

	return {
		MilestoneId = milestoneId,
		RequiredPoints = milestone.RequiredPoints,
		FreeReward = cloneReward(milestone.FreeReward),
		PremiumReward = cloneReward(milestone.PremiumReward),
		IsReached = progress.Points >= milestone.RequiredPoints,
		IsFreeClaimed = progress.ClaimedFreeMilestones[milestoneId] == true,
		IsPremiumClaimed = progress.ClaimedPremiumMilestones[milestoneId] == true,
	}
end

function RitualRushConfig.getSnapshot(progress, nowUnix)
	local eventInfo = RitualRushConfig.getCurrentEventInfo(nowUnix)
	local reconciledProgress = RitualRushConfig.reconcileProgress(progress, nowUnix)
	local milestones = {}
	local sourceProgress = {}

	for _, milestoneId in ipairs(RitualRushConfig.MilestoneOrder) do
		table.insert(milestones, getMilestoneSnapshot(RitualRushConfig.Milestones[milestoneId], reconciledProgress))
	end

	for _, sourceId in ipairs(ProfileContract.RushSourceOrder) do
		table.insert(sourceProgress, {
			SourceId = sourceId,
			Points = reconciledProgress.SourcePoints[sourceId] or 0,
			Cap = RitualRushConfig.SourceCaps[sourceId],
		})
	end

	return {
		EventId = eventInfo.EventId,
		DisplayName = RitualRushConfig.DisplayName,
		StartsAtUnix = eventInfo.StartsAtUnix,
		EndsAtUnix = eventInfo.EndsAtUnix,
		Points = reconciledProgress.Points,
		SourcePoints = reconciledProgress.SourcePoints,
		SourceProgress = sourceProgress,
		PremiumUnlocked = reconciledProgress.PremiumUnlocked,
		NextMilestone = RitualRushConfig.getNextMilestone(reconciledProgress.Points),
		Milestones = milestones,
	}
end

return RitualRushConfig
