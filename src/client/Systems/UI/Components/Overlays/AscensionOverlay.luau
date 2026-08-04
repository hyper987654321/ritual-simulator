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

local OVERLAY_SIZE = UDim2.fromScale(0.76, 0.82)
local DESIGN_CONTENT_SIZE = Vector2.new(760, 570)
local TEXT_COLOR = Color3.fromRGB(35, 35, 43)
local MUTED_TEXT_COLOR = Color3.fromRGB(92, 88, 101)
local STAR_COLOR = Color3.fromRGB(226, 168, 24)
local LUCK_COLOR = Color3.fromRGB(132, 79, 226)
local ESSENCE_COLOR = Color3.fromRGB(27, 157, 102)
local POWER_COLOR = Color3.fromRGB(211, 62, 143)
local SUCCESS_COLOR = Color3.fromRGB(32, 161, 91)
local WARNING_COLOR = Color3.fromRGB(202, 60, 60)
local LOCKED_COLOR = Color3.fromRGB(137, 134, 145)
local CARD_BACKGROUND = Color3.fromRGB(252, 252, 255)
local BODY_TEXT_SIZE = 17
local SMALL_TEXT_SIZE = 14
local SHOP_CARD_HEIGHT = 92
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
	ColorSequenceKeypoint.new(0, Color3.fromRGB(179, 176, 187)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(117, 113, 128)),
})
local RECOMMENDATIONS = {
	essence_mastery = "Suggested for faster runs",
	starting_capacity = "Suggested for smoother resets",
	rune_flow = "Suggested for AFK progression",
}

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

local function createBorder(color, thickness, transparency)
	return React.createElement("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
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

local function createScaledLabel(text, props, minimumTextSize)
	return createLabel(text, mergeProps({
		TextScaled = true,
	}, props), {
		TextSizeConstraint = React.createElement("UITextSizeConstraint", {
			MaxTextSize = (props and props.TextSize) or BODY_TEXT_SIZE,
			MinTextSize = minimumTextSize or 10,
		}),
	})
end

local function createPanel(layoutOrder, height, children)
	return React.createElement("Frame", {
		BackgroundColor3 = CARD_BACKGROUND,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, -8, 0, height),
		ZIndex = 96,
	}, mergeProps({
		Corner = createCorner(8),
		Stroke = createBorder(Color3.fromRGB(36, 34, 42), 2, 0.08),
	}, children))
end

local function createMilestoneCard(milestone, index, ascension)
	local completedCount = ascension.Count or ascension.Ascensions or 0
	local isComplete = completedCount >= index
	local isCurrent = ascension.HasNextMilestone == true and completedCount + 1 == index
	local statusText = if isComplete then "Complete" elseif isCurrent then "Current" else "Later"
	local statusColor = if isComplete then SUCCESS_COLOR elseif isCurrent then STAR_COLOR else LOCKED_COLOR

	return React.createElement("Frame", {
		BackgroundColor3 = if isCurrent then Color3.fromRGB(255, 248, 214) else Color3.fromRGB(247, 247, 251),
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.fromOffset(218, 78),
		ZIndex = 97,
	}, {
		Corner = createCorner(7),
		Stroke = createBorder(statusColor, if isCurrent then 3 else 2, if isCurrent then 0 else 0.2),
		Title = createLabel("Ascension " .. tostring(index), {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 23),
			TextColor3 = statusColor,
			TextSize = 18,
			ZIndex = 98,
		}),
		Gate = createScaledLabel(
			string.format("Zone %d | %d Rebirths", milestone.RequiredZone, milestone.RequiredRebirths),
			{
				Position = UDim2.fromOffset(10, 27),
				Size = UDim2.new(1, -20, 0, 22),
				TextColor3 = TEXT_COLOR,
				TextSize = 15,
				ZIndex = 98,
			},
			10
		),
		Reward = createLabel("+" .. tostring(milestone.StarReward) .. " Stars", {
			Position = UDim2.fromOffset(10, 51),
			Size = UDim2.new(0.55, -10, 0, 20),
			TextColor3 = STAR_COLOR,
			TextSize = 14,
			ZIndex = 98,
		}),
		Status = createLabel(statusText, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 51),
			Size = UDim2.new(0.45, 0, 0, 20),
			TextColor3 = statusColor,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 98,
		}),
	})
end

local function createMilestonesPanel(ascension)
	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for index, milestone in ipairs(AscensionConfig.Milestones) do
		children["Milestone" .. tostring(index)] = createMilestoneCard(milestone, index, ascension)
	end

	return createPanel(2, 94, children)
end

local function createRequirementRow(label, value, isMet, layoutOrder)
	local color = if isMet then SUCCESS_COLOR else WARNING_COLOR

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(0.5, -8, 1, 0),
		ZIndex = 97,
	}, {
		Label = createLabel(label, {
			Position = UDim2.fromOffset(10, 5),
			Size = UDim2.new(1, -20, 0, 22),
			TextColor3 = MUTED_TEXT_COLOR,
			TextSize = SMALL_TEXT_SIZE,
			ZIndex = 98,
		}),
		Value = createScaledLabel(value, {
			Position = UDim2.fromOffset(10, 28),
			Size = UDim2.new(1, -20, 0, 27),
			TextColor3 = color,
			TextSize = 18,
			ZIndex = 98,
		}, 11),
	})
end

local function createRequirementsPanel(ascension, currentRebirths)
	if ascension.IsV1Complete == true then
		return createPanel(3, 64, {
			Complete = createLabel("V1 complete: all three 15-zone Ascension milestones are finished.", {
				Font = UIThemeConfig.Font,
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -32, 1, 0),
				TextColor3 = SUCCESS_COLOR,
				TextSize = 18,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 98,
			}),
		})
	end

	local hasPendingAwayClaim = ascension.HasPendingAwayClaim == true

	return createPanel(3, if hasPendingAwayClaim then 94 else 64, {
		Gates = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 64),
			ZIndex = 97,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Zone = createRequirementRow(
				"Zone gate",
				if ascension.IsZoneRequirementMet == true
					then "Zone " .. tostring(ascension.RequiredZone) .. " unlocked"
					else "Unlock Zone " .. tostring(ascension.RequiredZone or "-"),
				ascension.IsZoneRequirementMet == true,
				1
			),
			Rebirths = createRequirementRow(
				"Rebirth gate",
				string.format(
					"%d / %s Rebirths",
					currentRebirths or 0,
					tostring(ascension.RequiredRebirths or "-")
				),
				ascension.IsRebirthRequirementMet == true,
				2
			),
		}),
		AwayReward = if hasPendingAwayClaim
			then createScaledLabel("Away reward pending - claim or dismiss it before ascending.", {
				Position = UDim2.fromOffset(12, 64),
				Size = UDim2.new(1, -24, 0, 26),
				TextColor3 = WARNING_COLOR,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 98,
			}, 10)
			else nil,
	})
end

local function formatBonusValue(kind, value)
	if typeof(value) ~= "number" then
		return "-"
	end

	if
		kind == "EssenceMultiplier"
		or kind == "CrystalEssenceMultiplier"
		or kind == "PetPowerMultiplier"
		or kind == "RuneChargeMultiplier"
	then
		return "x" .. NumberFormatter.decimal(value, 2)
	end

	if kind == "Luck" then
		return "+" .. NumberFormatter.decimal(value, 2)
	end

	if kind == "StartingCapacityBonus" then
		return "+" .. NumberFormatter.compact(value)
	end

	if kind == "OfflineCapBonusMinutes" then
		return "+" .. NumberFormatter.compact(value) .. " min"
	end

	return NumberFormatter.decimal(value, 2)
end

local function createBonusCard(label, kind, currentBonus, nextBonus, color, layoutOrder, isV1Complete)
	local currentValue = currentBonus[kind]
	local nextValue = nextBonus[kind]
	local valueText = formatBonusValue(kind, currentValue)

	if not isV1Complete and typeof(nextValue) == "number" then
		valueText ..= " > " .. formatBonusValue(kind, nextValue)
	end

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(247, 247, 251),
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(326, 44),
		ZIndex = 97,
	}, {
		Corner = createCorner(6),
		Accent = React.createElement("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 7, 1, 0),
			ZIndex = 98,
		}, {
			Corner = createCorner(6),
		}),
		Label = createLabel(label, {
			Position = UDim2.fromOffset(15, 2),
			Size = UDim2.new(0.48, -15, 1, -4),
			TextColor3 = color,
			TextSize = 14,
			ZIndex = 98,
		}),
		Value = createScaledLabel(valueText, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 2),
			Size = UDim2.new(0.52, 0, 1, -4),
			TextColor3 = color,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 98,
		}, 10),
	})
end

local function createBonusesPanel(ascension)
	local currentBonus = if typeof(ascension.Bonus) == "table" then ascension.Bonus else {}
	local nextBonus = if typeof(ascension.NextBonus) == "table" then ascension.NextBonus else currentBonus
	local isV1Complete = ascension.IsV1Complete == true

	return createPanel(4, 196, {
		Title = createLabel(if isV1Complete then "Current total bonuses" else "Current > next Ascension bonuses", {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(14, 4),
			Size = UDim2.new(1, -28, 0, 28),
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 98,
		}),
		Grid = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, 36),
			Size = UDim2.new(1, -28, 0, 152),
			ZIndex = 97,
		}, {
			Layout = React.createElement("UIGridLayout", {
				CellPadding = UDim2.fromOffset(10, 8),
				CellSize = UDim2.fromOffset(326, 44),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Essence = createBonusCard("Essence", "CrystalEssenceMultiplier", currentBonus, nextBonus, ESSENCE_COLOR, 1, isV1Complete),
			Power = createBonusCard("Pet power", "PetPowerMultiplier", currentBonus, nextBonus, POWER_COLOR, 2, isV1Complete),
			Luck = createBonusCard("Luck", "Luck", currentBonus, nextBonus, LUCK_COLOR, 3, isV1Complete),
			Capacity = createBonusCard("Starting capacity", "StartingCapacityBonus", currentBonus, nextBonus, Color3.fromRGB(37, 155, 201), 4, isV1Complete),
			Rune = createBonusCard("Rune charge", "RuneChargeMultiplier", currentBonus, nextBonus, Color3.fromRGB(226, 126, 36), 5, isV1Complete),
			Away = createBonusCard("Offline cap", "OfflineCapBonusMinutes", currentBonus, nextBonus, Color3.fromRGB(91, 110, 196), 6, isV1Complete),
		}),
	})
end

local function AscendButton(props)
	local hasPendingAwayClaim = props.HasPendingAwayClaim == true
	local canAscend = props.CanAscend == true and not hasPendingAwayClaim
	local isV1Complete = props.IsV1Complete == true
	local isActionable = canAscend and props.OnAscend ~= nil
	local text = if isV1Complete
		then "V1 Ascensions Complete"
		elseif hasPendingAwayClaim
		then "Claim Away Reward First"
		elseif canAscend
		then "Ascend"
		else "Requirements Needed"

	return AnimatedScaleButton.create({
		HoverScale = BUTTON_HOVER_SCALE,
		PressScale = BUTTON_PRESS_SCALE,
		HoverTweenInfo = BUTTON_HOVER_TWEEN_INFO,
		RestTweenInfo = BUTTON_REST_TWEEN_INFO,
		ButtonProps = {
			Active = isActionable,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 6,
			Size = UDim2.new(1, -8, 0, 50),
			Text = "",
			ZIndex = 96,
			[React.Event.Activated] = if isActionable then props.OnAscend else nil,
		},
		Children = {
			Background = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = if isActionable then 0 else 0.12,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 96,
			}, {
				Gradient = React.createElement("UIGradient", {
					Color = if isActionable then BUTTON_READY_GRADIENT else BUTTON_LOCKED_GRADIENT,
					Rotation = 90,
				}),
				Corner = createCorner(8),
				Stroke = createBorder(Color3.fromRGB(0, 0, 0), 3, 0),
			}),
			Label = createLabel(text, {
				Size = UDim2.fromScale(1, 1),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 23,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 98,
			}),
		},
	})
end

local function formatUpgradeEffect(effectKind, value)
	if typeof(value) ~= "number" then
		return "-"
	end

	if
		effectKind == "EssenceMultiplier"
		or effectKind == "PetPowerMultiplier"
		or effectKind == "RuneChargeMultiplier"
		or effectKind == "RushPointsMultiplier"
	then
		return "+" .. NumberFormatter.decimal(value * 100, 0) .. "%"
	end

	if effectKind == "Luck" then
		return "+" .. NumberFormatter.decimal(value, 2)
	end

	if effectKind == "RollSpeedPercent" then
		return "+" .. NumberFormatter.decimal(value, 0) .. "%"
	end

	if effectKind == "OfflineCapMinutes" then
		return "+" .. NumberFormatter.compact(value) .. " min"
	end

	return "+" .. NumberFormatter.compact(value)
end

local function UpgradeButton(props)
	local option = props.Option
	local isAvailable = option ~= nil
	local level = if isAvailable and typeof(option.Level) == "number" then option.Level else nil
	local maxLevel = if isAvailable and typeof(option.MaxLevel) == "number" then option.MaxLevel else nil
	local isMaxed = isAvailable and (option.IsMaxed == true or (level ~= nil and maxLevel ~= nil and level >= maxLevel))
	local cost = if isAvailable then option.Cost else nil
	local canAfford = typeof(cost) == "number" and props.UnspentStars >= cost
	local isActionable = isAvailable and not isMaxed and canAfford and props.OnBuyUpgrade ~= nil
	local definition = AscensionConfig.getUpgrade(props.UpgradeId)
	local displayName = if isAvailable and typeof(option.DisplayName) == "string"
		then option.DisplayName
		elseif definition ~= nil then definition.DisplayName else props.UpgradeId
	local description = if isAvailable and typeof(option.Description) == "string"
		then option.Description
		else "Server upgrade facts unavailable."
	local recommendation = RECOMMENDATIONS[props.UpgradeId]
	local levelText = if level ~= nil and maxLevel ~= nil
		then string.format("Lv %d / %d", level, maxLevel)
		else "Lv - / -"
	local effectText = if isAvailable
		then formatUpgradeEffect(option.EffectKind, option.CurrentEffect)
			.. " > "
			.. formatUpgradeEffect(option.EffectKind, option.NextEffect)
		else "- > -"
	local costText = if isMaxed then "MAX" elseif typeof(cost) == "number" then tostring(cost) .. " Stars" else "Unavailable"

	return React.createElement("Frame", {
		BackgroundColor3 = CARD_BACKGROUND,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, -8, 0, SHOP_CARD_HEIGHT),
		ZIndex = 96,
	}, {
		Corner = createCorner(8),
		Stroke = createBorder(if isActionable then STAR_COLOR else Color3.fromRGB(48, 45, 55), 2, 0.12),
		Title = createLabel(displayName, {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(14, 5),
			Size = UDim2.new(0.48, -14, 0, 25),
			TextColor3 = TEXT_COLOR,
			TextSize = 20,
			ZIndex = 97,
		}),
		Level = createLabel(levelText, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(0.73, -8, 0, 5),
			Size = UDim2.new(0.25, 0, 0, 25),
			TextColor3 = STAR_COLOR,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 97,
		}),
		Description = createScaledLabel(description, {
			Position = UDim2.fromOffset(14, 31),
			Size = UDim2.new(0.72, -22, 0, 23),
			TextColor3 = MUTED_TEXT_COLOR,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 97,
		}, 10),
		Effect = createLabel("Effect " .. effectText, {
			Position = UDim2.fromOffset(14, 57),
			Size = UDim2.new(0.36, -14, 0, 25),
			TextColor3 = if isAvailable then POWER_COLOR else LOCKED_COLOR,
			TextSize = 15,
			ZIndex = 97,
		}),
		Recommendation = if recommendation ~= nil then createLabel(recommendation, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(0.72, -8, 0, 57),
			Size = UDim2.new(0.32, 0, 0, 25),
			TextColor3 = ESSENCE_COLOR,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 97,
		}) else nil,
		Buy = React.createElement("TextButton", {
			Active = isActionable,
			AutoButtonColor = isActionable,
			BackgroundColor3 = if isActionable then Color3.fromRGB(46, 190, 97) else Color3.fromRGB(133, 130, 142),
			BackgroundTransparency = if isActionable then 0 else 0.16,
			BorderSizePixel = 0,
			Font = UIThemeConfig.Font,
			Position = UDim2.new(0.75, 0, 0, 23),
			Size = UDim2.new(0.23, 0, 0, 48),
			Text = costText,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 16,
			TextWrapped = true,
			ZIndex = 98,
			[React.Event.Activated] = if isActionable then function()
				props.OnBuyUpgrade(props.UpgradeId)
			end else nil,
		}, {
			Corner = createCorner(7),
			Stroke = createBorder(Color3.fromRGB(0, 0, 0), 2, 0.08),
		}),
	})
end

local function getUpgradeOptionsById(ascension)
	local optionsById = {}

	for _, option in ipairs(ascension.UpgradeOptions or {}) do
		if typeof(option) == "table" and typeof(option.UpgradeId) == "string" then
			optionsById[option.UpgradeId] = option
		end
	end

	return optionsById
end

function AscensionOverlay.create(props)
	local resolvedProps = props or {}
	local snapshot = resolvedProps.Snapshot

	if snapshot == nil then
		return nil
	end

	local ascension = if typeof(snapshot.Ascension) == "table" then snapshot.Ascension else {}
	local ascensions = ascension.Count or ascension.Ascensions or 0
	local unspentStars = ascension.UnspentStars or ascension.AscensionStars or 0
	local rebirth = if typeof(snapshot.Rebirth) == "table" then snapshot.Rebirth else {}
	local currentRebirths = rebirth.Count or snapshot.Rebirths or 0
	local optionsById = getUpgradeOptionsById(ascension)
	local scrollChildren = {
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
		}),
		Layout = React.createElement("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Header = createLabel(string.format("Ascensions %d    Unspent Stars %d", ascensions, unspentStars), {
			Font = UIThemeConfig.Font,
			LayoutOrder = 1,
			Size = UDim2.new(1, -8, 0, 38),
			TextColor3 = STAR_COLOR,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 96,
		}),
		Milestones = createMilestonesPanel(ascension),
		Requirements = createRequirementsPanel(ascension, currentRebirths),
		Bonuses = createBonusesPanel(ascension),
		ResetSummary = createPanel(5, 54, {
			Keep = createScaledLabel("Keeps pets, Rebirths, Stars/upgrades, Gems, potions, boosts, and records.", {
				Position = UDim2.fromOffset(14, 3),
				Size = UDim2.new(1, -28, 0, 23),
				TextColor3 = MUTED_TEXT_COLOR,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 97,
			}, 10),
			Reset = createScaledLabel("Resets Essence, run zones, Stone levels, and Rune levels/charge; keeps the active Rune Focus.", {
				Position = UDim2.fromOffset(14, 27),
				Size = UDim2.new(1, -28, 0, 23),
				TextColor3 = WARNING_COLOR,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 97,
			}, 10),
		}),
		Action = React.createElement(AscendButton, {
			CanAscend = ascension.CanAscend,
			HasPendingAwayClaim = ascension.HasPendingAwayClaim,
			IsV1Complete = ascension.IsV1Complete,
			OnAscend = resolvedProps.OnAscend,
		}),
		ShopTitle = React.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 7,
			Size = UDim2.new(1, -8, 0, 42),
			ZIndex = 96,
		}, {
			Title = createLabel("Star Upgrades", {
				Font = UIThemeConfig.Font,
				Size = UDim2.new(1, 0, 0, 25),
				TextColor3 = STAR_COLOR,
				TextSize = 25,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 96,
			}),
			Subtitle = createLabel("Optional choices - no Star spending is required to continue.", {
				Position = UDim2.fromOffset(0, 23),
				Size = UDim2.new(1, 0, 0, 18),
				TextColor3 = MUTED_TEXT_COLOR,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 97,
			}),
		}),
	}

	for index, upgradeId in ipairs(AscensionConfig.UpgradeOrder) do
		scrollChildren["Upgrade" .. tostring(index)] = React.createElement(UpgradeButton, {
			LayoutOrder = 7 + index,
			OnBuyUpgrade = resolvedProps.OnBuyAscensionUpgrade,
			Option = optionsById[upgradeId],
			UnspentStars = unspentStars,
			UpgradeId = upgradeId,
		})
	end

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
			Scroll = React.createElement("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				Position = UDim2.fromOffset(18, 12),
				ScrollBarImageColor3 = STAR_COLOR,
				ScrollBarImageTransparency = 0.18,
				ScrollBarThickness = 7,
				Size = UDim2.new(1, -36, 1, -24),
				ZIndex = 95,
			}, scrollChildren),
		},
	})
end

return AscensionOverlay
