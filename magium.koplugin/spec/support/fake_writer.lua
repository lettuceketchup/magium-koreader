-- Test double for save/manager's injected writer. Mirrors the real adapter's
-- shape: plain `read` / `write` fields (called with a dot, no `self`), with
-- `data` (persisted blob) and `writes` (count) exposed for assertions.
local FakeWriter = {}
function FakeWriter.new(seed)
  local w = { data = seed or {}, writes = 0 }
  w.read = function() return w.data end
  w.write = function(t)
    w.writes = w.writes + 1
    w.data = {}
    for k, v in pairs(t) do w.data[k] = v end
  end
  return w
end
return FakeWriter
