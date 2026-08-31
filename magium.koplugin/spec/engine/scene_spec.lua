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
