local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = {}

Network.FolderName = "RitualCoreRemotes"

local REMOTE_WAIT_TIMEOUT_SECONDS = 15

Network.RemoteEvents = {
	CrystalStateUpdated = "CrystalStateUpdated",
	PublicVisualUpdated = "PublicVisualUpdated",
	PublicVisualRemoved = "PublicVisualRemoved",
}

Network.RemoteFunctions = {
	RequestAction = "RequestAction",
	RequestSnapshot = "RequestSnapshot",
	RequestPublicVisuals = "RequestPublicVisuals",
}

Network.Actions = {
	RollPet = "RollPet",
	BuyStoneUpgrade = "BuyStoneUpgrade",
	UnlockZone = "UnlockZone",
	SelectZone = "SelectZone",
	Rebirth = "Rebirth",
	Ascend = "Ascend",
	BuyRune = "BuyRune",
	CompleteTutorialStep = "CompleteTutorialStep",
	ClaimRitualRushReward = "ClaimRitualRushReward",
	ClaimRitualRushFreeReward = "ClaimRitualRushFreeReward",
	UsePotion = "UsePotion",
	BuyPotionWithGems = "BuyPotionWithGems",
}

local function getFolder()
	local folder = ReplicatedStorage:FindFirstChild(Network.FolderName)

	if folder == nil and RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = Network.FolderName
		folder.Parent = ReplicatedStorage
	end

	if folder == nil then
		folder = ReplicatedStorage:WaitForChild(Network.FolderName, REMOTE_WAIT_TIMEOUT_SECONDS)
	end

	if folder == nil then
		error("Missing remote folder: " .. Network.FolderName, 2)
	end

	return folder
end

local function getRemote(name, className)
	local folder = getFolder()
	local remote = folder:FindFirstChild(name)

	if remote == nil and RunService:IsServer() then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end

	if remote == nil then
		remote = folder:WaitForChild(name, REMOTE_WAIT_TIMEOUT_SECONDS)
	end

	if remote == nil then
		error("Missing " .. className .. ": " .. name, 2)
	end

	return remote
end

function Network.getRemoteEvent(name)
	return getRemote(name, "RemoteEvent")
end

function Network.getRemoteFunction(name)
	return getRemote(name, "RemoteFunction")
end

return Network
