-- reader_smoke.lua — headless regression check for ui/reader.lua's tap zones,
-- run against the REAL KOReader widget stack (frotz-style). This is the test
-- that would have caught the Phase II "header tap always closes" report.
--
--   wsl -d Ubuntu -- bash tools/mgm.sh koenv spec/ui/reader_smoke.lua
--
-- Plain asserts, no busted — mgm.sh koenv runs bare luajit inside the emulator
-- env. Exits non-zero on the first failed assert.

-- bootstrap: a real 1272x1696 @300dpi SDL Screen under `mgm.sh test-ui-real` /
-- `real-screen` (MAGIUM_REAL_SCREEN=1), else commonrequire's fast dummy 600x800.
if os.getenv("MAGIUM_REAL_SCREEN") then require("spec/support/real_screen") else require("commonrequire") end
local Geom = require("ui/geometry")
local Reader = require("ui/reader")

local Screen = require("device").screen
local W, H = Screen:getWidth(), Screen:getHeight()
assert(W > 0 and H > 0, "no screen size (need EMULATE_READER_W/H)")

-- minimal fake locale: reader calls :str() and :header()
local locale = {
  str = function(_, k) return "[" .. k .. "]" end,
  header = function(_, id) return "Book 1 - Chapter 1" end,
}

local function make_reader(render_model, hooks)
  return Reader:new{
    render_model = render_model,
    locale = locale,
    on_menu = hooks.on_menu,
    on_close = hooks.on_close,
    advance = hooks.advance or function() return nil end,
  }
end

local function tap(reader, x, y)
  return reader:onGesture({ ges = "tap", pos = Geom:new{ x = x, y = y, w = 0, h = 0 } })
end

local RM_PROSE = {
  scene_id = "Ch1-Intro1",
  header = "Book 1 - Chapter 1",
  checkpoint = false,
  stat_checks = {},
  set_variables = {},
  paragraphs = { ("word "):rep(4000) },   -- long enough to force >1 page
  choices = { { text = "Go on", target = "Ch1-Intro2", set_variables = {}, special = nil } },
  achievements = {},
}

local fails = 0
local function check(name, cond)
  if cond then
    print("  ok   " .. name)
  else
    print("  FAIL " .. name)
    fails = fails + 1
  end
end

-- 1. tap on the far LEFT of the header -> close, not menu
do
  local menued, closed = false, false
  local r = make_reader(RM_PROSE, {
    on_menu = function() menued = true end,
    on_close = function() closed = true end,
  })
  tap(r, 10, 8)
  check("header-left tap -> on_close", closed)
  check("header-left tap -> NOT on_menu", not menued)
end

-- 2. tap on the far RIGHT of the header -> menu, not close
do
  local menued, closed = false, false
  local r = make_reader(RM_PROSE, {
    on_menu = function() menued = true end,
    on_close = function() closed = true end,
  })
  tap(r, W - 10, 8)
  check("header-right tap -> on_menu", menued)
  check("header-right tap -> NOT on_close", not closed)
end

-- 3. tap in the middle of the header (over the title) -> menu
do
  local menued, closed = false, false
  local r = make_reader(RM_PROSE, {
    on_menu = function() menued = true end,
    on_close = function() closed = true end,
  })
  tap(r, math.floor(W / 2), 8)
  check("header-middle tap -> on_menu (not close)", menued and not closed)
end

-- 4. taps in the BODY still page-turn (right = forward), never touch menu/close
do
  local menued, closed = false, false
  local r = make_reader(RM_PROSE, {
    on_menu = function() menued = true end,
    on_close = function() closed = true end,
  })
  assert(#r.pages >= 2, "test prose should paginate to >1 page")
  local before = r.page_idx
  tap(r, W - 40, math.floor(H / 2))
  check("body-right tap -> page advances", r.page_idx == before + 1)
  tap(r, 40, math.floor(H / 2))
  check("body-left tap -> page goes back", r.page_idx == before)
  check("body taps never fired menu/close", not menued and not closed)
end

-- 5. the choices page indicator is not the literal "choices"/"Choices" footer
do
  local r = make_reader(RM_PROSE, {})
  r.page_idx = #r.pages          -- last page = choices
  local ind = r:_build_indicator()
  local txt = ind.text or ""
  check("choices-page indicator is not a literal 'choice(s)' label",
    txt:lower():find("choice") == nil)
end

print(string.format("\n%s  (%d checks failed)", fails == 0 and "PASS" or "FAIL", fails))
os.exit(fails == 0 and 0 or 1)
