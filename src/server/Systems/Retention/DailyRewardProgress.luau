local DailyRewardProgress = {}

DailyRewardProgress.SecondsPerDay = 86_400
DailyRewardProgress.CycleRewards = { 5, 5, 10, 10, 15, 15, 20 }
DailyRewardProgress.FirstRebirthGemReward = 10
DailyRewardProgress.FirstRebirthRushReward = 75
DailyRewardProgress.FirstRebirthRushSource = "first_rebirth_daily"
DailyRewardProgress.MaximumExactInteger = 9_007_199_254_740_991

local function getServerNowUnix(nowUnix)
	if typeof(nowUnix) == "number" and nowUnix == nowUnix and math.abs(nowUnix) ~= math.huge then
		return math.max(0, math.floor(nowUnix))
	end

	return DateTime.now().UnixTimestamp
end

local function isInteger(value)
	return typeof(value) == "number"
		and value == value
		and math.abs(value) ~= math.huge
		and value % 1 == 0
end

local function getDayIndex(nowUnix)
	return math.floor(getServerNowUnix(nowUnix) / DailyRewardProgress.SecondsPerDay)
end

local function getDailyState(profile)
	local source = if typeof(profile.DailyRewards) == "table" then profile.DailyRewards else {}
	profile.DailyRewards = source
	source.Version = 1

	return source
end

local function clampInteger(value, minimum, maximum, fallback)
	if not isInteger(value) then
		return fallback
	end

	return math.clamp(value, minimum, maximum)
end

local function normalizeDailyState(profile, dayIndex)
	local daily = getDailyState(profile)
	daily.LastClaimedDay = clampInteger(
		daily.LastClaimedDay,
		-1,
		DailyRewardProgress.MaximumExactInteger,
		-1
	)
	daily.CycleDay = clampInteger(daily.CycleDay, 0, #DailyRewardProgress.CycleRewards, 0)
	daily.FirstRebirthRewardDay = clampInteger(
		daily.FirstRebirthRewardDay,
		-1,
		DailyRewardProgress.MaximumExactInteger,
		-1
	)

	if daily.LastClaimedDay > dayIndex then
		daily.LastClaimedDay = dayIndex
	end

	if daily.FirstRebirthRewardDay > dayIndex then
		daily.FirstRebirthRewardDay = dayIndex
	end

	return daily
end

local function nextCycleDay(daily, dayIndex)
	if daily.LastClaimedDay == dayIndex then
		return daily.CycleDay
	end

	if daily.LastClaimedDay == dayIndex - 1 and daily.CycleDay > 0 then
		return daily.CycleDay % #DailyRewardProgress.CycleRewards + 1
	end

	return 1
end

local function addBounded(current, amount)
	local safeCurrent = clampInteger(current, 0, DailyRewardProgress.MaximumExactInteger, 0)

	return safeCurrent + math.min(amount, DailyRewardProgress.MaximumExactInteger - safeCurrent)
end

local function copyCycleRewards()
	return {
		DailyRewardProgress.CycleRewards[1],
		DailyRewardProgress.CycleRewards[2],
		DailyRewardProgress.CycleRewards[3],
		DailyRewardProgress.CycleRewards[4],
		DailyRewardProgress.CycleRewards[5],
		DailyRewardProgress.CycleRewards[6],
		DailyRewardProgress.CycleRewards[7],
	}
end

function DailyRewardProgress.getDayIndex(serverNowUnix)
	return getDayIndex(serverNowUnix)
end

function DailyRewardProgress.getDayWindow(serverNowUnix)
	local dayIndex = getDayIndex(serverNowUnix)
	local startsAtUnix = dayIndex * DailyRewardProgress.SecondsPerDay

	return {
		DayIndex = dayIndex,
		StartsAtUnix = startsAtUnix,
		EndsAtUnix = startsAtUnix + DailyRewardProgress.SecondsPerDay,
	}
end

function DailyRewardProgress.buildSnapshot(profile, serverNowUnix)
	local nowUnix = getServerNowUnix(serverNowUnix)
	local dayIndex = getDayIndex(nowUnix)
	local daily = normalizeDailyState(profile, dayIndex)
	local isClaimedToday = daily.LastClaimedDay == dayIndex
	local claimCycleDay = nextCycleDay(daily, dayIndex)

	return {
		DayIndex = dayIndex,
		StartsAtUnix = dayIndex * DailyRewardProgress.SecondsPerDay,
		EndsAtUnix = (dayIndex + 1) * DailyRewardProgress.SecondsPerDay,
		IsClaimedToday = isClaimedToday,
		CanClaim = not isClaimedToday,
		CurrentCycleDay = daily.CycleDay,
		ClaimCycleDay = claimCycleDay,
		ClaimReward = DailyRewardProgress.CycleRewards[claimCycleDay],
		CycleRewards = copyCycleRewards(),
		FirstRebirthRewardClaimed = daily.FirstRebirthRewardDay == dayIndex,
		FirstRebirthReward = DailyRewardProgress.FirstRebirthGemReward,
	}
end

function DailyRewardProgress.claim(profile, requestedDayIndex, serverNowUnix)
	local nowUnix = getServerNowUnix(serverNowUnix)
	local dayIndex = getDayIndex(nowUnix)
	local daily = normalizeDailyState(profile, dayIndex)

	if not isInteger(requestedDayIndex) or requestedDayIndex ~= dayIndex then
		return {
			Ok = false,
			Changed = false,
			Code = "stale_day",
			Snapshot = DailyRewardProgress.buildSnapshot(profile, nowUnix),
		}
	end

	if daily.LastClaimedDay == dayIndex then
		return {
			Ok = true,
			Changed = false,
			Code = "already_claimed",
			Snapshot = DailyRewardProgress.buildSnapshot(profile, nowUnix),
		}
	end

	local cycleDay = nextCycleDay(daily, dayIndex)
	local reward = DailyRewardProgress.CycleRewards[cycleDay]
	daily.LastClaimedDay = dayIndex
	daily.CycleDay = cycleDay
	profile.RitualGems = addBounded(profile.RitualGems, reward)

	return {
		Ok = true,
		Changed = true,
		Code = "daily_reward_claimed",
		Reward = {
			RitualGems = reward,
			CycleDay = cycleDay,
		},
		Snapshot = DailyRewardProgress.buildSnapshot(profile, nowUnix),
	}
end

function DailyRewardProgress.grantFirstRebirthOfDay(profile, applyRushSource, serverNowUnix)
	local nowUnix = getServerNowUnix(serverNowUnix)
	local dayIndex = getDayIndex(nowUnix)
	local daily = normalizeDailyState(profile, dayIndex)

	if daily.FirstRebirthRewardDay == dayIndex then
		return {
			Ok = true,
			Changed = false,
			Code = "first_rebirth_daily_already_claimed",
			Reward = {
				RitualGems = 0,
				RitualRushPoints = 0,
				Source = DailyRewardProgress.FirstRebirthRushSource,
			},
		}
	end

	if typeof(applyRushSource) ~= "function" then
		return {
			Ok = false,
			Changed = false,
			Code = "rush_integration_required",
		}
	end

	local rushAwarded = clampInteger(
		applyRushSource(profile, DailyRewardProgress.FirstRebirthRushSource, 1, nowUnix),
		0,
		DailyRewardProgress.FirstRebirthRushReward,
		0
	)

	daily.FirstRebirthRewardDay = dayIndex
	profile.RitualGems = addBounded(profile.RitualGems, DailyRewardProgress.FirstRebirthGemReward)

	return {
		Ok = true,
		Changed = true,
		Code = "first_rebirth_daily_bonus",
		Reward = {
			RitualGems = DailyRewardProgress.FirstRebirthGemReward,
			RitualRushPoints = rushAwarded,
			Source = DailyRewardProgress.FirstRebirthRushSource,
		},
		DayIndex = dayIndex,
	}
end

DailyRewardProgress.claimDailyReward = DailyRewardProgress.claim
DailyRewardProgress.awardFirstRebirthOfDay = DailyRewardProgress.grantFirstRebirthOfDay
DailyRewardProgress.getSnapshot = DailyRewardProgress.buildSnapshot

return DailyRewardProgress
