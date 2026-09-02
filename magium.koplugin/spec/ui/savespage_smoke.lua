-- savespage_smoke.lua — headless check for ui/savespage.lua against the REAL
-- KOReader Menu widget stack.
--
--   wsl -d Ubuntu -- bash tools/mgm.sh koenv spec/ui/savespage_smoke.lua
--
-- Plain asserts, no busted. Exits non-zero on the first failure.

-- bootstrap: a real 1272x1696 @300dpi SDL Screen under `mgm.sh test-ui-real` /
-- `real-screen` (MAGIUM_REAL_SCREEN=1), else commonrequire's fast dummy 600x800.
if os.getenv("MAGIUM_REAL_SCREEN") then require("spec/support/real_screen") else require("commonrequire") end
local UIManager = require("ui/uimanager")
local SavesPage = require("ui/savespage")
local Screen = require("device").screen

local fails = 0
local function check(name, cond)
  print((cond and "  ok   " or "  FAIL ") .. name)
  if not cond then fails = fails + 1 end
end

-- capture whatever a select handler shows (ButtonDialog / ConfirmBox)
local shown
local real_show = UIManager.show
UIManager.show = function(_, w) shown = w end

local META = { [3] = { name = "Book 2 - Chapter 4", date = os.time() } }

local function make()
  return SavesPage:new{
    slots_meta = function() return META end,
    on_load = function() end,
    on_save = function() end,
    on_delete = function() end,
    on_close = function() end,
  }
end

-- flatten a ButtonDialog/ConfirmBox's button labels
local function labels(w)
  local out = {}
  for _, row in ipairs(w.buttons or {}) do
    for _, b in ipairs(row) do out[#out + 1] = b.text end
  end
  if w.ok_text then out[#out + 1] = w.ok_text end   -- ConfirmBox
  return table.concat(out, " | ")
end

do
  local p = make()
  check("50 slot items", #p.item_table == 50)
  check("occupied slot shows the name", p.item_table[4].text == "Book 2 - Chapter 4")
  check("occupied slot has a date in mandatory", (p.item_table[4].mandatory or ""):match("%d%d%d%d"))
  check("empty slot says (empty)", p.item_table[1].text:lower():find("empty") ~= nil)
  check("empty slot has no mandatory", p.item_table[1].mandatory == nil)
end

do
  local p = make()
  shown = nil
  p:onMenuSelect(p.item_table[1])   -- empty slot
  local l = shown and labels(shown) or ""
  check("empty-slot menu offers Save", l:lower():find("save") ~= nil)
  check("empty-slot menu has no Load", l:lower():find("load") == nil)
end

do
  local p = make()
  shown = nil
  p:onMenuSelect(p.item_table[4])   -- occupied slot 3
  local l = shown and labels(shown):lower() or ""
  check("occupied menu offers Load", l:find("load") ~= nil)
  check("occupied menu offers Overwrite", l:find("overwrite") ~= nil)
  check("occupied menu offers Delete", l:find("delete") ~= nil)
end

-- Phase V.5, item 5: slot names are locale:header(scene) — "Book N - Chapter M"
-- by construction, so bounded/short (unlike the achievement captions that
-- crashed). Audit that rather than assume it: compute the header for every
-- scene id in the corpus, confirm none is unexpectedly long, then paint a full
-- 50-slot list built from the widest one (the achievements-menu bug was a
-- paint-time layout crash a structural check missed).
do
  local PLUGIN = assert(package.path:match("^([^;]+)/%?%.lua"), "PLUGIN not in package.path")
  local parser = require("engine/parser")
  local Story = require("engine/story")
  local Locale = require("engine/locale")
  local locale = Locale.load(PLUGIN .. "/data", "en")

  local widest = ""
  for _, f in ipairs(Story._list_magium(PLUGIN .. "/data/en")) do
    for id in pairs(parser.parse(f)) do
      local h = locale:header(id) or ""
      if #h > #widest then widest = h end
    end
  end
  check("every corpus slot name (locale:header) stays short (<40 chars); widest = '"
    .. widest .. "'", #widest < 40)

  local full = {}
  for n = 0, 49 do full[n] = { name = widest, date = os.time() } end
  local p = SavesPage:new{
    slots_meta = function() return full end,
    on_load = function() end, on_save = function() end,
    on_delete = function() end, on_close = function() end,
  }
  local ok, err = pcall(function() p:paintTo(Screen.bb, 0, 0) end)
  check("full 50-slot list paints with the widest real slot name", ok)
  if not ok then print("    " .. tostring(err)) end
end

UIManager.show = real_show
print(string.format("\n%s  (%d checks failed)", fails == 0 and "PASS" or "FAIL", fails))
os.exit(fails == 0 and 0 or 1)
