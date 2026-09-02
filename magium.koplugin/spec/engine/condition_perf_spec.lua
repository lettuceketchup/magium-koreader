-- spec/engine/condition_perf_spec.lua — Phase VIII / OQ-011.
--
-- b3ch4a.magium:251 is one `choice(...) if (...)` whose condition is a ~490 KB
-- DNF with 2044 OR-clauses (scene B3-Ch04a-Stats-spent). The 490 KB string is
-- split into its 2044 AND-groups exactly once, at parse time (engine/parser.lua
-- -> M.parse_conditions), and stored on the scene — so a *render* only walks the
-- pre-built table (engine/conditions.eval). This times that walk.
--
-- LOOSE tripwire, not a tight gate. It catches an accidental O(n^2) blow-up in
-- condition eval (or a regression that re-parses the string per render), not a
-- 2x drift. Baselines: dev x86 LuaJIT is well under the budget; spike 06 puts
-- the owner's Kindle at ~5.6x the dev-x86 CPU cost, so BUDGET_MS / render here
-- projects to ~5.6x that on device. If this ever legitimately climbs,
-- re-measure on the real device before bumping the number.

local helper = require("spec/spec_helper")
local parser = require("engine/parser")
local Locale = require("engine/locale")
local scene = require("engine/scene")

local DATA_ROOT = helper.data_dir_en:gsub("/en$", "")
local SCENE_ID = "B3-Ch04a-Stats-spent"
local ITERS = 50
local BUDGET_MS = 50   -- per render, dev x86; ~280 ms projected on device (spike 06)

describe("condition eval — the b3ch4a:251 outlier (OQ-011)", function()
  local st, view, loc
  setup(function()
    local scenes = parser.parse(helper.data_dir_en .. "/b3ch4a.magium")
    st = scenes[SCENE_ID]
    loc = Locale.load(DATA_ROOT, "en")
    -- a view a real player reaching this scene would carry
    view = { v_b3_ch1_unlock = "2", v_b3_ch4_introduction = "1", v_b3_ch4_average_joe = "1" }
  end)

  it("still has the pathological condition (guards the bench itself)", function()
    assert.is_not_nil(st, SCENE_ID .. " missing from b3ch4a.magium")
    local biggest = 0
    for _, c in ipairs(st.choices) do
      if c.conditions then biggest = math.max(biggest, #c.conditions) end
    end
    -- if a data change ever drops the outlier, fail loudly rather than silently
    -- measuring nothing.
    assert.is_true(biggest > 1000,
      "expected a choice condition with >1000 OR-clauses, largest was " .. biggest)
  end)

  it("renders well under " .. BUDGET_MS .. " ms/render (regression tripwire)", function()
    scene.render(st, view, loc)   -- warm JIT
    local t0 = os.clock()
    for _ = 1, ITERS do scene.render(st, view, loc) end
    local per = (os.clock() - t0) / ITERS * 1000
    assert.is_true(per < BUDGET_MS,
      string.format("%.1f ms/render (budget %d) — likely re-parsing the DNF per render or an O(n^2) eval regression", per, BUDGET_MS))
  end)
end)
