local LeaderboardConfig = {}

LeaderboardConfig.BoardOrder = { "ritual_power", "rebirths", "rolls", "ascensions" }
LeaderboardConfig.MaximumRows = 10
LeaderboardConfig.RefreshSeconds = 5
LeaderboardConfig.Boards = {
	ritual_power = { BoardId = "ritual_power", DisplayName = "Ritual Power", SourceField = "BestRitualPower" },
	rebirths = { BoardId = "rebirths", DisplayName = "Rebirths", SourceField = "Rebirths" },
	rolls = { BoardId = "rolls", DisplayName = "Rolls", SourceField = "Rolls" },
	ascensions = { BoardId = "ascensions", DisplayName = "Ascensions", SourceField = "Ascensions" },
}

function LeaderboardConfig.getBoard(boardId)
	if typeof(boardId) ~= "string" then
		return nil
	end
	return LeaderboardConfig.Boards[boardId]
end

return LeaderboardConfig
