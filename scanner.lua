Scanner = {}

local _ = require('helpers')
local export_template = 'return {init = init, reduce = reduce, map = map, scan_should_stop = scan_should_stop, finish = finish}'
local unpack = table.unpack or unpack

function Scanner:new(t)
	self.script_name = t.script_name
    self.hosts = t.hosts
    self.keys_per_scan = t.keys_per_scan
    self.max_scans = t.max_scans

    self.shards = {}
    self.funcs = {
        init = nil,
        reduce = nil,
        should_stop = nil,
        finish = nil,
    }

    return self
end

function Scanner:connect()
    local r = require('redis')
	info('connect to shards...')

    self.shards = {}
    for _, v in pairs(self.hosts) do
        local host, port = split(v, ':')
        local conn = r.connect(host, port)
        table.insert(self.shards, { conn = conn, name = v })
    end
end

function Scanner:ping()
    for _, v in pairs(self.shards) do
        info(v.name, v.conn:ping())
    end
end

function Scanner:load_script(txt)
	info('loading scripts...')
    local s = '"' .. string.gsub(txt, '\n', '\r') .. '"'

    local sha = ''
    for _, v in pairs(self.shards) do
        sha = v.conn:raw_cmd('script load ' .. s)
    end

    self.sha = sha
end

function Scanner:load_reducer(fname)
    local funcs_txt = read_file(fname)

   	local r
    local _, err = pcall(function()
		local rcode = load(funcs_txt .. export_template)
		r = rcode()
    end)

	if not r then
		error(string.format("check script:\n\t%s\ncheck file by running:\n \tlua %s\n", err, self.script_name))
	end

    self:validate_reducer(r)

    self.funcs = {
        init = r.init,
        reduce = r.reduce,
        should_stop = r.should_stop,
        finish = r.finish,
    }

    local server_txt = read_file('template.lua')
    local script_txt =  funcs_txt .. '\r' .. server_txt

    self:load_script(script_txt)
end

function Scanner:validate_reducer(x)
    if x.init == nil then
        error('file must contain `init` func')
    end
    if x.reduce == nil then
        error('file must contain `reduce` func')
    end
    if x.map == nil then
        error('file must contain `map` func')
    end
    return
end

---run_script
---@param conn any
---@param args table
---@return number, table, number
function Scanner:run_script(conn, args)
    local cmd = string.format('evalsha %s 0 %s', self.sha, table.concat(args, ' '))
    local resp = conn:raw_cmd(cmd)
    local offset, ret, processed_keys = table.unpack(resp)

    return offset, ret, processed_keys
end

function Scanner:scan_loop()
    local total_keys = 0
	local eval_calls = 0
    local result = self.funcs.init()

    local offset = 0
    local ret = {}
    local processed_keys = 0

    for _, shard in pairs(self.shards) do
		local shard_eval_calls = 0
    	local shard_keys = 0
   		local acc = self.funcs.init()

        info('scan shard', shard.name)
        while true do
            offset, ret, processed_keys = self:run_script(shard.conn, {
                offset, self.keys_per_scan, self.max_scans,
            })
            shard_eval_calls = shard_eval_calls + 1
            eval_calls = eval_calls + 1

            shard_keys = shard_keys + processed_keys
            total_keys = total_keys + processed_keys

            if eval_calls % 100 == 0 then
				info(tostring(shard_keys) .. '->')
			end

            acc = self.funcs.reduce(acc, table_unpack(ret))
            if offset == '0' then
                break
            end

            if self.funcs.should_stop ~= nil and self.funcs.should_stop(acc, shard_keys) then
                break
            end
        end

        acc.totalKeys = shard_keys
        acc.evalCalls = shard_eval_calls

        if #self.shards>1 then
			info('done\n')
			print_table(acc)
		end

        result = self.funcs.reduce(result, acc)
    end

	result.totalKeys = total_keys
	result.evalCalls = eval_calls
    return result
end

function Scanner:scan()
    self:connect()

    self:load_reducer(self.script_name)
    info(string.format('loaded script %s as %s', self.script_name, self.sha))

    local result = self:scan_loop()
    info('scan finished')

	if self.funcs.finish ~= nil then
		self.funcs.finish(result)
	else
		print_table(result)
	end
end
