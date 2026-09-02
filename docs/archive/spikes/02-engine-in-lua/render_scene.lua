-- render_scene.lua — Lua port of renderScene()'s data pipeline in
-- ../magium-dev/src/renderers.js @ 51f5aa9 (everything except the EJS→HTML
-- step, which reference/tools/oracle-diff.js's normalizer undoes on the
-- oracle side anyway — see FINDING.md for why comparing at this level, not
-- at rendered-HTML level, is the right cut for this spike).

local utils = require("magium_utils")
local json = require("json")

local M = {}

-- EJS "<%= key %>" is the only template feature main.ejs's stat-check /
-- header strings use; a tiny substitution stands in for a full EJS engine.
local function ejs_lite(template, vars)
  return (template:gsub("<%%=%s*([%w_]+)%s*%%>", function(k)
    return tostring(vars[k])
  end))
end

local function normalize_text(s)
  s = s:gsub("[ \t\f\v]+", " ")
  return s:match("^%s*(.-)%s*$")
end

-- renderScene(req): scenes = merged { [sceneId] = parsed_scene } dict,
-- inputVars = the request body's variable map (v_current_scene included).
function M.render(scenes, sceneId, inputVars, locale)
  local scene = scenes[sceneId]
  if not scene then error("unknown scene: " .. tostring(sceneId)) end

  local cookie = {}
  for k, v in pairs(inputVars) do cookie[k] = v end

  local setVars = {}
  for _, sv in ipairs(scene.setVariables) do
    if utils.apply_conditions(sv.conditions, cookie) then table.insert(setVars, sv) end
  end
  for _, sv in ipairs(setVars) do cookie[sv.name] = sv.value end

  local choices = {}
  for _, c in ipairs(scene.choices) do
    if utils.apply_conditions(c.conditions, cookie) then table.insert(choices, c) end
  end

  local paragraphs = {}
  for _, p in ipairs(scene.paragraphs) do
    if utils.apply_conditions(p.conditions, cookie) then table.insert(paragraphs, p) end
  end

  local combined = {}
  for _, sv in ipairs(setVars) do table.insert(combined, sv) end
  for _, p in ipairs(paragraphs) do table.insert(combined, p) end
  for _, c in ipairs(choices) do table.insert(combined, c) end
  local statChecks = utils.statChecksToDisplay(combined, cookie, locale)

  if sceneId == "B3-Ch04a-Introduction2" then statChecks = {} end -- renderers.js:76

  local achievements = {}
  for _, a in ipairs(scene.achievements) do
    if cookie[a.variable] == "1" then table.insert(achievements, a) end
  end
  if cookie["v_ac_b3_ch9_prize"] == "1" then
    table.insert(achievements, { text = "Consolation prize", variable = "v_ac_b3_ch9_prize" })
  end

  local checkpoint = false
  for _, c in ipairs(choices) do
    if c.setVariables["v_checkpoint_rich"] == "0" then checkpoint = true; break end
  end

  -- ---- assemble the canonical shape reference/tools/oracle-diff.js expects
  local outStatChecks = json.arr({})
  for _, sc in ipairs(statChecks) do
    local tmpl = sc.success and locale.mainStatSuccessTemplate or locale.mainStatFailedTemplate
    local text = normalize_text(ejs_lite(tmpl, { variable = sc.variable, value = sc.value }))
    table.insert(outStatChecks, { success = sc.success, text = text })
  end

  local outSetVars = json.arr({})
  for _, sv in ipairs(setVars) do
    table.insert(outSetVars, { name = sv.name, value = sv.value })
  end

  local outParagraphs = json.arr({})
  for _, p in ipairs(paragraphs) do
    table.insert(outParagraphs, normalize_text(p.text))
  end

  local outChoices = json.arr({})
  for _, c in ipairs(choices) do
    local sv = {}
    for k, v in pairs(c.setVariables) do sv[k] = v end
    table.insert(outChoices, {
      text = normalize_text(c.text),
      target = c.target,
      special = c.special or json.NULL,
      setVariables = sv,
    })
  end

  local outAchievements = json.arr({})
  for _, a in ipairs(achievements) do
    table.insert(outAchievements, { variable = a.variable, text = normalize_text(a.text) })
  end

  return {
    sceneId = sceneId,
    header = utils.getHeaderFromId(sceneId) or json.NULL,
    checkpoint = checkpoint,
    statChecks = outStatChecks,
    setVariables = outSetVars,
    paragraphs = outParagraphs,
    choices = outChoices,
    achievements = outAchievements,
  }
end

return M
