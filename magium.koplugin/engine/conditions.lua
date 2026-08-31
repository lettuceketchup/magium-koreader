-- engine/conditions.lua — DNF condition evaluation.
-- Port of magium-dev/src/utils.js:apply_condition / apply_conditions @ 51f5aa9.
-- PURE: Lua stdlib only.

local M = {}
M.failures = {}   -- malformed atoms seen this session (dev diagnostics only)

function M.eval_atom(atom, view)
  if atom == nil or atom == "" then return true end
  if atom == "True" then return true end
  local name, op, num = atom:match("^([%w_]*) ([<>=!]+) (%d+)$")
  if not name then
    M.failures[#M.failures + 1] = atom
    return nil
  end
  local value = tonumber(num)
  local v = tonumber(view[name] or 0) or 0
  if op == ">" then return v > value
  elseif op == "<" then return v < value
  elseif op == "<=" then return v <= value
  elseif op == ">=" then return v >= value
  elseif op == "!=" then return v ~= value
  elseif op == "==" then return v == value end
  M.failures[#M.failures + 1] = atom
  return nil
end

function M.eval(dnf, view)
  if not dnf then return true end
  for _, and_group in ipairs(dnf) do
    local all_true = true
    for _, atom in ipairs(and_group) do
      if not M.eval_atom(atom, view) then all_true = false; break end
    end
    if all_true then return true end
  end
  return false
end

return M
