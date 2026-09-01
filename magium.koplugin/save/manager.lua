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
  -- Phase III: the 50 manual slots. Optional — the engine specs build a manager
  -- without one. A { load(n)->tbl|nil, save(n,tbl), remove(n) } adapter, plain
  -- functions like `writer` (dot-called). Autosave never touches it.
  self.slotstore = opts.slotstore
  return self
end

local NUM_SLOTS = 50

function SaveManager:_split()
  local current, ach = {}, {}
  for k, v in pairs(self.store:snapshot()) do
    if is_ac(k) then ach[k] = v else current[k] = v end
  end
  return current, ach
end

-- `writer` is the injected { read()->table|nil, write(table) } adapter — plain
-- functions, NOT methods, so call them with a dot (a `:` would pass `self.writer`
-- as the argument and silently drop the real payload).
-- `reason` is intentionally unused here: callers pass it so the main.lua layer
-- can attach it to the trace/log record for that flush ("close", "suspend",
-- "achievement", "debounce"). This module stays pure — no logger dependency.
function SaveManager:_write(reason)   -- luacheck: ignore reason
  local current, ach = self:_split()
  local existing = self.writer.read() or {}
  self.writer.write({
    currentState = current,
    achievements = ach,
    checkpoint = existing.checkpoint,   -- preserved untouched in Phase I
    slots = existing.slots,
  })
end

function SaveManager:load()
  local data = self.writer.read() or {}
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

-- --- checkpoint blob (special:checkpoint_save / _load) ------------------------
-- magium-dev: the `checkpoint` slot is a full `currentState` snapshot (no
-- v_ac_*, which live in their own blob). checkpoint_save copies currentState ->
-- checkpoint; checkpoint_load copies it back. The 50 manual slots stay Phase III.

function SaveManager:save_checkpoint()
  local current, ach = self:_split()
  local existing = self.writer.read() or {}
  self.writer.write({
    currentState = current,
    achievements = ach,
    checkpoint = { state = current, date = os.time() },
    slots = existing.slots,
  })
end

function SaveManager:has_checkpoint()
  local data = self.writer.read() or {}
  return data.checkpoint ~= nil and data.checkpoint.state ~= nil
end

-- Restore a currentState snapshot into the store, keeping the live achievements
-- blob (parity: v_ac_* are permanent across a checkpoint / slot reload). Returns
-- the resume scene id. Shared by load_checkpoint and load_slot.
function SaveManager:_restore_snapshot(snap)
  local _, ach = self:_split()   -- live v_ac_* — permanent, not part of the snapshot
  local merged = {}
  for k, v in pairs(snap) do merged[k] = v end
  for k, v in pairs(ach) do merged[k] = v end
  self.store:restore(merged)
  return self.store:get("v_current_scene")
end

-- Returns the resume scene id, or nil if there is no checkpoint (store untouched).
function SaveManager:load_checkpoint()
  local data = self.writer.read() or {}
  if not (data.checkpoint and data.checkpoint.state) then return nil end
  return self:_restore_snapshot(data.checkpoint.state)
end

-- --- the 50 manual slots (Phase III, ADR-007) --------------------------------
-- Each slot is its own { load(n), save(n,t), remove(n) } blob:
-- { state = <currentState snapshot, no v_ac_*>, date = os.time(), name = <str> }.
-- The saves screen reads all 50 on open (no index) — see spec §3, D2.

function SaveManager:save_slot(n, name)
  local current = self:_split()
  self.slotstore.save(n, { state = current, date = os.time(), name = name })
end

-- nil for an empty slot (store untouched); else restore + return the resume scene.
function SaveManager:load_slot(n)
  local b = self.slotstore.load(n)
  if not (b and b.state) then return nil end
  return self:_restore_snapshot(b.state)
end

function SaveManager:delete_slot(n)
  self.slotstore.remove(n)
end

-- { [n] = { name, date } } for the occupied slots only.
function SaveManager:slots_meta()
  local meta = {}
  for n = 0, NUM_SLOTS - 1 do
    local b = self.slotstore.load(n)
    if b then meta[n] = { name = b.name, date = b.date } end
  end
  return meta
end

return SaveManager
