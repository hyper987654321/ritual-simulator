local ProfileContract = {}

ProfileContract.DataVersion = 9
ProfileContract.MinimumSupportedDataVersion = 5
ProfileContract.MaximumExactInteger = 9_007_199_254_740_991
ProfileContract.MaximumIdentifierLength = 128
ProfileContract.MaximumReceiptLength = 200
ProfileContract.MaximumStoredPotions = 9_999
ProfileContract.MaximumEquippedPets = 3
ProfileContract.MaximumActiveBoostSeconds = 8 * 60 * 60

ProfileContract.Session = {
	LoadTimeoutSeconds = 60,
	ConfirmedSaveTimeoutSeconds = 15,
}

ProfileContract.StoneUpgradeOrder = {
	"Capacity",
	"Luck",
	"RollSpeed",
}

ProfileContract.StoneLevelMaxima = {
	Capacity = 100,
	Luck = 60,
	RollSpeed = 43,
}

ProfileContract.RuneFocusOrder = {
	"capacity",
	"pet_power",
	"ritual_speed",
	"luck",
}

ProfileContract.RuneFocusMaxLevels = {
	capacity = 15,
	pet_power = 20,
	ritual_speed = 15,
	luck = 15,
}

ProfileContract.RuneFocusRequirements = {
	capacity = { BaseCharge = 120, Growth = 1.55 },
	pet_power = { BaseCharge = 140, Growth = 1.60 },
	ritual_speed = { BaseCharge = 160, Growth = 1.60 },
	luck = { BaseCharge = 190, Growth = 1.65 },
}

ProfileContract.AscensionUpgradeOrder = {
	"essence_mastery",
	"starting_capacity",
	"pet_power",
	"ritual_luck",
	"roll_flow",
	"rune_flow",
	"away_ritual",
	"rush_focus",
}

ProfileContract.AscensionUpgradeMaxLevels = {
	essence_mastery = 10,
	starting_capacity = 8,
	pet_power = 10,
	ritual_luck = 8,
	roll_flow = 8,
	rune_flow = 8,
	away_ritual = 6,
	rush_focus = 5,
}

ProfileContract.BoostOrder = {
	"EssenceMultiplier",
	"LuckMultiplier",
	"RollSpeedMultiplier",
	"PetPowerMultiplier",
	"RuneChargeMultiplier",
}

ProfileContract.BoostMultipliers = {
	EssenceMultiplier = 2,
	LuckMultiplier = 2,
	RollSpeedMultiplier = 1.5,
	PetPowerMultiplier = 1.5,
	RuneChargeMultiplier = 1.5,
}

ProfileContract.PotionOrder = {
	"essence_potion_2x_15m",
	"roll_flow_potion_1_5x_15m",
	"pet_power_potion_1_5x_15m",
	"rune_flow_potion_1_5x_15m",
	"luck_potion_2x_15m",
}

ProfileContract.RushSourceOrder = {
	"roll_pet",
	"crystal_break_online",
	"stone_upgrade",
	"rune_level",
	"zone_unlock",
	"rebirth",
	"first_rebirth_daily",
	"ascension",
	"offline_claim",
}

ProfileContract.RushSourceCaps = {
	roll_pet = 500,
	crystal_break_online = 650,
	stone_upgrade = 400,
	rune_level = 250,
	zone_unlock = 360,
	rebirth = 500,
	first_rebirth_daily = 75,
	ascension = 500,
	offline_claim = 0,
}

ProfileContract.OnboardingMilestoneOrder = {
	"first_roll",
	"entered_crystal_zone",
	"first_stone_upgrade",
	"zone_2_unlocked",
	"zone_3_unlocked",
	"first_rebirth",
	"rune_focus_selected",
}

ProfileContract.OnboardingRewardedOrder = {
	"first_roll",
	"first_stone_upgrade",
	"first_rebirth",
}

ProfileContract.DurableRootOrder = {
	"Version",
	"Essence",
	"RitualGems",
	"Rolls",
	"BestRitualPower",
	"HighestCapacity",
	"RarestPetId",
	"RarestPetScore",
	"CurrentZone",
	"UnlockedZones",
	"StoneLevels",
	"Rebirths",
	"Ascensions",
	"AscensionStars",
	"AscensionUpgrades",
	"Automation",
	"RuneFocus",
	"RitualRush",
	"DailyRewards",
	"AwayRewards",
	"Onboarding",
	"Social",
	"Retention",
	"ProcessedPurchaseIds",
	"ActiveBoosts",
	"Potions",
	"Pets",
	"EquippedPetIds",
}

ProfileContract.LegacyDurableRoots = {
	RuneLevels = true,
	TutorialCompletedSteps = true,
}

ProfileContract.RuntimeRoots = {
	RollReadyAt = true,
	CrystalState = true,
	CrystalAttackState = true,
	CrystalAttackSequence = true,
	LastCrystalAttacks = true,
	CrystalFarmingActive = true,
	SnapshotRevision = true,
	ProgressionEpoch = true,
	RuneFocusSelectionReadyAt = true,
	FeedbackSequence = true,
}

function ProfileContract.createRuneNumberMap(defaultValue)
	local result = {}

	for _, focusId in ipairs(ProfileContract.RuneFocusOrder) do
		result[focusId] = defaultValue
	end

	return result
end

function ProfileContract.createAscensionUpgradeMap(defaultValue)
	local result = {}

	for _, upgradeId in ipairs(ProfileContract.AscensionUpgradeOrder) do
		result[upgradeId] = defaultValue
	end

	return result
end

function ProfileContract.createOnboardingMilestoneMap(defaultValue)
	local result = {}

	for _, milestoneId in ipairs(ProfileContract.OnboardingMilestoneOrder) do
		result[milestoneId] = defaultValue
	end

	return result
end

function ProfileContract.createOnboardingRewardedMap(defaultValue)
	local result = {}

	for _, milestoneId in ipairs(ProfileContract.OnboardingRewardedOrder) do
		result[milestoneId] = defaultValue
	end

	return result
end

return ProfileContract
