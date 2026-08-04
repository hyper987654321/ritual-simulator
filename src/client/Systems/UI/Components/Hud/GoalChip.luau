local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HudPrimitives = require(script.Parent.Parent.Parent:WaitForChild("Components"):WaitForChild("Common"):WaitForChild("HudPrimitives"))

local GoalChip = {}

function GoalChip.create(props)
	local resolved = props or {}
	local onboarding = resolved.Snapshot and resolved.Snapshot.Onboarding or {}
	local goal = onboarding.CurrentGoal
	local title = if goal then goal.TitleKey else "goal.complete.title"
	local description = if goal then goal.DescriptionKey else "Your ritual path is complete."

	return HudPrimitives.createPanel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(1, -24, 0, 58),
		BackgroundColor3 = Color3.fromRGB(31, 29, 49),
		ZIndex = 70,
	}, {
		Title = HudPrimitives.createLabel(title, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -150, 0, 22),
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 220, 120),
			ZIndex = 71,
		}),
		Description = HudPrimitives.createLabel(description, {
			Position = UDim2.fromOffset(12, 29),
			Size = UDim2.new(1, -150, 0, 20),
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 71,
		}),
		Details = HudPrimitives.createButton("Details", {
			Position = UDim2.new(1, -136, 0, 8),
			Size = UDim2.fromOffset(58, 44),
			TextSize = 12,
			ZIndex = 72,
			[React.Event.Activated] = resolved.OnOpen,
		}),
		Invite = HudPrimitives.createButton("Invite", {
			Position = UDim2.new(1, -72, 0, 8),
			Size = UDim2.fromOffset(60, 44),
			TextSize = 12,
			ZIndex = 72,
			[React.Event.Activated] = function()
				local ok = pcall(function() SocialService:PromptGameInvite(game:GetService("Players").LocalPlayer) end)
				if ok and resolved.OnInvite ~= nil then resolved.OnInvite() end
			end,
		}),
	})
end

return GoalChip
