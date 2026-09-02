-- achievementsmenu_smoke.lua — headless check for ui/achievementsmenu.lua
-- against the REAL KOReader Menu widget stack + the real achievements data.
--
--   wsl -d Ubuntu -- bash tools/mgm.sh koenv spec/ui/achievementsmenu_smoke.lua
--
-- Plain asserts, no busted. Exits non-zero on the first failure.
--
-- IMPORTANT: structural checks (item_table contents) do NOT catch paint-time
-- crashes — KOReader's MenuItem lazily sizes its TextWidgets in paintTo, not
-- at construction (see the `mandatory` bug this file now guards against: a
-- long caption in `mandatory` — an unwrapped single-line field — only blew up
-- once actually painted, so a pre-fix version of this file with structural
-- checks alone still exited 0). Every level this menu can show is also
-- painted for real via Screen.bb, matching koreader's own
-- spec/unit/widget_progresswidget_spec.lua pattern.
--
-- CAVEAT: this still runs under commonrequire's DUMMY Screen, hardcoded to
-- 600x800 regardless of EMULATE_READER_W/H (see mgm.sh koenv's comment) — so
-- these paint checks only prove "doesn't crash", not "looks right at the
-- real PW12 1272x1696". The title/checkbox layout fix below was actually
-- verified with a one-off non-dummy script at the real resolution
-- (2026-09-04); making that the norm is Phase V.5 scope.

require("commonrequire")
local Screen = require("device").screen
local Locale = require("engine/locale")
local AchievementsMenu = require("ui/achievementsmenu")

local fails = 0
local function check(name, cond)
  print((cond and "  ok   " or "  FAIL ") .. name)
  if not cond then fails = fails + 1 end
end

-- real paint, not just construction — this is what caught the mandatory bug
local function paint(m, name)
  local ok, err = pcall(function() m:paintTo(Screen.bb, 0, 0) end)
  check("paints without crashing: " .. name, ok)
  if not ok then print("    " .. tostring(err)) end
end

-- koenv's cwd is $EMU/koreader, not the plugin dir — but mgm.sh puts
-- "$PLUGIN/?.lua;..." at the front of package.path, so recover PLUGIN from it.
local PLUGIN = assert(package.path:match("^([^;]+)/%?%.lua"), "PLUGIN not found in package.path")
local locale = Locale.load(PLUGIN .. "/data", "en")

local CHECKED, UNCHECKED = "\xe2\x9c\x93 ", "\xe2\x96\xa2 "   -- must match ui/achievementsmenu.lua

local function make(view, on_reset)
  return AchievementsMenu:new{
    locale = locale, view = view or {}, on_close = function() end,
    on_reset = on_reset or function() end,
  }
end

local function find_by_prefix(item_table, prefix)
  for _, it in ipairs(item_table) do
    if it.text:sub(1, #prefix) == prefix then return it end
  end
end

do  -- book list
  local m = make()
  check("3 book rows", #m.item_table == 3)
  check("book 2 label", m.item_table[2].text == "Book 2")
  paint(m, "book list")
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
  paint(m, "book 2 chapter list")
end

do  -- drilling into an entry list: locked/unlocked, title/caption as two
    -- real rows (not one "\n"-joined row — MenuItem:init unconditionally
    -- collapses "\n" to a space, menu.lua:211), and this is exactly the
    -- screen that crashed on-device (long captions in mandatory) — paint it.
  local m = make({ v_ac_ch1_coward = "1" })
  m:onMenuSelect(m.item_table[1])   -- Book 1
  local ch1 = find_by_prefix(m.item_table, "Chapter 1")
  check("found Chapter 1 row", ch1 ~= nil and ch1.text == "Chapter 1")
  m:onMenuSelect(ch1)

  local coward, coward_idx
  for i, it in ipairs(m.item_table) do
    if it.level == "entry" and it.text == "Who are you calling a coward?" then
      coward, coward_idx = it, i
    end
  end
  check("found the coward title row", coward ~= nil)
  check("unlocked entry shows the checked glyph", coward and coward.mandatory == CHECKED)
  check("mandatory is a short glyph, not the long caption (the crash class)",
    coward and #coward.mandatory <= 4)

  local caption = coward_idx and m.item_table[coward_idx + 1]
  check("caption is its own row right after the title (a real 2nd line)",
    caption ~= nil and caption.level == "caption"
    and caption.text == "A true warrior never backs down from a challenge.")
  check("caption row is dim and not tappable (no checkbox, no selection)",
    caption and caption.dim == true and caption.select_enabled == false
    and caption.mandatory == nil)

  local other_title
  for _, it in ipairs(m.item_table) do
    if it.level == "entry" and it ~= coward then other_title = it end
  end
  check("a not-yet-earned entry shows the unchecked glyph",
    other_title and other_title.mandatory == UNCHECKED)
  check("2 levels deep", #m.paths == 2)
  paint(m, "book 1 chapter 1 entries")
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
  local ch1 = find_by_prefix(m.item_table, "Chapter 1")
  m:onMenuSelect(ch1)
  local coward = find_by_prefix(m.item_table, "Who are you calling a coward?")
  check("'2' (seen) still counts as unlocked", coward and coward.mandatory == CHECKED)
end

do  -- reset: title-bar icon present, confirmation gate, calls on_reset then closes
  local reset_called, closed = false, false
  local m = make(nil, function() reset_called = true end)
  m.close_callback = function() closed = true end
  check("has a warning title-bar icon", m.title_bar_left_icon == "notice-warning")

  local UIManager = require("ui/uimanager")
  local real_show = UIManager.show
  local shown
  UIManager.show = function(_, w) shown = w end
  m:onLeftButtonTap()
  UIManager.show = real_show
  check("tapping the icon shows a confirmation dialog, not an immediate reset",
    shown ~= nil and not reset_called)

  shown.ok_callback()
  check("confirming calls on_reset", reset_called)
  check("confirming closes the achievements screen", closed)
end

do  -- paint EVERY chapter's entry list, across all 3 books — the mandatory
    -- crash was caption-length-dependent, so a single sampled screen isn't
    -- enough to trust the whole 136-entry corpus.
  local painted = 0
  for book = 1, locale:achievement_book_count() do
    for _, key in ipairs(locale:achievement_chapters(book)) do
      local m = make()
      m:switchItemTable(m.title, m:_entry_items(book, key))
      paint(m, "entries " .. key)
      painted = painted + 1
    end
  end
  print("  (painted " .. painted .. " chapter entry-list screens)")
end

print(string.format("\n%s  (%d checks failed)", fails == 0 and "PASS" or "FAIL", fails))
os.exit(fails == 0 and 0 or 1)
