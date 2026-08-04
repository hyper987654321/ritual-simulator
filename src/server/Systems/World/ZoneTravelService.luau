local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapGen = Shared:WaitForChild("MapGen")
local Network = require(Shared:WaitForChild("Net"):WaitForChild("Network"))

local GeneratedMapRuntime = require(MapGen:WaitForChild("GeneratedMapRuntime"))

local Systems = script.Parent.Parent
local PlayerStateService = require(Systems:WaitForChild("Player"):WaitForChild("PlayerStateService"))
local SnapshotPublisher = require(Systems:WaitForChild("Player"):WaitForChild("SnapshotPublisher"))

local ZoneTravelService = {}

local ZONE_POLL_SECONDS = 0.25

local hasStarted = false
local crystalStateUpdated = nil
local playerStateUpdated = nil

local function getCharacterRootPosition(player)
	local character = player.Character

	if character == nil then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")

	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	return root.Position
end

local function syncPlayerZone(player)
	local position = getCharacterRootPosition(player)
	local zoneId = GeneratedMapRuntime.getZoneIdForPosition(position)
	local result = nil

	if zoneId ~= nil then
		result = PlayerStateService.enterActiveZone(player, zoneId)
	else
		result = PlayerStateService.exitActiveZone(player)
	end

	return result
end

local function stepFarming(player)
	local result = PlayerStateService.processCrystalFarming(player)

	return result
end

local function mergeDirtySections(target, source)
	if typeof(source) ~= "table" then
		return target
	end

	for sectionName, isDirty in pairs(source) do
		if isDirty == true then
			target[sectionName] = true
		end
	end

	return target
end

local function stepPlayer(player)
	local zoneResult = nil
	local farmingResult = nil
	local feedbackReady = false

	local ok, err = pcall(PlayerStateService.withProfileLock, player, function()
		zoneResult = syncPlayerZone(player)
		farmingResult = stepFarming(player)
		feedbackReady = PlayerStateService.hasReadyFeedback(player)
		local zoneChanged = typeof(zoneResult) == "table" and zoneResult.Changed == true
		local farmingChanged = typeof(farmingResult) == "table"
			and farmingResult.Ok == true
			and farmingResult.Changed == true

		if zoneChanged or farmingChanged then
			local dirtySections = mergeDirtySections({}, farmingResult and farmingResult.DirtySections)

			if zoneChanged then
				dirtySections.CurrentZone = true
				dirtySections.Zones = true
				dirtySections.Onboarding = true
				dirtySections.Crystal = true
				dirtySections.RuneFocus = true
				dirtySections.RitualPower = true
			end

			if farmingResult ~= nil and farmingResult.UsePlayerStateUpdated == true then
				SnapshotPublisher.publishPlayerStateUpdate(player, playerStateUpdated, dirtySections)
			else
				SnapshotPublisher.publishCrystalUpdate(player, crystalStateUpdated, dirtySections)
			end
		elseif feedbackReady then
			SnapshotPublisher.publishFeedbackUpdate(player, playerStateUpdated)
		end
	end)

	if not ok then
		warn("[ZoneTravelService] Failed to step player:", err)
	end
end

function ZoneTravelService.start()
	if hasStarted then
		return
	end

	hasStarted = true
	crystalStateUpdated = Network.getRemoteEvent(Network.RemoteEvents.CrystalStateUpdated)
	playerStateUpdated = Network.getRemoteEvent(Network.RemoteEvents.PlayerStateUpdated)

	task.spawn(function()
		while hasStarted do
			for _, player in ipairs(Players:GetPlayers()) do
				stepPlayer(player)
			end

			task.wait(ZONE_POLL_SECONDS)
		end
	end)
end

return ZoneTravelService
