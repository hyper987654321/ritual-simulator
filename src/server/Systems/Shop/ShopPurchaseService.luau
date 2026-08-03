local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local ShopProductConfig = require(Config:WaitForChild("ShopProductConfig"))
local PlayerStateService = require(script.Parent.Parent:WaitForChild("Player"):WaitForChild("PlayerStateService"))

local ShopPurchaseService = {}

local PROFILE_LOAD_TIMEOUT_SECONDS = 10

local hasStarted = false

local function warnCatalogIssues()
	local issues = ShopProductConfig.getCatalogIssues()

	for _, issue in ipairs(issues) do
		warn("[ShopPurchaseService] Shop product catalog issue:", issue.Code, issue.ShopProductId or issue.SectionId or "")
	end

	return #issues == 0
end

local function getReceiptProduct(receiptInfo)
	if typeof(receiptInfo) ~= "table" then
		return nil
	end

	return ShopProductConfig.getProductByRobloxProductId(receiptInfo.ProductId)
end

local function getReceiptPlayer(receiptInfo)
	if typeof(receiptInfo) ~= "table" or typeof(receiptInfo.PlayerId) ~= "number" then
		return nil
	end

	return Players:GetPlayerByUserId(receiptInfo.PlayerId)
end

local function processReceipt(receiptInfo)
	local product = getReceiptProduct(receiptInfo)

	if product == nil then
		warn("[ShopPurchaseService] Unrecognized or duplicate developer product receipt.")

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = getReceiptPlayer(receiptInfo)

	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if PlayerStateService.waitForProfile(player, PROFILE_LOAD_TIMEOUT_SECONDS) == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, result = pcall(function()
		return PlayerStateService.withProfileLock(player, function()
			return PlayerStateService.processShopReceipt(player, receiptInfo, product)
		end)
	end)

	if not success or result == nil or result.Ok ~= true then
		local reason = if typeof(result) == "table" then result.Reason else result
		warn("[ShopPurchaseService] Failed to process developer product receipt:", reason)

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopPurchaseService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	warnCatalogIssues()

	MarketplaceService.ProcessReceipt = processReceipt
end

return ShopPurchaseService
