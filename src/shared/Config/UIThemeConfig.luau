local UIThemeConfig = {}

UIThemeConfig.Font = Enum.Font.Gotham
UIThemeConfig.FontBold = Enum.Font.GothamBold
UIThemeConfig.Type = { Caption = 11, Label = 14, Body = 16, Button = 15, Value = 18, Title = 24 }
UIThemeConfig.Spacing = { Xs = 4, Sm = 8, Md = 12, Lg = 16, Xl = 24, Xxl = 32 }
UIThemeConfig.Radius = { Control = 8, Panel = 12, Dock = 16 }
UIThemeConfig.PanelTransparency = 0.05
UIThemeConfig.Colors = {
	Ink = Color3.fromRGB(245, 240, 255),
	Muted = Color3.fromRGB(170, 178, 198),
	Panel = Color3.fromRGB(13, 18, 34),
	Card = Color3.fromRGB(27, 35, 58),
	Violet = Color3.fromRGB(119, 82, 224),
	Cyan = Color3.fromRGB(81, 211, 232),
	Gold = Color3.fromRGB(244, 191, 74),
	Accent = Color3.fromRGB(244, 191, 74),
	Action = Color3.fromRGB(119, 82, 224),
	Success = Color3.fromRGB(104, 220, 150),
	Locked = Color3.fromRGB(82, 77, 103),
	Stroke = Color3.fromRGB(112, 124, 157),
}

return UIThemeConfig
