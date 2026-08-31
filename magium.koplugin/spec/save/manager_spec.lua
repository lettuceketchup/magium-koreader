require("spec/spec_helper")
local Store = require("engine/store")
local SaveManager = require("save/manager")
local FakeWriter = require("spec/support/fake_writer")

-- a controllable scheduler
local function make_sched()
  local pending = {}
  return {
    schedule = function(delay, fn) pending[#pending + 1] = fn; return #pending end,
    unschedule = function(h) pending[h] = nil end,
    fire_all = function() for _, fn in pairs(pending) do fn() end; pending = {} end,
    count = function() local n = 0 for _ in pairs(pending) do n = n + 1 end return n end,
  }
end

describe("SaveManager", function()
  it("touch() does not write until the timer fires", function()
    local store = Store.new({ v_current_scene = "Ch1-Intro2", v_x = "1" })
    local w = FakeWriter.new()
    local s = make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:touch()
    mgr:touch()
    assert.are.equal(0, w.writes)
    s.fire_all()
    assert.are.equal(1, w.writes)
    assert.are.equal("Ch1-Intro2", w.data.currentState.v_current_scene)
  end)

  it("separates v_ac_* into the achievements blob", function()
    local store = Store.new({ v_x = "1", v_ac_ch1_coward = "1" })
    local w = FakeWriter.new()
    local s = make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:flush_now("test")
    assert.is_nil(w.data.currentState.v_ac_ch1_coward)
    assert.are.equal("1", w.data.achievements.v_ac_ch1_coward)
    assert.are.equal("1", w.data.currentState.v_x)
  end)

  it("re-arming the timer replaces the previous one", function()
    local store = Store.new({ v_a = "1" })
    local w, s = FakeWriter.new(), make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:touch(); mgr:touch(); mgr:touch()
    assert.are.equal(1, s.count())
  end)

  it("load() restores the store and returns the resume scene", function()
    local w = FakeWriter.new({
      currentState = { v_current_scene = "Ch1-Cutthroat Dave", v_ch1_show_yourself = "2" },
      achievements = { v_ac_ch1_coward = "1" },
    })
    local store = Store.new()
    local s = make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    local resume = mgr:load()
    assert.are.equal("Ch1-Cutthroat Dave", resume)
    assert.are.equal("2", store:get("v_ch1_show_yourself"))
    assert.are.equal("1", store:get("v_ac_ch1_coward"))
  end)

  it("on_achievement_unlocked flushes immediately", function()
    local store = Store.new({ v_ac_x = "1" })
    local w, s = FakeWriter.new(), make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:on_achievement_unlocked()
    assert.are.equal(1, w.writes)
    assert.are.equal("1", w.data.achievements.v_ac_x)
  end)
end)
