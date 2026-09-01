require("spec/spec_helper")
local Store = require("engine/store")
local SaveManager = require("save/manager")
local FakeWriter = require("spec/support/fake_writer")

-- A controllable scheduler that mirrors the REAL adapter's handle contract
-- (main.lua:99 — `schedule` returns the scheduled fn itself and `unschedule`
-- takes that fn). An index-handle double would not have caught a manager that
-- passed the wrong thing to unschedule. `scheduled` / `unscheduled` record every
-- handle for identity assertions.
local function make_sched()
  local pending, scheduled, unscheduled = {}, {}, {}
  return {
    schedule = function(delay, fn)   -- luacheck: ignore delay
      pending[#pending + 1] = fn
      scheduled[#scheduled + 1] = fn
      return fn
    end,
    unschedule = function(h)
      unscheduled[#unscheduled + 1] = h
      for i, f in ipairs(pending) do
        if f == h then table.remove(pending, i); break end
      end
    end,
    fire_all = function()
      local due = pending; pending = {}
      for _, fn in ipairs(due) do fn() end
    end,
    count = function() return #pending end,
    scheduled = scheduled,
    unscheduled = unscheduled,
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

  -- _write reads before writing so the two blobs Phase I does not own survive a
  -- Phase I autosave (save/manager.lua:34-40). Untested until now — same failure
  -- class as the D3 ship-blocker (`:` vs `.` on the writer call).
  it("_write preserves a pre-existing checkpoint / slots blob", function()
    local store = Store.new({ v_current_scene = "Ch1-Intro2", v_ac_x = "1" })
    local w = FakeWriter.new{ checkpoint = { scene = "X" }, slots = { [1] = "s" } }
    local s = make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:flush_now("t")
    assert.are.equal("X", w.data.checkpoint.scene)
    assert.are.equal("s", w.data.slots[1])
    assert.are.equal("Ch1-Intro2", w.data.currentState.v_current_scene)
    assert.are.equal("1", w.data.achievements.v_ac_x)
  end)

  it("flush_now cancels the pending debounce timer", function()
    local store = Store.new({ v_a = "1" })
    local w, s = FakeWriter.new(), make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:touch()
    assert.are.equal(1, s.count())
    mgr:flush_now("t")
    assert.are.equal(0, s.count())
    assert.are.equal(1, w.writes)          -- only the flush wrote
    -- the handle handed to unschedule is EXACTLY what schedule returned
    assert.is_true(rawequal(s.scheduled[1], s.unscheduled[1]))
    s.fire_all()
    assert.are.equal(1, w.writes)          -- the debounced write never fires
  end)

  it("save_checkpoint / load_checkpoint round-trip currentState, keeping later achievements", function()
    local store = Store.new({ v_current_scene = "B2-Ch03a-Start", v_gold = "5", v_ac_x = "1" })
    local w, s = FakeWriter.new(), make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }

    assert.is_false(mgr:has_checkpoint())
    mgr:save_checkpoint()
    assert.is_true(mgr:has_checkpoint())
    assert.are.equal("B2-Ch03a-Start", w.data.checkpoint.state.v_current_scene)
    assert.is_nil(w.data.checkpoint.state.v_ac_x)   -- achievements are a separate blob

    store:set("v_current_scene", "B2-Ch07a-Kill")
    store:set("v_gold", "0")
    store:set("v_ac_y", "1")
    mgr:on_achievement_unlocked()   -- main.lua flushes the achievements blob on every unlock

    local scene_id = mgr:load_checkpoint()
    assert.are.equal("B2-Ch03a-Start", scene_id)
    assert.are.equal("5", store:get("v_gold"))
    assert.are.equal("1", store:get("v_ac_x"))
    assert.are.equal("1", store:get("v_ac_y"))   -- earned after the checkpoint, kept
  end)

  it("load_checkpoint returns nil and leaves the store alone when there is no checkpoint", function()
    local store = Store.new({ v_current_scene = "X" })
    local w, s = FakeWriter.new(), make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    assert.is_nil(mgr:load_checkpoint())
    assert.are.equal("X", store:get("v_current_scene"))
  end)

  it("save_checkpoint preserves the slots blob and the live currentState/achievements", function()
    local store = Store.new({ v_current_scene = "X", v_ac_x = "1" })
    local w = FakeWriter.new{ slots = { [1] = "s" } }
    local s = make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:save_checkpoint()
    assert.are.equal("s", w.data.slots[1])
    assert.are.equal("X", w.data.currentState.v_current_scene)
    assert.are.equal("1", w.data.achievements.v_ac_x)
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
