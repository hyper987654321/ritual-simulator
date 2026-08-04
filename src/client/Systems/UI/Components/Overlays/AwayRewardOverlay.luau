local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Kit = require(script.Parent:WaitForChild("OverlayKit"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Theme = require(Config:WaitForChild("UIThemeConfig"))

local AwayRewardOverlay = {}
local C = Theme.Colors

function AwayRewardOverlay.create(props)
	local away = (props.Snapshot and props.Snapshot.AwayRewards) or {}
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local height = if viewport.X < 600 then math.min(520, math.max(360, viewport.Y - 32)) else 340
	local loss = math.max(0, (away.EssenceOffered or 0) - (away.EssenceClaimableNow or 0))
	local summary = string.format("You were away for %dm. %dm counted toward your return.", away.ObservedMinutes or 0, away.EligibleMinutes or 0)
	local reward = string.format("%s Essence ready", tostring(away.EssenceClaimableNow or 0))
	local cap = if away.WasTimeCapped then "Away-time limit applied" else "No away-time limit applied"
	return Kit.modal({ Title = "Welcome Back", BackgroundId = "Rebirth", MaximumWidth = 580, MaximumHeight = height, ViewportSize = viewport, ZIndex = 80, OnClose = props.OnClose, Children = {
		Icon = Kit.icon("Rebirth", { Position = UDim2.new(1, -96, 0, 20), Size = UDim2.fromOffset(36, 36), ZIndex = 82 }),
		Summary = Kit.label(summary, { Position = UDim2.fromOffset(22, 82), Size = UDim2.new(1, -44, 0, 42), TextSize = 17, ZIndex = 82 }),
		RewardCard = React.createElement("Frame", { BackgroundColor3 = C.Card, BorderSizePixel = 0, Position = UDim2.fromOffset(22, 138), Size = UDim2.new(1, -44, 0, 106), ZIndex = 82 }, { Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }), Reward = Kit.label(reward, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 32), TextColor3 = C.Success, TextSize = 23, ZIndex = 83 }), Detail = Kit.label(string.format("%s  •  Capacity loss: %s", cap, tostring(loss)), { Position = UDim2.fromOffset(16, 54), Size = UDim2.new(1, -32, 0, 30), TextColor3 = C.Muted, TextSize = 13, ZIndex = 83 }) }),
		Charges = Kit.label("Rune charge gained\nCapacity  " .. tostring((away.RuneChargeByFocus or {}).capacity or 0) .. "    Pet Power  " .. tostring((away.RuneChargeByFocus or {}).pet_power or 0) .. "    Ritual Speed  " .. tostring((away.RuneChargeByFocus or {}).ritual_speed or 0) .. "    Luck  " .. tostring((away.RuneChargeByFocus or {}).luck or 0), { Position = UDim2.fromOffset(22, 260), Size = UDim2.new(1, -44, 0, 54), TextColor3 = C.Muted, TextSize = 13, ZIndex = 82 }),
		Dismiss = Kit.button("Dismiss", { Position = UDim2.fromOffset(22, height - 62), Size = UDim2.fromOffset(112, 44), ZIndex = 83, [React.Event.Activated] = function() props.OnDismiss(away.Sequence) end }),
		Claim = Kit.button("Claim Essence", { Position = UDim2.new(1, -166, 1, -62), Size = UDim2.fromOffset(144, 44), ZIndex = 83, [React.Event.Activated] = function() props.OnClaim(away.Sequence) end }),
	}})
end

return AwayRewardOverlay
