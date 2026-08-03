local SnapshotPublisher = {}

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local function commitPlayerState(player)
	local revision = PlayerStateService.advanceSnapshotRevision(player)

	if revision == nil then
		return false
	end

	PlayerStateService.syncProfile(player)
	PlayerStateService.updateLeaderstatsFromProfile(player)
	PlayerStateService.publishPublicVisual(player)

	return true
end

local function buildSnapshot(player)
	if not commitPlayerState(player) then
		return nil
	end

	return PlayerStateService.getSnapshot(player)
end

function SnapshotPublisher.attach(player, result)
	local response = result or {}

	response.Snapshot = buildSnapshot(player)

	return response
end

function SnapshotPublisher.publishCrystalUpdate(player, crystalStateUpdated)
	if crystalStateUpdated == nil then
		return nil
	end

	if not commitPlayerState(player) then
		return nil
	end

	local crystalUpdate = PlayerStateService.getCrystalUpdate(player)

	if crystalUpdate == nil then
		return nil
	end

	crystalStateUpdated:FireClient(player, crystalUpdate)

	return crystalUpdate
end

return SnapshotPublisher
