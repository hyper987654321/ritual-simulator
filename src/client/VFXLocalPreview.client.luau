-- Generated Studio-only local VFX preview. Never publish this script.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Definition = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VFXLocal"):WaitForChild("reference_waterfall_01"))
local TEXTURES = {
	["braided_wisp"] = "rbxasset://vfx-local/reference_waterfall_01/04f5ca2ac1793111/braided_wisp.png",
	["broad_soft_flow_band"] = "rbxasset://vfx-local/reference_waterfall_01/04f5ca2ac1793111/broad_soft_flow_band.png",
	["mist_puff"] = "rbxasset://vfx-local/reference_waterfall_01/04f5ca2ac1793111/mist_puff.png",
	["vertical_flow_noise"] = "rbxasset://vfx-local/reference_waterfall_01/04f5ca2ac1793111/vertical_flow_noise.png",
}
local TARGET_OFFSET = CFrame.new(0, -3, -5)

local TARGET_NAME = "VFXLocalPreviewTarget"
local TEMPLATE_NAME = "VFXLocalPreviewRuntime"
local LEGACY_LINEUP_TARGET_PREFIX = "VFXLocalLineupTarget_"
local LEGACY_LINEUP_TEMPLATE_NAME = "VFXLocalLineupRuntime"
local REVIEW_STAGE_NAME = "__VFXGameplayReview"
local REVIEW_STAGE_ORIGIN = Vector3.new(0, 2048, 0)
local REVIEW_HIDDEN_WORKSPACE_CHILDREN = table.freeze({
	LocalRitualStone = true,
})
local activeAnimation = nil

local CHARACTER_PART_CANDIDATES = table.freeze({
	humanoid_root = table.freeze({ "HumanoidRootPart" }),
	head = table.freeze({ "Head" }),
	torso = table.freeze({ "UpperTorso", "Torso" }),
	upper_torso = table.freeze({ "UpperTorso", "Torso" }),
	lower_torso = table.freeze({ "LowerTorso", "Torso" }),
	left_arm = table.freeze({ "LeftUpperArm", "Left Arm" }),
	left_upper_arm = table.freeze({ "LeftUpperArm", "Left Arm" }),
	left_lower_arm = table.freeze({ "LeftLowerArm", "Left Arm" }),
	left_hand = table.freeze({ "LeftHand", "Left Arm" }),
	right_arm = table.freeze({ "RightUpperArm", "Right Arm" }),
	right_upper_arm = table.freeze({ "RightUpperArm", "Right Arm" }),
	right_lower_arm = table.freeze({ "RightLowerArm", "Right Arm" }),
	right_hand = table.freeze({ "RightHand", "Right Arm" }),
	left_leg = table.freeze({ "LeftUpperLeg", "Left Leg" }),
	left_upper_leg = table.freeze({ "LeftUpperLeg", "Left Leg" }),
	left_lower_leg = table.freeze({ "LeftLowerLeg", "Left Leg" }),
	left_foot = table.freeze({ "LeftFoot", "Left Leg" }),
	right_leg = table.freeze({ "RightUpperLeg", "Right Leg" }),
	right_upper_leg = table.freeze({ "RightUpperLeg", "Right Leg" }),
	right_lower_leg = table.freeze({ "RightLowerLeg", "Right Leg" }),
	right_foot = table.freeze({ "RightFoot", "Right Leg" }),
})

local function resolveCharacterPart(character: Model, semanticName: string): BasePart
	local candidates = CHARACTER_PART_CANDIDATES[semanticName]
	if candidates == nil then error(string.format("unsupported character part binding %q", semanticName)) end
	for _, candidate in candidates do
		local part = character:FindFirstChild(candidate)
		if part ~= nil and part:IsA("BasePart") then return part end
	end
	error(string.format(
		"character %q has no BasePart for binding %q (tried %s)",
		character.Name,
		semanticName,
		table.concat(candidates, ", ")
	))
end

local function hideReviewClutter(instance: Instance)
	if REVIEW_HIDDEN_WORKSPACE_CHILDREN[instance.Name] == true and instance.Parent == Workspace then
		instance.Parent = nil
	end
end

Workspace.ChildAdded:Connect(hideReviewClutter)
for _, child in Workspace:GetChildren() do
	hideReviewClutter(child)
end

local function createReviewPart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Material = material
	part.Color = color
	part.Size = size
	part.Position = REVIEW_STAGE_ORIGIN + position
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildReviewStage(): CFrame
	local oldStage = Workspace:FindFirstChild(REVIEW_STAGE_NAME)
	if oldStage ~= nil then oldStage:Destroy() end

	local stage = Instance.new("Folder")
	stage.Name = REVIEW_STAGE_NAME
	stage.Parent = Workspace
	createReviewPart(
		stage,
		"Ground",
		Vector3.new(96, 1, 96),
		Vector3.new(0, -0.5, 0),
		Color3.fromRGB(88, 94, 106),
		Enum.Material.Concrete
	)
	createReviewPart(
		stage,
		"Backdrop",
		Vector3.new(96, 64, 2),
		Vector3.new(0, 32, -32),
		Color3.fromRGB(112, 119, 132),
		Enum.Material.SmoothPlastic
	)
	return CFrame.lookAt(
		REVIEW_STAGE_ORIGIN + Vector3.new(0, 3, 0),
		REVIEW_STAGE_ORIGIN + Vector3.new(0, 3, -1)
	)
end

local function placeCharacterOnReviewStage(character: Model, humanoidRootPart: BasePart)
	local reviewCFrame = buildReviewStage()
	character:PivotTo(reviewCFrame)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
end

local function transformCFrame(value)
	local position = value.Position
	local rotation = value.RotationDegreesXYZ
	local frame = CFrame.new(position[1], position[2], position[3])
	local matrix = value.RotationMatrix
	if type(matrix) == "table" and #matrix == 9 then
		frame = CFrame.new(position[1], position[2], position[3],
			matrix[1], matrix[2], matrix[3], matrix[4], matrix[5], matrix[6], matrix[7], matrix[8], matrix[9])
	end
	return frame
		* CFrame.fromEulerAnglesXYZ(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
end

local function shortestAngle(left, right, amount)
	local delta = (right - left + 180) % 360 - 180
	return left + delta * amount
end

local function sampleAnchorTransform(definition, tick)
	local base = definition.LocalTransform
	local keys = definition.Keyframes
	if #keys == 0 then return transformCFrame(base) end
	local sampleTick = tick + definition.PhaseOffsetTicks
	local lastTick = keys[#keys].Tick
	if definition.Looped == true and lastTick > 0 then sampleTick %= lastTick end
	local left = keys[1]
	local right = keys[#keys]
	for index = 2, #keys do
		if sampleTick <= keys[index].Tick then
			left = keys[index - 1]
			right = keys[index]
			break
		end
	end
	if sampleTick <= keys[1].Tick then left = keys[1]; right = keys[1] end
	if sampleTick >= lastTick then left = keys[#keys]; right = keys[#keys] end
	local span = right.Tick - left.Tick
	local amount = if span <= 0 then 0 else math.clamp((sampleTick - left.Tick) / span, 0, 1)
	if definition.Interpolation == "Step" then amount = 0 end
	if definition.Interpolation == "SmoothStep" then amount = amount * amount * (3 - 2 * amount) end
	local offsetPosition = {
		left.Offset.Position[1] + (right.Offset.Position[1] - left.Offset.Position[1]) * amount,
		left.Offset.Position[2] + (right.Offset.Position[2] - left.Offset.Position[2]) * amount,
		left.Offset.Position[3] + (right.Offset.Position[3] - left.Offset.Position[3]) * amount,
	}
	local offsetRotation = {
		shortestAngle(left.Offset.RotationDegreesXYZ[1], right.Offset.RotationDegreesXYZ[1], amount),
		shortestAngle(left.Offset.RotationDegreesXYZ[2], right.Offset.RotationDegreesXYZ[2], amount),
		shortestAngle(left.Offset.RotationDegreesXYZ[3], right.Offset.RotationDegreesXYZ[3], amount),
	}
	return transformCFrame(base)
		* CFrame.new(offsetPosition[1], offsetPosition[2], offsetPosition[3])
		* CFrame.fromEulerAnglesXYZ(math.rad(offsetRotation[1]), math.rad(offsetRotation[2]), math.rad(offsetRotation[3]))
end

local function pulseScale(pulses, tick)
	local scale = 1
	for _, pulse in pulses do
		if tick >= pulse.AtTick and tick < pulse.AtTick + pulse.DurationTicks then
			local amount = math.clamp((tick - pulse.AtTick) / pulse.DurationTicks, 0, 1)
			local smooth = amount * amount * (3 - 2 * amount)
			scale *= pulse.Scale + (1 - pulse.Scale) * smooth
		end
	end
	return scale
end

local function timelineActive(startTick, durationTicks, tick, timelineDurationTicks)
	if durationTicks <= 0 then return false end
	if durationTicks >= timelineDurationTicks then return true end
	local endTick = startTick + durationTicks
	if endTick <= timelineDurationTicks then
		return tick >= startTick and tick < endTick
	end
	return tick >= startTick or tick < endTick % timelineDurationTicks
end

local function collectRuntimeMaps(template, target, boundRoots)
	local anchors = {}
	local emitters = {}
	local beams = {}
	local trails = {}
	local lights = {}
	local spotLights = {}
	local sourceVolumes = {}
	local function collect(instance)
		if instance:IsA("Attachment") then
			local id = instance:GetAttribute("VFXAnchorId")
			if type(id) == "string" then anchors[id] = instance end
		elseif instance:IsA("ParticleEmitter") then
			local id = instance:GetAttribute("VFXEmitterId")
			if type(id) == "string" then emitters[id] = instance end
		elseif instance:IsA("Beam") then
			local id = instance:GetAttribute("VFXBeamId")
			if type(id) == "string" then beams[id] = instance end
		elseif instance:IsA("Trail") then
			local id = instance:GetAttribute("VFXTrailId")
			if type(id) == "string" then trails[id] = instance end
		elseif instance:IsA("PointLight") then
			local id = instance:GetAttribute("VFXLightId")
			if type(id) == "string" then lights[id] = instance end
		elseif instance:IsA("SpotLight") then
			local id = instance:GetAttribute("VFXLightId")
			if type(id) == "string" then spotLights[id] = instance end
		elseif instance:IsA("BasePart") then
			local id = instance:GetAttribute("VFXSourceEmitterId")
			if type(id) == "string" then sourceVolumes[id] = instance end
		end
	end
	collect(template)
	collect(target)
	for _, instance in template:GetDescendants() do collect(instance) end
	for _, instance in target:GetDescendants() do collect(instance) end
	for _, root in boundRoots do
		collect(root)
		for _, instance in root:GetDescendants() do collect(instance) end
	end
	return anchors, emitters, beams, trails, lights, spotLights, sourceVolumes
end

local function startAnimation(template, target, boundRoots)
	if activeAnimation ~= nil then activeAnimation:Disconnect(); activeAnimation = nil end
	local anchors, emitters, beams, trails, lights, spotLights, sourceVolumes = collectRuntimeMaps(template, target, boundRoots)
	local emitterDefinitions = {}
	local emitterTimelineEnabled = {}
	local emitterMotionAllowed = {}
	local emitterSourcePositions = {}
	for _, definition in Definition.Emitters do
		emitterDefinitions[definition.EmitterId] = definition
		emitterTimelineEnabled[definition.EmitterId] = false
		emitterMotionAllowed[definition.EmitterId] = definition.MinSourcePlanarSpeedStudsPerSecond <= 0
	end
	local tickHz = Definition.Registry.TickHz
	local durationTicks = Definition.Registry.DurationTicks
	local startedAt = os.clock()
	local previousUpdateAt = startedAt
	local previousTick = -1
	local previousCycle = -1
	local function applyTimelineEvent(event)
		local emitter = emitters[event.EmitterId]
		if emitter == nil then return end
		if event.Kind == "emit" then
			if emitterMotionAllowed[event.EmitterId] ~= false then emitter:Emit(event.Count) end
		elseif event.Kind == "enable" then
			emitterTimelineEnabled[event.EmitterId] = true
			emitter.Enabled = emitter:GetAttribute("VFXConfiguredEnabled") == true
				and emitterMotionAllowed[event.EmitterId] ~= false
		elseif event.Kind == "disable" then
			emitterTimelineEnabled[event.EmitterId] = false
			emitter.Enabled = false
		end
	end
	local function applyTimelineRange(afterTick, throughTick)
		for _, event in Definition.Timeline do
			if event.AtTick > afterTick and event.AtTick <= throughTick then applyTimelineEvent(event) end
		end
	end
	activeAnimation = RunService.Heartbeat:Connect(function()
		if template.Parent == nil or target.Parent == nil then
			if activeAnimation ~= nil then activeAnimation:Disconnect(); activeAnimation = nil end
			return
		end
		local now = os.clock()
		local elapsed = math.max(now - previousUpdateAt, 1 / 240)
		previousUpdateAt = now
		local absoluteTick = math.floor((now - startedAt) * tickHz)
		local cycle = math.floor(absoluteTick / durationTicks)
		local tick = absoluteTick % durationTicks
		for _, definition in Definition.Anchors do
			local anchor = anchors[definition.AnchorId]
			if anchor ~= nil then anchor.CFrame = sampleAnchorTransform(definition, tick) end
		end
		for emitterId, volume in sourceVolumes do
			local anchorId = volume:GetAttribute("VFXSourceAnchorId")
			local anchor = if type(anchorId) == "string" then anchors[anchorId] else nil
			local rotation = volume:GetAttribute("VFXSourceRotationDegreesXYZ")
			if anchor ~= nil and typeof(rotation) == "Vector3" then
				volume.CFrame = anchor.WorldCFrame
					* CFrame.fromEulerAnglesXYZ(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
			end
		end
		for emitterId, definition in emitterDefinitions do
			local minimumSpeed = definition.MinSourcePlanarSpeedStudsPerSecond
			if minimumSpeed > 0 then
				local volume = sourceVolumes[emitterId]
				local anchor = anchors[definition.AnchorId]
				local currentPosition = if volume ~= nil
					then volume.Position
					elseif anchor ~= nil then anchor.WorldPosition else nil
				if currentPosition ~= nil then
					local previousPosition = emitterSourcePositions[emitterId]
					emitterSourcePositions[emitterId] = currentPosition
					local allowed = false
					if previousPosition ~= nil then
						local delta = currentPosition - previousPosition
						local planarSpeed = Vector3.new(delta.X, 0, delta.Z).Magnitude / elapsed
						allowed = planarSpeed >= minimumSpeed
					end
					emitterMotionAllowed[emitterId] = allowed
					local emitter = emitters[emitterId]
					if emitter ~= nil then
						emitter.Enabled = emitter:GetAttribute("VFXConfiguredEnabled") == true
							and emitterTimelineEnabled[emitterId] == true
							and allowed
					end
				end
			end
		end
		for _, definition in Definition.Beams do
			local beam = beams[definition.BeamId]
			if beam ~= nil then
				beam.Enabled = beam:GetAttribute("VFXConfiguredEnabled") == true
					and timelineActive(definition.StartTick, definition.DurationTicks, tick, durationTicks)
				local scale = pulseScale(definition.WidthPulses, tick)
				beam.Width0 = definition.Width0 * scale
				beam.Width1 = definition.Width1 * scale
			end
		end
		for _, definition in Definition.Trails do
			local trail = trails[definition.TrailId]
			if trail ~= nil then
				trail.Enabled = trail:GetAttribute("VFXConfiguredEnabled") == true
					and timelineActive(definition.StartTick, definition.DurationTicks, tick, durationTicks)
			end
		end
		for _, definition in Definition.Lights do
			local light = lights[definition.LightId]
			if light ~= nil then
				light.Enabled = light:GetAttribute("VFXConfiguredEnabled") == true
					and timelineActive(definition.StartTick, definition.DurationTicks, tick, durationTicks)
				light.Brightness = definition.Brightness * pulseScale(definition.BrightnessPulses, tick)
			end
		end
		for _, definition in Definition.SpotLights do
			local light = spotLights[definition.LightId]
			if light ~= nil then
				light.Enabled = light:GetAttribute("VFXConfiguredEnabled") == true
					and timelineActive(definition.StartTick, definition.DurationTicks, tick, durationTicks)
				light.Brightness = definition.Brightness * pulseScale(definition.BrightnessPulses, tick)
			end
		end
		if previousCycle >= 0 and cycle > previousCycle then
			applyTimelineRange(previousTick, durationTicks)
			for emitterId, emitter in emitters do
				emitterTimelineEnabled[emitterId] = false
				emitter.Enabled = false
			end
			for _, trail in trails do trail:Clear() end
			applyTimelineRange(-1, tick)
		else
			applyTimelineRange(previousTick, tick)
		end
		previousTick = tick
		previousCycle = cycle
	end)
end

local function configureVisuals(template: Folder)
	for _, instance in template:GetDescendants() do
		if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
			local textureKey = instance:GetAttribute("VFXTextureKey")
			local texture = if type(textureKey) == "string" then TEXTURES[textureKey] else nil
			if texture == nil and not (instance:IsA("Trail") and textureKey == nil) then
				error(string.format("missing Studio-local texture for %s", tostring(textureKey)))
			end
			if texture ~= nil then instance.Texture = texture end
			instance:SetAttribute("VFXTextureUnresolved", false)
			instance.Enabled = false
		elseif instance:IsA("PointLight") or instance:IsA("SpotLight") then
			instance.Enabled = false
		end
	end
end

local function preloadVisuals(template: Folder)
	local renderers = {}
	for _, instance in template:GetDescendants() do
		if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
			if instance.Texture ~= "" then table.insert(renderers, instance) end
		end
	end
	if #renderers == 0 then return end
	-- Preload only this effect's renderers before tick-zero bursts. Roblox documents
	-- PreloadAsync for important spawn assets:
	-- https://create.roblox.com/docs/reference/engine/classes/ContentProvider#PreloadAsync
	-- Verified 2026-07-29.
	local failures = {}
	ContentProvider:PreloadAsync(renderers, function(assetId, status)
		if status ~= Enum.AssetFetchStatus.Success then
			table.insert(failures, string.format("%s (%s)", tostring(assetId), status.Name))
		end
	end)
	if #failures > 0 then
		error("failed to preload Studio-local textures: " .. table.concat(failures, ", "))
	end
end

local function play(character: Model)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
	if humanoidRootPart == nil or not humanoidRootPart:IsA("BasePart") then
		warn("Studio-local VFX preview could not find HumanoidRootPart")
		return
	end
	placeCharacterOnReviewStage(character, humanoidRootPart)
	local oldTarget = humanoidRootPart:FindFirstChild(TARGET_NAME)
	if oldTarget ~= nil then oldTarget:Destroy() end
	local oldTemplate = character:FindFirstChild(TEMPLATE_NAME)
	if oldTemplate ~= nil then oldTemplate:Destroy() end
	for _, child in humanoidRootPart:GetChildren() do
		if string.sub(child.Name, 1, #LEGACY_LINEUP_TARGET_PREFIX) == LEGACY_LINEUP_TARGET_PREFIX then
			child:Destroy()
		end
	end
	local oldLineupTemplate = character:FindFirstChild(LEGACY_LINEUP_TEMPLATE_NAME)
	if oldLineupTemplate ~= nil then oldLineupTemplate:Destroy() end

	local target = Instance.new("Attachment")
	target.Name = TARGET_NAME
	target.CFrame = TARGET_OFFSET
	target.Parent = humanoidRootPart

	local template = Definition.CreateTemplate(nil, { allowUnresolvedTextures = true })
	template.Name = TEMPLATE_NAME
	configureVisuals(template)
	template.Parent = character

	local rootAnchors = {}
	for _, child in template:GetChildren() do
		if child:IsA("Attachment") then table.insert(rootAnchors, child) end
	end
	local anchorDefinitions = {}
	for _, anchorDefinition in Definition.Anchors do
		anchorDefinitions[anchorDefinition.AnchorId] = anchorDefinition
	end
	for _, anchor in rootAnchors do
		local anchorId = anchor:GetAttribute("VFXAnchorId")
		local anchorDefinition = if type(anchorId) == "string" then anchorDefinitions[anchorId] else nil
		local characterPart = if anchorDefinition ~= nil then anchorDefinition.CharacterPart else nil
		anchor.Parent = if characterPart ~= nil
			then resolveCharacterPart(character, characterPart)
			else target
	end
	preloadVisuals(template)
	startAnimation(template, target, rootAnchors)
	print("Studio-local VFX preview active:", Definition.Registry.EffectName)
end

local player = Players.LocalPlayer
player.CharacterAdded:Connect(play)
if player.Character ~= nil then task.defer(play, player.Character) end
