local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")

local GameOverlay = require(CommonComponents:WaitForChild("GameOverlay"))
local AnimatedScaleButton = require(CommonComponents:WaitForChild("AnimatedScaleButton"))

local TeleportOverlay = {}

local OVERLAY_SIZE = UDim2.fromScale(0.34, 0.6)
local DESIGN_CONTENT_SIZE = Vector2.new(430, 430)
local TEXT_COLOR = Color3.fromRGB(35, 35, 43)
local SECTION_TITLE_TEXT_SIZE = 25
local BODY_TEXT_SIZE = 18
local ROW_HEIGHT = 64
local ROW_GAP = 10
local BUTTON_HOVER_SCALE = 1.04
local BUTTON_PRESS_SCALE = 0.96
local BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_REST_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_READY_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(142, 255, 86)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(56, 226, 73)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 184, 62)),
})
local BUTTON_LOCKED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 118, 118)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(239, 64, 64)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(193, 32, 32)),
})
local BUTTON_CURRENT_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(111, 222, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(37, 201, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 145, 226)),
})

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

local function createCorner(radius)
	return React.createElement("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
	})
end

local function createBorder(thickness)
	return React.createElement("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 3,
		Transparency = 0,
	})
end

local function createLabel(text, props, children)
	return React.createElement("TextLabel", mergeProps({
		BackgroundTransparency = 1,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = TEXT_COLOR,
		TextSize = BODY_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, props), children)
end

local function createDivider(yPosition)
	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(225, 225, 225),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, yPosition),
		Size = UDim2.new(1, -60, 0, 2),
		ZIndex = 96,
	})
end

local function ZoneButton(props)
	local zoneInfo = props.ZoneInfo
	local onSelectZone = props.OnSelectZone
	local isCurrent = zoneInfo.IsCurrent == true
	local isUnlocked = zoneInfo.IsUnlocked == true
	local isActionable = isUnlocked and not isCurrent and onSelectZone ~= nil
	local gradient = if isCurrent then BUTTON_CURRENT_GRADIENT elseif isUnlocked then BUTTON_READY_GRADIENT else BUTTON_LOCKED_GRADIENT
	local actionText = if isCurrent then "Current" elseif isUnlocked then "Teleport" else "Locked"

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		ZIndex = 96,
	}, {
		Button = AnimatedScaleButton.create({
			HoverScale = BUTTON_HOVER_SCALE,
			PressScale = BUTTON_PRESS_SCALE,
			HoverTweenInfo = BUTTON_HOVER_TWEEN_INFO,
			RestTweenInfo = BUTTON_REST_TWEEN_INFO,
			ButtonProps = {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 96,
				[React.Event.Activated] = if isActionable then function()
					onSelectZone(zoneInfo.ZoneId)
				end else nil,
			},
			Children = {
				Background = React.createElement("Frame", {
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = if isActionable or isCurrent then 0 else 0.1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 96,
				}, {
					Gradient = React.createElement("UIGradient", {
						Color = gradient,
						Rotation = 90,
					}),
					Corner = createCorner(8),
					Stroke = createBorder(3),
				}),
				Number = createLabel(tostring(zoneInfo.ZoneId), {
					Font = UIThemeConfig.Font,
					Position = UDim2.fromOffset(16, 0),
					Size = UDim2.fromOffset(34, ROW_HEIGHT),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 28,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 97,
				}),
				Name = createLabel(zoneInfo.DisplayName or ("Zone " .. tostring(zoneInfo.ZoneId)), {
					Font = UIThemeConfig.Font,
					Position = UDim2.fromOffset(60, 0),
					Size = UDim2.new(1, -188, 1, 0),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 22,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0,
					ZIndex = 97,
				}),
				Action = createLabel(actionText, {
					AnchorPoint = Vector2.new(1, 0),
					Font = UIThemeConfig.Font,
					Position = UDim2.new(1, -14, 0, 0),
					Size = UDim2.fromOffset(118, ROW_HEIGHT),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 18,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 97,
				}),
			},
		}),
	})
end

local function createZoneRows(zones, onSelectZone)
	local rows = {}

	for index, zoneInfo in ipairs(zones or {}) do
		rows["Zone" .. tostring(zoneInfo.ZoneId or index)] = React.createElement(ZoneButton, {
			LayoutOrder = index,
			OnSelectZone = onSelectZone,
			ZoneInfo = zoneInfo,
		})
	end

	return rows
end

function TeleportOverlay.create(props)
	local resolvedProps = props or {}
	local snapshot = resolvedProps.Snapshot

	if snapshot == nil then
		return nil
	end

	local zones = snapshot.Zones or {}
	local canvasHeight = #zones * ROW_HEIGHT + math.max(0, #zones - 1) * ROW_GAP

	return GameOverlay.create({
		BackgroundId = "RitualCore",
		CloseButtonSize = 132,
		CloseIconSize = 110,
		DesignContentSize = DESIGN_CONTENT_SIZE,
		OnClose = resolvedProps.OnClose,
		Size = resolvedProps.Size or OVERLAY_SIZE,
		Title = "Teleport",
		TitleTextSize = 44,
		TitleWidth = 350,
		ViewportSize = resolvedProps.ViewportSize,
		ZIndex = resolvedProps.ZIndex,
		Children = {
			Subtitle = createLabel("Choose Zone", {
				Font = UIThemeConfig.Font,
				Position = UDim2.fromOffset(0, 42),
				Size = UDim2.new(1, 0, 0, 32),
				TextSize = SECTION_TITLE_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 96,
			}),
			Divider = createDivider(78),
			ZoneList = React.createElement("ScrollingFrame", {
				Active = true,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, canvasHeight),
				Position = UDim2.fromOffset(34, 94),
				ScrollBarThickness = 6,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.fromOffset(362, 250),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				ZIndex = 96,
			}, mergeProps({
				Layout = React.createElement("UIListLayout", {
					Padding = UDim.new(0, ROW_GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}, createZoneRows(zones, resolvedProps.OnSelectZone))),
		},
	})
end

return TeleportOverlay
