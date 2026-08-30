# Spike 05 — `.magium` → Ink conversion

- **Status:** done
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.3, "Spike C")
- **Sources:** `../magium-dev/src/parser.js` @ `51f5aa9` (reused, not
  reimplemented); [`inkjs`](https://github.com/y-lohse/inkjs) `2.4.0`'s
  `inkjs/full` build (bundles a JS Ink compiler, not just the runtime)
- **Related:** [`../../research-plan.md`](../../research-plan.md) task 5.3,
  [`OQ-006`](../research/07-risks-open-questions.md),
  [`05-prior-art.md` §3](../research/05-prior-art.md#3-twine--ink--choicescript-players-on-constrained-hardware-43)
  (found no e-ink Ink player — this spike is about conversion *fidelity*
  only, not about running Ink on the Kindle), [`FINDING.md`](FINDING.md)

## Question

OQ-006: "Can `.magium` conditions/stats be faithfully represented in Twine
or Ink, or is fidelity lost?" Phase 4 already found no e-ink player exists
for either format (ruling out approach C on *deployability* grounds) and
flagged Ink over Twee as the better conversion target if this were spiked
anyway (MIT runtime, portable, no e-ink precedent either way). This spike
answers the narrower fidelity question that's left.

## What "answered" looks like

- One real chapter (`ch1.magium` — 12 scenes, 21 choices, 18 `#if` blocks,
  3 achievements, 4 `special:` hooks) converted to Ink source.
- The Ink source **compiles** with no errors, using `inkjs/full`'s
  in-process compiler (no external `inklecate` binary needed).
- Played through multiple choice paths and checked that conditional prose
  (`#if` blocks keyed on `v_ch1_show_yourself`/`v_ch1_intro_feeling`) selects
  the correct branch, that `set()`-equivalent assignments (`~ v_x = 1`)
  persist correctly across knots, and that the text matches the known-good
  oracle output for the same variable state.
- Every place fidelity is lost (achievements, `special:` hooks, cross-file
  navigation) is enumerated concretely, not just asserted in the abstract.

## What will be built (throwaway)

- `magium_to_ink.js` — converts one `.magium` file to Ink source, reusing
  `magium-dev`'s own parser (already validated — no reason to re-derive the
  grammar a third time, after spike 02's Lua port).
- `ch1.ink` — the conversion output (committed as the spike's artifact).
- `play_test.mjs` — a few scripted playthroughs via `inkjs/full`, checked by
  eye against `reference/tools/oracle-capture/ch1-dave-showmyself.json`.
