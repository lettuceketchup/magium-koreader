-- magium_utils.lua — Lua port of the condition-evaluation + stats slice of
-- ../magium-dev/src/utils.js @ 51f5aa9 (apply_condition, apply_conditions,
-- varToStat, parseStatCheck, statChecksToDisplay, getHeaderFromId).
--
-- Not ported: getLocaleData, capitalizeFirstLetter is inlined. localeData
-- itself (ui.json) is not parsed — the ~16 keys this spike's 3 files actually
-- need (14 statsXxxText + 2 statSuccess/Failed templates) are hardcoded in
-- spike_run.lua rather than writing a JSON *decoder* just for this. See
-- FINDING.md — this is the one deliberate scope-cut from a "full" engine port.

local M = {}

M.stats_variables = {
  v_strength = true, v_toughness = true, v_agility = true, v_reflexes = true,
  v_hearing = true, v_perception = true, v_ancient_languages = true,
  v_combat_technique = true, v_premonition = true, v_bluff = true,
  v_magical_sense = true, v_aura_hardening = true, v_magical_power = true,
  v_magical_knowledge = true,
}

-- getHeaderFromId: /(B(?<book>[0-9]*)-)?Ch(?<chapter>[0-9]*)[a-c]?-.*$/
function M.getHeaderFromId(sceneId)
  local book, chapter = sceneId:match("^B(%d*)%-Ch(%d*)[a-c]?%-")
  if not chapter then
    chapter = sceneId:match("^Ch(%d*)[a-c]?%-")
  end
  if not chapter or chapter == "" then return nil end
  book = book or "1"
  return "Book " .. book .. " - Chapter " .. tostring(tonumber(chapter))
end

-- apply_condition: /(?<varName>\w*) (?<condType><|>|>=|==|<=|!=) (?<value>[0-9]+)/
-- `values[variable] || 0` — values are strings; only nil/unset falls back to 0
-- (a numeric-string "0" is truthy in JS, so it is NOT replaced).
function M.apply_condition(entry, values)
  if not entry or entry == "" then return true end
  if entry == "True" then return true end
  -- Lua's %w is alnum-only (no underscore, unlike JS \w) — use [%w_] for identifiers.
  local varName, condType, valueStr = entry:match("^([%w_]*) ([<>=!]+) (%d+)$")
  if not varName then
    io.stderr:write("Condition fail\n" .. tostring(entry) .. "\n")
    return nil
  end
  local value = tonumber(valueStr)
  local raw = values[varName]
  local v = (raw ~= nil) and tonumber(raw) or 0
  if condType == ">" then return v > value
  elseif condType == "<" then return v < value
  elseif condType == "<=" then return v <= value
  elseif condType == ">=" then return v >= value
  elseif condType == "!=" then return v ~= value
  elseif condType == "==" then return v == value
  end
end

function M.apply_conditions(conditions, values)
  if not conditions then return true end
  for _, andGroup in ipairs(conditions) do
    local allTrue = true
    for _, cond in ipairs(andGroup) do
      if not M.apply_condition(cond, values) then allTrue = false; break end
    end
    if allTrue then return true end
  end
  return false
end

local function capitalize(s)
  return s:sub(1, 1):upper() .. s:sub(2)
end

function M.varToStat(varName)
  if varName == "v_agility" then return "statsSpeedText" end
  if varName == "v_perception" then return "statsObservationText" end
  local rest = varName:sub(3) -- strip "v_"
  local parts = {}
  local start = 1
  while true do
    local i, j = rest:find("_", start, true)
    if not i then table.insert(parts, capitalize(rest:sub(start))); break end
    table.insert(parts, capitalize(rest:sub(start, i - 1)))
    start = j + 1
  end
  return "stats" .. table.concat(parts) .. "Text"
end

function M.parseStatCheck(condition)
  local varName, condType, valueStr = condition:match("^([%w_]*) ([<>=!]+) (%d+)$")
  if not varName then
    io.stderr:write("Stat check parsing fail\n" .. tostring(condition) .. "\n")
    return nil
  end
  local value = tonumber(valueStr)
  if varName == "v_b3_ch1_unlock" and condType == "==" and value == 2 then
    return { variable = varName, value = value, success = false }
  end
  if not M.stats_variables[varName] then return nil end
  local success
  if condType == "<" then
    success = false
  elseif condType == "==" and value == 0 then
    success = false; value = 1
  elseif condType == ">=" or (condType == "==" and value ~= 0) then
    success = true
  elseif condType == ">" then
    success = true; value = value + 1
  end
  return { variable = M.varToStat(varName), value = value, success = success }
end

-- statChecksToDisplay(setVariables, values, localeData): `setVariables` here
-- is the caller's setVariables ++ paragraphs ++ choices concat (renderers.js
-- renderScene) — anything with a `.conditions` field is scanned.
function M.statChecksToDisplay(items, values, localeData)
  local seen = {}
  local out = {}
  for _, item in ipairs(items) do
    if item.conditions then
      for _, andGroup in ipairs(item.conditions) do
        local allTrue = true
        for _, c in ipairs(andGroup) do
          if not M.apply_condition(c, values) then allTrue = false; break end
        end
        if allTrue then
          for _, condition in ipairs(andGroup) do
            local sc = M.parseStatCheck(condition)
            if sc then
              local displayVar = sc.variable
              if displayVar ~= "v_b3_ch1_unlock" then displayVar = localeData[displayVar] end
              local key = tostring(displayVar) .. "|" .. tostring(sc.value) .. "|" .. tostring(sc.success)
              if not seen[key] then
                seen[key] = true
                table.insert(out, { variable = displayVar, value = sc.value, success = sc.success })
              end
            end
          end
        end
      end
    end
  end
  local hasLock = false
  for _, sc in ipairs(out) do
    if sc.variable == "v_b3_ch1_unlock" then hasLock = true; break end
  end
  if hasLock then
    local filtered = {}
    for _, sc in ipairs(out) do
      if sc.variable == "v_b3_ch1_unlock" then table.insert(filtered, sc) end
    end
    out = filtered
  end
  return out
end

return M
