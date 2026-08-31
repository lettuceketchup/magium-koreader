local FakeWriter = {}
FakeWriter.__index = FakeWriter
function FakeWriter.new(seed)
  return setmetatable({ data = seed or {}, writes = 0 }, FakeWriter)
end
function FakeWriter:read() return self.data end
function FakeWriter:write(t)
  self.writes = self.writes + 1
  self.data = {}
  for k, v in pairs(t) do self.data[k] = v end
end
return FakeWriter
