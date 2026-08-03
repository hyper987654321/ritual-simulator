local Workspace = game:GetService("Workspace")

local LeaderboardService = {}

local BOARD_FOLDER_NAME = "GeneratedLeaderboards"

local hasStarted = false

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
