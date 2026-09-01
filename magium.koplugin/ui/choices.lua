-- ui/choices.lua — the choice list, rendered as the reader's final page.
-- A single-column ButtonTable; each row's callback fires opts.on_select(button)
-- with that button's { label, target, set_vars, special } (pagination.lua fields).
local ButtonTable = require("ui/widget/buttontable")
local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local logger = require("logger")

local M = {}

function M.build(opts)
  -- Contract: a choices page always has at least one button — pagination.lua only
  -- emits a choices page from a scene's surviving choices, and 0/2159 scenes in
  -- the corpus parse to zero choice() constructs. But that is sampled, not
  -- proved, for the CONDITION-FILTERED case, so this degrades instead of
  -- throwing: a dead-end scene on the owner's Kindle must stay closable, not
  -- take the reader down. (The exits are safe either way — TapClose and
  -- MultiSwipe are registered on Reader, not on this subtree.)
  if not opts.buttons or #opts.buttons == 0 then
    logger.warn("magium: choices.build got no buttons for scene")
    -- A zero-row ButtonTable does not throw (../koreader/frontend/ui/widget/
    -- buttontable.lua:44-46 skips the row loop, and :157-162's refocusWidget()
    -- no-ops because moveFocusTo finds no target_item in an empty layout,
    -- focusmanager.lua:323-368 @9192014) — but it collapses to a 0x0 widget,
    -- i.e. a blank page that looks identical to a render bug. Say what happened
    -- and point at the way out instead.
    return VerticalGroup:new{
      align = "left",
      TextWidget:new{
        text = "[ No choices available here — tap the header to close. ]",
        face = Font:getFace("tfont", 16),
        max_width = opts.width,
      },
    }
  end
  local rows = {}
  for _, b in ipairs(opts.buttons) do
    -- `b` is a fresh per-iteration local (Lua 5.1) → each callback closes over
    -- its own button, not the last one.
    rows[#rows + 1] = { {
      text = b.label,
      align = "left",
      callback = function() opts.on_select(b) end,
    } }
  end
  return ButtonTable:new{
    width = opts.width,
    buttons = rows,
    show_parent = opts.show_parent,
  }
end

return M
