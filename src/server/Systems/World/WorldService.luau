local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapGen = Shared:WaitForChild("MapGen")
local MapGenConfig = require(MapGen:WaitForChild("MapGenConfig"))
local World = Shared:WaitForChild("World")
local RitualWorldContract = require(World:WaitForChild("RitualWorldContract"))

local CodeNativeWorldProvider = require(script.Parent:WaitForChild("CodeNativeWorldProvider"))

local WorldService = {}

local WORLD_FOLDER_NAME = MapGenConfig.OutputFolderName
local TEMPORARY_WORLD_FOLDER_NAME = "__RitualWorldBuild"
local PUBLISH_WORLD_FOLDER_NAME = "__RitualWorldPublish"
local hasStarted = false

local function describeErrors(errors)
	return table.concat(errors, "; ")
end

local function validateWorld(root, context)
	local valid, errors = RitualWorldContract.validate(root)
	assert(valid, context .. ": " .. describeErrors(errors))
end

local function buildAndPublishFallback()
	local existing = Workspace:FindFirstChild(WORLD_FOLDER_NAME)

	if existing ~= nil then
		local valid = RitualWorldContract.isValid(existing)

		if valid then
			return existing
		end
	end

	local existingTemporary = ServerStorage:FindFirstChild(TEMPORARY_WORLD_FOLDER_NAME)
	assert(existingTemporary == nil, "temporary world build already exists")
	local existingPublish = ServerStorage:FindFirstChild(PUBLISH_WORLD_FOLDER_NAME)
	assert(existingPublish == nil, "publish world build already exists")

	local temporary = nil
	local published = nil
	local ok, result = pcall(function()
		temporary = CodeNativeWorldProvider.build(ServerStorage, TEMPORARY_WORLD_FOLDER_NAME)
		validateWorld(temporary, "temporary world build is invalid")

		published = temporary:Clone()
		published.Name = PUBLISH_WORLD_FOLDER_NAME
		validateWorld(published, "published world clone is invalid")

		if existing ~= nil then
			existing:Destroy()
		end

		published.Name = WORLD_FOLDER_NAME
		published.Parent = Workspace
		return published
	end)

	if temporary ~= nil and temporary.Parent ~= nil then
		temporary:Destroy()
	end
	if not ok and published ~= nil and published.Parent ~= nil then
		published:Destroy()
	end

	assert(ok, result)
	return result
end

function WorldService.start()
	if hasStarted then
		return
	end

	buildAndPublishFallback()
	hasStarted = true
end

return WorldService
