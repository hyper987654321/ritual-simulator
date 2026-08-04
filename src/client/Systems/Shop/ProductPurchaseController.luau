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
	Completed = "completed",
	Cancelled = "cancelled",
}

local promptFinishedConnection = nil
local inFlightProductId = nil

local function result(status, shopProductId)
	return {
		Ok = status == ProductPurchaseController.ResultStatus.Prompted,
		Status = status,
		ShopProductId = shopProductId,
	}
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
		return result(ProductPurchaseController.ResultStatus.Completed, shopProductId)
	end

	return result(ProductPurchaseController.ResultStatus.Cancelled, shopProductId)
end

function ProductPurchaseController.start()
	if promptFinishedConnection ~= nil then
		return
	end

	promptFinishedConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(onPromptFinished)
end

function ProductPurchaseController.promptProduct(shopProductId)
	if typeof(shopProductId) ~= "string" then
		return result(ProductPurchaseController.ResultStatus.LocalUnavailable)
	end

	if inFlightProductId ~= nil then
		return result(ProductPurchaseController.ResultStatus.Busy, shopProductId)
	end

	local product = ShopProductConfig.getProduct(shopProductId)
	local robloxProductId = ShopProductConfig.getRobloxProductId(product)

	if product == nil or robloxProductId == nil then
		return result(ProductPurchaseController.ResultStatus.LocalUnavailable, shopProductId)
	end

	ProductPurchaseController.start()
	inFlightProductId = {
		ShopProductId = product.ShopProductId,
		RobloxProductId = robloxProductId,
	}

	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, robloxProductId)

	return result(ProductPurchaseController.ResultStatus.Prompted, product.ShopProductId)
end

function ProductPurchaseController.getInFlightProductId()
	if inFlightProductId == nil then
		return nil
	end

	return inFlightProductId.ShopProductId
end

function ProductPurchaseController.cleanup()
	if promptFinishedConnection ~= nil then
		promptFinishedConnection:Disconnect()
		promptFinishedConnection = nil
	end

	clearInFlight()
end

return ProductPurchaseController
