local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Systems = script.Parent.Parent

local PresentationAssetConfig = require(Config:WaitForChild("PresentationAssetConfig"))
local PresentationEventConfig = require(Config:WaitForChild("PresentationEventConfig"))
local ClientStateStore = require(Systems:WaitForChild("State"):WaitForChild("ClientStateStore"))
local PetRollRevealDefinition = require(script.Parent:WaitForChild("PetRollRevealDefinition"))

local PresentationController = {}

local MAX_ACTIVE_EFFECTS = 3
local EFFECT_CLEANUP_SECONDS = 2.2
local activeEffects = {}
local processedKeys = {}
local processedOrder = {}
local connections = {}
local started = false

local function rememberKey(key)
	if processedKeys[key] then
		return false
	end

	processedKeys[key] = true
	table.insert(processedOrder, key)
	while #processedOrder > 64 do
		processedKeys[table.remove(processedOrder, 1)] = nil
	end
	return true
end

local function destroyEffect(effect)
	if effect == nil then
		return
	end
	if effect.connection ~= nil then
		effect.connection:Disconnect()
		effect.connection = nil
	end
	for _, action in effect.delayedActions do
		pcall(task.cancel, action)
	end
	table.clear(effect.delayedActions)
	if effect.template ~= nil and effect.template.Parent ~= nil then
		effect.template:Destroy()
	end
	for _, anchor in effect.detachedAnchors do
		if anchor.Parent ~= nil then
			anchor:Destroy()
		end
	end
	if effect.target ~= nil and effect.target.Parent ~= nil then
		effect.target:Destroy()
	end
	for index = #activeEffects, 1, -1 do
		if activeEffects[index] == effect then
			table.remove(activeEffects, index)
		end
	end
end

local function cleanupEffects()
	for index = #activeEffects, 1, -1 do
		destroyEffect(activeEffects[index])
	end
end

local function transformCFrame(value)
	local position = value.Position
	local rotation = value.RotationDegreesXYZ
	local frame = CFrame.new(position[1], position[2], position[3])
	local matrix = value.RotationMatrix
	if type(matrix) == "table" and #matrix == 9 then
		frame = CFrame.new(
			position[1], position[2], position[3],
			matrix[1], matrix[2], matrix[3], matrix[4], matrix[5], matrix[6],
			matrix[7], matrix[8], matrix[9]
		)
	end
	return frame * CFrame.fromEulerAnglesXYZ(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
end

local function shortestAngle(left, right, amount)
	local delta = (right - left + 180) % 360 - 180
	return left + delta * amount
end

local function sampleAnchorTransform(definition, tick)
	local base = definition.LocalTransform
	local keys = definition.Keyframes
	if #keys == 0 then
		return transformCFrame(base)
	end
	local sampleTick = tick + definition.PhaseOffsetTicks
	local lastTick = keys[#keys].Tick
	if definition.Looped == true and lastTick > 0 then
		sampleTick %= lastTick
	end
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
	local position = {
		left.Offset.Position[1] + (right.Offset.Position[1] - left.Offset.Position[1]) * amount,
		left.Offset.Position[2] + (right.Offset.Position[2] - left.Offset.Position[2]) * amount,
		left.Offset.Position[3] + (right.Offset.Position[3] - left.Offset.Position[3]) * amount,
	}
	local rotation = {
		shortestAngle(left.Offset.RotationDegreesXYZ[1], right.Offset.RotationDegreesXYZ[1], amount),
		shortestAngle(left.Offset.RotationDegreesXYZ[2], right.Offset.RotationDegreesXYZ[2], amount),
		shortestAngle(left.Offset.RotationDegreesXYZ[3], right.Offset.RotationDegreesXYZ[3], amount),
	}
	return transformCFrame(base)
		* CFrame.new(position[1], position[2], position[3])
		* CFrame.fromEulerAnglesXYZ(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
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

local function collectRuntimeMaps(template, target, detachedAnchors)
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
	for _, anchor in detachedAnchors do
		collect(anchor)
		for _, instance in anchor:GetDescendants() do collect(instance) end
	end
	return anchors, emitters, beams, trails, lights, spotLights, sourceVolumes
end

local function playSound(logicalId, name)
	local soundId = PresentationAssetConfig.resolve(logicalId)
	if soundId == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = 0.8
	sound.Parent = SoundService
	local endedConnection
	endedConnection = sound.Ended:Connect(function()
		if endedConnection ~= nil then
			endedConnection:Disconnect()
			endedConnection = nil
		end
		sound:Destroy()
	end)
	sound:Play()
	task.delay(4, function()
		if sound.Parent ~= nil then
			if endedConnection ~= nil then
				endedConnection:Disconnect()
				endedConnection = nil
			end
			sound:Destroy()
		end
	end)
end

local function getRootAttachment()
	local player = Players.LocalPlayer
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "PresentationFeedbackAnchor"
	attachment.Position = Vector3.new(0, -1.5, -0.35)
	attachment.Parent = root
	return attachment
end

local function startRevealEffect()
	if not PresentationAssetConfig.isStudioLocal() then
		return
	end

	local target = getRootAttachment()
	if target == nil then
		return
	end

	local bindings = {
		release_ring = PresentationAssetConfig.resolve(PresentationAssetConfig.LogicalIds.ReleaseRing),
		seal_ribbon = PresentationAssetConfig.resolve(PresentationAssetConfig.LogicalIds.SealRibbon),
		spirit_core_flipbook = PresentationAssetConfig.resolve(PresentationAssetConfig.LogicalIds.SpiritCoreFlipbook),
		spirit_wisp_flipbook = PresentationAssetConfig.resolve(PresentationAssetConfig.LogicalIds.SpiritWispFlipbook),
	}
	local effect = PetRollRevealDefinition.CreateTemplate(bindings, { allowUnresolvedTextures = true })
	effect.Name = "PetRollRevealEffect"
	effect.Parent = target.Parent.Parent
	local detachedAnchors = {}
	for _, child in effect:GetChildren() do
		if child:IsA("Attachment") then
			table.insert(detachedAnchors, child)
		end
	end
	local state = {
		template = effect,
		target = target,
		detachedAnchors = detachedAnchors,
		delayedActions = {},
		connection = nil,
	}
	table.insert(activeEffects, state)
	while #activeEffects > MAX_ACTIVE_EFFECTS do
		destroyEffect(activeEffects[1])
	end

	local character = Players.LocalPlayer.Character
	if character == nil then
		destroyEffect(state)
		return
	end
	local function resolveCharacterPart(name)
		local candidates = { name }
		if name == "humanoid_root" then table.insert(candidates, "HumanoidRootPart") end
		if name == "head" then table.insert(candidates, "Head") end
		if name == "torso" or name == "upper_torso" then
			table.insert(candidates, "UpperTorso")
			table.insert(candidates, "Torso")
		end
		for _, candidate in candidates do
			if candidate ~= nil then
				local part = character:FindFirstChild(candidate)
				if part ~= nil and part:IsA("BasePart") then return part end
			end
		end
		return nil
	end
	local anchorDefinitions = {}
	for _, definition in PetRollRevealDefinition.Anchors do
		anchorDefinitions[definition.AnchorId] = definition
	end
	for _, anchor in detachedAnchors do
		local anchorId = anchor:GetAttribute("VFXAnchorId")
		local definition = if type(anchorId) == "string" then anchorDefinitions[anchorId] else nil
		local parent = if definition ~= nil and definition.CharacterPart ~= nil
			then resolveCharacterPart(definition.CharacterPart)
			else target
		if parent == nil then
			destroyEffect(state)
			return
		end
		anchor.Parent = parent
	end

	local anchors, emitters, beams, trails, lights, spotLights, sourceVolumes = collectRuntimeMaps(effect, target, detachedAnchors)
	local emitterDefinitions = {}
	local emitterTimelineEnabled = {}
	local emitterMotionAllowed = {}
	local emitterSourcePositions = {}
	for _, definition in PetRollRevealDefinition.Emitters do
		emitterDefinitions[definition.EmitterId] = definition
		emitterTimelineEnabled[definition.EmitterId] = false
		emitterMotionAllowed[definition.EmitterId] = definition.MinSourcePlanarSpeedStudsPerSecond <= 0
	end
	local tickHz = PetRollRevealDefinition.Registry.TickHz
	local durationTicks = PetRollRevealDefinition.Registry.DurationTicks
	local durationSeconds = PetRollRevealDefinition.Registry.DurationSeconds
	local startedAt = os.clock()
	local previousUpdateAt = startedAt
	local previousTick = -1
	local function textureReady(instance)
		return instance:GetAttribute("VFXTextureUnresolved") ~= true
	end
	local function applyTimelineEvent(event)
		local emitter = emitters[event.EmitterId]
		if emitter == nil or not textureReady(emitter) or emitter:GetAttribute("VFXConfiguredEnabled") ~= true then return end
		if event.Kind == "emit" then
			if emitterMotionAllowed[event.EmitterId] ~= false then emitter:Emit(event.Count) end
		elseif event.Kind == "enable" then
			emitterTimelineEnabled[event.EmitterId] = true
			emitter.Enabled = true
		elseif event.Kind == "disable" then
			emitterTimelineEnabled[event.EmitterId] = false
			emitter.Enabled = false
			end
	end
	local function applyTimelineRange(afterTick, throughTick)
		for _, event in PetRollRevealDefinition.Timeline do
			if event.AtTick > afterTick and event.AtTick <= throughTick then applyTimelineEvent(event) end
		end
	end
	state.connection = RunService.Heartbeat:Connect(function()
		if effect.Parent == nil or target.Parent == nil then
			destroyEffect(state)
			return
		end
		local now = os.clock()
		local elapsed = math.max(now - previousUpdateAt, 1 / tickHz)
		previousUpdateAt = now
		local absoluteTick = math.min(math.floor((now - startedAt) * tickHz), durationTicks)
		local tick = absoluteTick
		for _, definition in PetRollRevealDefinition.Anchors do
			local anchor = anchors[definition.AnchorId]
			if anchor ~= nil then anchor.CFrame = sampleAnchorTransform(definition, tick) end
		end
		for emitterId, volume in sourceVolumes do
			local anchorId = volume:GetAttribute("VFXSourceAnchorId")
			local anchor = if type(anchorId) == "string" then anchors[anchorId] else nil
			local rotation = volume:GetAttribute("VFXSourceRotationDegreesXYZ")
			if anchor ~= nil and typeof(rotation) == "Vector3" then
				volume.CFrame = anchor.WorldCFrame * CFrame.fromEulerAnglesXYZ(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
			end
		end
		for emitterId, definition in emitterDefinitions do
			local minimumSpeed = definition.MinSourcePlanarSpeedStudsPerSecond
			if minimumSpeed > 0 then
				local volume = sourceVolumes[emitterId]
				local anchor = anchors[definition.AnchorId]
				local position = if volume ~= nil then volume.Position elseif anchor ~= nil then anchor.WorldPosition else nil
				if position ~= nil then
					local previous = emitterSourcePositions[emitterId]
					emitterSourcePositions[emitterId] = position
					local allowed = previous ~= nil and (Vector3.new(position.X - previous.X, 0, position.Z - previous.Z).Magnitude / elapsed >= minimumSpeed)
					emitterMotionAllowed[emitterId] = allowed
					local emitter = emitters[emitterId]
					if emitter ~= nil then emitter.Enabled = emitter:GetAttribute("VFXConfiguredEnabled") == true and textureReady(emitter) and emitterTimelineEnabled[emitterId] and allowed end
				end
			end
		end
		for _, definition in PetRollRevealDefinition.Beams do
			local beam = beams[definition.BeamId]
			if beam ~= nil then
				beam.Enabled = beam:GetAttribute("VFXConfiguredEnabled") == true and textureReady(beam) and timelineActive(definition.StartTick, definition.DurationTicks, tick, durationTicks)
				local scale = pulseScale(definition.WidthPulses, tick)
				beam.Width0 = definition.Width0 * scale
				beam.Width1 = definition.Width1 * scale
			end
		end
		for _, definition in PetRollRevealDefinition.Trails do
			local trail = trails[definition.TrailId]
			if trail ~= nil then trail.Enabled = trail:GetAttribute("VFXConfiguredEnabled") == true and textureReady(trail) and timelineActive(definition.StartTick, definition.DurationTicks, tick, durationTicks) end
		end
		for _, definition in PetRollRevealDefinition.Lights do
			local light = lights[definition.LightId]
			if light ~= nil then light.Enabled = light:GetAttribute("VFXConfiguredEnabled") == true and timelineActive(definition.StartTick, definition.DurationTicks, tick, durationTicks); light.Brightness = definition.Brightness * pulseScale(definition.BrightnessPulses, tick) end
		end
		for _, definition in PetRollRevealDefinition.SpotLights do
			local light = spotLights[definition.LightId]
			if light ~= nil then light.Enabled = light:GetAttribute("VFXConfiguredEnabled") == true and timelineActive(definition.StartTick, definition.DurationTicks, tick, durationTicks); light.Brightness = definition.Brightness * pulseScale(definition.BrightnessPulses, tick) end
		end
		applyTimelineRange(previousTick, tick)
		previousTick = tick
		if now - startedAt >= durationSeconds then destroyEffect(state) end
	end)
end

local function handleFeedback(records)
	for _, record in ipairs(records) do
		if rememberKey(record.DedupeKey) then
			if record.EventId == PresentationEventConfig.EventIds.PetRollReveal then
				playSound(PresentationAssetConfig.LogicalIds.PetRollRevealSound, "PetRollRevealCue")
				startRevealEffect()
			elseif record.EventId == PresentationEventConfig.EventIds.ZoneUnlocked then
				playSound(PresentationAssetConfig.LogicalIds.ZoneUnlockedSound, "ZoneUnlockedCue")
			end
		end
	end
end

function PresentationController.start()
	if started then
		return
	end
	started = true
	table.insert(connections, ClientStateStore.subscribeFeedback(handleFeedback))
	local characterRemovingConnection = Players.LocalPlayer.CharacterRemoving:Connect(cleanupEffects)
	table.insert(connections, function()
		characterRemovingConnection:Disconnect()
	end)
end

function PresentationController.stop()
	if not started then
		return
	end
	started = false
	for _, disconnect in connections do
		disconnect()
	end
	table.clear(connections)
	cleanupEffects()
end

return PresentationController
