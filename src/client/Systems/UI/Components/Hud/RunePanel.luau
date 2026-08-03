local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")

local NumberFormatter = require(Util:WaitForChild("NumberFormatter"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))
local ZoneConfig = require(Config:WaitForChild("ZoneConfig"))

local CommonComponents = script.Parent.Parent:WaitForChild("Common")
local HudPrimitives = require(CommonComponents:WaitForChild("HudPrimitives"))

local RunePanel = {}

local function createRuneRows(snapshot, buyRune)
	local rows = {}
	local runesUnlocked = snapshot.RuneUnlock.IsUnlocked

	if not runesUnlocked then
		local requiredZone = ZoneConfig.getZone(snapshot.RuneUnlock.RequiredZone)
		local requiredZoneName = "Zone " .. tostring(snapshot.RuneUnlock.RequiredZone)

		if requiredZone ~= nil then
			requiredZoneName = requiredZone.DisplayName
		end

		rows.Locked = HudPrimitives.createLabel(
			string.format(
				"Runes unlock after %d Rebirth and reaching %s again.",
				snapshot.RuneUnlock.RequiredRebirths,
				requiredZoneName
			),
			{
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 44),
				TextColor3 = Color3.fromRGB(185, 180, 212),
				TextSize = 13,
				TextWrapped = true,
			}
		)

		return rows
	end

	for index, runeInfo in ipairs(snapshot.Runes) do
		local runeId = runeInfo.RuneId
		local canBuy = buyRune ~= nil and not runeInfo.IsMaxed and snapshot.Essence >= runeInfo.NextCost
		local actionText = if runeInfo.IsMaxed then "Max" else NumberFormatter.compact(runeInfo.NextCost)

		rows["Rune" .. tostring(index)] = React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(31, 30, 43),
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 50),
		}, {
			Corner = HudPrimitives.createCorner(6),
			Title = HudPrimitives.createLabel(
				string.format("%s Lv %d/%d", runeInfo.DisplayName, runeInfo.Level, runeInfo.MaxLevel),
				{
					Font = UIThemeConfig.Font,
					Position = UDim2.fromOffset(10, 4),
					Size = UDim2.new(1, -104, 0, 22),
					TextSize = 13,
				}
			),
			Description = HudPrimitives.createLabel(runeInfo.Description, {
				Position = UDim2.fromOffset(10, 25),
				Size = UDim2.new(1, -104, 0, 18),
				TextColor3 = Color3.fromRGB(175, 170, 205),
				TextSize = 11,
			}),
			Action = HudPrimitives.createButton(actionText, {
				AnchorPoint = Vector2.new(1, 0.5),
				AutoButtonColor = canBuy,
				BackgroundColor3 = if canBuy then Color3.fromRGB(40, 151, 123) else Color3.fromRGB(55, 52, 72),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(86, 30),
				TextColor3 = if canBuy then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(166, 160, 188),
				TextSize = 12,
				[React.Event.Activated] = if canBuy then function()
					buyRune(runeId)
				end else nil,
			}),
		})
	end

	return rows
end

function RunePanel.create(props)
	local resolvedProps = props or {}
	local snapshot = resolvedProps.Snapshot

	if snapshot == nil then
		return nil
	end

	return HudPrimitives.createPanel({
		Position = UDim2.fromOffset(392, 18),
		Size = UDim2.fromOffset(292, 278),
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 12),
		}),
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Title = HudPrimitives.createLabel("Starter Runes", {
			Font = UIThemeConfig.Font,
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 16,
		}),
		Rows = React.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 1, -30),
		}, HudPrimitives.mergeProps({
			Layout = React.createElement("UIListLayout", {
				Padding = UDim.new(0, 7),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}, createRuneRows(snapshot, resolvedProps.OnBuyRune))),
	})
end

return RunePanel
