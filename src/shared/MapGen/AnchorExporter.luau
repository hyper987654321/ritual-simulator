local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapGenConfig = require(script.Parent:WaitForChild("MapGenConfig"))

local AnchorExporter = {}

local DEFAULT_BASEPLATE_NAME = "Baseplate"
local DEFAULT_BASEPLATE_POSITION = Vector3.new(0, -10, 0)
local DEFAULT_BASEPLATE_SIZE = Vector3.new(512, 20, 512)

local function addGeneratedMetadata(instance, plan, zoneId, kind)
	instance:SetAttribute("GeneratedBy", MapGenConfig.GeneratedBy)
	instance:SetAttribute("Seed", plan.Seed)
	instance:SetAttribute("Preset", plan.PresetName)

	if zoneId ~= nil then
		instance:SetAttribute("ZoneId", zoneId)
	end

	if kind ~= nil then
		instance:SetAttribute("GeneratedKind", kind)
	end

	CollectionService:AddTag(instance, MapGenConfig.GeneratedTag)
end

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)

	if existing ~= nil and existing.ClassName == className then
		return existing
	end

	if existing ~= nil then
		existing:Destroy()
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent

	return instance
end

local function setMetadataAttributes(metadata, plan)
	metadata:SetAttribute("GeneratedBy", MapGenConfig.GeneratedBy)
	metadata:SetAttribute("Version", MapGenConfig.Version)
	metadata:SetAttribute("Seed", plan.Seed)
	metadata:SetAttribute("Preset", plan.PresetName)
	metadata:SetAttribute("MapStyle", if plan.Preset.MapStyle ~= nil then plan.Preset.MapStyle else "Unknown")
	metadata:SetAttribute("GeneratedAtUnix", os.time())
	metadata:SetAttribute("ZoneCount", #plan.ZonePlans)
	metadata:SetAttribute("BoundsMin", plan.Bounds.Min)
	metadata:SetAttribute("BoundsMax", plan.Bounds.Max)
end

local function createAnchorPart(parent, plan, zoneId, name, anchorType, position, index, visible)
	local sectionConfig = plan.Preset.Sections
	local y = if sectionConfig ~= nil and typeof(sectionConfig.TopY) == "number" then sectionConfig.TopY else position.Y
	local surfacePosition = Vector3.new(position.X, y, position.Z)
	local part = Instance.new("Part")

	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = Color3.fromRGB(103, 228, 255)
	part.Material = Enum.Material.Neon
	part.Position = surfacePosition + Vector3.new(0, 1, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.Transparency = if visible then 0.45 else 1
	part.Parent = parent
	part:SetAttribute("AnchorType", anchorType)

	if index ~= nil then
		part:SetAttribute("Index", index)
	end

	addGeneratedMetadata(part, plan, zoneId, "Anchor")
	CollectionService:AddTag(part, MapGenConfig.AnchorTag)

	return part
end

function AnchorExporter.getOutputRoot()
	return Workspace:FindFirstChild(MapGenConfig.OutputFolderName)
end

function AnchorExporter.ensureOutputRoot(plan)
	local root = Workspace:FindFirstChild(MapGenConfig.OutputFolderName)

	if root ~= nil and not root:IsA("Folder") then
		root:Destroy()
		root = nil
	end

	if root == nil then
		root = Instance.new("Folder")
		root.Name = MapGenConfig.OutputFolderName
		root.Parent = Workspace
	end

	addGeneratedMetadata(root, plan, nil, "Root")

	local metadata = getOrCreate(root, "Folder", MapGenConfig.MetadataFolderName)
	addGeneratedMetadata(metadata, plan, nil, "Metadata")
	setMetadataAttributes(metadata, plan)

	local zonesFolder = getOrCreate(root, "Folder", "Zones")
	local anchorsFolder = getOrCreate(root, "Folder", "Anchors")

	addGeneratedMetadata(zonesFolder, plan, nil, "Zones")
	addGeneratedMetadata(anchorsFolder, plan, nil, "Anchors")

	for _, zonePlan in ipairs(plan.ZonePlans) do
		local zoneFolder = getOrCreate(zonesFolder, "Folder", "Zone_" .. tostring(zonePlan.ZoneId))

		addGeneratedMetadata(zoneFolder, plan, zonePlan.ZoneId, "Zone")
		addGeneratedMetadata(getOrCreate(zoneFolder, "Folder", "Blocks"), plan, zonePlan.ZoneId, "Blocks")
		addGeneratedMetadata(getOrCreate(zoneFolder, "Folder", "Walls"), plan, zonePlan.ZoneId, "Walls")
		addGeneratedMetadata(getOrCreate(zoneFolder, "Folder", "Barriers"), plan, zonePlan.ZoneId, "Barriers")
		addGeneratedMetadata(getOrCreate(zoneFolder, "Folder", "Props"), plan, zonePlan.ZoneId, "Props")
		addGeneratedMetadata(getOrCreate(zoneFolder, "Folder", "Structures"), plan, zonePlan.ZoneId, "Structures")
		addGeneratedMetadata(getOrCreate(zoneFolder, "Folder", "Debug"), plan, zonePlan.ZoneId, "Debug")
		addGeneratedMetadata(getOrCreate(anchorsFolder, "Folder", "Zone_" .. tostring(zonePlan.ZoneId)), plan, zonePlan.ZoneId, "AnchorZone")
	end

	return root
end

function AnchorExporter.clearGeneratedInstances()
	local root = AnchorExporter.getOutputRoot()

	if root ~= nil then
		local zonesFolder = root:FindFirstChild("Zones")

		for _, child in ipairs(root:GetChildren()) do
			if child == zonesFolder then
				-- Imported Zone_N/Visual models belong to the external map pipeline,
				-- so clear only this plugin's generated siblings.
				for _, zoneFolder in ipairs(zonesFolder:GetChildren()) do
					if zoneFolder:IsA("Folder") and string.match(zoneFolder.Name, "^Zone_%d+$") then
						for _, zoneChild in ipairs(zoneFolder:GetChildren()) do
							if zoneChild.Name ~= "Visual"
								and (zoneChild:GetAttribute("GeneratedBy") == MapGenConfig.GeneratedBy
									or CollectionService:HasTag(zoneChild, MapGenConfig.GeneratedTag)) then
								zoneChild:Destroy()
							end
						end
					elseif zoneFolder:GetAttribute("GeneratedBy") == MapGenConfig.GeneratedBy
						or CollectionService:HasTag(zoneFolder, MapGenConfig.GeneratedTag) then
						zoneFolder:Destroy()
					end
				end
			elseif child:GetAttribute("GeneratedBy") == MapGenConfig.GeneratedBy
				or CollectionService:HasTag(child, MapGenConfig.GeneratedTag) then
				child:Destroy()
			end
		end
	end

	local baseplate = Workspace:FindFirstChild(DEFAULT_BASEPLATE_NAME)

	if baseplate ~= nil and baseplate:IsA("BasePart") and baseplate.Position == DEFAULT_BASEPLATE_POSITION and baseplate.Size == DEFAULT_BASEPLATE_SIZE then
		baseplate:Destroy()
	end

	for _, instance in ipairs(CollectionService:GetTagged(MapGenConfig.GeneratedTag)) do
		if instance.Parent ~= nil
			and instance:GetAttribute("GeneratedBy") == MapGenConfig.GeneratedBy
			and (root == nil or not instance:IsDescendantOf(root)) then
			instance:Destroy()
		end
	end
end

function AnchorExporter.createAnchors(plan, visible)
	local root = AnchorExporter.ensureOutputRoot(plan)
	local anchorsFolder = root:WaitForChild("Anchors")

	for _, zonePlan in ipairs(plan.ZonePlans) do
		local zoneAnchorFolder = anchorsFolder:WaitForChild("Zone_" .. tostring(zonePlan.ZoneId))

		zoneAnchorFolder:ClearAllChildren()

		if zonePlan.TeleportPosition ~= nil then
			createAnchorPart(zoneAnchorFolder, plan, zonePlan.ZoneId, "Teleport", "Teleport", zonePlan.TeleportPosition, nil, visible)
		end

		if zonePlan.PlayerSpawnPosition ~= nil then
			createAnchorPart(zoneAnchorFolder, plan, zonePlan.ZoneId, "Spawn", "Spawn", zonePlan.PlayerSpawnPosition, nil, visible)
		end

		if zonePlan.UnlockWall ~= nil then
			createAnchorPart(zoneAnchorFolder, plan, zonePlan.ZoneId, "UnlockWall", "UnlockWall", zonePlan.UnlockWall.Center, nil, visible)
		end

		if zonePlan.AscensionPosition ~= nil then
			createAnchorPart(zoneAnchorFolder, plan, zonePlan.ZoneId, "AscensionStatue", "AscensionStatue", zonePlan.AscensionPosition, nil, visible)
		end

		for _, anchor in ipairs(zonePlan.CrystalAnchors) do
			createAnchorPart(zoneAnchorFolder, plan, zonePlan.ZoneId, anchor.Name, anchor.AnchorType, anchor.Position, anchor.Index, visible)
		end

		for _, slot in ipairs(zonePlan.FeatureSlots or {}) do
			local featureAnchor = createAnchorPart(zoneAnchorFolder, plan, zonePlan.ZoneId, "Feature_" .. tostring(slot.Id), "Feature", slot.Position, nil, visible)

			featureAnchor:SetAttribute("FeatureId", slot.Id)
			featureAnchor:SetAttribute("FeatureType", slot.Type)
		end
	end

	return root
end

function AnchorExporter.setAnchorVisibility(root, visible)
	if root == nil then
		return
	end

	local anchorsFolder = root:FindFirstChild("Anchors")

	if anchorsFolder == nil then
		return
	end

	for _, descendant in ipairs(anchorsFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if visible then 0.45 else 1
		end
	end
end

function AnchorExporter.createDebugZoneBounds(plan, visible)
	local root = AnchorExporter.ensureOutputRoot(plan)
	local zonesFolder = root:WaitForChild("Zones")

	for _, zonePlan in ipairs(plan.ZonePlans) do
		local zoneFolder = zonesFolder:WaitForChild("Zone_" .. tostring(zonePlan.ZoneId))
		local debugFolder = zoneFolder:WaitForChild("Debug")

		debugFolder:ClearAllChildren()

		if visible then
			local boundsPart = Instance.new("Part")

			boundsPart.Name = "ZoneBounds"
			boundsPart.Anchored = true
			boundsPart.CanCollide = false
			boundsPart.CanQuery = false
			boundsPart.CanTouch = false
			boundsPart.Color = zonePlan.Theme.Colors.Accent
			boundsPart.Material = Enum.Material.ForceField
			boundsPart.Position = Vector3.new(zonePlan.BoundsCenter.X, zonePlan.Theme.BaseHeight + 0.2, zonePlan.BoundsCenter.Z)
			boundsPart.Size = Vector3.new(zonePlan.BoundsSize.X, 0.12, zonePlan.BoundsSize.Z)
			boundsPart.Transparency = 0.82
			boundsPart.Parent = debugFolder
			addGeneratedMetadata(boundsPart, plan, zonePlan.ZoneId, "DebugBounds")
		end
	end
end

local function formatVector3(vector)
	return string.format("Vector3.new(%.3f, %.3f, %.3f)", vector.X, vector.Y, vector.Z)
end

function AnchorExporter.exportAnchorConfigModule(root)
	if root == nil then
		return nil, "No generated map folder found."
	end

	local anchorsFolder = root:FindFirstChild("Anchors")

	if anchorsFolder == nil then
		return nil, "No Anchors folder found."
	end

	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local config = if shared ~= nil then shared:FindFirstChild("Config") else nil

	if config == nil then
		return nil, "ReplicatedStorage.Shared.Config was not found."
	end

	local metadata = root:FindFirstChild(MapGenConfig.MetadataFolderName)
	local seed = if metadata ~= nil then metadata:GetAttribute("Seed") else root:GetAttribute("Seed")
	local preset = if metadata ~= nil then metadata:GetAttribute("Preset") else root:GetAttribute("Preset")
	local lines = {
		"local GeneratedMapAnchorConfig = {}",
		"",
		string.format("GeneratedMapAnchorConfig.GeneratedBy = %q", MapGenConfig.GeneratedBy),
		string.format("GeneratedMapAnchorConfig.Seed = %d", if typeof(seed) == "number" then seed else 0),
		string.format("GeneratedMapAnchorConfig.Preset = %q", if typeof(preset) == "string" then preset else ""),
		"",
		"GeneratedMapAnchorConfig.Zones = {",
	}

	for _, zoneFolder in ipairs(anchorsFolder:GetChildren()) do
		local zoneIdText = string.match(zoneFolder.Name, "^Zone_(%d+)$")
		local zoneId = tonumber(zoneIdText)

		if zoneId ~= nil then
			table.insert(lines, "\t[" .. tostring(zoneId) .. "] = {")

			local teleport = zoneFolder:FindFirstChild("Teleport")

			if teleport ~= nil and teleport:IsA("BasePart") then
				table.insert(lines, "\t\tTeleport = " .. formatVector3(teleport.Position) .. ",")
			end

			local spawn = zoneFolder:FindFirstChild("Spawn")

			if spawn ~= nil and spawn:IsA("BasePart") then
				table.insert(lines, "\t\tSpawn = " .. formatVector3(spawn.Position) .. ",")
			end

			local unlockWall = zoneFolder:FindFirstChild("UnlockWall")

			if unlockWall ~= nil and unlockWall:IsA("BasePart") then
				table.insert(lines, "\t\tUnlockWall = " .. formatVector3(unlockWall.Position) .. ",")
			end

			local ascensionStatue = zoneFolder:FindFirstChild("AscensionStatue")

			if ascensionStatue ~= nil and ascensionStatue:IsA("BasePart") then
				table.insert(lines, "\t\tAscensionStatue = " .. formatVector3(ascensionStatue.Position) .. ",")
			end

			table.insert(lines, "\t\tFeatures = {")

			for _, child in ipairs(zoneFolder:GetChildren()) do
				if child:IsA("BasePart") and child:GetAttribute("AnchorType") == "Feature" then
					local featureId = child:GetAttribute("FeatureId") or string.gsub(child.Name, "^Feature_", "")
					local featureType = child:GetAttribute("FeatureType") or ""

					table.insert(lines, string.format("\t\t\t[%q] = { Type = %q, Position = %s },", tostring(featureId), tostring(featureType), formatVector3(child.Position)))
				end
			end

			table.insert(lines, "\t\t},")

			table.insert(lines, "\t\tCrystals = {")

			for index = 1, 20 do
				local crystal = zoneFolder:FindFirstChild("Crystal_" .. tostring(index))

				if crystal ~= nil and crystal:IsA("BasePart") then
					table.insert(lines, "\t\t\t" .. formatVector3(crystal.Position) .. ",")
				end
			end

			table.insert(lines, "\t\t},")
			table.insert(lines, "\t},")
		end
	end

	table.insert(lines, "}")
	table.insert(lines, "")
	table.insert(lines, "return GeneratedMapAnchorConfig")

	local moduleScript = config:FindFirstChild("GeneratedMapAnchorConfig")

	if moduleScript ~= nil and not moduleScript:IsA("ModuleScript") then
		moduleScript:Destroy()
		moduleScript = nil
	end

	if moduleScript == nil then
		moduleScript = Instance.new("ModuleScript")
		moduleScript.Name = "GeneratedMapAnchorConfig"
		moduleScript.Parent = config
	end

	moduleScript.Source = table.concat(lines, "\n")
	moduleScript:SetAttribute("GeneratedBy", MapGenConfig.GeneratedBy)
	moduleScript:SetAttribute("Seed", if typeof(seed) == "number" then seed else 0)
	moduleScript:SetAttribute("Preset", if typeof(preset) == "string" then preset else "")

	return moduleScript, nil
end

return AnchorExporter
