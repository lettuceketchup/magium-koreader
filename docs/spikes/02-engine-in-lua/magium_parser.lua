-- magium_parser.lua — Lua port of ../magium-dev/src/parser.js:parse() @ 51f5aa9
--
-- Faithful line-by-line translation of the JS reader, including its two known
-- quirks (kept deliberately, not "fixed", since this spike's job is to prove
-- or disprove *faithful* portability, not to improve on the original):
--   1. `currentParagraph` is never reset when a new `ID:` line starts a scene
--      (JS doesn't do it either) — harmless as long as every scene's last
--      construct is a choice()/#if/`}` that flushes it, which holds for the
--      3 files this spike parses.
--   2. The very first `currentScene` (before any `ID:` line) is a bare `{}`
--      that gets pushed and later dropped — mirrored via `first_scene_seen`.
--
-- Regexes with named capture groups don't exist in Lua patterns, so each
-- construct is matched with hand-written boundary scans instead of one
-- Lua-pattern-per-JS-regex. Every scan reproduces the *specific* backtracking
-- result the JS regex would produce for this grammar (documented inline),
-- not a generic regex engine — safe only because 02-magium-format-spec.md's
-- construct corpus scan found this grammar has no ambiguous cases in the
-- shipped data (single-paren conditions, no multi-digit set(), etc.)

local M = {}

-- Plain-substring split (JS `.split("literal")` equivalent; not a pattern).
local function split_plain(str, sep)
  local out = {}
  local start = 1
  while true do
    local i, j = str:find(sep, start, true)
    if not i then
      table.insert(out, str:sub(start))
      break
    end
    table.insert(out, str:sub(start, i - 1))
    start = j + 1
  end
  return out
end

-- parseConditions() in utils.js: strips the FIRST '(' and FIRST ')' only
-- (JS String.replace with a string, not a regex, replaces one occurrence),
-- then splits DNF as "OR of ANDs" on " || " / " && ".
local function parse_conditions(str)
  if not str or str == "" then return nil end
  local s = str
  local i = s:find("(", 1, true)
  if i then s = s:sub(1, i - 1) .. s:sub(i + 1) end
  local j = s:find(")", 1, true)
  if j then s = s:sub(1, j - 1) .. s:sub(j + 1) end
  local conds = {}
  for _, orPart in ipairs(split_plain(s, " || ")) do
    table.insert(conds, split_plain(orPart, " && "))
  end
  return conds
end
M.parse_conditions = parse_conditions

-- set\((?<varName>.*),(?<value>[+\-]?[0-9])\)( if (?<condition>.*))?
-- varName is greedy `.*` so JS backtracks to the LAST comma that leaves a
-- valid "<sign?><digit>)" tail — scan from the right for that comma.
local function try_match_set(line)
  if line:sub(1, 4) ~= "set(" then return nil end
  local body = line:sub(5)
  for i = #body, 1, -1 do
    if body:sub(i, i) == "," then
      local sign, digit, restAfter = body:sub(i + 1):match("^([%+%-]?)(%d)%)(.*)$")
      if digit then
        local varName = body:sub(1, i - 1)
        local condition = nil
        if restAfter:sub(1, 4) == " if " then condition = restAfter:sub(5) end
        return varName, sign .. digit, condition
      end
    end
  end
  return nil
end

-- achievement\("(?<text>.*)",(?<variable>.*)\)
-- text is greedy up to the LAST '",' with variable (`.*`) greedy to the final ')'.
local function try_match_achievement(line)
  if line:sub(1, 12) ~= "achievement(" then return nil end
  local body = line:sub(13)
  if body:sub(1, 1) ~= '"' then return nil end
  body = body:sub(2)
  if body:sub(-1) ~= ")" then return nil end
  local core = body:sub(1, #body - 1)
  local idx
  local searchFrom = 1
  while true do
    local i, j = core:find('",', searchFrom, true)
    if not i then break end
    idx = i
    searchFrom = i + 1
  end
  if not idx then return nil end
  return core:sub(1, idx - 1), core:sub(idx + 2)
end

-- choice\("(?<text>.*)", (?<target>[\w\-\s]*), (?<setVariables>...)((, )?special:(?<special>.*?))?\)( if (?<condition>.*))?
local function try_match_choice(line)
  if line:sub(1, 7) ~= "choice(" then return nil end
  local rest = line:sub(8)
  if rest:sub(1, 1) ~= '"' then return nil end
  rest = rest:sub(2)

  -- text: greedy `.*` up to the LAST '", ' (handles the doubled-quote
  -- "spoken text" idiom, e.g. choice(""...""...) — see 02 §3).
  local idx, idxEnd
  local searchFrom = 1
  while true do
    local i, j = rest:find('", ', searchFrom, true)
    if not i then break end
    idx, idxEnd = i, j
    searchFrom = i + 1
  end
  if not idx then return nil end
  local text = rest:sub(1, idx - 1)
  local afterText = rest:sub(idxEnd + 1)

  -- target: [\w\-\s]* excludes ',' so it unambiguously ends at the first comma.
  local commaI = afterText:find(",", 1, true)
  if not commaI then return nil end
  local target = afterText:sub(1, commaI - 1)
  local remainder = afterText:sub(commaI + 1)
  if remainder:sub(1, 1) == " " then remainder = remainder:sub(2) end

  -- setVariables/special values never contain parens in this grammar, so the
  -- first ')' from here is unambiguously the choice(...) call's own close.
  local closeI = remainder:find(")", 1, true)
  if not closeI then return nil end
  local core = remainder:sub(1, closeI - 1)
  local afterClose = remainder:sub(closeI + 1)
  local condition = nil
  if afterClose:sub(1, 4) == " if " then condition = afterClose:sub(5) end

  local setVars = {}
  local special = nil
  if core ~= "" then
    for _, token in ipairs(split_plain(core, ", ")) do
      if token ~= "" then
        if token:sub(1, 8) == "special:" then
          special = token:sub(9)
        else
          local eqI = token:find(" = ", 1, true)
          if eqI then
            setVars[token:sub(1, eqI - 1)] = token:sub(eqI + 3)
          end
        end
      end
    end
  end

  return {
    text = text,
    target = target,
    setVariables = setVars,
    special = special,
    conditions = parse_conditions(condition),
  }
end

-- #if\((?<condition>.*)\) — condition is greedy `.*` up to the LAST ')' on the line.
local function try_match_if(line)
  if line:sub(1, 4) ~= "#if(" then return nil end
  local body = line:sub(5)
  local lastClose = nil
  for i = #body, 1, -1 do
    if body:sub(i, i) == ")" then lastClose = i; break end
  end
  if not lastClose then return nil end
  return body:sub(1, lastClose - 1)
end

-- parse(filename): mirrors parser.js line-by-line, returns a { [sceneId] = scene }
-- dict (equivalent to the JS `scenes_dict` after `scenes.slice(1)`).
function M.parse(filename)
  local scenesOrder = {}
  local currentScene = {} -- JS: `let currentScene = {}` — the bogus leading placeholder
  local currentParagraph = { text = "", conditions = nil }
  local skip = false

  for line in io.lines(filename) do
    if line:sub(1, 2) == "ID" then
      table.insert(scenesOrder, currentScene)
      currentScene = {
        id = line:match("^ID: (.*)$"),
        paragraphs = {}, statChecks = {}, setVariables = {}, choices = {}, achievements = {},
      }
    elseif line:sub(1, 4) == "TEXT" then
      skip = true
    elseif skip then
      skip = false
    else
      local varName, value, cond = try_match_set(line)
      if varName then
        table.insert(currentScene.setVariables, { name = varName, value = value, conditions = parse_conditions(cond) })
      else
        local text, variable = try_match_achievement(line)
        if text then
          table.insert(currentScene.achievements, { text = text, variable = variable })
        else
          local choice = try_match_choice(line)
          if choice then
            if currentParagraph.text ~= "" then
              table.insert(currentScene.paragraphs, currentParagraph)
            end
            currentParagraph = { text = "", conditions = nil }
            table.insert(currentScene.choices, choice)
          else
            local ifCond = try_match_if(line)
            if ifCond ~= nil then
              if currentParagraph.text ~= "" then
                table.insert(currentScene.paragraphs, currentParagraph)
              end
              currentParagraph = { text = "", conditions = parse_conditions(ifCond) }
            elseif line:sub(1, 1) == "}" then
              table.insert(currentScene.paragraphs, currentParagraph)
              currentParagraph = { text = "", conditions = nil }
            else
              currentParagraph.text = currentParagraph.text .. line .. "<br/>"
            end
          end
        end
      end
    end
  end
  if currentParagraph.text ~= "" then
    table.insert(currentScene.paragraphs, currentParagraph)
  end
  table.insert(scenesOrder, currentScene)

  local dict = {}
  for i, scene in ipairs(scenesOrder) do
    if i > 1 then dict[scene.id] = scene end -- drop the leading placeholder (JS `scenes.slice(1)`)
  end
  return dict
end

return M
