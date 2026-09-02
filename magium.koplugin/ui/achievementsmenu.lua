-- ui/achievementsmenu.lua — Phase V: the 136-entry achievements browser
-- (book -> chapter -> entries), reached from the in-game menu's "Achievements"
-- row. Port of magium-dev/src/renderers.js:126-148 (renderAchievementsMenu /
-- …Book / …Chapter) and templates/achievements_menu*.ejs.
--
-- AchievementsMenu:new{
--   locale = <engine/locale>,   -- achievement_book_count/_chapters/_entries
--   view = <flat v_* snapshot>, -- unlocked test: view[variable] is "1" or "2"
--   on_close,
-- }
--
-- 3-level drill-down via the standard KOReader Menu idiom (self.paths stack +
-- switchItemTable + onReturn — see koreader/plugins/opds.koplugin), not a
-- flat list like ui/savespage.lua. Chapter order is Locale's on-disk
-- declaration order (spec §D5) — "Chapter 41"/"Chapter 42" are literal
-- labels, not renumbered (the b2ch41/b2ch42 group quirk).

local Menu = require("ui/widget/menu")
local _ = require("gettext")

local AchievementsMenu = Menu:extend{
  name = "magium_achievements",
  is_borderless = true,
  is_popout = false,
  covers_fullscreen = true,
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
  Menu.init(self)
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

function AchievementsMenu:_entry_items(book_n, key)
  local items = {}
  for _, e in ipairs(self.locale:achievement_entries(book_n, key)) do
    local v = self.view[e.variable]
    local unlocked = v ~= nil and v ~= "0"
    items[#items + 1] = { text = e.title, mandatory = e.caption, dim = not unlocked, level = "entry" }
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
