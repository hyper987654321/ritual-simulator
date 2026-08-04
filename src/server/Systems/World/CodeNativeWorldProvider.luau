local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local RitualWorldContract = require(Shared:WaitForChild("World"):WaitForChild("RitualWorldContract"))

local CodeNativeWorldProvider = {}

local FLOOR_THICKNESS = 1
local WALL_THICKNESS = 2
local WALL_HEIGHT = 6
local MARKER_SIZE = Vector3.new(1, 1, 1)

local function makeFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function makePart(parent, name, cframe, size, properties)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CFrame = cframe
	part.Size = size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for property, value in pairs(properties or {}) do
		part[property] = value
	end
	part.Parent = parent
	return part
end

local function makeMarker(parent, name, cframe)
	return makePart(parent, name, cframe, MARKER_SIZE, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
end

local function getVolumeCFrame(center, height)
	return CFrame.new(center.X, center.Y + height / 2, center.Z)
end

local function makeHorizontalPerimeter(collision, name, center, width, isOpen)
	if not isOpen then
		makePart(collision, name, CFrame.new(center), Vector3.new(width, WALL_HEIGHT, WALL_THICKNESS), { CanTouch = false })
		return
	end

	local openingWidth = 20
	local segmentWidth = (width - openingWidth) / 2
	assert(segmentWidth > 0, "zone perimeter is too narrow for connector opening")
	local segmentOffset = openingWidth / 2 + segmentWidth / 2
	makePart(collision, name .. "West", CFrame.new(center + Vector3.new(-segmentOffset, 0, 0)), Vector3.new(segmentWidth, WALL_HEIGHT, WALL_THICKNESS), { CanTouch = false })
	makePart(collision, name .. "East", CFrame.new(center + Vector3.new(segmentOffset, 0, 0)), Vector3.new(segmentWidth, WALL_HEIGHT, WALL_THICKNESS), { CanTouch = false })
end

local function buildZone(root, zoneId, zonesRoot, anchorsRoot)
	local definition = ZoneConfig.getZone(zoneId)
	local bounds = ZoneConfig.getZoneBounds(zoneId)
	local crystalArea = ZoneConfig.getCrystalArea(zoneId)
	assert(definition ~= nil and bounds ~= nil and crystalArea ~= nil, "ZoneConfig is incomplete")

	local zone = makeFolder(zonesRoot, "Zone_" .. tostring(zoneId))
	local collision = makeFolder(zone, "Collision")
	local visual = makeFolder(zone, "Visual")
	local anchors = makeFolder(anchorsRoot, "Zone_" .. tostring(zoneId))
	local originY = definition.Origin.Y
	local floorCenter = Vector3.new(bounds.Center.X, originY - FLOOR_THICKNESS / 2, bounds.Center.Z)

	makePart(collision, "Floor", CFrame.new(floorCenter), Vector3.new(bounds.Size.X, FLOOR_THICKNESS, bounds.Size.Z), {
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(52, 57, 74),
		CanTouch = false,
	})
	local wallY = originY + WALL_HEIGHT / 2
	local halfX = bounds.Size.X / 2
	local halfZ = bounds.Size.Z / 2
	makeHorizontalPerimeter(collision, "PerimeterNorth", Vector3.new(bounds.Center.X, wallY, bounds.Center.Z - halfZ), bounds.Size.X, zoneId > 1)
	makeHorizontalPerimeter(collision, "PerimeterSouth", Vector3.new(bounds.Center.X, wallY, bounds.Center.Z + halfZ), bounds.Size.X, zoneId < RitualWorldContract.ZoneCount)
	makePart(collision, "PerimeterEast", CFrame.new(bounds.Center.X + halfX, wallY, bounds.Center.Z), Vector3.new(WALL_THICKNESS, WALL_HEIGHT, bounds.Size.Z), { CanTouch = false })
	makePart(collision, "PerimeterWest", CFrame.new(bounds.Center.X - halfX, wallY, bounds.Center.Z), Vector3.new(WALL_THICKNESS, WALL_HEIGHT, bounds.Size.Z), { CanTouch = false })

	local nextBounds = ZoneConfig.getZoneBounds(zoneId + 1)
	if nextBounds ~= nil then
		local gap = nextBounds.Center.Z - bounds.Center.Z
		local connectorCenter = Vector3.new(bounds.Center.X, originY - FLOOR_THICKNESS / 2, (bounds.Center.Z + nextBounds.Center.Z) / 2)
		makePart(collision, "ConnectorToNext", CFrame.new(connectorCenter), Vector3.new(20, FLOOR_THICKNESS, math.max(1, math.abs(gap) - bounds.Size.Z / 2 - nextBounds.Size.Z / 2)), { CanTouch = false })
	end

	makePart(visual, "ZoneVisual", CFrame.new(bounds.Center.X, originY + 0.5, bounds.Center.Z), Vector3.new(bounds.Size.X - 4, 1, bounds.Size.Z - 4), {
		Material = Enum.Material.Slate,
		Color = definition.CrystalColor,
		Transparency = 0.8,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	local boundsSize = Vector3.new(bounds.Size.X, 8, bounds.Size.Z)
	local crystalAreaSize = Vector3.new(crystalArea.Size.X, 8, crystalArea.Size.Z)
	makeMarker(anchors, "ZoneBounds", getVolumeCFrame(bounds.Center, boundsSize.Y)).Size = boundsSize
	makeMarker(anchors, "CrystalArea", getVolumeCFrame(crystalArea.Center, crystalAreaSize.Y)).Size = crystalAreaSize
	makeMarker(anchors, "Teleport", CFrame.new(ZoneConfig.getTeleportPosition(zoneId)))
	for crystalId = 1, 5 do
		local angle = (crystalId - 1) * math.pi * 2 / 5
		local radiusX = math.max(2, crystalArea.Size.X / 2 - definition.CrystalSpawnPadding)
		local radiusZ = math.max(2, crystalArea.Size.Z / 2 - definition.CrystalSpawnPadding)
		local position = Vector3.new(crystalArea.Center.X + math.cos(angle) * radiusX, originY + definition.CrystalSpawnHeight, crystalArea.Center.Z + math.sin(angle) * radiusZ)
		makeMarker(anchors, "Crystal_" .. tostring(crystalId), CFrame.new(position))
	end

	if zoneId == 1 then
		makeMarker(anchors, "Spawn", CFrame.new(ZoneConfig.getSpawnPosition(zoneId)))
	end
	if zoneId >= 2 then
		local wall = ZoneConfig.getUnlockWall(zoneId)
		assert(wall ~= nil, "ZoneConfig is missing an unlock wall")
		makeMarker(anchors, "UnlockWall", CFrame.new(wall.Center))
	end
	if zoneId == 5 or zoneId == 10 or zoneId == 15 then
		makeMarker(anchors, "AscensionStatue", CFrame.new(bounds.Center + Vector3.new(0, 2, bounds.Size.Z / 2 - 14)))
	end
	for _, feature in ipairs(ZoneConfig.getZoneMapFeatures(zoneId)) do
		local featureId = tostring(feature.Id or feature.Type)
		local position = bounds.Center + (feature.Offset or Vector3.zero) + Vector3.new(0, 2, 0)
		makeMarker(anchors, "Feature_" .. featureId, CFrame.new(position))
	end
end

function CodeNativeWorldProvider.build(parent, name)
	assert(parent ~= nil and parent:IsA("Instance"), "parent must be an Instance")
	local rootName = name or "RitualWorld"
	local existing = parent:FindFirstChild(rootName)
	if existing ~= nil then
		local valid, errors = RitualWorldContract.validate(existing)
		assert(valid, "existing world is not a valid RitualWorld: " .. table.concat(errors, "; "))
		return existing
	end

	local root = makeFolder(parent, rootName)
	local metadata = makeFolder(root, "Metadata")
	metadata:SetAttribute("ContractVersion", RitualWorldContract.ContractVersion)
	metadata:SetAttribute("LayoutId", RitualWorldContract.LayoutId)
	metadata:SetAttribute("ZoneCount", RitualWorldContract.ZoneCount)
	metadata:SetAttribute("ContentKind", RitualWorldContract.ContentKind)
	local zones = makeFolder(root, "Zones")
	local anchors = makeFolder(root, "Anchors")
	for zoneId = 1, RitualWorldContract.ZoneCount do
		buildZone(root, zoneId, zones, anchors)
	end

	local valid, errors = RitualWorldContract.validate(root)
	assert(valid, "built RitualWorld is invalid: " .. table.concat(errors, "; "))
	return root
end

CodeNativeWorldProvider.Contract = RitualWorldContract

return CodeNativeWorldProvider
