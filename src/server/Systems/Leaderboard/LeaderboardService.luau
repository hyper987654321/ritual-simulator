local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local LeaderboardConfig = require(Config:WaitForChild("LeaderboardConfig"))
local CurrentServerLeaderboard = require(script.Parent:WaitForChild("CurrentServerLeaderboard"))

local LeaderboardService = {}

local BOARD_FOLDER_NAME = "GeneratedLeaderboards"

local hasStarted = false
local recordProvider = nil

function LeaderboardService.setRecordProvider(provider)
	recordProvider = provider
end

function LeaderboardService.getSnapshot()
	local records = if typeof(recordProvider) == "function" then recordProvider() else {}
	local snapshot = { Boards = {} }
	for _, boardId in ipairs(LeaderboardConfig.BoardOrder) do
		table.insert(snapshot.Boards, CurrentServerLeaderboard.get(boardId, records, os.clock(), false))
	end
	return snapshot
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
end

return LeaderboardService
