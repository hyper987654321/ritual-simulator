local PetFollowerLayout = {}

local MAX_PETS_PER_ROW = 5
local BASE_RADIUS = 4
local ROW_RADIUS_SPACING = 2.2
local HEIGHT = 2.4
local ROW_HEIGHT_STEP = 0.18
local MAX_ARC_SPREAD_RADIANS = math.rad(104)
local SLOT_SPREAD_RADIANS = math.rad(26)
local FOLLOW_HEADING_TURN_RADIANS_PER_SECOND = math.rad(115)

local function getHorizontalUnit(vector, fallback)
	local horizontal = if typeof(vector) == "Vector3" then Vector3.new(vector.X, 0, vector.Z) else Vector3.zero

	if horizontal.Magnitude > 0.001 then
		return horizontal.Unit
	end

	local fallbackHorizontal = if fallback ~= nil then Vector3.new(fallback.X, 0, fallback.Z) else Vector3.zero

	if fallbackHorizontal.Magnitude > 0.001 then
		return fallbackHorizontal.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function getRowInfo(index, total)
	local rowIndex = math.floor((index - 1) / MAX_PETS_PER_ROW)
	local rowStartIndex = rowIndex * MAX_PETS_PER_ROW + 1
	local rowCount = math.min(MAX_PETS_PER_ROW, math.max(0, total - rowStartIndex + 1))
	local slotIndex = index - rowStartIndex + 1

	return rowIndex, rowCount, slotIndex
end

local function getYawFromHorizontalDirection(direction)
	return math.atan2(direction.X, direction.Z)
end

local function getHorizontalDirectionFromYaw(yaw)
	return Vector3.new(math.sin(yaw), 0, math.cos(yaw))
end

local function getShortestAngleDelta(fromYaw, toYaw)
	return math.atan2(math.sin(toYaw - fromYaw), math.cos(toYaw - fromYaw))
end

local function stepHorizontalLookDirection(previousDirection, desiredDirection, maxTurnRadians)
	local previous = getHorizontalUnit(previousDirection, desiredDirection)
	local desired = getHorizontalUnit(desiredDirection, previous)
	local previousYaw = getYawFromHorizontalDirection(previous)
	local desiredYaw = getYawFromHorizontalDirection(desired)
	local delta = getShortestAngleDelta(previousYaw, desiredYaw)
	local yaw = previousYaw + math.clamp(delta, -maxTurnRadians, maxTurnRadians)

	return getHorizontalDirectionFromYaw(yaw)
end

function PetFollowerLayout.getFollowRootCFrame(rootPart, previousLookDirection, dt)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		local fallbackLookDirection = getHorizontalUnit(previousLookDirection, Vector3.new(0, 0, -1))

		return CFrame.lookAt(Vector3.zero, Vector3.zero + fallbackLookDirection), fallbackLookDirection
	end

	local desiredLookDirection = getHorizontalUnit(rootPart.CFrame.LookVector, previousLookDirection)
	local nextLookDirection = desiredLookDirection

	if previousLookDirection ~= nil and previousLookDirection.Magnitude > 0.001 then
		nextLookDirection = stepHorizontalLookDirection(
			previousLookDirection,
			desiredLookDirection,
			FOLLOW_HEADING_TURN_RADIANS_PER_SECOND * math.max(dt or 0, 0)
		)
	end

	local rootPosition = rootPart.Position

	return CFrame.lookAt(rootPosition, rootPosition + nextLookDirection), nextLookDirection
end

function PetFollowerLayout.getHomeCFrame(rootCFrame, index, total, timeNow)
	local safeTotal = math.max(1, total)
	local rowIndex, rowCount, slotIndex = getRowInfo(index, safeTotal)
	local radius = BASE_RADIUS + rowIndex * ROW_RADIUS_SPACING
	local spread = if rowCount <= 1 then 0 else math.min(MAX_ARC_SPREAD_RADIANS, SLOT_SPREAD_RADIANS * (rowCount - 1))
	local slotAlpha = if rowCount <= 1 then 0.5 else (slotIndex - 1) / (rowCount - 1)
	local angle = -spread * 0.5 + spread * slotAlpha
	local bob = math.sin((timeNow or 0) * 2.4 + index) * 0.12
	local localOffset = Vector3.new(
		math.sin(angle) * radius,
		HEIGHT + rowIndex * ROW_HEIGHT_STEP + bob,
		math.cos(angle) * radius
	)
	local position = rootCFrame:PointToWorldSpace(localOffset)

	return CFrame.lookAt(position, position + rootCFrame.LookVector)
end

return PetFollowerLayout
