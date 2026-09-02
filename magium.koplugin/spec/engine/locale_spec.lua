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

  it("loads all 3 achievement books, 136 entries total", function()
    assert.are.equal(3, loc:achievement_book_count())
    local total = 0
    for book = 1, 3 do
      for _, key in ipairs(loc:achievement_chapters(book)) do
        total = total + #loc:achievement_entries(book, key)
      end
    end
    assert.are.equal(136, total)
  end)

  it("preserves on-disk declaration order, inlining split chapters", function()
    local chapters = loc:achievement_chapters(2)
    local idx = {}
    for i, key in ipairs(chapters) do idx[key] = i end
    assert.is_truthy(idx.b2ch3 and idx.b2ch41 and idx.b2ch42 and idx.b2ch5)
    assert.are.equal(idx.b2ch3 + 1, idx.b2ch41)
    assert.are.equal(idx.b2ch41 + 1, idx.b2ch42)
    assert.are.equal(idx.b2ch42 + 1, idx.b2ch5)
  end)

  it("reads a known achievement entry's variable", function()
    local entries = loc:achievement_entries(1, "b1ch1")
    local found
    for _, e in ipairs(entries) do
      if e.variable == "v_ac_ch1_coward" then found = e end
    end
    assert.is_truthy(found)
    assert.are.equal("Who are you calling a coward?", found.title)
  end)
end)

describe("Locale (fr, Phase VII)", function()
  local loc
  setup(function() loc = Locale.load(DATA_ROOT, "fr") end)

  it("loads the fr bundle", function()
    assert.are.equal("fr", loc.lang)
    assert.are.equal("Oui", loc:str("localeYes"))
  end)

  it("derives the header from the fr template", function()
    assert.are.equal("Livre 1 - Chapitre 1", loc:header("Ch1-Intro1"))
    assert.are.equal("Livre 2 - Chapitre 7", loc:header("B2-Ch07a-Intro"))
  end)

  it("renders a stat-check line in fr", function()
    local txt = loc:stat_check_text({ variable = "Observation", value = 3, success = true })
    assert.is_truthy(txt:find("Observation"))
    assert.is_truthy(txt:find("3"))
    assert.is_falsy(txt:find("  "))
  end)

  it("has the same 136 achievements in the same declaration order as en", function()
    local en = Locale.load(DATA_ROOT, "en")
    local total = 0
    for book = 1, 3 do
      assert.are.same(en:achievement_chapters(book), loc:achievement_chapters(book))
      for _, key in ipairs(loc:achievement_chapters(book)) do
        total = total + #loc:achievement_entries(book, key)
      end
    end
    assert.are.equal(136, total)
  end)

  it("falls back to en for an unknown language", function()
    local bad = Locale.load(DATA_ROOT, "zz")
    assert.are.equal("en", bad.lang)
  end)
end)
