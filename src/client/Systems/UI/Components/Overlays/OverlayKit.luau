local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))
local UIBackgroundConfig = require(Config:WaitForChild("UIBackgroundConfig"))
local UIIconConfig = require(Config:WaitForChild("UIIconConfig"))

local Kit = {}
local C = UIThemeConfig.Colors

local function corner(radius)
	return React.createElement("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Kit.label(text, props)
	local resolved = { BackgroundTransparency = 1, Font = UIThemeConfig.Font, Text = tostring(text or ""), TextColor3 = C.Ink, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }
	for key, value in pairs(props or {}) do resolved[key] = value end
	return React.createElement("TextLabel", resolved)
end

function Kit.button(text, props)
	local resolved = { Active = true, AutoButtonColor = true, BackgroundColor3 = C.Action, BorderSizePixel = 0, Font = UIThemeConfig.Font, Text = text, TextColor3 = C.Ink, TextSize = 16 }
	for key, value in pairs(props or {}) do resolved[key] = value end
	return React.createElement("TextButton", resolved, { Corner = corner(10), Stroke = React.createElement("UIStroke", { Color = C.Stroke, Transparency = 0.12 }) })
end

function Kit.icon(iconId, props)
	local resolved = { BackgroundTransparency = 1, Image = UIIconConfig.getIcon(iconId) or "", ScaleType = Enum.ScaleType.Fit }
	for key, value in pairs(props or {}) do resolved[key] = value end
	return React.createElement("ImageLabel", resolved)
end

function Kit.modal(props)
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local mobile = viewport.X < 600
	local width = math.min(props.MaximumWidth or 620, math.max(280, viewport.X - 24))
	local height = math.min(props.MaximumHeight or 520, math.max(280, viewport.Y - 32))
	local z = props.ZIndex or 80
	local children = props.Children or {}
	children.Background = React.createElement("ImageLabel", { BackgroundColor3 = C.Panel, BackgroundTransparency = if UIBackgroundConfig.getBackground(props.BackgroundId) ~= "" then 0.12 else 0, BorderSizePixel = 0, ClipsDescendants = true, Image = UIBackgroundConfig.getBackground(props.BackgroundId) or "", ImageTransparency = 0.18, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = z }, { Corner = corner(18) })
	children.Title = Kit.label(props.Title, { Position = UDim2.fromOffset(22, 18), Size = UDim2.new(1, -92, 0, 38), TextSize = if mobile then 23 else 28, ZIndex = z + 2 })
	children.Rule = React.createElement("Frame", { BackgroundColor3 = C.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(22, 62), Size = UDim2.new(1, -44, 0, 2), ZIndex = z + 2 })
	children.Close = React.createElement("ImageButton", {
		Active = true,
		AnchorPoint = Vector2.new(1, 0),
		AutoButtonColor = true,
		BackgroundTransparency = 1,
		Image = UIIconConfig.getIcon("Close") or "",
		ImageColor3 = C.Muted,
		Position = UDim2.new(1, -10, 0, 10),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(44, 44),
		ZIndex = z + 3,
		[React.Event.Activated] = props.OnClose,
	})
	return React.createElement("Frame", { Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Panel, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, height), ZIndex = z }, children)
end

return Kit
