-- ui/toast.lua — Phase V: in-story achievement-unlock toast.
-- Port of main.ejs's .achievement-modal (auto-dismiss ~2s). KOReader's
-- Notification wraps a single-line TextWidget (no wrap), so this collapses
-- the reference's two-row "ACHIEVEMENT UNLOCKED" / title layout into one
-- line. Notification's own _shown_list already stacks concurrent toasts, so
-- N unlocks in one render just call M.show once each.

local Notification = require("ui/widget/notification")
local UIManager = require("ui/uimanager")

local M = {}

-- achievements: render_model.achievements ({variable, text}, already the
-- title — see engine/scene.lua). locale: engine/locale, for the header string.
function M.show(locale, achievements)
  local header = locale:str("mainAchievementUnlockedText") or "ACHIEVEMENT UNLOCKED"
  for _, a in ipairs(achievements) do
    UIManager:show(Notification:new{ text = header .. ": " .. a.text, timeout = 2 })
  end
end

return M
