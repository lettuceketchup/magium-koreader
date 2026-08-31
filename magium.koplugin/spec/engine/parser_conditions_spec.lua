require("spec/spec_helper")
local parser = require("engine/parser")

describe("parse_conditions", function()
  it("returns nil for absent conditions", function()
    assert.is_nil(parser.parse_conditions(nil))
    assert.is_nil(parser.parse_conditions(""))
  end)

  it("splits a single atom", function()
    assert.are.same({ { "v_perception > 2" } }, parser.parse_conditions("v_perception > 2"))
  end)

  it("splits an AND clause", function()
    assert.are.same(
      { { "v_a > 1", "v_b == 0" } },
      parser.parse_conditions("v_a > 1 && v_b == 0")
    )
  end)

  it("splits DNF (OR of ANDs)", function()
    assert.are.same(
      { { "v_a > 1", "v_b == 0" }, { "v_c != 3" } },
      parser.parse_conditions("v_a > 1 && v_b == 0 || v_c != 3")
    )
  end)

  it("strips one leading and one trailing paren (magium-dev behavior)", function()
    assert.are.same(
      { { "v_a > 1" }, { "v_b > 2" } },
      parser.parse_conditions("(v_a > 1 || v_b > 2)")
    )
  end)

  it("asserts on a nested group (02 R4 — never in the shipped corpus)", function()
    assert.has_error(function()
      parser.parse_conditions("(v_a && v_b) || (v_c && v_d)")
    end)
  end)
end)
