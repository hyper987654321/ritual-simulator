local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AscensionConfig = require(Config:WaitForChild("AscensionConfig"))
local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local RuneFocusConfig = require(Config:WaitForChild("RuneFocusConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))

local OnboardingProgress = {}

local REWARDS = {
	first_roll = { Essence = 25 },
	first_stone_upgrade = { RitualGems = 5 },
	first_rebirth = { RitualGems = 10, PotionId = "essence_potion_2x_15m", PotionCount = 1 },
}

local GOAL_IDS = {
	first_roll = true, entered_crystal_zone = true, first_stone_upgrade = true,
	zone_2_unlocked = true, zone_3_unlocked = true, first_rebirth = true,
	rune_focus_selected = true,
	away_rewards_pending = true, select_rune_focus = true, ascension_ready = true,
	rebirth_ready = true, unlock_zone = true, capacity_blocked = true,
	farm_zone = true, v1_complete = true,
}

local CTA_IDS = {
	away_rewards = true, rune_focus = true, ascension = true, rebirth = true,
	zone_travel = true, ritual_stone = true, crystal_area = true, roll = true,
}

local function integer(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, ProfileContract.MaximumExactInteger)
end

local function ensure(profile)
	local onboarding = if typeof(profile.Onboarding) == "table" then profile.Onboarding else {}
	onboarding.Version = 1
	onboarding.Milestones = if typeof(onboarding.Milestones) == "table" then onboarding.Milestones else {}
	onboarding.Rewarded = if typeof(onboarding.Rewarded) == "table" then onboarding.Rewarded else {}
	profile.Onboarding = onboarding
	return onboarding
end

local function add(profile, field, amount)
	local current = integer(profile[field])
	profile[field] = current + math.min(integer(amount), ProfileContract.MaximumExactInteger - current)
	return profile[field] - current
end

local function getCapacity(profile, context)
	if typeof(context) == "table" and typeof(context.getCapacity) == "function" then
		return integer(context.getCapacity(profile))
	end
	local contextCapacity = if typeof(context) == "table" then context.Capacity else nil
	if contextCapacity ~= nil then
		return integer(contextCapacity)
	end
	return integer(profile.Capacity or profile.HighestCapacity)
end

local function getRewardedMilestone(profile, milestoneId, context)
	local onboarding = ensure(profile)
	if onboarding.Milestones[milestoneId] == true then
		return { Changed = false, MilestoneId = milestoneId, Reward = {} }
	end
	-- Only authoritative gameplay callsites may invoke this operation.
	if typeof(context) ~= "table" or context.Authoritative ~= true then
		return { Changed = false, Code = "milestone_not_authoritative", Reward = {} }
	end
	if table.find(ProfileContract.OnboardingMilestoneOrder, milestoneId) == nil then
		return { Changed = false, Code = "unknown_milestone", Reward = {} }
	end

	onboarding.Milestones[milestoneId] = true
	local reward = REWARDS[milestoneId]
	local granted = {}
	if reward ~= nil and onboarding.Rewarded[milestoneId] ~= true then
		if reward.Essence ~= nil then
			local available = math.max(0, getCapacity(profile, context) - integer(profile.Essence))
			local amount = math.min(reward.Essence, available)
			granted.Essence = add(profile, "Essence", amount)
		elseif reward.RitualGems ~= nil then
			granted.RitualGems = add(profile, "RitualGems", reward.RitualGems)
		end
		if reward.PotionId ~= nil then
			if typeof(context.grantPotion) == "function" then
				context.grantPotion(profile, reward.PotionId, reward.PotionCount)
			else
				profile.Potions = if typeof(profile.Potions) == "table" then profile.Potions else {}
				profile.Potions[reward.PotionId] = integer(profile.Potions[reward.PotionId]) + reward.PotionCount
			end
			granted.Potions = { [reward.PotionId] = reward.PotionCount }
		end
		onboarding.Rewarded[milestoneId] = true
	end
	return { Changed = true, MilestoneId = milestoneId, Reward = granted }
end

function OnboardingProgress.ensure(profile)
	return ensure(profile)
end

function OnboardingProgress.complete(profile, milestoneId, context)
	if typeof(profile) ~= "table" then
		return { Changed = false, Code = "profile_unavailable", Reward = {} }
	end
	return getRewardedMilestone(profile, milestoneId, context)
end

OnboardingProgress.completeMilestone = OnboardingProgress.complete

function OnboardingProgress.updateGuidance(profile, values)
	if typeof(profile) ~= "table" or typeof(values) ~= "table" then
		return false
	end
	local onboarding = ensure(profile)
	local changed = false
	for _, key in ipairs({ "IntroSeen", "GuidanceHidden" }) do
		if values[key] ~= nil then
			if typeof(values[key]) ~= "boolean" then return false end
			onboarding[key] = values[key]
			changed = true
		end
	end
	return changed
end

local function goal(goalId, title, description, current, required, ready, cta)
	if not GOAL_IDS[goalId] or (cta ~= nil and not CTA_IDS[cta]) then return nil end
	return {
		GoalId = goalId, TitleKey = "goal." .. goalId .. ".title",
		DescriptionKey = "goal." .. goalId .. ".description", Current = integer(current),
		Required = integer(required), IsReady = ready == true, CtaId = cta,
	}
end

function OnboardingProgress.buildGoal(profile, context)
	if typeof(profile) ~= "table" then return nil end
	local source = if typeof(context) == "table" then context else {}
	local onboarding = ensure(profile)
	for _, milestoneId in ipairs(ProfileContract.OnboardingMilestoneOrder) do
		if onboarding.Milestones[milestoneId] ~= true then
			local current, required, cta = integer(profile.Rolls), 1, "roll"
			if milestoneId == "entered_crystal_zone" then current, cta = if source.InCrystalArea == true then 1 else 0, "crystal_area"
			elseif milestoneId == "first_stone_upgrade" then current, cta = integer(source.StoneUpgradeLevels or profile.StoneLevels and profile.StoneLevels.Capacity), "ritual_stone"
			elseif milestoneId == "zone_2_unlocked" then current, cta = if profile.UnlockedZones and profile.UnlockedZones[2] then 1 else 0, "zone_travel"
			elseif milestoneId == "zone_3_unlocked" then current, cta = if profile.UnlockedZones and profile.UnlockedZones[3] then 1 else 0, "zone_travel"
			elseif milestoneId == "first_rebirth" then current, required, cta = integer(profile.Rebirths), 1, "rebirth"
			elseif milestoneId == "rune_focus_selected" then current, cta = if profile.RuneFocus and profile.RuneFocus.ActiveId ~= nil then 1 else 0, "rune_focus"
			end
			return goal(milestoneId, "", "", current, required, current >= required, cta)
		end
	end
	if source.HasPendingAwayRewards == true or profile.AwayRewards and profile.AwayRewards.Pending ~= nil then return goal("away_rewards_pending", "", "", 1, 1, true, "away_rewards") end
	if RuneFocusConfig.canUseFocus(profile.UnlockedZones, profile.Rebirths) and (profile.RuneFocus == nil or profile.RuneFocus.ActiveId == nil) then return goal("select_rune_focus", "", "", 0, 1, true, "rune_focus") end
	local ascension = source.Ascension or {}
	local canAscend = source.CanAscend == true or ascension.CanAscend == true
	if canAscend then return goal("ascension_ready", "", "", 1, 1, true, "ascension") end
	local rebirthRequirement = RitualStoneConfig.getRebirthRequirement(profile.Rebirths)
	local canRebirth = source.CanRebirth == true or (integer(profile.Essence) >= rebirthRequirement.RequiredEssence and profile.UnlockedZones and profile.UnlockedZones[rebirthRequirement.RequiredZone] == true)
	if canRebirth then return goal("rebirth_ready", "", "", integer(profile.Essence), rebirthRequirement.RequiredEssence, true, "rebirth") end
	local nextZoneId = integer(source.NextZoneId)
	if nextZoneId == 0 then nextZoneId = integer(profile.CurrentZone) + 1 end
	local nextZone = ZoneConfig.getZone(nextZoneId)
	if nextZone ~= nil and profile.UnlockedZones and profile.UnlockedZones[nextZoneId] ~= true then
		local cost = integer(nextZone.UnlockCost)
		if integer(profile.Essence) >= cost then return goal("unlock_zone", "", "", integer(profile.Essence), cost, true, "zone_travel") end
		if integer(profile.Essence) >= getCapacity(profile, source) then return goal("capacity_blocked", "", "", integer(profile.Essence), getCapacity(profile, source), false, "ritual_stone") end
		return goal("farm_zone", "", "", integer(profile.Essence), cost, false, "crystal_area")
	end
	if integer(profile.Ascensions) >= #AscensionConfig.Milestones then return goal("v1_complete", "", "", integer(profile.Ascensions), #AscensionConfig.Milestones, true, nil) end
	return goal("farm_zone", "", "", integer(profile.Essence), integer(getCapacity(profile, source)), false, "crystal_area")
end

return OnboardingProgress
