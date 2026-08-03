local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local AscensionConfig = require(Config:WaitForChild("AscensionConfig"))
local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")

local AnimatedScaleButton = require(CommonComponents:WaitForChild("AnimatedScaleButton"))
local GameOverlay = require(CommonComponents:WaitForChild("GameOverlay"))

local AscensionOverlay = {}

local OVERLAY_SIZE = UDim2.fromScale(0.42, 0.62)
local DESIGN_CONTENT_SIZE = Vector2.new(500, 430)
local TEXT_COLOR = Color3.fromRGB(35, 35, 43)
local MUTED_TEXT_COLOR = Color3.fromRGB(92, 88, 101)
local STAR_COLOR = Color3.fromRGB(255, 218, 92)
local LUCK_COLOR = Color3.fromRGB(160, 112, 255)
local ESSENCE_COLOR = Color3.fromRGB(95, 245, 171)
local POWER_COLOR = Color3.fromRGB(255, 92, 194)
local SUCCESS_COLOR = Color3.fromRGB(42, 199, 116)
local WARNING_COLOR = Color3.fromRGB(218, 62, 62)
local BODY_TEXT_SIZE = 18
local BUTTON_HOVER_SCALE = 1.05
local BUTTON_PRESS_SCALE = 0.95
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

local function createPanel(position, size, children)
	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		ZIndex = 96,
	}, mergeProps({
		Corner = createCorner(8),
		Stroke = createBorder(3),
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 6),
		}),
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}, children))
end

local function createRow(label, value, color, layoutOrder)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 97,
	}, {
		Label = createLabel(label, {
			Size = UDim2.new(0.58, 0, 1, 0),
			TextColor3 = color or TEXT_COLOR,
			TextSize = BODY_TEXT_SIZE,
			ZIndex = 98,
		}),
		Value = createLabel(value, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.42, -8, 1, 0),
			TextColor3 = color or TEXT_COLOR,
			TextSize = BODY_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 98,
		}),
	})
end

local function createSummaryLine(text, color, layoutOrder)
	return createLabel(text, {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = color,
		TextSize = 16,
		ZIndex = 98,
	}, {
		TextSizeConstraint = React.createElement("UITextSizeConstraint", {
			MaxTextSize = 16,
			MinTextSize = 10,
		}),
	})
end

local function formatSignedNumber(value, places)
	return "+" .. NumberFormatter.decimal(value, places or 2)
end

local function formatMultiplierDelta(value)
	return "+" .. NumberFormatter.compact(math.floor((value or 0) * 100 + 0.5)) .. "%"
end

local function AscendButton(props)
	local canAscend = props.CanAscend == true
	local onAscend = props.OnAscend
	local isActionable = canAscend and onAscend ~= nil
	local requiredZone = props.RequiredZone or AscensionConfig.BaseRequiredZone
	local text = if canAscend then "Ascend" else "Reach Zone " .. tostring(requiredZone)
	local gradient = if canAscend then BUTTON_READY_GRADIENT else BUTTON_LOCKED_GRADIENT

	return AnimatedScaleButton.create({
		HoverScale = BUTTON_HOVER_SCALE,
		PressScale = BUTTON_PRESS_SCALE,
		HoverTweenInfo = BUTTON_HOVER_TWEEN_INFO,
		RestTweenInfo = BUTTON_REST_TWEEN_INFO,
		ButtonProps = {
			Active = true,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(250, 374),
			Size = UDim2.fromOffset(360, 44),
			Text = "",
			ZIndex = 96,
			[React.Event.Activated] = if isActionable then onAscend else nil,
		},
		Children = {
			Background = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = if isActionable then 0 else 0.12,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 96,
			}, {
				Gradient = React.createElement("UIGradient", {
					Color = gradient,
					Rotation = 90,
				}),
				Corner = createCorner(8),
				Stroke = createBorder(4),
			}),
			Label = createLabel(text, {
				Font = UIThemeConfig.Font,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 24,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 97,
			}),
		},
	})
end

function AscensionOverlay.create(props)
	local resolvedProps = props or {}
	local snapshot = resolvedProps.Snapshot

	if snapshot == nil then
		return nil
	end

	local ascension = if typeof(snapshot.Ascension) == "table" then snapshot.Ascension else {}
	local ascensions = ascension.Ascensions or snapshot.Ascensions or 0
	local ascensionStars = ascension.AscensionStars or snapshot.AscensionStars or 0
	local requiredZone = ascension.RequiredZone or AscensionConfig.getRequiredZone(ascensions)
	local canAscend = ascension.CanAscend == true
	local rewardStars = ascension.StarReward or AscensionConfig.StarsPerAscension
	local delta = if typeof(ascension.BonusDelta) == "table" then ascension.BonusDelta else AscensionConfig.getStatBonusDelta()
	local requirementColor = if canAscend then SUCCESS_COLOR else WARNING_COLOR

	return GameOverlay.create({
		BackgroundId = "RitualCore",
		CloseButtonSize = 132,
		CloseIconSize = 110,
		DesignContentSize = DESIGN_CONTENT_SIZE,
		OnClose = resolvedProps.OnClose,
		Size = resolvedProps.Size or OVERLAY_SIZE,
		Title = "Ascension",
		TitleTextSize = 56,
		TitleWidth = 430,
		ViewportSize = resolvedProps.ViewportSize,
		ZIndex = resolvedProps.ZIndex,
		Children = {
			Count = createLabel(
				string.format("Ascensions %d   Stars %d", ascensions, ascensionStars),
				{
					Font = UIThemeConfig.Font,
					Position = UDim2.fromOffset(0, 18),
					Size = UDim2.new(1, 0, 0, 30),
					TextColor3 = TEXT_COLOR,
					TextSize = 24,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 96,
				}
			),

			Requirement = createPanel(UDim2.fromOffset(42, 62), UDim2.fromOffset(416, 54), {
				Zone = createRow(
					"Requirement",
					if canAscend then "Ready" else "Reach Zone " .. tostring(requiredZone),
					requirementColor,
					1
				),
			}),

			Rewards = createPanel(UDim2.fromOffset(42, 136), UDim2.fromOffset(416, 126), {
				Stars = createRow("Ascension Stars", "+" .. tostring(rewardStars), STAR_COLOR, 1),
				Luck = createRow("Luck", formatSignedNumber(delta.Luck or 0, 2), LUCK_COLOR, 2),
				Essence = createRow("Crystal Essence", formatMultiplierDelta(delta.CrystalEssenceMultiplier), ESSENCE_COLOR, 3),
				Power = createRow("Ritual Power", "+" .. NumberFormatter.compact(delta.RitualPower or 0), POWER_COLOR, 4),
			}),

			Summary = createPanel(UDim2.fromOffset(42, 282), UDim2.fromOffset(416, 66), {
				Keep = createSummaryLine("Keeps pets, Rebirths, Gems, potions, boosts, and records.", MUTED_TEXT_COLOR, 1),
				Reset = createSummaryLine("Resets Essence, zones, stone upgrades, and runes.", WARNING_COLOR, 2),
			}),

			Action = React.createElement(AscendButton, {
				CanAscend = canAscend,
				OnAscend = resolvedProps.OnAscend,
				RequiredZone = requiredZone,
			}),
		},
	})
end

return AscensionOverlay
