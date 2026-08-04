local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local LeaderboardConfig = require(Config:WaitForChild("LeaderboardConfig"))
local CurrentServerLeaderboard = require(script.Parent:WaitForChild("CurrentServerLeaderboard"))

local LeaderboardService = {}

local BOARD_FOLDER_NAME = "GeneratedLeaderboards"

local hasStarted = false
local recordProvider = nil
local publicationProvider = nil
local lastSignature = nil

function LeaderboardService.setRecordProvider(provider)
	recordProvider = provider
end

function LeaderboardService.setPublicationProvider(provider)
	publicationProvider = provider
end

function LeaderboardService.getSnapshot()
	local records = if typeof(recordProvider) == "function" then recordProvider() else {}
	local snapshot = { Boards = {} }
	for _, boardId in ipairs(LeaderboardConfig.BoardOrder) do
		table.insert(snapshot.Boards, CurrentServerLeaderboard.get(boardId, records, os.clock(), false))
	end
	return snapshot
end

local function getSignature(snapshot)
	local parts = {}
	for _, board in ipairs(snapshot.Boards or {}) do
		table.insert(parts, tostring(board.BoardId))
		for _, row in ipairs(board.Rows or {}) do
			table.insert(parts, tostring(row.UserId) .. ":" .. tostring(row.Value) .. ":" .. tostring(row.Rank))
		end
	end
	return table.concat(parts, "|")
end

function LeaderboardService.publishIfChanged(force)
	local snapshot = LeaderboardService.getSnapshot()
	local signature = getSignature(snapshot)
	if not force and signature == lastSignature then return false end
	lastSignature = signature
	if typeof(publicationProvider) == "function" then
		for _, record in ipairs(if typeof(recordProvider) == "function" then recordProvider() else {}) do
			if typeof(record) == "table" and record.Player ~= nil then
				publicationProvider(record.Player)
			end
		end
	end
	return true
end

function LeaderboardService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local existing = Workspace:FindFirstChild(BOARD_FOLDER_NAME)

	if existing ~= nil then
		existing:Destroy()
	end

	task.spawn(function()
		while hasStarted do
			task.wait(5)
			LeaderboardService.publishIfChanged(false)
		end
	end)
end

return LeaderboardService
