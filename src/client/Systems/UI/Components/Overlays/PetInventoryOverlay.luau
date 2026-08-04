local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Util = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util")
local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local PetConfig = require(Config:WaitForChild("PetConfig"))
local Theme = require(Config:WaitForChild("UIThemeConfig"))
local ViewModel = require(script.Parent.Parent.Parent:WaitForChild("ViewModels"):WaitForChild("PetInventoryViewModel"))
local Kit = require(script.Parent:WaitForChild("OverlayKit"))
local PetViewport = require(script.Parent.Parent:WaitForChild("Common"):WaitForChild("PetViewport"))

local PetInventoryOverlay = {}
local C = Theme.Colors

local function petCard(item, selectedPetId, onSelect, order, cardWidth, zIndex)
	local rarityColor = PetConfig.getRarityColor(item.Rarity)
	local equipped = item.EquippedCount > 0
	return React.createElement("TextButton", { Active = true, AutoButtonColor = true, BackgroundColor3 = if selectedPetId == item.PetId then Color3.fromRGB(38, 63, 76) else C.Card, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.fromOffset(cardWidth, 166), Text = "", ZIndex = zIndex, [React.Event.Activated] = function() onSelect(item.PetId) end }, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, Theme.Radius.Control) }),
		Stroke = React.createElement("UIStroke", { Color = rarityColor, Thickness = 2, Transparency = if selectedPetId == item.PetId then 0.05 else 0.35 }),
		Viewport = PetViewport.create({ PetId = item.PetId, AspectRatio = 1.25, CameraPadding = 1.12, FieldOfView = 32, ModelName = "InventoryPet_" .. item.PetId, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 86), WarningContext = "pet-inventory", ZIndex = zIndex + 1 }),
		Power = Kit.label(NumberFormatter.compact(item.Power) .. " power", { Font = Theme.FontBold, Position = UDim2.fromOffset(10, 94), Size = UDim2.new(1, -20, 0, 22), TextColor3 = C.Gold, TextSize = Theme.Type.Value, ZIndex = zIndex + 1 }),
		Name = Kit.label(item.DisplayName, { Position = UDim2.fromOffset(10, 118), Size = UDim2.new(1, -20, 0, 18), TextColor3 = C.Ink, TextSize = Theme.Type.Label, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = zIndex + 1 }),
		Rarity = Kit.label(item.Rarity, { Position = UDim2.fromOffset(10, 138), Size = UDim2.new(1, -70, 0, 16), TextColor3 = rarityColor, TextSize = Theme.Type.Caption, ZIndex = zIndex + 1 }),
		Quantity = if item.Count > 1 then Kit.label("x" .. NumberFormatter.compact(item.Count), { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -8), Size = UDim2.fromOffset(42, 18), TextColor3 = C.Muted, TextSize = Theme.Type.Caption, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = zIndex + 1 }) else nil,
		Equipped = if equipped then Kit.label("EQUIPPED " .. tostring(item.EquippedCount), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(74, 18), TextColor3 = C.Success, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = zIndex + 2 }) else nil,
	})
end

function PetInventoryOverlay.create(props)
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local mobile = viewport.X < 600
	local narrow = viewport.X < 390
	local columns = if narrow then 2 elseif mobile then 3 else math.clamp(math.floor(viewport.X / 250), 3, 5)
	local width = math.min(760, math.max(288, math.floor(viewport.X * (mobile and 0.92 or 0.76))))
	local height = math.min(540, math.max(360, math.floor(viewport.Y * (mobile and 0.86 or 0.78))))
	local filterText, setFilterText = React.useState("")
	local sortBy, setSortBy = React.useState("Power")
	local selectedPetId, setSelectedPetId = React.useState(nil)
	local model = ViewModel.build(props.Snapshot or {}, { FilterText = filterText, SortBy = sortBy, Descending = true, IsMobile = mobile, Columns = columns, SelectedPetId = selectedPetId })
	local gridChildren = { Layout = React.createElement("UIGridLayout", { CellPadding = UDim2.fromOffset(8, 8), CellSize = UDim2.new(1 / columns, -8, 0, 166), FillDirectionMaxCells = columns, SortOrder = Enum.SortOrder.LayoutOrder }) }
	for index, item in ipairs(model.Items) do
		gridChildren["Pet" .. tostring(index)] = petCard(item, selectedPetId, setSelectedPetId, index, math.floor((width - 32 - (columns - 1) * 8) / columns), 86)
	end
	local children = {
		Toolbar = React.createElement("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 62), Size = UDim2.new(1, -32, 0, 40), ZIndex = 82 }, {
			Search = React.createElement("TextBox", { ClearTextOnFocus = false, BackgroundColor3 = C.Card, BorderSizePixel = 0, Font = Theme.Font, PlaceholderColor3 = C.Muted, PlaceholderText = "Search pets", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -188, 1, 0), Text = filterText, TextColor3 = C.Ink, TextSize = Theme.Type.Label, [React.Change.Text] = function(instance) setFilterText(instance.Text) end, ZIndex = 83 }, { Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, Theme.Radius.Control) }), Stroke = React.createElement("UIStroke", { Color = C.Stroke, Transparency = 0.55 }) }),
			EquipBest = Kit.button("Best", { BackgroundColor3 = C.Violet, Position = UDim2.new(1, -180, 0, 0), Size = UDim2.fromOffset(64, 40), TextSize = Theme.Type.Caption, ZIndex = 83, [React.Event.Activated] = props.OnEquipBest }),
			Sort = Kit.button("Sort: " .. sortBy, { BackgroundColor3 = C.Card, Position = UDim2.new(1, -108, 0, 0), Size = UDim2.fromOffset(108, 40), TextSize = Theme.Type.Caption, ZIndex = 83, [React.Event.Activated] = function() setSortBy(if sortBy == "Power" then "Rarity" elseif sortBy == "Rarity" then "Name" else "Power") end }),
		}),
		Summary = Kit.label(string.format("%d pets - %d equipped", model.Counts.Owned, model.Counts.Equipped), { Position = UDim2.fromOffset(16, 108), Size = UDim2.new(1, -32, 0, 20), TextColor3 = C.Muted, TextSize = Theme.Type.Caption, ZIndex = 82 }),
		Grid = React.createElement("ScrollingFrame", { Active = true, AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), Position = UDim2.fromOffset(16, 132), ScrollBarImageColor3 = C.Violet, ScrollBarThickness = 5, Size = UDim2.new(1, -32, 1, -204), ZIndex = 82 }, gridChildren),
	}
	local selected = model.SelectedItem
	if selected ~= nil then
		local selectedCount = selected.EquippedCount
		local maxCount = math.min(selected.Count, model.MaxEquipped)
		children.SelectedActions = React.createElement("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, height - 60), Size = UDim2.new(1, -32, 0, 44), ZIndex = 83 }, {
			Name = Kit.label(selected.DisplayName, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -244, 1, 0), TextColor3 = C.Ink, Font = Theme.FontBold, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 84 }),
			Minus = Kit.button("-", { BackgroundColor3 = if selectedCount > 0 then C.Card else C.Locked, Position = UDim2.new(1, -236, 0, 0), Size = UDim2.fromOffset(44, 44), TextSize = 22, ZIndex = 84, [React.Event.Activated] = if selectedCount > 0 then function() props.OnSetEquippedCount(selected.PetId, selectedCount - 1) end else nil }),
			Count = Kit.label(tostring(selectedCount), { Position = UDim2.new(1, -188, 0, 0), Size = UDim2.fromOffset(40, 44), TextColor3 = C.Ink, Font = Theme.FontBold, TextSize = Theme.Type.Value, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84 }),
			Plus = Kit.button("+", { BackgroundColor3 = if selectedCount < maxCount then C.Card else C.Locked, Position = UDim2.new(1, -144, 0, 0), Size = UDim2.fromOffset(44, 44), TextSize = 22, ZIndex = 84, [React.Event.Activated] = if selectedCount < maxCount then function() props.OnSetEquippedCount(selected.PetId, selectedCount + 1) end else nil }),
			Unequip = Kit.button("Unequip", { BackgroundColor3 = C.Card, Position = UDim2.new(1, -92, 0, 0), Size = UDim2.fromOffset(92, 44), TextSize = Theme.Type.Caption, ZIndex = 84, [React.Event.Activated] = function() props.OnUnequip(selected.PetId) end }),
		})
	end
	return Kit.modal({ Title = "Pet Inventory", MaximumWidth = width, MaximumHeight = height, ViewportSize = viewport, ZIndex = 80, OnClose = props.OnClose, Children = children })
end

return PetInventoryOverlay
