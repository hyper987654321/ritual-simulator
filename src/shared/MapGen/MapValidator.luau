local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local MapGenConfig = require(script.Parent:WaitForChild("MapGenConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))

local MapValidator = {}

local function addResult(results, severity, code, message, zoneId)
	table.insert(results, {
		Severity = severity,
		Code = code,
		Message = message,
		ZoneId = zoneId,
	})
end

local function getChild(parent, name, className)
	if parent == nil then
		return nil
	end

	local child = parent:FindFirstChild(name)

	if child ~= nil and (className == nil or child:IsA(className)) then
		return child
	end

	return nil
end

local function isPositionInsideBoundsWithMargin(zoneId, position, margin)
	local bounds = ZoneConfig.getZoneBounds(zoneId)

	if bounds == nil then
		return false
	end

	local halfSize = bounds.Size / 2
	local delta = position - bounds.Center

	return math.abs(delta.X) <= halfSize.X + margin and math.abs(delta.Z) <= halfSize.Z + margin
end

local function validateAnchor(results, zoneFolder, zoneId, name, required, plan)
	local anchor = getChild(zoneFolder, name, "BasePart")

	if anchor == nil then
		if required then
			addResult(results, "Fail", "MissingAnchor", "Zone " .. tostring(zoneId) .. " is missing " .. name .. " anchor.", zoneId)
		end

		return nil
	end

	addResult(results, "Pass", "AnchorExists", "Zone " .. tostring(zoneId) .. " has " .. name .. " anchor.", zoneId)

	if anchor:GetAttribute("GeneratedBy") ~= MapGenConfig.GeneratedBy then
		addResult(results, "Warn", "AnchorMetadata", name .. " in Zone " .. tostring(zoneId) .. " is missing GeneratedBy metadata.", zoneId)
	end

	local isInsideBounds = if name == "UnlockWall"
		then isPositionInsideBoundsWithMargin(zoneId, anchor.Position, 20)
		else ZoneConfig.isPositionInsideBounds(zoneId, anchor.Position)

	if not isInsideBounds then
		addResult(results, "Fail", "AnchorOutOfBounds", name .. " in Zone " .. tostring(zoneId) .. " is outside zone bounds.", zoneId)
	end

	return anchor
end

local function validateAnchors(results, root, plan)
	local anchorsFolder = getChild(root, "Anchors", "Folder")

	if anchorsFolder == nil then
		addResult(results, "Fail", "MissingAnchorsFolder", "RitualMapGenerated is missing Anchors folder.")
		return
	end

	for _, zoneId in ipairs(ZoneConfig.getZoneIds()) do
		local zoneFolder = getChild(anchorsFolder, "Zone_" .. tostring(zoneId), "Folder")

		if zoneFolder == nil then
			addResult(results, "Fail", "MissingZoneAnchorFolder", "Anchors/Zone_" .. tostring(zoneId) .. " is missing.", zoneId)
		else
			local anchors = {}

			validateAnchor(results, zoneFolder, zoneId, "Teleport", true, plan)

			if zoneId == 1 then
				validateAnchor(results, zoneFolder, zoneId, "Spawn", true, plan)
			end

			if zoneId ~= 1 then
				local unlockWall = validateAnchor(results, zoneFolder, zoneId, "UnlockWall", true, plan)

				if unlockWall ~= nil then
					table.insert(anchors, unlockWall)
				end
			end

			if zoneId == ZoneConfig.ZoneOrder[#ZoneConfig.ZoneOrder] then
				local ascension = validateAnchor(results, zoneFolder, zoneId, "AscensionStatue", true, plan)

				if ascension ~= nil then
					table.insert(anchors, ascension)
				end
			end

			local crystalCount = ZoneConfig.getCrystalCount(zoneId)
			local foundCrystals = 0

			for index = 1, crystalCount do
				local crystal = validateAnchor(results, zoneFolder, zoneId, "Crystal_" .. tostring(index), true, plan)

				if crystal ~= nil then
					foundCrystals += 1
					table.insert(anchors, crystal)
				end
			end

			if foundCrystals == crystalCount then
				addResult(results, "Pass", "CrystalAnchorCount", "Zone " .. tostring(zoneId) .. " has " .. tostring(crystalCount) .. " crystal anchors.", zoneId)
			end

			for leftIndex = 1, #anchors do
				for rightIndex = leftIndex + 1, #anchors do
					if (anchors[leftIndex].Position - anchors[rightIndex].Position).Magnitude < 6 then
						addResult(results, "Warn", "AnchorSpacing", anchors[leftIndex].Name .. " and " .. anchors[rightIndex].Name .. " in Zone " .. tostring(zoneId) .. " are close together.", zoneId)
					end
				end
			end
		end
	end
end

local function validateFolders(results, root, plan)
	local metadata = getChild(root, MapGenConfig.MetadataFolderName, "Folder")

	if metadata == nil then
		addResult(results, "Fail", "MissingMetadata", "RitualMapGenerated is missing Metadata folder.")
	else
		if metadata:GetAttribute("GeneratedBy") == MapGenConfig.GeneratedBy then
			addResult(results, "Pass", "MetadataGeneratedBy", "Metadata has GeneratedBy attribute.")
		else
			addResult(results, "Warn", "MetadataGeneratedBy", "Metadata is missing GeneratedBy attribute.")
		end
	end

	local zonesFolder = getChild(root, "Zones", "Folder")

	if zonesFolder == nil then
		addResult(results, "Fail", "MissingZonesFolder", "RitualMapGenerated is missing Zones folder.")
		return
	end

	for _, zoneId in ipairs(ZoneConfig.getZoneIds()) do
		local zoneFolder = getChild(zonesFolder, "Zone_" .. tostring(zoneId), "Folder")

		if zoneFolder == nil then
			addResult(results, "Fail", "MissingZoneFolder", "Zones/Zone_" .. tostring(zoneId) .. " is missing.", zoneId)
		else
			addResult(results, "Pass", "ZoneFolderExists", "Zones/Zone_" .. tostring(zoneId) .. " exists.", zoneId)

			local requiredChildren = if plan ~= nil and plan.Preset.MapStyle == "BlockSections"
				then { "Blocks", "Walls", "Barriers", "Props", "Structures", "Debug" }
				else { "Props", "Structures", "Debug" }

			for _, childName in ipairs(requiredChildren) do
				if getChild(zoneFolder, childName, "Folder") == nil then
					addResult(results, "Fail", "MissingZoneChildFolder", "Zones/Zone_" .. tostring(zoneId) .. " is missing " .. childName .. " folder.", zoneId)
				end
			end
		end
	end
end

local function validateGeneratedParts(results, root, plan)
	local partCount = 0
	local collidableDecorativeParts = 0
	local maxParts = if plan ~= nil then plan.Preset.Budgets.MaxGeneratedParts else 1500
	local maxCollidable = if plan ~= nil then plan.Preset.Budgets.MaxCollidableDecorativeParts else 250
	local boundsMargin = 8

	if plan ~= nil and plan.Preset.MapStyle == "BlockSections" then
		local sections = plan.Preset.Sections

		boundsMargin = math.max(
			sections.VisualPaddingX or sections.VisualPadding or 0,
			sections.VisualPaddingZ or sections.VisualPadding or 0
		) + math.max(sections.VisibleWallThickness or 0, sections.InvisibleWallThickness or 0) + 4
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			partCount += 1

			if descendant.Anchored ~= true then
				addResult(results, "Fail", "UnanchoredPart", descendant:GetFullName() .. " is not anchored.")
			end

			if descendant:GetAttribute("GeneratedBy") ~= MapGenConfig.GeneratedBy then
				addResult(results, "Warn", "MissingGeneratedBy", descendant:GetFullName() .. " is missing GeneratedBy metadata.")
			end

			if descendant.CanCollide then
				collidableDecorativeParts += 1
			end

			local zoneId = descendant:GetAttribute("ZoneId")

			if typeof(zoneId) == "number" and not isPositionInsideBoundsWithMargin(zoneId, descendant.Position, boundsMargin) then
				addResult(results, "Warn", "PropOutOfBounds", descendant:GetFullName() .. " is outside its zone bounds margin.", zoneId)
			end
		end
	end

	if partCount <= maxParts then
		addResult(results, "Pass", "GeneratedPartBudget", "Generated part count is " .. tostring(partCount) .. "/" .. tostring(maxParts) .. ".")
	else
		addResult(results, "Warn", "GeneratedPartBudget", "Generated part count is " .. tostring(partCount) .. "/" .. tostring(maxParts) .. ".")
	end

	if collidableDecorativeParts <= maxCollidable then
		addResult(results, "Pass", "CollidableBudget", "Collidable generated part count is " .. tostring(collidableDecorativeParts) .. "/" .. tostring(maxCollidable) .. ".")
	else
		addResult(results, "Warn", "CollidableBudget", "Collidable generated part count is " .. tostring(collidableDecorativeParts) .. "/" .. tostring(maxCollidable) .. ".")
	end
end

local function validatePropBudgets(results, root, plan)
	if plan == nil then
		return
	end

	local zonesFolder = getChild(root, "Zones", "Folder")

	if zonesFolder == nil then
		return
	end

	for _, zonePlan in ipairs(plan.ZonePlans) do
		local zoneFolder = getChild(zonesFolder, "Zone_" .. tostring(zonePlan.ZoneId), "Folder")
		local propsFolder = getChild(zoneFolder, "Props", "Folder")

		if propsFolder ~= nil then
			local propCount = #propsFolder:GetChildren()
			local propBudgets = plan.Preset.Budgets.PropsPerZone or {}
			local budget = propBudgets[zonePlan.ZoneId] or propBudgets.Default or 40

			if propCount <= budget then
				addResult(results, "Pass", "PropBudget", "Zone " .. tostring(zonePlan.ZoneId) .. " has " .. tostring(propCount) .. "/" .. tostring(budget) .. " decorative props.", zonePlan.ZoneId)
			else
				addResult(results, "Warn", "PropBudget", "Zone " .. tostring(zonePlan.ZoneId) .. " has " .. tostring(propCount) .. "/" .. tostring(budget) .. " decorative props.", zonePlan.ZoneId)
			end
		end
	end
end

function MapValidator.validate(plan)
	local results = {}
	local root = Workspace:FindFirstChild(MapGenConfig.OutputFolderName)

	if root == nil then
		addResult(results, "Fail", "MissingRoot", "Workspace/" .. MapGenConfig.OutputFolderName .. " does not exist.")
		return results
	end

	if not root:IsA("Folder") then
		addResult(results, "Fail", "RootIsNotFolder", "Workspace/" .. MapGenConfig.OutputFolderName .. " is not a Folder.")
		return results
	end

	addResult(results, "Pass", "RootExists", "Workspace/" .. MapGenConfig.OutputFolderName .. " exists.")
	validateFolders(results, root, plan)
	validateAnchors(results, root, plan)
	validateGeneratedParts(results, root, plan)
	validatePropBudgets(results, root, plan)

	return results
end

function MapValidator.formatResults(results)
	local lines = {}

	for _, result in ipairs(results) do
		local prefix = string.upper(result.Severity or "Info")
		local zoneText = if result.ZoneId ~= nil then " [Zone " .. tostring(result.ZoneId) .. "]" else ""

		table.insert(lines, prefix .. zoneText .. ": " .. result.Message)
	end

	return lines
end

return MapValidator
