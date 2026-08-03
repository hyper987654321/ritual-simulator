local UIBackgroundConfig = {}

UIBackgroundConfig.Backgrounds = {
	PetInventory = "rbxassetid://77574148531708",
	RitualCore = "rbxassetid://111076798547714",
	Rebirth = "rbxassetid://104283905221382",
}

function UIBackgroundConfig.getBackground(backgroundId)
	return UIBackgroundConfig.Backgrounds[backgroundId]
end

return UIBackgroundConfig
