local helper = require("spec/spec_helper")
local parser = require("engine/parser")
local Locale = require("engine/locale")
local scene = require("engine/scene")

local DATA_ROOT = helper.data_dir_en:gsub("/en$", "")

describe("scene.render — ch1", function()
  local scenes, loc
  setup(function()
    scenes = parser.parse(helper.data_dir_en .. "/ch1.magium")
    loc = Locale.load(DATA_ROOT, "en")
  end)

  it("renders Ch1-Intro1: header, 1 prose block, 3 choices, no stat checks", function()
    local rm = scene.render(scenes["Ch1-Intro1"], {}, loc)
    assert.are.equal("Ch1-Intro1", rm.scene_id)
    assert.are.equal("Book 1 - Chapter 1", rm.header)
    assert.are.equal(1, #rm.paragraphs)
    assert.are.equal(3, #rm.choices)
    assert.are.equal(0, #rm.stat_checks)
    assert.is_false(rm.checkpoint)
    assert.are.equal("Ch1-Intro2", rm.choices[1].set_variables.v_current_scene)
  end)

  it("filters Ch1-Intro2 prose by v_ch1_intro_feeling", function()
    local excited = scene.render(scenes["Ch1-Intro2"], { v_ch1_intro_feeling = "1" }, loc)
    local afraid = scene.render(scenes["Ch1-Intro2"], { v_ch1_intro_feeling = "3" }, loc)
    assert.are_not.equal(
      table.concat(excited.paragraphs, "|"),
      table.concat(afraid.paragraphs, "|")
    )
  end)

  it("does not mutate the caller's view", function()
    local view = { v_ch1_intro_feeling = "1" }
    scene.render(scenes["Ch1-Intro2"], view, loc)
    assert.are.same({ v_ch1_intro_feeling = "1" }, view)
  end)
end)

describe("scene.render — oracle parity (offline goldens)", function()
  -- Renders the committed ch1 cases and structurally compares to the committed
  -- goldens WITHOUT a live oracle (pure offline check). Requires the goldens
  -- captured by Task 14.
  local json = require("engine/vendor/json")
  local parser = require("engine/parser")
  local Locale = require("engine/locale")
  local sc = require("engine/scene")

  local function read(p) local f = io.open(p, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s end

  it("matches every committed ch1 golden", function()
    local cases_raw = read("../reference/tools/oracle-cases-ch1.json")
    if not cases_raw then pending("run Task 14 to generate ch1 fixtures"); return end
    local cases = json.decode(cases_raw)
    local scenes = parser.parse("./data/en/ch1.magium")
    local loc = Locale.load("./data", "en")
    local mismatches = {}
    for _, case in ipairs(cases) do
      local golden_raw = read("../reference/tools/oracle-capture/" .. case.name .. ".json")
      if golden_raw then
        local view = {}
        for k, v in pairs(case.vars or {}) do view[k] = v end
        view.v_current_scene = case.sceneId
        local rm = sc.render(scenes[case.sceneId], view, loc)
        local golden = json.decode(golden_raw)
        -- compare the fields the port owns
        if table.concat(rm.paragraphs, "\1") ~= table.concat(golden.paragraphs, "\1") then
          mismatches[#mismatches + 1] = case.name .. " paragraphs"
        end
        if #rm.choices ~= #golden.choices then
          mismatches[#mismatches + 1] = case.name .. " choice count"
        end
      end
    end
    assert.are.same({}, mismatches)
  end)
end)
