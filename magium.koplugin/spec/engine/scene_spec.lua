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

  -- string->string map equality, both directions.
  local function same_map(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
  end

  it("matches every committed ch1 golden", function()
    local cases_raw = read("../reference/tools/oracle-cases-ch1.json")
    if not cases_raw then pending("run Task 14 to generate ch1 fixtures"); return end
    local cases = json.decode(cases_raw)
    local scenes = parser.parse("./data/en/ch1.magium")
    local loc = Locale.load("./data", "en")
    local mismatches = {}
    local found = 0
    for _, case in ipairs(cases) do
      local golden_raw = read("../reference/tools/oracle-capture/" .. case.name .. ".json")
      if golden_raw then
        found = found + 1
        local view = {}
        for k, v in pairs(case.vars or {}) do view[k] = v end
        view.v_current_scene = case.sceneId
        local rm = sc.render(scenes[case.sceneId], view, loc)
        local golden = json.decode(golden_raw)

        if rm.scene_id ~= golden.sceneId then
          mismatches[#mismatches + 1] = case.name .. " sceneId"
        end
        if rm.checkpoint ~= golden.checkpoint then
          mismatches[#mismatches + 1] = case.name .. " checkpoint"
        end
        -- scene.lua and the oracle normalize prose identically for ch1 (the live
        -- 96/96 pass proves it) — safe to compare text here. NOT statChecks/header
        -- text: the live differ re-normalizes both sides for those.
        if table.concat(rm.paragraphs, "\1") ~= table.concat(golden.paragraphs, "\1") then
          mismatches[#mismatches + 1] = case.name .. " paragraphs"
        end

        if #rm.choices ~= #golden.choices then
          mismatches[#mismatches + 1] = case.name .. " choice count"
        else
          for i = 1, #rm.choices do
            local rc, gc = rm.choices[i], golden.choices[i]
            if rc.target ~= gc.target then
              mismatches[#mismatches + 1] = case.name .. " choices[" .. i .. "].target"
            end
            -- golden JSON null decodes to an absent key; normalize both sides.
            if (rc.special or json.null) ~= (gc.special or json.null) then
              mismatches[#mismatches + 1] = case.name .. " choices[" .. i .. "].special"
            end
            if not same_map(rc.set_variables or {}, gc.setVariables or {}) then
              mismatches[#mismatches + 1] = case.name .. " choices[" .. i .. "].setVariables"
            end
          end
        end

        if #rm.achievements ~= #golden.achievements then
          mismatches[#mismatches + 1] = case.name .. " achievement count"
        else
          for i = 1, #rm.achievements do
            local ra, ga = rm.achievements[i], golden.achievements[i]
            if ra.variable ~= ga.variable then
              mismatches[#mismatches + 1] = case.name .. " achievements[" .. i .. "].variable"
            end
            if ra.text ~= ga.text then
              mismatches[#mismatches + 1] = case.name .. " achievements[" .. i .. "].text"
            end
          end
        end
      end
    end
    -- a referenced golden that fails to resolve must FAIL, not silently skip.
    assert.are.equal(#cases, found)
    assert.are.same({}, mismatches)
  end)
end)

describe("scene.persist_effects", function()
  local Store = require("engine/store")

  it("replays render_model.set_variables into the store, resolving +N in order", function()
    local rm = {
      set_variables = {
        { name = "v_gold", value = "+5" },
        { name = "v_flag", value = "1" },
        { name = "v_gold", value = "+2" },
      },
      achievements = {},
    }
    local s = Store.new({ v_gold = "10" })
    scene.persist_effects(s, rm)
    assert.are.equal("17", s:get("v_gold"))
    assert.are.equal("1", s:get("v_flag"))
  end)

  it("respects the v_ac_* latch on write-back", function()
    local rm = { set_variables = { { name = "v_ac_x", value = "1" } }, achievements = {} }
    local s = Store.new({ v_ac_x = "2" })
    scene.persist_effects(s, rm)
    assert.are.equal("2", s:get("v_ac_x"))
  end)

  it("is a no-op when the scene set nothing", function()
    local s = Store.new({ v_a = "1" })
    scene.persist_effects(s, { set_variables = {}, achievements = {} })
    assert.are.equal("1", s:get("v_a"))
  end)

  it("flips a just-shown achievement's flag 1 -> 2 (seen latch)", function()
    local rm = { set_variables = {}, achievements = { { variable = "v_ac_x", text = "t" } } }
    local s = Store.new({ v_ac_x = "1" })
    scene.persist_effects(s, rm)
    assert.are.equal("2", s:get("v_ac_x"))
  end)

  it("does not re-latch an already-seen achievement", function()
    local rm = { set_variables = {}, achievements = { { variable = "v_ac_x", text = "t" } } }
    local s = Store.new({ v_ac_x = "2" })
    scene.persist_effects(s, rm)
    assert.are.equal("2", s:get("v_ac_x"))
  end)
end)

describe("scene.render — special case #8 (device-lock label)", function()
  local b3, loc
  setup(function()
    b3 = parser.parse(helper.data_dir_en .. "/b3ch1.magium")
    loc = Locale.load(helper.data_dir_en:gsub("/en$", ""), "en")
  end)

  it("renders an empty device-lock label on B3-Ch01a-Crossbow", function()
    local rm = scene.render(b3["B3-Ch01a-Crossbow"],
      { v_current_scene = "B3-Ch01a-Crossbow", v_b3_ch1_unlock = "2" }, loc)
    assert.are.equal(1, #rm.stat_checks)
    assert.is_false(rm.stat_checks[1].success)
    assert.are.equal("", rm.stat_checks[1].text)
  end)
end)
