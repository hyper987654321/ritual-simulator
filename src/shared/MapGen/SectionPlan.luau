local MapGenConfig = require(script.Parent:WaitForChild("MapGenConfig"))
local PathGenerator = require(script.Parent:WaitForChild("PathGenerator"))
local SeededRandom = require(script.Parent:WaitForChild("SeededRandom"))
local ZoneLayout = require(script.Parent:WaitForChild("ZoneLayout"))

local SectionPlan = {}

local function alignDown(value, resolution)
	return math.floor(value / resolution) * resolution
end

local function alignUp(value, resolution)
	return math.ceil(value / resolution) * resolution
end

local function getBounds(zonePlans, preset)
	local boundsConfig = preset.Bounds
	local minX = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxZ = -math.huge

	for _, zonePlan in ipairs(zonePlans) do
		minX = math.min(minX, zonePlan.BoundsMin.X)
		minZ = math.min(minZ, zonePlan.BoundsMin.Z)
		maxX = math.max(maxX, zonePlan.BoundsMax.X)
		maxZ = math.max(maxZ, zonePlan.BoundsMax.Z)
	end

	local margin = boundsConfig.Margin
	local resolution = boundsConfig.Resolution

	return {
		Min = Vector3.new(
			alignDown(minX - margin, resolution),
			alignDown(boundsConfig.MinY, resolution),
			alignDown(minZ - margin, resolution)
		),
		Max = Vector3.new(
			alignUp(maxX + margin, resolution),
			alignUp(boundsConfig.MaxY, resolution),
			alignUp(maxZ + margin, resolution)
		),
	}
end

function SectionPlan.build(seed, presetName)
	local safeSeed = SeededRandom.normalizeSeed(seed)
	local resolvedPresetName = if MapGenConfig.Presets[presetName] ~= nil then presetName else MapGenConfig.DefaultPreset
	local preset = MapGenConfig.getPreset(resolvedPresetName)

	if preset.MapStyle ~= "BlockSections" then
		resolvedPresetName = MapGenConfig.DefaultPreset
		preset = MapGenConfig.getPreset(resolvedPresetName)
	end

	local zonePlans = ZoneLayout.build(safeSeed, resolvedPresetName)
	local pathPlan = PathGenerator.create(zonePlans, preset)
	local bounds = getBounds(zonePlans, preset)

	return {
		Seed = safeSeed,
		PresetName = resolvedPresetName,
		Preset = preset,
		ZonePlans = zonePlans,
		PathPlan = pathPlan,
		Bounds = bounds,
	}
end

return SectionPlan
