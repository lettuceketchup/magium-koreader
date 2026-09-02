-- toast_smoke.lua — headless check for ui/toast.lua against the REAL
-- KOReader Notification widget stack.
--
--   wsl -d Ubuntu -- bash tools/mgm.sh koenv spec/ui/toast_smoke.lua
--
-- Plain asserts, no busted. Exits non-zero on the first failure.

-- bootstrap: a real 1272x1696 @300dpi SDL Screen under `mgm.sh test-ui-real` /
-- `real-screen` (MAGIUM_REAL_SCREEN=1), else commonrequire's fast dummy 600x800.
if os.getenv("MAGIUM_REAL_SCREEN") then require("spec/support/real_screen") else require("commonrequire") end
local UIManager = require("ui/uimanager")
local Toast = require("ui/toast")

local fails = 0
local function check(name, cond)
  print((cond and "  ok   " or "  FAIL ") .. name)
  if not cond then fails = fails + 1 end
end

local real_show = UIManager.show
local shown
UIManager.show = function(_, w) shown[#shown + 1] = w; return w end

local locale = { str = function(_, k)
  return k == "mainAchievementUnlockedText" and "ACHIEVEMENT UNLOCKED" or nil
end }

do  -- single unlock
  shown = {}
  Toast.show(locale, { { variable = "v_ac_x", text = "Who are you calling a coward?" } })
  check("shows exactly one Notification", #shown == 1)
  check("text is header + achievement title",
    shown[1].text == "ACHIEVEMENT UNLOCKED: Who are you calling a coward?")
  check("has a 2s timeout", shown[1].timeout == 2)
end

do  -- multiple simultaneous unlocks
  shown = {}
  Toast.show(locale, {
    { variable = "v_ac_a", text = "First" },
    { variable = "v_ac_b", text = "Second" },
  })
  check("shows one Notification per achievement", #shown == 2)
  check("first toast text", shown[1].text == "ACHIEVEMENT UNLOCKED: First")
  check("second toast text", shown[2].text == "ACHIEVEMENT UNLOCKED: Second")
end

do  -- no unlocks: no-op
  shown = {}
  Toast.show(locale, {})
  check("no achievements -> no toast", #shown == 0)
end

UIManager.show = real_show
print(string.format("\n%s  (%d checks failed)", fails == 0 and "PASS" or "FAIL", fails))
os.exit(fails == 0 and 0 or 1)
