local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local UIIconConfig = require(Config:WaitForChild("UIIconConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")

local GameOverlay = require(CommonComponents:WaitForChild("GameOverlay"))
local PetViewport = require(CommonComponents:WaitForChild("PetViewport"))

local PetInventoryOverlay = {}

local TILE_SIZE = UDim2.fromOffset(92, 104)
local TILE_PADDING = UDim2.fromOffset(10, 18)
local SECTION_TITLE_TEXT_SIZE = 26
local EMPTY_TEXT_COLOR = Color3.fromRGB(165, 165, 172)
local TOOLTIP_WIDTH = 196
local TOOLTIP_HEIGHT = 154
local TOOLTIP_SIDE_GAP = 10
local TOOLTIP_SIZE = UDim2.fromOffset(TOOLTIP_WIDTH, TOOLTIP_HEIGHT)
local TOOLTIP_RIGHT_X = 102
local TOOLTIP_TOP_ROW_Y = -4
local TOOLTIP_NAME_COLOR = Color3.fromRGB(0, 0, 0)
local TOOLTIP_TEXT_COLOR = TOOLTIP_NAME_COLOR
local TOOLTIP_ICON_SIZE = 22
local TOOLTIP_ROW_HEIGHT = 25
local TOOLTIP_TITLE_HEIGHT = 30
local TOOLTIP_SUBTITLE_HEIGHT = 19
local TOOLTIP_TITLE_TEXT_SIZE = 26
local TOOLTIP_SUBTITLE_TEXT_SIZE = 19
local TOOLTIP_STAT_TEXT_SIZE = 21
local TOOLTIP_CONTENT_GAP = 0
local TOOLTIP_TEXT_MIN_SIZE = 10
local BEST_PETS_POSITION = UDim2.fromOffset(0, 10)
local BEST_GRID_POSITION = UDim2.fromOffset(34, 44)
local BEST_GRID_SIZE = UDim2.new(1, -68, 0, 118)
local DIVIDER_POSITION = UDim2.new(0, 34, 0, 170)
local DIVIDER_SIZE = UDim2.new(1, -68, 0, 2)
local ALL_PETS_POSITION = UDim2.fromOffset(0, 176)
local ALL_GRID_POSITION = UDim2.fromOffset(34, 208)
local ALL_GRID_SIZE = UDim2.new(1, -68, 1, -238)
local PET_VIEWPORT_ASPECT_RATIO = 1
local PET_VIEWPORT_CAMERA_PADDING = 1.12

local function mergeProps(baseProps, extraProps)
	local props = {}

	for key, value in pairs(baseProps) do
		props[key] = value
	end

	for key, value in pairs(extraProps or {}) do
		props[key] = value
	end

	return props
end

local function createCorner(radius)
	return React.createElement("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
	})
end

local function createLabel(text, props, children)
	return React.createElement("TextLabel", mergeProps({
		BackgroundTransparency = 1,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = Color3.fromRGB(35, 35, 43),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, props), children)
end

local function createScaledLabel(text, props, minTextSize)
	return createLabel(text, mergeProps({
		TextScaled = true,
		TextWrapped = false,
	}, props), {
		SizeConstraint = React.createElement("UITextSizeConstraint", {
			MaxTextSize = (props and props.TextSize) or 18,
			MinTextSize = minTextSize or TOOLTIP_TEXT_MIN_SIZE,
		}),
	})
end

local function createEmptyText()
	return createLabel("No pets", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = UIThemeConfig.Font,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(220, 34),
		TextColor3 = EMPTY_TEXT_COLOR,
		TextSize = SECTION_TITLE_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 92,
	})
end

local function getSortChance(petId)
	local chance = PetConfig.getPetChance(petId)

	if typeof(chance) ~= "number" or chance <= 0 then
		return math.huge
	end

	return chance
end

local function sortPetStacksByRarity(stacks)
	table.sort(stacks, function(left, right)
		local leftChance = getSortChance(left.PetId)
		local rightChance = getSortChance(right.PetId)

		if leftChance == rightChance then
			return left.PetId < right.PetId
		end

		return leftChance < rightChance
	end)
end

local function getInventoryStacks(snapshot)
	local stacks = {}

	for _, petStack in ipairs(snapshot.Pets) do
		table.insert(stacks, {
			PetId = petStack.PetId,
			Count = petStack.Count or 0,
			EquippedCount = petStack.EquippedCount or 0,
			StoredCount = petStack.StoredCount or math.max(0, (petStack.Count or 0) - (petStack.EquippedCount or 0)),
		})
	end

	sortPetStacksByRarity(stacks)

	return stacks
end

local function getBestPetStacks(snapshot)
	local stacks = {}

	for _, petInstance in ipairs(snapshot.EquippedPets) do
		table.insert(stacks, {
			PetId = petInstance.PetId,
			Count = 1,
			EquippedCount = 1,
			StoredCount = 0,
		})
	end

	sortPetStacksByRarity(stacks)

	return stacks
end

local function getStoredPetStacks(snapshot)
	local stacks = {}

	for _, petStack in ipairs(getInventoryStacks(snapshot)) do
		local storedCount = petStack.StoredCount or 0

		if storedCount > 0 then
			table.insert(stacks, {
				PetId = petStack.PetId,
				Count = storedCount,
				EquippedCount = 0,
				StoredCount = storedCount,
			})
		end
	end

	return stacks
end

local function getColorHex(color)
	local red = math.floor((color.R * 255) + 0.5)
	local green = math.floor((color.G * 255) + 0.5)
	local blue = math.floor((color.B * 255) + 0.5)

	return string.format("#%02X%02X%02X", red, green, blue)
end

local function getRichTextSafeText(text)
	local safeText = tostring(text or "")
	safeText = string.gsub(safeText, "&", "&amp;")
	safeText = string.gsub(safeText, "<", "&lt;")
	safeText = string.gsub(safeText, ">", "&gt;")

	return safeText
end

local function getRichTextSegment(text, color, shouldStroke)
	local coloredText = string.format("<font color=\"%s\">%s</font>", getColorHex(color), getRichTextSafeText(text))

	if not shouldStroke then
		return coloredText
	end

	return string.format(
		"<stroke color=\"#000000\" thickness=\"1\" transparency=\"0.08\">%s</stroke>",
		coloredText
	)
end

local function getTooltipNameText(pet)
	local parts = PetConfig.getPetParts(pet.PetId)

	if parts == nil then
		return getRichTextSegment(pet.DisplayName or pet.PetId, TOOLTIP_NAME_COLOR, false)
	end

	local basePet = PetConfig.getBasePet(parts.BasePetId)
	local auraRarity = PetConfig.getAuraRarity(parts.AuraRarityId or parts.VariantId)
	local size = PetConfig.getSize(parts.SizeId)
	local textParts = {}

	if size ~= nil and size.DisplayName ~= nil and size.DisplayName ~= "" then
		table.insert(textParts, getRichTextSegment(size.DisplayName, size.Color or TOOLTIP_NAME_COLOR, size.Color ~= nil))
	end

	if auraRarity ~= nil and auraRarity.Prefix ~= nil and auraRarity.Prefix ~= "" then
		table.insert(
			textParts,
			getRichTextSegment(auraRarity.Prefix, auraRarity.UiColor or TOOLTIP_NAME_COLOR, auraRarity.UiColor ~= nil)
		)
	end

	table.insert(
		textParts,
		getRichTextSegment((basePet and basePet.DisplayName) or pet.DisplayName or pet.PetId, TOOLTIP_NAME_COLOR, false)
	)

	return table.concat(textParts, " ")
end

local function createTooltipRow(iconId, text, layoutOrder, zIndex)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, TOOLTIP_ROW_HEIGHT),
		ZIndex = zIndex,
	}, {
		Icon = React.createElement("ImageLabel", {
			Active = false,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = UIIconConfig.getIcon(iconId) or "",
			Position = UDim2.new(0, 0, 0.5, 0),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(TOOLTIP_ICON_SIZE, TOOLTIP_ICON_SIZE),
			ZIndex = zIndex + 1,
		}),
		Text = createScaledLabel(text, {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(27, 0),
			Size = UDim2.new(1, -27, 1, 0),
			TextColor3 = TOOLTIP_TEXT_COLOR,
			TextSize = TOOLTIP_STAT_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = zIndex + 1,
		}),
	})
end

local function getTooltipTextStroke(textColor)
	if textColor == nil or textColor == TOOLTIP_TEXT_COLOR then
		return 1
	end

	return 0.08
end

local function getTooltipPositionFromGui(guiObject, contentFrame)
	if
		typeof(guiObject) ~= "Instance"
		or not guiObject:IsA("GuiObject")
		or typeof(contentFrame) ~= "Instance"
		or not contentFrame:IsA("GuiObject")
	then
		return UDim2.fromOffset(TOOLTIP_RIGHT_X, TOOLTIP_TOP_ROW_Y)
	end

	local contentScale = contentFrame.AbsoluteSize.X / math.max(GameOverlay.DesignContentSize.X, 1)
	local safeContentScale = math.max(contentScale, 0.001)
	local contentSize = Vector2.new(
		contentFrame.AbsoluteSize.X / safeContentScale,
		contentFrame.AbsoluteSize.Y / safeContentScale
	)
	local tilePosition = Vector2.new(
		(guiObject.AbsolutePosition.X - contentFrame.AbsolutePosition.X) / safeContentScale,
		(guiObject.AbsolutePosition.Y - contentFrame.AbsolutePosition.Y) / safeContentScale
	)
	local tileSize = Vector2.new(
		guiObject.AbsoluteSize.X / safeContentScale,
		guiObject.AbsoluteSize.Y / safeContentScale
	)
	local xOffset = tilePosition.X + tileSize.X + TOOLTIP_SIDE_GAP
	local yOffset = tilePosition.Y + TOOLTIP_TOP_ROW_Y

	if xOffset + TOOLTIP_WIDTH > contentSize.X then
		xOffset = tilePosition.X - TOOLTIP_WIDTH - TOOLTIP_SIDE_GAP
	end

	if yOffset + TOOLTIP_HEIGHT > contentSize.Y then
		yOffset = tilePosition.Y + tileSize.Y - TOOLTIP_HEIGHT
	end

	xOffset = math.clamp(xOffset, 0, math.max(contentSize.X - TOOLTIP_WIDTH, 0))
	yOffset = math.clamp(yOffset, 0, math.max(contentSize.Y - TOOLTIP_HEIGHT, 0))

	return UDim2.fromOffset(math.floor(xOffset + 0.5), math.floor(yOffset + 0.5))
end

local function createPetTooltip(petStack, pet, petOddsText, position, zIndex)
	local tooltipZIndex = zIndex or 120
	local petName = getTooltipNameText(pet)
	local rarityText = pet.Rarity or "Unknown"
	local auraText = (pet.AuraRarity or "Plain") .. " aura"
	local damageText = NumberFormatter.compact(pet.Damage or 0) .. " power"
	local countText = "x" .. NumberFormatter.compact(petStack.Count or 1) .. " owned"
	local rarityColor = PetConfig.getRarityColor(rarityText)
	local auraColor = pet.AuraColor or Color3.fromRGB(235, 235, 240)

	return React.createElement("Frame", {
		Active = false,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Position = position or UDim2.fromOffset(TOOLTIP_RIGHT_X, TOOLTIP_TOP_ROW_Y),
		Size = TOOLTIP_SIZE,
		ZIndex = tooltipZIndex,
	}, {
		Corner = createCorner(8),
		Stroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = auraColor,
			Thickness = 3,
			Transparency = 0,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 2),
		}),
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, TOOLTIP_CONTENT_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Title = createScaledLabel(petName, {
			Font = UIThemeConfig.Font,
			LayoutOrder = 1,
			RichText = true,
			Size = UDim2.new(1, 0, 0, TOOLTIP_TITLE_HEIGHT),
			TextColor3 = TOOLTIP_NAME_COLOR,
			TextSize = TOOLTIP_TITLE_TEXT_SIZE,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = tooltipZIndex + 1,
		}),
		Rarity = createScaledLabel(rarityText, {
			Font = UIThemeConfig.Font,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, TOOLTIP_SUBTITLE_HEIGHT),
			TextColor3 = rarityColor,
			TextSize = TOOLTIP_SUBTITLE_TEXT_SIZE,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = getTooltipTextStroke(rarityColor),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = tooltipZIndex + 1,
		}),
		Aura = createTooltipRow("RitualCore", auraText, 3, tooltipZIndex + 1),
		Odds = createTooltipRow("RollDice", petOddsText, 4, tooltipZIndex + 1),
		Power = createTooltipRow("RitualCore", damageText, 5, tooltipZIndex + 1),
		Count = createTooltipRow("PetInventory", countText, 6, tooltipZIndex + 1),
	})
end

local function PetTile(props)
	local petStack = props.PetStack
	local layoutOrder = props.LayoutOrder
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd
	local tileZIndex = 93
	local hasPet = petStack ~= nil and (petStack.Count or 0) > 0
	local pet = if hasPet then PetConfig.getPet(petStack.PetId) else nil
	local petColor = if pet ~= nil then pet.Color else Color3.fromRGB(45, 45, 55)
	local petAccentColor = if pet ~= nil then pet.AuraAccentColor or pet.AuraColor or petColor else petColor
	local petOddsText = if pet ~= nil then PetConfig.getChanceOddsText(pet.RollChance) else ""
	local viewportRef = React.useRef(nil)
	local children = {
		Viewport = React.createElement("TextButton", {
			ref = viewportRef,
			Active = hasPet,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = if hasPet then 0 else 0.35,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextTransparency = 1,
			ZIndex = tileZIndex,
			[React.Event.MouseEnter] = if hasPet then function()
				if onHoverStart ~= nil then
					onHoverStart(petStack, pet, petOddsText, viewportRef.current)
				end
			end else nil,
			[React.Event.MouseLeave] = if hasPet then function()
				if onHoverEnd ~= nil then
					onHoverEnd()
				end
			end else nil,
		}, {
			Corner = createCorner(8),
			Stroke = React.createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = if hasPet then petAccentColor else Color3.fromRGB(0, 0, 0),
				Thickness = if hasPet then 3 else 2,
				Transparency = if hasPet then 0 else 0.7,
			}),
			Model = if hasPet then PetViewport.create({
				PetId = petStack.PetId,
				AspectRatio = PET_VIEWPORT_ASPECT_RATIO,
				CameraPadding = PET_VIEWPORT_CAMERA_PADDING,
				ModelName = "InventoryViewportPet",
				Position = UDim2.fromScale(0.08, 0.05),
				Size = UDim2.fromScale(0.84, 0.78),
				WarningContext = "inventory",
				ZIndex = tileZIndex + 1,
			}) else nil,
		}),
	}

	if hasPet and (petStack.Count or 0) > 1 then
		children.Count = createLabel("x" .. NumberFormatter.compact(petStack.Count), {
			AnchorPoint = Vector2.new(1, 0),
			Font = UIThemeConfig.Font,
			Position = UDim2.new(1, -3, 0, -3),
			Size = UDim2.fromOffset(56, 22),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 16,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.08,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = tileZIndex + 2,
		})
	end

	if hasPet and petOddsText ~= "" then
		children.Odds = createLabel(petOddsText, {
			AnchorPoint = Vector2.new(0.5, 1),
			Font = UIThemeConfig.Font,
			Position = UDim2.new(0.5, 0, 1, 6),
			Size = UDim2.new(1, 10, 0, 24),
			TextColor3 = petColor,
			TextSize = 20,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.08,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = tileZIndex + 2,
		})
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = TILE_SIZE,
		ZIndex = tileZIndex,
	}, children)
end

local function createPetTile(petStack, layoutOrder, onHoverStart, onHoverEnd)
	return React.createElement(PetTile, {
		PetStack = petStack,
		LayoutOrder = layoutOrder,
		OnHoverStart = onHoverStart,
		OnHoverEnd = onHoverEnd,
	})
end

local function createGridChildren(petStacks, onHoverStart, onHoverEnd)
	local children = {
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 10),
		}),
		Grid = React.createElement("UIGridLayout", {
			CellPadding = TILE_PADDING,
			CellSize = TILE_SIZE,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
	}

	for index, petStack in ipairs(petStacks) do
		children["Pet" .. tostring(index)] = createPetTile(petStack, index, onHoverStart, onHoverEnd)
	end

	return children
end

local function createBestGrid(petStacks, onHoverStart, onHoverEnd)
	local children = if #petStacks > 0 then createGridChildren(petStacks, onHoverStart, onHoverEnd) else {
		Empty = createEmptyText(),
	}

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = BEST_GRID_POSITION,
		Size = BEST_GRID_SIZE,
		ZIndex = 92,
	}, children)
end

local function createStoredGrid(petStacks, onHoverStart, onHoverEnd)
	local children = if #petStacks > 0 then createGridChildren(petStacks, onHoverStart, onHoverEnd) else {
		Empty = createEmptyText(),
	}

	return React.createElement("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		Position = ALL_GRID_POSITION,
		ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0),
		ScrollBarImageTransparency = 0.25,
		ScrollBarThickness = 5,
		Size = ALL_GRID_SIZE,
		ZIndex = 92,
	}, children)
end

local function PetInventoryOverlayComponent(props)
	local resolvedProps = props or {}
	local snapshot = resolvedProps.Snapshot
	local contentRef = React.useRef(nil)
	local hoveredPet, setHoveredPet = React.useState(nil)

	if snapshot == nil then
		return nil
	end

	local maxEquippedPets = snapshot.MaxEquippedPets or PetConfig.MAX_EQUIPPED
	local bestPetStacks = getBestPetStacks(snapshot)
	local storedPetStacks = getStoredPetStacks(snapshot)
	local contentChildren = {}

	local function showTooltip(petStack, pet, petOddsText, guiObject)
		if pet == nil then
			setHoveredPet(nil)
			return
		end

		setHoveredPet({
			Pet = pet,
			PetOddsText = petOddsText,
			PetStack = petStack,
			Position = getTooltipPositionFromGui(guiObject, contentRef.current),
		})
	end

	local function hideTooltip()
		setHoveredPet(nil)
	end

	contentChildren.BestPetsTitle = createLabel(string.format(
		"Your Best Pets <font color=\"#25C9FF\">%d/%d</font>",
		#snapshot.EquippedPets,
		maxEquippedPets
	), {
		Font = UIThemeConfig.Font,
		Position = BEST_PETS_POSITION,
		RichText = true,
		Size = UDim2.new(1, 0, 0, 36),
		TextColor3 = Color3.fromRGB(35, 35, 43),
		TextSize = SECTION_TITLE_TEXT_SIZE,
		TextStrokeColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 96,
	})

	contentChildren.BestGrid = createBestGrid(bestPetStacks, showTooltip, hideTooltip)
	contentChildren.Divider = React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(225, 225, 225),
		BorderSizePixel = 0,
		Position = DIVIDER_POSITION,
		Size = DIVIDER_SIZE,
		ZIndex = 92,
	})
	contentChildren.AllPetsTitle = createLabel("All Pets", {
		Font = UIThemeConfig.Font,
		Position = ALL_PETS_POSITION,
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = Color3.fromRGB(35, 35, 43),
		TextSize = SECTION_TITLE_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 96,
	})
	contentChildren.Grid = createStoredGrid(storedPetStacks, showTooltip, hideTooltip)

	if hoveredPet ~= nil then
		contentChildren.Tooltip = createPetTooltip(
			hoveredPet.PetStack,
			hoveredPet.Pet,
			hoveredPet.PetOddsText,
			hoveredPet.Position,
			130
		)
	end

	return GameOverlay.create({
		BackgroundId = "PetInventory",
		OnClose = resolvedProps.OnClose,
		Size = resolvedProps.Size,
		Title = "Pets",
		TitleTextSize = 64,
		TitleWidth = 260,
		ViewportSize = resolvedProps.ViewportSize,
		ZIndex = resolvedProps.ZIndex,
		Children = {
			Content = React.createElement("Frame", {
				ref = contentRef,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 92,
			}, contentChildren),
		},
	})
end

function PetInventoryOverlay.create(props)
	return React.createElement(PetInventoryOverlayComponent, props)
end

return PetInventoryOverlay
