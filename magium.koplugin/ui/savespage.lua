-- ui/savespage.lua — Phase III: the 50 manual save slots (spec §5, ADR-007).
-- A fullscreen KOReader Menu of "Slot 0".."Slot 49"; tapping a slot opens a
-- ButtonDialog (Save / Load / Overwrite / Delete). No import/export, no rename
-- (ADR-007). All slot I/O is the parent's job — this widget only decides what to
-- offer and calls back.
--
-- SavesPage:new{
--   slots_meta = function() -> { [n] = { name, date } },   -- re-read after each change
--   on_load(n), on_save(n), on_delete(n), on_close,
-- }

local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local NUM_SLOTS = 50

local SavesPage = Menu:extend{
  name = "magium_saves",
  is_borderless = true,
  is_popout = false,
  covers_fullscreen = true,
  title = _("Save files"),
}

function SavesPage:init()
  self.item_table = self:_build_items()
  self.close_callback = self.on_close
  Menu.init(self)
end

function SavesPage:_build_items()
  local meta = self.slots_meta()
  local items = {}
  for n = 0, NUM_SLOTS - 1 do
    local m = meta[n]
    items[n + 1] = m
      and { text = m.name, mandatory = os.date("%Y-%m-%d %H:%M", m.date), slot_n = n }
      or  { text = string.format(_("Slot %d  —  (empty)"), n), slot_n = n }
  end
  return items
end

function SavesPage:_refresh()
  self:switchItemTable(self.title, self:_build_items())
end

-- Tapping a slot opens the action dialog; the slot list stays open behind it.
function SavesPage:onMenuSelect(item)
  local n = item.slot_n
  local occupied = self.slots_meta()[n] ~= nil
  local dialog
  local function act(fn) return function() UIManager:close(dialog); fn() end end
  local buttons

  if occupied then
    buttons = {
      {{ text = _("Load"), callback = act(function()
        UIManager:close(self)
        self.on_load(n)
      end) }},
      {{ text = _("Overwrite"), callback = act(function()
        UIManager:show(ConfirmBox:new{
          text = _("Overwrite this save?"),
          ok_text = _("Overwrite"),
          ok_callback = function() self.on_save(n); self:_refresh() end,
        })
      end) }},
      {{ text = _("Delete"), callback = act(function()
        UIManager:show(ConfirmBox:new{
          text = _("Delete this save?"),
          ok_text = _("Delete"),
          ok_callback = function() self.on_delete(n); self:_refresh() end,
        })
      end) }},
      {{ text = _("Cancel"), callback = act(function() end) }},
    }
  else
    buttons = {
      {{ text = _("Save here"), callback = act(function()
        self.on_save(n); self:_refresh()
      end) }},
      {{ text = _("Cancel"), callback = act(function() end) }},
    }
  end

  dialog = ButtonDialog:new{ title = item.text, title_align = "center", buttons = buttons }
  UIManager:show(dialog)
  return true
end

return SavesPage
