local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local PresentationEventConfig = require(Config:WaitForChild("PresentationEventConfig"))

local SnapshotPublisher = {}

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local function isActiveProfile(player, profile)
	return profile ~= nil and PlayerStateService.isCurrentProfile(player, profile)
end

local function preparePlayerState(player)
	local profile = PlayerStateService.getProfile(player)

	if not isActiveProfile(player, profile) then
		return nil
	end

	if not PlayerStateService.syncProfile(player, profile) then
		return nil
	end

	if not isActiveProfile(player, profile) then
		return nil
	end

	local revision = PlayerStateService.advanceSnapshotRevision(player, profile)

	if revision == nil or not isActiveProfile(player, profile) then
		return nil
	end

	PlayerStateService.updateLeaderstatsFromProfile(player, profile)

	if not isActiveProfile(player, profile) then
		return nil
	end

	PlayerStateService.publishPublicVisual(player, profile)

	if not isActiveProfile(player, profile) then
		return nil
	end

	return profile
end

local function buildSnapshot(player)
	local profile = preparePlayerState(player)

	if profile == nil then
		return nil
	end

	local snapshot = PlayerStateService.getSnapshot(player, profile)

	if snapshot == nil or not isActiveProfile(player, profile) then
		return nil
	end

	return snapshot
end

local function buildCurrentSnapshot(player)
	local profile = PlayerStateService.getProfile(player)

	if not isActiveProfile(player, profile) then
		return nil
	end

	local snapshot = PlayerStateService.getSnapshot(player, profile)

	if snapshot == nil or not isActiveProfile(player, profile) then
		return nil
	end

	return snapshot
end

local function markProfileSessionInactive(response)
	response.Ok = false
	response.Changed = response.Changed == true
	response.Code = "profile_session_inactive"
	response.Reason = "profile_session_inactive"
	response.Message = "Player profile session is no longer active."
	response.Snapshot = nil

	return response
end

local function mergeFeedback(player, profile, first)
	local merged = {}

	for _, record in ipairs(PresentationEventConfig.sanitizeRecords(first)) do
		table.insert(merged, record)
	end

	local remaining = PresentationEventConfig.MaxRecordsPerPacket - #merged

	if remaining > 0 then
		for _, record in ipairs(PlayerStateService.takeFeedback(player, profile, remaining)) do
			table.insert(merged, record)
		end
	end

	return if #merged > 0 then merged else nil
end

function SnapshotPublisher.attach(player, result)
	local response = result or {}
	local includeUnchangedSnapshot = response.IncludeSnapshot == true

	response.Changed = response.Changed == true
	response.IncludeSnapshot = nil

	if not response.Changed and not includeUnchangedSnapshot then
		return response
	end

	local snapshot = if response.Changed then buildSnapshot(player) else buildCurrentSnapshot(player)

	if snapshot == nil then
		return markProfileSessionInactive(response)
	end

	response.Snapshot = snapshot
	response.Feedback = mergeFeedback(player, PlayerStateService.getProfile(player), response.Feedback)

	return response
end

function SnapshotPublisher.publishCrystalUpdate(player, crystalStateUpdated, requestedSections)
	if crystalStateUpdated == nil then
		return nil
	end

	local profile = preparePlayerState(player)

	if profile == nil then
		return nil
	end

	local crystalUpdate = PlayerStateService.getCrystalUpdate(player, profile, requestedSections)

	if crystalUpdate == nil or not isActiveProfile(player, profile) then
		return nil
	end

	crystalUpdate.Feedback = mergeFeedback(player, profile, crystalUpdate.Feedback)

	crystalStateUpdated:FireClient(player, crystalUpdate)

	return crystalUpdate
end

function SnapshotPublisher.publishPlayerStateUpdate(player, playerStateUpdated, requestedSections)
	if playerStateUpdated == nil or typeof(requestedSections) ~= "table" then
		return nil
	end

	local profile = preparePlayerState(player)

	if profile == nil then
		return nil
	end

	local sections = PlayerStateService.getPlayerStateSections(player, profile, requestedSections)

	if sections == nil or not isActiveProfile(player, profile) then
		return nil
	end

	local update = {
		SchemaVersion = 1,
		Revision = profile.SnapshotRevision or 0,
		Sections = sections,
	}

	update.Feedback = mergeFeedback(player, profile, nil)
	playerStateUpdated:FireClient(player, update)

	return update
end

function SnapshotPublisher.publishFeedbackUpdate(player, playerStateUpdated)
	if playerStateUpdated == nil then
		return nil
	end

	local profile = PlayerStateService.getProfile(player)

	if not isActiveProfile(player, profile) then
		return nil
	end

	local feedback = mergeFeedback(player, profile, nil)

	if feedback == nil or not isActiveProfile(player, profile) then
		return nil
	end

	local update = {
		SchemaVersion = 1,
		Revision = profile.SnapshotRevision or 0,
		Sections = {},
		Feedback = feedback,
	}

	playerStateUpdated:FireClient(player, update)

	return update
end

return SnapshotPublisher
