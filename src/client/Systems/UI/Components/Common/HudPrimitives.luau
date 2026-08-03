local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local HudPrimitives = {}

function HudPrimitives.mergeProps(baseProps, extraProps)
	local props = {}

	for key, value in pairs(baseProps or {}) do
		props[key] = value
	end

	for key, value in pairs(extraProps or {}) do
		props[key] = value
	end

	return props
end

local function copyChildren(children)
	local result = {}

	for key, value in pairs(children or {}) do
		result[key] = value
	end

	return result
end

function HudPrimitives.createCorner(radius)
	return React.createElement("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
	})
end

function HudPrimitives.createStroke(color, transparency)
	return React.createElement("UIStroke", {
		Color = color or Color3.fromRGB(255, 255, 255),
		Transparency = transparency or 0.7,
		Thickness = 1,
	})
end

function HudPrimitives.createLabel(text, props, children)
	return React.createElement("TextLabel", HudPrimitives.mergeProps({
		BackgroundTransparency = 1,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = Color3.fromRGB(237, 235, 255),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, props), children)
end

function HudPrimitives.createPanel(props, children)
	local panelChildren = copyChildren(children)
	panelChildren.Corner = HudPrimitives.createCorner(8)
	panelChildren.Stroke = HudPrimitives.createStroke(Color3.fromRGB(157, 135, 255), 0.55)

	return React.createElement("Frame", HudPrimitives.mergeProps({
		BackgroundColor3 = Color3.fromRGB(25, 24, 34),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, props), panelChildren)
end

function HudPrimitives.createButton(text, props, children)
	local buttonChildren = copyChildren(children)
	buttonChildren.Corner = HudPrimitives.createCorner(8)
	buttonChildren.Stroke = HudPrimitives.createStroke(Color3.fromRGB(255, 255, 255), 0.68)

	return React.createElement("TextButton", HudPrimitives.mergeProps({
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(104, 75, 255),
		BorderSizePixel = 0,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 16,
	}, props), buttonChildren)
end

function HudPrimitives.createStatRow(label, value, order, zIndex)
	local rowZIndex = zIndex or 1

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = rowZIndex,
	}, {
		Label = HudPrimitives.createLabel(label, {
			Size = UDim2.fromScale(0.52, 1),
			TextColor3 = Color3.fromRGB(175, 170, 205),
			TextSize = 13,
			ZIndex = rowZIndex,
		}),
		Value = HudPrimitives.createLabel(value, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.45, 1),
			Font = UIThemeConfig.Font,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 13,
			ZIndex = rowZIndex,
		}),
	})
end

return HudPrimitives
