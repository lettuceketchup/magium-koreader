-- ui/achievementsmenu.lua — Phase V: the 136-entry achievements browser
-- (book -> chapter -> entries), reached from the in-game menu's "Achievements"
-- row. Port of magium-dev/src/renderers.js:126-148 (renderAchievementsMenu /
-- …Book / …Chapter) and templates/achievements_menu*.ejs.
--
-- AchievementsMenu:new{
--   locale = <engine/locale>,   -- achievement_book_count/_chapters/_entries
--   view = <flat v_* snapshot>, -- unlocked test: view[variable] is "1" or "2"
--   on_close,
--   on_reset,   -- called after the user confirms; does the real store wipe +
--               -- flush (main.lua owns persistence, same split as
--               -- ui/savespage.lua's on_save/on_delete). No reference in
--               -- magium-dev — owner-requested, not a port.
-- }
--
-- 3-level drill-down via the standard KOReader Menu idiom (self.paths stack +
-- switchItemTable + onReturn — see koreader/plugins/opds.koplugin), not a
-- flat list like ui/savespage.lua. Chapter order is Locale's on-disk
-- declaration order (spec §D5) — "Chapter 41"/"Chapter 42" are literal
-- labels, not renumbered (the b2ch41/b2ch42 group quirk).

local ConfirmBox = require("ui/widget/confirmbox")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

-- multilines_show_more_text: without it, MenuItem auto-promotes to
-- single-line-with-ellipsis whenever the font doesn't fit 2 lines at the
-- row's default height (menu.lua:142-156) — which is exactly what a
-- title+caption pair does, so titles were single-line-ellipsized on-device
-- despite the row having plenty of empty vertical room (confirmed via a
-- real-resolution screenshot, 2026-09-04). This flag shrinks the font
-- instead, to actually show the wrapped text — koreader's own intended
-- mechanism for "long item text", not a custom widget.
local AchievementsMenu = Menu:extend{
  name = "magium_achievements",
  is_borderless = true,
  is_popout = false,
  covers_fullscreen = true,
  multilines_show_more_text = true,
}

-- render a ui.json template's one `<%= num %>` placeholder
local function label(tmpl, num)
  return (tmpl:gsub("<%%=%s*num%s*%%>", tostring(num)))
end

function AchievementsMenu:init()
  self.title = self.locale:str("achievementsMenuHeaderText") or _("Achievements")
  self.paths = {}
  self.item_table = self:_book_items()
  self.close_callback = self.on_close
  self.title_bar_left_icon = "notice-warning"
  Menu.init(self)
end

-- Reset-all-achievements, gated behind a confirmation. Destructive and
-- irreversible, so it's a title-bar icon (never a tap target in the list
-- itself) with an explicit ConfirmBox — same caution level as
-- ui/savespage.lua's Delete/Overwrite dialogs.
function AchievementsMenu:onLeftButtonTap()
  UIManager:show(ConfirmBox:new{
    text = _("Reset all achievements? This cannot be undone."),
    ok_text = _("Reset"),
    ok_callback = function()
      self.on_reset()
      self:onCloseAllMenus()   -- state changed under every level shown; simplest is to leave
    end,
  })
  return true
end

function AchievementsMenu:_book_items()
  local tmpl = self.locale:str("achievementsMenuBookTemplate") or "Book <%= num %>"
  local items = {}
  for n = 1, self.locale:achievement_book_count() do
    items[n] = { text = label(tmpl, n), level = "book", book_n = n }
  end
  return items
end

function AchievementsMenu:_chapter_items(book_n)
  local tmpl = self.locale:str("achievementsMenuChapterTemplate") or "Chapter <%= num %>"
  local items = {}
  for _, key in ipairs(self.locale:achievement_chapters(book_n)) do
    local num = key:match("ch(%d+)$")
    items[#items + 1] = { text = label(tmpl, num), level = "chapter", book_n = book_n, key = key }
  end
  return items
end

-- Port of achievements_menu_chapter.ejs's achievement_ok/achievement_no icon
-- swap — koreader's own CheckMark widget (ui/widget/checkmark.lua) uses these
-- exact glyphs for the same locked/unlocked-checkbox purpose everywhere else
-- in the app, so they're guaranteed to render on every supported font/device.
local CHECKED, UNCHECKED = "\xe2\x9c\x93 ", "\xe2\x96\xa2 "   -- "✓ ", "▢ "

-- Two Menu rows per achievement (title+checkbox, then a dim caption row) —
-- NOT one row with an embedded "\n". MenuItem:init unconditionally runs
-- `self.text:gsub("\n", " ")` (menu.lua:211) before any font-size/wrap
-- branch even sees the string, so no in-`text` trick can force a hard line
-- break inside a single row (confirmed by reading that line, and by
-- screenshot: multilines_show_more_text still ran the two sentences
-- together). A genuine second line means a genuine second Menu row.
function AchievementsMenu:_entry_items(book_n, key)
  local items = {}
  for _, e in ipairs(self.locale:achievement_entries(book_n, key)) do
    local v = self.view[e.variable]
    local unlocked = v ~= nil and v ~= "0"
    -- `mandatory` is a single-line, unwrapped, untruncated TextWidget (file
    -- size, page number, ...) — a full caption sentence in it crashes paint
    -- (menu.lua:200-202: available_width can go negative). A short checkbox
    -- glyph is exactly what it's for; it only goes on the title row.
    items[#items + 1] = {
      text = e.title,
      mandatory = unlocked and CHECKED or UNCHECKED,
      level = "entry",
    }
    items[#items + 1] = {
      text = e.caption,
      dim = true,
      select_enabled = false,   -- Menu:onMenuSelect no-ops on this natively
      level = "caption",
    }
  end
  return items
end

function AchievementsMenu:onMenuSelect(item)
  if item.level == "book" then
    table.insert(self.paths, { table = self.item_table, title = self.title })
    self:switchItemTable(self.title, self:_chapter_items(item.book_n))
  elseif item.level == "chapter" then
    table.insert(self.paths, { table = self.item_table, title = self.title })
    self:switchItemTable(self.title, self:_entry_items(item.book_n, item.key))
  end
  -- entry rows are terminal: tapping one does nothing further
  return true
end

function AchievementsMenu:onReturn()
  local prev = table.remove(self.paths)
  if prev then self:switchItemTable(prev.title, prev.table) end
  return true
end

return AchievementsMenu
