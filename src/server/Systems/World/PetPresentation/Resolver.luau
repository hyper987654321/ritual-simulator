local Resolver = {}

local MODEL_CONTRACT_VERSION = 1
local PLACEHOLDER_STATUS = "placeholder"
local REVIEWED_STATUS = "reviewed"
local ERROR_COLOR = Color3.fromRGB(255, 70, 70)

local SILHOUETTES = {
	ember_sprite = "orb",
	sun_sprite = "sun",
	moon_sprite = "moon",
	crystal_sprite = "crystal",
	crescent_sprite = "crescent",
	rune_stone = "rune",
	crimson_glyph = "glyph",
}

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function isFiniteCFrame(value)
	if typeof(value) ~= "CFrame" then
		return false
	end

	for _, component in ipairs({ value:GetComponents() }) do
		if not isFiniteNumber(component) then
			return false
		end
	end

	return true
end

local function configurePart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
end

local function createPart(model, name, color, size, cframe, shape, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	configurePart(part)
	part.Parent = model
	return part
end

local function getAccentColor(baseColor)
	local hue, saturation, value = baseColor:ToHSV()
	return Color3.fromHSV((hue + 0.08) % 1, math.min(1, saturation * 0.8 + 0.2), math.min(1, value * 1.15))
end

local function createOrb(model, color)
	createPart(model, "Core", color, Vector3.new(1.2, 1.2, 1.2), CFrame.new(), Enum.PartType.Ball, Enum.Material.Neon)
	createPart(model, "Flare", getAccentColor(color), Vector3.new(0.32, 1.5, 0.32), CFrame.Angles(0, 0, math.rad(45)), nil, Enum.Material.Neon)
end

local function createSun(model, color)
	local accent = getAccentColor(color)
	createPart(model, "Core", color, Vector3.new(1.05, 1.05, 1.05), CFrame.new(), Enum.PartType.Ball, Enum.Material.Neon)
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		local position = Vector3.new(math.cos(angle) * 0.72, math.sin(angle) * 0.72, 0)
		createPart(model, "Ray" .. index, accent, Vector3.new(0.16, 0.42, 0.16), CFrame.new(position) * CFrame.Angles(0, 0, angle), nil, Enum.Material.Neon)
	end
end

local function createMoon(model, color)
	local accent = getAccentColor(color)
	createPart(model, "Body", color, Vector3.new(1.35, 1.35, 0.48), CFrame.new(), Enum.PartType.Ball, Enum.Material.Neon)
	createPart(model, "Cusp", accent, Vector3.new(0.28, 1.15, 0.28), CFrame.new(0.62, 0, 0) * CFrame.Angles(0, 0, math.rad(35)), nil, Enum.Material.Neon)
end

local function createCrystal(model, color)
	local accent = getAccentColor(color)
	createPart(model, "Shard", color, Vector3.new(0.82, 1.5, 0.82), CFrame.Angles(0, 0, math.rad(8)), nil, Enum.Material.Glass)
	createPart(model, "ShardAccent", accent, Vector3.new(0.18, 1.15, 0.18), CFrame.new(0.33, 0.08, -0.34) * CFrame.Angles(0, 0, math.rad(-12)), nil, Enum.Material.Neon)
end

local function createCrescent(model, color)
	local accent = getAccentColor(color)
	createPart(model, "Arc", color, Vector3.new(1.35, 1.35, 0.42), CFrame.new(), Enum.PartType.Ball, Enum.Material.Neon)
	createPart(model, "Tip", accent, Vector3.new(0.26, 0.78, 0.26), CFrame.new(0.58, 0.44, 0) * CFrame.Angles(0, 0, math.rad(-42)), nil, Enum.Material.Neon)
	createPart(model, "TipLower", accent, Vector3.new(0.26, 0.78, 0.26), CFrame.new(0.58, -0.44, 0) * CFrame.Angles(0, 0, math.rad(42)), nil, Enum.Material.Neon)
end

local function createRune(model, color)
	local accent = getAccentColor(color)
	createPart(model, "Stone", color, Vector3.new(1.2, 1.1, 0.9), CFrame.Angles(0, math.rad(12), math.rad(-5)), nil, Enum.Material.Slate)
	createPart(model, "RuneVertical", accent, Vector3.new(0.14, 0.72, 0.12), CFrame.new(0, 0.02, -0.48), nil, Enum.Material.Neon)
	createPart(model, "RuneCrossbar", accent, Vector3.new(0.54, 0.14, 0.12), CFrame.new(0.08, 0.12, -0.48), nil, Enum.Material.Neon)
end

local function createGlyph(model, color)
	local accent = getAccentColor(color)
	createPart(model, "GlyphCore", color, Vector3.new(0.82, 1.22, 0.82), CFrame.Angles(0, 0, math.rad(45)), nil, Enum.Material.Neon)
	createPart(model, "GlyphRing", accent, Vector3.new(1.55, 0.12, 1.55), CFrame.Angles(math.rad(90), 0, 0), Enum.PartType.Cylinder, Enum.Material.Neon)
	createPart(model, "GlyphBar", accent, Vector3.new(0.15, 1.65, 0.15), CFrame.Angles(0, 0, math.rad(45)), nil, Enum.Material.Neon)
end

local function createFallbackModel(basePetId, basePet)
	local model = Instance.new("Model")
	model.Name = basePetId
	local color = if basePet ~= nil and typeof(basePet.Color) == "Color3" then basePet.Color else ERROR_COLOR
	local silhouette = SILHOUETTES[basePetId]

	if silhouette == "orb" then
		createOrb(model, color)
	elseif silhouette == "sun" then
		createSun(model, color)
	elseif silhouette == "moon" then
		createMoon(model, color)
	elseif silhouette == "crystal" then
		createCrystal(model, color)
	elseif silhouette == "crescent" then
		createCrescent(model, color)
	elseif silhouette == "rune" then
		createRune(model, color)
	elseif silhouette == "glyph" then
		createGlyph(model, color)
	else
		createPart(model, "ErrorOrb", ERROR_COLOR, Vector3.new(1.1, 1.1, 1.1), CFrame.new(), Enum.PartType.Ball, Enum.Material.Neon)
	end

	return model
end

local function hasExecutableDescendant(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			return true
		end
	end

	return false
end

local function isValidTemplate(model)
	if model == nil or not model:IsA("Model") or hasExecutableDescendant(model) then
		return false
	end

	local partCount = 0
	local visiblePartCount = 0

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			partCount += 1
			if not isFiniteVector3(descendant.Size)
				or descendant.Size.X <= 0
				or descendant.Size.Y <= 0
				or descendant.Size.Z <= 0
				or not isFiniteCFrame(descendant.CFrame) then
				return false
			end

			if descendant.Transparency < 1 then
				visiblePartCount += 1
			end
		end
	end

	return partCount > 0 and visiblePartCount > 0
end

local function sanitizeModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			configurePart(descendant)
		end
	end

	return model
end

local function annotate(model, basePetId, status, sourceArtifactId)
	model:SetAttribute("PetBaseId", basePetId)
	model:SetAttribute("ModelContractVersion", MODEL_CONTRACT_VERSION)
	model:SetAttribute("PresentationStatus", status)
	model:SetAttribute("SourceArtifactId", sourceArtifactId)
	return model
end

local function createErrorOrb(basePetId)
	local model = Instance.new("Model")
	model.Name = basePetId
	createPart(model, "ErrorOrb", ERROR_COLOR, Vector3.new(1, 1, 1), CFrame.new(), Enum.PartType.Ball, Enum.Material.Neon)
	return annotate(model, basePetId, PLACEHOLDER_STATUS, "code-native:error-orb:v1")
end

function Resolver.resolve(basePetId, basePet, sourceTemplate)
	if sourceTemplate ~= nil then
		local clonedModel
		local didClone, cloneResult = pcall(function()
			return sourceTemplate:Clone()
		end)

		if didClone and cloneResult ~= nil and isValidTemplate(cloneResult) then
			return annotate(sanitizeModel(cloneResult), basePetId, REVIEWED_STATUS, "ServerStorage.PetModels/" .. basePetId)
		end
	end

	local placeholder = createFallbackModel(basePetId, basePet)
	if isValidTemplate(placeholder) then
		return annotate(placeholder, basePetId, PLACEHOLDER_STATUS, "code-native:" .. basePetId .. ":v1")
	end

	return createErrorOrb(basePetId)
end

return Resolver
