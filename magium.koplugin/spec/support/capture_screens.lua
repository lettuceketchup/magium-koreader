-- capture_screens.lua — DEV TOOL, not a test. Boots the real Magium plugin
-- headlessly against a real 1272x1696 @300dpi SDL framebuffer, drives it to each
-- screen, and writes a PNG per screen. Used to regenerate the screenshots in
-- docs/media/ and the README.
--
--   wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh real-screen spec/support/capture_screens.lua'
--
-- Output: docs/media/*.png (override with arg[1] = an absolute dir).
-- Mirrors the widget-stack capture pattern of spec/ui/main_e2e_smoke.lua.

local boot = require("spec/support/koenv_boot")   -- real screen + throwaway KO_HOME

-- The owner's Paperwhite 12 is keyless + touch-only. The SDL emulator reports a
-- keyboard, which makes KOReader's Menu paint per-row shortcut letters (Q/W/E…)
-- that never show on the target device. Stub it false BEFORE main.lua's requires
-- pull in ui/widget/menu.lua (its `is_enable_shortcut` is read at module load).
local Device = require("device")
Device.hasKeyboard = function() return false end

local UIManager = require("ui/uimanager")
local Screen = Device.screen
local Blitbuffer = require("ffi/blitbuffer")
local lfs = require("libs/libkoreader-lfs")

-- Require the plugin with the real UIManager in place (load-time nextTick), then
-- go headless: capture shown widgets instead of repainting the framebuffer.
local Reader = require("ui/reader")
local PLUGIN = assert(package.path:match("^([^;]+)/%?%.lua"), "PLUGIN not in package.path")
local Magium = require("main")

local OUT = arg[1] or (PLUGIN .. "/../docs/media")
lfs.mkdir(OUT)

local stack = {}
UIManager.show = function(_, w) stack[#stack + 1] = w; return w end
UIManager.close = function(_, w)
  for i = #stack, 1, -1 do if stack[i] == w then table.remove(stack, i) end end
end
UIManager.nextTick = function(_, fn) if fn then fn() end end
UIManager.scheduleIn = function(_, _d, fn) if fn then fn() end; return fn end
UIManager.unschedule = function() end
UIManager.setDirty = function() end
UIManager.forceRePaint = function() end
UIManager.preventStandby = function() end
UIManager.allowStandby = function() end

local function pop() table.remove(stack) end

local function shoot(name)
  Screen.bb:fill(Blitbuffer.COLOR_WHITE)
  for _, w in ipairs(stack) do
    local ok, err = pcall(function() w:paintTo(Screen.bb, 0, 0) end)
    if not ok then print("  paint WARN (" .. name .. "): " .. tostring(err)) end
  end
  local path = OUT .. "/" .. name .. ".png"
  if Screen.bb.writePNG then Screen.bb:writePNG(path)
  elseif Screen.shot then Screen:shot(path)
  else error("no PNG writer on this build") end
  print("wrote " .. path)
end

local m = Magium:new{ ui = { menu = { registerToMainMenu = function() end } }, path = PLUGIN }

-- 1 + 2. reader: prose page, then the choices page
m:openReader()
shoot("reader-prose")

m.reader.page_idx = #m.reader.pages
m.reader:_render()
shoot("reader-choices")
m.reader.page_idx = 1
m.reader:_render()

-- 3. in-game menu (over the reader)
m:openMenu()
shoot("menu")
pop()

-- 4. stats allocation — seed a spread + spare points
for k, v in pairs({
  v_strength = "3", v_agility = "2", v_toughness = "2", v_perception = "3",
  v_knowledge = "2", v_charisma = "1", v_willpower = "2", v_speed = "1", v_reflexes = "2",
  v_available_points = "5",
}) do m.store:set(k, v) end
m:openStats()
shoot("stats")
pop()

-- 5. achievements browser — seed a few unlocked, drill Book 1 > Chapter 1
for _, k in ipairs({ "v_ac_ch1_coward", "v_ac_ch1_survivor", "v_ac_ch1_die" }) do
  m.store:set(k, "1")
end
m:openAchievements()
do
  local a = m.achievements_ui
  a:onMenuSelect(a.item_table[1])   -- Book 1
  for _, it in ipairs(a.item_table) do
    if it.text == "Chapter 1" then a:onMenuSelect(it); break end
  end
end
shoot("achievements")
pop()

-- 6. save slots — fill a handful across the books
m.store:set("v_current_scene", "Ch1-Intro1")
m.save:save_slot(0, "Book 1 - Chapter 1")
m.store:set("v_current_scene", "Ch2-Intro")
m.save:save_slot(1, "Book 1 - Chapter 2")
m.store:set("v_current_scene", "B2-Ch04a-Introduction")
m.save:save_slot(4, "Book 2 - Chapter 4")
m.store:set("v_current_scene", "Ch1-Intro1")
m:openSaves()
shoot("saves")
pop()

-- 7. settings
m:openSettings()
shoot("settings")
pop()

-- 8. about (via the real menu button)
m:openMenu()
do
  local dialog = stack[#stack]
  for _, row in ipairs(dialog.buttons or {}) do
    for _, b in ipairs(row) do
      if b.text == "About" then b.callback(); break end
    end
  end
end
shoot("about")

os.execute("rm -rf '" .. boot.home .. "'")
print("\ndone")
