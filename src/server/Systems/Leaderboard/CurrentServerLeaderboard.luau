local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LeaderboardConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LeaderboardConfig"))

local CurrentServerLeaderboard = {}
local cache = {}

local function safeInteger(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, 9_007_199_254_740_991)
end

local function safePlayer(record)
	local player = if typeof(record) == "table" and record.Player ~= nil then record.Player else record
	local profile = if typeof(record) == "table" then record.Profile else nil
	local ready = if typeof(record) == "table" and record.ProfileReady ~= nil then record.ProfileReady == true else profile ~= nil
	return player, profile, ready
end

function CurrentServerLeaderboard.build(boardId, records)
	local definition = LeaderboardConfig.getBoard(boardId)
	if definition == nil or typeof(records) ~= "table" then
		return { BoardId = boardId, Rows = {} }
	end
	local candidates = {}
	for _, record in ipairs(records) do
		local player, profile, ready = safePlayer(record)
		local userId = safeInteger(player and player.UserId)
		if ready and userId > 0 and typeof(profile) == "table" then
			table.insert(candidates, {
				UserId = userId,
				DisplayName = if typeof(player.DisplayName) == "string" then player.DisplayName else "",
				Name = if typeof(player.Name) == "string" then player.Name else "",
				Value = safeInteger(profile[definition.SourceField]),
			})
		end
	end
	table.sort(candidates, function(left, right)
		if left.Value ~= right.Value then return left.Value > right.Value end
		return left.UserId < right.UserId
	end)
	local rows = {}
	for index = 1, math.min(LeaderboardConfig.MaximumRows, #candidates) do
		local candidate = candidates[index]
		table.insert(rows, { Rank = index, UserId = candidate.UserId, DisplayName = candidate.DisplayName, Name = candidate.Name, Value = candidate.Value })
	end
	return { BoardId = boardId, DisplayName = definition.DisplayName, Rows = rows }
end

function CurrentServerLeaderboard.invalidate()
	cache = {}
end

function CurrentServerLeaderboard.get(boardId, records, nowUnix, forceRefresh)
	local now = if typeof(nowUnix) == "number" then nowUnix else os.clock()
	local previous = cache[boardId]
	if forceRefresh ~= true and previous ~= nil and now - previous.At < LeaderboardConfig.RefreshSeconds then
		return previous.Snapshot
	end
	local snapshot = CurrentServerLeaderboard.build(boardId, records)
	cache[boardId] = { At = now, Snapshot = snapshot }
	return snapshot
end

return CurrentServerLeaderboard
