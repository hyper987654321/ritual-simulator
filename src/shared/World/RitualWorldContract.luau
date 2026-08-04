local RitualWorldContract = {}

RitualWorldContract.ContractVersion = 1
RitualWorldContract.LayoutId = "ritual_v1_15"
RitualWorldContract.ZoneCount = 15
RitualWorldContract.ContentKind = "blockout"

local EXECUTABLE_CLASSES = {
	BindableEvent = true,
	BindableFunction = true,
	LocalScript = true,
	ModuleScript = true,
	PackageLink = true,
	RemoteEvent = true,
	RemoteFunction = true,
	Script = true,
}

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
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

local function isAxisAlignedCFrame(value)
	if not isFiniteCFrame(value) then
		return false
	end

	local axes = { value.RightVector, value.UpVector, value.LookVector }
	for _, axis in ipairs(axes) do
		local nonZeroComponents = 0
		for _, component in ipairs({ axis.X, axis.Y, axis.Z }) do
			if math.abs(component) > 0.999 then
				nonZeroComponents += 1
			elseif math.abs(component) > 0.001 then
				return false
			end
		end
		if nonZeroComponents ~= 1 then
			return false
		end
	end

	return true
end

local function isSafeMarker(part)
	return part:IsA("BasePart")
		and part.Anchored
		and part.Transparency >= 1
		and not part.CanCollide
		and not part.CanTouch
		and not part.CanQuery
		and isFiniteCFrame(part.CFrame)
		and isFiniteVector3(part.Size)
		and part.Size.X > 0
		and part.Size.Y > 0
		and part.Size.Z > 0
end

local function hasMetadata(root, errors)
	local metadata = root:FindFirstChild("Metadata")
	if metadata == nil or not metadata:IsA("Folder") then
		table.insert(errors, "missing Metadata folder")
		return
	end

	if metadata:GetAttribute("ContractVersion") ~= RitualWorldContract.ContractVersion then
		table.insert(errors, "metadata ContractVersion mismatch")
	end
	if metadata:GetAttribute("LayoutId") ~= RitualWorldContract.LayoutId then
		table.insert(errors, "metadata LayoutId mismatch")
	end
	if metadata:GetAttribute("ZoneCount") ~= RitualWorldContract.ZoneCount then
		table.insert(errors, "metadata ZoneCount mismatch")
	end
	local contentKind = metadata:GetAttribute("ContentKind")
	if contentKind ~= "blockout" and contentKind ~= "reviewed_import" then
		table.insert(errors, "metadata ContentKind mismatch")
	end
end

local function validateCollision(folder, errors, prefix)
	local parts = 0
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			parts += 1
			if not descendant.Anchored or not descendant.CanCollide or descendant.CanTouch then
				table.insert(errors, prefix .. " collision safety mismatch")
			end
			if not isFiniteCFrame(descendant.CFrame) or not isFiniteVector3(descendant.Size) then
				table.insert(errors, prefix .. " collision transform is nonfinite")
			end
		end
	end
	if parts == 0 then
		table.insert(errors, prefix .. " collision is empty")
	end
end

local function validateVisual(folder, errors, prefix)
	if #folder:GetChildren() == 0 then
		table.insert(errors, prefix .. " visual is empty")
	end
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if not descendant.Anchored or descendant.CanCollide or descendant.CanTouch or descendant.CanQuery then
				table.insert(errors, prefix .. " visual safety mismatch")
			end
			if not isFiniteCFrame(descendant.CFrame) or not isFiniteVector3(descendant.Size) then
				table.insert(errors, prefix .. " visual transform is nonfinite")
			end
		end
	end
end

local function validateAnchors(zoneId, folder, errors)
	local prefix = "Zone_" .. tostring(zoneId)
	local required = { "ZoneBounds", "CrystalArea", "Teleport" }
	if zoneId == 1 then
		table.insert(required, "Spawn")
		table.insert(required, "Feature_Leaderboard")
	elseif zoneId >= 2 then
		table.insert(required, "UnlockWall")
	end
	if zoneId == 5 or zoneId == 10 or zoneId == 15 then
		table.insert(required, "AscensionStatue")
	end

	for _, name in ipairs(required) do
		local anchor = folder:FindFirstChild(name)
		if anchor == nil or not isSafeMarker(anchor) then
			table.insert(errors, prefix .. " missing or unsafe " .. name)
		end
	end
	for _, volumeName in ipairs({ "ZoneBounds", "CrystalArea" }) do
		local volume = folder:FindFirstChild(volumeName)
		if volume ~= nil and not isAxisAlignedCFrame(volume.CFrame) then
			table.insert(errors, prefix .. " " .. volumeName .. " must be axis-aligned")
		end
	end

	local seen = {}
	for crystalId = 1, 5 do
		local name = "Crystal_" .. tostring(crystalId)
		local anchor = folder:FindFirstChild(name)
		if anchor == nil or not isSafeMarker(anchor) then
			table.insert(errors, prefix .. " missing or unsafe " .. name)
		else
			for _, previous in ipairs(seen) do
				if anchor.CFrame == previous then
					table.insert(errors, prefix .. " duplicate crystal CFrame")
				end
			end
			table.insert(seen, anchor.CFrame)
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if string.match(child.Name, "^Crystal_%d+$") and not string.match(child.Name, "^Crystal_[1-5]$") then
			table.insert(errors, prefix .. " has extra crystal anchor")
		end
	end
end

function RitualWorldContract.validate(root)
	local errors = {}
	if root == nil or not root:IsA("Folder") then
		return false, { "root must be a Folder" }
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if EXECUTABLE_CLASSES[descendant.ClassName] or descendant:IsA("BaseScript") then
			table.insert(errors, "executable descendant: " .. descendant:GetFullName())
		end
	end

	hasMetadata(root, errors)
	local zones = root:FindFirstChild("Zones")
	local anchors = root:FindFirstChild("Anchors")
	if zones == nil or not zones:IsA("Folder") then
		table.insert(errors, "missing Zones folder")
	end
	if anchors == nil or not anchors:IsA("Folder") then
		table.insert(errors, "missing Anchors folder")
	end
	if zones == nil or anchors == nil then
		return false, errors
	end

	for zoneId = 1, RitualWorldContract.ZoneCount do
		local zoneName = "Zone_" .. tostring(zoneId)
		local zone = zones:FindFirstChild(zoneName)
		local anchorZone = anchors:FindFirstChild(zoneName)
		if zone == nil or not zone:IsA("Folder") then
			table.insert(errors, "missing " .. zoneName .. " zone")
		else
			local collision = zone:FindFirstChild("Collision")
			local visual = zone:FindFirstChild("Visual")
			if collision == nil or not collision:IsA("Folder") then
				table.insert(errors, zoneName .. " missing Collision folder")
			else
				validateCollision(collision, errors, zoneName)
			end
			if visual == nil or not visual:IsA("Folder") then
				table.insert(errors, zoneName .. " missing Visual folder")
			else
				validateVisual(visual, errors, zoneName)
			end
		end
		if anchorZone == nil or not anchorZone:IsA("Folder") then
			table.insert(errors, "missing " .. zoneName .. " anchors")
		else
			validateAnchors(zoneId, anchorZone, errors)
		end
	end

	return #errors == 0, errors
end

function RitualWorldContract.isValid(root)
	local valid = RitualWorldContract.validate(root)
	return valid
end

return RitualWorldContract
