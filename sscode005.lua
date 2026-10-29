-- Slot 5: Artemis Engine, Luaponte & Global Environment Inspector
if debug and debug.sethook then debug.sethook() end
local lib = require('sslib')

local env_rep = lib.scan_globals()
local eng_rep = lib.scan_engine(e)
local reg_rep = lib.scan_registry()

editor.write('report_env.txt', env_rep)
editor.write('report_engine.txt', eng_rep)
editor.write('report_registry.txt', reg_rep)

print('=== ARTEMIS & LUAPONTE INSPECTOR COMPLETE ===')
print(string.format('Saved report_env.txt      (%d bytes)', #env_rep))
print(string.format('Saved report_engine.txt   (%d bytes)', #eng_rep))
print(string.format('Saved report_registry.txt (%d bytes)', #reg_rep))
print('Tip: Open report_engine.txt or press "Env Inspect" in Pro Editor!')
print('Press B to return to the editor.')
