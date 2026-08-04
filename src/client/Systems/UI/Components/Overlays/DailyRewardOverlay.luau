local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HudPrimitives = require(script.Parent.Parent.Parent:WaitForChild("Components"):WaitForChild("Common"):WaitForChild("HudPrimitives"))

local DailyRewardOverlay = {}

function DailyRewardOverlay.create(props)
	local daily = props.Snapshot.DailyRewards or {}
	local cells = {}
	for day = 1, 7 do
		local reward = daily.CycleRewards and daily.CycleRewards[day] or 0
		cells["Day" .. day] = HudPrimitives.createLabel(string.format("%d\n%d Gems", day, reward), {
			BackgroundColor3 = if day == daily.ClaimCycleDay then Color3.fromRGB(104, 75, 255) else Color3.fromRGB(45, 43, 60),
			BackgroundTransparency = 0,
			Size = UDim2.new(1 / 7, -4, 0, 54),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 12,
			ZIndex = 82,
		})
	end
	return HudPrimitives.createPanel({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 0, 170), ZIndex = 80,
	}, {
		Title = HudPrimitives.createLabel("Daily Rewards", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 24), TextSize = 20, ZIndex = 81 }),
		Cells = React.createElement("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 0, 54), ZIndex = 81 }, cells),
		Layout = React.createElement("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Claim = HudPrimitives.createButton(if daily.IsClaimedToday then "Claimed" else "Claim", { Position = UDim2.new(1, -124, 1, -52), Size = UDim2.fromOffset(108, 44), Active = daily.CanClaim == true, ZIndex = 82, [React.Event.Activated] = function() if daily.CanClaim then props.OnClaim(daily.DayIndex) end end }),
		Close = HudPrimitives.createButton("Close", { Position = UDim2.fromOffset(14, 116), Size = UDim2.fromOffset(86, 44), ZIndex = 82, [React.Event.Activated] = props.OnClose }),
	})
end

return DailyRewardOverlay
