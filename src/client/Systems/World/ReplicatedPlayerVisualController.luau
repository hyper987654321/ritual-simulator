local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Net"):WaitForChild("Network"))

local PetModelVisualFactory = require(script.Parent:WaitForChild("PetModelVisualFactory"))
local PetFollowerLayout = require(script.Parent:WaitForChild("PetFollowerLayout"))

local Systems = script.Parent.Parent
local RitualStoneVisualFactory = require(Systems:WaitForChild("Ritual"):WaitForChild("RitualStoneVisualFactory"))

local ReplicatedPlayerVisualController = {}

local REMOTE_VISUAL_FOLDER_NAME = "LocalRemotePlayerVisuals"
local PUBLIC_VISUAL_REQUEST_ATTEMPTS = 3
local PUBLIC_VISUAL_REQUEST_RETRY_SECONDS = 1
local PUBLIC_VISUAL_REQUEST_TIMEOUT_SECONDS = 4
local REMOTE_FULL_EFFECT_DISTANCE = 80

local localPlayer = Players.LocalPlayer
local hasStarted = false
local remoteVisualFolder = nil
local entriesByUserId = {}
local renderConnection = nil
local publicVisualUpdatedRemote = nil
local publicVisualRemovedRemote = nil
local requestPublicVisualsRemote = nil

local function getPlayerFolderName(userId)
	return "Player_" .. tostring(userId)
end

local function getCharacterRoot(userId)
	local owner = Players:GetPlayerByUserId(userId)
	local character = if owner ~= nil then owner.Character else nil

	if character == nil then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if root ~= nil and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function shouldReducePetEffects(remoteRoot, localRoot)
	if remoteRoot == nil or localRoot == nil then
		return true
	end

	return (remoteRoot.Position - localRoot.Position).Magnitude > REMOTE_FULL_EFFECT_DISTANCE
end

local function createStoneSnapshot(payload)
	return {
		Rebirths = payload.Rebirths or 0,
		RitualPower = payload.RitualPower or 0,
		StoneStats = {
			Capacity = if payload.StoneStats ~= nil then payload.StoneStats.Capacity or 0 else 0,
		},
	}
end

local function createRemotePetVisual(entry, petUid, petId)
	local petVisual = PetModelVisualFactory.create(entry.RenderFolder, petUid, petId)

	if petVisual ~= nil then
		petVisual.Model:SetAttribute("OwnerUserId", entry.UserId)
		PetModelVisualFactory.setVisible(petVisual, false)
	end

	return petVisual
end

local function destroyRemotePet(petVisual)
	PetModelVisualFactory.destroy(petVisual)
end

local function updateRenderLoop()
	local hasRemoteEntries = next(entriesByUserId) ~= nil

	if hasRemoteEntries and renderConnection == nil then
		renderConnection = RunService.Heartbeat:Connect(function(dt)
			local timeNow = os.clock()
			local localRoot = getCharacterRoot(localPlayer.UserId)

			for _, entry in pairs(entriesByUserId) do
				local root = getCharacterRoot(entry.UserId)
				local alpha = math.clamp(dt * 7, 0, 1)
				local reducePetEffects = shouldReducePetEffects(root, localRoot)

				if root == nil then
					RitualStoneVisualFactory.setVisible(entry.StoneVisual, false)
					entry.StoneVisual.HasPosition = false
					entry.FollowLookDirection = nil

					for _, petVisual in pairs(entry.PetsByUid) do
						PetModelVisualFactory.setVisible(petVisual, false)
						petVisual.HasPosition = false
					end
				else
					RitualStoneVisualFactory.updateFollow(entry.StoneVisual, root.CFrame, timeNow, dt)
					RitualStoneVisualFactory.setVisible(entry.StoneVisual, true)

					local followRootCFrame = nil

					followRootCFrame, entry.FollowLookDirection = PetFollowerLayout.getFollowRootCFrame(
						root,
						entry.FollowLookDirection,
						dt
					)

					for index, petUid in ipairs(entry.PetOrder) do
						local petVisual = entry.PetsByUid[petUid]

						if petVisual ~= nil then
							local homeCFrame = PetFollowerLayout.getHomeCFrame(followRootCFrame, index, #entry.PetOrder, timeNow)
							local targetCFrame = PetModelVisualFactory.getFacingCFrame(
								homeCFrame.Position,
								homeCFrame.LookVector
							)

							if petVisual.HasPosition then
								PetModelVisualFactory.pivotTo(
									petVisual,
									PetModelVisualFactory.getCFrame(petVisual):Lerp(targetCFrame, alpha)
								)
							else
								PetModelVisualFactory.pivotTo(petVisual, targetCFrame)
								petVisual.HasPosition = true
							end

							PetModelVisualFactory.setVisible(petVisual, true)
							PetModelVisualFactory.updateEffects(petVisual, timeNow, {
								Reduced = reducePetEffects,
							})
						end
					end
				end
			end
		end)
	elseif not hasRemoteEntries and renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function destroyEntry(userId)
	local entry = entriesByUserId[userId]

	if entry == nil then
		return
	end

	for _, petVisual in pairs(entry.PetsByUid) do
		destroyRemotePet(petVisual)
	end

	if entry.RenderFolder.Parent ~= nil then
		entry.RenderFolder:Destroy()
	end

	entriesByUserId[userId] = nil
	updateRenderLoop()
end

local function getOrCreateEntry(userId)
	local entry = entriesByUserId[userId]

	if entry ~= nil then
		return entry
	end

	if remoteVisualFolder == nil then
		return nil
	end

	local renderFolder = Instance.new("Folder")
	renderFolder.Name = getPlayerFolderName(userId)
	renderFolder.Parent = remoteVisualFolder

	local stoneFolder = Instance.new("Folder")
	stoneFolder.Name = "RitualStone"
	stoneFolder.Parent = renderFolder

	entry = {
		UserId = userId,
		RenderFolder = renderFolder,
		StoneVisual = RitualStoneVisualFactory.create(stoneFolder),
		StoneSnapshot = nil,
		PetsByUid = {},
		PetOrder = {},
		FollowLookDirection = nil,
	}

	RitualStoneVisualFactory.setVisible(entry.StoneVisual, false)
	entriesByUserId[userId] = entry
	updateRenderLoop()

	return entry
end

local function syncPets(entry, equippedPets)
	local safeEquippedPets = if typeof(equippedPets) == "table" then equippedPets else {}
	local seenPetUids = {}
	local nextOrder = {}

	for index, petInstance in ipairs(safeEquippedPets) do
		local petUid = petInstance.Uid or petInstance.SlotId or index
		local petId = petInstance.PetId

		if typeof(petUid) == "number" and typeof(petId) == "string" then
			seenPetUids[petUid] = true
			table.insert(nextOrder, petUid)

			local petVisual = entry.PetsByUid[petUid]

			if petVisual == nil or petVisual.PetId ~= petId then
				destroyRemotePet(petVisual)
				entry.PetsByUid[petUid] = createRemotePetVisual(entry, petUid, petId)
			end
		end
	end

	for petUid, petVisual in pairs(entry.PetsByUid) do
		if seenPetUids[petUid] ~= true then
			destroyRemotePet(petVisual)
			entry.PetsByUid[petUid] = nil
		end
	end

	entry.PetOrder = nextOrder
end

local function applyPublicVisual(payload)
	if typeof(payload) ~= "table" or typeof(payload.UserId) ~= "number" then
		return
	end

	if payload.UserId == localPlayer.UserId then
		destroyEntry(payload.UserId)
		return
	end

	local entry = getOrCreateEntry(payload.UserId)

	if entry == nil then
		return
	end

	entry.StoneSnapshot = createStoneSnapshot(payload)
	RitualStoneVisualFactory.updateStats(entry.StoneVisual, entry.StoneSnapshot)
	syncPets(entry, payload.EquippedPets)
end

local function applyPublicVisualList(publicVisuals)
	if typeof(publicVisuals) ~= "table" then
		return
	end

	for _, payload in ipairs(publicVisuals) do
		applyPublicVisual(payload)
	end
end

local function invokeRequestPublicVisualsWithTimeout()
	local didFinish = false
	local ok = false
	local publicVisuals = nil

	task.spawn(function()
		ok, publicVisuals = pcall(function()
			return requestPublicVisualsRemote:InvokeServer()
		end)
		didFinish = true
	end)

	local startedAt = os.clock()

	while
		not didFinish
		and hasStarted
		and os.clock() - startedAt < PUBLIC_VISUAL_REQUEST_TIMEOUT_SECONDS
	do
		task.wait()
	end

	if not didFinish then
		return false, "Timed out requesting public player visuals."
	end

	return ok, publicVisuals
end

local function requestInitialPublicVisuals()
	local lastError = nil

	for attempt = 1, PUBLIC_VISUAL_REQUEST_ATTEMPTS do
		local ok, publicVisuals = invokeRequestPublicVisualsWithTimeout()

		if ok and typeof(publicVisuals) == "table" then
			applyPublicVisualList(publicVisuals)
			return
		end

		lastError = if ok then "Unexpected public player visuals response." else publicVisuals

		if attempt < PUBLIC_VISUAL_REQUEST_ATTEMPTS then
			task.wait(PUBLIC_VISUAL_REQUEST_RETRY_SECONDS)
		end
	end

	warn("Failed to request public player visuals:", lastError)
end

function ReplicatedPlayerVisualController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	publicVisualUpdatedRemote = Network.getRemoteEvent(Network.RemoteEvents.PublicVisualUpdated)
	publicVisualRemovedRemote = Network.getRemoteEvent(Network.RemoteEvents.PublicVisualRemoved)
	requestPublicVisualsRemote = Network.getRemoteFunction(Network.RemoteFunctions.RequestPublicVisuals)

	local existingRemoteVisualFolder = Workspace:FindFirstChild(REMOTE_VISUAL_FOLDER_NAME)

	if existingRemoteVisualFolder ~= nil then
		existingRemoteVisualFolder:Destroy()
	end

	remoteVisualFolder = Instance.new("Folder")
	remoteVisualFolder.Name = REMOTE_VISUAL_FOLDER_NAME
	remoteVisualFolder.Parent = Workspace

	publicVisualUpdatedRemote.OnClientEvent:Connect(applyPublicVisual)
	publicVisualRemovedRemote.OnClientEvent:Connect(function(userId)
		if typeof(userId) == "number" then
			destroyEntry(userId)
		end
	end)
	Players.PlayerRemoving:Connect(function(leavingPlayer)
		destroyEntry(leavingPlayer.UserId)
	end)

	task.spawn(requestInitialPublicVisuals)
end

return ReplicatedPlayerVisualController
