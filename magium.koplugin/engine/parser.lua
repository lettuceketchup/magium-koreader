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

-- ------------------------------------------------------------- construct matchers
-- Each anchors to the line as given (callers pass an already-rtrimmed line).
-- Hand tokenizers, because Lua patterns have no named groups / alternation and
-- these JS regexes rely on greedy backtracking. Each reproduces the SPECIFIC
-- result the JS regex yields for this grammar (02 §3 corpus scan: no ambiguity).

-- set\((?<varName>.*),(?<value>[+\-]?[0-9])\)( if (?<condition>.*))?
-- varName is greedy .* → JS backtracks to the LAST comma leaving a valid
-- "<sign?><one-digit>)" tail. Scan commas from the right. Corpus set() has NO
-- space after the comma, matching the JS regex; do not tolerate one.
function M._match_set(line)
  if line:sub(1, 4) ~= "set(" then return nil end
  local body = line:sub(5)
  for i = #body, 1, -1 do
    if body:sub(i, i) == "," then
      local after_comma = body:sub(i + 1)
      -- R3: a multi-digit numeric literal must abort, not silently truncate.
      if after_comma:match("^[%+%-]?%d%d") then
        error("_match_set: multi-digit set() literal (02 R3): " .. line)
      end
      local sign, digit, after = after_comma:match("^([%+%-]?)(%d)%)(.*)$")
      if digit then
        local cond = nil
        if after:sub(1, 4) == " if " then cond = after:sub(5) end
        return body:sub(1, i - 1), sign .. digit, cond
      end
    end
  end
  return nil
end

-- achievement\("(?<text>.*)",(?<variable>.*)\)  — text greedy to LAST '",'.
function M._match_achievement(line)
  if line:sub(1, 12) ~= "achievement(" then return nil end
  local body = line:sub(13)
  if body:sub(1, 1) ~= '"' or body:sub(-1) ~= ")" then return nil end
  local core = body:sub(2, #body - 1)
  local idx, from = nil, 1
  while true do
    local i = core:find('",', from, true)
    if not i then break end
    idx, from = i, i + 1
  end
  if not idx then return nil end
  return core:sub(1, idx - 1), core:sub(idx + 2)
end

-- choice("<text>", <target>, <setvars>[, special:<s>])[ if <cond>]
function M._match_choice(line)
  if line:sub(1, 7) ~= "choice(" then return nil end
  local rest = line:sub(8)
  if rest:sub(1, 1) ~= '"' then return nil end
  rest = rest:sub(2)

  -- text: greedy .* up to the LAST '", ' (handles ""spoken"" labels).
  local idx, idx_end, from = nil, nil, 1
  while true do
    local i, j = rest:find('", ', from, true)
    if not i then break end
    idx, idx_end, from = i, j, i + 1
  end
  if not idx then return nil end
  local text = rest:sub(1, idx - 1)
  local after_text = rest:sub(idx_end + 1)

  -- target: [\w\-\s]* — cannot contain ',', so it ends at the first comma.
  local comma = after_text:find(",", 1, true)
  if not comma then return nil end
  local target = after_text:sub(1, comma - 1)
  local remainder = after_text:sub(comma + 1)
  if remainder:sub(1, 1) == " " then remainder = remainder:sub(2) end

  -- setvars/special never contain parens in this grammar → first ')' closes the call.
  local close = remainder:find(")", 1, true)
  if not close then return nil end
  local core = remainder:sub(1, close - 1)
  local after_close = remainder:sub(close + 1)
  local cond = nil
  if after_close:sub(1, 4) == " if " then cond = after_close:sub(5) end

  local set_vars, special = {}, nil
  if core ~= "" then
    for _, tok in ipairs(M._split_plain(core, ", ")) do
      if tok ~= "" then
        if tok:sub(1, 8) == "special:" then
          special = tok:sub(9)
        else
          local eq = tok:find(" = ", 1, true)
          if eq then set_vars[tok:sub(1, eq - 1)] = tok:sub(eq + 3) end
        end
      end
    end
  end

  return {
    text = text,
    target = target,
    set_vars = set_vars,
    special = special,
    conditions = M.parse_conditions(cond),
  }
end

-- #if\((?<condition>.*)\)  — greedy to the LAST ')' on the line.
function M._match_if(line)
  if line:sub(1, 4) ~= "#if(" then return nil end
  local body = line:sub(5)
  for i = #body, 1, -1 do
    if body:sub(i, i) == ")" then return body:sub(1, i - 1) end
  end
  return nil
end

M.anomalies = {}

local CONSTRUCT_PREFIXES = { "set(", "achievement(", "choice(", "#if(" }

local function looks_like_construct(line)
  for _, p in ipairs(CONSTRUCT_PREFIXES) do
    if line:sub(1, #p) == p then return true end
  end
  return false
end

-- parse(path): mirrors parser.js line-by-line. Returns { [id] = scene }.
function M.parse(path)
  M.anomalies = {}
  local order = {}
  local current = {}                       -- the bogus leading {} (JS: let currentScene = {})
  local para = { text = "", conditions = nil }
  local skip = false
  local seen_ids = {}

  local fh = assert(io.open(path, "r"), "cannot open " .. path)
  for raw in fh:lines() do
    local line = raw:gsub("\r$", "")       -- R10

    if line:sub(1, 4) == "ID: " then
      order[#order + 1] = current
      local id = line:sub(5)
      if seen_ids[id] then
        error("parser.parse: duplicate scene id '" .. id .. "' in " .. path)  -- R9
      end
      seen_ids[id] = true
      current = {
        id = id, paragraphs = {}, choices = {},
        set_variables = {}, achievements = {},
      }
    elseif line:sub(1, 5) == "TEXT:" then
      skip = true
    elseif skip then
      skip = false
    else
      local sn, sv, sc = M._match_set(line)
      local at, av = nil, nil
      local ch = nil
      local ic = nil
      if sn then
        current.set_variables[#current.set_variables + 1] =
          { name = sn, value = sv, conditions = M.parse_conditions(sc) }
      else
        at, av = M._match_achievement(line)
        if at then
          current.achievements[#current.achievements + 1] = { text = at, variable = av }
        else
          ch = M._match_choice(line)
          if ch then
            if para.text ~= "" then current.paragraphs[#current.paragraphs + 1] = para end
            para = { text = "", conditions = nil }
            current.choices[#current.choices + 1] = ch
          else
            ic = M._match_if(line)
            if ic ~= nil then
              if para.text ~= "" then current.paragraphs[#current.paragraphs + 1] = para end
              para = { text = "", conditions = M.parse_conditions(ic) }
            elseif line:sub(1, 1) == "}" then
              current.paragraphs[#current.paragraphs + 1] = para
              para = { text = "", conditions = nil }
            else
              if looks_like_construct(line) then
                M.anomalies[#M.anomalies + 1] =
                  path .. ": unmatched construct-like line: " .. line
              end
              para.text = para.text .. line .. "<br/>"
            end
          end
        end
      end
    end
  end
  fh:close()

  if para.text ~= "" then current.paragraphs[#current.paragraphs + 1] = para end
  order[#order + 1] = current

  local dict = {}
  for i = 2, #order do dict[order[i].id] = order[i] end   -- drop the leading {} (JS slice(1))
  return dict
end

return M
