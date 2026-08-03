local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Vendor = script.Parent.Parent.Parent:WaitForChild("Vendor")
local ProfileStore = require(Vendor:WaitForChild("ProfileStore"))

local ProfileTemplate = require(script.Parent:WaitForChild("ProfileTemplate"))

local ProfilePersistence = {}

local DATA_STORE_NAME = "RitualCoreProfiles_v1"

local profileTemplate = ProfileTemplate.create()
local baseProfileStore = ProfileStore.New(DATA_STORE_NAME, profileTemplate)
local playerStore = if RunService:IsStudio() then baseProfileStore.Mock else baseProfileStore
local activeSessions = {}
local sessionEndConnections = {}

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, childValue in pairs(value) do
		copy[key] = deepCopy(childValue)
	end

	return copy
end

local function getProfileKey(player)
	return "Player_" .. tostring(player.UserId)
end

local function clearSession(player)
	local sessionEndConnection = sessionEndConnections[player]

	if sessionEndConnection ~= nil then
		sessionEndConnection:Disconnect()
		sessionEndConnections[player] = nil
	end

	activeSessions[player] = nil
end

local function copyDurableFields(target, profile)
	for key in pairs(target) do
		target[key] = nil
	end

	for key, defaultValue in pairs(profileTemplate) do
		target[key] = deepCopy(if profile[key] ~= nil then profile[key] else defaultValue)
	end

	target.Version = ProfileTemplate.DATA_VERSION
end

local function createRuntimeProfile(savedData)
	local profile = deepCopy(savedData)

	return ProfileTemplate.applyRuntimeDefaults(profile)
end

function ProfilePersistence.startSession(player, onSessionEnd)
	local session = playerStore:StartSessionAsync(getProfileKey(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if player.Parent ~= Players then
		if session ~= nil and session:IsActive() then
			session:EndSession()
		end

		return nil
	end

	if session == nil then
		return nil
	end

	session:AddUserId(player.UserId)
	session:Reconcile()

	local profile = createRuntimeProfile(session.Data)
	copyDurableFields(session.Data, profile)

	clearSession(player)

	sessionEndConnections[player] = session.OnSessionEnd:Connect(function()
		clearSession(player)

		if onSessionEnd ~= nil then
			onSessionEnd(player)
		end
	end)

	activeSessions[player] = session

	return profile
end

function ProfilePersistence.sync(player, profile)
	local session = activeSessions[player]

	if session == nil or not session:IsActive() then
		return false
	end

	copyDurableFields(session.Data, profile)

	return true
end

function ProfilePersistence.save(player, profile)
	local session = activeSessions[player]

	if session == nil or not session:IsActive() then
		return false
	end

	copyDurableFields(session.Data, profile)
	session:Save()

	return true
end

function ProfilePersistence.releaseSession(player, profile)
	local session = activeSessions[player]

	if session == nil then
		clearSession(player)
		return
	end

	if profile ~= nil and session:IsActive() then
		copyDurableFields(session.Data, profile)
	end

	clearSession(player)

	if session:IsActive() then
		session:EndSession()
	end
end

return ProfilePersistence
