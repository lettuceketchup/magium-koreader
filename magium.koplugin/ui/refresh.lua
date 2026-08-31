-- ui/refresh.lua — e-ink refresh-type policy (spec §8.3). Phase I: conservative.
-- OQ-007 tuning (Phase VIII) edits only this file.
local M = { _scene_count = 0, DEGHOST_EVERY = 6 }

function M.on_open() return "full" end
function M.on_page_turn() return "ui" end
function M.on_new_scene()
  M._scene_count = M._scene_count + 1
  if M._scene_count % M.DEGHOST_EVERY == 0 then return "full" end
  return "ui"
end
function M.on_modal() return "flashui" end

return M
