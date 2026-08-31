local helper = require("spec/spec_helper")
local Locale = require("engine/locale")

local DATA_ROOT = helper.data_dir_en:gsub("/en$", "")

describe("Locale", function()
  local loc
  setup(function() loc = Locale.load(DATA_ROOT, "en") end)

  it("looks up a ui string", function()
    assert.is_string(loc:str("statsStrengthText"))
  end)

  it("derives the header from a scene id", function()
    assert.are.equal("Book 1 - Chapter 1", loc:header("Ch1-Intro1"))
    assert.are.equal("Book 2 - Chapter 7", loc:header("B2-Ch07a-Intro"))
  end)

  it("returns nil header for a non-matching id", function()
    assert.is_nil(loc:header("MainMenu"))
  end)

  it("renders a stat-check line", function()
    local txt = loc:stat_check_text({ variable = loc:str("statsObservationText"), value = 3, success = true })
    assert.is_truthy(txt:find("Observation"))
    assert.is_truthy(txt:find("3"))
    assert.is_falsy(txt:find("  "))       -- whitespace collapsed
  end)
end)
