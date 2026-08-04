local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HudPrimitives = require(script.Parent.Parent.Parent:WaitForChild("Components"):WaitForChild("Common"):WaitForChild("HudPrimitives"))

local AwayRewardOverlay = {}

function AwayRewardOverlay.create(props)
	local away = props.Snapshot.AwayRewards or {}
	return HudPrimitives.createPanel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 190), ZIndex = 80 }, {
		Title = HudPrimitives.createLabel("Welcome back", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 26), TextSize = 20, ZIndex = 81 }),
		Summary = HudPrimitives.createLabel(string.format("Away: %dm  •  Eligible: %dm\nEssence offered: %s", away.ObservedMinutes or 0, away.EligibleMinutes or 0, tostring(away.EssenceOffered or 0)), { Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -28, 0, 52), TextSize = 15, TextWrapped = true, ZIndex = 81 }),
		Dismiss = HudPrimitives.createButton("Dismiss", { Position = UDim2.fromOffset(14, 132), Size = UDim2.fromOffset(108, 44), ZIndex = 82, [React.Event.Activated] = function() props.OnDismiss(away.Sequence) end }),
		Claim = HudPrimitives.createButton("Claim", { Position = UDim2.new(1, -122, 1, -58), Size = UDim2.fromOffset(108, 44), ZIndex = 82, [React.Event.Activated] = function() props.OnClaim(away.Sequence) end }),
	})
end

return AwayRewardOverlay
