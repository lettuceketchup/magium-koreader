-- save/manager.lua — Phase I: currentState autosave (debounced) + achievements
-- + resume. Checkpoint blob and the 50 manual slots are Phase III.
-- The file I/O + scheduler are injected so the logic is testable without KOReader.

local SaveManager = {}
SaveManager.__index = SaveManager

local function is_ac(k) return k:sub(1, 5) == "v_ac_" end

function SaveManager.new(opts)
  local self = setmetatable({}, SaveManager)
  self.store = assert(opts.store)
  self.writer = assert(opts.writer)
  self.schedule = assert(opts.schedule)
  self.unschedule = assert(opts.unschedule)
  self.debounce = opts.debounce or 5
  self._timer = nil
  return self
end

function SaveManager:_split()
  local current, ach = {}, {}
  for k, v in pairs(self.store:snapshot()) do
    if is_ac(k) then ach[k] = v else current[k] = v end
  end
  return current, ach
end

function SaveManager:_write(reason)
  local current, ach = self:_split()
  local existing = self.writer:read() or {}
  self.writer:write({
    currentState = current,
    achievements = ach,
    checkpoint = existing.checkpoint,   -- preserved untouched in Phase I
    slots = existing.slots,
  })
end

function SaveManager:load()
  local data = self.writer:read() or {}
  local merged = {}
  for k, v in pairs(data.currentState or {}) do merged[k] = v end
  for k, v in pairs(data.achievements or {}) do merged[k] = v end
  self.store:restore(merged)
  return self.store:get("v_current_scene")
end

function SaveManager:touch()
  if self._timer then self.unschedule(self._timer) end
  self._timer = self.schedule(self.debounce, function()
    self._timer = nil
    self:_write("debounce")
  end)
end

function SaveManager:flush_now(reason)
  if self._timer then self.unschedule(self._timer); self._timer = nil end
  self:_write(reason or "flush")
end

function SaveManager:on_achievement_unlocked()
  -- achievements are rare; flush the whole blob immediately.
  self:_write("achievement")
end

return SaveManager
