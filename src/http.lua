local N = _G.n2h
local log = N.log or print

if N.block_raw and N.free then
	N.free(N.block_raw)
	N.block_raw = nil
end

local REQ_CAP = 0x8000
local BODY_CAP = 0x7000
local PORT = 8080

local CONCURRENCY = 14
local F_SETFL = 4
local O_NONBLOCK = 0x800
local EAGAIN = 11

local TSTRING_DATA = 0x18

local function i32(r)
	if r == nil or r ~= r then
		return -1
	end
	if r >= 0x80000000 then
		return -1
	end
	return r
end

local function data_addr(s)
	return assert(N.str_addr(s), "httpd: no TString pointer") + TSTRING_DATA
end

local function aligned_block(size)
	local raw = N.alloc(size + 0xfff)
	assert(raw and raw ~= 0, "httpd: block allocation failed")
	local base = raw + 0xfff
	return base - base % 0x1000
end

local socket_pool = _G.n2h_socket_pool or aligned_block(0xC0000)
_G.n2h_socket_pool = socket_pool
log(string.format("[+] socket pool @ 0x%x (768 KiB)", socket_pool))

local addr_block = _G.n2h_addr_block or N.alloc(0x1000)
_G.n2h_addr_block = addr_block
assert(addr_block and addr_block ~= 0, "httpd: sockaddr allocation failed")
local ADDR = addr_block
local ADDRLEN = addr_block + 0x20

local req_s = string.rep("\0", REQ_CAP)
local req_data = data_addr(req_s)

local probe = string.rep("A", 64)
local probe_addr = data_addr(probe)
N.poke(probe_addr, 0x44434241)
assert(probe:sub(1, 4) == "ABCD",
	"httpd: Lua TString data offset is not 0x18")

local function write_sockaddr(port)
	local hi = math.floor(port / 256) % 256
	local lo = port % 256
	local word = 16 + 2 * 256 + hi * 65536 + lo * 16777216
	N.poke(ADDR, word)
	N.poke(ADDR + 8, 0)
	N.poke(ADDRLEN, 16)
end
write_sockaddr(PORT)

local function respond(code, reason, body, ctype)
	body = body or ""
	return string.format(
		"HTTP/1.1 %d %s\r\n" ..
		"Content-Type: %s\r\n" ..
		"Content-Length: %d\r\n" ..
		"Access-Control-Allow-Origin: *\r\n" ..
		"Connection: close\r\n" ..
		"\r\n%s",
		code, reason, ctype or "text/plain; charset=utf-8", #body, body)
end

local function percent_decode(s)
	return (s:gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end))
end

local function query_param(query, name)
	for pair in query:gmatch("[^&]+") do
		local k, v = pair:match("^([^=]*)=?(.*)$")
		if k and percent_decode(k) == name then
			return percent_decode(v)
		end
	end
	return nil
end

local protected_files = {
	["save:/core.lua"] = true,
	["save:/inject.iet"] = true,
	["save:/inject.lua"] = true,
	["save:/http.lua"] = true,
	["save:/proggy.ttf"] = true,
	["save:/save9999.dat"] = true,
	["save:/saveg.dat"] = true,
	["save:/system.dat"] = true,
	["save:/ssedit1.lua"] = true,
	["save:/ssedit2.lua"] = true,
	["save:/ssedit3.lua"] = true,
	["save:/sed01.asb"] = true,
	["save:/sed02.asb"] = true,
	["save:/sed03.asb"] = true,
	["save:/save0001.dat"] = true,
	["save:/save0002.dat"] = true,
	["save:/save0003.dat"] = true,
}

local function clean_save_path(name)
	if type(name) ~= "string" or name == "" then
		return nil, "empty path"
	end
	if #name > 200 then
		return nil, "path too long"
	end
	name = name:gsub("^save:/", "")
	if name == "" then
		return nil, "empty path"
	end
	if name:sub(1, 1) == "/" then
		return nil, "absolute path"
	end
	if name:find("%.%.") then
		return nil, "path escapes save:/"
	end
	if not name:match("^[%w%-%_%./]+$") then
		return nil, "bad path characters"
	end
	return "save:/" .. name
end

local function save_target(name)
	local path, why = clean_save_path(name)
	if not path then
		return nil, why
	end
	if protected_files[path] then
		return nil, "attempted to modify protected file, please use the update mechanism or modify the save using other means"
	end
	return path
end

local function track_custom_file(short_name)
	local idx_path = "save:/ed004-files.txt"
	local existing = ""
	local rf = io.open(idx_path, "rb")
	if rf then
		existing = rf:read("*a") or ""
		rf:close()
	end
	for line in existing:gmatch("[^\r\n]+") do
		if line == short_name then return end
	end
	local wf = io.open(idx_path, "wb")
	if wf then
		wf:write(existing .. short_name .. "\n")
		wf:close()
	end
end

local function run_eval(src)
	local captured = {}
	local saved = print
	print = function(...)
		local n = select("#", ...)
		local parts = {}
		for i = 1, n do
			parts[i] = tostring((select(i, ...)))
		end
		captured[#captured + 1] = table.concat(parts, "\t")
	end
	local fn, lerr = loadstring(src)
	local ok, res
	if not fn then
		ok, res = false, lerr
	else
		ok, res = pcall(fn)
	end
	print = saved

	local lines = { ok and "status: ok" or "status: error" }
	if res ~= nil then
		lines[#lines + 1] = "result: " .. tostring(res)
	end
	if #captured > 0 then
		lines[#lines + 1] = "output:"
		for i = 1, #captured do
			lines[#lines + 1] = captured[i]
		end
	end
	return table.concat(lines, "\n") .. "\n"
end

local function run_save(name, body)
	local path, why = save_target(name)
	if not path then
		return nil, why
	end
	local f, err = io.open(path, "wb")
	if not f then
		return nil, tostring(err)
	end
	local ok, werr = f:write(body)
	f:close()
	if not ok then
		return nil, tostring(werr)
	end
	local short = path:gsub("^save:/", "")
	pcall(track_custom_file, short)
	if e and e.tag then
		pcall(function() e:tag{"save", file = "ed004-commit.dat"} end)
	end
	return #body .. " bytes to " .. path
end

local function run_read(name)
	local path, why = clean_save_path(name)
	if not path then
		return nil, why
	end
	local f, err = io.open(path, "rb")
	if not f then
		return nil, tostring(err)
	end
	local data = f:read("*a") or ""
	f:close()
	return data
end

local function run_list()
	local base = (e and e.var and e:var("s.savepath")) or "save:"
	local candidates = {
		"pro_editor.lua", "sslib.lua",
		"inject.lua", "inject2.lua", "http.lua", "http2.lua", "core.lua", "core2.lua",
		"exploita.lua", "exploita2.lua", "exploitb.lua", "exploitb2.lua", "proggy.ttf",
		"sscode004.lua", "sscode005.lua", "sscode006.lua", "sscode007.lua", "sscode008.lua", "sscode009.lua",
		"report_engine.txt", "report_env.txt", "report_registry.txt", "report_files.txt", "report_vm.txt",
		"files_list.txt", "crash_log.txt", "ed004-clipboard.txt", "ed004-session.txt", "ed004-files.txt",
		"saveg.dat", "system.dat", "autosave.dat", "ssedit1.lua", "ssedit2.lua", "ssedit3.lua"
	}
	for i = 10, 30 do
		candidates[#candidates + 1] = string.format("sscode%03d.lua", i)
	end
	local idx_f = io.open(base .. "/ed004-files.txt", "rb")
	if idx_f then
		local idx_data = idx_f:read("*a") or ""
		idx_f:close()
		for line in idx_data:gmatch("[^\r\n]+") do
			if line ~= "" then candidates[#candidates + 1] = line end
		end
	end
	local seen = {}
	local rows = {}
	for _, name in ipairs(candidates) do
		if not seen[name] then
			seen[name] = true
			local f = io.open(base .. "/" .. name, "rb")
			if f then
				local size = f:seek("end") or 0
				f:close()
				local ro = protected_files["save:/" .. name] and "RO" or "RW"
				rows[#rows + 1] = string.format("%s\t%d\t%s", name, size, ro)
			end
		end
	end
	return table.concat(rows, "\n") .. "\n"
end

local WEB_UI = [[<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Seedsow Switch 2 Web IDE</title>
<style>
*{box-sizing:border-box;font-family:ui-monospace,SFMono-Regular,Consolas,monospace}
body{margin:0;background:#0b1320;color:#e6edf3;display:flex;flex-direction:column;height:100vh}
header{background:#111d30;padding:10px 18px;border-bottom:1px solid #263859;display:flex;justify-content:space-between;align-items:center}
header h1{margin:0;font-size:16px;color:#7ee787}
.badge{background:#1f324d;color:#79c0ff;padding:4px 10px;border-radius:4px;font-size:12px}
main{display:flex;flex:1;overflow:hidden}
#sidebar{width:370px;background:#0f192a;border-right:1px solid #263859;display:flex;flex-direction:column}
.panel-hdr{padding:10px 12px;background:#152238;font-size:13px;font-weight:bold;color:#79c0ff;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #263859}
#filelist{flex:1;overflow-y:auto;padding:6px}
.frow{display:flex;justify-content:space-between;align-items:center;padding:6px 8px;border-bottom:1px solid #1a273d;font-size:12px}
.frow:hover{background:#18263e}
.fname{color:#e6edf3;cursor:pointer;word-break:break-all;flex:1}
.fname:hover{color:#79c0ff;text-decoration:underline}
.fmeta{color:#8b949e;margin:0 8px;font-size:11px;white-space:nowrap}
.ro{color:#ffa657;font-size:10px;border:1px solid #ffa657;padding:1px 4px;border-radius:3px;margin-right:4px}
#upload-box{padding:10px;border-top:1px solid #263859;background:#111d30;font-size:12px}
#workspace{flex:1;display:flex;flex-direction:column;overflow:hidden}
.toolbar{padding:8px 12px;background:#152238;border-bottom:1px solid #263859;display:flex;gap:8px;align-items:center;flex-wrap:wrap}
button{background:#1f6feb;color:#fff;border:none;padding:5px 11px;border-radius:4px;cursor:pointer;font-size:12px;font-weight:600}
button:hover{background:#388bfd}
button.sec{background:#21262d;border:1px solid #30363d;color:#c9d1d9}
button.sec:hover{background:#30363d}
button.run{background:#238636}
button.run:hover{background:#2ea043}
button.del{background:#da3633;padding:2px 6px;font-size:11px}
input[type=text]{background:#0b1320;color:#e6edf3;border:1px solid #30363d;padding:5px 8px;border-radius:4px;font-size:12px}
#editor{flex:1;background:#0b1320;color:#e6edf3;border:none;padding:12px;font-size:13px;line-height:1.45;resize:none;outline:none}
#console-wrap{height:230px;border-top:1px solid #263859;display:flex;flex-direction:column;background:#070c14}
#output{flex:1;margin:0;padding:10px 12px;overflow-y:auto;font-size:12px;color:#7ee787;white-space:pre-wrap}
</style>
</head>
<body>
<header>
  <h1>Seedsow Pro v2 + switch-artemis-launcher Web IDE</h1>
  <div>
    <button class="sec" onclick="genReports()">1-Click Generate Switch 2 Reports</button>
    <span class="badge" id="status">Connected</span>
  </div>
</header>
<main>
  <div id="sidebar">
    <div class="panel-hdr">
      <span>save:/ Files</span>
      <button class="sec" onclick="loadFiles()">Refresh</button>
    </div>
    <div id="filelist">Loading...</div>
    <div id="upload-box">
      <div style="margin-bottom:6px;color:#79c0ff;font-weight:bold">Upload Local File to save:/</div>
      <input type="file" id="upfile" style="width:100%;margin-bottom:6px" onchange="syncUpName()">
      <div style="display:flex;gap:6px">
        <input type="text" id="upname" placeholder="filename (e.g. test.lua)" style="flex:1">
        <button onclick="uploadFile()">Upload</button>
      </div>
    </div>
  </div>
  <div id="workspace">
    <div class="toolbar">
      <span style="font-size:12px;color:#8b949e">File:</span>
      <input type="text" id="curfile" value="scratch.lua" style="width:200px">
      <button onclick="saveCurrent()">Save to save:/ (Ctrl+S)</button>
      <button class="run" onclick="evalCurrent()">Run in Lua VM (Ctrl+Enter)</button>
      <button class="sec" onclick="quickInfo()">VM & Engine Info</button>
      <button class="sec" onclick="clearConsole()">Clear Output</button>
    </div>
    <textarea id="editor" spellcheck="false">-- Type Lua code here and press Ctrl+Enter to execute on Switch 2!
print("Lua VM:", _VERSION, "RAM:", math.floor(collectgarbage("count")) .. " KiB")
print("Save path:", e:var("s.savepath"))
</textarea>
    <div id="console-wrap">
      <div class="panel-hdr">
        <span>Remote /eval Output</span>
        <span style="font-size:11px;color:#8b949e">Max payload: 28 KB</span>
      </div>
      <pre id="output">Ready.</pre>
    </div>
  </div>
</main>
<script>
const out = document.getElementById('output');
const ed = document.getElementById('editor');
const cur = document.getElementById('curfile');
const st = document.getElementById('status');

function logOut(msg) { out.textContent = msg; }

async function loadFiles() {
  try {
    const r = await fetch('/list');
    const t = await r.text();
    const box = document.getElementById('filelist');
    box.innerHTML = '';
    t.trim().split('\n').forEach(line => {
      if (!line) return;
      const [name, size, mode] = line.split('\t');
      const div = document.createElement('div');
      div.className = 'frow';
      const roBadge = mode === 'RO' ? '<span class="ro">RO</span>' : '';
      const delBtn = mode === 'RW' ? `<button class="del" onclick="delFile('${name}')">X</button>` : '';
      div.innerHTML = `<span class="fname" onclick="openFile('${name}')">${name}</span>
        <span class="fmeta">${roBadge}${size || '?'} B</span>
        <a href="/read?path=save:/${encodeURIComponent(name)}" download="${name}" style="color:#79c0ff;text-decoration:none;margin-right:6px;font-size:11px">DL</a>${delBtn}`;
      box.appendChild(div);
    });
  } catch (e) { logOut('List error: ' + e); }
}

async function openFile(name) {
  st.textContent = 'Reading ' + name + '...';
  try {
    const r = await fetch('/read?path=save:/' + encodeURIComponent(name));
    if (!r.ok) { logOut(await r.text()); return; }
    const buf = await r.text();
    cur.value = name;
    ed.value = buf;
    st.textContent = 'Opened ' + name + ' (' + buf.length + ' B)';
  } catch (e) { logOut('Read error: ' + e); }
}

async function saveCurrent() {
  const name = cur.value.trim();
  if (!name) return;
  st.textContent = 'Saving ' + name + '...';
  const r = await fetch('/save?path=save:/' + encodeURIComponent(name), {method:'PUT', body: ed.value});
  const t = await r.text();
  logOut(t);
  st.textContent = r.ok ? 'Saved ' + name : 'Save Error';
  loadFiles();
}

async function evalCurrent() {
  st.textContent = 'Running...';
  try {
    const r = await fetch('/eval', {method:'POST', body: ed.value});
    logOut(await r.text());
    st.textContent = 'Connected';
  } catch (e) { logOut('Eval error: ' + e); }
}

async function delFile(name) {
  if (!confirm('Delete save:/' + name + '?')) return;
  const r = await fetch('/delete?path=save:/' + encodeURIComponent(name), {method:'DELETE'});
  logOut(await r.text());
  loadFiles();
}

function syncUpName() {
  const f = document.getElementById('upfile').files[0];
  if (f) document.getElementById('upname').value = f.name;
}

async function uploadFile() {
  const f = document.getElementById('upfile').files[0];
  const name = document.getElementById('upname').value.trim();
  if (!f || !name) return alert('Choose a file and target filename');
  const buf = await f.arrayBuffer();
  const r = await fetch('/save?path=save:/' + encodeURIComponent(name), {method:'PUT', body: buf});
  logOut(await r.text());
  loadFiles();
}

async function genReports() {
  st.textContent = 'Scanning runtime...';
  const code = `local lib = require("sslib")
local base = e:var("s.savepath")
local function write_f(n, d) local f=io.open(base.."/"..n,"wb"); if f then f:write(d); f:close() end end
write_f("report_env.txt", lib.scan_globals())
write_f("report_engine.txt", lib.scan_engine(e))
write_f("report_registry.txt", lib.scan_registry())
e:tag{"save", file="ed004-commit.dat"}
print("Generated report_env.txt, report_engine.txt, and report_registry.txt! Click them in the sidebar to view or download.")`;
  const r = await fetch('/eval', {method:'POST', body: code});
  logOut(await r.text());
  st.textContent = 'Reports Ready';
  loadFiles();
}

async function quickInfo() {
  const code = `print("Lua:", _VERSION, "RAM KiB:", collectgarbage("count"))
for _, k in ipairs({"s.savepath","s.scriptpath","s.systempath"}) do
  local ok, v = pcall(function() return e:var(k) end)
  print(k, "=", ok and v or "ERR")
end
if type(_G.n2h) == "table" then
  local t = {}; for k in pairs(_G.n2h) do t[#t+1]=k end; table.sort(t)
  print("_G.n2h:", table.concat(t, ", "))
end`;
  const r = await fetch('/eval', {method:'POST', body: code});
  logOut(await r.text());
}

function clearConsole() {
  out.textContent = '';
  fetch('/eval', {method:'POST', body:'if _G.n2h_clear then _G.n2h_clear() end'});
}

ed.addEventListener('keydown', e => {
  if (e.key === 'Tab') {
    e.preventDefault();
    const s = ed.selectionStart, end = ed.selectionEnd;
    ed.value = ed.value.substring(0, s) + '\t' + ed.value.substring(end);
    ed.selectionStart = ed.selectionEnd = s + 1;
  } else if (e.ctrlKey && e.key === 'Enter') {
    e.preventDefault(); evalCurrent();
  } else if (e.ctrlKey && (e.key === 's' || e.key === 'S')) {
    e.preventDefault(); saveCurrent();
  }
});

loadFiles();
</script>
</body>
</html>
]]

local function handle(method, target, body)
	local path, query = target:match("^([^?]*)(.*)$")
	query = query:gsub("^%?", "")

	if method == "GET" and (path == "/" or path == "/ui") then
		return respond(200, "OK", WEB_UI, "text/html; charset=utf-8")
	end

	if method == "GET" and path == "/favicon.ico" then
		return respond(204, "No Content", "")
	end

	if method == "GET" and path == "/status" then
		return respond(200, "OK", string.format(
			"seedsow-lua-editor-pro + switch-artemis-launcher HTTP server\n" ..
			"GET  / (Browser Web IDE)\n" ..
			"POST /eval body=<lua>\n" ..
			"GET  /list\n" ..
			"GET  /read?path=save:/<name>\n" ..
			"PUT|POST /save?path=save:/<name> body=<file>\n" ..
			"DELETE /delete?path=save:/<name>\n"))
	end

	if path == "/list" then
		return respond(200, "OK", run_list())
	end

	if path == "/read" then
		local name = query_param(query, "path")
		local data, why = run_read(name)
		if not data then
			return respond(404, "Not Found", "read failed: " .. tostring(why) .. "\n")
		end
		return respond(200, "OK", data, "text/plain; charset=utf-8")
	end

	if path == "/eval" then
		if method ~= "POST" then
			return respond(405, "Method Not Allowed", "use POST /eval\n")
		end
		return respond(200, "OK", run_eval(body))
	end

	if path == "/save" then
		if method ~= "PUT" and method ~= "POST" then
			return respond(405, "Method Not Allowed", "use PUT /save?path=...\n")
		end
		local name = query_param(query, "path")
		local written, why = run_save(name, body)
		if not written then
			return respond(400, "Bad Request", "save failed: " .. tostring(why) .. "\n")
		end
		return respond(200, "OK", "wrote " .. written .. "\n")
	end

	if path == "/delete" then
		if method ~= "DELETE" then
			return respond(405, "Method Not Allowed", "use DELETE /delete?path=...\n")
		end
		local name = query_param(query, "path")
		local path, why = save_target(name)
		if not path then
			return respond(400, "Bad Request", "invalid path: " .. tostring(why) .. "\n")
		end
		local ok, err = os.remove(path)
		if not ok then
			return respond(500, "Internal Server Error", "delete failed: " .. tostring(err) .. "\n")
		end
		return respond(200, "OK", "deleted " .. path .. "\n")
	end

	return respond(404, "Not Found", "no such endpoint\n")
end

local st = {
	phase = "init",
	lfd = -1,
	cfd = -1,
	req = "",
	out = "",
	out_addr = 0,
	out_pos = 1,
}

local function parse_and_answer()
	local s = st.req
	local header_end, body_start
	local crlf = s:find("\r\n\r\n", 1, true)
	if crlf then
		header_end, body_start = crlf - 1, crlf + 4
	else
		local lf = s:find("\n\n", 1, true)
		if lf then
			header_end, body_start = lf - 1, lf + 2
		end
	end
	if not header_end then
		if #s >= REQ_CAP - 1 then
			return respond(431, "Request Header Fields Too Large", "request too large\n")
		end
		return "need"
	end
	local head = s:sub(1, header_end)
	local first = head:match("^([^\r\n]+)")
	if not first then
		return respond(400, "Bad Request", "bad request line\n")
	end
	local method, target = first:match("^(%u+)%s+(%S+)%s+HTTP/%d%.%d")
	if not method then
		return respond(400, "Bad Request", "bad request line\n")
	end

	local clen = 0
	local rest = head:sub(#first + 1)
	for line in rest:gmatch("[^\r\n]+") do
		local k, v = line:match("^([^:]+):%s*(.*)$")
		if k then
			k = k:lower()
			if k == "content-length" then
				clen = tonumber(v) or 0
			end
		end
	end

	if clen > BODY_CAP then
		return respond(413, "Payload Too Large", "body larger than " .. BODY_CAP .. "\n")
	end
	if #s < body_start + clen - 1 then
		return "need"
	end
	local body = (clen > 0) and s:sub(body_start, body_start + clen - 1) or ""
	return handle(method, target, body)
end

local function errno()
	return i32(N.call_deep(N.sdk("socket_get_last_error")))
end

local function close_client()
	if st.cfd >= 0 then
		N.call_deep(N.sdk("socket_close"), st.cfd, 0, 0, 0)
		st.cfd = -1
	end
	st.req = ""
	st.out = ""
	st.out_pos = 1
end

local function http_stop(what, res)
	if st.phase == "dead" then
		return
	end
	st.phase = "dead"
	log(string.format("[!] httpd: %s -> %s; server stopped", what, tostring(res)))
end

local function already_initialized(res)
	return res ~= 0 and res % 512 == 27
		and math.floor(res / 512) % 8192 == 2
end

local function post_init()
	local res = i32(N.call_deep(N.sdk("socket_initialize"), socket_pool,
		0xC0000, 0x20000, CONCURRENCY))
	log(string.format("[D] socket initialize -> 0x%x", res))
	if res ~= 0 and not already_initialized(res) then
		http_stop("socket initialize", string.format("0x%x", res))
		return
	end

	local fd = i32(N.call_deep(N.sdk("socket_socket"), 2, 1, 0))
	if fd < 0 then
		http_stop("socket", fd)
		return
	end
	st.lfd = fd
	log(string.format("[D] socket fd=%d", fd))

	local bind_res = i32(N.call_deep(N.sdk("socket_bind"), fd, ADDR, 16))
	if bind_res ~= 0 then
		http_stop("bind", bind_res)
		return
	end
	local listen_res = i32(N.call_deep(N.sdk("socket_listen"), fd, 4))
	if listen_res ~= 0 then
		http_stop("listen", listen_res)
		return
	end

	local fr = i32(N.call_deep(N.sdk("socket_fcntl"), fd,
		F_SETFL, O_NONBLOCK))
	if fr < 0 then
		http_stop("fcntl(listen)", errno())
		return
	end

	st.lfd = fd
	st.phase = "accept"
	log(string.format("Web IDE & HTTP server listening on http://CONSOLE_IP:%d", PORT))
	log("Open http://CONSOLE_IP:8080 in your PC browser! (Press B on controller to stop server)")
end

local function pump_accept()
	local fd = i32(N.call_deep(N.sdk("socket_accept"), st.lfd, ADDR, ADDRLEN))
	if fd >= 0 then
		local fr = i32(N.call_deep(N.sdk("socket_fcntl"), fd,
			F_SETFL, O_NONBLOCK))
		if fr < 0 then
			log(string.format("[!] httpd: fcntl(%d) -> %d", fd, errno()))
			N.call_deep(N.sdk("socket_close"), fd, 0, 0, 0)
			return
		end
		st.cfd = fd
		st.req = ""
		st.out = ""
		st.out_pos = 1
		st.phase = "recv"
		return
	end
	local err = errno()
	if err ~= EAGAIN then
		http_stop("accept", err)
	end
end

local function pump_recv()
	local n = i32(N.call_deep(N.sdk("socket_recv"),
		st.cfd, req_data, REQ_CAP, 0))
	if n > 0 then
		st.req = st.req .. req_s:sub(1, n)
		local verdict = parse_and_answer()
		if verdict == "need" then
			return
		end
		st.out = verdict
		st.out_addr = data_addr(st.out)
		st.out_pos = 1
		st.phase = "send"
	elseif n == 0 then
		log("[httpd] peer closed")
		close_client()
		st.phase = "accept"
	else
		local err = errno()
		if err ~= EAGAIN then
			log(string.format("[httpd] recv errno=%d", err))
			close_client()
			st.phase = "accept"
		end
	end
end

local function pump_send()
	local remaining = #st.out - st.out_pos + 1
	local where = st.out_addr + st.out_pos - 1
	local n = i32(N.call_deep(N.sdk("socket_send"),
		st.cfd, where, remaining, 0))
	if n > 0 then
		st.out_pos = st.out_pos + n
		if st.out_pos > #st.out then
			close_client()
			st.phase = "accept"
		end
	elseif n == 0 then
		close_client()
		st.phase = "accept"
	else
		local err = errno()
		if err ~= EAGAIN then
			log(string.format("[httpd] send errno=%d", err))
			close_client()
			st.phase = "accept"
		end
	end
end

function n2h_http_frame()
	if e and e.isDownEdge and e:isDownEdge(27) then
		close_client()
		if st.lfd >= 0 then
			N.call_deep(N.sdk("socket_close"), st.lfd, 0, 0, 0)
			st.lfd = -1
		end
		st.phase = "dead"
		if _G.n2h_clear then
			pcall(_G.n2h_clear)
		end
		if e:isFileExists("save:/inject2.lua") then
			e:include("save:/inject2.lua")
		else
			e:include("save:/inject.lua")
		end
		return
	end
	if st.phase == "accept" then
		pump_accept()
	elseif st.phase == "recv" then
		pump_recv()
	elseif st.phase == "send" then
		pump_send()
	end
end

post_init()
e:setEventHandler{ onEnterFrame = "n2h_http_frame" }
