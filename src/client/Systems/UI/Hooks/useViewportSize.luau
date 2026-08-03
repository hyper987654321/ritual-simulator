local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local DEFAULT_VIEWPORT_SIZE = Vector2.new(1280, 720)

local function getCurrentViewportSize(defaultViewportSize)
	local currentCamera = Workspace.CurrentCamera

	return if currentCamera ~= nil then currentCamera.ViewportSize else defaultViewportSize
end

local function useViewportSize(defaultViewportSize)
	local fallbackViewportSize = defaultViewportSize or DEFAULT_VIEWPORT_SIZE
	local viewportSize, setViewportSize = React.useState(getCurrentViewportSize(fallbackViewportSize))

	React.useEffect(function()
		local viewportConnection = nil

		local function updateViewportSize()
			setViewportSize(getCurrentViewportSize(fallbackViewportSize))
		end

		local function connectViewportListener()
			if viewportConnection ~= nil then
				viewportConnection:Disconnect()
				viewportConnection = nil
			end

			local currentCamera = Workspace.CurrentCamera

			if currentCamera ~= nil then
				viewportConnection = currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewportSize)
			end
		end

		updateViewportSize()
		connectViewportListener()

		local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			updateViewportSize()
			connectViewportListener()
		end)

		return function()
			if viewportConnection ~= nil then
				viewportConnection:Disconnect()
			end

			cameraConnection:Disconnect()
		end
	end, {})

	return viewportSize
end

return useViewportSize
