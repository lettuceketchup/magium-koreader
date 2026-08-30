# Research Plan — Magium on KOReader

- **Status:** active — Phase 0 in progress
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

- [~] 0.1 Record exact device facts. **Done from public specs:** Kindle Paperwhite 12th gen (2024, B0DKTZ6592), MediaTek dual-core 1 GHz, ~512 MB RAM, 16 GB, 7″/300 ppi, `koreader-kindlehf` build. **Still needs owner on-device:** exact firmware, KOReader version + channel, LuaJIT build string, free RAM/storage (OQ-010).
- [x] 0.2 Write `00-overview.md`: problem, goals/non-goals, "full parity" (links design doc §3), success criteria, glossary, device table. _Refine parity detail after Phase 1._
- [x] 0.3 Get `magium-dev` running locally. `npm install` + `node main_node.js <port>` verified on Node v24.11.0 (2026-08-31).
- [~] 0.4 `reference/magium-dev-notes.md`: run instructions + differential-oracle method **documented and proven** (`POST /` + `HX-Request` header + variable-map body). **TODO:** build the normalizer/diff script.
- [x] 0.5 Skimmed `magium-recrystallized` source; wrote `reference/magium-recrystallized-notes.md`. Confirms it's not a viable base: Rust/WASM engine, binary `.story` TLV format with no in-repo compiler, designed for HTTP range-streaming, AGPL, unfinished scripting layer. Save-model stores and the chunked/indexed format layout are worth borrowing if approach D (build-time preprocess) is chosen.
- [x] 0.6 Sibling commit hashes recorded (design doc §4): `magium-dev` `51f5aa9`, `magium-recrystallized` `0dcfd2e`.

## Phase 1 — Magium analysis

**Goal:** a complete, source-grounded understanding of the engine and data.
**Deliverables:** `docs/research/01-magium-analysis.md`, `docs/research/02-magium-format-spec.md`.
**Depends on:** Phase 0.

- [ ] 1.1 Document the scene model: how `parser.js` turns a file into scenes (`id`, `paragraphs`, `choices`, `setVariables`, `achievements`, `statChecks`), including the quirky bits (blank line after `TEXT:`, `<br/>` joining, the leading empty scene that gets sliced off).
- [ ] 1.2 Document the variable store: naming (`v_*`), types (everything is a string/number), defaulting to 0, where `v_current_scene` and `v_checkpoint_rich` come from.
- [ ] 1.3 Document condition evaluation: DNF structure, `apply_condition` regex + operators, `"True"` literal, missing-variable behavior. Reference `utils.js:apply_condition`/`apply_conditions`.
- [ ] 1.4 Document scene-effect ordering in `renderScene`: filter `setVariables` by condition → apply them → filter choices → filter paragraphs → compute stat checks → filter achievements. This order matters for a faithful port.
- [ ] 1.5 Document the stats system: the 14 `stats_variables`, `parseStatCheck` success/failure logic, `statChecksToDisplay`, the `v_b3_ch1_unlock` lock special case, and stat-check de-duplication.
- [ ] 1.6 Document achievements: JSON structure of `achievements{1,2,3}.json`, per-book/chapter grouping, the "always-visible" `v_ac_b3_ch9_prize` case, how `achievement(...)` lines gate on a `v_ac_*` flag.
- [ ] 1.7 Document the `special:` hooks: `restart`, `saves`, `stats`, `checkpoint` — what each does in the web UI, and the `special:checkpoint` / `v_checkpoint_rich == 0` interaction.
- [ ] 1.8 Document saves & settings: what the web build persists (cookies/localStorage), save slot shape (name + date + full variable snapshot), settings (theme, language, font?).
- [ ] 1.9 Document i18n: `locales.json`, `ui.json` keys, `mainHeaderTemplate` EJS, `getHeaderFromId` regex, en vs. fr data differences.
- [ ] 1.10 List every hardcoded scene-ID special case in `renderers.js` (`B3-Ch04a-Introduction2`, `Ch6-Eiden-vs-dragon`, `B3-Ch01`... ) and what each does.
- [ ] 1.11 Write `02-magium-format-spec.md`: a formal-ish grammar for `.magium`, then a **construct corpus** — scan all 54 files and enumerate every distinct syntactic form actually used (all `special:` values, all operator types, nested `#if`, choices with empty target, multi-assignment choices, quoting edge cases like `choice(""I see no reason..."")`). Flag anything the parser regexes would mishandle.
- [ ] 1.12 Estimate in-memory footprint of the parsed story (all scenes as JS/Lua objects) — rough number for the constraints budget.

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

- [ ] 3.1 Enumerate PW4/PW5 hard limits under KOReader: usable RAM for a plugin, CPU class, storage, no OS threads, e-ink refresh latency, battery cost of heavy CPU use, any Lua memory ceiling / GC behavior.
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
- [ ] 8.2 Effort band per phase (e.g. S/M/L or hour ranges), calibrated to "reads code, limited Lua" + community help. State assumptions.
- [ ] 8.3 Sequencing / critical path; what unblocks what; what can be parallelised or handed to a contributor.
- [ ] 8.4 Timeline sketch under a stated weekly-hours assumption.
- [ ] 8.5 Handoff checklist (design doc §11 exit criteria): confirm all `docs/research/*` are `stable`, every `OQ` closed or deferred, recommendation recorded.
- [ ] 8.6 Start a new brainstorming cycle for the implementation design.

---

## Running log

Newest entries at the top. One entry per work session: what was done, decisions, what's next.

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
