local _ = require('scanner')

local function main()
    -- exclude script name from args table
    arg[0] = nil
    arg[-1] = nil

    -- deinterleave args
    local args = table_unpack(arg)

    local script_name = args['-s']
    if not script_name then
    	error('no script name')
	end

    local hosts = split(args['-h'], ',')
    if not hosts or #hosts == 0 then
        error('incorrect host(s)')
    end

    -- reasonable defaults, script finishes in less than 5s
    local keys_per_scan = tonumber(args['-k']) or 1000
    local max_scans = tonumber(args['-m']) or 10

    local s = Scanner:new {
        hosts = hosts,
        max_scans = max_scans,
        keys_per_scan = keys_per_scan,
        script_name = script_name,
    }

    s:scan()
end

main()