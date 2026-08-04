local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Kit = require(script.Parent:WaitForChild("OverlayKit"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIThemeConfig"))
local NumberFormatter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("NumberFormatter"))

local DailyRewardOverlay = {}
local C = Theme.Colors

local function rewardText(value)
	if typeof(value) == "number" then
		return NumberFormatter.compact(value) .. " GEMS"
	end
	return "Reward"
end

function DailyRewardOverlay.create(props)
	local daily = (props.Snapshot and props.Snapshot.DailyRewards) or {}
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local mobile = viewport.X < 600
	local days = { Layout = React.createElement("UIGridLayout", { CellPadding = UDim2.fromOffset(8, 8), CellSize = if mobile then UDim2.new(0.5, -4, 0, 80) else UDim2.new(1 / 7, -8, 1, 0), SortOrder = Enum.SortOrder.LayoutOrder }) }
	local children = {
		Subtitle = Kit.label(if daily.IsClaimedToday then "Today's reward is claimed. Come back tomorrow." else "Claim one reward each day to build your streak.", { Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 0, 24), TextColor3 = C.Muted, TextSize = Theme.Type.Label, ZIndex = 82 }),
		Days = nil,
	}
	local claimDay = daily.ClaimCycleDay or 1
	for day = 1, 7 do
		local reward = daily.CycleRewards and daily.CycleRewards[day] or 0
		local claimed = day < claimDay or (day == claimDay and daily.IsClaimedToday == true)
		local isCurrent = day == claimDay and not claimed
		local locked = day > claimDay
		days["Day" .. day] = Kit.button("", { Active = false, AutoButtonColor = false, BackgroundColor3 = if claimed then C.Success elseif isCurrent then C.Violet elseif locked then C.Panel else C.Card, BackgroundTransparency = if locked then 0.35 else 0, LayoutOrder = day, Text = "", ZIndex = 83 }, {
			Day = Kit.label("DAY " .. day, { Position = UDim2.fromOffset(4, 7), Size = UDim2.new(1, -8, 0, 18), TextColor3 = if locked then C.Muted else C.Ink, TextSize = Theme.Type.Caption, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84 }),
			Reward = Kit.label(if claimed then "CLAIMED" elseif locked then "LOCKED" else rewardText(reward), { Position = UDim2.fromOffset(4, 30), Size = UDim2.new(1, -8, 0, 28), TextColor3 = if locked then C.Muted else C.Gold, TextSize = Theme.Type.Label, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84 }),
			State = if isCurrent and daily.IsClaimedToday ~= true then Kit.label("TODAY", { Position = UDim2.new(0, 4, 1, -22), Size = UDim2.new(1, -8, 0, 18), TextColor3 = C.Cyan, TextSize = Theme.Type.Caption, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84 }) else nil,
		})
	end
	children.Days = React.createElement("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 104), Size = UDim2.new(1, -32, 0, if mobile then 264 else 104), ZIndex = 82 }, days)
	children.Claim = Kit.button(if daily.IsClaimedToday then "Claimed" else "Claim Reward", { Active = daily.CanClaim == true, BackgroundColor3 = if daily.CanClaim == true then C.Gold else C.Locked, Position = UDim2.new(1, -156, 1, -60), Size = UDim2.fromOffset(140, 44), TextColor3 = if daily.CanClaim == true then C.Panel else C.Muted, ZIndex = 83, [React.Event.Activated] = if daily.CanClaim == true then function() props.OnClaim(daily.DayIndex) end else nil })
	return Kit.modal({ Title = "Daily Rewards", MaximumWidth = 720, MaximumHeight = if mobile then 430 else 360, ViewportSize = viewport, ZIndex = 80, OnClose = props.OnClose, Children = children })
end

return DailyRewardOverlay
