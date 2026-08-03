local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local AnimatedScaleButton = {}

local DEFAULT_HOVER_SCALE = 1.05
local DEFAULT_PRESS_SCALE = 0.95
local DEFAULT_HOVER_TWEEN_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DEFAULT_REST_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function mergeProps(baseProps, extraProps)
	local props = {}

	for key, value in pairs(baseProps or {}) do
		props[key] = value
	end

	for key, value in pairs(extraProps or {}) do
		props[key] = value
	end

	return props
end

local function copyChildren(children)
	local result = {}

	for key, value in pairs(children or {}) do
		result[key] = value
	end

	return result
end

local function AnimatedScaleButtonComponent(props)
	local resolvedProps = props or {}
	local buttonProps = resolvedProps.ButtonProps or {}
	local contentChildren = copyChildren(resolvedProps.Children)
	local scaleRef = React.useRef(nil)
	local activeTweenRef = React.useRef(nil)
	local existingActivated = buttonProps[React.Event.Activated]
	local existingMouseEnter = buttonProps[React.Event.MouseEnter]
	local existingMouseLeave = buttonProps[React.Event.MouseLeave]
	local existingMouseButton1Down = buttonProps[React.Event.MouseButton1Down]
	local existingMouseButton1Up = buttonProps[React.Event.MouseButton1Up]
	local hoverScale = resolvedProps.HoverScale or DEFAULT_HOVER_SCALE
	local pressScale = resolvedProps.PressScale or DEFAULT_PRESS_SCALE
	local hoverTweenInfo = resolvedProps.HoverTweenInfo or DEFAULT_HOVER_TWEEN_INFO
	local restTweenInfo = resolvedProps.RestTweenInfo or DEFAULT_REST_TWEEN_INFO

	local function tweenScale(targetScale)
		local scale = scaleRef.current

		if scale == nil or resolvedProps.Animate == false then
			return
		end

		local activeTween = activeTweenRef.current

		if activeTween ~= nil then
			activeTween:Cancel()
			activeTweenRef.current = nil
		end

		local tweenInfo = if targetScale > 1 then hoverTweenInfo else restTweenInfo
		local tween = TweenService:Create(scale, tweenInfo, {
			Scale = targetScale,
		})

		activeTweenRef.current = tween
		tween:Play()
	end

	React.useEffect(function()
		return function()
			local activeTween = activeTweenRef.current

			if activeTween ~= nil then
				activeTween:Cancel()
				activeTweenRef.current = nil
			end
		end
	end, {})

	contentChildren.AnimatedScale = React.createElement("UIScale", {
		ref = scaleRef,
		Scale = resolvedProps.InitialScale or 1,
	})

	local resolvedButtonProps = mergeProps({
		Active = true,
		AutoButtonColor = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
	}, buttonProps)

	resolvedButtonProps[React.Event.Activated] = existingActivated

	resolvedButtonProps[React.Event.MouseEnter] = function(...)
		tweenScale(hoverScale)

		if existingMouseEnter ~= nil then
			existingMouseEnter(...)
		end
	end

	resolvedButtonProps[React.Event.MouseLeave] = function(...)
		tweenScale(1)

		if existingMouseLeave ~= nil then
			existingMouseLeave(...)
		end
	end

	resolvedButtonProps[React.Event.MouseButton1Down] = function(...)
		tweenScale(pressScale)

		if existingMouseButton1Down ~= nil then
			existingMouseButton1Down(...)
		end
	end

	resolvedButtonProps[React.Event.MouseButton1Up] = function(...)
		tweenScale(hoverScale)

		if existingMouseButton1Up ~= nil then
			existingMouseButton1Up(...)
		end
	end

	return React.createElement(resolvedProps.ClassName or "TextButton", resolvedButtonProps, {
		AnimatedContent = React.createElement("Frame", {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = resolvedProps.ContentZIndex or resolvedButtonProps.ZIndex,
		}, contentChildren),
	})
end

function AnimatedScaleButton.create(props)
	return React.createElement(AnimatedScaleButtonComponent, props)
end

return AnimatedScaleButton
