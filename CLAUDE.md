# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A port of *Magium* (a text-based CYOA game) to run on a **Kindle Paperwhite 12th
gen (2024) via KOReader** (owner's device: FW 5.19.5, KOReader v2026.07.1
`kindlehf`, ~1 GB RAM).

**The research phase is complete** — feasibility confirmed, approach chosen
(standalone KOReader plugin, Lua reimplementation of the `magium-dev` engine —
[ADR-002](docs/decisions/ADR-002-porting-approach.md)), and the design dossier it
produced lives under `docs/`. The game code is the KOReader plugin in
`magium.koplugin/`.

Current phase: **FEATURE-COMPLETE** — Phase VIII (final) merged 2026-09-08,
tag `v1.0`; Phases I–VI + V.5 all shipped with owner on-device sign-off; Phase
VII (fr localization) built + shelved on upstream content (`phase-vii-shelved`).
Every research OQ is closed or deferred. Work now is **maintenance** — bug
fixes, and any polish the owner asks for. Non-blocking follow-ups: Phase VII
(needs a real fr `.magium` set), Phase 7 licensing ([ADR-003](docs/decisions/ADR-003-defer-licensing-distribution.md),
only if distribution is considered), a GC post-release watch. See the running
log in `research-plan.md` and the roadmap in
`docs/research/09-roadmap-effort.md`.

## Orientation — read these first, in order

1. `docs/specs/2026-08-31-plugin-architecture-and-phase-i.md` — **the implementation spec**: module map, data-shape contracts, the 12-step `scene.render` pipeline, phase roadmap. This is the authority when a plan step conflicts with it.
2. `magium.koplugin/` — the plugin itself: `engine/` (pure Lua, no KOReader deps, oracle-tested), `ui/` (KOReader widgets), `save/`, `main.lua` glue, `spec/` (busted tests).
3. `research-plan.md` — dated running log at the bottom (newest first) — the live status of the build.
4. `docs/decisions/` — ADRs: every decision that closed off an alternative, with reasoning.
5. `SUMMARY.md` — the research conclusions + confidence tags (background; research is done).
6. `docs/research/09-roadmap-effort.md` — the phased implementation roadmap.

## Workflow skills — invoke these, don't re-derive

Three project skills capture the repeating procedures. Use them instead of
reconstructing the steps from this file, the running log, or memory:

- **`phase`** — run an implementation phase end to end: pick it, brainstorm,
  spec, branch, implement, verify, owner device sign-off, merge, log.
- **`verify`** — the test-gate decision matrix for a change: which of `busted` /
  `oracle-corpus` / `test-ui` / `emu-smoke` to run, what green means, how to
  triage a failure.
- **`device`** — deploy to the owner's Kindle and pull `crash.log` + save state
  when a device bug comes back.

This file keeps only the *rules* that outlive the tooling; the *how* is in the
skills.

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

## Working style (enforced)

- **Use `ponytail` for most coding tasks** — writing, adding, refactoring,
  fixing, reviewing code, and choosing dependencies. Laziest solution that
  actually works: stdlib and KOReader-native before custom code, one line before
  fifty, question whether the code needs to exist. (Not for pure docs/prose.)
- **Do not use subagents for large tasks.** Handle multi-step / multi-file work
  inline in the main session. (Subagents on an explicit user request only.)
- **Keep doc updates cheap.** If updating the docs for a change would cost more
  than ~20% of the run's token budget, trim it: update only the running log +
  the one or two docs that would otherwise be *wrong*, batch the edits, keep them
  terse. Code is the priority; the dossier is background now.

## Working conventions (dossier — see design doc §8)

- **Every doc** starts with the standard header block: Status / Last updated / Phase / Sources / Related.
- **Every non-obvious claim** carries an inline citation: code as `path:line` (add `@commit` if volatile); web links **must** include a `web.archive.org` capture; forum/Discord/Reddit links include author + date + a one-line quote.
- **Findings** carry `confidence: high | medium | low` + a one-line reason. `SUMMARY.md` never overstates its sources.
- **Decisions** that close an alternative → a new ADR in `docs/decisions/` (`ADR-NNN-slug.md`). Superseding = new ADR linking back; old one's status → `superseded`.
- **Open questions** live only in `07-risks-open-questions.md` as `OQ-NNN` rows; reference them by ID elsewhere, never restate.
- **Cross-links** are relative. Link to the specific section that establishes a fact instead of duplicating it.
- **Spikes** are throwaway. Each gets `docs/spikes/NN-slug/` with `HYPOTHESIS.md`, code, `FINDING.md`. Never promote spike code to production without a new approved phase.
- **After each work session**, append a dated entry to the running log at the bottom of `research-plan.md`.

## Doing implementation work

- Work from the spec (`docs/specs/2026-08-31-plugin-architecture-and-phase-i.md`)
  and the roadmap (`docs/research/09-roadmap-effort.md`); the spec is the
  authority when a plan step conflicts with it. Pick the current phase from the
  `research-plan.md` running log.
- `engine/` is **pure Lua, no KOReader deps** — develop and test it on the
  desktop against the `magium-dev` differential oracle (`magium.koplugin/spec/`,
  `reference/tools/oracle-diff.js`). `magium-dev` @ its recorded commit is the
  behavioral reference for every engine question.
- `ui/` needs the KOReader emulator (WSL2, see `reference/`) or the device. No
  hot reload: copy to `koreader/plugins/`, restart, read `koreader/crash.log`.
- **Every `ui/` change is emulator-verified and lands an automated check —
  a `spec/ui/*_smoke.lua` (real `paintTo` for every state realistic data can
  reach, not just structural asserts) and/or a `spec/flow/*` — before the
  owner is asked to test on device.** The device pass confirms e-ink feel and
  real input, never that the code works or that a screen renders.
  → **`verify`** and **`device`** skills.
- **The test commands** (all `wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh <cmd>'`):
  `test` (full busted — pure engine/save/flow + the app-level E2E
  `spec/save/schema_compat_spec.lua` / `navigation_spec.lua` integrity block);
  `test-ui` (fast dummy-600×800 smoke pass, "doesn't crash");
  `test-ui-real` (xvfb + real 1272×1696 @300dpi via `spec/support/real_screen.lua`
  — proves layout, **the gate before a device pass / merge**);
  `oracle-corpus` (per-scene render parity vs magium-dev, only when a render
  path could change); `emu-smoke` (plugin still loads).
- **Every regression suite that exists is run and updated by every later phase
  or change, not just the one that added it** — `test`, `test-ui` /
  `test-ui-real`, `oracle-corpus`, and the Phase V.5 additions
  (`spec/ui/main_e2e_smoke.lua`, the `navigation_spec.lua` achievements-integrity
  block, `spec/save/schema_compat_spec.lua` + its `fixtures/save_v1.lua`).
  A behavior change that doesn't update the test asserting the old behavior is
  incomplete. → **`verify`** skill.
- Still-open items that need device time or code are tracked as roadmap work, not
  `OQ-NNN` (see `docs/research/07-risks-open-questions.md` blocking-status note).

## Git

- Branch `main`, no CI yet. Feature work on a `feat/…` branch; never commit straight to `main` unasked.
- Commit messages: what changed + which phase/task + why. Reference `ADR-NNN` when relevant.
- Full phase lifecycle (spec → branch → verify → device sign-off → `--no-ff` merge → log): the **`phase`** skill.
