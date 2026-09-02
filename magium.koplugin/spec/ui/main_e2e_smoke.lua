-- main_e2e_smoke.lua — app-level end-to-end check (Phase V.5, item 1).
--
--   wsl -d Ubuntu -- bash tools/mgm.sh test-ui       (dummy 600x800)
--   wsl -d Ubuntu -- bash tools/mgm.sh test-ui-real  (real 1272x1696)
--
-- Builds the REAL `Magium` plugin object (main.lua) headlessly — fake `ui`
-- table, real `Persist` against a throwaway KO_HOME (koenv_boot) — and drives
-- it the way KOReader's plugin loader + a player would: open the reader, open
-- the in-game menu, open each sub-screen FROM the real menu callback, start a
-- new game, run the suspend/close lifecycle. Every per-widget smoke already
-- proves its screen works in isolation; this proves main.lua wires them
-- together (the gap that let two device-only bugs through — research-plan.md
-- 2026-09-04, session 30 / the Phase IV tutorial + Phase V mandatory bugs).
--
-- Plain asserts, no busted (runs under `mgm.sh koenv`/`real-screen`).

local boot = require("spec/support/koenv_boot")

local UIManager = require("ui/uimanager")
local Persist = require("persist")

local fails = 0
local function check(name, cond, extra)
  print((cond and "  ok   " or "  FAIL ") .. name .. (cond and "" or ("  <<< " .. tostring(extra or ""))))
  if not cond then fails = fails + 1 end
end

-- Require the plugin (and its heavy KOReader deps) with the REAL UIManager
-- still in place — networkmanager & friends call UIManager:nextTick at load
-- time and need real scheduling.
local Reader = require("ui/reader")
-- koenv's cwd is $EMU/koreader; mgm.sh puts "$PLUGIN/?.lua;" first on package.path.
local PLUGIN = assert(package.path:match("^([^;]+)/%?%.lua"), "PLUGIN not in package.path")
local Magium = require("main")

-- ---- NOW go headless: capture the widget stack, run schedulers inline -------
local stack = {}
UIManager.show = function(_, w, _refresh) stack[#stack + 1] = w; return w end
UIManager.close = function(_, w)
  for i = #stack, 1, -1 do if stack[i] == w then table.remove(stack, i) end end
end
UIManager.nextTick = function(_, fn) if fn then fn() end end
UIManager.scheduleIn = function(_, _delay, fn) if fn then fn() end; return fn end
UIManager.unschedule = function() end
UIManager.setDirty = function() end
UIManager.forceRePaint = function() end
UIManager.preventStandby = function() end
UIManager.allowStandby = function() end

local function top() return stack[#stack] end
local function top_is_reader() return getmetatable(top()) == Reader end

local menu_registered = false
local fake_ui = { menu = { registerToMainMenu = function() menu_registered = true end } }

local m
do
  local ok, err = pcall(function()
    m = Magium:new{ ui = fake_ui, path = PLUGIN }
  end)
  check("Magium:new{} constructs headlessly", ok, err)
  check("init() registered the main-menu item", menu_registered)
  check("init() built a SaveManager + Store", m and m.save ~= nil and m.store ~= nil)
end

-- addToMainMenu builds the entries the loader will read
do
  local items = {}
  m:addToMainMenu(items)
  check("addToMainMenu exposes 'magium' + the trace toggle",
    items.magium ~= nil and items.magium_trace ~= nil)
end

-- ---- openReader: real parse + fresh start -----------------------------------
do
  m:openReader()
  check("openReader shows the Reader widget", top_is_reader())
  check("story parsed + resident", m.story ~= nil and m.story:get_scene("Ch1-Intro1") ~= nil)
  check("fresh start lands on the intro scene", m.store:get("v_current_scene") == "Ch1-Intro1")
  check("_loaded set (lifecycle flushes now armed)", m._loaded == true)
end

-- ---- openMenu: button enablement mirrors real state ------------------------
do
  local reader = m.reader
  m:openMenu()
  local dialog = top()
  check("openMenu shows a ButtonDialog", dialog ~= nil and dialog.buttons ~= nil)
  local by_text = {}
  for _, row in ipairs(dialog.buttons or {}) do
    for _, b in ipairs(row) do by_text[b.text] = b end
  end
  local cp = by_text["Load from last checkpoint"]
  check("'Load from last checkpoint' is DISABLED with no checkpoint",
    cp ~= nil and cp.enabled == false)
  check("'Settings' is enabled (Phase VI)",
    by_text["Settings"] ~= nil and by_text["Settings"].enabled ~= false)
  -- close the menu, back to the reader
  UIManager:close(dialog)
  check("closing the menu leaves the Reader on top", top() == reader)
end

-- ---- each sub-screen opens FROM its real menu callback and returns ---------
local function open_from_menu(label)
  m:openMenu()
  local dialog = top()
  for _, row in ipairs(dialog.buttons or {}) do
    for _, b in ipairs(row) do
      if b.text == label then b.callback(); return end
    end
  end
  error("no menu button labelled " .. label)
end

do  -- Saves
  open_from_menu(m.locale:str("menuSaveLoadText") or "Save / Load game")
  check("Save/Load opens the SavesPage", m.saves ~= nil and top() == m.saves)
  check("SavesPage shows 50 slots", #m.saves.item_table == 50)
  -- real save round-trip through main.lua's on_save wiring
  m.saves.on_save(0)
  local blob = Persist:new{ path = boot.home .. "/magium/slots/0.blob", codec = "luajit" }:load()
  check("on_save wrote slot 0 to disk with a chapter name",
    blob ~= nil and type(blob.name) == "string" and blob.state ~= nil)
  UIManager:close(m.saves)
end

do  -- Stats — opened from the menu; on intro scene, no "Full immersion" unlock
  open_from_menu("Stats")
  check("Stats opens the StatsPage", m.stats ~= nil and top() == m.stats)
  check("no spurious 'Full immersion' unlock on the intro scene",
    (m.store:get("v_ac_ch6_immersion") or "0") == "0")
  m.stats.on_close()            -- "Return to game"
  check("closing Stats reopens a live Reader", top_is_reader())
end

do  -- special:stats choice -> openStats -> close must NOT revert the scene.
    -- Regression: openReader used to reload the store from disk on every reopen,
    -- so a stats choice (which only debounces its autosave) dropped the player
    -- back to the last flushed scene on return (research-plan 2026-09-07).
  m.store:set("v_current_scene", "Ch1-Intro1")
  m.save:flush_now("test-setup")               -- disk == Ch1-Intro1
  local real_touch = m.save.touch
  m.save.touch = function() end                -- simulate a still-pending debounce
  m.reader.advance{ label = "Invest points now", target = "Ch1-Intro2",
    set_vars = { v_current_scene = "Ch1-Intro2" }, special = "stats" }
  check("special:stats opened the StatsPage", top() == m.stats)
  check("the choice's scene move is in memory, not yet on disk",
    m.store:get("v_current_scene") == "Ch1-Intro2")
  m.stats.on_close()                            -- "Return to game" -> _reopenReader
  check("returning from a stats choice keeps the post-choice scene",
    m.store:get("v_current_scene") == "Ch1-Intro2")
  check("returning from a stats choice lands on a live Reader", top_is_reader())
  m.save.touch = real_touch
  m.save:flush_now("test-cleanup")
end

do  -- Settings (Phase VI): cheat mode + text size, driven from the real menu
  open_from_menu("Settings")
  local sdialog = top()
  check("Settings opens a ButtonDialog", sdialog ~= nil and sdialog.buttons ~= nil)
  local srow = {}
  for _, row in ipairs(sdialog.buttons or {}) do
    for _, b in ipairs(row) do srow[b.text] = b end
  end
  -- cheat mode: row -> ConfirmBox -> ok_callback sets v_available_points = 50
  local cheat_label = m.locale:str("settingsCheatModeText") or "Cheat mode"
  check("Settings has a cheat-mode row", srow[cheat_label] ~= nil)
  srow[cheat_label].callback()
  local confirm = top()
  check("cheat mode shows a ConfirmBox", confirm ~= nil and confirm.ok_callback ~= nil)
  confirm.ok_callback()
  check("cheat mode set v_available_points to 50", m.store:get("v_available_points") == "50")
  local disk = Persist:new{ path = boot.home .. "/magium/state", codec = "luajit" }:load()
  check("cheat mode flushed to disk",
    disk ~= nil and disk.currentState and disk.currentState.v_available_points == "50")
  UIManager:close(top())   -- the InfoMessage
  -- text size: open the sub-dialog, pick a preset, assert the setting persisted
  m:openSettings()
  local sd2 = top()
  for _, row in ipairs(sd2.buttons or {}) do
    for _, b in ipairs(row) do if b.text == "Text size" then b.callback() end end
  end
  local tsize = top()
  check("Text size opens a sub-dialog", tsize ~= nil and tsize.buttons ~= nil)
  for _, row in ipairs(tsize.buttons or {}) do
    for _, b in ipairs(row) do
      if b.text:find("Large") then b.callback() end
    end
  end
  check("picking Large persisted magium_prose_size = 25",
    G_reader_settings:readSetting("magium_prose_size") == 25)
  G_reader_settings:delSetting("magium_prose_size")
  check("reader is live again after a text-size change", top_is_reader())
end

do  -- Language (Phase VII): switch to fr, reader re-renders in place, switch back
  m.store:set("v_current_scene", "Ch1-Intro1")
  m:openSettings()
  local sd = top()
  local function pick_language(match)
    for _, row in ipairs(sd.buttons or {}) do
      for _, b in ipairs(row) do if b.text == "Language" then b.callback() end end
    end
    local ld = top()
    for _, row in ipairs(ld.buttons or {}) do
      for _, b in ipairs(row) do if b.text:find(match, 1, true) then b.callback(); return end end
    end
    error("no language row matching " .. match)
  end
  pick_language("Français")
  check("switching to fr rebuilt the locale bundle", m.locale.lang == "fr")
  check("fr switch re-renders on a live Reader", top_is_reader())
  check("fr header uses the fr template",
    m.locale:header(m.store:get("v_current_scene")) == "Livre 1 - Chapitre 1")
  check("scene position is unchanged across the switch",
    m.store:get("v_current_scene") == "Ch1-Intro1")
  m:openSettings(); sd = top()
  pick_language("English")
  check("switching back to en rebuilt the locale bundle", m.locale.lang == "en")
  check("en switch lands on a live Reader", top_is_reader())
  G_reader_settings:delSetting("magium_lang")
end

do  -- Achievements
  m.store:set("v_ac_ch1_coward", "1")   -- pretend one is earned
  open_from_menu(m.locale:str("menuAchievementsText") or "Achievements")
  check("Achievements opens the browser", m.achievements_ui ~= nil and top() == m.achievements_ui)
  check("browser sees the earned achievement",
    (m.achievements_ui.view or {}).v_ac_ch1_coward == "1")
  -- reset action drops v_ac_* only
  m.achievements_ui.on_reset()
  check("on_reset cleared v_ac_* but kept play state",
    m.store:get("v_ac_ch1_coward") == nil and m.store:get("v_current_scene") ~= nil)
  UIManager:close(m.achievements_ui)
end

-- ---- newGame: confirm -> reset, achievements survive ----------------------
do
  m.store:set("v_ac_ch1_die", "2")
  m.store:set("v_gold", "999")
  m.store:set("v_current_scene", "B2-Ch04a-Introduction")
  m:newGame()
  local confirm = top()
  check("newGame shows a ConfirmBox", confirm ~= nil and confirm.ok_callback ~= nil)
  confirm.ok_callback()
  check("confirmed newGame resets the scene to the intro",
    m.store:get("v_current_scene") == "Ch1-Intro1")
  check("newGame wiped play vars", m.store:get("v_gold") == nil)
  check("newGame KEPT achievements", m.store:get("v_ac_ch1_die") == "2")
  check("newGame reopens a live Reader", top_is_reader())
end

-- ---- lifecycle: suspend / close flush the real blob ----------------------
do
  m.store:set("v_current_scene", "Ch1-Intro2")
  m:onSuspend()
  local disk = Persist:new{ path = boot.home .. "/magium/state", codec = "luajit" }:load()
  check("onSuspend flushed v_current_scene to disk",
    disk ~= nil and disk.currentState and disk.currentState.v_current_scene == "Ch1-Intro2")
  -- onClose / onCloseWidget must not throw with _loaded true
  local ok = pcall(function() m:onClose(); m:onCloseWidget() end)
  check("onClose / onCloseWidget run cleanly", ok)
end

-- ---- trace: enabling it twice must not error or leak the file handle -----
do
  G_reader_settings:saveSetting("magium_trace", true)
  local ok, err = pcall(function()
    m:openReader()   -- opens a trace file
    m:_reopenReader() -- _configureTrace closes the old handle before opening a new one
  end)
  check("trace on: reopen closes the old file then opens a new one, no error", ok, err)
  local n = 0
  for f in require("libs/libkoreader-lfs").dir(boot.home .. "/magium") do
    if f:match("^trace%-.*%.jsonl$") then n = n + 1 end
  end
  check("trace files were written (>=1, pruned to <=5)", n >= 1 and n <= 5, n)
  G_reader_settings:saveSetting("magium_trace", false)
end

print(string.format("\n%s  (%d checks failed)", fails == 0 and "PASS" or "FAIL", fails))
if fails == 0 then os.execute("rm -rf '" .. boot.home .. "'") end   -- keep the dir on failure for inspection
os.exit(fails == 0 and 0 or 1)
