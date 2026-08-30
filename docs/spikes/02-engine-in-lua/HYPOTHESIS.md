# Spike 02 — engine in Lua

- **Status:** done
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.2, "Spike B")
- **Sources:** `../magium-dev/src/parser.js`, `src/utils.js` @ `51f5aa9`; `reference/tools/oracle-diff.js` + its committed goldens
- **Related:** [`../../research-plan.md`](../../research-plan.md) task 5.2, [`OQ-008`](../research/07-risks-open-questions.md), [`FINDING.md`](FINDING.md), [spike 03](../03-full-corpus-memory-parse/FINDING.md) (reuses this parser on the full corpus)

## Question

Can the condition evaluator (`apply_condition`/`apply_conditions`) and the
scene parser be reproduced in Lua closely enough to match `magium-dev`'s
output exactly, for real story content — not a toy example?

## What "answered" looks like

- A Lua port of `parser.js:parse()` + the condition/stat-check slice of
  `utils.js`, run against real `.magium` files.
- Its output for a slice of scenes, diffed **structurally** against
  `magium-dev`'s own output for the same scene + variable-state inputs
  (the differential-oracle method from [`reference/magium-dev-notes.md`](../../reference/magium-dev-notes.md)),
  using the existing harness (`reference/tools/oracle-diff.js diff`) unmodified.
- Confirmed: every diffed case matches exactly (paragraphs, choices +
  their `setVariables`, stat-checks, achievements, checkpoint, header).
- Refuted: any structural mismatch that isn't explained by a deliberate,
  documented simplification.

## What will be built (throwaway)

- `magium_parser.lua` — line-by-line port of `parser.js:parse()`.
- `magium_utils.lua` — port of `apply_condition`/`apply_conditions`,
  `varToStat`, `parseStatCheck`, `statChecksToDisplay`, `getHeaderFromId`.
- `render_scene.lua` — port of `renderers.js:renderScene()`'s data pipeline
  (the 8-step filter/apply sequence that produces the scene's final shape),
  stopping short of actual EJS→HTML templating.
- `json.lua` — minimal JSON *encoder* (no decoder needed — see below).
- `spike_run.lua` — CLI: parses the 3 files holding the fixture scenes,
  renders `reference/tools/oracle-cases.json`'s 6 cases, writes canonical
  JSON per case.

## Scope note: bigger than "3 scenes"

The plan (`research-plan.md` 5.2) called for a 3-scene slice. The existing
6-case oracle fixture set already spans exactly 3 files
(`ch1.magium`, `ch3.magium`, `b2ch1.magium`) and **4** distinct scenes
(`Ch1-Intro1`, `Ch1-Cutthroat Dave` ×2 variable states, `Ch3-Vantage` ×2,
`B2-Ch01a-Intro`), so reusing it outright — rather than hand-picking a
smaller slice and writing new goldens — covers more ground for the same
effort and reuses an already-reviewed fixture set. See also
[spike 03](../03-full-corpus-memory-parse/) which runs this same parser,
unmodified, over the **full 54-file corpus**.
