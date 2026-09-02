require("spec/spec_helper")
local Store = require("engine/store")
local SaveManager = require("save/manager")
local FakeWriter = require("spec/support/fake_writer")
local FakeSlotStore = require("spec/support/fake_slotstore")

-- Phase V.5, item 4: load the frozen Phase-V save blob (spec/save/fixtures/
-- save_v1.lua) through the REAL SaveManager and assert every field still lands
-- where the loader expects it. This breaks the day the on-disk format drifts —
-- the tripwire for a silent old-save-won't-load regression.

local FIX = require("spec/save/fixtures/save_v1")

-- deep copy so a mutating test never poisons the shared fixture table
local function clone(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = clone(v) end
  return c
end

local function mgr_over(fixture)
  local fx = clone(fixture)
  local store = Store.new()
  local w = FakeWriter.new(fx.state)
  local ss = FakeSlotStore.new(fx.slots)
  local m = SaveManager.new{
    store = store, writer = w, slotstore = ss,
    schedule = function(_, fn) return fn end, unschedule = function() end,
  }
  return m, store, w, ss
end

describe("save schema compatibility (frozen fixture)", function()
  it("state blob has exactly the four known top-level keys", function()
    local keys = {}
    for k in pairs(FIX.state) do keys[k] = true end
    -- `slots` is a legacy field SaveManager preserves untouched; it may be nil in
    -- the fixture table (so not iterated) — that's fine, it's optional.
    keys.slots = nil
    assert.are.same({ currentState = true, achievements = true, checkpoint = true }, keys)
  end)

  it("load() merges currentState + achievements into the store and returns the scene", function()
    local m, store = mgr_over(FIX)
    local scene = m:load()
    assert.are.equal("B2-Ch04a-Introduction", scene)
    assert.are.equal("B2-Ch04a-Introduction", store:get("v_current_scene"))
    assert.are.equal("63", store:get("v_gold"))
    assert.are.equal("3", store:get("v_strength"))
    -- achievements land in the same flat store, seen-latch value preserved
    assert.are.equal("2", store:get("v_ac_ch1_coward"))
    assert.are.equal("1", store:get("v_ac_ch2_baria"))
  end)

  it("checkpoint round-trips: restore its state, keep the live achievements", function()
    local m, store = mgr_over(FIX)
    m:load()
    assert.is_true(m:has_checkpoint())
    local scene = m:load_checkpoint()
    assert.are.equal("B2-Ch01a-Intro", scene)
    assert.are.equal("B2-Ch01a-Intro", store:get("v_current_scene"))
    assert.are.equal("40", store:get("v_gold"))
    -- v_ac_* are permanent across a checkpoint restore, not part of the snapshot
    assert.are.equal("2", store:get("v_ac_ch1_coward"))
    -- a var not in the checkpoint snapshot is gone after restore (full replace)
    assert.is_nil(store:get("v_baria_relationship"))
  end)

  it("slots_meta() surfaces the occupied slot's name + date", function()
    local m = mgr_over(FIX)
    local meta = m:slots_meta()
    assert.are.equal("Book 1 - Chapter 5", meta[3].name)
    assert.are.equal(1725290000, meta[3].date)
    assert.is_nil(meta[0])
  end)

  it("load_slot() restores the slot snapshot; an empty slot is a no-op", function()
    local m, store = mgr_over(FIX)
    m:load()
    local scene = m:load_slot(3)
    assert.are.equal("Ch5-Departure", scene)
    assert.are.equal("Ch5-Departure", store:get("v_current_scene"))
    assert.are.equal("51", store:get("v_gold"))
    assert.are.equal("2", store:get("v_ac_ch1_coward"))   -- achievements survive
    assert.is_nil(m:load_slot(0))
  end)
end)
