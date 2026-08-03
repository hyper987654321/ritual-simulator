local Util = require(script.Parent:WaitForChild("BlockWriterUtil"))

local PropDefinitions = {}

local function color(ctx, key, fallback)
	return Util.getColor(ctx.ZonePlan.Theme, key, fallback)
end

local function scaledVector(ctx, value)
	local scale = ctx.Scale or 1

	return Vector3.new(value.X * scale, value.Y * scale, value.Z * scale)
end

local function withScale(ctx, scale, callback)
	local previousScale = ctx.Scale

	ctx.Scale = (ctx.Scale or 1) * scale
	callback(ctx)
	ctx.Scale = previousScale
end

local function localFrame(ctx, offset, angles)
	local cframe = ctx.Frame * CFrame.new(offset.X, offset.Y, offset.Z)

	if angles ~= nil then
		cframe = cframe * CFrame.Angles(angles.X, angles.Y, angles.Z)
	end

	return cframe
end

local function block(ctx, name, offset, size, partColor, options)
	local safeOptions = options or {}
	local part = Util.createPart(ctx.Parent, ctx.Plan, ctx.ZonePlan.ZoneId, "Prop", ctx.NamePrefix .. "_" .. name, {
		CanCollide = safeOptions.CanCollide == true,
		CanQuery = if safeOptions.CanQuery == nil then false else safeOptions.CanQuery,
		CastShadow = if safeOptions.CastShadow == nil then true else safeOptions.CastShadow,
		Color = partColor,
		Material = safeOptions.Material or Enum.Material.Plastic,
		Shape = safeOptions.Shape,
		Size = scaledVector(ctx, size),
		CFrame = localFrame(ctx, scaledVector(ctx, offset), safeOptions.Angles),
		Transparency = safeOptions.Transparency,
	})

	if safeOptions.Smooth ~= true then
		Util.setStudSurfaces(part)
	end

	return part
end

local SIGN_MESSAGES = {
	"TOUCH GRASS",
	"FREE SHADE",
	"BUGS THIS WAY",
	"NO RUSHING",
}

local function addSurfaceText(part, text, textColor)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "SignText"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.LightInfluence = 0.25
	surfaceGui.PixelsPerStud = 34
	surfaceGui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(35, 24, 16)
	label.TextStrokeTransparency = 0.18
	label.TextWrapped = true
	label.Parent = surfaceGui
end

local function axisPosition(index, count, span)
	if count <= 1 then
		return 0
	end

	return -span / 2 + span * ((index - 1) / (count - 1))
end

local function addFaceStuds(ctx, prefix, center, boxSize, face, columns, rows, studColor, studSize)
	local detailSize = studSize or Vector3.new(0.42, 0.42, 0.14)
	local thickness = detailSize.Z
	local width = detailSize.X
	local height = detailSize.Y
	local faceOffset = thickness / 2 + 0.02
	local horizontalSpan = if face == "Left" or face == "Right" then boxSize.Z - width else boxSize.X - width
	local verticalSpan = boxSize.Y - height

	for row = 1, rows do
		for column = 1, columns do
			local horizontal = axisPosition(column, columns, horizontalSpan)
			local vertical = axisPosition(row, rows, verticalSpan)
			local offset
			local size

			if face == "Front" then
				offset = Vector3.new(center.X + horizontal, center.Y + vertical, center.Z - boxSize.Z / 2 - faceOffset)
				size = Vector3.new(width, height, thickness)
			elseif face == "Back" then
				offset = Vector3.new(center.X + horizontal, center.Y + vertical, center.Z + boxSize.Z / 2 + faceOffset)
				size = Vector3.new(width, height, thickness)
			elseif face == "Left" then
				offset = Vector3.new(center.X - boxSize.X / 2 - faceOffset, center.Y + vertical, center.Z + horizontal)
				size = Vector3.new(thickness, height, width)
			else
				offset = Vector3.new(center.X + boxSize.X / 2 + faceOffset, center.Y + vertical, center.Z + horizontal)
				size = Vector3.new(thickness, height, width)
			end

			block(ctx, prefix .. "_" .. face .. "_" .. tostring(row) .. "_" .. tostring(column), offset, size, studColor, {
				CanCollide = false,
			})
		end
	end
end

local function addTopStuds(ctx, prefix, center, boxSize, columns, rows, studColor, studSize)
	local detailSize = studSize or Vector3.new(0.44, 0.14, 0.44)
	local horizontalSpan = boxSize.X - detailSize.X
	local depthSpan = boxSize.Z - detailSize.Z

	for row = 1, rows do
		for column = 1, columns do
			block(ctx, prefix .. "_Top_" .. tostring(row) .. "_" .. tostring(column), Vector3.new(
				center.X + axisPosition(column, columns, horizontalSpan),
				center.Y + boxSize.Y / 2 + detailSize.Y / 2 + 0.02,
				center.Z + axisPosition(row, rows, depthSpan)
			), detailSize, studColor, {
				CanCollide = false,
			})
		end
	end
end

local function buildGrass(ctx)
	local leafShadow = color(ctx, "LeafShadow", Color3.fromRGB(49, 164, 65))
	local leaf = color(ctx, "Leaf", Color3.fromRGB(72, 216, 78))
	local leafAccent = color(ctx, "LeafAccent", Color3.fromRGB(142, 245, 83))
	local blades = {
		{ "Center", Vector3.new(0, 1.95, 0), Vector3.new(0.48, 3.9, 0.48), leafAccent, 0 },
		{ "East", Vector3.new(0.86, 1.55, 0), Vector3.new(0.42, 3.1, 0.34), leaf, 0 },
		{ "West", Vector3.new(-0.86, 1.55, 0), Vector3.new(0.42, 3.1, 0.34), leaf, 0 },
		{ "North", Vector3.new(0, 1.5, -0.86), Vector3.new(0.34, 3.0, 0.42), leafShadow, 0 },
		{ "South", Vector3.new(0, 1.5, 0.86), Vector3.new(0.34, 3.0, 0.42), leafShadow, 0 },
		{ "NorthEast", Vector3.new(0.62, 1.22, -0.62), Vector3.new(0.34, 2.45, 0.34), leaf, math.rad(45) },
		{ "SouthWest", Vector3.new(-0.62, 1.22, 0.62), Vector3.new(0.34, 2.45, 0.34), leaf, math.rad(45) },
		{ "NorthWest", Vector3.new(-0.62, 1.22, -0.62), Vector3.new(0.34, 2.45, 0.34), leafShadow, math.rad(-45) },
		{ "SouthEast", Vector3.new(0.62, 1.22, 0.62), Vector3.new(0.34, 2.45, 0.34), leafShadow, math.rad(-45) },
	}

	for _, blade in ipairs(blades) do
		block(ctx, "Blade_" .. blade[1], blade[2], blade[3], blade[4], {
			CanCollide = false,
			Angles = Vector3.new(0, blade[5], 0),
		})
	end
end

local function buildBush(ctx)
	local leaf = color(ctx, "Leaf", Color3.fromRGB(72, 216, 78))
	local leafAccent = color(ctx, "LeafAccent", Color3.fromRGB(142, 245, 83))
	local leafShadow = color(ctx, "LeafShadow", Color3.fromRGB(44, 156, 58))
	local berry = color(ctx, "FlowerAlt", Color3.fromRGB(190, 91, 255))
	local flower = color(ctx, "Flower", Color3.fromRGB(255, 228, 102))
	local pieces = {
		{ "Lower", Vector3.new(0, 1.0, 0), Vector3.new(4.4, 1.9, 3.8), leafShadow },
		{ "Center", Vector3.new(0, 1.65, 0), Vector3.new(3.7, 2.0, 3.2), leaf },
		{ "Left", Vector3.new(-1.45, 1.45, 0), Vector3.new(2.1, 1.7, 2.8), leaf },
		{ "Right", Vector3.new(1.45, 1.45, 0), Vector3.new(2.1, 1.7, 2.8), leaf },
		{ "Front", Vector3.new(0, 1.35, -1.28), Vector3.new(3.0, 1.55, 1.35), leafShadow },
		{ "Back", Vector3.new(0, 1.35, 1.28), Vector3.new(3.0, 1.55, 1.35), leafShadow },
		{ "Top", Vector3.new(0, 2.55, 0), Vector3.new(2.6, 1.15, 2.3), leafAccent },
	}

	for index, piece in ipairs(pieces) do
		block(ctx, "Bush_" .. piece[1] .. "_" .. tostring(index), piece[2], piece[3], piece[4], {
			CanCollide = false,
		})
	end

	local berries = {
		{ -1.0, 2.18, -1.98, berry },
		{ 1.0, 2.18, -1.98, berry },
		{ -0.45, 2.88, -1.26, flower },
		{ 0.45, 2.88, -1.26, flower },
		{ -1.38, 1.72, -1.98, flower },
		{ 1.38, 1.72, -1.98, flower },
		{ -1.0, 2.18, 1.98, berry },
		{ 1.0, 2.18, 1.98, berry },
		{ -0.45, 2.88, 1.26, flower },
		{ 0.45, 2.88, 1.26, flower },
	}

	for index, berrySpec in ipairs(berries) do
		block(ctx, "Berry_" .. tostring(index), Vector3.new(berrySpec[1], berrySpec[2], berrySpec[3]), Vector3.new(0.36, 0.36, 0.22), berrySpec[4], {
			CanCollide = false,
		})
	end
end

local function buildFlowerClump(ctx)
	local stem = color(ctx, "LeafShadow", Color3.fromRGB(44, 156, 58))
	local flower = color(ctx, "Flower", Color3.fromRGB(255, 228, 102))
	local flowerAlt = color(ctx, "FlowerAlt", Color3.fromRGB(190, 91, 255))
	local flowerShadow = flowerAlt:Lerp(Color3.fromRGB(72, 32, 118), 0.24)
	local leaf = color(ctx, "Leaf", Color3.fromRGB(72, 216, 78))
	local petalCount = 8

	for leafIndex = 1, 4 do
		local angle = (leafIndex - 1) * (math.pi / 2) + math.pi / 4
		local x = math.cos(angle) * 1.05
		local z = math.sin(angle) * 1.05

		block(ctx, "GroundLeaf_" .. tostring(leafIndex), Vector3.new(x, 0.16, z), Vector3.new(1.45, 0.22, 0.52), leaf, {
			CanCollide = false,
			Angles = Vector3.new(0, -angle, 0),
		})
	end

	for petal = 1, petalCount do
		local angle = (petal - 1) * ((math.pi * 2) / petalCount)
		local x = math.cos(angle) * 1.0
		local z = math.sin(angle) * 1.0
		local isDiagonal = petal % 2 == 0

		block(ctx, "PetalShadow_" .. tostring(petal), Vector3.new(x * 0.92, 0.22, z * 0.92), Vector3.new(1.22, 0.22, 0.5), flowerShadow, {
			CanCollide = false,
			Angles = Vector3.new(0, -angle, 0),
		})
		block(ctx, "Petal_" .. tostring(petal), Vector3.new(x, 0.36, z), Vector3.new(if isDiagonal then 1.05 else 1.22, 0.26, 0.48), flowerAlt, {
			CanCollide = false,
			Angles = Vector3.new(0, -angle, 0),
		})
	end

	block(ctx, "StemCenter", Vector3.new(0, 0.34, 0), Vector3.new(0.42, 0.58, 0.42), stem, {
		CanCollide = false,
	})
	block(ctx, "CenterBase", Vector3.new(0, 0.62, 0), Vector3.new(1.0, 0.38, 1.0), flower, {
		CanCollide = false,
	})
	block(ctx, "CenterTop", Vector3.new(0, 0.9, 0), Vector3.new(0.58, 0.24, 0.58), flower:Lerp(Color3.fromRGB(255, 255, 255), 0.16), {
		CanCollide = false,
	})
end

local function buildRock(ctx)
	local stone = color(ctx, "Stone", Color3.fromRGB(115, 119, 120))
	local stoneLight = stone:Lerp(Color3.fromRGB(255, 255, 255), 0.12)
	local stoneDark = stone:Lerp(Color3.fromRGB(35, 42, 48), 0.2)

	block(ctx, "RockBase", Vector3.new(0, 0.45, 0), Vector3.new(3.6, 0.9, 2.8), stone)
	block(ctx, "RockMid", Vector3.new(0, 1.05, -0.05), Vector3.new(2.8, 0.82, 2.15), stoneLight, {
		CanCollide = false,
	})
	block(ctx, "RockTop", Vector3.new(0, 1.55, -0.12), Vector3.new(1.7, 0.42, 1.25), stone, {
		CanCollide = false,
	})
	block(ctx, "FrontCrackA", Vector3.new(-0.32, 1.06, -1.47), Vector3.new(0.22, 0.72, 0.14), stoneDark, {
		CanCollide = false,
	})
	block(ctx, "FrontCrackB", Vector3.new(0.26, 0.72, -1.47), Vector3.new(0.22, 0.42, 0.14), stoneDark, {
		CanCollide = false,
	})
	block(ctx, "BackCrackA", Vector3.new(-0.32, 1.06, 1.47), Vector3.new(0.22, 0.72, 0.14), stoneDark, {
		CanCollide = false,
	})
	block(ctx, "BackCrackB", Vector3.new(0.26, 0.72, 1.47), Vector3.new(0.22, 0.42, 0.14), stoneDark, {
		CanCollide = false,
	})
	block(ctx, "LeftChip", Vector3.new(-1.48, 0.72, -0.55), Vector3.new(0.42, 0.34, 0.64), stoneDark, {
		CanCollide = false,
	})
	block(ctx, "RightChip", Vector3.new(1.48, 0.72, -0.55), Vector3.new(0.42, 0.34, 0.64), stoneDark, {
		CanCollide = false,
	})
	block(ctx, "LeftBackChip", Vector3.new(-1.48, 0.72, 0.55), Vector3.new(0.42, 0.34, 0.64), stoneDark, {
		CanCollide = false,
	})
	block(ctx, "RightBackChip", Vector3.new(1.48, 0.72, 0.55), Vector3.new(0.42, 0.34, 0.64), stoneDark, {
		CanCollide = false,
	})
end

local function buildPathPebbles(ctx)
	local stone = color(ctx, "Stone", Color3.fromRGB(115, 119, 120))
	local leaf = color(ctx, "LeafShadow", Color3.fromRGB(44, 156, 58))
	local pebbleSpecs = {
		{ -1.85, -0.85, 1.0, 0.24, 0.72, math.rad(-12) },
		{ -0.95, 0.62, 0.82, 0.22, 1.0, math.rad(12) },
		{ 0, -0.1, 1.05, 0.24, 0.78, 0 },
		{ 0.95, 0.62, 0.82, 0.22, 1.0, math.rad(-12) },
		{ 1.85, -0.85, 1.0, 0.24, 0.72, math.rad(12) },
	}

	for index, spec in ipairs(pebbleSpecs) do
		block(ctx, "Pebble_" .. tostring(index), Vector3.new(spec[1], spec[4] / 2, spec[2]), Vector3.new(spec[3], spec[4], spec[5]), stone:Lerp(Color3.fromRGB(255, 255, 255), index * 0.015), {
			CanCollide = false,
			Angles = Vector3.new(0, spec[6], 0),
		})
	end

	for index, x in ipairs({ -1.35, 1.35 }) do
		block(ctx, "Moss_" .. tostring(index), Vector3.new(x, 0.18, 1.1), Vector3.new(0.75, 0.16, 0.28), leaf, {
			CanCollide = false,
			Angles = Vector3.new(0, if index == 1 then math.rad(18) else math.rad(-18), 0),
		})
		block(ctx, "BackMoss_" .. tostring(index), Vector3.new(x, 0.18, -1.1), Vector3.new(0.75, 0.16, 0.28), leaf, {
			CanCollide = false,
			Angles = Vector3.new(0, if index == 1 then math.rad(-18) else math.rad(18), 0),
		})
	end
end

local function buildOreVein(ctx)
	local stone = color(ctx, "Stone", Color3.fromRGB(115, 119, 120))
	local accent = color(ctx, "Accent", Color3.fromRGB(103, 228, 255))

	block(ctx, "OreRock", Vector3.new(0, 1.1, 0), Vector3.new(5.4, 2.2, 3.8), stone, {
		Angles = Vector3.new(0, ctx.Rng:NextNumber(0, math.pi * 2), 0),
	})

	for index = 1, ctx.Rng:NextInteger(3, 5) do
		block(ctx, "OreGlow_" .. tostring(index), Vector3.new(
			ctx.Rng:NextNumber(-2.2, 2.2),
			ctx.Rng:NextNumber(1.0, 2.1),
			-2.05
		), Vector3.new(ctx.Rng:NextNumber(0.5, 0.9), ctx.Rng:NextNumber(0.5, 1.2), 0.34), accent, {
			CanCollide = false,
			Material = Enum.Material.Plastic,
			Transparency = 0.08,
		})
	end
end

local function buildRockCluster(ctx)
	local stone = color(ctx, "Stone", Color3.fromRGB(115, 119, 120))
	local stoneLight = stone:Lerp(Color3.fromRGB(255, 255, 255), 0.1)
	local stoneDark = stone:Lerp(Color3.fromRGB(35, 42, 48), 0.22)
	local rocks = {
		{ "Center", Vector3.new(0, 0.8, 0), Vector3.new(3.2, 1.6, 2.65), stoneLight, 0 },
		{ "Left", Vector3.new(-2.05, 0.58, 0.22), Vector3.new(1.75, 1.16, 1.9), stone, math.rad(8) },
		{ "Right", Vector3.new(2.05, 0.58, 0.22), Vector3.new(1.75, 1.16, 1.9), stone, math.rad(-8) },
		{ "Front", Vector3.new(0, 0.38, -1.42), Vector3.new(2.1, 0.76, 1.15), stoneDark:Lerp(stone, 0.55), 0 },
		{ "Back", Vector3.new(0, 0.38, 1.42), Vector3.new(2.1, 0.76, 1.15), stoneDark:Lerp(stone, 0.55), 0 },
	}

	for index, rock in ipairs(rocks) do
		block(ctx, "ClusterRock_" .. rock[1] .. "_" .. tostring(index), rock[2], rock[3], rock[4], {
			Angles = Vector3.new(0, rock[5], 0),
		})
	end

	for index, side in ipairs({ -1, 1 }) do
		block(ctx, "SideChip_" .. tostring(index), Vector3.new(side * 2.9, 0.32, -0.48), Vector3.new(0.58, 0.34, 0.8), stoneDark, {
			CanCollide = false,
			Angles = Vector3.new(0, side * math.rad(8), 0),
		})
		block(ctx, "BackSideChip_" .. tostring(index), Vector3.new(side * 2.9, 0.32, 0.48), Vector3.new(0.58, 0.34, 0.8), stoneDark, {
			CanCollide = false,
			Angles = Vector3.new(0, side * math.rad(-8), 0),
		})
		block(ctx, "TopCrack_" .. tostring(index), Vector3.new(side * 0.48, 1.66, -0.24), Vector3.new(0.18, 0.14, 0.9), stoneDark, {
			CanCollide = false,
		})
	end
end

local function buildTreeStump(ctx)
	local wood = color(ctx, "Wood", Color3.fromRGB(104, 70, 39))
	local woodDark = wood:Lerp(Color3.fromRGB(43, 29, 18), 0.44)
	local woodMid = wood:Lerp(Color3.fromRGB(255, 214, 142), 0.14)
	local woodLight = wood:Lerp(Color3.fromRGB(255, 214, 142), 0.34)
	local groove = woodDark:Lerp(Color3.fromRGB(10, 8, 7), 0.18)

	for index, side in ipairs({ -1, 1 }) do
		block(ctx, "RootRunX_" .. tostring(index), Vector3.new(side * 2.85, 0.42, 0), Vector3.new(3.25, 0.62, 1.05), woodDark:Lerp(wood, 0.12), {
			CanCollide = false,
		})
		block(ctx, "RootToeX_" .. tostring(index), Vector3.new(side * 4.22, 0.32, 0), Vector3.new(1.2, 0.42, 1.18), woodDark, {
			CanCollide = false,
		})
		block(ctx, "RootRunZ_" .. tostring(index), Vector3.new(0, 0.42, side * 2.85), Vector3.new(1.05, 0.62, 3.25), woodDark:Lerp(wood, 0.12), {
			CanCollide = false,
		})
		block(ctx, "RootToeZ_" .. tostring(index), Vector3.new(0, 0.32, side * 4.22), Vector3.new(1.18, 0.42, 1.2), woodDark, {
			CanCollide = false,
		})
		block(ctx, "RootTopPlateX_" .. tostring(index), Vector3.new(side * 3.35, 0.82, 0), Vector3.new(0.58, 0.14, 0.5), woodMid, {
			CanCollide = false,
		})
		block(ctx, "RootTopPlateZ_" .. tostring(index), Vector3.new(0, 0.82, side * 3.35), Vector3.new(0.5, 0.14, 0.58), woodMid, {
			CanCollide = false,
		})
	end

	for xSide = -1, 1, 2 do
		for zSide = -1, 1, 2 do
			block(ctx, "CornerRoot_" .. tostring(xSide) .. "_" .. tostring(zSide), Vector3.new(xSide * 2.3, 0.38, zSide * 2.3), Vector3.new(0.82, 0.52, 2.35), woodDark, {
				CanCollide = false,
				Angles = Vector3.new(0, xSide * zSide * math.rad(45), 0),
			})
		end
	end

	local bodyCenter = Vector3.new(0, 1.92, 0)
	local bodySize = Vector3.new(3.85, 2.95, 3.85)

	block(ctx, "BodyCore", bodyCenter, bodySize, wood, {
		CanCollide = true,
	})

	local sidePanels = {
		{ "Front", Vector3.new(0, 1.9, -2.12), Vector3.new(3.35, 2.75, 0.56), woodDark:Lerp(wood, 0.3), nil },
		{ "Back", Vector3.new(0, 1.9, 2.12), Vector3.new(3.35, 2.75, 0.56), woodDark:Lerp(wood, 0.3), nil },
		{ "Left", Vector3.new(-2.12, 1.9, 0), Vector3.new(0.56, 2.75, 3.35), woodDark:Lerp(wood, 0.3), nil },
		{ "Right", Vector3.new(2.12, 1.9, 0), Vector3.new(0.56, 2.75, 3.35), woodDark:Lerp(wood, 0.3), nil },
		{ "CornerNW", Vector3.new(-1.68, 1.9, -1.68), Vector3.new(0.56, 2.65, 1.45), woodDark:Lerp(wood, 0.2), Vector3.new(0, math.rad(45), 0) },
		{ "CornerNE", Vector3.new(1.68, 1.9, -1.68), Vector3.new(0.56, 2.65, 1.45), woodDark:Lerp(wood, 0.2), Vector3.new(0, math.rad(-45), 0) },
		{ "CornerSW", Vector3.new(-1.68, 1.9, 1.68), Vector3.new(0.56, 2.65, 1.45), woodDark:Lerp(wood, 0.2), Vector3.new(0, math.rad(-45), 0) },
		{ "CornerSE", Vector3.new(1.68, 1.9, 1.68), Vector3.new(0.56, 2.65, 1.45), woodDark:Lerp(wood, 0.2), Vector3.new(0, math.rad(45), 0) },
	}

	for _, panel in ipairs(sidePanels) do
		block(ctx, "BodyPanel_" .. panel[1], panel[2], panel[3], panel[4], {
			CanCollide = false,
			Angles = panel[5],
		})
	end

	local buttresses = {
		{ "Front", Vector3.new(0, 1.35, -2.38), Vector3.new(1.05, 2.2, 0.54), Vector3.new(math.rad(-8), 0, 0) },
		{ "Back", Vector3.new(0, 1.35, 2.38), Vector3.new(1.05, 2.2, 0.54), Vector3.new(math.rad(8), 0, 0) },
		{ "Left", Vector3.new(-2.38, 1.35, 0), Vector3.new(0.54, 2.2, 1.05), Vector3.new(0, 0, math.rad(8)) },
		{ "Right", Vector3.new(2.38, 1.35, 0), Vector3.new(0.54, 2.2, 1.05), Vector3.new(0, 0, math.rad(-8)) },
	}

	for _, buttress in ipairs(buttresses) do
		block(ctx, "Buttress_" .. buttress[1], buttress[2], buttress[3], woodMid, {
			CanCollide = false,
			Angles = buttress[4],
		})
	end

	local barkMarks = {
		{ "FrontLeft", Vector3.new(-0.9, 1.9, -2.43), Vector3.new(0.36, 1.64, 0.16) },
		{ "FrontRight", Vector3.new(0.9, 1.9, -2.43), Vector3.new(0.36, 1.64, 0.16) },
		{ "BackLeft", Vector3.new(-0.9, 1.9, 2.43), Vector3.new(0.36, 1.64, 0.16) },
		{ "BackRight", Vector3.new(0.9, 1.9, 2.43), Vector3.new(0.36, 1.64, 0.16) },
		{ "LeftFront", Vector3.new(-2.43, 1.9, -0.9), Vector3.new(0.16, 1.64, 0.36) },
		{ "LeftBack", Vector3.new(-2.43, 1.9, 0.9), Vector3.new(0.16, 1.64, 0.36) },
		{ "RightFront", Vector3.new(2.43, 1.9, -0.9), Vector3.new(0.16, 1.64, 0.36) },
		{ "RightBack", Vector3.new(2.43, 1.9, 0.9), Vector3.new(0.16, 1.64, 0.36) },
	}

	for _, mark in ipairs(barkMarks) do
		block(ctx, "BarkPanel_" .. mark[1], mark[2], mark[3], groove, {
			CanCollide = false,
		})
	end

	local topCenter = Vector3.new(0, 3.55, 0)
	local topSize = Vector3.new(4.75, 0.32, 4.75)
	block(ctx, "CutSurface", topCenter, topSize, woodLight, {
		CanCollide = false,
	})

	local edgePieces = {
		{ "Front", Vector3.new(0, 3.76, -2.28), Vector3.new(4.25, 0.28, 0.42), woodMid, nil },
		{ "Back", Vector3.new(0, 3.76, 2.28), Vector3.new(4.25, 0.28, 0.42), woodMid, nil },
		{ "Left", Vector3.new(-2.28, 3.76, 0), Vector3.new(0.42, 0.28, 4.25), woodMid, nil },
		{ "Right", Vector3.new(2.28, 3.76, 0), Vector3.new(0.42, 0.28, 4.25), woodMid, nil },
		{ "CornerNW", Vector3.new(-1.76, 3.76, -1.76), Vector3.new(0.42, 0.28, 1.1), woodMid, Vector3.new(0, math.rad(45), 0) },
		{ "CornerNE", Vector3.new(1.76, 3.76, -1.76), Vector3.new(0.42, 0.28, 1.1), woodMid, Vector3.new(0, math.rad(-45), 0) },
		{ "CornerSW", Vector3.new(-1.76, 3.76, 1.76), Vector3.new(0.42, 0.28, 1.1), woodMid, Vector3.new(0, math.rad(-45), 0) },
		{ "CornerSE", Vector3.new(1.76, 3.76, 1.76), Vector3.new(0.42, 0.28, 1.1), woodMid, Vector3.new(0, math.rad(45), 0) },
	}

	for _, edge in ipairs(edgePieces) do
		block(ctx, "CutEdge_" .. edge[1], edge[2], edge[3], edge[4], {
			CanCollide = false,
			Angles = edge[5],
		})
	end

	local ringY = 3.96
	local rings = {
		{ "Outer", 3.45, 3.45, 0.2, woodMid:Lerp(groove, 0.24) },
		{ "Middle", 2.25, 2.25, 0.17, woodMid:Lerp(groove, 0.36) },
		{ "Inner", 1.08, 1.08, 0.14, groove:Lerp(woodLight, 0.26) },
	}

	for _, ring in ipairs(rings) do
		local name = ring[1]
		local width = ring[2]
		local depth = ring[3]
		local line = ring[4]
		local ringColor = ring[5]

		block(ctx, "AnnualRing_" .. name .. "_Front", Vector3.new(0, ringY, -depth / 2), Vector3.new(width, 0.12, line), ringColor, {
			CanCollide = false,
		})
		block(ctx, "AnnualRing_" .. name .. "_Back", Vector3.new(0, ringY, depth / 2), Vector3.new(width, 0.12, line), ringColor, {
			CanCollide = false,
		})
		block(ctx, "AnnualRing_" .. name .. "_Left", Vector3.new(-width / 2, ringY, 0), Vector3.new(line, 0.12, depth), ringColor, {
			CanCollide = false,
		})
		block(ctx, "AnnualRing_" .. name .. "_Right", Vector3.new(width / 2, ringY, 0), Vector3.new(line, 0.12, depth), ringColor, {
			CanCollide = false,
		})
	end

	block(ctx, "AnnualRing_Core", Vector3.new(0, ringY + 0.02, 0), Vector3.new(0.48, 0.12, 0.48), groove:Lerp(woodLight, 0.36), {
		CanCollide = false,
	})
end

local function buildFallenLog(ctx)
	local wood = color(ctx, "Wood", Color3.fromRGB(104, 70, 39))
	local woodDark = wood:Lerp(Color3.fromRGB(43, 29, 18), 0.34)
	local woodLight = wood:Lerp(Color3.fromRGB(255, 214, 142), 0.22)
	local segmentLength = 2.3

	for segment = -1, 1 do
		local segmentColor = if segment == 0 then wood else wood:Lerp(woodDark, 0.12)

		block(ctx, "BodySegment_" .. tostring(segment + 2), Vector3.new(segment * segmentLength, 0.94, 0), Vector3.new(segmentLength + 0.12, 1.48, 1.58), segmentColor, {
			CanCollide = true,
		})
	end

	for _, side in ipairs({ -1, 1 }) do
		local x = side * (segmentLength * 1.5 + 0.08)

		block(ctx, "Cap_" .. tostring(side), Vector3.new(x, 0.94, 0), Vector3.new(0.34, 1.72, 1.72), woodLight, {
			CanCollide = false,
		})
		block(ctx, "CapRingV_" .. tostring(side), Vector3.new(x + side * 0.19, 0.94, 0), Vector3.new(0.12, 1.04, 0.16), woodDark, {
			CanCollide = false,
		})
		block(ctx, "CapRingH_" .. tostring(side), Vector3.new(x + side * 0.2, 0.94, 0), Vector3.new(0.12, 0.16, 1.04), woodDark, {
			CanCollide = false,
		})
	end

	for index, x in ipairs({ -2.3, 0, 2.3 }) do
		block(ctx, "TopBark_" .. tostring(index), Vector3.new(x, 1.73, -0.08), Vector3.new(1.15, 0.16, 0.28), woodDark, {
			CanCollide = false,
		})
		block(ctx, "FrontBark_" .. tostring(index), Vector3.new(x, 0.9, -0.85), Vector3.new(1.42, 0.26, 0.14), woodDark, {
			CanCollide = false,
		})
	end

	for index, side in ipairs({ -1, 1 }) do
		block(ctx, "BranchBase_" .. tostring(index), Vector3.new(side * 1.25, 1.55, 0.78), Vector3.new(1.25, 0.38, 0.42), woodDark, {
			CanCollide = false,
			Angles = Vector3.new(0, side * math.rad(18), side * math.rad(10)),
		})
		block(ctx, "BranchTip_" .. tostring(index), Vector3.new(side * 1.82, 1.78, 1.02), Vector3.new(0.48, 0.34, 0.38), woodLight, {
			CanCollide = false,
			Angles = Vector3.new(0, side * math.rad(18), side * math.rad(10)),
		})
		block(ctx, "BackBranchBase_" .. tostring(index), Vector3.new(side * 1.25, 1.55, -0.78), Vector3.new(1.25, 0.38, 0.42), woodDark, {
			CanCollide = false,
			Angles = Vector3.new(0, side * math.rad(-18), side * math.rad(10)),
		})
		block(ctx, "BackBranchTip_" .. tostring(index), Vector3.new(side * 1.82, 1.78, -1.02), Vector3.new(0.48, 0.34, 0.38), woodLight, {
			CanCollide = false,
			Angles = Vector3.new(0, side * math.rad(-18), side * math.rad(10)),
		})
	end
end

local function buildSignPost(ctx)
	local wood = color(ctx, "Wood", Color3.fromRGB(104, 70, 39))
	local woodDark = wood:Lerp(Color3.fromRGB(43, 29, 18), 0.3)
	local woodLight = wood:Lerp(Color3.fromRGB(255, 214, 142), 0.2)
	local textColor = color(ctx, "Flower", Color3.fromRGB(255, 228, 102))
	local messageIndex = (((ctx.Index or 1) - 1) % #SIGN_MESSAGES) + 1
	local message = SIGN_MESSAGES[messageIndex]

	block(ctx, "Post", Vector3.new(0, 1.35, 0), Vector3.new(0.58, 2.7, 0.58), wood)
	block(ctx, "PostShadow", Vector3.new(0.12, 1.28, -0.32), Vector3.new(0.22, 2.2, 0.2), woodDark, {
		CanCollide = false,
	})
	block(ctx, "PostCap", Vector3.new(0, 2.78, 0), Vector3.new(0.88, 0.28, 0.88), woodDark, {
		CanCollide = false,
	})

	local board = block(ctx, "BoardFace", Vector3.new(0, 2.8, -0.48), Vector3.new(4.35, 1.25, 0.28), wood:Lerp(woodDark, 0.2), {
		CanCollide = false,
	})
	addSurfaceText(board, message, textColor)

	block(ctx, "BoardTopTrim", Vector3.new(0, 3.48, -0.48), Vector3.new(4.55, 0.22, 0.38), woodLight, {
		CanCollide = false,
	})
	block(ctx, "BoardBottomTrim", Vector3.new(0, 2.12, -0.48), Vector3.new(4.55, 0.22, 0.38), woodDark, {
		CanCollide = false,
	})
	block(ctx, "BoardLeftTrim", Vector3.new(-2.28, 2.8, -0.48), Vector3.new(0.22, 1.28, 0.38), woodDark, {
		CanCollide = false,
	})
	block(ctx, "BoardRightTrim", Vector3.new(2.28, 2.8, -0.48), Vector3.new(0.22, 1.28, 0.38), woodDark, {
		CanCollide = false,
	})

	for index, side in ipairs({ -1, 1 }) do
		block(ctx, "Brace_" .. tostring(index), Vector3.new(side * 0.92, 2.12, -0.18), Vector3.new(1.65, 0.22, 0.24), woodDark, {
			CanCollide = false,
			Angles = Vector3.new(0, 0, side * math.rad(18)),
		})
		block(ctx, "NailTop_" .. tostring(index), Vector3.new(side * 1.73, 3.18, -0.66), Vector3.new(0.26, 0.26, 0.12), woodDark, {
			CanCollide = false,
		})
		block(ctx, "NailBottom_" .. tostring(index), Vector3.new(side * 1.73, 2.43, -0.66), Vector3.new(0.26, 0.26, 0.12), woodDark, {
			CanCollide = false,
		})
	end
end

local function buildSmallFence(ctx)
	local wood = color(ctx, "Wood", Color3.fromRGB(104, 70, 39))
	local woodDark = wood:Lerp(Color3.fromRGB(43, 29, 18), 0.28)
	local leaf = color(ctx, "LeafShadow", Color3.fromRGB(44, 156, 58))

	for index, x in ipairs({ -2.4, 0, 2.4 }) do
		local postColor = if index == 2 then wood:Lerp(woodDark, 0.08) else wood

		block(ctx, "Post_" .. tostring(index), Vector3.new(x, 1.22, 0), Vector3.new(0.58, 2.45, 0.58), postColor)
		block(ctx, "PostCap_" .. tostring(index), Vector3.new(x, 2.58, 0), Vector3.new(0.82, 0.28, 0.82), woodDark, {
			CanCollide = false,
		})
		block(ctx, "PostNail_" .. tostring(index), Vector3.new(x, 1.82, -0.36), Vector3.new(0.24, 0.24, 0.12), woodDark, {
			CanCollide = false,
		})
		block(ctx, "BackPostNail_" .. tostring(index), Vector3.new(x, 1.82, 0.36), Vector3.new(0.24, 0.24, 0.12), woodDark, {
			CanCollide = false,
		})
	end

	block(ctx, "RailTop", Vector3.new(0, 1.82, -0.06), Vector3.new(5.6, 0.36, 0.36), wood)
	block(ctx, "RailBottom", Vector3.new(0, 1.08, 0.05), Vector3.new(5.35, 0.34, 0.34), woodDark)

	for index, side in ipairs({ -1, 1 }) do
		block(ctx, "CrossBrace_" .. tostring(index), Vector3.new(side * 0.62, 1.42, -0.2), Vector3.new(2.25, 0.24, 0.24), woodDark:Lerp(wood, 0.16), {
			CanCollide = false,
			Angles = Vector3.new(0, 0, side * math.rad(16)),
		})
		block(ctx, "BackCrossBrace_" .. tostring(index), Vector3.new(side * 0.62, 1.42, 0.2), Vector3.new(2.25, 0.24, 0.24), woodDark:Lerp(wood, 0.16), {
			CanCollide = false,
			Angles = Vector3.new(0, 0, side * math.rad(16)),
		})
		block(ctx, "GrassBase_" .. tostring(index), Vector3.new(side * 2.0, 0.42, -0.58), Vector3.new(0.34, 0.84, 0.28), leaf, {
			CanCollide = false,
		})
		block(ctx, "BackGrassBase_" .. tostring(index), Vector3.new(side * 2.0, 0.42, 0.58), Vector3.new(0.34, 0.84, 0.28), leaf, {
			CanCollide = false,
		})
	end
end

local function buildCrystalCluster(ctx)
	local accent = color(ctx, "Accent", Color3.fromRGB(103, 228, 255))
	local light = color(ctx, "Light", Color3.fromRGB(179, 255, 239))
	local stone = color(ctx, "Stone", Color3.fromRGB(115, 119, 120))
	local pieces = {
		{ "Base", Vector3.new(0, 0.24, 0), Vector3.new(5.1, 0.48, 4.1), stone, nil },
		{ "BaseLipFront", Vector3.new(0, 0.54, -1.82), Vector3.new(4.4, 0.22, 0.34), stone:Lerp(Color3.fromRGB(255, 255, 255), 0.08), nil },
		{ "BaseLipBack", Vector3.new(0, 0.54, 1.82), Vector3.new(4.4, 0.22, 0.34), stone:Lerp(Color3.fromRGB(255, 255, 255), 0.08), nil },
		{ "CenterShard", Vector3.new(0, 2.08, 0), Vector3.new(1.35, 3.2, 1.35), accent, Vector3.new(0, 0, math.rad(-4)) },
		{ "CenterCap", Vector3.new(0, 3.78, 0), Vector3.new(0.92, 0.48, 0.92), light, Vector3.new(0, 0, math.rad(-4)) },
		{ "LeftShard", Vector3.new(-1.42, 1.42, 0.26), Vector3.new(1.0, 2.1, 1.0), accent:Lerp(light, 0.25), Vector3.new(0, 0, math.rad(8)) },
		{ "RightShard", Vector3.new(1.42, 1.42, 0.26), Vector3.new(1.0, 2.1, 1.0), accent:Lerp(light, 0.25), Vector3.new(0, 0, math.rad(-8)) },
		{ "FrontShard", Vector3.new(0, 1.15, -1.28), Vector3.new(0.85, 1.55, 0.85), accent:Lerp(Color3.fromRGB(255, 255, 255), 0.16), Vector3.new(math.rad(8), 0, 0) },
		{ "BackShard", Vector3.new(0, 1.15, 1.28), Vector3.new(0.85, 1.55, 0.85), accent:Lerp(Color3.fromRGB(255, 255, 255), 0.16), Vector3.new(math.rad(-8), 0, 0) },
	}

	for _, piece in ipairs(pieces) do
		block(ctx, piece[1], piece[2], piece[3], piece[4], {
			CanCollide = false,
			Angles = piece[5],
		})
	end

	for index, side in ipairs({ -1, 1 }) do
		block(ctx, "CrystalChip_" .. tostring(index), Vector3.new(side * 2.12, 0.78, -0.82), Vector3.new(0.56, 0.7, 0.56), accent:Lerp(light, 0.12), {
			CanCollide = false,
			Angles = Vector3.new(0, side * math.rad(8), side * math.rad(6)),
		})
		block(ctx, "BackCrystalChip_" .. tostring(index), Vector3.new(side * 2.12, 0.78, 0.82), Vector3.new(0.56, 0.7, 0.56), accent:Lerp(light, 0.12), {
			CanCollide = false,
			Angles = Vector3.new(0, side * math.rad(-8), side * math.rad(6)),
		})
	end
end

local function buildRitualLamp(ctx)
	local stone = color(ctx, "Stone", Color3.fromRGB(115, 119, 120))
	local accent = color(ctx, "Accent", Color3.fromRGB(103, 228, 255))
	local light = color(ctx, "Light", Color3.fromRGB(179, 255, 239))

	block(ctx, "LampBase", Vector3.new(0, 0.35, 0), Vector3.new(2.6, 0.7, 2.6), stone)
	block(ctx, "LampPost", Vector3.new(0, 1.95, 0), Vector3.new(0.65, 3.2, 0.65), stone)
	block(ctx, "LampFrame", Vector3.new(0, 3.85, 0), Vector3.new(2.0, 1.35, 2.0), stone:Lerp(accent, 0.22), {
		CanCollide = false,
	})
	block(ctx, "LampCore", Vector3.new(0, 3.85, 0), Vector3.new(0.9, 0.9, 0.9), light, {
		CanCollide = false,
		Material = Enum.Material.Plastic,
		Transparency = 0.28,
	})
	block(ctx, "LampCap", Vector3.new(0, 4.75, 0), Vector3.new(2.4, 0.45, 2.4), accent:Lerp(stone, 0.35), {
		CanCollide = false,
	})
end

local function buildBrokenPillar(ctx)
	local stone = color(ctx, "Stone", Color3.fromRGB(115, 119, 120))
	local height = ctx.Rng:NextInteger(2, 4)

	for index = 1, height do
		block(ctx, "Pillar_" .. tostring(index), Vector3.new(
			ctx.Rng:NextNumber(-0.22, 0.22),
			0.55 + (index - 1) * 1.05,
			ctx.Rng:NextNumber(-0.22, 0.22)
		), Vector3.new(2.2, 1.05, 2.2), stone, {
			Angles = Vector3.new(ctx.Rng:NextNumber(-0.08, 0.08), ctx.Rng:NextNumber(-0.32, 0.32), ctx.Rng:NextNumber(-0.08, 0.08)),
		})
	end
end

local function buildBlockTree(ctx)
	local themeWood = color(ctx, "Wood", Color3.fromRGB(174, 88, 36))
	local trunk = themeWood:Lerp(Color3.fromRGB(219, 109, 43), 0.72)
	local trunkShade = trunk:Lerp(Color3.fromRGB(135, 68, 32), 0.18)
	local trunkLight = trunk:Lerp(Color3.fromRGB(255, 174, 76), 0.24)
	local leafTheme = color(ctx, "Leaf", Color3.fromRGB(92, 224, 60))
	local leafAccentTheme = color(ctx, "LeafAccent", Color3.fromRGB(154, 246, 74))
	local leafShadowTheme = color(ctx, "LeafShadow", Color3.fromRGB(52, 172, 60))
	local leafBase = leafTheme:Lerp(Color3.fromRGB(90, 229, 47), 0.48)
	local leafMid = leafAccentTheme:Lerp(Color3.fromRGB(150, 245, 54), 0.42)
	local leafTop = leafMid:Lerp(Color3.fromRGB(220, 255, 88), 0.22)
	local leafShade = leafShadowTheme:Lerp(leafBase, 0.5)
	local leafStud = leafTop:Lerp(Color3.fromRGB(255, 255, 140), 0.12)

	local function detail(name, offset, size, partColor)
		block(ctx, name, offset, size, partColor, {
			CanCollide = false,
		})
	end

	block(ctx, "Trunk", Vector3.new(0, 1.78, 0), Vector3.new(1.22, 3.56, 1.22), trunk, {
		CanCollide = true,
	})
	block(ctx, "TrunkBase", Vector3.new(0, 0.2, 0), Vector3.new(1.58, 0.4, 1.58), trunkShade:Lerp(trunk, 0.24), {
		CanCollide = true,
	})
	block(ctx, "TrunkNeck", Vector3.new(0.04, 3.18, -0.02), Vector3.new(1.02, 1.0, 1.02), trunkLight, {
		CanCollide = true,
	})

	local barkPanels = {
		{ "FrontLow", Vector3.new(-0.3, 1.02, -0.71), Vector3.new(0.24, 0.72, 0.12), trunkShade },
		{ "FrontHigh", Vector3.new(0.32, 2.22, -0.71), Vector3.new(0.22, 0.88, 0.12), trunkShade:Lerp(trunk, 0.12) },
		{ "RightMid", Vector3.new(0.71, 1.76, 0.26), Vector3.new(0.12, 0.86, 0.24), trunkShade },
		{ "LeftUpper", Vector3.new(-0.71, 2.62, -0.18), Vector3.new(0.12, 0.54, 0.22), trunkLight },
	}

	for _, panel in ipairs(barkPanels) do
		detail("Bark_" .. panel[1], panel[2], panel[3], panel[4])
	end

	local lowerCenter = Vector3.new(0, 3.72, 0)
	local lowerSize = Vector3.new(5.9, 0.95, 4.9)
	local middleCenter = Vector3.new(0.16, 4.42, -0.08)
	local middleSize = Vector3.new(4.7, 0.86, 3.75)
	local upperCenter = Vector3.new(-0.12, 5.06, 0.04)
	local upperSize = Vector3.new(3.35, 0.78, 2.7)
	local crownCenter = Vector3.new(0.08, 5.62, -0.04)
	local crownSize = Vector3.new(2.05, 0.62, 1.64)

	local canopy = {
		{ "LeafLower", lowerCenter, lowerSize, leafBase },
		{ "LeafMiddle", middleCenter, middleSize, leafMid },
		{ "LeafUpper", upperCenter, upperSize, leafTop },
		{ "LeafCrown", crownCenter, crownSize, leafTop:Lerp(Color3.fromRGB(255, 255, 255), 0.04) },
	}

	for _, leafPiece in ipairs(canopy) do
		detail(leafPiece[1], leafPiece[2], leafPiece[3], leafPiece[4])
	end

	local leafSteps = {
		{ "LowerFrontStep", Vector3.new(-0.82, 3.38, -2.64), Vector3.new(1.5, 0.5, 0.52), leafShade },
		{ "LowerLeftStep", Vector3.new(-3.04, 3.5, -0.62), Vector3.new(0.54, 0.58, 1.28), leafBase },
		{ "LowerRightStep", Vector3.new(2.94, 3.56, 0.74), Vector3.new(0.56, 0.56, 1.12), leafBase:Lerp(leafMid, 0.12) },
		{ "LowerBackStep", Vector3.new(0.94, 3.5, 2.56), Vector3.new(1.2, 0.5, 0.5), leafShade:Lerp(leafBase, 0.24) },
		{ "MiddleFrontStep", Vector3.new(0.82, 4.15, -2.02), Vector3.new(1.16, 0.44, 0.42), leafBase },
		{ "MiddleLeftStep", Vector3.new(-2.2, 4.18, 0.64), Vector3.new(0.44, 0.44, 0.86), leafMid },
		{ "UpperRightStep", Vector3.new(1.56, 4.88, -0.58), Vector3.new(0.42, 0.38, 0.64), leafTop },
	}

	for _, step in ipairs(leafSteps) do
		detail(step[1], step[2], step[3], step[4])
	end

	local undersideLeaves = {
		{ "CenterDrop", Vector3.new(0, 3.0, -0.04), Vector3.new(1.64, 0.48, 1.38), leafShade:Lerp(leafBase, 0.3) },
		{ "FrontDrop", Vector3.new(1.38, 3.02, -1.96), Vector3.new(0.7, 0.44, 0.56), leafShade },
		{ "LeftDrop", Vector3.new(-2.1, 3.06, 0.78), Vector3.new(0.54, 0.42, 0.76), leafBase },
		{ "BackDrop", Vector3.new(1.64, 3.08, 1.82), Vector3.new(0.66, 0.4, 0.52), leafShade:Lerp(leafBase, 0.18) },
	}

	for _, underside in ipairs(undersideLeaves) do
		detail("LeafUnderside_" .. underside[1], underside[2], underside[3], underside[4])
	end

	addFaceStuds(ctx, "TreeLowerStuds", lowerCenter, lowerSize, "Front", 4, 1, leafStud, Vector3.new(0.36, 0.3, 0.12))
	addFaceStuds(ctx, "TreeMiddleStuds", middleCenter, middleSize, "Front", 3, 1, leafStud, Vector3.new(0.32, 0.28, 0.12))
	addTopStuds(ctx, "TreeCrownStuds", crownCenter, crownSize, 2, 1, leafStud, Vector3.new(0.34, 0.12, 0.34))
end

local function buildPineTree(ctx)
	local wood = color(ctx, "Wood", Color3.fromRGB(104, 70, 39))
	local leaf = color(ctx, "Leaf", Color3.fromRGB(130, 245, 226))
	local leafAccent = color(ctx, "LeafAccent", Color3.fromRGB(204, 255, 244))
	local trunkHeight = ctx.Rng:NextNumber(5.8, 7.4)

	block(ctx, "Trunk", Vector3.new(0, trunkHeight / 2, 0), Vector3.new(1.6, trunkHeight, 1.6), wood, {
		CanCollide = true,
	})

	for tier = 1, 4 do
		local width = 8.0 - tier * 1.25
		local height = 1.5
		local y = trunkHeight + tier * 1.05

		block(ctx, "SnowTier_" .. tostring(tier), Vector3.new(0, y, 0), Vector3.new(width, height, width), if tier % 2 == 0 then leafAccent else leaf, {
			CanCollide = false,
			Angles = Vector3.new(0, ctx.Rng:NextNumber(-0.28, 0.28), 0),
		})
	end
end

local function buildCactus(ctx)
	local cactus = color(ctx, "Cactus", color(ctx, "LeafShadow", Color3.fromRGB(64, 169, 82)))
	local accent = color(ctx, "LeafAccent", Color3.fromRGB(142, 245, 83))
	local height = ctx.Rng:NextNumber(6.8, 9.4)

	block(ctx, "CactusBody", Vector3.new(0, height / 2, 0), Vector3.new(2.0, height, 2.0), cactus, {
		CanCollide = true,
	})

	for sideIndex, side in ipairs({ -1, 1 }) do
		local armHeight = ctx.Rng:NextNumber(2.2, 3.4)
		local armY = height * ctx.Rng:NextNumber(0.48, 0.68)

		block(ctx, "CactusArmStem_" .. tostring(sideIndex), Vector3.new(side * 1.65, armY, 0), Vector3.new(2.6, 1.2, 1.2), cactus, {
			Angles = Vector3.new(0, 0, side * math.rad(6)),
		})
		block(ctx, "CactusArmUp_" .. tostring(sideIndex), Vector3.new(side * 2.8, armY + armHeight / 2, 0), Vector3.new(1.2, armHeight, 1.2), cactus)
	end

	block(ctx, "CactusGlow", Vector3.new(0, height + 0.4, 0), Vector3.new(1.2, 0.5, 1.2), accent, {
		CanCollide = false,
		Material = Enum.Material.Plastic,
		Transparency = 0.18,
	})
end

local function buildAnimalSkull(ctx)
	local bone = color(ctx, "Bone", Color3.fromRGB(226, 202, 171))
	local boneShadow = bone:Lerp(Color3.fromRGB(92, 66, 58), 0.22)
	local dark = color(ctx, "Void", Color3.fromRGB(12, 10, 16))

	block(ctx, "SkullCranium", Vector3.new(0, 2.55, 0), Vector3.new(6.8, 4.1, 4.6), bone, {
		Angles = Vector3.new(ctx.Rng:NextNumber(-0.08, 0.08), ctx.Rng:NextNumber(-0.12, 0.12), ctx.Rng:NextNumber(-0.06, 0.06)),
	})
	block(ctx, "SkullSnout", Vector3.new(0, 1.65, -3.4), Vector3.new(4.2, 2.2, 2.6), boneShadow)
	block(ctx, "SkullJaw", Vector3.new(0, 0.72, -2.8), Vector3.new(5.8, 0.8, 2.4), bone)
	block(ctx, "MouthVoid", Vector3.new(0, 1.05, -4.22), Vector3.new(4.9, 0.65, 0.34), dark, {
		CanCollide = false,
		Material = Enum.Material.Plastic,
	})

	for sideIndex, side in ipairs({ -1, 1 }) do
		block(ctx, "Eye_" .. tostring(sideIndex), Vector3.new(side * 1.75, 2.55, -2.42), Vector3.new(1.2, 1.45, 0.42), dark, {
			CanCollide = false,
		})
		block(ctx, "Nostril_" .. tostring(sideIndex), Vector3.new(side * 0.75, 1.64, -4.75), Vector3.new(0.72, 0.82, 0.36), dark, {
			CanCollide = false,
		})

		for hornIndex = 1, 5 do
			local hornSize = Vector3.new(1.25 - hornIndex * 0.08, 1.0, 1.25 - hornIndex * 0.08)
			local hornOffset = Vector3.new(
				side * (2.2 + hornIndex * 0.58),
				4.0 + hornIndex * 0.42,
				0.2 + hornIndex * 0.16
			)

			block(ctx, "Horn_" .. tostring(sideIndex) .. "_" .. tostring(hornIndex), hornOffset, hornSize, bone, {
				Angles = Vector3.new(math.rad(-8 + hornIndex * 3), 0, side * math.rad(20 + hornIndex * 5)),
			})
		end
	end

	for tooth = 1, 5 do
		block(ctx, "Tooth_" .. tostring(tooth), Vector3.new(-2 + tooth, 0.25, -4.0), Vector3.new(0.35, 0.7, 0.35), bone, {
			CanCollide = false,
		})
	end
end

local definitions = {
	Grass = {
		Footprint = 3,
		Build = buildGrass,
	},
	Bush = {
		Footprint = 5,
		Build = buildBush,
	},
	FlowerClump = {
		Footprint = 3,
		Build = buildFlowerClump,
	},
	Rock = {
		Footprint = 4,
		Build = buildRock,
	},
	PathPebbles = {
		Footprint = 3,
		Build = buildPathPebbles,
	},
	RockCluster = {
		Footprint = 6,
		Build = buildRockCluster,
	},
	OreVein = {
		Footprint = 6,
		Build = buildOreVein,
	},
	CrystalCluster = {
		Footprint = 5,
		Build = buildCrystalCluster,
	},
	RitualLamp = {
		Footprint = 4,
		Build = buildRitualLamp,
	},
	BrokenPillar = {
		Footprint = 5,
		Build = buildBrokenPillar,
	},
	TreeStump = {
		Footprint = 8,
		Build = buildTreeStump,
	},
	FallenLog = {
		Footprint = 8,
		Build = buildFallenLog,
	},
	SignPost = {
		Footprint = 4,
		Build = buildSignPost,
	},
	SmallFence = {
		Footprint = 6,
		Build = buildSmallFence,
	},
	BlockTree = {
		Footprint = 10,
		Build = buildBlockTree,
	},
	PineTree = {
		Footprint = 9,
		Build = buildPineTree,
	},
	Cactus = {
		Footprint = 8,
		Build = buildCactus,
	},
	AnimalSkull = {
		Footprint = 11,
		Build = buildAnimalSkull,
	},
	CrystalGrass = {
		Footprint = 3,
		Build = function(ctx)
			withScale(ctx, 0.72, buildGrass)
		end,
	},
	CrystalRock = {
		Footprint = 4,
		Build = function(ctx)
			withScale(ctx, 0.66, buildRock)
		end,
	},
}

PropDefinitions.Order = {
	"Grass",
	"Bush",
	"FlowerClump",
	"Rock",
	"PathPebbles",
	"RockCluster",
	"OreVein",
	"CrystalCluster",
	"CrystalGrass",
	"CrystalRock",
	"RitualLamp",
	"BrokenPillar",
	"TreeStump",
	"FallenLog",
	"SignPost",
	"SmallFence",
	"BlockTree",
	"PineTree",
	"Cactus",
	"AnimalSkull",
}

PropDefinitions.BigOrder = {
	"BlockTree",
	"PineTree",
	"Cactus",
	"AnimalSkull",
	"BrokenPillar",
}

function PropDefinitions.get(propType)
	return definitions[propType]
end

function PropDefinitions.getFootprint(propType)
	local definition = definitions[propType]

	return if definition ~= nil then definition.Footprint or 4 else 4
end

function PropDefinitions.pickWeighted(rng, weights, fallback, order)
	if typeof(weights) ~= "table" then
		return fallback
	end

	local orderedTypes = order or PropDefinitions.Order
	local totalWeight = 0

	for _, propType in ipairs(orderedTypes) do
		local weight = weights[propType]

		if typeof(weight) == "number" and weight > 0 and definitions[propType] ~= nil then
			totalWeight += weight
		end
	end

	if totalWeight <= 0 then
		return fallback
	end

	local roll = rng:NextNumber(0, totalWeight)
	local runningWeight = 0

	for _, propType in ipairs(orderedTypes) do
		local weight = weights[propType]

		if typeof(weight) == "number" and weight > 0 and definitions[propType] ~= nil then
			runningWeight += weight

			if roll <= runningWeight then
				return propType
			end
		end
	end

	return fallback
end

function PropDefinitions.build(propType, parent, plan, zonePlan, position, rng, index, options)
	local definition = definitions[propType] or definitions.RockCluster
	local safeOptions = options or {}
	local yaw = if typeof(safeOptions.Yaw) == "number" then safeOptions.Yaw else rng:NextNumber(0, math.pi * 2)
	local scale = if typeof(safeOptions.Scale) == "number" then safeOptions.Scale else 1
	local ctx = {
		Frame = CFrame.new(position.X, Util.getZoneTopY(plan), position.Z) * CFrame.Angles(0, yaw, 0),
		Index = index,
		NamePrefix = tostring(propType) .. "_" .. tostring(index),
		Parent = parent,
		Plan = plan,
		Position = position,
		Rng = rng,
		Scale = scale,
		ZonePlan = zonePlan,
	}

	definition.Build(ctx)
end

return PropDefinitions
