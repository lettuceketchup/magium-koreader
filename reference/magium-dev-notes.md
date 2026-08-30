# Reference: magium-dev (the differential oracle)

- **Status:** stub (not started)
- **Last updated:** 2026-08-31
- **Phase:** 0
- **Sources:** `../magium-dev` @ `51f5aa9` — `README`, `package.json`, `src/main_setup.js`
- **Related:** [`../docs/research/01-magium-analysis.md`](../docs/research/01-magium-analysis.md)

> `magium-dev` is the known-good implementation. We run it locally and diff a
> Lua port's output against it for identical inputs.

## What it is

- Plain JS. Two entry points: an Express server (`main_node.js` → `src/main_setup.js`)
  and an Electron wrapper (`main_electron.js`).
- Story data loaded from `../magium-dev/data/<locale>/*.magium` + `achievements*.json` + `ui.json`.
- Core logic: `src/parser.js` (file → scenes), `src/utils.js` (conditions, stats,
  headers), `src/renderers.js` (scene → HTML via EJS templates in `templates/`).

## Running it *(task 0.3)*

```sh
cd ../magium-dev
npm install
npm run start:electron     # desktop app
# or
npm run start:server       # Express on :3000 (PORT env or argv[2] to change)
```

_(Confirm these work; note Node version, any install issues.)_

## Reaching an arbitrary scene

_(task 0.4 — the web build tracks state in `v_current_scene` + cookies. Document
how to POST a variable state to `/` and read back the rendered scene, or how to
drive the Electron UI. Goal: a repeatable "given this variable map, what text +
choices does scene X produce?" harness.)_

## Output-capture method

_(task 0.4 — script that, given a scene ID + variable map, emits normalized
text + ordered choice list, for diffing against a port. Store the script here.)_

## Notes

_(none yet)_
