local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local MapGenConfig = require(script.Parent:WaitForChild("MapGenConfig"))

local GeneratedMapRuntime = {}

local TELEPORT_HEIGHT_OFFSET = 3
local CRYSTAL_HEIGHT_OFFSET = 2
local OFFSET_MATCH_TOLERANCE = 1

local function getRoot()
	return Workspace:FindFirstChild(MapGenConfig.OutputFolderName)
end

local function getZoneAnchorFolder(zoneId)
	local root = getRoot()

	if root == nil then
		return nil
	end

	local anchorsFolder = root:FindFirstChild("Anchors")

	if anchorsFolder == nil then
		return nil
	end

	local zoneFolder = anchorsFolder:FindFirstChild("Zone_" .. tostring(zoneId))

	if zoneFolder == nil then
		return nil
	end

	return zoneFolder
end

local function getAnchorPart(zoneId, anchorName)
	local zoneFolder = getZoneAnchorFolder(zoneId)

	if zoneFolder == nil then
		return nil
	end

	local anchor = zoneFolder:FindFirstChild(anchorName)

	if anchor ~= nil and anchor:IsA("BasePart") then
		return anchor
	end

	return nil
end

local function getZoneFloorPart(zoneId)
	local root = getRoot()

	if root == nil then
		return nil
	end

	local zonesFolder = root:FindFirstChild("Zones")
	local zoneFolder = if zonesFolder ~= nil then zonesFolder:FindFirstChild("Zone_" .. tostring(zoneId)) else nil
	local blocksFolder = if zoneFolder ~= nil then zoneFolder:FindFirstChild("Blocks") else nil
	local floor = if blocksFolder ~= nil then blocksFolder:FindFirstChild("SectionFloor") else nil

	if floor ~= nil and floor:IsA("BasePart") then
		return floor
	end

	return nil
end

local function getAnchorPosition(zoneId, anchorName)
	local anchor = getAnchorPart(zoneId, anchorName)

	return if anchor ~= nil then anchor.Position else nil
end

local function getAnchorOffset(zoneId)
	local anchorPosition = getAnchorPosition(zoneId, "Teleport") or getAnchorPosition(zoneId, "Spawn")

	if anchorPosition == nil then
		return nil
	end

	local fallbackPosition = ZoneConfig.getTeleportPosition(zoneId)

	return Vector3.new(anchorPosition.X - fallbackPosition.X, 0, anchorPosition.Z - fallbackPosition.Z)
end

local function getFloorOffset(zoneId)
	local floor = getZoneFloorPart(zoneId)
	local bounds = ZoneConfig.getZoneBounds(zoneId)

	if floor == nil or bounds == nil then
		return nil
	end

	return Vector3.new(floor.Position.X - bounds.Center.X, 0, floor.Position.Z - bounds.Center.Z)
end

local function getZoneOffsetInfo(zoneId)
	local anchorOffset = getAnchorOffset(zoneId)
	local floorOffset = getFloorOffset(zoneId)

	if anchorOffset ~= nil and floorOffset ~= nil then
		if (anchorOffset - floorOffset).Magnitude <= OFFSET_MATCH_TOLERANCE then
			return anchorOffset, "Anchor"
		end

		return floorOffset, "Floor"
	end

	if anchorOffset ~= nil then
		return anchorOffset, "Anchor"
	end

	if floorOffset ~= nil then
		return floorOffset, "Floor"
	end

	return nil, nil
end

local function getZoneOffset(zoneId)
	local offset = getZoneOffsetInfo(zoneId)

	return offset
end

local function shouldUseAnchorPosition(zoneId)
	local _, source = getZoneOffsetInfo(zoneId)

	return source == "Anchor"
end

local function offsetPosition(zoneId, position)
	if typeof(position) ~= "Vector3" then
		return nil
	end

	local offset = getZoneOffset(zoneId)

	return if offset ~= nil then position + offset else position
end

function GeneratedMapRuntime.hasGeneratedMap()
	return getRoot() ~= nil
end

function GeneratedMapRuntime.getRuntimePosition(zoneId, fallbackPosition)
	return offsetPosition(zoneId, fallbackPosition)
end

function GeneratedMapRuntime.getTeleportPosition(zoneId)
	local anchorPosition = if shouldUseAnchorPosition(zoneId)
		then getAnchorPosition(zoneId, "Teleport") or getAnchorPosition(zoneId, "Spawn")
		else nil

	if anchorPosition ~= nil then
		return anchorPosition + Vector3.new(0, TELEPORT_HEIGHT_OFFSET, 0)
	end

	return ZoneConfig.getTeleportPosition(zoneId)
end

function GeneratedMapRuntime.getTeleportCFrame(zoneId)
	local teleportPosition = GeneratedMapRuntime.getTeleportPosition(zoneId)
	local crystalArea = GeneratedMapRuntime.getCrystalArea(zoneId)
	local lookAtPosition = if crystalArea ~= nil
		then Vector3.new(crystalArea.Center.X, teleportPosition.Y, crystalArea.Center.Z)
		else teleportPosition + Vector3.new(0, 0, -1)

	return CFrame.lookAt(teleportPosition, lookAtPosition)
end

function GeneratedMapRuntime.getZoneBounds(zoneId)
	local bounds = ZoneConfig.getZoneBounds(zoneId)

	if bounds == nil then
		return nil
	end

	return {
		Center = offsetPosition(zoneId, bounds.Center) or bounds.Center,
		Size = bounds.Size,
	}
end

function GeneratedMapRuntime.isPositionInsideBounds(zoneId, position)
	if typeof(position) ~= "Vector3" then
		return false
	end

	local bounds = GeneratedMapRuntime.getZoneBounds(zoneId)

	if bounds == nil then
		return false
	end

	local halfSize = bounds.Size / 2
	local delta = position - bounds.Center
	local isInsideY = bounds.Size.Y <= 0 or math.abs(delta.Y) <= halfSize.Y

	return math.abs(delta.X) <= halfSize.X and isInsideY and math.abs(delta.Z) <= halfSize.Z
end

function GeneratedMapRuntime.getZoneIdForPosition(position)
	for _, zoneId in ipairs(ZoneConfig.getZoneIds()) do
		if GeneratedMapRuntime.isPositionInsideBounds(zoneId, position) then
			return zoneId
		end
	end

	return nil
end

function GeneratedMapRuntime.getCrystalArea(zoneId)
	local area = ZoneConfig.getCrystalArea(zoneId)

	if area == nil then
		return nil
	end

	return {
		Center = offsetPosition(zoneId, area.Center) or area.Center,
		Size = area.Size,
	}
end

function GeneratedMapRuntime.isPositionInsideCrystalArea(zoneId, position, margin)
	if typeof(position) ~= "Vector3" then
		return false
	end

	local area = GeneratedMapRuntime.getCrystalArea(zoneId)

	if area == nil then
		return false
	end

	local safeMargin = margin or 0
	local halfSize = area.Size / 2
	local delta = position - area.Center

	return math.abs(delta.X) <= halfSize.X + safeMargin and math.abs(delta.Z) <= halfSize.Z + safeMargin
end

function GeneratedMapRuntime.getCrystalPosition(zoneId, random, index)
	if shouldUseAnchorPosition(zoneId) and typeof(index) == "number" then
		local anchorPosition = getAnchorPosition(zoneId, "Crystal_" .. tostring(index))

		if anchorPosition ~= nil then
			return anchorPosition + Vector3.new(0, CRYSTAL_HEIGHT_OFFSET, 0)
		end
	end

	local position = ZoneConfig.getRandomCrystalPosition(zoneId, random)

	return offsetPosition(zoneId, position) or position
end

function GeneratedMapRuntime.getFeaturePosition(zoneId, featureId)
	if featureId == nil then
		return nil
	end

	local anchorPosition = getAnchorPosition(zoneId, "Feature_" .. tostring(featureId))

	if anchorPosition ~= nil then
		return anchorPosition
	end

	local bounds = ZoneConfig.getZoneBounds(zoneId)

	if bounds == nil then
		return nil
	end

	for _, feature in ipairs(ZoneConfig.getZoneMapFeatures(zoneId)) do
		local id = feature.Id or feature.Type

		if tostring(id) == tostring(featureId) then
			local offset = feature.Offset or Vector3.zero
			local position = bounds.Center + offset
			local y = (ZoneConfig.getZone(zoneId).Origin or Vector3.zero).Y + 1

			return offsetPosition(zoneId, Vector3.new(position.X, y, position.Z))
		end
	end

	return nil
end

function GeneratedMapRuntime.getUnlockWall(zoneId)
	local wall = ZoneConfig.getUnlockWall(zoneId)

	if wall == nil then
		return nil
	end

	local anchorPosition = if shouldUseAnchorPosition(zoneId) then getAnchorPosition(zoneId, "UnlockWall") else nil
	local center = if anchorPosition ~= nil
		then Vector3.new(anchorPosition.X, wall.Center.Y, anchorPosition.Z)
		else offsetPosition(zoneId, wall.Center) or wall.Center

	return {
		Center = center,
		Size = wall.Size,
		PromptDistance = wall.PromptDistance,
	}
end

function GeneratedMapRuntime.isPositionNearUnlockWall(zoneId, position)
	if typeof(position) ~= "Vector3" then
		return false
	end

	local wall = GeneratedMapRuntime.getUnlockWall(zoneId)

	if wall == nil then
		return false
	end

	local deltaX = position.X - wall.Center.X
	local deltaZ = position.Z - wall.Center.Z
	local promptDistance = wall.PromptDistance or ZoneConfig.UnlockPromptDistance

	return deltaX * deltaX + deltaZ * deltaZ <= promptDistance * promptDistance
end

return GeneratedMapRuntime
