local ClientUiSignals = {}

local ascensionRequested = Instance.new("BindableEvent")

function ClientUiSignals.requestAscension()
	ascensionRequested:Fire()
end

function ClientUiSignals.onAscensionRequested(callback)
	return ascensionRequested.Event:Connect(callback)
end

return ClientUiSignals
