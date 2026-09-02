require("spec/spec_helper")
local parser = require("engine/parser")
local Story = require("engine/story")
local specials = require("engine/specials")
local Locale = require("engine/locale")

-- Static navigation-integrity check over the WHOLE corpus. Complements the
-- oracle-corpus sweep (which checks each scene RENDERS like magium-dev) — this
-- checks the scene GRAPH: every choice leads somewhere real, and every scene is
-- reachable from the start.

local function load_all()
  local scenes = {}
  for _, f in ipairs(Story._list_magium("./data/en")) do
    for id, sc in pairs(parser.parse(f)) do
      assert(not scenes[id], "duplicate scene id: " .. id)
      scenes[id] = sc
    end
  end
  return scenes
end

-- The scene a choice sends you to: v_current_scene assignment wins (C6), then
-- the bare target. nil = this choice does not navigate (empty target + a
-- special: hook that opens a screen — saves / checkpoint_load with no target).
local function next_scene(choice)
  local v = choice.set_vars and choice.set_vars.v_current_scene
  if v and v ~= "" then return v end
  if choice.target and choice.target ~= "" then return choice.target end
  return nil
end

describe("navigation integrity (whole corpus)", function()
  local scenes
  setup(function() scenes = load_all() end)

  it("every choice target resolves to a real scene", function()
    local broken = {}
    for id, sc in pairs(scenes) do
      for _, c in ipairs(sc.choices) do
        local dst = next_scene(c)
        if dst and not scenes[dst] then
          broken[#broken + 1] = string.format("%s -> %q (choice %q)", id, dst, (c.text or ""):sub(1, 30))
        end
      end
      -- scene-level set(v_current_scene, X)
      for _, sv in ipairs(sc.set_variables) do
        if sv.name == "v_current_scene" and sv.value ~= "" and not scenes[sv.value] then
          broken[#broken + 1] = string.format("%s set(v_current_scene, %q)", id, sv.value)
        end
      end
    end
    assert.message("dangling targets:\n  " .. table.concat(broken, "\n  ")).are.same({}, broken)
  end)

  it("the start scene and every special:restart target exist", function()
    assert.is_truthy(scenes[specials.DEFAULT_SCENE], "missing " .. specials.DEFAULT_SCENE)
    for id, sc in pairs(scenes) do
      for _, c in ipairs(sc.choices) do
        if c.special == "restart" then
          local dst = next_scene(c) or specials.DEFAULT_SCENE
          assert.is_truthy(scenes[dst], id .. " restart -> missing " .. dst)
        end
      end
    end
  end)

  it("every scene is reachable from the start (following all choice edges)", function()
    local seen, queue = { [specials.DEFAULT_SCENE] = true }, { specials.DEFAULT_SCENE }
    while #queue > 0 do
      local id = table.remove(queue)
      local sc = scenes[id]
      if sc then
        local edges = {}
        for _, c in ipairs(sc.choices) do
          local d = next_scene(c)
          if d then edges[#edges + 1] = d end
          if c.special == "restart" then edges[#edges + 1] = specials.DEFAULT_SCENE end
        end
        for _, sv in ipairs(sc.set_variables) do
          if sv.name == "v_current_scene" and sv.value ~= "" then edges[#edges + 1] = sv.value end
        end
        for _, d in ipairs(edges) do
          if scenes[d] and not seen[d] then seen[d] = true; queue[#queue + 1] = d end
        end
      end
    end
    local unreachable = {}
    for id in pairs(scenes) do
      if not seen[id] then unreachable[#unreachable + 1] = id end
    end
    table.sort(unreachable)
    -- As of magium-dev @ 51f5aa9: exactly 14 unreachable scenes, all
    -- `B{2,3}-Ch..-Credits` — no `choice()`/`v_current_scene` in the corpus
    -- targets them (magium-dev reaches them through chapter-transition logic,
    -- not the scene graph). Ceiling 16 leaves slack; a real regression (a whole
    -- branch orphaned) blows well past it. Bump deliberately + note if the
    -- corpus grows.
    for _, id in ipairs(unreachable) do
      assert.message(id .. " is unreachable and is not a *-Credits scene")
        .is_truthy(id:match("%-Credits$"))
    end
    assert.message(string.format("%d unreachable scenes:\n  %s",
      #unreachable, table.concat(unreachable, "\n  "))).is_true(#unreachable <= 16)
  end)
end)

-- Content integrity for the achievements menu (Phase V.5, item 2). The menu is
-- driven by achievements{1,2,3}.json (136 entries); the toast + unlock is driven
-- by achievement() calls in the corpus. A mismatch = an achievement that can
-- never be earned (menu entry, no unlock path) or a toast for something the menu
-- never lists. Complements oracle-corpus (per-scene RENDER parity) — this is the
-- cross-file wiring check.
describe("achievements content integrity (JSON <-> corpus)", function()
  -- Unlocks with no in-story achievement() call: shown by their own modal
  -- (stats.ejs / the consolation rule), not main.ejs's per-scene loop. Kept in
  -- sync with main.lua openStats() (#11) and engine/store.lua (#13 consolation).
  local NO_ACHIEVEMENT_CALL = {
    v_ac_ch6_immersion = "main.lua openStats() — special case #11 (stats.ejs:175)",
    v_ac_b3_ch9_prize  = "engine/specials.lua CONSOLATION — special case, store.lua:41",
  }

  local ach_call_vars, json_vars

  setup(function()
    local scenes = load_all()
    ach_call_vars = {}
    for id, sc in pairs(scenes) do
      for _, a in ipairs(sc.achievements) do ach_call_vars[a.variable] = id end
    end

    json_vars = {}
    local loc = Locale.load("./data", "en")
    for book = 1, loc:achievement_book_count() do
      for _, key in ipairs(loc:achievement_chapters(book)) do
        for _, e in ipairs(loc:achievement_entries(book, key)) do
          assert(not json_vars[e.variable], "duplicate achievement variable in JSON: " .. e.variable)
          json_vars[e.variable] = key
        end
      end
    end
  end)

  it("every menu (JSON) achievement has an unlock path (achievement() call or a known special case)", function()
    local orphans = {}
    for v, key in pairs(json_vars) do
      if not ach_call_vars[v] and not NO_ACHIEVEMENT_CALL[v] then
        orphans[#orphans + 1] = string.format("%s (%s) — never unlocked", v, key)
      end
    end
    table.sort(orphans)
    assert.message("orphaned achievements:\n  " .. table.concat(orphans, "\n  ")).are.same({}, orphans)
  end)

  it("every achievement() call in the corpus has a matching menu (JSON) entry", function()
    local strays = {}
    for v, id in pairs(ach_call_vars) do
      if not json_vars[v] then
        strays[#strays + 1] = string.format("%s (called at %s) — no menu entry", v, id)
      end
    end
    table.sort(strays)
    assert.message("achievement() calls with no JSON entry:\n  " .. table.concat(strays, "\n  ")).are.same({}, strays)
  end)

  it("the known no-achievement()-call unlocks still lack a call (else drop them from the exception list)", function()
    for v, why in pairs(NO_ACHIEVEMENT_CALL) do
      assert.message(v .. " now HAS an achievement() call — remove it from NO_ACHIEVEMENT_CALL (" .. why .. ")")
        .is_nil(ach_call_vars[v])
      assert.message(v .. " is in NO_ACHIEVEMENT_CALL but not in the JSON menu at all")
        .is_truthy(json_vars[v])
    end
  end)
end)
