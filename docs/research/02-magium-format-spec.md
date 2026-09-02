# 02 — The `.magium` file format

- **Status:** stable (grammar + full corpus scan done 2026-08-31, construct counts reproducible via [`scan-magium-constructs.js`](../../reference/tools/scan-magium-constructs.js); the described grammar is what [spike 02](../spikes/02-engine-in-lua/FINDING.md)'s Lua parser was built and oracle-validated against)
- **Last updated:** 2026-08-31
- **Phase:** 1
- **Sources:** `../magium-dev` @ `51f5aa9` — `src/parser.js`, `src/utils.js`; all 54 files of `../magium-dev/data/en/*.magium`; `../magium-dev/data/fr/*.magium`; corpus scan [`reference/tools/scan-magium-constructs.js`](../../reference/tools/scan-magium-constructs.js) (run 2026-08-31, Node v24)
- **Related:** [`01-magium-analysis.md`](01-magium-analysis.md), [`00-overview.md`](00-overview.md), [`04-constraints-budget.md`](04-constraints-budget.md), [`07-risks-open-questions.md`](07-risks-open-questions.md)

> Goal: a precise description of `.magium` syntax **plus an exhaustive corpus of
> every construct actually used across all 54 English files**, flagging anything
> the reference parser's regexes would mishandle. This underpins both a Lua
> reimplementation and any format-conversion approach.
>
> The reference parser is `../magium-dev/src/parser.js` — 131 lines, one
> `readline` loop, five regexes. It is the definition of the format: there is no
> spec upstream, so "correct" means "what `parser.js` produces".

---

## 1. File & line structure

### 1.1 Encoding & line endings

- Files are UTF-8. `parser.js:24` reads them with `fs.createReadStream` (no
  encoding argument) piped into `readline`, which decodes as UTF-8.
- **All 54 English files use CRLF (`\r\n`) line endings** (corpus scan:
  `crlfFiles: 54`). `parser.js:28` sets `crlfDelay: Infinity`, so `readline`
  strips the `\r\n` cleanly. **A port that splits on `\n` itself must strip a
  trailing `\r`** or every line (and every parsed value / scene id) ends with an
  invisible carriage return. `.gitattributes` in this repo normalizes *our*
  files to LF, but the upstream data is CRLF.
- No BOM observed.

### 1.2 The line dispatch (`parser.js:36–118`)

The parser holds three pieces of state — `currentScene`, `currentParagraph`
(`{ text, conditions }`), and a boolean `skip` — and classifies each line by the
**first matching** rule in this order:

| # | Test (`parser.js`) | Effect |
|---|---|---|
| 1 | `line.startsWith("ID")` (`:37`) | flush previous scene; start a new scene `{ id, paragraphs:[], statChecks:[], setVariables:[], choices:[], achievements:[] }`. `id = line.split(": ")[1]` |
| 2 | `line.startsWith("TEXT")` (`:49`) | set `skip = true` (the next line — always blank — is swallowed) |
| 3 | `skip` is true (`:51`) | consume this one line, set `skip = false` |
| 4 | matches `RE_SET` (`:54`) | append a `setVariables` entry to the scene |
| 5 | matches `RE_ACH` (`:67`) | append an `achievements` entry to the scene |
| 6 | matches `RE_CHOICE` (`:76`) | flush `currentParagraph` if non-empty; append a `choices` entry |
| 7 | matches `RE_IF` (`:104`) | flush `currentParagraph` if non-empty; start a new `currentParagraph` carrying the `#if` condition |
| 8 | `line.startsWith("}")` (`:112`) | flush `currentParagraph` (unconditionally); reset it to `{ text:"", conditions: undefined }` |
| 9 | *(else)* (`:115`) | `currentParagraph.text += line + "<br/>"` |

Consequences that a reimplementation must copy exactly:

- **Rules 1 and 2 are `startsWith`, not exact matches.** Any line beginning with
  the literal `ID` becomes a scene header; any line beginning `TEXT` triggers the
  skip. No prose line in the corpus does this (scan checked), but it is a latent
  trap for future story edits — see §4.
- **Rules 4–7 are *unanchored* `String.match`.** The regex is tested against the
  whole line, so a *prose* line that merely *contains* `set(x,1)` or
  `choice("…", Foo, …)` would be silently converted into a directive and removed
  from the visible text. No corpus line triggers this today (scan:
  `set-like prose: []`, `choice-like prose: []`), but it is the single biggest
  fragility in the format — see §4.
- **`set()` and `achievement()` do *not* flush the current paragraph.** Prose
  before and after a `set()` line joins into **one** paragraph. Only `choice`,
  `#if`, and `}` split paragraphs.
- **Every prose line gets `<br/>` appended** (`:116`), including the last line
  before a flush. Paragraph text therefore always ends in `<br/>`. A blank prose
  line (rule 9 with `line === ""`) contributes a bare `<br/>` — **this is how
  vertical spacing between prose blocks is authored.**
- **The leading empty scene.** `currentScene` starts as `{}`. The first `ID:`
  line flushes that `{}` into `scenes`. After the loop, `parser.js:124` does
  `scenes.slice(1)` to drop it, then builds `scenes_dict[scene.id] = scene`.
  Net: every real scene is kept, keyed by its id; the `{}` sentinel is discarded.
- **Scene ids are a flat global namespace.** `main_setup.js:56` merges every
  file's `scenes_dict` into one object with `Object.assign`. Duplicate ids —
  within a file or across files — silently overwrite (last loaded wins). The
  corpus has **no duplicate ids** (scan: `duplicateSceneIds: []`). File load
  order is `glob` order (`main_setup.js:51`).

### 1.3 Scene ids

- `id = line.split(": ")[1]` — the substring after the first `": "`. A `": "`
  later in the id would truncate it; none occur.
- Ids **contain spaces**: `Ch1-Cutthroat Dave`, `Ch7-Summoner-vs-dwarf`. The
  scan found scene ids used as `choice` targets with internal spaces in 3 places.
- Observed shape: `[B<n>-]Ch<n>[a-c]-<Name>`, e.g. `Ch1-Intro1`,
  `B2-Ch07a-Intro`, `B3-Ch04a-Stats-spent`. The header derivation
  (`utils.js:getHeaderFromId`) only needs the `B<n>` / `Ch<n>` numbers — see
  [`01-magium-analysis.md` §9](01-magium-analysis.md#9-localization-task-19).
- The default / start scene is the literal `"Ch1-Intro1"`
  (`renderers.js:55`, `main_setup.js:91`).

---

## 2. Constructs

Grammar is given informally (the format has no formal spec); the regex from
`parser.js` is the authority and is quoted for each.

### 2.1 `choice(...)`

```
choice("<label>", <target>, <assignments>[, special:<hook>]) [if <condition>]
```

Regex (`parser.js:76–78`):

```js
/choice\("(?<text>.*)", (?<target>[\w\-\s]*), (?<setVariables>(\w* = [\w\-\s+]*(, )?)*)((, )?special:(?<special>.*?))?\)( if (?<condition>.*))?/
```

Parsed into `{ text, target, setVariables:{…}, special, conditions }`
(`parser.js:97–103`).

- **`text`** — `.*` is **greedy**. It backtracks from the end of the line to the
  last `", "` that is followed by a valid `target, assignments…` tail. This is
  deliberate and correct: it lets choice labels contain `"` and `", `.
  - **Doubled quotes**: `choice(""I see no reason to hide."", Ch1-Cutthroat Dave, …)`
    parses to `text = "I see no reason to hide."` (the outer quote of the pair is
    the delimiter, the inner one is literal). **809 of 3734 choices** use the
    `choice(""…"")` form (scan: `choiceDoubleQuotedText: 809`) — it is the normal
    way to write a choice whose label is a spoken line.
- **`target`** — `[\w\-\s]*`: word chars, hyphen, whitespace. May be **empty**
  (`choice("Load game", , , special:saves)`): **289 of 3734** choices have an
  empty target (scan: `choiceEmptyTarget: 289`) — exactly the choices that hand
  off to a sub-screen (`special:saves`, `special:stats`, some
  `special:checkpoint_load`).
  - **⚠ `target` is dead data in `magium-dev`.** Nothing in `renderers.js` or the
    templates reads `choice.target`. Navigation is driven **entirely** by the
    `v_current_scene` assignment inside `setVariables` (see
    [`01-magium-analysis.md` §2](01-magium-analysis.md#2-variable-store-task-12)).
    Every non-`special` choice in the corpus carries
    `v_current_scene = <target>` explicitly (scan:
    `choiceNoAssignments: 145` — and all 145 are `special:restart`). A port may
    key navigation off `target` *or* off `v_current_scene`; they agree wherever
    both exist, but only `v_current_scene` is load-bearing upstream.
- **`assignments`** — zero or more `v_name = value`, comma-space separated.
  `[\w\-\s+]*` for the value side, so values may contain spaces (scene ids) and
  a leading `+`/`-`. Split by `", "` then each half by ` = ` (`parseAssignment`,
  `parser.js:4–11`). Distribution: 145 choices set nothing, 2538 set exactly one
  variable, **1051 set two or more** (scan). Assignment order is preserved in
  the parsed object but stored as a plain object, so a repeated key would collapse
  (none observed).
- **`special:<hook>`** — optional trailing tag, `.*?` (lazy). The five values in
  the corpus (scan: `choiceSpecialValues`):

  | `special:` value | count | what it does (web UI) |
  |---|---|---|
  | `restart` | 145 | clears saved state, returns to `Ch1-Intro1` |
  | `saves` | 145 | opens the save/load screen |
  | `checkpoint_load` | 144 | restores the `checkpoint` slot into current state |
  | `checkpoint_save` | 73 | writes current state to the `checkpoint` slot |
  | `stats` | 13 | opens the stat-allocation screen |

  Behaviour is in `templates/main.ejs:35–58` (which `hx-*` attributes and
  `hx-on::before-request` handler each value wires up) — detailed in
  [`01-magium-analysis.md` §7](01-magium-analysis.md#7-special-hooks-task-17).
  **Note:** the CLAUDE.md quick-reference lists `special:checkpoint`; the data
  actually uses `checkpoint_load` / `checkpoint_save`. There is no bare
  `special:checkpoint`.
- **`if <condition>`** — optional. In the source the condition is **always**
  wrapped in one pair of parens: `… ) if (v_ch2_deer_interaction != 1)`. The
  regex group captures `(v_ch2_deer_interaction != 1)` *including* the parens;
  `parseConditions` then strips the first `(` and first `)` (§2.5). 1019 of 3734
  choices are conditional (scan: `choice() if: 1019`).

### 2.2 `set(var, value) [if <condition>]`

Regex (`parser.js:54–56`):

```js
/set\((?<varName>.*),(?<value>[+\-]?[0-9])\)( if (?<condition>.*))?/
```

Parsed into `{ name, value, conditions }` and pushed to `scene.setVariables`
(`parser.js:61–65`).

- **`value` is a single character: `[+\-]?[0-9]`.** One optional sign, one digit.
  `set(v_x, 10)` would mis-parse (`varName` greedily eats `v_x,1`, `value` = `0`).
  **No corpus `set()` uses a multi-digit literal** (scan: `unparsed set()` is
  empty and every captured value is one digit). Observed values (scan
  `setValues`): `0` ×254, `1` ×298, `2` ×14, `3` ×8, `4` ×3, `5` ×5, `6` ×1,
  `7` ×1, plus the **relative** forms `+1` ×4, `+3` ×4, `-3` ×2.
- **Relative values (`+N` / `-N`)** are *not* resolved by the parser — the value
  string `"+3"` is stored verbatim. They are applied later, client-side, by
  `storeItem` (`public/scripts/utils.js:13–18`): `+N` → `current + N`, `-N` →
  `current - N`, anything else → literal assignment. A port's variable-store
  writer must implement the same `+`/`-` prefix rule. 10 `set()` lines total use
  it (scan: `setRelativeValues: 10`); the same prefix convention also applies to
  `choice` assignments and is where `v_ac_*` counters like
  `v_ac_b3_ch9_consolation` get incremented.
- **`varName`** — `.*` greedy up to the last `,` before the value+`)`. Names are
  `v_*` by convention (see §2.5).
- **594 `set()` lines**, of which **466 are conditional** (scan). An
  unconditional `set()` (`conditions === undefined`) always fires when the scene
  renders (`renderers.js:58–60` via `apply_conditions(undefined, …)` → `true`).
- `set()` lines do **not** split paragraphs (§1.2).

### 2.3 `#if(<condition>) { … }`

Regex (`parser.js:104`): `/#if\((?<condition>.*)\)/`. The matching `}` is
detected by `line.startsWith("}")` (`parser.js:112`).

- Opens a conditional **paragraph block**: `currentParagraph` is flushed, then a
  fresh one is started with `conditions` set. Lines until the next `}` accumulate
  into that paragraph's `text`. `}` flushes it and clears the condition.
- **Never nested** (scan: `ifNestedMax: 1`). `#if` count == `}` count == **2480**
  exactly (scan) — every block is balanced and flat. A port can treat `#if`/`}`
  as a non-recursive open/close pair.
- The condition here is **not** paren-wrapped in the source
  (`#if(v_agility < 2 && v_strength < 3) {`), unlike the `if (…)` suffix on
  `set`/`choice`. `parseConditions`' `.replace("(","")` / `.replace(")","")` are
  therefore no-ops for `#if` conditions.
- **`#if(False) {`** appears once (`b3ch5a.magium:193`) — a deliberately disabled
  block. `False` is not a recognised atom, so `apply_condition` returns
  `undefined` → the block is never shown. Verified against the running oracle
  2026-08-31 (the block's text does not appear in the rendered scene).
- Empty `#if` blocks (open then immediately `}`) push a `{ text:"", conditions }`
  paragraph; harmless (renders as nothing).
- A `}` with no preceding `#if` still runs rule 8 — it flushes whatever prose had
  accumulated and resets. No corpus line does this.

### 2.4 `achievement("<text>", <variable>)`

Regex (`parser.js:67`): `/achievement\("(?<text>.*)",(?<variable>.*)\)/`.
Parsed into `{ text, variable }` (`parser.js:71–74`). Note: **no space** after
the comma (contrast `choice(`, which requires `", "`).

- **145 lines** across the corpus (scan). `variable` is a `v_ac_*` flag.
- Display is gated at render time: the achievement modal shows **only if
  `cookieData[achievement.variable] === "1"`** (`renderers.js:80–82`) — i.e. the
  flag must be exactly the string `"1"` in the current variable state, which
  happens on the render immediately after the choice that set it. Detail and the
  `v_ac_b3_ch9_prize` always-on special case:
  [`01-magium-analysis.md` §6](01-magium-analysis.md#6-achievements-task-16).
- `text` here is the achievement **title** (it matches the `title` field in
  `achievements{1,2,3}.json`, e.g. `achievement("A message in the sky",
  v_ac_ch3_message)`), rendered in the toast's caption slot beneath the fixed
  "ACHIEVEMENT UNLOCKED" header (`main.ejs:66–83`). The longer `caption` string
  in the JSON is only used by the achievements *menu*. *(oracle-verified.)*

### 2.5 Conditions

Grammar:

```
condition   :=  or_clause ( " || " or_clause )*
or_clause   :=  atom ( " && " atom )*
atom        :=  <varName> " " <op> " " <integer>   |   "True"
op          :=  "<" | ">" | ">=" | "<=" | "==" | "!="
```

- **DNF only** — an OR of ANDs, no other nesting. `parseConditions`
  (`parser.js:13–21`) does exactly: `.replace("(","").replace(")","")`, then
  `.split(" || ")`, then map `.split(" && ")`. Result is `string[][]` — outer =
  OR, inner = AND. Whitespace around operators is **mandatory and exact** (single
  spaces); the atom regex (`utils.js:63`) is
  `/(?<varName>\w*) (?<condType><|>|>=|==|<=|!=) (?<value>[0-9]+)/`.
- **Parens are cosmetic and single.** Across the whole corpus, no condition
  string contains more than one `(` or more than one `)` (scan:
  `conditionMultiParen: []`). Every `if (…)` suffix contributes exactly one
  outer pair, which `parseConditions` strips. So the naive single-`replace` is
  safe *for this data* — but it would corrupt any future condition with a second
  paren.
- **Operators used** (scan `conditionOperators`, ~29.7k atoms total):
  `==` 16481, `>` 9301, `!=` 1724, `<` 1290, `>=` 873, `<=` 21. All six occur;
  `<=` is rare but real.
- **`True`** literal: handled by `apply_condition` (`utils.js:59`) but **never
  used** in the corpus (scan: `conditionTrueLiteral: 0`). **`False`**: not
  handled (treated as an unparseable atom → falsy); used once (§2.3).
- **Missing / unset variable** → treated as `0`: `(values[variable] || 0)`
  (`utils.js:70–75`). Comparisons use JS `==`/`!=` after `parseInt` on the
  literal, so `"3" == 3`. A Lua port must `tonumber()` both sides (values are
  stored as strings — see [`01` §2](01-magium-analysis.md#2-variable-store-task-12)).
- **Unparseable atom** → `apply_condition` logs `"Condition fail"` and returns
  `undefined` (falsy). In `apply_conditions` that fails the enclosing AND-clause.
  A port should treat an unrecognised atom as **false**, silently.
- Scale: **1034 distinct atom strings** over **318 distinct variables** (scan).
  Largest single condition: **2044 OR-clauses, ~490 KB on one line** — see §4.

---

## 3. Construct corpus *(task 1.11)*

Generated by [`reference/tools/scan-magium-constructs.js`](../../reference/tools/scan-magium-constructs.js)
over `../magium-dev/data/en/*.magium` @ `51f5aa9`, 2026-08-31. Re-run and diff
after any upstream data change.

| Construct | Count | Notes / corpus facts |
|---|---:|---|
| Files | 54 | all CRLF; French mirror set is structurally identical (§5) |
| `ID:` scenes | 2159 | flat global namespace, no duplicate ids |
| `TEXT:` + swallowed blank | 2159 | exactly one blank line after each `TEXT:` |
| prose lines (rule 9) | 74064 | each becomes `text + "<br/>"`; blank prose line ⇒ bare `<br/>` |
| `set(name, value)` | 594 | 128 unconditional, 466 `… if (…)` |
| — value `0` / `1` | 254 / 298 | the overwhelming majority |
| — value `2`–`7` | 32 | small multi-level bumps |
| — relative `+1` / `+3` / `-3` | 4 / 4 / 2 | resolved client-side by `storeItem`, not the parser |
| `achievement("cap", v_ac_x)` | 145 | comma has **no** trailing space |
| `choice("label", target, …)` | 3734 | avg ~1.7 per scene |
| — `choice(""spoken"")` doubled-quote label | 809 | normal form for dialogue choices |
| — empty target | 289 | all are sub-screen hand-offs |
| — target contains a space | 3 | e.g. `Ch1-Cutthroat Dave` |
| — 0 / 1 / ≥2 assignments | 145 / 2538 / 1051 | |
| — `… if (…)` | 1019 | |
| — `special:restart` | 145 | |
| — `special:saves` | 145 | |
| — `special:checkpoint_load` | 144 | |
| — `special:checkpoint_save` | 73 | |
| — `special:stats` | 13 | |
| `#if(cond) {` … `}` | 2480 / 2480 | balanced, **never nested** |
| — `#if(False)` | 1 | permanently hidden block (`b3ch5a.magium:193`) |
| distinct condition atoms | 1034 | over 318 distinct `v_*` variables |
| condition operators | `==`,`>`,`!=`,`<`,`>=`,`<=` | all six; `<=` only 21× |
| `True` / `False` literal | 0 / 1 | `True` supported but unused; `False` unsupported, used once |
| conditions with >1 paren | 0 | naive `parseConditions` is safe for this data |
| max OR-clauses in one condition | 2044 | `b3ch4a.magium:251`, ~490 KB (§4) |
| max AND-terms in one clause | 15 | |

---

## 4. Parser risk list

Cases where `parser.js` / `utils.js` are fragile. None is *currently* triggered
by the corpus (the scan checks each), but each is a real hazard for a port, for
future story edits, or for a format-conversion tool.

| # | Risk | Where | Corpus status | Impact on a port |
|---|---|---|---|---|
| R1 | **Unanchored construct regexes.** A prose line containing `set(x,1)`, `choice("…", Foo, …)`, `achievement("…",v)` or `#if(…)` is silently turned into a directive and vanishes from the visible text. | `parser.js:54,67,76,104` (`line.match`, no `^`) | clean (`set-like prose: []`, `choice-like prose: []`) | Port should **anchor** these to the start of the (trimmed) line. Flag if a future upstream diff adds such prose. |
| R2 | **`startsWith("ID")` / `startsWith("TEXT")`.** Any line beginning with those two letters is a scene break / skip trigger. | `parser.js:37,49` | clean | Anchor to `ID: ` / `TEXT:` exactly. |
| R3 | **`set()` value is one digit.** `set(v_x, 12)` mis-parses to `varName="v_x,1", value="0"` with no error. | `parser.js:55` `[+\-]?[0-9]` | clean (no multi-digit) | Port can keep the 1-digit rule but should **assert** on a longer literal rather than silently truncate. |
| R4 | **`parseConditions` strips only the first `(` and `)`.** A condition with a real nested group (`(a && b) || (c && d)`) would be mangled. | `parser.js:15–17` | clean (0 conditions with >1 paren) | A port's condition parser should handle balanced parens properly, or assert single-pair. |
| R5 | **Exact-whitespace conditions.** Atoms must be `var<SP>op<SP>int`; `&&`/`||` must be `<SP>&&<SP>` / `<SP>||<SP>`. A double space or tab breaks the atom regex → clause silently false. | `utils.js:63`, `parser.js:19` | clean | Port should normalise whitespace before splitting, or match the brittleness deliberately and diff against the oracle. |
| R6 | **Silent failure modes.** Unknown atom, unmatched `set`, bad choice → `console.log` + `undefined`/skip, never an exception. Bugs hide. | `utils.js:78`, `parser.js` else-fallthrough | 1 known (`#if(False)`) | Port should log/count anomalies loudly during development, then match the silent behaviour in release. |
| R7 | **The 490 KB condition line.** `b3ch4a.magium:251` — `choice("Continue", B3-Ch04a-Avg-Joe-Invested2, …) if (<2044-clause DNF>)`. Several sibling `B3-Ch04a-Avg-Joe-Invested{1..4}` choices in scene `B3-Ch04a-Stats-spent` carry similar pre-expanded DNFs; this one line is 81% of the 605 KB file. | `b3ch4a.magium:202–260` | present, parses fine | **Performance:** re-splitting a ~490 KB string and evaluating up to 2044×15 atoms every time that scene renders is a concrete cost on the Kindle CPU. Options: cache the parsed condition, pre-compile the data (approach D), or special-case the Average-Joe check. Feeds [`04-constraints-budget.md`](04-constraints-budget.md) and spike B. |
| R8 | **`target` vs `v_current_scene` divergence.** If a port navigates by `choice.target` it will disagree with `magium-dev` anywhere the two differ; only `v_current_scene` is load-bearing upstream. | `renderers.js` (never reads `.target`) | agree wherever both present | Pick `v_current_scene` as the source of truth for parity; treat `target` as a hint/label. |
| R9 | **Global scene namespace, last-wins.** Cross-file id collisions overwrite silently. | `main_setup.js:56` | no collisions | Port should assert uniqueness on load. |
| R10 | **CRLF everywhere.** | upstream data | all 54 files | Strip `\r` when reading lines manually. |

---

## 5. en vs. fr divergence

- **File sets are identical** — same 54 filenames in `data/en/` and `data/fr/`
  (scan / `diff`).
- **Scene structure matches** — spot-checked `ch1` (12 scenes each), `ch3` (91),
  `b2ch1` (47), `b3ch12b` (46): identical `ID:` counts, so the branching graph
  and variable logic are shared. Scene ids, variable names, conditions, `set()`
  targets and values are language-independent (they're code, not text).
  Re-verified 2026-09-08: all 54 fr files parse and their scene-ID sets equal en
  file-for-file.
- **⚠️ But the fr prose is barely translated** (checked 2026-09-08, Phase VII —
  the §-note spot-checks above counted `ID:` lines, never checked the *language*
  of the prose). @ `51f5aa9`: **only `ch1.magium` has French text**; 29/54 fr
  files are byte-identical to `data/en/`, the rest are English with minor
  structural drift (e.g. `ch2.magium` → *"Both Daren and I turn around…"*). A
  byte scan for UTF-8 `é` across `data/fr/*.magium` matches exactly one file.
  `ui.json` is fully French; `achievements*.json` ~1 entry. The fr set is a
  stub, not a French edition.
- **`ui.json` differs** per locale, including the header template:
  `"Book&nbsp;<%= book %> - Chapter&nbsp;<%= chapter %>"` (en) vs
  `"Livre <%= book %> - Chapitre <%= chapter %>"` (fr) — note the en template
  uses `&nbsp;`, the fr one plain spaces.
- **`achievements{1,2,3}.json`** exist per locale with matching keys; only
  `title` / `caption` are translated.
- Implication for a port: **one engine + one set of `.magium` "logic", `N` prose
  bundles.** A conversion approach could even diff en vs fr to mechanically
  separate structure from translatable text. See
  [`01-magium-analysis.md` §9](01-magium-analysis.md#9-localization-task-19).

---

## Findings

- **F-04 (confidence: high):** The format is tiny and regular — 5 regexes, DNF
  conditions, no nesting beyond a flat `#if`/`}` pair. A faithful Lua parser is a
  small, mechanical job; the risk is in matching `parser.js`'s *quirks* (§4), not
  its complexity. Verified by full-corpus scan + oracle spot-checks 2026-08-31.
- **F-05 (confidence: high):** Navigation is driven by the `v_current_scene`
  variable assignment in a choice's `setVariables`, **not** by the `target`
  field, which `magium-dev` never reads. A parity port must treat
  `v_current_scene` as authoritative.
- **F-06 (confidence: high):** `choice(""spoken line"")` (doubled outer quotes)
  is not an edge case — 809 of 3734 choices use it. The greedy `text` capture
  handles it; a hand-rolled non-greedy parser would break on it.
- **F-07 (confidence: medium):** One auto-generated 490 KB condition line
  (`b3ch4a.magium:251`, 2044 OR-clauses) is a concrete per-render performance
  hazard on the target device. Needs measurement in spike B; may force
  condition-caching or a build-time pre-compile step (approach D). Feeds
  [`04-constraints-budget.md`](04-constraints-budget.md) and OQ-001.
- **F-08 (confidence: high for *structure*; the *content* half was wrong):** the
  en and fr scene graph, variables and conditions are shared — i18n for the port
  is mechanically "swap the string bundle", not "reparse a different story", and
  this was re-verified 2026-09-08. **However**, the original claim that fr "only
  differs in translated prose and labels" implied a *complete* translation; in
  fact @ `51f5aa9` the fr `.magium` prose is a stub (1/54 files — see §5). Phase
  VII built the bundle-swap, hit this, and was rolled back
  ([roadmap Phase VII](09-roadmap-effort.md#phase-vii--localization-en--fr)).
