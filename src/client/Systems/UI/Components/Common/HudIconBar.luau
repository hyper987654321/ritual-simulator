local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local UIIconConfig = require(Config:WaitForChild("UIIconConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))
local AnimatedScaleButton = require(script.Parent:WaitForChild("AnimatedScaleButton"))

local HudIconBar = {}

HudIconBar.ButtonSize = 176

local ICON_IMAGE_SIZE = 176
local ICON_GAP = 4
local ICON_HOVER_SCALE = 1.06
local ICON_PRESS_SCALE = 0.92
local ICON_HOVER_TWEEN_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ICON_REST_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ICON_Y_SCALE = 0.52
local ICON_LABEL_HEIGHT = 24
local CONTROL_MIN_SCALE = 0.55
local CONTROL_TOUCH_MAX_SCALE = 0.9

local function mergeProps(baseProps, extraProps)
	local props = {}

	for key, value in pairs(baseProps) do
		props[key] = value
	end

	for key, value in pairs(extraProps or {}) do
		props[key] = value
	end

	return props
end

local function mergeTable(baseTable, extraTable)
	local result = {}

	for key, value in pairs(baseTable or {}) do
		result[key] = value
	end

	for key, value in pairs(extraTable or {}) do
		result[key] = value
	end

	return result
end

local function createLabel(text, props)
	return React.createElement("TextLabel", mergeProps({
		BackgroundTransparency = 1,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 18,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, props))
end

local function HudIconButton(componentProps)
	local iconImage = componentProps.IconImage
	local buttonProps = componentProps.ButtonProps or {}
	local resolvedOptions = componentProps.Options or {}
	local zIndex = buttonProps.ZIndex or 20
	local iconSize = resolvedOptions.IconSize or ICON_IMAGE_SIZE
	local iconYScale = resolvedOptions.IconYScale or if resolvedOptions.LabelText ~= nil then 0.43 else ICON_Y_SCALE
	local iconPivotYOffset = resolvedOptions.IconPivotYOffset
	local buttonChildren = {}

	if iconPivotYOffset ~= nil then
		buttonChildren.Icon = React.createElement("Frame", {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, iconYScale),
			Rotation = resolvedOptions.IconRotation or 0,
			Size = UDim2.fromOffset(iconSize, iconSize),
			ZIndex = zIndex + 1,
		}, {
			Image = React.createElement("ImageLabel", {
				Active = false,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = iconImage or "",
				ImageColor3 = resolvedOptions.IconColor3,
				ImageTransparency = resolvedOptions.IconTransparency or 0,
				Position = UDim2.new(0.5, 0, 0.5, iconPivotYOffset),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(iconSize, iconSize),
				ZIndex = zIndex + 1,
			}),
		})
	else
		buttonChildren.Icon = React.createElement("ImageLabel", {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = iconImage or "",
			ImageColor3 = resolvedOptions.IconColor3,
			ImageTransparency = resolvedOptions.IconTransparency or 0,
			Position = UDim2.fromScale(0.5, iconYScale),
			Rotation = resolvedOptions.IconRotation or 0,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(iconSize, iconSize),
			ZIndex = zIndex + 1,
		})
	end

	if resolvedOptions.LabelText ~= nil then
		buttonChildren.Label = createLabel(resolvedOptions.LabelText, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 24, 0, ICON_LABEL_HEIGHT),
			ZIndex = zIndex + 2,
		})
	end

	local resolvedButtonProps = mergeProps({
		Active = true,
		AutoButtonColor = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(HudIconBar.ButtonSize, HudIconBar.ButtonSize),
		Text = "",
		ZIndex = zIndex,
	}, buttonProps)

	return AnimatedScaleButton.create({
		HoverScale = ICON_HOVER_SCALE,
		PressScale = ICON_PRESS_SCALE,
		HoverTweenInfo = ICON_HOVER_TWEEN_INFO,
		RestTweenInfo = ICON_REST_TWEEN_INFO,
		ButtonProps = resolvedButtonProps,
		Children = buttonChildren,
	})
end

local function createHudIconButton(iconImage, props, options)
	return React.createElement(HudIconButton, {
		IconImage = iconImage,
		ButtonProps = props,
		Options = options,
	})
end

function HudIconBar.getControlScale(viewportSize, defaultViewportSize, controlCount)
	local resolvedViewportSize = viewportSize or defaultViewportSize
	local resolvedDefaultViewportSize = defaultViewportSize or Vector2.new(1280, 720)
	local resolvedControlCount = controlCount or 4
	local widthScale = resolvedViewportSize.X / resolvedDefaultViewportSize.X
	local heightScale = resolvedViewportSize.Y / resolvedDefaultViewportSize.Y
	local toolbarWidth = HudIconBar.ButtonSize * resolvedControlCount + ICON_GAP * math.max(resolvedControlCount - 1, 0)
	local fitScale = (resolvedViewportSize.X - ICON_GAP * 2) / toolbarWidth
	local scale = math.clamp(math.min(widthScale, heightScale, fitScale), CONTROL_MIN_SCALE, 1)

	if UserInputService.TouchEnabled then
		return math.min(scale, CONTROL_TOUCH_MAX_SCALE)
	end

	return scale
end

function HudIconBar.create(controls, props, fillDirection, scale)
	local resolvedProps = props or {}
	local barZIndex = resolvedProps.ZIndex or 20
	local gap = resolvedProps.IconGap or ICON_GAP
	local frameProps = mergeTable(resolvedProps)
	frameProps.IconGap = nil
	local resolvedFillDirection = fillDirection or Enum.FillDirection.Horizontal
	local isHorizontal = resolvedFillDirection == Enum.FillDirection.Horizontal
	local controlCount = #controls
	local width = if isHorizontal
		then HudIconBar.ButtonSize * controlCount + gap * math.max(controlCount - 1, 0)
		else HudIconBar.ButtonSize
	local height = if isHorizontal
		then HudIconBar.ButtonSize
		else HudIconBar.ButtonSize * controlCount + gap * math.max(controlCount - 1, 0)
	local children = {
		Scale = React.createElement("UIScale", {
			Scale = scale or 1,
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = resolvedFillDirection,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, gap),
		}),
	}

	for index, control in ipairs(controls) do
		children[control.Name] = createHudIconButton(UIIconConfig.getIcon(control.IconId), {
			AutoButtonColor = control.AutoButtonColor ~= false,
			LayoutOrder = index,
			ZIndex = control.ZIndex or barZIndex + 1,
			[React.Event.Activated] = control.Activated,
		}, {
			IconColor3 = control.IconColor3,
			IconSize = control.IconSize,
			IconTransparency = control.IconTransparency,
			IconRotation = control.IconRotation,
			IconPivotYOffset = control.IconPivotYOffset,
			IconYScale = control.IconYScale,
			LabelText = control.LabelText,
		})
	end

	return React.createElement("Frame", mergeProps({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, height),
		ZIndex = barZIndex,
	}, frameProps), children)
end

return HudIconBar
