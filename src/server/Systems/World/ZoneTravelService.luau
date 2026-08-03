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

	return result.Changed == true
end

local function stepFarming(player)
	local result = PlayerStateService.processCrystalFarming(player)

	return result.Ok == true and result.Changed == true
end

local function stepPlayer(player)
	local zoneChanged = false
	local farmingChanged = false

	local ok, err = pcall(PlayerStateService.withProfileLock, player, function()
		zoneChanged = syncPlayerZone(player)
		farmingChanged = stepFarming(player)

		if zoneChanged or farmingChanged then
			SnapshotPublisher.publishCrystalUpdate(player, crystalStateUpdated)
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
