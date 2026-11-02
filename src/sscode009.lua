-- Slot 9: Bootloader for switch-artemis-launcher (alula) & HTTP Server (:8080)
-- Press Y in the launcher to start the HTTP server, or X to return to Pro Editor v2.
if debug and debug.sethook then debug.sethook() end
editor.screen('0xff000000')
return function(eng)
    if debug and debug.sethook then debug.sethook() end
    _G.e = eng
    local update_path = "save:/inject2.lua"
    local should_load_update = eng:isFileExists(update_path)
    _G.n2h_was_recovery = false
    if eng:isDown(114) then -- KEYS.MINUS
        should_load_update = false
        _G.n2h_was_recovery = true
    end
    if should_load_update then
        eng:include(update_path)
    else
        eng:include("save:/inject.lua")
    end
end
