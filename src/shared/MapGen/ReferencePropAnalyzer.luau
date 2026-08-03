local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapGenConfig = require(script.Parent:WaitForChild("MapGenConfig"))

local ReferencePropAnalyzer = {}

ReferencePropAnalyzer.SourceFolderName = "ReferenceProps"
ReferencePropAnalyzer.OutputModuleName = "GeneratedReferencePropBlueprints"

local GENERIC_NAMES = {
	folder = true,
	model = true,
	part = true,
	meshpart = true,
	union = true,
	unionoperation = true,
}

local function formatNumber(value)
	if math.abs(value) < 0.0005 then
		return "0"
	end

	return string.format("%.4f", value)
end

local function formatVector3(value)
	return "Vector3.new(" .. formatNumber(value.X) .. ", " .. formatNumber(value.Y) .. ", " .. formatNumber(value.Z) .. ")"
end

local function formatColor3(value)
	return string.format(
		"Color3.fromRGB(%d, %d, %d)",
		math.clamp(math.floor(value.R * 255 + 0.5), 0, 255),
		math.clamp(math.floor(value.G * 255 + 0.5), 0, 255),
		math.clamp(math.floor(value.B * 255 + 0.5), 0, 255)
	)
end

local function formatCFrame(value)
	local components = { value:GetComponents() }
	local output = {}

	for index, component in ipairs(components) do
		output[index] = formatNumber(component)
	end

	return "CFrame.new(" .. table.concat(output, ", ") .. ")"
end

local function formatEnum(enumItem)
	local enumText = tostring(enumItem)

	if string.sub(enumText, 1, 5) == "Enum." then
		return enumText
	end

	local enumTypeName = nil
	local ok = pcall(function()
		enumTypeName = enumItem.EnumType.Name
	end)

	if ok and enumTypeName ~= nil then
		return "Enum." .. enumTypeName .. "." .. enumItem.Name
	end

	return enumText
end

local function quote(value)
	return string.format("%q", tostring(value))
end

local function isGenericName(name)
	local normalized = string.lower(string.gsub(name, "%s+", ""))

	if GENERIC_NAMES[normalized] == true then
		return true
	end

	return string.match(normalized, "^part%d*$") ~= nil
		or string.match(normalized, "^model%d*$") ~= nil
		or string.match(normalized, "^meshpart%d*$") ~= nil
end

local function classifyColor(color)
	local r = color.R
	local g = color.G
	local b = color.B

	if g > 0.36 and g > r * 1.18 and g > b * 1.18 then
		return "Leaf"
	end

	if r > 0.78 and g > 0.78 and b > 0.78 and math.max(r, g, b) - math.min(r, g, b) < 0.14 then
		return "Snow"
	end

	if r > 0.75 and g > 0.5 and b < 0.35 then
		return "WarmAccent"
	end

	if (r > 0.55 and g < r * 0.68 and b < r * 0.68) or (r > 0.45 and b > 0.45 and g < 0.35) then
		return "FlowerAccent"
	end

	if r > 0.22 and g > 0.12 and b < 0.2 and r > b * 1.8 then
		return "Wood"
	end

	if math.abs(r - g) < 0.08 and math.abs(g - b) < 0.08 then
		return "Stone"
	end

	if b > 0.5 and g > 0.35 then
		return "Crystal"
	end

	return "Other"
end

local function colorKey(color)
	return string.format(
		"%03d,%03d,%03d",
		math.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
		math.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
		math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
	)
end

local function roundedValue(value, step)
	return math.floor(value / step + 0.5) * step
end

local function roundedKey(value, step)
	return formatNumber(roundedValue(value, step))
end

local function sizeKey(size)
	return table.concat({
		roundedKey(size.X, 0.25),
		roundedKey(size.Y, 0.25),
		roundedKey(size.Z, 0.25),
	}, "x")
end

local function countSetEntries(set)
	local count = 0

	for _ in pairs(set) do
		count += 1
	end

	return count
end

local function hasKeyword(text, keywords)
	for _, keyword in ipairs(keywords) do
		if string.find(text, keyword, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function getDominantCounterKey(counter)
	local bestKey = nil
	local bestCount = -1

	for key, count in pairs(counter) do
		if count > bestCount or (count == bestCount and tostring(key) < tostring(bestKey)) then
			bestKey = key
			bestCount = count
		end
	end

	return bestKey or "Other", math.max(bestCount, 0)
end

local function isLikelyRotated(cframe)
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cframe:GetComponents()
	local offAxis = math.abs(r01) + math.abs(r02) + math.abs(r10) + math.abs(r12) + math.abs(r20) + math.abs(r21)
	local diagonalDelta = math.abs(r00 - 1) + math.abs(r11 - 1) + math.abs(r22 - 1)

	return offAxis + diagonalDelta > 0.05
end

local function classifyCategory(nameText, roleCounts, footprint, height, partCount)
	local normalized = string.lower(nameText)

	if hasKeyword(normalized, { "lotus", "flower", "bloom", "petal" }) then
		return "Flower"
	end

	if hasKeyword(normalized, { "snowman", "snow man" }) then
		return "Snowman"
	end

	if hasKeyword(normalized, { "crab" }) then
		return "Creature"
	end

	if hasKeyword(normalized, { "tree", "oak", "palm", "pine", "birch", "spruce", "trunk", "branched" }) then
		return "Tree"
	end

	if hasKeyword(normalized, { "stump", "log" }) then
		return "Wood"
	end

	if hasKeyword(normalized, { "grass", "blade" }) then
		return "Grass"
	end

	if hasKeyword(normalized, { "mushroom", "shroom" }) then
		return "Mushroom"
	end

	if hasKeyword(normalized, { "fence", "post" }) then
		return "Fence"
	end

	if hasKeyword(normalized, { "portal" }) then
		return "Portal"
	end

	if hasKeyword(normalized, { "mountain", "cliff" }) then
		return "Mountain"
	end

	if hasKeyword(normalized, { "rock", "stone", "boulder", "ore" }) then
		return "Stone"
	end

	if hasKeyword(normalized, { "bush", "shrub", "hedge" }) then
		return "Bush"
	end

	if hasKeyword(normalized, { "cactus" }) then
		return "Cactus"
	end

	local leafCount = roleCounts.Leaf or 0
	local woodCount = roleCounts.Wood or 0
	local stoneCount = roleCounts.Stone or 0
	local snowCount = roleCounts.Snow or 0
	local flowerCount = roleCounts.FlowerAccent or 0
	local warmAccentCount = roleCounts.WarmAccent or 0
	local footprintSafe = math.max(footprint, 0.001)

	if snowCount >= math.max(2, partCount * 0.35) then
		return "Snow"
	end

	if flowerCount + warmAccentCount >= math.max(2, partCount * 0.22) and leafCount > 0 then
		return "Flower"
	end

	if leafCount > 0 and woodCount > 0 then
		return if height / footprintSafe > 0.9 then "Tree" else "Bush"
	end

	if leafCount >= math.max(2, partCount * 0.45) then
		return "Bush"
	end

	if stoneCount >= math.max(1, partCount * 0.45) then
		return "Stone"
	end

	if woodCount >= math.max(1, partCount * 0.45) then
		return "Wood"
	end

	return "Misc"
end

local function classifyComplexity(score, partCount)
	if partCount <= 4 or score < 18 then
		return "VerySimplistic"
	end

	if score < 36 then
		return "Simple"
	end

	if score < 60 then
		return "Defined"
	end

	if score < 82 then
		return "Advanced"
	end

	return "ReferenceQuality"
end

local function buildDesignTags(stats)
	local tags = {}

	if stats.ComplexityLevel == "VerySimplistic" or stats.ComplexityLevel == "Simple" then
		table.insert(tags, "Simplistic")
	end

	if stats.ComplexityLevel == "Advanced" or stats.ComplexityLevel == "ReferenceQuality" then
		table.insert(tags, "TemplateCandidate")
	end

	if stats.SmallDetailCount >= 10 and stats.SmallDetailRatio >= 0.2 then
		table.insert(tags, "HighSmallDetail")
	end

	if stats.VerticalLayerCount >= 5 then
		table.insert(tags, "Layered")
	end

	if stats.RotatedPartCount >= 4 then
		table.insert(tags, "AngledGeometry")
	end

	if stats.UniqueColorCount >= 3 then
		table.insert(tags, "StrongPalette")
	end

	if stats.UniqueSizeCount >= 8 then
		table.insert(tags, "SizeVariation")
	end

	if stats.NestedModelCount > 0 then
		table.insert(tags, "NestedSource")
	end

	if stats.GenericNameRatio >= 0.5 then
		table.insert(tags, "GenericNames")
	end

	return tags
end

local function getHierarchyPath(root, instance)
	local names = {}
	local cursor = instance

	while cursor ~= nil and cursor ~= root do
		table.insert(names, 1, cursor.Name)
		cursor = cursor.Parent
	end

	return table.concat(names, "/")
end

local function getDepth(root, instance)
	local depth = 0
	local cursor = instance.Parent

	while cursor ~= nil and cursor ~= root do
		depth += 1
		cursor = cursor.Parent
	end

	return depth
end

local function collectBaseParts(container)
	local parts = {}

	if container:IsA("BasePart") then
		table.insert(parts, container)
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function extendBoundsWithPoint(bounds, point)
	if bounds.Min == nil then
		bounds.Min = point
		bounds.Max = point
		return
	end

	bounds.Min = Vector3.new(
		math.min(bounds.Min.X, point.X),
		math.min(bounds.Min.Y, point.Y),
		math.min(bounds.Min.Z, point.Z)
	)
	bounds.Max = Vector3.new(
		math.max(bounds.Max.X, point.X),
		math.max(bounds.Max.Y, point.Y),
		math.max(bounds.Max.Z, point.Z)
	)
end

local function extendBoundsWithPart(bounds, part)
	local half = part.Size / 2

	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				extendBoundsWithPoint(bounds, part.CFrame:PointToWorldSpace(Vector3.new(
					x * half.X,
					y * half.Y,
					z * half.Z
				)))
			end
		end
	end
end

local function getBounds(parts)
	local bounds = {}

	for _, part in ipairs(parts) do
		extendBoundsWithPart(bounds, part)
	end

	if bounds.Min == nil then
		return nil
	end

	return {
		Min = bounds.Min,
		Max = bounds.Max,
		Center = (bounds.Min + bounds.Max) / 2,
		Size = bounds.Max - bounds.Min,
	}
end

local function countNestedModels(root, container)
	local count = 0
	local maxDepth = 0

	if container:IsA("Model") then
		count += 1
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("Model") then
			count += 1
			maxDepth = math.max(maxDepth, getDepth(root, descendant))
		end
	end

	return count, maxDepth
end

local function sortPartsByGeometry(origin, parts)
	table.sort(parts, function(left, right)
		local leftRelative = origin:PointToObjectSpace(left.Position)
		local rightRelative = origin:PointToObjectSpace(right.Position)

		if math.abs(leftRelative.Y - rightRelative.Y) > 0.001 then
			return leftRelative.Y < rightRelative.Y
		end

		if math.abs(leftRelative.X - rightRelative.X) > 0.001 then
			return leftRelative.X < rightRelative.X
		end

		if math.abs(leftRelative.Z - rightRelative.Z) > 0.001 then
			return leftRelative.Z < rightRelative.Z
		end

		local leftVolume = left.Size.X * left.Size.Y * left.Size.Z
		local rightVolume = right.Size.X * right.Size.Y * right.Size.Z

		if math.abs(leftVolume - rightVolume) > 0.001 then
			return leftVolume > rightVolume
		end

		return left:GetFullName() < right:GetFullName()
	end)
end

local function incrementCounter(counter, key)
	counter[key] = (counter[key] or 0) + 1
end

local function analyzePart(root, origin, part, index)
	local relativeCFrame = origin:ToObjectSpace(part.CFrame)
	local role = classifyColor(part.Color)
	local meshInfo = nil

	if part:IsA("MeshPart") then
		meshInfo = {
			MeshId = part.MeshId,
			TextureID = part.TextureID,
		}
	else
		local specialMesh = part:FindFirstChildWhichIsA("SpecialMesh")

		if specialMesh ~= nil then
			meshInfo = {
				MeshId = specialMesh.MeshId,
				TextureId = specialMesh.TextureId,
				MeshType = specialMesh.MeshType.Name,
				Scale = specialMesh.Scale,
				Offset = specialMesh.Offset,
			}
		end
	end

	return {
		Id = string.format("P%03d_%s", index, role),
		Name = part.Name,
		Path = getHierarchyPath(root, part),
		ClassName = part.ClassName,
		Role = role,
		Depth = getDepth(root, part),
		RelativeCFrame = relativeCFrame,
		RelativePosition = relativeCFrame.Position,
		Size = part.Size,
		Color = part.Color,
		Material = part.Material,
		Transparency = part.Transparency,
		Reflectance = part.Reflectance,
		CanCollide = part.CanCollide,
		CanQuery = part.CanQuery,
		CastShadow = part.CastShadow,
		Shape = if part:IsA("Part") then part.Shape else nil,
		TopSurface = part.TopSurface,
		BottomSurface = part.BottomSurface,
		LeftSurface = part.LeftSurface,
		RightSurface = part.RightSurface,
		FrontSurface = part.FrontSurface,
		BackSurface = part.BackSurface,
		Mesh = meshInfo,
	}
end

local function analyzeCandidate(root, candidate, index)
	local parts = collectBaseParts(candidate)

	if #parts == 0 then
		return nil
	end

	local bounds = getBounds(parts)
	local origin = CFrame.new(bounds.Center.X, bounds.Min.Y, bounds.Center.Z)
	local genericNameCount = 0
	local classCounts = {}
	local materialCounts = {}
	local roleCounts = {}
	local nestedModelCount, maxModelDepth = countNestedModels(candidate, candidate)
	local uniqueColors = {}
	local uniqueSizes = {}
	local verticalLayers = {}
	local rotatedPartCount = 0
	local smallDetailCount = 0
	local boundsVolume = math.max(bounds.Size.X * bounds.Size.Y * bounds.Size.Z, 0.001)

	sortPartsByGeometry(origin, parts)

	local analyzedParts = {}

	for partIndex, part in ipairs(parts) do
		if isGenericName(part.Name) then
			genericNameCount += 1
		end

		incrementCounter(classCounts, part.ClassName)
		incrementCounter(materialCounts, part.Material.Name)

		local analyzedPart = analyzePart(candidate, origin, part, partIndex)
		local partVolume = part.Size.X * part.Size.Y * part.Size.Z
		local smallestPartAxis = math.min(part.Size.X, part.Size.Y, part.Size.Z)
		local smallestBoundsAxis = math.max(0.001, math.min(bounds.Size.X, bounds.Size.Y, bounds.Size.Z))

		uniqueColors[colorKey(part.Color)] = true
		uniqueSizes[sizeKey(part.Size)] = true
		verticalLayers[roundedKey(analyzedPart.RelativePosition.Y, 0.5)] = true

		if isLikelyRotated(analyzedPart.RelativeCFrame) then
			rotatedPartCount += 1
			analyzedPart.IsRotated = true
		else
			analyzedPart.IsRotated = false
		end

		if partVolume <= boundsVolume * 0.012 or smallestPartAxis <= smallestBoundsAxis * 0.08 then
			smallDetailCount += 1
			analyzedPart.IsSmallDetail = true
		else
			analyzedPart.IsSmallDetail = false
		end

		incrementCounter(roleCounts, analyzedPart.Role)
		table.insert(analyzedParts, analyzedPart)
	end

	local displayName = candidate.Name

	if isGenericName(displayName) then
		displayName = string.format("Reference_%02d", index)
	end

	local uniqueColorCount = countSetEntries(uniqueColors)
	local uniqueSizeCount = countSetEntries(uniqueSizes)
	local verticalLayerCount = countSetEntries(verticalLayers)
	local dominantRole, dominantRoleCount = getDominantCounterKey(roleCounts)
	local category = classifyCategory(displayName .. " " .. candidate.Name .. " " .. getHierarchyPath(root, candidate), roleCounts, math.max(bounds.Size.X, bounds.Size.Z), bounds.Size.Y, #parts)
	local complexityScore = math.floor(
		math.min(#parts * 1.15, 36)
			+ math.min(smallDetailCount * 1.45, 28)
			+ math.min((uniqueColorCount - 1) * 4, 16)
			+ math.min((uniqueSizeCount - 1) * 1.2, 14)
			+ math.min((verticalLayerCount - 1) * 2.1, 18)
			+ math.min(rotatedPartCount * 1.35, 14)
			+ math.min(nestedModelCount * 1.8 + maxModelDepth * 2, 12)
			+ 0.5
	)
	local complexityLevel = classifyComplexity(complexityScore, #parts)
	local smallDetailRatio = smallDetailCount / math.max(#parts, 1)
	local genericNameRatio = genericNameCount / math.max(#parts, 1)
	local analysisStats = {
		ComplexityLevel = complexityLevel,
		SmallDetailCount = smallDetailCount,
		SmallDetailRatio = smallDetailRatio,
		VerticalLayerCount = verticalLayerCount,
		RotatedPartCount = rotatedPartCount,
		UniqueColorCount = uniqueColorCount,
		UniqueSizeCount = uniqueSizeCount,
		NestedModelCount = nestedModelCount,
		GenericNameRatio = genericNameRatio,
	}

	return {
		Id = string.format("Reference_%02d", index),
		Name = displayName,
		OriginalName = candidate.Name,
		ClassName = candidate.ClassName,
		Category = category,
		SourcePath = getHierarchyPath(root, candidate),
		PartCount = #parts,
		GenericNameCount = genericNameCount,
		GenericNameRatio = genericNameRatio,
		NestedModelCount = nestedModelCount,
		MaxModelDepth = maxModelDepth,
		ComplexityScore = complexityScore,
		ComplexityLevel = complexityLevel,
		DesignTags = buildDesignTags(analysisStats),
		SmallDetailCount = smallDetailCount,
		SmallDetailRatio = smallDetailRatio,
		VerticalLayerCount = verticalLayerCount,
		RotatedPartCount = rotatedPartCount,
		UniqueColorCount = uniqueColorCount,
		UniqueSizeCount = uniqueSizeCount,
		DominantRole = dominantRole,
		DominantRoleCount = dominantRoleCount,
		Bounds = bounds,
		Origin = origin,
		Footprint = math.max(bounds.Size.X, bounds.Size.Z),
		Height = bounds.Size.Y,
		ClassCounts = classCounts,
		MaterialCounts = materialCounts,
		RoleCounts = roleCounts,
		Parts = analyzedParts,
	}
end

local function getSortedCandidates(root)
	local candidates = {}

	for _, child in ipairs(root:GetChildren()) do
		if #collectBaseParts(child) > 0 then
			table.insert(candidates, child)
		end
	end

	table.sort(candidates, function(left, right)
		local leftParts = collectBaseParts(left)
		local rightParts = collectBaseParts(right)
		local leftBounds = getBounds(leftParts)
		local rightBounds = getBounds(rightParts)

		if leftBounds ~= nil and rightBounds ~= nil then
			if math.abs(leftBounds.Center.X - rightBounds.Center.X) > 0.001 then
				return leftBounds.Center.X < rightBounds.Center.X
			end

			if math.abs(leftBounds.Center.Z - rightBounds.Center.Z) > 0.001 then
				return leftBounds.Center.Z < rightBounds.Center.Z
			end
		end

		return left:GetFullName() < right:GetFullName()
	end)

	return candidates
end

local function appendCounter(lines, indent, name, counter)
	table.insert(lines, indent .. name .. " = {")

	local keys = {}

	for key in pairs(counter) do
		table.insert(keys, key)
	end

	table.sort(keys)

	for _, key in ipairs(keys) do
		table.insert(lines, string.format("%s\t[%q] = %d,", indent, key, counter[key]))
	end

	table.insert(lines, indent .. "},")
end

local function appendStringArray(lines, indent, name, values)
	table.insert(lines, indent .. name .. " = {")

	for _, value in ipairs(values) do
		table.insert(lines, indent .. "\t" .. quote(value) .. ",")
	end

	table.insert(lines, indent .. "},")
end

local function appendPart(lines, part, indent)
	table.insert(lines, indent .. "{")
	table.insert(lines, indent .. "\tId = " .. quote(part.Id) .. ",")
	table.insert(lines, indent .. "\tName = " .. quote(part.Name) .. ",")
	table.insert(lines, indent .. "\tPath = " .. quote(part.Path) .. ",")
	table.insert(lines, indent .. "\tClassName = " .. quote(part.ClassName) .. ",")
	table.insert(lines, indent .. "\tRole = " .. quote(part.Role) .. ",")
	table.insert(lines, indent .. "\tDepth = " .. tostring(part.Depth) .. ",")
	table.insert(lines, indent .. "\tCFrame = " .. formatCFrame(part.RelativeCFrame) .. ",")
	table.insert(lines, indent .. "\tPosition = " .. formatVector3(part.RelativePosition) .. ",")
	table.insert(lines, indent .. "\tSize = " .. formatVector3(part.Size) .. ",")
	table.insert(lines, indent .. "\tColor = " .. formatColor3(part.Color) .. ",")
	table.insert(lines, indent .. "\tMaterial = " .. formatEnum(part.Material) .. ",")
	table.insert(lines, indent .. "\tTransparency = " .. formatNumber(part.Transparency) .. ",")
	table.insert(lines, indent .. "\tReflectance = " .. formatNumber(part.Reflectance) .. ",")
	table.insert(lines, indent .. "\tCanCollide = " .. tostring(part.CanCollide) .. ",")
	table.insert(lines, indent .. "\tCanQuery = " .. tostring(part.CanQuery) .. ",")
	table.insert(lines, indent .. "\tCastShadow = " .. tostring(part.CastShadow) .. ",")
	table.insert(lines, indent .. "\tIsRotated = " .. tostring(part.IsRotated) .. ",")
	table.insert(lines, indent .. "\tIsSmallDetail = " .. tostring(part.IsSmallDetail) .. ",")

	if part.Shape ~= nil then
		table.insert(lines, indent .. "\tShape = " .. formatEnum(part.Shape) .. ",")
	end

	table.insert(lines, indent .. "\tSurfaces = {")
	table.insert(lines, indent .. "\t\tTop = " .. formatEnum(part.TopSurface) .. ",")
	table.insert(lines, indent .. "\t\tBottom = " .. formatEnum(part.BottomSurface) .. ",")
	table.insert(lines, indent .. "\t\tLeft = " .. formatEnum(part.LeftSurface) .. ",")
	table.insert(lines, indent .. "\t\tRight = " .. formatEnum(part.RightSurface) .. ",")
	table.insert(lines, indent .. "\t\tFront = " .. formatEnum(part.FrontSurface) .. ",")
	table.insert(lines, indent .. "\t\tBack = " .. formatEnum(part.BackSurface) .. ",")
	table.insert(lines, indent .. "\t},")

	if part.Mesh ~= nil then
		table.insert(lines, indent .. "\tMesh = {")

		local meshKeys = {}

		for key in pairs(part.Mesh) do
			table.insert(meshKeys, key)
		end

		table.sort(meshKeys)

		for _, key in ipairs(meshKeys) do
			local value = part.Mesh[key]

			if typeof(value) == "Vector3" then
				table.insert(lines, indent .. "\t\t" .. key .. " = " .. formatVector3(value) .. ",")
			else
				table.insert(lines, indent .. "\t\t" .. key .. " = " .. quote(value) .. ",")
			end
		end

		table.insert(lines, indent .. "\t},")
	end

	table.insert(lines, indent .. "},")
end

local function buildBlueprintSource(analysis)
	local lines = {
		"local GeneratedReferencePropBlueprints = {}",
		"",
		string.format("GeneratedReferencePropBlueprints.GeneratedBy = %q", MapGenConfig.GeneratedBy),
		string.format("GeneratedReferencePropBlueprints.SourceFolderName = %q", ReferencePropAnalyzer.SourceFolderName),
		string.format("GeneratedReferencePropBlueprints.GeneratedAtUnix = %d", os.time()),
		string.format("GeneratedReferencePropBlueprints.TotalProps = %d", analysis.TotalProps),
		string.format("GeneratedReferencePropBlueprints.TotalParts = %d", analysis.TotalParts),
		"",
		"GeneratedReferencePropBlueprints.Props = {",
	}

	for _, prop in ipairs(analysis.Props) do
		table.insert(lines, "\t{")
		table.insert(lines, "\t\tId = " .. quote(prop.Id) .. ",")
		table.insert(lines, "\t\tName = " .. quote(prop.Name) .. ",")
		table.insert(lines, "\t\tOriginalName = " .. quote(prop.OriginalName) .. ",")
		table.insert(lines, "\t\tClassName = " .. quote(prop.ClassName) .. ",")
		table.insert(lines, "\t\tCategory = " .. quote(prop.Category) .. ",")
		table.insert(lines, "\t\tSourcePath = " .. quote(prop.SourcePath) .. ",")
		table.insert(lines, "\t\tPartCount = " .. tostring(prop.PartCount) .. ",")
		table.insert(lines, "\t\tGenericNameCount = " .. tostring(prop.GenericNameCount) .. ",")
		table.insert(lines, "\t\tGenericNameRatio = " .. formatNumber(prop.GenericNameRatio) .. ",")
		table.insert(lines, "\t\tNestedModelCount = " .. tostring(prop.NestedModelCount) .. ",")
		table.insert(lines, "\t\tMaxModelDepth = " .. tostring(prop.MaxModelDepth) .. ",")
		table.insert(lines, "\t\tComplexityScore = " .. tostring(prop.ComplexityScore) .. ",")
		table.insert(lines, "\t\tComplexityLevel = " .. quote(prop.ComplexityLevel) .. ",")
		table.insert(lines, "\t\tSmallDetailCount = " .. tostring(prop.SmallDetailCount) .. ",")
		table.insert(lines, "\t\tSmallDetailRatio = " .. formatNumber(prop.SmallDetailRatio) .. ",")
		table.insert(lines, "\t\tVerticalLayerCount = " .. tostring(prop.VerticalLayerCount) .. ",")
		table.insert(lines, "\t\tRotatedPartCount = " .. tostring(prop.RotatedPartCount) .. ",")
		table.insert(lines, "\t\tUniqueColorCount = " .. tostring(prop.UniqueColorCount) .. ",")
		table.insert(lines, "\t\tUniqueSizeCount = " .. tostring(prop.UniqueSizeCount) .. ",")
		table.insert(lines, "\t\tDominantRole = " .. quote(prop.DominantRole) .. ",")
		table.insert(lines, "\t\tDominantRoleCount = " .. tostring(prop.DominantRoleCount) .. ",")
		table.insert(lines, "\t\tFootprint = " .. formatNumber(prop.Footprint) .. ",")
		table.insert(lines, "\t\tHeight = " .. formatNumber(prop.Height) .. ",")
		table.insert(lines, "\t\tBounds = {")
		table.insert(lines, "\t\t\tMin = " .. formatVector3(prop.Bounds.Min) .. ",")
		table.insert(lines, "\t\t\tMax = " .. formatVector3(prop.Bounds.Max) .. ",")
		table.insert(lines, "\t\t\tSize = " .. formatVector3(prop.Bounds.Size) .. ",")
		table.insert(lines, "\t\t},")
		appendStringArray(lines, "\t\t", "DesignTags", prop.DesignTags)
		appendCounter(lines, "\t\t", "ClassCounts", prop.ClassCounts)
		appendCounter(lines, "\t\t", "MaterialCounts", prop.MaterialCounts)
		appendCounter(lines, "\t\t", "RoleCounts", prop.RoleCounts)
		table.insert(lines, "\t\tParts = {")

		for _, part in ipairs(prop.Parts) do
			appendPart(lines, part, "\t\t\t")
		end

		table.insert(lines, "\t\t},")
		table.insert(lines, "\t},")
	end

	table.insert(lines, "}")
	table.insert(lines, "")
	table.insert(lines, "return GeneratedReferencePropBlueprints")

	return table.concat(lines, "\n")
end

function ReferencePropAnalyzer.buildBlueprintSource(analysis)
	return buildBlueprintSource(analysis)
end

local function sanitizeModuleName(value, fallback)
	local sanitized = string.gsub(tostring(value or ""), "[^%w_]+", "_")
	sanitized = string.gsub(sanitized, "^_+", "")
	sanitized = string.gsub(sanitized, "_+$", "")

	if sanitized == "" then
		sanitized = fallback
	end

	if string.len(sanitized) > 40 then
		sanitized = string.sub(sanitized, 1, 40)
	end

	return sanitized
end

local function getPropModuleName(prop)
	return prop.Id .. "_" .. sanitizeModuleName(prop.Name, "Prop")
end

local function appendPropSummary(lines, prop, detailModuleName, indent)
	table.insert(lines, indent .. "{")
	table.insert(lines, indent .. "\tId = " .. quote(prop.Id) .. ",")
	table.insert(lines, indent .. "\tName = " .. quote(prop.Name) .. ",")
	table.insert(lines, indent .. "\tOriginalName = " .. quote(prop.OriginalName) .. ",")
	table.insert(lines, indent .. "\tCategory = " .. quote(prop.Category) .. ",")
	table.insert(lines, indent .. "\tDetailModule = " .. quote(detailModuleName) .. ",")
	table.insert(lines, indent .. "\tPartCount = " .. tostring(prop.PartCount) .. ",")
	table.insert(lines, indent .. "\tComplexityScore = " .. tostring(prop.ComplexityScore) .. ",")
	table.insert(lines, indent .. "\tComplexityLevel = " .. quote(prop.ComplexityLevel) .. ",")
	table.insert(lines, indent .. "\tSmallDetailCount = " .. tostring(prop.SmallDetailCount) .. ",")
	table.insert(lines, indent .. "\tVerticalLayerCount = " .. tostring(prop.VerticalLayerCount) .. ",")
	table.insert(lines, indent .. "\tRotatedPartCount = " .. tostring(prop.RotatedPartCount) .. ",")
	table.insert(lines, indent .. "\tUniqueColorCount = " .. tostring(prop.UniqueColorCount) .. ",")
	table.insert(lines, indent .. "\tUniqueSizeCount = " .. tostring(prop.UniqueSizeCount) .. ",")
	table.insert(lines, indent .. "\tFootprint = " .. formatNumber(prop.Footprint) .. ",")
	table.insert(lines, indent .. "\tHeight = " .. formatNumber(prop.Height) .. ",")
	table.insert(lines, indent .. "\tBounds = {")
	table.insert(lines, indent .. "\t\tMin = " .. formatVector3(prop.Bounds.Min) .. ",")
	table.insert(lines, indent .. "\t\tMax = " .. formatVector3(prop.Bounds.Max) .. ",")
	table.insert(lines, indent .. "\t\tSize = " .. formatVector3(prop.Bounds.Size) .. ",")
	table.insert(lines, indent .. "\t},")
	appendStringArray(lines, indent .. "\t", "DesignTags", prop.DesignTags)
	appendCounter(lines, indent .. "\t", "RoleCounts", prop.RoleCounts)
	table.insert(lines, indent .. "},")
end

local function buildIndexSource(analysis, detailModuleNames)
	local lines = {
		"local GeneratedReferencePropBlueprints = {}",
		"",
		string.format("GeneratedReferencePropBlueprints.GeneratedBy = %q", MapGenConfig.GeneratedBy),
		string.format("GeneratedReferencePropBlueprints.SourceFolderName = %q", ReferencePropAnalyzer.SourceFolderName),
		string.format("GeneratedReferencePropBlueprints.GeneratedAtUnix = %d", os.time()),
		string.format("GeneratedReferencePropBlueprints.TotalProps = %d", analysis.TotalProps),
		string.format("GeneratedReferencePropBlueprints.TotalParts = %d", analysis.TotalParts),
		"",
		"GeneratedReferencePropBlueprints.Props = {",
	}

	for index, prop in ipairs(analysis.Props) do
		appendPropSummary(lines, prop, detailModuleNames[index], "\t")
	end

	table.insert(lines, "}")
	table.insert(lines, "")
	table.insert(lines, "return GeneratedReferencePropBlueprints")

	return table.concat(lines, "\n")
end

local function buildSinglePropSource(prop)
	local lines = {
		"local ReferencePropBlueprint = {}",
		"",
		"ReferencePropBlueprint.Id = " .. quote(prop.Id),
		"ReferencePropBlueprint.Name = " .. quote(prop.Name),
		"ReferencePropBlueprint.OriginalName = " .. quote(prop.OriginalName),
		"ReferencePropBlueprint.ClassName = " .. quote(prop.ClassName),
		"ReferencePropBlueprint.Category = " .. quote(prop.Category),
		"ReferencePropBlueprint.SourcePath = " .. quote(prop.SourcePath),
		"ReferencePropBlueprint.PartCount = " .. tostring(prop.PartCount),
		"ReferencePropBlueprint.GenericNameCount = " .. tostring(prop.GenericNameCount),
		"ReferencePropBlueprint.GenericNameRatio = " .. formatNumber(prop.GenericNameRatio),
		"ReferencePropBlueprint.NestedModelCount = " .. tostring(prop.NestedModelCount),
		"ReferencePropBlueprint.MaxModelDepth = " .. tostring(prop.MaxModelDepth),
		"ReferencePropBlueprint.ComplexityScore = " .. tostring(prop.ComplexityScore),
		"ReferencePropBlueprint.ComplexityLevel = " .. quote(prop.ComplexityLevel),
		"ReferencePropBlueprint.SmallDetailCount = " .. tostring(prop.SmallDetailCount),
		"ReferencePropBlueprint.SmallDetailRatio = " .. formatNumber(prop.SmallDetailRatio),
		"ReferencePropBlueprint.VerticalLayerCount = " .. tostring(prop.VerticalLayerCount),
		"ReferencePropBlueprint.RotatedPartCount = " .. tostring(prop.RotatedPartCount),
		"ReferencePropBlueprint.UniqueColorCount = " .. tostring(prop.UniqueColorCount),
		"ReferencePropBlueprint.UniqueSizeCount = " .. tostring(prop.UniqueSizeCount),
		"ReferencePropBlueprint.DominantRole = " .. quote(prop.DominantRole),
		"ReferencePropBlueprint.DominantRoleCount = " .. tostring(prop.DominantRoleCount),
		"ReferencePropBlueprint.Footprint = " .. formatNumber(prop.Footprint),
		"ReferencePropBlueprint.Height = " .. formatNumber(prop.Height),
		"ReferencePropBlueprint.Bounds = {",
		"\tMin = " .. formatVector3(prop.Bounds.Min) .. ",",
		"\tMax = " .. formatVector3(prop.Bounds.Max) .. ",",
		"\tSize = " .. formatVector3(prop.Bounds.Size) .. ",",
		"}",
	}

	appendStringArray(lines, "", "ReferencePropBlueprint.DesignTags", prop.DesignTags)
	appendCounter(lines, "", "ReferencePropBlueprint.ClassCounts", prop.ClassCounts)
	appendCounter(lines, "", "ReferencePropBlueprint.MaterialCounts", prop.MaterialCounts)
	appendCounter(lines, "", "ReferencePropBlueprint.RoleCounts", prop.RoleCounts)

	table.insert(lines, "ReferencePropBlueprint.Parts = {")

	for _, part in ipairs(prop.Parts) do
		appendPart(lines, part, "\t")
	end

	table.insert(lines, "}")
	table.insert(lines, "")
	table.insert(lines, "return ReferencePropBlueprint")

	return table.concat(lines, "\n")
end

local function setModuleSource(moduleScript, source)
	local directOk, directErr = pcall(function()
		moduleScript.Source = source
	end)

	if directOk then
		return true, nil
	end

	local serviceOk, scriptEditorService = pcall(function()
		return game:GetService("ScriptEditorService")
	end)

	if serviceOk and scriptEditorService ~= nil then
		local updateOk, updateErr = pcall(function()
			scriptEditorService:UpdateSourceAsync(moduleScript, function()
				return source
			end)
		end)

		if updateOk then
			return true, nil
		end

		return false, tostring(directErr) .. " / " .. tostring(updateErr)
	end

	return false, tostring(directErr)
end

local function writeModuleScript(parent, name, source)
	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Name = name
	moduleScript:SetAttribute("GeneratedBy", MapGenConfig.GeneratedBy)
	moduleScript:SetAttribute("SourceLength", string.len(source))
	moduleScript.Parent = parent

	local writeOk, writeErr = setModuleSource(moduleScript, source)

	if not writeOk then
		moduleScript:SetAttribute("SourceWriteError", writeErr)
		return nil, "Failed to write " .. moduleScript:GetFullName() .. ": " .. tostring(writeErr)
	end

	return moduleScript, nil
end

function ReferencePropAnalyzer.exportBlueprintModules(analysis)
	local exportRoot = ReplicatedStorage:FindFirstChild(ReferencePropAnalyzer.OutputModuleName)

	if exportRoot ~= nil and not exportRoot:IsA("Folder") then
		exportRoot:Destroy()
		exportRoot = nil
	end

	if exportRoot == nil then
		exportRoot = Instance.new("Folder")
		exportRoot.Name = ReferencePropAnalyzer.OutputModuleName
		exportRoot.Parent = ReplicatedStorage
	end

	for _, child in ipairs(exportRoot:GetChildren()) do
		child:Destroy()
	end

	exportRoot:SetAttribute("GeneratedBy", MapGenConfig.GeneratedBy)
	exportRoot:SetAttribute("SourceFolderName", ReferencePropAnalyzer.SourceFolderName)
	exportRoot:SetAttribute("TotalProps", analysis.TotalProps)
	exportRoot:SetAttribute("TotalParts", analysis.TotalParts)

	local detailModuleNames = {}

	for index, prop in ipairs(analysis.Props) do
		detailModuleNames[index] = getPropModuleName(prop)
	end

	local indexModule, indexErr = writeModuleScript(exportRoot, "Index", buildIndexSource(analysis, detailModuleNames))

	if indexModule == nil then
		return nil, indexErr
	end

	local propModules = {}

	for index, prop in ipairs(analysis.Props) do
		local moduleScript, moduleErr = writeModuleScript(exportRoot, detailModuleNames[index], buildSinglePropSource(prop))

		if moduleScript == nil then
			return nil, moduleErr
		end

		table.insert(propModules, moduleScript)
	end

	return exportRoot, nil, {
		IndexModule = indexModule,
		PropModules = propModules,
		TotalModules = 1 + #propModules,
	}
end

function ReferencePropAnalyzer.getReferenceRoot()
	local root = Workspace:FindFirstChild(ReferencePropAnalyzer.SourceFolderName)

	if root == nil then
		return nil, "Workspace." .. ReferencePropAnalyzer.SourceFolderName .. " was not found."
	end

	return root, nil
end

function ReferencePropAnalyzer.analyze(root)
	local sourceRoot = root

	if sourceRoot == nil then
		local rootErr = nil

		sourceRoot, rootErr = ReferencePropAnalyzer.getReferenceRoot()

		if sourceRoot == nil then
			return {
				Error = rootErr,
				SourceRoot = nil,
				TotalProps = 0,
				TotalParts = 0,
				Props = {},
			}
		end
	end

	local props = {}
	local totalParts = 0

	for index, candidate in ipairs(getSortedCandidates(sourceRoot)) do
		local prop = analyzeCandidate(sourceRoot, candidate, index)

		if prop ~= nil then
			totalParts += prop.PartCount
			table.insert(props, prop)
		end
	end

	return {
		SourceRoot = sourceRoot,
		TotalProps = #props,
		TotalParts = totalParts,
		Props = props,
	}
end

function ReferencePropAnalyzer.formatSummary(analysis)
	if analysis.Error ~= nil then
		return { analysis.Error }
	end

	local lines = {
		string.format(
			"ReferenceProps analysis: %d props, %d BaseParts.",
			analysis.TotalProps,
			analysis.TotalParts
		),
	}
	local categoryCounts = {}
	local complexityCounts = {}
	local rankedProps = {}

	for _, prop in ipairs(analysis.Props) do
		incrementCounter(categoryCounts, prop.Category)
		incrementCounter(complexityCounts, prop.ComplexityLevel)
		table.insert(rankedProps, prop)
	end

	local function appendCounts(label, counts)
		local values = {}

		for key, count in pairs(counts) do
			table.insert(values, tostring(key) .. "=" .. tostring(count))
		end

		table.sort(values)

		if #values > 0 then
			table.insert(lines, label .. ": " .. table.concat(values, ", ") .. ".")
		end
	end

	appendCounts("Categories", categoryCounts)
	appendCounts("Complexity", complexityCounts)

	table.sort(rankedProps, function(left, right)
		if left.ComplexityScore ~= right.ComplexityScore then
			return left.ComplexityScore > right.ComplexityScore
		end

		return left.Name < right.Name
	end)

	local candidateLabels = {}

	for index = 1, math.min(5, #rankedProps) do
		local prop = rankedProps[index]

		table.insert(candidateLabels, string.format(
			"%s %s/%s %d",
			prop.Name,
			prop.Category,
			prop.ComplexityLevel,
			prop.ComplexityScore
		))
	end

	if #candidateLabels > 0 then
		table.insert(lines, "Top reference candidates: " .. table.concat(candidateLabels, "; ") .. ".")
	end

	for _, prop in ipairs(analysis.Props) do
		table.insert(lines, string.format(
			"%s [%s/%s %d]: %d parts, %d details, %d layers, %d colors, %d rotated, bounds %.1fx%.1fx%.1f, generic names %d/%d, nested models %d.",
			prop.Name,
			prop.Category,
			prop.ComplexityLevel,
			prop.ComplexityScore,
			prop.PartCount,
			prop.SmallDetailCount,
			prop.VerticalLayerCount,
			prop.UniqueColorCount,
			prop.RotatedPartCount,
			prop.Bounds.Size.X,
			prop.Bounds.Size.Y,
			prop.Bounds.Size.Z,
			prop.GenericNameCount,
			prop.PartCount,
			prop.NestedModelCount
		))
	end

	return lines
end

function ReferencePropAnalyzer.exportBlueprintModule(analysis)
	return ReferencePropAnalyzer.exportBlueprintModules(analysis)
end

return ReferencePropAnalyzer
