local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HudPrimitives = require(script.Parent.Parent.Parent:WaitForChild("Components"):WaitForChild("Common"):WaitForChild("HudPrimitives"))

local AwayRewardOverlay = {}

function AwayRewardOverlay.create(props)
	local away = props.Snapshot.AwayRewards or {}
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local mobile = viewport.X < 600
	local charges = away.RuneChargeByFocus or {}
	local chargeText = string.format("Capacity: %s  •  Pet Power: %s\nRitual Speed: %s  •  Luck: %s", charges.capacity or 0, charges.pet_power or 0, charges.ritual_speed or 0, charges.luck or 0)
	local capText = if away.WasTimeCapped then "Eight-hour cap applied" else "No time cap applied"
	local loss = math.max(0, (away.EssenceOffered or 0) - (away.EssenceClaimableNow or 0))
	local width = math.min(560, math.max(260, viewport.X - 24))
	return HudPrimitives.createPanel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, if mobile then 300 else 250), ZIndex = 80 }, {
		Title = HudPrimitives.createLabel("Welcome back", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 26), TextSize = 20, ZIndex = 81 }),
		Summary = HudPrimitives.createLabel(string.format("Observed: %dm  •  Eligible: %dm\n%s\nEssence offered: %s  •  Claimable: %s\nCapacity loss: %s", away.ObservedMinutes or 0, away.EligibleMinutes or 0, capText, away.EssenceOffered or 0, away.EssenceClaimableNow or 0, loss), { Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -28, 0, if mobile then 92 else 78), TextSize = 14, TextWrapped = true, ZIndex = 81 }),
		Charges = HudPrimitives.createLabel(chargeText, { Position = UDim2.fromOffset(14, if mobile then 142 else 128), Size = UDim2.new(1, -28, 0, 46), TextSize = 13, TextWrapped = true, ZIndex = 81 }),
		Close = HudPrimitives.createButton("Close", { Position = UDim2.new(1, -82, 0, 8), Size = UDim2.fromOffset(68, 44), TextSize = 12, ZIndex = 82, [React.Event.Activated] = props.OnClose }),
		Dismiss = HudPrimitives.createButton("Dismiss", { Position = UDim2.fromOffset(14, if mobile then 242 else 196), Size = UDim2.fromOffset(108, 44), ZIndex = 82, [React.Event.Activated] = function() props.OnDismiss(away.Sequence) end }),
		Claim = HudPrimitives.createButton("Claim", { Position = UDim2.new(1, -122, 1, if mobile then -58 else -54), Size = UDim2.fromOffset(108, 44), ZIndex = 82, [React.Event.Activated] = function() props.OnClaim(away.Sequence) end }),
	})
end

return AwayRewardOverlay
