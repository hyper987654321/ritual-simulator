local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local RetentionOverlay = {}

local function card(item, onClaim, order)
	local progress = tostring(item.Progress or 0) .. " / " .. tostring(item.Requirement or 0)
	local state = if item.Claimed then "Claimed" elseif item.Ready then "Claim ready" else progress
	return React.createElement("Frame", { BackgroundColor3 = Color3.fromRGB(39, 43, 62), BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.new(1, -12, 0, 58) }, {
		Label = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -110, 0, 24), Font = Enum.Font.GothamMedium, Text = tostring(item.Id), TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left }),
		State = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -110, 0, 20), Font = Enum.Font.Gotham, Text = state, TextColor3 = item.Ready and Color3.fromRGB(113, 235, 142) or Color3.fromRGB(190, 198, 220), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }),
		Claim = React.createElement("TextButton", { Active = item.Ready == true, AutoButtonColor = item.Ready == true, BackgroundColor3 = item.Ready and Color3.fromRGB(62, 176, 106) or Color3.fromRGB(75, 79, 96), BorderSizePixel = 0, Position = UDim2.new(1, -96, 0, 9), Size = UDim2.fromOffset(84, 40), Font = Enum.Font.GothamBold, Text = if item.Claimed then "Done" elseif item.Ready then "Claim" else "Wait", TextColor3 = Color3.new(1, 1, 1), TextSize = 12, [React.Event.Activated] = if item.Ready then function() onClaim(item.Id) end else nil }),
	})
end

function RetentionOverlay.create(props)
	local snapshot = props.Snapshot or {}
	local retention = snapshot.Retention or {}
	local items = {}
	for _, group in ipairs({ retention.Deeds, retention.Playtime, retention.Achievements }) do
		for _, item in ipairs(group or {}) do table.insert(items, item) end
	end
	return React.createElement("Frame", { BackgroundColor3 = Color3.fromRGB(20, 22, 34), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), ZIndex = 70 }, {
		Title = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -70, 0, 32), Font = Enum.Font.GothamBold, Text = "Ritual Deeds  •  Blessings  •  Chronicle", TextColor3 = Color3.new(1, 1, 1), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left }),
		Ready = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 0, 22), Font = Enum.Font.Gotham, Text = "Ready: " .. tostring(retention.ReadyCount or 0), TextColor3 = Color3.fromRGB(151, 222, 255), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left }),
		Close = React.createElement("TextButton", { BackgroundColor3 = Color3.fromRGB(70, 74, 96), BorderSizePixel = 0, Position = UDim2.new(1, -52, 0, 12), Size = UDim2.fromOffset(40, 40), Font = Enum.Font.GothamBold, Text = "X", TextColor3 = Color3.new(1, 1, 1), TextSize = 16, [React.Event.Activated] = props.OnClose }),
		List = React.createElement("ScrollingFrame", { Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), Position = UDim2.fromOffset(10, 76), ScrollBarThickness = 6, Size = UDim2.new(1, -20, 1, -86) }, { Layout = React.createElement("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), Items = React.createElement(React.Fragment, nil, table.unpack((function() local result = {}; for index, item in ipairs(items) do result[index] = card(item, props.OnClaim, index) end; return result end)())) }),
	})
end

return RetentionOverlay
