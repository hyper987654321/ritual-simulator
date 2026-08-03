local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local PotionConfig = require(Config:WaitForChild("PotionConfig"))
local ShopProductConfig = require(Config:WaitForChild("ShopProductConfig"))
local UIIconConfig = require(Config:WaitForChild("UIIconConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")

local AnimatedScaleButton = require(CommonComponents:WaitForChild("AnimatedScaleButton"))
local GameOverlay = require(CommonComponents:WaitForChild("GameOverlay"))

local ShopOverlay = {}

local OVERLAY_SIZE = UDim2.fromScale(0.58, 0.72)
local DESIGN_CONTENT_SIZE = Vector2.new(620, 470)
local TEXT_COLOR = Color3.fromRGB(35, 35, 43)
local MUTED_TEXT_COLOR = Color3.fromRGB(92, 88, 101)
local GEM_COLOR = Color3.fromRGB(255, 74, 214)
local GOLD_COLOR = Color3.fromRGB(255, 218, 92)
local RUSH_COLOR = Color3.fromRGB(37, 201, 255)
local BOOST_COLOR = Color3.fromRGB(42, 199, 116)
local BODY_TEXT_SIZE = 17
local SECTION_TITLE_TEXT_SIZE = 25
local CARD_WIDTH = 178
local CARD_HEIGHT = 118
local CARD_GAP = 12
local POTION_CARD_WIDTH = 246
local POTION_CARD_HEIGHT = 128
local POTION_BUTTON_WIDTH = 106
local BUTTON_HEIGHT = 30
local ICON_SIZE = 30
local BUTTON_HOVER_SCALE = 1.04
local BUTTON_PRESS_SCALE = 0.96
local BUTTON_BUY_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 238, 111)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 182, 55)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 118, 24)),
})
local BUTTON_USE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(111, 222, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(37, 201, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 145, 226)),
})
local BUTTON_ACTIVE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(142, 255, 86)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(56, 226, 73)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 184, 62)),
})
local BUTTON_DISABLED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(176, 180, 190)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(122, 126, 138)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(82, 86, 98)),
})
local BUTTON_LOCKED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 118, 118)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(239, 64, 64)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(193, 32, 32)),
})

local PRODUCT_TYPE_ACCENT_COLORS = {
	[ShopProductConfig.ProductTypes.GemPack] = GEM_COLOR,
	[ShopProductConfig.ProductTypes.RitualRushPremium] = RUSH_COLOR,
	[ShopProductConfig.ProductTypes.Boost] = BOOST_COLOR,
}

local BOOST_ACCENT_COLORS = {
	[ShopProductConfig.BoostIds.EssenceMultiplier] = BOOST_COLOR,
	[ShopProductConfig.BoostIds.LuckMultiplier] = GEM_COLOR,
}

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

local function createBorder(thickness, transparency)
	return React.createElement("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 3,
		Transparency = transparency or 0,
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

local function createDivider(yPosition)
	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(225, 225, 225),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, yPosition),
		Size = UDim2.new(1, -56, 0, 2),
		ZIndex = 96,
	})
end

local function createSectionTitle(text, yPosition)
	return createLabel(text, {
		Font = UIThemeConfig.Font,
		Position = UDim2.fromOffset(0, yPosition),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = SECTION_TITLE_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 96,
	})
end

local function createGemIcon(position, size, zIndex)
	return React.createElement("ImageLabel", {
		Active = false,
		BackgroundTransparency = 1,
		Image = UIIconConfig.getIcon("Essence") or "",
		ImageColor3 = GEM_COLOR,
		Position = position,
		ScaleType = Enum.ScaleType.Fit,
		Size = size or UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
		ZIndex = zIndex or 97,
	})
end

local function createIcon(iconId, iconColor, position, size, zIndex)
	return React.createElement("ImageLabel", {
		Active = false,
		BackgroundTransparency = 1,
		Image = if iconId ~= nil then UIIconConfig.getIcon(iconId) or "" else "",
		ImageColor3 = iconColor,
		Position = position,
		ScaleType = Enum.ScaleType.Fit,
		Size = size or UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
		ZIndex = zIndex or 97,
	})
end

local function getProductAccentColor(product)
	local grant = product.Grant
	local boost = if typeof(grant) == "table" then grant.Boost else nil

	if typeof(boost) == "table" and BOOST_ACCENT_COLORS[boost.BoostId] ~= nil then
		return BOOST_ACCENT_COLORS[boost.BoostId]
	end

	return PRODUCT_TYPE_ACCENT_COLORS[product.ProductType] or GEM_COLOR
end

local function getProductDetail(product)
	local grant = product.Grant
	local ritualGems = if typeof(grant) == "table" then grant.RitualGems else nil

	if product.ProductType == ShopProductConfig.ProductTypes.GemPack and typeof(ritualGems) == "number" then
		return NumberFormatter.compact(ritualGems) .. " Gem pack"
	end

	return product.Description or ""
end

local function createProductActivatedHandler(product, onProductActivated)
	local robloxProductId = ShopProductConfig.getRobloxProductId(product)

	if onProductActivated == nil or robloxProductId == nil then
		return nil
	end

	local shopProductId = product.ShopProductId

	return function()
		onProductActivated(shopProductId, robloxProductId)
	end
end

local function ProductButton(props)
	local isActionable = props.OnActivated ~= nil
	local gradient = if isActionable
		then props.Gradient or BUTTON_ACTIVE_GRADIENT
		else props.DisabledGradient or BUTTON_LOCKED_GRADIENT

	return AnimatedScaleButton.create({
		Animate = isActionable,
		HoverScale = BUTTON_HOVER_SCALE,
		PressScale = BUTTON_PRESS_SCALE,
		ButtonProps = {
			Active = isActionable,
			AnchorPoint = Vector2.new(0.5, 1),
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = props.Position or UDim2.new(0.5, 0, 1, -10),
			Size = props.Size or UDim2.new(1, -22, 0, BUTTON_HEIGHT),
			Text = "",
			ZIndex = 98,
			[React.Event.Activated] = props.OnActivated,
		},
		Children = {
			Background = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = if isActionable then 0 else 0.1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 98,
			}, {
				Gradient = React.createElement("UIGradient", {
					Color = gradient,
					Rotation = 90,
				}),
				Corner = createCorner(8),
				Stroke = createBorder(3),
			}),
			Label = createLabel(props.Text or "Soon", {
				Font = UIThemeConfig.Font,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextSize = 15,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 99,
			}, {
				TextSizeConstraint = React.createElement("UITextSizeConstraint", {
					MaxTextSize = 15,
					MinTextSize = 8,
				}),
			}),
		},
	})
end

local function createProductCard(props)
	local accentColor = props.AccentColor or GEM_COLOR
	local layoutOrder = props.LayoutOrder or 1

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		ZIndex = 96,
	}, {
		Corner = createCorner(8),
		Stroke = createBorder(3, 0.05),
		Accent = React.createElement("Frame", {
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 6),
			ZIndex = 97,
		}, {
			Corner = createCorner(8),
		}),
		Icon = createGemIcon(UDim2.fromOffset(14, 18), UDim2.fromOffset(28, 28), 97),
		Name = createLabel(props.Name or "Offer", {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(50, 14),
			Size = UDim2.new(1, -60, 0, 28),
			TextColor3 = accentColor,
			TextSize = 21,
			ZIndex = 97,
		}),
		Detail = createLabel(props.Detail or "", {
			Position = UDim2.fromOffset(14, 46),
			Size = UDim2.new(1, -28, 0, 24),
			TextColor3 = MUTED_TEXT_COLOR,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 97,
		}),
		Action = React.createElement(ProductButton, {
			OnActivated = props.OnActivated,
			Text = props.ActionText or "Soon",
		}),
	})
end

local function getPotionAccentColor(potion)
	local boostGrant = if typeof(potion.BoostGrant) == "table" then potion.BoostGrant else nil

	if boostGrant ~= nil and BOOST_ACCENT_COLORS[boostGrant.BoostId] ~= nil then
		return BOOST_ACCENT_COLORS[boostGrant.BoostId]
	end

	return BOOST_COLOR
end

local function createPotionActivatedHandler(potionId, callback)
	if typeof(potionId) ~= "string" or callback == nil then
		return nil
	end

	return function()
		callback(potionId)
	end
end

local function createPotionCard(props)
	local potion = props.Potion
	local accentColor = getPotionAccentColor(potion)
	local ownedCount = math.max(0, math.floor(potion.Count or 0))
	local gemCost = math.max(0, math.floor(potion.GemCost or 0))
	local ritualGems = math.max(0, math.floor(props.RitualGems or 0))
	local canBuy = potion.IsShopEnabled == true and gemCost > 0 and ritualGems >= gemCost and props.OnBuyPotion ~= nil
	local canUse = ownedCount > 0 and props.OnUsePotion ~= nil
	local buyText = if gemCost > 0 then NumberFormatter.compact(gemCost) .. " Gems" else "Unavailable"
	local useText = "Use"

	if potion.IsShopEnabled ~= true then
		buyText = "Unavailable"
	elseif gemCost > 0 and ritualGems < gemCost then
		buyText = "Need Gems"
	end

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 1,
		Size = UDim2.fromOffset(POTION_CARD_WIDTH, POTION_CARD_HEIGHT),
		ZIndex = 96,
	}, {
		Corner = createCorner(8),
		Stroke = createBorder(3, 0.05),
		Accent = React.createElement("Frame", {
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 6),
			ZIndex = 97,
		}, {
			Corner = createCorner(8),
		}),
		Icon = createIcon(potion.IconId, accentColor, UDim2.fromOffset(14, 18), UDim2.fromOffset(28, 28), 97),
		Name = createLabel(potion.DisplayName or "Potion", {
			Font = UIThemeConfig.Font,
			Position = UDim2.fromOffset(50, 14),
			Size = UDim2.new(1, -142, 0, 26),
			TextColor3 = accentColor,
			TextScaled = true,
			TextSize = 20,
			ZIndex = 97,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 20,
				MinTextSize = 10,
			}),
		}),
		Owned = createLabel(NumberFormatter.compact(ownedCount) .. " owned", {
			AnchorPoint = Vector2.new(1, 0),
			Font = UIThemeConfig.Font,
			Position = UDim2.new(1, -14, 0, 18),
			Size = UDim2.fromOffset(78, 20),
			TextColor3 = TEXT_COLOR,
			TextScaled = true,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 97,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 13,
				MinTextSize = 8,
			}),
		}),
		Detail = createLabel(potion.Description or "", {
			Position = UDim2.fromOffset(14, 52),
			Size = UDim2.new(1, -28, 0, 34),
			TextColor3 = MUTED_TEXT_COLOR,
			TextScaled = true,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 97,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 13,
				MinTextSize = 8,
			}),
		}),
		Buy = React.createElement(ProductButton, {
			Gradient = BUTTON_BUY_GRADIENT,
			OnActivated = if canBuy then createPotionActivatedHandler(potion.PotionId, props.OnBuyPotion) else nil,
			Position = UDim2.new(0, 12 + POTION_BUTTON_WIDTH / 2, 1, -8),
			Size = UDim2.fromOffset(POTION_BUTTON_WIDTH, BUTTON_HEIGHT),
			Text = buyText,
		}),
		Use = React.createElement(ProductButton, {
			DisabledGradient = BUTTON_DISABLED_GRADIENT,
			Gradient = BUTTON_USE_GRADIENT,
			OnActivated = if canUse then createPotionActivatedHandler(potion.PotionId, props.OnUsePotion) else nil,
			Position = UDim2.new(1, -(12 + POTION_BUTTON_WIDTH / 2), 1, -8),
			Size = UDim2.fromOffset(POTION_BUTTON_WIDTH, BUTTON_HEIGHT),
			Text = useText,
		}),
	})
end

local function createPotionRow(snapshot, onBuyPotion, onUsePotion, yPosition)
	local potions = if typeof(snapshot) == "table" and typeof(snapshot.Potions) == "table"
		then snapshot.Potions
		else PotionConfig.getPotionSnapshots({})
	local ritualGems = if typeof(snapshot) == "table" then snapshot.RitualGems or 0 else 0
	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for index, potion in ipairs(potions) do
		children["Potion" .. tostring(index)] = createPotionCard({
			LayoutOrder = index,
			OnBuyPotion = onBuyPotion,
			OnUsePotion = onUsePotion,
			Potion = potion,
			RitualGems = ritualGems,
		})
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(28, yPosition),
		Size = UDim2.new(1, -56, 0, POTION_CARD_HEIGHT),
		ZIndex = 96,
	}, children)
end

local function createCardRow(items, yPosition)
	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for index, item in ipairs(items) do
		children["Card" .. tostring(index)] = createProductCard(mergeProps(item, {
			LayoutOrder = index,
		}))
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(28, yPosition),
		Size = UDim2.new(1, -56, 0, CARD_HEIGHT),
		ZIndex = 96,
	}, children)
end

local function createBalancePanel(snapshot)
	local ritualGems = if snapshot ~= nil then snapshot.RitualGems or 0 else 0

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(36, 28),
		Size = UDim2.new(1, -72, 0, 58),
		ZIndex = 96,
	}, {
		Corner = createCorner(8),
		Stroke = createBorder(3, 0.08),
		Row = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 20, 0.5, 0),
			Size = UDim2.new(1, -42, 0, 34),
			ZIndex = 97,
		}, {
			Icon = createGemIcon(UDim2.new(0, 0, 0.5, -15), UDim2.fromOffset(30, 30), 98),
			Label = createLabel("Ritual Gems", {
				AnchorPoint = Vector2.new(0, 0.5),
				Font = UIThemeConfig.Font,
				Position = UDim2.new(0, 42, 0.5, 2),
				Size = UDim2.new(1, -238, 0, 30),
				TextColor3 = GEM_COLOR,
				TextScaled = true,
				TextSize = 24,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 98,
			}, {
				TextSizeConstraint = React.createElement("UITextSizeConstraint", {
					MaxTextSize = 24,
					MinTextSize = 12,
				}),
			}),
			Value = createLabel(NumberFormatter.compact(ritualGems), {
				AnchorPoint = Vector2.new(1, 0.5),
				Font = UIThemeConfig.Font,
				Position = UDim2.new(1, 0, 0.5, 1),
				Size = UDim2.fromOffset(180, 34),
				TextColor3 = GOLD_COLOR,
				TextScaled = true,
				TextSize = 30,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.72,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 98,
			}, {
				TextSizeConstraint = React.createElement("UITextSizeConstraint", {
					MaxTextSize = 30,
					MinTextSize = 14,
				}),
			}),
		}),
	})
end

local function getProductCards(sectionId, onProductActivated)
	local cards = {}

	for index, product in ipairs(ShopProductConfig.getSectionProducts(sectionId)) do
		local robloxProductId = ShopProductConfig.getRobloxProductId(product)

		cards[index] = {
			ShopProductId = product.ShopProductId,
			RobloxProductId = robloxProductId,
			Name = product.DisplayName,
			Detail = getProductDetail(product),
			AccentColor = getProductAccentColor(product),
			ActionText = if robloxProductId ~= nil and onProductActivated ~= nil then "Buy" else "Soon",
			OnActivated = createProductActivatedHandler(product, onProductActivated),
		}
	end

	return cards
end

function ShopOverlay.create(props)
	local resolvedProps = props or {}
	local snapshot = resolvedProps.Snapshot
	local onProductActivated = resolvedProps.OnProductActivated
	local onBuyPotion = resolvedProps.OnBuyPotion
	local onUsePotion = resolvedProps.OnUsePotion
	local gemSection = ShopProductConfig.getSection(ShopProductConfig.SectionIds.GemPacks)

	return GameOverlay.create({
		BackgroundId = "RitualCore",
		CloseButtonSize = 132,
		CloseIconSize = 110,
		DesignContentSize = DESIGN_CONTENT_SIZE,
		OnClose = resolvedProps.OnClose,
		Size = resolvedProps.Size or OVERLAY_SIZE,
		Title = "Shop",
		TitleTextSize = 58,
		TitleWidth = 260,
		ViewportSize = resolvedProps.ViewportSize,
		ZIndex = resolvedProps.ZIndex,
		Children = {
			Balance = createBalancePanel(snapshot),
			GemTitle = createSectionTitle((gemSection and gemSection.DisplayName) or "Gems", 102),
			GemDivider = createDivider(136),
			Gems = createCardRow(getProductCards(ShopProductConfig.SectionIds.GemPacks, onProductActivated), 154),
			OfferTitle = createSectionTitle("Potions", 286),
			OfferDivider = createDivider(320),
			Offers = createPotionRow(snapshot, onBuyPotion, onUsePotion, 338),
		},
	})
end

return ShopOverlay
