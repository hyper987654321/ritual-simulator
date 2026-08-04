local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ShopProductConfig = require(Config:WaitForChild("ShopProductConfig"))

local ProductPurchaseController = {}

ProductPurchaseController.ResultStatus = {
	Prompted = "prompted",
	Busy = "busy",
	LocalUnavailable = "local_unavailable",
	PromptFailed = "prompt_failed",
	Completed = "completed",
	Cancelled = "cancelled",
}

local promptFinishedConnection = nil
local inFlightProductId = nil
local lastResult = nil
local resultSubscriber = nil

local function result(status, shopProductId)
	return {
		Ok = status == ProductPurchaseController.ResultStatus.Prompted,
		Status = status,
		ShopProductId = shopProductId,
	}
end

local function publishResult(purchaseResult)
	lastResult = purchaseResult

	local subscriber = resultSubscriber

	if subscriber ~= nil then
		pcall(subscriber, purchaseResult)
	end

	return purchaseResult
end

local function isLuckProduct(product)
	if typeof(product) ~= "table" then
		return false
	end

	if product.ShopProductId == "boost_luck_2x_15m" then
		return true
	end

	local grant = product.Grant
	local boost = if typeof(grant) == "table" then grant.Boost else nil

	return typeof(boost) == "table"
		and product.ProductType == ShopProductConfig.ProductTypes.Boost
		and boost.BoostId == ShopProductConfig.BoostIds.LuckMultiplier
end

local function clearInFlight()
	inFlightProductId = nil
end

local function onPromptFinished(playerId, robloxProductId, isPurchased)
	local localPlayer = Players.LocalPlayer

	if localPlayer == nil or playerId ~= localPlayer.UserId then
		return
	end

	if inFlightProductId == nil or robloxProductId ~= inFlightProductId.RobloxProductId then
		return
	end

	local shopProductId = inFlightProductId.ShopProductId
	clearInFlight()

	-- A receipt is authoritative on the server. This only reports prompt state.
	if isPurchased then
		return publishResult(result(ProductPurchaseController.ResultStatus.Completed, shopProductId))
	end

	return publishResult(result(ProductPurchaseController.ResultStatus.Cancelled, shopProductId))
end

function ProductPurchaseController.start()
	if promptFinishedConnection ~= nil then
		return
	end

	promptFinishedConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(onPromptFinished)
end

function ProductPurchaseController.promptProduct(shopProductId)
	if typeof(shopProductId) ~= "string" then
		return publishResult(result(ProductPurchaseController.ResultStatus.LocalUnavailable))
	end

	if inFlightProductId ~= nil then
		return publishResult(result(ProductPurchaseController.ResultStatus.Busy, shopProductId))
	end

	local product = ShopProductConfig.getProduct(shopProductId)
	local robloxProductId = ShopProductConfig.getRobloxProductId(product)

	if product == nil or robloxProductId == nil or isLuckProduct(product) then
		return publishResult(result(ProductPurchaseController.ResultStatus.LocalUnavailable, shopProductId))
	end

	local localPlayer = Players.LocalPlayer

	if localPlayer == nil then
		return publishResult(result(ProductPurchaseController.ResultStatus.LocalUnavailable, shopProductId))
	end

	ProductPurchaseController.start()
	inFlightProductId = {
		ShopProductId = product.ShopProductId,
		RobloxProductId = robloxProductId,
	}

	local promptSucceeded = pcall(function()
		MarketplaceService:PromptProductPurchase(localPlayer, robloxProductId)
	end)

	if not promptSucceeded then
		clearInFlight()

		return publishResult(result(ProductPurchaseController.ResultStatus.PromptFailed, product.ShopProductId))
	end

	return publishResult(result(ProductPurchaseController.ResultStatus.Prompted, product.ShopProductId))
end

function ProductPurchaseController.getInFlightProductId()
	if inFlightProductId == nil then
		return nil
	end

	return inFlightProductId.ShopProductId
end

function ProductPurchaseController.subscribe(callback)
	if typeof(callback) ~= "function" then
		return function() end
	end

	resultSubscriber = callback

	return function()
		if resultSubscriber == callback then
			resultSubscriber = nil
		end
	end
end

function ProductPurchaseController.getLastResult()
	return lastResult
end

function ProductPurchaseController.cleanup()
	if promptFinishedConnection ~= nil then
		promptFinishedConnection:Disconnect()
		promptFinishedConnection = nil
	end

	resultSubscriber = nil
	clearInFlight()
end

return ProductPurchaseController
