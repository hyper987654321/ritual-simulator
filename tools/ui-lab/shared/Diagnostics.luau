local Diagnostics = {}
local function overlap(a, b)
	return a.AbsolutePosition.X < b.AbsolutePosition.X + b.AbsoluteSize.X
		and a.AbsolutePosition.X + a.AbsoluteSize.X > b.AbsolutePosition.X
		and a.AbsolutePosition.Y < b.AbsolutePosition.Y + b.AbsoluteSize.Y
		and a.AbsolutePosition.Y + a.AbsoluteSize.Y > b.AbsolutePosition.Y
end
function Diagnostics.inspect(screenGui)
	local report = { Passed = {}, Warnings = {}, Errors = {} }
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.zero
	if viewport.X > 0 and viewport.Y > 0 then
		table.insert(report.Passed, string.format("Viewport bounds %dx%d are discoverable.", viewport.X, viewport.Y))
	else table.insert(report.Errors, "Viewport bounds are unavailable.") end
	local panels = {}
	for _, instance in screenGui:GetDescendants() do
		if instance:IsA("GuiObject") then
			if instance.AbsoluteSize.X <= 0 or instance.AbsoluteSize.Y <= 0 then table.insert(report.Warnings, instance.Name .. " has a blank layout size.") end
			if instance.Name == "SafeArea" or instance.Name == "Diagnostics" or string.sub(instance.Name, 1, 4) == "Card" or instance.Name == "Anatomy" then table.insert(panels, instance) end
			if (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) and instance.Text == "" and instance:GetAttribute("AllowBlank") ~= true then
				table.insert(report.Warnings, instance.Name .. " has missing text content.")
			elseif (instance:IsA("ImageLabel") or instance:IsA("ImageButton")) and instance.Image == "" and instance:GetAttribute("AllowBlank") ~= true then
				table.insert(report.Warnings, instance.Name .. " has missing image content.")
			end
		end
	end
	for index, panel in panels do
		for otherIndex = index + 1, #panels do if overlap(panel, panels[otherIndex]) then table.insert(report.Warnings, "Root panels overlap: " .. panel.Name .. " / " .. panels[otherIndex].Name) end end
	end
	if #panels > 0 then table.insert(report.Passed, string.format("Checked %d root panel bounds and overlap relationships.", #panels)) end
	local highest = -math.huge
	for _, instance in screenGui:GetDescendants() do
		if instance:IsA("GuiObject") and instance.Visible then highest = math.max(highest, instance.ZIndex) end
	end
	table.insert(report.Passed, "Visible ZIndex relationships inspected through the highest visible layer (" .. tostring(highest) .. ").")
	return report
end
return Diagnostics
