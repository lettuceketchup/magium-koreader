# Spec: Plugin architecture & Phase I (MVP)

- **Status:** in-review
- **Last updated:** 2026-08-31
- **Phase:** Implementation — design cycle 1 (roadmap [Milestone 0](../research/09-roadmap-effort.md#milestone-0--pre-flight-on-device-parse-timing-gate) + [Phase I](../research/09-roadmap-effort.md#phase-i--mvp-engine-core--the-real-reading-widget))
- **Sources:**
  - [`../research/09-roadmap-effort.md`](../research/09-roadmap-effort.md) — the roadmap this spec opens
  - [`../decisions/ADR-002-porting-approach.md`](../decisions/ADR-002-porting-approach.md) — approach (candidate A)
  - [`../decisions/ADR-004-plugin-internal-architecture.md`](../decisions/ADR-004-plugin-internal-architecture.md) — the layering/widget decisions recorded from this spec's brainstorm
  - [`../research/01-magium-analysis.md`](../research/01-magium-analysis.md) — engine semantics being ported
  - [`../research/02-magium-format-spec.md`](../research/02-magium-format-spec.md) — `.magium` grammar + parser risk list (R1–R10)
  - [`../research/03-koreader-platform.md`](../research/03-koreader-platform.md) — widget / persistence / lifecycle / e-ink APIs
  - [`../research/04-constraints-budget.md`](../research/04-constraints-budget.md) §4 — the parse-strategy fork
  - [`../spikes/02-engine-in-lua/`](../spikes/02-engine-in-lua/) — validated engine-port reference (6/6 oracle match)
  - [`../spikes/03-full-corpus-memory-parse/`](../spikes/03-full-corpus-memory-parse/) — ~11.5 MB resident, 112–205 ms desktop parse
  - [`../spikes/04-ui-plugin-skeleton/`](../spikes/04-ui-plugin-skeleton/) — validated plugin/registration shape; `TextViewer` ruled out (OQ-013)
  - `../../../magium-dev` @ `51f5aa9` — `src/parser.js`, `src/utils.js`, `src/renderers.js` (the port target + differential oracle)
  - `../../../koreader` @ `v2026.07.1` (`9192014`) — the platform source
- **Related:** [`../research/07-risks-open-questions.md`](../research/07-risks-open-questions.md) (OQ-001, OQ-007, OQ-011, OQ-013), [`../../SUMMARY.md`](../../SUMMARY.md), [`../../research-plan.md`](../../research-plan.md), [`README.md`](README.md)

> This is the first implementation-design spec. It defines the whole plugin's
> internal architecture (so every later phase has a fixed skeleton to extend) and
> specifies **Milestone 0** and **Phase I** in build-ready detail. Roadmap phases
> II–VIII get an architectural note here and their own spec cycle when reached.
>
> Governing conventions: the research dossier's
> [design doc §8](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#8-documentation--traceability-conventions)
> (standard header, inline citations, confidence tags, ADRs close alternatives).

---

## 1. Scope

### 1.1 In scope for this spec

- The permanent three-layer module architecture for `magium.koplugin` (§3).
- The `.koplugin` folder layout (§4).
- **Milestone 0** — the on-device cold-parse measurement that sets the default
  parse strategy (§10).
- **Phase I** — the complete engine layer + the paginated reading widget +
  chapter 1 playable end to end + `currentState` autosave/resume (§11).
- The contracts (module interfaces + data shapes) that phases II–VIII depend on
  (§5–§9).

### 1.2 Explicitly out of scope

- Roadmap phases II–VIII beyond an architectural note (§12). Each gets its own
  spec.
- Licensing / distribution / packaging — deferred by
  [ADR-003](../decisions/ADR-003-defer-licensing-distribution.md); Phase VIII
  ships only a bare `koreader/plugins/` copy for the owner's own device.
- Any change to the `magium-dev` reference or the sibling checkouts.
- CI (the repo has none; §9 notes where it would attach).

### 1.3 Non-negotiable constraints (from the research phase)

| # | Constraint | Source |
|---|---|---|
| C1 | **Full parity** is the target: narrative + conditions + stats/stat-checks + achievements + multi-slot saves + settings + i18n (en/fr). Any gap → an `OQ-NNN`, not a silent drop. | [design doc §3](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#3-target-definition-full-parity) |
| C2 | Standalone `.koplugin`, Lua reimplementation of the `magium-dev` engine, `.magium` bundled verbatim and parsed at runtime. | [ADR-002](../decisions/ADR-002-porting-approach.md) |
| C3 | Single Lua state, cooperative scheduling, no threads. Any work >~1 frame is sliced via `UIManager:scheduleIn`/`nextTick` or run under `Trapper`. | [`03` §2](../research/03-koreader-platform.md#2-lua-environment-22) |
| C4 | LuaJIT 2.1 / Lua 5.1 + FFI. No `utf8` stdlib, Lua string patterns (not regex), all numbers are doubles. | [`03` §2](../research/03-koreader-platform.md#2-lua-environment-22) |
| C5 | Parity is verified by **differential test against the running `magium-dev` oracle** — so the engine must run under plain desktop `luajit`, with no KOReader dependency. | [design doc §9](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#9-how-research-findings-are-validated), [`03` §8.3](../research/03-koreader-platform.md#83-differential-testing) |
| C6 | Navigation is authoritative on the `v_current_scene` variable, never `choice.target`. | [`02` R8 / F-05](../research/02-magium-format-spec.md#4-parser-risk-list) |
| C7 | Spike code ([spikes 02–05](../spikes/)) is a **design reference, not a starting point** — production code is written fresh, hardened, and covers the full 54-file / 13-special-case surface. | CLAUDE.md, [`09` §0](../research/09-roadmap-effort.md#0-scope--assumptions-82-calibration) |

---

## 2. Architecture at a glance

```
                         ┌─────────────────────────────────────────┐
   main.lua  ───────────►│  plugin class (WidgetContainer:extend)   │
   registration,         │  lifecycle, save-flush points, wiring    │
   entry point           └───────────────┬─────────────────────────┘
                                         │ owns
                    ┌────────────────────┼────────────────────┐
                    ▼                    ▼                    ▼
             ┌────────────┐      ┌───────────────┐     ┌────────────┐
             │  engine/   │◄─────│     ui/       │     │   save/    │
             │  pure Lua  │ uses │  KOReader     │     │  manager   │
             │  NO ko deps│      │  widgets      │     │  (thin)    │
             └─────┬──────┘      └───────────────┘     └─────┬──────┘
                   │ reads/parses                            │ Persist / LuaSettings
                   ▼                                         ▼
             data/en/*.magium                       koreader data-dir/magium/
```

**Dependency direction (enforced by review, and by C5):**

- `engine/` requires nothing from `ui/`, `save/`, or the KOReader frontend
  (`ui/`, `apps/`, `device/`, `Persist`, `LuaSettings`, `UIManager`, …). It
  requires only the Lua stdlib. This is what lets `./kodev test front` *and*
  a bare `luajit` run the engine specs and the oracle diff.
- `ui/` requires `engine/` (for render-model shapes) and KOReader widgets.
- `save/manager.lua` requires `engine/store` (for snapshot/restore) + KOReader
  `Persist`/`LuaSettings`. Its format and debounce logic are written to be
  unit-testable with a fake writer.
- `main.lua` requires all three and the KOReader plugin surface.

`engine/scene.render()` is a **pure function** of `(scene_table, store_view, locale)` —
the same shape as `magium-dev`'s `renderScene(req)` — so the oracle comparison is
apples-to-apples.

---

## 3. Module map

### 3.1 `engine/` — pure Lua, desktop-testable

| Module | Responsibility | Ports / references |
|---|---|---|
| `parser.lua` | One `.magium` file → `{ [scene_id] = scene_table }`. Line-oriented scan; anchored construct matching (R1/R2); the documented quirks reproduced deliberately (leading `{}` scene, `currentParagraph` not reset on `ID:`, `<br/>` join, blank-line→`<br/>`, doubled-quote choice labels). | `parser.js` (whole file); [spike 02 `magium_parser.lua`](../spikes/02-engine-in-lua/magium_parser.lua); [`02` §1–2](../research/02-magium-format-spec.md) |
| `conditions.lua` | DNF evaluation. `eval_atom(atom, store_view)` + `eval(dnf, store_view)`. `nil`/absent → true; `"True"` → true; unknown atom → false (loud in dev, silent in release — R6); numeric coercion `tonumber(v or 0)`. | `utils.js` `apply_condition` / `apply_conditions`; [spike 02 `magium_utils.lua`](../spikes/02-engine-in-lua/magium_utils.lua); [`01` §3](../research/01-magium-analysis.md#3-condition-evaluation-task-13) |
| `stats.lua` | `var_to_stat`, `parse_stat_check` (4 branches, 100 % corpus coverage), `stat_checks_to_display` (fed by set ∪ paragraphs ∪ choices; de-dup; the `v_b3_ch1_unlock` lock filter). | `utils.js` `varToStat` / `parseStatCheck` / `statChecksToDisplay`; [`01` §5](../research/01-magium-analysis.md#5-stats-system-task-15) |
| `store.lua` | The flat `v_*` variable map. `get(k) → string`, `set(k, v)` with **`+N`/`−N` resolve-on-write** and the **`v_ac_*` "seen" latch** (never lower `"2"`→`"1"`); `snapshot()` / `restore(t)`; a cheap read-only `view()` for render. The `v_ac_b3_ch9_consolation == 5 → v_ac_b3_ch9_prize = 1` rule lives here (special case #12). | `utils.js:13–24,29–31`; [`01` §2](../research/01-magium-analysis.md#2-variable-store-task-12) |
| `scene.lua` | `render(scene_table, store_view, locale) → render_model`. The fixed 12-step pipeline (§6). Pure. | `renderers.js:renderScene`; [`01` §4](../research/01-magium-analysis.md#4-scene-effect-ordering-in-renderscene-task-14); [spike 02 `render_scene.lua`](../spikes/02-engine-in-lua/render_scene.lua) |
| `specials.lua` | The 13 hardcoded special cases ([`01` §10](../research/01-magium-analysis.md#10-hardcoded-scene-id--variable-special-cases-task-110)) as a data table + small apply-hooks called at fixed points in `scene.render` and (later) in the stats screen. Phase I implements the render-time ones (#1–#4, #6–#8, #12; #13's unset→0 is in `conditions`/`store`); stats-screen ones (#5, #9–#11) are declared but inert until Phase IV. | `renderers.js` / `utils.js` / templates, per the §10 table |
| `locale.lua` | Loads `data/<lang>/ui.json` via `engine/vendor/json.lua` (pure Lua, same under `luajit` and KOReader); `str(key)`; `header(scene_id)` = `getHeaderFromId` + the `<%= book %>/<%= chapter %>` micro-interpolator; the `mainStat{Success,Failed}Template` interpolation. | `utils.js` `getHeaderFromId` / `getLocaleData`; [`01` §9](../research/01-magium-analysis.md#9-localization-task-19) |
| `story.lua` | **The parse-strategy seam.** `Story.new{ data_dir, locale, strategy } → story`; `story:preload(on_progress)`; `story:get_scene(id) → scene_table`; `story:scene_ids()`. Two impls behind one interface (§7). | new; [`04` §4](../research/04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34) |

`engine/` has **no** `init.lua` facade object — the modules are mostly pure
functions plus two stateful holders (`store`, `story`), matching `magium-dev`'s
own structure. `main.lua` constructs and holds those two.

### 3.2 `ui/` — KOReader widgets

| Module | Responsibility | Phase |
|---|---|---|
| `reader.lua` | The custom fullscreen reading widget (§8). Holds the current `render_model`, the current page index, and the choice-page state. Owns page-turn input + the refresh calls. | I |
| `pagination.lua` | `paginate(render_model, geometry, measure_fn) → { pages }`. Pure chunking algorithm; `measure_fn(text, width) → height` is injected so it unit-tests without a display (real caller passes a `TextBoxWidget`-backed measurer). | I |
| `choices.lua` | Renders the choice list as the final page — a vertical `ButtonTable`; each button carries `{ label, target, set_vars, special }` and a tap callback into `reader.lua`. | I |
| `refresh.lua` | Refresh-type policy: which of `ui`/`partial`/`full`/`flashui` for page-turn vs scene-change vs modal vs periodic de-ghost. Phase I uses a conservative default; **OQ-007 tuning lands here** in Phase VIII. | I (stub) / VIII |
| `statspage.lua` | `KeyValuePage` stats screen. | IV |
| `savespage.lua` | `Menu`-based slot list + `InputDialog` for slot names. | III |
| `toast.lua` | Achievement unlock — `Notification`. | V |

### 3.3 `save/` — persistence

| Module | Responsibility | Phase |
|---|---|---|
| `manager.lua` | The 4-blob model (§9): `currentState` + `achievements` + `checkpoint` in one `LuaSettings` file; 50 manual slots as individual `Persist` blobs. Debounced autosave; explicit checkpoint save/load; slot CRUD. | I: `currentState` + `achievements` only. III: checkpoint + slots. |

---

## 4. `.koplugin` folder layout

```
magium.koplugin/
  _meta.lua                 return { fullname = _("Magium"), description = _([[...]]) }
  main.lua

  engine/
    parser.lua  conditions.lua  stats.lua  store.lua
    scene.lua   specials.lua     locale.lua  story.lua
    vendor/
      json.lua                -- vendored rxi/json.lua (MIT), pure-Lua encode+decode;
                              --   used by locale.lua (decode ui.json) and spec/oracle_diff.lua (encode)

  ui/
    reader.lua  pagination.lua  choices.lua  refresh.lua
    statspage.lua  savespage.lua  toast.lua           -- added in later phases

  save/
    manager.lua

  data/
    en/
      *.magium                -- 54 files, bundled verbatim from magium-dev @ 51f5aa9
      ui.json
      achievements1.json  achievements2.json  achievements3.json
    fr/                       -- added in Phase VII

  l10n/                       -- plugin-chrome gettext .po; added in Phase VII

  spec/
    run.lua                   -- luajit entrypoint for the engine-only spec subset
    oracle_diff.lua           -- drives engine/scene.render, diffs vs magium-dev
    *_spec.lua                -- busted specs
    fixtures/                 -- symlink or copy of reference/tools/oracle-capture goldens
```

`package.path` is extended per-plugin, so `require("engine.parser")` resolves
against `main.lua`'s directory ([`03` §1.1](../research/03-koreader-platform.md#1-plugin-anatomy-21)).

Story data lives **next to `main.lua`** (read-only bundle). Saves live under the
KOReader **data dir** (`DataStorage:getDataDir() .. "/magium/"`) —
[`03` §4.1](../research/03-koreader-platform.md#4-persistence-24).

---

## 5. Data shapes (the contracts)

### 5.1 `scene_table` (parser output — one entry per scene)

```lua
{
  id = "Ch3-Vantage",
  paragraphs = {                       -- order preserved
    { text = "…<br/>…",  conditions = <dnf> | nil },
  },
  choices = {
    { text = "…", target = "Ch3-Busy", special = "saves" | nil,
      set_vars = { v_current_scene = "Ch3-Busy", v_x = "+1" },   -- string values
      conditions = <dnf> | nil },
  },
  set_variables = {
    { name = "v_x", value = "2", conditions = <dnf> | nil },      -- value is 1 char: [+-]?[0-9]
  },
  achievements = { { text = "…", variable = "v_ac_x" } },
}
```

`<dnf>` = `{ {atom, atom, …}, {atom, …}, … }` — outer OR of inner ANDs; an atom is
the raw string `"v_perception > 2"`. `nil` = unconditional.

### 5.2 `render_model` (`scene.render` output — what `ui/` consumes and what the oracle diff compares)

```lua
{
  scene_id   = "Ch3-Vantage",
  header     = "Book 1 - Chapter 3" | nil,
  checkpoint = false,                       -- show the checkpoint banner?
  stat_checks = { { success = true, text = "[ Observation check successful - level 3 ]" } },
  set_variables = { { name = "v_x", value = "2" } },   -- literal parsed value (parity; see §6 note)
  paragraphs = { "normalized prose string", … },       -- <br/> still present; ui/ converts to \n
  choices    = { { text = "…", target = "…", special = "saves"|nil, set_variables = {…} } },
  achievements = { { variable = "v_ac_x", text = "…" } },
}
```

The canonical JSON form for the oracle diff is defined by
[`reference/tools/oracle-diff.js`](../../reference/tools/oracle-diff.js)'s normalizer;
`spec/oracle_diff.lua` emits the same shape (this is exactly what
[spike 02 `render_scene.lua`](../spikes/02-engine-in-lua/render_scene.lua) already does — reuse that mapping).

### 5.3 `page` (pagination output)

```lua
{ kind = "prose",   blocks = { <banner?>, <stat_checks?>, <paragraph lines…> } }
{ kind = "choices", buttons = { { label, target, set_vars, special }, … } }
```

`kind = "choices"` is always the **last** page (decision: choices-as-final-page,
[ADR-004](../decisions/ADR-004-plugin-internal-architecture.md)).

---

## 6. The 12-step render pipeline (`engine/scene.lua`)

A faithful port of `renderers.js:renderScene` lines 52–92
([`01` §4](../research/01-magium-analysis.md#4-scene-effect-ordering-in-renderscene-task-14)).
Order is parity-critical:

1. Resolve `scene_id` (`store:get("v_current_scene")` or `"Ch1-Intro1"` — special case #1).
2. Take a working var view = a copy of the store's current values.
3. Keep `set_variables` whose `conditions` pass against the **incoming** view.
4. Apply the survivors to the working view **in array order** (later see earlier).
   *Parity note:* the working view applies values literally, including `"+3"`;
   `tonumber("+3") == 3` makes subsequent comparisons agree with `magium-dev`
   (`parseInt`). The **store** (§5, `store:set`) resolves `+N`/`−N` for real only
   when the player commits a choice — this split is verified by a dedicated
   Phase I oracle fixture.
5. Keep `choices` whose `conditions` pass against the post-step-4 view.
6. Keep `paragraphs` whose `conditions` pass against the post-step-4 view.
7. `stat_checks = stats.stat_checks_to_display(survivors_of(set∪para∪choice), view, locale)`.
8. Special case #2 — `scene_id == "B3-Ch04a-Introduction2"` → `stat_checks = {}`.
9. Keep `achievements` where `view[a.variable] == "1"` (strict).
10. Special case #3 — `view.v_ac_b3_ch9_prize == "1"` → append the "Consolation prize" achievement.
11. `checkpoint = any surviving choice sets v_checkpoint_rich == "0"` (special case #4).
12. `header = locale.header(scene_id)`.

Then `ui/` renders: banner → stat-check lines → prose → (final page) choices;
achievement toasts fire on the render right after the unlocking choice
([`01` §6.1](../research/01-magium-analysis.md#6-achievements-task-16)).

---

## 7. The parse-strategy seam (`engine/story.lua`)

One interface, two implementations. **Milestone 0 picks the default**; the other
stays built and switchable (a plugin setting).

```lua
Story.new{
  data_dir    = "…/data",
  locale      = "en",
  strategy    = "eager" | "lazy",
  cache_store = <adapter> | nil,    -- get(key)→table|nil, set(key, table); lazy only
}
story:preload(on_progress)          -- called once, off the init hot path
story:get_scene(scene_id)           -- returns the scene_table; caches parsed scenes
story:scene_ids()                   -- iterator over all known ids (for full-corpus QA)
```

`data_dir` is read with the Lua stdlib `io` (core, available under both plain
`luajit` and KOReader) — so `story` stays engine-pure (C5). The **only**
KOReader-specific concern, disk caching of parsed blobs (lazy path), is behind an
injected `cache_store` adapter: `main.lua` backs it with KOReader `Persist`
(`luajit` codec) under the data-dir `cache/`; specs back it with an in-memory or
temp-dir fake. Same injected-seam pattern as `pagination.measure_fn` and
`save/manager`'s writer.

### 7.1 `eager`

> **Milestone 0 (pending):** emulator (x86) cold parse measured 411 ms; the on-device ARM number that sets the default is pending the owner's Kindle run — see [spike 06](../spikes/06-ondevice-parse-timing/FINDING.md).

`preload` parses all 54 files now, under a `Trapper` coroutine with a progress
bar so the UI stays responsive (C3). Holds every `scene_table` resident
(~11.5 MB measured, [spike 03](../spikes/03-full-corpus-memory-parse/) — a
non-issue against ~497 MB free). `get_scene` is a table lookup.

### 7.2 `lazy`

`preload` builds only a **scene-id → file index**: scan every `data/<lang>/*.magium`
for `^ID: ` lines (no construct parsing — milliseconds). Store the index via
`cache_store:set("index-<lang>", …)`, keyed by the set of `(filename, size)` —
rebuild only when that changes.

`get_scene(miss)` → look up the file, parse that **whole chapter file**, cache all
its scenes in memory, and `cache_store:set("chapter-<file>", parsed)`. Every later
launch reads it back via `cache_store:get` instead of re-parsing. Bounded working
set also eases GC
([`04` §3 row 7](../research/04-constraints-budget.md#3-budget-table-33)).

### 7.3 Shared

- Both assert **scene-id uniqueness** across files on load (R9).
- Both strip `\r` when reading lines (R10).
- The `b3ch4a.magium` 490 KB condition (R7 / OQ-011) is parsed like any other in
  Phase I; its per-render cost is measured and mitigated in Phase VIII. If
  Milestone 0 *or* an early Phase I profile shows the parse of that one line is
  itself a stall, `story` gains a targeted pre-split cache for it — noted, not
  built now.

---

## 8. The reading widget (`ui/reader.lua` + `ui/pagination.lua`) — resolves OQ-013

`TextViewer` is rejected ([spike 04](../spikes/04-ui-plugin-skeleton/), OQ-013:
padded dialog, continuous scroll, no page concept). `reader.lua` is a bespoke
fullscreen widget — an `InputContainer`/`FrameContainer` composition that covers
the screen (`covers_fullscreen = true`), modeled structurally on
`frotz.koplugin`'s `GameView` but **paginated, not scrolled**
([`03` §3 spike-A verdict](../research/03-koreader-platform.md#3-ui-toolkit-inventory-23)).

### 8.1 Layout

```
┌───────────────────────────────────────────┐
│ Book 1 - Chapter 1                         │  header (locale.header)
│                                            │
│ [ Checkpoint reached: Game saved. ]        │  banner — first page only, if render_model.checkpoint
│ [ Observation check successful - level 3 ] │  stat-check lines — first page only
│                                            │
│ Prose, wrapped to the full text width,     │  TextBoxWidget, <br/> → \n
│ justified per KOReader defaults, filling    │  ([`03` §5](../research/03-koreader-platform.md#5-text-rendering-25), F-19)
│ the page …                                 │
│                                            │
│                                            │
│                              2 / 4         │  page indicator
└───────────────────────────────────────────┘
        tap right / PgFwd → next page
        tap left  / PgBack → prev page
        Back → close (flush autosave, pop to FileManager)
```

The **final page** (`kind = "choices"`) replaces the prose area with the choice
`ButtonTable`; the indicator reads e.g. `choices`. Selecting a choice:

1. apply `choice.set_vars` to the **store** (`store:set` — relative writes resolve here);
2. `store:set("v_current_scene", choice.target)` (C6);
3. if `choice.special` → dispatch (`restart` / `saves` / `stats` /
   `checkpoint_save` / `checkpoint_load` — [`01` §7](../research/01-magium-analysis.md#7-special-hooks-task-17));
   in Phase I only `restart` is fully wired, the rest are navigation stubs;
4. re-`render` the new scene, re-`paginate`, show page 1.

### 8.2 Pagination (`pagination.lua`)

Pure function `paginate(render_model, geometry, measure_fn) → { pages }`:

- `geometry` = `{ width, height, line_height, header_h, indicator_h }` supplied by
  `reader.lua` from the real screen + face metrics.
- Greedily fill each prose page: accumulate paragraph lines until the next line
  would exceed `height`; the first page also subtracts the banner + stat-check
  block height.
- `measure_fn(text, width) → height` is injected. Real caller: a thin wrapper
  over `TextBoxWidget:new{…}:getSize()` (or its line-count API,
  [`03` §3](../research/03-koreader-platform.md#3-ui-toolkit-inventory-23)). Specs
  pass a deterministic fake (`#lines * fixed_height`).
- Append exactly one `kind = "choices"` page.
- Re-paginate on font-size change or rotation (`reader.lua` listens for the events).

### 8.3 Refresh (`ui/refresh.lua`, Phase I default)

Conservative, tuned later (OQ-007, Phase VIII):

| Event | Refresh type |
|---|---|
| open the reader | `full` |
| page turn (same scene) | `ui` |
| new scene (choice committed) | `ui`, with a `full` every 6th scene to de-ghost ([`03` §6](../research/03-koreader-platform.md#6-e-ink-specifics-26)) |
| open/close a modal (later phases) | `flashui` |
| close the reader | parent handles it |

---

## 9. Save model (`save/manager.lua`)

Maps `magium-dev`'s four `localStorage` blobs
([`01` §8](../research/01-magium-analysis.md#8-saves--settings-task-18)):

| magium-dev blob | Here | Phase |
|---|---|---|
| `currentState` (live vars minus `v_ac_*`) | key in `magium/state.lua` (`LuaSettings`) | I |
| `achievements` (`v_ac_*` flags) | key in `magium/state.lua` | I |
| `checkpoint` (snapshot + `date` + `name`) | key in `magium/state.lua` | III |
| `save0…save49` (snapshot + `date` + `name`) | `magium/slots/NN.blob` (`Persist`, `luajit`), plus a `{NN → {date,name}}` index in `state.lua` | III |

`state.lua` is small (single-digit KB, [`04` F-23](../research/04-constraints-budget.md#findings))
and loads every launch; slot blobs load only when the saves screen opens or a
slot is loaded — so 50 slots never inflate launch cost.

**Autosave debounce** (F-20, [`03` §4.3](../research/03-koreader-platform.md#4-persistence-24)):
`currentState` flushes on a short idle timer (order of seconds via
`UIManager:scheduleIn`, reset on each store mutation), on
`checkpoint_save`/`checkpoint_load`, on `reader:onClose`, and on the broadcast
`Close` / suspend events — **never once per choice**. Exact debounce interval is
an implementation-plan tuning knob. `v_ac_*` flushes
immediately on unlock (rare; a lost unlock is worse than a few seconds of lost
position). Both `LuaSettings:flush()` and `Persist:save()` fsync
([`03` §4.2](../research/03-koreader-platform.md#4-persistence-24)).

The serialization + debounce logic takes an injected writer so it is
unit-testable without touching the filesystem; the KOReader `Persist`/`LuaSettings`
wiring is a thin adapter.

---

## 10. Milestone 0 — on-device parse-timing gate

**Purpose:** produce the number that sets `story`'s default `strategy` (§7), before
Phase I builds around one shape. Per
[`09` Milestone 0](../research/09-roadmap-effort.md#milestone-0--pre-flight-on-device-parse-timing-gate)
and [ADR-002](../decisions/ADR-002-porting-approach.md)'s deliberately-open detail.

**Method:**

1. Write `engine/parser.lua` and `engine/story.lua` (`eager` path) to production
   quality first — Milestone 0 is not throwaway, it is Phase I's parser exercised
   early.
2. Wrap them in a minimal `main.lua` that, on a menu tap, runs
   `story:preload()` over all 54 English files and logs `os.clock()` / wall-clock
   deltas (cold: first run after KOReader restart; warm: subsequent).
3. Run on the owner's **real Kindle Paperwhite 12th gen** (primary) and the WSL2
   `kodev` build (first pass — same ARM-vs-x86 caveat
   [spike 03](../spikes/03-full-corpus-memory-parse/) flagged).
4. Record: cold-parse wall-clock (ms), warm-parse, peak RSS delta.

**Decision rule:**

| Cold parse (device) | Default strategy |
|---|---|
| ≤ ~1 s | `eager` — parse all at launch behind a progress bar |
| > ~1 s | `lazy` — index + per-chapter disk cache (§7.2) |

Threshold rationale: [`04` §3 row 3](../research/04-constraints-budget.md#3-budget-table-33).
Either way both impls ship; this only sets the default. **Effort: 2–4 h**
([`09` §2](../research/09-roadmap-effort.md#2-effort-summary-table-82)).

**Deliverable:** a short `docs/spikes/06-ondevice-parse-timing/FINDING.md` (spike
folder — it is a measurement, and its harness is subsumed by Phase I) + this
spec's §7 default updated with the result.

---

## 11. Phase I — MVP

### 11.1 Deliverables

**Engine (complete, not partial):**

- `parser.lua` — parses all 54 English files with **zero anomalies**; structural
  counts match the known corpus exactly: **2159 scenes, 4880 paragraphs, 3734
  choices, 594 `set()`, 145 `achievement()`, 2480 `#if`**
  ([`01` §11](../research/01-magium-analysis.md#11-parsed-story-size--memory-footprint-task-112)).
  Anchored constructs (R1/R2), 1-char `set()` value asserted not truncated (R3),
  single-paren-condition assertion (R4), `\r` stripped (R10), id uniqueness
  asserted (R9).
- `conditions.lua`, `stats.lua`, `store.lua`, `locale.lua` — full ports.
- `scene.lua` — the **entire** 12-step pipeline including `stat_checks` and
  `achievements` computation (their *screens* don't exist yet, but computing the
  data keeps the oracle diff whole).
- `specials.lua` — render-time special cases #1–#4, #6–#8, #12 live (#13's
  unset→0 handled in `conditions`/`store`); stats-screen #5, #9–#11 declared,
  inert.
- `story.lua` — both `eager` and `lazy`, default per Milestone 0.

**UI:**

- `reader.lua` + `pagination.lua` + `choices.lua` — chapter 1 (`ch1.magium`,
  12 scenes) playable start to finish: prose pagination, choices-as-final-page,
  page-turn + Back input, header + checkpoint banner + stat-check lines,
  conservative refresh.
- `refresh.lua` — the Phase I default table (§8.3).

**Save:**

- `save/manager.lua` — `currentState` autosave (debounced) + `achievements`
  immediate flush + **resume** (reopen → `store` restored → `v_current_scene`
  scene shown). No manual slots / checkpoint UI (Phase III).

**Plugin:**

- `main.lua` — `more_tools` menu item + `Dispatcher` action; `story:preload()`
  scheduled off the `init()` hot path; lifecycle flush on close/suspend/`Close`.
- `_meta.lua`.

**No title/menu screen in Phase I** — opening the plugin goes straight to
`store:get("v_current_scene")` (or `Ch1-Intro1` on a fresh state).
`magium-dev`'s menu (`menu.ejs` — new game / continue / saves / stats /
achievements / settings / about) is not a `.magium` scene; it is built in
Phase II (entry actions) and III–VI (the screens it links to).

**Tests:**

- `spec/oracle_diff.lua` — green on the existing 6
  [`reference/tools/oracle-capture`](../../reference/tools/) goldens **and** on a
  new fixture set covering every branch, `#if`, and `set()` in `ch1.magium`
  (generated by walking `ch1` against the running oracle).
- `spec/*_spec.lua` (busted) — `conditions` (all 6 operators, coercion, unknown
  atom, `True`, empty clause), `stats` (all 4 `parse_stat_check` branches +
  lock filter + de-dup), `store` (`+N`/`−N`, `v_ac_*` latch, consolation-prize
  rule), `parser` (the corpus counts above), `pagination` (fake measurer:
  fill, overflow, first-page banner offset, the trailing choices page).
- Runs under `./kodev test front` (WSL2) and `luajit spec/run.lua` (engine subset).

### 11.2 Exit criteria

- [ ] `ch1` plays start → finish on the **real Kindle** (or WSL2 `kodev` as an
      interim), every choice reaching its correct target scene.
- [ ] `spec/oracle_diff.lua` reports **0 diffs** across the 6 goldens + the full
      `ch1` fixture set.
- [ ] `parser.lua` produces the exact corpus counts (§11.1) with 0 anomalies
      logged.
- [ ] Close the reader mid-chapter, reopen from the menu → resumes on the same
      scene with the same variable state.
- [ ] `koreader/crash.log` clean (no Lua tracebacks, no `logger.warn/err` from
      the plugin) across a full `ch1` playthrough + a resume.
- [ ] All busted specs pass in both runners.
- [ ] Milestone 0's `FINDING.md` committed; §7 default recorded.

### 11.3 Effort

**35–55 h** ([`09` §2](../research/09-roadmap-effort.md#2-effort-summary-table-82)):
engine core 15–25 h (mechanical, oracle-checked); pagination widget 15–30 h (the
new build, the KOReader-idiom ramp, the best target for community help —
[`09` §3](../research/09-roadmap-effort.md#3-critical-path--parallelism-83)).
Milestone 0 adds 2–4 h up front.

---

## 12. Phases II–VIII — architectural notes

Each is its own spec cycle. What each adds against this skeleton, so the Phase I
code is written to accommodate it without rework:

| Phase | Adds | Touches (existing) | New modules |
|---|---|---|---|
| **II — full corpus & nav** | all 54 files; history/back stack; audit + port all 13 special cases against real scenes; `special:` hooks as nav stubs | `story` (multi-file already there), `reader` (history stack), `specials` (finish) | — |
| **III — saves** | `checkpoint` blob; 50 manual slots; `checkpoint_save`/`checkpoint_load` real; slot name/date UI | `save/manager`, `reader` (special dispatch) | `ui/savespage.lua` |
| **IV — stats** | `KeyValuePage` stats screen; the `v_available_points`/`v_max_stat` spend flow; stats-screen special cases #9–#11 | `specials` (activate #9–#11), `store` (stat vars), `reader` (special dispatch) | `ui/statspage.lua` |
| **V — achievements** | unlock toast; the 136-entry `achievements{1,2,3}.json` menu; `b2ch41` group quirk; always-on `v_ac_b3_ch9_prize` | `scene` already computes the list; `locale` (achievements JSON) | `ui/toast.lua`, `ui/achievementsmenu.lua` |
| **VI — settings** | a scoping pass first — most of `settings.ejs` (font/theme) is KOReader's job ([`01` §8](../research/01-magium-analysis.md#8-saves--settings-task-18)); port only genuinely game-specific settings | `main` (menu) | maybe none |
| **VII — i18n** | `data/fr/` bundle + `fr/ui.json`; `l10n/<lang>/*.po` for plugin chrome; a locale switch | `locale` (already parameterised), `story` (`locale` arg exists) | `l10n/` |
| **VIII — polish** | OQ-007 e-ink tuning in `refresh.lua`; OQ-011 490 KB-condition mitigation in `conditions`/`story`; LuaJIT GC tuning; full-corpus `oracle_diff` over all 2159 scenes; `crash.log` bug bash; bare `koreader/plugins/` packaging | `refresh`, `conditions`, `story`, `spec/oracle_diff` | — |

The engine/ui split means III–V and VII only **add** modules — they do not reopen
`engine/` core or `ui/reader.lua`
([`09` §3](../research/09-roadmap-effort.md#3-critical-path--parallelism-83), F-37).

---

## 13. Open questions carried in

| ID | State entering implementation | Where it resolves |
|---|---|---|
| [OQ-001](../research/07-risks-open-questions.md) (parse-time tail) | memory closed; on-device ARM cold-parse time still unmeasured | **Milestone 0** (§10) |
| [OQ-007](../research/07-risks-open-questions.md) (e-ink refresh feel) | unanswerable off real e-ink | Phase VIII, `ui/refresh.lua` — owner on device |
| [OQ-011](../research/07-risks-open-questions.md) (490 KB condition cost) | parses fine; per-render cost on ARM unmeasured | Phase VIII (or earlier if Milestone 0 flags the parse itself); §7.3 |
| [OQ-013](../research/07-risks-open-questions.md) (pagination widget) | **resolved by this spec** — §8, custom fullscreen paginated widget, choices-as-final-page | built in Phase I |

No open question blocks writing the implementation plan; OQ-001 blocks *starting
Phase I code* only in the sense that Milestone 0 (2–4 h) runs first.

---

## 14. Handoff to the implementation plan

On approval of this spec, the next step is the **writing-plans** skill to turn
§10 + §11 into an ordered, checkpointed implementation plan:

1. Milestone 0 — parser + `story` eager + timing harness → the number.
2. Engine core — `conditions`, `store`, `stats`, `locale`, `scene`, `specials`
   (render-time), each with its busted spec, then `oracle_diff` green on the 6
   goldens.
3. `story` lazy path + the strategy default from step 1.
4. `pagination` (pure, fake measurer) → `reader` + `choices` → `ch1` playable in
   WSL2 `kodev`.
5. `save/manager` autosave + resume.
6. `main.lua` wiring + lifecycle; on-device `ch1` run; exit criteria (§11.2).

Build order rationale: the pure engine + its oracle diff comes first (cheapest,
highest-certainty, unblocks everything), the widget second (the real ramp), glue
last.
