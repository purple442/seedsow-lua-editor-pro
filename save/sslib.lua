-- sslib.lua: Seedsow Lullaby Research & Introspection Library (Lua 5.1 compatible)
local M = {}

function M.safe_tostring(v)
    local ok, s = pcall(tostring, v)
    if ok and type(s) == 'string' then return s end
    return '<' .. type(v) .. '>'
end

function M.hexdump(data, start_offset, max_bytes)
    if type(data) ~= 'string' then return 'Not a string (' .. type(data) .. ')' end
    local start_at = math.max(0, tonumber(start_offset) or 0)
    local count = math.min(#data - start_at, tonumber(max_bytes) or 256)
    if count <= 0 then return '(empty range)' end
    local rows = {}
    for off = start_at, start_at + count - 1, 16 do
        local chunk = data:sub(off + 1, math.min(start_at + count, off + 16))
        local hex = {}
        for i = 1, #chunk do
            hex[#hex + 1] = string.format('%02X', chunk:byte(i))
        end
        local ascii = chunk:gsub('[^ -~]', '.')
        rows[#rows + 1] = string.format('%06X  %-47s  |%s|', off, table.concat(hex, ' '), ascii)
    end
    return table.concat(rows, '\n')
end

function M.func_info(fn)
    if type(fn) ~= 'function' then return M.safe_tostring(fn) end
    if not (debug and debug.getinfo) then return M.safe_tostring(fn) end
    local ok, info = pcall(debug.getinfo, fn, 'Slnu')
    if not ok or type(info) ~= 'table' then return M.safe_tostring(fn) end
    local what = info.what or '?'
    local src = info.short_src or info.source or '?'
    local line = info.linedefined and info.linedefined >= 0 and (':' .. tostring(info.linedefined)) or ''
    local nups = info.nups and (' ups=' .. tostring(info.nups)) or ''
    return string.format('[%s %s%s%s]', what, src, line, nups)
end

function M.inspect_table(tbl, max_items)
    if type(tbl) ~= 'table' then return {M.safe_tostring(tbl)} end
    local limit = tonumber(max_items) or 200
    local keys = {}
    for k in pairs(tbl) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        if ta == 'number' or ta == 'string' then return a < b end
        return M.safe_tostring(a) < M.safe_tostring(b)
    end)
    local out = {}
    for i = 1, math.min(#keys, limit) do
        local k = keys[i]
        local v = tbl[k]
        local vt = type(v)
        local desc
        if vt == 'function' then
            desc = M.func_info(v)
        elseif vt == 'string' then
            local clean = v:gsub('[\r\n\t]', ' ')
            if #clean > 60 then clean = clean:sub(1, 57) .. '...' end
            desc = string.format('%q (%d B)', clean, #v)
        elseif vt == 'table' then
            local count = 0
            pcall(function() for _ in pairs(v) do count = count + 1 end end)
            desc = string.format('table (%d keys)', count)
        else
            desc = M.safe_tostring(v)
        end
        out[#out + 1] = string.format('  %-28s = (%s) %s', M.safe_tostring(k), vt, desc)
    end
    if #keys > limit then
        out[#out + 1] = string.format('  ... (%d more entries omitted)', #keys - limit)
    end
    return out
end

function M.scan_globals()
    local lines = {}
    lines[#lines + 1] = '=== SEEDSOW LULLABY / ARTEMIS ENGINE GLOBAL ENVIRONMENT REPORT ==='
    lines[#lines + 1] = 'Lua Version: ' .. tostring(_VERSION)
    if collectgarbage then
        local ok, kb = pcall(collectgarbage, 'count')
        if ok then lines[#lines + 1] = string.format('Lua Memory Usage: %.2f KiB', tonumber(kb) or 0) end
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = '--- 1. TOP-LEVEL _G ENTRIES ---'
    local g_rows = M.inspect_table(_G, 300)
    for _, r in ipairs(g_rows) do lines[#lines + 1] = r end

    local interesting = {'pluto', 'sys', 'init', 'game', 'csv', 'debug', 'package', 'io', 'os', 'coroutine'}
    for _, name in ipairs(interesting) do
        local tbl = rawget(_G, name)
        if type(tbl) == 'table' then
            lines[#lines + 1] = ''
            lines[#lines + 1] = '--- TABLE: _G.' .. name .. ' ---'
            for _, r in ipairs(M.inspect_table(tbl, 150)) do lines[#lines + 1] = r end
        end
    end
    return table.concat(lines, '\n')
end

function M.scan_engine(e)
    local lines = {}
    lines[#lines + 1] = '=== ARTEMIS ENGINE & LUAPONTE OBJECT REPORT ==='
    lines[#lines + 1] = 'Engine Value: ' .. M.safe_tostring(e) .. ' (type: ' .. type(e) .. ')'
    if debug and debug.getmetatable then
        local mt = debug.getmetatable(e)
        if type(mt) == 'table' then
            lines[#lines + 1] = ''
            lines[#lines + 1] = '--- Engine Metatable (debug.getmetatable(engine)) ---'
            for _, r in ipairs(M.inspect_table(mt, 200)) do lines[#lines + 1] = r end
            for k, v in pairs(mt) do
                if type(v) == 'table' then
                    lines[#lines + 1] = ''
                    lines[#lines + 1] = '--- Engine Metatable Subtable: ' .. M.safe_tostring(k) .. ' ---'
                    for _, r in ipairs(M.inspect_table(v, 200)) do lines[#lines + 1] = r end
                elseif type(v) == 'function' and debug.getupvalue then
                    lines[#lines + 1] = ''
                    lines[#lines + 1] = '--- Upvalues of Metatable Function: ' .. M.safe_tostring(k) .. ' ---'
                    for idx = 1, 20 do
                        local uname, uval = debug.getupvalue(v, idx)
                        if not uname then break end
                        lines[#lines + 1] = string.format('  upvalue[%d] %s = (%s) %s', idx, tostring(uname), type(uval), M.safe_tostring(uval))
                        if type(uval) == 'table' then
                            for _, r in ipairs(M.inspect_table(uval, 150)) do lines[#lines + 1] = '    ' .. r end
                        end
                    end
                end
            end
        else
            lines[#lines + 1] = 'Metatable: ' .. M.safe_tostring(mt)
        end
    end

    lines[#lines + 1] = ''
    lines[#lines + 1] = '--- Engine Variables (e:var probes) ---'
    local vars = {
        's.savepath', 's.scriptpath', 's.systempath', 's.rootpath', 's.datapath',
        's.platform', 's.version', 's.title', 's.language', 's.lang',
        'g.system', 't.ssedit_input', 't.ssedit_measure'
    }
    for _, vname in ipairs(vars) do
        local ok, val = pcall(function() return e:var(vname) end)
        if ok and val ~= nil and val ~= '' then
            local s = M.safe_tostring(val)
            if #s > 80 then s = s:sub(1, 77) .. '... (' .. #s .. ' B)' end
            lines[#lines + 1] = string.format('  e:var(%q) = %s', vname, s)
        else
            lines[#lines + 1] = string.format('  e:var(%q) = <nil/empty>', vname)
        end
    end
    return table.concat(lines, '\n')
end

function M.scan_registry()
    local lines = {}
    lines[#lines + 1] = '=== LUA REGISTRY (debug.getregistry()) REPORT ==='
    if not (debug and debug.getregistry) then
        lines[#lines + 1] = 'debug.getregistry is not available.'
        return table.concat(lines, '\n')
    end
    local ok, reg = pcall(debug.getregistry)
    if not ok or type(reg) ~= 'table' then
        lines[#lines + 1] = 'Failed to read registry: ' .. M.safe_tostring(reg)
        return table.concat(lines, '\n')
    end
    for _, r in ipairs(M.inspect_table(reg, 250)) do lines[#lines + 1] = r end
    for k, v in pairs(reg) do
        if type(v) == 'table' and v ~= _G and v ~= package and v ~= reg then
            lines[#lines + 1] = ''
            lines[#lines + 1] = '--- Registry Subtable [' .. M.safe_tostring(k) .. '] ---'
            for _, r in ipairs(M.inspect_table(v, 100)) do lines[#lines + 1] = r end
        end
    end
    return table.concat(lines, '\n')
end

function M.list_save_files(e, base)
    local candidates = {
        'pro_editor.lua', 'sslib.lua',
        'sscode004.lua', 'sscode005.lua', 'sscode006.lua', 'sscode007.lua', 'sscode008.lua',
        'ssdemo-blue.lua',
        'report_env.txt', 'report_engine.txt', 'report_registry.txt', 'report_files.txt', 'report_vm.txt',
        'crash_log.txt', 'ed004-session.txt', 'ed004-files.txt', 'ed004-clipboard.txt',
        'ssedit-session.txt', 'ssedit-controls.txt', 'ssedit-input-report.txt', 'ssedit-transfer-report.txt',
        'saveg.dat', 'system.dat', 'autosave.dat',
        'save0001.dat', 'save0002.dat', 'save0003.dat', 'save0004.dat', 'save0005.dat',
        'save0006.dat', 'save0007.dat', 'save0008.dat', 'save0121.dat',
        'sed01.asb', 'sed02.asb', 'sed03.asb', 'ss004.asb', 'ss005.asb', 'ss006.asb', 'ss007.asb', 'ss008.asb',
        'ssedit1.lua', 'ssedit2.lua', 'ssedit3.lua'
    }
    -- Add user slots 9..30 if present
    for i = 9, 30 do
        candidates[#candidates + 1] = string.format('sscode%03d.lua', i)
    end
    -- Also read custom file index if present
    local idx_f = io.open(base .. '/ed004-files.txt', 'rb')
    if idx_f then
        local idx_data = idx_f:read('*a') or ''
        idx_f:close()
        for line in idx_data:gmatch('[^\r\n]+') do
            if line ~= '' then candidates[#candidates + 1] = line end
        end
    end
    local seen = {}
    local found = {}
    for _, name in ipairs(candidates) do
        if not seen[name] then
            seen[name] = true
            local f = io.open(base .. '/' .. name, 'rb')
            if f then
                local size = f:seek('end') or 0
                f:close()
                found[#found + 1] = {name = name, size = size}
            end
        end
    end
    return found
end

return M
