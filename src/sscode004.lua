-- Slot 4: Bootloader for Seedsow Pro Editor v2 (Side-Slot 4)
-- Slots 1-3 remain untouched as read-only V3 recovery backups.
if debug and debug.sethook then debug.sethook() end
editor.screen('0xff0f1c2e')
return function(eng)
    if debug and debug.sethook then debug.sethook() end
    local base = eng:var('s.savepath')
    local f, err = io.open(base .. '/pro_editor.lua', 'rb')
    assert(f, 'Cannot open pro_editor.lua: ' .. tostring(err))
    local src = f:read('*a')
    f:close()
    local chunk, load_err = loadstring(src, '@' .. base .. '/pro_editor.lua')
    assert(chunk, 'Cannot compile pro_editor.lua: ' .. tostring(load_err))
    local pro = chunk()
    pro.start(eng, {isolated = true, side_slot = 4}, src)
end
