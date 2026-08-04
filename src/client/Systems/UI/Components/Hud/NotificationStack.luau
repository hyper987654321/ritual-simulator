local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HudPrimitives = require(script.Parent.Parent.Parent:WaitForChild("Components"):WaitForChild("Common"):WaitForChild("HudPrimitives"))

local NotificationStack = {}
local labels = {
	daily_reward_ready = "Daily reward ready",
	daily_reward_claimed = "Daily reward claimed",
	first_rebirth_daily_bonus = "Daily Rebirth bonus earned",
	away_reward_ready = "Away reward ready",
	away_reward_claimed = "Away reward resolved",
	first_coplay_reward = "Friend co-play reward earned",
	onboarding_milestone_complete = "New milestone complete",
	stone_upgrade = "Ritual Stone upgraded",
	rebirth_complete = "Rebirth complete",
	ascension_complete = "Ascension complete",
	rune_focus_selected = "Rune Focus selected",
}

local function readable(record)
	local text = labels[record.EventId] or "Ritual update"
	local reward = record.Reward or {}
	local args = record.Args or {}
	if reward.RitualGems then text ..= string.format(" (+%d Gems)", reward.RitualGems) end
	if reward.Essence then text ..= string.format(" (+%d Essence)", reward.Essence) end
	if args.MilestoneId then text ..= " — milestone complete" end
	return string.sub(text, 1, 120)
end

function NotificationStack.create(props)
	local feedback = props and props.Feedback or {}
	local children = {}
	for index = 1, math.min(3, #feedback) do
		local item = feedback[index]
		children["Toast" .. index] = HudPrimitives.createPanel({ LayoutOrder = index, Size = UDim2.new(1, 0, 0, 38), ZIndex = 75 }, {
			Text = HudPrimitives.createLabel(readable(item), { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 76 }),
		})
	end
	children.Layout = React.createElement("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
	return React.createElement("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 78), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(1, -24, 0, 132), ZIndex = 75 }, children)
end

return NotificationStack
