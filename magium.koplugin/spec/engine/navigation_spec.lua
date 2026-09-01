require("spec/spec_helper")
local parser = require("engine/parser")
local Story = require("engine/story")
local specials = require("engine/specials")

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
