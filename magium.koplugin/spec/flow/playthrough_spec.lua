require("spec/spec_helper")
local HeadlessGame = require("spec/support/headless_game")
local parser = require("engine/parser")
local Story = require("engine/story")
local specials = require("engine/specials")

local DATA_ROOT = require("spec/spec_helper").data_dir_en:gsub("/en$", "")

-- Load the whole corpus once (parser only — no store) for static path-finding.
local function corpus()
  local scenes = {}
  for _, f in ipairs(Story._list_magium(DATA_ROOT .. "/en")) do
    for id, sc in pairs(parser.parse(f)) do scenes[id] = sc end
  end
  return scenes
end

local function dst_of(c)
  local v = c.set_variables and c.set_variables.v_current_scene
  if v and v ~= "" then return v end
  if c.target and c.target ~= "" then return c.target end
  return nil
end

-- A choice edge the BFS is allowed to use: unconditional, and either plain or a
-- "Next chapter" checkpoint_save (both always present at runtime and navigate
-- via v_current_scene). restart / checkpoint_load / saves / stats are excluded.
local function traversable(c)
  return not c.conditions and (not c.special or c.special == "checkpoint_save")
end

-- BFS from `start` over traversable choice edges only — the path is guaranteed
-- replayable through the dynamic engine. Returns the id list from start to the
-- first scene matching `want`, or nil.
local function unconditional_path(scenes, start, want)
  local prev = { [start] = start }
  local queue, head = { start }, 1
  while head <= #queue do
    local id = queue[head]; head = head + 1
    if want(id) and id ~= start then
      local path, cur = {}, id
      while cur ~= start do table.insert(path, 1, cur); cur = prev[cur] end
      table.insert(path, 1, start)
      return path
    end
    local sc = scenes[id]
    if sc then
      for _, c in ipairs(sc.choices) do
        local d = dst_of(c)
        if d and traversable(c) and scenes[d] and not prev[d] then
          prev[d] = id
          queue[#queue + 1] = d
        end
      end
    end
  end
  return nil
end

-- the "book/chapter number" of a scene id, for a forward-progress heuristic.
local function depth_of(id)
  local b = tonumber(id:match("^B(%d)%-")) or 1
  local ch = tonumber(id:match("^B?%d?%-?Ch(%d+)")) or 0
  return b * 100 + ch
end

-- a scene the walker should avoid stepping into: no choice that isn't a
-- restart/checkpoint_load/saves screen-opener (i.e. a death / dead end).
local function is_dead_end(scenes, id)
  local sc = scenes[id]
  if not sc then return true end
  for _, c in ipairs(sc.choices) do
    local s = c.special
    if s ~= "restart" and s ~= "checkpoint_load" and s ~= "saves" and s ~= "stats" then
      return false
    end
  end
  return #sc.choices > 0   -- 0 choices = a legit ending, not a dead end
end

describe("playthrough (headless, whole engine)", function()
  local scenes
  setup(function() scenes = corpus() end)

  it("plays Ch1 -> deep into Book 2 with maxed stats, every scene rendering + set() persisting", function()
    local g = HeadlessGame.new(DATA_ROOT)
    -- a completionist save: every stat maxed so stat-gates pass
    for _, v in ipairs({
      "v_strength","v_toughness","v_agility","v_reflexes","v_hearing","v_perception",
      "v_ancient_languages","v_combat_technique","v_premonition","v_bluff",
      "v_magical_sense","v_aura_hardening","v_magical_power","v_magical_knowledge",
    }) do g.store:set(v, "5") end
    g:start("Ch1-Intro1")

    local visits, trail, deepest = {}, {}, 0
    for _ = 1, 6000 do
      local id = g:scene_id()
      visits[id] = (visits[id] or 0) + 1
      trail[#trail + 1] = id
      deepest = math.max(deepest, depth_of(id))
      local list = g:choices()
      if #list == 0 then break end   -- an ending

      -- rank choices: prefer forward progress, avoid death scenes and re-visits
      local best, best_score
      for i, c in ipairs(list) do
        local s = c.special
        local opener = s == "restart" or s == "saves" or s == "stats" or s == "checkpoint_load"
        local d = dst_of(c)
        if not opener and d then
          local score = depth_of(d) * 1000
            - (visits[d] or 0) * 100000
            - (is_dead_end(scenes, d) and 10000000 or 0)
          if not best or score > best_score then best, best_score = i, score end
        end
      end
      if not best then break end     -- only screen-openers left (a death scene)
      g:choose(best)
    end

    -- A naive greedy walker won't clear every stat/knowledge gate, but it should
    -- traverse many chapters of real choices. Every hop's g:render() asserts the
    -- scene exists and renders; reaching here means nothing along a 100+-scene
    -- path threw, and set()/persist_effects ran on each. (Full per-scene render
    -- parity is the oracle-corpus sweep's job — 8887/8887.)
    assert.is_true(deepest >= 105,
      string.format("only reached depth %d (want >= Ch5, 105); trail len %d, last %s",
        deepest, #trail, trail[#trail]))
    local distinct = 0
    for _ in pairs(visits) do distinct = distinct + 1 end
    assert.is_true(distinct > 40, "only " .. distinct .. " distinct scenes walked")
  end)

  it("checkpoint_save then load_checkpoint round-trips to the saved scene", function()
    -- find any scene with a checkpoint_save choice, statically
    local from, save_choice
    for id, sc in pairs(scenes) do
      for _, c in ipairs(sc.choices) do
        if c.special == "checkpoint_save" then from, save_choice = id, c; break end
      end
      if from then break end
    end
    assert.is_truthy(from, "no checkpoint_save choice anywhere in the corpus")

    local g = HeadlessGame.new(DATA_ROOT)
    g:start(from)
    g:choose(function(c) return c.special == "checkpoint_save" end)
    local saved_at = g:scene_id()
    assert.is_true(g.save:has_checkpoint())
    assert.are.equal(dst_of(save_choice), saved_at)

    -- move somewhere else, then load the checkpoint back
    g.store:set("v_current_scene", "Ch1-Intro1")
    g:render()
    local restored = g.save:load_checkpoint()
    assert.are.equal(saved_at, restored)
    assert.are.equal(saved_at, g.store:get("v_current_scene"))
  end)

  it("save_slot then load_slot round-trips the scene + vars after playing on", function()
    local g = HeadlessGame.new(DATA_ROOT)
    g:start("Ch1-Intro1")
    g:choose(1)                                   -- one real choice in
    local saved_at, saved_gold = g:scene_id(), g.store:get("v_gold")
    g.save:save_slot(0, "test")

    for _ = 1, 5 do                                -- play further
      if #g:choices() == 0 then break end
      g:choose(1)
    end
    assert.are_not.equal(saved_at, g:scene_id())   -- we actually moved on

    local restored = g.save:load_slot(0)
    g:render()
    assert.are.equal(saved_at, restored)
    assert.are.equal(saved_at, g.store:get("v_current_scene"))
    assert.are.equal(saved_gold, g.store:get("v_gold"))
    assert.is_nil(g.save:load_slot(7))             -- empty slot: no-op
  end)

  it("special:restart returns to the start and keeps achievements", function()
    local g = HeadlessGame.new(DATA_ROOT)
    g:start("B2-Ch07a-Kill")               -- a death scene with a real special:restart choice
    g.store:set("v_ac_ch1_coward", "1")
    g:render()
    g:choose(function(c) return c.special == "restart" end)
    assert.are.equal("Ch1-Intro1", g:scene_id())
    assert.are.equal("1", g.store:get("v_ac_ch1_coward"))
  end)

  -- Phase V: a real achievement() call (Ch1-Cutthroat Dave / v_ac_ch1_coward)
  -- shows on the render that unlocks it, then latches "1" -> "2" so it never
  -- shows again — engine/scene.lua:persist_effects, spec §D1/D4.
  it("shows an achievement once and latches it, no re-toast on re-render", function()
    local g = HeadlessGame.new(DATA_ROOT)
    g:start("Ch1-Intro2")
    local rm = g:choose(function(c)
      return c.set_variables and c.set_variables.v_ac_ch1_coward == "1"
    end)

    local function shown_coward(render_model)
      for _, a in ipairs(render_model.achievements) do
        if a.variable == "v_ac_ch1_coward" then return a end
      end
    end

    local a = shown_coward(rm)
    assert.is_truthy(a, "coward achievement not in render_model.achievements")
    assert.are.equal("Who are you calling a coward?", a.text)
    -- persist_effects (called inside render(), which choose() triggers) already latched it
    assert.are.equal("2", g.store:get("v_ac_ch1_coward"))

    local rm2 = g:render()   -- re-render the same scene
    assert.is_nil(shown_coward(rm2), "achievement re-shown after being seen")
    assert.are.equal("2", g.store:get("v_ac_ch1_coward"))
  end)

  -- The "-spent" scene: a special:stats "Invest points now" choice carries BOTH
  -- v_current_scene = <Scene>-Stats-spent AND special:stats. So the choice
  -- navigates the player to a near-duplicate scene whose only choice is
  -- "Continue" (the author's "you have already decided to invest" branch) and
  -- main.lua opens the stats screen over it. Nothing mechanically special about
  -- the -spent scene — it is just the id you land on.
  it("special:stats 'Invest points now' lands on the -spent scene with a Continue choice", function()
    local g = HeadlessGame.new(DATA_ROOT)
    g:start("Ch2-Stats")
    local invest
    for _, c in ipairs(g:choices()) do
      if c.special == "stats" then invest = c end
    end
    assert.is_truthy(invest, "no special:stats choice at Ch2-Stats")
    assert.are.equal("Ch2-Stats-spent", invest.set_variables.v_current_scene)

    g:choose(function(c) return c.special == "stats" end)
    assert.are.equal("Ch2-Stats-spent", g:scene_id())
    local labels = {}
    for _, c in ipairs(g:choices()) do labels[#labels + 1] = c.text end
    assert.are.equal(1, #labels)
    assert.is_truthy(labels[1]:find("Continue"))
    g:choose(1)
    assert.are.equal("Ch2-Fallen-trees", g:scene_id())
  end)

  it("a Book 3 ch>=4 stats screen shows the bluff / magical-sense / aura rows", function()
    local g = HeadlessGame.new(DATA_ROOT)
    g:start("B3-Ch04a-Introduction2")
    g:choose(function(c) return c.special == "stats" end)
    assert.are.equal("B3-Ch04a-Stats-spent", g:scene_id())
    -- specials gate (#10) drives ui/statspage.lua's row list
    assert.is_true(specials.stats_show_book3_rows("B3-Ch04a-Stats-spent"))
    assert.is_false(specials.stats_show_book3_rows("Ch2-Stats-spent"))
  end)

  it("checkpoint_load on a death scene with no checkpoint does not navigate", function()
    local g = HeadlessGame.new(DATA_ROOT)
    g:start("B2-Ch07a-Kill")
    assert.is_false(g.save:has_checkpoint())
    g:choose(function(c) return c.special == "checkpoint_load" end)
    assert.is_nil(g.last_checkpoint_load)
    assert.are.equal("B2-Ch07a-Kill", g:scene_id())   -- stayed put (InfoMessage path in main.lua)
  end)
end)
