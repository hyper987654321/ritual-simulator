local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local PresentationEventConfig = require(Config:WaitForChild("PresentationEventConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")
local HudPrimitives = require(CommonComponents:WaitForChild("HudPrimitives"))

local RunePanel = {}

local function findFocus(runeFocus, focusId)
	for _, focus in ipairs(runeFocus.Focuses or {}) do
		if focus.FocusId == focusId then
			return focus
		end
	end

	return nil
end

local function getCapacityStatus(runeFocus)
	if not runeFocus.IsUnlocked then
		return string.format(
			"Unlock: %d Rebirth + Zone %d",
			runeFocus.RequiredRebirths or 1,
			runeFocus.RequiredZone or 3
		), Color3.fromRGB(190, 184, 211)
	end

	if runeFocus.ActiveId == nil then
		return "Select a focus for crystal-break charge", Color3.fromRGB(255, 210, 111)
	end

	local activeFocus = findFocus(runeFocus, runeFocus.ActiveId)

	if activeFocus ~= nil and activeFocus.IsMaxed then
		return "Maxed | leave crystal area to switch", Color3.fromRGB(255, 198, 107)
	end

	if runeFocus.CapacityState == "full_charging" then
		return "Essence full | Rune charge continues", Color3.fromRGB(116, 238, 184)
	end

	if runeFocus.CapacityState == "full_paused" then
		return "Rune charge paused | select another focus", Color3.fromRGB(255, 158, 158)
	end

	if (runeFocus.SelectionRetryAfter or 0) > 0 then
		return "Focus switching has a short cooldown", Color3.fromRGB(192, 184, 216)
	end

	return "Crystal breaks charge this automatically", Color3.fromRGB(178, 208, 230)
end

local function getLevelUpFeedback(feedback, activeId)
	for index = #(feedback or {}), 1, -1 do
		local record = feedback[index]
		local args = if typeof(record.Args) == "table" then record.Args else {}

		if
			record.EventId == PresentationEventConfig.EventIds.RuneLevelUp
			and args.FocusId == activeId
		then
			return record
		end
	end

	return nil
end

local function createProgressCard(runeFocus, feedback)
	local activeFocus = findFocus(runeFocus, runeFocus.ActiveId)

	if activeFocus == nil then
		return React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(35, 33, 49),
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 58),
			Size = UDim2.new(1, -24, 0, 58),
		}, {
			Corner = HudPrimitives.createCorner(7),
			Prompt = HudPrimitives.createLabel(
				if runeFocus.IsUnlocked then "Choose one path below" else "Rune Focus is not available in this run yet",
				{
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(1, -20, 1, 0),
					TextColor3 = Color3.fromRGB(218, 213, 237),
					TextSize = 13,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Center,
				}
			),
		})
	end

	local progress = math.clamp(activeFocus.Progress or 0, 0, 1)
	local levelFeedback = getLevelUpFeedback(feedback, activeFocus.FocusId)
	local progressText = if activeFocus.IsMaxed
		then "MAXIMUM FOCUS"
		else string.format(
			"%s / %s charge",
			NumberFormatter.compact(activeFocus.Charge or 0),
			NumberFormatter.compact(activeFocus.RequiredCharge or 0)
		)

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(35, 33, 49),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(1, -24, 0, 58),
	}, {
		Corner = HudPrimitives.createCorner(7),
		Title = HudPrimitives.createLabel(
			string.format("%s  |  Lv %d/%d", activeFocus.DisplayName, activeFocus.Level, activeFocus.MaxLevel),
			{
				Position = UDim2.fromOffset(10, 3),
				Size = UDim2.new(1, -20, 0, 20),
				TextSize = 13,
			}
		),
		LevelUp = if levelFeedback ~= nil then HudPrimitives.createLabel(
			string.format("LEVEL +%d", levelFeedback.Args.LevelsGained or 1),
			{
				AnchorPoint = Vector2.new(1, 0),
				Font = UIThemeConfig.Font,
				Position = UDim2.new(1, -10, 0, 3),
				Size = UDim2.fromOffset(78, 20),
				TextColor3 = Color3.fromRGB(255, 224, 107),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
			}
		) else nil,
		Track = React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(16, 15, 24),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(10, 27),
			Size = UDim2.new(1, -20, 0, 10),
		}, {
			Corner = HudPrimitives.createCorner(5),
			Fill = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(126, 92, 255),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(progress, 1),
			}, {
				Corner = HudPrimitives.createCorner(5),
				Gradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 198, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 112, 255)),
					}),
				}),
			}),
		}),
		Charge = HudPrimitives.createLabel(progressText, {
			Position = UDim2.fromOffset(10, 39),
			Size = UDim2.new(1, -20, 0, 16),
			TextColor3 = Color3.fromRGB(187, 181, 211),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function createFocusButtons(runeFocus, selectFocus)
	local children = {
		Layout = React.createElement("UIGridLayout", {
			CellPadding = UDim2.fromOffset(6, 6),
			CellSize = UDim2.new(0.5, -3, 0, 30),
			FillDirectionMaxCells = 2,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, focus in ipairs(runeFocus.Focuses or {}) do
		local isActive = focus.FocusId == runeFocus.ActiveId
		local canSelect = runeFocus.CanSelect == true
			and not isActive
			and not focus.IsMaxed
			and selectFocus ~= nil
		local levelText = if focus.IsMaxed then "MAX" else "Lv " .. tostring(focus.Level)
		local buttonText = string.format("%s | %s", focus.DisplayName, levelText)

		children["Focus" .. tostring(index)] = HudPrimitives.createButton(buttonText, {
			AutoButtonColor = canSelect,
			BackgroundColor3 = if isActive
				then Color3.fromRGB(91, 71, 168)
				elseif canSelect then Color3.fromRGB(48, 45, 68) else Color3.fromRGB(38, 36, 49),
			LayoutOrder = index,
			TextColor3 = if isActive
				then Color3.fromRGB(255, 244, 183)
				elseif canSelect then Color3.fromRGB(233, 230, 247) else Color3.fromRGB(145, 139, 163),
			TextSize = 10,
			[React.Event.Activated] = if canSelect then function()
				selectFocus(focus.FocusId)
			end else nil,
		})
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 124),
		Size = UDim2.new(1, -24, 0, 66),
	}, children)
end

local function getFeedbackPresentation(runeFocus, record)
	local args = if typeof(record.Args) == "table" then record.Args else {}
	local focus = findFocus(runeFocus, args.FocusId)
	local focusName = if focus ~= nil then focus.DisplayName else "Rune Focus"

	if record.EventId == PresentationEventConfig.EventIds.RuneCharge then
		return string.format(
			"+%s %s charge",
			NumberFormatter.compact(args.ChargeApplied or 0),
			focusName
		), Color3.fromRGB(80, 154, 194)
	elseif record.EventId == PresentationEventConfig.EventIds.RuneLevelUp then
		return string.format("%s reached Lv %d", focusName, args.Level or 0), Color3.fromRGB(133, 102, 47)
	elseif record.EventId == PresentationEventConfig.EventIds.RuneFocusSelected then
		return focusName .. " selected", Color3.fromRGB(75, 132, 105)
	elseif record.EventId == PresentationEventConfig.EventIds.CapacityFull then
		if args.CanContinueForRune == true then
			return "Capacity full | Rune charge continues", Color3.fromRGB(75, 132, 105)
		end

		return "Capacity full | farming paused", Color3.fromRGB(142, 88, 65)
	end

	return nil, nil
end

local function createFeedbackRows(runeFocus, feedback)
	local children = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local visibleCount = 0

	for _, record in ipairs(feedback or {}) do
		local text, color = getFeedbackPresentation(runeFocus, record)

		if text ~= nil and visibleCount < PresentationEventConfig.MaxClientToasts then
			visibleCount += 1
			children["Feedback" .. tostring(visibleCount)] = HudPrimitives.createLabel(text, {
				BackgroundColor3 = color,
				BackgroundTransparency = 0.16,
				BorderSizePixel = 0,
				LayoutOrder = visibleCount,
				Size = UDim2.new(1, 0, 0, 22),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
			}, {
				Corner = HudPrimitives.createCorner(6),
			})
		end
	end

	if visibleCount == 0 then
		return nil, 0
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 196),
		Size = UDim2.new(1, -24, 0, visibleCount * 26 - 4),
	}, children), visibleCount
end

function RunePanel.create(props)
	local resolvedProps = props or {}
	local snapshot = resolvedProps.Snapshot
	local runeFocus = if typeof(snapshot) == "table" then snapshot.RuneFocus else nil

	if typeof(runeFocus) ~= "table" then
		return nil
	end

	local statusText, statusColor = getCapacityStatus(runeFocus)
	local feedbackRows, feedbackCount = createFeedbackRows(runeFocus, resolvedProps.Feedback)

	return HudPrimitives.createPanel({
		Position = UDim2.fromOffset(292, 18),
		Size = UDim2.fromOffset(318, 202 + feedbackCount * 26),
	}, {
		Title = HudPrimitives.createLabel("Rune Focus", {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 22),
			TextSize = 16,
		}),
		Status = HudPrimitives.createLabel(statusText, {
			Position = UDim2.fromOffset(12, 31),
			Size = UDim2.new(1, -24, 0, 20),
			TextColor3 = statusColor,
			TextSize = 11,
		}),
		Progress = createProgressCard(runeFocus, resolvedProps.Feedback),
		Focuses = createFocusButtons(runeFocus, resolvedProps.OnSelectRuneFocus),
		Feedback = feedbackRows,
	})
end

return RunePanel
