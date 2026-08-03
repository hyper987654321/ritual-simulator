local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AbyssalHalfCrownAura = require(script.Parent:WaitForChild("AbyssalHalfCrownAura"))

local AbyssalHalfCrownAuraController = {}

local FULL_EFFECT_DISTANCE = 64
local MAX_EFFECT_DISTANCE = 118

local localPlayer = Players.LocalPlayer
local hasStarted = false
local aurasByPlayer = {}
local connectionsByPlayer = {}
local heartbeatConnection = nil

local function destroyAura(player)
	local aura = aurasByPlayer[player]

	if aura ~= nil then
		AbyssalHalfCrownAura.destroy(aura)
		aurasByPlayer[player] = nil
	end
end

local function attachAura(player, character)
	task.spawn(function()
		local rootPart = character:WaitForChild("HumanoidRootPart", 10)

		if
			rootPart == nil
			or not rootPart:IsA("BasePart")
			or player.Character ~= character
			or character.Parent == nil
		then
			return
		end

		destroyAura(player)
		aurasByPlayer[player] = AbyssalHalfCrownAura.create(character)
	end)
end

local function unwatchPlayer(player)
	destroyAura(player)

	local connections = connectionsByPlayer[player]

	if connections ~= nil then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end

		connectionsByPlayer[player] = nil
	end
end

local function watchPlayer(player)
	if connectionsByPlayer[player] ~= nil then
		return
	end

	connectionsByPlayer[player] = {
		player.CharacterAdded:Connect(function(character)
			attachAura(player, character)
		end),
		player.CharacterRemoving:Connect(function(character)
			local aura = aurasByPlayer[player]

			if aura ~= nil and aura.Character == character then
				destroyAura(player)
			end
		end),
	}

	if player.Character ~= nil then
		attachAura(player, player.Character)
	end
end

local function getQualityLevel(player, aura, cameraPosition)
	if player == localPlayer then
		return AbyssalHalfCrownAura.Quality.Full
	end

	local distance = (aura.RootPart.Position - cameraPosition).Magnitude

	if distance <= FULL_EFFECT_DISTANCE then
		return AbyssalHalfCrownAura.Quality.Full
	elseif distance <= MAX_EFFECT_DISTANCE then
		return AbyssalHalfCrownAura.Quality.Reduced
	end

	return AbyssalHalfCrownAura.Quality.Hidden
end

local function updateAuras()
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera ~= nil then camera.CFrame.Position else Vector3.zero
	local timeNow = os.clock()

	for player, aura in pairs(aurasByPlayer) do
		if aura == nil or not AbyssalHalfCrownAura.update(aura, timeNow) then
			aurasByPlayer[player] = nil
		else
			AbyssalHalfCrownAura.setQualityLevel(aura, getQualityLevel(player, aura, cameraPosition))
		end
	end
end

function AbyssalHalfCrownAuraController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(unwatchPlayer)
	heartbeatConnection = RunService.Heartbeat:Connect(updateAuras)
end

return AbyssalHalfCrownAuraController
