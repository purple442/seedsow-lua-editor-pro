-- Slot 6: Save Directory & Engine Path Analyzer
if debug and debug.sethook then debug.sethook() end
local lib = require('sslib')
local base = e:var('s.savepath')

local lines = {}
lines[#lines + 1] = '=== SAVE DIRECTORY & ENGINE PATH REPORT ==='
lines[#lines + 1] = 'Base Save Path (s.savepath): ' .. tostring(base)
lines[#lines + 1] = ''

local files = lib.list_save_files(e, base)
lines[#lines + 1] = string.format('Found %d known files in save directory:', #files)
lines[#lines + 1] = string.format('%-26s  %10s  %-10s  %s', 'FILENAME', 'SIZE (B)', 'ADLER32', 'HEADER HEX (8 B)')
lines[#lines + 1] = string.rep('-', 76)

for _, item in ipairs(files) do
    local data = editor.read(item.name)
    if data then
        local a, b = 1, 0
        for i = 1, math.min(#data, 65536) do
            a = (a + data:byte(i)) % 65521
            b = (b + a) % 65521
        end
        local adler = b * 65536 + a
        local hdr = {}
        for i = 1, math.min(#data, 8) do
            hdr[#hdr + 1] = string.format('%02X', data:byte(i))
        end
        lines[#lines + 1] = string.format('%-26s  %10d  %08X    %s', item.name, item.size, adler, table.concat(hdr, ' '))
    else
        lines[#lines + 1] = string.format('%-26s  %10d  (unreadable)', item.name, item.size)
    end
end

local report = table.concat(lines, '\n') .. '\n'
editor.write('report_files.txt', report)

print('=== SAVE & PATH ANALYZER COMPLETE ===')
print(string.format('Analyzed %d files -> saved to report_files.txt (%d B)', #files, #report))
print('Open report_files.txt in the editor to view full table.')
print('Press B to return to the editor.')
