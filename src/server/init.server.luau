local Systems = script:WaitForChild("Systems")

local LeaderboardService = require(Systems:WaitForChild("Leaderboard"):WaitForChild("LeaderboardService"))
local PlayerStateService = require(Systems:WaitForChild("Player"):WaitForChild("PlayerStateService"))
local RitualService = require(Systems:WaitForChild("Ritual"):WaitForChild("RitualService"))
local ShopPurchaseService = require(Systems:WaitForChild("Shop"):WaitForChild("ShopPurchaseService"))
local ZoneTravelService = require(Systems:WaitForChild("World"):WaitForChild("ZoneTravelService"))
local PetModelReplicationService = require(Systems:WaitForChild("World"):WaitForChild("PetModelReplicationService"))
local PlayerVisualReplicationService = require(Systems:WaitForChild("World"):WaitForChild("PlayerVisualReplicationService"))
local WorldService = require(Systems:WaitForChild("World"):WaitForChild("WorldService"))
local SnapshotPublisher = require(Systems:WaitForChild("Player"):WaitForChild("SnapshotPublisher"))
local ProfilePersistence = require(Systems:WaitForChild("Player"):WaitForChild("ProfilePersistence"))
local SocialPresenceService = require(Systems:WaitForChild("Social"):WaitForChild("SocialPresenceService"))
local Network = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Network"))

PetModelReplicationService.start()
PlayerStateService.start()
local playerStateUpdated = Network.getRemoteEvent(Network.RemoteEvents.PlayerStateUpdated)
local socialPresenceService = SocialPresenceService.new({
	getProfile = PlayerStateService.getProfile,
	isProfileReady = PlayerStateService.isCurrentProfile,
	hasLifetimeRoll = function(_player, profile) return (profile.Rolls or 0) > 0 end,
	withProfileLock = PlayerStateService.withProfileLock,
	grantReward = PlayerStateService.grantSocialReward,
	saveConfirmed = function(player, profile, predicate) return ProfilePersistence.saveConfirmed(player, profile, predicate) end,
	publishReward = function(player)
		SnapshotPublisher.publishPlayerStateUpdate(player, playerStateUpdated, { Social = true, RitualGems = true })
	end,
	publishSocial = function(player)
		SnapshotPublisher.publishPlayerStateUpdate(player, playerStateUpdated, { Social = true })
	end,
})
PlayerStateService.setSocialPresenceService(socialPresenceService)
socialPresenceService:start()
ShopPurchaseService.start()
WorldService.start()
ZoneTravelService.start()
PlayerVisualReplicationService.start()
LeaderboardService.start()
RitualService.start()
