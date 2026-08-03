local PathGenerator = {}

local function distanceToSegment2D(x, z, ax, az, bx, bz)
	local abX = bx - ax
	local abZ = bz - az
	local apX = x - ax
	local apZ = z - az
	local abLengthSquared = abX * abX + abZ * abZ

	if abLengthSquared <= 0.001 then
		local dx = x - ax
		local dz = z - az

		return math.sqrt(dx * dx + dz * dz)
	end

	local alpha = math.clamp((apX * abX + apZ * abZ) / abLengthSquared, 0, 1)
	local closestX = ax + abX * alpha
	local closestZ = az + abZ * alpha
	local dx = x - closestX
	local dz = z - closestZ

	return math.sqrt(dx * dx + dz * dz)
end

local function distance2D(a, x, z)
	local dx = x - a.X
	local dz = z - a.Z

	return math.sqrt(dx * dx + dz * dz)
end

local function makePathPoint(zonePlan)
	if zonePlan.TeleportPosition ~= nil then
		return zonePlan.TeleportPosition
	end

	if zonePlan.AscensionPosition ~= nil then
		return Vector3.new(zonePlan.BoundsCenter.X, zonePlan.Theme.BaseHeight, zonePlan.BoundsCenter.Z)
	end

	return Vector3.new(zonePlan.BoundsCenter.X, zonePlan.Theme.BaseHeight, zonePlan.BoundsCenter.Z)
end

function PathGenerator.create(zonePlans, preset)
	local points = {}
	local arenas = {}
	local unlocks = {}
	local teleport = nil
	local ascension = nil

	for _, zonePlan in ipairs(zonePlans) do
		table.insert(points, makePathPoint(zonePlan))

		if zonePlan.TeleportPosition ~= nil and teleport == nil then
			teleport = zonePlan.TeleportPosition
		end

		if zonePlan.AscensionPosition ~= nil then
			ascension = zonePlan.AscensionPosition
		end

		if zonePlan.UnlockWall ~= nil then
			table.insert(unlocks, {
				ZoneId = zonePlan.ZoneId,
				Position = zonePlan.UnlockWall.Center,
				Radius = preset.Path.UnlockRadius,
			})
		end

		for _, anchor in ipairs(zonePlan.CrystalAnchors) do
			table.insert(arenas, {
				ZoneId = zonePlan.ZoneId,
				Position = anchor.Position,
				Radius = anchor.Radius or preset.Path.CrystalArenaRadius,
			})
		end
	end

	local plan = {
		Points = points,
		Arenas = arenas,
		Unlocks = unlocks,
		Teleport = teleport,
		Ascension = ascension,
		MainWidth = preset.Path.MainWidth,
		Feather = preset.Path.Feather,
		TeleportRadius = preset.Path.TeleportRadius or preset.Path.SpawnRadius,
		AscensionRadius = preset.Path.AscensionRadius,
	}

	function plan:getDistanceToMainPath(x, z)
		local closest = math.huge

		for index = 1, math.max(#self.Points - 1, 0) do
			local a = self.Points[index]
			local b = self.Points[index + 1]

			closest = math.min(closest, distanceToSegment2D(x, z, a.X, a.Z, b.X, b.Z))
		end

		return closest
	end

	function plan:getDistanceToArena(x, z)
		local closest = math.huge
		local closestArena = nil

		for _, arena in ipairs(self.Arenas) do
			local distance = distance2D(arena.Position, x, z)

			if distance < closest then
				closest = distance
				closestArena = arena
			end
		end

		return closest, closestArena
	end

	function plan:isOnMainPath(x, z)
		return self:getDistanceToMainPath(x, z) <= self.MainWidth / 2
	end

	function plan:isInCrystalArena(x, z)
		local distance, arena = self:getDistanceToArena(x, z)

		return arena ~= nil and distance <= arena.Radius
	end

	function plan:isInTeleportArea(x, z)
		return self.Teleport ~= nil and distance2D(self.Teleport, x, z) <= self.TeleportRadius
	end

	function plan:isInSpawnArea(x, z)
		return self:isInTeleportArea(x, z)
	end

	function plan:isInAscensionArea(x, z)
		return self.Ascension ~= nil and distance2D(self.Ascension, x, z) <= self.AscensionRadius
	end

	function plan:getFlattenInfluence(x, z)
		local influence = 0
		local pathDistance = self:getDistanceToMainPath(x, z)
		local pathInner = self.MainWidth / 2
		local pathOuter = pathInner + self.Feather

		if pathDistance <= pathOuter then
			influence = math.max(influence, 1 - math.clamp((pathDistance - pathInner) / self.Feather, 0, 1))
		end

		local arenaDistance, arena = self:getDistanceToArena(x, z)

		if arena ~= nil then
			local arenaOuter = arena.Radius + self.Feather

			if arenaDistance <= arenaOuter then
				influence = math.max(influence, 1 - math.clamp((arenaDistance - arena.Radius) / self.Feather, 0, 1))
			end
		end

		if self.Teleport ~= nil then
			local teleportDistance = distance2D(self.Teleport, x, z)
			local teleportOuter = self.TeleportRadius + self.Feather

			if teleportDistance <= teleportOuter then
				influence = math.max(influence, 1 - math.clamp((teleportDistance - self.TeleportRadius) / self.Feather, 0, 1))
			end
		end

		if self.Ascension ~= nil then
			local ascensionDistance = distance2D(self.Ascension, x, z)
			local ascensionOuter = self.AscensionRadius + self.Feather

			if ascensionDistance <= ascensionOuter then
				influence = math.max(influence, 1 - math.clamp((ascensionDistance - self.AscensionRadius) / self.Feather, 0, 1))
			end
		end

		return math.clamp(influence, 0, 1)
	end

	return plan
end

return PathGenerator
