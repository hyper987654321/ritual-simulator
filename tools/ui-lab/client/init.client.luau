local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ReactRoblox"))
local App = require(script.Parent:WaitForChild("App"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UILabMount"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Parent = playerGui

local root = ReactRoblox.createRoot(screenGui)
root:render(React.createElement(App))
