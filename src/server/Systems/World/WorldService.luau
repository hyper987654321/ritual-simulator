local Workspace = game:GetService("Workspace")

local WorldService = {}

local WORLD_FOLDER_NAME = "GeneratedRitualWorld"
local hasStarted = false

function WorldService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	local existing = Workspace:FindFirstChild(WORLD_FOLDER_NAME)

	if existing ~= nil then
		existing:Destroy()
	end
end

return WorldService
