-- savespage_smoke.lua — headless check for ui/savespage.lua against the REAL
-- KOReader Menu widget stack.
--
--   wsl -d Ubuntu -- bash tools/mgm.sh koenv spec/ui/savespage_smoke.lua
--
-- Plain asserts, no busted. Exits non-zero on the first failure.

require("commonrequire")
local UIManager = require("ui/uimanager")
local SavesPage = require("ui/savespage")

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

UIManager.show = real_show
print(string.format("\n%s  (%d checks failed)", fails == 0 and "PASS" or "FAIL", fails))
os.exit(fails == 0 and 0 or 1)
