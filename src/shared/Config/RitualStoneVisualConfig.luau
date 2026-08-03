local RitualStoneConfig = require(script.Parent:WaitForChild("RitualStoneConfig"))

local RitualStoneVisualConfig = {}

RitualStoneVisualConfig.FollowOffset = Vector3.new(4.5, 3.2, 1.5)
RitualStoneVisualConfig.BodyColor = Color3.fromRGB(70, 67, 84)
RitualStoneVisualConfig.CoreBaseColor = Color3.fromRGB(126, 91, 255)
RitualStoneVisualConfig.RingColor = Color3.fromRGB(99, 219, 255)
RitualStoneVisualConfig.BodyBaseSize = Vector3.new(1.9, 3.1, 1.4)
RitualStoneVisualConfig.CoreBaseSize = Vector3.new(1.25, 1.25, 1.25)
RitualStoneVisualConfig.RingSize = Vector3.new(0.16, 3.2, 3.2)

function RitualStoneVisualConfig.getTier(rebirths)
	return math.floor((rebirths or 0) / 5)
end

function RitualStoneVisualConfig.getVisualState(snapshot)
	local stats = (snapshot and snapshot.StoneStats) or RitualStoneConfig.BaseStats
	local capacity = math.max(0, stats.Capacity or RitualStoneConfig.BaseStats.Capacity)
	local essence = (snapshot and snapshot.Essence) or 0
	local fillRatio = if capacity > 0 then math.clamp(essence / capacity, 0, 1) else 0
	local tier = RitualStoneVisualConfig.getTier((snapshot and snapshot.Rebirths) or 0)
	local coreScale = 1.05 + fillRatio * 0.55 + tier * 0.05
	local bodyScale = 1 + tier * 0.08

	return {
		BodySize = RitualStoneVisualConfig.BodyBaseSize * bodyScale,
		CoreSize = Vector3.new(coreScale, coreScale, coreScale),
		CoreColor = Color3.fromRGB(126 + math.floor(fillRatio * 70), 91 + math.floor(fillRatio * 90), 255),
		GlowBrightness = 1.5 + fillRatio * 2,
		RingTransparency = 0.36 - fillRatio * 0.18,
		FillRatio = fillRatio,
	}
end

return RitualStoneVisualConfig
