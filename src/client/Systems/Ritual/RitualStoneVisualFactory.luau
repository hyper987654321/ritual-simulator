local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))
local RitualStoneVisualConfig = require(Config:WaitForChild("RitualStoneVisualConfig"))

local RitualStoneVisualFactory = {}

local RITUAL_POWER_TEXT_COLOR = "#C84656"

local function createPart(parent, name, properties)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false

	for property, value in pairs(properties) do
		part[property] = value
	end

	part.Parent = parent

	return part
end

local function createBillboard(parent)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StoneBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(230, 60)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.Parent = parent

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Font = UIThemeConfig.Font
	text.RichText = true
	text.Size = UDim2.fromScale(1, 1)
	text.Text = ""
	text.TextColor3 = Color3.fromRGB(237, 235, 255)
	text.TextScaled = true
	text.TextStrokeTransparency = 0.45
	text.Parent = billboard

	return billboard, text
end

function RitualStoneVisualFactory.create(parent)
	local body = createPart(parent, "StoneBody", {
		Color = RitualStoneVisualConfig.BodyColor,
		Material = Enum.Material.Basalt,
		Size = RitualStoneVisualConfig.BodyBaseSize,
	})

	local core = createPart(parent, "StoneCore", {
		Color = RitualStoneVisualConfig.CoreBaseColor,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		Size = RitualStoneVisualConfig.CoreBaseSize,
	})

	local ring = createPart(parent, "StoneRing", {
		Color = RitualStoneVisualConfig.RingColor,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder,
		Size = RitualStoneVisualConfig.RingSize,
		Transparency = 0.22,
	})

	local glow = Instance.new("PointLight")
	glow.Name = "StoneGlow"
	glow.Brightness = 1.8
	glow.Color = core.Color
	glow.Range = 14
	glow.Parent = core

	local billboard, label = createBillboard(body)

	return {
		Body = body,
		Core = core,
		Ring = ring,
		Glow = glow,
		Billboard = billboard,
		Label = label,
		RingTransparency = ring.Transparency,
		HasPosition = false,
	}
end

function RitualStoneVisualFactory.setVisible(visual, isVisible)
	visual.Body.Transparency = if isVisible then 0 else 1
	visual.Core.Transparency = if isVisible then 0 else 1
	visual.Ring.Transparency = if isVisible then visual.RingTransparency else 1
	visual.Glow.Enabled = isVisible
	visual.Billboard.Enabled = isVisible
end

function RitualStoneVisualFactory.updateStats(visual, snapshot)
	if snapshot == nil or snapshot.StoneStats == nil then
		return
	end

	local state = RitualStoneVisualConfig.getVisualState(snapshot)
	local ritualPower = snapshot.RitualPower or 0

	visual.Body.Size = state.BodySize
	visual.Core.Size = state.CoreSize
	visual.Core.Color = state.CoreColor
	visual.Glow.Color = visual.Core.Color
	visual.Glow.Brightness = state.GlowBrightness
	visual.RingTransparency = state.RingTransparency
	visual.Ring.Transparency = state.RingTransparency
	visual.Label.Text = string.format(
		"<font color=\"%s\">%s</font>",
		RITUAL_POWER_TEXT_COLOR,
		NumberFormatter.compact(ritualPower)
	)
end

function RitualStoneVisualFactory.updateFollow(visual, rootCFrame, timeNow, dt)
	local bob = math.sin(timeNow * 2.2) * 0.25
	local targetPosition = rootCFrame.Position
		+ rootCFrame.RightVector * RitualStoneVisualConfig.FollowOffset.X
		+ Vector3.new(0, RitualStoneVisualConfig.FollowOffset.Y + bob, 0)
		+ rootCFrame.LookVector * RitualStoneVisualConfig.FollowOffset.Z
	local yaw = timeNow * 0.7
	local targetCFrame = CFrame.new(targetPosition) * CFrame.Angles(0, yaw, 0)
	local alpha = math.clamp(dt * 8, 0, 1)

	if visual.HasPosition then
		visual.Body.CFrame = visual.Body.CFrame:Lerp(targetCFrame, alpha)
	else
		visual.Body.CFrame = targetCFrame
		visual.HasPosition = true
	end

	visual.Core.CFrame = visual.Body.CFrame * CFrame.new(0, 0.25, 0)
	visual.Ring.CFrame = visual.Body.CFrame * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, timeNow * 1.5, 0)
end

return RitualStoneVisualFactory
