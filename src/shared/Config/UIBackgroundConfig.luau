local UIAssetConfig = require(script.Parent:WaitForChild("UIAssetConfig"))

local UIBackgroundConfig = {}

UIBackgroundConfig.Backgrounds = {
	PetInventory = UIAssetConfig.resolveBackground("pet_inventory"),
	RitualCore = UIAssetConfig.resolveBackground("ritual_core"),
	Rebirth = UIAssetConfig.resolveBackground("rebirth"),
}

function UIBackgroundConfig.getBackground(backgroundId)
	return UIBackgroundConfig.Backgrounds[backgroundId]
end

return UIBackgroundConfig
