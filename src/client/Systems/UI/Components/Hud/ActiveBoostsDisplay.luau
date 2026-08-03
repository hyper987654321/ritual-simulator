local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local BoostConfig = require(Config:WaitForChild("BoostConfig"))
local UIIconConfig = require(Config:WaitForChild("UIIconConfig"))
local UIThemeConfig = require(Config:WaitForChild("UIThemeConfig"))

local HudLayoutConfig = require(script.Parent:WaitForChild("HudLayoutConfig"))

local ActiveBoostsDisplay = {}

local ROW_WIDTH = HudLayoutConfig.CurrencyDisplaySize.X.Offset
local ROW_HEIGHT = 30
local ROW_GAP = 2
local ROW_ICON_SIZE = 26
local ROW_CONTENT_LEFT = 34
local ROW_CONTENT_RIGHT_PADDING = 0
local ROW_TIMER_WIDTH = 78
local ROW_Z_INDEX = 58

local BOOST_STYLES = {
	[BoostConfig.BoostIds.EssenceMultiplier] = {
		AccentColor = Color3.fromRGB(95, 245, 171),
		IconColor = Color3.fromRGB(95, 245, 171),
	},
	[BoostConfig.BoostIds.LuckMultiplier] = {
		AccentColor = Color3.fromRGB(255, 109, 205),
		IconColor = Color3.fromRGB(255, 109, 205),
	},
}

local function getCurrentUnixTime()
	return DateTime.now().UnixTimestamp
end

local function formatRemainingTime(remainingSeconds)
	local seconds = math.max(0, math.floor(remainingSeconds or 0))
	local minutes = math.floor(seconds / 60)
	local hours = math.floor(minutes / 60)

	seconds = seconds % 60
	minutes = minutes % 60

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds)
	end

	return string.format("%d:%02d", minutes, seconds)
end

local function getActiveBoosts(boosts, nowUnix)
	local activeBoosts = {}

	if typeof(boosts) ~= "table" then
		return activeBoosts
	end

	for _, boost in ipairs(boosts) do
		if typeof(boost) == "table" and typeof(boost.EndsAtUnix) == "number" then
			local remainingSeconds = math.floor(boost.EndsAtUnix) - nowUnix

			if remainingSeconds > 0 then
				table.insert(activeBoosts, {
					BoostId = boost.BoostId,
					DisplayName = boost.DisplayName or boost.ShortDisplayName or "Boost",
					IconId = boost.IconId,
					RemainingSeconds = remainingSeconds,
				})
			end
		end
	end

	return activeBoosts
end

local function createLabel(text, props, children)
	local mergedProps = {
		BackgroundTransparency = 1,
		Font = UIThemeConfig.Font,
		Text = text,
		TextColor3 = Color3.fromRGB(237, 235, 255),
		TextScaled = true,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = ROW_Z_INDEX + 3,
	}

	for key, value in pairs(props or {}) do
		mergedProps[key] = value
	end

	return React.createElement("TextLabel", mergedProps, children)
end

local function createTextSizeConstraint(maxTextSize, minTextSize)
	return React.createElement("UITextSizeConstraint", {
		MaxTextSize = maxTextSize,
		MinTextSize = minTextSize,
	})
end

local function createBoostRow(boost, layoutOrder)
	local style = BOOST_STYLES[boost.BoostId] or {
		AccentColor = Color3.fromRGB(157, 135, 255),
		IconColor = Color3.fromRGB(237, 235, 255),
	}
	local icon = if typeof(boost.IconId) == "string" then UIIconConfig.getIcon(boost.IconId) else nil

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT),
		ZIndex = ROW_Z_INDEX,
	}, {
		Icon = React.createElement("ImageLabel", {
			Active = false,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = icon or "",
			ImageColor3 = style.IconColor,
			Position = UDim2.new(0, 0, 0.5, 0),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(ROW_ICON_SIZE, ROW_ICON_SIZE),
			ZIndex = ROW_Z_INDEX + 2,
		}),
		Name = createLabel(boost.DisplayName, {
			Position = UDim2.fromOffset(ROW_CONTENT_LEFT, 0),
			Size = UDim2.new(1, -(ROW_CONTENT_LEFT + ROW_TIMER_WIDTH + ROW_CONTENT_RIGHT_PADDING + 8), 1, 0),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 15,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.2,
		}, {
			TextSizeConstraint = createTextSizeConstraint(15, 9),
		}),
		Timer = createLabel(formatRemainingTime(boost.RemainingSeconds), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -ROW_CONTENT_RIGHT_PADDING, 0.5, 1),
			Size = UDim2.fromOffset(ROW_TIMER_WIDTH, ROW_HEIGHT),
			TextColor3 = style.AccentColor,
			TextSize = 15,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, {
			TextSizeConstraint = createTextSizeConstraint(15, 9),
		}),
	})
end

local function ActiveBoostsDisplayComponent(props)
	local nowUnix, setNowUnix = React.useState(getCurrentUnixTime())

	React.useEffect(function()
		local cancelled = false

		task.spawn(function()
			while not cancelled do
				task.wait(1)

				if not cancelled then
					setNowUnix(getCurrentUnixTime())
				end
			end
		end)

		return function()
			cancelled = true
		end
	end, {})

	local activeBoosts = getActiveBoosts(props.ActiveBoosts, nowUnix)

	if #activeBoosts == 0 then
		return nil
	end

	local children = {
		Scale = React.createElement("UIScale", {
			Scale = props.Scale or 1,
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for index, boost in ipairs(activeBoosts) do
		children["Boost" .. tostring(index)] = createBoostRow(boost, index)
	end

	local scale = props.Scale or 1
	local height = ROW_HEIGHT * #activeBoosts + ROW_GAP * math.max(0, #activeBoosts - 1)
	local bottomOffset = math.floor(
		HudLayoutConfig.CurrencyDisplaySize.Y.Offset * scale
			+ math.abs(HudLayoutConfig.CurrencyDisplayPosition.Y.Offset)
			+ 8
	)

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 22, 1, -bottomOffset),
		Size = UDim2.fromOffset(ROW_WIDTH, height),
		ZIndex = ROW_Z_INDEX,
	}, children)
end

function ActiveBoostsDisplay.create(props)
	return React.createElement(ActiveBoostsDisplayComponent, props or {})
end

return ActiveBoostsDisplay
