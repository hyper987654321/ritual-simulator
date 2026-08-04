local Diagnostics = {}

local registeredRootPanels = {}

function Diagnostics.registerRootPanel(name)
	registeredRootPanels[name] = true
end

local function overlaps(a, b)
	return a.AbsolutePosition.X < b.AbsolutePosition.X + b.AbsoluteSize.X
		and a.AbsolutePosition.X + a.AbsoluteSize.X > b.AbsolutePosition.X
		and a.AbsolutePosition.Y < b.AbsolutePosition.Y + b.AbsoluteSize.Y
		and a.AbsolutePosition.Y + a.AbsoluteSize.Y > b.AbsolutePosition.Y
end

local function isOpaqueVisible(instance)
	return instance:IsA("GuiObject")
		and instance.Visible
		and instance.BackgroundTransparency < 1
end

local function checkContent(instance, report)
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		if instance.Text == "" and instance:GetAttribute("AllowBlank") ~= true then
			table.insert(report.Warnings, instance:GetFullName() .. " has missing text content.")
		end
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		if instance.Image == "" and instance:GetAttribute("AllowBlank") ~= true then
			table.insert(report.Warnings, instance:GetFullName() .. " has missing image content.")
		end
	end
end

local function checkAncestorZIndex(instance, storyRoot, report)
	local ancestor = instance.Parent
	while ancestor and ancestor ~= storyRoot do
		if isOpaqueVisible(ancestor) and instance.ZIndex < ancestor.ZIndex then
			table.insert(report.Warnings, string.format(
				"Global ZIndex: %s (%d) is below opaque ancestor %s (%d).",
				instance:GetFullName(),
				instance.ZIndex,
				ancestor:GetFullName(),
				ancestor.ZIndex
			))
		end
		ancestor = ancestor.Parent
	end
end

function Diagnostics.inspect(storyRoot)
	local report = { Passed = {}, Warnings = {}, Errors = {} }
	if not storyRoot or storyRoot.Name ~= "StoryRoot" then
		table.insert(report.Errors, "Diagnostics require a named StoryRoot design canvas.")
		return report
	end

	local screenGui = storyRoot:FindFirstAncestorOfClass("ScreenGui")
	if not screenGui or screenGui.ZIndexBehavior ~= Enum.ZIndexBehavior.Global then
		table.insert(report.Errors, "StoryRoot must be under a ScreenGui using Global ZIndexBehavior.")
	end

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.zero
	if viewport.X > 0 and viewport.Y > 0 then
		table.insert(report.Passed, string.format("Viewport bounds %dx%d are discoverable.", viewport.X, viewport.Y))
	else
		table.insert(report.Errors, "Viewport bounds are unavailable.")
	end

	local rootPanels = {}
	for _, instance in storyRoot:GetDescendants() do
		if instance:IsA("GuiObject") then
			checkContent(instance, report)
			checkAncestorZIndex(instance, storyRoot, report)
			if registeredRootPanels[instance.Name] then
				table.insert(rootPanels, instance)
			end
			if instance.AbsoluteSize.X <= 0 or instance.AbsoluteSize.Y <= 0 then
				table.insert(report.Warnings, instance:GetFullName() .. " has a blank layout size.")
			end
		end
	end

	for index, panel in rootPanels do
		for otherIndex = index + 1, #rootPanels do
			local other = rootPanels[otherIndex]
			local related = panel:IsAncestorOf(other) or other:IsAncestorOf(panel)
			if not related and overlaps(panel, other) then
				table.insert(report.Warnings, string.format("Registered root panels overlap: %s / %s.", panel:GetFullName(), other:GetFullName()))
			end
		end
	end

	table.insert(report.Passed, string.format("Inspected StoryRoot only: %d registered root panels.", #rootPanels))
	table.insert(report.Passed, "Checked visible content, bounds, containment-aware overlap, and Global ZIndex ancestry.")
	return report
end

return Diagnostics
