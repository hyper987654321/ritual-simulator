local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local UIIconConfig = require(Config:WaitForChild("UIIconConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local HudBottomNav = {}

local COLORS = {
	Panel = Color3.fromRGB(19, 16, 31),
	PanelEdge = Color3.fromRGB(111, 86, 176),
	Text = Color3.fromRGB(231, 226, 250),
	Muted = Color3.fromRGB(164, 156, 193),
	Violet = Color3.fromRGB(120, 91, 220),
	Gold = Color3.fromRGB(255, 207, 104),
	Cyan = Color3.fromRGB(106, 224, 239),
}

local function corner(radius)
	return React.createElement("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, transparency)
	return React.createElement("UIStroke", { Color = color, Transparency = transparency, Thickness = 1 })
end

local function iconButton(item, isPrimary, zIndex)
	local height = if isPrimary then 68 else 54
	local children = {
		Icon = React.createElement("ImageLabel", {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = UIIconConfig.getIcon(item.IconId) or "",
			ImageColor3 = if isPrimary then COLORS.Gold else COLORS.Cyan,
			Position = UDim2.fromScale(0.5, 0.08),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(if isPrimary then 30 else 24, if isPrimary then 30 else 24),
			ZIndex = zIndex + 1,
		}),
		Label = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Font = UIThemeConfig.Font,
			Position = UDim2.new(0.5, 0, 1, -5),
			Size = UDim2.new(1, -4, 0, 19),
			Text = item.Label,
			TextColor3 = if isPrimary then COLORS.Gold else COLORS.Text,
			TextSize = if isPrimary then 15 else 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = zIndex + 1,
		}),
	}

	return React.createElement("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = if isPrimary then COLORS.Violet else Color3.fromRGB(31, 26, 50),
		BorderSizePixel = 0,
		LayoutOrder = item.Order,
		Size = UDim2.fromOffset(item.Width, height),
		Text = "",
		[React.Event.Activated] = item.Activated,
		ZIndex = zIndex,
	}, children, {
		Corner = corner(12),
		Edge = stroke(if isPrimary then COLORS.Gold else COLORS.PanelEdge, if isPrimary then 0.2 else 0.45),
	})
end

local function menuButton(item, order, zIndex)
	return React.createElement("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(35, 29, 56),
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(0.5, -4, 0, 44),
		Text = item.Label,
		TextColor3 = COLORS.Text,
		Font = UIThemeConfig.Font,
		TextSize = 12,
		[React.Event.Activated] = item.Activated,
		ZIndex = zIndex,
	}, { Corner = corner(8), Edge = stroke(COLORS.PanelEdge, 0.55) })
end

function HudBottomNav.create(props)
	local resolved = props or {}
	local menuOpen, setMenuOpen = React.useState(false)
	local viewport = resolved.ViewportSize or Vector2.new(1280, 720)
	local width = math.min(viewport.X - 20, 470)
	local scale = math.clamp(math.min(viewport.Y / 760, 1), 0.82, 1)
	local zIndex = resolved.ZIndex or 60
	local availableWidth = width - 24
	local normalWidth = math.min(72, math.floor((availableWidth - 100) / 4))
	local primaryWidth = availableWidth - normalWidth * 4
	local moreItems = {
		{ Label = "Shop", Activated = resolved.OnShop },
		{ Label = "Rush", Activated = resolved.OnRitualRush },
		{ Label = "Rebirth", Activated = resolved.OnRebirth },
		{ Label = "Daily", Activated = resolved.OnRetention },
		{ Label = "Boards", Activated = resolved.OnLeaderboard },
		{ Label = "Friends", Activated = resolved.OnSocial },
	}
	local controls = {
		{ Label = "Pets", IconId = "PetInventory", Order = 1, Width = normalWidth, Activated = resolved.OnPets },
		{ Label = "Roll", IconId = "RollDice", Order = 2, Width = primaryWidth, Activated = resolved.OnRoll },
		{ Label = "Ritual", IconId = "RitualCore", Order = 3, Width = normalWidth, Activated = resolved.OnRitual },
		{ Label = "Zones", IconId = "Teleporter", Order = 4, Width = normalWidth, Activated = resolved.OnZones },
		{ Label = "More", IconId = "Shop", Order = 5, Width = normalWidth, Activated = function() setMenuOpen(not menuOpen) end },
	}
	if resolved.RollOnly == true then
		controls = {
			{ Label = "Roll", IconId = "RollDice", Order = 1, Width = primaryWidth, Activated = resolved.OnRoll },
		}
	end

	local menuChildren = {
		Layout = React.createElement("UIGridLayout", {
			CellPadding = UDim2.fromOffset(8, 8),
			CellSize = UDim2.new(0.5, -4, 0, 44),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, item in ipairs(moreItems) do
		menuChildren["Item" .. tostring(index)] = menuButton(item, index, zIndex + 2)
	end

	local navChildren = {
		Scale = React.createElement("UIScale", { Scale = scale }),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for _, item in ipairs(controls) do
		navChildren[item.Label] = iconButton(item, item.Label == "Roll", zIndex + 1)
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(width, 78),
		ZIndex = zIndex,
	}, {
		Corner = corner(16),
		Edge = stroke(COLORS.PanelEdge, 0.3),
		Navigation = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex + 1,
		}, navChildren),
		MoreMenu = if menuOpen then React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = COLORS.Panel,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0, -10),
			Size = UDim2.fromOffset(math.min(width, 300), 156),
			ZIndex = zIndex + 2,
		}, {
			Corner = corner(12),
			Edge = stroke(COLORS.PanelEdge, 0.25),
			Padding = React.createElement("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
			Items = React.createElement("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, menuChildren),
		}) else nil,
	})
end

return HudBottomNav
