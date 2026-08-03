local Util = require(script.Parent:WaitForChild("BlockWriterUtil"))

local ZoneStructureWriter = {}

local function createPad(parent, plan, zonePlan, name, position, color, size, options)
	local sections = plan.Preset.Sections
	local topY = Util.getZoneTopY(plan)
	local safeOptions = options or {}
	local pad = Util.createPart(parent, plan, zonePlan.ZoneId, "Pad", name, {
		CanCollide = false,
		Color = color,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(size.X, sections.PadThickness, size.Z),
		Position = Vector3.new(position.X, topY + sections.PadThickness / 2 + 0.02, position.Z),
		Transparency = if safeOptions.Transparency ~= nil then safeOptions.Transparency else 0.12,
	})

	pad.TopSurface = Enum.SurfaceType.Studs
	pad.BottomSurface = Enum.SurfaceType.Smooth

	return pad
end

local function createAreaMarker(parent, plan, zonePlan, name, center, size, color)
	local topY = Util.getZoneTopY(plan)
	local marker = Util.createPart(parent, plan, zonePlan.ZoneId, "AreaMarker", name, {
		CanCollide = false,
		CanQuery = false,
		Color = color,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(size.X, 0.12, size.Z),
		Position = Vector3.new(center.X, topY + 0.07, center.Z),
		Transparency = 0.74,
	})

	marker.TopSurface = Enum.SurfaceType.Studs
	marker.BottomSurface = Enum.SurfaceType.Smooth

	return marker
end

local function getFacingYaw(facing)
	if facing == "East" then
		return math.rad(90)
	elseif facing == "West" then
		return math.rad(-90)
	elseif facing == "North" then
		return math.rad(180)
	end

	return 0
end

local function offsetFrame(baseFrame, offset)
	return baseFrame * CFrame.new(offset.X, offset.Y, offset.Z)
end

local function createFeaturePart(parent, plan, zonePlan, name, properties)
	local part = Util.createPart(parent, plan, zonePlan.ZoneId, "Feature", name, properties)

	Util.setStudSurfaces(part)

	return part
end

local function createLeaderboardFeature(model, plan, zonePlan, slot, frame)
	local theme = zonePlan.Theme
	local stone = Util.getColor(theme, "Stone", Color3.fromRGB(115, 119, 120))
	local accent = Util.getColor(theme, "Accent", Color3.fromRGB(103, 228, 255))
	local panelColor = Util.getColor(theme, "BlockSideAlt", Color3.fromRGB(60, 55, 70))

	createFeaturePart(model, plan, zonePlan, "Leaderboard_LeftPost", {
		Color = stone,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(1.4, 10, 1.4),
		CFrame = offsetFrame(frame, Vector3.new(-8.5, 5, 0.6)),
	})
	createFeaturePart(model, plan, zonePlan, "Leaderboard_RightPost", {
		Color = stone,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(1.4, 10, 1.4),
		CFrame = offsetFrame(frame, Vector3.new(8.5, 5, 0.6)),
	})
	createFeaturePart(model, plan, zonePlan, "Leaderboard_Panel", {
		Color = panelColor,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(18, 8.5, 1),
		CFrame = offsetFrame(frame, Vector3.new(0, 7.1, 0)),
	})
	createFeaturePart(model, plan, zonePlan, "Leaderboard_Header", {
		CanCollide = false,
		Color = accent,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(16, 1, 0.42),
		CFrame = offsetFrame(frame, Vector3.new(0, 10.4, -0.72)),
	})
end

local function createNpcFeature(model, plan, zonePlan, slot, frame)
	local theme = zonePlan.Theme
	local cloth = Util.getColor(theme, "Accent", Color3.fromRGB(103, 228, 255))
	local stone = Util.getColor(theme, "Stone", Color3.fromRGB(115, 119, 120))
	local light = Util.getColor(theme, "Light", Color3.fromRGB(179, 255, 239))

	createFeaturePart(model, plan, zonePlan, "NpcPedestal", {
		Color = stone,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(5.5, 1.2, 5.5),
		CFrame = offsetFrame(frame, Vector3.new(0, 0.6, 0)),
	})
	createFeaturePart(model, plan, zonePlan, "NpcBody", {
		Color = cloth,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(2.2, 3.2, 1.4),
		CFrame = offsetFrame(frame, Vector3.new(0, 3.2, 0)),
	})
	createFeaturePart(model, plan, zonePlan, "NpcHead", {
		Color = light,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = offsetFrame(frame, Vector3.new(0, 5.7, 0)),
	})
end

local function createEggShopFeature(model, plan, zonePlan, slot, frame)
	local theme = zonePlan.Theme
	local accent = Util.getColor(theme, "Accent", Color3.fromRGB(103, 228, 255))
	local light = Util.getColor(theme, "Light", Color3.fromRGB(179, 255, 239))
	local stone = Util.getColor(theme, "Stone", Color3.fromRGB(115, 119, 120))

	createFeaturePart(model, plan, zonePlan, "EggShop_Base", {
		Color = stone,
		Material = Enum.Material.Plastic,
		Size = Vector3.new(15, 1, 5),
		CFrame = offsetFrame(frame, Vector3.new(0, 0.5, 0)),
	})

	for index, x in ipairs({ -5, 0, 5 }) do
		local egg = createFeaturePart(model, plan, zonePlan, "Egg_" .. tostring(index), {
			CanCollide = false,
			Color = if index == 2 then light else accent,
			Material = Enum.Material.Plastic,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.8, 4.2, 2.8),
			CFrame = offsetFrame(frame, Vector3.new(x, 3.1, 0)),
			Transparency = 0,
		})

		egg.BottomSurface = Enum.SurfaceType.Smooth
	end
end

local FEATURE_BUILDERS = {
	Leaderboard = createLeaderboardFeature,
	Npc = createNpcFeature,
	EggShop = createEggShopFeature,
}

local function createFeatureSlot(parent, plan, zonePlan, slot)
	local model = Util.createModel(parent, plan, zonePlan.ZoneId, "Feature", "Feature_" .. tostring(slot.Id))
	local topY = Util.getZoneTopY(plan)
	local size = slot.Size or Vector3.new(12, 0, 12)
	local position = slot.Position
	local frame = CFrame.new(position.X, topY, position.Z) * CFrame.Angles(0, getFacingYaw(slot.Facing), 0)
	local builder = FEATURE_BUILDERS[slot.Type]

	model:SetAttribute("FeatureId", slot.Id)
	model:SetAttribute("FeatureType", slot.Type)
	createPad(model, plan, zonePlan, "FeaturePad", position, Util.getColor(zonePlan.Theme, "BlockTopAlt", Color3.fromRGB(106, 213, 57)), size, {
		Transparency = 0.34,
	})

	if builder ~= nil then
		builder(model, plan, zonePlan, slot, frame)
	end
end

function ZoneStructureWriter.createZoneStructures(plan, zonePlan, structuresFolder)
	local theme = zonePlan.Theme
	local light = Util.getColor(theme, "Light", Color3.fromRGB(179, 255, 239))

	if zonePlan.PlayerSpawnPosition ~= nil then
		createPad(structuresFolder, plan, zonePlan, "SpawnPad", zonePlan.PlayerSpawnPosition, Color3.fromRGB(120, 226, 255), Vector3.new(11, 0, 11))
	end

	if zonePlan.CrystalArea ~= nil then
		createAreaMarker(structuresFolder, plan, zonePlan, "CrystalArea", zonePlan.CrystalArea.Center, zonePlan.CrystalArea.Size, Util.getColor(theme, "BlockTopAlt", Color3.fromRGB(106, 213, 57)))
	end

	if zonePlan.AscensionPosition ~= nil then
		createPad(structuresFolder, plan, zonePlan, "AscensionPad", zonePlan.AscensionPosition, light, Vector3.new(14, 0, 14))
	end

	for _, slot in ipairs(zonePlan.FeatureSlots or {}) do
		createFeatureSlot(structuresFolder, plan, zonePlan, slot)
	end
end

return ZoneStructureWriter
