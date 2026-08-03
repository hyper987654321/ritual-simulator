local PlayerPublicVisualSignal = {}

local listeners = {}

function PlayerPublicVisualSignal.fire(player, publicVisual)
	if publicVisual == nil then
		return
	end

	for listener in pairs(listeners) do
		local ok, err = pcall(listener, player, publicVisual)

		if not ok then
			warn("[PlayerPublicVisualSignal] Listener failed:", err)
		end
	end
end

function PlayerPublicVisualSignal.subscribe(listener)
	listeners[listener] = true

	return function()
		listeners[listener] = nil
	end
end

return PlayerPublicVisualSignal
