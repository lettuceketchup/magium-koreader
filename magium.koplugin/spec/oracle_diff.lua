-- spec/oracle_diff.lua — render fixture cases via engine/scene and emit the
-- canonical JSON shape reference/tools/oracle-diff.js produces, for its `diff`.
--
--   luajit spec/oracle_diff.lua <cases.json> <out_dir>
--
-- cases.json: [ { "name", "sceneId", "vars": {} }, ... ]  (oracle-cases.json shape)

package.path = "./?.lua;./?/init.lua;" .. package.path
local json = require("engine/vendor/json")
local parser = require("engine/parser")
local scene = require("engine/scene")
local Locale = require("engine/locale")

local DATA_EN = "./data/en"
local DATA_ROOT = "./data"

local function read(path)
  local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s
end

-- Load every ch we might need. Cases in Phase I stay within these files;
-- extend as fixtures grow.
local FILES = { "ch1.magium", "ch3.magium", "b2ch1.magium" }

local function to_canonical(rm)
  -- rm is engine/scene render_model; reshape to the oracle-diff.js key names.
  local sc = {}
  for _, x in ipairs(rm.stat_checks) do sc[#sc + 1] = { success = x.success, text = x.text } end
  local sv = {}
  for _, x in ipairs(rm.set_variables) do sv[#sv + 1] = { name = x.name, value = x.value } end
  local ch = {}
  for _, c in ipairs(rm.choices) do
    ch[#ch + 1] = {
      text = c.text, target = c.target, special = c.special or json.null,
      setVariables = c.set_variables,
    }
  end
  local ac = {}
  for _, a in ipairs(rm.achievements) do ac[#ac + 1] = { variable = a.variable, text = a.text } end
  return {
    sceneId = rm.scene_id,
    header = rm.header or json.null,
    checkpoint = rm.checkpoint,
    statChecks = sc,
    setVariables = sv,
    paragraphs = rm.paragraphs,
    choices = ch,
    achievements = ac,
  }
end

local cases_path, out_dir = arg[1], arg[2]
assert(cases_path and out_dir, "usage: luajit spec/oracle_diff.lua <cases.json> <out_dir>")

local scenes = {}
for _, f in ipairs(FILES) do
  for id, s in pairs(parser.parse(DATA_EN .. "/" .. f)) do scenes[id] = s end
end
local loc = Locale.load(DATA_ROOT, "en")

os.execute('mkdir -p "' .. out_dir .. '"')
local cases = json.decode(read(cases_path))
for _, case in ipairs(cases) do
  local view = {}
  for k, v in pairs(case.vars or {}) do view[k] = v end
  view.v_current_scene = case.sceneId
  local rm = scene.render(assert(scenes[case.sceneId], "unknown scene " .. case.sceneId), view, loc)
  local fh = assert(io.open(out_dir .. "/" .. case.name .. ".json", "w"))
  fh:write(json.encode(to_canonical(rm)) .. "\n")
  fh:close()
  print("rendered " .. case.name)
end
