-- engine/scene.lua — the 12-step render pipeline.
-- Pure port of magium-dev/src/renderers.js:renderScene @ 51f5aa9 (data steps
-- only; the EJS→HTML step is UI's job). PURE: Lua stdlib + engine siblings.

local conditions = require("engine/conditions")
local stats = require("engine/stats")
local specials = require("engine/specials")

local M = {}

local function shallow_copy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end

-- Collapse horizontal whitespace runs and trim. The oracle's canonical form
-- applies exactly this to every text field it recovers from the rendered HTML —
-- paragraphs (../magium-dev/reference/tools/oracle-diff.js:110), choice labels
-- (:127) and achievement captions (:139) — so all three have to be normalized
-- here too. (0/145 achievement labels corpus-wide actually differ under it: this
-- is faithfulness to the oracle contract, not a bug fix.)
local function norm(s)
  return (s:gsub("[ \t\f\v]+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- +N/-N in a scene's own set() is applied LITERALLY into the working view
-- (magium-dev renderScene step 5 defers the arithmetic to the client). The
-- persisted arithmetic happens in store:set() when a choice commits.
function M.render(scene_table, view, locale)
  local st = scene_table
  local work = shallow_copy(view)

  -- 3. filter set_variables by incoming view; 4. apply survivors in order.
  local set_vars = {}
  for _, sv in ipairs(st.set_variables) do
    if conditions.eval(sv.conditions, work) then set_vars[#set_vars + 1] = sv end
  end
  for _, sv in ipairs(set_vars) do work[sv.name] = sv.value end

  -- 5. filter choices; 6. filter paragraphs — against post-set() view.
  local choices = {}
  for _, c in ipairs(st.choices) do
    if conditions.eval(c.conditions, work) then choices[#choices + 1] = c end
  end
  local paragraphs = {}
  for _, p in ipairs(st.paragraphs) do
    if conditions.eval(p.conditions, work) then paragraphs[#paragraphs + 1] = p end
  end

  -- 7. stat checks over set ∪ paragraphs ∪ choices.
  local scan = {}
  for _, x in ipairs(set_vars) do scan[#scan + 1] = x end
  for _, x in ipairs(paragraphs) do scan[#scan + 1] = x end
  for _, x in ipairs(choices) do scan[#scan + 1] = x end
  local raw_checks = stats.stat_checks_to_display(scan, work)

  -- 8. B3-Ch04a-Introduction2 → no checks.
  if specials.suppress_stat_checks(st.id) then raw_checks = {} end

  -- 9. keep achievements where the flag is exactly "1"; 10. always-on prize.
  local achievements = {}
  for _, a in ipairs(st.achievements) do
    if work[a.variable] == "1" then
      achievements[#achievements + 1] = { variable = a.variable, text = norm(a.text) }
    end
  end
  for _, a in ipairs(specials.extra_achievements(work)) do
    -- the always-on prize renders through the same achievement-modal caption the
    -- oracle normalizes at oracle-diff.js:139, so norm it on the same footing
    -- (its text is a hardcoded literal today, so this is a no-op guard)
    achievements[#achievements + 1] = { variable = a.variable, text = norm(a.text) }
  end

  -- 11. checkpoint banner: a surviving choice sets v_checkpoint_rich == "0".
  local checkpoint = false
  for _, c in ipairs(choices) do
    if c.set_vars.v_checkpoint_rich == "0" then checkpoint = true; break end
  end

  -- assemble render_model
  -- statChecksToDisplay (renderers.js:70, utils.js:195) swaps the varToStat KEY
  -- for the localized label, EXCEPT the raw v_b3_ch1_unlock sentinel. Our
  -- stats.stat_checks_to_display returns the KEY; do the swap here.
  local out_checks = {}
  for _, sc in ipairs(raw_checks) do
    local var = sc.variable
    if var ~= "v_b3_ch1_unlock" then var = locale:str(var) end
    -- stats.parse_stat_check leaves `success` nil for an unmatched operator
    -- (`<=` / `!=`) — magium-dev leaves it `undefined` too (utils.js:158-171),
    -- but the oracle's canonical form derives success from the rendered <div>
    -- class, so it is ALWAYS a boolean (false = the fail template). Coerce once
    -- here so the render model is total. Reachable at
    -- ../magium-dev/data/en/ch11b.magium:1049 (Ch11b-Hole, `v_hearing <= 4`);
    -- no ch1 impact — every ch1 check has a matched operator.
    local ok = sc.success and true or false
    local text
    if var == "v_b3_ch1_unlock" and specials.HIDE_DEVICE_LOCK_TEXT[st.id] then
      text = ""                                              -- special case #8
    else
      text = locale:stat_check_text{ variable = var, value = sc.value, success = ok }
    end
    out_checks[#out_checks + 1] = { success = ok, text = text }
  end
  local out_setvars = {}
  for _, sv in ipairs(set_vars) do
    out_setvars[#out_setvars + 1] = { name = sv.name, value = sv.value }
  end
  local out_paras = {}
  for _, p in ipairs(paragraphs) do
    out_paras[#out_paras + 1] = norm(p.text)
  end
  local out_choices = {}
  for _, c in ipairs(choices) do
    local sv = {}
    for k, v in pairs(c.set_vars) do sv[k] = v end
    out_choices[#out_choices + 1] = {
      text = norm(c.text),
      target = c.target,
      special = c.special,
      set_variables = sv,
    }
  end

  return {
    scene_id = st.id,
    header = locale:header(st.id),
    checkpoint = checkpoint,
    stat_checks = out_checks,
    set_variables = out_setvars,
    paragraphs = out_paras,
    choices = out_choices,
    achievements = achievements,
  }
end

-- Persist a rendered scene's own surviving set() effects into the real store.
-- magium-dev emits a storeVariable() script per surviving setVariable on EVERY
-- render (magium-dev/templates/main.ejs:1-3 @51f5aa9); the client persists them
-- with +N/-N resolved. render_model.set_variables is already filtered + ordered
-- by render(), so this just replays it through store:set (which does the
-- +N/-N arithmetic and the v_ac_* latch).
--
-- ponytail: re-applies on every scene entry, INCLUDING a resume onto the same
-- scene — a scene with set(v_x, +N) adds N again per resume, exactly as
-- magium-dev does (each resume re-POSTs and re-emits the script). ~10 relative
-- set() lines corpus-wide, most conditional. Upgrade path if the owner hits a
-- runaway counter: gate this on a per-session visited-scene set.
function M.persist_effects(store, render_model)
  for _, sv in ipairs(render_model.set_variables) do
    store:set(sv.name, sv.value)
  end
end

return M
