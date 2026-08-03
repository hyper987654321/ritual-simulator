local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MapGen = Shared:WaitForChild("MapGen")
local Util = Shared:WaitForChild("Util")

local AscensionConfig = require(Config:WaitForChild("AscensionConfig"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))
local GeneratedMapRuntime = require(MapGen:WaitForChild("GeneratedMapRuntime"))
local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))

local Systems = script.Parent.Parent
local ClientUiSignals = require(Systems:WaitForChild("State"):WaitForChild("ClientUiSignals"))
local ClientStateStore = require(Systems:WaitForChild("State"):WaitForChild("ClientStateStore"))
local PetModelVisualFactory = require(script.Parent:WaitForChild("PetModelVisualFactory"))
local PetFollowerLayout = require(script.Parent:WaitForChild("PetFollowerLayout"))

local WorldController = {}

local LOCAL_FOLDER_NAME = "LocalRitualPreview"
local RITUAL_STONE_FOLDER_NAME = "LocalRitualStone"
local ESSENCE_FLY_IN_DURATION = 0.55
local ESSENCE_FLY_IN_MAX_ORBS = 6
local PET_ATTACK_WINDUP_SECONDS = 0.14
local PET_ATTACK_LUNGE_SECONDS = 0.18
local PET_ATTACK_HIT_HOLD_SECONDS = 0.08
local PET_ATTACK_RECOVER_SECONDS = 0.24
local PET_HIT_BURST_SECONDS = 0.26
local PET_FOLLOW_MAX_SPEED = 30
local PET_ENGAGE_MAX_SPEED = 26
local PET_FOLLOW_ARRIVAL_GAIN = 8
local PET_ENGAGE_ARRIVAL_GAIN = 7.5
local PET_VELOCITY_RESPONSE = 10
local PET_FOLLOW_LOOK_TURN_RADIANS_PER_SECOND = math.rad(115)
local PET_ACTION_LOOK_RESPONSE = 12
local PET_FOLLOW_SNAP_DISTANCE = 70
local PET_ATTACK_WINDUP_DISTANCE = 0.75
local PET_ATTACK_APPROACH_PADDING = 1.15
local PET_ATTACK_CONTACT_PADDING = 0.12
local PET_ATTACK_CRYSTAL_RADIUS = 2
local PET_ATTACK_SLOT_ANGLE_RADIANS = math.rad(22)
local PET_ATTACK_MAX_SLOT_ANGLE_RADIANS = math.rad(48)
local PET_STATE_FOLLOW = "Follow"
local PET_STATE_ENGAGE = "Engage"
local PET_STATE_ATTACK_WINDUP = "AttackWindup"
local PET_STATE_ATTACK_LUNGE = "AttackLunge"
local PET_STATE_ATTACK_HOLD = "AttackHold"
local PET_STATE_ATTACK_RECOVER = "AttackRecover"
local USE_LOCAL_PET_VISUALS = true
local player = Players.LocalPlayer

local hasStarted = false
local localFolder = nil
local crystals = {}
local crystalsById = {}
local petVisuals = {}
local petTargets = {}
local petAttackVisuals = {}
local breakingCrystalVisuals = {}
local unlockWallsByZoneId = {}
local ascensionStatue = nil
local lastAttackSequence = 0
local currentSnapshot = nil
local followRootLookDirection = nil

local function createBillboard(part)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CrystalBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(140, 40)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = UIThemeConfig.Font
	label.Size = UDim2.fromScale(1, 1)
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(237, 235, 255)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.45
	label.Parent = billboard

	return label
end

local function createUnlockWallButton(wallPart, zoneId, face, maxDistance)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "UnlockWallSurface"
	surfaceGui.Adornee = wallPart
	surfaceGui.AlwaysOnTop = false
	surfaceGui.CanvasSize = Vector2.new(1024, 512)
	surfaceGui.Face = face
	surfaceGui.LightInfluence = 0.2
	surfaceGui.MaxDistance = maxDistance
	surfaceGui.PixelsPerStud = 48
	surfaceGui.ResetOnSpawn = false
	surfaceGui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "UnlockContent"
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromScale(0.08, 0.12)
	root.Size = UDim2.fromScale(0.84, 0.76)
	root.Parent = surfaceGui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.fromScale(0, 0)
	title.Size = UDim2.fromScale(1, 0.46)
	title.Text = ""
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.TextWrapped = true
	title.Parent = root

	local button = Instance.new("TextButton")
	button.Name = "UnlockButton"
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(255, 74, 104)
	button.BackgroundTransparency = 0
	button.Font = Enum.Font.GothamBlack
	button.Position = UDim2.fromScale(0.14, 0.54)
	button.Size = UDim2.fromScale(0.72, 0.34)
	button.Text = ""
	button.TextColor3 = Color3.fromRGB(255, 245, 220)
	button.TextScaled = true
	button.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	button.TextStrokeTransparency = 0
	button.TextWrapped = true
	button:SetAttribute("CanUnlock", false)
	button.Parent = root

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 18)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = Color3.fromRGB(255, 255, 255)
	buttonStroke.Thickness = 5
	buttonStroke.Transparency = 0.16
	buttonStroke.Parent = button

	button.Activated:Connect(function()
		if button:GetAttribute("CanUnlock") ~= true then
			return
		end

		ClientStateStore.unlockZone(zoneId)
	end)

	return {
		Button = button,
		Gui = surfaceGui,
		Title = title,
	}
end

local function createUnlockWallSurfaces(wallPart, zoneId, maxDistance)
	local surfaces = {}
	local faces = if wallPart.Size.X >= wallPart.Size.Z
		then { Enum.NormalId.Front, Enum.NormalId.Back }
		else { Enum.NormalId.Left, Enum.NormalId.Right }

	for _, face in ipairs(faces) do
		table.insert(surfaces, createUnlockWallButton(wallPart, zoneId, face, maxDistance))
	end

	return surfaces
end

local function createAscensionStatueLabel(part)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AscensionStatueBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(260, 76)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = UIThemeConfig.Font
	label.Size = UDim2.fromScale(1, 1)
	label.Text = ""
	label.TextColor3 = AscensionConfig.Statue.Color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.18
	label.Parent = billboard

	return label
end

local function destroyAscensionStatue()
	if ascensionStatue == nil then
		return
	end

	if ascensionStatue.Part.Parent ~= nil then
		ascensionStatue.Part:Destroy()
	end

	ascensionStatue = nil
end

local function createAscensionStatue(requiredZone)
	local basePosition = AscensionConfig.getStatuePosition(requiredZone)
	local position = GeneratedMapRuntime.getRuntimePosition(requiredZone, basePosition)

	if position == nil then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = "LocalAscensionStatue"
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.Color = AscensionConfig.Statue.Color
	part.Material = Enum.Material.Neon
	part.Position = position
	part.Size = AscensionConfig.Statue.Size
	part.Parent = localFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AscensionPrompt"
	prompt.ActionText = "Ascend"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = AscensionConfig.Statue.PromptDistance
	prompt.ObjectText = "Ascension Statue"
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function()
		ClientUiSignals.requestAscension()
	end)

	ascensionStatue = {
		Part = part,
		Label = createAscensionStatueLabel(part),
		Prompt = prompt,
		RequiredZone = requiredZone,
	}

	return ascensionStatue
end

local function updateAscensionStatue(statue, ascension)
	local requiredZone = ascension.RequiredZone or statue.RequiredZone
	local isReady = ascension.CanAscend == true

	statue.Prompt.Enabled = isReady
	statue.Label.Text = if isReady
		then "Ascension\nReady"
		else "Ascension\nReach Zone " .. tostring(requiredZone)
end

local function syncAscensionStatue(snapshot)
	local ascension = if snapshot ~= nil and typeof(snapshot.Ascension) == "table" then snapshot.Ascension else nil

	if ascension == nil or ascension.RequiredZoneExists ~= true or typeof(ascension.RequiredZone) ~= "number" then
		destroyAscensionStatue()
		return
	end

	if ascensionStatue == nil or ascensionStatue.RequiredZone ~= ascension.RequiredZone then
		destroyAscensionStatue()
		createAscensionStatue(ascension.RequiredZone)
	end

	if ascensionStatue ~= nil then
		updateAscensionStatue(ascensionStatue, ascension)
	end
end

local function destroyUnlockWall(zoneId)
	local wall = unlockWallsByZoneId[zoneId]

	if wall == nil then
		return
	end

	if wall.Surfaces ~= nil then
		for _, surface in ipairs(wall.Surfaces) do
			if surface.Gui ~= nil and surface.Gui.Parent ~= nil then
				surface.Gui:Destroy()
			end
		end
	end

	if wall.Model ~= nil and wall.Model.Parent ~= nil then
		wall.Model:Destroy()
	elseif wall.Part.Parent ~= nil then
		wall.Part:Destroy()
	end

	unlockWallsByZoneId[zoneId] = nil
end

local function createUnlockWall(zoneInfo)
	local wallConfig = GeneratedMapRuntime.getUnlockWall(zoneInfo.ZoneId)

	if wallConfig == nil then
		return nil
	end

	local interactionDistance = wallConfig.PromptDistance or ZoneConfig.UnlockPromptDistance
	local model = Instance.new("Model")
	model.Name = "LocalZoneUnlockWall_" .. tostring(zoneInfo.ZoneId)
	model.Parent = localFolder

	local part = Instance.new("Part")
	part.Name = "GlassGate"
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = false
	part.Color = Color3.fromRGB(103, 238, 255)
	part.Material = Enum.Material.Glass
	part.Position = wallConfig.Center
	part.Size = wallConfig.Size
	part.Transparency = 0.36
	part.Parent = model

	local wall = {
		Model = model,
		Part = part,
		Surfaces = createUnlockWallSurfaces(part, zoneInfo.ZoneId, math.max(120, interactionDistance)),
		ZoneId = zoneInfo.ZoneId,
	}

	unlockWallsByZoneId[zoneInfo.ZoneId] = wall

	return wall
end

local function updateUnlockWall(wall, zoneInfo)
	local costText = NumberFormatter.compact(zoneInfo.UnlockCost or 0)
	local canUnlock = zoneInfo.CanUnlock == true
	local buttonColor = if canUnlock then Color3.fromRGB(63, 219, 91) else Color3.fromRGB(255, 74, 104)
	local buttonText = if canUnlock then costText .. " Essence\nUnlock" else costText .. " Essence"

	wall.Part.Color = Color3.fromRGB(103, 238, 255)

	for _, surface in ipairs(wall.Surfaces) do
		local button = surface.Button

		surface.Title.Text = zoneInfo.DisplayName
		button.Text = buttonText
		button:SetAttribute("CanUnlock", canUnlock)
		button.AutoButtonColor = canUnlock
		button.Active = canUnlock
		button.BackgroundColor3 = buttonColor
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function syncUnlockWalls(snapshot)
	if snapshot == nil then
		return
	end

	local seenZoneIds = {}

	for _, zoneInfo in ipairs(snapshot.Zones or {}) do
		local zoneId = zoneInfo.ZoneId

		if typeof(zoneId) == "number" and zoneId ~= 1 and zoneInfo.IsUnlocked ~= true then
			seenZoneIds[zoneId] = true

			local wall = unlockWallsByZoneId[zoneId] or createUnlockWall(zoneInfo)

			if wall ~= nil then
				updateUnlockWall(wall, zoneInfo)
			end
		end
	end

	for zoneId in pairs(unlockWallsByZoneId) do
		if seenZoneIds[zoneId] ~= true then
			destroyUnlockWall(zoneId)
		end
	end
end

local function createCrystal(crystalState)
	local zone = if currentSnapshot ~= nil then ZoneConfig.getZone(currentSnapshot.CurrentZone) else nil
	local crystalColor = if zone ~= nil then zone.CrystalColor else Color3.fromRGB(103, 228, 255)
	local part = Instance.new("Part")
	part.Name = "EnergyCrystal" .. tostring(crystalState.CrystalId)
	part.Anchored = true
	part.CanCollide = false
	part.Color = crystalColor
	part.Material = Enum.Material.Neon
	part.Position = crystalState.Position
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(4, 4, 4)
	part.Parent = localFolder

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Brightness = 1.2
	light.Color = part.Color
	light.Range = 12
	light.Parent = part

	return {
		Part = part,
		Label = createBillboard(part),
		CrystalId = crystalState.CrystalId,
		Health = crystalState.Health or crystalState.MaxHealth or 0,
		MaxHealth = crystalState.MaxHealth or 0,
	}
end

local function clearCrystals()
	for _, crystal in ipairs(crystals) do
		crystal.Part:Destroy()
	end

	crystals = {}
	crystalsById = {}
	petTargets = {}
	breakingCrystalVisuals = {}
end

local function removeCrystal(crystal)
	if crystal == nil then
		return
	end

	if crystal.Part.Parent ~= nil then
		crystal.Part:Destroy()
	end

	crystalsById[crystal.CrystalId] = nil

	for index = #crystals, 1, -1 do
		if crystals[index] == crystal then
			table.remove(crystals, index)
			break
		end
	end
end

local function getCharacterRoot()
	local character = player.Character

	if character == nil then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getEssenceTargetPosition()
	local stoneFolder = Workspace:FindFirstChild(RITUAL_STONE_FOLDER_NAME)

	if stoneFolder ~= nil then
		local stoneCore = stoneFolder:FindFirstChild("StoneCore")

		if stoneCore ~= nil and stoneCore:IsA("BasePart") then
			return stoneCore.Position
		end
	end

	local root = getCharacterRoot()

	if root ~= nil then
		return root.Position + Vector3.new(4.5, 3.2, 1.5)
	end

	return nil
end

local function createEssenceOrb(position, color)
	local orb = Instance.new("Part")
	orb.Name = "EssenceFlyIn"
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.Color = color
	orb.Material = Enum.Material.Neon
	orb.Position = position
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(0.48, 0.48, 0.48)
	orb.Parent = localFolder

	local light = Instance.new("PointLight")
	light.Name = "EssenceGlow"
	light.Brightness = 0.8
	light.Color = color
	light.Range = 6
	light.Parent = orb

	return orb
end

local function spawnEssenceFlyIn(fromPosition, amount, color)
	local targetPosition = getEssenceTargetPosition()

	if targetPosition == nil or amount <= 0 then
		return
	end

	local orbCount = math.clamp(math.ceil(amount / 12), 2, ESSENCE_FLY_IN_MAX_ORBS)

	for index = 1, orbCount do
		local angle = (index / orbCount) * math.pi * 2
		local startPosition = fromPosition + Vector3.new(math.cos(angle) * 1.6, 0.5 + index * 0.08, math.sin(angle) * 1.6)
		local targetOffset = Vector3.new(math.cos(angle) * 0.28, math.sin(index * 1.7) * 0.28, math.sin(angle) * 0.28)
		local orb = createEssenceOrb(startPosition, color)
		local tween = TweenService:Create(orb, TweenInfo.new(
			ESSENCE_FLY_IN_DURATION,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		), {
			Position = targetPosition + targetOffset,
			Size = Vector3.new(0.12, 0.12, 0.12),
			Transparency = 1,
		})

		tween:Play()

		task.delay(ESSENCE_FLY_IN_DURATION + 0.05, function()
			if orb.Parent ~= nil then
				orb:Destroy()
			end
		end)
	end
end

local function createPetHitBurst(position, petId)
	if localFolder == nil or typeof(position) ~= "Vector3" then
		return
	end

	local pet = if typeof(petId) == "string" then PetConfig.getPet(petId) else nil
	local revealTier = if pet ~= nil then pet.AuraRevealTier or 1 else 1

	if revealTier <= 1 then
		return
	end

	local color = if pet ~= nil then pet.AuraColor or pet.Color else Color3.fromRGB(125, 238, 255)
	local accentColor = if pet ~= nil then pet.AuraAccentColor or color else color
	local burstSize = 0.48 + revealTier * 0.14
	local burst = Instance.new("Part")

	burst.Name = "PetHitBurst"
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.Color = color
	burst.Material = Enum.Material.Neon
	burst.Position = position
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(0.16, 0.16, 0.16)
	burst.Parent = localFolder

	local light = Instance.new("PointLight")
	light.Name = "PetHitGlow"
	light.Brightness = 0.35 + revealTier * 0.18
	light.Color = color
	light.Range = 3 + revealTier
	light.Shadows = false
	light.Parent = burst

	TweenService:Create(burst, TweenInfo.new(PET_HIT_BURST_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(burstSize, burstSize, burstSize),
		Transparency = 1,
	}):Play()

	if revealTier >= 4 then
		local ring = Instance.new("Part")
		local ringSize = 1 + revealTier * 0.28

		ring.Name = "PetHitRing"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Color = accentColor
		ring.Material = Enum.Material.Neon
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.18, 0.025, 0.18)
		ring.Transparency = 0.2
		ring.CFrame = CFrame.new(position)
		ring.Parent = localFolder

		TweenService:Create(ring, TweenInfo.new(PET_HIT_BURST_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(ringSize, 0.025, ringSize),
			Transparency = 1,
		}):Play()

		task.delay(PET_HIT_BURST_SECONDS + 0.05, function()
			if ring.Parent ~= nil then
				ring:Destroy()
			end
		end)
	end

	task.delay(PET_HIT_BURST_SECONDS + 0.05, function()
		if burst.Parent ~= nil then
			burst:Destroy()
		end
	end)
end

local function canStoreCurrentCrystalReward(snapshot)
	if snapshot == nil or snapshot.StoneStats == nil or snapshot.Crystal == nil then
		return false
	end

	return snapshot.Crystal.CanStoreCurrentCrystalReward ~= false
end

local function syncCrystals(snapshot)
	if snapshot == nil or snapshot.Crystal == nil or snapshot.Crystal.ZoneId ~= snapshot.CurrentZone then
		clearCrystals()
		return
	end

	local seenCrystalIds = {}

	for _, crystalState in ipairs(snapshot.Crystal.Crystals or {}) do
		local crystalId = crystalState.CrystalId

		if typeof(crystalId) == "number" then
			seenCrystalIds[crystalId] = true

			local crystal = crystalsById[crystalId]

			if crystal == nil then
				crystal = createCrystal(crystalState)
				crystalsById[crystalId] = crystal
				table.insert(crystals, crystal)
			end

			crystal.Health = crystalState.Health or crystal.Health
			crystal.MaxHealth = crystalState.MaxHealth or crystal.MaxHealth
			crystal.Part.Position = crystalState.Position
		end
	end

	for index = #crystals, 1, -1 do
		local crystal = crystals[index]

		if seenCrystalIds[crystal.CrystalId] ~= true then
			if breakingCrystalVisuals[crystal.CrystalId] ~= nil then
				crystal.Health = 0
			else
				removeCrystal(crystal)
			end
		end
	end
end

local function findPetVisual(petUid)
	if not USE_LOCAL_PET_VISUALS then
		return nil
	end

	for _, petVisual in ipairs(petVisuals) do
		if petVisual.PetUid == petUid then
			return petVisual
		end
	end

	return nil
end

local function getAttackTargetPosition(attack)
	local crystal = crystalsById[attack.CrystalId]

	if crystal ~= nil then
		return crystal.Part.Position
	end

	if typeof(attack.Position) == "Vector3" then
		return attack.Position
	end

	return nil
end

local function playPetHitVisual(attack, zone)
	if typeof(attack) ~= "table" or typeof(attack.PetUid) ~= "number" then
		return
	end

	local targetPosition = getAttackTargetPosition(attack)

	if targetPosition == nil then
		return
	end

	local now = os.clock()
	local impactAt = now + PET_ATTACK_WINDUP_SECONDS + PET_ATTACK_LUNGE_SECONDS
	local petVisual = findPetVisual(attack.PetUid)

	petAttackVisuals[attack.PetUid] = {
		StartPosition = if petVisual ~= nil then PetModelVisualFactory.getPosition(petVisual) else nil,
		TargetPosition = targetPosition,
		CrystalId = attack.CrystalId,
		StartedAt = now,
		WindupEndsAt = now + PET_ATTACK_WINDUP_SECONDS,
		ImpactAt = impactAt,
		HoldEndsAt = impactAt + PET_ATTACK_HIT_HOLD_SECONDS,
		DoneAt = impactAt + PET_ATTACK_HIT_HOLD_SECONDS + PET_ATTACK_RECOVER_SECONDS,
	}

	task.delay(math.max(0, impactAt - now), function()
		createPetHitBurst(targetPosition, if petVisual ~= nil then petVisual.PetId else nil)
	end)

	if attack.DidBreak == true and typeof(attack.CrystalId) == "number" then
		local crystal = crystalsById[attack.CrystalId]

		if crystal ~= nil then
			crystal.Health = 0
		end

		breakingCrystalVisuals[attack.CrystalId] = {
			RemoveAt = impactAt,
			EssenceAwarded = attack.EssenceAwarded or 0,
			Position = targetPosition,
			Color = if zone ~= nil then zone.CrystalColor else Color3.fromRGB(103, 228, 255),
		}
	end
end

local function syncPetTargets(snapshot)
	petTargets = {}

	if not USE_LOCAL_PET_VISUALS then
		return
	end

	if snapshot == nil or snapshot.Crystal == nil then
		return
	end

	if
		snapshot.Crystal.IsFarmingActive ~= true
		or #snapshot.EquippedPets == 0
		or not canStoreCurrentCrystalReward(snapshot)
	then
		return
	end

	for _, petTarget in ipairs(snapshot.Crystal.PetTargets or {}) do
		if typeof(petTarget.PetUid) == "number" and typeof(petTarget.Position) == "Vector3" then
			petTargets[petTarget.PetUid] = {
				CrystalId = petTarget.CrystalId,
				Position = petTarget.Position,
			}
		end
	end
end

local function cleanupBrokenCrystalVisuals()
	local now = os.clock()

	for crystalId, breakingVisual in pairs(breakingCrystalVisuals) do
		if (breakingVisual.RemoveAt or 0) <= now then
			local crystal = crystalsById[crystalId]
			local position = breakingVisual.Position

			if crystal ~= nil then
				position = crystal.Part.Position
				removeCrystal(crystal)
			end

			if typeof(position) == "Vector3" and (breakingVisual.EssenceAwarded or 0) > 0 then
				spawnEssenceFlyIn(position, breakingVisual.EssenceAwarded, breakingVisual.Color)
			end

			breakingCrystalVisuals[crystalId] = nil
		end
	end
end

local function easeInQuad(alpha)
	return alpha * alpha
end

local function easeOutQuad(alpha)
	local inverse = 1 - alpha

	return 1 - inverse * inverse
end

local function getResponseAlpha(response, dt)
	return 1 - math.exp(-math.max(response, 0) * math.max(dt, 0))
end

local function getHorizontalUnit(vector, fallback)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)

	if horizontal.Magnitude > 0.001 then
		return horizontal.Unit
	end

	local fallbackHorizontal = if fallback ~= nil then Vector3.new(fallback.X, 0, fallback.Z) else Vector3.zero

	if fallbackHorizontal.Magnitude > 0.001 then
		return fallbackHorizontal.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function getUnit(vector, fallback)
	if vector.Magnitude > 0.001 then
		return vector.Unit
	end

	if fallback ~= nil and fallback.Magnitude > 0.001 then
		return fallback.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function rotateHorizontalUnit(vector, angle)
	local horizontal = getHorizontalUnit(vector, Vector3.new(0, 0, -1))
	local cosine = math.cos(angle)
	local sine = math.sin(angle)

	return getHorizontalUnit(Vector3.new(
		horizontal.X * cosine - horizontal.Z * sine,
		0,
		horizontal.X * sine + horizontal.Z * cosine
	), horizontal)
end

local function getSlotOffset(index, total)
	return index - ((math.max(total, 1) + 1) * 0.5)
end

local function getAttackLaneAwayFromCrystal(index, total, rootCFrame, targetCenter, referencePosition)
	local fallbackAwayFromCrystal = if rootCFrame ~= nil then rootCFrame.LookVector * -1 else Vector3.new(0, 0, -1)
	local safeReferencePosition = if typeof(referencePosition) == "Vector3"
		then referencePosition
		else targetCenter + fallbackAwayFromCrystal
	local baseAwayFromCrystal = getHorizontalUnit(safeReferencePosition - targetCenter, fallbackAwayFromCrystal)
	local slotAngle = math.clamp(
		getSlotOffset(index, total) * PET_ATTACK_SLOT_ANGLE_RADIANS,
		-PET_ATTACK_MAX_SLOT_ANGLE_RADIANS,
		PET_ATTACK_MAX_SLOT_ANGLE_RADIANS
	)

	return rotateHorizontalUnit(baseAwayFromCrystal, slotAngle)
end

local function getYawFromHorizontalDirection(direction)
	return math.atan2(direction.X, direction.Z)
end

local function getHorizontalDirectionFromYaw(yaw)
	return Vector3.new(math.sin(yaw), 0, math.cos(yaw))
end

local function getShortestAngleDelta(fromYaw, toYaw)
	return math.atan2(math.sin(toYaw - fromYaw), math.cos(toYaw - fromYaw))
end

local function stepHorizontalLookDirection(previousDirection, desiredDirection, maxTurnRadians)
	local previous = getHorizontalUnit(previousDirection, desiredDirection)
	local desired = getHorizontalUnit(desiredDirection, previous)
	local previousYaw = getYawFromHorizontalDirection(previous)
	local desiredYaw = getYawFromHorizontalDirection(desired)
	local delta = getShortestAngleDelta(previousYaw, desiredYaw)
	local yaw = previousYaw + math.clamp(delta, -maxTurnRadians, maxTurnRadians)

	return getHorizontalDirectionFromYaw(yaw)
end

local function getSmoothedLookDirection(petVisual, desiredLookDirection, dt, state)
	local desired = getUnit(desiredLookDirection, petVisual.LookDirection)
	local previous = petVisual.LookDirection

	if state == PET_STATE_FOLLOW then
		if previous == nil or previous.Magnitude <= 0.001 then
			petVisual.LookDirection = getHorizontalUnit(desired, Vector3.new(0, 0, -1))
		else
			petVisual.LookDirection = stepHorizontalLookDirection(
				previous,
				desired,
				PET_FOLLOW_LOOK_TURN_RADIANS_PER_SECOND * math.max(dt, 0)
			)
		end

		return petVisual.LookDirection
	end

	local alpha = getResponseAlpha(PET_ACTION_LOOK_RESPONSE, dt)

	if previous == nil or previous.Magnitude <= 0.001 then
		petVisual.LookDirection = desired
	else
		petVisual.LookDirection = getUnit(previous:Lerp(desired, alpha), desired)
	end

	return petVisual.LookDirection
end

local function getPetPoseCFrame(petVisual, position, desiredLookDirection, _now, dt, state, phaseAlpha)
	local lookDirection = getSmoothedLookDirection(petVisual, desiredLookDirection, dt, state)
	local safePhaseAlpha = math.clamp(phaseAlpha or 0, 0, 1)
	local pitch = 0
	local roll = 0

	if state == PET_STATE_ATTACK_WINDUP then
		pitch = math.rad(5) * easeOutQuad(safePhaseAlpha)
	elseif state == PET_STATE_ATTACK_LUNGE then
		pitch = math.rad(-12) * easeInQuad(safePhaseAlpha)
	elseif state == PET_STATE_ATTACK_HOLD then
		pitch = math.rad(-9)
	elseif state == PET_STATE_ATTACK_RECOVER then
		pitch = math.rad(-9) * (1 - easeOutQuad(safePhaseAlpha))
	end

	return PetModelVisualFactory.getFacingCFrame(position, lookDirection, pitch, roll)
end

local function stepArrivePosition(petVisual, currentPosition, targetPosition, dt, maxSpeed, arrivalGain)
	local offset = targetPosition - currentPosition
	local distance = offset.Magnitude

	if distance <= 0.025 then
		petVisual.Velocity = Vector3.zero
		return targetPosition
	end

	local desiredSpeed = math.min(maxSpeed, distance * arrivalGain)
	local desiredVelocity = offset.Unit * desiredSpeed

	local alpha = getResponseAlpha(PET_VELOCITY_RESPONSE, dt)
	local velocity = petVisual.Velocity or Vector3.zero

	velocity = velocity:Lerp(desiredVelocity, alpha)

	local step = velocity * dt

	if step.Magnitude > distance then
		velocity = Vector3.zero
		currentPosition = targetPosition
	else
		currentPosition += step
	end

	petVisual.Velocity = velocity

	return currentPosition
end

local function getPetTargetCenter(activeTarget)
	if activeTarget == nil then
		return nil
	end

	local targetCrystal = if typeof(activeTarget.CrystalId) == "number" then crystalsById[activeTarget.CrystalId] else nil

	if targetCrystal ~= nil then
		return targetCrystal.Part.Position
	end

	if typeof(activeTarget.Position) == "Vector3" then
		return activeTarget.Position
	end

	return nil
end

local function getTargetKey(crystalId, targetCenter)
	if typeof(crystalId) == "number" then
		return "Crystal:" .. tostring(crystalId)
	end

	if typeof(targetCenter) == "Vector3" then
		return string.format(
			"Position:%d:%d:%d",
			math.floor(targetCenter.X * 10 + 0.5),
			math.floor(targetCenter.Y * 10 + 0.5),
			math.floor(targetCenter.Z * 10 + 0.5)
		)
	end

	return nil
end

local function getActiveTargetCrystalId(activeTarget)
	if activeTarget ~= nil and typeof(activeTarget.CrystalId) == "number" then
		return activeTarget.CrystalId
	end

	return nil
end

local function getPetVisualTarget(petVisual)
	local attackVisual = petAttackVisuals[petVisual.PetUid]

	if attackVisual ~= nil then
		return attackVisual.TargetPosition, attackVisual.CrystalId
	end

	local activeTarget = petTargets[petVisual.PetUid]

	return getPetTargetCenter(activeTarget), getActiveTargetCrystalId(activeTarget)
end

local function getTargetSlotAssignments(referencePosition)
	local groupsByKey = {}
	local targetSlotsByPetUid = {}

	for equippedIndex, petVisual in ipairs(petVisuals) do
		local targetCenter, crystalId = getPetVisualTarget(petVisual)
		local targetKey = getTargetKey(crystalId, targetCenter)

		if targetKey ~= nil and targetCenter ~= nil then
			local group = groupsByKey[targetKey]

			if group == nil then
				group = {
					Entries = {},
				}
				groupsByKey[targetKey] = group
			end

			table.insert(group.Entries, {
				PetUid = petVisual.PetUid,
				EquippedIndex = equippedIndex,
			})
		end
	end

	for _, group in pairs(groupsByKey) do
		local slotCount = #group.Entries

		table.sort(group.Entries, function(left, right)
			return left.EquippedIndex < right.EquippedIndex
		end)

		for slotIndex, entry in ipairs(group.Entries) do
			targetSlotsByPetUid[entry.PetUid] = {
				SlotIndex = slotIndex,
				SlotCount = slotCount,
				ReferencePosition = referencePosition,
			}
		end
	end

	return targetSlotsByPetUid
end

local function getEngagePosition(petVisual, index, total, rootCFrame, targetCenter, referencePosition, now)
	local frontReach = PetModelVisualFactory.getFrontReach(petVisual)
	local awayFromCrystal = getAttackLaneAwayFromCrystal(index, total, rootCFrame, targetCenter, referencePosition)
	local distance = PET_ATTACK_CRYSTAL_RADIUS + frontReach + PET_ATTACK_APPROACH_PADDING
	local hover = math.sin(now * 2.7 + index * 1.11) * 0.18

	return targetCenter
		+ awayFromCrystal * distance
		+ Vector3.new(0, 0.35 + hover, 0)
end

local function prepareAttackVisual(petVisual, attackVisual, index, total, rootCFrame, currentPosition, now, laneReferencePosition)
	if attackVisual.IsPrepared == true then
		return
	end

	local targetCenter = attackVisual.TargetPosition
	local startPosition = attackVisual.StartPosition or currentPosition
	local referencePosition = laneReferencePosition or startPosition
	local awayFromCrystal = getAttackLaneAwayFromCrystal(index, total, rootCFrame, targetCenter, referencePosition)
	local frontReach = PetModelVisualFactory.getFrontReach(petVisual)
	local impactDistance = PET_ATTACK_CRYSTAL_RADIUS + frontReach + PET_ATTACK_CONTACT_PADDING

	attackVisual.StartPosition = startPosition
	attackVisual.WindupPosition = targetCenter
		+ awayFromCrystal * (impactDistance + PET_ATTACK_WINDUP_DISTANCE)
		+ Vector3.new(0, 0.18, 0)
	attackVisual.ImpactPosition = targetCenter + awayFromCrystal * impactDistance
	attackVisual.RecoverPosition = getEngagePosition(
		petVisual,
		index,
		total,
		rootCFrame,
		targetCenter,
		referencePosition,
		now
	)
	attackVisual.IsPrepared = true
end

local function updateAttackPetVisual(petVisual, attackVisual, index, total, rootCFrame, currentPosition, now, dt, laneReferencePosition)
	prepareAttackVisual(petVisual, attackVisual, index, total, rootCFrame, currentPosition, now, laneReferencePosition)

	local targetCenter = attackVisual.TargetPosition
	local state = PET_STATE_ATTACK_RECOVER
	local phaseAlpha = 1
	local targetPosition = attackVisual.RecoverPosition

	if now < attackVisual.WindupEndsAt then
		state = PET_STATE_ATTACK_WINDUP
		phaseAlpha = math.clamp((now - attackVisual.StartedAt) / PET_ATTACK_WINDUP_SECONDS, 0, 1)
		targetPosition = attackVisual.StartPosition:Lerp(attackVisual.WindupPosition, easeOutQuad(phaseAlpha))
	elseif now < attackVisual.ImpactAt then
		state = PET_STATE_ATTACK_LUNGE
		phaseAlpha = math.clamp((now - attackVisual.WindupEndsAt) / PET_ATTACK_LUNGE_SECONDS, 0, 1)
		targetPosition = attackVisual.WindupPosition:Lerp(attackVisual.ImpactPosition, easeInQuad(phaseAlpha))
	elseif now < attackVisual.HoldEndsAt then
		state = PET_STATE_ATTACK_HOLD
		phaseAlpha = math.clamp((now - attackVisual.ImpactAt) / PET_ATTACK_HIT_HOLD_SECONDS, 0, 1)
		targetPosition = attackVisual.ImpactPosition
	else
		state = PET_STATE_ATTACK_RECOVER
		phaseAlpha = math.clamp((now - attackVisual.HoldEndsAt) / PET_ATTACK_RECOVER_SECONDS, 0, 1)
		targetPosition = attackVisual.ImpactPosition:Lerp(attackVisual.RecoverPosition, easeOutQuad(phaseAlpha))
	end

	petVisual.MotionState = state
	petVisual.Velocity = Vector3.zero

	PetModelVisualFactory.pivotTo(
		petVisual,
		getPetPoseCFrame(petVisual, targetPosition, targetCenter - targetPosition, now, dt, state, phaseAlpha)
	)
end

local function createPetVisual(petInstance, index, spawnPosition)
	local root = getCharacterRoot()
	local initialPosition = spawnPosition

	if initialPosition == nil then
		initialPosition = if root ~= nil then root.Position + Vector3.new(0, 2.4, 0) else Vector3.new(0, 0, 0)
	end

	local initialLookDirection = if root ~= nil then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	local petVisual = PetModelVisualFactory.create(
		localFolder,
		petInstance.Uid,
		petInstance.PetId,
		PetModelVisualFactory.getFacingCFrame(initialPosition, initialLookDirection)
	)

	if petVisual ~= nil then
		petVisual.MotionState = PET_STATE_FOLLOW
		petVisual.Velocity = Vector3.zero
		petVisual.LookDirection = initialLookDirection
	end

	return petVisual
end

local function refreshPetVisuals(snapshot)
	if not USE_LOCAL_PET_VISUALS then
		for index = #petVisuals, 1, -1 do
			petAttackVisuals[petVisuals[index].PetUid] = nil
			PetModelVisualFactory.destroy(petVisuals[index])
			table.remove(petVisuals, index)
		end

		petTargets = {}
		return
	end

	for index = #petVisuals, #snapshot.EquippedPets + 1, -1 do
		petAttackVisuals[petVisuals[index].PetUid] = nil
		PetModelVisualFactory.destroy(petVisuals[index])
		table.remove(petVisuals, index)
	end

	for index, petInstance in ipairs(snapshot.EquippedPets) do
		local petVisual = petVisuals[index]

		if petVisual == nil or petVisual.PetUid ~= petInstance.Uid or petVisual.PetId ~= petInstance.PetId then
			local spawnPosition = nil

			if petVisual ~= nil then
				spawnPosition = PetModelVisualFactory.getPosition(petVisual)
				petAttackVisuals[petVisual.PetUid] = nil
				PetModelVisualFactory.destroy(petVisual)
			end

			petVisuals[index] = createPetVisual(petInstance, index, spawnPosition)
		end
	end
end

local function updatePetVisuals(dt)
	if not USE_LOCAL_PET_VISUALS then
		return
	end

	local root = getCharacterRoot()

	if root == nil then
		followRootLookDirection = nil
		return
	end

	local now = os.clock()
	local followRootCFrame = nil

	followRootCFrame, followRootLookDirection = PetFollowerLayout.getFollowRootCFrame(root, followRootLookDirection, dt)

	for _, petVisual in ipairs(petVisuals) do
		local attackVisual = petAttackVisuals[petVisual.PetUid]

		if attackVisual ~= nil and now >= (attackVisual.DoneAt or 0) then
			petAttackVisuals[petVisual.PetUid] = nil
		end
	end

	local targetSlotsByPetUid = getTargetSlotAssignments(followRootCFrame.Position)

	for index, petVisual in ipairs(petVisuals) do
		local currentCFrame = PetModelVisualFactory.getCFrame(petVisual)
		local currentPosition = currentCFrame.Position
		local homeCFrame = PetFollowerLayout.getHomeCFrame(followRootCFrame, index, #petVisuals, now)
		local activeTarget = petTargets[petVisual.PetUid]
		local attackVisual = petAttackVisuals[petVisual.PetUid]
		local targetSlot = targetSlotsByPetUid[petVisual.PetUid]
		local targetSlotIndex = if targetSlot ~= nil then targetSlot.SlotIndex else index
		local targetSlotCount = if targetSlot ~= nil then targetSlot.SlotCount else #petVisuals
		local targetReferencePosition = if targetSlot ~= nil then targetSlot.ReferencePosition else followRootCFrame.Position

		if attackVisual ~= nil then
			updateAttackPetVisual(
				petVisual,
				attackVisual,
				targetSlotIndex,
				targetSlotCount,
				followRootCFrame,
				currentPosition,
				now,
				dt,
				targetReferencePosition
			)
		else
			local targetCenter = getPetTargetCenter(activeTarget)
			local targetPosition = homeCFrame.Position
			local desiredLookDirection = homeCFrame.LookVector
			local maxSpeed = PET_FOLLOW_MAX_SPEED
			local arrivalGain = PET_FOLLOW_ARRIVAL_GAIN
			local state = PET_STATE_FOLLOW

			if targetCenter ~= nil then
				state = PET_STATE_ENGAGE
				targetPosition = getEngagePosition(
					petVisual,
					targetSlotIndex,
					targetSlotCount,
					followRootCFrame,
					targetCenter,
					targetReferencePosition,
					now
				)
				desiredLookDirection = targetCenter - currentPosition
				maxSpeed = PET_ENGAGE_MAX_SPEED
				arrivalGain = PET_ENGAGE_ARRIVAL_GAIN
			end

			local nextPosition = nil

			if state == PET_STATE_FOLLOW and (targetPosition - currentPosition).Magnitude > PET_FOLLOW_SNAP_DISTANCE then
				petVisual.Velocity = Vector3.zero
				nextPosition = targetPosition
			else
				nextPosition = stepArrivePosition(
					petVisual,
					currentPosition,
					targetPosition,
					dt,
					maxSpeed,
					arrivalGain
				)
			end

			if targetCenter ~= nil then
				desiredLookDirection = targetCenter - nextPosition
			end

			petVisual.MotionState = state
			PetModelVisualFactory.pivotTo(
				petVisual,
				getPetPoseCFrame(petVisual, nextPosition, desiredLookDirection, now, dt, state, 0)
			)
		end

		PetModelVisualFactory.updateEffects(petVisual, now)
	end
end

local function updateCrystalLabels(zone, snapshot)
	local canStoreReward = canStoreCurrentCrystalReward(snapshot)
	local rollPromptCrystalId = nil

	if #snapshot.EquippedPets == 0 then
		local teleportPosition = GeneratedMapRuntime.getTeleportPosition(snapshot.CurrentZone)
		local closestDistance = math.huge

		for _, crystal in ipairs(crystals) do
			local delta = crystal.Part.Position - teleportPosition
			local distance = delta.X * delta.X + delta.Z * delta.Z

			if distance < closestDistance then
				closestDistance = distance
				rollPromptCrystalId = crystal.CrystalId
			end
		end
	end

	for _, crystal in ipairs(crystals) do
		if breakingCrystalVisuals[crystal.CrystalId] ~= nil then
			crystal.Label.Text = string.format("HP 0/%d", crystal.MaxHealth)
		elseif #snapshot.EquippedPets == 0 then
			crystal.Label.Text = if crystal.CrystalId == rollPromptCrystalId then "Roll a pet" else ""
		elseif not canStoreReward then
			crystal.Label.Text = "Full capacity"
		else
			crystal.Label.Text = string.format("HP %d/%d", math.max(0, math.ceil(crystal.Health)), crystal.MaxHealth)
		end

		crystal.Part.Color = zone.CrystalColor
		crystal.Part.Transparency = 0
	end
end

local function stepFarming(dt)
	local snapshot = currentSnapshot

	cleanupBrokenCrystalVisuals()

	if snapshot == nil then
		updatePetVisuals(dt)
		return
	end

	local zone = ZoneConfig.getZone(snapshot.CurrentZone)

	if zone == nil or #crystals == 0 then
		updatePetVisuals(dt)
		return
	end

	local crystalState = snapshot.Crystal

	if crystalState == nil then
		updatePetVisuals(dt)
		return
	end

	updateCrystalLabels(zone, snapshot)

	if
		crystalState.IsFarmingActive ~= true
		or #snapshot.EquippedPets == 0
		or not canStoreCurrentCrystalReward(snapshot)
	then
		updatePetVisuals(dt)
		return
	end

	updatePetVisuals(dt)
end

function WorldController.start()
	if hasStarted then
		return
	end

	hasStarted = true

	ClientStateStore.start()

	local existing = Workspace:FindFirstChild(LOCAL_FOLDER_NAME)

	if existing ~= nil then
		existing:Destroy()
	end

	localFolder = Instance.new("Folder")
	localFolder.Name = LOCAL_FOLDER_NAME
	localFolder.Parent = Workspace

	ClientStateStore.subscribe(function(snapshot)
		local previousSnapshot = currentSnapshot
		local previousZone = if previousSnapshot ~= nil then previousSnapshot.CurrentZone else nil
		local nextAttackSequence = if snapshot.Crystal ~= nil then snapshot.Crystal.AttackSequence or 0 else 0

		if previousZone ~= snapshot.CurrentZone then
			clearCrystals()
			petTargets = {}
			petAttackVisuals = {}
			lastAttackSequence = 0
		end

		if nextAttackSequence ~= lastAttackSequence and snapshot.Crystal ~= nil then
			local zone = ZoneConfig.getZone(snapshot.CurrentZone)

			for _, attack in ipairs(snapshot.Crystal.LastAttacks or {}) do
				playPetHitVisual(attack, zone)
			end

			lastAttackSequence = nextAttackSequence
		end

		currentSnapshot = snapshot

		syncUnlockWalls(snapshot)
		syncAscensionStatue(snapshot)
		syncCrystals(snapshot)
		refreshPetVisuals(snapshot)
		syncPetTargets(snapshot)
	end)

	RunService.Heartbeat:Connect(stepFarming)
end

return WorldController
