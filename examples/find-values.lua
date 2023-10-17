--[[
    Find all keys that have one of the values
--]]

local needles = {
    'aa',
    'bb'
}

--[[
	it is possible to do some preparation outside of init/map/reduce. This will be called once per request (reused across N scans).
]]--
local needle_set = {}
for _, l in ipairs(needles) do
    needle_set[l] = true
end

local function init()
	return {
        found_keys = {}
	}
end

local function reduce(acc, result)
    for k, _ in pairs(result.found_keys) do
        acc.found_keys[k] = true
    end

	return acc
end

local function map(keys)
	local values = redis.call('mget', unpack(keys));

    local found_keys = {}

    for i, v in ipairs(values) do
        if needle_set[v] ~= nil then
            found_keys[keys[i]] = true;
        end;
	end

	return {
        found_keys = found_keys
    }
end
