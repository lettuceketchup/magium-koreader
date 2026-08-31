# Magium KOReader Plugin — Milestone 0 + Phase I Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a KOReader plugin that plays Magium chapter 1 end-to-end on a Kindle Paperwhite — a complete Lua engine (parser + condition/stat/store/render pipeline) verified byte-for-byte against the `magium-dev` oracle, a custom fullscreen paginated reading widget, and debounced autosave/resume.

**Architecture:** Three layers with a one-way dependency rule. `engine/` is pure Lua with **zero KOReader imports** so it runs under plain `luajit` against the differential oracle. `ui/` builds KOReader widgets on top of the engine's render-model. `save/` is a thin persistence wrapper. `main.lua` wires them. `engine/scene.render()` is a pure function of `(scene_table, store_view, locale)` — the exact contract `magium-dev`'s `renderScene` satisfies.

**Tech Stack:** Lua 5.1 / LuaJIT 2.1 (+ FFI); KOReader plugin API (`WidgetContainer`, `UIManager`, `TextBoxWidget`, `ButtonTable`, `LuaSettings`, `Persist`, `Trapper`) at tag `v2026.07.1`; `busted` for unit tests (runs on luajit); Node.js for the `magium-dev` oracle server; `kodev` SDL emulator (WSL2) for widget verification; vendored `rxi/json.lua` (MIT) for JSON.

**Spec:** [`docs/specs/2026-08-31-plugin-architecture-and-phase-i.md`](../../specs/2026-08-31-plugin-architecture-and-phase-i.md) — read it alongside this plan; every task argues from a spec section.

## Global Constraints

Copied verbatim from the spec. Every task's requirements implicitly include these.

- **No KOReader import may appear anywhere under `engine/`.** Not `require("ui/...")`, `require("apps/...")`, `require("device/...")`, `Persist`, `LuaSettings`, `UIManager`, `Trapper`, `Screen`. Only the Lua stdlib (`io`, `string`, `table`, `os`, `math`) and `require("engine/...")` siblings + `require("engine/vendor/json")`. This is what keeps the oracle diff runnable under bare `luajit`. Reviewers reject any violation. (spec §2, C5, ADR-004)
- **Navigation is authoritative on `v_current_scene`**, never `choice.target`. `target` is parsed and carried but never used to decide the next scene. (spec C6, `02` R8/F-05)
- **Variable values are strings in storage**; comparisons coerce `tonumber(v or 0)` and compare numerically. (spec §5.1, §6; `01` §2 F-2)
- **`+N` / `−N` writes resolve on write** in `store:set()` against the current value. The render-model still reports the literal parsed value in its `set_variables` field for oracle parity. (spec §5.2, §6 step 4)
- **`v_ac_*` "seen" latch**: `store:set(k, "2")` must never overwrite a value that is already `"1"` with... actually the rule is the reverse — a re-render writing `"2"` is fine, but `store:set` must not let `"2"` be lowered to `"1"` by a later write. `"2"` is sticky once set. (spec §3.1, `01` §2, `utils.js:31`)
- **Parser hardening (`02` §4):** anchor construct matches to line start (R1/R2); assert on a multi-digit `set()` literal rather than truncate (R3); assert single-paren conditions, no nested groups (R4); strip `\r` from every line (R10); assert scene-id uniqueness across files (R9); count anomalies loudly in dev (R6).
- **Corpus structural counts** the parser must reproduce exactly over the 54 English files: **2159 scenes, 4880 paragraph objects, 3734 choices, 594 `set()`, 145 `achievement()`, 2480 `#if` blocks**. (spec §11.1, `01` §11)
- **The 13 hardcoded special cases** (`01` §10): Phase I implements render-time #1–#4, #6–#8, #12; #13's unset→0 lives in `conditions`/`store`; stats-screen #5, #9–#11 are declared inert. (spec §3.1, §11.1)
- **Autosave never fires per-choice.** `currentState` flushes on a short idle timer, on checkpoint hooks, on reader close, and on suspend/`Close`. `v_ac_*` flushes immediately on unlock. (spec §9, F-20)
- **Spike code is a design reference, not a copy source.** Production code is written fresh and hardened. (spec C7, CLAUDE.md)

---

## Environment

All Lua / Node / emulator work runs in **WSL2 Ubuntu** (the `kodev` build is already set up there — [`reference/setup-koreader-wsl.sh`](../../../reference/setup-koreader-wsl.sh), OQ-012 resolved). From the Windows session, invoke via `wsl bash -lc '...'`, or work in a WSL shell directly. The repo is reachable in WSL at `/mnt/f/Projects/Magium - Kindle/magium-koreader`; the siblings at `/mnt/f/Projects/Magium - Kindle/{magium-dev,koreader}`.

Prerequisites the plan assumes (Task 1 verifies them): `luajit`, `luarocks` + `busted`, `node` (≥18), and either a `kodev` checkout with a working `./kodev build` or the ability to run one. The Kindle Paperwhite 12th gen is needed only for Task 6 (Milestone 0 measurement) and Task 21 (final on-device run).

The plugin lives at **repo root** as `magium.koplugin/`. It is deployed to the emulator by symlinking into `~/koreader/koreader/plugins/` (or the build's plugin dir) and to the device by USB-copying into `koreader/plugins/`.

---

## File Structure

**Created by this plan:**

```
magium.koplugin/
  _meta.lua                         plugin metadata (fullname, description)
  main.lua                          plugin class: registration, entry, lifecycle, wiring   [Task 20]
  .busted                           busted config (lpath, spec root)                        [Task 1]

  engine/                           PURE LUA — no KOReader imports
    vendor/
      json.lua                      vendored rxi/json.lua (MIT), encode+decode              [Task 1]
    parser.lua                      .magium file → { [scene_id] = scene_table }             [Tasks 2,3,4]
    conditions.lua                  DNF eval: eval_atom, eval                               [Task 7]
    store.lua                       variable map: get/set/+N-N/latch/snapshot/restore/view  [Task 8]
    stats.lua                       var_to_stat, parse_stat_check, stat_checks_to_display   [Task 9]
    locale.lua                      ui.json strings, header(), stat templates               [Task 10]
    specials.lua                    render-time special-case table + apply hooks            [Task 11]
    scene.lua                       the 12-step render() pipeline → render_model            [Task 12]
    story.lua                       parse-strategy seam: eager (lazy seam stubbed, deferred) [Task 5]

  ui/
    pagination.lua                  paginate(render_model, geometry, measure_fn) → {pages}  [Task 16]
    reader.lua                      custom fullscreen paginated widget                      [Task 17]
    choices.lua                     choice-list widget (final page)                         [Task 18]
    refresh.lua                     e-ink refresh-type policy                               [Task 17]

  save/
    manager.lua                     4-blob save model, debounced autosave, resume          [Task 19]

  data/
    en/*.magium  en/ui.json  en/achievements{1,2,3}.json    copied verbatim from magium-dev [Task 1]

  spec/
    spec_helper.lua                 package.path + a fake KOReader shim for pure specs      [Task 1]
    run.lua                         convenience: run the engine-only spec subset           [Task 1]
    oracle_diff.lua                 render fixtures via engine/scene, diff vs magium-dev    [Task 13]
    support/
      fake_measure.lua              deterministic measure_fn for pagination specs          [Task 16]
      (mem_cache.lua                 — deferred with the lazy strategy, see Task 15)
      fake_writer.lua               in-memory writer for save/manager specs                [Task 19]
    engine/
      parser_conditions_spec.lua                                                          [Task 2]
      parser_constructs_spec.lua                                                           [Task 3]
      parser_spec.lua                                                                      [Task 4]
      story_eager_spec.lua                                                                 [Task 5]
      conditions_spec.lua                                                                  [Task 7]
      store_spec.lua                                                                       [Task 8]
      stats_spec.lua                                                                       [Task 9]
      locale_spec.lua                                                                      [Task 10]
      specials_spec.lua                                                                    [Task 11]
      scene_spec.lua                                                                       [Task 12]
      (story_lazy_spec.lua           — deferred with the lazy strategy, see Task 15)
    ui/
      pagination_spec.lua                                                                  [Task 16]
    save/
      manager_spec.lua                                                                     [Task 19]

tools/
  gen-ch1-cases.js                  enumerate ch1 scene ids → oracle cases file            [Task 14]

docs/spikes/06-ondevice-parse-timing/
  HYPOTHESIS.md                                                                            [Task 6]
  FINDING.md                        filled after the device run                            [Task 6]

reference/tools/oracle-capture/
  ch1-*.json                        committed ch1 goldens                                  [Task 14]
reference/tools/oracle-cases-ch1.json    generated ch1 case list                           [Task 14]
```

**Modified by this plan:**

- `docs/specs/2026-08-31-plugin-architecture-and-phase-i.md:297` — §7.1 record Milestone 0's chosen default [Task 6]
- `research-plan.md` — running-log entry per work session (per CLAUDE.md convention)
- `SUMMARY.md` — status line + a finding when Phase I lands [Task 21]

---

## Task 1: Scaffolding, test harness, story data

**Files:**
- Create: `magium.koplugin/_meta.lua`
- Create: `magium.koplugin/.busted`
- Create: `magium.koplugin/engine/vendor/json.lua`
- Create: `magium.koplugin/spec/spec_helper.lua`
- Create: `magium.koplugin/spec/run.lua`
- Create: `magium.koplugin/spec/engine/smoke_spec.lua`
- Create: `magium.koplugin/data/en/` (copied tree)
- Create: `magium.koplugin/.gitignore`

**Interfaces:**
- Produces: a working `busted` run from inside `magium.koplugin/`; `require("engine/vendor/json")` exposing `json.encode(v)` and `json.decode(s)`; `data/en/*.magium` (54 files) + `data/en/ui.json` + `data/en/achievements{1,2,3}.json` present.

- [ ] **Step 1: Verify prerequisites**

Run:
```bash
wsl bash -lc 'command -v luajit && luajit -v && command -v node && node -v && command -v luarocks || echo "MISSING luarocks"'
```
Expected: luajit prints `LuaJIT 2.1...`, node prints `v18+`. If `luarocks` is missing:
```bash
wsl bash -lc 'sudo apt-get update && sudo apt-get install -y luarocks && sudo luarocks install busted'
```
Then `wsl bash -lc 'busted --version'` should print a version.

- [ ] **Step 2: Create the plugin skeleton**

`magium.koplugin/_meta.lua`:
```lua
local _ = require("gettext")
return {
    fullname = _("Magium"),
    description = _([[Play the text-based CYOA game Magium. Bundles the story; opens from the file manager.]]),
}
```

`magium.koplugin/.gitignore`:
```
cache/
spec/out/
```

`magium.koplugin/.busted`:
```lua
return {
  default = {
    lpath = "./?.lua;./?/init.lua",
    ROOT = { "spec" },
    pattern = "_spec%.lua$",
    ["auto-insulate"] = true,
  },
}
```

- [ ] **Step 3: Vendor rxi/json.lua**

Fetch `json.lua` from `rxi/json.lua` (MIT) and save to `magium.koplugin/engine/vendor/json.lua`. If network is available:
```bash
wsl bash -lc 'cd "/mnt/f/Projects/Magium - Kindle/magium-koreader/magium.koplugin/engine/vendor" && curl -fsSL -o json.lua https://raw.githubusercontent.com/rxi/json.lua/dbde0c17242a1faf0dd5e6fc73abcbf8b0d8f4d0/json.lua'
```
If no network, transcribe rxi/json.lua (single file, ~390 lines, Lua 5.1-compatible, exposes `json.encode` / `json.decode`) into that path. Prepend a header comment:
```lua
-- Vendored from rxi/json.lua @ dbde0c1 (MIT). https://github.com/rxi/json.lua
-- Pure Lua 5.1 JSON encode/decode. Used by engine/locale.lua and spec/oracle_diff.lua.
```

- [ ] **Step 4: Copy the story data**

```bash
wsl bash -lc 'set -e; SRC="/mnt/f/Projects/Magium - Kindle/magium-dev/data/en"; DST="/mnt/f/Projects/Magium - Kindle/magium-koreader/magium.koplugin/data/en"; mkdir -p "$DST"; cp "$SRC"/*.magium "$SRC"/ui.json "$SRC"/achievements1.json "$SRC"/achievements2.json "$SRC"/achievements3.json "$DST"/; ls "$DST"/*.magium | wc -l'
```
Expected: `54`.

- [ ] **Step 5: Create the spec helper and runner**

`magium.koplugin/spec/spec_helper.lua`:
```lua
-- Prepend the plugin root so require("engine/...") resolves under bare luajit.
-- Also stub the two KOReader globals a pure spec might transitively touch via
-- vendored code (none currently do — this is a guard rail, kept minimal).
package.path = "./?.lua;./?/init.lua;" .. package.path

return {
  data_dir_en = "./data/en",
  magium_dev_en = os.getenv("MAGIUM_DEV_EN") or
    "/mnt/f/Projects/Magium - Kindle/magium-dev/data/en",
}
```

`magium.koplugin/spec/run.lua`:
```lua
-- Convenience: run only the engine-layer specs (pure, no KOReader, fastest).
-- Usage: luajit spec/run.lua      (from inside magium.koplugin/)
-- os.execute returns a number on Lua 5.1/LuaJIT (0 = success, and 0 is truthy),
-- a boolean on 5.2+. Normalize both.
local ok = os.execute("busted spec/engine")
os.exit((ok == true or ok == 0) and 0 or 1)
```

- [ ] **Step 6: Write the smoke spec**

`magium.koplugin/spec/engine/smoke_spec.lua`:
```lua
local helper = require("spec/spec_helper")
local json = require("engine/vendor/json")

describe("scaffolding", function()
  it("resolves engine requires", function()
    assert.is_table(json)
  end)

  it("round-trips JSON", function()
    local s = json.encode({ a = 1, b = { "x", "y" } })
    local back = json.decode(s)
    assert.are.equal(1, back.a)
    assert.are.equal("y", back.b[2])
  end)

  it("sees the story data", function()
    local f = io.open(helper.data_dir_en .. "/ch1.magium", "r")
    assert.is_not_nil(f)
    f:close()
  end)
end)
```

- [ ] **Step 7: Run the smoke spec**

Run:
```bash
wsl bash -lc 'cd "/mnt/f/Projects/Magium - Kindle/magium-koreader/magium.koplugin" && busted spec/engine/smoke_spec.lua'
```
Expected: `3 successes / 0 failures`.

- [ ] **Step 8: Commit**

```bash
git add magium.koplugin/ && git commit -m "magium plugin: scaffolding, busted harness, vendored json, story data (Task 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Parser — `parse_conditions`

**Files:**
- Create: `magium.koplugin/engine/parser.lua` (partial — this function only)
- Test: `magium.koplugin/spec/engine/parser_conditions_spec.lua`

**Interfaces:**
- Produces: `local parser = require("engine/parser")` with `parser.parse_conditions(str) -> dnf|nil` where `dnf = { {atom_string, ...}, ... }` (outer OR of inner ANDs). `nil`/`""` input → `nil`.

Reference: `magium-dev/src/parser.js:13–21` (`parseConditions`). It does `.replace("(","")` then `.replace(")","")` — **first occurrence of each only** — then `split(" || ")`, each `split(" && ")`. `02` R4: assert no nested groups remain.

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/parser_conditions_spec.lua`:
```lua
require("spec/spec_helper")
local parser = require("engine/parser")

describe("parse_conditions", function()
  it("returns nil for absent conditions", function()
    assert.is_nil(parser.parse_conditions(nil))
    assert.is_nil(parser.parse_conditions(""))
  end)

  it("splits a single atom", function()
    assert.are.same({ { "v_perception > 2" } }, parser.parse_conditions("v_perception > 2"))
  end)

  it("splits an AND clause", function()
    assert.are.same(
      { { "v_a > 1", "v_b == 0" } },
      parser.parse_conditions("v_a > 1 && v_b == 0")
    )
  end)

  it("splits DNF (OR of ANDs)", function()
    assert.are.same(
      { { "v_a > 1", "v_b == 0" }, { "v_c != 3" } },
      parser.parse_conditions("v_a > 1 && v_b == 0 || v_c != 3")
    )
  end)

  it("strips one leading and one trailing paren (magium-dev behavior)", function()
    assert.are.same(
      { { "v_a > 1" }, { "v_b > 2" } },
      parser.parse_conditions("(v_a > 1 || v_b > 2)")
    )
  end)

  it("asserts on a nested group (02 R4 — never in the shipped corpus)", function()
    assert.has_error(function()
      parser.parse_conditions("(v_a && v_b) || (v_c && v_d)")
    end)
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

Run: `wsl bash -lc 'cd .../magium.koplugin && busted spec/engine/parser_conditions_spec.lua'`
Expected: FAIL — `module 'engine/parser' not found`.

- [ ] **Step 3: Implement**

`magium.koplugin/engine/parser.lua`:
```lua
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
```

- [ ] **Step 4: Run it, verify it passes**

Run: `wsl bash -lc 'cd .../magium.koplugin && busted spec/engine/parser_conditions_spec.lua'`
Expected: `6 successes / 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/parser.lua magium.koplugin/spec/engine/parser_conditions_spec.lua
git commit -m "engine/parser: parse_conditions DNF split (Task 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Parser — construct matchers

**Files:**
- Modify: `magium.koplugin/engine/parser.lua` (add the four matchers)
- Test: `magium.koplugin/spec/engine/parser_constructs_spec.lua`

**Interfaces:**
- Consumes: `parser.parse_conditions` (Task 2), `parser._split_plain`.
- Produces, all local to the module but exercised via `parser._match_*` exports:
  - `parser._match_set(line) -> name, value, cond_str | nil` — value is `[+-]?<one digit>` as a string.
  - `parser._match_achievement(line) -> text, variable | nil`
  - `parser._match_choice(line) -> choice_table | nil` where `choice_table = { text, target, set_vars = {k=v}, special = str|nil, conditions = dnf|nil }`
  - `parser._match_if(line) -> cond_str | nil`

Reference: `parser.js:54,67,76,104` and [spike 02 `magium_parser.lua:57–171`](../../spikes/02-engine-in-lua/magium_parser.lua) for the hand-tokenizer shapes. **Anchor every matcher to the trimmed line start (R1/R2).** The regexes to reproduce, verbatim from `parser.js`:
```
set:         /set\((?<varName>.*),(?<value>[+\-]?[0-9])\)( if (?<condition>.*))?/
achievement: /achievement\("(?<text>.*)",(?<variable>.*)\)/
choice:      /choice\("(?<text>.*)", (?<target>[\w\-\s]*), (?<setVariables>(\w* = [\w\-\s+]*(, )?)*)((, )?special:(?<special>.*?))?\)( if (?<condition>.*))?/
#if:         /#if\((?<condition>.*)\)/
```

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/parser_constructs_spec.lua`:
```lua
require("spec/spec_helper")
local parser = require("engine/parser")

describe("_match_set", function()
  -- Corpus format has NO space after the comma: `set(v_x,1)` (594 lines checked).
  it("matches a plain set", function()
    local n, v, c = parser._match_set("set(v_is_dead,1)")
    assert.are.equal("v_is_dead", n); assert.are.equal("1", v); assert.is_nil(c)
  end)
  it("matches a relative set with a condition", function()
    local n, v, c = parser._match_set("set(v_ac_x,+3) if (v_a > 1)")
    assert.are.equal("v_ac_x", n); assert.are.equal("+3", v)
    assert.are.equal("(v_a > 1)", c)
  end)
  it("returns nil for a non-set line", function()
    assert.is_nil(parser._match_set("He drew set(the) blade"))
  end)
  it("errors on a multi-digit literal (02 R3)", function()
    assert.has_error(function() parser._match_set("set(v_x,12)") end)
  end)
end)

describe("_match_achievement", function()
  it("captures text and variable", function()
    local t, v = parser._match_achievement('achievement("A message in the sky",v_ac_ch1_coward)')
    assert.are.equal("A message in the sky", t)
    assert.are.equal("v_ac_ch1_coward", v)
  end)
end)

describe("_match_choice", function()
  it("parses target, set-vars and a divert", function()
    local c = parser._match_choice('choice("Excited", Ch1-Intro2, v_ch1_intro_feeling = 1, v_current_scene = Ch1-Intro2)')
    assert.are.equal("Excited", c.text)
    assert.are.equal("Ch1-Intro2", c.target)
    assert.are.equal("1", c.set_vars.v_ch1_intro_feeling)
    assert.are.equal("Ch1-Intro2", c.set_vars.v_current_scene)
    assert.is_nil(c.special)
  end)
  it("handles doubled-quote spoken labels (02 F-06)", function()
    local c = parser._match_choice('choice(""I see no reason to hide."", Ch1-Dave2, v_current_scene = Ch1-Dave2)')
    assert.are.equal('"I see no reason to hide."', c.text)
    assert.are.equal("Ch1-Dave2", c.target)
  end)
  it("captures special: and a trailing condition", function()
    local c = parser._match_choice('choice("Load game", , , special:saves) if (v_a > 0)')
    assert.are.equal("saves", c.special)
    assert.are.same({ { "v_a > 0" } }, c.conditions)
  end)
end)

describe("_match_if", function()
  it("captures the condition up to the last paren", function()
    assert.are.equal("v_ch1_intro_feeling == 1", parser._match_if("#if(v_ch1_intro_feeling == 1)"))
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

Expected: FAIL — `_match_set` is nil.

- [ ] **Step 3: Implement**

Append to `magium.koplugin/engine/parser.lua`, before `return M`:
```lua
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
      -- (The JS regex would simply not match and the line would fall to prose;
      --  we assert instead. Corpus has 0 multi-digit set() values.)
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
```

- [ ] **Step 4: Run it, verify it passes**

Expected: all matcher tests green.

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/parser.lua magium.koplugin/spec/engine/parser_constructs_spec.lua
git commit -m "engine/parser: set/achievement/choice/#if construct matchers, hardened (Task 3)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Parser — `parse(path)` file loop + corpus verification

**Files:**
- Modify: `magium.koplugin/engine/parser.lua` (add `M.parse`)
- Test: `magium.koplugin/spec/engine/parser_spec.lua`

**Interfaces:**
- Consumes: `M._match_set/_match_achievement/_match_choice/_match_if`, `M.parse_conditions`.
- Produces: `parser.parse(path) -> scenes` where `scenes = { [scene_id] = scene_table }`. `scene_table = { id, paragraphs = {{text, conditions}}, choices = {choice_table}, set_variables = {{name, value, conditions}}, achievements = {{text, variable}} }`. Also `parser.anomalies` — a list (strings) reset at the start of each `parse` call, appended to when a line starts with a construct keyword but no matcher succeeds (R1/R6).

Reference: `parser.js:23–126`. Dispatch order per line: `ID` → `TEXT` → skip-one → set → achievement → choice → `#if` → `}` → else prose (`line .. "<br/>"`). Quirks kept: the leading `{}` placeholder scene dropped via `slice(1)`; `currentParagraph` not reset on `ID:`; blank prose line → bare `<br/>`.

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/parser_spec.lua`:
```lua
local helper = require("spec/spec_helper")
local parser = require("engine/parser")

describe("parser.parse — ch1.magium", function()
  local scenes
  setup(function() scenes = parser.parse(helper.data_dir_en .. "/ch1.magium") end)

  it("has 12 scenes and no anomalies", function()
    local n = 0
    for _ in pairs(scenes) do n = n + 1 end
    assert.are.equal(12, n)
    assert.are.same({}, parser.anomalies)
  end)

  it("parses Ch1-Intro1's three choices with diverts", function()
    local s = scenes["Ch1-Intro1"]
    assert.are.equal(3, #s.choices)
    assert.are.equal("Excited", s.choices[1].text)
    assert.are.equal("Ch1-Intro2", s.choices[1].set_vars.v_current_scene)
  end)

  it("parses Ch1-Intro2's #if paragraph branches", function()
    local s = scenes["Ch1-Intro2"]
    local conditional = 0
    for _, p in ipairs(s.paragraphs) do
      if p.conditions then conditional = conditional + 1 end
    end
    assert.is_true(conditional >= 3)
  end)

  it("keeps <br/> joins in prose", function()
    assert.is_truthy(scenes["Ch1-Intro1"].paragraphs[1].text:find("<br/>", 1, true))
  end)
end)

describe("parser.parse — full English corpus", function()
  it("reproduces the exact structural counts (spec §11.1)", function()
    local dir = helper.data_dir_en
    local p = io.popen('ls "' .. dir .. '"/*.magium')
    local files = {}
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    assert.are.equal(54, #files)

    local scn, para, cho, setv, ach, ifs, anomalies = 0, 0, 0, 0, 0, 0, 0
    for _, f in ipairs(files) do
      local scenes = parser.parse(f)
      anomalies = anomalies + #parser.anomalies
      for _, s in pairs(scenes) do
        scn = scn + 1
        para = para + #s.paragraphs
        cho = cho + #s.choices
        setv = setv + #s.set_variables
        ach = ach + #s.achievements
        for _, pp in ipairs(s.paragraphs) do
          if pp.conditions then ifs = ifs + 1 end
        end
      end
    end
    assert.are.equal(0, anomalies)
    assert.are.equal(2159, scn)
    assert.are.equal(4880, para)
    assert.are.equal(3734, cho)
    assert.are.equal(594, setv)
    assert.are.equal(145, ach)
    -- #if blocks: paragraphs carrying a conditions field. 2480 per 01 §11.
    assert.are.equal(2480, ifs)
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

Expected: FAIL — `parser.parse` is nil.

- [ ] **Step 3: Implement**

Append `M.parse` and `M.anomalies` to `magium.koplugin/engine/parser.lua`:
```lua
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
```

- [ ] **Step 4: Run it, verify it passes**

Run: `wsl bash -lc 'cd .../magium.koplugin && busted spec/engine/parser_spec.lua'`
Expected: all green, including the exact corpus counts. If a count is off, the parser diverges from `magium-dev` — do not adjust the expected numbers; fix the matcher. Cross-check by parsing the same file with `node -e` against `magium-dev/src/parser.js`.

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/parser.lua magium.koplugin/spec/engine/parser_spec.lua
git commit -m "engine/parser: parse() file loop; full-corpus structural parity (Task 4)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: `engine/story.lua` — eager strategy

**Files:**
- Create: `magium.koplugin/engine/story.lua`
- Test: `magium.koplugin/spec/engine/story_eager_spec.lua`

**Interfaces:**
- Consumes: `require("engine/parser")`.
- Produces: `local Story = require("engine/story")`, then:
  - `Story.new{ data_dir = <path>, locale = "en", strategy = "eager", cache_store = nil } -> story`
  - `story:preload(on_progress)` — `on_progress` optional `function(done, total)`; parses all 54 files. Returns `story`.
  - `story:get_scene(id) -> scene_table | nil`
  - `story:scene_ids() -> function` iterator yielding each id once
  - `story:count() -> n` (loaded scene count; for QA)

Reference: spec §7.1, §7.3. `data_dir` is `<root>` containing `<locale>/*.magium`.

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/story_eager_spec.lua`:
```lua
local helper = require("spec/spec_helper")
local Story = require("engine/story")

local DATA_ROOT = helper.data_dir_en:gsub("/en$", "")  -- ".../data"

describe("Story (eager)", function()
  local story
  setup(function()
    story = Story.new{ data_dir = DATA_ROOT, locale = "en", strategy = "eager" }
    story:preload()
  end)

  it("loads the whole corpus", function()
    assert.are.equal(2159, story:count())
  end)

  it("returns a parsed scene by id", function()
    local s = story:get_scene("Ch1-Intro1")
    assert.are.equal("Ch1-Intro1", s.id)
    assert.are.equal(3, #s.choices)
  end)

  it("returns nil for an unknown id", function()
    assert.is_nil(story:get_scene("No-Such-Scene"))
  end)

  it("reports progress", function()
    local last = 0
    local s2 = Story.new{ data_dir = DATA_ROOT, locale = "en", strategy = "eager" }
    s2:preload(function(done, total) last = done; assert.are.equal(54, total) end)
    assert.are.equal(54, last)
  end)

  it("iterates every id once", function()
    local seen = {}
    for id in story:scene_ids() do
      assert.is_nil(seen[id])
      seen[id] = true
    end
    assert.are.equal(2159, (function() local n = 0 for _ in pairs(seen) do n = n + 1 end return n end)())
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

Expected: FAIL — `module 'engine/story' not found`.

- [ ] **Step 3: Implement**

`magium.koplugin/engine/story.lua`:
```lua
-- engine/story.lua — the parse-strategy seam (spec §7). PURE: Lua stdlib only.
-- Two strategies behind one interface; Milestone 0 picks the default.

local parser = require("engine/parser")

local Story = {}
Story.__index = Story

local function list_magium(dir)
  local files = {}
  local p = assert(io.popen('ls "' .. dir .. '"/*.magium 2>/dev/null'))
  for line in p:lines() do files[#files + 1] = line end
  p:close()
  table.sort(files)
  return files
end

local function file_size(path)
  local f = io.open(path, "rb")
  if not f then return 0 end
  local n = f:seek("end")
  f:close()
  return n
end

function Story.new(opts)
  assert(opts and opts.data_dir, "Story.new: data_dir required")
  local self = setmetatable({}, Story)
  self.data_dir = opts.data_dir
  self.locale = opts.locale or "en"
  self.strategy = opts.strategy or "eager"
  self.cache_store = opts.cache_store
  self.dir = self.data_dir .. "/" .. self.locale
  self.scenes = {}          -- id -> scene_table (eager: all; lazy: parsed so far)
  self.index = nil          -- lazy: id -> filename
  self._loaded_files = {}   -- lazy: filename -> true
  return self
end

function Story:_merge(dict)
  for id, scene in pairs(dict) do
    if self.scenes[id] then
      error("Story: duplicate scene id across files: " .. id)  -- R9
    end
    self.scenes[id] = scene
  end
end

function Story:preload(on_progress)
  if self.strategy == "eager" then
    local files = list_magium(self.dir)
    for i, f in ipairs(files) do
      self:_merge(parser.parse(f))
      if on_progress then on_progress(i, #files) end
    end
  else
    self:_build_index(on_progress)
  end
  return self
end

function Story:get_scene(id)
  if self.scenes[id] then return self.scenes[id] end
  if self.strategy == "lazy" then return self:_lazy_get(id) end
  return nil
end

function Story:count()
  local n = 0
  for _ in pairs(self.scenes) do n = n + 1 end
  return n
end

function Story:scene_ids()
  return coroutine.wrap(function()
    if self.strategy == "lazy" and self.index then
      for id in pairs(self.index) do coroutine.yield(id) end
    else
      for id in pairs(self.scenes) do coroutine.yield(id) end
    end
  end)
end

-- ---- lazy strategy (Task 15 fills _build_index / _lazy_get) --------------------
function Story:_build_index(on_progress) error("lazy strategy not built yet (Task 15)") end
function Story:_lazy_get(id) error("lazy strategy not built yet (Task 15)") end

-- exposed for Task 15's spec
Story._list_magium = list_magium
Story._file_size = file_size

return Story
```

- [ ] **Step 4: Run it, verify it passes**

Expected: all 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/story.lua magium.koplugin/spec/engine/story_eager_spec.lua
git commit -m "engine/story: eager parse-strategy + interface (Task 5)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Milestone 0 — on-device parse-timing harness

**Files:**
- Create: `docs/spikes/06-ondevice-parse-timing/HYPOTHESIS.md`
- Create: `docs/spikes/06-ondevice-parse-timing/FINDING.md` (skeleton; filled after the run)
- Create: `magium.koplugin/main.lua` (temporary timing-only version; replaced in Task 20)
- Modify: `docs/specs/2026-08-31-plugin-architecture-and-phase-i.md` §7.1

**Interfaces:**
- Consumes: `require("engine/story")`.
- Produces: a menu item **"Magium: time parse"** that runs `story:preload()` and logs cold/warm wall-clock. This `main.lua` is discarded in Task 20 — keep it minimal.

Reference: spec §10; the timing pattern from [spike 03 `measure_lua.lua`](../../spikes/03-full-corpus-memory-parse/measure_lua.lua). **Decision rule:** device cold parse ≤ ~1 s → `eager` at launch; > ~1 s → lazy per-chapter cache *or* eager deferred to first open (`04` §3 row 3). **Outcome: 2.2 s → `eager`, deferred to first `openReader()` (owner call — simpler than building the lazy path). Task 15 deferred; Task 20 `PARSE_STRATEGY = "eager"`.**

- [ ] **Step 1: Write `HYPOTHESIS.md`**

`docs/spikes/06-ondevice-parse-timing/HYPOTHESIS.md`:
```markdown
# Spike 06 — on-device parse-timing gate (Milestone 0)

- **Status:** in progress
- **Last updated:** <date>
- **Phase:** Implementation — Milestone 0
- **Sources:** [`../../specs/2026-08-31-plugin-architecture-and-phase-i.md` §10](../../specs/2026-08-31-plugin-architecture-and-phase-i.md#10-milestone-0--on-device-parse-timing-gate), [spike 03](../03-full-corpus-memory-parse/FINDING.md)
- **Related:** [ADR-002](../../decisions/ADR-002-porting-approach.md), OQ-001

## Hypothesis

Parsing all 54 English `.magium` files with `engine/parser.lua` completes in
≤ ~1 s on the Kindle Paperwhite 12th gen's 1 GHz MTK ARM core under
koreader-base's LuaJIT — making "parse everything at launch" (`story` eager)
viable without a lazy/disk-cache layer for the MVP.

Desktop anchors (spike 03): 112–205 ms on x86 across two LuaJIT builds.

## Method

Deploy the timing `main.lua` + `engine/`. Menu → "Magium: time parse". It
restarts-cold-parses once (log line `MAGIUM parse cold: N ms`), then parses
twice more warm (`MAGIUM parse warm: N ms`). Read `koreader/crash.log`.

Run on: (a) the real Kindle, (b) the WSL2 kodev emulator (x86 — sanity only).

## Decision rule

| Kindle cold parse | `story` default |
|---|---|
| ≤ ~1 s | `eager` |
| > ~1 s | `lazy` |
```

- [ ] **Step 2: Write the timing `main.lua`**

`magium.koplugin/main.lua`:
```lua
-- TEMPORARY — Milestone 0 timing harness only. Replaced by the real plugin
-- class in Task 20. Do not build on this file.
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local _ = require("gettext")

local Story = require("engine/story")

local Magium = WidgetContainer:extend{ name = "magium", is_doc_only = false }

function Magium:init()
  self.ui.menu:registerToMainMenu(self)
end

local function time_parse(data_root)
  local function once()
    local t0 = os.clock()
    Story.new{ data_dir = data_root, locale = "en", strategy = "eager" }:preload()
    return (os.clock() - t0) * 1000
  end
  local cold = once()
  logger.info(string.format("MAGIUM parse cold: %.0f ms", cold))
  local warm1, warm2 = once(), once()
  logger.info(string.format("MAGIUM parse warm: %.0f ms / %.0f ms", warm1, warm2))
  return cold, warm1, warm2
end

function Magium:addToMainMenu(menu_items)
  menu_items.magium = {
    text = _("Magium: time parse"),
    sorting_hint = "more_tools",
    callback = function()
      local data_root = self.path .. "/data"
      local cold, w1, w2 = time_parse(data_root)
      UIManager:show(InfoMessage:new{
        text = string.format("cold %.0f ms\nwarm %.0f / %.0f ms\n(see crash.log)", cold, w1, w2),
      })
    end,
  }
end

return Magium
```

- [ ] **Step 3: Verify in the emulator**

```bash
wsl bash -lc 'ln -sfn "/mnt/f/Projects/Magium - Kindle/magium-koreader/magium.koplugin" ~/koreader/koreader/plugins/magium.koplugin && cd ~/koreader && xvfb-run -a ./kodev run --simulate=kindle-paperwhite --no-build'
```
In the emulator: ≡ menu → More tools → "Magium: time parse". Expect an InfoMessage with three numbers. Then:
```bash
wsl bash -lc 'grep "MAGIUM parse" ~/koreader/koreader/crash.log | tail -5'
```
Expected: `MAGIUM parse cold: <N> ms` and a warm pair, `<N>` in the low hundreds of ms (x86).

- [ ] **Step 4: Run on the real Kindle (owner checkpoint)**

Copy `magium.koplugin/` to the Kindle's `koreader/plugins/`, restart KOReader, run the menu item, pull `koreader/crash.log` over USB, read the `MAGIUM parse cold` line.

**This step needs the physical device and is the owner's to run.** Record the number.

- [ ] **Step 5: Record the finding and set the default**

Write `docs/spikes/06-ondevice-parse-timing/FINDING.md` with the cold/warm numbers (device + emulator), the verdict against the ~1 s rule, and the chosen `strategy`.

Edit `docs/specs/2026-08-31-plugin-architecture-and-phase-i.md` §7.1 opening sentence to state the measured number and the resulting default (e.g. "Milestone 0 measured NNN ms on-device → default `strategy = \"eager\"`.").

- [ ] **Step 6: Commit**

```bash
git add docs/spikes/06-ondevice-parse-timing/ magium.koplugin/main.lua docs/specs/
git commit -m "Milestone 0: on-device parse-timing harness + finding; set story default (Task 6)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: `engine/conditions.lua`

**Files:**
- Create: `magium.koplugin/engine/conditions.lua`
- Test: `magium.koplugin/spec/engine/conditions_spec.lua`

**Interfaces:**
- Produces: `local C = require("engine/conditions")`:
  - `C.eval_atom(atom_string, view) -> boolean|nil` — `view` is a `{ [name] = string_value }` table. `nil`/`""` atom → `true`; `"True"` → `true`; malformed → `nil` (falsy) and appended to `C.failures` (a list, for dev diagnostics).
  - `C.eval(dnf, view) -> boolean` — `nil` dnf → `true`; else OR-of-ANDs.

Reference: `utils.js:54–97`; [spike 02 `magium_utils.lua:35–66`](../../spikes/02-engine-in-lua/magium_utils.lua). Operators: `< > <= >= == !=`, numeric. Coercion: `tonumber(view[name] or 0) or 0`. `%w` excludes `_` in Lua — the identifier class is `[%w_]`.

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/conditions_spec.lua`:
```lua
require("spec/spec_helper")
local C = require("engine/conditions")

describe("eval_atom", function()
  it("true for nil / empty / 'True'", function()
    assert.is_true(C.eval_atom(nil, {}))
    assert.is_true(C.eval_atom("", {}))
    assert.is_true(C.eval_atom("True", {}))
  end)
  it("compares each operator numerically", function()
    local v = { v_x = "3" }
    assert.is_true(C.eval_atom("v_x > 2", v))
    assert.is_false(C.eval_atom("v_x > 3", v))
    assert.is_true(C.eval_atom("v_x >= 3", v))
    assert.is_true(C.eval_atom("v_x == 3", v))
    assert.is_true(C.eval_atom("v_x != 4", v))
    assert.is_true(C.eval_atom("v_x < 4", v))
    assert.is_true(C.eval_atom("v_x <= 3", v))
  end)
  it("treats an unset variable as 0", function()
    assert.is_true(C.eval_atom("v_missing == 0", {}))
    assert.is_false(C.eval_atom("v_missing > 0", {}))
  end)
  it("handles snake_case identifiers (Lua %w gotcha)", function()
    assert.is_true(C.eval_atom("v_ancient_languages > 2", { v_ancient_languages = "3" }))
  end)
  it("returns nil and records a failure for a malformed atom", function()
    C.failures = {}
    assert.is_nil(C.eval_atom("False", {}))
    assert.are.equal(1, #C.failures)
  end)
end)

describe("eval", function()
  it("nil dnf is unconditional true", function()
    assert.is_true(C.eval(nil, {}))
  end)
  it("OR of ANDs", function()
    local v = { v_a = "1", v_b = "0", v_c = "9" }
    assert.is_true(C.eval({ { "v_a > 5" }, { "v_c > 5" } }, v))
    assert.is_false(C.eval({ { "v_a > 5" }, { "v_b > 5" } }, v))
    assert.is_true(C.eval({ { "v_a == 1", "v_b == 0" } }, v))
    assert.is_false(C.eval({ { "v_a == 1", "v_b == 1" } }, v))
  end)
  it("an empty AND clause is true (JS .every on [])", function()
    assert.is_true(C.eval({ {} }, {}))
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

- [ ] **Step 3: Implement**

`magium.koplugin/engine/conditions.lua`:
```lua
-- engine/conditions.lua — DNF condition evaluation.
-- Port of magium-dev/src/utils.js:apply_condition / apply_conditions @ 51f5aa9.
-- PURE: Lua stdlib only.

local M = {}
M.failures = {}   -- malformed atoms seen this session (dev diagnostics only)

function M.eval_atom(atom, view)
  if atom == nil or atom == "" then return true end
  if atom == "True" then return true end
  local name, op, num = atom:match("^([%w_]*) ([<>=!]+) (%d+)$")
  if not name then
    M.failures[#M.failures + 1] = atom
    return nil
  end
  local value = tonumber(num)
  local v = tonumber(view[name] or 0) or 0
  if op == ">" then return v > value
  elseif op == "<" then return v < value
  elseif op == "<=" then return v <= value
  elseif op == ">=" then return v >= value
  elseif op == "!=" then return v ~= value
  elseif op == "==" then return v == value end
  M.failures[#M.failures + 1] = atom
  return nil
end

function M.eval(dnf, view)
  if not dnf then return true end
  for _, and_group in ipairs(dnf) do
    local all_true = true
    for _, atom in ipairs(and_group) do
      if not M.eval_atom(atom, view) then all_true = false; break end
    end
    if all_true then return true end
  end
  return false
end

return M
```

- [ ] **Step 4: Run it, verify it passes**

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/conditions.lua magium.koplugin/spec/engine/conditions_spec.lua
git commit -m "engine/conditions: DNF evaluation (Task 7)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: `engine/store.lua`

**Files:**
- Create: `magium.koplugin/engine/store.lua`
- Test: `magium.koplugin/spec/engine/store_spec.lua`

**Interfaces:**
- Produces: `local Store = require("engine/store")`:
  - `Store.new(initial_table | nil) -> store` — copies `initial_table`.
  - `store:get(name) -> string|nil`
  - `store:set(name, value)` — value is a string. `"+N"`/`"-N"` resolve against the current numeric value and store the resolved decimal string. **The `v_ac_*` "seen" freeze:** for any `name` starting `v_ac_`, if the current value is (numerically) `2`, the write is **ignored entirely** — regardless of the incoming value (matches `magium-dev/public/scripts/utils.js` `storeVariable`: `if (data[key] != 2) storeItem(...)`). Non-`v_ac_` names are never frozen. Writing `v_ac_b3_ch9_consolation` and reaching exactly `5` also sets `v_ac_b3_ch9_prize = "1"` (special case #12 — `storeItem`'s `data[key] == 5`; in practice the freeze caps this counter at 2 so it never fires, but keep it for faithful parity).
  - `store:view() -> table` — a fresh shallow copy `{ [name] = value }` for passing to `conditions.eval` / `scene.render`.
  - `store:snapshot() -> table` — deep-ish copy for saves.
  - `store:restore(t)` — replace all state from `t`.

Reference: spec §3.1, §5.2; `01` §2 (`utils.js:13–24,29–31`).

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/store_spec.lua`:
```lua
require("spec/spec_helper")
local Store = require("engine/store")

describe("Store", function()
  it("get/set round-trips strings", function()
    local s = Store.new()
    s:set("v_x", "3")
    assert.are.equal("3", s:get("v_x"))
    assert.is_nil(s:get("v_missing"))
  end)

  it("resolves +N / -N on write", function()
    local s = Store.new({ v_c = "2" })
    s:set("v_c", "+3")
    assert.are.equal("5", s:get("v_c"))
    s:set("v_c", "-1")
    assert.are.equal("4", s:get("v_c"))
  end)

  it("+N against an unset variable starts from 0", function()
    local s = Store.new()
    s:set("v_new", "+2")
    assert.are.equal("2", s:get("v_new"))
  end)

  it("freezes a v_ac_* flag once it reaches 2 (any incoming value)", function()
    local s = Store.new({ v_ac_x = "2" })
    s:set("v_ac_x", "1")
    assert.are.equal("2", s:get("v_ac_x"))
    s:set("v_ac_x", "3")
    assert.are.equal("2", s:get("v_ac_x"))
    s:set("v_ac_x", "+5")
    assert.are.equal("2", s:get("v_ac_x"))
  end)

  it("does not freeze a non-v_ac_ variable at 2", function()
    local s = Store.new({ v_ch1_show_yourself = "2" })
    s:set("v_ch1_show_yourself", "1")
    assert.are.equal("1", s:get("v_ch1_show_yourself"))
  end)

  it("triggers the consolation prize at exactly 5 (special case #12)", function()
    -- Seeded at 4 to bypass the v_ac_ freeze (which otherwise caps this counter
    -- at 2, exactly as magium-dev does). `storeItem`: data[key] == 5.
    local s = Store.new({ v_ac_b3_ch9_consolation = "4" })
    s:set("v_ac_b3_ch9_consolation", "+1")
    assert.are.equal("5", s:get("v_ac_b3_ch9_consolation"))
    assert.are.equal("1", s:get("v_ac_b3_ch9_prize"))
  end)

  it("view is a detached copy", function()
    local s = Store.new({ v_a = "1" })
    local v = s:view()
    v.v_a = "999"
    assert.are.equal("1", s:get("v_a"))
  end)

  it("snapshot / restore round-trips", function()
    local s = Store.new({ v_a = "1", v_b = "2" })
    local snap = s:snapshot()
    s:set("v_a", "9")
    s:restore(snap)
    assert.are.equal("1", s:get("v_a"))
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

- [ ] **Step 3: Implement**

`magium.koplugin/engine/store.lua`:
```lua
-- engine/store.lua — the flat v_* variable map. PURE: Lua stdlib only.
-- Port of the write-side semantics in magium-dev/public/scripts/utils.js
-- (storeItem: +N/-N resolution; the v_ac_ "seen" latch; the consolation rule).

local Store = {}
Store.__index = Store

function Store.new(initial)
  local self = setmetatable({}, Store)
  self.v = {}
  if initial then
    for k, val in pairs(initial) do self.v[k] = val end
  end
  return self
end

function Store:get(name) return self.v[name] end

function Store:set(name, value)
  value = tostring(value)

  -- v_ac_* "seen" freeze: once the flag is (numerically) 2, no further write
  -- lands — for ANY incoming value. magium-dev storeVariable: if (data[key] != 2).
  if name:sub(1, 5) == "v_ac_" and (tonumber(self.v[name] or 0) or 0) == 2 then
    return
  end

  -- +N / -N resolve on write against the current numeric value.
  local sign = value:sub(1, 1)
  if sign == "+" or sign == "-" then
    local delta = tonumber(value)
    if delta then
      value = tostring((tonumber(self.v[name] or 0) or 0) + delta)
    end
  end
  self.v[name] = value

  -- special case #12: consolation counter reaches exactly 5 → prize flag.
  -- (storeItem: data[key] == 5. In practice the freeze above caps this counter
  --  at 2, so this never fires in real play — kept for faithful parity.)
  if name == "v_ac_b3_ch9_consolation" and tonumber(value) == 5 then
    self.v.v_ac_b3_ch9_prize = "1"
  end
end

function Store:view()
  local out = {}
  for k, val in pairs(self.v) do out[k] = val end
  return out
end

function Store:snapshot()
  local out = {}
  for k, val in pairs(self.v) do out[k] = val end
  return out
end

function Store:restore(t)
  self.v = {}
  for k, val in pairs(t or {}) do self.v[k] = val end
end

return Store
```

- [ ] **Step 4: Run it, verify it passes**

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/store.lua magium.koplugin/spec/engine/store_spec.lua
git commit -m "engine/store: variable map, +N/-N, seen latch, consolation rule (Task 8)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: `engine/stats.lua`

**Files:**
- Create: `magium.koplugin/engine/stats.lua`
- Test: `magium.koplugin/spec/engine/stats_spec.lua`

**Interfaces:**
- Consumes: `require("engine/conditions")` (for `eval_atom` when scanning groups).
- Produces: `local stats = require("engine/stats")`:
  - `stats.var_to_stat(var_name) -> ui_json_key` (e.g. `"v_agility"` → `"statsSpeedText"`).
  - `stats.parse_stat_check(atom_string) -> { variable = key_or_raw, value = n, success = bool } | nil`
  - `stats.stat_checks_to_display(items, view) -> { { variable = key_or_raw, value = n, success = bool }, ... }` — `items` is an array where each element may have `.conditions` (a dnf). De-duped; the `v_b3_ch1_unlock` lock filter drops all other rows.

Reference: `utils.js:114–208`; [spike 02 `magium_utils.lua:68–153`](../../spikes/02-engine-in-lua/magium_utils.lua). The 14 stat vars per `utils.js:4–19`.

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/stats_spec.lua`:
```lua
require("spec/spec_helper")
local stats = require("engine/stats")

describe("var_to_stat", function()
  it("special-cases agility and perception", function()
    assert.are.equal("statsSpeedText", stats.var_to_stat("v_agility"))
    assert.are.equal("statsObservationText", stats.var_to_stat("v_perception"))
  end)
  it("camel-cases the rest", function()
    assert.are.equal("statsAncientLanguagesText", stats.var_to_stat("v_ancient_languages"))
    assert.are.equal("statsStrengthText", stats.var_to_stat("v_strength"))
  end)
end)

describe("parse_stat_check", function()
  it("nil for a non-stat variable", function()
    assert.is_nil(stats.parse_stat_check("v_ch1_show_yourself > 1"))
  end)
  it("< N => failed at level N", function()
    assert.are.same({ variable = "statsObservationText", value = 1, success = false },
      stats.parse_stat_check("v_perception < 1"))
  end)
  it("== 0 => failed at level 1", function()
    assert.are.same({ variable = "statsStrengthText", value = 1, success = false },
      stats.parse_stat_check("v_strength == 0"))
  end)
  it(">= N and == N (N != 0) => success at level N", function()
    assert.are.same({ variable = "statsHearingText", value = 3, success = true },
      stats.parse_stat_check("v_hearing >= 3"))
    assert.are.same({ variable = "statsHearingText", value = 2, success = true },
      stats.parse_stat_check("v_hearing == 2"))
  end)
  it("> N => success at level N+1", function()
    assert.are.same({ variable = "statsReflexesText", value = 3, success = true },
      stats.parse_stat_check("v_reflexes > 2"))
  end)
  it("v_b3_ch1_unlock == 2 => raw locked failure", function()
    assert.are.same({ variable = "v_b3_ch1_unlock", value = 2, success = false },
      stats.parse_stat_check("v_b3_ch1_unlock == 2"))
  end)
end)

describe("stat_checks_to_display", function()
  it("collects checks from passing condition groups, de-duped", function()
    local view = { v_perception = "2", v_ancient_languages = "3" }
    local items = {
      { conditions = { { "v_perception > 1" } } },
      { conditions = { { "v_ancient_languages >= 3" } } },
      { conditions = { { "v_perception > 1" } } },   -- dup
    }
    local out = stats.stat_checks_to_display(items, view)
    assert.are.equal(2, #out)
  end)
  it("lock filter: v_b3_ch1_unlock drops every other row", function()
    local view = { v_b3_ch1_unlock = "2", v_strength = "5" }
    local items = {
      { conditions = { { "v_b3_ch1_unlock == 2" } } },
      { conditions = { { "v_strength >= 3" } } },
    }
    local out = stats.stat_checks_to_display(items, view)
    assert.are.equal(1, #out)
    assert.are.equal("v_b3_ch1_unlock", out[1].variable)
  end)
  it("skips items without conditions", function()
    assert.are.equal(0, #stats.stat_checks_to_display({ { value = "x" } }, {}))
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

- [ ] **Step 3: Implement**

`magium.koplugin/engine/stats.lua`:
```lua
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
```

- [ ] **Step 4: Run it, verify it passes**

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/stats.lua magium.koplugin/spec/engine/stats_spec.lua
git commit -m "engine/stats: var_to_stat, parse_stat_check, stat_checks_to_display (Task 9)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 10: `engine/locale.lua`

**Files:**
- Create: `magium.koplugin/engine/locale.lua`
- Test: `magium.koplugin/spec/engine/locale_spec.lua`

**Interfaces:**
- Consumes: `require("engine/vendor/json")`.
- Produces: `local Locale = require("engine/locale")`:
  - `Locale.load(data_dir, lang) -> locale` — reads `<data_dir>/<lang>/ui.json`.
  - `locale:str(key) -> string|nil`
  - `locale:header(scene_id) -> string|nil` — `getHeaderFromId` + template interpolation. `nil` if the id has no `Ch<n>` segment.
  - `locale:stat_check_text(stat_check) -> string` — picks `mainStatSuccessTemplate` / `mainStatFailedTemplate`, interpolates `<%= variable %>` (already a resolved label or the raw `v_b3_ch1_unlock`, in which case use `mainStatDeviceLockedText`), `<%= value %>`, collapses whitespace, trims.

Reference: `utils.js:28–36` (`getHeaderFromId` regex `/(B(?<book>[0-9]*)-)?Ch(?<chapter>[0-9]*)[a-c]?-.*$/`), `01` §9; [spike 02 `render_scene.lua:12–18`](../../spikes/02-engine-in-lua/render_scene.lua) (`ejs_lite`).

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/locale_spec.lua`:
```lua
local helper = require("spec/spec_helper")
local Locale = require("engine/locale")

local DATA_ROOT = helper.data_dir_en:gsub("/en$", "")

describe("Locale", function()
  local loc
  setup(function() loc = Locale.load(DATA_ROOT, "en") end)

  it("looks up a ui string", function()
    assert.is_string(loc:str("statsStrengthText"))
  end)

  it("derives the header from a scene id", function()
    assert.are.equal("Book 1 - Chapter 1", loc:header("Ch1-Intro1"))
    assert.are.equal("Book 2 - Chapter 7", loc:header("B2-Ch07a-Intro"))
  end)

  it("returns nil header for a non-matching id", function()
    assert.is_nil(loc:header("MainMenu"))
  end)

  it("renders a stat-check line", function()
    local txt = loc:stat_check_text({ variable = loc:str("statsObservationText"), value = 3, success = true })
    assert.is_truthy(txt:find("Observation"))
    assert.is_truthy(txt:find("3"))
    assert.is_falsy(txt:find("  "))       -- whitespace collapsed
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

- [ ] **Step 3: Implement**

`magium.koplugin/engine/locale.lua`:
```lua
-- engine/locale.lua — ui.json strings, header derivation, stat-check templates.
-- Port of the getHeaderFromId + ui.json usage in magium-dev @ 51f5aa9.
-- PURE: Lua stdlib + engine/vendor/json.

local json = require("engine/vendor/json")

local Locale = {}
Locale.__index = Locale

local function read_file(path)
  local f = assert(io.open(path, "r"), "cannot open " .. path)
  local s = f:read("*a")
  f:close()
  return s
end

function Locale.load(data_dir, lang)
  local self = setmetatable({}, Locale)
  self.lang = lang
  self.strings = json.decode(read_file(data_dir .. "/" .. lang .. "/ui.json"))
  return self
end

function Locale:str(key) return self.strings[key] end

-- <%= name %> interpolation (the only EJS feature ui.json templates use).
local function interp(tmpl, vars)
  return (tmpl:gsub("<%%=%s*([%w_]+)%s*%%>", function(k) return tostring(vars[k]) end))
end

local function collapse_ws(s)
  return (s:gsub("&nbsp;", " "):gsub("[ \t\f\v]+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Locale:header(scene_id)
  local book, chapter = scene_id:match("^B(%d*)%-Ch(%d*)[a-c]?%-")
  if not chapter then
    chapter = scene_id:match("^Ch(%d*)[a-c]?%-")
  end
  if not chapter or chapter == "" then return nil end
  book = (book ~= nil and book ~= "") and book or "1"
  local tmpl = self.strings.mainHeaderTemplate or "Book <%= book %> - Chapter <%= chapter %>"
  return collapse_ws(interp(tmpl, { book = book, chapter = tostring(tonumber(chapter)) }))
end

function Locale:stat_check_text(sc)
  if sc.variable == "v_b3_ch1_unlock" then
    return collapse_ws(self.strings.mainStatDeviceLockedText or "[ Stat device locked - check failed ]")
  end
  local tmpl = sc.success and self.strings.mainStatSuccessTemplate or self.strings.mainStatFailedTemplate
  return collapse_ws(interp(tmpl, { variable = sc.variable, value = sc.value }))
end

return Locale
```

- [ ] **Step 4: Run it, verify it passes**

If `loc:header("B2-Ch07a-Intro")` fails, check the `[a-c]?` optional-letter handling against the real scene-id set in `data/en/`.

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/locale.lua magium.koplugin/spec/engine/locale_spec.lua
git commit -m "engine/locale: ui.json strings, header derivation, stat-check text (Task 10)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 11: `engine/specials.lua`

**Files:**
- Create: `magium.koplugin/engine/specials.lua`
- Test: `magium.koplugin/spec/engine/specials_spec.lua`

**Interfaces:**
- Produces: `local specials = require("engine/specials")`:
  - `specials.DEFAULT_SCENE = "Ch1-Intro1"` (case #1)
  - `specials.suppress_stat_checks(scene_id) -> bool` — true for `"B3-Ch04a-Introduction2"` (case #2)
  - `specials.extra_achievements(view) -> { {text, variable}, ... }` — the always-on Consolation prize when `view.v_ac_b3_ch9_prize == "1"` (case #3)
  - `specials.CONSOLATION = { text = "Consolation prize", variable = "v_ac_b3_ch9_prize" }`

Cases #4 (checkpoint banner) and #6–#8 (`v_b3_ch1_unlock`) are handled inside `stats.lua` / `scene.lua` directly, not here — this module holds only the scene-id-keyed lookups. Note that in the spec's §11.1 list.

Reference: `01` §10 table; `renderers.js:76,84`.

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/specials_spec.lua`:
```lua
require("spec/spec_helper")
local specials = require("engine/specials")

describe("specials", function()
  it("default scene", function()
    assert.are.equal("Ch1-Intro1", specials.DEFAULT_SCENE)
  end)
  it("suppresses stat checks in the Average-Joe reveal", function()
    assert.is_true(specials.suppress_stat_checks("B3-Ch04a-Introduction2"))
    assert.is_false(specials.suppress_stat_checks("Ch1-Intro1"))
  end)
  it("appends the consolation prize when the flag is set", function()
    assert.are.same({}, specials.extra_achievements({}))
    local extra = specials.extra_achievements({ v_ac_b3_ch9_prize = "1" })
    assert.are.equal(1, #extra)
    assert.are.equal("v_ac_b3_ch9_prize", extra[1].variable)
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

- [ ] **Step 3: Implement**

`magium.koplugin/engine/specials.lua`:
```lua
-- engine/specials.lua — scene-id-keyed hardcoded special cases (01 §10).
-- Render-time cases only. PURE: Lua stdlib only.

local M = {}

M.DEFAULT_SCENE = "Ch1-Intro1"                                       -- case #1
M.CONSOLATION = { text = "Consolation prize", variable = "v_ac_b3_ch9_prize" }

local NO_STAT_CHECK_SCENES = { ["B3-Ch04a-Introduction2"] = true }   -- case #2

function M.suppress_stat_checks(scene_id)
  return NO_STAT_CHECK_SCENES[scene_id] == true
end

function M.extra_achievements(view)                                  -- case #3
  if view.v_ac_b3_ch9_prize == "1" then
    return { { text = M.CONSOLATION.text, variable = M.CONSOLATION.variable } }
  end
  return {}
end

return M
```

- [ ] **Step 4: Run it, verify it passes**

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/specials.lua magium.koplugin/spec/engine/specials_spec.lua
git commit -m "engine/specials: render-time special-case table (Task 11)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 12: `engine/scene.lua` — the 12-step render pipeline

**Files:**
- Create: `magium.koplugin/engine/scene.lua`
- Test: `magium.koplugin/spec/engine/scene_spec.lua`

**Interfaces:**
- Consumes: `require("engine/conditions")`, `require("engine/stats")`, `require("engine/specials")`, and a `locale` object (Task 10) passed in.
- Produces: `local scene = require("engine/scene")`:
  - `scene.render(scene_table, view, locale) -> render_model` where
    ```
    render_model = {
      scene_id, header, checkpoint (bool),
      stat_checks   = { { success, text }, ... },
      set_variables = { { name, value }, ... },   -- literal parsed value
      paragraphs    = { "<prose with <br/>>", ... },
      choices       = { { text, target, special, set_variables = {k=v} }, ... },
      achievements  = { { variable, text }, ... },
    }
    ```

Reference: `renderers.js:52–92`; spec §6 (the 12 steps, in order); [spike 02 `render_scene.lua`](../../spikes/02-engine-in-lua/render_scene.lua). **`view` is a plain table** (from `store:view()`); `render` must not mutate it — it copies to a working view internally.

- [ ] **Step 1: Write the failing test**

`magium.koplugin/spec/engine/scene_spec.lua`:
```lua
local helper = require("spec/spec_helper")
local parser = require("engine/parser")
local Locale = require("engine/locale")
local scene = require("engine/scene")

local DATA_ROOT = helper.data_dir_en:gsub("/en$", "")

describe("scene.render — ch1", function()
  local scenes, loc
  setup(function()
    scenes = parser.parse(helper.data_dir_en .. "/ch1.magium")
    loc = Locale.load(DATA_ROOT, "en")
  end)

  it("renders Ch1-Intro1: header, 1 prose block, 3 choices, no stat checks", function()
    local rm = scene.render(scenes["Ch1-Intro1"], {}, loc)
    assert.are.equal("Ch1-Intro1", rm.scene_id)
    assert.are.equal("Book 1 - Chapter 1", rm.header)
    assert.are.equal(1, #rm.paragraphs)
    assert.are.equal(3, #rm.choices)
    assert.are.equal(0, #rm.stat_checks)
    assert.is_false(rm.checkpoint)
    assert.are.equal("Ch1-Intro2", rm.choices[1].set_variables.v_current_scene)
  end)

  it("filters Ch1-Intro2 prose by v_ch1_intro_feeling", function()
    local excited = scene.render(scenes["Ch1-Intro2"], { v_ch1_intro_feeling = "1" }, loc)
    local afraid = scene.render(scenes["Ch1-Intro2"], { v_ch1_intro_feeling = "3" }, loc)
    assert.are_not.equal(
      table.concat(excited.paragraphs, "|"),
      table.concat(afraid.paragraphs, "|")
    )
  end)

  it("does not mutate the caller's view", function()
    local view = { v_ch1_intro_feeling = "1" }
    scene.render(scenes["Ch1-Intro2"], view, loc)
    assert.are.same({ v_ch1_intro_feeling = "1" }, view)
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

- [ ] **Step 3: Implement**

`magium.koplugin/engine/scene.lua`:
```lua
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
      achievements[#achievements + 1] = { variable = a.variable, text = a.text }
    end
  end
  for _, a in ipairs(specials.extra_achievements(work)) do
    achievements[#achievements + 1] = a
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
    local text = locale:stat_check_text{ variable = var, value = sc.value, success = sc.success }
    out_checks[#out_checks + 1] = { success = sc.success, text = text }
  end
  local out_setvars = {}
  for _, sv in ipairs(set_vars) do
    out_setvars[#out_setvars + 1] = { name = sv.name, value = sv.value }
  end
  local out_paras = {}
  for _, p in ipairs(paragraphs) do
    out_paras[#out_paras + 1] = (p.text:gsub("[ \t\f\v]+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
  end
  local out_choices = {}
  for _, c in ipairs(choices) do
    local sv = {}
    for k, v in pairs(c.set_vars) do sv[k] = v end
    out_choices[#out_choices + 1] = {
      text = (c.text:gsub("[ \t\f\v]+", " "):gsub("^%s+", ""):gsub("%s+$", "")),
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

return M
```

- [ ] **Step 4: Run it, verify it passes**

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/engine/scene.lua magium.koplugin/spec/engine/scene_spec.lua
git commit -m "engine/scene: the 12-step render pipeline (Task 12)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 13: Oracle diff — green on the 6 committed goldens

**Files:**
- Create: `magium.koplugin/spec/oracle_diff.lua`
- Test: this task's "test" is the diff exit code.

**Interfaces:**
- Consumes: `engine/parser`, `engine/story`, `engine/scene`, `engine/locale`, `engine/vendor/json`.
- Produces: `luajit spec/oracle_diff.lua <cases.json> <out_dir>` — renders each case with `engine/scene.render`, writes `<out_dir>/<name>.json` in the **canonical shape** that [`reference/tools/oracle-diff.js`](../../../reference/tools/oracle-diff.js) emits (key order `sceneId, header, checkpoint, statChecks[{success,text}], setVariables[{name,value}], paragraphs[str], choices[{text,target,special,setVariables{}}], achievements[{variable,text}]`).

Reference: [`reference/magium-dev-notes.md`](../../../reference/magium-dev-notes.md) (canonical shape + how to run the oracle); [spike 02 `spike_run.lua`](../../spikes/02-engine-in-lua/spike_run.lua) (the same driver pattern).

- [ ] **Step 1: Write the driver**

`magium.koplugin/spec/oracle_diff.lua`:
```lua
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
```

**Required first: patch `engine/vendor/json.lua` for a `null` sentinel.** The vendored
rxi/json.lua has none — Lua `nil` in a table just drops the key, and
`reference/tools/oracle-diff.js`'s `diffCanonical` treats `null` (in the golden's
`choices[].special`) versus a missing key as a **type mismatch**. Add these two lines,
clearly marked as a local addition (and update the file's header comment — it is no
longer "unmodified upstream"):

- right after `local json = { _version = "0.1.2" }`:
  ```lua
  -- LOCAL ADDITION (not upstream): a sentinel for JSON null in a table slot.
  -- Lua nil in a table just deletes the key; this keeps "present but null".
  json.null = setmetatable({}, { __name = "json.null" })
  ```
- as the **first** statement inside the `encode = function(val, stack)` body:
  ```lua
    if val == json.null then return "null" end
  ```

Verify: `luajit -e 'local j=require("engine/vendor/json"); print(j.encode({a=j.null, b={1,2}}))'`
→ `{"a":null,"b":[1,2]}` (key order may vary — `oracle-diff.js diff` parses + compares structurally, so order is irrelevant).

Note: rxi/json.lua encodes an empty Lua table `{}` as `[]` (array), not `{}`. Every ch1
choice carries at least `v_current_scene`, so `choices[].setVariables` is never empty in
Phase I. If a later phase hits a choice with no set-vars, `to_canonical` must force an
object there (e.g. a `__object` marker or a non-empty guard) — not needed now.

- [ ] **Step 2: Re-capture the goldens from the live oracle (drift check)**

```bash
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh diff capture'
```
`mgm.sh diff` starts the magium-dev oracle (polling up to 25 s), runs
`node reference/tools/oracle-diff.js capture`, then tears the oracle down. It
regenerates `reference/tools/oracle-capture/*.json` (6 files) from the live
oracle. Then review `git diff reference/tools/oracle-capture/` — it should be
empty (the goldens are committed from Phase 0, and `magium-dev` is still at
`51f5aa9` = the spec's pin). **If the diff is non-empty and non-trivial, the
oracle drifted — STOP and report; do not trust the comparison.**

- [ ] **Step 3: Render the port and diff**

```bash
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh oracle-diff-lua ../reference/tools/oracle-cases.json spec/out/goldens6'
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh diff diff reference/tools/oracle-capture magium.koplugin/spec/out/goldens6'
```
`mgm.sh oracle-diff-lua <args>` runs `luajit spec/oracle_diff.lua <args>` from
`magium.koplugin/` (oracle live for the duration, though the render step doesn't
need it). The second line runs `node reference/tools/oracle-diff.js diff <a> <b>`.
Expected: **`6/6 match`**. Any `DIFF` line names the exact JSON path — fix the
engine module it points to (paragraph text → `scene.lua`/`parser.lua`; stat-check
text → `locale.lua`/`stats.lua`/`scene.lua` key→label swap; choice set-vars →
`parser.lua`; `special: null` → the `json.null` patch). **Do not edit a golden to
match the port.**

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/spec/oracle_diff.lua magium.koplugin/engine/vendor/json.lua
git commit -m "spec/oracle_diff: engine renders match the 6 committed goldens (Task 13)

Adds a json.null sentinel to the vendored rxi/json.lua (2 lines, marked local).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 14: Full chapter-1 fixture set — oracle green on every ch1 branch

**Files:**
- Create: `tools/gen-ch1-cases.js`
- Create: `reference/tools/oracle-cases-ch1.json` (generated, committed)
- Create: `reference/tools/oracle-capture/ch1-*.json` (generated goldens, committed)

**Interfaces:**
- Consumes: `engine` modules via `spec/oracle_diff.lua` (Task 13).
- Produces: an oracle-green diff over every scene in `ch1.magium`, under a spread of relevant variable states.

Reference: spec §11.1 ("a new fixture set covering every branch, `#if`, and `set()` in `ch1.magium`"). ch1 has 12 scenes; the branching var is `v_ch1_intro_feeling` (1/2/3) plus `v_ch1_show_yourself` and a couple of achievement flags.

- [x] **Step 1: Write the case generator**

`tools/gen-ch1-cases.js`:
```js
// Enumerate every ID: in ch1.magium and emit oracle cases: each scene under a
// small matrix of the variables ch1 actually branches on. Output shape matches
// reference/tools/oracle-cases.json.
const fs = require("node:fs");
const path = require("node:path");

const CH1 = path.resolve(__dirname, "..", "..", "magium-dev", "data", "en", "ch1.magium");
const ids = fs.readFileSync(CH1, "utf8")
  .split(/\r?\n/).filter(l => l.startsWith("ID: ")).map(l => l.slice(4));

// ch1 branch variables (from reading ch1.magium — keep this list in sync if the
// upstream file changes). ch1 branches on v_ch1_intro_feeling (1/2/3) and
// v_ch1_show_yourself (1/2/3 — #if == 1/2/3 and != 1/2), and displays three
// achievements (v_ac_ch1_coward / v_ac_ch1_die / v_ac_ch1_honesty).
const MATRIX = [
  {},                                        // all unset (0) — covers the != branches
  { v_ch1_intro_feeling: "1" },
  { v_ch1_intro_feeling: "2" },
  { v_ch1_intro_feeling: "3" },
  { v_ch1_show_yourself: "1" },               // #if(v_ch1_show_yourself == 1) ×5
  { v_ch1_show_yourself: "2", v_ac_ch1_coward: "1" },
  { v_ch1_show_yourself: "3" },
  { v_ac_ch1_coward: "1", v_ac_ch1_die: "1", v_ac_ch1_honesty: "1" },  // all achievement displays
];

const cases = [];
for (const id of ids) {
  MATRIX.forEach((vars, i) => {
    cases.push({
      name: `ch1-${id.replace(/[^A-Za-z0-9]+/g, "_")}-m${i}`,
      sceneId: id,
      vars,
    });
  });
}
fs.writeFileSync(
  path.resolve(__dirname, "..", "reference", "tools", "oracle-cases-ch1.json"),
  JSON.stringify(cases, null, 2) + "\n"
);
console.log(`${cases.length} cases for ${ids.length} ch1 scenes`);
```

- [x] **Step 2: Generate cases and capture goldens**

```bash
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh with-oracle node tools/gen-ch1-cases.js'
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh diff capture --cases reference/tools/oracle-cases-ch1.json --out reference/tools/oracle-capture'
```
(`gen-ch1-cases.js` doesn't need the oracle, but `mgm.sh with-oracle <cmd>` is a
convenient no-op wrapper. `mgm.sh diff <args>` starts the oracle, runs
`node reference/tools/oracle-diff.js <args>`, tears it down.)
`gen-ch1-cases.js` prints e.g. `96 cases for 12 ch1 scenes` (8 matrix rows × 12 scenes).

- [x] **Step 3: Run the port and diff the full ch1 set**

```bash
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh oracle-diff-lua ../reference/tools/oracle-cases-ch1.json spec/out/ch1'
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh diff diff reference/tools/oracle-capture magium.koplugin/spec/out/ch1'
```
`oracle-diff.js diff <dir_a> <dir_b>` compares pairwise by **common** filename.
`spec/out/ch1/` holds only the generated ch1 cases, so the count is **the number
of generated cases** (e.g. `96/96`) — the 6 hand goldens live only in
`oracle-capture/` and are validated by Task 13 + re-checked in Task 21. If any
`DIFF`: it names the exact JSON path — **fix the engine, never a golden.** A
per-branch divergence here (that the 6 goldens didn't catch) is a real bug.

- [x] **Step 4: Add a busted wrapper so the diff runs in CI-style**

Append to `magium.koplugin/spec/engine/scene_spec.lua` an offline structural
check: render each committed ch1 case and compare the port-owned fields to the
committed golden **without** a live oracle. Compares `scene_id`, `checkpoint`,
`paragraphs` (concat), and per-choice `target` / `special` / `set_variables`
(deep) + `achievements`. It does **not** raw-compare `statChecks[].text` or
`header` — the live differ re-normalizes both sides for those, so an offline
equality there could false-fail; the live oracle diff (Step 3) is the gate for
them. A referenced golden that fails to resolve makes the test **fail**
(`assert.are.equal(#cases, found)`), never silently skip.

```lua
describe("scene.render — oracle parity (offline goldens)", function()
  -- Renders the committed ch1 cases and structurally compares to the committed
  -- goldens WITHOUT a live oracle (pure offline check). Requires the goldens
  -- captured by Task 14.
  local json = require("engine/vendor/json")
  local parser = require("engine/parser")
  local Locale = require("engine/locale")
  local sc = require("engine/scene")

  local function read(p) local f = io.open(p, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s end

  -- string->string map equality, both directions.
  local function same_map(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
  end

  it("matches every committed ch1 golden", function()
    local cases_raw = read("../reference/tools/oracle-cases-ch1.json")
    if not cases_raw then pending("run Task 14 to generate ch1 fixtures"); return end
    local cases = json.decode(cases_raw)
    local scenes = parser.parse("./data/en/ch1.magium")
    local loc = Locale.load("./data", "en")
    local mismatches = {}
    local found = 0
    for _, case in ipairs(cases) do
      local golden_raw = read("../reference/tools/oracle-capture/" .. case.name .. ".json")
      if golden_raw then
        found = found + 1
        local view = {}
        for k, v in pairs(case.vars or {}) do view[k] = v end
        view.v_current_scene = case.sceneId
        local rm = sc.render(scenes[case.sceneId], view, loc)
        local golden = json.decode(golden_raw)

        if rm.scene_id ~= golden.sceneId then
          mismatches[#mismatches + 1] = case.name .. " sceneId"
        end
        if rm.checkpoint ~= golden.checkpoint then
          mismatches[#mismatches + 1] = case.name .. " checkpoint"
        end
        -- scene.lua and the oracle normalize prose identically for ch1 (the live
        -- 96/96 pass proves it) — safe to compare text here. NOT statChecks/header
        -- text: the live differ re-normalizes both sides for those.
        if table.concat(rm.paragraphs, "\1") ~= table.concat(golden.paragraphs, "\1") then
          mismatches[#mismatches + 1] = case.name .. " paragraphs"
        end

        if #rm.choices ~= #golden.choices then
          mismatches[#mismatches + 1] = case.name .. " choice count"
        else
          for i = 1, #rm.choices do
            local rc, gc = rm.choices[i], golden.choices[i]
            if rc.target ~= gc.target then
              mismatches[#mismatches + 1] = case.name .. " choices[" .. i .. "].target"
            end
            -- golden JSON null decodes to an absent key; normalize both sides.
            if (rc.special or json.null) ~= (gc.special or json.null) then
              mismatches[#mismatches + 1] = case.name .. " choices[" .. i .. "].special"
            end
            if not same_map(rc.set_variables or {}, gc.setVariables or {}) then
              mismatches[#mismatches + 1] = case.name .. " choices[" .. i .. "].setVariables"
            end
          end
        end

        if #rm.achievements ~= #golden.achievements then
          mismatches[#mismatches + 1] = case.name .. " achievement count"
        else
          for i = 1, #rm.achievements do
            local ra, ga = rm.achievements[i], golden.achievements[i]
            if ra.variable ~= ga.variable then
              mismatches[#mismatches + 1] = case.name .. " achievements[" .. i .. "].variable"
            end
            if ra.text ~= ga.text then
              mismatches[#mismatches + 1] = case.name .. " achievements[" .. i .. "].text"
            end
          end
        end
      end
    end
    -- a referenced golden that fails to resolve must FAIL, not silently skip.
    assert.are.equal(#cases, found)
    assert.are.same({}, mismatches)
  end)
end)
```

Also pin the `json.object` marker's behavior in `spec/engine/smoke_spec.lua`
(`json.encode(json.object({})) == "{}"`), since the marker is a local addition
to the vendored `engine/vendor/json.lua` that only the oracle harness exercises.

- [x] **Step 5: Run the full engine spec suite**

```bash
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh test-engine'
```
Expected: all green (the new offline-goldens `it` now runs against the committed ch1 goldens).

- [x] **Step 6: Commit**

```bash
git add tools/gen-ch1-cases.js reference/tools/oracle-cases-ch1.json reference/tools/oracle-capture/ch1-*.json magium.koplugin/spec/engine/scene_spec.lua
git commit -m "ch1 full fixture set: engine matches the oracle on every ch1 branch (Task 14)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 15: `engine/story.lua` — lazy strategy — **DEFERRED (not Phase I)**

**Milestone 0 (Task 6, 2026-08-31)** measured a ~2.2 s device cold parse — over the
~1 s gate. Rather than build the lazy index + per-chapter disk-cache path now, the
owner chose the simpler route: **`eager` with `preload()` deferred to the first
`openReader()` of the session**, behind a `Trapper` progress bar (Task 20). The
~2.2 s hits once per KOReader session, the first time Magium is opened; every
open after that is instant; page turns and choices never parse. Resident heap is
~11.5 MB (spike 03) — a non-issue against ~500 MB free.

**What stays for later:** `engine/story.lua` keeps the `strategy` / `cache_store`
params on `Story.new` and the two erroring stubs (`_build_index` / `_lazy_get`,
`Story._list_magium` / `Story._file_size`). A later phase (VIII — polish, or
sooner if the per-session wait ever grates) implements the lazy path against this
seam and backs `cache_store` with KOReader `Persist`. The `spec/support/mem_cache.lua`
fake and `story_lazy_spec.lua` come with it then. Spec §7.2 carries the design.

No work in this task. Proceed to Task 16.

---

## Task 16: `ui/pagination.lua`

**Files:**
- Create: `magium.koplugin/ui/pagination.lua`
- Create: `magium.koplugin/spec/support/fake_measure.lua`
- Test: `magium.koplugin/spec/ui/pagination_spec.lua`

**Interfaces:**
- Produces: `local pagination = require("ui/pagination")`:
  - `pagination.paginate(render_model, geometry, measure_fn) -> pages` where
    - `geometry = { width, prose_height, first_page_offset }` (px)
    - `measure_fn(text, width) -> height_px`
    - `pages` = array; each `{ kind = "prose", blocks = { {type="banner"|"stat_check"|"prose", text=...}, ... } }` or the single trailing `{ kind = "choices", buttons = { {label, target, set_vars, special}, ... } }`
  - Prose is split by `<br/><br/>` into blocks, greedily packed. Page 1 subtracts `first_page_offset` (banner + stat-check lines) from `prose_height`.
  - A scene with zero surviving paragraphs → just the choices page.

Reference: spec §8.2. **Pure** — no KOReader. `measure_fn` is the only side-channel.

- [ ] **Step 1: Write the fake measurer + failing test**

`magium.koplugin/spec/support/fake_measure.lua`:
```lua
-- Deterministic stand-in for a TextBoxWidget-backed measurer: 20px per wrapped
-- line, ~40 chars per line at the test width.
return function(text, width)
  local chars_per_line = math.max(1, math.floor(width / 10))
  local lines = 0
  for para in (text .. "\n"):gmatch("(.-)\n") do
    lines = lines + math.max(1, math.ceil(#para / chars_per_line))
  end
  return lines * 20
end
```

`magium.koplugin/spec/ui/pagination_spec.lua`:
```lua
require("spec/spec_helper")
local pagination = require("ui/pagination")
local measure = require("spec/support/fake_measure")

local GEO = { width = 400, prose_height = 200, first_page_offset = 0 }

describe("paginate", function()
  it("one short paragraph -> one prose page + one choices page", function()
    local rm = {
      paragraphs = { "Short line." },
      stat_checks = {}, checkpoint = false,
      choices = { { text = "Go", target = "S2", set_variables = {}, special = nil } },
    }
    local pages = pagination.paginate(rm, GEO, measure)
    assert.are.equal(2, #pages)
    assert.are.equal("prose", pages[1].kind)
    assert.are.equal("choices", pages[2].kind)
    assert.are.equal("Go", pages[2].buttons[1].label)
  end)

  it("overflows long prose across multiple pages", function()
    local big = string.rep("word ", 400)   -- ~2000 chars -> ~50 lines -> ~1000px
    local rm = {
      paragraphs = { big }, stat_checks = {}, checkpoint = false,
      choices = { { text = "Go", target = "S2", set_variables = {} } },
    }
    local pages = pagination.paginate(rm, GEO, measure)
    assert.is_true(#pages >= 4)             -- >=3 prose + 1 choices
    assert.are.equal("choices", pages[#pages].kind)
  end)

  it("shrinks page 1 by first_page_offset", function()
    local rm = {
      paragraphs = { "A", "B", "C", "D" }, stat_checks = {}, checkpoint = false,
      choices = { { text = "Go", target = "S", set_variables = {} } },
    }
    local wide = pagination.paginate(rm, { width = 400, prose_height = 200, first_page_offset = 0 }, measure)
    local narrow = pagination.paginate(rm, { width = 400, prose_height = 200, first_page_offset = 160 }, measure)
    assert.is_true(#narrow >= #wide)
  end)

  it("choices-only scene -> a single choices page", function()
    local rm = {
      paragraphs = {}, stat_checks = {}, checkpoint = false,
      choices = { { text = "Continue", target = "S2", set_variables = {} } },
    }
    local pages = pagination.paginate(rm, GEO, measure)
    assert.are.equal(1, #pages)
    assert.are.equal("choices", pages[1].kind)
  end)

  it("puts banner + stat checks as blocks on page 1 only", function()
    local rm = {
      paragraphs = { "P1", "P2" },
      stat_checks = { { success = true, text = "[ Observation check successful - level 3 ]" } },
      checkpoint = true,
      choices = { { text = "Go", target = "S", set_variables = {} } },
    }
    local pages = pagination.paginate(rm, GEO, measure)
    assert.are.equal("banner", pages[1].blocks[1].type)
    assert.are.equal("stat_check", pages[1].blocks[2].type)
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

- [ ] **Step 3: Implement**

`magium.koplugin/ui/pagination.lua`:
```lua
-- ui/pagination.lua — split a render_model into screen-sized pages.
-- PURE: no KOReader. measure_fn is injected (real caller wraps TextBoxWidget).

local M = {}

local function prose_blocks(paragraphs)
  -- Each render_model paragraph is one string with <br/> runs; split into
  -- display blocks on the blank-line marker <br/><br/>, keep single <br/> as \n.
  local blocks = {}
  for _, para in ipairs(paragraphs) do
    for chunk in (para .. "<br/><br/>"):gmatch("(.-)<br/><br/>") do
      local text = chunk:gsub("<br/>", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      if text ~= "" then blocks[#blocks + 1] = text end
    end
  end
  return blocks
end

function M.paginate(render_model, geometry, measure_fn)
  local pages = {}
  local width = geometry.width

  -- page 1 head blocks (banner + stat checks) — rendered once, on page 1.
  local head = {}
  if render_model.checkpoint then
    head[#head + 1] = { type = "banner", text = "checkpoint" }
  end
  for _, sc in ipairs(render_model.stat_checks) do
    head[#head + 1] = { type = "stat_check", text = sc.text, success = sc.success }
  end

  local blocks = prose_blocks(render_model.paragraphs)
  local i = 1
  local first = true
  while i <= #blocks do
    local budget = geometry.prose_height - (first and geometry.first_page_offset or 0)
    local page = { kind = "prose", blocks = {} }
    if first then
      for _, h in ipairs(head) do page.blocks[#page.blocks + 1] = h end
    end
    local used = 0
    local placed_any = false
    while i <= #blocks do
      local h = measure_fn(blocks[i], width)
      if used + h > budget and placed_any then break end
      page.blocks[#page.blocks + 1] = { type = "prose", text = blocks[i] }
      used = used + h
      placed_any = true
      i = i + 1
    end
    pages[#pages + 1] = page
    first = false
  end

  -- if there was no prose at all but there are head blocks, still show page 1.
  if #pages == 0 and #head > 0 then
    pages[1] = { kind = "prose", blocks = head }
  end

  -- the trailing choices page (always present in Phase I — every scene has choices).
  local buttons = {}
  for _, c in ipairs(render_model.choices) do
    buttons[#buttons + 1] = {
      label = c.text, target = c.target,
      set_vars = c.set_variables, special = c.special,
    }
  end
  pages[#pages + 1] = { kind = "choices", buttons = buttons }

  return pages
end

return M
```

- [ ] **Step 4: Run it, verify it passes**

```bash
wsl bash -lc 'cd .../magium.koplugin && busted spec/ui/pagination_spec.lua'
```

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/ui/pagination.lua magium.koplugin/spec/support/fake_measure.lua magium.koplugin/spec/ui/pagination_spec.lua
git commit -m "ui/pagination: pure page-chunking with injected measurer (Task 16)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 17: `ui/reader.lua` + `ui/refresh.lua` — the paginated widget (prose pages)

**Files:**
- Create: `magium.koplugin/ui/refresh.lua`
- Create: `magium.koplugin/ui/reader.lua`
- Verification: manual, in the `kodev` emulator.

**Interfaces:**
- Consumes: `require("ui/pagination")`; KOReader `InputContainer`, `FrameContainer`, `VerticalGroup`, `TextBoxWidget`, `TextWidget`, `Font`, `Size`, `Screen`, `UIManager`, `Geom`, `Device`.
- Produces: `local Reader = require("ui/reader")`:
  - `Reader:new{ render_model = <rm>, locale = <locale>, on_choice = function(button) end, on_close = function() end } -> widget`
  - Internally builds `geometry` from `Screen` + the chosen `Font` face, calls `pagination.paginate`, renders page 1, binds page-turn (tap zones + `PgFwd`/`PgBack`) and `Back`→`on_close`.
  - `widget:show_choices()` is called when paging past the last prose page (Task 18 wires the choice widget in; for Task 17 the choices page renders the labels as plain disabled rows).

Reference: spec §8; [`03` §3](../../research/03-koreader-platform.md#3-ui-toolkit-inventory-23) (`TextBoxWidget`, `covers_fullscreen`); [spike 04 `main.lua`](../../spikes/04-ui-plugin-skeleton/magium_spike.koplugin/main.lua) for the registration/`UIManager:show` pattern only (not the widget — that spike used `TextViewer`, which is rejected).

- [ ] **Step 1: Write `ui/refresh.lua`**

`magium.koplugin/ui/refresh.lua`:
```lua
-- ui/refresh.lua — e-ink refresh-type policy (spec §8.3). Phase I: conservative.
-- OQ-007 tuning (Phase VIII) edits only this file.
local M = { _scene_count = 0, DEGHOST_EVERY = 6 }

function M.on_open() return "full" end
function M.on_page_turn() return "ui" end
function M.on_new_scene()
  M._scene_count = M._scene_count + 1
  if M._scene_count % M.DEGHOST_EVERY == 0 then return "full" end
  return "ui"
end
function M.on_modal() return "flashui" end

return M
```

- [ ] **Step 2: Write `ui/reader.lua`**

`magium.koplugin/ui/reader.lua`:
```lua
-- ui/reader.lua — custom fullscreen paginated reading widget (spec §8, OQ-013).
-- Not TextViewer: a bespoke fullscreen FrameContainer with real pagination.

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen
local pagination = require("ui/pagination")
local refresh = require("ui/refresh")

local Reader = InputContainer:extend{
  render_model = nil,
  locale = nil,
  on_choice = nil,   -- function(button)
  on_close = nil,    -- function()
  covers_fullscreen = true,
  page_idx = 1,
}

local PROSE_FACE = "cfont"
local PROSE_SIZE = 20
local HEAD_FACE = "tfont"

function Reader:init()
  self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
  self.pad = Size.padding.large
  self.text_width = self.dimen.w - 2 * self.pad
  self.face = Font:getFace(PROSE_FACE, PROSE_SIZE)

  if Device:hasKeys() then
    self.key_events = {
      NextPage = { { Device.input.group.PgFwd } },
      PrevPage = { { Device.input.group.PgBack } },
      Close = { { Device.input.group.Back } },
    }
  end
  self.ges_events = {
    TapForward = { GestureRange:new{ ges = "tap", range = self:_zone("right") } },
    TapBackward = { GestureRange:new{ ges = "tap", range = self:_zone("left") } },
  }

  local header_h = self:_header_height()
  local indicator_h = self:_indicator_height()
  self.geometry = {
    width = self.text_width,
    prose_height = self.dimen.h - header_h - indicator_h - 2 * self.pad,
    first_page_offset = self:_head_offset(),
  }
  self.pages = pagination.paginate(self.render_model, self.geometry, function(text, w)
    local tb = TextBoxWidget:new{ text = text, face = self.face, width = w }
    local h = tb:getSize().h
    tb:free()
    return h
  end)
  self.page_idx = 1
  self:_render()
  UIManager:setDirty(self, refresh.on_open())
end

-- (helper methods _zone, _header_height, _indicator_height, _head_offset,
--  _render, _build_page, _build_header, _build_indicator — full bodies below)

function Reader:_zone(side)
  local w = self.dimen.w
  return Geom:new{
    x = side == "left" and 0 or w * 0.5, y = 0,
    w = w * 0.5, h = self.dimen.h,
  }
end

function Reader:_header_height()
  local hw = TextWidget:new{ text = "Ag", face = Font:getFace(HEAD_FACE, 18) }
  local h = hw:getSize().h + Size.padding.default
  hw:free()
  return h
end

function Reader:_indicator_height()
  local iw = TextWidget:new{ text = "1 / 1", face = Font:getFace("ffont", 14) }
  local h = iw:getSize().h + Size.padding.default
  iw:free()
  return h
end

function Reader:_head_offset()
  -- rough px for banner + stat-check lines on page 1
  local n = (self.render_model.checkpoint and 1 or 0) + #self.render_model.stat_checks
  if n == 0 then return 0 end
  return n * (self.face:getHeight() + Size.padding.small) + Size.padding.default
end

function Reader:_build_header()
  return TextWidget:new{
    text = self.render_model.header or "",
    face = Font:getFace(HEAD_FACE, 18),
    max_width = self.text_width,
  }
end

function Reader:_build_indicator()
  local total = #self.pages
  local page = self.pages[self.page_idx]
  local label = page.kind == "choices" and "choices" or (self.page_idx .. " / " .. (total - 1))
  return TextWidget:new{ text = label, face = Font:getFace("ffont", 14) }
end

function Reader:_build_page()
  local vg = VerticalGroup:new{ align = "left" }
  local page = self.pages[self.page_idx]
  if page.kind == "choices" then
    for _, b in ipairs(page.buttons) do
      table.insert(vg, TextWidget:new{
        text = "> " .. b.label, face = self.face, max_width = self.text_width,
      })
      table.insert(vg, VerticalSpan:new{ width = Size.padding.default })
    end
  else
    for _, blk in ipairs(page.blocks) do
      if blk.type == "banner" then
        table.insert(vg, TextWidget:new{
          text = self.locale:str("mainCheckpointReachedText") or "[ Checkpoint reached: Game saved. ]",
          face = Font:getFace(HEAD_FACE, 16),
        })
      elseif blk.type == "stat_check" then
        table.insert(vg, TextWidget:new{ text = blk.text, face = Font:getFace(HEAD_FACE, 16) })
      else
        table.insert(vg, TextBoxWidget:new{
          text = blk.text, face = self.face, width = self.text_width,
          alignment = "left",
        })
      end
      table.insert(vg, VerticalSpan:new{ width = Size.padding.default })
    end
  end
  return vg
end

function Reader:_render()
  self[1] = FrameContainer:new{
    background = Blitbuffer.COLOR_WHITE,
    bordersize = 0,
    padding = self.pad,
    width = self.dimen.w,
    height = self.dimen.h,
    VerticalGroup:new{
      align = "left",
      self:_build_header(),
      VerticalSpan:new{ width = Size.padding.large },
      self:_build_page(),
      VerticalSpan:new{ width = Size.padding.large },
      self:_build_indicator(),
    },
  }
end

function Reader:_turn(delta)
  local next_idx = self.page_idx + delta
  if next_idx < 1 or next_idx > #self.pages then return end
  self.page_idx = next_idx
  self:_render()
  UIManager:setDirty(self, refresh.on_page_turn())
end

function Reader:onNextPage() self:_turn(1); return true end
function Reader:onPrevPage() self:_turn(-1); return true end
function Reader:onTapForward() self:_turn(1); return true end
function Reader:onTapBackward() self:_turn(-1); return true end

function Reader:onClose()
  if self.on_close then self.on_close() end
  UIManager:close(self)
  return true
end

-- Task 18 overrides this to open the real choice widget / commit a choice.
function Reader:onChoiceSelected(button)
  if self.on_choice then self.on_choice(button) end
  return true
end

return Reader
```

Note: `GestureRange` is `require("ui/gesturerange")` — add that require at the top. The helper-method comment lists them; ensure every referenced method has a body (they do, above).

- [ ] **Step 3: Wire a temporary launch path and verify in the emulator**

Temporarily extend the Task 6 `main.lua` menu with a second item that opens the reader on `Ch1-Intro1` (remove in Task 20):
```lua
-- add inside addToMainMenu, alongside the timing item:
menu_items.magium_read = {
  text = _("Magium: read ch1 intro"),
  sorting_hint = "more_tools",
  callback = function()
    local Story = require("engine/story")
    local Locale = require("engine/locale")
    local scenemod = require("engine/scene")
    local Reader = require("ui/reader")
    local story = Story.new{ data_dir = self.path .. "/data", locale = "en", strategy = "eager" }:preload()
    local loc = Locale.load(self.path .. "/data", "en")
    local rm = scenemod.render(story:get_scene("Ch1-Intro1"), {}, loc)
    UIManager:show(Reader:new{ render_model = rm, locale = loc,
      on_close = function() end,
      on_choice = function(b) require("logger").info("choice:", b.label) end })
  end,
}
```

```bash
wsl bash -lc 'cd ~/koreader && xvfb-run -a ./kodev run --simulate=kindle-paperwhite --no-build'
```
In the emulator: menu → "Magium: read ch1 intro". **Verify:**
- Full-screen (no dialog frame, no close button), header reads "Book 1 - Chapter 1".
- The intro prose renders, wrapped, left-aligned.
- Tap right / PgFwd advances pages; the indicator updates `1 / N` … then `choices`.
- The choices page lists `> Excited`, `> Calm`, `> Afraid`.
- `Back` closes to the file manager.
- `grep -i "magium\|error\|traceback" ~/koreader/koreader/crash.log | tail` — no Lua errors.

Take a screenshot (`Screen:shot()` via the emulator's screenshot key, or `import -window root`) and save to `docs/spikes/06-ondevice-parse-timing/reader-ch1.png` for the record.

- [ ] **Step 4: If the emulator run reveals layout bugs, fix `reader.lua`**

Common fixes: `TextBoxWidget` needs `height` too if it must clip; `VerticalGroup` overflow → reduce `PROSE_SIZE` or increase `first_page_offset`. Iterate against the emulator until the four checks in Step 3 pass.

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/ui/reader.lua magium.koplugin/ui/refresh.lua magium.koplugin/main.lua docs/spikes/06-ondevice-parse-timing/reader-ch1.png
git commit -m "ui/reader: fullscreen paginated widget, prose pages + page turns (Task 17)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 18: `ui/choices.lua` + choice → next scene wiring

**Files:**
- Create: `magium.koplugin/ui/choices.lua`
- Modify: `magium.koplugin/ui/reader.lua` (render the choices page with `ButtonTable`, add `set_engine`/`advance`)
- Verification: manual, in the `kodev` emulator.

**Interfaces:**
- Consumes: KOReader `ButtonTable`; `require("engine/scene")`, `require("engine/store")`.
- Produces:
  - `local Choices = require("ui/choices")` — `Choices.build{ buttons = {...}, width = w, on_select = function(button) end } -> ButtonTable widget`.
  - `Reader:new{ ..., advance = function(button) -> new_render_model end }` — when a choice is tapped, `reader` calls `advance(button)` and rebuilds itself with the returned render_model at page 1.

Reference: spec §8.1 (choice commit sequence: apply `set_vars` → set `v_current_scene` → dispatch `special` → re-render); `03` §3 (`ButtonTable`); C6 (navigate by `v_current_scene`).

- [ ] **Step 1: Write `ui/choices.lua`**

`magium.koplugin/ui/choices.lua`:
```lua
-- ui/choices.lua — the choice list, rendered as the reader's final page.
local ButtonTable = require("ui/widget/buttontable")

local M = {}

function M.build(opts)
  local rows = {}
  for _, b in ipairs(opts.buttons) do
    rows[#rows + 1] = { {
      text = b.label,
      align = "left",
      callback = function() opts.on_select(b) end,
    } }
  end
  return ButtonTable:new{
    width = opts.width,
    buttons = rows,
    show_parent = opts.show_parent,
  }
end

return M
```

- [ ] **Step 2: Wire choices into `reader.lua`**

In `magium.koplugin/ui/reader.lua`:
- add `require("ui/choices")` at the top;
- in `_build_page`, replace the `page.kind == "choices"` branch with:
```lua
  if page.kind == "choices" then
    return require("ui/choices").build{
      buttons = page.buttons,
      width = self.text_width,
      show_parent = self,
      on_select = function(button) self:_commit_choice(button) end,
    }
  end
```
- add:
```lua
function Reader:_commit_choice(button)
  if self.advance then
    local rm = self.advance(button)
    if rm then
      self.render_model = rm
      self.pages = pagination.paginate(rm, self.geometry, function(text, w)
        local tb = TextBoxWidget:new{ text = text, face = self.face, width = w }
        local h = tb:getSize().h; tb:free(); return h
      end)
      self.page_idx = 1
      self:_render()
      UIManager:setDirty(self, refresh.on_new_scene())
    end
  end
end
```

- [ ] **Step 3: Wire the engine advance in the temporary `main.lua`**

Replace the temporary `magium_read` callback's `Reader:new{...}` with one that holds a `Store` and provides `advance`:
```lua
callback = function()
  local Story = require("engine/story")
  local Locale = require("engine/locale")
  local scenemod = require("engine/scene")
  local Store = require("engine/store")
  local Reader = require("ui/reader")
  local specials = require("engine/specials")

  local story = Story.new{ data_dir = self.path .. "/data", locale = "en", strategy = "eager" }:preload()
  local loc = Locale.load(self.path .. "/data", "en")
  local store = Store.new()
  store:set("v_current_scene", specials.DEFAULT_SCENE)

  local function render_current()
    local id = store:get("v_current_scene")
    return scenemod.render(story:get_scene(id), store:view(), loc)
  end

  local reader
  reader = Reader:new{
    render_model = render_current(),
    locale = loc,
    on_close = function() end,
    advance = function(button)
      for k, v in pairs(button.set_vars) do store:set(k, v) end
      -- v_current_scene is among set_vars for a normal choice (C6); special: only
      -- 'restart' is wired in Phase I.
      if button.special == "restart" then
        store:restore({}); store:set("v_current_scene", specials.DEFAULT_SCENE)
      end
      return render_current()
    end,
  }
  UIManager:show(reader)
end,
```

- [ ] **Step 4: Verify a full ch1 playthrough in the emulator**

```bash
wsl bash -lc 'cd ~/koreader && xvfb-run -a ./kodev run --simulate=kindle-paperwhite --no-build'
```
Menu → "Magium: read ch1 intro". **Play chapter 1 to its end:**
- On the choices page, tap `Excited` → the next scene (`Ch1-Intro2`) renders at page 1 with the "excited" prose branch.
- Continue through every scene to the end of ch1 (the last scene's choice diverts to `Ch2-...` — eager has the whole corpus loaded, so that scene renders; no crash).
- `grep -i "error\|traceback\|magium" ~/koreader/koreader/crash.log | tail -20` — clean.

Screenshot the `Ch1-Intro2` excited branch → `docs/spikes/06-ondevice-parse-timing/reader-ch1-branch.png`.

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/ui/choices.lua magium.koplugin/ui/reader.lua magium.koplugin/main.lua docs/spikes/06-ondevice-parse-timing/reader-ch1-branch.png
git commit -m "ui/choices + reader: choices-as-final-page, choice -> next scene (Task 18)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 19: `save/manager.lua` — debounced autosave + resume

**Files:**
- Create: `magium.koplugin/save/manager.lua`
- Create: `magium.koplugin/spec/support/fake_writer.lua`
- Test: `magium.koplugin/spec/save/manager_spec.lua`

**Interfaces:**
- Consumes: `require("engine/store")`; an injected `writer` = `{ read() -> table|nil, write(table) }` and an injected `schedule(delay, fn) -> handle` / `unschedule(handle)` (real caller passes `UIManager:scheduleIn` / `UIManager:unschedule`).
- Produces: `local SaveManager = require("save/manager")`:
  - `SaveManager.new{ store = <store>, writer = <writer>, schedule = <fn>, unschedule = <fn>, debounce = 5 } -> mgr`
  - `mgr:load()` — reads `currentState` + `achievements` from the writer into the store; returns the resumed `v_current_scene` or `nil`.
  - `mgr:touch()` — call after any store mutation from a choice; (re)arms the debounce timer.
  - `mgr:flush_now(reason)` — write immediately (close / suspend / checkpoint).
  - `mgr:on_achievement_unlocked()` — immediate flush of just the `v_ac_*` slice.

Reference: spec §9; F-20. **`currentState` = the store's non-`v_ac_*` keys; `achievements` = the `v_ac_*` keys.** Never write per-`touch()` — only when the timer fires or `flush_now`.

- [ ] **Step 1: Write the fake writer + failing test**

`magium.koplugin/spec/support/fake_writer.lua`:
```lua
local FakeWriter = {}
FakeWriter.__index = FakeWriter
function FakeWriter.new(seed)
  return setmetatable({ data = seed or {}, writes = 0 }, FakeWriter)
end
function FakeWriter:read() return self.data end
function FakeWriter:write(t)
  self.writes = self.writes + 1
  self.data = {}
  for k, v in pairs(t) do self.data[k] = v end
end
return FakeWriter
```

`magium.koplugin/spec/save/manager_spec.lua`:
```lua
require("spec/spec_helper")
local Store = require("engine/store")
local SaveManager = require("save/manager")
local FakeWriter = require("spec/support/fake_writer")

-- a controllable scheduler
local function make_sched()
  local pending = {}
  return {
    schedule = function(delay, fn) pending[#pending + 1] = fn; return #pending end,
    unschedule = function(h) pending[h] = nil end,
    fire_all = function() for _, fn in pairs(pending) do fn() end; pending = {} end,
    count = function() local n = 0 for _ in pairs(pending) do n = n + 1 end return n end,
  }
end

describe("SaveManager", function()
  it("touch() does not write until the timer fires", function()
    local store = Store.new({ v_current_scene = "Ch1-Intro2", v_x = "1" })
    local w = FakeWriter.new()
    local s = make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:touch()
    mgr:touch()
    assert.are.equal(0, w.writes)
    s.fire_all()
    assert.are.equal(1, w.writes)
    assert.are.equal("Ch1-Intro2", w.data.currentState.v_current_scene)
  end)

  it("separates v_ac_* into the achievements blob", function()
    local store = Store.new({ v_x = "1", v_ac_ch1_coward = "1" })
    local w = FakeWriter.new()
    local s = make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:flush_now("test")
    assert.is_nil(w.data.currentState.v_ac_ch1_coward)
    assert.are.equal("1", w.data.achievements.v_ac_ch1_coward)
    assert.are.equal("1", w.data.currentState.v_x)
  end)

  it("re-arming the timer replaces the previous one", function()
    local store = Store.new({ v_a = "1" })
    local w, s = FakeWriter.new(), make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:touch(); mgr:touch(); mgr:touch()
    assert.are.equal(1, s.count())
  end)

  it("load() restores the store and returns the resume scene", function()
    local w = FakeWriter.new({
      currentState = { v_current_scene = "Ch1-Cutthroat Dave", v_ch1_show_yourself = "2" },
      achievements = { v_ac_ch1_coward = "1" },
    })
    local store = Store.new()
    local s = make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    local resume = mgr:load()
    assert.are.equal("Ch1-Cutthroat Dave", resume)
    assert.are.equal("2", store:get("v_ch1_show_yourself"))
    assert.are.equal("1", store:get("v_ac_ch1_coward"))
  end)

  it("on_achievement_unlocked flushes immediately", function()
    local store = Store.new({ v_ac_x = "1" })
    local w, s = FakeWriter.new(), make_sched()
    local mgr = SaveManager.new{ store = store, writer = w,
      schedule = s.schedule, unschedule = s.unschedule, debounce = 5 }
    mgr:on_achievement_unlocked()
    assert.are.equal(1, w.writes)
    assert.are.equal("1", w.data.achievements.v_ac_x)
  end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

- [ ] **Step 3: Implement**

`magium.koplugin/save/manager.lua`:
```lua
-- save/manager.lua — Phase I: currentState autosave (debounced) + achievements
-- + resume. Checkpoint blob and the 50 manual slots are Phase III.
-- The file I/O + scheduler are injected so the logic is testable without KOReader.

local SaveManager = {}
SaveManager.__index = SaveManager

local function is_ac(k) return k:sub(1, 5) == "v_ac_" end

function SaveManager.new(opts)
  local self = setmetatable({}, SaveManager)
  self.store = assert(opts.store)
  self.writer = assert(opts.writer)
  self.schedule = assert(opts.schedule)
  self.unschedule = assert(opts.unschedule)
  self.debounce = opts.debounce or 5
  self._timer = nil
  return self
end

function SaveManager:_split()
  local current, ach = {}, {}
  for k, v in pairs(self.store:snapshot()) do
    if is_ac(k) then ach[k] = v else current[k] = v end
  end
  return current, ach
end

function SaveManager:_write(reason)
  local current, ach = self:_split()
  local existing = self.writer:read() or {}
  self.writer:write({
    currentState = current,
    achievements = ach,
    checkpoint = existing.checkpoint,   -- preserved untouched in Phase I
    slots = existing.slots,
  })
end

function SaveManager:load()
  local data = self.writer:read() or {}
  local merged = {}
  for k, v in pairs(data.currentState or {}) do merged[k] = v end
  for k, v in pairs(data.achievements or {}) do merged[k] = v end
  self.store:restore(merged)
  return self.store:get("v_current_scene")
end

function SaveManager:touch()
  if self._timer then self.unschedule(self._timer) end
  self._timer = self.schedule(self.debounce, function()
    self._timer = nil
    self:_write("debounce")
  end)
end

function SaveManager:flush_now(reason)
  if self._timer then self.unschedule(self._timer); self._timer = nil end
  self:_write(reason or "flush")
end

function SaveManager:on_achievement_unlocked()
  -- achievements are rare; flush the whole blob immediately.
  self:_write("achievement")
end

return SaveManager
```

- [ ] **Step 4: Run it, verify it passes**

```bash
wsl bash -lc 'cd .../magium.koplugin && busted spec/save/manager_spec.lua'
```

- [ ] **Step 5: Commit**

```bash
git add magium.koplugin/save/manager.lua magium.koplugin/spec/support/fake_writer.lua magium.koplugin/spec/save/manager_spec.lua
git commit -m "save/manager: debounced currentState autosave + achievements + resume (Task 19)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 20: `main.lua` — the real plugin class + wiring

**Files:**
- Rewrite: `magium.koplugin/main.lua` (replace the Task 6 timing harness)
- Verification: manual, in the `kodev` emulator.

**Interfaces:**
- Consumes: all `engine/*`, `ui/reader`, `save/manager`; KOReader `WidgetContainer`, `UIManager`, `Persist`, `DataStorage`, `Dispatcher`, `Trapper`, `logger`.
- Produces: the shipping plugin — menu item + Dispatcher action open the reader; the eager `story:preload()` (~2.2 s) runs on the **first `openReader()`** of the session behind a `Trapper` progress bar (once-guarded — `init()` does no parsing); lifecycle events flush the save.

Reference: spec §6 (glue), §8.1 (choice commit), §9 (flush points), §11.1 (Plugin deliverables); [`03` §1.3, §7](../../research/03-koreader-platform.md) (registration + lifecycle); [spike 04 `main.lua`](../../spikes/04-ui-plugin-skeleton/magium_spike.koplugin/main.lua) (boilerplate shape).

- [ ] **Step 1: Write `main.lua`**

`magium.koplugin/main.lua`:
```lua
--[[--
Magium — play the text CYOA game inside KOReader. Phase I: chapter 1 playable,
autosave/resume. Later phases add saves UI, stats, achievements, i18n.
--]]--

local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local Persist = require("persist")
local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local _ = require("gettext")

local Story = require("engine/story")
local Locale = require("engine/locale")
local scene = require("engine/scene")
local Store = require("engine/store")
local specials = require("engine/specials")
local Reader = require("ui/reader")
local SaveManager = require("save/manager")

-- Milestone 0 (Task 6, 2026-08-31): device cold parse ≈ 2.2 s. Over the ~1 s
-- gate — but the owner chose `eager` with the parse **deferred to the first
-- reader-open** (a Trapper progress bar covers the ~2.2 s once per session)
-- rather than build the lazy/disk-cache path now. See spec §7 + spike 06.
local PARSE_STRATEGY = "eager"

local Magium = WidgetContainer:extend{ name = "magium", is_doc_only = false }

-- ---- persistence adapters (the KOReader-specific edges) -----------------------

local function save_dir()
  local d = DataStorage:getDataDir() .. "/magium"
  lfs.mkdir(d)
  return d
end

local function state_writer()
  local path = save_dir() .. "/state"
  local p = Persist:new{ path = path, codec = "luajit" }
  return {
    read = function() return p:load() end,
    write = function(t) p:save(t) end,
  }
end

-- (Milestone 0 chose `eager` + parse-on-first-open, so there is no lazy
--  disk-cache adapter in Phase I. The `cache_store` seam stays on `Story.new`
--  for the deferred lazy path — a later phase backs it with `Persist`.)

-- ---- lifecycle ---------------------------------------------------------------

function Magium:init()
  self:onDispatcherRegisterActions()
  self.ui.menu:registerToMainMenu(self)
  self.data_dir = self.path .. "/data"
  self.locale = Locale.load(self.data_dir, "en")
  self.story = Story.new{ data_dir = self.data_dir, locale = "en", strategy = PARSE_STRATEGY }
  self.store = Store.new()
  self.save = SaveManager.new{
    store = self.store, writer = state_writer(),
    schedule = function(d, fn) UIManager:scheduleIn(d, fn); return fn end,
    unschedule = function(fn) UIManager:unschedule(fn) end,
    debounce = 8,
  }
  -- NOTE: no parse here. init() runs at KOReader startup for every plugin; the
  -- ~2.2 s eager parse happens lazily in openReader() the first time the user
  -- actually opens Magium (Milestone 0 decision).
end

-- Parse all 54 files once, the first time the reader is opened this session,
-- behind a Trapper progress bar. Subsequent opens are instant (story is resident).
function Magium:_ensureLoaded()
  if self._loaded then return end
  Trapper:wrap(function()
    self.story:preload(function(done, total)
      Trapper:info(string.format("%s %d/%d", _("Loading Magium…"), done, total))
    end)
    Trapper:clear()
  end)
  self._loaded = true
end

function Magium:onDispatcherRegisterActions()
  Dispatcher:registerAction("magium_open", {
    category = "none", event = "MagiumOpen", title = _("Magium"), general = true,
  })
end

function Magium:addToMainMenu(menu_items)
  menu_items.magium = {
    text = _("Magium"),
    sorting_hint = "more_tools",
    callback = function() self:openReader() end,
  }
end

function Magium:onMagiumOpen() self:openReader(); return true end

function Magium:openReader()
  self:_ensureLoaded()   -- first open this session: ~2.2 s parse behind a progress bar

  -- resume, or start fresh
  local resume = self.save:load()
  if not resume or not self.story:get_scene(resume) then
    self.store:restore({})
    self.store:set("v_current_scene", specials.DEFAULT_SCENE)
  end

  local function render_current()
    local id = self.store:get("v_current_scene")
    local st = self.story:get_scene(id)
    if not st then
      logger.warn("Magium: unknown scene", id, "— resetting to intro")
      self.store:set("v_current_scene", specials.DEFAULT_SCENE)
      st = self.story:get_scene(specials.DEFAULT_SCENE)
    end
    return scene.render(st, self.store:view(), self.locale)
  end

  self.reader = Reader:new{
    render_model = render_current(),
    locale = self.locale,
    on_close = function() self.save:flush_now("close") end,
    advance = function(button)
      for k, v in pairs(button.set_vars) do self.store:set(k, v) end
      if button.special == "restart" then
        self.store:restore({})
        self.store:set("v_current_scene", specials.DEFAULT_SCENE)
      end
      -- special:saves / :stats / :checkpoint_* are Phase II/III — treat as no-op nav for now
      self.save:touch()
      return render_current()
    end,
  }
  UIManager:show(self.reader)
end

-- flush on suspend / shutdown
function Magium:onSuspend() self.save:flush_now("suspend") end
function Magium:onClose() self.save:flush_now("close-broadcast") end
function Magium:onCloseWidget() self.save:flush_now("close-widget") end

return Magium
```

- [ ] **Step 2: Full-playthrough verification in the emulator**

```bash
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh emu-smoke 40'
```
For an interactive check, deploy + run with a display instead (`mgm.sh emu-deploy` then `mgm.sh emu-run`).
- Menu → More tools → **Magium**. **First open shows a "Loading Magium… N/54" progress bar for ~1–2 s** (x86; ~2.2 s on device), then the reader opens on `Ch1-Intro1` (fresh state). A second open in the same session is instant (story stays resident).
- Play chapter 1 to the end, taking a branch at `Ch1-Intro2`.
- Press `Back` mid-chapter. Reopen **Magium** → it **resumes on the same scene** with the same branch prose (and no second progress bar).
- `mgm.sh emu-log 200 | grep -iE "magium|error|traceback|warn"` — no errors, no `Magium: unknown scene` warnings during normal ch1 play.
- Check the save file exists: `ls -la ~/koreader/koreader-emulator-x86_64-linux-gnu-debug/koreader/magium/` (emulator data dir) → `state` present.

- [ ] **Step 3: Run the whole spec suite**

```bash
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh test'
```
Expected: every spec green (`spec/engine`, `spec/ui`, `spec/save`).

- [ ] **Step 4: Commit**

```bash
git add magium.koplugin/main.lua
git commit -m "main.lua: real plugin class — menu/dispatcher entry, lifecycle, wiring (Task 20)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 21: On-device run + Phase I exit criteria

**Files:**
- Modify: `SUMMARY.md`, `research-plan.md`
- Verification: on the real Kindle Paperwhite 12th gen (owner).

**Interfaces:** none — this task verifies the spec §11.2 exit criteria and records the outcome.

Reference: spec §11.2.

- [ ] **Step 1: Deploy to the device**

Connect the Kindle over USB. Copy the plugin:
```bash
# from Windows: copy the folder magium.koplugin\ into  <Kindle>\koreader\plugins\
# exclude spec/ and cache/ — ship engine/, ui/, save/, data/, main.lua, _meta.lua
```
Eject, restart KOReader on the device (or Tools → Plugin management → enable Magium → restart).

- [ ] **Step 2: Play chapter 1 on-device**

- File manager → ≡ → More tools → **Magium**.
- Play `ch1` start to finish. At `Ch1-Intro2` take each of the three feelings across three runs (use `special:restart` if reachable, or reinstall to reset).
- Every choice reaches its intended next scene.
- Page turns feel acceptable (this is the OQ-007 perceptual check — record the owner's impression; tuning is Phase VIII, not this task).

- [ ] **Step 3: Resume check on-device**

Close mid-chapter (`Back`), relaunch Magium → resumes on the same scene + state.

- [ ] **Step 4: Pull and inspect `crash.log`**

Copy `<Kindle>\koreader\crash.log`. Confirm: no Lua traceback, no `logger.warn`/`err` from `Magium` across the ch1 playthrough + resume.

- [ ] **Step 5: Run the exit-criteria checklist (spec §11.2)**

Confirm each, on the evidence gathered:
- [ ] ch1 plays start→finish on the real Kindle, every choice correct.
- [ ] `oracle_diff` reports 0 diffs across the 6 goldens + the full ch1 set (Task 13/14 — re-run once more).
- [ ] `parser.lua` produces the exact corpus counts, 0 anomalies (Task 4 — re-run).
- [ ] close + reopen resumes on the same scene + variable state.
- [ ] `crash.log` clean across a full ch1 playthrough + a resume.
- [ ] all busted specs pass (`mgm.sh test`).
- [ ] Milestone 0 `FINDING.md` committed; spec §7 result recorded (Task 6 — **done**: 2.2 s → eager-deferred-to-first-open, lazy deferred).

- [ ] **Step 6: Record the outcome**

`SUMMARY.md` — add a finding (next free number — 36 and 37 are already the
Milestone 0 + engine-parity rows added in session 18):
```markdown
| 38 | **Phase I done: Magium chapter 1 plays end-to-end on the Kindle Paperwhite.** Full Lua engine verified against the magium-dev oracle on all 6 goldens + every ch1 branch (N cases, 0 diffs); custom fullscreen paginated reader (OQ-013 resolved in build); eager parse deferred to first open (Milestone 0); debounced autosave + resume. | high | [spec](docs/specs/2026-08-31-plugin-architecture-and-phase-i.md) §11.2; SDD ledger |
```
Update `SUMMARY.md` status line: `Phase I (MVP) complete — ch1 playable on-device.`

`research-plan.md` — append a running-log entry (per CLAUDE.md): what shipped, the Milestone 0 number, what's next (Phase II spec cycle).

- [ ] **Step 7: Commit**

```bash
git add SUMMARY.md research-plan.md docs/spikes/06-ondevice-parse-timing/FINDING.md
git commit -m "Phase I complete: Magium ch1 plays end-to-end on-device (Task 21)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Self-Review

### 1. Spec coverage

| Spec section | Task(s) |
|---|---|
| §2 layering, engine-pure rule | Global Constraints; enforced per task; §3.1 dep rule in Task 1 helper |
| §3.1 `parser.lua` | 2, 3, 4 |
| §3.1 `conditions.lua` | 7 |
| §3.1 `stats.lua` | 9 |
| §3.1 `store.lua` (+N/−N, latch, #12) | 8 |
| §3.1 `scene.lua` (12 steps) | 12 |
| §3.1 `specials.lua` (render-time #1–#4,#6–#8,#12) | 8 (#12), 9 (#6,#7), 11 (#1,#2,#3), 12 (#4 checkpoint), 10 (#8 lock text) |
| §3.1 `locale.lua` | 10 |
| §3.1 `story.lua` eager (+ lazy seam stubbed; lazy impl deferred per Milestone 0) | 5 |
| §3.2 `ui/pagination.lua` | 16 |
| §3.2 `ui/reader.lua` | 17, 18 |
| §3.2 `ui/choices.lua` | 18 |
| §3.2 `ui/refresh.lua` | 17 |
| §3.3 `save/manager.lua` | 19 |
| §4 folder layout + vendored json | 1 |
| §5 data-shape contracts | 4 (scene_table), 12 (render_model), 16 (page) |
| §6 12-step pipeline + parity note | 12 |
| §7 parse-strategy seam | 5, 15 |
| §8 reading widget (OQ-013) | 16, 17, 18 |
| §8.3 refresh policy | 17 |
| §9 save model (4-blob, debounce) | 19 (currentState+achievements; checkpoint/slots explicitly Phase III) |
| §10 Milestone 0 | 6 |
| §11.1 Phase I deliverables | 2–20 |
| §11.2 exit criteria | 21 |
| §11.1 "no title/menu screen in Phase I" | 20 (opens straight to `v_current_scene`) |
| §13 OQ-013 resolved in build | 16–18 |

Gaps deliberately deferred (spec §1.2 / §12, not this plan): stats/saves/achievements screens, full-corpus nav + 13-special-case audit, i18n, e-ink tuning, packaging. Milestone 0 Step 4 and Task 21 need the physical device — flagged as owner checkpoints, not agent-completable.

### 2. Placeholder scan

- No "TBD"/"TODO"/"implement later" in task steps. The one `pending(...)` call in Task 14 Step 4 is a real busted primitive (skips gracefully if Task 14's fixtures aren't generated yet), not a plan placeholder.
- `PARSE_STRATEGY = "eager"` in Task 20 — Milestone 0 measured ≈ 2.2 s cold on the Kindle. Owner chose `eager` with `preload()` deferred to the first `openReader()` (Trapper progress bar) over building the lazy path. **Task 15 is deferred out of Phase I**; the `cache_store` adapter is not built; `story.lua`'s lazy stubs stay (erroring) for a later phase.
- Every code step has a full code block. Every test step has real assertions.
- Task 17's `reader.lua` lists helper methods in a comment then defines every one below it — verified each referenced method (`_zone`, `_header_height`, `_indicator_height`, `_head_offset`, `_build_header`, `_build_indicator`, `_build_page`, `_render`, `_turn`) has a body.

### 3. Type consistency

- `scene_table` fields: `set_variables` (with `_`), `set_vars` on choice tables. Checked: `parser._match_choice` produces `choice.set_vars`; `scene.render` reads `c.set_vars` and `st.set_variables`; `reader.advance` reads `button.set_vars`; `pagination` copies `c.set_variables` from the **render_model** (Task 12 emits `set_variables` on render-model choices) → **INCONSISTENCY FIXED BELOW**.
- `render_model.choices[].set_variables` (Task 12) vs `pagination` reading `c.set_variables` (Task 16) — consistent (both `set_variables`).
- `pagination` page button field is `set_vars` (Task 16: `set_vars = c.set_variables`); `reader._commit_choice`/`main.advance` read `button.set_vars` (Tasks 18, 20) — consistent.
- `Story` interface: `new/preload/get_scene/scene_ids/count` — used consistently in Tasks 5, 6, 13, 15, 20.
- `SaveManager`: `new/load/touch/flush_now/on_achievement_unlocked` — consistent Tasks 19, 20.
- `conditions.eval` / `conditions.eval_atom` — consistent Tasks 7, 9, 12.
- `locale:header` / `locale:str` / `locale:stat_check_text` — consistent Tasks 10, 12, 17.

**Fix applied:** Task 12's `scene.render` emits render-model choices with key `set_variables` (matching the oracle canonical shape). Task 16 `pagination.paginate` reads `c.set_variables` and emits page buttons with key `set_vars`. Tasks 18/20 read `button.set_vars`. This chain is consistent as written. The parser's internal `choice.set_vars` (Task 3) is a separate layer (scene_table, not render_model) and is only read by `scene.render` — also consistent. No code change needed; the names differ by layer *by design* (scene_table uses `set_vars`, render_model uses `set_variables` to match the oracle). Callers verified against the right layer.

### 4. Ambiguity check

- "short idle timer" → Task 19 makes `debounce` an explicit constructor arg (5 in specs, 8 in `main.lua`).
- Milestone 0 "~1 s" threshold → Task 6 states the rule as a table; the "~" is inherent to the spec and acceptable (the decision is binary and cross-referenced).
- `data_dir` vs `dir`: `Story.new` takes `data_dir` = the parent of `<locale>/`; internally `self.dir = data_dir .. "/" .. locale`. Specs pass `DATA_ROOT = helper.data_dir_en:gsub("/en$","")`. Consistent.
- Emulator invocation: every emulator step uses `xvfb-run -a ./kodev run --simulate=kindle-paperwhite --no-build` from `~/koreader`. If the owner's kodev checkout is elsewhere, adjust the path — noted in the Environment section.

### Fixes applied inline

- Clarified in Task 16/18 interface blocks that the `set_vars` (page button) vs `set_variables` (render_model) naming is intentional per-layer, and callers were checked.
- Task 14 Step 4 offline check compares only port-owned fields (paragraphs, choice count) to avoid coupling the busted spec to the full canonical normalizer (which lives in `oracle-diff.js`); the authoritative full diff is Steps 2–3 against the live oracle.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-31-magium-plugin-milestone-0-phase-i.md`. Two execution options:

**1. Subagent-Driven (recommended)** — a fresh subagent per task, review between tasks, fast iteration. Best fit here: the engine tasks (2–15) are highly independent and each ends green against a spec-defined check.

**2. Inline Execution** — execute tasks in this session with batch checkpoints for review.

Which approach?
