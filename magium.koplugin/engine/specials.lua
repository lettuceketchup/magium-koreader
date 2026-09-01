-- engine/specials.lua — scene-id-keyed hardcoded special cases (01 §10).
-- Render-time cases only. PURE: Lua stdlib only.

local M = {}

M.DEFAULT_SCENE = "Ch1-Intro1"                                       -- case #1
M.CONSOLATION = { text = "Consolation prize", variable = "v_ac_b3_ch9_prize" }

local NO_STAT_CHECK_SCENES = { ["B3-Ch04a-Introduction2"] = true }   -- case #2

-- case #8: the device-lock stat-check line shows mainStatDeviceLockedText
-- everywhere EXCEPT B3-Ch01a-Crossbow, where the scene's own prose already
-- states the lock — magium-dev renders an empty <div class='stat_fail'> there
-- (magium-dev/templates/main.ejs:17-20 @51f5aa9).
M.HIDE_DEVICE_LOCK_TEXT = { ["B3-Ch01a-Crossbow"] = true }

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
