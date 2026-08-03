local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local RitualStoneConfig = require(Config:WaitForChild("RitualStoneConfig"))
local RitualStoneVisualConfig = require(Config:WaitForChild("RitualStoneVisualConfig"))
local UIIconConfig = require(Config:WaitForChild("UIIconConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")

local GameOverlay = require(CommonComponents:WaitForChild("GameOverlay"))
local AnimatedScaleButton = require(CommonComponents:WaitForChild("AnimatedScaleButton"))

local RitualCoreOverlay = {}

local TEXT_COLOR = Color3.fromRGB(35, 35, 43)
local ACCENT_COLOR = Color3.fromRGB(37, 201, 255)
local STAT_COLORS = {
	Capacity = Color3.fromRGB(37, 201, 255),
	Luck = Color3.fromRGB(160, 112, 255),
	RollSpeed = Color3.fromRGB(255, 178, 62),
	RitualPower = Color3.fromRGB(255, 92, 194),
}
local SECTION_TITLE_TEXT_SIZE = 25
local BODY_TEXT_SIZE = 18
local SMALL_TEXT_SIZE = 13
local CONTENT_TOP_PADDING = 44
local LEFT_COLUMN_POSITION = UDim2.fromOffset(44, CONTENT_TOP_PADDING)
local LEFT_COLUMN_SIZE = UDim2.fromOffset(384, 380)
local RIGHT_COLUMN_POSITION = UDim2.fromOffset(456, CONTENT_TOP_PADDING)
local RIGHT_COLUMN_SIZE = UDim2.fromOffset(420, 376)
local VIEWPORT_SIZE = UDim2.fromOffset(384, 308)
local STAT_CARD_SIZE = UDim2.fromOffset(186, 42)
local STAT_CARD_PADDING = UDim2.fromOffset(10, 8)
local UPGRADE_ROW_HEIGHT = 50
local UPGRADE_BUTTON_HOVER_SCALE = 1.04
local UPGRADE_BUTTON_PRESS_SCALE = 0.96
local UPGRADE_BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local UPGRADE_BUTTON_REST_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local UPGRADE_READY_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(142, 255, 86)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(56, 226, 73)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 184, 62)),
})
local UPGRADE_LOCKED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 118, 118)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(239, 64, 64)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(193, 32, 32)),
})

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

local function createBorder(thickness)
	return React.createElement("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 3,
		Transparency = 0,
	})
end

local function createLabel(text, props, children)
	return React.createElement("TextLabel", mergeProps({
		BackgroundTransparency = 1,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = TEXT_COLOR,
		TextSize = BODY_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, props), children)
end

local function RitualStoneViewport(props)
	local snapshot = props.Snapshot
	local zIndex = props.ZIndex or 95
	local visual = RitualStoneVisualConfig.getVisualState(snapshot)
	local viewportRef = React.useRef(nil)
	local cameraRef = React.useRef(nil)

	React.useEffect(function()
		local viewport = viewportRef.current
		local camera = cameraRef.current

		if viewport ~= nil and camera ~= nil then
			viewport.CurrentCamera = camera
		end
	end, {})

	return React.createElement("ViewportFrame", {
		ref = viewportRef,
		Ambient = Color3.fromRGB(180, 180, 195),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.35, -0.8, -0.4),
		Position = UDim2.fromOffset(0, 0),
		Size = VIEWPORT_SIZE,
		ZIndex = zIndex,
	}, {
		Corner = createCorner(8),
		Stroke = React.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(0, 0, 0),
			Thickness = 4,
			Transparency = 0,
		}),
		Camera = React.createElement("Camera", {
			ref = cameraRef,
			CFrame = CFrame.new(Vector3.new(4.9, 3.1, 6.1), Vector3.new(0, 0.25, 0)),
			FieldOfView = 33,
		}),
		World = React.createElement("WorldModel", {}, {
			Body = React.createElement("Part", {
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Color = RitualStoneVisualConfig.BodyColor,
				CFrame = CFrame.new(0, 0, 0),
				Material = Enum.Material.Basalt,
				Size = visual.BodySize,
			}),
			Core = React.createElement("Part", {
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Color = visual.CoreColor,
				CFrame = CFrame.new(0, 0.25, 0),
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Ball,
				Size = visual.CoreSize,
			}, {
				Glow = React.createElement("PointLight", {
					Brightness = visual.GlowBrightness,
					Color = visual.CoreColor,
					Range = 14,
				}),
			}),
			Ring = React.createElement("Part", {
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Color = RitualStoneVisualConfig.RingColor,
				CFrame = CFrame.Angles(0, 0, math.rad(90)),
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Cylinder,
				Size = RitualStoneVisualConfig.RingSize,
				Transparency = visual.RingTransparency,
			}),
		}),
	})
end

local function createStatCard(label, value, layoutOrder, accentColor)
	local resolvedAccentColor = accentColor or TEXT_COLOR

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = STAT_CARD_SIZE,
		ZIndex = 96,
	}, {
		Corner = createCorner(7),
		Stroke = createBorder(2),
		Accent = React.createElement("Frame", {
			BackgroundColor3 = resolvedAccentColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(0, 8, 1, 0),
			ZIndex = 97,
		}, {
			Corner = createCorner(7),
		}),
		Label = createLabel(label, {
			Position = UDim2.fromOffset(17, 4),
			Size = UDim2.new(1, -24, 0, 16),
			TextColor3 = resolvedAccentColor,
			TextSize = 15,
			ZIndex = 97,
		}),
		Value = createLabel(value, {
			Position = UDim2.fromOffset(17, 20),
			Size = UDim2.new(1, -24, 0, 20),
			TextColor3 = resolvedAccentColor,
			TextSize = 19,
			ZIndex = 97,
		}),
	})
end

local function getUpgradeEffectText(upgradeId, upgrade)
	if upgradeId == "Capacity" then
		return "+" .. NumberFormatter.compact(upgrade.Amount or 0) .. " capacity"
	end

	if upgradeId == "Luck" then
		return "+" .. NumberFormatter.decimal(upgrade.Amount or 0, 1) .. " luck"
	end

	if upgradeId == "RollSpeed" then
		return "+" .. NumberFormatter.compact(upgrade.Amount or 0) .. "% roll speed"
	end

	return upgrade.Description or ""
end

local function UpgradeButton(props)
	local upgradeId = props.UpgradeId
	local upgrade = props.Upgrade
	local level = props.Level or 0
	local cost = props.Cost or 0
	local canAfford = props.CanAfford == true
	local canBuy = props.CanBuy == true
	local onBuyUpgrade = props.OnBuyUpgrade
	local gradient = if canAfford then UPGRADE_READY_GRADIENT else UPGRADE_LOCKED_GRADIENT
	local costText = NumberFormatter.compact(cost) .. " Essence"

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, UPGRADE_ROW_HEIGHT),
		ZIndex = 96,
	}, {
		Button = AnimatedScaleButton.create({
			HoverScale = UPGRADE_BUTTON_HOVER_SCALE,
			PressScale = UPGRADE_BUTTON_PRESS_SCALE,
			HoverTweenInfo = UPGRADE_BUTTON_HOVER_TWEEN_INFO,
			RestTweenInfo = UPGRADE_BUTTON_REST_TWEEN_INFO,
			ButtonProps = {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 96,
				[React.Event.Activated] = if canBuy then function()
					onBuyUpgrade(upgradeId)
				end else nil,
			},
			Children = {
				Background = React.createElement("Frame", {
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = if canBuy then 0 else 0.08,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 96,
				}, {
					Gradient = React.createElement("UIGradient", {
						Color = gradient,
						Rotation = 90,
					}),
					Corner = createCorner(8),
					Stroke = createBorder(3),
				}),
				Title = createLabel(upgrade.DisplayName, {
					Font = UIThemeConfig.Font,
					Position = UDim2.fromOffset(16, 3),
					Size = UDim2.new(1, -154, 0, 25),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 20,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0,
					ZIndex = 97,
				}),
				Effect = createLabel(getUpgradeEffectText(upgradeId, upgrade), {
					Position = UDim2.fromOffset(16, 28),
					Size = UDim2.new(1, -154, 0, 18),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = SMALL_TEXT_SIZE + 1,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0.15,
					ZIndex = 97,
				}),
				Level = createLabel("Lv " .. tostring(level), {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -14, 0, 3),
					Size = UDim2.fromOffset(122, 23),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 18,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 97,
				}),
				Cost = createLabel(costText, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -14, 0, 28),
					Size = UDim2.fromOffset(130, 18),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = SMALL_TEXT_SIZE + 1,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0.08,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 97,
				}),
			},
		}),
	})
end

local function createUpgradeRow(snapshot, upgradeId, layoutOrder, onBuyUpgrade)
	local upgrade = RitualStoneConfig.Upgrades[upgradeId]

	if upgrade == nil then
		return nil
	end

	local level = (snapshot.StoneLevels and snapshot.StoneLevels[upgradeId]) or 0
	local cost = (snapshot.NextUpgradeCosts and snapshot.NextUpgradeCosts[upgradeId]) or 0
	local canAfford = (snapshot.Essence or 0) >= cost
	local canBuy = canAfford and onBuyUpgrade ~= nil

	return React.createElement(UpgradeButton, {
		CanAfford = canAfford,
		CanBuy = canBuy,
		Cost = cost,
		LayoutOrder = layoutOrder,
		Level = level,
		OnBuyUpgrade = onBuyUpgrade,
		Upgrade = upgrade,
		UpgradeId = upgradeId,
	})
end

local function createUpgradeRows(snapshot, onBuyUpgrade)
	local rows = {}

	for index, upgradeId in ipairs(RitualStoneConfig.UpgradeOrder) do
		rows[upgradeId] = createUpgradeRow(snapshot, upgradeId, index, onBuyUpgrade)
	end

	return rows
end

local function createEssenceDisplay(essenceText)
	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 344),
		Size = UDim2.fromOffset(0, 32),
		ZIndex = 96,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Icon = React.createElement("ImageLabel", {
			Active = false,
			BackgroundTransparency = 1,
			Image = UIIconConfig.getIcon("Essence") or "",
			LayoutOrder = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(30, 30),
			ZIndex = 97,
		}),
		Text = createLabel(essenceText, {
			AutomaticSize = Enum.AutomaticSize.X,
			Font = UIThemeConfig.Font,
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 32),
			TextColor3 = ACCENT_COLOR,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 97,
		}),
	})
end

local function createLeftColumn(snapshot)
	local stats = snapshot.StoneStats or RitualStoneConfig.BaseStats
	local capacity = stats.Capacity or RitualStoneConfig.BaseStats.Capacity
	local essenceText = string.format(
		"%s / %s Essence",
		NumberFormatter.compact(snapshot.Essence or 0),
		NumberFormatter.compact(capacity)
	)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = LEFT_COLUMN_POSITION,
		Size = LEFT_COLUMN_SIZE,
		ZIndex = 94,
	}, {
		Viewport = React.createElement(RitualStoneViewport, {
			Snapshot = snapshot,
			ZIndex = 95,
		}),
		DisplayTitle = createLabel("Ritual Stone", {
			Position = UDim2.fromOffset(0, 316),
			Size = UDim2.new(1, 0, 0, 30),
			TextSize = SECTION_TITLE_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 96,
		}),
		Essence = createEssenceDisplay(essenceText),
	})
end

local function createRightColumn(snapshot, onBuyUpgrade)
	local stats = snapshot.StoneStats or RitualStoneConfig.BaseStats
	local rollSpeedText = tostring(RitualStoneConfig.getRollOpeningSpeedPercent(stats.RollSpeedPercent)) .. "%"
	local statRows = {
		Grid = React.createElement("UIGridLayout", {
			CellPadding = STAT_CARD_PADDING,
			CellSize = STAT_CARD_SIZE,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		Capacity = createStatCard("Capacity", NumberFormatter.compact(stats.Capacity or 0), 1, STAT_COLORS.Capacity),
		Luck = createStatCard("Luck", NumberFormatter.decimal(stats.Luck or 0, 2), 2, STAT_COLORS.Luck),
		RollSpeed = createStatCard("Roll Speed", rollSpeedText, 3, STAT_COLORS.RollSpeed),
		RitualPower = createStatCard("Ritual Power", NumberFormatter.compact(snapshot.RitualPower or 0), 4, STAT_COLORS.RitualPower),
	}
	local upgradeRows = createUpgradeRows(snapshot, onBuyUpgrade)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = RIGHT_COLUMN_POSITION,
		Size = RIGHT_COLUMN_SIZE,
		ZIndex = 94,
	}, {
		Stats = React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 152),
			ZIndex = 96,
		}, {
			Corner = createCorner(8),
			Stroke = React.createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 3,
				Transparency = 0,
			}),
			Title = createLabel("Core Stats", {
				Font = UIThemeConfig.Font,
				Position = UDim2.fromOffset(0, 5),
				Size = UDim2.new(1, 0, 0, 30),
				TextSize = SECTION_TITLE_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 97,
			}),
			TitleDivider = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(225, 225, 225),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 14, 0, 38),
				Size = UDim2.new(1, -28, 0, 2),
				ZIndex = 97,
			}),
			Rows = React.createElement("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(14, 46),
				Size = UDim2.new(1, -28, 0, 96),
				ZIndex = 97,
			}, statRows),
		}),
		UpgradesTitle = createLabel("Upgrades", {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(0, 164),
			Size = UDim2.new(1, 0, 0, 28),
			TextSize = SECTION_TITLE_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 96,
		}),
		UpgradesTitleDivider = React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(225, 225, 225),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 14, 0, 196),
			Size = UDim2.new(1, -28, 0, 2),
			ZIndex = 96,
		}),
		Upgrades = React.createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 204),
			Size = UDim2.new(1, 0, 0, 166),
			ZIndex = 96,
		}, mergeProps({
			Layout = React.createElement("UIListLayout", {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}, upgradeRows)),
	})
end

function RitualCoreOverlay.create(props)
	local resolvedProps = props or {}
	local snapshot = resolvedProps.Snapshot

	if snapshot == nil then
		return nil
	end

	return GameOverlay.create({
		BackgroundId = "RitualCore",
		OnClose = resolvedProps.OnClose,
		Size = resolvedProps.Size,
		Title = "Ritual Core",
		TitleTextSize = 60,
		TitleWidth = 470,
		ViewportSize = resolvedProps.ViewportSize,
		ZIndex = resolvedProps.ZIndex,
		Children = {
			LeftColumn = createLeftColumn(snapshot),
			RightColumn = createRightColumn(snapshot, resolvedProps.OnBuyUpgrade),
		},
	})
end

return RitualCoreOverlay
