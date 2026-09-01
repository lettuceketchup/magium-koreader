-- spec/gen_cases.lua — derive an oracle case matrix from parsed scene
-- conditions, instead of a human reading each .magium file by eye.
-- Replaces tools/gen-ch1-cases.js (which hardcoded one chapter's variables).
--
--   luajit spec/gen_cases.lua <data/en dir> <out.json> [filename-pattern]
--
-- filename-pattern (optional): a Lua pattern to filter which *.magium files
-- to include, e.g. "^ch1%.magium$" to scope to one chapter.
--
-- For every scene: walks its set()/choice()/#if DNF condition tables
-- (engine/parser.lua already extracted these — no re-parsing of prose) and
-- its achievement variables, and emits:
--   - a zero baseline ({})
--   - one case per (var, true-value) and (var, false-value) per atom, off
--     that baseline — exercises each atom's own true/false boundary
--   - one case per AND-group with >= 2 distinct vars, satisfying the whole
--     group at once — exercises conjunctions a one-var-at-a-time baseline
--     flip can never reach (e.g. "v_perception > 2 && v_ancient_languages > 3")
--   - one case per achievement variable, set to "1"
-- Cases with an identical vars map are deduped. This is linear in the
-- number of condition atoms per scene, not a combinatorial cross-product.
--
-- Coverage is self-checked: for every DNF the scene contains, the derived
-- case set should make it eval both true and false at least once
-- (engine/conditions.eval). Where it can't (an atom outside the v>=0 domain
-- this generator tests in, e.g. "v_x < 0" — dead/always-true content, not a
-- generator bug), a warning is logged to stderr, not a hard failure: one
-- unreachable branch in one chapter shouldn't block generating cases for the
-- other 53. Mirrors engine/parser.lua's M.anomalies non-fatal pattern.

package.path = "./?.lua;./?/init.lua;" .. package.path
local json = require("engine/vendor/json")
local parser = require("engine/parser")
local conditions = require("engine/conditions")
local Story = require("engine/story")

local data_dir, out_path, name_pattern = arg[1], arg[2], arg[3]
assert(data_dir and out_path, "usage: luajit spec/gen_cases.lua <data/en dir> <out.json> [filename-pattern]")

local warnings = {}

-- ---- atom parsing (mirrors engine/conditions.lua's own regex) ----
local function parse_atom(atom)
  local name, op, num = atom:match("^([%w_]*) ([<>=!]+) (%d+)$")
  if not name or name == "" then return nil end
  return name, op, tonumber(num)
end

-- value >= 0 that makes "name op num" true/false; nil = unreachable in the
-- v >= 0 domain this generator explores (e.g. "< 0" can never be true).
local function true_value(op, num)
  if op == ">" then return num + 1
  elseif op == ">=" then return num
  elseif op == "<" then return (num > 0) and (num - 1) or nil
  elseif op == "<=" then return 0
  elseif op == "==" then return num
  elseif op == "!=" then return num + 1 end
end

local function false_value(op, num)
  if op == ">" then return 0
  elseif op == ">=" then return (num > 0) and (num - 1) or nil
  elseif op == "<" then return num
  elseif op == "<=" then return num + 1
  elseif op == "==" then return num + 1
  elseif op == "!=" then return num end
end

local function collect_dnfs(scene)
  local dnfs = {}
  for _, sv in ipairs(scene.set_variables) do if sv.conditions then dnfs[#dnfs + 1] = sv.conditions end end
  for _, c in ipairs(scene.choices) do if c.conditions then dnfs[#dnfs + 1] = c.conditions end end
  for _, p in ipairs(scene.paragraphs) do if p.conditions then dnfs[#dnfs + 1] = p.conditions end end
  return dnfs
end

local function vars_key(vars)
  local parts = {}
  for k, v in pairs(vars) do parts[#parts + 1] = k .. "=" .. v end
  table.sort(parts)
  return table.concat(parts, "&")
end

local function derive_cases(scene_id, scene)
  local dnfs = collect_dnfs(scene)
  local seen, cases = {}, {}
  local function emit(vars)
    if next(vars) == nil then vars = {} end
    local key = vars_key(vars)
    if seen[key] then return end
    seen[key] = true
    cases[#cases + 1] = vars
  end

  emit({}) -- baseline: everything unset (reads as 0)

  for _, dnf in ipairs(dnfs) do
    for _, and_group in ipairs(dnf) do
      local group_true = {}
      local group_ok = true
      for _, atom in ipairs(and_group) do
        local name, op, num = parse_atom(atom)
        if name then
          local tv, fv = true_value(op, num), false_value(op, num)
          if tv and tv > 0 then emit({ [name] = tostring(tv) }) end
          if fv and fv > 0 then emit({ [name] = tostring(fv) }) end
          if tv == nil then group_ok = false end
          group_true[name] = tostring(tv or 0)
        end
      end
      -- AND-group case: only worth a dedicated case with >= 2 distinct vars
      -- (a single-var group is already covered by the per-atom flip above).
      local n = 0
      for _ in pairs(group_true) do n = n + 1 end
      if group_ok and n >= 2 then
        if conditions.eval({ and_group }, group_true) then
          emit(group_true)
        else
          warnings[#warnings + 1] = scene_id .. ": AND-group not satisfiable by per-atom values: "
            .. table.concat(and_group, " && ")
        end
      end
    end
  end

  for _, a in ipairs(scene.achievements) do
    emit({ [a.variable] = "1" })
  end

  -- coverage self-check: every DNF should hit both true and false somewhere
  -- in the generated case set.
  for _, dnf in ipairs(dnfs) do
    local saw_true, saw_false = false, false
    for _, vars in ipairs(cases) do
      if conditions.eval(dnf, vars) then saw_true = true else saw_false = true end
      if saw_true and saw_false then break end
    end
    if not (saw_true and saw_false) then
      local desc = {}
      for _, g in ipairs(dnf) do desc[#desc + 1] = table.concat(g, " && ") end
      warnings[#warnings + 1] = scene_id .. ": condition never both true/false in derived cases: "
        .. table.concat(desc, " || ") .. " (true=" .. tostring(saw_true) .. " false=" .. tostring(saw_false) .. ")"
    end
  end

  return cases
end

local function sanitize(id) return (id:gsub("[^%w]+", "_")) end

local function mkdir_for(path)
  local dir = path:match("^(.*)[/\\][^/\\]*$")
  if dir then os.execute('mkdir -p "' .. dir .. '"') end
end

-- ---- main ----
local files = Story._list_magium(data_dir)
if name_pattern then
  local filtered = {}
  for _, f in ipairs(files) do
    if f:match(name_pattern) then filtered[#filtered + 1] = f end
  end
  files = filtered
end
assert(#files > 0, "no .magium files matched in " .. data_dir)

local out_cases = {}
local scene_count = 0
for _, path in ipairs(files) do
  local stem = path:match("([^/\\]+)%.magium$")
  local scenes = parser.parse(path)
  local ids = {}
  for id in pairs(scenes) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    scene_count = scene_count + 1
    local cases = derive_cases(id, scenes[id])
    for i, vars in ipairs(cases) do
      out_cases[#out_cases + 1] = {
        name = stem .. "-" .. sanitize(id) .. "-m" .. (i - 1),
        sceneId = id,
        vars = json.object(vars),
      }
    end
  end
end

mkdir_for(out_path)
local fh = assert(io.open(out_path, "w"))
fh:write(json.encode(out_cases) .. "\n")
fh:close()

io.stderr:write(string.format(
  "%d cases for %d scenes across %d file(s) -> %s\n", #out_cases, scene_count, #files, out_path))
if #warnings > 0 then
  io.stderr:write(#warnings .. " coverage warning(s):\n")
  for _, w in ipairs(warnings) do io.stderr:write("  " .. w .. "\n") end
end
