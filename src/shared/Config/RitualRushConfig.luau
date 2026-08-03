local PotionConfig = require(script.Parent:WaitForChild("PotionConfig"))

local RitualRushConfig = {}

RitualRushConfig.EventIdPrefix = "ritual_rush"
RitualRushConfig.EventDurationSeconds = 24 * 60 * 60
RitualRushConfig.DisplayName = "Ritual Rush"

RitualRushConfig.PointSources = {
	RollPet = "RollPet",
	CrystalBroken = "CrystalBroken",
	BuyStoneUpgrade = "BuyStoneUpgrade",
	UnlockZone = "UnlockZone",
	Rebirth = "Rebirth",
}

RitualRushConfig.PointsBySource = {
	[RitualRushConfig.PointSources.RollPet] = 1,
	[RitualRushConfig.PointSources.CrystalBroken] = 3,
	[RitualRushConfig.PointSources.BuyStoneUpgrade] = 10,
	[RitualRushConfig.PointSources.UnlockZone] = 50,
	[RitualRushConfig.PointSources.Rebirth] = 200,
}

RitualRushConfig.MilestoneOrder = {
	"points_10",
	"points_25",
	"points_50",
	"points_100",
	"points_250",
	"points_500",
	"points_1000",
}

RitualRushConfig.Milestones = {
	points_10 = {
		MilestoneId = "points_10",
		RequiredPoints = 10,
		FreeReward = {
			Essence = 75,
		},
		PremiumReward = {
			RitualGems = 3,
		},
	},
	points_25 = {
		MilestoneId = "points_25",
		RequiredPoints = 25,
		FreeReward = {
			RitualGems = 5,
		},
		PremiumReward = {
			Essence = 125,
		},
	},
	points_50 = {
		MilestoneId = "points_50",
		RequiredPoints = 50,
		FreeReward = {
			Essence = 180,
			Potions = {
				{
					PotionId = PotionConfig.PotionIds.Essence2x15m,
					Count = 1,
				},
			},
		},
		PremiumReward = {
			RitualGems = 8,
		},
	},
	points_100 = {
		MilestoneId = "points_100",
		RequiredPoints = 100,
		FreeReward = {
			RitualGems = 10,
			Potions = {
				{
					PotionId = PotionConfig.PotionIds.Luck2x15m,
					Count = 1,
				},
			},
		},
		PremiumReward = {
			Essence = 350,
		},
	},
	points_250 = {
		MilestoneId = "points_250",
		RequiredPoints = 250,
		FreeReward = {
			Essence = 700,
		},
		PremiumReward = {
			RitualGems = 20,
		},
	},
	points_500 = {
		MilestoneId = "points_500",
		RequiredPoints = 500,
		FreeReward = {
			Essence = 1500,
			RitualGems = 20,
		},
		PremiumReward = {
			RitualGems = 40,
		},
	},
	points_1000 = {
		MilestoneId = "points_1000",
		RequiredPoints = 1000,
		FreeReward = {
			Essence = 4000,
			RitualGems = 50,
		},
		PremiumReward = {
			RitualGems = 100,
		},
	},
}

local function getSafeRewardAmount(amount)
	if typeof(amount) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(amount))
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
	local clone = {
		Essence = 0,
		RitualGems = 0,
		Potions = {},
	}

	if typeof(reward) ~= "table" then
		return clone
	end

	clone.Essence = getSafeRewardAmount(reward.Essence)
	clone.RitualGems = getSafeRewardAmount(reward.RitualGems)
	clone.Potions = cloneRewardPotions(reward.Potions)

	return clone
end

local function getCurrentUnixTime(nowUnix)
	if typeof(nowUnix) == "number" then
		return math.max(0, math.floor(nowUnix))
	end

	return DateTime.now().UnixTimestamp
end

local function cloneClaimedMilestones(claimedMilestones)
	local clone = {}

	if typeof(claimedMilestones) ~= "table" then
		return clone
	end

	for _, milestoneId in ipairs(RitualRushConfig.MilestoneOrder) do
		if claimedMilestones[milestoneId] == true then
			clone[milestoneId] = true
		end
	end

	return clone
end

local function getSafePoints(points)
	if typeof(points) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(points))
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

local function getMilestoneSnapshot(milestone, progress)
	local points = progress.Points or 0
	local milestoneId = milestone.MilestoneId

	return {
		MilestoneId = milestoneId,
		RequiredPoints = milestone.RequiredPoints,
		FreeReward = cloneReward(milestone.FreeReward),
		PremiumReward = cloneReward(milestone.PremiumReward),
		IsReached = points >= milestone.RequiredPoints,
		IsFreeClaimed = progress.ClaimedFreeMilestones[milestoneId] == true,
		IsPremiumClaimed = progress.ClaimedPremiumMilestones[milestoneId] == true,
	}
end

function RitualRushConfig.createDefaultProgress(nowUnix)
	local eventInfo = RitualRushConfig.getCurrentEventInfo(nowUnix)

	return {
		EventId = eventInfo.EventId,
		Points = 0,
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
		EventId = eventInfo.EventId,
		Points = getSafePoints(progress.Points),
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

function RitualRushConfig.getMilestones()
	local milestones = {}

	for _, milestoneId in ipairs(RitualRushConfig.MilestoneOrder) do
		local milestone = RitualRushConfig.Milestones[milestoneId]

		if milestone ~= nil then
			table.insert(milestones, {
				MilestoneId = milestone.MilestoneId,
				RequiredPoints = milestone.RequiredPoints,
				FreeReward = cloneReward(milestone.FreeReward),
				PremiumReward = cloneReward(milestone.PremiumReward),
			})
		end
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
	local safePoints = getSafePoints(points)

	for _, milestoneId in ipairs(RitualRushConfig.MilestoneOrder) do
		local milestone = RitualRushConfig.Milestones[milestoneId]

		if milestone ~= nil and safePoints < milestone.RequiredPoints then
			return {
				MilestoneId = milestone.MilestoneId,
				RequiredPoints = milestone.RequiredPoints,
				RemainingPoints = milestone.RequiredPoints - safePoints,
			}
		end
	end

	return nil
end

function RitualRushConfig.getSnapshot(progress, nowUnix)
	local eventInfo = RitualRushConfig.getCurrentEventInfo(nowUnix)
	local reconciledProgress = RitualRushConfig.reconcileProgress(progress, nowUnix)
	local milestones = {}

	for _, milestoneId in ipairs(RitualRushConfig.MilestoneOrder) do
		local milestone = RitualRushConfig.Milestones[milestoneId]

		if milestone ~= nil then
			table.insert(milestones, getMilestoneSnapshot(milestone, reconciledProgress))
		end
	end

	return {
		EventId = eventInfo.EventId,
		DisplayName = RitualRushConfig.DisplayName,
		StartsAtUnix = eventInfo.StartsAtUnix,
		EndsAtUnix = eventInfo.EndsAtUnix,
		Points = reconciledProgress.Points,
		PremiumUnlocked = reconciledProgress.PremiumUnlocked,
		NextMilestone = RitualRushConfig.getNextMilestone(reconciledProgress.Points),
		Milestones = milestones,
	}
end

return RitualRushConfig
