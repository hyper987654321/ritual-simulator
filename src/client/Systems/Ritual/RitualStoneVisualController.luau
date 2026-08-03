local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Systems = script.Parent.Parent
local ClientStateStore = require(Systems:WaitForChild("State"):WaitForChild("ClientStateStore"))
local RitualStoneVisualFactory = require(script.Parent:WaitForChild("RitualStoneVisualFactory"))

local RitualStoneVisualController = {}

local FOLDER_NAME = "LocalRitualStone"

local player = Players.LocalPlayer
local hasStarted = false
local folder = nil
local visual = nil

local function getCharacterRoot()
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function step(dt)
	local root = getCharacterRoot()

	if root == nil or visual == nil then
		return
	end

	RitualStoneVisualFactory.updateFollow(visual, root.CFrame, os.clock(), dt)
end

function RitualStoneVisualController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	ClientStateStore.start()

	local existing = Workspace:FindFirstChild(FOLDER_NAME)

	if existing ~= nil then
		existing:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	visual = RitualStoneVisualFactory.create(folder)

	ClientStateStore.subscribe(function(snapshot)
		RitualStoneVisualFactory.updateStats(visual, snapshot)
	end)

	RunService.Heartbeat:Connect(step)
end

return RitualStoneVisualController
