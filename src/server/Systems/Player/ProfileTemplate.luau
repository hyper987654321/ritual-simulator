local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local BoostConfig = require(Config:WaitForChild("BoostConfig"))
local PotionConfig = require(Config:WaitForChild("PotionConfig"))
local RitualRushConfig = require(Config:WaitForChild("RitualRushConfig"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))

local ProfileTemplate = {}

ProfileTemplate.DATA_VERSION = 5

local function getNonNegativeInteger(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end

	return math.max(0, math.floor(value))
end

function ProfileTemplate.create()
	return {
		Version = ProfileTemplate.DATA_VERSION,
		Essence = 0,
		RitualGems = 1000,
		Rolls = 0,
		BestRitualPower = 0,
		HighestCapacity = RitualStoneConfig.BaseStats.Capacity,
		RarestPetId = nil,
		RarestPetScore = 0,
		CurrentZone = 1,
		UnlockedZones = {
			[1] = true,
		},
		StoneLevels = {
			Capacity = 0,
			Luck = 0,
			RollSpeed = 0,
		},
		RuneLevels = {
			capacity = 0,
			luck = 0,
			ritual_speed = 0,
			pet_power = 0,
		},
		Rebirths = 0,
		Ascensions = 0,
		AscensionStars = 0,
		AscensionUpgrades = {},
		RitualRush = RitualRushConfig.createDefaultProgress(),
		ProcessedPurchaseIds = {},
		ActiveBoosts = {},
		Potions = {},
		TutorialCompletedSteps = {},
		Pets = {},
		EquippedPetIds = {},
	}
end

function ProfileTemplate.applyRuntimeDefaults(profile)
	profile.Version = ProfileTemplate.DATA_VERSION
	profile.RollReadyAt = 0
	profile.CrystalState = nil
	profile.CrystalAttackState = {}
	profile.CrystalAttackSequence = 0
	profile.LastCrystalAttacks = {}
	profile.CrystalFarmingActive = false
	profile.SnapshotRevision = 0
	profile.RitualRush = RitualRushConfig.reconcileProgress(profile.RitualRush)
	profile.ProcessedPurchaseIds = if typeof(profile.ProcessedPurchaseIds) == "table"
		then profile.ProcessedPurchaseIds
		else {}
	profile.ActiveBoosts = BoostConfig.normalizeActiveBoosts(profile.ActiveBoosts)
	profile.Potions = PotionConfig.normalizeInventory(profile.Potions)
	profile.Ascensions = getNonNegativeInteger(profile.Ascensions)
	profile.AscensionStars = getNonNegativeInteger(profile.AscensionStars)
	profile.AscensionUpgrades = if typeof(profile.AscensionUpgrades) == "table" then profile.AscensionUpgrades else {}

	return profile
end

return ProfileTemplate
