local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Kit = require(script.Parent:WaitForChild("OverlayKit"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Theme = require(Config:WaitForChild("UIThemeConfig"))

local LeaderboardOverlay = {}
local C = Theme.Colors

function LeaderboardOverlay.create(props)
	local boards = if props.Snapshot and typeof(props.Snapshot.Leaderboards) == "table" then props.Snapshot.Leaderboards.Boards or {} else {}
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local height = math.min(560, math.max(340, viewport.Y - 32))
	local list = { Layout = React.createElement("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for index, board in ipairs(boards) do
		local rows = { Layout = React.createElement("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) }
		for rowIndex, row in ipairs(board.Rows or {}) do
			rows["Row" .. rowIndex] = Kit.label(string.format("%d   %s   %s", row.Rank or rowIndex, row.DisplayName or row.Name or "Player", row.Value or "—"), { LayoutOrder = rowIndex, Size = UDim2.new(1, 0, 0, 28), TextSize = 14, TextColor3 = if rowIndex == 1 then C.Accent else C.Ink })
		end
		list["Board" .. index] = React.createElement("Frame", { BackgroundColor3 = C.Card, BorderSizePixel = 0, LayoutOrder = index, Size = UDim2.new(1, -8, 0, 174) }, { Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }), Name = Kit.label(board.DisplayName or "Leaderboard", { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 28), TextColor3 = C.Accent, TextSize = 17 }), Rows = React.createElement("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 44), Size = UDim2.new(1, -28, 0, 118) }, rows) })
	end
	if #boards == 0 then list.Empty = Kit.label("Leaderboards will appear once a server has scores to share.", { LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 64), TextColor3 = C.Muted, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center }) end
	return Kit.modal({ Title = "Server Leaderboards", BackgroundId = "RitualCore", MaximumWidth = 680, MaximumHeight = height, ViewportSize = viewport, ZIndex = 70, OnClose = props.OnClose, Children = { List = React.createElement("ScrollingFrame", { Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), Position = UDim2.fromOffset(22, 84), ScrollBarThickness = 5, Size = UDim2.new(1, -44, 1, -104), ZIndex = 72 }, list) } })
end

return LeaderboardOverlay
