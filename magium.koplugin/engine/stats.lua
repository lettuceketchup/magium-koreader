-- engine/stats.lua — stat-check display logic.
-- Port of magium-dev/src/utils.js:varToStat / parseStatCheck / statChecksToDisplay
-- @ 51f5aa9. PURE: Lua stdlib + engine/conditions.

local conditions = require("engine/conditions")

local M = {}

M.stat_variables = {}
for _, v in ipairs({
  "v_strength", "v_toughness", "v_agility", "v_reflexes", "v_hearing",
  "v_perception", "v_ancient_languages", "v_combat_technique", "v_premonition",
  "v_bluff", "v_magical_sense", "v_aura_hardening", "v_magical_power",
  "v_magical_knowledge",
}) do M.stat_variables[v] = true end

local function capitalize(s) return s:sub(1, 1):upper() .. s:sub(2) end

function M.var_to_stat(var_name)
  if var_name == "v_agility" then return "statsSpeedText" end
  if var_name == "v_perception" then return "statsObservationText" end
  local rest = var_name:sub(3)  -- strip "v_"
  local parts = {}
  for chunk in (rest .. "_"):gmatch("([^_]*)_") do
    if chunk ~= "" then parts[#parts + 1] = capitalize(chunk) end
  end
  return "stats" .. table.concat(parts) .. "Text"
end

local function parse_atom(atom)
  return atom:match("^([%w_]*) ([<>=!]+) (%d+)$")
end

function M.parse_stat_check(atom)
  local name, op, num = parse_atom(atom)
  if not name then return nil end
  local value = tonumber(num)
  if name == "v_b3_ch1_unlock" and op == "==" and value == 2 then
    return { variable = "v_b3_ch1_unlock", value = 2, success = false }
  end
  if not M.stat_variables[name] then return nil end
  local success
  if op == "<" then
    success = false
  elseif op == "==" and value == 0 then
    success, value = false, 1
  elseif op == ">=" or (op == "==" and value ~= 0) then
    success = true
  elseif op == ">" then
    success, value = true, value + 1
  end
  return { variable = M.var_to_stat(name), value = value, success = success }
end

function M.stat_checks_to_display(items, view)
  local seen, out = {}, {}
  for _, item in ipairs(items) do
    if item.conditions then
      for _, and_group in ipairs(item.conditions) do
        local all_true = true
        for _, atom in ipairs(and_group) do
          if not conditions.eval_atom(atom, view) then all_true = false; break end
        end
        if all_true then
          for _, atom in ipairs(and_group) do
            local sc = M.parse_stat_check(atom)
            if sc then
              local key = tostring(sc.variable) .. "|" .. tostring(sc.value) .. "|" .. tostring(sc.success)
              if not seen[key] then
                seen[key] = true
                out[#out + 1] = sc
              end
            end
          end
        end
      end
    end
  end
  -- lock filter
  local has_lock = false
  for _, sc in ipairs(out) do
    if sc.variable == "v_b3_ch1_unlock" then has_lock = true; break end
  end
  if has_lock then
    local filtered = {}
    for _, sc in ipairs(out) do
      if sc.variable == "v_b3_ch1_unlock" then filtered[#filtered + 1] = sc end
    end
    out = filtered
  end
  return out
end

return M
