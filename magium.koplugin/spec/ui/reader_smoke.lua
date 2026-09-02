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

-- 6. Phase V.5, item 5: stress the choices page with the LONGEST real
-- choice() labels in the corpus, painted for real. RM_PROSE's "Go on" never
-- exercises a label wide enough to overflow the button column — the same class
-- of gap that let the achievements-menu caption crash reach the device.
do
  local PLUGIN = assert(package.path:match("^([^;]+)/%?%.lua"), "PLUGIN not in package.path")
  local parser = require("engine/parser")
  local Story = require("engine/story")

  local longest = {}
  for _, f in ipairs(Story._list_magium(PLUGIN .. "/data/en")) do
    for _, sc in pairs(parser.parse(f)) do
      for _, c in ipairs(sc.choices) do
        if c.text and #c.text > 0 then longest[#longest + 1] = c.text end
      end
    end
  end
  table.sort(longest, function(a, b) return #a > #b end)
  assert(#longest > 0, "no choice labels parsed from the corpus")

  -- a scene whose choices ARE the 15 widest labels in the whole game
  local choices = {}
  for i = 1, math.min(15, #longest) do
    choices[i] = { text = longest[i], target = "X", set_variables = {}, special = nil }
  end
  local rm = {
    scene_id = "stress", header = "Book 1 - Chapter 1", checkpoint = false,
    stat_checks = {}, set_variables = {}, paragraphs = { "x" },
    choices = choices, achievements = {},
  }
  local r = make_reader(rm, {})
  r.page_idx = #r.pages   -- the choices page
  local ok, err = pcall(function() r:_render(); r[1]:paintTo(Screen.bb, 0, 0) end)
  check("widest " .. #choices .. " corpus choice labels paint without crashing (longest = "
    .. #longest[1] .. " chars)", ok)
  if not ok then print("    " .. tostring(err)) end
end

print(string.format("\n%s  (%d checks failed)", fails == 0 and "PASS" or "FAIL", fails))
os.exit(fails == 0 and 0 or 1)
