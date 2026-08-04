local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Theme = require(Config:WaitForChild("UIThemeConfig"))
local Icons = require(Config:WaitForChild("UIIconConfig"))

local Icon = {}
local C = Theme.Colors

local function frame(props, children)
	local resolved = { BackgroundColor3 = C.Ink, BorderSizePixel = 0 }
	for key, value in pairs(props or {}) do
		resolved[key] = value
	end
	return React.createElement("Frame", resolved, children)
end

local function corner(radius)
	return React.createElement("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, thickness, transparency)
	return React.createElement("UIStroke", { Color = color, Thickness = thickness or 1, Transparency = transparency or 0 })
end

local function bar(color, position, size, rotation, radius)
	return frame({ BackgroundColor3 = color, Position = position, Rotation = rotation or 0, Size = size }, { Corner = corner(radius or 2) })
end

local function dot(color, position, size)
	return frame({ BackgroundColor3 = color, Position = position, Size = size }, { Corner = corner(99) })
end

local function ring(color, position, size, thickness)
	return frame({ BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Position = position, Size = size }, { Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke = stroke(color, thickness or 2) })
end

local function primitive(iconId, color)
	local children = {}
	if iconId == "Pets" or iconId == "PetInventory" then
		children.Pad = frame({ BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.48, 0.42), Rotation = -8 }, { Corner = corner(7) })
		for index, position in ipairs({ UDim2.fromScale(0.25, 0.25), UDim2.fromScale(0.43, 0.1), UDim2.fromScale(0.62, 0.1), UDim2.fromScale(0.79, 0.27) }) do
			children["Toe" .. index] = dot(color, UDim2.new(position.X.Scale, 0, position.Y.Scale, 0), UDim2.fromScale(0.2, 0.2))
		end
	elseif iconId == "RollDice" then
		children.Body = frame({ BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.66, 0.66), Rotation = 12 }, { Corner = corner(5) })
		for index, position in ipairs({ UDim2.fromScale(0.28, 0.28), UDim2.fromScale(0.62, 0.28), UDim2.fromScale(0.45, 0.45), UDim2.fromScale(0.28, 0.62), UDim2.fromScale(0.62, 0.62) }) do
			children["Pip" .. index] = dot(C.Panel, position, UDim2.fromScale(0.12, 0.12))
		end
	elseif iconId == "RitualCore" or iconId == "Essence" then
		children.Outer = ring(color, UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.76, 0.76), 2)
		children.Inner = ring(color, UDim2.fromScale(0.28, 0.28), UDim2.fromScale(0.44, 0.44), 2)
		children.Core = frame({ BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.2), Rotation = 45 }, { Corner = corner(2) })
	elseif iconId == "Zones" or iconId == "Teleporter" then
		children.Pin = frame({ BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.42), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.58, 0.58), Rotation = 45 }, { Corner = corner(99) })
		children.Hole = dot(C.Panel, UDim2.fromScale(0.42, 0.34), UDim2.fromScale(0.16, 0.16))
		children.Tail = bar(color, UDim2.fromScale(0.46, 0.73), UDim2.fromScale(0.08, 0.2), 0, 2)
	elseif iconId == "More" then
		for index, x in ipairs({ 0.22, 0.5, 0.78 }) do children["Dot" .. index] = dot(color, UDim2.fromScale(x - 0.07, 0.43), UDim2.fromScale(0.14, 0.14)) end
	elseif iconId == "Close" then
		children.A = bar(color, UDim2.fromScale(0.08, 0.46), UDim2.fromScale(0.84, 0.1), 45)
		children.B = bar(color, UDim2.fromScale(0.08, 0.46), UDim2.fromScale(0.84, 0.1), -45)
	elseif iconId == "Shop" then
		children.Bag = frame({ BackgroundColor3 = color, Position = UDim2.fromScale(0.18, 0.32), Size = UDim2.fromScale(0.64, 0.52) }, { Corner = corner(4) })
		children.Handle = ring(color, UDim2.fromScale(0.34, 0.12), UDim2.fromScale(0.32, 0.32), 2)
	elseif iconId == "Daily" then
		children.Page = frame({ BackgroundColor3 = color, Position = UDim2.fromScale(0.16, 0.2), Size = UDim2.fromScale(0.68, 0.66) }, { Corner = corner(4) })
		children.Top = bar(C.Panel, UDim2.fromScale(0.16, 0.36), UDim2.fromScale(0.68, 0.08), 0)
		for index, position in ipairs({ UDim2.fromScale(0.28, 0.52), UDim2.fromScale(0.58, 0.52), UDim2.fromScale(0.28, 0.7), UDim2.fromScale(0.58, 0.7) }) do children["Date" .. index] = dot(C.Panel, position, UDim2.fromScale(0.12, 0.12)) end
	elseif iconId == "Friends" then
		children.Left = dot(color, UDim2.fromScale(0.2, 0.18), UDim2.fromScale(0.3, 0.3))
		children.Right = dot(color, UDim2.fromScale(0.5, 0.18), UDim2.fromScale(0.3, 0.3))
		children.LeftBody = frame({ BackgroundColor3 = color, Position = UDim2.fromScale(0.12, 0.5), Size = UDim2.fromScale(0.44, 0.32) }, { Corner = corner(6) })
		children.RightBody = frame({ BackgroundColor3 = color, Position = UDim2.fromScale(0.44, 0.5), Size = UDim2.fromScale(0.44, 0.32) }, { Corner = corner(6) })
	elseif iconId == "AutoRoll" or iconId == "AutoRollColored" then
		children.A = bar(color, UDim2.fromScale(0.12, 0.44), UDim2.fromScale(0.62, 0.1), -35)
		children.B = bar(color, UDim2.fromScale(0.28, 0.2), UDim2.fromScale(0.1, 0.6), 55)
		children.C = bar(color, UDim2.fromScale(0.28, 0.44), UDim2.fromScale(0.62, 0.1), 145)
	elseif iconId == "Rebirth" or iconId == "RollViewHidden" then
		children.Outer = ring(color, UDim2.fromScale(0.16, 0.16), UDim2.fromScale(0.68, 0.68), 2)
		children.Arrow = bar(color, UDim2.fromScale(0.43, 0.08), UDim2.fromScale(0.14, 0.42), 0)
		children.Head = bar(color, UDim2.fromScale(0.32, 0.08), UDim2.fromScale(0.36, 0.12), 0)
	else
		children.Dot = dot(color, UDim2.fromScale(0.43, 0.43), UDim2.fromScale(0.14, 0.14))
	end
	return children
end

function Icon.create(iconId, props)
	local resolved = { BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), ZIndex = 1 }
	for key, value in pairs(props or {}) do resolved[key] = value end
	local image = Icons.getIcon(iconId)
	if image ~= nil and image ~= "" then
		resolved.Image = image
		resolved.ScaleType = Enum.ScaleType.Fit
		return React.createElement("ImageLabel", resolved)
	end
	local color = resolved.ImageColor3 or C.Ink
	resolved.ImageColor3 = nil
	resolved.TextSize = nil
	resolved.Font = nil
	resolved.Text = nil
	return frame(resolved, primitive(iconId, color))
end

return Icon
