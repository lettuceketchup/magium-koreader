-- json.lua — minimal JSON *encoder* (no decoder; spike 02 never needs to read
-- JSON from Lua, only write it, so a decoder was left out of scope).
--
-- Because plain Lua tables can't distinguish "empty array" from "empty
-- object", arrays are tagged explicitly with `__isarray = true` (see `arr()`).
-- A dedicated NULL sentinel represents JSON `null`, since assigning Lua `nil`
-- to a table field just deletes the key instead of keeping a "present but
-- null" entry.

local M = {}

M.NULL = setmetatable({}, { __tostring = function() return "null" end })

function M.arr(list)
  list.__isarray = true
  return list
end

local function esc(s)
  s = s:gsub('\\', '\\\\')
  s = s:gsub('"', '\\"')
  s = s:gsub('\n', '\\n')
  s = s:gsub('\r', '\\r')
  s = s:gsub('\t', '\\t')
  s = s:gsub('%c', function(c) return string.format('\\u%04x', c:byte()) end)
  return s
end

function M.encode(v)
  if v == nil or v == M.NULL then return "null" end
  local t = type(v)
  if t == "boolean" then return tostring(v) end
  if t == "number" then
    if v == math.floor(v) then return string.format("%d", v) end
    return tostring(v)
  end
  if t == "string" then return '"' .. esc(v) .. '"' end
  if t == "table" then
    if v.__isarray then
      local n = 0
      for k in pairs(v) do
        if type(k) == "number" and k > n then n = k end
      end
      local parts = {}
      for i = 1, n do
        table.insert(parts, M.encode(v[i]))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local keys = {}
      for k in pairs(v) do table.insert(keys, k) end
      table.sort(keys)
      local parts = {}
      for _, k in ipairs(keys) do
        table.insert(parts, M.encode(tostring(k)) .. ":" .. M.encode(v[k]))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  error("json.encode: cannot encode type " .. t)
end

return M
