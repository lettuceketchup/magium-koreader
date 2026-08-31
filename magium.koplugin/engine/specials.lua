-- engine/specials.lua — scene-id-keyed hardcoded special cases (01 §10).
-- Render-time cases only. PURE: Lua stdlib only.

local M = {}

M.DEFAULT_SCENE = "Ch1-Intro1"                                       -- case #1
M.CONSOLATION = { text = "Consolation prize", variable = "v_ac_b3_ch9_prize" }

local NO_STAT_CHECK_SCENES = { ["B3-Ch04a-Introduction2"] = true }   -- case #2

function M.suppress_stat_checks(scene_id)
  return NO_STAT_CHECK_SCENES[scene_id] == true
end

function M.extra_achievements(view)                                  -- case #3
  if view.v_ac_b3_ch9_prize == "1" then
    return { { text = M.CONSOLATION.text, variable = M.CONSOLATION.variable } }
  end
  return {}
end

return M
