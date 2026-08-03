local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local RitualRushConfig = require(Config:WaitForChild("RitualRushConfig"))

local RitualRushProgress = {}

function RitualRushProgress.ensureProgress(profile)
	if profile == nil then
		return nil
	end

	profile.RitualRush = RitualRushConfig.reconcileProgress(profile.RitualRush)

	return profile.RitualRush
end

function RitualRushProgress.awardPoints(profile, source, sourceCount)
	local progress = RitualRushProgress.ensureProgress(profile)

	if progress == nil then
		return 0
	end

	local pointsPerSource = RitualRushConfig.getPointAmount(source)

	if pointsPerSource == nil or pointsPerSource <= 0 then
		return 0
	end

	local count = 1

	if typeof(sourceCount) == "number" then
		count = math.floor(sourceCount)
	end

	if count <= 0 then
		return 0
	end

	local awardedPoints = pointsPerSource * count
	progress.Points += awardedPoints

	return awardedPoints
end

return RitualRushProgress
