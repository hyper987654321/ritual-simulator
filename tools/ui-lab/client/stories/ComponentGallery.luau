local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Diagnostics = require(ReplicatedStorage:WaitForChild("UILab"):WaitForChild("Diagnostics"))

Diagnostics.registerRootPanel("GalleryCardOne")
Diagnostics.registerRootPanel("GalleryCardTwo")
Diagnostics.registerRootPanel("GalleryCardThree")
Diagnostics.registerRootPanel("GalleryAnatomy")

local C = {
	Canvas = Color3.fromRGB(14, 18, 28),
	Panel = Color3.fromRGB(25, 31, 47),
	Card = Color3.fromRGB(32, 40, 59),
	Stroke = Color3.fromRGB(79, 91, 117),
	Ink = Color3.fromRGB(244, 246, 250),
	Muted = Color3.fromRGB(167, 178, 199),
	Violet = Color3.fromRGB(151, 116, 242),
	Cyan = Color3.fromRGB(91, 206, 220),
	Gold = Color3.fromRGB(239, 190, 85),
	Green = Color3.fromRGB(96, 197, 139),
	Red = Color3.fromRGB(230, 112, 117),
}

local function copyProps(props)
	local copy = {}
	for key, value in props or {} do
		copy[key] = value
	end
	return copy
end

local function corner(radius)
	return React.createElement("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function outline(color)
	return React.createElement("UIStroke", { Color = color, Transparency = 0.35, Thickness = 1 })
end

local function label(text, props)
	local resolved = copyProps(props)
	resolved.Text = text
	resolved.Font = resolved.Font or Enum.Font.Gotham
	resolved.TextColor3 = resolved.TextColor3 or C.Ink
	resolved.TextSize = resolved.TextSize or 14
	resolved.TextXAlignment = resolved.TextXAlignment or Enum.TextXAlignment.Left
	resolved.TextYAlignment = resolved.TextYAlignment or Enum.TextYAlignment.Center
	resolved.BackgroundTransparency = 1
	resolved.BorderSizePixel = 0
	return React.createElement("TextLabel", resolved)
end

local function button(text, props)
	local resolved = copyProps(props)
	resolved.Text = text
	resolved.Font = resolved.Font or Enum.Font.GothamMedium
	resolved.TextColor3 = resolved.TextColor3 or C.Ink
	resolved.TextSize = resolved.TextSize or 13
	resolved.BackgroundColor3 = resolved.BackgroundColor3 or C.Card
	resolved.BorderSizePixel = 0
	resolved.AutoButtonColor = true
	return React.createElement("TextButton", resolved, {
		Corner = corner(8),
		Outline = outline(C.Stroke),
	})
end

local function card(name, title, value, accent, layoutOrder)
	return React.createElement("Frame", {
		Name = name,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 68),
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, {
		Corner = corner(8),
		Outline = outline(C.Stroke),
		Accent = React.createElement("Frame", {
			Size = UDim2.fromOffset(4, 68),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 4,
		}),
		Title = label(title, {
			Position = UDim2.fromOffset(16, 8),
			Size = UDim2.new(1, -32, 0, 24),
			Font = Enum.Font.GothamMedium,
			ZIndex = 5,
		}),
		Value = label(value, {
			Position = UDim2.fromOffset(16, 34),
			Size = UDim2.new(1, -32, 0, 20),
			TextSize = 12,
			TextColor3 = C.Muted,
			ZIndex = 5,
		}),
	})
end

local function ComponentGallery(props)
	local fixture = props.fixture
	local children = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Buttons = React.createElement("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Primary = button("Primary action", {
				Size = UDim2.fromOffset(154, 44),
				BackgroundColor3 = C.Violet,
				ZIndex = 3,
			}),
			Quiet = button("Quiet action", {
				Position = UDim2.fromOffset(166, 0),
				Size = UDim2.fromOffset(140, 44),
				ZIndex = 3,
			}),
			Locked = button("Locked", {
				Position = UDim2.fromOffset(318, 0),
				Size = UDim2.fromOffset(110, 44),
				Active = false,
				BackgroundColor3 = Color3.fromRGB(54, 59, 72),
				TextColor3 = C.Muted,
				ZIndex = 3,
			}),
		}),
		Cards = React.createElement("Frame", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 228),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Layout = React.createElement("UIListLayout", {
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			One = card("GalleryCardOne", "Token roles", "Violet / Cyan / Gold", C.Violet, 1),
			Two = card("GalleryCardTwo", "Spacing", "4 / 8 / 12 / 16 / 24 / 32", C.Cyan, 2),
			Three = card("GalleryCardThree", "Radius", "8 controls / 12 panels", C.Gold, 3),
		}),
		Anatomy = React.createElement("Frame", {
			Name = "GalleryAnatomy",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 128),
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			Corner = corner(12),
			Outline = outline(C.Stroke),
			Header = label("Modal anatomy", {
				Position = UDim2.fromOffset(16, 12),
				Size = UDim2.new(1, -32, 0, 24),
				Font = Enum.Font.GothamBold,
				ZIndex = 5,
			}),
			Body = label("One title / bounded content / optional footer", {
				Position = UDim2.fromOffset(16, 42),
				Size = UDim2.new(1, -32, 0, 24),
				TextColor3 = C.Muted,
				ZIndex = 5,
			}),
			Footer = button("Close", {
				Position = UDim2.new(1, -112, 1, -52),
				Size = UDim2.fromOffset(96, 36),
				ZIndex = 5,
			}),
		}),
	}

	if fixture.Id == "empty" then
		children.State = label("No fixture content. Empty states explain what happens next.", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 44),
			TextColor3 = C.Muted,
			ZIndex = 5,
		})
	elseif fixture.Id == "loading" then
		children.State = label("Loading fixture...", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 44),
			TextColor3 = C.Cyan,
			ZIndex = 5,
		})
	elseif fixture.Id == "locked" then
		children.State = label("This fixture is locked. Explain the gate beside the disabled action.", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 44),
			TextColor3 = C.Gold,
			ZIndex = 5,
		})
	elseif fixture.Id == "error" then
		children.State = label("Could not load fixture. Retry remains visible and calm.", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 44),
			TextColor3 = C.Red,
			ZIndex = 5,
		})
	end

	return React.createElement("Frame", {
		Name = "StoryRoot",
		ref = props.storyRootRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Canvas,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, children)
end

return ComponentGallery
