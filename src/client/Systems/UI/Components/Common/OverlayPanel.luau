local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local AnimatedScaleButton = require(script.Parent:WaitForChild("AnimatedScaleButton"))
local Icon = require(script.Parent.Parent:WaitForChild("Foundation"):WaitForChild("Icon"))

local OverlayPanel = {}

local DEFAULT_SIZE = UDim2.fromOffset(560, 420)
local DEFAULT_POSITION = UDim2.fromScale(0.5, 0.5)
local DEFAULT_ANCHOR_POINT = Vector2.new(0.5, 0.5)
local DEFAULT_Z_INDEX = 80
local CLOSE_BUTTON_SIZE = 40
local CLOSE_ICON_SIZE = 24
local CLOSE_BUTTON_POSITION = UDim2.new(1, -28, 0, 32)
local CLOSE_BUTTON_HOVER_SCALE = 1.02
local CLOSE_BUTTON_PRESS_SCALE = 0.98
local CLOSE_BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_BUTTON_REST_TWEEN_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function copyChildren(children)
	local result = {}

	for key, value in pairs(children or {}) do
		result[key] = value
	end

	return result
end

function OverlayPanel.create(props)
	local resolvedProps = props or {}
	local zIndex = resolvedProps.ZIndex or DEFAULT_Z_INDEX
	local closeButtonSize = resolvedProps.CloseButtonSize or CLOSE_BUTTON_SIZE
	local closeIconSize = resolvedProps.CloseIconSize or CLOSE_ICON_SIZE
	local contentChildren = copyChildren(resolvedProps.Children)
	local children = {}

	children.Corner = React.createElement("UICorner", {
		CornerRadius = UDim.new(0, resolvedProps.CornerRadius or 8),
	})

	children.Stroke = React.createElement("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = resolvedProps.BorderColor3 or Color3.fromRGB(6, 6, 10),
		Thickness = resolvedProps.BorderThickness or 2,
		Transparency = resolvedProps.BorderTransparency or 0.18,
	})

	children.Content = React.createElement("Frame", {
		Active = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex + 1,
	}, contentChildren)

	if resolvedProps.OnClose ~= nil then
		children.Close = AnimatedScaleButton.create({
			HoverScale = CLOSE_BUTTON_HOVER_SCALE,
			PressScale = CLOSE_BUTTON_PRESS_SCALE,
			HoverTweenInfo = CLOSE_BUTTON_HOVER_TWEEN_INFO,
			RestTweenInfo = CLOSE_BUTTON_REST_TWEEN_INFO,
			ButtonProps = {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = true,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = CLOSE_BUTTON_POSITION,
				Size = UDim2.fromOffset(closeButtonSize, closeButtonSize),
				Text = "",
				ZIndex = zIndex + 20,
				[React.Event.Activated] = resolvedProps.OnClose,
			},
			Children = {
				Icon = Icon.create("Close", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(closeIconSize, closeIconSize), TextSize = 22, ZIndex = zIndex + 21 }),
			},
		})
	end

	return React.createElement("Frame", {
		Active = true,
		AnchorPoint = resolvedProps.AnchorPoint or DEFAULT_ANCHOR_POINT,
		BackgroundColor3 = resolvedProps.BackgroundColor3 or Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = resolvedProps.BackgroundTransparency or 0.18,
		BorderSizePixel = 0,
		Position = resolvedProps.Position or DEFAULT_POSITION,
		Size = resolvedProps.Size or DEFAULT_SIZE,
		ZIndex = zIndex,
	}, children)
end

return OverlayPanel
