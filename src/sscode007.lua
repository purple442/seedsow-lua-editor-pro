-- Slot 7: Lua VM, Pluto & Debug Capabilities Diagnostics
if debug and debug.sethook then debug.sethook() end
local lib = require('sslib')

local lines = {}
lines[#lines + 1] = '=== LUA VM & DEBUG DIAGNOSTICS REPORT ==='
lines[#lines + 1] = 'Lua _VERSION: ' .. tostring(_VERSION)
if collectgarbage then
    lines[#lines + 1] = string.format('GC Memory in use: %.2f KiB', collectgarbage('count') or 0)
end
lines[#lines + 1] = ''
lines[#lines + 1] = '--- 1. DEBUG LIBRARY CAPABILITIES ---'
if type(debug) == 'table' then
    for _, r in ipairs(lib.inspect_table(debug, 50)) do lines[#lines + 1] = r end
else
    lines[#lines + 1] = 'debug table not present'
end

lines[#lines + 1] = ''
lines[#lines + 1] = '--- 2. PLUTO SERIALIZATION LIBRARY ---'
if type(pluto) == 'table' then
    for _, r in ipairs(lib.inspect_table(pluto, 50)) do lines[#lines + 1] = r end
else
    lines[#lines + 1] = 'pluto table not present'
end

lines[#lines + 1] = ''
lines[#lines + 1] = '--- 3. PACKAGE.LOADED MODULES ---'
if package and type(package.loaded) == 'table' then
    for _, r in ipairs(lib.inspect_table(package.loaded, 100)) do lines[#lines + 1] = r end
end

local report = table.concat(lines, '\n') .. '\n'
editor.write('report_vm.txt', report)

print('=== VM & DEBUG DIAGNOSTICS COMPLETE ===')
print('Saved report_vm.txt (' .. #report .. ' bytes).')
print('Open report_vm.txt in the editor to inspect.')
print('Press B to return to the editor.')
