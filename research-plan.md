# Research Plan — Magium on KOReader

- **Status:** active — Phases 0 & 1 done; Phase 2 next
- **Last updated:** 2026-08-31
- **Governing design:** [`docs/superpowers/specs/2026-08-31-magium-koreader-research-design.md`](docs/superpowers/specs/2026-08-31-magium-koreader-research-design.md)
- **Conventions:** see design doc §8 and [`CLAUDE.md`](CLAUDE.md). Every deliverable
  doc uses the standard header; every claim is cited; findings carry a confidence tag.

This is the executable checklist. Work one phase at a time, produce that phase's
deliverable doc(s), then update [`SUMMARY.md`](SUMMARY.md) and append to the
[running log](#running-log) at the bottom.

Status keys: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped (say why in the log)

---

## Phase 0 — Baseline & setup

**Goal:** know exactly what we're targeting and have the reference oracle running.
**Deliverables:** `docs/research/00-overview.md`, `reference/magium-dev-notes.md`.

- [x] 0.1 Device facts recorded (owner supplied on-device readings 2026-08-31): Kindle Paperwhite 12th gen (2024, B0DKTZ6592), FW **Kindle 5.19.5**, **956.9 MB RAM** (~497 available), 10.6 GB free, KOReader **v2026.07.1** release (`kindlehf`), idle RSS ~33 MB. OQ-010 closed. Only LuaJIT exact build string still TBD → folded into task 2.2.
- [x] 0.2 Write `00-overview.md`: problem, goals/non-goals, "full parity" (links design doc §3), success criteria, glossary, device table. _Refine parity detail after Phase 1._
- [x] 0.3 Get `magium-dev` running locally. `npm install` + `node main_node.js <port>` verified on Node v24.11.0 (2026-08-31).
- [x] 0.4 `reference/magium-dev-notes.md`: run instructions + differential-oracle method proven. Normalizer/diff harness built: [`reference/tools/oracle-diff.js`](reference/tools/oracle-diff.js) (`scene` / `capture` / `diff`), 6-case fixture set + committed goldens under `reference/tools/oracle-capture/`. Ready to diff the spike-B Lua port against.
- [x] 0.5 Skimmed `magium-recrystallized` source; wrote `reference/magium-recrystallized-notes.md`. Confirms it's not a viable base: Rust/WASM engine, binary `.story` TLV format with no in-repo compiler, designed for HTTP range-streaming, AGPL, unfinished scripting layer. Save-model stores and the chunked/indexed format layout are worth borrowing if approach D (build-time preprocess) is chosen.
- [x] 0.6 Sibling commit hashes recorded (design doc §4): `magium-dev` `51f5aa9`, `magium-recrystallized` `0dcfd2e`.

## Phase 1 — Magium analysis

**Goal:** a complete, source-grounded understanding of the engine and data.
**Deliverables:** `docs/research/01-magium-analysis.md`, `docs/research/02-magium-format-spec.md`.
**Depends on:** Phase 0.

- [x] 1.1 Scene model documented — [`01`](docs/research/01-magium-analysis.md) §0–1, full grammar/quirks in [`02` §1–2](docs/research/02-magium-format-spec.md).
- [x] 1.2 Variable store — [`01` §2](docs/research/01-magium-analysis.md#2-variable-store-task-12): flat `v_*` namespace, string values, unset→0, `v_current_scene` (only nav state), `v_checkpoint_rich`, `+N`/`-N` relative writes, two client buckets.
- [x] 1.3 Condition evaluation — [`01` §3](docs/research/01-magium-analysis.md#3-condition-evaluation-task-13): DNF, `apply_condition` operators + coercion, `True`, unknown-atom→false, whitespace-sensitivity, single-paren stripping.
- [x] 1.4 `renderScene` 12-step ordering — [`01` §0,§4](docs/research/01-magium-analysis.md#4-scene-effect-ordering-in-renderscene-task-14).
- [x] 1.5 Stats system — [`01` §5](docs/research/01-magium-analysis.md#5-stats-system-task-15): 14 vars, `varToStat`, `parseStatCheck` 4 branches (cover 100% of corpus), `statChecksToDisplay` (fed by set∪paragraphs∪choices), lock filter, de-dup, stats screen.
- [x] 1.6 Achievements — [`01` §6](docs/research/01-magium-analysis.md#6-achievements-task-16): in-story `achievement()` gates on flag `=== "1"`; toast shows JSON `title`; `achievements{1,2,3}.json` = 136 total, `b2ch41`-style group quirk; `v_ac_b3_ch9_prize` always-on.
- [x] 1.7 `special:` hooks — [`01` §7](docs/research/01-magium-analysis.md#7-special-hooks-task-17): real values are `restart`/`saves`/`stats`/`checkpoint_load`/`checkpoint_save` (no bare `checkpoint`); checkpoint-banner ↔ `v_checkpoint_rich === "0"`.
- [x] 1.8 Saves & settings — [`01` §8](docs/research/01-magium-analysis.md#8-saves--settings-task-18): 4 blobs (`currentState` autosave / `checkpoint` / `save0-49` / `achievements`), each a full var snapshot + `date`/`name`; theme/font/locale are KOReader's job.
- [x] 1.9 i18n — [`01` §9](docs/research/01-magium-analysis.md#9-localization-task-19): `locales.json`, `ui.json` (incl. EJS micro-templates), `getHeaderFromId` regex; en/fr `.magium` structurally identical.
- [x] 1.10 All 13 hardcoded special cases tabulated — [`01` §10](docs/research/01-magium-analysis.md#10-hardcoded-scene-id--variable-special-cases-task-110).
- [x] 1.11 [`02-magium-format-spec.md`](docs/research/02-magium-format-spec.md) written: grammar + construct corpus (reproducible via [`reference/tools/scan-magium-constructs.js`](reference/tools/scan-magium-constructs.js)) + 10-item parser risk list. Key: nav via `v_current_scene` not `target`; 809 `choice(""…"")`; no multi-digit `set()`; conditions never have >1 paren; `#if` never nested; one 490 KB / 2044-clause condition outlier.
- [x] 1.12 Footprint — [`01` §11](docs/research/01-magium-analysis.md#11-parsed-story-size--memory-footprint-task-112): ~17.4 MB V8 heap (Lua TBD spike D), 8.16 MB serialized; feeds [`04`](docs/research/04-constraints-budget.md).

## Phase 2 — KOReader platform

**Goal:** know what the plugin platform gives us and how to build/deploy/debug.
**Deliverable:** `docs/research/03-koreader-platform.md`.
**Depends on:** Phase 0. May overlap Phase 1.

- [ ] 2.1 Plugin anatomy: directory layout, `_meta.lua`, `main.lua`, the `WidgetContainer` base, `init()`, how a plugin registers menu items, the event/dispatcher model. Cite the plugin dev guide + a real example plugin from the KOReader source tree.
- [ ] 2.2 Lua environment: Lua 5.1 / LuaJIT, what stdlib is available, string/`re`/regex support (KOReader bundles `lua-lgettext`, `rapidjson`, etc.), UTF-8 handling.
- [ ] 2.3 UI toolkit inventory for our needs: widgets for (a) a long scrollable block of prose, (b) a vertical list of tappable choice buttons, (c) modal menus/dialogs, (d) a stats panel. Candidates: `TextViewer`, `Menu`, `ButtonDialog`, `ButtonDialogTitle`, `ScrollTextWidget`, `ScrollableContainer`, `MovableContainer`, `InputDialog`. Record each one's constraints (max content, pagination behavior, back-button semantics).
- [ ] 2.4 Persistence: `LuaSettings`, `DocSettings`, `Persist`, writing plain files to the plugin dir or a data dir. Where user data should live on a Kindle. Size/perf of reading/writing a multi-KB save blob frequently.
- [ ] 2.5 Text rendering: how KOReader lays out and reflows text, font control, whether we can reuse the document renderer or must use text widgets, markup support (does any widget take a subset of HTML? our data has `<br/>`).
- [ ] 2.6 E-ink specifics: refresh modes (full vs. partial vs. A2), how to avoid ghosting on frequent screen updates, expected latency per interaction.
- [ ] 2.7 Lifecycle & integration: can a plugin present a fullscreen UI that isn't a "document"? How does it coexist with the file browser / reader? How is it launched (menu, gesture)? How does it exit cleanly?
- [ ] 2.8 Build/deploy/debug loop: how to get a plugin onto the Paperwhite (USB copy to `koreader/plugins/`), how to see `logger` output / crash logs, hot-reload options, emulator availability on desktop for faster iteration.
- [ ] 2.9 Localisation: KOReader's own gettext-based i18n, and whether/how a plugin ships translations.
- [ ] 2.10 Packaging & distribution paths: KOReader's plugin index, `kindlemodshelf`, manual install. What each requires.

## Phase 3 — Constraints budget

**Goal:** a hard go/no-go table.
**Deliverable:** `docs/research/04-constraints-budget.md`.
**Depends on:** Phase 2 (and 1.12).

- [~] 3.1 Enumerate device hard limits under KOReader: RAM, CPU, storage, no OS threads, e-ink refresh latency, battery, Lua GC behavior. Core numbers already captured in [`04-constraints-budget.md`](docs/research/04-constraints-budget.md) §1 (2026-08-31); still need e-ink latency + LuaJIT specifics.
- [ ] 3.2 Enumerate Magium's demands: 7.7 MB text on disk, parsed-story memory footprint (1.12), regex-heavy parsing cost, frequency and size of save writes, number of scenes resident at once.
- [ ] 3.3 Build the table: each demand vs. the budget → green / yellow / red, with the mitigation for every yellow/red (e.g. parse lazily per chapter, pre-compile data to a leaner format at build time, cache parsed scenes to disk).
- [ ] 3.4 Decide whether runtime parsing is viable on-device or whether a build-time preprocessing step is needed — feed this into Phase 6.

## Phase 4 — Prior art

**Goal:** learn from comparable efforts; build the contacts map for later help.
**Deliverable:** `docs/research/05-prior-art.md`.

- [ ] 4.1 Interactive fiction on e-ink: existing Z-machine/Glulx/TADS interpreters on Kindle or KOReader (Frotz ports, `fabularium`, etc.), and what their authors say about UI and performance.
- [ ] 4.2 Existing KOReader game / non-book plugins: survey the `kindlemodshelf` plugin list and the KOReader repo. Note any that render narrative + choices (gamebook / CYOA / Twine / Ink players, `rakuyomi` manga reader architecture as a "non-document fullscreen UI" example).
- [ ] 4.3 Twine / Ink / ChoiceScript players on constrained hardware — do any run offline in a way we could target via format conversion?
- [ ] 4.4 Past attempts to put Magium (or similar CYOA apps) on an e-reader — search r/Magium, r/koreader, MobileRead, the Magium Discord.
- [ ] 4.5 Contacts map: a table of `OQ` venues — which kind of question goes to KOReader Discord vs. KOReader GitHub Discussions vs. MobileRead vs. r/koreader vs. Magium Discord vs. a specific plugin author (with handles/links).
- [ ] 4.6 Reach out where it's cheap and useful; record responses as cited findings.

## Phase 5 — De-risking spikes (throwaway)

**Goal:** answer the riskiest questions on the real device instead of on paper.
**Deliverable:** `docs/spikes/*` (each: `HYPOTHESIS.md`, code, `FINDING.md`), feeding Phase 6.
**Depends on:** Phases 1 and 2.

- [ ] 5.1 Spike A — **UI feel:** fork the simplest existing plugin, hard-code one Magium scene (prose + 3 choices), render it on the Paperwhite, wire the choices to swap to another hard-coded scene. Judge: does the widget model fit? refresh feel? navigation?
- [ ] 5.2 Spike B — **engine in Lua:** port `apply_condition`/`apply_conditions` + the scene parser for a 3-scene slice to Lua. Feed identical variable states to it and to `magium-dev`; diff the resulting text + choice list.
- [ ] 5.3 Spike C — **format conversion:** write a `.magium` → Twee (or Ink) converter for one chapter; try the output in an existing player (desktop first, then on-device if a player exists). Judge conversion fidelity for conditions/stats.
- [ ] 5.4 Spike D — **memory:** load all 54 files' text (and/or the fully parsed story) into memory on-device; watch RAM via KOReader's tools. Confirms/kills the "parse everything up front" approach.
- [ ] 5.5 Spike E (only if a yellow/red from Phase 3 needs it) — targeted measurement of whatever that risk is.
- [ ] 5.6 Write up each spike's verdict and roll the findings into `SUMMARY.md`.

## Phase 6 — Approach comparison & recommendation

**Goal:** pick an end-form (or decide more spiking is needed).
**Deliverables:** `docs/research/06-approach-comparison.md`, `docs/research/07-risks-open-questions.md`, an ADR.
**Depends on:** Phases 3, 4, 5.

- [ ] 6.1 Describe each candidate concretely: (A) standalone KOReader plugin with a Lua engine, (B) extend an existing plugin, (C) convert `.magium` to a supported format + use an existing player, (D) hybrid (build-time conversion to a lean format + small Lua runtime).
- [ ] 6.2 Decision matrix scored on: implementation effort, parity ceiling (can it ever reach full parity?), on-device performance, maintainability & upstream-sync cost, fit with owner's skills + community, distribution ease, risk.
- [ ] 6.3 Consolidate all open questions into `07-risks-open-questions.md` as `OQ-NNN` rows with venue tags; note which are blocking.
- [ ] 6.4 Write the recommendation into `SUMMARY.md` with a confidence tag, and record it as an ADR.

## Phase 7 — Licensing & permissions

**Goal:** know what license the port must use and what redistribution is allowed.
**Deliverable:** `docs/research/08-licensing.md`, `LICENSE`, an ADR.

- [ ] 7.1 Compare upstream licenses: `magium-dev` MIT, `magium-recrystallized` AGPL-3.0, original `raduprv/Magium`. Determine what a port inherits depending on which code/data it derives from.
- [ ] 7.2 The story-text permission chain: the family's permission to the community projects — does it extend to a further port? Who to ask (Magium Discord / project maintainers).
- [ ] 7.3 KOReader's own license (AGPL-3.0) and what that implies for a plugin distributed with/for it.
- [ ] 7.4 Distribution implications for each channel (KOReader plugin index, kindlemodshelf, GitHub releases).
- [ ] 7.5 Pick a license for this repo; record as an ADR; add `LICENSE`.

## Phase 8 — Roadmap, effort, timeline

**Goal:** a credible implementation roadmap and a clean handoff to the design phase.
**Deliverable:** `docs/research/09-roadmap-effort.md`.
**Depends on:** Phase 6.

- [ ] 8.1 Phased implementation roadmap for the chosen approach: MVP (render + choose + conditions) → saves → stats/stat-checks → achievements → settings/themes → i18n → polish. Each phase: deliverables, dependencies.
- [ ] 8.2 Effort band per phase (e.g. S/M/L or hour ranges). Calibrate to: experienced generalist programmer new to Lua (fast ramp) and new to the KOReader API (the real ramp — carry a premium on KOReader-facing work) + targeted community help. State assumptions.
- [ ] 8.3 Sequencing / critical path; what unblocks what; what can be parallelised or handed to a contributor.
- [ ] 8.4 Timeline sketch under a stated weekly-hours assumption.
- [ ] 8.5 Handoff checklist (design doc §11 exit criteria): confirm all `docs/research/*` are `stable`, every `OQ` closed or deferred, recommendation recorded.
- [ ] 8.6 Start a new brainstorming cycle for the implementation design.

---

## Running log

Newest entries at the top. One entry per work session: what was done, decisions, what's next.

### 2026-08-31 (session 6) — Phase 1 done: engine + format fully analysed

- Read the whole `magium-dev` engine (`parser.js`, `utils.js`, `renderers.js`,
  `main_setup.js`, all 11 EJS templates, the 4 client scripts, `ui.json` /
  `locales.json` / `achievements1.json`) at `51f5aa9`.
- Rewrote [`01-magium-analysis.md`](docs/research/01-magium-analysis.md) from stub
  to a full source-grounded reference: data-flow diagram, the 12-step
  `renderScene` pipeline, variable store, condition eval, stats, achievements,
  `special:` hooks, saves/settings, i18n, and a table of **13 hardcoded special
  cases**. Findings F-09…F-13.
- Wrote [`02-magium-format-spec.md`](docs/research/02-magium-format-spec.md):
  informal grammar + a **construct corpus** generated by a new reproducible
  scanner [`reference/tools/scan-magium-constructs.js`](reference/tools/scan-magium-constructs.js)
  (scanned all 54 en files), + a 10-item **parser risk list**. Findings F-04…F-08.
- Key discoveries: navigation is driven by the `v_current_scene` *variable*, not
  the `choice.target` field (which the engine never reads); `choice(""spoken"")`
  doubled-quote labels are 809/3734 choices, not an edge case; no `set()` uses a
  multi-digit value; no condition has >1 paren and no `#if` is nested (so the
  naive parser regexes are safe *for this data*); `special:` values are
  `restart`/`saves`/`stats`/`checkpoint_load`/`checkpoint_save` (CLAUDE.md's
  "checkpoint" shorthand is imprecise); the in-story achievement toast shows the
  JSON `title`; en/fr `.magium` are structurally identical (i18n = bundle swap).
- **One performance flag:** `b3ch4a.magium:251` is a single ~490 KB
  `choice … if (…)` line — a 2044-OR-clause pre-expanded DNF for the "Average
  Joe" check. Per-render cost on the Kindle is untested → **new OQ-011**.
- OQ-008 downgraded to "mostly resolved"; a few spot-checks run against the live
  oracle (`#if(False)` hidden, stat-device lock, achievement gating, statChecks
  suppression). Updated `SUMMARY.md` (rows 9–12), `04-constraints-budget.md`
  (condition-eval demand row).
- **Next:** Phase 2 (KOReader platform → `03-koreader-platform.md`, tasks
  2.1–2.10) — the plugin API, widget toolkit, persistence, e-ink, build/deploy
  loop. Independent of Phase 1; unblocks spikes A & B.

### 2026-08-31 (session 5) — oracle diff harness built; Phase 0 closed
- Built [`reference/tools/oracle-diff.js`](reference/tools/oracle-diff.js) (task 0.4): drives `magium-dev` over HTTP, normalizes each rendered scene to a canonical JSON shape (header, checkpoint, statChecks, setVariables, paragraphs, choices, achievements), and does a structural pairwise diff. Three subcommands: `scene`, `capture`, `diff`. No deps (global `fetch`).
- Normalizer is coupled to `templates/main.ejs` @ `51f5aa9`: choices read from the `setResponseVariables({...})` button payload; checkpoint vs. stat-check disambiguated against `ui.json:mainCheckpointReachedText`. Caveat recorded in `magium-dev-notes.md`.
- Wrote a 6-case fixture set ([`oracle-cases.json`](reference/tools/oracle-cases.json)) + committed goldens (`reference/tools/oracle-capture/`): opening scene, `#if` filtering + achievement + spaced scene-id, `choice(""quoted"")`, two stat checks, no-stat (still shows a failed check from `v_perception < 1`), checkpoint banner. Verified capture-vs-self = 6/6 and that a mutated golden is caught.
- **Phase 0 complete.** Only the exact LuaJIT build string is still open (folded into task 2.2).
- **Next:** Phase 1 (engine deep-dive, `01`/`02`) and Phase 2 (KOReader platform, `03`) — can run in parallel. The oracle is ready for spike B to diff against.

### 2026-08-31 (session 4) — owner-skill calibration corrected
- Clarified owner background: experienced generalist programmer (JS, Python, C; light hobby 2D/puzzle game dev), **new to Lua** and to the KOReader API. Earlier "limited Lua" was underselling the general programming experience.
- Reframed effort assumptions across design doc §2/§12, `00-overview.md`, `SUMMARY.md` F-4, `09-roadmap-effort.md`, plan task 8.2: **Lua syntax is a fast ramp for this background; the KOReader plugin/widget API + e-ink idioms are the real learning curve** and carry the effort premium. Engine/logic port is mostly mechanical JS→Lua translation against the oracle.
- No structural changes; no new OQs.

### 2026-08-31 (session 3) — real device facts; RAM concern retired
- Owner supplied on-device readings: **FW Kindle 5.19.5**, **956.9 MB RAM** (220.8 free / 497.5 available), 10.6 GB free storage, **KOReader v2026.07.1 release** (`kindlehf`), KOReader idle RSS ~32.7 MB.
- **Big correction:** public reviews' "512 MB RAM" was wrong — it's ~1 GB. Updated `00-overview.md`, `03-koreader-platform.md` §0, `04-constraints-budget.md`.
- **OQ-010 closed.** **OQ-001 downgraded** from blocking to a confirmation (memory fits with room; only launch parse-time matters now — spike B). **OQ-009 narrowed** to "stable under plugin load" (KOReader release build runs fine on 5.19.5).
- Constraints budget re-scored: storage/CPU/memory 🟢; launch-parse/save-IO/e-ink 🟡 (responsiveness, not blockers).
- Added a **low-confidence early read** to `SUMMARY.md`: constraints favor a standalone Lua plugin reimplementing the `magium-dev` engine + bundled data. To be confirmed in Phase 6.
- **Next:** build the oracle diff-normalizer (0.4); then Phases 1 + 2 in parallel. Phase 0 is otherwise done.

### 2026-08-31 (session 2) — Phase 0 substantially done
- **Device identified:** Amazon.in B0DKTZ6592 = **Kindle Paperwhite 12th gen (2024), 16 GB**. Public specs: MediaTek dual-core 1 GHz, ~512 MB RAM, 7″/300 ppi, USB-C. Requires the `koreader-kindlehf` KOReader build (FW ≥ 5.16.3). Filled into `00-overview.md` §"Target environment facts" and `03-koreader-platform.md` §0.
- **Noted risk OQ-009:** KOReader launch-crash reports on 12th-gen for some FW/build combos (issue #13307). Owner says it works — needs exact-version confirmation. Added OQ-010 for the remaining on-device facts.
- **`magium-dev` running** (Node v24.11.0). Confirmed it works as a stateless differential oracle: `POST /` + `HX-Request: true` + variable-map JSON → rendered scene. Documented in `reference/magium-dev-notes.md`.
- **Measured story scale** (`scratchpad/measure.js`): 54 files / 7.50 MB / 2159 scenes / 4880 paragraphs / 3734 choices; ~17 MB parsed in V8, 8.16 MB serialized. Into `01-magium-analysis.md` §11 and `04-constraints-budget.md`.
- **Preliminary constraints budget** drafted: storage & CPU 🟢; RAM headroom, blocking parse, save-write frequency, e-ink refresh all 🟡 pending on-device measurement. OQ-001 sharpened with real numbers.
- **Decisions:** none new (magium-dev-as-base already recorded).
- **Next:** owner to supply on-device facts (OQ-010) + confirm KOReader stability (OQ-009); build the oracle diff-normalizer (0.4); then start Phase 1 (engine deep-dive) and Phase 2 (KOReader platform), which can run in parallel.

### 2026-08-31 (session 1) — project initialized
- Explored both sibling repos. Confirmed `magium-dev` (MIT, ~650 LOC JS, runtime `.magium` parser, 54 files / 7.7 MB) is the sensible porting base over `magium-recrystallized` (AGPL, Rust/WASM, binary `.story`).
- Brainstormed and approved the research-phase design: modular dossier layout, traceability conventions, methods (prior-art scan / constraints budget / de-risking spikes / differential oracle / data-format-first), 9-phase plan.
- Wrote the governing design doc, scaffolded the repo (`README`, `SUMMARY`, this plan, `CLAUDE.md`, `docs/research/*` stubs, `docs/decisions/` + ADR-001, `docs/spikes/README`, `reference/*` stubs).
- **Next:** Phase 0 — record device/KOReader facts, get `magium-dev` running locally, write `00-overview.md` and `reference/magium-dev-notes.md`.
