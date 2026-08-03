local UIIconConfig = {}

UIIconConfig.Icons = {
	Shop = "rbxassetid://118518094306118",
	RollDice = "rbxassetid://124732110683161",
	RitualCore = "rbxassetid://99838496150193",
	AutoRoll = "rbxassetid://130752548008107",
	AutoRollColored = "rbxassetid://115373117077352",
	Rebirth = "rbxassetid://110813377404964",
	PetInventory = "rbxassetid://131674770644573",
	Teleporter = "rbxassetid://125969952273538",
	Essence = "rbxassetid://79145626472114",
	Close = "rbxassetid://136204663387521",
	RollViewHidden = "rbxassetid://101563112674664",
}

UIIconConfig.IconOrder = {
	"Shop",
	"RollDice",
	"RitualCore",
	"AutoRoll",
	"AutoRollColored",
	"Rebirth",
	"PetInventory",
	"Teleporter",
	"Essence",
	"Close",
	"RollViewHidden",
}

function UIIconConfig.getIcon(iconId)
	return UIIconConfig.Icons[iconId]
end

return UIIconConfig
