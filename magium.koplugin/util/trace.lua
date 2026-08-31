-- util/trace.lua — optional structured action trace for bug reports (spec §9.2,
-- ADR-005). OFF by default. Buffers { t=<ms>, ev=<kind>, ...data } records and
-- flushes them as JSON Lines to an injected writer; mirrors a one-line summary
-- to an injected log fn. PURE: Lua stdlib + engine/vendor/json. No KOReader.

local json = require("engine/vendor/json")

local M = {
  enabled = false,
  _buf = {},
  _writer = nil,
  _log = nil,
  _clock = function() return 0 end,
  _flush_every = 32,
  _count = 0,
}

function M.configure(opts)
  M.enabled = opts.enabled and true or false
  M._writer = opts.writer
  M._log = opts.log
  M._clock = opts.clock or function() return 0 end
  M._flush_every = opts.flush_every or 32
  M._buf = {}
  M._count = 0
end

-- "kind k=v k=v" for the mirror log — scalar fields only, key-sorted for stable output.
local function summary(kind, data)
  local parts = { kind }
  if data then
    local keys = {}
    for k in pairs(data) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local v = data[k]
      local tv = type(v)
      if tv == "string" or tv == "number" or tv == "boolean" then
        parts[#parts + 1] = k .. "=" .. tostring(v)
      end
    end
  end
  return table.concat(parts, " ")
end

function M.event(kind, data)
  if not M.enabled then return end
  local rec = { t = M._clock(), ev = kind }
  if data then
    for k, v in pairs(data) do rec[k] = v end
  end
  M._buf[#M._buf + 1] = rec
  if M._log then M._log("[MGM] " .. summary(kind, data)) end
  M._count = M._count + 1
  if M._count >= M._flush_every then M.flush() end
end

function M.flush()
  if M.enabled and M._writer then
    for _, rec in ipairs(M._buf) do M._writer(json.encode(rec)) end
  end
  M._buf = {}
  M._count = 0
end

return M
