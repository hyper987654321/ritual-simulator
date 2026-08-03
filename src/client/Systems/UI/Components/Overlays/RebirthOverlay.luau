local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")

local GameOverlay = require(CommonComponents:WaitForChild("GameOverlay"))
local AnimatedScaleButton = require(CommonComponents:WaitForChild("AnimatedScaleButton"))

local RebirthOverlay = {}

local OVERLAY_SIZE = UDim2.fromScale(0.34, 0.6)
local DESIGN_CONTENT_SIZE = Vector2.new(430, 430)
local TEXT_COLOR = Color3.fromRGB(35, 35, 43)
local ACCENT_COLOR = Color3.fromRGB(37, 201, 255)
local SUCCESS_COLOR = Color3.fromRGB(42, 199, 116)
local WARNING_COLOR = Color3.fromRGB(218, 62, 62)
local POWER_COLOR = Color3.fromRGB(255, 92, 194)
local LUCK_COLOR = Color3.fromRGB(160, 112, 255)
local SECTION_TITLE_TEXT_SIZE = 25
local BODY_TEXT_SIZE = 18
local BUTTON_HOVER_SCALE = 1.06
local BUTTON_PRESS_SCALE = 0.94
local BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_REST_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_GRADIENT = ColorSequence.new({
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

local function createSectionTitle(text, yPosition)
	return createLabel(text, {
		Font = UIThemeConfig.Font,
		Position = UDim2.fromOffset(0, yPosition),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = SECTION_TITLE_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 96,
	})
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

local function createBenefitRow(label, value, color, layoutOrder)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 97,
	}, {
		Accent = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(11, 11),
			ZIndex = 98,
		}, {
			Corner = createCorner(4),
		}),
		Label = createLabel(label, {
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(0.55, -22, 1, 0),
			TextColor3 = color,
			TextSize = BODY_TEXT_SIZE,
			ZIndex = 98,
		}),
		Value = createLabel(value, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.45, 0, 1, 0),
			TextColor3 = color,
			TextSize = BODY_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 98,
		}),
	})
end

local function createRequirementRow(label, value, isMet, layoutOrder)
	local valueColor = if isMet then SUCCESS_COLOR else WARNING_COLOR

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 97,
	}, {
		Label = createLabel(label, {
			Size = UDim2.new(0.44, 0, 1, 0),
			TextColor3 = TEXT_COLOR,
			TextSize = BODY_TEXT_SIZE,
			ZIndex = 98,
		}),
		Value = createLabel(value, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.56, -8, 1, 0),
			TextScaled = true,
			TextColor3 = valueColor,
			TextSize = BODY_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 98,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = BODY_TEXT_SIZE,
				MinTextSize = 10,
			}),
		}),
	})
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

local function RebirthButton(props)
	local canRebirth = props.CanRebirth == true
	local onRebirth = props.OnRebirth
	local isActionable = canRebirth and onRebirth ~= nil
	local buttonText = if canRebirth then "Rebirth" else "Requirements Needed"
	local gradient = if canRebirth then BUTTON_GRADIENT else BUTTON_LOCKED_GRADIENT

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
			Position = UDim2.fromOffset(215, 367),
			Size = UDim2.fromOffset(322, 42),
			Text = "",
			ZIndex = 96,
			[React.Event.Activated] = if isActionable then onRebirth else nil,
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
			Label = createLabel(buttonText, {
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

local function createRebirthButton(canRebirth, onRebirth)
	return React.createElement(RebirthButton, {
		CanRebirth = canRebirth,
		OnRebirth = onRebirth,
	})
end

function RebirthOverlay.create(props)
	local resolvedProps = props or {}
	local snapshot = resolvedProps.Snapshot

	if snapshot == nil then
		return nil
	end

	local rebirths = snapshot.Rebirths or 0
	local stats = snapshot.StoneStats or RitualStoneConfig.BaseStats
	local requirement = snapshot.RebirthRequirement or RitualStoneConfig.getRebirthRequirement(rebirths)
	local currentMultiplier = stats.RebirthMultiplier or (1 + rebirths * RitualStoneConfig.Rebirth.MultiplierPerRebirth)
	local nextMultiplier = 1 + (rebirths + 1) * RitualStoneConfig.Rebirth.MultiplierPerRebirth
	local powerIncreaseText = "+" .. NumberFormatter.compact(RitualStoneConfig.Rebirth.MultiplierPerRebirth * 100) .. "%"
	local luckIncreaseText = "+" .. NumberFormatter.decimal(RitualStoneConfig.Rebirth.LuckPerRebirth, 2)
	local essenceMet = (snapshot.Essence or 0) >= requirement.RequiredEssence
	local canRebirth = requirement.CanRebirth == true

	return GameOverlay.create({
		BackgroundId = "Rebirth",
		CloseButtonSize = 132,
		CloseIconSize = 110,
		DesignContentSize = DESIGN_CONTENT_SIZE,
		OnClose = resolvedProps.OnClose,
		Size = resolvedProps.Size or OVERLAY_SIZE,
		Title = "Rebirth",
		TitleTextSize = 56,
		TitleWidth = 330,
		ViewportSize = resolvedProps.ViewportSize,
		ZIndex = resolvedProps.ZIndex,
		Children = {
			RebirthCount = createLabel(string.format("Rebirths <font color=\"#DA3E3E\">%d</font>", rebirths), {
				Font = UIThemeConfig.Font,
				Position = UDim2.fromOffset(0, 18),
				RichText = true,
				Size = UDim2.new(1, 0, 0, 28),
				TextColor3 = TEXT_COLOR,
				TextSize = SECTION_TITLE_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 96,
			}),

			BenefitTitle = createSectionTitle("Increase Stats By", 58),
			BenefitDivider = createDivider(90),
			Benefits = createPanel(UDim2.fromOffset(34, 102), UDim2.fromOffset(362, 104), {
				Power = createBenefitRow("Power", powerIncreaseText, POWER_COLOR, 1),
				Luck = createBenefitRow("Luck", luckIncreaseText, LUCK_COLOR, 2),
				Gain = createBenefitRow(
					"Gain",
					"x" .. NumberFormatter.decimal(currentMultiplier, 2) .. " > x" .. NumberFormatter.decimal(nextMultiplier, 2),
					ACCENT_COLOR,
					3
				),
			}),

			RequirementsTitle = createSectionTitle("Requirement", 226),
			RequirementsDivider = createDivider(258),
			Requirements = createPanel(UDim2.fromOffset(34, 270), UDim2.fromOffset(362, 48), {
				Essence = createRequirementRow(
					"Essence",
					NumberFormatter.compact(snapshot.Essence or 0) .. " / " .. NumberFormatter.compact(requirement.RequiredEssence),
					essenceMet,
					1
				),
			}),

			Action = createRebirthButton(canRebirth, resolvedProps.OnRebirth),
		},
	})
end

return RebirthOverlay
