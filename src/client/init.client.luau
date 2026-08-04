local Systems = script:WaitForChild("Systems")

local RitualStoneVisualController = require(Systems:WaitForChild("Ritual"):WaitForChild("RitualStoneVisualController"))
local HudController = require(Systems:WaitForChild("UI"):WaitForChild("HudController"))
local ReplicatedPlayerVisualController = require(Systems:WaitForChild("World"):WaitForChild("ReplicatedPlayerVisualController"))
local WorldController = require(Systems:WaitForChild("World"):WaitForChild("WorldController"))
local ProductPurchaseController = require(Systems:WaitForChild("Shop"):WaitForChild("ProductPurchaseController"))

WorldController.start()
ProductPurchaseController.start()
RitualStoneVisualController.start()
ReplicatedPlayerVisualController.start()
HudController.start()
