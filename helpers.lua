---table_unpack unpacks interleaving keys and values as table
--- {1='a', 2='b', 3='c'} becomes {'a'='b'}, (uneven args are omitted)
---@param t table
function table_unpack(t)
	if type(t) ~= 'table' then
		return t
	end

	local i = 0
	local ret = {}
	local pv

	for _, v in pairs(t) do
		i = i + 1
		if i % 2 == 0 then
			ret[pv] = table_unpack(v)
		end

		pv = v
	end

	return ret
end

local unpack = table.unpack or unpack

---read_file reads file to string
---@param path string
function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

---split splits string `s` by delimiter `c`
---@param s string
---@param c string
function split(s, c)
	local t = {}
	for v in string.gmatch(s, '([^'.. c ..']+)') do
		table.insert(t, v)
	end

	if #t == 1 then
		return {s}
	end

	return unpack(t)
end


---@param t table
---@param cnt number|nil
local function _print_table(t, cnt)
    local off = string.rep('\t', cnt)

    if t == nil then
        io.write(off, '(nil)\n')
        return
    end

	for k, v in pairs(t) do
		if type(v) == "table" and k ~= "__index" then
			io.write(off, tostring(k), '\n')
			_print_table(v, cnt + 1)
		else
			io.write(off, tostring(k), '\t', tostring(v), '\n')
		end
	end
end

---info prints info
function info(...)
    io.stdout:write(..., '\n')
end

---print_table prints table recursively
---@param t table
function print_table(t)
    _print_table(t, 0)
end

