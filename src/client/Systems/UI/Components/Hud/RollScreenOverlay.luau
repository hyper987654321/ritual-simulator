local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")

local HudIconBar = require(CommonComponents:WaitForChild("HudIconBar"))
local HudLayoutConfig = require(script.Parent:WaitForChild("HudLayoutConfig"))
local HudPrimitives = require(CommonComponents:WaitForChild("HudPrimitives"))
local PetViewport = require(CommonComponents:WaitForChild("PetViewport"))
local Surface = require(script.Parent.Parent:WaitForChild("Foundation"):WaitForChild("Surface"))
local Icon = require(script.Parent.Parent:WaitForChild("Foundation"):WaitForChild("Icon"))

local RollScreenOverlay = {}

local PET_VIEWPORT_ASPECT_RATIO = 1.48
local PET_VIEWPORT_CAMERA_PADDING = 1.05
local ROLL_SCREEN_ACTION_POSITION = UDim2.fromScale(0.5, 0.84)
local AUTO_ROLL_ICON_ROTATION_DEGREES_PER_SECOND = 180
local AUTO_ROLL_ICON_PIVOT_Y_OFFSET = 3
local ROLL_ROULETTE_WIDTH = 1000
local ROLL_ROULETTE_HEIGHT = 250
local ROLL_ROULETTE_CARD_WIDTH = 190
local ROLL_ROULETTE_CARD_HEIGHT = 218
local ROLL_ROULETTE_CARD_GAP = 10
local ROLL_ROULETTE_POSITION = UDim2.fromScale(0.5, 0.32)
local ROLL_RESULT_NUMBER_POSITION = UDim2.fromScale(0.5, 0.58)
local ROLL_RESULT_NAME_POSITION = UDim2.fromScale(0.5, 0.67)
local ROLL_RESULT_POWER_POSITION = UDim2.fromScale(0.5, 0.725)
local ROLL_ROULETTE_CARD_COUNT = 28
local ROLL_ROULETTE_TARGET_INDEX = 23
local ROLL_ROULETTE_TARGET_INDEX_MIN = 21
local ROLL_ROULETTE_TARGET_INDEX_MAX = 25
local ROLL_ROULETTE_ROLLING_Z_INDEX = 30
local ROLL_ROULETTE_REVEAL_Z_INDEX = 50
local ROLL_ROULETTE_NEAR_MISS_CHANCE = 0.08
local ROLL_ROULETTE_SECOND_NEAR_MISS_CHANCE = 0.18
local ROLL_ROULETTE_VIEWPORT_WIDTH_RATIO = 0.97
local ROLL_SCREEN_DESIGN_WIDTH = ROLL_ROULETTE_WIDTH / ROLL_ROULETTE_VIEWPORT_WIDTH_RATIO
local ROLL_SCREEN_DESIGN_HEIGHT = HudLayoutConfig.DefaultViewportSize.Y
local ROLL_SCREEN_MIN_SCALE = 0.35

local rollVisualRandom = Random.new()

RollScreenOverlay.ScrimTransparency = 0.42

local function isFinitePositiveNumber(value)
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge and value > 0
end

local function getVisualPetInfo(entry, isLegacyFallback)
	if typeof(entry) ~= "table" or typeof(entry.PetId) ~= "string" then
		return nil
	end

	local pet = PetConfig.getPet(entry.PetId)

	if pet == nil then
		return nil
	end

	local chance = if isFinitePositiveNumber(entry.AdjustedChance)
		then entry.AdjustedChance
		else entry.Chance
	local oddsText = if typeof(entry.OddsText) == "string" and entry.OddsText ~= ""
		then entry.OddsText
		elseif isFinitePositiveNumber(chance) then PetConfig.getChanceOddsText(chance) else "-"

	if isLegacyFallback and oddsText ~= "-" and string.sub(oddsText, 1, 5) ~= "Base " then
		oddsText = "Base " .. oddsText
	end

	local power = entry.Power

	if typeof(power) ~= "number" or power ~= power or math.abs(power) == math.huge or power < 0 then
		power = if isLegacyFallback then PetConfig.getPetPower(entry.PetId) else nil
	end

	return {
		PetId = entry.PetId,
		DisplayName = if typeof(entry.DisplayName) == "string" then entry.DisplayName else pet.DisplayName,
		RevealDisplayName = PetConfig.getPetRevealDisplayName(entry.PetId),
		Rarity = if typeof(entry.Rarity) == "string" then entry.Rarity else pet.Rarity,
		AuraRarity = if typeof(entry.AuraRarity) == "string" then entry.AuraRarity else pet.AuraRarity,
		AuraRarityId = if typeof(entry.AuraRarityId) == "string" then entry.AuraRarityId else pet.AuraRarityId,
		AuraRevealTier = entry.AuraRevealTier or pet.AuraRevealTier,
		AdjustedChance = if not isLegacyFallback then chance else nil,
		Chance = if isFinitePositiveNumber(chance) then chance else 0,
		OddsText = oddsText,
		Power = power,
		Color = pet.Color,
		AuraColor = pet.AuraColor,
		AuraAccentColor = pet.AuraAccentColor,
		IsLegacyFallback = isLegacyFallback,
	}
end

local function getRollPreviewEntries(snapshot)
	local roll = if typeof(snapshot) == "table" and typeof(snapshot.Roll) == "table" then snapshot.Roll else nil
	local preview = if roll ~= nil and typeof(roll.Preview) == "table" then roll.Preview else nil
	local sourceEntries = if preview ~= nil and typeof(preview.Entries) == "table" then preview.Entries else nil
	local isLegacyFallback = sourceEntries == nil
	local entries = {}

	if sourceEntries == nil then
		sourceEntries = PetConfig.getRollPreview()
	end

	for _, entry in ipairs(sourceEntries) do
		local petInfo = getVisualPetInfo(entry, isLegacyFallback)

		if petInfo ~= nil then
			table.insert(entries, petInfo)
		end
	end

	return entries
end

local function getPreviewPetInfo(sequence, index)
	if #sequence == 0 then
		return nil
	end

	local wrappedIndex = ((index - 1) % #sequence) + 1

	return sequence[wrappedIndex]
end

local function getPetInfoById(petId, sequence)
	for _, petInfo in ipairs(sequence or {}) do
		if petInfo.PetId == petId then
			return petInfo
		end
	end

	local pet = PetConfig.getPet(petId)

	if pet == nil then
		return nil
	end

	return getVisualPetInfo({
		PetId = petId,
		Chance = pet.RollChance,
		OddsText = "Base " .. PetConfig.getChanceOddsText(pet.RollChance),
		Power = PetConfig.getPetPower(petId),
	}, true)
end

local function getRollRouletteSpacing()
	return ROLL_ROULETTE_CARD_WIDTH + ROLL_ROULETTE_CARD_GAP
end

local function getRollRouletteFillerPetInfo(sequence, index)
	if #sequence == 0 then
		return nil
	end

	local totalChance = 0

	for _, petInfo in ipairs(sequence) do
		totalChance += petInfo.Chance or 0
	end

	if totalChance <= 0 then
		return getPreviewPetInfo(sequence, index)
	end

	local rollPoint = (((index * 67) + (index * index * 13)) % 997) / 997 * totalChance
	local runningChance = 0

	for _, petInfo in ipairs(sequence) do
		runningChance += petInfo.Chance or 0

		if rollPoint <= runningChance then
			return petInfo
		end
	end

	return sequence[#sequence]
end

local function getRandomRollRouletteFillerPetInfo(sequence)
	if #sequence == 0 then
		return nil
	end

	local totalChance = 0

	for _, petInfo in ipairs(sequence) do
		totalChance += petInfo.Chance or 0
	end

	if totalChance <= 0 then
		return sequence[rollVisualRandom:NextInteger(1, #sequence)]
	end

	local rollPoint = rollVisualRandom:NextNumber(0, totalChance)
	local runningChance = 0

	for _, petInfo in ipairs(sequence) do
		runningChance += petInfo.Chance or 0

		if rollPoint <= runningChance then
			return petInfo
		end
	end

	return sequence[#sequence]
end

local function getRollRouletteNearMissCandidates(sequence, resultInfo)
	local candidates = {}
	local resultPower = if resultInfo ~= nil then resultInfo.Power or 0 else 0

	for _, petInfo in ipairs(sequence or {}) do
		if resultInfo == nil or petInfo.PetId ~= resultInfo.PetId then
			if resultInfo ~= nil and (petInfo.Power or 0) > resultPower then
				table.insert(candidates, petInfo)
			end
		end
	end

	table.sort(candidates, function(left, right)
		local leftChance = left.Chance or 1
		local rightChance = right.Chance or 1

		if leftChance == rightChance then
			return (left.Power or 0) > (right.Power or 0)
		end

		return leftChance < rightChance
	end)

	return candidates
end

local function addRollRouletteNearMissCards(track, targetIndex, sequence, resultInfo)
	if rollVisualRandom:NextNumber() > ROLL_ROULETTE_NEAR_MISS_CHANCE then
		return
	end

	local candidates = getRollRouletteNearMissCandidates(sequence, resultInfo)

	if #candidates == 0 then
		return
	end

	local primaryCandidate = candidates[rollVisualRandom:NextInteger(1, math.min(#candidates, 2))]
	local primarySlot = if rollVisualRandom:NextNumber() < 0.68 then targetIndex + 1 else targetIndex - 1

	if primarySlot >= 1 and primarySlot <= #track then
		track[primarySlot] = primaryCandidate
	end

	if #candidates > 1 and rollVisualRandom:NextNumber() < ROLL_ROULETTE_SECOND_NEAR_MISS_CHANCE then
		local secondarySlot = if primarySlot == targetIndex + 1 then targetIndex - 1 else targetIndex + 1

		if secondarySlot >= 1 and secondarySlot <= #track then
			local secondaryCandidate = candidates[rollVisualRandom:NextInteger(1, #candidates)]

			track[secondarySlot] = secondaryCandidate
		end
	end
end

local function getRollAnimationPetInfo(rollAnimation)
	if rollAnimation == nil or rollAnimation.Pet == nil or rollAnimation.Phase == "Rolling" then
		return nil
	end

	return rollAnimation.ResultInfo or getPetInfoById(rollAnimation.Pet.PetId, rollAnimation.Sequence)
end

local function getRollPetNumberText(petInfo)
	if petInfo == nil or petInfo.OddsText == nil then
		return "-"
	end

	return petInfo.OddsText
end

local function getRollPetPowerText(petInfo)
	if petInfo == nil or typeof(petInfo.Power) ~= "number" then
		return ""
	end

	local prefix = if petInfo.IsLegacyFallback then "Base power " else "Power "

	return prefix .. NumberFormatter.compact(petInfo.Power)
end

local function getRollRouletteCardEmphasis(xPosition)
	local cardCenter = xPosition + ROLL_ROULETTE_CARD_WIDTH / 2
	local distanceFromCenter = math.abs(cardCenter - ROLL_ROULETTE_WIDTH / 2)

	return 1 - math.clamp(distanceFromCenter / (ROLL_ROULETTE_WIDTH / 2), 0, 1)
end

local function createRollRouletteCard(petInfo, xPosition, emphasis, isTarget, zIndexBase)
	local displayName = if petInfo ~= nil then petInfo.DisplayName else "Unknown"
	local petColor = if petInfo ~= nil and petInfo.Color ~= nil then petInfo.Color else Color3.fromRGB(126, 91, 255)
	local accentColor = if petInfo ~= nil and petInfo.AuraAccentColor ~= nil then petInfo.AuraAccentColor else petColor
	local resolvedEmphasis = math.clamp(emphasis or 0, 0, 1)
	local cardZIndex = zIndexBase + 1
	local cardScale = 0.72 + resolvedEmphasis * 0.28
	local cardWidth = math.floor(ROLL_ROULETTE_CARD_WIDTH * cardScale)
	local cardHeight = math.floor(ROLL_ROULETTE_CARD_HEIGHT * cardScale)
	local cardX = xPosition + (ROLL_ROULETTE_CARD_WIDTH - cardWidth) / 2
	local cardY = (ROLL_ROULETTE_HEIGHT - cardHeight) / 2
	local fade = 1 - resolvedEmphasis
	local strokeTransparency = if isTarget then 0.05 else 0.32 + fade * 0.42
	local numberY = math.floor(10 * cardScale)
	local numberHeight = math.floor(48 * cardScale)
	local viewportY = math.floor(44 * cardScale)
	local viewportHeight = math.floor(126 * cardScale)
	local nameY = math.floor(166 * cardScale)
	local nameHeight = math.floor(42 * cardScale)

	return React.createElement("Frame", {
		BackgroundColor3 = if isTarget then Color3.fromRGB(45, 39, 55) else Color3.fromRGB(31, 30, 40),
		BackgroundTransparency = 0.07 + fade * 0.28,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(cardX, cardY),
		Size = UDim2.fromOffset(cardWidth, cardHeight),
		ZIndex = cardZIndex,
	}, {
		Corner = HudPrimitives.createCorner(8),
		Stroke = HudPrimitives.createStroke(petColor, strokeTransparency),
		Accent = React.createElement("Frame", {
			BackgroundColor3 = petColor,
			BackgroundTransparency = fade * 0.35,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 4),
			ZIndex = cardZIndex + 1,
		}, {
			Corner = HudPrimitives.createCorner(8),
		}),
		AuraAccent = if isTarget and petInfo ~= nil and (petInfo.AuraRevealTier or 1) >= 4 then React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = accentColor,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(0.72, 0, 0, 3),
			ZIndex = cardZIndex + 2,
		}, {
			Corner = HudPrimitives.createCorner(4),
		}) else nil,
		Number = HudPrimitives.createLabel(getRollPetNumberText(petInfo), {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(8, numberY),
			Size = UDim2.new(1, -16, 0, numberHeight),
			TextColor3 = petColor,
			TextSize = math.floor(42 * cardScale),
			TextTransparency = fade * 0.28,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = cardZIndex + 1,
		}),
		Viewport = if petInfo ~= nil then PetViewport.create({
			PetId = petInfo.PetId,
			AspectRatio = PET_VIEWPORT_ASPECT_RATIO,
			CameraPadding = PET_VIEWPORT_CAMERA_PADDING,
			ModelName = "RollViewportPet",
			Position = UDim2.fromOffset(10, viewportY),
			Size = UDim2.new(1, -20, 0, viewportHeight),
			WarningContext = "roll",
			ZIndex = cardZIndex + 1,
		}) else nil,
		Name = HudPrimitives.createLabel(displayName, {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(8, nameY),
			Size = UDim2.new(1, -16, 0, nameHeight),
			TextColor3 = petColor,
			TextSize = math.floor(19 * cardScale),
			TextTransparency = fade * 0.2,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = cardZIndex + 1,
		}),
	})
end

local function createRollRouletteTrack(rollAnimation, zIndexBase)
	local track = rollAnimation.Track
	local resolvedZIndexBase = zIndexBase or ROLL_ROULETTE_ROLLING_Z_INDEX

	if track == nil then
		track = RollScreenOverlay.buildRollRouletteTrack(rollAnimation.Sequence or {}, nil)
	end

	local children = {
		CenterLine = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(255, 233, 90),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(ROLL_ROULETTE_WIDTH / 2, 0),
			Size = UDim2.new(0, 4, 1, 0),
			ZIndex = resolvedZIndexBase + 4,
		}),
		CenterTop = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(255, 233, 90),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(ROLL_ROULETTE_WIDTH / 2, 0),
			Size = UDim2.fromOffset(54, 5),
			ZIndex = resolvedZIndexBase + 5,
		}, {
			Corner = HudPrimitives.createCorner(4),
		}),
		CenterBottom = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(255, 233, 90),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(ROLL_ROULETTE_WIDTH / 2, ROLL_ROULETTE_HEIGHT),
			Size = UDim2.fromOffset(54, 5),
			ZIndex = resolvedZIndexBase + 5,
		}, {
			Corner = HudPrimitives.createCorner(4),
		}),
	}
	local offset = rollAnimation.TrackOffset or 0
	local spacing = getRollRouletteSpacing()

	for index = 1, #track do
		local petInfo = track[index]
		local xPosition = (index - 1) * spacing - offset

		if petInfo ~= nil
			and xPosition > -ROLL_ROULETTE_CARD_WIDTH - spacing
			and xPosition < ROLL_ROULETTE_WIDTH + spacing
		then
			local emphasis = getRollRouletteCardEmphasis(xPosition)

			children["Pet" .. tostring(index)] = createRollRouletteCard(
				petInfo,
				xPosition,
				emphasis,
				rollAnimation.Phase == "Reveal" and rollAnimation.TargetIndex == index,
				resolvedZIndexBase
			)
		end
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = ROLL_ROULETTE_POSITION,
		Size = UDim2.fromOffset(ROLL_ROULETTE_WIDTH, ROLL_ROULETTE_HEIGHT),
		ZIndex = resolvedZIndexBase,
	}, children)
end

local function createRevealBurst(petInfo, zIndexBase)
	local revealTier = math.clamp((if petInfo ~= nil then petInfo.AuraRevealTier or 1 else 1), 1, 5)

	if revealTier <= 1 then
		return nil
	end

	local petColor = if petInfo ~= nil and petInfo.Color ~= nil then petInfo.Color else Color3.fromRGB(126, 91, 255)
	local accentColor = if petInfo ~= nil and petInfo.AuraAccentColor ~= nil then petInfo.AuraAccentColor else petColor
	local burstWidth = 300 + revealTier * 54
	local burstHeight = 72 + revealTier * 12
	local fillTransparency = math.clamp(0.9 - revealTier * 0.055, 0.58, 0.88)

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = petColor,
		BackgroundTransparency = fillTransparency,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.625),
		Size = UDim2.fromOffset(burstWidth, burstHeight),
		ZIndex = zIndexBase + 4,
	}, {
		Corner = HudPrimitives.createCorner(8),
		Stroke = React.createElement("UIStroke", {
			Color = accentColor,
			Thickness = 1 + revealTier,
			Transparency = math.clamp(0.72 - revealTier * 0.1, 0.16, 0.7),
		}),
		Gradient = if petInfo ~= nil and petInfo.AuraRarityId == "rainbow" then React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 86, 86)),
				ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 215, 80)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(89, 255, 136)),
				ColorSequenceKeypoint.new(0.65, Color3.fromRGB(87, 213, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 232)),
			}),
			Rotation = 12,
		}) else nil,
	})
end

local function createResultNameLabel(petInfo, zIndex)
	local displayName = petInfo.RevealDisplayName or petInfo.DisplayName
	local petColor = petInfo.Color or Color3.fromRGB(237, 235, 255)
	local children = nil

	if petInfo.AuraRarityId == "rainbow" then
		children = {
			Gradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 86, 86)),
					ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 215, 80)),
					ColorSequenceKeypoint.new(0.4, Color3.fromRGB(89, 255, 136)),
					ColorSequenceKeypoint.new(0.65, Color3.fromRGB(87, 213, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 232)),
				}),
				Rotation = 0,
			}),
		}
	end

	return HudPrimitives.createLabel(displayName, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = UIThemeConfig.Font,
		Position = ROLL_RESULT_NAME_POSITION,
		Size = UDim2.fromOffset(560, 46),
		TextColor3 = petColor,
		TextSize = if (petInfo.AuraRevealTier or 1) >= 5 then 34 else 30,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.35,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = zIndex,
	}, children)
end

local function createRollAnimationOverlay(rollAnimation)
	if rollAnimation == nil then
		return nil
	end

	local petInfo = getRollAnimationPetInfo(rollAnimation)
	local isReveal = rollAnimation.Phase == "Reveal"
	local zIndexBase = if isReveal then ROLL_ROULETTE_REVEAL_Z_INDEX else ROLL_ROULETTE_ROLLING_Z_INDEX
	local children = {
		Track = createRollRouletteTrack(rollAnimation, zIndexBase),
	}

	if isReveal and petInfo ~= nil then
		children.RevealBurst = createRevealBurst(petInfo, zIndexBase)
		children.ResultNumber = HudPrimitives.createLabel(getRollPetNumberText(petInfo), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Font = UIThemeConfig.Font,
			Position = ROLL_RESULT_NUMBER_POSITION,
			Size = UDim2.fromOffset(440, 56),
			TextColor3 = petInfo.Color,
			TextSize = 46,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.35,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = zIndexBase + 6,
		})
		children.ResultName = createResultNameLabel(petInfo, zIndexBase + 6)
		children.ResultPower = HudPrimitives.createLabel(getRollPetPowerText(petInfo), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Font = UIThemeConfig.Font,
			Position = ROLL_RESULT_POWER_POSITION,
			Size = UDim2.fromOffset(360, 30),
			TextColor3 = Color3.fromRGB(237, 235, 255),
			TextSize = 20,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.35,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = zIndexBase + 6,
		})
	end

	return React.createElement("Frame", {
		Active = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndexBase,
	}, children)
end

function RollScreenOverlay.getScale(viewportSize)
	local resolvedViewportSize = viewportSize or HudLayoutConfig.DefaultViewportSize
	local widthScale = resolvedViewportSize.X / ROLL_SCREEN_DESIGN_WIDTH
	local heightScale = resolvedViewportSize.Y / ROLL_SCREEN_DESIGN_HEIGHT

	return math.clamp(math.min(widthScale, heightScale), ROLL_SCREEN_MIN_SCALE, 1)
end

function RollScreenOverlay.getRollPreviewData(snapshot)
	if snapshot == nil then
		return {
			Entries = {},
		}
	end

	return {
		Entries = getRollPreviewEntries(snapshot),
	}
end

function RollScreenOverlay.getRollAnimationDurationScale(snapshot)
	local rollSpeedPercent = RitualStoneConfig.BaseStats.RollSpeedPercent

	if snapshot ~= nil and snapshot.StoneStats ~= nil and snapshot.StoneStats.RollSpeedPercent ~= nil then
		rollSpeedPercent = snapshot.StoneStats.RollSpeedPercent
	end

	return RitualStoneConfig.getRollOpeningDurationScale(rollSpeedPercent)
end

function RollScreenOverlay.getRollAnimationPaceText(durationScale)
	local safeDurationScale = math.max(durationScale or 1, 0.01)

	return tostring(math.floor((1 / safeDurationScale) * 100 + 0.5)) .. "%"
end

function RollScreenOverlay.getRollRouletteTargetOffset(targetIndex)
	return (targetIndex - 1) * getRollRouletteSpacing()
		+ ROLL_ROULETTE_CARD_WIDTH / 2
		- ROLL_ROULETTE_WIDTH / 2
end

function RollScreenOverlay.getRollOpeningDurationFromScale(durationScale)
	return math.max(
		0.05,
		RitualStoneConfig.getRollOpeningDuration(RitualStoneConfig.BaseStats.RollSpeedPercent)
			* math.max(durationScale or 1, 0.01)
	)
end

function RollScreenOverlay.buildRollRouletteTrack(sequence, rolledPet)
	local resultInfo = if rolledPet ~= nil then getPetInfoById(rolledPet.PetId, sequence) else nil

	if
		typeof(rolledPet) == "table"
		and (
			isFinitePositiveNumber(rolledPet.AdjustedChance)
			or typeof(rolledPet.OddsText) == "string"
			or typeof(rolledPet.Power) == "number"
		)
	then
		resultInfo = getVisualPetInfo(rolledPet, false) or resultInfo
	end

	local track = {}
	local targetIndex = if resultInfo ~= nil
		then rollVisualRandom:NextInteger(ROLL_ROULETTE_TARGET_INDEX_MIN, ROLL_ROULETTE_TARGET_INDEX_MAX)
		else ROLL_ROULETTE_TARGET_INDEX

	for index = 1, ROLL_ROULETTE_CARD_COUNT do
		if resultInfo ~= nil then
			track[index] = getRandomRollRouletteFillerPetInfo(sequence or {}) or resultInfo
		else
			track[index] = getRollRouletteFillerPetInfo(sequence or {}, index) or resultInfo
		end
	end

	if resultInfo ~= nil then
		addRollRouletteNearMissCards(track, targetIndex, sequence or {}, resultInfo)
		track[targetIndex] = resultInfo
	end

	return track, targetIndex
end

local function RollScreenActions(props)
	local autoRollEnabled = props.AutoRollEnabled == true
	local iconRotation, setIconRotation = React.useBinding(0)
	local rotationRef = React.useRef(0)

	React.useEffect(function()
		rotationRef.current = 0
		setIconRotation(0)

		if not autoRollEnabled then
			return
		end

		local connection = RunService.Heartbeat:Connect(function(deltaTime)
			rotationRef.current = (rotationRef.current + deltaTime * AUTO_ROLL_ICON_ROTATION_DEGREES_PER_SECOND) % 360
			setIconRotation(rotationRef.current)
		end)

		return function()
			connection:Disconnect()
		end
	end, { autoRollEnabled })

	return Surface.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = ROLL_SCREEN_ACTION_POSITION, Size = UDim2.fromOffset(320, 64), ZIndex = 60 }, {
		Padding = React.createElement("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
		Layout = React.createElement("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }),
		Auto = Surface.button(if autoRollEnabled then "Auto Roll: On" else "Auto Roll: Off", { BackgroundColor3 = if autoRollEnabled then UIThemeConfig.Colors.Success else UIThemeConfig.Colors.Card, LayoutOrder = 1, Size = UDim2.fromOffset(180, 44), [React.Event.Activated] = props.OnToggleAutoRoll }, { Icon = Icon.create("AutoRoll", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(24, 24), TextSize = 20, ZIndex = 61 }) }),
		Hide = Surface.button("Hide", { BackgroundColor3 = UIThemeConfig.Colors.Card, LayoutOrder = 2, Size = UDim2.fromOffset(92, 44), [React.Event.Activated] = props.OnHide }, { Icon = Icon.create("Close", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(20, 20), TextSize = 18, ZIndex = 61 }) }),
	})
end

function RollScreenOverlay.create(props)
	local resolvedProps = props or {}

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(ROLL_SCREEN_DESIGN_WIDTH, ROLL_SCREEN_DESIGN_HEIGHT),
		ZIndex = 30,
	}, {
		Scale = React.createElement("UIScale", {
			Scale = resolvedProps.Scale or 1,
		}),
		RollAnimation = createRollAnimationOverlay(resolvedProps.RollAnimation),
		RollScreenActions = React.createElement(RollScreenActions, {
			AutoRollEnabled = resolvedProps.AutoRollEnabled,
			OnHide = resolvedProps.OnHide,
			OnToggleAutoRoll = resolvedProps.OnToggleAutoRoll,
		}),
	})
end

return RollScreenOverlay
