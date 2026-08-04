local UIBackgroundConfig = {}

UIBackgroundConfig.Backgrounds = {}

function UIBackgroundConfig.getBackground(backgroundId)
	return UIBackgroundConfig.Backgrounds[backgroundId]
end

return UIBackgroundConfig
