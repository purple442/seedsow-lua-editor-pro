-- the SDK bitches and aborts on an invalid mount name
package.path = "./?.lua;save:/?.lua;save:/lib/?.lua"

local KEYS = {
	A = 13,
	B = 27,
	X = 112,
	Y = 113,
	MINUS = 114
}

local old_print = _G.n2h_orig_print or print
_G.n2h_orig_print = old_print

_G.n2h_msg_gen = (_G.n2h_msg_gen or 0) + 1
local current_msg = "n2h_msg_" .. _G.n2h_msg_gen

local LOG_MAX = 64
local log_lines = {}

local function log_push(line)
	log_lines[#log_lines + 1] = line
	while #log_lines > LOG_MAX do
		table.remove(log_lines, 1)
	end
end

local function apply_font()
	e:tag{
		"font",
		anchorcenter = "0",
		face = "save:/proggy.ttf",
		left = "5",
		top = "5",
		width = "1270",
		height = "710",
		size = "26",
		rubysize = "0",
		spacetop = "0",
		spacemiddle = "0",
		spacebottom = "0",
		color = "0xFFFFFF",
		shadowcolor = "0x000000",
		outlinecolor = "0x000000",
		shadow = "1",
		outline = "2",
		rubyshadow = "0",
		rubyoutline = "0",
		align = "left",
		style = "",
		hung = "1",
		stack = "0"
	}
end

local function init_console()
	for _, id in ipairs({"zzlogn", "zzamask", "startmask", "500", "600", "2", "zzzzsseditor", "zzzzssprogram", "zzzzn2hbg"}) do
		pcall(function() e:tag{"lydel", id = id} end)
	end
	if _G.n2h_last_msg then
		pcall(function() e:tag{"lyprop", id = "~" .. _G.n2h_last_msg, visible = "0"} end)
	end
	_G.n2h_last_msg = current_msg
	e:tag{
		"lyc",
		color = "0xFF0f1c2e",
		width = "1280",
		height = "720",
		id = "zzzzn2hbg.0"
	}
	e:tag{"lyprop", id = "zzzzn2hbg", left = "0", top = "0", visible = "1", alpha = "255"}
	e:tag{"fontinit"}
	e:tag{
		"chgmsg",
		id = current_msg,
		stack = "0"
	}
	e:tag{"rp"}
	apply_font()
	e:tag{"lyprop", id = "~" .. current_msg, visible = "1", alpha = "255"}

	print = function(...)
		local args = {...}
		local formatted_args = {}
		for i, v in ipairs(args) do
			if type(v) == "string" then
				formatted_args[i] = v
			else
				formatted_args[i] = tostring(v)
			end
		end
		local line = table.concat(formatted_args, " ")
		log_push(line)
		old_print(unpack(args))
		e:tag{
			"print",
			data = line
		}
		e:tag{"rt"}
	end
end

local function n2h_clear()
	local old = current_msg
	_G.n2h_msg_gen = (_G.n2h_msg_gen or 0) + 1
	current_msg = "n2h_msg_" .. _G.n2h_msg_gen
	_G.n2h_last_msg = current_msg
	e:tag{"lyprop", id = "~" .. old, visible = "0"}
	e:tag{"chgmsg", id = current_msg, stack = "0"}
	e:tag{"rp"}
	apply_font()
	e:tag{"lyprop", id = "~" .. current_msg, visible = "1", alpha = "255"}
	for i = #log_lines, 1, -1 do
		log_lines[i] = nil
	end
end
_G.n2h_clear = n2h_clear

function n2h_launcher_idle() end

local selected = false
local is_recovery = false

local function launch_pro_editor()
	if selected then
		return
	end
	selected = true
	e:setEventHandler{ onEnterFrame = "n2h_launcher_idle" }
	pcall(function() e:tag{"/chgmsg"} end)
	e:tag{"lyprop", id = "~" .. current_msg, visible = "0"}
	e:tag{"lydel", id = "zzzzn2hbg"}
	e:tag{"lydel", id = "0"}
	print = old_print
	local base = e:var("s.savepath")
	local f, err = io.open(base .. "/pro_editor.lua", "rb")
	if not f then
		init_console()
		print("[!] Cannot open pro_editor.lua: " .. tostring(err))
		selected = false
		return
	end
	local src = f:read("*a")
	f:close()
	local chunk, lerr = loadstring(src, "@" .. base .. "/pro_editor.lua")
	if not chunk then
		init_console()
		print("[!] Cannot compile pro_editor.lua: " .. tostring(lerr))
		selected = false
		return
	end
	local pro = chunk()
	pro.start(e, {isolated = true, side_slot = 4}, src)
end

local function launch(mode)
	if selected then
		return
	end

	local updated_payload = "save:/" .. mode .. "2.lua"
	local payload = "save:/" .. mode .. ".lua"

	if is_recovery then
		print("[*] recovery mode (ignoring script updates)")
	end

	if not is_recovery and e:isFileExists(updated_payload) then
		print("[*] launcher: using updated payload (hold - to ignore)")
		payload = updated_payload
	end

	if not e:isFileExists(payload) then
		print("[!] launcher: " .. payload .. " is missing")
		return
	end

	local core_path = "save:/core.lua"

	-- we want to potentially allow updating the code without bricking our HTTP server
	local updated_core_path = "save:/core2.lua"
	if not is_recovery and e:isFileExists(updated_core_path) then
		print("[*] launcher: using updated core from " .. updated_core_path)
		core_path = updated_core_path
	end

	selected = true

	e:setEventHandler{ onEnterFrame = "n2h_launcher_idle" }
	n2h_clear()
	e:include(core_path)
	e:include(payload)
end

function n2h_launcher_frame()
	if selected then
		return
	end

	if e:isDownEdge(KEYS.MINUS) and not is_recovery then
		is_recovery = true
		print("[!] RECOVERY MODE (ignoring script updates)")
	elseif e:isDownEdge(KEYS.A) then
		launch("exploita")
	elseif e:isDownEdge(KEYS.B) then
		launch("exploitb")
	elseif e:isDownEdge(KEYS.X) then
		launch_pro_editor()
	elseif e:isDownEdge(KEYS.Y) then
		launch("http")
	end
end

local function launcher_main()
	init_console()

	print("==============================================")
	print(" switch-artemis-launcher (alula) + Pro Editor")
	print("==============================================")
	print(" Press a button on the controller to launch:")
	print(" A : slot 1 (exploita.lua)")
	print(" B : slot 2 (exploitb.lua)")
	print(" X : Return to Pro Editor v2 (GUI)")
	print(" Y : HTTP server (:8080)")
	print("==============================================")

	if _G.n2h_was_recovery then
		print("[!] Ignored launcher update. Press - again to enable recovery mode for payloads.")
	end

	e:setEventHandler{ onEnterFrame = "n2h_launcher_frame" }
end

launcher_main()
