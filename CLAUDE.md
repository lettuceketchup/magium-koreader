# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **feasibility study and design dossier** for porting *Magium* (a text-based CYOA
game) to run on a **Kindle Paperwhite 12th gen (2024) via KOReader** (owner's
device: FW 5.19.5, KOReader v2026.07.1 `kindlehf`, ~1 GB RAM). There is no
application code here yet and none should be added until the research phase
finishes and an implementation design is separately approved.

Current phase: **RESEARCH** (see `research-plan.md` for status).

## Orientation — read these first, in order

1. `README.md` — project intro and status.
2. `SUMMARY.md` — living "what we know so far": current conclusions + confidence.
3. `research-plan.md` — the executable phase/task checklist and the dated running log at its bottom.
4. `docs/superpowers/specs/2026-08-31-magium-koreader-research-design.md` — the governing design doc for this phase (scope, conventions, exit criteria).
5. `docs/decisions/` — ADRs: every decision that closed off an alternative, with reasoning.
6. `docs/research/07-risks-open-questions.md` — open questions (`OQ-NNN`), each tagged with where to get it answered.

## Reference implementations (sibling folders, not in this repo)

Two community recreations of Magium live next to this repo and are used for
analysis and differential testing. They are **not** vendored or submoduled —
reference them by relative path + commit hash.

- `../magium-dev` — **primary porting base & differential oracle.** Plain-JS/Electron,
  ~650 LOC engine (`src/parser.js`, `src/utils.js`, `src/renderers.js`) that parses
  human-readable `.magium` script files at runtime. Story data: `data/en/*.magium`
  (54 files, 7.7 MB), `data/en/achievements{1,2,3}.json`, `data/<lang>/ui.json`.
  License: MIT. Upstream: https://github.com/thuiop/magium-dev
- `../magium-recrystallized` — secondary reference. Svelte + Rust/WASM; compiles the
  story to a binary `.story` format (`wasm_module/`, `static/magium.story`).
  License: AGPL-3.0. Upstream: https://github.com/Br3nnabee/magium-recrystallized
- `../koreader` — **the target platform's source**, added in Phase 2. Sibling
  checkout pinned to release tag **`v2026.07.1`** (commit `9192014`) = exactly the
  build the owner runs. Cite by `../koreader/<path>:<line>` (same convention as
  `../magium-dev`). Setup + how to run the emulator on Windows:
  `reference/koreader-notes.md`. License: AGPL-3.0.

The MIT/AGPL split matters for what license the port can adopt — see
`docs/research/08-licensing.md`.

## How the Magium engine works (short version)

`.magium` files are line-oriented scripts. A scene starts with `ID: <SceneId>`,
followed by `TEXT:` and prose. Special constructs:

- `choice("label", TargetSceneId, var = value, ...)  [if <condition>]`
- `set(var, value) [if <condition>]` — scene side effects on the variable store
- `#if(<condition>) { ... }` — conditional paragraph blocks
- `achievement("text", v_flag)` — unlock display
- `special:restart | saves | stats | checkpoint` — inside a `choice(...)`

Conditions are DNF ("OR of ANDs"): `(a && b) || c`, each atom like `v_perception > 2`.
Evaluation reference: `../magium-dev/src/utils.js:apply_conditions`.
Scene header ("Book X - Chapter Y") is derived from the scene ID:
`../magium-dev/src/utils.js:getHeaderFromId`.

## Working conventions (enforced — see design doc §8)

- **Every doc** starts with the standard header block: Status / Last updated / Phase / Sources / Related.
- **Every non-obvious claim** carries an inline citation: code as `path:line` (add `@commit` if volatile); web links **must** include a `web.archive.org` capture; forum/Discord/Reddit links include author + date + a one-line quote.
- **Findings** carry `confidence: high | medium | low` + a one-line reason. `SUMMARY.md` never overstates its sources.
- **Decisions** that close an alternative → a new ADR in `docs/decisions/` (`ADR-NNN-slug.md`). Superseding = new ADR linking back; old one's status → `superseded`.
- **Open questions** live only in `07-risks-open-questions.md` as `OQ-NNN` rows; reference them by ID elsewhere, never restate.
- **Cross-links** are relative. Link to the specific section that establishes a fact instead of duplicating it.
- **Spikes** are throwaway. Each gets `docs/spikes/NN-slug/` with `HYPOTHESIS.md`, code, `FINDING.md`. Never promote spike code to production without a new approved phase.
- **After each work session**, append a dated entry to the running log at the bottom of `research-plan.md`.

## Doing research work

- Pick the current phase from `research-plan.md`. Produce/extend that phase's deliverable doc(s).
- Ground engine claims in `../magium-dev` source lines; verify behavior by running that project (see `reference/magium-dev-notes.md`) or the live web build at http://www.magium.org/menu.
- Anything that depends on real on-device KOReader behavior (memory, e-ink refresh, widget limits, deploy loop) needs a spike on the actual Paperwhite, not just documentation.
- Write for an outside contributor: docs should be shareable in isolation on Discord/Reddit/MobileRead.

## Git

- Branch `main`, no CI yet. Commit docs as they stabilize.
- Commit messages: what changed + which phase/doc + why. Reference `OQ-NNN` / `ADR-NNN` when relevant.
