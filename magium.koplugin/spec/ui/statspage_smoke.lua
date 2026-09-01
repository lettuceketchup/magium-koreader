-- statspage_smoke.lua — headless check for ui/statspage.lua against the REAL
-- KOReader KeyValuePage widget stack.
--
--   wsl -d Ubuntu -- bash tools/mgm.sh koenv spec/ui/statspage_smoke.lua
--
-- Plain asserts, no busted. Exits non-zero on the first failure.

require("commonrequire")
local UIManager = require("ui/uimanager")
local StatsPage = require("ui/statspage")

G_reader_settings:makeTrue("magium_stats_intro_seen")   -- skip the first-visit modal

local fails = 0
local function check(name, cond)
  print((cond and "  ok   " or "  FAIL ") .. name)
  if not cond then fails = fails + 1 end
end

-- swallow every UIManager:show (intro TextViewer shouldn't fire, but be safe)
local real_show = UIManager.show
UIManager.show = function() end

local locale = {
  str = function(_, k) return k end,
  stat_check_text = function(_, sc) return "[" .. tostring(sc.variable) .. " " .. tostring(sc.value) .. "]" end,
}

local function make(view, scene_id, on_confirm)
  return StatsPage:new{
    view = view,
    scene_id = scene_id or "Ch2-Intro",
    locale = locale,
    on_confirm = on_confirm or function() end,
    on_close = function() end,
  }
end

-- kv pair whose value (entry[2]) or key (entry[1]) contains `sub`
local function row(p, sub)
  for _, e in ipairs(p.kv_pairs) do
    if (e[1] or ""):find(sub, 1, true) or (e[2] or ""):find(sub, 1, true) then return e end
  end
end

do  -- layout
  local p = make({ v_strength = "1", v_available_points = "3" })
  check("plain scene: 12 rows (points + 9 stats + confirm + cancel)", #p.kv_pairs == 12)
  check("available points shows 3", row(p, "statsAvailablePointsText")[2] == "3")
  check("strength row is '1 / 3'", row(p, "statsStrengthText")[2] == "1 / 3")
  check("confirm/cancel rows present",
    row(p, "statsConfirmText") ~= nil and row(p, "statsCancelText") ~= nil)
end

do  -- magic gate (#9): 2 extra display-only rows
  local p = make({ v_b3_ch11_magic = "4", v_available_points = "2" }, "Ch2-Intro")
  check("magic gate: 14 rows", #p.kv_pairs == 14)
  local mp = row(p, "statsMagicalPowerText")
  check("magical power shows v_b3_ch11_magic value", mp[2] == "4")
  check("magical power row is not tappable", mp.callback == nil)
end

do  -- book-3 gate (#10): 3 extra allocatable rows
  local p = make({ v_available_points = "5" }, "B3-Ch04a-Foo")
  check("book3 gate: 15 rows", #p.kv_pairs == 15)
  check("bluff row present + tappable",
    row(p, "statsBluffText") ~= nil and row(p, "statsBluffText").callback ~= nil)
end

do  -- _bump: pending value up, points down
  local p = make({ v_strength = "1", v_available_points = "3" })
  row(p, "statsStrengthText").callback()
  check("bump raises strength to '2 / 3'", row(p, "statsStrengthText")[2] == "2 / 3")
  check("bump drops available points to 2", row(p, "statsAvailablePointsText")[2] == "2")
end

do  -- _bump no-op at the cap and at 0 points
  local p = make({ v_agility = "3", v_available_points = "3" })   -- max_stat default 3
  row(p, "statsSpeedText").callback()
  check("bump no-op at max_stat", row(p, "statsSpeedText")[2] == "3 / 3")
  check("points untouched when capped", row(p, "statsAvailablePointsText")[2] == "3")

  local q = make({ v_strength = "1", v_available_points = "0" })
  row(q, "statsStrengthText").callback()
  check("bump no-op at 0 points", row(q, "statsStrengthText")[2] == "1 / 3")
end

do  -- Confirm hands back a pending map with the raised stat + decremented points
  local got
  local p = make({ v_strength = "1", v_available_points = "3" }, "Ch2-Intro",
    function(pending) got = pending end)
  row(p, "statsStrengthText").callback()
  row(p, "statsStrengthText").callback()
  row(p, "statsConfirmText").callback()
  check("confirm map raises strength", got and got.v_strength == 3)
  check("confirm map decrements available points", got and got.v_available_points == 1)
  check("after confirm, pending cleared (points row = 1)", row(p, "statsAvailablePointsText")[2] == "1")
end

do  -- Cancel drops pending
  local p = make({ v_strength = "1", v_available_points = "3" })
  row(p, "statsStrengthText").callback()
  row(p, "statsCancelText").callback()
  check("cancel reverts strength", row(p, "statsStrengthText")[2] == "1 / 3")
  check("cancel restores points", row(p, "statsAvailablePointsText")[2] == "3")
end

UIManager.show = real_show
print(string.format("\n%s  (%d checks failed)", fails == 0 and "PASS" or "FAIL", fails))
os.exit(fails == 0 and 0 or 1)
