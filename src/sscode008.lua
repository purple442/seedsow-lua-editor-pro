-- Slot 8: Interactive Research Scratchpad
local lib = require('sslib')
local p = editor
p.screen('0xff0d1b2a')
p.label('title', 40, 28, 38, 'SEEDSOW SWITCH 2 RESEARCH SCRATCHPAD')
p.label('sub', 40, 82, 24, string.format('Lua: %s  |  RAM: %.1f KiB  |  Save: %s', tostring(_VERSION), collectgarbage('count') or 0, tostring(e:var('s.savepath'))))

local dump = lib.hexdump(p.read('sed01.asb') or '', 0, 96)
local row_idx = 0
for line in dump:gmatch('[^\r\n]+') do
    row_idx = row_idx + 1
    p.label('hex' .. row_idx, 40, 130 + row_idx * 34, 20, line)
end
p.label('help', 40, 640, 22, 'Press B to return to Pro Editor. Edit sscode008.lua (Slot 8) for custom tests.')

local start_tick = e:now()
local last_sec = -1
return function(eng, api)
    local elapsed = math.floor((eng:now() - start_tick) / 100)
    if elapsed ~= last_sec then
        last_sec = elapsed
        api.label('clk', 40, 580, 24, string.format('Uptime: %.1f s  |  Engine Tick: %d', elapsed / 10, eng:now()))
    end
end
