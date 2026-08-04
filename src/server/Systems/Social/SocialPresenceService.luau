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

function SocialPresenceService:_notify(player)
	if typeof(self.Callbacks.publishSocial) == "function" then
		self.Callbacks.publishSocial(player)
	end
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
	local withProfileLock = self.Callbacks.withProfileLock
	local grant = self.Callbacks.grantReward
	local saveConfirmed = self.Callbacks.saveConfirmed
	if typeof(withProfileLock) ~= "function"
		or typeof(grant) ~= "function"
		or typeof(saveConfirmed) ~= "function"
	then
		return false
	end

	local awardedProfile = nil
	local ok, saved = pcall(withProfileLock, player, function(lockedProfile)
		if typeof(lockedProfile) ~= "table" then return false end
		local social = if typeof(lockedProfile.Social) == "table" then lockedProfile.Social else {}
		lockedProfile.Social = social
		if social.FirstCoPlayRewarded == true then return false end
		local grantedOk, granted = pcall(grant, player, lockedProfile, REWARD_GEMS)
		if not grantedOk or granted == false then return false end
		social.FirstCoPlayRewarded = true
		local saveOk, confirmed = pcall(saveConfirmed, player, lockedProfile, function(data)
			return typeof(data) == "table"
				and typeof(data.Social) == "table"
				and data.Social.FirstCoPlayRewarded == true
		end)
		if not saveOk or confirmed ~= true then return false end
		awardedProfile = lockedProfile
		return true
	end)
	if not ok or saved ~= true then return false end
	if typeof(self.Callbacks.publishReward) == "function" then
		self.Callbacks.publishReward(player, awardedProfile or profile, REWARD_GEMS)
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
			self:_notify(left)
			self:_notify(right)
			return
		end
		self:_award(left, leftProfile)
		self:_award(right, rightProfile)
		self:_cancel(state.Key)
		self:_notify(left)
		self:_notify(right)
	end)
end

function SocialPresenceService:_consider(left, right)
	if left == nil or right == nil or left == right then return end
	local key = pairKey(left, right)
	local pairState = self.Pairs[key]
	if pairState ~= nil and pairState.Kind == "timer" then return end
	local leftProfile, rightProfile = self:_profile(left), self:_profile(right)
	if not self:_ready(left, leftProfile) or not self:_ready(right, rightProfile)
		or not self:_hasRoll(left, leftProfile) or not self:_hasRoll(right, rightProfile) then return end
	local friendship = pairState
	if friendship == nil then
		friendship = {
			Kind = "friend",
			Left = left,
			Right = right,
			Result = self:_verifyFriendship(left, right),
		}
		self.Pairs[key] = friendship
	end
	if friendship.Result ~= true then return end
	local state = {
		Kind = "timer",
		Key = key,
		Left = left,
		Right = right,
		Generation = 1,
		ExpectedGeneration = 1,
		StartedAt = os.clock(),
	}
	self.Pairs[key] = state
	self:_schedule(left, right, state)
	self:_notify(left)
	self:_notify(right)
end

function SocialPresenceService:playerAdded(player)
	self.Players[player] = true
	for other in pairs(self.Players) do self:_consider(player, other) end
end

function SocialPresenceService:profileBecameEligible(player)
	task.defer(function()
		if self.Players[player] ~= true or player.Parent ~= Players then return end
		for other in pairs(self.Players) do self:_consider(player, other) end
	end)
end

SocialPresenceService.onFirstRoll = SocialPresenceService.profileBecameEligible

function SocialPresenceService:getSnapshot(player, profile)
	local social = if typeof(profile.Social) == "table" then profile.Social else {}
	local verifiedFriendCount = 0
	local remainingSeconds = if social.FirstCoPlayRewarded == true then 0 else REQUIRED_SECONDS
	for _, state in pairs(self.Pairs) do
		if state.Left == player or state.Right == player then
			if state.Kind == "friend" and state.Result == true or state.Kind == "timer" then verifiedFriendCount += 1 end
			if state.Kind == "timer" then
				remainingSeconds = math.min(remainingSeconds, math.max(0, REQUIRED_SECONDS - (os.clock() - state.StartedAt)))
			end
		end
	end
	return {
		VerifiedFriendCount = verifiedFriendCount,
		FirstCoPlayRewarded = social.FirstCoPlayRewarded == true,
		RequiredSeconds = REQUIRED_SECONDS,
		RemainingSeconds = remainingSeconds,
	}
end

function SocialPresenceService:playerRemoving(player)
	self.Players[player] = nil
	for key, state in pairs(self.Pairs) do
		if state.Left == player or state.Right == player then
			self:_cancel(key)
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
