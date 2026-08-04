local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local TutorialConfig = require(Config:WaitForChild("TutorialConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")

local HudLayoutConfig = require(script.Parent:WaitForChild("HudLayoutConfig"))
local HudPrimitives = require(CommonComponents:WaitForChild("HudPrimitives"))

local TutorialOverlay = {}

TutorialOverlay.Enabled = false
TutorialOverlay.MovementFallbackSeconds = 4
TutorialOverlay.IntroSeconds = 1.35

local TUTORIAL_ARROW_IMAGE = "rbxassetid://131441383381322"
local TUTORIAL_SCRIM_TRANSPARENCY = 0.48
local TUTORIAL_SKIP_BUTTON_SIZE = UDim2.fromOffset(78, 30)
local ROLL_TUTORIAL_ARROW_START_POSITION = UDim2.new(0.5, 0, 1, -190)
local ROLL_TUTORIAL_ARROW_END_POSITION = UDim2.new(0.5, 0, 1, -118)

local function lerpNumber(startValue, endValue, alpha)
	return startValue + (endValue - startValue) * alpha
end

local function lerpUDim2(startValue, endValue, alpha)
	local resolvedAlpha = math.clamp(alpha or 1, 0, 1)

	return UDim2.new(
		lerpNumber(startValue.X.Scale, endValue.X.Scale, resolvedAlpha),
		lerpNumber(startValue.X.Offset, endValue.X.Offset, resolvedAlpha),
		lerpNumber(startValue.Y.Scale, endValue.Y.Scale, resolvedAlpha),
		lerpNumber(startValue.Y.Offset, endValue.Y.Offset, resolvedAlpha)
	)
end

local function getTutorialTargetBounds(tutorialStep)
	if tutorialStep.TargetPosition == nil or tutorialStep.TargetSize == nil then
		return nil
	end

	local targetAnchorPoint = tutorialStep.TargetAnchorPoint or Vector2.new(0, 0)
	local targetWidth = tutorialStep.TargetSize.X.Offset
	local targetHeight = tutorialStep.TargetSize.Y.Offset
	local left = UDim.new(
		tutorialStep.TargetPosition.X.Scale,
		tutorialStep.TargetPosition.X.Offset - targetWidth * targetAnchorPoint.X
	)
	local top = UDim.new(
		tutorialStep.TargetPosition.Y.Scale,
		tutorialStep.TargetPosition.Y.Offset - targetHeight * targetAnchorPoint.Y
	)
	local right = UDim.new(left.Scale, left.Offset + targetWidth)
	local bottom = UDim.new(top.Scale, top.Offset + targetHeight)

	return {
		Left = left,
		Top = top,
		Right = right,
		Bottom = bottom,
		Width = targetWidth,
		Height = targetHeight,
	}
end

local function createTutorialScrimPiece(position, size)
	return React.createElement("Frame", {
		Active = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = TUTORIAL_SCRIM_TRANSPARENCY,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		ZIndex = 30,
	})
end

local function createTutorialScrimChildren(tutorialStep)
	if tutorialStep.NoScrim then
		return {}
	end

	local bounds = getTutorialTargetBounds(tutorialStep)

	if bounds == nil then
		return {
			Scrim = createTutorialScrimPiece(UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)),
		}
	end

	return {
		TopScrim = createTutorialScrimPiece(
			UDim2.fromScale(0, 0),
			UDim2.new(1, 0, bounds.Top.Scale, bounds.Top.Offset)
		),
		BottomScrim = createTutorialScrimPiece(
			UDim2.new(0, 0, bounds.Bottom.Scale, bounds.Bottom.Offset),
			UDim2.new(1, 0, 1 - bounds.Bottom.Scale, -bounds.Bottom.Offset)
		),
		LeftScrim = createTutorialScrimPiece(
			UDim2.new(0, 0, bounds.Top.Scale, bounds.Top.Offset),
			UDim2.new(bounds.Left.Scale, bounds.Left.Offset, 0, bounds.Height)
		),
		RightScrim = createTutorialScrimPiece(
			UDim2.new(bounds.Right.Scale, bounds.Right.Offset, bounds.Top.Scale, bounds.Top.Offset),
			UDim2.new(1 - bounds.Right.Scale, -bounds.Right.Offset, 0, bounds.Height)
		),
	}
end

function TutorialOverlay.getCurrentStepId(snapshot)
	if not TutorialOverlay.Enabled then
		return nil
	end

	if snapshot == nil then
		return nil
	end

	local onboarding = if typeof(snapshot.Onboarding) == "table" then snapshot.Onboarding else nil

	if onboarding == nil then
		local legacyTutorial = if typeof(snapshot.Tutorial) == "table" then snapshot.Tutorial else nil

		if legacyTutorial == nil or legacyTutorial.IsComplete then
			return nil
		end

		return legacyTutorial.CurrentStepId
	end

	if onboarding.GuidanceHidden == true then
		return nil
	end

	if onboarding.IntroSeen ~= true then
		return TutorialConfig.StepIds.Intro
	end

	local milestones = if typeof(onboarding.Milestones) == "table" then onboarding.Milestones else {}

	if milestones.first_roll ~= true then
		return TutorialConfig.StepIds.FirstRoll
	end

	-- The legacy overlay has no blocking card for these canonical traversal milestones.
	if milestones.entered_crystal_zone ~= true then
		return nil
	end

	if milestones.first_stone_upgrade ~= true then
		return TutorialConfig.StepIds.FirstStoneUpgrade
	end

	if milestones.zone_2_unlocked ~= true or milestones.zone_3_unlocked ~= true then
		return nil
	end

	if milestones.first_rebirth ~= true then
		return TutorialConfig.StepIds.FirstRebirth
	end

	return nil
end

function TutorialOverlay.getStep(snapshot, tutorialStarted)
	local currentStepId = TutorialOverlay.getCurrentStepId(snapshot)

	if currentStepId == nil then
		return nil
	end

	if currentStepId == TutorialConfig.StepIds.Intro then
		if not tutorialStarted then
			return nil
		end

		return {
			StepId = currentStepId,
			Message = "Hey, let's go through a short tutorial.",
			LabelPosition = UDim2.fromScale(0.5, 0.48),
			LabelSize = UDim2.fromOffset(430, 38),
			SkipButtonPosition = UDim2.fromScale(0.5, 0.56),
		}
	end

	if currentStepId == TutorialConfig.StepIds.FirstRoll then
		return {
			StepId = currentStepId,
			Message = "Start here: roll your first pet",
			ArrowPosition = ROLL_TUTORIAL_ARROW_END_POSITION,
			ArrowStartPosition = ROLL_TUTORIAL_ARROW_START_POSITION,
			ArrowRotation = 0,
			LabelPosition = UDim2.new(0.5, -88, 1, -166),
			SkipButtonAnchorPoint = Vector2.new(0, 0.5),
			SkipButtonPosition = UDim2.new(0.5, -50, 1, -122),
			TargetPosition = HudLayoutConfig.RollButtonPosition,
			TargetSize = HudLayoutConfig.RollTutorialTargetSize,
			TargetAnchorPoint = HudLayoutConfig.RollButtonAnchor,
		}
	end

	if currentStepId == TutorialConfig.StepIds.FirstStoneUpgrade then
		local nextUpgradeCosts = if typeof(snapshot.NextUpgradeCosts) == "table" then snapshot.NextUpgradeCosts else {}
		local firstCost = nextUpgradeCosts.Capacity or 0
		local canAffordFirstUpgrade = snapshot.Essence >= firstCost

		if not canAffordFirstUpgrade then
			return {
				StepId = currentStepId,
				Message = string.format(
					"Your pet is breaking crystals. Gather %s Essence for your first Ritual Stone upgrade.",
					NumberFormatter.compact(firstCost)
				),
				LabelPosition = UDim2.new(0.5, 0, 1, -154),
				LabelSize = UDim2.fromOffset(470, 38),
				NoScrim = true,
				SkipButtonPosition = UDim2.new(0.5, 0, 1, -116),
			}
		end

		return {
			StepId = currentStepId,
			Message = "Buy your first Ritual Stone upgrade",
			ArrowPosition = UDim2.new(1, -372, 0, 82),
			ArrowRotation = -90,
			LabelPosition = UDim2.new(1, -512, 0, 38),
			SkipButtonAnchorPoint = Vector2.new(1, 0.5),
			SkipButtonPosition = UDim2.new(1, -410, 0, 82),
			TargetPosition = UDim2.new(1, -18, 0, 18),
			TargetSize = UDim2.fromOffset(318, 216),
			TargetAnchorPoint = Vector2.new(1, 0),
		}
	end

	local rebirth = if typeof(snapshot.Rebirth) == "table" then snapshot.Rebirth else snapshot.RebirthRequirement

	if currentStepId == TutorialConfig.StepIds.FirstRebirth and rebirth ~= nil and rebirth.CanRebirth == true then
		return {
			StepId = currentStepId,
			Message = "Rebirth is ready",
			ArrowPosition = UDim2.new(1, -372, 0, 532),
			ArrowRotation = -90,
			LabelPosition = UDim2.new(1, -512, 0, 490),
			SkipButtonAnchorPoint = Vector2.new(1, 0.5),
			SkipButtonPosition = UDim2.new(1, -410, 0, 532),
			TargetPosition = UDim2.new(1, -18, 0, 480),
			TargetSize = UDim2.fromOffset(318, 154),
			TargetAnchorPoint = Vector2.new(1, 0),
		}
	end

	return nil
end

function TutorialOverlay.create(props)
	local resolvedProps = props or {}
	local tutorialStep = resolvedProps.Step

	if tutorialStep == nil then
		return nil
	end

	local children = createTutorialScrimChildren(tutorialStep)
	local arrowPosition = tutorialStep.ArrowPosition

	if tutorialStep.ArrowStartPosition ~= nil and tutorialStep.ArrowPosition ~= nil then
		arrowPosition = lerpUDim2(tutorialStep.ArrowStartPosition, tutorialStep.ArrowPosition, tutorialStep.ArrowAlpha or 1)
	end

	if tutorialStep.TargetPosition ~= nil then
		children.Target = React.createElement("Frame", {
			Active = false,
			AnchorPoint = tutorialStep.TargetAnchorPoint,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = tutorialStep.TargetPosition,
			Size = tutorialStep.TargetSize,
			ZIndex = 31,
		}, {
			Corner = HudPrimitives.createCorner(10),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.fromRGB(255, 244, 181),
				Thickness = 3,
				Transparency = 0.05,
			}),
		})
	end

	if arrowPosition ~= nil then
		children.Arrow = React.createElement("ImageLabel", {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = TUTORIAL_ARROW_IMAGE,
			ImageColor3 = Color3.fromRGB(255, 244, 181),
			Position = arrowPosition,
			Rotation = tutorialStep.ArrowRotation or 0,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(58, 58),
			ZIndex = 31,
		})
	end

	children.Label = HudPrimitives.createLabel(tutorialStep.Message, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = UIThemeConfig.Font,
		Position = tutorialStep.LabelPosition,
		Size = tutorialStep.LabelSize or UDim2.fromOffset(310, 32),
		TextColor3 = Color3.fromRGB(255, 244, 181),
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 31,
	})

	if resolvedProps.OnSkip ~= nil and tutorialStep.StepId ~= nil and tutorialStep.SkipButtonPosition ~= nil then
		children.Skip = HudPrimitives.createButton("Skip", {
			Active = true,
			AnchorPoint = tutorialStep.SkipButtonAnchorPoint or Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(35, 33, 48),
			Position = tutorialStep.SkipButtonPosition,
			Size = TUTORIAL_SKIP_BUTTON_SIZE,
			TextColor3 = Color3.fromRGB(255, 244, 181),
			TextSize = 13,
			ZIndex = 32,
			[React.Event.Activated] = function()
				resolvedProps.OnSkip(tutorialStep.StepId)
			end,
		})
	end

	return React.createElement("Frame", {
		Active = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
	}, children)
end

return TutorialOverlay
