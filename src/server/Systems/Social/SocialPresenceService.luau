local Players = game:GetService("Players")

local SocialPresenceService = {}
SocialPresenceService.__index = SocialPresenceService

local REQUIRED_SECONDS = 120
local REWARD_GEMS = 5

local function pairKey(left, right)
	local leftId, rightId = left.UserId, right.UserId
	if leftId > rightId then leftId, rightId = rightId, leftId end
	return tostring(leftId) .. ":" .. tostring(rightId)
end

local function safeFriendsWith(left, right)
	local ok, result = pcall(function()
		return left:IsFriendsWithAsync(right.UserId)
	end)
	return ok and result == true
end

local function finiteInteger(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.max(0, math.floor(value))
end

function SocialPresenceService.new(callbacks)
	local self = setmetatable({
		Callbacks = if typeof(callbacks) == "table" then callbacks else {},
		Pairs = {},
		Players = {},
		Started = false,
	}, SocialPresenceService)
	return self
end

function SocialPresenceService:_profile(player)
	local getProfile = self.Callbacks.getProfile
	return if typeof(getProfile) == "function" then getProfile(player) else nil
end

function SocialPresenceService:_ready(player, profile)
	if player == nil or player.Parent ~= Players or typeof(profile) ~= "table" then return false end
	if typeof(self.Callbacks.isProfileReady) == "function" then return self.Callbacks.isProfileReady(player, profile) == true end
	return true
end

function SocialPresenceService:_hasRoll(player, profile)
	if typeof(self.Callbacks.hasLifetimeRoll) == "function" then return self.Callbacks.hasLifetimeRoll(player, profile) == true end
	return finiteInteger(profile.Rolls) > 0
end

function SocialPresenceService:_verifyFriendship(left, right)
	if typeof(self.Callbacks.isFriend) == "function" then
		local ok, result = pcall(self.Callbacks.isFriend, left, right)
		return ok and result == true
	end
	return safeFriendsWith(left, right)
end

function SocialPresenceService:_cancel(key)
	local state = self.Pairs[key]
	if state ~= nil then state.Generation += 1 end
	self.Pairs[key] = nil
end

function SocialPresenceService:_award(player, profile)
	local social = if typeof(profile.Social) == "table" then profile.Social else {}
	profile.Social = social
	if social.FirstCoPlayRewarded == true then return false end
	local grant = self.Callbacks.grantReward
	if typeof(grant) == "function" then
		local ok, granted = pcall(grant, player, profile, REWARD_GEMS)
		if not ok or granted == false then return false end
	else
		profile.RitualGems = finiteInteger(profile.RitualGems) + REWARD_GEMS
	end
	social.FirstCoPlayRewarded = true
	if typeof(self.Callbacks.saveConfirmed) == "function" then
		local ok, saved = pcall(self.Callbacks.saveConfirmed, player, profile, function(data)
			return typeof(data) == "table" and typeof(data.Social) == "table" and data.Social.FirstCoPlayRewarded == true
		end)
		if not ok or saved ~= true then return false end
	end
	if typeof(self.Callbacks.publishReward) == "function" then
		self.Callbacks.publishReward(player, profile, REWARD_GEMS)
	end
	return true
end

function SocialPresenceService:_schedule(left, right, state)
	task.delay(REQUIRED_SECONDS, function()
		if self.Pairs[state.Key] ~= state or state.Generation ~= state.ExpectedGeneration then return end
		local leftProfile, rightProfile = self:_profile(left), self:_profile(right)
		if not self:_ready(left, leftProfile) or not self:_ready(right, rightProfile)
			or not self:_hasRoll(left, leftProfile) or not self:_hasRoll(right, rightProfile)
			or not self:_verifyFriendship(left, right)
		then
			self:_cancel(state.Key)
			return
		end
		self:_award(left, leftProfile)
		self:_award(right, rightProfile)
		self:_cancel(state.Key)
	end)
end

function SocialPresenceService:_consider(left, right)
	if left == nil or right == nil or left == right then return end
	local key = pairKey(left, right)
	if self.Pairs[key] ~= nil then return end
	local leftProfile, rightProfile = self:_profile(left), self:_profile(right)
	if not self:_ready(left, leftProfile) or not self:_ready(right, rightProfile)
		or not self:_hasRoll(left, leftProfile) or not self:_hasRoll(right, rightProfile) then return end
	local friendship = self.Pairs[key .. ":friend"]
	if friendship == nil then
		friendship = { Result = self:_verifyFriendship(left, right) }
		self.Pairs[key .. ":friend"] = friendship
	end
	if friendship.Result ~= true then return end
	local state = { Key = key, Generation = 1, ExpectedGeneration = 1 }
	self.Pairs[key] = state
	self:_schedule(left, right, state)
end

function SocialPresenceService:playerAdded(player)
	self.Players[player] = true
	for other in pairs(self.Players) do self:_consider(player, other) end
end

function SocialPresenceService:profileBecameEligible(player)
	for other in pairs(self.Players) do self:_consider(player, other) end
end

SocialPresenceService.onFirstRoll = SocialPresenceService.profileBecameEligible

function SocialPresenceService:playerRemoving(player)
	self.Players[player] = nil
	for key in pairs(self.Pairs) do
		if string.find(key, tostring(player.UserId), 1, true) ~= nil then
			self:_cancel(key)
			self.Pairs[key .. ":friend"] = nil
		end
	end
end

function SocialPresenceService:start()
	if self.Started then return end
	self.Started = true
	for _, player in ipairs(Players:GetPlayers()) do self:playerAdded(player) end
	self.JoinConnection = Players.PlayerAdded:Connect(function(player) self:playerAdded(player) end)
	self.LeaveConnection = Players.PlayerRemoving:Connect(function(player) self:playerRemoving(player) end)
end

function SocialPresenceService:stop()
	if self.JoinConnection then self.JoinConnection:Disconnect() end
	if self.LeaveConnection then self.LeaveConnection:Disconnect() end
	self.JoinConnection, self.LeaveConnection, self.Started = nil, nil, false
	for key in pairs(self.Pairs) do self:_cancel(key) end
	self.Players = {}
end

return SocialPresenceService
