local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local RetentionOverlay = {}

local function card(item, onClaim, order, claimWidth)
	local progress = tostring(item.Progress or 0) .. " / " .. tostring(item.Requirement or 0)
	local state = if item.Claimed then "Claimed" elseif item.Ready then "Claim ready" else progress
	return React.createElement("Frame", { BackgroundColor3 = Color3.fromRGB(39, 43, 62), BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.new(1, -12, 0, 88) }, {
		Label = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -claimWidth - 20, 0, 22), Font = Enum.Font.GothamMedium, Text = item.Label or item.Id, TextColor3 = Color3.new(1, 1, 1), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left }),
		Description = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -claimWidth - 20, 0, 22), Font = Enum.Font.Gotham, Text = item.Description or "", TextColor3 = Color3.fromRGB(190, 198, 220), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }),
		Reward = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 52), Size = UDim2.new(1, -claimWidth - 20, 0, 22), Font = Enum.Font.Gotham, Text = (item.RewardText or "Reward unavailable") .. "  |  " .. state, TextColor3 = item.Ready and Color3.fromRGB(113, 235, 142) or Color3.fromRGB(190, 198, 220), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }),
		Claim = React.createElement("TextButton", { Active = item.Ready == true, AutoButtonColor = item.Ready == true, BackgroundColor3 = item.Ready and Color3.fromRGB(62, 176, 106) or Color3.fromRGB(75, 79, 96), BorderSizePixel = 0, Position = UDim2.new(1, -claimWidth + 8, 0, 22), Size = UDim2.fromOffset(claimWidth - 16, 44), Font = Enum.Font.GothamBold, Text = if item.Claimed then "Done" elseif item.Ready then "Claim" else "Wait", TextColor3 = Color3.new(1, 1, 1), TextSize = 12, [React.Event.Activated] = if item.Ready then function() onClaim(item.Id) end else nil }),
	})
end

function RetentionOverlay.create(props)
	local snapshot = props.Snapshot or {}
	local retention = snapshot.Retention or {}
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local isMobile = viewport.X < 700
	local widthScale = if isMobile then 0.94 else 0.72
	local heightScale = if isMobile then 0.9 else 0.78
	local claimWidth = if isMobile then 78 else 96
	local sections = {
		{ Title = "Daily Ritual Deeds", Items = retention.Deeds },
		{ Title = "Session Blessings", Items = retention.Playtime },
		{ Title = "Chronicle Achievements", Items = retention.Achievements },
	}
	local listChildren = { Layout = React.createElement("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	local order = 0
	for _, section in ipairs(sections) do
		order += 1
		listChildren["Section" .. order] = React.createElement("TextLabel", { BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, -12, 0, 28), Font = Enum.Font.GothamBold, Text = section.Title, TextColor3 = Color3.fromRGB(151, 222, 255), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left })
		for _, item in ipairs(section.Items or {}) do
			order += 1
			listChildren["Card" .. order] = card(item, props.OnClaim, order, claimWidth)
		end
	end
	return React.createElement("Frame", { BackgroundColor3 = Color3.fromRGB(20, 22, 34), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(widthScale, heightScale), ZIndex = 70 }, {
		Title = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -80, 0, 32), Font = Enum.Font.GothamBold, Text = "Retention", TextColor3 = Color3.new(1, 1, 1), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left }),
		Ready = React.createElement("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 0, 22), Font = Enum.Font.Gotham, Text = "Ready: " .. tostring(retention.ReadyCount or 0), TextColor3 = Color3.fromRGB(151, 222, 255), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left }),
		Close = React.createElement("TextButton", { BackgroundColor3 = Color3.fromRGB(70, 74, 96), BorderSizePixel = 0, Position = UDim2.new(1, -60, 0, 12), Size = UDim2.fromOffset(44, 44), Font = Enum.Font.GothamBold, Text = "X", TextColor3 = Color3.new(1, 1, 1), TextSize = 16, [React.Event.Activated] = props.OnClose }),
		List = React.createElement("ScrollingFrame", { Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), Position = UDim2.fromOffset(10, 76), ScrollBarThickness = 6, Size = UDim2.new(1, -20, 1, -86) }, listChildren),
	})
end

return RetentionOverlay
