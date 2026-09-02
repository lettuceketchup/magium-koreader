# Reference: magium-dev (the differential oracle)

- **Status:** stable (oracle + diff harness verified 2026-08-31)
- **Last updated:** 2026-08-31
- **Phase:** 0
- **Sources:** `../magium-dev` @ `51f5aa9` — `README`, `package.json`, `src/main_setup.js`, `src/renderers.js`, `src/parser.js`, `src/utils.js`, `templates/main.ejs`, `data/en/ui.json`; run locally with Node v24.11.0 on Windows
- **Related:** [`../docs/research/01-magium-analysis.md`](../docs/archive/research/01-magium-analysis.md)

> `magium-dev` is the known-good implementation. We run it locally and diff a
> Lua port's output against it for identical inputs.

## What it is

- Plain JS. Two entry points: an Express server (`main_node.js` → `src/main_setup.js`)
  and an Electron wrapper (`main_electron.js`).
- Story data loaded from `../magium-dev/data/<locale>/*.magium` + `achievements*.json` + `ui.json`.
- Core logic: `src/parser.js` (file → scenes), `src/utils.js` (conditions, stats,
  headers), `src/renderers.js` (scene → HTML via EJS templates in `templates/`).

## Running it *(task 0.3 — DONE)*

```sh
cd ../magium-dev
npm install                # ~715 packages; npm audit warns (dev-only, ignore for reference use)
node main_node.js 3006     # Express server on the given port (default 3000; PORT env or argv[2])
# or: npm run start:electron   (desktop app; needs a display)
```

Verified 2026-08-31 with **Node v24.11.0** on Windows. `npm install` succeeds
with vulnerability warnings in dev tooling only — harmless for using this as a
read-only oracle. Data auto-loads from `data/en/*.magium` on startup.

## Reaching an arbitrary scene *(task 0.4 — DONE)*

The server is stateless per request: **`POST /` with a JSON body = the full
variable map**, and it renders that scene. Key details from `src/renderers.js`:

- Scene shown = `body.v_current_scene`, or `Ch1-Intro1` if absent.
- Send header **`HX-Request: true`** to get just the scene fragment (prose +
  choice buttons + header). Without it you get the full page shell.
- Send header `Content-Type: application/json`.
- The response embeds each choice's `setVariables` in the button's `onClick`
  `setResponseVariables({...})` payload — that is the authoritative
  "what this choice does" data to diff against.

Example — reach `Ch1-Cutthroat Dave` on the "show myself" branch:

```sh
curl -s -X POST http://localhost:3006/ \
  -H "Content-Type: application/json" -H "HX-Request: true" \
  -d '{"v_current_scene":"Ch1-Cutthroat Dave","v_ch1_show_yourself":"2"}'
```

Note: variable **values are strings** in the body (`"2"`, not `2`) — matches how
the web client stores them and how `apply_condition` coerces.

## Output-capture / diff harness *(task 0.4 — DONE)*

[`tools/oracle-diff.js`](tools/oracle-diff.js) — no dependencies, uses Node's
global `fetch` (Node ≥ 18; tested on v24.11.0).

```sh
# 1. start the oracle
cd ../magium-dev && node main_node.js 3000

# 2. from the repo root — one scene to stdout:
node reference/tools/oracle-diff.js scene "Ch1-Intro1"
node reference/tools/oracle-diff.js scene "Ch3-Vantage" v_perception=2 v_ancient_languages=3

# 3. capture the whole fixture set (cases -> canonical JSON goldens):
node reference/tools/oracle-diff.js capture
#   reads  reference/tools/oracle-cases.json
#   writes reference/tools/oracle-capture/<name>.json + _index.json

# 4. diff port output vs. oracle goldens (file or dir, pairwise by name):
node reference/tools/oracle-diff.js diff reference/tools/oracle-capture <port-out-dir>
#   prints per-file ok/DIFF with a structural path diff; exit 1 on any mismatch
```

Base URL: `--base http://host:port` or `MAGIUM_ORACLE` env (default
`http://localhost:3000`).

**Canonical scene shape** (stable key order; every value a string, matching
`apply_condition`'s coercion):

```
{ sceneId, header, checkpoint,
  statChecks:   [ { success, text } ],          // "[ Observation check failed - level 1 ]"
  setVariables: [ { name, value } ],            // scene set() results, post-condition-filter, in order
  paragraphs:   [ string ],                     // one entry per parser paragraph object; <br/> runs kept
  choices:      [ { text, target, special, setVariables:{} } ],
  achievements: [ { variable, text } ] }
```

How it reads the render (mirrors `templates/main.ejs`): choices come from each
button's `onClick="setResponseVariables({...})"` payload (HTML-entity-decoded,
`JSON.parse`d — this is the authoritative "what the choice does"); `setVariables`
from the head-region `storeVariable(...)` scripts; checkpoint vs. stat-check by
matching `stat_success` inner text against `ui.json:mainCheckpointReachedText`;
paragraphs are the prose lines left after head markup is stripped.

**Fixture set** ([`tools/oracle-cases.json`](tools/oracle-cases.json), 6 cases):
opening scene, `#if` paragraph filtering + achievement modal + scene-id-with-a-space,
`choice(""quoted"")` text, two-stat-check scene, same scene with no stats (still
shows a *failed* check from `v_perception < 1`), and a checkpoint banner. Goldens
committed under `tools/oracle-capture/` — regenerate with `capture` after any
oracle bump and review the diff.

**Caveat:** the normalizer is coupled to `main.ejs` @ `51f5aa9`. If the oracle's
template changes, re-verify the six goldens by eye before trusting a green diff.

## Measurements taken 2026-08-31

Parsed the full English story in-process
([`tools/measure-story-size.js`](tools/measure-story-size.js) — `node --expose-gc reference/tools/measure-story-size.js`):

| Metric | Value |
|---|---|
| Files | 54 |
| Disk size (en) | 7.50 MB |
| Scenes | 2159 |
| Paragraphs | 4880 |
| Choices | 3734 |
| `set(...)` directives | 594 |
| Parsed objects, V8 heap delta | ~17.4 MB |
| `JSON.stringify(story)` length | 8.16 MB |

These feed [`../docs/research/01-magium-analysis.md`](../docs/archive/research/01-magium-analysis.md) §11
and [`../docs/research/04-constraints-budget.md`](../docs/archive/research/04-constraints-budget.md).
Lua table overhead differs from V8 — the real on-device number needs spike D.
