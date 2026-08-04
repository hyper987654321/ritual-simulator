local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Kit = require(script.Parent:WaitForChild("OverlayKit"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Theme = require(Config:WaitForChild("UIThemeConfig"))

local RetentionOverlay = {}
local C = Theme.Colors

local function goalCard(item, onClaim, order)
	local title = item.Label or "Ritual goal"
	local state = if item.Claimed then "Claimed" elseif item.Ready then "Ready to claim" else tostring(item.Progress or 0) .. " / " .. tostring(item.Requirement or 0)
	return React.createElement("Frame", { BackgroundColor3 = C.Card, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.new(1, -8, 0, 86) }, { Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }), Title = Kit.label(title, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -154, 0, 24), TextSize = 16 }), Description = Kit.label(item.Description or "Complete this ritual step to earn a blessing.", { Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -154, 0, 22), TextColor3 = C.Muted, TextSize = 12 }), Status = Kit.label((item.RewardText or "Reward") .. "  •  " .. state, { Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -154, 0, 20), TextColor3 = if item.Ready then C.Success else C.Muted, TextSize = 12 }), Claim = Kit.button(if item.Claimed then "Done" elseif item.Ready then "Claim" else "Locked", { Active = item.Ready == true, BackgroundColor3 = if item.Ready then C.Action else C.Locked, Position = UDim2.new(1, -128, 0, 21), Size = UDim2.fromOffset(112, 44), TextSize = 13, [React.Event.Activated] = if item.Ready then function() onClaim(item.Id) end else nil }) })
end

function RetentionOverlay.create(props)
	local retention = (props.Snapshot and props.Snapshot.Retention) or {}
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local height = math.min(580, math.max(360, viewport.Y - 32))
	local list = { Layout = React.createElement("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) }
	local order = 0
	for _, section in ipairs({ { Title = "Daily Ritual Deeds", Items = retention.Deeds }, { Title = "Session Blessings", Items = retention.Playtime }, { Title = "Chronicle Achievements", Items = retention.Achievements } }) do
		order += 1
		list["Section" .. order] = Kit.label(section.Title, { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 25), TextColor3 = C.Accent, TextSize = 15 })
		for _, item in ipairs(section.Items or {}) do order += 1; list["Goal" .. order] = goalCard(item, props.OnClaim, order) end
	end
	return Kit.modal({ Title = "Ritual Goals", BackgroundId = "PetInventory", MaximumWidth = 680, MaximumHeight = height, ViewportSize = viewport, ZIndex = 70, OnClose = props.OnClose, Children = { Ready = Kit.label(tostring(retention.ReadyCount or 0) .. " rewards ready", { Position = UDim2.fromOffset(22, 78), Size = UDim2.new(1, -44, 0, 28), TextColor3 = C.Muted, TextSize = 14, ZIndex = 72 }), List = React.createElement("ScrollingFrame", { Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), Position = UDim2.fromOffset(22, 114), ScrollBarThickness = 5, Size = UDim2.new(1, -44, 1, -130), ZIndex = 72 }, list) }})
end

return RetentionOverlay
