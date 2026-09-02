# 01 — Magium engine analysis

- **Status:** stable (source-grounded, spot-checked against the oracle in Phase 1; independently validated by a full Lua reimplementation matching 6/6 diffed fixtures + exact full-corpus structural counts — [spike 02](../spikes/02-engine-in-lua/FINDING.md), [spike 03](../spikes/03-full-corpus-memory-parse/FINDING.md))
- **Last updated:** 2026-08-31
- **Phase:** 1
- **Sources:** `../magium-dev` @ `51f5aa9` — `src/parser.js`, `src/utils.js`, `src/renderers.js`, `src/main_setup.js`, `templates/*.ejs`, `public/scripts/{utils,saves,stats,theme}.js`, `data/en/{ui.json,locales.json,achievements1.json}`; the running differential oracle ([`../../reference/magium-dev-notes.md`](../../../reference/magium-dev-notes.md)); corpus scan [`../../reference/tools/scan-magium-constructs.js`](../../../reference/tools/scan-magium-constructs.js)
- **Related:** [`02-magium-format-spec.md`](02-magium-format-spec.md), [`00-overview.md`](00-overview.md), [`04-constraints-budget.md`](04-constraints-budget.md), [design doc §3](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#3-target-definition-full-parity), [`07-risks-open-questions.md`](07-risks-open-questions.md)

> Goal: a complete, source-grounded description of how the Magium engine behaves,
> so a Lua reimplementation can be checked against it. Every claim cites a line in
> `magium-dev`; behaviours marked *(oracle-verified)* were confirmed against the
> running build 2026-08-31.
>
> **The whole engine is ~640 lines of JS in four files.** `parser.js` (131) turns
> `.magium` text into scene objects; `utils.js` (219) does conditions, stat
> checks and headers; `renderers.js` (194) turns a scene + a variable map into
> HTML; `main_setup.js` (117) is the Express wiring. Everything else is EJS
> templates and client-side persistence glue.

---

## 0. Data flow at a glance

```
 .magium files ──parser.parse()──►  scenes_dict { id → {paragraphs, choices,
                                        setVariables, achievements, statChecks:[]} }
                                     (merged across all 54 files, one namespace)

 HTTP POST /  body = full variable map (strings), header HX-Request: true
      │
      ▼
 renderScene(req)                       ── renderers.js:52 ──
   1. id       = body.v_current_scene || "Ch1-Intro1"
   2. cookieData = { ...body }                     (working copy of all vars)
   3. sceneData = { ...scenes_dict[id] }           (shallow copy of the scene)
   4. keep setVariables whose conditions pass under cookieData
   5. apply those setVariables to cookieData        (in array order; +N/-N are literal here)
   6. keep choices     whose conditions pass under cookieData   (post-step-5)
   7. keep paragraphs  whose conditions pass under cookieData   (post-step-5)
   8. statChecks = stat atoms found in the *passing* condition groups of
                   (setVariables ∪ paragraphs ∪ choices)
   9. if id == "B3-Ch04a-Introduction2": statChecks = []
  10. keep achievements where cookieData[ach.variable] === "1"
  11. if cookieData.v_ac_b3_ch9_prize == "1": append the "Consolation prize" achievement
  12. scene.checkpoint = any surviving choice sets v_checkpoint_rich === "0"
      │
      ▼
 main.ejs  → storeVariable() scripts, checkpoint banner, stat-check divs,
             prose paragraphs, choice buttons, achievement modals, OOB header
      │
      ▼
 client: setResponseVariables(choice) + inline storeVariable() calls persist the
         new variable state to localStorage; next choice POSTs it back.
```

The server is a **pure function** of the posted variable map — no server-side
session — which is exactly why it works as a differential oracle
([F-01](#findings)).

---

## 1. Scene model *(task 1.1)*

`parser.parse(filename)` (`parser.js:23–126`) streams the file line-by-line and
produces `scenes_dict: { [id]: scene }`. A `scene` is:

```js
{ id: "Ch3-Vantage",
  paragraphs:   [ { text: "…<br/>", conditions: undefined | string[][] } ],
  choices:      [ { text, target, setVariables: {…}, special, conditions } ],
  setVariables: [ { name, value, conditions } ],
  achievements: [ { text, variable } ],
  statChecks:   [] }          // always empty from the parser; filled by renderScene
```

The line grammar, the exact dispatch order, and every parser quirk (unanchored
regexes, `startsWith` traps, the swallowed blank line after `TEXT:`, `<br/>`
joining, blank-line-as-`<br/>`, the sliced leading `{}` scene, the flat global id
namespace) are documented in **[`02-magium-format-spec.md` §1–2](02-magium-format-spec.md)**.
The points that matter most for a faithful engine port:

- **`set()` and `achievement()` are paragraph-transparent** — prose on both sides
  of them joins into one paragraph. Only `choice`, `#if` and `}` split
  paragraphs (`parser.js:80,105,113`).
- **Every prose line ends up with `<br/>` appended** (`parser.js:116`), so
  paragraph `text` always ends `<br/>`; consecutive prose lines are `<br/>`-joined
  and a blank line becomes a bare `<br/>`. There is **no other markup** — the
  data has no `<b>`, `<i>`, links, images; `<br/>` is the entire vocabulary
  (relevant to text-widget choice in [`03`](03-koreader-platform.md)).
- **`paragraphs[i].text` is one string per parser paragraph object**, which for a
  `#if` block is the whole multi-line block glued with `<br/>`.
- **`statChecks` from the parser is always `[]`** — it exists on the object but
  is only ever populated by `renderScene` (§5). A port should compute stat-check
  display at render time, not parse time.

Measured corpus shape: **2159 scenes, 4880 paragraph objects, 3734 choices, 594
`set()`, 145 `achievement()`, 2480 `#if` blocks** (§11, and
[`02` §3](02-magium-format-spec.md#3-construct-corpus-task-111)).

---

## 2. Variable store *(task 1.2)*

- **One flat namespace, `v_*` by convention.** No scoping, no types declared.
  318 distinct variables appear in conditions (scan); the full set (including
  write-only flags) is larger.
- **Every value is a string in storage** — `"2"`, `"0"`, `"Ch3-Busy"`,
  `"Cutthroat Dave"`. Numbers appear only transiently inside `parseInt`
  comparisons. The web client stores strings; the oracle body must send strings
  (`"2"`, not `2`) — [F-02](#findings).
- **Unset variable ⇒ `0`.** `apply_condition` uses `(values[variable] || 0)`
  (`utils.js:70–75`); templates use `<%= (locals.v_x) || 0 %>`. Note `"0"` is
  truthy in JS, so a stored `"0"` is kept and then coerced by the numeric
  comparison — a Lua port must `tonumber(v or 0)` and compare numerically.
- **Special variables:**
  | Variable | Role | Set by | Read by |
  |---|---|---|---|
  | `v_current_scene` | **the only navigation state** | every non-`special` choice, `special:restart` (→ `Ch1-Intro1`) | `renderScene` (`renderers.js:53`), `main_setup.js:89` |
  | `v_checkpoint_rich` | checkpoint marker: `"0"` just past a checkpoint, `"1"` at chapter-end save | `choice` assignments (136 lines) | `renderScene` for the banner (`renderers.js:87`) |
  | `v_ac_*` | achievement flags: `"1"` = just unlocked, `"2"` = seen (modal shown) | `choice`/`set` assignments; the `storeVariable("v_ac_x","2")` scripts in `main.ejs` | `renderScene` achievement filter (`renderers.js:81`); menu template |
  | stat vars (14) | `v_strength … v_magical_knowledge` | the stats screen (`stats.js:confirmStats`) and a few `set()` in-story | conditions, `parseStatCheck` |
  | `v_max_stat` | stat cap, **defaults to 3** (not 0) | stats screen; `settings` cheat mode sets `v_available_points` to 50 | `stats.ejs` |
  | `v_available_points` | unspent stat points | in-story `set()`, cheat mode | `stats.ejs`, `stats.js` |
  | `v_is_dead` | death-branch flag | `set(v_is_dead, 0/1) if (…)` | conditions |
  | `v_maximized_stats_used`, `v_b3_ch11_magic`, `v_b3_ch1_unlock` | scene/UI special-cases | in-story | `renderStats`, `stats.ejs`, `parseStatCheck` (§5, §10) |
- **Two buckets in the web client** (`public/scripts/utils.js:28–38`): keys
  starting `v_ac_` go to the `achievements` localStorage blob, everything else to
  `currentState`. The two are merged back into one flat map when POSTed
  (`saves.js:87–91`). An `achievements` flag already at `"2"` is never lowered
  (`utils.js:31`). A port can keep one map but must not let a re-render's
  `storeVariable(…, "2")` clobber a later `"1"` incorrectly — the "seen" latch
  matters for not re-popping modals.
- **`+N` / `-N` values** in `set()`/`choice` assignments are **relative** and
  resolved on write by `storeItem` (`utils.js:13–18`): `+3` → `current+3`. The
  parser stores them verbatim; `renderScene` step 5 applies them **literally**
  (so the server-rendered `storeVariable("v_x","+3")` defers the arithmetic to
  the client). A port that evaluates server-side must do the `+`/`-` arithmetic
  itself. 10 `set()` lines use this; achievement counters like
  `v_ac_b3_ch9_consolation` are incremented this way, and hitting `5` triggers
  `v_ac_b3_ch9_prize = 1` (`utils.js:22–24`) → the always-on "Consolation prize"
  achievement (§6, §10).

---

## 3. Condition evaluation *(task 1.3)*

`apply_condition(entry, values)` (`utils.js:54–82`) and
`apply_conditions(conditions, values)` (`utils.js:90–97`).

- **`conditions` is `string[][]`** — DNF, outer OR of inner ANDs — produced by
  `parseConditions` (`parser.js:13–21`). `undefined` ⇒ unconditional.
- `apply_conditions` = `!conditions || conditions.some(and => and.every(atom => apply_condition(atom, values)))`.
  - No conditions → **true** (always show).
  - Empty inner array → `.every` on `[]` → **true**.
- `apply_condition`:
  - falsy `entry` → **true** (`utils.js:55`).
  - `"True"` → **true** (`utils.js:59`). *(supported, never used — scan)*
  - else match `/(?<varName>\w*) (?<condType><|>|>=|==|<=|!=) (?<value>[0-9]+)/`
    and switch on the operator, comparing `(values[varName] || 0)` (JS loose
    `==`/`!=`, numeric `<`/`>`/`<=`/`>=`) against `parseInt(value)`
    (`utils.js:69–76`).
  - **no match** (e.g. `"False"`, malformed) → `console.log("Condition fail")` +
    **return `undefined`** (falsy → fails the AND-clause). *(oracle-verified:
    `#if(False)` block never renders.)*
- **Whitespace is load-bearing** — single spaces around operator and `&&`/`||`.
  See [`02` §2.5 / §4 R5](02-magium-format-spec.md#25-conditions).
- **Parens**: `parseConditions` strips only the first `(` and first `)`; safe
  because no corpus condition has more than one of each ([`02` §2.5](02-magium-format-spec.md#25-conditions)).
- Operator frequency across ~29.7k atoms: `==` 55%, `>` 31%, `!=` 6%, `<` 4%,
  `>=` 3%, `<=` 0.07% (scan).

**Port checklist:** DNF split on ` || ` then ` && `; atom = `var op int`;
missing var = 0; string values compared numerically; unknown atom = false
(silent in release); `True` = true; empty/absent condition = true.

---

## 4. Scene-effect ordering in `renderScene` *(task 1.4)*

The exact sequence (`renderers.js:52–92`) — **order matters for parity**:

1. **Pick scene** — `id = body.v_current_scene || "Ch1-Intro1"`;
   `sceneData = { ...scenes_dict[id] }` (shallow copy — the parsed scene is not
   mutated).
2. **Working var copy** — `cookieData = { ...body }`.
3. **Filter `setVariables`** by `apply_conditions(sv.conditions, cookieData)` —
   evaluated against the **incoming** values (`renderers.js:58`).
4. **Apply** surviving `setVariables` to `cookieData` **in array order**
   (`renderers.js:61`) — later ones see earlier ones' effects. Values written
   literally (incl. `"+3"`).
5. **Filter `choices`** by `apply_conditions(c.conditions, cookieData)` — now
   against the **post-`set()`** values (`renderers.js:64`).
6. **Filter `paragraphs`** likewise (`renderers.js:67`).
7. **Compute `statChecks`** — `statChecksToDisplay((surviving setVariables) ∪
   (surviving paragraphs) ∪ (surviving choices), cookieData, localeData)`
   (`renderers.js:70`). Only entries that *have* a `conditions` field
   contribute; see §5.
8. **`B3-Ch04a-Introduction2` special-case** — `statChecks = []`
   (`renderers.js:76`) so the "Average Joe" reveal scene shows no checks.
9. **Filter `achievements`** — keep where `cookieData[ach.variable] === "1"`
   (strict) (`renderers.js:81`).
10. **`v_ac_b3_ch9_prize` special-case** — if `== "1"` (loose), append
    `{ text: "Consolation prize", variable: "v_ac_b3_ch9_prize" }`
    (`renderers.js:84`).
11. **`scene.checkpoint`** — `choices.some(c => c.setVariables["v_checkpoint_rich"] === "0")`
    over the **surviving** choices (`renderers.js:87`).
12. **Header** — `getHeaderFromId(id, localeData.mainHeaderTemplate)` (§9).

Then `main.ejs` renders in this DOM order (`templates/main.ejs`):
`storeVariable()` scripts for each surviving `setVariable` → checkpoint banner →
stat-check divs → paragraphs (`<%- paragraph.text %>`, raw) → choice buttons →
achievement modals (each preceded by `storeVariable("v_ac_x","2")`) → header
(out-of-band `hx-swap-oob`).

**Consequence:** a scene's own `set()` effects are visible to that scene's own
`#if` paragraphs and conditional choices. `v_current_scene` during the render is
still the *current* scene's id; the choices carry the *next* one.

---

## 5. Stats system *(task 1.5)*

### 5.1 The 14 stat variables

`stats_variables` (`utils.js:4–19`): `v_strength, v_toughness, v_agility,
v_reflexes, v_hearing, v_perception, v_ancient_languages, v_combat_technique,
v_premonition, v_bluff, v_magical_sense, v_aura_hardening, v_magical_power,
v_magical_knowledge`. The last two are "currently not utilized" (comment). The
stats *screen* also handles `v_available_points` and `v_max_stat`
(`stats.js:6–9`, 16 names incl. `available_points`/`max_stat`).

### 5.2 `varToStat` — variable → display label

`utils.js:114–127`: `v_agility` → `"Speed"`, `v_perception` → `"Observation"`,
else strip `v_`, split `_`, capitalise each part, join → e.g.
`v_ancient_languages` → `"AncientLanguages"`. Then `"stats" + name + "Text"` is
the `ui.json` key: `statsAncientLanguagesText` → `"Ancient languages"`.

### 5.3 `parseStatCheck(condition)` — `utils.js:135–173`

Given a condition atom already known to be true, returns
`{ variable, value, success }` or `undefined`.

| Atom form | Result | Rendered (via `mainStat{Success,Failed}Template`) |
|---|---|---|
| `v_b3_ch1_unlock == 2` | `{ variable:"v_b3_ch1_unlock", value:2, success:false }` — **special-cased first** (`utils.js:151`) | "[ Stat device locked - check failed ]" (unless scene is `B3-Ch01a-Crossbow`) |
| not in `stats_variables` | `undefined` (no check shown) | — |
| `v_x < N` | `{ success:false, value:N }` | "[ ‹Stat› check failed - level N ]" |
| `v_x == 0` | `{ success:false, value:1 }` | "[ ‹Stat› check failed - level 1 ]" |
| `v_x >= N` or `v_x == N` (N≠0) | `{ success:true, value:N }` | "[ ‹Stat› check successful - level N ]" |
| `v_x > N` | `{ success:true, value:N+1 }` | "[ ‹Stat› check successful - level N+1 ]" |
| `v_x <= N`, `v_x != N` | falls through → `success: undefined` → renders as **failed** | *(not used on stat vars in the corpus — scan confirms only `<`, `>=`, `==`, `>`)* |

### 5.4 `statChecksToDisplay(setVariables, values, localeData)` — `utils.js:181–208`

- Iterates the passed array (in `renderScene` it's
  `setVariables ∪ paragraphs ∪ choices`). Skips entries with no `conditions`.
- For each entry, keeps the condition **OR-groups that are fully true**
  (`utils.js:188`), then runs `parseStatCheck` on **every atom** of every kept
  group. So a stat atom anywhere in a *passing* condition of a *surviving*
  `set()`/paragraph/choice becomes a visible check line — not just `set()` lines.
  *(oracle-verified against the `ch3-vantage-*` fixtures.)*
- **De-dup** by `JSON.stringify` into a `Set` (`utils.js:196,202`), so
  `v_x > 2` and `v_x >= 3` (both → level-3 success) show once.
- **Stat-device lock filter** (`utils.js:204–206`): if any check is the
  `v_b3_ch1_unlock` lock, **all other checks are dropped** — only the "locked"
  line shows. *(oracle-verified.)*
- Label substitution (`utils.js:195`): `statCheck.variable` (already
  `varToStat`'d) is looked up in `localeData` unless it's the raw
  `v_b3_ch1_unlock`.

### 5.5 Stats screen (`renderStats` / `stats.ejs` / `stats.js`)

- Opened by the STATS header button or `special:stats`. `renderStats`
  (`renderers.js:94–103`) sets `maximized` = `v_current_scene === "Ch6-Eiden-vs-dragon"
  && v_maximized_stats_used === "1"` (a one-off "all stats max out in a rage"
  animation; also fires the `v_ac_ch6_immersion` achievement — `stats.ejs:175`).
- `stats.ejs` lays the stats out on a 2-column grid. `v_b3_ch11_magic` gates the
  magical-power/knowledge rows; `sceneAfter()` (book 3, chapter ≥ 4) gates
  bluff / magical sense / aura hardening (`stats.ejs:126–165`).
- `stats.js`: on first open, any of the 16 stat vars that is `null`/`undefined`
  is written as `0` (`v_max_stat` as `3`) and the page reloads
  (`stats.js:12–37`). `updateStat` / `confirmStats` spend `v_available_points`.
- A first-visit modal (`stats.ejs:197`) shows a mock success + fail check, gated
  by the `stats_intro_seen` **cookie**.

---

## 6. Achievements *(task 1.6)*

### 6.1 In-story unlock — `achievement("caption", v_ac_flag)`

- Parsed to `{ text, variable }` (`parser.js:71`), stored on the scene.
- `renderScene` keeps an achievement only if `cookieData[variable] === "1"`
  (strict string, `renderers.js:81`) — i.e. the modal shows on the single render
  right after the choice that set the flag to `"1"`.
- `main.ejs:66–83` renders each surviving achievement as
  `<script>storeVariable("v_ac_x","2")</script>` + a `.achievement-modal` toast
  (auto-dismiss 2 s) showing the fixed "ACHIEVEMENT UNLOCKED" header over
  `achievement.text`. The `"2"` write latches it "seen" so it never re-pops
  (`utils.js:31`). *(oracle-verified: flag `""`→0 modals, `"1"`→1 modal,
  `"2"`→0 modals; toast text = "A message in the sky".)*
- The in-story `achievement("…", v_ac_x)` string is the achievement **title**
  (matches `achievements*.json` `title`), **not** its longer menu `caption`.
- **`v_ac_b3_ch9_prize` is always-on** (`renderers.js:84`): if `== "1"` in any
  scene, a `{ text:"Consolation prize" }` achievement is appended. It's set when
  `v_ac_b3_ch9_consolation` reaches `5` (`utils.js:22–24`).

### 6.2 Achievements menu — `achievements{1,2,3}.json`

- One file per book. Top-level keys are **display groups**, mostly `b<book>ch<chapter>`
  but book 2 uses `b2ch41`/`b2ch42` and book 3 `b3ch61`/`b3ch62` (chapter split
  into two groups). Each entry:
  `{ title, caption, chapter, variable }`.
- Totals: book 1 = 35, book 2 = 48, book 3 = 53 → **136 achievements**.
- The menu (`renderers.js:126–148`, `achievements_menu*.ejs`) lists books →
  chapters → entries; the group-key regex `/b([0-9])ch([0-9]+)/`
  (`achievements_menu_chapter.ejs:2`) means `b2ch41` renders as "Chapter 41" — a
  known cosmetic quirk.
- An entry shows as unlocked when `(locals[achievement.variable] || 0) != "0"`
  (`achievements_menu_chapter.ejs:4`) — i.e. flag is `"1"` **or** `"2"`.
- The menu renders `title` + `caption`; the in-story toast renders only the
  `title` (§6.1).

---

## 7. `special:` hooks *(task 1.7)*

The `special:` tag on a choice changes which HTMX attributes `main.ejs:35–58`
emits. Corpus counts: `restart` 145, `saves` 145, `checkpoint_load` 144,
`checkpoint_save` 73, `stats` 13 (scan). **No bare `special:checkpoint`** —
CLAUDE.md's shorthand notwithstanding.

| `special:` | client action before the request | request | net effect |
|---|---|---|---|
| *(none)* | — | `POST /` with current state | render the choice's target scene (`v_current_scene` assignment) |
| `restart` | `clearState()` — wipe the `currentState` blob (`saves.js:1–3`) | `POST /` | fresh game; the choice also sets `v_current_scene = Ch1-Intro1` |
| `saves` | — | `POST /saves/0` with **all** localStorage | open the save/load screen |
| `stats` | — | `POST /stats` with current state | open the stat-allocation screen |
| `checkpoint_save` | `saveGameToLocalStorage('checkpoint')` — copy `currentState` → `checkpoint` slot, stamp `date`/`name` (`saves.js:27–44`) | `POST /` | save, then go to target (usually next chapter intro) |
| `checkpoint_load` | `loadGameFromLocalStorage('checkpoint')` — copy `checkpoint` slot → `currentState` (`saves.js:46–54`) | `POST /` | restore; target scene comes from the restored `v_current_scene` |

**Checkpoint banner** ("[ Checkpoint reached: Game saved. ]",
`ui.json:mainCheckpointReachedText`): shown when a **surviving** choice in the
current scene sets `v_checkpoint_rich = 0` (`renderers.js:87`, `main.ejs:5–9`,
rendered as a `stat_success` div). `v_checkpoint_rich`: `"0"` on the ordinary
"Continue" choice just after a checkpoint (136 lines carry it — mostly `= 0`);
`"1"` on the `special:checkpoint_save` "Next chapter" choices, which also set
`v_chapter_save_counter = 5` and `v_next_chapter_crash = 1`. The banner is
reassurance text — the actual persistent write is either the continuous
`currentState` autosave (every choice POST re-persists it client-side) or the
explicit `checkpoint_save`.

For a port, the equivalents are: `restart` = clear state + go to start;
`saves`/`stats` = open our own sub-screens; `checkpoint_save`/`checkpoint_load` =
write/read a dedicated checkpoint save; plus a continuous autosave of the live
variable map.

---

## 8. Saves & settings *(task 1.8)*

### 8.1 What the web build persists (all `localStorage`, LZ-String base64)

| Key | Contents | Written by |
|---|---|---|
| `currentState` | the live variable map minus `v_ac_*` | every choice (`storeVariable`/`setResponseVariables`), `clearState`, load |
| `achievements` | just the `v_ac_*` flags | `storeVariable` for `v_ac_` keys (`utils.js:29`) |
| `checkpoint` | a full `currentState` snapshot + `date` + `name` | `special:checkpoint_save` |
| `save0` … `save49` | full snapshot + `date` + `name` per slot (5 pages × 10) | the saves screen |
| `theme` | `"original-light" \| "original-dark" \| "catppuccin-light" \| "catppuccin-dark"` | `theme.js:handleThemeChange` |
| `stats_intro_seen` (cookie) | `"1"` once the stats intro modal is dismissed | `stats.ejs:209` |
| `fontsize` (cookie), `locale` (cookie) | `"<px>px"`, `"en" \| "fr"` | settings screen |

- **Save-slot shape** (`renderers.js:150–171`): a save is the entire variable
  map (`currentState`) with two extra keys `date` (UTC string) and `name`
  (defaults to the date, editable). The saves screen only *displays* `date` +
  `name`; loading replaces `currentState` wholesale.
- Read/write helpers: `readSaveFromLocalStorage` / `writeSaveToLocalStorage`
  (`saves.js:5–25`) — `JSON` → `LZString.compressToBase64`.
- Import/export = copy/paste the compressed blob (or plain JSON) via clipboard
  (`saves.js:107–186`).
- Migration: `migrateAchievements()` (`saves.js:188–199`) split `v_ac_*` out of
  `currentState` into their own blob (a one-time 0.9.4 change).

### 8.2 Settings

- **Theme** — 4 presets (2 palettes × light/dark), CSS-class + `color-scheme`
  swap (`theme.js`).
- **Font size** — a slider writing `--font-size` and a `fontsize` cookie,
  0.75×–1.25× of 16 px (`utils.js:41–66`, `settings.ejs:48–58`).
- **Language** — `en` / `fr` cookie, page reload (`language.ejs`).
- **Cheat mode** — sets `v_available_points` to 50 (`settings.ejs:44`).

For a port on KOReader: theme/font are the platform's job (KOReader has its own
font + night-mode); we need our own persistence for `currentState`, `checkpoint`,
save slots, achievements, and `locale`. Save-blob size and write frequency feed
[`04` §2–3](04-constraints-budget.md#2-magiums-demands-32).

---

## 9. Localization *(task 1.9)*

- **`data/locales.json`** — `{ "en": "English", "fr": "Français" }`. Drives which
  `data/<locale>/` dirs are loaded (`main_setup.js:48`) and the language menu.
- **`data/<locale>/ui.json`** — ~70 flat keys of UI strings, several of which are
  **EJS micro-templates**: `mainHeaderTemplate`
  (`"Book&nbsp;<%= book %> - Chapter&nbsp;<%= chapter %>"` / fr:
  `"Livre <%= book %> - Chapitre <%= chapter %>"`), `mainStatSuccessTemplate`,
  `mainStatFailedTemplate`, `achievementsMenuBookTemplate`,
  `achievementsMenuChapterTemplate`. A port needs a tiny `<%= name %>`
  interpolator or must pre-split these.
- **`getHeaderFromId(sceneId, headerTemplate)`** (`utils.js:28–36`): regex
  `/(B(?<book>[0-9]*)-)?Ch(?<chapter>[0-9]*)[a-c]?-.*$/` → `book` (default
  `"1"`), `chapter` (`parseInt`) → render the template. So `Ch3-Vantage` →
  "Book 1 - Chapter 3"; `B2-Ch07a-Intro` → "Book 2 - Chapter 7". Returns
  `undefined` if the id doesn't match (no header shown).
- **`data/<locale>/achievements{1,2,3}.json`** — same keys per locale, only
  `title`/`caption` translated.
- **`.magium` files**: en and fr are **structurally identical** — same 54
  filenames, same scene ids, same counts, same variables and conditions. See
  [`02` §5](02-magium-format-spec.md#5-en-vs-fr-divergence) and [F-08](#findings).
  **⚠️ Translation completeness (verified 2026-09-08, Phase VII):** the fr *prose*
  @ `51f5aa9` is a near-abandoned stub — only **`ch1.magium`** contains French
  text; 29/54 fr files are byte-identical to `data/en/` and the rest are English
  with minor structural drift. `ui.json` is fully French; `achievements*.json` is
  ~1 entry translated. The original §5 spot-checks counted `ID:` lines, not
  language.
- **Consequence for the port:** one engine + one "story logic", `N` prose
  bundles — i18n is a string-bundle swap, not a re-parse. But **as of `51f5aa9`
  there is no French prose bundle worth swapping to** (Phase VII implemented the
  swap, found this, and was rolled back — [roadmap Phase VII](09-roadmap-effort.md#phase-vii--localization-en--fr),
  running-log session 35).

---

## 10. Hardcoded scene-ID / variable special cases *(task 1.10)*

Every hand-coded exception in the engine and templates — a Lua port must
reproduce each:

| # | Where | Trigger | Behaviour |
|---|---|---|---|
| 1 | `renderers.js:53–55`, `main_setup.js:89–91` | `body.v_current_scene` absent | default to scene `"Ch1-Intro1"` |
| 2 | `renderers.js:76` | `id == "B3-Ch04a-Introduction2"` | `sceneData.statChecks = []` (hide checks in the Average-Joe reveal) |
| 3 | `renderers.js:84–86` | `v_ac_b3_ch9_prize == "1"` | append "Consolation prize" achievement in **any** scene |
| 4 | `renderers.js:87–89` | a surviving choice sets `v_checkpoint_rich === "0"` | `scene.checkpoint = true` → checkpoint banner |
| 5 | `renderers.js:96–98` | `v_current_scene === "Ch6-Eiden-vs-dragon" && v_maximized_stats_used === "1"` | stats screen plays the "maximised" count-up animation |
| 6 | `utils.js:151–153` | atom `v_b3_ch1_unlock == 2` | stat check → `{ success:false }`, label `v_b3_ch1_unlock` (stat-device-locked) |
| 7 | `utils.js:204–206` | any displayed check is the `v_b3_ch1_unlock` lock | drop **all** other stat checks |
| 8 | `main.ejs:17–19` | rendering the lock check **and** `v_current_scene != "B3-Ch01a-Crossbow"` | show `mainStatDeviceLockedText`; on `B3-Ch01a-Crossbow` show nothing |
| 9 | `stats.ejs:2` | `v_b3_ch11_magic` truthy | show magical-power / magical-knowledge rows (value = `v_b3_ch11_magic`) |
| 10 | `stats.ejs:126–132` | `sceneAfter(v_current_scene)` — book 3, chapter ≥ 4 | show bluff / magical-sense / aura-hardening rows |
| 11 | `stats.ejs:175`, `renderers.js:97` | `maximized` && `v_ac_ch6_immersion == 0` | unlock "Full immersion" achievement |
| 12 | `utils.js:22–24` (client) | `v_ac_b3_ch9_consolation == 5` | set `v_ac_b3_ch9_prize = 1` |
| 13 | `stats.js:25`, `stats.ejs` | stat var unset | default `0`, but `v_max_stat` defaults `3` |

---

## 11. Parsed-story size & memory footprint *(task 1.12)*

Measured 2026-08-31 by parsing all 54 English files in Node
(`../../reference/tools/measure-story-size.js`, and the corpus scan):

| Metric | Value | Note |
|---|---|---|
| Files | 54 | English only; French is a separate equal-size set |
| Disk size | 7.50 MB | raw `.magium` text, CRLF |
| Scenes | 2159 | flat global namespace, no duplicate ids |
| Paragraph objects | 4880 | one per parser paragraph (a `#if` block = 1) |
| Choices | 3734 | avg ~1.7 per scene; 1051 set ≥2 vars |
| `set(...)` directives | 594 | 466 conditional |
| `achievement(...)` | 145 | |
| `#if(){}` blocks | 2480 | never nested |
| Distinct condition variables | 318 | over 1034 distinct atoms |
| Fully-parsed objects (V8 heap) | ~17.4 MB | `confidence: medium` — V8 layout, not Lua |
| `JSON.stringify` of the whole story | 8.16 MB | ≈ a flat serialized form |
| Largest single line | ~490 KB | `b3ch4a.magium:251` — a 2044-clause DNF ([`02` §4 R7](02-magium-format-spec.md#4-parser-risk-list)) |

**Implications:**

- **Memory (confidence: medium):** holding the entire parsed story resident
  costs ~10–30 MB depending on Lua table overhead. The device has ~1 GB
  (~500 MB available); this fits comfortably. Spike D confirms the Lua number
  and cold-parse time rather than gating the approach
  ([`04` §3](04-constraints-budget.md#3-budget-table-33), OQ-001).
- **Parse cost (confidence: low):** 54 files, one regex-heavy pass, plus the one
  490 KB condition line. Needs timing on-device (spike B). If a cold parse blocks
  the UI too long, options are lazy per-chapter parsing or a build-time
  pre-compile ([`04` §4](04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34)).
- **Story scale rules out hand-authoring** — ~2160 scenes / ~3700 choices means
  any conversion approach (approach C/D) must be fully mechanical; a naive Twine
  export would be ~2160 passages (check tooling limits in spike C).

---

## Findings

- **F-01 (confidence: high):** `renderScene` is a pure function of the posted
  variable map — no server-side session — so `magium-dev` is a clean differential
  oracle. Method: [`../../reference/magium-dev-notes.md`](../../../reference/magium-dev-notes.md).
- **F-02 (confidence: high):** Variable values are strings everywhere (`"2"`, not
  `2`); conditions coerce via `parseInt` + JS `==`. A port must compare
  numerically (`tonumber`) or diverge on `v_x == 0` for unset vars.
- **F-03 (confidence: medium):** Story scale — ~2160 scenes / ~3700 choices —
  rules out any approach needing per-scene hand-authoring.
- **F-09 (confidence: high):** The engine is ~640 LOC over four files with no
  framework logic beyond Express routing. A Lua reimplementation is small and
  mostly mechanical; the effort is in (a) matching parser quirks
  ([`02` §4](02-magium-format-spec.md#4-parser-risk-list)) and (b) rebuilding the
  UI on KOReader widgets ([`03`](03-koreader-platform.md)), not in engine
  complexity.
- **F-10 (confidence: high):** Stat-check *display* is a render-time computation
  over the passing condition groups of surviving `set()`/paragraph/choice
  entries — not a parse-time property and not limited to `set()` lines. The four
  `parseStatCheck` branches (`<`, `== 0`, `>=`/`==≠0`, `>`) cover 100% of the
  corpus. *(oracle-verified.)*
- **F-11 (confidence: high):** There are **13 hand-coded special cases** (§10)
  spanning `renderers.js`, `utils.js` and the templates. They're small but
  parity-critical — a checklist item for the port and for spike B's diff.
- **F-12 (confidence: high):** Persistence is four blobs — `currentState`
  (continuous autosave), `checkpoint`, numbered save slots, `achievements` — each
  a full variable snapshot. The port must supply its own storage for these; theme
  and font belong to KOReader.
- **F-13 (confidence: high):** `magium-dev` navigates purely on the
  `v_current_scene` variable; `choice.target` is parsed but never read. Parity
  ports should treat `v_current_scene` as authoritative
  ([`02` F-05](02-magium-format-spec.md#findings)).
