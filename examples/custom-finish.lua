--[[
    Does nothing and runs some user-specified code in the end
--]]

local function init()
    return {}
end

local function reduce(acc, result)
    return {
		result = {
			['foo'] = 'bar'
		}
    }
end

local function map(keys)
    return {}
end

local function should_stop(acc, keys)
    return true
end

local function finish(acc)
	-- we can use require to import anything we have locally
	local _ = require('helpers')
	print('running local code after scan')
	print_table(acc.result)
	return
end
