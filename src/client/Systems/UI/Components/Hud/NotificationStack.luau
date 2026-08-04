local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HudPrimitives = require(script.Parent.Parent.Parent:WaitForChild("Components"):WaitForChild("Common"):WaitForChild("HudPrimitives"))

local NotificationStack = {}

function NotificationStack.create(props)
	local feedback = props and props.Feedback or {}
	local children = {}
	for index = 1, math.min(3, #feedback) do
		local item = feedback[index]
		children["Toast" .. index] = HudPrimitives.createPanel({
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 38),
			ZIndex = 75,
		}, {
			Text = HudPrimitives.createLabel(item.EventId or "Ritual update", {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -20, 1, 0),
				TextSize = 13,
				ZIndex = 76,
			}),
		})
	end
	children.Layout = React.createElement("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 78),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1, -24, 0, 132),
		ZIndex = 75,
	}, children)
end

return NotificationStack
