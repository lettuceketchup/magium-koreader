-- spike_run.lua — CLI entry point for spike 02 (engine in Lua).
--
-- Parses the 3 .magium files that hold the fixture scenes, renders the same
-- 6 cases as reference/tools/oracle-cases.json (hand-transcribed here rather
-- than parsed from JSON, since this spike only needs a JSON *encoder* — see
-- json.lua), and writes one canonical-shape .json file per case into an
-- output directory for reference/tools/oracle-diff.js's `diff` command to
-- compare against the committed goldens in reference/tools/oracle-capture/.
--
-- Usage: luajit spike_run.lua <magium-dev/data/en dir> <out dir>

local parser = require("magium_parser")
local render_scene = require("render_scene")
local json = require("json")

-- The ~16 ui.json keys these 3 files' scenes need — see magium_utils.lua's
-- header comment for why this is hardcoded instead of parsed from JSON.
local LOCALE = {
  mainStatSuccessTemplate = "[ <%= variable %> check successful - level <%= value %>  ]",
  mainStatFailedTemplate = "[ <%= variable %> check failed - level <%= value %>  ]",
  statsStrengthText = "Strength",
  statsToughnessText = "Toughness",
  statsSpeedText = "Speed",
  statsReflexesText = "Reflexes",
  statsHearingText = "Hearing",
  statsObservationText = "Observation",
  statsAncientLanguagesText = "Ancient languages",
  statsCombatTechniqueText = "Combat technique",
  statsPremonitionText = "Premonition",
  statsBluffText = "Bluff (aura concealement)",
  statsMagicalSenseText = "Magical sense",
  statsAuraHardeningText = "Aura hardening",
  statsMagicalPowerText = "Magical power",
  statsMagicalKnowledgeText = "Magical knowledge",
}

-- mirrors reference/tools/oracle-cases.json exactly
local CASES = {
  { name = "ch1-intro1", sceneId = "Ch1-Intro1", vars = {} },
  { name = "ch1-dave-showmyself", sceneId = "Ch1-Cutthroat Dave", vars = { v_ch1_show_yourself = "2", v_ac_ch1_coward = "1" } },
  { name = "ch1-showmyself-quotequote", sceneId = "Ch1-Cutthroat Dave", vars = { v_ch1_show_yourself = "3" } },
  { name = "ch3-vantage-statchecks", sceneId = "Ch3-Vantage", vars = { v_perception = "2", v_ancient_languages = "3" } },
  { name = "ch3-vantage-nostat", sceneId = "Ch3-Vantage", vars = {} },
  { name = "b2ch1-intro-checkpoint", sceneId = "B2-Ch01a-Intro", vars = { v_ch11_saved_rose = "0" } },
}

local function file_exists(p)
  local f = io.open(p, "r")
  if f then f:close(); return true end
  return false
end

local function main(argv)
  local dataDir = argv[1]
  local outDir = argv[2]
  if not dataDir or not outDir then
    io.stderr:write("usage: luajit spike_run.lua <magium-dev/data/en dir> <out dir>\n")
    os.exit(2)
  end

  local scenes = {}
  for _, fname in ipairs({ "ch1.magium", "ch3.magium", "b2ch1.magium" }) do
    local path = dataDir .. "/" .. fname
    if not file_exists(path) then
      io.stderr:write("missing: " .. path .. "\n")
      os.exit(2)
    end
    local fileScenes = parser.parse(path)
    for id, scene in pairs(fileScenes) do scenes[id] = scene end
  end
  io.stderr:write(string.format("parsed %d scenes from 3 files\n", (function()
    local n = 0; for _ in pairs(scenes) do n = n + 1 end; return n
  end)()))

  os.execute("mkdir -p " .. outDir)
  for _, case in ipairs(CASES) do
    local vars = {}
    for k, v in pairs(case.vars) do vars[k] = v end
    vars.v_current_scene = case.sceneId
    local ok, result = pcall(render_scene.render, scenes, case.sceneId, vars, LOCALE)
    if not ok then
      io.stderr:write("FAIL " .. case.name .. ": " .. tostring(result) .. "\n")
    else
      local f = io.open(outDir .. "/" .. case.name .. ".json", "w")
      f:write(json.encode(result) .. "\n")
      f:close()
      print(string.format("rendered %-28s %dp %dc %ds", case.name,
        #result.paragraphs, #result.choices, #result.statChecks))
    end
  end
end

main(arg)
