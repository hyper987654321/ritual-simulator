local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local SocialOverlay = {}

local localPlayer = Players.LocalPlayer
local DEFAULT_REQUIRED_SECONDS = 120
local FIRST_CO_PLAY_REWARD_GEMS = 5
local LAYOUT = {
	SafeTop = 56,
	SafeBottom = 18,
	HorizontalMargin = 12,
	MaximumSheetWidth = 460,
	MinimumTargetSize = 44,
}

local COLORS = {
	Panel = Color3.fromRGB(25, 24, 39),
	Card = Color3.fromRGB(42, 39, 61),
	Accent = Color3.fromRGB(255, 205, 89),
	Ready = Color3.fromRGB(105, 232, 159),
	Text = Color3.fromRGB(255, 250, 235),
	Muted = Color3.fromRGB(188, 182, 202),
	Stroke = Color3.fromRGB(111, 94, 146),
}

local function corner(radius)
	return React.createElement("UICorner", {
		CornerRadius = UDim.new(0, radius),
	})
end

local function label(text, props)
	local resolved = {
		BackgroundTransparency = 1,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = COLORS.Text,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}

	for key, value in pairs(props or {}) do
		resolved[key] = value
	end

	return React.createElement("TextLabel", resolved)
end

local function button(text, props)
	local resolved = {
		Active = true,
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(118, 84, 193),
		BorderSizePixel = 0,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = COLORS.Text,
		TextSize = 16,
	}

	for key, value in pairs(props or {}) do
		resolved[key] = value
	end

	return React.createElement("TextButton", resolved, {
		Corner = corner(11),
		Stroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = COLORS.Stroke,
			Thickness = 1,
			Transparency = 0.15,
		}),
	})
end

local function formatRemaining(seconds)
	local safeSeconds = math.max(0, math.ceil(seconds or 0))
	local minutes = math.floor(safeSeconds / 60)
	local remainder = safeSeconds % 60

	return string.format("%d:%02d", minutes, remainder)
end

local function SocialOverlayComponent(props)
	local resolvedProps = props or {}
	local snapshot = if typeof(resolvedProps.Snapshot) == "table" then resolvedProps.Snapshot else {}
	local social = if typeof(resolvedProps.Social) == "table"
		then resolvedProps.Social
		else if typeof(snapshot.Social) == "table" then snapshot.Social else {}
	local viewport = resolvedProps.ViewportSize or Vector2.new(1280, 720)
	local layout = LAYOUT
	local width = math.max(
		280,
		math.min(layout.MaximumSheetWidth, math.max(280, viewport.X - layout.HorizontalMargin * 2))
	)
	local height = math.max(320, math.min(410, viewport.Y - layout.SafeTop - layout.SafeBottom - 20))
	local inviteAvailable, setInviteAvailable = React.useState(
		if typeof(resolvedProps.InviteAvailable) == "boolean" then resolvedProps.InviteAvailable else false
	)
	local inviteChecked, setInviteChecked = React.useState(typeof(resolvedProps.InviteAvailable) == "boolean")
	local friendCount = if typeof(social.VerifiedFriendCount) == "number"
		then math.max(0, math.floor(social.VerifiedFriendCount))
		else 0
	local hasVerifiedFriend = friendCount > 0
	local requiredSeconds = if typeof(social.RequiredSeconds) == "number"
		then math.max(0, social.RequiredSeconds)
		else DEFAULT_REQUIRED_SECONDS
	local remainingSeconds, setRemainingSeconds = React.useState(
		if typeof(social.RemainingSeconds) == "number"
			then math.max(0, social.RemainingSeconds)
			else requiredSeconds
	)

	React.useEffect(function()
		if typeof(resolvedProps.InviteAvailable) == "boolean" then
			setInviteAvailable(resolvedProps.InviteAvailable)
			setInviteChecked(true)
			return
		end

		local cancelled = false

		task.spawn(function()
			local succeeded, available = pcall(function()
				return SocialService:CanSendGameInviteAsync(localPlayer)
			end)

			if not cancelled then
				setInviteAvailable(succeeded and available == true)
				setInviteChecked(true)
			end
		end)

		return function()
			cancelled = true
		end
	end, { resolvedProps.InviteAvailable })

	React.useEffect(function()
		local sourceRemaining = if typeof(social.RemainingSeconds) == "number"
			then math.max(0, social.RemainingSeconds)
			else requiredSeconds

		setRemainingSeconds(sourceRemaining)

		if social.FirstCoPlayRewarded == true or not hasVerifiedFriend or sourceRemaining <= 0 then
			return
		end

		local cancelled = false

		task.spawn(function()
			local startedAt = os.clock()

			while not cancelled do
				task.wait(1)

				if cancelled then
					break
				end

				local nextRemaining = math.max(0, sourceRemaining - (os.clock() - startedAt))
				setRemainingSeconds(nextRemaining)

				if nextRemaining <= 0 then
					break
				end
			end
		end)

		return function()
			cancelled = true
		end
	end, {
		social.RemainingSeconds,
		social.RequiredSeconds,
		social.FirstCoPlayRewarded,
		social.VerifiedFriendCount,
	})

	local rewarded = social.FirstCoPlayRewarded == true
	local statusText

	if rewarded then
		statusText = "First co-play reward earned"
	elseif hasVerifiedFriend then
		statusText = "Stay together  " .. formatRemaining(remainingSeconds)
	else
		statusText = "Join the same server as a Roblox friend"
	end

	local function promptInvite()
		if not inviteAvailable then
			return
		end

		-- Native invitation is presentation only. No result or recipient is sent
		-- to the game server, and closing the prompt never claims a reward.
		pcall(function()
			SocialService:PromptGameInvite(localPlayer)
		end)
	end

	return React.createElement("Frame", {
		Active = true,
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(math.floor(viewport.X / 2), viewport.Y - layout.SafeBottom),
		Size = UDim2.fromOffset(width, height),
		ZIndex = resolvedProps.ZIndex or 100,
	}, {
		Corner = corner(18),
		Stroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = COLORS.Stroke,
			Thickness = 2,
			Transparency = 0.05,
		}),
		Handle = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = COLORS.Muted,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(48, 4),
			ZIndex = (resolvedProps.ZIndex or 100) + 1,
		}, {
			Corner = corner(2),
		}),
		Title = label("Play rituals together", {
			Position = UDim2.fromOffset(20, 30),
			Size = UDim2.new(1, -72, 0, 42),
			TextSize = if viewport.X < 520 then 22 else 25,
			ZIndex = (resolvedProps.ZIndex or 100) + 1,
		}),
		Close = button("×", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(layout.MinimumTargetSize, layout.MinimumTargetSize),
			TextColor3 = COLORS.Muted,
			TextSize = 26,
			ZIndex = (resolvedProps.ZIndex or 100) + 2,
			[React.Event.Activated] = resolvedProps.OnClose,
		}),
		Description = label(
			"Invite friends for fun, then actually play together to earn the one-time reward.",
			{
				Position = UDim2.fromOffset(20, 76),
				Size = UDim2.new(1, -40, 0, 56),
				TextColor3 = COLORS.Muted,
				TextSize = 14,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = (resolvedProps.ZIndex or 100) + 1,
			}
		),
		RewardCard = React.createElement("Frame", {
			BackgroundColor3 = COLORS.Card,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(20, 142),
			Size = UDim2.new(1, -40, 0, 132),
			ZIndex = (resolvedProps.ZIndex or 100) + 1,
		}, {
			Corner = corner(13),
			Reward = label("FIRST CO-PLAY REWARD", {
				Position = UDim2.fromOffset(14, 10),
				Size = UDim2.new(1, -28, 0, 18),
				TextColor3 = COLORS.Accent,
				TextSize = 11,
				ZIndex = (resolvedProps.ZIndex or 100) + 2,
			}),
			Amount = label("+" .. tostring(FIRST_CO_PLAY_REWARD_GEMS) .. " Ritual Gems", {
				Position = UDim2.fromOffset(14, 30),
				Size = UDim2.new(1, -28, 0, 32),
				TextColor3 = if rewarded then COLORS.Ready else COLORS.Text,
				TextSize = 20,
				ZIndex = (resolvedProps.ZIndex or 100) + 2,
			}),
			Status = label(statusText, {
				Position = UDim2.fromOffset(14, 68),
				Size = UDim2.new(1, -28, 0, 24),
				TextColor3 = if rewarded or hasVerifiedFriend then COLORS.Ready else COLORS.Muted,
				TextSize = 13,
				ZIndex = (resolvedProps.ZIndex or 100) + 2,
			}),
			Rule = label(
				"Both players need 1 lifetime Roll and " .. tostring(math.floor(requiredSeconds)) .. " consecutive server seconds.",
				{
					Position = UDim2.fromOffset(14, 94),
					Size = UDim2.new(1, -28, 0, 30),
					TextColor3 = COLORS.Muted,
					TextSize = 11,
					ZIndex = (resolvedProps.ZIndex or 100) + 2,
				}
			),
		}),
		Invite = button(
			if not inviteChecked then "Checking invites..." else if inviteAvailable then "Invite Friends" else "Invites unavailable",
			{
				Active = inviteChecked and inviteAvailable,
				AutoButtonColor = inviteChecked and inviteAvailable,
				BackgroundColor3 = if inviteAvailable then Color3.fromRGB(118, 84, 193) else COLORS.Card,
				Position = UDim2.new(0, 20, 1, -64),
				Size = UDim2.new(1, -40, 0, layout.MinimumTargetSize),
				TextColor3 = if inviteAvailable then COLORS.Text else COLORS.Muted,
				ZIndex = (resolvedProps.ZIndex or 100) + 2,
				[React.Event.Activated] = promptInvite,
			}
		),
	})
end

function SocialOverlay.create(props)
	return React.createElement(SocialOverlayComponent, props)
end

return SocialOverlay
