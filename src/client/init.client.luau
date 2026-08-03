local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Systems = script:WaitForChild("Systems")

local RitualStoneVisualController = require(Systems:WaitForChild("Ritual"):WaitForChild("RitualStoneVisualController"))
local HudController = require(Systems:WaitForChild("UI"):WaitForChild("HudController"))
local ReplicatedPlayerVisualController = require(Systems:WaitForChild("World"):WaitForChild("ReplicatedPlayerVisualController"))
local WorldController = require(Systems:WaitForChild("World"):WaitForChild("WorldController"))

local function startStudioVFXPreview()
	if not RunService:IsStudio() then
		return
	end

	local previewTemplate = script:FindFirstChild("VFXLocalPreview")

	if previewTemplate == nil or not previewTemplate:IsA("LocalScript") then
		return
	end

	previewTemplate.Enabled = false

	local existingRuntime = script.Parent:FindFirstChild("VFXLocalPreviewRuntime")

	if existingRuntime ~= nil then
		existingRuntime:Destroy()
	end

	local runtime = previewTemplate:Clone()
	runtime.Name = "VFXLocalPreviewRuntime"
	runtime.Enabled = true
	runtime.Parent = script.Parent

	task.delay(4, function()
		local player = Players.LocalPlayer
		local character = player.Character
		local template = if character ~= nil then character:FindFirstChild("VFXLocalPreviewRuntime") else nil

		if template == nil then
			warn("[VFXPreviewAudit] generated runtime was not attached to the character")
			return
		end

		print(
			"[VFXPreviewAudit]",
			template:GetAttribute("VFXEffectId"),
			template:GetAttribute("VFXSourceFingerprint")
		)

		for _, descendant in template:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				local emitterId = descendant:GetAttribute("VFXEmitterId")

				if
					type(emitterId) == "string"
					and (
						string.find(emitterId, "flame_envelope", 1, true) ~= nil
						or emitterId == "ground_rising_wisp_field"
					)
				then
					local parent = descendant.Parent
					local parentDescription = parent.ClassName .. ":" .. parent.Name

					if parent:IsA("BasePart") then
						parentDescription ..= string.format(
							" size=(%.2f,%.2f,%.2f) position=(%.2f,%.2f,%.2f)",
							parent.Size.X,
							parent.Size.Y,
							parent.Size.Z,
							parent.Position.X,
							parent.Position.Y,
							parent.Position.Z
						)
					end

					print(
						string.format(
							"[VFXPreviewAudit] %s enabled=%s rate=%.2f zOffset=%.2f parent=%s",
							emitterId,
							tostring(descendant.Enabled),
							descendant.Rate,
							descendant.ZOffset,
							parentDescription
						)
					)
				end
			end
		end
	end)
end

WorldController.start()
RitualStoneVisualController.start()
ReplicatedPlayerVisualController.start()
HudController.start()
startStudioVFXPreview()
