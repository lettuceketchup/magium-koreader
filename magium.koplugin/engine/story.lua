-- engine/story.lua — the parse-strategy seam (spec §7). PURE: Lua stdlib only.
-- Two strategies behind one interface; Milestone 0 picks the default.

local parser = require("engine/parser")

local Story = {}
Story.__index = Story

local function list_magium(dir)
  local files = {}
  local p = assert(io.popen('ls "' .. dir .. '"/*.magium 2>/dev/null'))
  for line in p:lines() do files[#files + 1] = line end
  p:close()
  table.sort(files)
  return files
end

local function file_size(path)
  local f = io.open(path, "rb")
  if not f then return 0 end
  local n = f:seek("end")
  f:close()
  return n
end

function Story.new(opts)
  assert(opts and opts.data_dir, "Story.new: data_dir required")
  local self = setmetatable({}, Story)
  self.data_dir = opts.data_dir
  self.locale = opts.locale or "en"
  self.strategy = opts.strategy or "eager"
  self.cache_store = opts.cache_store
  self.dir = self.data_dir .. "/" .. self.locale
  self.scenes = {}          -- id -> scene_table (eager: all; lazy: parsed so far)
  self.index = nil          -- lazy: id -> filename
  self._loaded_files = {}   -- lazy: filename -> true
  return self
end

function Story:_merge(dict)
  for id, scene in pairs(dict) do
    if self.scenes[id] then
      error("Story: duplicate scene id across files: " .. id)  -- R9
    end
    self.scenes[id] = scene
  end
end

function Story:preload(on_progress)
  if self.strategy == "eager" then
    local files = list_magium(self.dir)
    for i, f in ipairs(files) do
      self:_merge(parser.parse(f))
      if on_progress then on_progress(i, #files) end
    end
  else
    self:_build_index(on_progress)
  end
  return self
end

function Story:get_scene(id)
  if self.scenes[id] then return self.scenes[id] end
  if self.strategy == "lazy" then return self:_lazy_get(id) end
  return nil
end

function Story:count()
  local n = 0
  for _ in pairs(self.scenes) do n = n + 1 end
  return n
end

function Story:scene_ids()
  return coroutine.wrap(function()
    if self.strategy == "lazy" and self.index then
      for id in pairs(self.index) do coroutine.yield(id) end
    else
      for id in pairs(self.scenes) do coroutine.yield(id) end
    end
  end)
end

-- ---- lazy strategy (Task 15 fills _build_index / _lazy_get) --------------------
function Story:_build_index(on_progress) error("lazy strategy not built yet (Task 15)") end
function Story:_lazy_get(id) error("lazy strategy not built yet (Task 15)") end

-- exposed for Task 15's spec
Story._list_magium = list_magium
Story._file_size = file_size

return Story
