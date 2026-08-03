local ReplicatedStorage = game:GetService("ReplicatedStorage")

local toolbar = plugin:CreateToolbar("Ritual Core")
local toolbarButton = toolbar:CreateButton("RitualMapGenerator", "Open Ritual Map Generator", "", "Map Gen")
toolbarButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,
	false,
	false,
	360,
	560,
	320,
	420
)

local widget = plugin:CreateDockWidgetPluginGui("RitualMapGeneratorWidget", widgetInfo)
widget.Title = "Ritual Map Generator"

local state = {
	IsBusy = false,
	ShowAnchors = false,
	ShowZoneBounds = false,
}

local outputLines = {}
local buttons = {}

local function create(className, properties)
	local instance = Instance.new(className)

	for key, value in pairs(properties or {}) do
		instance[key] = value
	end

	return instance
end

local root = create("Frame", {
	BackgroundColor3 = Color3.fromRGB(28, 28, 34),
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Parent = widget,
})

local padding = create("UIPadding", {
	PaddingTop = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10),
	Parent = root,
})

local list = create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = root,
})

local title = create("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 28),
	Text = "Ritual Map Generator",
	TextColor3 = Color3.fromRGB(242, 240, 255),
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = root,
})

local function createField(labelText, defaultText, layoutOrder)
	local frame = create("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = root,
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 76, 1, 0),
		Text = labelText,
		TextColor3 = Color3.fromRGB(205, 203, 221),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local box = create("TextBox", {
		BackgroundColor3 = Color3.fromRGB(42, 42, 52),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		Position = UDim2.new(0, 84, 0, 0),
		Size = UDim2.new(1, -84, 1, 0),
		Text = defaultText,
		TextColor3 = Color3.fromRGB(242, 240, 255),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = box,
	})

	return box
end

local seedBox = createField("Seed", "123456", 2)
local presetBox = createField("Preset", "Block Sections v1", 3)

local buttonGrid = create("Frame", {
	BackgroundTransparency = 1,
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 188),
	Parent = root,
})

local buttonGridLayout = create("UIGridLayout", {
	CellPadding = UDim2.fromOffset(8, 8),
	CellSize = UDim2.new(0.5, -4, 0, 34),
	FillDirectionMaxCells = 2,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = buttonGrid,
})

local function createButton(text, order)
	local button = create("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(56, 55, 68),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		LayoutOrder = order,
		Size = UDim2.fromOffset(150, 34),
		Text = text,
		TextColor3 = Color3.fromRGB(245, 243, 255),
		TextSize = 12,
		TextWrapped = true,
		Parent = buttonGrid,
	})

	table.insert(buttons, button)

	return button
end

local generateAllButton = createButton("Generate All", 1)
local generateSectionsButton = createButton("Generate Sections", 2)
local generatePropsButton = createButton("Generate Props", 3)
local clearMapButton = createButton("Clear Map", 4)
local clearGeneratedButton = createButton("Clear Generated", 5)
local validateButton = createButton("Validate", 6)
local exportButton = createButton("Export Anchors", 7)
local analyzeReferencesButton = createButton("Analyze References", 8)

local debugFrame = create("Frame", {
	BackgroundTransparency = 1,
	LayoutOrder = 5,
	Size = UDim2.new(1, 0, 0, 76),
	Parent = root,
})

local debugLayout = create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 6),
	Parent = debugFrame,
})

local function createToggle(text, key)
	local toggle = create("TextButton", {
		BackgroundColor3 = Color3.fromRGB(41, 41, 50),
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		Size = UDim2.new(1, 0, 0, 32),
		TextColor3 = Color3.fromRGB(223, 221, 238),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = debugFrame,
	})

	create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		Parent = toggle,
	})

	local function refresh()
		toggle.Text = (if state[key] then "[x] " else "[ ] ") .. text
	end

	toggle.Activated:Connect(function()
		state[key] = not state[key]
		refresh()
	end)

	refresh()

	return toggle
end

createToggle("Show anchors", "ShowAnchors")
createToggle("Show zone bounds", "ShowZoneBounds")

local outputFrame = create("ScrollingFrame", {
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(20, 20, 25),
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	LayoutOrder = 6,
	ScrollBarThickness = 8,
	Size = UDim2.new(1, 0, 1, -350),
	Parent = root,
})

local outputLabel = create("TextLabel", {
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	Size = UDim2.new(1, -12, 0, 0),
	Text = "",
	TextColor3 = Color3.fromRGB(215, 214, 226),
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = outputFrame,
})

create("UIPadding", {
	PaddingTop = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 8),
	Parent = outputFrame,
})

local function refreshOutput()
	outputLabel.Text = table.concat(outputLines, "\n")
end

local function log(message)
	table.insert(outputLines, "- " .. message)

	if #outputLines > 160 then
		table.remove(outputLines, 1)
	end

	refreshOutput()
end

local function setBusy(isBusy)
	state.IsBusy = isBusy

	for _, button in ipairs(buttons) do
		button.Active = not isBusy
		button.AutoButtonColor = not isBusy
		button.BackgroundColor3 = if isBusy then Color3.fromRGB(38, 38, 45) else Color3.fromRGB(56, 55, 68)
	end
end

local cachedModules = nil

local function loadModules()
	if cachedModules ~= nil then
		return cachedModules
	end

	local shared = ReplicatedStorage:FindFirstChild("Shared")

	if shared == nil then
		return nil, "ReplicatedStorage.Shared was not found. Sync the Rojo project into Studio first."
	end

	local mapGen = shared:FindFirstChild("MapGen")

	if mapGen == nil then
		return nil, "ReplicatedStorage.Shared.MapGen was not found. Sync the new source modules into Studio first."
	end

	local modules = {
		AnchorExporter = require(mapGen:WaitForChild("AnchorExporter")),
		BlockMapWriter = require(mapGen:WaitForChild("BlockMapWriter")),
		MapValidator = require(mapGen:WaitForChild("MapValidator")),
		ReferencePropAnalyzer = require(mapGen:WaitForChild("ReferencePropAnalyzer")),
		SectionPlan = require(mapGen:WaitForChild("SectionPlan")),
	}

	cachedModules = modules

	return modules
end

local function getSeed()
	return tonumber(seedBox.Text) or 1
end

local function getPreset()
	if presetBox.Text == "" then
		return "Block Sections v1"
	end

	return presetBox.Text
end

local function getPlan(modules)
	return modules.SectionPlan.build(getSeed(), getPreset())
end

local function runJob(jobName, callback)
	if state.IsBusy then
		log("Already running a generation job.")
		return
	end

	local modules, loadError = loadModules()

	if modules == nil then
		log(loadError)
		return
	end

	setBusy(true)
	log(jobName .. " started.")

	task.spawn(function()
		local ok, err = pcall(function()
			callback(modules)
		end)

		if ok then
			log(jobName .. " finished.")
		else
			log(jobName .. " failed: " .. tostring(err))
		end

		setBusy(false)
	end)
end

local function validateAndLog(modules, plan)
	local results = modules.MapValidator.validate(plan)
	local lines = modules.MapValidator.formatResults(results)

	for _, line in ipairs(lines) do
		log(line)
	end
end

generateAllButton.Activated:Connect(function()
	runJob("Generate all", function(modules)
		local plan = getPlan(modules)

		modules.AnchorExporter.clearGeneratedInstances()
		modules.BlockMapWriter.generate(plan, {
			ShowAnchors = state.ShowAnchors,
			ShowZoneBounds = state.ShowZoneBounds,
		}, function(done, total, zoneId)
			log("Generated section " .. tostring(zoneId) .. " (" .. tostring(done) .. "/" .. tostring(total) .. ")")
		end)
		validateAndLog(modules, plan)
	end)
end)

generateSectionsButton.Activated:Connect(function()
	runJob("Generate sections", function(modules)
		local plan = getPlan(modules)

		modules.AnchorExporter.clearGeneratedInstances()
		modules.BlockMapWriter.generate(plan, {
			ShowAnchors = state.ShowAnchors,
			ShowZoneBounds = state.ShowZoneBounds,
		}, function(done, total, zoneId)
			log("Generated section " .. tostring(zoneId) .. " (" .. tostring(done) .. "/" .. tostring(total) .. ")")
		end)
	end)
end)

generatePropsButton.Activated:Connect(function()
	runJob("Generate props", function(modules)
		local plan = getPlan(modules)

		log("Props are generated with sections for this block-map version.")
		modules.BlockMapWriter.generate(plan, {
			ShowAnchors = state.ShowAnchors,
			ShowZoneBounds = state.ShowZoneBounds,
		}, function(done, total, zoneId)
			log("Generated section " .. tostring(zoneId) .. " (" .. tostring(done) .. "/" .. tostring(total) .. ")")
		end)
	end)
end)

clearMapButton.Activated:Connect(function()
	runJob("Clear generated map", function(modules)
		modules.AnchorExporter.clearGeneratedInstances()
	end)
end)

clearGeneratedButton.Activated:Connect(function()
	runJob("Clear generated", function(modules)
		modules.AnchorExporter.clearGeneratedInstances()
	end)
end)

validateButton.Activated:Connect(function()
	runJob("Validate map", function(modules)
		validateAndLog(modules, getPlan(modules))
	end)
end)

exportButton.Activated:Connect(function()
	runJob("Export anchors", function(modules)
		local moduleScript, err = modules.AnchorExporter.exportAnchorConfigModule(modules.AnchorExporter.getOutputRoot())

		if moduleScript ~= nil then
			log("Exported anchors to " .. moduleScript:GetFullName() .. ".")
		else
			log(err or "Anchor export failed.")
		end
	end)
end)

analyzeReferencesButton.Activated:Connect(function()
	runJob("Analyze reference props", function(modules)
		local referenceRoot, rootErr = modules.ReferencePropAnalyzer.getReferenceRoot()

		if referenceRoot == nil then
			log(rootErr or "ReferenceProps folder was not found.")
			return
		end

		local analysis = modules.ReferencePropAnalyzer.analyze(referenceRoot)

		for _, line in ipairs(modules.ReferencePropAnalyzer.formatSummary(analysis)) do
			log(line)
		end

		local exportRoot, exportErr, exportDetails = modules.ReferencePropAnalyzer.exportBlueprintModule(analysis)

		if exportRoot ~= nil then
			local moduleCount = #exportRoot:GetChildren()

			if exportDetails ~= nil then
				moduleCount = exportDetails.TotalModules
			end

			log("Exported reference blueprints to " .. exportRoot:GetFullName() .. " (" .. tostring(moduleCount) .. " modules).")
			log("Open " .. exportRoot:GetFullName() .. ".Index for the summary; each Reference_* child has full part offsets.")
		else
			log(exportErr or "Reference blueprint export failed.")
		end
	end)
end)

toolbarButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toolbarButton:SetActive(widget.Enabled)
end)

log("Ready. Sync source modules, then Generate All to build block sections.")
