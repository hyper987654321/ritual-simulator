local SeededRandom = {}

local MAX_SEED = 2147483647

function SeededRandom.normalizeSeed(seed)
	local numberSeed = if typeof(seed) == "number" then seed else tonumber(seed)

	if typeof(numberSeed) ~= "number" or numberSeed ~= numberSeed or math.abs(numberSeed) == math.huge then
		numberSeed = 1
	end

	numberSeed = math.floor(math.abs(numberSeed)) % MAX_SEED

	if numberSeed <= 0 then
		numberSeed = 1
	end

	return numberSeed
end

function SeededRandom.zoneSeed(baseSeed, zoneId, salt)
	local safeBase = SeededRandom.normalizeSeed(baseSeed)
	local safeZone = if typeof(zoneId) == "number" then math.floor(zoneId) else 0
	local safeSalt = if typeof(salt) == "number" then math.floor(salt) else 0

	return SeededRandom.normalizeSeed(safeBase * 1000003 + safeZone * 9176 + safeSalt * 131)
end

function SeededRandom.create(baseSeed, zoneId, salt)
	return Random.new(SeededRandom.zoneSeed(baseSeed, zoneId or 0, salt or 0))
end

return SeededRandom
