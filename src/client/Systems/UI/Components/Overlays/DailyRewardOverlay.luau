local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HudPrimitives = require(script.Parent.Parent.Parent:WaitForChild("Components"):WaitForChild("Common"):WaitForChild("HudPrimitives"))

local DailyRewardOverlay = {}

function DailyRewardOverlay.create(props)
	local daily = props.Snapshot.DailyRewards or {}
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local mobile = viewport.X < 600
	local cells = {}
	for day = 1, 7 do
		local reward = daily.CycleRewards and daily.CycleRewards[day] or 0
		cells["Day" .. day] = HudPrimitives.createLabel(string.format("%d\n%d Gems", day, reward), {
			BackgroundColor3 = if day == daily.ClaimCycleDay then Color3.fromRGB(104, 75, 255) else Color3.fromRGB(45, 43, 60),
			BackgroundTransparency = 0,
			Size = if mobile then UDim2.new(1, 0, 0, 44) else UDim2.new(1 / 7, -4, 0, 54),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = if mobile then 14 else 12,
			ZIndex = 82,
		})
	end
	local width = math.min(560, math.max(260, viewport.X - 24))
	cells.Layout = React.createElement("UIListLayout", { FillDirection = if mobile then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	local panelHeight = if mobile then math.min(600, math.max(320, viewport.Y - 24)) else 190
	local cellHeight = if mobile then panelHeight - 126 else 54
	local cellsProps = {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 0, cellHeight),
		ZIndex = 81,
	}
	if mobile then
		cellsProps.CanvasSize = UDim2.fromOffset(0, 7 * 48)
		cellsProps.ScrollBarThickness = 6
		cellsProps.ScrollingDirection = Enum.ScrollingDirection.Y
		cellsProps.ClipsDescendants = true
	end
	return HudPrimitives.createPanel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, panelHeight), ZIndex = 80 }, {
		Title = HudPrimitives.createLabel("Daily Rewards", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 24), TextSize = 20, ZIndex = 81 }),
		Cells = React.createElement(if mobile then "ScrollingFrame" else "Frame", cellsProps, cells),
		Claim = HudPrimitives.createButton(if daily.IsClaimedToday then "Claimed" else "Claim", { Position = UDim2.new(1, -124, 1, -54), Size = UDim2.fromOffset(108, 44), Active = daily.CanClaim == true, ZIndex = 82, [React.Event.Activated] = function() if daily.CanClaim then props.OnClaim(daily.DayIndex) end end }),
		Close = HudPrimitives.createButton("Close", { Position = UDim2.fromOffset(14, panelHeight - 54), Size = UDim2.fromOffset(86, 44), ZIndex = 82, [React.Event.Activated] = props.OnClose }),
	})
end

return DailyRewardOverlay
