local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Vendor = script.Parent.Parent.Parent:WaitForChild("Vendor")

local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local ProfileStore = require(Vendor:WaitForChild("ProfileStore"))
local ProfileTemplate = require(script.Parent:WaitForChild("ProfileTemplate"))

local ProfilePersistence = {}

local DATA_STORE_NAME = "RitualCoreProfiles_v1"

local profileTemplate = ProfileTemplate.create()
local baseProfileStore = ProfileStore.New(DATA_STORE_NAME, profileTemplate)
local playerStore = if RunService:IsStudio() then baseProfileStore.Mock else baseProfileStore

local activeRecords = {}
local activeLoadTokens = {}
local nextRecordToken = 0
local nextLoadToken = 0

local function getProfileKey(player)
	return "Player_" .. tostring(player.UserId)
end

local function disconnect(connection)
	if connection ~= nil then
		connection:Disconnect()
	end
end

local function isCurrentRecord(player, profile, record)
	return record ~= nil
		and activeRecords[player] == record
		and record.Profile == profile
		and record.Session:IsActive()
		and record.IsEnding ~= true
end

local function clearActiveLoad(player, loadToken)
	if activeLoadTokens[player] == loadToken then
		activeLoadTokens[player] = nil
	end
end

local function endUnpublishedSession(session)
	if session ~= nil then
		pcall(function()
			if not session:IsActive() then
				return
			end

			session:EndSession()
		end)
	end
end

local function loadRuntimeProfile(session, nowUnix)
	local migratedData, migrationReason = ProfileTemplate.migrateBeforeReconcile(session.Data, nowUnix)

	if migratedData == nil then
		return nil, migrationReason
	end

	-- Normalize the detached migration before touching live session data. A
	-- malformed accepted-version profile therefore fails without being partly
	-- migrated by the final EndSession save.
	local profile = ProfileTemplate.createRuntimeProfile(migratedData, nowUnix)
	local normalizedData = ProfileTemplate.overlayDurable(session.Data, profile, nowUnix)
	ProfileTemplate.applyNormalizedDurable(profile, normalizedData)

	return profile
end

function ProfilePersistence.startSession(player, onSessionEnd)
	if
		player == nil
		or player.Parent ~= Players
		or activeRecords[player] ~= nil
		or activeLoadTokens[player] ~= nil
	then
		return nil, nil, "profile_load_unavailable"
	end

	nextLoadToken += 1
	local loadToken = nextLoadToken
	activeLoadTokens[player] = loadToken

	local loadStartedAt = os.clock()
	local startSucceeded, sessionOrError = pcall(function()
		return playerStore:StartSessionAsync(getProfileKey(player), {
			Cancel = function()
				return player.Parent ~= Players
					or activeLoadTokens[player] ~= loadToken
					or os.clock() - loadStartedAt >= ProfileContract.Session.LoadTimeoutSeconds
			end,
		})
	end)
	local session = if startSucceeded then sessionOrError else nil

	if session == nil then
		clearActiveLoad(player, loadToken)
		return nil, nil, if startSucceeded then "profile_load_unavailable" else "profile_load_failed"
	end

	if
		player.Parent ~= Players
		or activeLoadTokens[player] ~= loadToken
		or os.clock() - loadStartedAt >= ProfileContract.Session.LoadTimeoutSeconds
		or not session:IsActive()
	then
		clearActiveLoad(player, loadToken)
		endUnpublishedSession(session)
		return nil, nil, "profile_load_cancelled"
	end

	local nowUnix = DateTime.now().UnixTimestamp
	local success, profileOrError, migrationReason = pcall(function()
		session:AddUserId(player.UserId)
		return loadRuntimeProfile(session, nowUnix)
	end)

	if not success or profileOrError == nil then
		clearActiveLoad(player, loadToken)
		endUnpublishedSession(session)
		return nil, nil, if success then migrationReason else "profile_load_failed"
	end

	if
		player.Parent ~= Players
		or activeLoadTokens[player] ~= loadToken
		or os.clock() - loadStartedAt >= ProfileContract.Session.LoadTimeoutSeconds
		or not session:IsActive()
		or activeRecords[player] ~= nil
	then
		clearActiveLoad(player, loadToken)
		endUnpublishedSession(session)
		return nil, nil, "profile_load_stale"
	end

	nextRecordToken += 1
	local record = {
		Session = session,
		Profile = profileOrError,
		Token = nextRecordToken,
		EndConnection = nil,
		IsEnding = false,
		ConfirmedSaveBusy = false,
	}

	record.EndConnection = session.OnSessionEnd:Connect(function()
		-- ProfileStore makes the session inactive before this signal fires. The
		-- wrapper identity, rather than IsActive(), protects a newer record.
		if activeRecords[player] ~= record then
			return
		end

		activeRecords[player] = nil
		disconnect(record.EndConnection)
		record.EndConnection = nil

		if onSessionEnd ~= nil then
			onSessionEnd(player, record.Profile, record.Token)
		end
	end)

	activeRecords[player] = record
	clearActiveLoad(player, loadToken)

	if
		player.Parent ~= Players
		or os.clock() - loadStartedAt >= ProfileContract.Session.LoadTimeoutSeconds
		or not session:IsActive()
	then
		activeRecords[player] = nil
		disconnect(record.EndConnection)
		record.EndConnection = nil
		endUnpublishedSession(session)
		return nil, nil, "profile_load_stale"
	end

	return record.Profile, record.Token, nil
end

function ProfilePersistence.isCurrent(player, profile, token)
	local record = activeRecords[player]

	return isCurrentRecord(player, profile, record) and (token == nil or record.Token == token)
end

function ProfilePersistence.sync(player, profile)
	local record = activeRecords[player]

	if not isCurrentRecord(player, profile, record) then
		return false
	end

	local normalizedData = ProfileTemplate.overlayDurable(record.Session.Data, profile, DateTime.now().UnixTimestamp)
	ProfileTemplate.applyNormalizedDurable(profile, normalizedData)

	return isCurrentRecord(player, profile, record)
end

function ProfilePersistence.saveConfirmed(player, profile, receiptPredicate, timeoutSeconds)
	if typeof(receiptPredicate) ~= "function" then
		return false, "save_predicate_invalid"
	end

	if not ProfilePersistence.sync(player, profile) then
		return false, "profile_session_inactive"
	end

	local record = activeRecords[player]

	if not isCurrentRecord(player, profile, record) then
		return false, "profile_session_inactive"
	end

	if record.ConfirmedSaveBusy == true then
		return false, "save_confirmation_busy"
	end

	local timeout = ProfileContract.Session.ConfirmedSaveTimeoutSeconds

	if
		type(timeoutSeconds) == "number"
		and timeoutSeconds == timeoutSeconds
		and math.abs(timeoutSeconds) ~= math.huge
	then
		timeout = math.clamp(timeoutSeconds, 1, ProfileContract.Session.ConfirmedSaveTimeoutSeconds)
	end

	local function matchesReceipt(savedData)
		local predicateOk, receiptIsDurable = pcall(receiptPredicate, savedData)

		if not predicateOk then
			return false, "save_predicate_failed"
		end

		return receiptIsDurable == true, nil
	end

	local wasAlreadyDurable, predicateReason = matchesReceipt(record.Session.LastSavedData)

	if predicateReason ~= nil then
		return false, predicateReason
	end

	if wasAlreadyDurable then
		return true, nil
	end

	record.ConfirmedSaveBusy = true
	local completed = false
	local waiter = nil
	local saveConnection
	local endConnection
	local operationSucceeded, confirmed, completionReason = pcall(function()
		local didConfirm = false
		local reason = nil

		waiter = Instance.new("BindableEvent")

		local function finish(nextConfirmed, nextReason)
			if completed then
				return
			end

			completed = true
			didConfirm = nextConfirmed
			reason = nextReason
			waiter:Fire()
		end

		saveConnection = record.Session.OnAfterSave:Connect(function(lastSavedData)
			if
				activeRecords[player] ~= record
				or record.Profile ~= profile
				or not record.Session:IsActive()
			then
				finish(false, "profile_session_inactive")
				return
			end

			local receiptIsDurable, predicateFailure = matchesReceipt(lastSavedData)

			if predicateFailure ~= nil then
				finish(false, predicateFailure)
			elseif receiptIsDurable then
				finish(true, nil)
			end
		end)

		endConnection = record.Session.OnSessionEnd:Connect(function()
			finish(false, "profile_session_ended")
		end)

		task.delay(timeout, function()
			finish(false, "save_confirmation_timeout")
		end)

		local saveStarted = pcall(function()
			record.Session:Save()
		end)

		if not saveStarted then
			finish(false, "save_start_failed")
		end

		while not completed do
			waiter.Event:Wait()
		end

		return didConfirm, reason
	end)

	completed = true
	record.ConfirmedSaveBusy = false
	pcall(disconnect, saveConnection)
	pcall(disconnect, endConnection)

	if waiter ~= nil then
		pcall(function()
			waiter:Destroy()
		end)
	end

	if not operationSucceeded then
		return false, "save_confirmation_failed"
	end

	if confirmed ~= true or not isCurrentRecord(player, profile, record) then
		return false, completionReason or "profile_session_inactive"
	end

	return true, nil
end

function ProfilePersistence.releaseSession(player, profile, token)
	local record = activeRecords[player]

	if
		record == nil
		or profile == nil
		or token == nil
		or record.Profile ~= profile
		or record.Token ~= token
	then
		return false
	end

	if record.IsEnding == true then
		return false
	end

	record.IsEnding = true

	local synchronized = pcall(function()
		if record.Session:IsActive() then
			local normalizedData = ProfileTemplate.overlayDurable(
				record.Session.Data,
				record.Profile,
				DateTime.now().UnixTimestamp
			)
			ProfileTemplate.applyNormalizedDurable(record.Profile, normalizedData)
		end
	end)

	activeRecords[player] = nil
	disconnect(record.EndConnection)
	record.EndConnection = nil

	local ended = pcall(function()
		if record.Session:IsActive() then
			record.Session:EndSession()
		end
	end)

	return synchronized and ended
end

return ProfilePersistence
