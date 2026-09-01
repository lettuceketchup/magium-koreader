-- headless_game.lua — the engine + save layers wired the way main.lua wires
-- them, minus KOReader. Lets a spec "play" the game: render a scene, pick a
-- choice, follow special: hooks, checkpoint, restart. Mirrors main.lua's
-- `advance` closure and `render_current` (main.lua:311-379) — if that flow
-- changes, change this too.

local parser = require("engine/parser")
local Story = require("engine/story")
local Store = require("engine/store")
local scene = require("engine/scene")
local specials = require("engine/specials")
local Locale = require("engine/locale")
local SaveManager = require("save/manager")
local FakeWriter = require("spec/support/fake_writer")

local HeadlessGame = {}
HeadlessGame.__index = HeadlessGame

function HeadlessGame.new(data_root)
  local self = setmetatable({}, HeadlessGame)
  self.story = Story.new{ data_dir = data_root, locale = "en", strategy = "eager" }
  self.story:preload()
  self.locale = Locale.load(data_root, "en")
  self.store = Store.new()
  self.save = SaveManager.new{
    store = self.store, writer = FakeWriter.new(),
    schedule = function(_, fn) return fn end,   -- no real timers in a spec
    unschedule = function() end,
    debounce = 5,
  }
  self.steps = 0
  return self
end

function HeadlessGame:start(scene_id)
  self.store:restore({})
  self.store:set("v_current_scene", scene_id or specials.DEFAULT_SCENE)
  return self:render()
end

function HeadlessGame:scene_id() return self.store:get("v_current_scene") end

-- render the current scene + persist its own set() effects (main.lua render_current)
function HeadlessGame:render()
  local id = self:scene_id()
  local st = assert(self.story:get_scene(id), "no such scene: " .. tostring(id))
  self.rm = scene.render(st, self.store:view(), self.locale)
  scene.persist_effects(self.store, self.rm)
  return self.rm
end

function HeadlessGame:choices() return self.rm.choices end

-- pick a choice: `sel` is an index, or a predicate f(choice, i) -> bool.
-- Applies set_vars + the special: hook, then re-renders. Returns the new rm.
function HeadlessGame:choose(sel)
  local list = self.rm.choices
  assert(#list > 0, "no choices at " .. self:scene_id())
  local c
  if type(sel) == "function" then
    for i, cc in ipairs(list) do if sel(cc, i) then c = cc; break end end
    assert(c, "no choice matched the predicate at " .. self:scene_id())
  else
    c = assert(list[sel], "choice #" .. tostring(sel) .. " missing at " .. self:scene_id())
  end

  for k, v in pairs(c.set_variables or {}) do self.store:set(k, v) end

  if c.special == "restart" then
    local keep = {}
    for k, v in pairs(self.store:snapshot()) do
      if k:sub(1, 5) == "v_ac_" then keep[k] = v end
    end
    self.store:restore(keep)
    self.store:set("v_current_scene", specials.DEFAULT_SCENE)
  elseif c.special == "checkpoint_save" then
    self.save:save_checkpoint()
  elseif c.special == "checkpoint_load" then
    local restored = self.save:load_checkpoint()
    self.last_checkpoint_load = restored   -- nil when there is no checkpoint
  end
  -- special:saves / :stats just open a screen in main.lua — no state change here.

  self.steps = self.steps + 1
  return self:render()
end

return HeadlessGame
