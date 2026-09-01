-- ui/choices.lua — the choice list, rendered as the reader's final page.
-- A single-column ButtonTable; each row's callback fires opts.on_select(button)
-- with that button's { label, target, set_vars, special } (pagination.lua fields).
local ButtonTable = require("ui/widget/buttontable")

local M = {}

function M.build(opts)
  -- Contract: a choices page always has at least one button. Unreachable today
  -- (pagination.lua only emits a choices page for a scene's surviving choices,
  -- and every ch1 scene has some) — the assert documents the invariant and makes
  -- a future empty-choices scene fail loudly instead of rendering a blank page.
  assert(opts.buttons and #opts.buttons > 0, "choices.build: no buttons")
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
