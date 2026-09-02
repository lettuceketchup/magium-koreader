-- statspage_smoke.lua — headless check for ui/statspage.lua against the REAL
-- KOReader KeyValuePage widget stack.
--
--   wsl -d Ubuntu -- bash tools/mgm.sh koenv spec/ui/statspage_smoke.lua
--
-- Plain asserts, no busted. Exits non-zero on the first failure.

-- bootstrap: a real 1272x1696 @300dpi SDL Screen under `mgm.sh test-ui-real` /
-- `real-screen` (MAGIUM_REAL_SCREEN=1), else commonrequire's fast dummy 600x800.
if os.getenv("MAGIUM_REAL_SCREEN") then require("spec/support/real_screen") else require("commonrequire") end
local UIManager = require("ui/uimanager")
local StatsPage = require("ui/statspage")

local fails = 0
local function check(name, cond)
  print((cond and "  ok   " or "  FAIL ") .. name)
  if not cond then fails = fails + 1 end
end

-- capture UIManager:show (used by the "?" help button)
local real_show = UIManager.show
local shown
UIManager.show = function(_, w) shown = w end

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
  check("has a ? title-bar button", p.title_bar_left_icon == "notice-question")
  shown = nil
  p:_show_help()
  check("? opens a TextViewer built from the intro string",
    shown ~= nil and (shown.text or ""):find("statsIntroductionText", 1, true) ~= nil)
end

do  -- magic gate (#9): 2 extra display-only rows
  local p = make({ v_b3_ch11_magic = "4", v_available_points = "2" }, "Ch2-Intro")
  check("magic gate: 14 rows", #p.kv_pairs == 14)
  local mp = row(p, "statsMagicalPowerText")
  check("magical power shows v_b3_ch11_magic value", mp[2] == "4")
  check("magical power row is not tappable", mp.callback == nil)
end

do  -- book-3 gate (#10): 3 extra allocatable rows, real scene id
  local p = make({ v_available_points = "5" }, "B3-Ch04a-Stats-spent")
  check("book3 gate: 15 rows", #p.kv_pairs == 15)
  check("bluff row present + tappable",
    row(p, "statsBluffText") ~= nil and row(p, "statsBluffText").callback ~= nil)
  check("aura-hardening + magical-sense rows present",
    row(p, "statsAuraHardeningText") ~= nil and row(p, "statsMagicalSenseText") ~= nil)
  local q = make({ v_available_points = "5" }, "B3-Ch03a-Foo")   -- ch < 4
  check("book3 gate off before ch 4: 12 rows", #q.kv_pairs == 12)
end

do  -- both gates at once: 9 + 2 magic + 3 book3 + points + confirm + cancel = 17
  local p = make({ v_b3_ch11_magic = "3", v_available_points = "5" }, "B3-Ch10b-Stats-spent")
  check("magic + book3 gates: 17 rows", #p.kv_pairs == 17)
  check("book-3 stat still tappable, magic row still not",
    row(p, "statsBluffText").callback ~= nil and row(p, "statsMagicalKnowledgeText").callback == nil)
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
