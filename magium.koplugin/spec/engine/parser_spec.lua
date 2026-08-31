local helper = require("spec/spec_helper")
local parser = require("engine/parser")

describe("parser.parse — ch1.magium", function()
  local scenes
  setup(function() scenes = parser.parse(helper.data_dir_en .. "/ch1.magium") end)

  it("has 12 scenes and no anomalies", function()
    local n = 0
    for _ in pairs(scenes) do n = n + 1 end
    assert.are.equal(12, n)
    assert.are.same({}, parser.anomalies)
  end)

  it("parses Ch1-Intro1's three choices with diverts", function()
    local s = scenes["Ch1-Intro1"]
    assert.are.equal(3, #s.choices)
    assert.are.equal("Excited", s.choices[1].text)
    assert.are.equal("Ch1-Intro2", s.choices[1].set_vars.v_current_scene)
  end)

  it("parses Ch1-Intro2's #if paragraph branches", function()
    local s = scenes["Ch1-Intro2"]
    local conditional = 0
    for _, p in ipairs(s.paragraphs) do
      if p.conditions then conditional = conditional + 1 end
    end
    assert.is_true(conditional >= 3)
  end)

  it("keeps <br/> joins in prose", function()
    assert.is_truthy(scenes["Ch1-Intro1"].paragraphs[1].text:find("<br/>", 1, true))
  end)
end)

describe("parser.parse — full English corpus", function()
  it("reproduces the exact structural counts (spec §11.1)", function()
    local dir = helper.data_dir_en
    local p = io.popen('ls "' .. dir .. '"/*.magium')
    local files = {}
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    assert.are.equal(54, #files)

    local scn, para, cho, setv, ach, ifs, anomalies = 0, 0, 0, 0, 0, 0, 0
    for _, f in ipairs(files) do
      local scenes = parser.parse(f)
      anomalies = anomalies + #parser.anomalies
      for _, s in pairs(scenes) do
        scn = scn + 1
        para = para + #s.paragraphs
        cho = cho + #s.choices
        setv = setv + #s.set_variables
        ach = ach + #s.achievements
        for _, pp in ipairs(s.paragraphs) do
          if pp.conditions then ifs = ifs + 1 end
        end
      end
    end
    assert.are.equal(0, anomalies)
    assert.are.equal(2159, scn)
    assert.are.equal(4880, para)
    assert.are.equal(3734, cho)
    assert.are.equal(594, setv)
    assert.are.equal(145, ach)
    -- #if blocks: paragraphs carrying a conditions field. 2480 per 01 §11.
    assert.are.equal(2480, ifs)
  end)
end)
