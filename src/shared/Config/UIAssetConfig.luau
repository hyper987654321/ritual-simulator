local RunService = game:GetService("RunService")

local UIAssetConfig = {}
local ROOT = "rbxasset://textures/ritual-simulator/ui/"

function UIAssetConfig.resolve(kind, name)
	if not RunService:IsStudio() or typeof(name) ~= "string" or name == "" then
		return ""
	end
	return ROOT .. kind .. "/" .. name .. ".png"
end

function UIAssetConfig.resolveIcon(name)
	return UIAssetConfig.resolve("icons", name)
end

function UIAssetConfig.resolveBackground(name)
	return UIAssetConfig.resolve("backgrounds", name)
end

return UIAssetConfig
