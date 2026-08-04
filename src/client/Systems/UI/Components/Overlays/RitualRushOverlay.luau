local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local PotionConfig = require(Config:WaitForChild("PotionConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")

local AnimatedScaleButton = require(CommonComponents:WaitForChild("AnimatedScaleButton"))
local GameOverlay = require(CommonComponents:WaitForChild("GameOverlay"))

local RitualRushOverlay = {}

local OVERLAY_SIZE = UDim2.fromScale(0.56, 0.74)
local DESIGN_CONTENT_SIZE = Vector2.new(560, 620)
local TEXT_COLOR = Color3.fromRGB(35, 35, 43)
local MUTED_TEXT_COLOR = Color3.fromRGB(92, 88, 101)
local POINT_COLOR = Color3.fromRGB(255, 92, 194)
local GEM_COLOR = Color3.fromRGB(255, 218, 92)
local SUCCESS_COLOR = Color3.fromRGB(42, 199, 116)
local WARNING_COLOR = Color3.fromRGB(218, 62, 62)
local CLAIM_COLOR = Color3.fromRGB(37, 201, 255)
local PREMIUM_LOCKED_TEXT_COLOR = Color3.fromRGB(116, 108, 124)
local ROW_HEIGHT = 56
local ROW_GAP = 4
local BODY_TEXT_SIZE = 17
local REWARD_ROW_INSET = 10
local THRESHOLD_WIDTH = 60
local FREE_REWARD_LEFT = 82
local FREE_BUTTON_WIDTH = 88
local PREMIUM_INFO_WIDTH = 138
local ACTION_GAP = 6
local BUTTON_HOVER_SCALE = 1.04
local BUTTON_PRESS_SCALE = 0.96
local BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_REST_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_CLAIM_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(142, 255, 86)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(56, 226, 73)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 184, 62)),
})
local BUTTON_CLAIMED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(111, 222, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(37, 201, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 145, 226)),
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

local function createBorder(thickness, transparency)
	return React.createElement("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 3,
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

local function createDivider(yPosition)
	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(225, 225, 225),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, yPosition),
		Size = UDim2.new(1, -60, 0, 2),
		ZIndex = 96,
	})
end

local function getUnixTime()
	return DateTime.now().UnixTimestamp
end

local function getCountdownText(endsAtUnix, nowUnix)
	if typeof(endsAtUnix) ~= "number" then
		return "Ends soon"
	end

	local remainingSeconds = math.max(0, math.floor(endsAtUnix - nowUnix))
	local hours = math.floor(remainingSeconds / 3600)
	local minutes = math.floor((remainingSeconds % 3600) / 60)
	local seconds = remainingSeconds % 60

	if hours > 0 then
		return string.format("Ends in %dh %dm", hours, minutes)
	end

	if minutes > 0 then
		return string.format("Ends in %dm %ds", minutes, seconds)
	end

	return string.format("Ends in %ds", seconds)
end

local function getRewardText(reward, compactLabels)
	local parts = {}
	local essence = if typeof(reward) == "table" then reward.Essence or 0 else 0
	local ritualGems = if typeof(reward) == "table" then reward.RitualGems or 0 else 0

	if essence > 0 then
		local label = if compactLabels then " Ess" else " Essence"

		table.insert(parts, NumberFormatter.compact(essence) .. label)
	end

	if ritualGems > 0 then
		table.insert(parts, NumberFormatter.compact(ritualGems) .. " Gems")
	end

	if typeof(reward) == "table" and typeof(reward.Potions) == "table" then
		for _, potionGrant in ipairs(reward.Potions) do
			local potionText = PotionConfig.getPotionGrantDisplayText(potionGrant, compactLabels)

			if potionText ~= nil then
				table.insert(parts, potionText)
			end
		end
	end

	if #parts == 0 then
		return "Reward"
	end

	return table.concat(parts, " + ")
end

local function getLastMilestonePoints(milestones)
	local highestPoints = 1

	for _, milestone in ipairs(milestones or {}) do
		if typeof(milestone) == "table" and typeof(milestone.RequiredPoints) == "number" then
			highestPoints = math.max(highestPoints, milestone.RequiredPoints)
		end
	end

	return highestPoints
end

local function RewardButton(props)
	local state = props.State
	local milestoneId = props.MilestoneId
	local onClaimReward = props.OnClaimReward
	local isClaimable = (state == "Claim" or state == "Bonus") and onClaimReward ~= nil
	local gradient = props.Gradient

	if gradient == nil then
		gradient = if state == "Claim" or state == "Bonus"
			then BUTTON_CLAIM_GRADIENT
			elseif state == "Claimed" then BUTTON_CLAIMED_GRADIENT
			else BUTTON_LOCKED_GRADIENT
	end

	return AnimatedScaleButton.create({
		HoverScale = BUTTON_HOVER_SCALE,
		PressScale = BUTTON_PRESS_SCALE,
		HoverTweenInfo = BUTTON_HOVER_TWEEN_INFO,
		RestTweenInfo = BUTTON_REST_TWEEN_INFO,
		ButtonProps = {
			Active = true,
			AnchorPoint = Vector2.new(1, 0.5),
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = props.Position or UDim2.new(1, -REWARD_ROW_INSET, 0.5, 0),
			Size = UDim2.fromOffset(props.Width or 112, 44),
			Text = "",
			ZIndex = 98,
			[React.Event.Activated] = if isClaimable then function()
				onClaimReward(milestoneId)
			end else nil,
		},
		Children = {
			Background = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = if isClaimable then 0 else 0.1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 98,
			}, {
				Gradient = React.createElement("UIGradient", {
					Color = gradient,
					Rotation = 90,
				}),
				Corner = createCorner(8),
				Stroke = createBorder(3),
			}),
			Label = createLabel(props.Label or state, {
				Font = UIThemeConfig.Font,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextSize = 15,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 99,
			}, {
				TextSizeConstraint = React.createElement("UITextSizeConstraint", {
					MaxTextSize = 15,
					MinTextSize = 8,
				}),
			}),
		},
	})
end

local function ClaimButton(props)
	return RewardButton({
		MilestoneId = props.MilestoneId,
		OnClaimReward = props.OnClaimReward,
		Position = UDim2.new(1, -REWARD_ROW_INSET, 0.5, 0),
		State = props.State,
		Width = FREE_BUTTON_WIDTH,
	})
end

local function PremiumRewardInfo(props)
	local milestone = props.Milestone
	local isClaimed = milestone.IsPremiumClaimed == true
	local isUnlocked = props.PremiumUnlocked == true
	local text = if isClaimed then "Premium claimed" else "Premium +" .. getRewardText(milestone.PremiumReward, true)
	local textColor = if isClaimed then CLAIM_COLOR elseif isUnlocked then GEM_COLOR else PREMIUM_LOCKED_TEXT_COLOR

	return React.createElement("Frame", {
		Active = false,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -(FREE_BUTTON_WIDTH + ACTION_GAP + REWARD_ROW_INSET), 0.5, 0),
			Size = UDim2.fromOffset(PREMIUM_INFO_WIDTH, 44),
		ZIndex = 97,
	}, {
		Label = createLabel(text, {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 1),
			TextColor3 = textColor,
			TextScaled = true,
			TextSize = 14,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = if isUnlocked or isClaimed then 0.35 else 1,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 98,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 14,
				MinTextSize = 8,
			}),
		}),
	})
end

local function getClaimState(points, milestone, premiumUnlocked)
	if points < (milestone.RequiredPoints or math.huge) then
		return "Locked"
	end

	if milestone.IsFreeClaimed ~= true then
		return "Claim"
	end

	if premiumUnlocked == true and milestone.IsPremiumClaimed ~= true then
		return "Bonus"
	end

	return "Claimed"
end

local function getIsReached(points, milestone)
	return points >= (milestone.RequiredPoints or math.huge)
end

local function getRewardTextColor(state)
	if state == "Claimed" then
		return CLAIM_COLOR
	end

	if state == "Bonus" then
		return CLAIM_COLOR
	end

	return TEXT_COLOR
end

local function RewardRow(props)
	local milestone = props.Milestone
	local points = props.Points or 0
	local state = getClaimState(points, milestone, props.PremiumUnlocked)
	local isReached = getIsReached(points, milestone)
	local pointColor = if isReached then SUCCESS_COLOR else WARNING_COLOR

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		ZIndex = 96,
	}, {
		Corner = createCorner(8),
		Stroke = createBorder(2, 0.12),
		Threshold = createLabel(NumberFormatter.compact(milestone.RequiredPoints or 0), {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(REWARD_ROW_INSET, 0),
			Size = UDim2.fromOffset(THRESHOLD_WIDTH, ROW_HEIGHT),
			TextColor3 = pointColor,
			TextSize = 20,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.65,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 97,
		}),
		Reward = createLabel(getRewardText(milestone.FreeReward, false), {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(FREE_REWARD_LEFT, 0),
			Size = UDim2.new(1, -(FREE_REWARD_LEFT + PREMIUM_INFO_WIDTH + FREE_BUTTON_WIDTH + ACTION_GAP + 28), 1, 0),
			TextColor3 = getRewardTextColor(state),
			TextScaled = true,
			TextSize = BODY_TEXT_SIZE,
			ZIndex = 97,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = BODY_TEXT_SIZE,
				MinTextSize = 11,
			}),
		}),
		Premium = React.createElement(PremiumRewardInfo, {
			Milestone = milestone,
			PremiumUnlocked = props.PremiumUnlocked,
		}),
		Action = React.createElement(ClaimButton, {
			MilestoneId = milestone.MilestoneId,
			OnClaimReward = props.OnClaimReward,
			State = state,
		}),
	})
end

local function createRewardRows(milestones, points, premiumUnlocked, onClaimReward)
	local rows = {}

	for index, milestone in ipairs(milestones or {}) do
		rows["Milestone" .. tostring(milestone.MilestoneId or index)] = React.createElement(RewardRow, {
			LayoutOrder = index,
			Milestone = milestone,
			OnClaimReward = onClaimReward,
			PremiumUnlocked = premiumUnlocked,
			Points = points,
		})
	end

	return rows
end

local function createProgressPanel(rush, nowUnix)
	local points = math.max(0, math.floor(rush.Points or 0))
	local milestones = rush.Milestones or {}
	local nextMilestone = rush.NextMilestone
	local targetPoints = if typeof(nextMilestone) == "table" and typeof(nextMilestone.RequiredPoints) == "number"
		then nextMilestone.RequiredPoints
		else getLastMilestonePoints(milestones)
	local progressRatio = math.clamp(points / math.max(1, targetPoints), 0, 1)
	local nextText = if typeof(nextMilestone) == "table"
		then string.format("%s to %s", NumberFormatter.compact(nextMilestone.RemainingPoints or 0), NumberFormatter.compact(nextMilestone.RequiredPoints or 0))
		else "Track complete"

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(30, 34),
		Size = UDim2.fromOffset(500, 112),
		ZIndex = 96,
	}, {
		Corner = createCorner(8),
		Stroke = createBorder(3),
		Points = createLabel(NumberFormatter.compact(points) .. " / " .. NumberFormatter.compact(targetPoints) .. " points", {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(18, 10),
			Size = UDim2.fromOffset(250, 26),
			TextColor3 = POINT_COLOR,
			TextSize = 23,
			ZIndex = 97,
		}),
		Timer = createLabel(getCountdownText(rush.EndsAtUnix, nowUnix), {
			AnchorPoint = Vector2.new(1, 0),
			Font = UIThemeConfig.Font,
			Position = UDim2.new(1, -18, 0, 10),
			Size = UDim2.fromOffset(190, 26),
			TextColor3 = MUTED_TEXT_COLOR,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 97,
		}),
		BarBack = React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(42, 38, 52),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(18, 48),
			Size = UDim2.new(1, -36, 0, 24),
			ZIndex = 97,
		}, {
			Corner = createCorner(8),
			Stroke = createBorder(2, 0.2),
			Fill = React.createElement("Frame", {
				BackgroundColor3 = POINT_COLOR,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(progressRatio, 1),
				ZIndex = 98,
			}, {
				Corner = createCorner(8),
				Gradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 92, 194)),
						ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 218, 92)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(37, 201, 255)),
					}),
				}),
			}),
		}),
		Next = createLabel(nextText, {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(18, 80),
			Size = UDim2.new(1, -36, 0, 22),
			TextColor3 = GEM_COLOR,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 97,
		}),
	})
end

local function RitualRushOverlayComponent(props)
	local snapshot = props.Snapshot
	local nowUnix, setNowUnix = React.useState(getUnixTime())

	React.useEffect(function()
		local cancelled = false

		task.spawn(function()
			while not cancelled do
				task.wait(1)

				if not cancelled then
					setNowUnix(getUnixTime())
				end
			end
		end)

		return function()
			cancelled = true
		end
	end, {})

	if snapshot == nil or snapshot.RitualRush == nil then
		return nil
	end

	local rush = snapshot.RitualRush
	local points = math.max(0, math.floor(rush.Points or 0))

	return GameOverlay.create({
		BackgroundId = "RitualCore",
		CloseButtonSize = 132,
		CloseIconSize = 110,
		DesignContentSize = DESIGN_CONTENT_SIZE,
		OnClose = props.OnClose,
		Size = props.Size or OVERLAY_SIZE,
		Title = "Ritual Rush",
		TitleTextSize = 54,
		TitleWidth = 430,
		ViewportSize = props.ViewportSize,
		ZIndex = props.ZIndex,
		Children = {
			Progress = createProgressPanel(rush, nowUnix),
			RewardTitle = createLabel("Rewards", {
				Font = UIThemeConfig.Font,
				Position = UDim2.fromOffset(0, 178),
				Size = UDim2.new(1, 0, 0, 28),
				TextColor3 = TEXT_COLOR,
				TextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 96,
			}),
			Divider = createDivider(210),
			RewardRows = React.createElement("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				Position = UDim2.fromOffset(30, 224),
				ScrollBarImageColor3 = CLAIM_COLOR,
				ScrollBarImageTransparency = 0.2,
				ScrollBarThickness = 6,
				Size = UDim2.fromOffset(500, 370),
				ZIndex = 96,
			}, mergeProps({
				Layout = React.createElement("UIListLayout", {
					Padding = UDim.new(0, ROW_GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}, createRewardRows(rush.Milestones, points, rush.PremiumUnlocked, props.OnClaimReward))),
		},
	})
end

function RitualRushOverlay.create(props)
	return React.createElement(RitualRushOverlayComponent, props or {})
end

return RitualRushOverlay
