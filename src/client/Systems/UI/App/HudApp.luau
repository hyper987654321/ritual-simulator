local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local TutorialConfig = require(Config:WaitForChild("TutorialConfig"))
local UIIconConfig = require(Config:WaitForChild("UIIconConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))

local Systems = script.Parent.Parent.Parent
local ClientUiSignals = require(Systems:WaitForChild("State"):WaitForChild("ClientUiSignals"))
local ClientStateStore = require(Systems:WaitForChild("State"):WaitForChild("ClientStateStore"))
local ProductPurchaseController = require(Systems:WaitForChild("Shop"):WaitForChild("ProductPurchaseController"))

local Components = script.Parent.Parent:WaitForChild("Components")
local CommonComponents = Components:WaitForChild("Common")
local HudComponents = Components:WaitForChild("Hud")
local OverlayComponents = Components:WaitForChild("Overlays")

local AscensionOverlay = require(OverlayComponents:WaitForChild("AscensionOverlay"))
local HudIconBar = require(CommonComponents:WaitForChild("HudIconBar"))
local ActiveBoostsDisplay = require(HudComponents:WaitForChild("ActiveBoostsDisplay"))
local HudLayoutConfig = require(HudComponents:WaitForChild("HudLayoutConfig"))
local HudBottomNav = require(HudComponents:WaitForChild("HudBottomNav"))
local HudPrimitives = require(CommonComponents:WaitForChild("HudPrimitives"))
local PetInventoryOverlay = require(OverlayComponents:WaitForChild("PetInventoryOverlay"))
local RebirthOverlay = require(OverlayComponents:WaitForChild("RebirthOverlay"))
local RitualCoreOverlay = require(OverlayComponents:WaitForChild("RitualCoreOverlay"))
local RitualRushOverlay = require(OverlayComponents:WaitForChild("RitualRushOverlay"))
local RollScreenOverlay = require(HudComponents:WaitForChild("RollScreenOverlay"))
local RunePanel = require(HudComponents:WaitForChild("RunePanel"))
local ShopOverlay = require(OverlayComponents:WaitForChild("ShopOverlay"))
local TeleportOverlay = require(OverlayComponents:WaitForChild("TeleportOverlay"))
local TutorialOverlay = require(HudComponents:WaitForChild("TutorialOverlay"))
local GoalChip = require(HudComponents:WaitForChild("GoalChip"))
local NotificationStack = require(HudComponents:WaitForChild("NotificationStack"))
local DailyRewardOverlay = require(OverlayComponents:WaitForChild("DailyRewardOverlay"))
local AwayRewardOverlay = require(OverlayComponents:WaitForChild("AwayRewardOverlay"))
local RetentionOverlay = require(OverlayComponents:WaitForChild("RetentionOverlay"))
local LeaderboardOverlay = require(OverlayComponents:WaitForChild("LeaderboardOverlay"))
local SocialOverlay = require(OverlayComponents:WaitForChild("SocialOverlay"))

local Hooks = script.Parent.Parent:WaitForChild("Hooks")
local useRollActions = require(Hooks:WaitForChild("useRollActions"))
local useViewportSize = require(Hooks:WaitForChild("useViewportSize"))

local PET_INVENTORY_OVERLAY_ID = "PetInventory"
local SHOP_OVERLAY_ID = "Shop"
local RITUAL_CORE_OVERLAY_ID = "RitualCore"
local RITUAL_RUSH_OVERLAY_ID = "RitualRush"
local REBIRTH_OVERLAY_ID = "Rebirth"
local ASCENSION_OVERLAY_ID = "Ascension"
local TELEPORT_OVERLAY_ID = "Teleport"
local DAILY_OVERLAY_ID = "DailyReward"
local AWAY_OVERLAY_ID = "AwayReward"
local RETENTION_OVERLAY_ID = "Retention"
local LEADERBOARD_OVERLAY_ID = "Leaderboard"
local SOCIAL_OVERLAY_ID = "Social"

local player = Players.LocalPlayer

local function createCurrencyIcon(iconColor)
	return React.createElement("ImageLabel", {
		Active = false,
		BackgroundTransparency = 1,
		Image = UIIconConfig.getIcon("Essence") or "",
		ImageColor3 = iconColor,
		LayoutOrder = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(HudLayoutConfig.CurrencyIconSize, HudLayoutConfig.CurrencyIconSize),
		ZIndex = 59,
	})
end

local function createCurrencyRow(iconColor, textColor, valueText, layoutOrder)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, HudLayoutConfig.CurrencyRowHeight),
		ZIndex = 58,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, HudLayoutConfig.CurrencyDisplayGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Icon = createCurrencyIcon(iconColor),
		Value = HudPrimitives.createLabel(valueText, {
			Font = UIThemeConfig.Font,
			LayoutOrder = 2,
			Size = UDim2.new(1, -HudLayoutConfig.CurrencyIconSize - HudLayoutConfig.CurrencyDisplayGap, 1, 0),
			TextColor3 = textColor or Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextSize = HudLayoutConfig.CurrencyTextSize,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 59,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = HudLayoutConfig.CurrencyTextSize,
				MinTextSize = HudLayoutConfig.CurrencyMinTextSize,
			}),
		}),
	})
end

local function getEssenceCapacityText(snapshot)
	local stoneStats = if typeof(snapshot.StoneStats) == "table" then snapshot.StoneStats else {}
	local capacity = if typeof(stoneStats.Capacity) == "number" then stoneStats.Capacity else 0

	return string.format(
		"%s / %s",
		NumberFormatter.compact(snapshot.Essence or 0),
		NumberFormatter.compact(capacity)
	)
end

local function createCurrencyDisplay(snapshot, scale)
	return React.createElement("Frame", {
		AnchorPoint = HudLayoutConfig.CurrencyDisplayAnchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = HudLayoutConfig.CurrencyDisplayPosition,
		Size = HudLayoutConfig.CurrencyDisplaySize,
		ZIndex = 58,
	}, {
		Scale = React.createElement("UIScale", {
			Scale = scale or 1,
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, HudLayoutConfig.CurrencyRowGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Essence = createCurrencyRow(nil, nil, getEssenceCapacityText(snapshot), 1),
		RitualGems = createCurrencyRow(
			Color3.fromRGB(255, 74, 214),
			Color3.fromRGB(255, 218, 92),
			NumberFormatter.compact(snapshot.RitualGems or 0),
			2
		),
	})
end

local function createStatsPanel(snapshot, zoneName)
	local essenceText = string.format(
		"%s / %s",
		NumberFormatter.compact(snapshot.Essence),
		NumberFormatter.compact(snapshot.StoneStats.Capacity)
	)

	return HudPrimitives.createPanel({
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(260, 218),
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 12),
		}),
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Title = HudPrimitives.createLabel("Ritual Core", {
			Font = UIThemeConfig.Font,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 26),
			TextSize = 20,
		}),
		Zone = HudPrimitives.createStatRow("Zone", zoneName, 2),
		Essence = HudPrimitives.createStatRow("Essence", essenceText, 3),
		Power = HudPrimitives.createStatRow("Ritual Power", NumberFormatter.compact(snapshot.RitualPower), 4),
		Luck = HudPrimitives.createStatRow("Luck", NumberFormatter.decimal(snapshot.StoneStats.Luck, 2), 5),
		Speed = HudPrimitives.createStatRow(
			"Roll Opening Speed",
			RollScreenOverlay.getRollAnimationPaceText(RollScreenOverlay.getRollAnimationDurationScale(snapshot)),
			6
		),
		Rolls = HudPrimitives.createStatRow("Rolls", NumberFormatter.compact(snapshot.Rolls), 7),
	})
end

local function createCompactStatus(snapshot, zoneName)
	local stoneStats = if typeof(snapshot.StoneStats) == "table" then snapshot.StoneStats else {}
	local capacity = stoneStats.Capacity or 0
	local essenceText = string.format("%s / %s", NumberFormatter.compact(snapshot.Essence or 0), NumberFormatter.compact(capacity))

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(19, 16, 31),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(350, 62),
		ZIndex = 58,
	}, {
		Corner = HudPrimitives.createCorner(14),
		Stroke = HudPrimitives.createStroke(Color3.fromRGB(111, 86, 176), 0.35),
		Zone = HudPrimitives.createLabel(zoneName:upper(), {
			Position = UDim2.fromOffset(14, 7),
			Size = UDim2.fromOffset(120, 16),
			TextColor3 = Color3.fromRGB(106, 224, 239),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 59,
		}),
		Essence = HudPrimitives.createLabel("ESSENCE  " .. essenceText, {
			Position = UDim2.fromOffset(14, 25),
			Size = UDim2.fromOffset(205, 27),
			TextColor3 = Color3.fromRGB(231, 226, 250),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 59,
		}),
		Gems = HudPrimitives.createLabel("✦  " .. NumberFormatter.compact(snapshot.RitualGems or 0), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 25),
			Size = UDim2.fromOffset(105, 27),
			TextColor3 = Color3.fromRGB(255, 207, 104),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 59,
		}),
	})
end

local function createRuneHint(snapshot)
	local runeFocus = snapshot.RuneFocus
	if typeof(runeFocus) ~= "table" then
		return nil
	end

	local text = if runeFocus.IsUnlocked ~= true
		then string.format("Rune Focus unlocks at Zone %d", runeFocus.RequiredZone or 3)
		elseif runeFocus.ActiveId == nil then "Rune Focus available — choose a path in Ritual"
		else "Rune Focus charges from crystal breaks"

	return HudPrimitives.createLabel("ᛉ  " .. text, {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(27, 23, 47),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.fromOffset(330, 28),
		TextColor3 = Color3.fromRGB(177, 221, 237),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 57,
	}, { Corner = HudPrimitives.createCorner(8) })
end

local function HudApp()
	local snapshot, setSnapshot = React.useState(ClientStateStore.getSnapshot())
	local feedback, setFeedback = React.useState(ClientStateStore.getFeedback())
	local purchaseStatus, setPurchaseStatus = React.useState(ProductPurchaseController.getLastResult())
	local menuOpen, setMenuOpen = React.useState(false)
	local rollActions = useRollActions({
		BuildRollRouletteTrack = RollScreenOverlay.buildRollRouletteTrack,
		GetRollAnimationDurationScale = RollScreenOverlay.getRollAnimationDurationScale,
		GetRollOpeningDurationFromScale = RollScreenOverlay.getRollOpeningDurationFromScale,
		GetRollPreviewData = RollScreenOverlay.getRollPreviewData,
		GetRollRouletteTargetOffset = RollScreenOverlay.getRollRouletteTargetOffset,
		GetSnapshot = ClientStateStore.getSnapshot,
		ProgressionEpoch = if typeof(snapshot) == "table" then snapshot.ProgressionEpoch else nil,
		RollPet = ClientStateStore.rollPet,
	})
	local autoRollEnabled = rollActions.AutoRollEnabled
	local rollAnimation = rollActions.RollAnimation
	local rollScreenOpen, setRollScreenOpen = React.useState(false)
	local hideRollAnimation, setHideRollAnimation = React.useState(false)
	local activeOverlay, setActiveOverlay = React.useState(nil)
	local runServerAction
	local tutorialStarted, setTutorialStarted = React.useState(false)
	local currentTutorialStepId = TutorialOverlay.getCurrentStepId(snapshot)
	local viewportSize = useViewportSize(HudLayoutConfig.DefaultViewportSize)

	React.useEffect(function()
		return ClientStateStore.subscribe(function(nextSnapshot)
			setSnapshot(nextSnapshot)
		end)
	end, {})

	React.useEffect(function()
		return ClientStateStore.subscribeFeedback(function(nextFeedback)
			setFeedback(nextFeedback)
		end)
	end, {})

	React.useEffect(function()
		return ProductPurchaseController.subscribe(function(result)
			setPurchaseStatus(result)
		end)
	end, {})

	React.useEffect(function()
		local connection = ClientUiSignals.onAscensionRequested(function()
			setRollScreenOpen(false)
			setHideRollAnimation(false)
			setActiveOverlay(ASCENSION_OVERLAY_ID)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		if currentTutorialStepId ~= TutorialConfig.StepIds.Intro or tutorialStarted then
			return
		end

		local cancelled = false

		task.spawn(function()
			local character = player.Character
			local startedAt = os.clock()

			while character == nil and not cancelled and os.clock() - startedAt < TutorialOverlay.MovementFallbackSeconds do
				task.wait(0.1)
				character = player.Character
			end

			local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil

			while humanoid == nil and character ~= nil and not cancelled and os.clock() - startedAt < TutorialOverlay.MovementFallbackSeconds do
				task.wait(0.1)
				humanoid = character:FindFirstChildOfClass("Humanoid")
			end

			local movementWaitStartedAt = os.clock()

			while not cancelled and player.Parent ~= nil do
				if humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.05 then
					break
				end

				if os.clock() - movementWaitStartedAt >= TutorialOverlay.MovementFallbackSeconds then
					break
				end

				task.wait(0.1)
			end

			if not cancelled then
				setTutorialStarted(true)
			end
		end)

		return function()
			cancelled = true
		end
	end, { currentTutorialStepId, tutorialStarted })

	React.useEffect(function()
		if currentTutorialStepId ~= TutorialConfig.StepIds.Intro or not tutorialStarted then
			return
		end

		local cancelled = false

		task.spawn(function()
			task.wait(TutorialOverlay.IntroSeconds)

			if cancelled then
				return
			end

			ClientStateStore.completeTutorialStep(TutorialConfig.StepIds.Intro)
		end)

		return function()
			cancelled = true
		end
	end, { currentTutorialStepId, tutorialStarted })

	local function rollPet()
		rollActions.RollPet()
	end

	local function activateRollScreen()
		setActiveOverlay(nil)
		setRollScreenOpen(true)
		setHideRollAnimation(false)

		rollPet()
	end

	local function hideRollScreen()
		setHideRollAnimation(true)
		setRollScreenOpen(false)
	end

	local function closeOverlay()
		setActiveOverlay(nil)
	end

	local function togglePetInventoryOverlay()
		setActiveOverlay(function(currentOverlay)
			return if currentOverlay == PET_INVENTORY_OVERLAY_ID then nil else PET_INVENTORY_OVERLAY_ID
		end)
	end

	local function toggleShopOverlay()
		setActiveOverlay(function(currentOverlay)
			return if currentOverlay == SHOP_OVERLAY_ID then nil else SHOP_OVERLAY_ID
		end)
	end

	local function toggleRitualCoreOverlay()
		setActiveOverlay(function(currentOverlay)
			return if currentOverlay == RITUAL_CORE_OVERLAY_ID then nil else RITUAL_CORE_OVERLAY_ID
		end)
	end

	local function toggleRitualRushOverlay()
		setActiveOverlay(function(currentOverlay)
			return if currentOverlay == RITUAL_RUSH_OVERLAY_ID then nil else RITUAL_RUSH_OVERLAY_ID
		end)
	end

	local function toggleRebirthOverlay()
		setActiveOverlay(function(currentOverlay)
			return if currentOverlay == REBIRTH_OVERLAY_ID then nil else REBIRTH_OVERLAY_ID
		end)
	end

	local function toggleTeleportOverlay()
		setActiveOverlay(function(currentOverlay)
			return if currentOverlay == TELEPORT_OVERLAY_ID then nil else TELEPORT_OVERLAY_ID
		end)
	end

	local function toggleRetentionOverlay()
		setActiveOverlay(function(currentOverlay) return if currentOverlay == RETENTION_OVERLAY_ID then nil else RETENTION_OVERLAY_ID end)
	end

	local function openDailyOverlay()
		setMenuOpen(false)
		setActiveOverlay(DAILY_OVERLAY_ID)
	end

	local function toggleLeaderboardOverlay()
		setActiveOverlay(function(currentOverlay) return if currentOverlay == LEADERBOARD_OVERLAY_ID then nil else LEADERBOARD_OVERLAY_ID end)
	end

	local function toggleSocialOverlay()
		setActiveOverlay(function(currentOverlay)
			return if currentOverlay == SOCIAL_OVERLAY_ID then nil else SOCIAL_OVERLAY_ID
		end)
	end

	local function toggleMoreMenu()
		setMenuOpen(function(currentMenuOpen)
			return not currentMenuOpen
		end)
	end

	local function claimRetention(retentionId)
		runServerAction(function() return ClientStateStore.claimRetention(retentionId) end)
	end

	runServerAction = function(action)
		task.spawn(function()
			local ok, result = pcall(action)

			if not ok then
				warn(result)
			end
		end)
	end

	local function buyUpgrade(upgradeId)
		runServerAction(function()
			return ClientStateStore.buyStoneUpgrade(upgradeId)
		end)
	end

	local function setAutoCapacity(enabled)
		runServerAction(function()
			return ClientStateStore.setAutoCapacity(enabled)
		end)
	end

	local function rebirth()
		runServerAction(function()
			return ClientStateStore.rebirth()
		end)
	end

	local function ascend()
		runServerAction(function()
			local result = ClientStateStore.ascend()

			if result ~= nil and result.Ok ~= false then
				setActiveOverlay(nil)
			end

			return result
		end)
	end

	local function buyAscensionUpgrade(upgradeId)
		runServerAction(function()
			return ClientStateStore.buyAscensionUpgrade(upgradeId)
		end)
	end

	local function selectZone(zoneId)
		runServerAction(function()
			return ClientStateStore.selectZone(zoneId)
		end)
	end

	local function claimRitualRushReward(milestoneId)
		local ritualRush = if typeof(snapshot) == "table" and typeof(snapshot.RitualRush) == "table"
			then snapshot.RitualRush
			else nil
		local selectedTrack = nil

		if ritualRush ~= nil and typeof(ritualRush.Milestones) == "table" then
			for _, milestone in ipairs(ritualRush.Milestones) do
				if typeof(milestone) == "table" and milestone.MilestoneId == milestoneId then
					if milestone.IsFreeClaimed ~= true then
						selectedTrack = "free"
					elseif ritualRush.PremiumUnlocked == true and milestone.IsPremiumClaimed ~= true then
						selectedTrack = "premium"
					end

					break
				end
			end
		end

		if selectedTrack == nil then
			return
		end

		runServerAction(function()
			return ClientStateStore.claimRitualRushReward(milestoneId, selectedTrack)
		end)
	end

	local function usePotion(potionId)
		runServerAction(function()
			return ClientStateStore.usePotion(potionId)
		end)
	end

	local function buyPotionWithGems(potionId)
		runServerAction(function()
			return ClientStateStore.buyPotionWithGems(potionId)
		end)
	end

	local function promptProduct(shopProductId)
		runServerAction(function() return ProductPurchaseController.promptProduct(shopProductId) end)
	end

	local function selectRuneFocus(focusId)
		runServerAction(function()
			return ClientStateStore.selectRuneFocus(focusId)
		end)
	end

	local function skipTutorialStep(stepId)
		runServerAction(function()
			return ClientStateStore.completeTutorialStep(stepId, TutorialConfig.CompletionModes.Skip)
		end)
	end

	React.useEffect(function()
		if activeOverlay ~= nil or snapshot == nil then return end
		if snapshot.AwayRewards and snapshot.AwayRewards.HasPendingClaim == true then
			setActiveOverlay(AWAY_OVERLAY_ID)
		elseif snapshot.DailyRewards and snapshot.DailyRewards.CanClaim == true then
			setActiveOverlay(DAILY_OVERLAY_ID)
		end
	end, { snapshot and snapshot.AwayRewards and snapshot.AwayRewards.HasPendingClaim, snapshot and snapshot.DailyRewards and snapshot.DailyRewards.CanClaim, activeOverlay })

	if snapshot == nil then
		return React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Loading = HudPrimitives.createLabel("Loading Ritual Core...", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Font = UIThemeConfig.Font,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(260, 40),
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		})
	end

	local zone = ZoneConfig.getZone(snapshot.CurrentZone)
	local zoneName = if zone ~= nil then zone.DisplayName else "Unknown Zone"
	local tutorialStep = TutorialOverlay.getStep(snapshot, tutorialStarted)
	local hudControlScale = HudIconBar.getControlScale(viewportSize, HudLayoutConfig.DefaultViewportSize, 4)
	local rollScreenScale = RollScreenOverlay.getScale(viewportSize)
	local rollScreenVisible = rollScreenOpen and not hideRollAnimation
	local bottomNavigation = if not rollScreenVisible then HudBottomNav.create({
			MenuOpen = menuOpen,
			OnToggleMore = toggleMoreMenu,
			ViewportSize = viewportSize,
			OnPets = togglePetInventoryOverlay,
			OnRoll = activateRollScreen,
			OnRitual = toggleRitualCoreOverlay,
			OnZones = toggleTeleportOverlay,
			OnShop = toggleShopOverlay,
			OnDaily = openDailyOverlay,
			OnRitualRush = toggleRitualRushOverlay,
			OnRebirth = toggleRebirthOverlay,
			OnRetention = toggleRetentionOverlay,
			OnLeaderboard = toggleLeaderboardOverlay,
			OnSocial = toggleSocialOverlay,
		}) else nil

	local function claimDaily(dayIndex)
		runServerAction(function() return ClientStateStore.claimDailyReward(dayIndex) end)
	end

	local function claimAway(sequence)
		runServerAction(function() return ClientStateStore.claimAwayRewards(sequence) end)
	end

	local function dismissAway(sequence)
		runServerAction(function() return ClientStateStore.dismissAwayRewards(sequence) end)
	end

	local function updateGuidance(values)
		runServerAction(function() return ClientStateStore.updateGuidance(values) end)
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		RollScreenScrim = if rollScreenVisible then React.createElement("Frame", {
			Active = false,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = RollScreenOverlay.ScrimTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
		}) else nil,

		StatusBar = if not rollScreenVisible then createCompactStatus(snapshot, zoneName) else nil,

		GoalChip = if not rollScreenVisible then GoalChip.create({
			Snapshot = snapshot,
			ViewportSize = viewportSize,
			OnUpdateGuidance = updateGuidance,
		}) else nil,

		Notifications = if not rollScreenVisible then NotificationStack.create({ Feedback = feedback }) else nil,

		RuneHint = if not rollScreenVisible then createRuneHint(snapshot) else nil,

		ActiveBoostsDisplay = if not rollScreenVisible then ActiveBoostsDisplay.create({
			ActiveBoosts = snapshot.ActiveBoosts,
			Scale = hudControlScale,
		}) else nil,

		ShopOverlay = if activeOverlay == SHOP_OVERLAY_ID and not rollScreenVisible
			then ShopOverlay.create({
				OnProductActivated = promptProduct,
				PurchaseStatus = purchaseStatus,
				Snapshot = snapshot,
				OnBuyPotion = buyPotionWithGems,
				OnClose = closeOverlay,
				OnUsePotion = usePotion,
				ViewportSize = viewportSize,
			})
			else nil,

		PetInventoryOverlay = if activeOverlay == PET_INVENTORY_OVERLAY_ID and not rollScreenVisible
			then PetInventoryOverlay.create({
				OnEquipBest = function() runServerAction(ClientStateStore.equipBestPets) end,
				OnSetEquippedCount = function(petId, count) runServerAction(function() return ClientStateStore.setPetEquippedCount(petId, count) end) end,
				OnUnequip = function(petId) runServerAction(function() return ClientStateStore.unequipPet(petId) end) end,
				Snapshot = snapshot,
				OnClose = closeOverlay,
				ViewportSize = viewportSize,
			})
			else nil,

		RitualCoreOverlay = if activeOverlay == RITUAL_CORE_OVERLAY_ID and not rollScreenVisible
			then RitualCoreOverlay.create({
				Snapshot = snapshot,
				OnClose = closeOverlay,
				OnBuyUpgrade = buyUpgrade,
				OnSetAutoCapacity = setAutoCapacity,
				ViewportSize = viewportSize,
			})
			else nil,

		RitualRushOverlay = if activeOverlay == RITUAL_RUSH_OVERLAY_ID and not rollScreenVisible
			then RitualRushOverlay.create({
				Snapshot = snapshot,
				OnClaimReward = claimRitualRushReward,
				OnClose = closeOverlay,
				ViewportSize = viewportSize,
			})
			else nil,

		RebirthOverlay = if activeOverlay == REBIRTH_OVERLAY_ID and not rollScreenVisible
			then RebirthOverlay.create({
				Snapshot = snapshot,
				OnClose = closeOverlay,
				OnRebirth = rebirth,
				ViewportSize = viewportSize,
			})
			else nil,

		AscensionOverlay = if activeOverlay == ASCENSION_OVERLAY_ID and not rollScreenVisible
			then AscensionOverlay.create({
				Snapshot = snapshot,
				OnAscend = ascend,
				OnBuyAscensionUpgrade = buyAscensionUpgrade,
				OnClose = closeOverlay,
				ViewportSize = viewportSize,
			})
			else nil,

		TeleportOverlay = if activeOverlay == TELEPORT_OVERLAY_ID and not rollScreenVisible
			then TeleportOverlay.create({
				Snapshot = snapshot,
				OnClose = closeOverlay,
				OnSelectZone = selectZone,
				ViewportSize = viewportSize,
			})
			else nil,

		AwayRewardOverlay = if activeOverlay == AWAY_OVERLAY_ID and not rollScreenVisible
			then AwayRewardOverlay.create({ Snapshot = snapshot, OnClaim = claimAway, OnDismiss = dismissAway, OnClose = closeOverlay, ViewportSize = viewportSize })
			else nil,

		DailyRewardOverlay = if activeOverlay == DAILY_OVERLAY_ID and not rollScreenVisible
			then DailyRewardOverlay.create({ Snapshot = snapshot, OnClaim = claimDaily, OnClose = closeOverlay, ViewportSize = viewportSize })
			else nil,

		RetentionOverlay = if activeOverlay == RETENTION_OVERLAY_ID and not rollScreenVisible
			then RetentionOverlay.create({ Snapshot = snapshot, OnClaim = claimRetention, OnClose = closeOverlay, ViewportSize = viewportSize }) else nil,

		LeaderboardOverlay = if activeOverlay == LEADERBOARD_OVERLAY_ID and not rollScreenVisible
			then LeaderboardOverlay.create({ Snapshot = snapshot, OnClose = closeOverlay, ViewportSize = viewportSize }) else nil,

		SocialOverlay = if activeOverlay == SOCIAL_OVERLAY_ID and not rollScreenVisible
			then SocialOverlay.create({ Snapshot = snapshot, OnClose = closeOverlay, ViewportSize = viewportSize }) else nil,

		RollScreenContent = if rollScreenVisible then RollScreenOverlay.create({
			AutoRollEnabled = autoRollEnabled,
			OnHide = hideRollScreen,
			OnToggleAutoRoll = rollActions.ToggleAutoRoll,
			RollAnimation = rollAnimation,
			Scale = rollScreenScale,
		}) else nil,

		BottomNavigation = bottomNavigation,

		TutorialOverlay = nil,
	})
end

return HudApp
