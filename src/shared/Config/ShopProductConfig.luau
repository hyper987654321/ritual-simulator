local BoostConfig = require(script.Parent:WaitForChild("BoostConfig"))

local ShopProductConfig = {}

ShopProductConfig.ProductTypes = {
	GemPack = "GemPack",
	RitualRushPremium = "RitualRushPremium",
	Boost = "Boost",
}

ShopProductConfig.BoostIds = BoostConfig.BoostIds

ShopProductConfig.SectionIds = {
	GemPacks = "GemPacks",
	Featured = "Featured",
}

ShopProductConfig.ProductOrder = {
	"gems_100",
	"gems_500",
	"gems_1500",
	"ritual_rush_premium",
	"boost_essence_2x_15m",
	"boost_luck_2x_15m",
}

ShopProductConfig.Products = {
	gems_100 = {
		ShopProductId = "gems_100",
		ProductType = ShopProductConfig.ProductTypes.GemPack,
		DisplayName = "100 Gems",
		Description = "100 Ritual Gems",
		RobloxProductId = 0,
		Grant = {
			RitualGems = 100,
		},
	},
	gems_500 = {
		ShopProductId = "gems_500",
		ProductType = ShopProductConfig.ProductTypes.GemPack,
		DisplayName = "500 Gems",
		Description = "500 Ritual Gems",
		RobloxProductId = 0,
		Grant = {
			RitualGems = 500,
		},
	},
	gems_1500 = {
		ShopProductId = "gems_1500",
		ProductType = ShopProductConfig.ProductTypes.GemPack,
		DisplayName = "1500 Gems",
		Description = "1500 Ritual Gems",
		RobloxProductId = 0,
		Grant = {
			RitualGems = 1500,
		},
	},
	ritual_rush_premium = {
		ShopProductId = "ritual_rush_premium",
		ProductType = ShopProductConfig.ProductTypes.RitualRushPremium,
		DisplayName = "Premium Rush",
		Description = "Second reward row",
		RobloxProductId = 0,
		Grant = {
			RitualRushPremium = true,
		},
	},
	boost_essence_2x_15m = {
		ShopProductId = "boost_essence_2x_15m",
		ProductType = ShopProductConfig.ProductTypes.Boost,
		DisplayName = "2x Essence",
		Description = "15 min boost",
		RobloxProductId = 0,
		Grant = {
			Boost = {
				BoostId = ShopProductConfig.BoostIds.EssenceMultiplier,
				Multiplier = 2,
				DurationSeconds = 15 * 60,
			},
		},
	},
	boost_luck_2x_15m = {
		ShopProductId = "boost_luck_2x_15m",
		ProductType = ShopProductConfig.ProductTypes.Boost,
		DisplayName = "Lucky Ritual",
		Description = "15 min boost",
		RobloxProductId = 0,
		Grant = {
			Boost = {
				BoostId = ShopProductConfig.BoostIds.LuckMultiplier,
				Multiplier = 2,
				DurationSeconds = 15 * 60,
			},
		},
	},
}

ShopProductConfig.SectionOrder = {
	ShopProductConfig.SectionIds.GemPacks,
	ShopProductConfig.SectionIds.Featured,
}

ShopProductConfig.Sections = {
	[ShopProductConfig.SectionIds.GemPacks] = {
		SectionId = ShopProductConfig.SectionIds.GemPacks,
		DisplayName = "Gems",
		ProductIds = {
			"gems_100",
			"gems_500",
			"gems_1500",
		},
	},
	[ShopProductConfig.SectionIds.Featured] = {
		SectionId = ShopProductConfig.SectionIds.Featured,
		DisplayName = "Featured",
		ProductIds = {
			"ritual_rush_premium",
			"boost_essence_2x_15m",
			"boost_luck_2x_15m",
		},
	},
}

local function cloneValue(value)
	if typeof(value) ~= "table" then
		return value
	end

	local clone = {}

	for key, nestedValue in pairs(value) do
		clone[key] = cloneValue(nestedValue)
	end

	return clone
end

local function getPositiveInteger(value)
	if typeof(value) ~= "number" then
		return nil
	end

	local integer = math.floor(value)

	if integer <= 0 or integer ~= value then
		return nil
	end

	return integer
end

local function cloneProduct(product)
	if product == nil then
		return nil
	end

	return cloneValue(product)
end

local function cloneSection(section)
	if section == nil then
		return nil
	end

	return cloneValue(section)
end

local function getProductRobloxProductId(product)
	if typeof(product) ~= "table" then
		return nil
	end

	return getPositiveInteger(product.RobloxProductId)
end

function ShopProductConfig.getProduct(shopProductId)
	if typeof(shopProductId) ~= "string" then
		return nil
	end

	return cloneProduct(ShopProductConfig.Products[shopProductId])
end

function ShopProductConfig.getProducts(productIds)
	local products = {}
	local resolvedProductIds = ShopProductConfig.ProductOrder

	if productIds ~= nil then
		if typeof(productIds) ~= "table" then
			return products
		end

		resolvedProductIds = productIds
	end

	for _, shopProductId in ipairs(resolvedProductIds) do
		local product = ShopProductConfig.getProduct(shopProductId)

		if product ~= nil then
			table.insert(products, product)
		end
	end

	return products
end

function ShopProductConfig.getSection(sectionId)
	if typeof(sectionId) ~= "string" then
		return nil
	end

	return cloneSection(ShopProductConfig.Sections[sectionId])
end

function ShopProductConfig.getSectionProducts(sectionId)
	local section = ShopProductConfig.getSection(sectionId)

	if section == nil then
		return {}
	end

	return ShopProductConfig.getProducts(section.ProductIds)
end

function ShopProductConfig.hasRobloxProductId(productOrShopProductId)
	return ShopProductConfig.getRobloxProductId(productOrShopProductId) ~= nil
end

function ShopProductConfig.getRobloxProductId(productOrShopProductId)
	local product = if typeof(productOrShopProductId) == "table"
		then productOrShopProductId
		else ShopProductConfig.getProduct(productOrShopProductId)
	local robloxProductId = getProductRobloxProductId(product)

	if robloxProductId == nil then
		return nil
	end

	local indexedProduct = ShopProductConfig.getProductByRobloxProductId(robloxProductId)

	if indexedProduct == nil or indexedProduct.ShopProductId ~= product.ShopProductId then
		return nil
	end

	return robloxProductId
end

function ShopProductConfig.getProductByRobloxProductId(robloxProductId)
	local safeProductId = getPositiveInteger(robloxProductId)

	if safeProductId == nil then
		return nil
	end

	local matchedProduct = nil

	for _, product in pairs(ShopProductConfig.Products) do
		if getProductRobloxProductId(product) == safeProductId then
			if matchedProduct ~= nil then
				return nil
			end

			matchedProduct = product
		end
	end

	return cloneProduct(matchedProduct)
end

function ShopProductConfig.getCatalogIssues()
	local issues = {}
	local productIdsByRobloxProductId = {}

	for shopProductId, product in pairs(ShopProductConfig.Products) do
		if typeof(product) ~= "table" then
			table.insert(issues, {
				Code = "InvalidProduct",
				ShopProductId = shopProductId,
			})
			continue
		end

		if product.ShopProductId ~= shopProductId then
			table.insert(issues, {
				Code = "MismatchedShopProductId",
				ExpectedShopProductId = shopProductId,
				ShopProductId = product.ShopProductId,
			})
		end

		local robloxProductId = getProductRobloxProductId(product)

		if robloxProductId ~= nil then
			local existingShopProductId = productIdsByRobloxProductId[robloxProductId]

			if existingShopProductId ~= nil then
				table.insert(issues, {
					Code = "DuplicateRobloxProductId",
					RobloxProductId = robloxProductId,
					ShopProductIds = {
						existingShopProductId,
						shopProductId,
					},
				})
			else
				productIdsByRobloxProductId[robloxProductId] = shopProductId
			end
		end
	end

	for _, shopProductId in ipairs(ShopProductConfig.ProductOrder) do
		if ShopProductConfig.Products[shopProductId] == nil then
			table.insert(issues, {
				Code = "UnknownOrderedProduct",
				ShopProductId = shopProductId,
			})
		end
	end

	for sectionId, section in pairs(ShopProductConfig.Sections) do
		if typeof(section) ~= "table" then
			table.insert(issues, {
				Code = "InvalidSection",
				SectionId = sectionId,
			})
			continue
		end

		if section.SectionId ~= sectionId then
			table.insert(issues, {
				Code = "MismatchedSectionId",
				ExpectedSectionId = sectionId,
				SectionId = section.SectionId,
			})
		end

		if typeof(section.ProductIds) ~= "table" then
			table.insert(issues, {
				Code = "InvalidSectionProductIds",
				SectionId = sectionId,
			})
			continue
		end

		for _, shopProductId in ipairs(section.ProductIds) do
			if ShopProductConfig.Products[shopProductId] == nil then
				table.insert(issues, {
					Code = "UnknownSectionProduct",
					SectionId = sectionId,
					ShopProductId = shopProductId,
				})
			end
		end
	end

	for _, sectionId in ipairs(ShopProductConfig.SectionOrder) do
		if ShopProductConfig.Sections[sectionId] == nil then
			table.insert(issues, {
				Code = "UnknownOrderedSection",
				SectionId = sectionId,
			})
		end
	end

	return issues
end

function ShopProductConfig.isCatalogValid()
	return #ShopProductConfig.getCatalogIssues() == 0
end

return ShopProductConfig
