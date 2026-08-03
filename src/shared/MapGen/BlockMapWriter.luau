local AnchorExporter = require(script.Parent:WaitForChild("AnchorExporter"))
local PropScatterer = require(script.Parent:WaitForChild("PropScatterer"))
local Util = require(script.Parent:WaitForChild("BlockWriterUtil"))
local ZoneBlockWriter = require(script.Parent:WaitForChild("ZoneBlockWriter"))
local ZoneStructureWriter = require(script.Parent:WaitForChild("ZoneStructureWriter"))

local BlockMapWriter = {}

function BlockMapWriter.generate(plan, options, progressCallback)
	local root = AnchorExporter.ensureOutputRoot(plan)
	local zonesFolder = root:WaitForChild("Zones")
	local safeOptions = options or {}

	root:SetAttribute("MapStyle", "BlockSections")
	Util.prepareZoneFolders(plan, root)

	for zoneIndex, zonePlan in ipairs(plan.ZonePlans) do
		local zoneFolder = zonesFolder:WaitForChild("Zone_" .. tostring(zonePlan.ZoneId))
		local blocksFolder = zoneFolder:WaitForChild("Blocks")
		local wallsFolder = zoneFolder:WaitForChild("Walls")
		local barriersFolder = zoneFolder:WaitForChild("Barriers")
		local propsFolder = zoneFolder:WaitForChild("Props")
		local structuresFolder = zoneFolder:WaitForChild("Structures")
		local debugFolder = zoneFolder:WaitForChild("Debug")

		ZoneBlockWriter.createSectionFloor(plan, zonePlan, blocksFolder)
		ZoneBlockWriter.createBoundaryWalls(plan, zonePlan, wallsFolder, barriersFolder)
		ZoneStructureWriter.createZoneStructures(plan, zonePlan, structuresFolder)
		ZoneBlockWriter.createDebugBounds(plan, zonePlan, debugFolder, safeOptions.ShowZoneBounds == true)
		PropScatterer.scatter(plan, zonePlan, propsFolder)

		if progressCallback ~= nil then
			progressCallback(zoneIndex, #plan.ZonePlans, zonePlan.ZoneId)
		end

		task.wait()
	end

	for index = 1, #plan.ZonePlans - 1 do
		ZoneBlockWriter.createBridgeBetweenZones(plan, plan.ZonePlans[index], plan.ZonePlans[index + 1], root)
	end

	AnchorExporter.createAnchors(plan, safeOptions.ShowAnchors == true)

	return root
end

return BlockMapWriter
