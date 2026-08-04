local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

local Systems = script.Parent.Parent
local ClientStateStore = require(Systems:WaitForChild("State"):WaitForChild("ClientStateStore"))
local HudApp = require(script.Parent:WaitForChild("App"):WaitForChild("HudApp"))

local HudController = {}

local UI_ROOT_NAME = "RitualCoreHud"

local player = Players.LocalPlayer
local uiRoot = nil

function HudController.start()
	if uiRoot ~= nil then
		return
	end

	ClientStateStore.start()

	local playerGui = player:WaitForChild("PlayerGui")
	local mountTarget = playerGui:FindFirstChild(UI_ROOT_NAME)

	if mountTarget == nil then
		mountTarget = Instance.new("ScreenGui")
		mountTarget.Name = UI_ROOT_NAME
		mountTarget.ResetOnSpawn = false
		mountTarget.IgnoreGuiInset = true
		mountTarget.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		mountTarget.ZIndexBehavior = Enum.ZIndexBehavior.Global
		mountTarget.Parent = playerGui
	end

	uiRoot = ReactRoblox.createRoot(mountTarget)
	uiRoot:render(React.createElement(HudApp))
end

function HudController.stop()
	if uiRoot == nil then
		return
	end

	uiRoot:unmount()
	uiRoot = nil
end

return HudController
