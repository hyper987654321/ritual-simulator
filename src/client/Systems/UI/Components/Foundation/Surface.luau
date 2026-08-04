local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIThemeConfig"))

local Surface = {}
local C = Theme.Colors

function Surface.corner(radius)
	return React.createElement("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius.Control) })
end

function Surface.stroke(color, transparency, thickness)
	return React.createElement("UIStroke", { Color = color or C.Stroke, Transparency = if transparency == nil then 0.35 else transparency, Thickness = thickness or 1 })
end

function Surface.shadow(zIndex)
	return React.createElement("Frame", { BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.65, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, 0), ZIndex = (zIndex or 1) - 1 }, { Corner = Surface.corner(Theme.Radius.Panel) })
end

function Surface.label(text, props, children)
	local resolved = { BackgroundTransparency = 1, Font = Theme.Font, Text = tostring(text or ""), TextColor3 = C.Ink, TextSize = Theme.Type.Label, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }
	for key, value in pairs(props or {}) do resolved[key] = value end
	return React.createElement("TextLabel", resolved, children)
end

function Surface.button(text, props, children)
	local resolved = { Active = true, AutoButtonColor = true, BackgroundColor3 = C.Violet, BorderSizePixel = 0, Font = Theme.FontBold, Text = text, TextColor3 = C.Ink, TextSize = Theme.Type.Button }
	for key, value in pairs(props or {}) do resolved[key] = value end
	local buttonChildren = { Corner = Surface.corner(Theme.Radius.Control), Stroke = Surface.stroke(C.Stroke, 0.3) }
	for key, value in pairs(children or {}) do buttonChildren[key] = value end
	return React.createElement("TextButton", resolved, buttonChildren)
end

function Surface.panel(props, children)
	local resolved = { BackgroundColor3 = C.Panel, BackgroundTransparency = Theme.PanelTransparency, BorderSizePixel = 0 }
	for key, value in pairs(props or {}) do resolved[key] = value end
	local panelChildren = { Corner = Surface.corner(Theme.Radius.Panel), Stroke = Surface.stroke(C.Stroke, 0.35), Shadow = Surface.shadow(resolved.ZIndex) }
	for key, value in pairs(children or {}) do panelChildren[key] = value end
	return React.createElement("Frame", resolved, panelChildren)
end

function Surface.card(props, children)
	local resolved = { BackgroundColor3 = C.Card, BackgroundTransparency = 0.08, BorderSizePixel = 0 }
	for key, value in pairs(props or {}) do resolved[key] = value end
	local cardChildren = { Corner = Surface.corner(Theme.Radius.Control), Stroke = Surface.stroke(C.Stroke, 0.55) }
	for key, value in pairs(children or {}) do cardChildren[key] = value end
	return React.createElement("Frame", resolved, cardChildren)
end

return Surface
