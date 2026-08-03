local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local PetConfig = require(Config:WaitForChild("PetConfig"))

local PetViewport = {}

local PET_MODEL_FOLDER_NAME = "PetModels"
local DEFAULT_CAMERA_FOV = 34
local DEFAULT_ASPECT_RATIO = 1.48
local DEFAULT_CAMERA_PADDING = 1.05
local DEFAULT_DEPTH_PADDING = 0.16
local DEFAULT_MODEL_YAW = math.rad(90)
local DEFAULT_MODEL_NAME = "PetViewportModel"

local warnedMissingViewportTemplateByContext = {}

local function getBasePetId(petId)
	local pet = PetConfig.getPet(petId)

	if pet ~= nil and typeof(pet.BasePetId) == "string" then
		return pet.BasePetId
	end

	local parts = PetConfig.getPetParts(petId)

	if parts ~= nil and typeof(parts.BasePetId) == "string" then
		return parts.BasePetId
	end

	return petId
end

local function getWarningContext(props)
	return props.WarningContext or props.ModelName or DEFAULT_MODEL_NAME
end

local function getPetModelTemplate(petId, warningContext)
	if typeof(petId) ~= "string" then
		return nil
	end

	local basePetId = getBasePetId(petId)
	local folder = ReplicatedStorage:FindFirstChild(PET_MODEL_FOLDER_NAME)
	local template = if folder ~= nil then folder:FindFirstChild(basePetId) else nil

	if template ~= nil and template:IsA("Model") then
		return template
	end

	local warningKey = tostring(warningContext) .. ":" .. tostring(basePetId)

	if warnedMissingViewportTemplateByContext[warningKey] ~= true then
		warnedMissingViewportTemplateByContext[warningKey] = true
		warn("Missing pet model template for viewport:", warningContext, basePetId)
	end

	return nil
end

local function configureViewportModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

local function centerViewportModel(model)
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local offset = Vector3.new(-boundsCFrame.Position.X, -boundsCFrame.Position.Y, -boundsCFrame.Position.Z)

	model:PivotTo(model:GetPivot() + offset)

	return boundsSize
end

local function orientViewportModel(model, modelYaw)
	centerViewportModel(model)
	model:PivotTo(CFrame.Angles(0, modelYaw, 0) * model:GetPivot())
	centerViewportModel(model)
end

local function frameViewportCamera(camera, model, fieldOfView, aspectRatio, cameraPadding, depthPadding)
	local _, boundsSize = model:GetBoundingBox()
	local verticalFov = math.rad(fieldOfView)
	local horizontalFov = 2 * math.atan(math.tan(verticalFov * 0.5) * aspectRatio)
	local verticalDistance = (boundsSize.Y * 0.5) / math.max(math.tan(verticalFov * 0.5), 0.001)
	local horizontalDistance = (math.max(boundsSize.X, boundsSize.Z) * 0.5) / math.max(math.tan(horizontalFov * 0.5), 0.001)
	local depthOffset = boundsSize.Z * depthPadding
	local distance = (math.max(verticalDistance, horizontalDistance) + depthOffset) * cameraPadding
	local cameraPosition = Vector3.new(distance * 0.04, distance * 0.02, distance)

	camera.FieldOfView = fieldOfView
	camera.CFrame = CFrame.new(cameraPosition, Vector3.new(0, 0, 0))
end

local function PetViewportComponent(props)
	local resolvedProps = props or {}
	local petId = resolvedProps.PetId
	local zIndex = resolvedProps.ZIndex or 1
	local modelName = resolvedProps.ModelName or DEFAULT_MODEL_NAME
	local warningContext = getWarningContext(resolvedProps)
	local aspectRatio = resolvedProps.AspectRatio or DEFAULT_ASPECT_RATIO
	local cameraPadding = resolvedProps.CameraPadding or DEFAULT_CAMERA_PADDING
	local depthPadding = resolvedProps.DepthPadding or DEFAULT_DEPTH_PADDING
	local fieldOfView = resolvedProps.FieldOfView or DEFAULT_CAMERA_FOV
	local modelYaw = resolvedProps.ModelYaw or DEFAULT_MODEL_YAW
	local viewportRef = React.useRef(nil)
	local worldRef = React.useRef(nil)
	local cameraRef = React.useRef(nil)

	React.useEffect(function()
		local viewport = viewportRef.current
		local world = worldRef.current
		local camera = cameraRef.current

		if viewport ~= nil and camera ~= nil then
			viewport.CurrentCamera = camera
		end

		if world == nil then
			return nil
		end

		local template = getPetModelTemplate(petId, warningContext)

		if template == nil then
			return nil
		end

		local model = template:Clone()

		if model == nil then
			return nil
		end

		model.Name = modelName
		model.Parent = world
		configureViewportModel(model)
		orientViewportModel(model, modelYaw)

		if camera ~= nil then
			frameViewportCamera(camera, model, fieldOfView, aspectRatio, cameraPadding, depthPadding)
		end

		return function()
			if model.Parent ~= nil then
				model:Destroy()
			end
		end
	end, { petId, modelName, warningContext, aspectRatio, cameraPadding, depthPadding, fieldOfView, modelYaw })

	return React.createElement("ViewportFrame", {
		ref = viewportRef,
		Ambient = resolvedProps.Ambient or Color3.fromRGB(205, 205, 220),
		BackgroundTransparency = if resolvedProps.BackgroundTransparency ~= nil then resolvedProps.BackgroundTransparency else 1,
		BorderSizePixel = resolvedProps.BorderSizePixel or 0,
		LightColor = resolvedProps.LightColor or Color3.fromRGB(255, 255, 255),
		LightDirection = resolvedProps.LightDirection or Vector3.new(-0.28, -0.7, -0.45),
		Position = resolvedProps.Position,
		Size = resolvedProps.Size,
		ZIndex = zIndex,
	}, {
		Camera = React.createElement("Camera", {
			ref = cameraRef,
			CFrame = CFrame.new(Vector3.new(0.5, 0.25, 4.6), Vector3.new(0, 0, 0)),
			FieldOfView = fieldOfView,
		}),
		World = React.createElement("WorldModel", {
			ref = worldRef,
		}),
	})
end

function PetViewport.create(props)
	return React.createElement(PetViewportComponent, props or {})
end

return PetViewport
