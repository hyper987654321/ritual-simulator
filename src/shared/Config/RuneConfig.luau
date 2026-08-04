local RuneFocusConfig = require(script.Parent:WaitForChild("RuneFocusConfig"))

-- Compatibility facade for callers that still use the old module name. Rune
-- progression itself is no longer an Essence shop; authoritative consumers
-- should use RuneFocusConfig directly.
local RuneConfig = {}

RuneConfig.Unlock = RuneFocusConfig.Unlock
RuneConfig.RuneOrder = table.clone(RuneFocusConfig.FocusOrder)
RuneConfig.Runes = {}

for _, focusId in ipairs(RuneConfig.RuneOrder) do
	local focus = RuneFocusConfig.getFocus(focusId)

	RuneConfig.Runes[focusId] = {
		DisplayName = focus.DisplayName,
		Description = focus.Description,
		BaseCost = focus.BaseCharge,
		CostGrowth = focus.ChargeGrowth,
		MaxLevel = focus.MaxLevel,
	}
end

function RuneConfig.getRune(runeId)
	return RuneConfig.Runes[runeId]
end

function RuneConfig.getUpgradeCost(runeId, level)
	return RuneFocusConfig.getRequiredCharge(runeId, level)
end

function RuneConfig.getBonuses(runeLevels)
	return RuneFocusConfig.getBonuses(runeLevels)
end

function RuneConfig.canUseRunes(unlockedZones, rebirths)
	return RuneFocusConfig.canUseFocus(unlockedZones, rebirths)
end

return RuneConfig
