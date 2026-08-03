-- Studio-only reference gallery. This is not a production effect and is never
-- intended to be published. It displays external textures as raw atlas sheets
-- so they can be inspected before we author a Roblox composition around them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end

local GALLERY_NAME = "__VFXReferenceGallery"
local CONTENT_ROOT = "rbxasset://vfx-local/reference_gallery/cc0-oga-v1/"
local GENERATED_STUDY_TEXTURE = "rbxasset://vfx-local/reference_gallery/cc0-oga-v1/aura_vfx_texture_study_sheet_v1.png"

local REFERENCES = table.freeze({
	{ Name = "Fire01 - CC0", Texture = CONTENT_ROOT .. "Fire01.png" },
	{ Name = "Explosion25 - CC0", Texture = CONTENT_ROOT .. "Explosion25.png" },
	{ Name = "Effect36 - CC0", Texture = CONTENT_ROOT .. "Effect36.png" },
	{ Name = "Effect51 - CC0", Texture = CONTENT_ROOT .. "Effect51.png" },
	{ Name = "ToonExplosion31 - CC0", Texture = CONTENT_ROOT .. "ToonExplosion31.png" },
	{ Name = "ImageGen study - reference only", Texture = GENERATED_STUDY_TEXTURE },
})

local function createAnchor(parent: Instance, name: string, position: Vector3): Part
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = parent
	return anchor
end

local function createBoard(parent: Instance, reference, position: Vector3, index: number)
	local anchor = createAnchor(parent, "TextureBoard_" .. tostring(index), position)
	local gui = Instance.new("BillboardGui")
	gui.Name = "RawTextureBoard"
	gui.Adornee = anchor
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 100
	gui.Size = UDim2.fromOffset(250, 290)
	gui.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Name = "ReferenceOnlyFrame"
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local image = Instance.new("ImageLabel")
	image.Name = "RawTexture"
	image.BackgroundColor3 = Color3.fromRGB(5, 6, 9)
	image.BackgroundTransparency = 0
	image.BorderSizePixel = 0
	image.Position = UDim2.fromOffset(8, 8)
	image.Size = UDim2.new(1, -16, 1, -48)
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = reference.Texture
	image.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "ReferenceLabel"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 8, 1, -37)
	label.Size = UDim2.new(1, -16, 0, 29)
	label.Font = Enum.Font.GothamSemibold
	label.Text = reference.Name
	label.TextColor3 = Color3.fromRGB(242, 242, 248)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = frame
end

local function buildGallery(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end

	local oldGallery = Workspace:FindFirstChild(GALLERY_NAME)
	if oldGallery ~= nil then
		oldGallery:Destroy()
	end

	local gallery = Instance.new("Folder")
	gallery.Name = GALLERY_NAME
	gallery:SetAttribute("ReferenceOnly", true)
	gallery:SetAttribute("ProductionEffect", false)
	gallery.Parent = Workspace

	-- Put the raw sheets in a readable arc in front of the character. The
	-- BillboardGui keeps them readable while orbiting the camera around the stage.
	local center = root.Position + root.CFrame.LookVector * 9 + Vector3.new(0, 4.5, 0)
	local positions = {
		Vector3.new(-7.5, 1.7, 0),
		Vector3.new(-4.5, 0.2, 0),
		Vector3.new(-1.5, -0.4, 0),
		Vector3.new(1.5, -0.4, 0),
		Vector3.new(4.5, 0.2, 0),
		Vector3.new(7.5, 1.7, 0),
	}
	for index, reference in REFERENCES do
		createBoard(gallery, reference, center + positions[index], index)
	end

	local titleAnchor = createAnchor(gallery, "GalleryTitle", center + Vector3.new(0, 4.0, 0))
	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "GalleryTitleGui"
	titleGui.Adornee = titleAnchor
	titleGui.AlwaysOnTop = false
	titleGui.LightInfluence = 0
	titleGui.MaxDistance = 120
	titleGui.Size = UDim2.fromOffset(650, 60)
	titleGui.Parent = titleAnchor

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.GothamBold
	title.Text = "VFX REFERENCE GALLERY  -  RAW TEXTURES  -  STUDY ONLY"
	title.TextColor3 = Color3.fromRGB(255, 224, 166)
	title.TextScaled = true
	title.Parent = titleGui

	print("Studio VFX reference gallery active: " .. tostring(#REFERENCES) .. " raw texture sheets")
end

local player = Players.LocalPlayer
player.CharacterAdded:Connect(function(character)
	-- Let the gameplay preview finish its deterministic review-stage placement first.
	task.delay(1, buildGallery, character)
end)
if player.Character ~= nil then
	task.delay(1, buildGallery, player.Character)
end
