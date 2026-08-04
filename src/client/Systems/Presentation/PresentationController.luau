local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	if effect ~= nil and effect.Parent ~= nil then
		effect:Destroy()
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
	effect.Parent = target
	table.insert(activeEffects, effect)
	while #activeEffects > MAX_ACTIVE_EFFECTS do
		destroyEffect(activeEffects[1])
	end

	for _, child in effect:GetChildren() do
		if child:IsA("Attachment") then
			child.Parent = target
		end
	end

	for _, event in PetRollRevealDefinition.Timeline do
		task.delay(event.AtSeconds, function()
			if effect.Parent == nil then
				return
			end
			local emitter = effect:FindFirstChild(event.EmitterId, true)
			if emitter ~= nil and emitter:IsA("ParticleEmitter") then
				if event.Kind == "emit" then
					if emitter:GetAttribute("VFXTextureUnresolved") ~= true then
						emitter:Emit(event.Count)
					end
				elseif event.Kind == "enable" then
					emitter.Enabled = emitter:GetAttribute("VFXTextureUnresolved") ~= true
				elseif event.Kind == "disable" then
					emitter.Enabled = false
				end
			end
		end)
	end
	task.delay(EFFECT_CLEANUP_SECONDS, function()
		destroyEffect(effect)
		destroyEffect(target)
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
