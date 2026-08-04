local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HudPrimitives = require(script.Parent.Parent.Parent:WaitForChild("Components"):WaitForChild("Common"):WaitForChild("HudPrimitives"))

local GoalChip = {}
local copy = {
	first_roll = { "Roll your first pet", "Open the Ritual Core and complete a roll." },
	entered_crystal_zone = { "Enter the crystal area", "Travel to your active crystal area." },
	first_stone_upgrade = { "Upgrade the Ritual Stone", "Highlight Capacity to store more Essence." },
	zone_2_unlocked = { "Unlock Zone 2", "Reach the next zone requirement." },
	zone_3_unlocked = { "Reach Zone 3", "Unlock Zone 3 to access Rune Focus." },
	first_rebirth = { "Prepare your first Rebirth", "Meet both Rebirth requirements." },
	rune_focus_selected = { "Choose a Rune Focus", "Select the focus that fits your ritual." },
	away_rewards_pending = { "Resolve Away rewards", "Claim or dismiss the return summary before resetting." },
	select_rune_focus = { "Select a Rune Focus", "Choose an available Rune Focus." },
	ascension_ready = { "Ascension is ready", "Visit the Ascension Statue." },
	rebirth_ready = { "Rebirth is ready", "Reset your run for permanent power." },
	unlock_zone = { "Unlock the next zone", "Spend Essence to open the next zone." },
	capacity_blocked = { "Increase Capacity", "Upgrade the Ritual Stone or enable Auto Capacity." },
	farm_zone = { "Farm the current zone", "Gather Essence toward your next milestone." },
	v1_complete = { "Ritual Simulator complete", "You reached every current Ascension milestone." },
}

local function GoalChipComponent(props)
	local snapshot = props.Snapshot or {}
	local goal = snapshot.Onboarding and snapshot.Onboarding.CurrentGoal
	local goalId = if goal then goal.GoalId else "v1_complete"
	local text = copy[goalId] or copy.v1_complete
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local width = math.min(360, math.max(200, viewport.X - 24))
	local initiallyHidden = snapshot.Onboarding and snapshot.Onboarding.GuidanceHidden == true
	local expanded, setExpanded = React.useState(false)
	local guidanceHidden, setGuidanceHidden = React.useState(initiallyHidden)
	local inviteAvailable, setInviteAvailable = React.useState(false)

	React.useEffect(function()
		local cancelled = false
		task.spawn(function()
			local ok, available = pcall(function()
				return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
			end)
			if not cancelled then setInviteAvailable(ok and available == true) end
		end)
		return function() cancelled = true end
	end, {})

	local function toggleGuidance()
		local nextHidden = not guidanceHidden
		setGuidanceHidden(nextHidden)
		if props.OnUpdateGuidance then props.OnUpdateGuidance({ GuidanceHidden = nextHidden }) end
	end

	local children = {
		Title = HudPrimitives.createLabel(text[1], { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -96, 0, 24), TextSize = 15, TextColor3 = Color3.fromRGB(255, 220, 120), ZIndex = 71 }),
		Details = HudPrimitives.createButton(if expanded then "Close" else "Details", { Position = UDim2.new(1, -78, 0, 7), Size = UDim2.fromOffset(66, 44), TextSize = 12, ZIndex = 72, [React.Event.Activated] = function() setExpanded(not expanded) end }),
	}
	if not guidanceHidden then
		children.Description = HudPrimitives.createLabel(text[2], { Position = UDim2.fromOffset(12, 31), Size = UDim2.new(1, -24, 0, 20), TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 71 })
	end
	if expanded then
		children.Facts = HudPrimitives.createLabel(string.format("Progress: %s / %s", tostring(goal and goal.Current or 0), tostring(goal and goal.Required or 0)), { Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 24), TextSize = 14, ZIndex = 71 })
		children.Guidance = HudPrimitives.createButton(if guidanceHidden then "Show guidance" else "Hide guidance", { Position = UDim2.fromOffset(12, 94), Size = UDim2.fromOffset(128, 44), TextSize = 12, ZIndex = 72, [React.Event.Activated] = toggleGuidance })
		if inviteAvailable then
			children.Invite = HudPrimitives.createButton("Invite Friends", { Position = UDim2.new(1, -140, 1, -52), Size = UDim2.fromOffset(128, 44), TextSize = 12, ZIndex = 72, [React.Event.Activated] = function() pcall(function() SocialService:PromptGameInvite(Players.LocalPlayer) end) end })
		end
	end
	return HudPrimitives.createPanel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(width, if expanded then 154 else 62), BackgroundColor3 = Color3.fromRGB(31, 29, 49), ZIndex = 70 }, children)
end

function GoalChip.create(props)
	return React.createElement(GoalChipComponent, props or {})
end

return GoalChip
