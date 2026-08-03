local CommonComponents = script.Parent.Parent:WaitForChild("Common")
local HudIconBar = require(CommonComponents:WaitForChild("HudIconBar"))

local HudLayoutConfig = {}

HudLayoutConfig.DefaultViewportSize = Vector2.new(1280, 720)
HudLayoutConfig.HudControlBottomOffset = 0
HudLayoutConfig.RollButtonPosition = UDim2.new(0.5, 0, 1, -HudLayoutConfig.HudControlBottomOffset)
HudLayoutConfig.RollButtonAnchor = Vector2.new(0.5, 1)
HudLayoutConfig.CurrencyDisplayPosition = UDim2.new(0, 22, 1, -24)
HudLayoutConfig.CurrencyDisplayAnchor = Vector2.new(0, 1)
HudLayoutConfig.CurrencyDisplaySize = UDim2.fromOffset(260, 116)
HudLayoutConfig.CurrencyDisplayGap = 4
HudLayoutConfig.CurrencyRowHeight = 54
HudLayoutConfig.CurrencyRowGap = 2
HudLayoutConfig.CurrencyIconSize = 50
HudLayoutConfig.CurrencyTextSize = 36
HudLayoutConfig.CurrencyMinTextSize = 20
HudLayoutConfig.RightHudActionPosition = UDim2.new(1, -8, 0.5, 0)
HudLayoutConfig.RightHudActionAnchor = Vector2.new(1, 0.5)
HudLayoutConfig.RightHudActionScale = 0.68
HudLayoutConfig.RollTutorialTargetSize = UDim2.fromOffset(HudIconBar.ButtonSize, HudIconBar.ButtonSize)

return HudLayoutConfig
