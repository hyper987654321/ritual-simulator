local RunService = game:GetService("RunService")

local PresentationAssetConfig = {}

local STUDIO_ONLY = RunService:IsStudio()

PresentationAssetConfig.LogicalIds = {
	PetRollRevealSound = "presentation.sound.pet_roll_reveal",
	ZoneUnlockedSound = "presentation.sound.zone_unlocked",
	ReleaseRing = "presentation.texture.release_ring",
	SealRibbon = "presentation.texture.seal_ribbon",
	SpiritCoreFlipbook = "presentation.texture.spirit_core_flipbook",
	SpiritWispFlipbook = "presentation.texture.spirit_wisp_flipbook",
}

local URIS = {
	[PresentationAssetConfig.LogicalIds.PetRollRevealSound] = "rbxasset://sounds/ritual-simulator/pet_roll_reveal.wav",
	[PresentationAssetConfig.LogicalIds.ZoneUnlockedSound] = "rbxasset://sounds/ritual-simulator/zone_unlocked.wav",
	[PresentationAssetConfig.LogicalIds.ReleaseRing] = "rbxasset://textures/ritual-simulator/vfx/release_ring.png",
	[PresentationAssetConfig.LogicalIds.SealRibbon] = "rbxasset://textures/ritual-simulator/vfx/seal_ribbon.png",
	[PresentationAssetConfig.LogicalIds.SpiritCoreFlipbook] = "rbxasset://textures/ritual-simulator/vfx/spirit_core_flipbook.png",
	[PresentationAssetConfig.LogicalIds.SpiritWispFlipbook] = "rbxasset://textures/ritual-simulator/vfx/spirit_wisp_flipbook.png",
}

function PresentationAssetConfig.resolve(logicalId)
	if not STUDIO_ONLY then
		return ""
	end

	return URIS[logicalId] or ""
end

function PresentationAssetConfig.isStudioLocal()
	return STUDIO_ONLY
end

return table.freeze(PresentationAssetConfig)
