-- achievementsmenu_smoke.lua — headless check for ui/achievementsmenu.lua
-- against the REAL KOReader Menu widget stack + the real achievements data.
--
--   wsl -d Ubuntu -- bash tools/mgm.sh koenv spec/ui/achievementsmenu_smoke.lua
--
-- Plain asserts, no busted. Exits non-zero on the first failure.

require("commonrequire")
local Locale = require("engine/locale")
local AchievementsMenu = require("ui/achievementsmenu")

local fails = 0
local function check(name, cond)
  print((cond and "  ok   " or "  FAIL ") .. name)
  if not cond then fails = fails + 1 end
end

-- koenv's cwd is $EMU/koreader, not the plugin dir — but mgm.sh puts
-- "$PLUGIN/?.lua;..." at the front of package.path, so recover PLUGIN from it.
local PLUGIN = assert(package.path:match("^([^;]+)/%?%.lua"), "PLUGIN not found in package.path")
local locale = Locale.load(PLUGIN .. "/data", "en")

local function make(view)
  return AchievementsMenu:new{ locale = locale, view = view or {}, on_close = function() end }
end

do  -- book list
  local m = make()
  check("3 book rows", #m.item_table == 3)
  check("book 2 label", m.item_table[2].text == "Book 2")
end

do  -- drilling into book 2: split chapters inline between 3 and 5 (D5)
  local m = make()
  m:onMenuSelect(m.item_table[2])
  local texts = {}
  for _, it in ipairs(m.item_table) do texts[#texts + 1] = it.text end
  local function idx(t)
    for i, v in ipairs(texts) do if v == t then return i end end
  end
  check("has Chapter 3, 41, 42, 5", idx("Chapter 3") and idx("Chapter 41") and idx("Chapter 42") and idx("Chapter 5"))
  check("41 right after 3", idx("Chapter 41") == idx("Chapter 3") + 1)
  check("42 right after 41", idx("Chapter 42") == idx("Chapter 41") + 1)
  check("5 right after 42", idx("Chapter 5") == idx("Chapter 42") + 1)
  check("return arrow armed (1 level deep)", #m.paths == 1)
end

do  -- drilling into an entry list: locked/unlocked
  local m = make({ v_ac_ch1_coward = "1" })
  m:onMenuSelect(m.item_table[1])   -- Book 1
  local ch1
  for _, it in ipairs(m.item_table) do
    if it.text == "Chapter 1" then ch1 = it end
  end
  check("found Chapter 1 row", ch1 ~= nil)
  m:onMenuSelect(ch1)
  local coward
  for _, it in ipairs(m.item_table) do
    if it.text == "Who are you calling a coward?" then coward = it end
  end
  check("found the coward entry", coward ~= nil)
  check("unlocked entry (flag=1) is not dimmed", coward and coward.dim == false)
  check("entry carries its caption as mandatory", coward and coward.mandatory ~= nil)

  local other
  for _, it in ipairs(m.item_table) do
    if it ~= coward then other = it end
  end
  check("a not-yet-earned entry is dimmed", other and other.dim == true)
  check("2 levels deep", #m.paths == 2)
end

do  -- onReturn pops back to the previous level
  local m = make()
  local book_table = m.item_table
  m:onMenuSelect(m.item_table[2])
  check("switched away from the book list", m.item_table ~= book_table)
  m:onReturn()
  check("back to the book list", #m.item_table == 3 and m.item_table[2].text == "Book 2")
  check("paths empty at the root", #m.paths == 0)
end

do  -- unlocked test treats "2" (seen) the same as "1" (unseen)
  local m = make({ v_ac_ch1_coward = "2" })
  m:onMenuSelect(m.item_table[1])
  local ch1
  for _, it in ipairs(m.item_table) do
    if it.text == "Chapter 1" then ch1 = it end
  end
  m:onMenuSelect(ch1)
  local coward
  for _, it in ipairs(m.item_table) do
    if it.text == "Who are you calling a coward?" then coward = it end
  end
  check("'2' (seen) still counts as unlocked", coward and coward.dim == false)
end

print(string.format("\n%s  (%d checks failed)", fails == 0 and "PASS" or "FAIL", fails))
os.exit(fails == 0 and 0 or 1)
