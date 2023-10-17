--[[
    Server template for scanning keys and applying map+reduce
--]]

--- redis_pack interleaves keys and values for transport
--- {a = 'b'} becomes {1 = a, 2 = b}
---@param t table
---@return table
local function redis_pack(t)
    if type(t) ~= 'table' then
        return t
    end

    local ret = {}
    for k, v in pairs(t) do
        table.insert(ret, k)
        table.insert(ret, redis_pack(v))
    end

    return ret
end

local first_offset = ARGV[1]
local scan_count = ARGV[2]
local max_calls = tonumber(ARGV[3])

local offset = first_offset
local acc = init()
local scanned_keys = 0
local calls = 0

local cmd_args = { }

pcall(function()
    if scan_type then
        table.insert(cmd_args, 'type')
        table.insert(cmd_args, scan_type)
    end
end)

pcall(function()
    if scan_match then
        table.insert(cmd_args, 'match')
        table.insert(cmd_args, scan_match)
    end
end)

while true do
    local ret = redis.call(
            'scan', offset,
            'count', scan_count,
            unpack(cmd_args)
    )

    offset = ret[1]
    local keys = ret[2]
    local diff = map(keys)

    acc = reduce(acc, diff)
    scanned_keys = scanned_keys + #keys

    local resp = { offset, redis_pack(acc), scanned_keys }

    if offset == '0' then
        return resp
    end

    calls = calls + 1
    if max_calls and calls >= max_calls then
        return resp
    end

    if scan_should_stop(acc, scanned_keys) then
        return resp
    end
end