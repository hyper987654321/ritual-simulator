local AbyssalHalfCrownAura = {}

local AURA_FOLDER_NAME = "AbyssalHalfCrownAura_Final"
local LOCAL_TEXTURE_ROOT = "rbxasset://textures/abyssal_half_crown/"
local FLAME_ATLAS_TEXTURE = LOCAL_TEXTURE_ROOT .. "flame_atlas.png"
local FLAME_TEXTURES = {
	LOCAL_TEXTURE_ROOT .. "flame_1.png",
	LOCAL_TEXTURE_ROOT .. "flame_2.png",
	LOCAL_TEXTURE_ROOT .. "flame_3.png",
	LOCAL_TEXTURE_ROOT .. "flame_4.png",
}
local CROWN_TEXTURE = LOCAL_TEXTURE_ROOT .. "crown.png"
local GROUND_TEXTURE = LOCAL_TEXTURE_ROOT .. "ground_ripple.png"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local COLOR_VOID = Color3.fromRGB(8, 0, 5)
local COLOR_ABYSS = Color3.fromRGB(54, 2, 22)
local COLOR_CRIMSON = Color3.fromRGB(151, 9, 55)
local COLOR_HOT = Color3.fromRGB(255, 35, 101)
local COLOR_PINK = Color3.fromRGB(255, 104, 155)
local COLOR_WHITE = Color3.fromRGB(255, 238, 244)

local QUALITY_HIDDEN = 0
local QUALITY_REDUCED = 1
local QUALITY_FULL = 2

local FLAME_GLOW_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLOR_ABYSS),
	ColorSequenceKeypoint.new(0.42, COLOR_CRIMSON),
	ColorSequenceKeypoint.new(0.78, COLOR_HOT),
	ColorSequenceKeypoint.new(1, COLOR_PINK),
})

local FLAME_CORE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLOR_ABYSS),
	ColorSequenceKeypoint.new(0.48, COLOR_HOT),
	ColorSequenceKeypoint.new(0.82, COLOR_PINK),
	ColorSequenceKeypoint.new(1, COLOR_PINK),
})

local CROWN_GLOW_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLOR_CRIMSON),
	ColorSequenceKeypoint.new(0.45, COLOR_HOT),
	ColorSequenceKeypoint.new(0.72, COLOR_WHITE),
	ColorSequenceKeypoint.new(1, COLOR_HOT),
})

local CROWN_CORE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLOR_PINK),
	ColorSequenceKeypoint.new(0.42, COLOR_WHITE),
	ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, COLOR_PINK),
})

local GROUND_GLOW_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLOR_ABYSS),
	ColorSequenceKeypoint.new(0.45, COLOR_CRIMSON),
	ColorSequenceKeypoint.new(0.75, COLOR_HOT),
	ColorSequenceKeypoint.new(1, COLOR_ABYSS),
})

local GROUND_CORE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLOR_CRIMSON),
	ColorSequenceKeypoint.new(0.5, COLOR_PINK),
	ColorSequenceKeypoint.new(1, COLOR_CRIMSON),
})

local FLAME_GLOW_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.78),
	NumberSequenceKeypoint.new(0.18, 0.56),
	NumberSequenceKeypoint.new(0.68, 0.7),
	NumberSequenceKeypoint.new(1, 1),
})

local FLAME_CORE_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.62),
	NumberSequenceKeypoint.new(0.22, 0.3),
	NumberSequenceKeypoint.new(0.67, 0.5),
	NumberSequenceKeypoint.new(1, 1),
})

local LINE_GLOW_TRANSPARENCY = NumberSequence.new(0.5)
local LINE_CORE_TRANSPARENCY = NumberSequence.new(0.05)

local FLAME_SPECS = {
	{ X = -2.12, Z = 0.72, BaseY = -2.78, Height = 5.65, Lean = -0.5, Scale = 0.28, Phase = 0.2, Major = true },
	{ X = -1.2, Z = 0.94, BaseY = -2.9, Height = 7.18, Lean = -0.34, Scale = 0.34, Phase = 1.1, Major = true },
	{ X = -0.35, Z = 1.02, BaseY = -2.95, Height = 7.78, Lean = -0.14, Scale = 0.38, Phase = 2.5, Major = true },
	{ X = 0.6, Z = 1, BaseY = -2.94, Height = 7.45, Lean = 0.22, Scale = 0.36, Phase = 4.1, Major = true },
	{ X = 1.47, Z = 0.9, BaseY = -2.87, Height = 6.72, Lean = 0.4, Scale = 0.32, Phase = 5.3, Major = true },
	{ X = 2.18, Z = 0.68, BaseY = -2.76, Height = 5.5, Lean = 0.54, Scale = 0.27, Phase = 0.8, Major = true },
	{ X = -1.82, Z = -0.82, BaseY = -2.7, Height = 4.82, Lean = -0.27, Scale = 0.2, Phase = 3.2, Major = false },
	{ X = 1.76, Z = -0.84, BaseY = -2.69, Height = 4.75, Lean = 0.3, Scale = 0.2, Phase = 4.8, Major = false },
}

local SHARD_SPECS = {
	{ Angle = -104, Height = 0.42, Width = 0.26, Lift = 0.2, Phase = 0.2 },
	{ Angle = -70, Height = 0.56, Width = 0.3, Lift = 0.29, Phase = 1.3 },
	{ Angle = -36, Height = 0.72, Width = 0.34, Lift = 0.38, Phase = 2.5 },
	{ Angle = 0, Height = 0.96, Width = 0.42, Lift = 0.48, Phase = 3.1, Major = true },
	{ Angle = 36, Height = 0.72, Width = 0.34, Lift = 0.38, Phase = 4.2 },
	{ Angle = 70, Height = 0.56, Width = 0.3, Lift = 0.29, Phase = 5.4 },
	{ Angle = 104, Height = 0.42, Width = 0.26, Lift = 0.2, Phase = 0.9 },
	{ Angle = 0, Height = 2.08, Width = 0.66, Phase = 1.8, Major = true, Apex = true },
}

local TEXTURE_FLAME_SPECS = {
	{ X = -1.72, Z = 0.92, Height = 6.75, Width = 2.55, Phase = 0.1, Frame = 0, Major = true, Transparency = 0.16 },
	{ X = -0.62, Z = 1.08, Height = 7.75, Width = 2.65, Phase = 1.2, Frame = 1, Major = true, Transparency = 0.1, Hot = true },
	{ X = 0.55, Z = 1.05, Height = 7.55, Width = 2.6, Phase = 2.4, Frame = 2, Major = true, Transparency = 0.11, Hot = true },
	{ X = 1.68, Z = 0.9, Height = 6.65, Width = 2.5, Phase = 3.5, Frame = 3, Major = true, Transparency = 0.16 },
	{ X = -2.25, Z = 0.35, Height = 5.65, Width = 2.1, Phase = 4.6, Frame = 1, Major = true, Transparency = 0.25 },
	{ X = 2.22, Z = 0.32, Height = 5.55, Width = 2.08, Phase = 5.7, Frame = 0, Major = true, Transparency = 0.25 },
	{ X = -1.48, Z = -0.72, Height = 4.25, Width = 1.48, Phase = 0.8, Frame = 2, Major = true, Transparency = 0.32 },
	{ X = 1.42, Z = -0.74, Height = 4.15, Width = 1.45, Phase = 2.1, Frame = 3, Major = true, Transparency = 0.32 },
	{ X = -0.68, Z = -0.88, Height = 3.6, Width = 1.18, Phase = 3.4, Frame = 0, Major = false, Transparency = 0.38 },
	{ X = 0.62, Z = -0.9, Height = 3.7, Width = 1.2, Phase = 4.8, Frame = 1, Major = false, Transparency = 0.38 },
	{ X = -2.52, Z = 0.65, Height = 4.4, Width = 1.7, Phase = 5.4, Frame = 3, Major = false, Transparency = 0.45, Haze = true },
	{ X = 2.5, Z = 0.62, Height = 4.35, Width = 1.68, Phase = 1.7, Frame = 2, Major = false, Transparency = 0.45, Haze = true },
}

local SLASH_SPECS = {
	{ X = -1.9, Z = -1.12, BaseY = -1.8, Rise = 5.4, Length = 1.25, Tilt = 58, Phase = 0.02 },
	{ X = 1.65, Z = -1.15, BaseY = -1.1, Rise = 4.8, Length = 1.08, Tilt = 67, Phase = 0.18 },
	{ X = -0.75, Z = -1.3, BaseY = -2.2, Rise = 5.9, Length = 0.86, Tilt = 48, Phase = 0.34 },
	{ X = 2.15, Z = 0.15, BaseY = -2.35, Rise = 4.75, Length = 1.34, Tilt = 72, Phase = 0.5 },
	{ X = -2.25, Z = 0.22, BaseY = -2.25, Rise = 4.6, Length = 1.18, Tilt = 64, Phase = 0.66 },
	{ X = 0.72, Z = -1.24, BaseY = -1.7, Rise = 5.25, Length = 0.98, Tilt = 54, Phase = 0.82 },
}

local function numberSequence(points)
	local keypoints = {}

	for _, point in ipairs(points) do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2], point[3] or 0))
	end

	return NumberSequence.new(keypoints)
end

local function colorSequence(points)
	local keypoints = {}

	for _, point in ipairs(points) do
		table.insert(keypoints, ColorSequenceKeypoint.new(point[1], point[2]))
	end

	return ColorSequence.new(keypoints)
end

local function createAttachment(parent, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = parent

	return attachment
end

local function createBeam(parent, name, attachment0, attachment1, options)
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Brightness = options.Brightness or 1
	beam.Color = options.Color
	beam.CurveSize0 = options.CurveSize0 or 0
	beam.CurveSize1 = options.CurveSize1 or 0
	beam.FaceCamera = options.FaceCamera ~= false
	beam.LightEmission = options.LightEmission or 1
	beam.LightInfluence = options.LightInfluence or 0
	beam.Segments = options.Segments or 3
	beam.TextureSpeed = 0
	beam.Transparency = options.Transparency
	beam.Width0 = options.Width0
	beam.Width1 = options.Width1
	beam.ZOffset = options.ZOffset or 0
	beam.Parent = parent

	return beam
end

local function createLayeredLine(parent, name, attachment0, attachment1, options)
	local glow = createBeam(parent, name .. "_Glow", attachment0, attachment1, {
		Brightness = options.GlowBrightness or 1.4,
		Color = options.GlowColor,
		CurveSize0 = options.CurveSize0,
		CurveSize1 = options.CurveSize1,
		FaceCamera = options.FaceCamera,
		LightEmission = 1,
		Segments = options.Segments,
		Transparency = options.GlowTransparency or LINE_GLOW_TRANSPARENCY,
		Width0 = options.Width0 * (options.GlowScale or 3),
		Width1 = options.Width1 * (options.GlowScale or 3),
		ZOffset = options.ZOffset or 0,
	})
	local core = createBeam(parent, name .. "_Core", attachment0, attachment1, {
		Brightness = options.CoreBrightness or 3,
		Color = options.CoreColor,
		CurveSize0 = options.CurveSize0,
		CurveSize1 = options.CurveSize1,
		FaceCamera = options.FaceCamera,
		LightEmission = 1,
		Segments = options.Segments,
		Transparency = options.CoreTransparency or LINE_CORE_TRANSPARENCY,
		Width0 = options.Width0,
		Width1 = options.Width1,
		ZOffset = (options.ZOffset or 0) + 0.01,
	})

	return {
		Core = core,
		Glow = glow,
		GlowScale = options.GlowScale or 3,
		MinimumQuality = options.MinimumQuality or QUALITY_REDUCED,
	}
end

local function setLayeredLineWidths(line, width0, width1, qualityLevel, visible)
	local enabled = visible and qualityLevel >= line.MinimumQuality

	line.Glow.Enabled = enabled
	line.Core.Enabled = enabled

	if not enabled then
		return
	end

	line.Glow.Width0 = width0 * line.GlowScale
	line.Glow.Width1 = width1 * line.GlowScale
	line.Core.Width0 = width0
	line.Core.Width1 = width1
end

local function createVolumePart(folder, rootPart, name, localCFrame, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = rootPart.CFrame * localCFrame
	part.Massless = true
	part.Size = size
	part.Transparency = 1
	part.Parent = folder

	local weld = Instance.new("WeldConstraint")
	weld.Name = "AuraWeld"
	weld.Part0 = rootPart
	weld.Part1 = part
	weld.Parent = part

	return part
end

local function createEmitter(parent, name, texture, options)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Acceleration = options.Acceleration or Vector3.zero
	emitter.Brightness = options.Brightness or 1
	emitter.Color = options.Color
	emitter.Drag = options.Drag or 0
	emitter.EmissionDirection = options.EmissionDirection or Enum.NormalId.Top
	emitter.Enabled = true
	emitter.FlipbookBlendFrames = options.FlipbookBlendFrames == true
	emitter.Lifetime = options.Lifetime
	emitter.LightEmission = options.LightEmission or 0
	emitter.LightInfluence = options.LightInfluence or 0
	emitter.LockedToPart = options.LockedToPart == true
	emitter.Orientation = options.Orientation or Enum.ParticleOrientation.FacingCamera
	emitter.Rate = options.Rate
	emitter.Rotation = options.Rotation or NumberRange.new(0)
	emitter.RotSpeed = options.RotSpeed or NumberRange.new(0)
	emitter.Size = options.Size
	emitter.Speed = options.Speed
	emitter.SpreadAngle = options.SpreadAngle or Vector2.zero
	emitter.Squash = options.Squash or NumberSequence.new(0)
	emitter.Texture = texture
	emitter.TimeScale = options.TimeScale or 1
	emitter.Transparency = options.Transparency
	emitter.VelocityInheritance = options.VelocityInheritance or 0
	emitter.WindAffectsDrag = options.WindAffectsDrag == true
	emitter.ZOffset = options.ZOffset or 0

	if options.FlipbookLayout ~= nil then
		emitter.FlipbookLayout = options.FlipbookLayout
		emitter.FlipbookFramerate = options.FlipbookFramerate or NumberRange.new(8)
		emitter.FlipbookMode = options.FlipbookMode or Enum.ParticleFlipbookMode.Loop
		emitter.FlipbookStartRandom = options.FlipbookStartRandom ~= false
	end

	if parent:IsA("BasePart") then
		emitter.Shape = options.Shape or Enum.ParticleEmitterShape.Box
		emitter.ShapeInOut = options.ShapeInOut or Enum.ParticleEmitterShapeInOut.Outward
		emitter.ShapePartial = options.ShapePartial or 1
		emitter.ShapeStyle = options.ShapeStyle or Enum.ParticleEmitterShapeStyle.Volume
	end

	emitter.Parent = parent

	return {
		BaseRate = options.Rate,
		Emitter = emitter,
		MinimumQuality = options.MinimumQuality or QUALITY_REDUCED,
	}
end

local function createTextureFlames(aura)
	for index, spec in ipairs(TEXTURE_FLAME_SPECS) do
		local minimumQuality = if spec.Major then QUALITY_REDUCED else QUALITY_FULL
		local centerY = aura.GroundY + spec.Height * aura.Scale * 0.5
		local attachment = createAttachment(
			aura.AnchorPart,
			"TexturedFlameAnchor_" .. index,
			Vector3.new(spec.X * aura.Scale, centerY, spec.Z * aura.Scale)
		)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TexturedAbyssalFlame_" .. index
		billboard.Adornee = attachment
		billboard.AlwaysOnTop = false
		billboard.Enabled = true
		billboard.LightInfluence = if spec.Haze then 0.28 else 0
		billboard.MaxDistance = 150
		billboard.Size = UDim2.fromScale(spec.Width * aura.Scale, spec.Height * aura.Scale)
		billboard.Parent = attachment

		local image = Instance.new("ImageLabel")
		image.Name = "Flame"
		image.BackgroundTransparency = 1
		image.ImageColor3 = if spec.Haze
			then Color3.fromRGB(78, 18, 39)
			elseif spec.Hot then Color3.fromRGB(255, 218, 231)
			else Color3.fromRGB(185, 88, 119)
		image.ImageTransparency = spec.Transparency
		image.ScaleType = Enum.ScaleType.Stretch
		image.Size = UDim2.fromScale(1, 1)
		image.Image = FLAME_TEXTURES[spec.Frame + 1]
		image.Parent = billboard

		table.insert(aura.TextureFlames, {
			Attachment = attachment,
			Billboard = billboard,
			Image = image,
			MinimumQuality = minimumQuality,
			Spec = spec,
		})
	end
end

local function createCrownSprite(aura)
	local attachment = createAttachment(
		aura.AnchorPart,
		"TexturedCrownAnchor",
		Vector3.new(0, 4.46 * aura.Scale, -0.16 * aura.Scale)
	)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TexturedAbyssalCrown"
	billboard.Adornee = attachment
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150
	billboard.Size = UDim2.fromScale(3.55 * aura.Scale, 3.55 * aura.Scale)
	billboard.Parent = attachment

	local image = Instance.new("ImageLabel")
	image.Name = "Crown"
	image.BackgroundTransparency = 1
	image.ImageColor3 = Color3.fromRGB(235, 185, 202)
	image.ImageTransparency = 0.08
	image.ScaleType = Enum.ScaleType.Stretch
	image.Size = UDim2.fromScale(1, 1)
	image.Image = CROWN_TEXTURE
	image.Parent = billboard
	aura.CrownSprite = {
		Attachment = attachment,
		Billboard = billboard,
		Image = image,
	}
end

local function createGroundSprite(aura)
	local baseSize = 6.35 * aura.Scale
	local part = createVolumePart(
		aura.Folder,
		aura.RootPart,
		"TexturedGroundRipple",
		CFrame.new(0, aura.GroundY + 0.09, 0),
		Vector3.new(baseSize, 0.035, baseSize)
	)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "GroundRippleSurface"
	surface.Adornee = part
	surface.AlwaysOnTop = false
	surface.CanvasSize = Vector2.new(512, 512)
	surface.Face = Enum.NormalId.Top
	surface.LightInfluence = 0
	surface.Parent = part

	local image = Instance.new("ImageLabel")
	image.Name = "Ripple"
	image.BackgroundTransparency = 1
	image.ImageColor3 = Color3.fromRGB(205, 95, 129)
	image.ImageTransparency = 0.2
	image.ScaleType = Enum.ScaleType.Stretch
	image.Size = UDim2.fromScale(1, 1)
	image.Image = GROUND_TEXTURE
	image.Parent = surface
	aura.GroundSprite = {
		BaseSize = baseSize,
		Image = image,
		Part = part,
		Surface = surface,
	}
end

local function getCharacterScale(character)
	local ok, scale = pcall(function()
		return character:GetScale()
	end)

	if ok and typeof(scale) == "number" then
		return math.clamp(scale, 0.65, 2.5)
	end

	return 1
end

local function getGroundOffset(character, rootPart)
	local lowestY = -3

	for _, descendant in ipairs(character:GetDescendants()) do
		if
			descendant:IsA("BasePart")
			and descendant ~= rootPart
			and descendant:FindFirstAncestorOfClass("Accessory") == nil
		then
			local localPosition = rootPart.CFrame:PointToObjectSpace(descendant.Position)
			lowestY = math.min(lowestY, localPosition.Y - descendant.Size.Y * 0.5)
		end
	end

	return lowestY + 0.08
end

local function createFlameColumns(aura)
	for index, spec in ipairs(FLAME_SPECS) do
		local scale = aura.Scale
		local basePosition = Vector3.new(spec.X, spec.BaseY, spec.Z) * scale
		local middlePosition = basePosition + Vector3.new(spec.Lean * 0.34, spec.Height * 0.48, 0) * scale
		local tipPosition = basePosition + Vector3.new(spec.Lean, spec.Height, 0) * scale
		local base = createAttachment(aura.AnchorPart, "FlameBase_" .. index, basePosition)
		local middle = createAttachment(aura.AnchorPart, "FlameMiddle_" .. index, middlePosition)
		local tip = createAttachment(aura.AnchorPart, "FlameTip_" .. index, tipPosition)
		local minimumQuality = if spec.Major then QUALITY_REDUCED else QUALITY_FULL
		local lowerWidth = 0.13 * spec.Scale * scale
		local upperWidth = 0.105 * spec.Scale * scale
		local lower = createLayeredLine(aura.Folder, "FlameLower_" .. index, base, middle, {
			CoreBrightness = 2.6,
			CoreColor = FLAME_CORE_COLOR,
			CoreTransparency = FLAME_CORE_TRANSPARENCY,
			GlowBrightness = 1.25,
			GlowColor = FLAME_GLOW_COLOR,
			GlowScale = 2.2,
			GlowTransparency = FLAME_GLOW_TRANSPARENCY,
			MinimumQuality = minimumQuality,
			Segments = 4,
			Width0 = lowerWidth,
			Width1 = upperWidth,
		})
		local upper = createLayeredLine(aura.Folder, "FlameUpper_" .. index, middle, tip, {
			CoreBrightness = 3,
			CoreColor = FLAME_CORE_COLOR,
			CoreTransparency = FLAME_CORE_TRANSPARENCY,
			GlowBrightness = 1.35,
			GlowColor = FLAME_GLOW_COLOR,
			GlowScale = 2.35,
			GlowTransparency = FLAME_GLOW_TRANSPARENCY,
			MinimumQuality = minimumQuality,
			Segments = 4,
			Width0 = upperWidth,
			Width1 = 0.006 * scale,
		})

		table.insert(aura.Flames, {
			Base = base,
			Lower = lower,
			Middle = middle,
			Spec = spec,
			Tip = tip,
			Upper = upper,
		})
	end
end

local function createCrownArc(aura)
	local pointCount = 12
	local radius = 1.1 * aura.Scale

	for index = 0, pointCount - 1 do
		local alpha = index / (pointCount - 1)
		local angle = math.rad(-128 + 256 * alpha)
		local position = Vector3.new(
			math.sin(angle) * radius,
			(3.52 + 0.06 * math.cos(angle * 2)) * aura.Scale,
			-math.cos(angle) * radius
		)
		local attachment = createAttachment(aura.AnchorPart, "CrownArcPoint_" .. index, position)

		table.insert(aura.CrownNodes, {
			Attachment = attachment,
			BasePosition = position,
			Phase = alpha * math.pi * 2,
		})
	end

	for index = 1, #aura.CrownNodes - 1 do
		if index % 5 ~= 0 then
			local left = aura.CrownNodes[index].Attachment
			local right = aura.CrownNodes[index + 1].Attachment
			local line = createLayeredLine(aura.Folder, "CrownArc_" .. index, left, right, {
				CoreBrightness = 2.8,
				CoreColor = CROWN_CORE_COLOR,
				GlowBrightness = 0.85,
				GlowColor = CROWN_GLOW_COLOR,
				GlowScale = 2.8,
				MinimumQuality = QUALITY_REDUCED,
				Segments = 2,
				Width0 = 0.027 * aura.Scale,
				Width1 = 0.027 * aura.Scale,
			})

			table.insert(aura.CrownLines, {
				Line = line,
				Phase = index * 0.63,
				Width = 0.027 * aura.Scale,
			})
		end
	end
end

local function createCrownShards(aura)
	local radius = 0.94 * aura.Scale

	for index, spec in ipairs(SHARD_SPECS) do
		local angle = math.rad(spec.Angle)
		local tangent = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local center = if spec.Apex
			then Vector3.new(0, 5.18 * aura.Scale, 0.24 * aura.Scale)
			else Vector3.new(
				math.sin(angle) * radius,
				(3.5 + spec.Lift) * aura.Scale,
				-math.cos(angle) * radius
			)
		local halfWidth = spec.Width * 0.5 * aura.Scale
		local bottomPosition = center - Vector3.new(0, spec.Height * 0.44 * aura.Scale, 0)
		local topPosition = center + Vector3.new(0, spec.Height * 0.62 * aura.Scale, 0)
		local leftPosition = center - tangent * halfWidth
		local rightPosition = center + tangent * halfWidth
		local bottom = createAttachment(aura.AnchorPart, "CrownShardBottom_" .. index, bottomPosition)
		local left = createAttachment(aura.AnchorPart, "CrownShardLeft_" .. index, leftPosition)
		local top = createAttachment(aura.AnchorPart, "CrownShardTop_" .. index, topPosition)
		local right = createAttachment(aura.AnchorPart, "CrownShardRight_" .. index, rightPosition)
		local nodes = {
			{ Attachment = bottom, BasePosition = bottomPosition, Phase = spec.Phase },
			{ Attachment = left, BasePosition = leftPosition, Phase = spec.Phase },
			{ Attachment = top, BasePosition = topPosition, Phase = spec.Phase },
			{ Attachment = right, BasePosition = rightPosition, Phase = spec.Phase },
		}

		for _, node in ipairs(nodes) do
			table.insert(aura.CrownNodes, node)
		end

		local pairs = {
			{ bottom, left },
			{ left, top },
			{ top, right },
			{ right, bottom },
			{ bottom, top },
		}

		for edgeIndex, pair in ipairs(pairs) do
			local line = createLayeredLine(
				aura.Folder,
				"CrownShard_" .. index .. "_" .. edgeIndex,
				pair[1],
				pair[2],
				{
					CoreBrightness = if spec.Apex then 4.5 elseif spec.Major then 3.4 else 2.5,
					CoreColor = CROWN_CORE_COLOR,
					GlowBrightness = if spec.Apex then 1.45 elseif spec.Major then 1.05 else 0.7,
					GlowColor = CROWN_GLOW_COLOR,
					GlowScale = if spec.Apex then 3.8 elseif spec.Major then 3.1 else 2.6,
					MinimumQuality = if spec.Major or edgeIndex < 5 then QUALITY_REDUCED else QUALITY_FULL,
					Segments = 2,
					Width0 = (if edgeIndex == 5 then 0.022 else 0.028) * aura.Scale,
					Width1 = (if edgeIndex == 5 then 0.016 else 0.028) * aura.Scale,
				}
			)

			table.insert(aura.CrownLines, {
				Line = line,
				Phase = spec.Phase + edgeIndex * 0.31,
				Width = (if edgeIndex == 5 then 0.022 else 0.028) * aura.Scale,
			})
		end
	end
end

local function createGroundRing(aura, ringIndex, segmentCount, phaseOffset, persistent)
	local ring = {
		Lines = {},
		Nodes = {},
		Persistent = persistent,
		PhaseOffset = phaseOffset,
	}

	for index = 1, segmentCount do
		local attachment = createAttachment(
			aura.AnchorPart,
			"GroundRing_" .. ringIndex .. "_Point_" .. index,
			Vector3.new(0, aura.GroundY, 0)
		)

		table.insert(ring.Nodes, attachment)
	end

	for index = 1, segmentCount do
		if (index + ringIndex * 2) % 6 ~= 0 then
			local nextIndex = if index == segmentCount then 1 else index + 1
			local line = createLayeredLine(
				aura.Folder,
				"GroundRing_" .. ringIndex .. "_Segment_" .. index,
				ring.Nodes[index],
				ring.Nodes[nextIndex],
				{
					CoreBrightness = 1.65,
					CoreColor = GROUND_CORE_COLOR,
					GlowBrightness = 0.55,
					GlowColor = GROUND_GLOW_COLOR,
					GlowScale = 2.7,
					MinimumQuality = if persistent then QUALITY_REDUCED else QUALITY_FULL,
					Segments = 2,
					Width0 = 0.026 * aura.Scale,
					Width1 = 0.026 * aura.Scale,
				}
			)

			table.insert(ring.Lines, line)
		end
	end

	table.insert(aura.GroundRings, ring)
end

local function createGroundCracks(aura)
	for index = 1, 9 do
		local angle = math.rad(index * 137.5)
		local innerRadius = (0.72 + (index % 3) * 0.12) * aura.Scale
		local outerRadius = (1.45 + (index % 4) * 0.28) * aura.Scale
		local innerPosition = Vector3.new(
			math.cos(angle) * innerRadius,
			aura.GroundY + 0.025,
			math.sin(angle) * innerRadius
		)
		local outerPosition = Vector3.new(
			math.cos(angle + 0.08 * ((index % 2) * 2 - 1)) * outerRadius,
			aura.GroundY + 0.025,
			math.sin(angle + 0.08 * ((index % 2) * 2 - 1)) * outerRadius
		)
		local inner = createAttachment(aura.AnchorPart, "GroundCrackInner_" .. index, innerPosition)
		local outer = createAttachment(aura.AnchorPart, "GroundCrackOuter_" .. index, outerPosition)
		local line = createLayeredLine(aura.Folder, "GroundCrack_" .. index, inner, outer, {
			CoreBrightness = 1.8,
			CoreColor = GROUND_CORE_COLOR,
			GlowBrightness = 0.55,
			GlowColor = GROUND_GLOW_COLOR,
			GlowScale = 2.6,
			MinimumQuality = if index % 3 == 0 then QUALITY_FULL else QUALITY_REDUCED,
			Segments = 2,
			Width0 = 0.027 * aura.Scale,
			Width1 = 0.008 * aura.Scale,
		})

		table.insert(aura.GroundCracks, {
			Line = line,
			Phase = index * 0.78,
			Width = 0.027 * aura.Scale,
		})
	end
end

local function createHotSlashes(aura)
	for index, spec in ipairs(SLASH_SPECS) do
		local attachment0 = createAttachment(aura.AnchorPart, "HotSlashStart_" .. index, Vector3.zero)
		local attachment1 = createAttachment(aura.AnchorPart, "HotSlashEnd_" .. index, Vector3.zero)
		local line = createLayeredLine(aura.Folder, "HotSlash_" .. index, attachment0, attachment1, {
			CoreBrightness = 5,
			CoreColor = CROWN_CORE_COLOR,
			GlowBrightness = 1.8,
			GlowColor = CROWN_GLOW_COLOR,
			GlowScale = 3.4,
			MinimumQuality = if index % 2 == 0 then QUALITY_FULL else QUALITY_REDUCED,
			Segments = 3,
			Width0 = 0.055 * aura.Scale,
			Width1 = 0.012 * aura.Scale,
		})

		table.insert(aura.Slashes, {
			Attachment0 = attachment0,
			Attachment1 = attachment1,
			Line = line,
			Spec = spec,
		})
	end
end

local function createParticles(aura)
	local scale = aura.Scale
	local rearVolume = createVolumePart(
		aura.Folder,
		aura.RootPart,
		"AbyssalRearFlameVolume",
		CFrame.new(0, -0.18 * scale, 0.82 * scale),
		Vector3.new(5.25, 5.7, 1.15) * scale
	)
	local shellVolume = createVolumePart(
		aura.Folder,
		aura.RootPart,
		"AbyssalOuterShellVolume",
		CFrame.new(0, -0.2 * scale, 0.08 * scale),
		Vector3.new(5.45, 5.95, 3.15) * scale
	)
	local frontVolume = createVolumePart(
		aura.Folder,
		aura.RootPart,
		"AbyssalFrontEdgeVolume",
		CFrame.new(0, -0.58 * scale, -0.88 * scale),
		Vector3.new(4.4, 4.65, 0.5) * scale
	)
	local bodyVolume = createVolumePart(
		aura.Folder,
		aura.RootPart,
		"AbyssalInnerWispVolume",
		CFrame.new(0, -0.28 * scale, 0),
		Vector3.new(3.8, 5.1, 2.1) * scale
	)
	local groundVolume = createVolumePart(
		aura.Folder,
		aura.RootPart,
		"AbyssalGroundParticleVolume",
		CFrame.new(0, aura.GroundY + 0.14 * scale, 0),
		Vector3.new(5.9, 0.08, 5.9) * scale
	)
	local crownAttachment = createAttachment(
		aura.AnchorPart,
		"CrownParticleAnchor",
		Vector3.new(0, 3.9 * scale, -0.15 * scale)
	)

	table.insert(aura.Emitters, createEmitter(rearVolume, "RearAnimatedFlameField", FLAME_ATLAS_TEXTURE, {
		Acceleration = Vector3.new(0, 1.7, 0) * scale,
		Brightness = 1.65,
		Color = colorSequence({
			{ 0, Color3.fromRGB(160, 32, 73) },
			{ 0.34, COLOR_HOT },
			{ 0.68, Color3.fromRGB(255, 188, 210) },
			{ 1, COLOR_ABYSS },
		}),
		Drag = 0.42,
		EmissionDirection = Enum.NormalId.Top,
		FlipbookBlendFrames = true,
		FlipbookFramerate = NumberRange.new(7, 11),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		Lifetime = NumberRange.new(1.2, 1.9),
		LightEmission = 0.68,
		LockedToPart = true,
		MinimumQuality = QUALITY_REDUCED,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Rate = 34,
		Rotation = NumberRange.new(-16, 16),
		RotSpeed = NumberRange.new(-7, 7),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = numberSequence({
			{ 0, 0.42 * scale, 0.15 * scale },
			{ 0.2, 1.12 * scale, 0.3 * scale },
			{ 0.68, 2.15 * scale, 0.5 * scale },
			{ 1, 0.18 * scale },
		}),
		Speed = NumberRange.new(0.8 * scale, 1.65 * scale),
		SpreadAngle = Vector2.new(20, 10),
		Squash = numberSequence({
			{ 0, 0.38 },
			{ 0.46, 1.1, 0.22 },
			{ 1, 1.7 },
		}),
		Transparency = numberSequence({
			{ 0, 1 },
			{ 0.1, 0.22 },
			{ 0.7, 0.43 },
			{ 1, 1 },
		}),
		VelocityInheritance = 0.9,
		ZOffset = -0.45,
	}))

	table.insert(aura.Emitters, createEmitter(shellVolume, "OuterBrokenFlameShell", FLAME_ATLAS_TEXTURE, {
		Acceleration = Vector3.new(0, 0.85, 0) * scale,
		Brightness = 0.9,
		Color = colorSequence({
			{ 0, Color3.fromRGB(74, 6, 29) },
			{ 0.42, COLOR_CRIMSON },
			{ 0.8, COLOR_HOT },
			{ 1, COLOR_ABYSS },
		}),
		Drag = 1.05,
		FlipbookBlendFrames = true,
		FlipbookFramerate = NumberRange.new(5, 8),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		Lifetime = NumberRange.new(1.55, 2.6),
		LightEmission = 0.36,
		LockedToPart = true,
		MinimumQuality = QUALITY_REDUCED,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Rate = 18,
		Rotation = NumberRange.new(-40, 40),
		RotSpeed = NumberRange.new(-15, 15),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = numberSequence({
			{ 0, 0.3 * scale, 0.12 * scale },
			{ 0.3, 1.15 * scale, 0.28 * scale },
			{ 0.78, 2.25 * scale, 0.55 * scale },
			{ 1, 0.12 * scale },
		}),
		Speed = NumberRange.new(0.08 * scale, 0.52 * scale),
		SpreadAngle = Vector2.new(50, 50),
		Squash = numberSequence({
			{ 0, 0.25 },
			{ 0.55, 1.25, 0.3 },
			{ 1, 1.8 },
		}),
		Transparency = numberSequence({
			{ 0, 1 },
			{ 0.14, 0.45 },
			{ 0.72, 0.66 },
			{ 1, 1 },
		}),
		VelocityInheritance = 0.92,
		ZOffset = -0.72,
	}))

	table.insert(aura.Emitters, createEmitter(frontVolume, "FrontHotFlameEdges", FLAME_ATLAS_TEXTURE, {
		Acceleration = Vector3.new(0, 1.4, 0) * scale,
		Brightness = 2.25,
		Color = colorSequence({
			{ 0, COLOR_HOT },
			{ 0.5, Color3.fromRGB(255, 218, 229) },
			{ 0.78, COLOR_PINK },
			{ 1, COLOR_CRIMSON },
		}),
		Drag = 0.65,
		FlipbookBlendFrames = true,
		FlipbookFramerate = NumberRange.new(9, 14),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		Lifetime = NumberRange.new(0.85, 1.35),
		LightEmission = 0.95,
		LockedToPart = true,
		MinimumQuality = QUALITY_REDUCED,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Rate = 16,
		Rotation = NumberRange.new(-12, 12),
		RotSpeed = NumberRange.new(-5, 5),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = numberSequence({
			{ 0, 0.24 * scale, 0.1 * scale },
			{ 0.28, 0.78 * scale, 0.18 * scale },
			{ 0.76, 1.42 * scale, 0.3 * scale },
			{ 1, 0.08 * scale },
		}),
		Speed = NumberRange.new(0.65 * scale, 1.4 * scale),
		SpreadAngle = Vector2.new(16, 8),
		Squash = numberSequence({
			{ 0, 0.62 },
			{ 0.55, 1.4, 0.25 },
			{ 1, 1.9 },
		}),
		Transparency = numberSequence({
			{ 0, 1 },
			{ 0.1, 0.08 },
			{ 0.72, 0.36 },
			{ 1, 1 },
		}),
		VelocityInheritance = 0.96,
		ZOffset = 0.15,
	}))

	table.insert(aura.Emitters, createEmitter(bodyVolume, "InnerZeroGravityWisps", FLAME_ATLAS_TEXTURE, {
		Acceleration = Vector3.new(0, 0.45, 0) * scale,
		Brightness = 1.75,
		Color = colorSequence({
			{ 0, COLOR_ABYSS },
			{ 0.3, COLOR_HOT },
			{ 0.58, COLOR_WHITE },
			{ 1, COLOR_CRIMSON },
		}),
		Drag = 1.6,
		FlipbookBlendFrames = true,
		FlipbookFramerate = NumberRange.new(4, 7),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		Lifetime = NumberRange.new(1.3, 2.45),
		LightEmission = 0.82,
		LockedToPart = true,
		MinimumQuality = QUALITY_REDUCED,
		Rate = 14,
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-34, 34),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = numberSequence({
			{ 0, 0.08 * scale },
			{ 0.22, 0.42 * scale, 0.14 * scale },
			{ 0.72, 0.78 * scale, 0.22 * scale },
			{ 1, 0.04 * scale },
		}),
		Speed = NumberRange.new(0.08 * scale, 0.58 * scale),
		SpreadAngle = Vector2.new(180, 180),
		Squash = numberSequence({
			{ 0, -0.18 },
			{ 0.5, 0.5, 0.25 },
			{ 1, 1.1 },
		}),
		Transparency = numberSequence({
			{ 0, 1 },
			{ 0.14, 0.18 },
			{ 0.7, 0.46 },
			{ 1, 1 },
		}),
		VelocityInheritance = 0.98,
		ZOffset = 0.32,
	}))

	table.insert(aura.Emitters, createEmitter(shellVolume, "ShadowHazeShell", SMOKE_TEXTURE, {
		Acceleration = Vector3.new(0, 0.48, 0) * scale,
		Brightness = 0.24,
		Color = colorSequence({
			{ 0, COLOR_VOID },
			{ 0.42, Color3.fromRGB(58, 2, 23) },
			{ 0.76, COLOR_ABYSS },
			{ 1, COLOR_VOID },
		}),
		Drag = 2.2,
		Lifetime = NumberRange.new(1.7, 3.2),
		LightEmission = 0.03,
		LightInfluence = 0.46,
		LockedToPart = true,
		MinimumQuality = QUALITY_REDUCED,
		Rate = 19,
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-15, 15),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = numberSequence({
			{ 0, 0.8 * scale, 0.3 * scale },
			{ 0.44, 2.65 * scale, 0.65 * scale },
			{ 1, 4.2 * scale, 0.8 * scale },
		}),
		Speed = NumberRange.new(0.04 * scale, 0.28 * scale),
		SpreadAngle = Vector2.new(180, 180),
		Transparency = numberSequence({
			{ 0, 1 },
			{ 0.16, 0.58 },
			{ 0.68, 0.74 },
			{ 1, 1 },
		}),
		VelocityInheritance = 0.95,
		ZOffset = -0.9,
	}))

	table.insert(aura.Emitters, createEmitter(shellVolume, "AbyssalSpecClusters", SPARKLE_TEXTURE, {
		Acceleration = Vector3.new(0, 1.15, 0) * scale,
		Brightness = 3.5,
		Color = colorSequence({
			{ 0, COLOR_HOT },
			{ 0.34, COLOR_WHITE },
			{ 0.62, Color3.new(1, 1, 1) },
			{ 1, COLOR_CRIMSON },
		}),
		Drag = 0.72,
		Lifetime = NumberRange.new(0.48, 1.45),
		LightEmission = 1,
		MinimumQuality = QUALITY_FULL,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rate = 18,
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-120, 120),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = numberSequence({
			{ 0, 0.02 * scale },
			{ 0.18, 0.16 * scale, 0.09 * scale },
			{ 0.72, 0.07 * scale, 0.04 * scale },
			{ 1, 0 },
		}),
		Speed = NumberRange.new(0.15 * scale, 1.35 * scale),
		SpreadAngle = Vector2.new(180, 180),
		Transparency = numberSequence({
			{ 0, 1 },
			{ 0.1, 0 },
			{ 0.7, 0.18 },
			{ 1, 1 },
		}),
		VelocityInheritance = 0.88,
		ZOffset = 0.65,
	}))

	table.insert(aura.Emitters, createEmitter(groundVolume, "GroundEmberBurst", SPARKLE_TEXTURE, {
		Acceleration = Vector3.new(0, 1.9, 0) * scale,
		Brightness = 3.2,
		Color = colorSequence({
			{ 0, COLOR_CRIMSON },
			{ 0.48, COLOR_HOT },
			{ 0.78, COLOR_WHITE },
			{ 1, COLOR_ABYSS },
		}),
		Drag = 1,
		EmissionDirection = Enum.NormalId.Top,
		Lifetime = NumberRange.new(0.5, 1.25),
		LightEmission = 1,
		MinimumQuality = QUALITY_REDUCED,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rate = 12,
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-120, 120),
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapePartial = 0.56,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = numberSequence({
			{ 0, 0.04 * scale, 0.03 * scale },
			{ 0.26, 0.18 * scale, 0.08 * scale },
			{ 1, 0 },
		}),
		Speed = NumberRange.new(0.7 * scale, 2.35 * scale),
		SpreadAngle = Vector2.new(76, 76),
		Transparency = numberSequence({
			{ 0, 0.04 },
			{ 0.68, 0.2 },
			{ 1, 1 },
		}),
		VelocityInheritance = 0.8,
		ZOffset = 0.35,
	}))

	table.insert(aura.Emitters, createEmitter(crownAttachment, "CrownSpecCluster", SPARKLE_TEXTURE, {
		Acceleration = Vector3.new(0, 0.24, 0) * scale,
		Brightness = 3.6,
		Color = colorSequence({
			{ 0, COLOR_HOT },
			{ 0.42, COLOR_WHITE },
			{ 1, COLOR_PINK },
		}),
		Drag = 1.55,
		Lifetime = NumberRange.new(0.65, 1.55),
		LightEmission = 1,
		MinimumQuality = QUALITY_FULL,
		Rate = 9,
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-75, 75),
		Size = numberSequence({
			{ 0, 0 },
			{ 0.2, 0.14 * scale, 0.07 * scale },
			{ 0.68, 0.06 * scale },
			{ 1, 0 },
		}),
		Speed = NumberRange.new(0.1 * scale, 0.8 * scale),
		SpreadAngle = Vector2.new(180, 180),
		Transparency = numberSequence({
			{ 0, 1 },
			{ 0.16, 0 },
			{ 0.72, 0.18 },
			{ 1, 1 },
		}),
		VelocityInheritance = 0.95,
		ZOffset = 0.6,
	}))

	for _, entry in ipairs(aura.Emitters) do
		entry.Emitter:Emit(math.max(5, math.floor(entry.BaseRate * 1.35)))
	end

	aura.CrownParticleAttachment = crownAttachment
end

local function createDebris(aura)
	for index = 1, 16 do
		local hotFragment = index % 5 == 0
		local fragment = Instance.new("WedgePart")
		fragment.Name = "AbyssalDebris_" .. index
		fragment.Anchored = false
		fragment.CanCollide = false
		fragment.CanQuery = false
		fragment.CanTouch = false
		fragment.CastShadow = false
		fragment.Color = if hotFragment then COLOR_HOT else COLOR_VOID
		fragment.Massless = true
		fragment.Material = if hotFragment then Enum.Material.Neon else Enum.Material.SmoothPlastic
		fragment.Size = Vector3.new(
			(0.045 + (index % 3) * 0.026) * aura.Scale,
			(0.1 + (index % 4) * 0.045) * aura.Scale,
			(0.055 + (index % 2) * 0.035) * aura.Scale
		)
		fragment.Transparency = if hotFragment then 0.12 else 0.08
		fragment.CFrame = aura.RootPart.CFrame
		fragment.Parent = aura.Folder

		local weld = Instance.new("Weld")
		weld.Name = "DebrisWeld"
		weld.Part0 = aura.RootPart
		weld.Part1 = fragment
		weld.C0 = CFrame.identity
		weld.C1 = CFrame.identity
		weld.Parent = fragment

		table.insert(aura.Debris, {
			AngularSpeed = (0.22 + (index % 4) * 0.075) * (if index % 2 == 0 then 1 else -1),
			BaseTransparency = fragment.Transparency,
			BaseY = aura.GroundY + 0.22 * aura.Scale,
			Fragment = fragment,
			Height = (4.7 + (index % 3) * 0.58) * aura.Scale,
			MinimumQuality = if hotFragment or index % 2 == 0 then QUALITY_REDUCED else QUALITY_FULL,
			Phase = (index * 0.61803398875) % 1,
			Radius = (1.45 + (index % 5) * 0.28) * aura.Scale,
			RiseSpeed = 0.055 + (index % 4) * 0.012,
			Spin = 0.8 + (index % 5) * 0.37,
			Weld = weld,
		})
	end
end

local function createLighting(aura)
	local bodyLight = Instance.new("PointLight")
	bodyLight.Name = "AbyssalBodyLight"
	bodyLight.Brightness = 0.72
	bodyLight.Color = COLOR_HOT
	bodyLight.Range = 7.5 * aura.Scale
	bodyLight.Shadows = false
	bodyLight.Parent = aura.AnchorPart
	table.insert(aura.Lights, {
		BaseBrightness = 0.72,
		Light = bodyLight,
		Phase = 0,
	})

	local crownLight = Instance.new("PointLight")
	crownLight.Name = "AbyssalCrownLight"
	crownLight.Brightness = 0.48
	crownLight.Color = COLOR_PINK
	crownLight.Range = 4.4 * aura.Scale
	crownLight.Shadows = false
	crownLight.Parent = aura.CrownParticleAttachment
	table.insert(aura.Lights, {
		BaseBrightness = 0.48,
		Light = crownLight,
		Phase = 1.7,
	})

	local highlight = Instance.new("Highlight")
	highlight.Name = "AbyssalCrimsonRim"
	highlight.Adornee = aura.Character
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = COLOR_ABYSS
	highlight.FillTransparency = 0.9
	highlight.OutlineColor = COLOR_PINK
	highlight.OutlineTransparency = 0.46
	highlight.Parent = aura.Folder

	aura.Highlight = highlight
end

local function updateFlames(aura, timeNow)
	for index, flame in ipairs(aura.Flames) do
		local spec = flame.Spec
		local phase = spec.Phase
		local scale = aura.Scale
		local slowWave = math.sin(timeNow * 1.72 + phase)
		local fastWave = math.sin(timeNow * 3.86 + phase * 1.61)
		local depthWave = math.cos(timeNow * 1.28 + phase * 0.83)
		local flutter = slowWave * 0.72 + fastWave * 0.28
		local basePosition = Vector3.new(
			spec.X + slowWave * 0.035,
			spec.BaseY,
			spec.Z + depthWave * 0.025
		) * scale
		local middlePosition = Vector3.new(
			spec.X + spec.Lean * 0.34 + flutter * 0.18 * spec.Scale,
			spec.BaseY + spec.Height * 0.48 + fastWave * 0.07,
			spec.Z + depthWave * 0.11
		) * scale
		local tipPosition = Vector3.new(
			spec.X + spec.Lean + flutter * 0.48 * spec.Scale,
			spec.BaseY + spec.Height + slowWave * 0.16,
			spec.Z + depthWave * 0.2
		) * scale
		local pulse = 0.9 + 0.13 * math.sin(timeNow * 2.45 + phase)
		local lowerWidth = 0.13 * spec.Scale * scale * pulse
		local upperWidth = 0.105 * spec.Scale * scale * pulse
		local lowerCurve = (0.12 + 0.08 * fastWave) * scale
		local upperCurve = (-0.1 + 0.07 * slowWave) * scale

		flame.Base.Position = basePosition
		flame.Middle.CFrame = CFrame.new(middlePosition) * CFrame.Angles(0, 0, lowerCurve)
		flame.Tip.CFrame = CFrame.new(tipPosition) * CFrame.Angles(0, 0, upperCurve)
		flame.Lower.Glow.CurveSize0 = lowerCurve
		flame.Lower.Glow.CurveSize1 = -lowerCurve * 0.6
		flame.Lower.Core.CurveSize0 = lowerCurve
		flame.Lower.Core.CurveSize1 = -lowerCurve * 0.6
		flame.Upper.Glow.CurveSize0 = -upperCurve * 0.65
		flame.Upper.Glow.CurveSize1 = upperCurve
		flame.Upper.Core.CurveSize0 = -upperCurve * 0.65
		flame.Upper.Core.CurveSize1 = upperCurve

		setLayeredLineWidths(
			flame.Lower,
			lowerWidth,
			upperWidth,
			aura.QualityLevel,
			aura.QualityLevel > QUALITY_HIDDEN
		)
		setLayeredLineWidths(
			flame.Upper,
			upperWidth,
			0.006 * scale,
			aura.QualityLevel,
			aura.QualityLevel > QUALITY_HIDDEN
		)

		if index % 3 == 0 then
			flame.Upper.Core.Brightness = 2.8 + 1.25 * math.max(0, fastWave)
		end
	end
end

local function updateTextureFlames(aura, timeNow)
	for index, flame in ipairs(aura.TextureFlames) do
		local spec = flame.Spec
		local slowWave = math.sin(timeNow * 1.08 + spec.Phase)
		local fastWave = math.sin(timeNow * 2.46 + spec.Phase * 1.7)
		local pulse = 1 + slowWave * 0.025 + fastWave * 0.012
		local width = spec.Width * aura.Scale * pulse
		local height = spec.Height * aura.Scale * (1 + slowWave * 0.018)
		local centerY = aura.GroundY + height * 0.5
		local sway = slowWave * (if spec.Haze then 0.24 else 0.14)
		local depthDrift = math.cos(timeNow * 0.82 + spec.Phase) * 0.055
		local baseTransparency = spec.Transparency
		local flicker = math.max(0, fastWave) * (if spec.Haze then 0.035 else 0.018)

		flame.Attachment.Position = Vector3.new(
			(spec.X + sway) * aura.Scale,
			centerY,
			(spec.Z + depthDrift) * aura.Scale
		)
		flame.Billboard.Enabled = aura.QualityLevel >= flame.MinimumQuality
		flame.Billboard.Size = UDim2.fromScale(width, height)
		flame.Image.ImageTransparency = math.clamp(baseTransparency + flicker, 0, 0.9)
		flame.Image.Rotation = slowWave * (if spec.Haze then 7 else 3.5)
	end
end

local function updateCrown(aura, timeNow)
	local bob = (0.055 * math.sin(timeNow * 1.7) + 0.018 * math.sin(timeNow * 4.1)) * aura.Scale

	if aura.CrownSprite ~= nil then
		aura.CrownSprite.Attachment.Position = Vector3.new(
			0,
			4.46 * aura.Scale + bob,
			-0.16 * aura.Scale
		)
		aura.CrownSprite.Billboard.Enabled = aura.QualityLevel > QUALITY_HIDDEN
		aura.CrownSprite.Image.ImageTransparency = 0.08
			+ 0.035 * math.max(0, math.sin(timeNow * 2.7))
		aura.CrownSprite.Image.Rotation = math.sin(timeNow * 1.25) * 0.6
	end

	for _, node in ipairs(aura.CrownNodes) do
		local shimmer = math.sin(timeNow * 2.2 + node.Phase) * 0.012 * aura.Scale
		node.Attachment.Position = node.BasePosition + Vector3.new(0, bob + shimmer, 0)
	end

	for _, entry in ipairs(aura.CrownLines) do
		local pulse = 0.88 + 0.22 * math.max(0, math.sin(timeNow * 2.9 + entry.Phase))
		local width = entry.Width * pulse

		setLayeredLineWidths(
			entry.Line,
			width,
			width,
			aura.QualityLevel,
			aura.QualityLevel > QUALITY_HIDDEN
		)
	end

	aura.CrownParticleAttachment.Position = Vector3.new(
		0,
		3.9 * aura.Scale + bob,
		-0.15 * aura.Scale
	)
end

local function updateGroundRings(aura, timeNow)
	local segmentCount = 0

	if aura.GroundSprite ~= nil then
		local breathe = 1 + 0.025 * math.sin(timeNow * 1.45)
		local size = aura.GroundSprite.BaseSize * breathe

		aura.GroundSprite.Part.Size = Vector3.new(size, 0.035, size)
		aura.GroundSprite.Surface.Enabled = aura.QualityLevel > QUALITY_HIDDEN
		aura.GroundSprite.Image.ImageTransparency = 0.18
			+ 0.1 * math.max(0, math.sin(timeNow * 1.8 + 0.4))
	end

	for ringIndex, ring in ipairs(aura.GroundRings) do
		local radius = 0
		local width = 0
		local visible = aura.QualityLevel > QUALITY_HIDDEN
		local rotation = timeNow * (if ringIndex % 2 == 0 then -0.12 else 0.16)

		if ring.Persistent then
			radius = (1.08 + math.sin(timeNow * 1.55) * 0.055) * aura.Scale
			width = (0.021 + math.max(0, math.sin(timeNow * 2.25)) * 0.007) * aura.Scale
		else
			local phase = (timeNow / 3.15 + ring.PhaseOffset) % 1
			local eased = 1 - (1 - phase) * (1 - phase)
			local fade = math.sin(math.pi * phase) ^ 0.72

			radius = (1.05 + eased * 2.25) * aura.Scale
			width = 0.027 * fade * aura.Scale
			visible = visible and fade > 0.06
			rotation += phase * 0.3
		end

		segmentCount = #ring.Nodes

		for index, attachment in ipairs(ring.Nodes) do
			local angle = ((index - 1) / segmentCount) * math.pi * 2 + rotation
			local wobble = 1 + math.sin(index * 2.31 + timeNow * 1.2) * 0.025

			attachment.Position = Vector3.new(
				math.cos(angle) * radius * wobble,
				aura.GroundY + 0.035,
				math.sin(angle) * radius * wobble
			)
		end

		for _, line in ipairs(ring.Lines) do
			setLayeredLineWidths(line, width, width, aura.QualityLevel, visible)
		end
	end

	for _, crack in ipairs(aura.GroundCracks) do
		local pulse = 0.32 + 0.68 * math.max(0, math.sin(timeNow * 1.75 + crack.Phase)) ^ 3
		local width = crack.Width * pulse * 0.72

		setLayeredLineWidths(
			crack.Line,
			width,
			width * 0.18,
			aura.QualityLevel,
			aura.QualityLevel > QUALITY_HIDDEN
		)
	end
end

local function updateHotSlashes(aura, timeNow)
	for index, slash in ipairs(aura.Slashes) do
		local spec = slash.Spec
		local cycle = (timeNow * 0.31 + spec.Phase) % 1
		local activeAlpha = cycle / 0.18
		local visible = activeAlpha >= 0 and activeAlpha <= 1
		local intensity = if visible then math.sin(activeAlpha * math.pi) ^ 0.62 else 0
		local tilt = math.rad(spec.Tilt)
		local direction = Vector3.new(math.cos(tilt), math.sin(tilt), math.sin(index * 1.7) * 0.22).Unit
		local sideways = math.sin(activeAlpha * math.pi * 0.8 + index) * 0.34
		local center = Vector3.new(
			spec.X + sideways,
			spec.BaseY + spec.Rise * activeAlpha,
			spec.Z + math.cos(index * 2.1) * 0.12
		) * aura.Scale
		local length = spec.Length * aura.Scale * (0.78 + intensity * 0.32)

		slash.Attachment0.Position = center - direction * length * 0.48
		slash.Attachment1.Position = center + direction * length * 0.52
		setLayeredLineWidths(
			slash.Line,
			0.036 * aura.Scale * intensity,
			0.005 * aura.Scale * intensity,
			aura.QualityLevel,
			visible and intensity > 0.04 and aura.QualityLevel > QUALITY_HIDDEN
		)
	end
end

local function updateParticlesAndLighting(aura, timeNow)
	for _, entry in ipairs(aura.Emitters) do
		local enabled = aura.QualityLevel >= entry.MinimumQuality

		entry.Emitter.Enabled = enabled

		if enabled then
			entry.Emitter.Rate = entry.BaseRate * (if aura.QualityLevel == QUALITY_FULL then 1 else 0.52)
		end
	end

	for _, entry in ipairs(aura.Lights) do
		entry.Light.Enabled = aura.QualityLevel > QUALITY_HIDDEN
		entry.Light.Brightness = entry.BaseBrightness
			* (0.88 + 0.2 * math.max(0, math.sin(timeNow * 2.15 + entry.Phase)))
			* (if aura.QualityLevel == QUALITY_FULL then 1 else 0.62)
	end

	aura.Highlight.Enabled = aura.QualityLevel > QUALITY_HIDDEN
	aura.Highlight.OutlineTransparency = 0.42 + 0.12 * math.sin(timeNow * 1.8) ^ 2
end

local function updateDebris(aura, timeNow)
	for index, entry in ipairs(aura.Debris) do
		local cycle = (entry.Phase + timeNow * entry.RiseSpeed) % 1
		local fade = math.sin(cycle * math.pi)
		local angle = entry.Phase * math.pi * 2 + timeNow * entry.AngularSpeed
		local radiusPulse = 0.88 + 0.12 * math.sin(timeNow * 0.7 + index * 1.91)
		local radius = entry.Radius * radiusPulse
		local position = Vector3.new(
			math.cos(angle) * radius,
			entry.BaseY + cycle * entry.Height,
			math.sin(angle) * radius * 0.72
		)
		local rotation = timeNow * entry.Spin + entry.Phase * math.pi * 2
		local visible = aura.QualityLevel >= entry.MinimumQuality

		entry.Weld.C0 = CFrame.new(position)
			* CFrame.Angles(rotation * 0.73, rotation, -rotation * 0.48)
		entry.Fragment.Transparency = if visible
			then math.clamp(entry.BaseTransparency + (1 - fade) * 0.8, 0, 1)
			else 1
	end
end

function AbyssalHalfCrownAura.create(character)
	if character == nil or not character:IsA("Model") then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	local existing = character:FindFirstChild(AURA_FOLDER_NAME)

	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = AURA_FOLDER_NAME
	folder:SetAttribute("AuraImplementation", "LayeredVolumetricVFX")
	folder:SetAttribute("AuraVersion", 4)
	folder.Parent = character

	local aura = {
		Character = character,
		AnchorPart = nil,
		CrownLines = {},
		CrownNodes = {},
		CrownParticleAttachment = nil,
		CrownSprite = nil,
		Debris = {},
		Emitters = {},
		Flames = {},
		Folder = folder,
		GroundCracks = {},
		GroundRings = {},
		GroundSprite = nil,
		GroundY = 0,
		Highlight = nil,
		Lights = {},
		QualityLevel = QUALITY_FULL,
		RootPart = rootPart,
		Scale = getCharacterScale(character),
		Slashes = {},
		StartedAt = os.clock(),
		TextureFlames = {},
	}

	aura.GroundY = getGroundOffset(character, rootPart)
	aura.AnchorPart = createVolumePart(
		folder,
		rootPart,
		"AbyssalAuraAnchor",
		CFrame.identity,
		Vector3.new(0.1, 0.1, 0.1)
	)

	createGroundSprite(aura)
	createCrownArc(aura)
	createCrownShards(aura)
	createGroundCracks(aura)
	createHotSlashes(aura)
	createParticles(aura)
	createDebris(aura)
	createLighting(aura)
	folder:SetAttribute("ParticleEmitterCount", #aura.Emitters)
	folder:SetAttribute("CrownSegmentCount", #aura.CrownLines)
	folder:SetAttribute("DebrisCount", #aura.Debris)
	folder:SetAttribute("GroundTextureReady", aura.GroundSprite ~= nil)

	return aura
end

function AbyssalHalfCrownAura.setQualityLevel(aura, qualityLevel)
	if aura == nil then
		return
	end

	aura.QualityLevel = math.clamp(math.floor(qualityLevel or QUALITY_FULL), QUALITY_HIDDEN, QUALITY_FULL)
end

function AbyssalHalfCrownAura.update(aura, timeNow)
	if
		aura == nil
		or aura.Folder.Parent == nil
		or aura.Character.Parent == nil
		or aura.RootPart.Parent == nil
	then
		return false
	end

	local auraTime = timeNow - aura.StartedAt

	updateTextureFlames(aura, auraTime)
	updateFlames(aura, auraTime)
	updateCrown(aura, auraTime)
	updateGroundRings(aura, auraTime)
	updateHotSlashes(aura, auraTime)
	updateParticlesAndLighting(aura, auraTime)
	updateDebris(aura, auraTime)

	return true
end

function AbyssalHalfCrownAura.destroy(aura)
	if aura == nil then
		return
	end

	if aura.Folder ~= nil and aura.Folder.Parent ~= nil then
		aura.Folder:Destroy()
	end
end

AbyssalHalfCrownAura.Quality = table.freeze({
	Full = QUALITY_FULL,
	Hidden = QUALITY_HIDDEN,
	Reduced = QUALITY_REDUCED,
})

return AbyssalHalfCrownAura
