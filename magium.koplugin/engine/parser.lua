-- engine/parser.lua — .magium text → scene tables.
-- Port of magium-dev/src/parser.js @ 51f5aa9, hardened per 02 §4 (R1–R10).
-- PURE: Lua stdlib only. No KOReader imports.

local M = {}

-- Plain-substring split (JS String.prototype.split with a string arg).
local function split_plain(str, sep)
  local out, start = {}, 1
  while true do
    local i, j = str:find(sep, start, true)
    if not i then
      out[#out + 1] = str:sub(start)
      return out
    end
    out[#out + 1] = str:sub(start, i - 1)
    start = j + 1
  end
end
M._split_plain = split_plain

-- parseConditions: strip the FIRST '(' and FIRST ')' (JS .replace with a string
-- literal replaces one occurrence), then DNF-split on " || " / " && ".
function M.parse_conditions(str)
  if not str or str == "" then return nil end
  local s = str
  local i = s:find("(", 1, true)
  if i then s = s:sub(1, i - 1) .. s:sub(i + 1) end
  local j = s:find(")", 1, true)
  if j then s = s:sub(1, j - 1) .. s:sub(j + 1) end
  if s:find("[()]") then
    error("parse_conditions: nested group not supported (02 R4): " .. tostring(str))
  end
  local dnf = {}
  for _, or_part in ipairs(split_plain(s, " || ")) do
    dnf[#dnf + 1] = split_plain(or_part, " && ")
  end
  return dnf
end

return M
