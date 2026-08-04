local UIIconConfig = {}

UIIconConfig.Icons = {
	Shop = "", RollDice = "", RitualCore = "", Daily = "", Friends = "", Pets = "", Zones = "", More = "", Close = "",
	AutoRoll = "",
	AutoRollColored = "",
	Rebirth = "",
	PetInventory = "",
	Teleporter = "",
	Essence = "",
	RollViewHidden = "",
}

UIIconConfig.Glyphs = {
	Shop = "¢", RollDice = "✦", RitualCore = "◈", Daily = "◷", Friends = "♧", Pets = "♢", Zones = "⌖", More = "•••", Close = "×",
	AutoRoll = "↻", AutoRollColored = "↻", Rebirth = "↟", PetInventory = "♢", Teleporter = "⌖", Essence = "✧", RollViewHidden = "◌",
}

function UIIconConfig.getIcon(iconId)
	return UIIconConfig.Icons[iconId]
end

function UIIconConfig.getGlyph(iconId)
	return UIIconConfig.Glyphs[iconId] or "•"
end

return UIIconConfig
