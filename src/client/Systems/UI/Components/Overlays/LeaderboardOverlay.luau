local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local LeaderboardOverlay = {}

function LeaderboardOverlay.create(props)
	local boards = if props.Snapshot and typeof(props.Snapshot.Leaderboards) == "table" then props.Snapshot.Leaderboards.Boards or {} else {}
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local isMobile = viewport.X < 700
	local widthScale = if isMobile then 0.94 else 0.76
	local heightScale = if isMobile then 0.9 else 0.78
	local children = { Close = React.createElement("TextButton", { BackgroundColor3 = Color3.fromRGB(70, 74, 96), BorderSizePixel = 0, Position = UDim2.new(1, -60, 0, 12), Size = UDim2.fromOffset(44, 44), Font = Enum.Font.GothamBold, Text = "X", TextColor3 = Color3.new(1, 1, 1), TextSize = 16, [React.Event.Activated] = props.OnClose }) }
	for index, board in ipairs(boards) do
		local text = tostring(board.DisplayName or board.BoardId) .. "\n"
		for _, row in ipairs(board.Rows or {}) do text ..= tostring(row.Rank) .. ". " .. tostring(row.DisplayName or row.Name) .. "  " .. tostring(row.Value) .. "\n" end
		children["Board" .. index] = React.createElement("TextLabel", { BackgroundColor3 = Color3.fromRGB(39, 43, 62), BorderSizePixel = 0, LayoutOrder = index, Size = UDim2.new(1, -12, 0, 150), Font = Enum.Font.Gotham, Text = text, TextColor3 = Color3.new(1, 1, 1), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	end
	children.Layout = React.createElement("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	return React.createElement("Frame", { BackgroundColor3 = Color3.fromRGB(20, 22, 34), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(widthScale, heightScale), ZIndex = 70 }, { Title = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -80, 0, 32), Font = Enum.Font.GothamBold, Text = "Current Server Leaderboards", TextColor3 = Color3.new(1, 1, 1), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left }), List = React.createElement("ScrollingFrame", { Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), Position = UDim2.fromOffset(10, 60), ScrollBarThickness = 6, Size = UDim2.new(1, -20, 1, -70) }, children) })
end

return LeaderboardOverlay
