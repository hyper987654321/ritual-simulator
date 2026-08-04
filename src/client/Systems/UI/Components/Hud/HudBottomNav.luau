local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIThemeConfig"))
local Surface = require(script.Parent.Parent:WaitForChild("Foundation"):WaitForChild("Surface"))
local Icon = require(script.Parent.Parent:WaitForChild("Foundation"):WaitForChild("Icon"))

local HudBottomNav = {}
local C = Theme.Colors

local function createSlot(item, width, zIndex)
	local selected = item.Selected == true
	return React.createElement("TextButton", {
		Active = true, AutoButtonColor = true, BackgroundColor3 = if selected then C.Violet else C.Card,
		BackgroundTransparency = if selected then 0.05 else 0.2, BorderSizePixel = 0, LayoutOrder = item.Order,
		Size = UDim2.fromOffset(width, 52), Text = "", [React.Event.Activated] = item.Activated, ZIndex = zIndex,
	}, {
		Corner = Surface.corner(Theme.Radius.Control), Stroke = Surface.stroke(if selected then C.Cyan else C.Stroke, if selected then 0.2 else 0.7),
		Icon = Icon.create(item.IconId, { AnchorPoint = Vector2.new(0.5, 0), ImageColor3 = if selected then C.Ink else C.Muted, Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(24, 24), TextSize = 22, ZIndex = zIndex + 1 }),
		Label = Surface.label(item.Label, { Font = if selected then Theme.FontBold else Theme.Font, Position = UDim2.new(0, 2, 1, -22), Size = UDim2.new(1, -4, 0, 18), TextColor3 = if selected then C.Ink else C.Muted, TextSize = Theme.Type.Caption, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = zIndex + 1 }),
	})
end

function HudBottomNav.create(props)
	local resolved = props or {}
	local viewport = resolved.ViewportSize or Vector2.new(1280, 720)
	local mobile = viewport.X < 600
	local width = math.clamp(viewport.X - 24, 300, if mobile then 520 else 520)
	local slotWidth = math.floor((width - 32) / 5)
	local zIndex = resolved.ZIndex or 60
	local controls = {
		{ Label = "Pets", IconId = "Pets", Order = 1, Activated = resolved.OnPets },
		{ Label = "Roll", IconId = "RollDice", Order = 2, Activated = resolved.OnRoll, Selected = resolved.RollOnly },
		{ Label = "Ritual", IconId = "RitualCore", Order = 3, Activated = resolved.OnRitual },
		{ Label = "Zones", IconId = "Zones", Order = 4, Activated = resolved.OnZones },
		{ Label = "More", IconId = "More", Order = 5, Activated = resolved.OnToggleMore },
	}
	local children = { Corner = Surface.corner(Theme.Radius.Dock), Stroke = Surface.stroke(C.Stroke, 0.25), Padding = React.createElement("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }), Layout = React.createElement("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }) }
	for _, item in ipairs(controls) do children[item.Label] = createSlot(item, slotWidth, zIndex + 1) end
	if resolved.MenuOpen then
		local menuItems = {
			{ Label = "Shop", Activated = resolved.OnShop }, { Label = "Daily", Activated = resolved.OnDaily }, { Label = "Friends", Activated = resolved.OnSocial },
			{ Label = "Rush", Activated = resolved.OnRitualRush }, { Label = "Rebirth", Activated = resolved.OnRebirth }, { Label = "Boards", Activated = resolved.OnLeaderboard },
		}
		local menuChildren = { Layout = React.createElement("UIGridLayout", { CellPadding = UDim2.fromOffset(8, 8), CellSize = UDim2.new(0.5, -4, 0, 36), SortOrder = Enum.SortOrder.LayoutOrder }) }
		for index, item in ipairs(menuItems) do menuChildren["Item" .. index] = Surface.button(item.Label, { BackgroundColor3 = C.Card, LayoutOrder = index, TextSize = Theme.Type.Caption, [React.Event.Activated] = item.Activated, ZIndex = zIndex + 4 }) end
		children.MoreMenu = React.createElement("Frame", { AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = C.Panel, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.fromOffset(math.min(width, 320), 196), ZIndex = zIndex + 3 }, {
			Corner = Surface.corner(Theme.Radius.Panel), Stroke = Surface.stroke(C.Stroke, 0.25), Padding = React.createElement("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
			Title = Surface.label("More", { Size = UDim2.new(1, 0, 0, 24), TextColor3 = C.Muted, TextSize = Theme.Type.Caption, ZIndex = zIndex + 4 }),
			Items = React.createElement("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), ZIndex = zIndex + 4 }, menuChildren),
		})
	end
	return React.createElement("Frame", { AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = C.Panel, BackgroundTransparency = Theme.PanelTransparency, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(width, 68), ZIndex = zIndex }, children)
end

return HudBottomNav
