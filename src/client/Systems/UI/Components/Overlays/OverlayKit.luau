local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIThemeConfig"))
local Surface = require(script.Parent.Parent:WaitForChild("Foundation"):WaitForChild("Surface"))
local Icon = require(script.Parent.Parent:WaitForChild("Foundation"):WaitForChild("Icon"))

local Kit = {}
local C = Theme.Colors

function Kit.label(text, props, children) return Surface.label(text, props, children) end
function Kit.button(text, props, children) return Surface.button(text, props, children) end
function Kit.icon(iconId, props) return Icon.create(iconId, props) end

function Kit.modal(props)
	local viewport = props.ViewportSize or Vector2.new(1280, 720)
	local mobile = viewport.X < 600
	local width = math.min(props.MaximumWidth or 760, math.max(288, math.floor(viewport.X * (mobile and 0.92 or 0.76))))
	local height = math.min(props.MaximumHeight or 540, math.max(280, math.floor(viewport.Y * (mobile and 0.82 or 0.78))))
	local z = props.ZIndex or 80
	local children = props.Children or {}
	children.Header = React.createElement("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -72, 0, 44), ZIndex = z + 2 }, { Title = Surface.label(props.Title, { Font = Theme.FontBold, Size = UDim2.fromScale(1, 1), TextSize = if mobile then 20 else Theme.Type.Title, ZIndex = z + 3 }) })
	children.Close = React.createElement("ImageButton", { Active = true, AutoButtonColor = true, BackgroundColor3 = C.Card, BorderSizePixel = 0, Image = "", Position = UDim2.new(1, -56, 0, 12), Size = UDim2.fromOffset(40, 40), ZIndex = z + 4, [React.Event.Activated] = props.OnClose }, { Corner = Surface.corner(Theme.Radius.Control), Stroke = Surface.stroke(C.Stroke, 0.4), Glyph = Icon.create("Close", { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1), TextSize = 24, ZIndex = z + 5 }) })
	return Surface.panel({ Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, height), ZIndex = z }, children)
end

return Kit
