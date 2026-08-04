local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Theme = require(Config:WaitForChild("UIThemeConfig"))
local Icons = require(Config:WaitForChild("UIIconConfig"))

local Icon = {}

function Icon.create(iconId, props)
	local glyph = Icons.getGlyph(iconId)
	local resolved = { BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), ZIndex = 1 }
	for key, value in pairs(props or {}) do resolved[key] = value end
	local image = Icons.getIcon(iconId)
	if image ~= nil and image ~= "" then
		resolved.Image = image
		resolved.ScaleType = Enum.ScaleType.Fit
		return React.createElement("ImageLabel", resolved)
	end
	return React.createElement("TextLabel", { BackgroundTransparency = 1, Font = Theme.FontBold, Position = resolved.Position, Size = resolved.Size, Text = glyph, TextColor3 = resolved.ImageColor3 or Theme.Colors.Ink, TextSize = resolved.TextSize or 22, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = resolved.ZIndex })
end

return Icon
