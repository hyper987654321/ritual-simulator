local RuneConfig = {}

RuneConfig.Unlock = {
	RequiredZone = 3,
	RequiredRebirths = 1,
}

RuneConfig.Runes = {
	capacity = {
		DisplayName = "Capacity Rune",
		Description = "Permanently increases Ritual Stone capacity.",
		BaseCost = 120,
		CostGrowth = 1.55,
		MaxLevel = 20,
		Bonuses = {
			Capacity = 25,
		},
	},
	luck = {
		DisplayName = "Luck Rune",
		Description = "Permanently improves ritual roll luck.",
		BaseCost = 150,
		CostGrowth = 1.6,
		MaxLevel = 20,
		Bonuses = {
			Luck = 0.04,
		},
	},
	ritual_speed = {
		DisplayName = "Roll Speed Rune",
		Description = "Permanently speeds up pet roll openings.",
		BaseCost = 180,
		CostGrowth = 1.65,
		MaxLevel = 15,
		Bonuses = {
			RollSpeedPercent = 1.2,
		},
	},
	pet_power = {
		DisplayName = "Pet Power Rune",
		Description = "Permanently increases pet crystal damage.",
		BaseCost = 180,
		CostGrowth = 1.65,
		MaxLevel = 20,
		Bonuses = {
			PetPowerMultiplier = 0.04,
		},
	},
}

RuneConfig.RuneOrder = {
	"capacity",
	"luck",
	"ritual_speed",
	"pet_power",
}

function RuneConfig.getRune(runeId)
	return RuneConfig.Runes[runeId]
end

function RuneConfig.getUpgradeCost(runeId, level)
	local rune = RuneConfig.getRune(runeId)

	if rune == nil then
		return nil
	end

	return math.floor(rune.BaseCost * (rune.CostGrowth ^ (level or 0)))
end

function RuneConfig.getBonuses(runeLevels)
	local bonuses = {
		Capacity = 0,
		Luck = 0,
		RollSpeedPercent = 0,
		PetPowerMultiplier = 1,
	}

	for _, runeId in ipairs(RuneConfig.RuneOrder) do
		local rune = RuneConfig.getRune(runeId)
		local level = (runeLevels and runeLevels[runeId]) or 0

		if rune ~= nil and level > 0 then
			bonuses.Capacity += (rune.Bonuses.Capacity or 0) * level
			bonuses.Luck += (rune.Bonuses.Luck or 0) * level
			bonuses.RollSpeedPercent += (rune.Bonuses.RollSpeedPercent or 0) * level
			bonuses.PetPowerMultiplier += (rune.Bonuses.PetPowerMultiplier or 0) * level
		end
	end

	return bonuses
end

function RuneConfig.canUseRunes(unlockedZones, rebirths)
	return (rebirths or 0) >= RuneConfig.Unlock.RequiredRebirths
		and unlockedZones ~= nil
		and unlockedZones[RuneConfig.Unlock.RequiredZone] == true
end

return RuneConfig
