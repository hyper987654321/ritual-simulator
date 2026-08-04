local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Kit = require(script.Parent:WaitForChild("OverlayKit"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Theme = require(Config:WaitForChild("UIThemeConfig"))

local SocialOverlay = {}
local C = Theme.Colors
local localPlayer = Players.LocalPlayer

local function clockText(seconds)
	local safe = math.max(0, math.ceil(seconds or 0))
	return string.format("%d:%02d", math.floor(safe / 60), safe % 60)
end

local function SocialOverlayComponent(props)
	local snapshot = props.Snapshot or {}
	local social = props.Social or snapshot.Social or {}
	local required = math.max(0, social.RequiredSeconds or 120)
	local friendCount = math.max(0, social.VerifiedFriendCount or 0)
	local initialRemaining = math.max(0, social.RemainingSeconds or required)
	local inviteAvailable, setInviteAvailable = React.useState(if typeof(props.InviteAvailable) == "boolean" then props.InviteAvailable else false)
	local inviteChecked, setInviteChecked = React.useState(typeof(props.InviteAvailable) == "boolean")
	local remaining, setRemaining = React.useState(initialRemaining)
	React.useEffect(function()
		if typeof(props.InviteAvailable) == "boolean" then return end
		local cancelled = false
		task.spawn(function()
			local ok, available = pcall(function() return SocialService:CanSendGameInviteAsync(localPlayer) end)
			if not cancelled then setInviteAvailable(ok and available == true); setInviteChecked(true) end
		end)
		return function() cancelled = true end
	end, { props.InviteAvailable })
	React.useEffect(function()
		setRemaining(initialRemaining)
		if friendCount == 0 or social.FirstCoPlayRewarded == true then return end
		local cancelled = false
		task.spawn(function()
			local started = os.clock()
			while not cancelled do
				task.wait(1)
				local nextRemaining = math.max(0, initialRemaining - (os.clock() - started))
				setRemaining(nextRemaining)
				if nextRemaining <= 0 then break end
			end
		end)
		return function() cancelled = true end
	end, { social.RemainingSeconds, social.VerifiedFriendCount, social.FirstCoPlayRewarded })
	local rewarded = social.FirstCoPlayRewarded == true
	local status = if rewarded then "Reward earned" elseif friendCount > 0 then "Play together for " .. clockText(remaining) else "Join the same server as a Roblox friend"
	return Kit.modal({ Title = "Play Together", MaximumWidth = 520, MaximumHeight = 380, ViewportSize = props.ViewportSize, ZIndex = props.ZIndex or 100, OnClose = props.OnClose, Children = {
		Icon = Kit.icon("PetInventory", { Position = UDim2.new(1, -96, 0, 20), Size = UDim2.fromOffset(36, 36), ZIndex = 102 }),
		Intro = Kit.label("Invite a friend, then complete a short co-play ritual in the same server.", { Position = UDim2.fromOffset(22, 82), Size = UDim2.new(1, -44, 0, 42), TextColor3 = C.Muted, TextSize = 14, ZIndex = 102 }),
		Reward = React.createElement("Frame", { BackgroundColor3 = C.Card, BorderSizePixel = 0, Position = UDim2.fromOffset(22, 138), Size = UDim2.new(1, -44, 0, 100), ZIndex = 102 }, { Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }), Amount = Kit.label("+5 Ritual Gems", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 30), TextColor3 = if rewarded then C.Success else C.Accent, TextSize = 22, ZIndex = 103 }), Status = Kit.label(status, { Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 24), TextColor3 = if rewarded then C.Success else C.Muted, TextSize = 13, ZIndex = 103 }) }),
		Rule = Kit.label("One-time reward • " .. tostring(math.floor(required)) .. " seconds together", { Position = UDim2.fromOffset(22, 252), Size = UDim2.new(1, -44, 0, 24), TextColor3 = C.Muted, TextSize = 13, ZIndex = 102 }),
		Invite = Kit.button(if not inviteChecked then "Checking invites..." elseif inviteAvailable then "Invite Friends" else "Invites unavailable", { Active = inviteChecked and inviteAvailable, BackgroundColor3 = if inviteAvailable then C.Action else C.Locked, Position = UDim2.fromOffset(22, 294), Size = UDim2.new(1, -44, 0, 44), ZIndex = 103, [React.Event.Activated] = function() if inviteAvailable then pcall(function() SocialService:PromptGameInvite(localPlayer) end) end end }),
	}})
end

function SocialOverlay.create(props)
	return React.createElement(SocialOverlayComponent, props)
end

return SocialOverlay
