require("spec/spec_helper")
local stats = require("engine/stats")

describe("var_to_stat", function()
  it("special-cases agility and perception", function()
    assert.are.equal("statsSpeedText", stats.var_to_stat("v_agility"))
    assert.are.equal("statsObservationText", stats.var_to_stat("v_perception"))
  end)
  it("camel-cases the rest", function()
    assert.are.equal("statsAncientLanguagesText", stats.var_to_stat("v_ancient_languages"))
    assert.are.equal("statsStrengthText", stats.var_to_stat("v_strength"))
  end)
end)

describe("parse_stat_check", function()
  it("nil for a non-stat variable", function()
    assert.is_nil(stats.parse_stat_check("v_ch1_show_yourself > 1"))
  end)
  it("< N => failed at level N", function()
    assert.are.same({ variable = "statsObservationText", value = 1, success = false },
      stats.parse_stat_check("v_perception < 1"))
  end)
  it("== 0 => failed at level 1", function()
    assert.are.same({ variable = "statsStrengthText", value = 1, success = false },
      stats.parse_stat_check("v_strength == 0"))
  end)
  it(">= N and == N (N != 0) => success at level N", function()
    assert.are.same({ variable = "statsHearingText", value = 3, success = true },
      stats.parse_stat_check("v_hearing >= 3"))
    assert.are.same({ variable = "statsHearingText", value = 2, success = true },
      stats.parse_stat_check("v_hearing == 2"))
  end)
  it("> N => success at level N+1", function()
    assert.are.same({ variable = "statsReflexesText", value = 3, success = true },
      stats.parse_stat_check("v_reflexes > 2"))
  end)
  it("v_b3_ch1_unlock == 2 => raw locked failure", function()
    assert.are.same({ variable = "v_b3_ch1_unlock", value = 2, success = false },
      stats.parse_stat_check("v_b3_ch1_unlock == 2"))
  end)
end)

describe("stat_checks_to_display", function()
  it("collects checks from passing condition groups, de-duped", function()
    local view = { v_perception = "2", v_ancient_languages = "3" }
    local items = {
      { conditions = { { "v_perception > 1" } } },
      { conditions = { { "v_ancient_languages >= 3" } } },
      { conditions = { { "v_perception > 1" } } },   -- dup
    }
    local out = stats.stat_checks_to_display(items, view)
    assert.are.equal(2, #out)
  end)
  it("lock filter: v_b3_ch1_unlock drops every other row", function()
    local view = { v_b3_ch1_unlock = "2", v_strength = "5" }
    local items = {
      { conditions = { { "v_b3_ch1_unlock == 2" } } },
      { conditions = { { "v_strength >= 3" } } },
    }
    local out = stats.stat_checks_to_display(items, view)
    assert.are.equal(1, #out)
    assert.are.equal("v_b3_ch1_unlock", out[1].variable)
  end)
  it("skips items without conditions", function()
    assert.are.equal(0, #stats.stat_checks_to_display({ { value = "x" } }, {}))
  end)
end)
