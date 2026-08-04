local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local AscensionConfig = require(Config:WaitForChild("AscensionConfig"))
local ProfileContract = require(Config:WaitForChild("ProfileContract"))
local RitualRushConfig = require(Config:WaitForChild("RitualRushConfig"))

local RitualRushProgress = {}

function RitualRushProgress.ensureProgress(profile, _nowUnix)
	if profile == nil then
		return nil
	end

	profile.RitualRush = RitualRushConfig.reconcileProgress(profile.RitualRush, _nowUnix)

	return profile.RitualRush
end

function RitualRushProgress.awardPoints(profile, source, sourceCount, nowUnix)
	local progress = RitualRushProgress.ensureProgress(profile, nowUnix)

	if progress == nil then
		return 0
	end

	local pointsPerSource = RitualRushConfig.getPointAmount(source)
	local sourceCap = RitualRushConfig.getSourceCap(source)

	if pointsPerSource == nil or pointsPerSource <= 0 or sourceCap == nil or sourceCap <= 0 then
		return 0
	end

	local count = 1

	if
		typeof(sourceCount) == "number"
		and sourceCount == sourceCount
		and math.abs(sourceCount) ~= math.huge
	then
		count = math.floor(sourceCount)
	end

	if count <= 0 then
		return 0
	end

	local currentSourcePoints = math.clamp(math.floor(progress.SourcePoints[source] or 0), 0, sourceCap)
	local availableSourcePoints = sourceCap - currentSourcePoints

	if availableSourcePoints <= 0 then
		return 0
	end

	local pointMultiplier = AscensionConfig.getStatBonuses(profile).RushPointsMultiplier
	local rawAward = pointsPerSource * count * pointMultiplier
	local boundedAward = if rawAward == rawAward and math.abs(rawAward) ~= math.huge
		then math.min(ProfileContract.MaximumExactInteger, math.floor(rawAward))
		else ProfileContract.MaximumExactInteger
	local awardedPoints = math.min(availableSourcePoints, boundedAward)

	if awardedPoints <= 0 then
		return 0
	end

	progress.SourcePoints[source] = currentSourcePoints + awardedPoints
	progress.Points = math.min(ProfileContract.MaximumExactInteger, progress.Points + awardedPoints)

	return awardedPoints
end

return RitualRushProgress
