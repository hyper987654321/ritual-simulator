local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local PetConfig = require(Config:WaitForChild("PetConfig"))

local PetModelVisualFactory = {}

local PET_MODEL_FOLDER_NAME = "PetModels"
local PET_BASE_MAX_DIMENSION = 2.35
local DEFAULT_FRONT_REACH = 1
local MODEL_FACE_YAW = math.rad(-90)
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local AURA_EFFECTS = {
	SoftGlow = {
		FillTransparency = 0.82,
		OutlineTransparency = 0.18,
		ParticleRate = 5,
		ParticleLifetime = NumberRange.new(0.75, 1.15),
		ParticleSpeed = NumberRange.new(0.2, 0.65),
		ParticleSize = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.09),
			NumberSequenceKeypoint.new(0.5, 0.16),
			NumberSequenceKeypoint.new(1, 0),
		}),
		ParticleTransparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.75, 0.36),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightBrightness = 0.65,
		LightRange = 5,
	},
	FlameAura = {
		Texture = FIRE_TEXTURE,
		FillTransparency = 0.78,
		OutlineTransparency = 0.1,
		ParticleRate = 8,
		ParticleLifetime = NumberRange.new(0.45, 0.75),
		ParticleSpeed = NumberRange.new(0.25, 0.9),
		ParticleRise = 1.4,
		ParticleSize = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(0.55, 0.28),
			NumberSequenceKeypoint.new(1, 0.04),
		}),
		ParticleTransparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightBrightness = 0.95,
		LightRange = 6,
	},
	RadiantRings = {
		FillTransparency = 0.7,
		OutlineTransparency = 0.04,
		ParticleRate = 10,
		ParticleLifetime = NumberRange.new(0.65, 1),
		ParticleSpeed = NumberRange.new(0.15, 0.55),
		ParticleSize = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.45, 0.18),
			NumberSequenceKeypoint.new(1, 0),
		}),
		ParticleTransparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.78, 0.28),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightBrightness = 1.15,
		LightRange = 7,
		RingTransparency = 0.42,
		RingSpinSpeed = 34,
	},
	RainbowAura = {
		FillTransparency = 0.68,
		OutlineTransparency = 0.02,
		ParticleRate = 12,
		ParticleLifetime = NumberRange.new(0.65, 1.05),
		ParticleSpeed = NumberRange.new(0.2, 0.7),
		ParticleSize = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		}),
		ParticleTransparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.8, 0.24),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightBrightness = 1.25,
		LightRange = 8,
		RingTransparency = 0.36,
		RingSpinSpeed = 48,
	},
}

local petModelFolder = nil
local didWaitForPetModelFolder = false
local warnedMissingTemplateByBasePetId = {}

local function getPetModelFolder()
	if petModelFolder ~= nil and petModelFolder.Parent ~= nil then
		return petModelFolder
	end

	petModelFolder = ReplicatedStorage:FindFirstChild(PET_MODEL_FOLDER_NAME)

	if petModelFolder == nil and not didWaitForPetModelFolder then
		didWaitForPetModelFolder = true
		petModelFolder = ReplicatedStorage:WaitForChild(PET_MODEL_FOLDER_NAME, 10)
	end

	return petModelFolder
end

local function warnMissingTemplate(basePetId)
	if warnedMissingTemplateByBasePetId[basePetId] == true then
		return
	end

	warnedMissingTemplateByBasePetId[basePetId] = true
	warn("Missing pet model template in ReplicatedStorage.PetModels:", basePetId)
end

local function getBasePetId(petId)
	local pet = PetConfig.getPet(petId)

	if pet ~= nil and typeof(pet.BasePetId) == "string" then
		return pet.BasePetId
	end

	local parts = PetConfig.getPetParts(petId)

	if parts ~= nil and typeof(parts.BasePetId) == "string" then
		return parts.BasePetId
	end

	return petId
end

local function getBaseParts(model)
	local baseParts = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(baseParts, descendant)
		end
	end

	return baseParts
end

local function getLargestBasePart(baseParts)
	local largestPart = nil
	local largestVolume = 0

	for _, part in ipairs(baseParts) do
		local size = part.Size
		local volume = size.X * size.Y * size.Z

		if volume > largestVolume then
			largestPart = part
			largestVolume = volume
		end
	end

	return largestPart
end

local function configureBaseParts(baseParts)
	local originalTransparencyByPart = {}

	for _, part in ipairs(baseParts) do
		originalTransparencyByPart[part] = part.Transparency
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end

	return originalTransparencyByPart
end

local function scaleModel(model, scale)
	local _, boundsSize = model:GetBoundingBox()
	local maxDimension = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)

	if maxDimension <= 0 then
		return
	end

	model:ScaleTo((PET_BASE_MAX_DIMENSION * math.max(scale or 1, 0.05)) / maxDimension)
end

local function getModelBoundsSize(model)
	local _, boundsSize = model:GetBoundingBox()

	return boundsSize
end

local function getRainbowColor(timeNow, phase)
	return Color3.fromHSV(((timeNow or 0) * 0.18 + (phase or 0)) % 1, 0.78, 1)
end

local function createHighlight(model, color, config)
	local highlight = Instance.new("Highlight")
	highlight.Name = "PetAuraHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = color
	highlight.FillTransparency = config.FillTransparency or 0.82
	highlight.OutlineColor = color
	highlight.OutlineTransparency = config.OutlineTransparency or 0.12
	highlight.Parent = model

	return highlight
end

local function createAuraAttachment(rootPart)
	local attachment = Instance.new("Attachment")
	attachment.Name = "PetAuraAttachment"
	attachment.Parent = rootPart

	return attachment
end

local function createAuraParticles(attachment, color, config)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PetAuraParticles"
	emitter.Texture = config.Texture or SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.55
	emitter.LightInfluence = 0
	emitter.Rate = config.ParticleRate or 0
	emitter.Lifetime = config.ParticleLifetime or NumberRange.new(0.6, 1)
	emitter.Speed = config.ParticleSpeed or NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = config.ParticleSize or NumberSequence.new(0.12)
	emitter.Transparency = config.ParticleTransparency or NumberSequence.new(0.35)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-80, 80)
	emitter.Acceleration = Vector3.new(0, config.ParticleRise or 0.45, 0)
	emitter.Drag = 1.2
	emitter.VelocityInheritance = 0.45
	emitter.Parent = attachment

	return emitter
end

local function createAuraLight(rootPart, color, config)
	local light = Instance.new("PointLight")
	light.Name = "PetAuraLight"
	light.Brightness = config.LightBrightness or 0.7
	light.Color = color
	light.Range = config.LightRange or 5
	light.Shadows = false
	light.Parent = rootPart

	return light
end

local function createAuraRing(model, boundsCFrame, boundsSize, color, config)
	if config.RingTransparency == nil then
		return nil
	end

	local ring = Instance.new("Part")
	local ringDiameter = math.max(boundsSize.X, boundsSize.Z) * 1.35

	ring.Name = "PetAuraRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(ringDiameter, 0.035, ringDiameter)
	ring.Transparency = config.RingTransparency
	ring.CFrame = CFrame.new(boundsCFrame.Position - Vector3.new(0, boundsSize.Y * 0.48, 0))
	ring.Parent = model

	return ring
end

local function createAuraEffects(model, baseParts, pet, petUid)
	if model == nil or pet == nil or pet.AuraVfx == nil or pet.AuraVfx == "None" then
		return nil
	end

	local config = AURA_EFFECTS[pet.AuraVfx]
	local rootPart = getLargestBasePart(baseParts)

	if config == nil or rootPart == nil then
		return nil
	end

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local color = pet.AuraColor or pet.Color or Color3.fromRGB(255, 255, 255)
	local accentColor = pet.AuraAccentColor or color
	local attachment = createAuraAttachment(rootPart)
	local emitter = createAuraParticles(attachment, color, config)
	local light = createAuraLight(rootPart, color, config)
	local highlight = createHighlight(model, color, config)
	local ring = createAuraRing(model, boundsCFrame, boundsSize, accentColor, config)
	local phaseSeed = if typeof(petUid) == "number" then petUid else 0

	return {
		Vfx = pet.AuraVfx,
		Color = color,
		AccentColor = accentColor,
		Phase = (phaseSeed * 0.137) % 1,
		Highlight = highlight,
		BaseFillTransparency = config.FillTransparency or 0.82,
		BaseOutlineTransparency = config.OutlineTransparency or 0.12,
		Emitter = emitter,
		BaseParticleRate = config.ParticleRate or 0,
		Light = light,
		BaseLightBrightness = config.LightBrightness or 0.7,
		Ring = ring,
		BaseRingTransparency = config.RingTransparency,
		RingSpinSpeed = config.RingSpinSpeed or 0,
	}
end

local function setEffectsEnabled(effects, isEnabled)
	if effects == nil then
		return
	end

	if effects.Highlight ~= nil then
		effects.Highlight.Enabled = isEnabled
	end

	if effects.Emitter ~= nil then
		effects.Emitter.Enabled = isEnabled and effects.Emitter.Rate > 0
	end

	if effects.Light ~= nil then
		effects.Light.Enabled = isEnabled
	end

	if effects.Ring ~= nil then
		effects.Ring.Transparency = if isEnabled then effects.BaseRingTransparency or 0.42 else 1
	end
end

local function getUnit(vector, fallback)
	if typeof(vector) == "Vector3" and vector.Magnitude > 0.001 then
		return vector.Unit
	end

	if typeof(fallback) == "Vector3" and fallback.Magnitude > 0.001 then
		return fallback.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function createEmptyModel(parent, petUid, petId, basePetId)
	local model = Instance.new("Model")
	model.Name = "Pet_" .. tostring(petUid)
	model:SetAttribute("PetUid", petUid)
	model:SetAttribute("PetId", petId)
	model:SetAttribute("BasePetId", basePetId)
	model:SetAttribute("HasPetModelTemplate", false)
	model.Parent = parent

	return model
end

local function createModel(parent, petUid, petId, basePetId)
	local folder = getPetModelFolder()
	local template = if folder ~= nil then folder:FindFirstChild(basePetId) else nil

	if template == nil or not template:IsA("Model") then
		warnMissingTemplate(basePetId)
		return createEmptyModel(parent, petUid, petId, basePetId)
	end

	local model = template:Clone()

	if model == nil then
		warnMissingTemplate(basePetId)
		return createEmptyModel(parent, petUid, petId, basePetId)
	end

	model.Name = "Pet_" .. tostring(petUid)
	model:SetAttribute("PetUid", petUid)
	model:SetAttribute("PetId", petId)
	model:SetAttribute("BasePetId", basePetId)
	model:SetAttribute("HasPetModelTemplate", true)
	model.Parent = parent

	return model
end

function PetModelVisualFactory.create(parent, petUid, petId, initialCFrame)
	if parent == nil or typeof(petId) ~= "string" then
		return nil
	end

	local pet = PetConfig.getPet(petId)
	local basePetId = getBasePetId(petId)
	local model = createModel(parent, petUid, petId, basePetId)
	local baseParts = getBaseParts(model)
	local originalTransparencyByPart = configureBaseParts(baseParts)

	if #baseParts > 0 and pet ~= nil then
		scaleModel(model, pet.Scale or 1)
	end

	local boundsSize = if #baseParts > 0 then getModelBoundsSize(model) else Vector3.zero

	if initialCFrame ~= nil then
		model:PivotTo(initialCFrame)
	end

	local effects = if #baseParts > 0 then createAuraEffects(model, baseParts, pet, petUid) else nil

	return {
		Model = model,
		Parts = baseParts,
		OriginalTransparencyByPart = originalTransparencyByPart,
		Effects = effects,
		BoundsSize = boundsSize,
		FrontReach = if #baseParts > 0 then math.max(boundsSize.X, boundsSize.Z) * 0.5 else DEFAULT_FRONT_REACH,
		PetUid = petUid,
		PetId = petId,
		HasPosition = initialCFrame ~= nil,
		IsVisible = true,
	}
end

function PetModelVisualFactory.destroy(visual)
	if visual ~= nil and visual.Model ~= nil and visual.Model.Parent ~= nil then
		visual.Model:Destroy()
	end
end

function PetModelVisualFactory.getCFrame(visual)
	if visual == nil or visual.Model == nil then
		return CFrame.new()
	end

	return visual.Model:GetPivot()
end

function PetModelVisualFactory.getPosition(visual)
	return PetModelVisualFactory.getCFrame(visual).Position
end

function PetModelVisualFactory.getFrontReach(visual)
	if visual == nil or typeof(visual.FrontReach) ~= "number" then
		return DEFAULT_FRONT_REACH
	end

	return math.max(DEFAULT_FRONT_REACH * 0.35, visual.FrontReach)
end

function PetModelVisualFactory.getFacingCFrame(position, lookDirection, pitch, roll)
	local safePosition = if typeof(position) == "Vector3" then position else Vector3.zero
	local safePitch = if typeof(pitch) == "number" then pitch else 0
	local safeRoll = if typeof(roll) == "number" then roll else 0
	local safeLookDirection = getUnit(lookDirection, Vector3.new(0, 0, -1))

	return CFrame.lookAt(safePosition, safePosition + safeLookDirection) * CFrame.Angles(safePitch, MODEL_FACE_YAW, safeRoll)
end

function PetModelVisualFactory.pivotTo(visual, cframe)
	if visual ~= nil and visual.Model ~= nil then
		visual.Model:PivotTo(cframe)
	end
end

function PetModelVisualFactory.setVisible(visual, isVisible)
	if visual == nil then
		return
	end

	visual.IsVisible = isVisible == true

	for _, part in ipairs(visual.Parts or {}) do
		if isVisible then
			part.Transparency = visual.OriginalTransparencyByPart[part] or 0
		else
			part.Transparency = 1
		end
	end

	setEffectsEnabled(visual.Effects, visual.IsVisible)
end

function PetModelVisualFactory.updateEffects(visual, timeNow, options)
	if visual == nil or visual.Effects == nil or visual.IsVisible == false then
		return
	end

	local effects = visual.Effects
	local resolvedOptions = options or {}
	local isReduced = resolvedOptions.Reduced == true
	local pulse = 0.5 + math.sin((timeNow or 0) * 2.35 + effects.Phase * math.pi * 2) * 0.5
	local color = effects.Color
	local accentColor = effects.AccentColor

	if effects.Vfx == "RainbowAura" then
		color = getRainbowColor(timeNow, effects.Phase)
		accentColor = getRainbowColor((timeNow or 0) + 1.5, effects.Phase + 0.33)
	end

	if effects.Highlight ~= nil then
		effects.Highlight.FillColor = color
		effects.Highlight.OutlineColor = accentColor
		effects.Highlight.FillTransparency = math.clamp(
			(effects.BaseFillTransparency or 0.82) + (1 - pulse) * 0.08 + (if isReduced then 0.08 else 0),
			0,
			1
		)
		effects.Highlight.OutlineTransparency = math.clamp(
			(effects.BaseOutlineTransparency or 0.12) + (1 - pulse) * 0.08 + (if isReduced then 0.12 else 0),
			0,
			1
		)
	end

	if effects.Emitter ~= nil then
		local rateScale = if isReduced then 0.28 else 1
		local particleRate = math.max(0, math.floor((effects.BaseParticleRate or 0) * rateScale + 0.5))

		effects.Emitter.Color = if effects.Vfx == "RainbowAura"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, color),
				ColorSequenceKeypoint.new(0.5, accentColor),
				ColorSequenceKeypoint.new(1, getRainbowColor((timeNow or 0) + 3, effects.Phase + 0.66)),
			})
			else ColorSequence.new(color)
		effects.Emitter.Rate = particleRate
		effects.Emitter.Enabled = particleRate > 0
	end

	if effects.Light ~= nil then
		local brightnessScale = if isReduced then 0.35 else 1

		effects.Light.Color = color
		effects.Light.Brightness = (effects.BaseLightBrightness or 0.7) * brightnessScale * (0.78 + pulse * 0.34)
		effects.Light.Enabled = effects.Light.Brightness > 0
	end

	if effects.Ring ~= nil then
		effects.Ring.Color = accentColor
		effects.Ring.Transparency = math.clamp(
			(effects.BaseRingTransparency or 0.42) + (if isReduced then 0.2 else 0),
			0,
			1
		)

		if effects.RingSpinSpeed ~= 0 then
			effects.Ring.Orientation = Vector3.new(0, ((timeNow or 0) * effects.RingSpinSpeed) % 360, 0)
		end
	end
end

return PetModelVisualFactory
