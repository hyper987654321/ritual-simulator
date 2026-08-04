local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local PetConfig = require(Config:WaitForChild("PetConfig"))
local PetPresentationResolver = require(script.Parent:WaitForChild("PetPresentation"):WaitForChild("Resolver"))

local PetModelReplicationService = {}

local PET_MODEL_FOLDER_NAME = "PetModels"

local hasStarted = false

local function createReplicatedFolder()
	local folder = Instance.new("Folder")
	folder.Name = PET_MODEL_FOLDER_NAME

	return folder
end

local function replaceReplicatedFolder(folder)
	local existingFolder = ReplicatedStorage:FindFirstChild(PET_MODEL_FOLDER_NAME)

	if existingFolder ~= nil then
		existingFolder:Destroy()
	end

	folder.Parent = ReplicatedStorage
end

local function getRequiredBasePetIds()
	local requiredBasePetIds = {}
	local requiredByBasePetId = {}

	for _, basePetId in ipairs(PetConfig.BaseRollOrder) do
		if typeof(basePetId) == "string" and PetConfig.getBasePet(basePetId) ~= nil then
			if requiredByBasePetId[basePetId] == true then
				warn("Duplicate pet model id in PetConfig.BaseRollOrder:", basePetId)
			else
				requiredByBasePetId[basePetId] = true
				table.insert(requiredBasePetIds, basePetId)
			end
		else
			warn("Skipping invalid base pet id in PetConfig.BaseRollOrder:", tostring(basePetId))
		end
	end

	return requiredBasePetIds, requiredByBasePetId
end

local function warnUnusedSourceChildren(sourceFolder, requiredByBasePetId)
	for _, sourceChild in ipairs(sourceFolder:GetChildren()) do
		if requiredByBasePetId[sourceChild.Name] ~= true then
			warn("Unused pet model template in ServerStorage.PetModels; not replicated:", sourceChild:GetFullName())
		end
	end
end

local function publishPetModels()
	local replicatedFolder = createReplicatedFolder()
	local sourceFolder = ServerStorage:FindFirstChild(PET_MODEL_FOLDER_NAME)
	local requiredBasePetIds, requiredByBasePetId = getRequiredBasePetIds()

	if sourceFolder == nil then
		warn("ServerStorage.PetModels is missing; using code-native pet placeholders.")
		for _, basePetId in ipairs(requiredBasePetIds) do
			local resolvedModel = PetPresentationResolver.resolve(basePetId, PetConfig.getBasePet(basePetId), nil)
			resolvedModel.Parent = replicatedFolder
		end
		replaceReplicatedFolder(replicatedFolder)
		return
	end

	for _, basePetId in ipairs(requiredBasePetIds) do
		local sourceModel = sourceFolder:FindFirstChild(basePetId)

		if sourceModel == nil then
			warn("Missing required pet model template; using code-native placeholder:", basePetId)
		elseif not sourceModel:IsA("Model") then
			warn("Invalid required pet visual template; using code-native placeholder:", sourceModel:GetFullName())
		end

		local resolvedModel = PetPresentationResolver.resolve(basePetId, PetConfig.getBasePet(basePetId), sourceModel)
		resolvedModel.Parent = replicatedFolder
	end

	warnUnusedSourceChildren(sourceFolder, requiredByBasePetId)
	replaceReplicatedFolder(replicatedFolder)
end

function PetModelReplicationService.start()
	if hasStarted then
		return
	end

	hasStarted = true
	publishPetModels()
end

return PetModelReplicationService
