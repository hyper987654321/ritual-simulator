local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local AscensionConfig = require(Config:WaitForChild("AscensionConfig"))
local PresentationEventConfig = require(Config:WaitForChild("PresentationEventConfig"))
local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local RitualRushConfig = require(Config:WaitForChild("RitualRushConfig"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local RuneFocusConfig = require(Config:WaitForChild("RuneFocusConfig"))

local Systems = script.Parent.Parent
local PlayerFeedbackQueue = require(Systems:WaitForChild("Player"):WaitForChild("PlayerFeedbackQueue"))
local RitualRushProgress = require(script.Parent:WaitForChild("RitualRushProgress"))

local RitualStoneProgress = {}

local function getSafeInteger(value, maximum)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.clamp(math.floor(value), 0, maximum)
end

local function getPermanentStats(profile, levelOverrides)
	local runeFocus = if typeof(profile.RuneFocus) == "table" then profile.RuneFocus else {}
	local runeBonuses = RuneFocusConfig.getBonuses(runeFocus.Levels)
	local ascensionBonuses = AscensionConfig.getStatBonuses(profile)
	local sourceLevels = if typeof(profile.StoneLevels) == "table" then profile.StoneLevels else {}
	local levels = if typeof(levelOverrides) == "table" then levelOverrides else sourceLevels

	return RitualStoneConfig.getStats(levels, profile.Rebirths, runeBonuses, ascensionBonuses)
end

local function completeFirstUpgradeMilestone(profile)
	local onboarding = if typeof(profile.Onboarding) == "table" then profile.Onboarding else {}
	local milestones = if typeof(onboarding.Milestones) == "table" then onboarding.Milestones else {}

	onboarding.Version = 1
	onboarding.IntroSeen = onboarding.IntroSeen == true
	onboarding.GuidanceHidden = onboarding.GuidanceHidden == true
	onboarding.Milestones = milestones
	onboarding.Rewarded = if typeof(onboarding.Rewarded) == "table" then onboarding.Rewarded else {}
	profile.Onboarding = onboarding
	milestones.first_stone_upgrade = true
end

local function failure(code, message, upgradeId)
	return {
		Ok = false,
		Changed = false,
		Code = code,
		Message = message,
		UpgradeId = upgradeId,
	}
end

function RitualStoneProgress.inspectPurchase(profile, upgradeId)
	if typeof(profile) ~= "table" then
		return failure("profile_not_ready", "Player profile is not ready.", upgradeId)
	end

	if
		typeof(upgradeId) ~= "string"
		or #upgradeId == 0
		or #upgradeId > ProfileContract.MaximumIdentifierLength
	then
		return failure("invalid_stone_upgrade", "Choose a configured Ritual Stone upgrade.", nil)
	end

	local upgrade = RitualStoneConfig.Upgrades[upgradeId]

	if upgrade == nil or table.find(RitualStoneConfig.UpgradeOrder, upgradeId) == nil then
		return failure("invalid_stone_upgrade", "Choose a configured Ritual Stone upgrade.", upgradeId)
	end

	local levels = if typeof(profile.StoneLevels) == "table" then profile.StoneLevels else {}
	local currentLevel = getSafeInteger(levels[upgradeId], upgrade.MaxLevel)

	if currentLevel >= upgrade.MaxLevel then
		return failure("stone_upgrade_maxed", "Stone upgrade is already maxed.", upgradeId)
	end

	if upgradeId == "RollSpeed" then
		local simulatedLevels = table.clone(levels)
		simulatedLevels[upgradeId] = currentLevel + 1
		local currentStats = getPermanentStats(profile, levels)
		local nextStats = getPermanentStats(profile, simulatedLevels)

		-- Active boosts are intentionally absent. Permanent Roll Speed may still be
		-- purchased while a temporary potion happens to reach the runtime cap.
		if nextStats.RollSpeedPercent <= currentStats.RollSpeedPercent then
			return failure(
				"stone_upgrade_effective_cap",
				"Stone upgrade has reached its effective cap.",
				upgradeId
			)
		end
	end

	local cost = RitualStoneConfig.getUpgradeCost(upgradeId, currentLevel)

	if
		typeof(cost) ~= "number"
		or cost ~= cost
		or math.abs(cost) == math.huge
		or cost ~= math.floor(cost)
		or cost < 1
		or cost > ProfileContract.MaximumExactInteger
	then
		return failure("stone_upgrade_cost_unavailable", "Stone upgrade cost is not configured.", upgradeId)
	end

	local essence = getSafeInteger(profile.Essence, ProfileContract.MaximumExactInteger)

	if essence < cost then
		local result = failure("insufficient_essence", "Not enough Ritual Essence.", upgradeId)
		result.Cost = cost

		return result
	end

	return {
		Ok = true,
		Changed = false,
		Code = "stone_upgrade_available",
		UpgradeId = upgradeId,
		CurrentLevel = currentLevel,
		NextLevel = currentLevel + 1,
		Cost = cost,
		Essence = essence,
	}
end

function RitualStoneProgress.purchase(profile, upgradeId)
	local inspection = RitualStoneProgress.inspectPurchase(profile, upgradeId)

	if inspection.Ok ~= true then
		return inspection
	end

	local levels = if typeof(profile.StoneLevels) == "table" then profile.StoneLevels else {}

	-- This is the single non-yielding currency/level mutation used by both the
	-- manual action and Auto Capacity. The inspection immediately above is
	-- repeated on every call, so stale levels, costs, and balances cannot pass.
	profile.Essence = inspection.Essence - inspection.Cost
	levels[upgradeId] = inspection.NextLevel
	profile.StoneLevels = levels
	completeFirstUpgradeMilestone(profile)
	local rushPointsAwarded = RitualRushProgress.awardPoints(
		profile,
		RitualRushConfig.PointSources.BuyStoneUpgrade
	)

	return {
		Ok = true,
		Changed = true,
		Code = "stone_upgrade_purchased",
		Message = "Ritual Stone upgraded.",
		UpgradeId = upgradeId,
		LevelsBought = 1,
		Level = inspection.NextLevel,
		EssenceSpent = inspection.Cost,
		Cost = inspection.Cost,
		RushPointsAwarded = rushPointsAwarded,
	}
end

function RitualStoneProgress.isAutoCapacityEnabled(profile)
	local automation = if typeof(profile) == "table" and typeof(profile.Automation) == "table"
		then profile.Automation
		else {}
	local rebirths = if typeof(profile) == "table"
		then getSafeInteger(profile.Rebirths, ProfileContract.MaximumExactInteger)
		else 0

	return rebirths >= RitualStoneConfig.AutoCapacity.RequiredRebirths
		and automation.AutoCapacityEnabled == true
end

function RitualStoneProgress.queueAutoCapacityFeedback(profile, result)
	if
		typeof(result) ~= "table"
		or getSafeInteger(result.LevelsBought, ProfileContract.MaximumExactInteger) <= 0
	then
		return nil
	end

	return PlayerFeedbackQueue.queue(
		profile,
		PresentationEventConfig.EventIds.AutoCapacityPurchase,
		{
			UpgradeId = "Capacity",
			LevelsBought = result.LevelsBought,
			Level = result.Level,
			EssenceSpent = result.EssenceSpent,
		}
	)
end

function RitualStoneProgress.purchaseAutoCapacity(profile, options)
	if not RitualStoneProgress.isAutoCapacityEnabled(profile) then
		return {
			Ok = true,
			Changed = false,
			Code = "auto_capacity_inactive",
			LevelsBought = 0,
			EssenceSpent = 0,
		}
	end

	local levelsBought = 0
	local essenceSpent = 0
	local rushPointsAwarded = 0
	local lastLevel = getSafeInteger(
		typeof(profile.StoneLevels) == "table" and profile.StoneLevels.Capacity or 0,
		RitualStoneConfig.Upgrades.Capacity.MaxLevel
	)
	local sourceOptions = if typeof(options) == "table" then options else {}
	local purchaseLimit = math.min(
		RitualStoneConfig.AutoCapacity.MaxPurchasesPerInvocation,
		getSafeInteger(
			sourceOptions.MaxPurchases,
			RitualStoneConfig.AutoCapacity.MaxPurchasesPerInvocation
		)
	)

	if sourceOptions.MaxPurchases == nil then
		purchaseLimit = RitualStoneConfig.AutoCapacity.MaxPurchasesPerInvocation
	end

	for _ = 1, purchaseLimit do
		local purchase = RitualStoneProgress.purchase(profile, "Capacity")

		if purchase.Ok ~= true then
			break
		end

		levelsBought = math.min(
			RitualStoneConfig.AutoCapacity.MaxPurchasesPerInvocation,
			levelsBought + 1
		)
		essenceSpent = math.min(
			ProfileContract.MaximumExactInteger,
			essenceSpent + math.min(
				getSafeInteger(purchase.EssenceSpent, ProfileContract.MaximumExactInteger),
				ProfileContract.MaximumExactInteger - essenceSpent
			)
		)
		rushPointsAwarded = math.min(
			ProfileContract.MaximumExactInteger,
			rushPointsAwarded + math.min(
				getSafeInteger(purchase.RushPointsAwarded, ProfileContract.MaximumExactInteger),
				ProfileContract.MaximumExactInteger - rushPointsAwarded
			)
		)
		lastLevel = purchase.Level
	end

	local stats = getPermanentStats(profile)

	local result = {
		Ok = true,
		Changed = levelsBought > 0,
		Code = if levelsBought > 0 then "auto_capacity_purchased" else "auto_capacity_no_purchase",
		UpgradeId = "Capacity",
		LevelsBought = levelsBought,
		Level = lastLevel,
		EssenceSpent = essenceSpent,
		RushPointsAwarded = rushPointsAwarded,
		Capacity = stats.Capacity,
	}

	if sourceOptions.QueueFeedback ~= false then
		RitualStoneProgress.queueAutoCapacityFeedback(profile, result)
	end

	return result
end

return RitualStoneProgress
