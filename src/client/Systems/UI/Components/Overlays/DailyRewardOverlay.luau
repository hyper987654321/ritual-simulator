local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Kit = require(script.Parent:WaitForChild("OverlayKit"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Theme = require(Config:WaitForChild("UIThemeConfig"))

local DailyRewardOverlay = {}
local C = Theme.Colors

function DailyRewardOverlay.create(props)
	local daily = (props.Snapshot and props.Snapshot.DailyRewards) or {}
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local mobile = viewport.X < 600
	local cells = { Layout = React.createElement("UIListLayout", { FillDirection = if mobile then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for day = 1, 7 do
		local reward = daily.CycleRewards and daily.CycleRewards[day] or 0
		local claimed = daily.IsClaimedToday and day == daily.ClaimCycleDay
		cells["Day" .. day] = React.createElement("Frame", { BackgroundColor3 = if day == daily.ClaimCycleDay then C.Action else C.Card, BorderSizePixel = 0, LayoutOrder = day, Size = if mobile then UDim2.new(1, 0, 0, 48) else UDim2.new(1 / 7, -7, 0, 78) }, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Day = Kit.label("DAY " .. day, { Position = UDim2.fromOffset(8, 7), Size = UDim2.new(1, -16, 0, 20), TextColor3 = C.Muted, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center }),
			Reward = Kit.label(tostring(reward) .. " Gems", { Position = UDim2.fromOffset(5, 28), Size = UDim2.new(1, -10, 0, 30), TextColor3 = if claimed then C.Success else C.Ink, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center }),
		})
	end
	local height = if mobile then math.min(560, math.max(360, viewport.Y - 32)) else 300
	return Kit.modal({ Title = "Daily Rewards", BackgroundId = "RitualCore", MaximumWidth = 620, MaximumHeight = height, ViewportSize = viewport, ZIndex = 80, OnClose = props.OnClose, Children = {
		Icon = Kit.icon("RitualCore", { Position = UDim2.new(1, -96, 0, 20), Size = UDim2.fromOffset(36, 36), ZIndex = 82 }),
		Hint = Kit.label(if daily.IsClaimedToday then "Today's blessing is already claimed." else "Return each day to build a seven-day streak.", { Position = UDim2.fromOffset(22, 78), Size = UDim2.new(1, -44, 0, 32), TextColor3 = C.Muted, TextSize = 14, ZIndex = 82 }),
		Days = React.createElement(if mobile then "ScrollingFrame" else "Frame", { Active = mobile, AutomaticCanvasSize = if mobile then Enum.AutomaticSize.Y else Enum.AutomaticSize.None, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), Position = UDim2.fromOffset(22, 118), ScrollBarThickness = 5, Size = UDim2.new(1, -44, 0, if mobile then height - 194 else 86), ZIndex = 82 }, cells),
		CloseAction = Kit.button("Close", { Position = UDim2.fromOffset(22, height - 62), Size = UDim2.fromOffset(108, 44), ZIndex = 83, [React.Event.Activated] = props.OnClose }),
		Claim = Kit.button(if daily.IsClaimedToday then "Claimed" else "Claim Reward", { Active = daily.CanClaim == true, BackgroundColor3 = if daily.CanClaim then C.Action else C.Locked, Position = UDim2.new(1, -166, 1, -62), Size = UDim2.fromOffset(144, 44), ZIndex = 83, [React.Event.Activated] = if daily.CanClaim then function() props.OnClaim(daily.DayIndex) end else nil }),
	}})
end

return DailyRewardOverlay
