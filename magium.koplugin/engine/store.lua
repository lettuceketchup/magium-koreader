-- engine/store.lua — the flat v_* variable map. PURE: Lua stdlib only.
-- Port of the write-side semantics in magium-dev/public/scripts/utils.js
-- (storeItem: +N/-N resolution; the v_ac_ "seen" latch; the consolation rule).

local Store = {}
Store.__index = Store

function Store.new(initial)
  local self = setmetatable({}, Store)
  self.v = {}
  if initial then
    for k, val in pairs(initial) do self.v[k] = val end
  end
  return self
end

function Store:get(name) return self.v[name] end

function Store:set(name, value)
  value = tostring(value)

  -- v_ac_* "seen" freeze: once the flag is (numerically) 2, no further write
  -- lands — for ANY incoming value. magium-dev storeVariable: if (data[key] != 2).
  if name:sub(1, 5) == "v_ac_" and (tonumber(self.v[name] or 0) or 0) == 2 then
    return
  end

  -- +N / -N resolve on write against the current numeric value.
  local sign = value:sub(1, 1)
  if sign == "+" or sign == "-" then
    local delta = tonumber(value)
    if delta then
      value = tostring((tonumber(self.v[name] or 0) or 0) + delta)
    end
  end
  self.v[name] = value

  -- special case #12: consolation counter reaches exactly 5 → prize flag.
  -- (storeItem: data[key] == 5. In practice the freeze above caps this counter
  --  at 2, so this never fires in real play — kept for faithful parity.)
  if name == "v_ac_b3_ch9_consolation" and tonumber(value) == 5 then
    self.v.v_ac_b3_ch9_prize = "1"
  end
end

function Store:view()
  local out = {}
  for k, val in pairs(self.v) do out[k] = val end
  return out
end

function Store:snapshot()
  local out = {}
  for k, val in pairs(self.v) do out[k] = val end
  return out
end

function Store:restore(t)
  self.v = {}
  for k, val in pairs(t or {}) do self.v[k] = val end
end

return Store
