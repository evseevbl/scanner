--[[
    Counts key length distribution
--]]

local function init()
	return {
        counters = {},
	}
end

local function reduce(acc, result)
	for k, v in pairs(result.counters) do
		acc.counters[k] = (acc.counters[k] or 0) + v
	end

	return acc
end

local function map(keys)
	local res = {}

	for _, k in pairs(keys) do
		res[#k] = (res[#k] or 0) + 1
	end

	return {
		counters = res,
	}
end
