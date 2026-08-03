local NumberFormatter = {}

local SUFFIXES = {
	{ Value = 1_000_000_000, Suffix = "B" },
	{ Value = 1_000_000, Suffix = "M" },
	{ Value = 1_000, Suffix = "K" },
}

local LOWER_SUFFIXES = {
	{ Value = 1_000_000_000, Suffix = "b" },
	{ Value = 1_000_000, Suffix = "m" },
	{ Value = 1_000, Suffix = "k" },
}

local function trimTrailingZero(text)
	local trimmed = string.gsub(text, "%.0$", "")

	return trimmed
end

function NumberFormatter.compact(value)
	local numberValue = tonumber(value) or 0

	for _, suffix in ipairs(SUFFIXES) do
		if math.abs(numberValue) >= suffix.Value then
			local shortened = numberValue / suffix.Value

			if shortened >= 100 then
				return string.format("%d%s", math.floor(shortened), suffix.Suffix)
			end

			return string.format("%.1f%s", shortened, suffix.Suffix)
		end
	end

	return tostring(math.floor(numberValue + 0.5))
end

function NumberFormatter.compactLower(value)
	local numberValue = tonumber(value) or 0

	for _, suffix in ipairs(LOWER_SUFFIXES) do
		if math.abs(numberValue) >= suffix.Value then
			local shortened = numberValue / suffix.Value

			if math.abs(shortened) >= 100 then
				return string.format("%d%s", math.floor(shortened), suffix.Suffix)
			end

			return trimTrailingZero(string.format("%.1f", shortened)) .. suffix.Suffix
		end
	end

	return tostring(math.floor(numberValue + 0.5))
end

function NumberFormatter.decimal(value, places)
	local numberValue = tonumber(value) or 0
	local decimals = places or 1

	return string.format("%." .. tostring(decimals) .. "f", numberValue)
end

return NumberFormatter
