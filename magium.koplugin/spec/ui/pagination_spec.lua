require("spec/spec_helper")
local pagination = require("ui/pagination")
local measure = require("spec/support/fake_measure")

local GEO = { width = 400, prose_height = 200, first_page_offset = 0 }

describe("paginate", function()
  it("one short paragraph -> one prose page + one choices page", function()
    local rm = {
      paragraphs = { "Short line." },
      stat_checks = {}, checkpoint = false,
      choices = { { text = "Go", target = "S2", set_variables = {}, special = nil } },
    }
    local pages = pagination.paginate(rm, GEO, measure)
    assert.are.equal(2, #pages)
    assert.are.equal("prose", pages[1].kind)
    assert.are.equal("choices", pages[2].kind)
    assert.are.equal("Go", pages[2].buttons[1].label)
  end)

  it("overflows long prose across multiple pages", function()
    local big = string.rep("word ", 400)   -- ~2000 chars -> ~50 lines -> ~1000px
    local rm = {
      paragraphs = { big }, stat_checks = {}, checkpoint = false,
      choices = { { text = "Go", target = "S2", set_variables = {} } },
    }
    local pages = pagination.paginate(rm, GEO, measure)
    assert.is_true(#pages >= 4)             -- >=3 prose + 1 choices
    assert.are.equal("choices", pages[#pages].kind)
  end)

  it("shrinks page 1 by first_page_offset", function()
    local rm = {
      paragraphs = { "A", "B", "C", "D" }, stat_checks = {}, checkpoint = false,
      choices = { { text = "Go", target = "S", set_variables = {} } },
    }
    local wide = pagination.paginate(rm, { width = 400, prose_height = 200, first_page_offset = 0 }, measure)
    local narrow = pagination.paginate(rm, { width = 400, prose_height = 200, first_page_offset = 160 }, measure)
    assert.is_true(#narrow >= #wide)
  end)

  it("choices-only scene -> a single choices page", function()
    local rm = {
      paragraphs = {}, stat_checks = {}, checkpoint = false,
      choices = { { text = "Continue", target = "S2", set_variables = {} } },
    }
    local pages = pagination.paginate(rm, GEO, measure)
    assert.are.equal(1, #pages)
    assert.are.equal("choices", pages[1].kind)
  end)

  it("puts banner + stat checks as blocks on page 1 only", function()
    local rm = {
      paragraphs = { "P1", "P2" },
      stat_checks = { { success = true, text = "[ Observation check successful - level 3 ]" } },
      checkpoint = true,
      choices = { { text = "Go", target = "S", set_variables = {} } },
    }
    local pages = pagination.paginate(rm, GEO, measure)
    assert.are.equal("banner", pages[1].blocks[1].type)
    assert.are.equal("stat_check", pages[1].blocks[2].type)
  end)
end)
