local UIAssetConfig = require(script.Parent:WaitForChild("UIAssetConfig"))

local UIIconConfig = {}

UIIconConfig.Icons = {
	Shop = UIAssetConfig.resolveIcon("shop"),
	RollDice = UIAssetConfig.resolveIcon("roll_dice"),
	RitualCore = UIAssetConfig.resolveIcon("ritual_core"),
	AutoRoll = "",
	AutoRollColored = "",
	Rebirth = "",
	PetInventory = UIAssetConfig.resolveIcon("pet_inventory"),
	Teleporter = "",
	Essence = "",
	Close = UIAssetConfig.resolveIcon("close"),
	RollViewHidden = "",
}

UIIconConfig.IconOrder = {
	"Shop", "RollDice", "RitualCore", "AutoRoll", "AutoRollColored", "Rebirth",
	"PetInventory", "Teleporter", "Essence", "Close", "RollViewHidden",
}

function UIIconConfig.getIcon(iconId)
	return UIIconConfig.Icons[iconId]
end

return UIIconConfig
