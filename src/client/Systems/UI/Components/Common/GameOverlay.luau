local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local UIBackgroundConfig = require(Config:WaitForChild("UIBackgroundConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local OverlayPanel = require(script.Parent:WaitForChild("OverlayPanel"))

local DEFAULT_CLOSE_BUTTON_SIZE = 168
local DEFAULT_CLOSE_ICON_SIZE = 140
local MIN_CLOSE_BUTTON_SIZE = 36
local MIN_CLOSE_ICON_SIZE = 30
local PANEL_BORDER_THICKNESS = 5
local PANEL_CORNER_RADIUS = 8
local MIN_PANEL_BORDER_THICKNESS = 2
local MIN_PANEL_CORNER_RADIUS = 4

local GameOverlay = {}

GameOverlay.Size = UDim2.fromScale(0.72, 0.62)
GameOverlay.DefaultViewportSize = Vector2.new(1280, 720)
GameOverlay.DesignContentSize = Vector2.new(
	GameOverlay.DefaultViewportSize.X * GameOverlay.Size.X.Scale,
	GameOverlay.DefaultViewportSize.Y * GameOverlay.Size.Y.Scale
)
GameOverlay.MinimumScale = 0.05

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

local function copyChildren(children)
	local result = {}

	for key, value in pairs(children or {}) do
		result[key] = value
	end

	return result
end

local function createLabel(text, props, children)
	return React.createElement("TextLabel", mergeProps({
		BackgroundTransparency = 1,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = Color3.fromRGB(35, 35, 43),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, props), children)
end

local function getAllowedPanelSize(viewportSize, overlaySize)
	local resolvedViewportSize = viewportSize or GameOverlay.DefaultViewportSize
	local resolvedOverlaySize = overlaySize or GameOverlay.Size

	return Vector2.new(
		resolvedViewportSize.X * resolvedOverlaySize.X.Scale + resolvedOverlaySize.X.Offset,
		resolvedViewportSize.Y * resolvedOverlaySize.Y.Scale + resolvedOverlaySize.Y.Offset
	)
end

local function getContentScale(viewportSize, overlaySize, designContentSize)
	local resolvedDesignContentSize = designContentSize or GameOverlay.DesignContentSize
	local allowedPanelSize = getAllowedPanelSize(viewportSize, overlaySize)
	local widthScale = allowedPanelSize.X / resolvedDesignContentSize.X
	local heightScale = allowedPanelSize.Y / resolvedDesignContentSize.Y

	return math.max(GameOverlay.MinimumScale, math.min(widthScale, heightScale))
end

local function getScaledOffset(value, scale, minimumValue)
	return math.max(minimumValue or 0, math.floor(value * scale + 0.5))
end

local function getScaledPanelSize(designContentSize, contentScale)
	return UDim2.fromOffset(
		getScaledOffset(designContentSize.X, contentScale, 1),
		getScaledOffset(designContentSize.Y, contentScale, 1)
	)
end

local function createBackgroundImage(backgroundId)
	local backgroundImage = if backgroundId ~= nil then UIBackgroundConfig.getBackground(backgroundId) else nil

	if backgroundImage == nil or backgroundImage == "" then
		return nil
	end

	return React.createElement("ImageLabel", {
		Active = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = backgroundImage,
		Position = UDim2.fromScale(0, 0),
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 91,
	})
end

local function createScaledContent(contentScale, designContentSize, children)
	local scaledChildren = copyChildren(children)
	scaledChildren.Scale = React.createElement("UIScale", {
		Scale = contentScale,
	})

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(designContentSize.X, designContentSize.Y),
		ZIndex = 92,
	}, scaledChildren)
end

local function createScaledTitle(contentScale, designContentSize, props)
	local titleText = props.Title

	if titleText == nil or titleText == "" then
		return nil
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(designContentSize.X, designContentSize.Y),
		ZIndex = 96,
	}, {
		Scale = React.createElement("UIScale", {
			Scale = contentScale,
		}),
		Title = createLabel(titleText, mergeProps({
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(-14, -42),
			Size = UDim2.fromOffset(props.TitleWidth or 360, 76),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = props.TitleTextSize or 64,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 96,
		}, props.TitleProps), {
			Stroke = React.createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 5,
				Transparency = 0,
			}),
		}),
	})
end

function GameOverlay.create(props)
	local resolvedProps = props or {}
	local size = resolvedProps.Size or GameOverlay.Size
	local designContentSize = resolvedProps.DesignContentSize or GameOverlay.DesignContentSize
	local contentScale = getContentScale(resolvedProps.ViewportSize, size, designContentSize)
	local closeButtonSize = resolvedProps.CloseButtonSize or DEFAULT_CLOSE_BUTTON_SIZE
	local closeIconSize = resolvedProps.CloseIconSize or DEFAULT_CLOSE_ICON_SIZE

	return OverlayPanel.create({
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderThickness = getScaledOffset(PANEL_BORDER_THICKNESS, contentScale, MIN_PANEL_BORDER_THICKNESS),
		BorderTransparency = 0,
		CloseButtonSize = getScaledOffset(closeButtonSize, contentScale, MIN_CLOSE_BUTTON_SIZE),
		CloseIconSize = getScaledOffset(closeIconSize, contentScale, MIN_CLOSE_ICON_SIZE),
		CornerRadius = getScaledOffset(PANEL_CORNER_RADIUS, contentScale, MIN_PANEL_CORNER_RADIUS),
		OnClose = resolvedProps.OnClose,
		Size = getScaledPanelSize(designContentSize, contentScale),
		ZIndex = resolvedProps.ZIndex or 90,
		Children = {
			Background = createBackgroundImage(resolvedProps.BackgroundId),
			ScaledTitle = createScaledTitle(contentScale, designContentSize, resolvedProps),
			ScaledContent = createScaledContent(contentScale, designContentSize, resolvedProps.Children),
		},
	})
end

return GameOverlay
