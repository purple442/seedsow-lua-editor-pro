# Seedsow Pro Editor v2 & Research Suite

An enhanced, non-destructive **Side-Slot Lua IDE and Runtime Introspection Suite** for the *Seedsow Lullaby* (*Tanetsumi no Uta* / 『たねつみの歌』) **Artemis Engine** environment on Nintendo Switch and Nintendo Switch 2.

Built on top of the foundation by **[DialingSpoon527/seedsow-lua-editor](https://github.com/DialingSpoon527/seedsow-lua-editor)**, this extension utilizes the official `SIDE_SLOT` architecture (`Slot 4`) to add a full research toolkit, file browser, text/hex search, persistent clipboard, scrollable console output, crash-safe stacktrace logging, and automated `_G` / `Luaponte` / `debug.getregistry()` introspection—while keeping the original V3 recovery editors in **Slots 1–3** 100% untouched.

---

## ✨ What's New in Pro Editor v2 (`pro_editor.lua`)

### 1. New 5th Toolbar Row (Research & Productivity)
* **`Files / List` (Save Directory Browser):** Scans the save container (`s.savepath`), calculates exact byte sizes, flags files as `[READ/WRITE]` or `[PROTECTED/RO]`, and opens the formatted directory listing in `files_list.txt`.
* **`Find / Search` (Text & Hex Search):** Opens the native Switch keyboard dialog (supporting wired USB keyboards) to search forward with wrap-around:
  * In **TEXT mode**: Searches for plain-text substrings and jumps the cursor directly to the matching line and column.
  * In **HEX mode**: Accepts hex byte sequences (e.g., `41 53 42 00` or `424F5747`) or ASCII strings and jumps the cursor to the exact byte offset.
* **`Copy line` & `Paste clip` (Persistent Clipboard):** Copies the current line (in TEXT mode) or 16 bytes at the cursor (in HEX mode) to a persistent clipboard (`ed004-clipboard.txt`) that survives across files and reboots.
* **`Snippet +` (Built-in Code Templates):** Cycles through 6 ready-to-use Lua and Artemis introspection templates (`sslib` table dumper, `engine` metatable scanner, binary file hexdump, `e:var` prober, fullscreen UI loop, and `xpcall` traceback wrapper) pre-filled in the native keyboard prompt for review before insertion.
* **`Env Inspect` (1-Click Engine & Registry Dumper):** Automatically executes a deep scan of the runtime environment, saves `report_engine.txt`, `report_env.txt`, and `report_registry.txt` to the save directory, and cycles through opening them directly in the editor buffer.

### 2. Upgraded Runtime & Editor Ergonomics
* **Scrollable `print()` Output (200-Line Buffer):** Unlike the base editor (which only displays the last 5 lines of output), you can now press **D-Pad Up / Down** while a script is in the `RUNNING` state to scroll through up to 200 lines of output.
* **Crash-Safe Execution (`xpcall` + `debug.traceback`):** Runtime errors no longer fail silently without context. Full stacktraces with line numbers are captured via `debug.traceback` and automatically saved to `crash_log.txt`.
* **Live Telemetry Header & Hex Cursor Indicator:**
  * Displays live Lua VM memory usage (`RAM ... KiB` via `collectgarbage("count")`), hexadecimal byte offset (`0x...`), and `Ln:Col` position.
  * Highlights the active byte under the cursor in `[XX]` brackets when editing in `HEX` mode.
  * Expanded **40-step Undo history**.

---

## 🔬 Pre-Installed Research Slots (Slots 4–8) & `sslib.lua`

 Slots **1–3** remain locked as the original V3 recovery editors (`ssedit1.lua`–`ssedit3.lua`, Adler32 `3655278942`). Slots **4–8** are pre-configured and automatically registered in the game's Load menu:

| Slot | File | Title | Description |
| :--- | :--- | :--- | :--- |
| **Slot 1–3** | `ssedit1..3.lua` | `LUA EDITOR` / `RECOVERY` | Untouched V3 recovery editors (read-only fallback). |
| **Slot 4** | `sscode004.lua` | `PRO EDITOR v2 (SIDE SLOT)` | Clean two-stage side-loader that boots `pro_editor.lua`. |
| **Slot 5** | `sscode005.lua` | `RES 5: ENV & LUAPONTE INSPECT` | Scans `_G`, `debug.getmetatable(engine)`, C++ upvalues, and `debug.getregistry()`. Writes `report_env.txt`, `report_engine.txt`, and `report_registry.txt`. |
| **Slot 6** | `sscode006.lua` | `RES 6: SAVE & PATH ANALYZER` | Audits all files in `s.savepath`, computing sizes, Adler32 checksums, and 8-byte magic headers into `report_files.txt`. |
| **Slot 7** | `sscode007.lua` | `RES 7: LUA VM & DEBUG DIAG` | Audits `_VERSION`, `debug.*` functions, `pluto.*` serialization primitives, and `package.loaded` into `report_vm.txt`. |
| **Slot 8** | `sscode008.lua` | `RES 8: RESEARCH SCRATCHPAD` | Fullscreen interactive dashboard demonstrating live `sslib.hexdump()` rendering and real-time engine ticks. |

### Shared Introspection Module (`sslib.lua`)
Any user script can load the included helper library via:
```lua
local lib = require("sslib")
```
Available functions in `sslib`:
* `lib.hexdump(data, start_offset, max_bytes)` — Formats binary strings into canonical `offset | hex | ascii` rows.
* `lib.func_info(fn)` — Uses `debug.getinfo` to distinguish `[C]` closures from Lua functions, reporting definition lines and upvalue counts (`nups`).
* `lib.inspect_table(tbl, max_items)` — Sorted, type-annotated table inspector.
* `lib.scan_globals()` — Generates a full report of `_G` and engine tables (`pluto`, `sys`, `init`, `game`, `csv`, `debug`, `package`).
* `lib.scan_engine(e)` — Inspects the `engine` C++ userdata metatable (`Luaponte` bindings), subtables, closure upvalues (`debug.getupvalue`), and `e:var(...)` system paths.
* `lib.scan_registry()` — Dumps `debug.getregistry()` and its internal C++ class/callback tables.
* `lib.list_save_files(e, base)` — Enumerates known and tracked files in the save directory with byte sizes.

---

## 🚀 Installation & Transfer Guide

### Prerequisites
* *Seedsow Lullaby* (Full game or free eShop Demo — must be the same version on both consoles, launched at least once so a save directory exists).
* A modded, unbanned **Nintendo Switch 1** with **JKSV** installed (to inject the save and transfer it locally to an unmodded **Nintendo Switch 2**).

### Step-by-Step Setup
1. **Place the Backup in JKSV on Switch 1:**
   * Copy all files from this repository directly into your JKSV backup folder (or create a **flat** `.zip` archive where `.nx_save_meta.bin`, `saveg.dat`, `system.dat`, `pro_editor.lua`, `sslib.lua`, etc. sit at the **root** of the archive/folder).
   * ⚠️ **Important JKSV Note:** Do **not** nest the files inside an extra subfolder (e.g., avoid `JKSV/Seedsow Lullaby/MyBackup/seedsow-lua-editor/saveg.dat`). `.nx_save_meta.bin` must be at the top level of the backup (`JKSV/Seedsow Lullaby/MyBackup/.nx_save_meta.bin`) so JKSV applies the 16 MiB save data size allocation and restores files directly to `save:/`.
2. **Restore in `sysCFW` (Offline) & Reboot to Stock OFW:**
   * Boot your Switch 1 into `sysCFW` (keep Airplane Mode / DNS blocking active), open **JKSV**, and restore the backup to *Seedsow Lullaby*.
   * Reboot your Switch 1 into clean **Stock OFW**.
3. **Transfer to Switch 2:**
   * On both consoles, go to **System Settings → Data Management → Transfer Your Save Data** and send the *Seedsow Lullaby* save data from your Switch 1 to your Switch 2.
4. **Launch Pro Editor v2:**
   * Start *Seedsow Lullaby* on your Switch 2 and load **Slot 4** from the Load menu (or load **Slot 1** and press **`Y` / `RUN buffer`** on `sscode004.lua`).
   * You will see the green header: `SEEDSOW PRO EDITOR v2 + RESEARCH SUITE [Slot 4 | RAM ... KiB]`.

---

## 🙏 Credits & Acknowledgments
* **[DialingSpoon527](https://github.com/DialingSpoon527)** — Creator of the original [`seedsow-lua-editor`](https://github.com/DialingSpoon527/seedsow-lua-editor), V3 recovery architecture, and `SIDE_SLOT` mechanism.
* **Gezine** — Prior research on Artemis Engine save loading (`ArtemisLuaLoader`).
