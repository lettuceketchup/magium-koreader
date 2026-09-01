require("spec/spec_helper")
local json = require("engine/vendor/json")
local trace = require("util/trace")
local FakeTrace = require("spec/support/fake_trace_writer")

local function fresh(enabled, flush_every)
  local w = FakeTrace.new()
  local tick = 0
  trace.configure{
    enabled = enabled, writer = w.writer, log = w.log,
    clock = function() tick = tick + 10; return tick end,
    flush_every = flush_every or 32,
  }
  return w
end

describe("util/trace", function()
  it("is a no-op when disabled", function()
    local w = fresh(false)
    trace.event("render", { scene = "X" })
    trace.event("choice", { label = "Go" })
    trace.flush()
    assert.are.equal(0, #w.lines)
    assert.are.equal(0, #w.logs)
  end)

  it("buffers then flushes one JSON object per event", function()
    local w = fresh(true)
    trace.event("render", { scene = "Ch1-Intro1", pages = 2, checkpoint = false })
    assert.are.equal(0, #w.lines)       -- buffered, not yet written
    trace.flush()
    assert.are.equal(1, #w.lines)
    local rec = json.decode(w.lines[1])
    assert.are.equal("render", rec.ev)
    assert.are.equal("Ch1-Intro1", rec.scene)
    assert.are.equal(2, rec.pages)
    assert.are.equal("number", type(rec.t))
  end)

  it("mirrors a sorted scalar summary line to log on every event", function()
    local w = fresh(true)
    trace.event("choice", { target = "Ch1-Intro2", label = "Excited", special = "" })
    assert.are.equal(1, #w.logs)
    assert.are.equal("[MGM] choice label=Excited special= target=Ch1-Intro2", w.logs[1])
  end)

  it("auto-flushes at flush_every", function()
    local w = fresh(true, 3)
    trace.event("a"); trace.event("b")
    assert.are.equal(0, #w.lines)
    trace.event("c")                    -- 3rd → auto-flush
    assert.are.equal(3, #w.lines)
    trace.event("d")
    trace.flush()
    assert.are.equal(4, #w.lines)
  end)

  it("configure() clears a pending buffer", function()
    local w = fresh(true)
    trace.event("x")
    fresh(true)                         -- reconfigure
    trace.flush()
    assert.are.equal(0, #w.lines)       -- old event dropped
  end)

  -- A diagnostic must never break the game (ADR-005): a throwing writer must not
  -- propagate out of event()/flush(), and the tracer degrades permanently to off
  -- rather than re-throwing on every later flush.
  it("survives a throwing writer and degrades to disabled", function()
    local w = FakeTrace.new()
    local logs = {}
    trace.configure{
      enabled = true,
      writer = function() error("disk full") end,
      log = function(msg) logs[#logs + 1] = msg end,
      clock = function() return 0 end,
    }
    assert.has_no.errors(function()
      trace.event("render", { scene = "X" })
      trace.flush()
    end)
    assert.is_false(trace.enabled)
    assert.is_truthy(logs[#logs]:match("trace disabled after write error"))
    -- and it stays off + silent from here on
    assert.has_no.errors(function() trace.event("choice"); trace.flush() end)
    assert.are.equal(0, #w.lines)
  end)

  it("does not propagate a throwing log fn", function()
    trace.configure{
      enabled = true,
      writer = function() end,
      log = function() error("logger exploded") end,
      clock = function() return 0 end,
    }
    assert.has_no.errors(function() trace.event("render", { scene = "X" }) end)
    assert.is_true(trace.enabled)   -- a bad log fn is not a write failure
  end)

  it("round-trips a nested data table", function()
    local w = fresh(true)
    trace.event("choice", { set = { v_ch1_intro_feeling = "1", v_current_scene = "Ch1-Intro2" } })
    trace.flush()
    local rec = json.decode(w.lines[1])
    assert.are.equal("1", rec.set.v_ch1_intro_feeling)
    assert.are.equal("Ch1-Intro2", rec.set.v_current_scene)
  end)
end)
