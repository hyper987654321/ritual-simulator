local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Net"):WaitForChild("Network"))

local PlayerStateService = require(script.Parent.Parent:WaitForChild("Player"):WaitForChild("PlayerStateService"))

local PlayerVisualReplicationService = {}

local hasStarted = false
local publicVisualsByPlayer = {}
local publicVisualSignaturesByPlayer = {}
local rateBucketsByPlayer = {}

local REQUEST_PUBLIC_VISUALS_RATE_LIMIT = {
	Capacity = 3,
	RefillPerSecond = 0.5,
}

local function getEquippedPetPayloads(publicVisual)
	local equippedPets = {}

	for index, petInstance in ipairs(publicVisual.EquippedPets or {}) do
		if typeof(petInstance.PetId) == "string" then
			table.insert(equippedPets, {
				Uid = petInstance.Uid or petInstance.SlotId or index,
				SlotId = petInstance.SlotId or petInstance.Uid or index,
				PetId = petInstance.PetId,
			})
		end
	end

	return equippedPets
end

local function createPublicVisualPayload(player, publicVisual)
	if publicVisual == nil then
		return nil
	end

	return {
		UserId = player.UserId,
		PlayerName = player.Name,
		RitualPower = publicVisual.RitualPower or 0,
		Rebirths = publicVisual.Rebirths or 0,
		StoneStats = {
			Capacity = if publicVisual.StoneStats ~= nil then publicVisual.StoneStats.Capacity or 0 else 0,
		},
		EquippedPets = getEquippedPetPayloads(publicVisual),
	}
end

local function createPublicVisualSignature(payload)
	local parts = {
		tostring(payload.UserId or ""),
		tostring(payload.RitualPower or 0),
		tostring(payload.Rebirths or 0),
		tostring(if payload.StoneStats ~= nil then payload.StoneStats.Capacity or 0 else 0),
	}

	for _, petInstance in ipairs(payload.EquippedPets or {}) do
		table.insert(parts, tostring(petInstance.Uid or ""))
		table.insert(parts, tostring(petInstance.SlotId or ""))
		table.insert(parts, tostring(petInstance.PetId or ""))
	end

	return table.concat(parts, "|")
end

local function getPublicVisualList(excludedPlayer)
	local visuals = {}

	for player, payload in pairs(publicVisualsByPlayer) do
		if player ~= excludedPlayer then
			table.insert(visuals, payload)
		end
	end

	table.sort(visuals, function(left, right)
		return (left.UserId or 0) < (right.UserId or 0)
	end)

	return visuals
end

local function getPlayerRateBucket(player)
	local bucket = rateBucketsByPlayer[player]

	if bucket == nil then
		bucket = {
			Tokens = REQUEST_PUBLIC_VISUALS_RATE_LIMIT.Capacity,
			UpdatedAt = os.clock(),
		}
		rateBucketsByPlayer[player] = bucket
	end

	return bucket
end

local function consumeRequestPublicVisualsToken(player)
	local bucket = getPlayerRateBucket(player)
	local now = os.clock()
	local elapsed = math.max(0, now - bucket.UpdatedAt)

	bucket.Tokens = math.min(
		REQUEST_PUBLIC_VISUALS_RATE_LIMIT.Capacity,
		bucket.Tokens + elapsed * REQUEST_PUBLIC_VISUALS_RATE_LIMIT.RefillPerSecond
	)
	bucket.UpdatedAt = now

	if bucket.Tokens < 1 then
		return false
	end

	bucket.Tokens -= 1

	return true
end

local function firePublicVisualUpdatedToOtherPlayers(owner, publicVisualUpdated, payload)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= owner then
			publicVisualUpdated:FireClient(player, payload)
		end
	end
end

local function publishPlayerVisual(player, publicVisual, publicVisualUpdated)
	local payload = createPublicVisualPayload(player, publicVisual)

	if payload == nil then
		return
	end

	local signature = createPublicVisualSignature(payload)

	if publicVisualSignaturesByPlayer[player] == signature then
		return
	end

	publicVisualsByPlayer[player] = payload
	publicVisualSignaturesByPlayer[player] = signature
	firePublicVisualUpdatedToOtherPlayers(player, publicVisualUpdated, payload)
end

local function removePlayerVisual(player, publicVisualRemoved)
	if publicVisualsByPlayer[player] == nil then
		return
	end

	publicVisualsByPlayer[player] = nil
	publicVisualSignaturesByPlayer[player] = nil
	publicVisualRemoved:FireAllClients(player.UserId)
end

function PlayerVisualReplicationService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local publicVisualUpdated = Network.getRemoteEvent(Network.RemoteEvents.PublicVisualUpdated)
	local publicVisualRemoved = Network.getRemoteEvent(Network.RemoteEvents.PublicVisualRemoved)
	local requestPublicVisuals = Network.getRemoteFunction(Network.RemoteFunctions.RequestPublicVisuals)

	requestPublicVisuals.OnServerInvoke = function(player)
		if not consumeRequestPublicVisualsToken(player) then
			return {}
		end

		return getPublicVisualList(player)
	end

	PlayerStateService.subscribePublicVisualChanged(function(player, publicVisual)
		publishPlayerVisual(player, publicVisual, publicVisualUpdated)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerVisual(player, publicVisualRemoved)
		rateBucketsByPlayer[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		local publicVisual = PlayerStateService.getPublicVisual(player)

		if publicVisual ~= nil then
			publishPlayerVisual(player, publicVisual, publicVisualUpdated)
		end
	end
end

return PlayerVisualReplicationService
