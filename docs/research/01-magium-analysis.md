# 01 — Magium engine analysis

- **Status:** stub (not started)
- **Last updated:** 2026-08-31
- **Phase:** 1
- **Sources:** `../magium-dev` @ `51f5aa9` — `src/parser.js`, `src/utils.js`, `src/renderers.js`, `src/main_setup.js`; live web build http://www.magium.org/menu
- **Related:** [`02-magium-format-spec.md`](02-magium-format-spec.md), [`00-overview.md`](00-overview.md), [design doc §3](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#3-target-definition-full-parity)

> Goal: a complete, source-grounded description of how the Magium engine behaves,
> so a Lua reimplementation can be checked against it. Every claim cites a line in
> `magium-dev` and, where behavior is observable, is confirmed against the running
> build (the differential oracle — see [`../../reference/magium-dev-notes.md`](../../reference/magium-dev-notes.md)).

## 1. Scene model *(task 1.1)*
_How `parser.js` turns a file into scene objects; parser quirks._

## 2. Variable store *(task 1.2)*
_`v_*` naming, types, default 0, `v_current_scene`, `v_checkpoint_rich`._

## 3. Condition evaluation *(task 1.3)*
_DNF structure, `apply_condition` operators, `"True"`, missing-variable behavior._

## 4. Scene-effect ordering in `renderScene` *(task 1.4)*
_setVariables filter → apply → choices filter → paragraphs filter → stat checks → achievements filter._

## 5. Stats system *(task 1.5)*
_14 stat variables, `parseStatCheck`, `statChecksToDisplay`, `v_b3_ch1_unlock` lock, de-dup._

## 6. Achievements *(task 1.6)*
_`achievements{1,2,3}.json` shape, per-book/chapter grouping, always-visible `v_ac_b3_ch9_prize`, `achievement(...)` gating._

## 7. `special:` hooks *(task 1.7)*
_`restart`, `saves`, `stats`, `checkpoint`; `special:checkpoint` / `v_checkpoint_rich == 0`._

## 8. Saves & settings *(task 1.8)*
_What the web build persists; save slot shape; theme/language/font settings._

## 9. Localization *(task 1.9)*
_`locales.json`, `ui.json`, `mainHeaderTemplate`, `getHeaderFromId` regex, en vs fr._

## 10. Hardcoded scene-ID special cases *(task 1.10)*
_Every `id == "..."` check in `renderers.js` and what it does._

## 11. Parsed-story size & memory footprint *(task 1.12 — partial)*

Measured 2026-08-31 by parsing all 54 English files in Node
(`../../reference/magium-dev-notes.md` → Measurements):

| Metric | Value | Note |
|---|---|---|
| Files | 54 | English only; French is a separate equal-size set |
| Disk size | 7.50 MB | raw `.magium` text |
| Scenes | 2159 | keyed by scene ID |
| Paragraphs | 4880 | after `#if` splitting |
| Choices | 3734 | avg ~1.7 per scene |
| `set(...)` directives | 594 | |
| Fully-parsed objects (V8 heap) | ~17.4 MB | `confidence: medium` — V8 object layout, not Lua |
| `JSON.stringify` of the whole story | 8.16 MB | ~= a flat serialized form |

**Implication (confidence: medium):** holding the entire parsed story resident
costs on the order of 10–30 MB depending on Lua table overhead. The target device
has ~1 GB RAM (~500 MB available), so this fits comfortably — **spike D** now just
confirms the Lua-side number and the cold-parse time, rather than gating the
approach ([`04-constraints-budget.md`](04-constraints-budget.md) §4, OQ-001).

## Findings

- **F-01 (confidence: high):** The `magium-dev` server is a pure function of the
  posted variable map — `POST /` with `{v_current_scene, ...}` renders that scene.
  This makes it a clean differential oracle. Method:
  [`../../reference/magium-dev-notes.md`](../../reference/magium-dev-notes.md).
- **F-02 (confidence: high):** Variable values are strings everywhere
  (`"2"`, not `2`); conditions coerce via `parseInt`. A port must match this or
  comparisons like `v_x == 0` on an unset var will diverge.
- **F-03 (confidence: medium):** Story scale — ~2160 scenes / ~3700 choices —
  rules out any approach that needs per-scene hand-authoring (e.g. a naive full
  Twine conversion would produce ~2160 passages; check tooling limits in spike C).
