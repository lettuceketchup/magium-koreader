-- Test double for save/manager's injected `slotstore`. Mirrors the real adapter
-- shape: plain `load(n)` / `save(n, tbl)` / `remove(n)` (dot-called, no `self`).
-- `data` (the per-slot blobs) and `writes` / `removes` (counts) are exposed for
-- assertions.
local FakeSlotStore = {}
function FakeSlotStore.new(seed)
  local s = { data = seed or {}, writes = 0, removes = 0 }
  s.load = function(n) return s.data[n] end
  s.save = function(n, t)
    s.writes = s.writes + 1
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    s.data[n] = copy
  end
  s.remove = function(n)
    s.removes = s.removes + 1
    s.data[n] = nil
  end
  return s
end
return FakeSlotStore
