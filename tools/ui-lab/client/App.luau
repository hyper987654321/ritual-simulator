local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Presets = require(ReplicatedStorage:WaitForChild("UILab"):WaitForChild("Presets"))
local Fixtures = require(ReplicatedStorage:WaitForChild("UILab"):WaitForChild("Fixtures"))
local Registry = require(ReplicatedStorage:WaitForChild("UILab"):WaitForChild("StoryRegistry"))
local Diagnostics = require(ReplicatedStorage:WaitForChild("UILab"):WaitForChild("Diagnostics"))

local storiesFolder = script.Parent:WaitForChild("stories")

local Colors = {
	Canvas = Color3.fromRGB(16, 20, 32),
	Panel = Color3.fromRGB(25, 31, 47),
	Card = Color3.fromRGB(32, 40, 59),
	Stroke = Color3.fromRGB(79, 91, 117),
	Ink = Color3.fromRGB(244, 246, 250),
	Muted = Color3.fromRGB(167, 178, 199),
	Violet = Color3.fromRGB(151, 116, 242),
	Cyan = Color3.fromRGB(91, 206, 220),
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

local function outline()
	return React.createElement("UIStroke", {
		Color = Colors.Stroke,
		Transparency = 0.35,
		Thickness = 1,
	})
end

local function label(text, props)
	local resolved = copyProps(props)
	resolved.Text = text
	resolved.Font = resolved.Font or Enum.Font.Gotham
	resolved.TextColor3 = resolved.TextColor3 or Colors.Ink
	resolved.TextSize = resolved.TextSize or 13
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
	resolved.TextColor3 = resolved.TextColor3 or Colors.Ink
	resolved.TextSize = resolved.TextSize or 12
	resolved.BackgroundColor3 = resolved.BackgroundColor3 or Colors.Card
	resolved.BorderSizePixel = 0
	resolved.AutoButtonColor = true
	return React.createElement("TextButton", resolved, {
		Corner = corner(8),
		Outline = outline(),
	})
end

local function choiceRow(items, selected, onSelect)
	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, item in items do
		children[item.Id] = button(item.Label, {
			LayoutOrder = index,
			Size = UDim2.fromOffset(92, 30),
			BackgroundColor3 = if item.Id == selected then Colors.Violet else Colors.Card,
			[React.Event.Activated] = function()
				onSelect(item.Id)
			end,
		})
	end
	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
	}, children)
end

local function findFixture(id)
	for _, fixture in Fixtures do
		if fixture.Id == id then
			return fixture
		end
	end
	return Fixtures[1]
end

local function findPreset(id)
	for _, preset in { Presets.Desktop, Presets.Laptop, Presets.Tablet, Presets.Mobile } do
		if preset.Id == id then
			return preset
		end
	end
	return Presets.Desktop
end

local function App()
	local storyId, setStoryId = React.useState(Registry.all()[1].Id)
	local fixtureId, setFixtureId = React.useState("populated")
	local presetId, setPresetId = React.useState("desktop")
	local diagnostics, setDiagnostics = React.useState(nil)
	local previewRef = React.useRef(nil)
	local storyRootRef = React.useRef(nil)
	local displayScale, setDisplayScale = React.useState(1)

	local story = Registry.get(storyId)
	local fixture = findFixture(fixtureId)
	local preset = findPreset(presetId)
	local Story = require(storiesFolder:WaitForChild(story.Module))

	React.useEffect(function()
		local function updateScale()
			local preview = previewRef.current
			if not preview then
				return
			end
			local available = preview.AbsoluteSize - Vector2.new(32, 32)
			local scaleX = available.X / preset.Width
			local scaleY = available.Y / preset.Height
			setDisplayScale(math.max(0.05, math.min(scaleX, scaleY, 1)))
		end
		updateScale()
		local preview = previewRef.current
		if not preview then
			return
		end
		local connection = preview:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
		return function()
			connection:Disconnect()
		end
	end, { presetId })

	local reportRows = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if diagnostics then
		for index, message in diagnostics.Passed do
			reportRows["Pass" .. index] = label("PASS " .. message, {
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 18),
				TextSize = 11,
				TextColor3 = Color3.fromRGB(96, 197, 139),
			})
		end
		for index, message in diagnostics.Warnings do
			reportRows["Warning" .. index] = label("WARN " .. message, {
				LayoutOrder = 20 + index,
				Size = UDim2.new(1, 0, 0, 18),
				TextSize = 11,
				TextColor3 = Color3.fromRGB(239, 190, 85),
			})
		end
		for index, message in diagnostics.Errors do
			reportRows["Error" .. index] = label("ERROR " .. message, {
				LayoutOrder = 40 + index,
				Size = UDim2.new(1, 0, 0, 18),
				TextSize = 11,
				TextColor3 = Color3.fromRGB(230, 112, 117),
			})
		end
	else
		reportRows.Empty = label("Run a report after the story settles.", {
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 11,
			TextColor3 = Colors.Muted,
		})
	end

	local toolbarContent = React.createElement("Frame", {
		Size = UDim2.fromOffset(1240, 108),
		BackgroundTransparency = 1,
	}, {
		Title = label("UI LAB / CLEAN-SLATE", {
			Position = UDim2.fromOffset(16, 8),
			Size = UDim2.fromOffset(320, 24),
			Font = Enum.Font.GothamBold,
			TextSize = 17,
		}),
		StoryLabel = label("STORY", {
			Position = UDim2.fromOffset(16, 42),
			Size = UDim2.fromOffset(56, 22),
			TextSize = 10,
			TextColor3 = Colors.Muted,
		}),
		StoryChoices = React.createElement("Frame", {
			Position = UDim2.fromOffset(76, 38),
			Size = UDim2.fromOffset(300, 32),
			BackgroundTransparency = 1,
		}, choiceRow(Registry.all(), storyId, setStoryId)),
		FixtureLabel = label("FIXTURE", {
			Position = UDim2.fromOffset(16, 76),
			Size = UDim2.fromOffset(56, 22),
			TextSize = 10,
			TextColor3 = Colors.Muted,
		}),
		FixtureChoices = React.createElement("Frame", {
			Position = UDim2.fromOffset(76, 72),
			Size = UDim2.fromOffset(520, 32),
			BackgroundTransparency = 1,
		}, choiceRow(Fixtures, fixtureId, setFixtureId)),
		DeviceLabel = label("DEVICE", {
			Position = UDim2.fromOffset(420, 42),
			Size = UDim2.fromOffset(56, 22),
			TextSize = 10,
			TextColor3 = Colors.Muted,
		}),
		DeviceChoices = React.createElement("Frame", {
			Position = UDim2.fromOffset(480, 38),
			Size = UDim2.fromOffset(400, 32),
			BackgroundTransparency = 1,
		}, choiceRow({ Presets.Desktop, Presets.Laptop, Presets.Tablet, Presets.Mobile }, presetId, setPresetId)),
		SizeInfo = label(string.format("DESIGN %dx%d  DISPLAY SCALE %.2f", preset.Width, preset.Height, displayScale), {
			Position = UDim2.fromOffset(900, 42),
			Size = UDim2.fromOffset(320, 22),
			TextSize = 11,
			TextColor3 = Colors.Cyan,
		}),
		Run = button("Run diagnostics", {
			Position = UDim2.fromOffset(900, 74),
			Size = UDim2.fromOffset(150, 30),
			BackgroundColor3 = Colors.Cyan,
			TextColor3 = Colors.Canvas,
			[React.Event.Activated] = function()
				if storyRootRef.current then
					setDiagnostics(Diagnostics.inspect(storyRootRef.current))
				end
			end,
		}),
	})

	return React.createElement("Frame", {
		Name = "UILabApp",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.Canvas,
		BorderSizePixel = 0,
	}, {
		Toolbar = React.createElement("ScrollingFrame", {
			Name = "ToolbarScroll",
			Size = UDim2.new(1, 0, 0, 116),
			CanvasSize = UDim2.fromOffset(1240, 0),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Colors.Violet,
			BackgroundColor3 = Colors.Panel,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 20,
		}, {
			Content = toolbarContent,
		}),
		Preview = React.createElement("Frame", {
			Name = "PreviewViewport",
			ref = previewRef,
			Position = UDim2.fromOffset(16, 132),
			Size = UDim2.new(1, -32, 1, -148),
			BackgroundColor3 = Color3.fromRGB(20, 25, 39),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 1,
		}, {
			Corner = corner(12),
			Outline = outline(),
			CanvasLabel = label("FIXED DESIGN CANVAS", {
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.fromOffset(220, 18),
				TextSize = 10,
				TextColor3 = Colors.Muted,
				ZIndex = 2,
			}),
			DesignCanvas = React.createElement("Frame", {
				Name = "DesignCanvas",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(preset.Width, preset.Height),
				BackgroundTransparency = 1,
				ZIndex = 1,
			}, {
				Scale = React.createElement("UIScale", { Scale = displayScale }),
				Story = React.createElement(Story, {
					fixture = fixture,
					preset = preset,
					storyRootRef = storyRootRef,
				}),
			}),
		}),
		Diagnostics = React.createElement("Frame", {
			Name = "DiagnosticsChrome",
			Position = UDim2.new(1, -356, 1, -140),
			Size = UDim2.fromOffset(340, 116),
			BackgroundColor3 = Colors.Panel,
			BorderSizePixel = 0,
			ZIndex = 30,
		}, {
			Corner = corner(8),
			Outline = outline(),
			Title = label("DIAGNOSTICS / STORYROOT ONLY", {
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -24, 0, 18),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = Colors.Cyan,
			}),
			Body = React.createElement("ScrollingFrame", {
				Position = UDim2.fromOffset(12, 28),
				Size = UDim2.new(1, -24, 1, -36),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, reportRows),
		}),
	})
end

return App
