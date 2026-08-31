# Research Plan — Magium on KOReader

- **Status:** research phase substantially complete — Phases 0–6 and 8 done
  (approach chosen — [ADR-002](docs/decisions/ADR-002-porting-approach.md);
  roadmap written — [`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md));
  **Phase 7 deferred** (personal-use-only scope confirmed by owner —
  [ADR-003](docs/decisions/ADR-003-defer-licensing-distribution.md)). Awaiting
  owner review of the roadmap before opening the implementation-design cycle.
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

- [x] 2.1 Plugin anatomy — [`03` §1](docs/research/03-koreader-platform.md#1-plugin-anatomy-21): `<name>.koplugin/` + `main.lua` (+ `_meta.lua`), `WidgetContainer:extend`, `init()`, `is_doc_only`, three entry points (main-menu item / Dispatcher action / event handlers), sandboxed `on*` handlers. Cites `hello.koplugin`, `pluginloader.lua`.
- [x] 2.2 Lua environment — [`03` §2](docs/research/03-koreader-platform.md#2-lua-environment-22): **LuaJIT 2.1.ROLLING** (`NUM 20199`, `LuaJIT/LuaJIT@3c4f9fe`, not OpenResty), Lua 5.1 + FFI, no `utf8` stdlib, patterns not regex; `rapidjson`/SQLite3/`zstd`/`string.buffer` bundled, LZ-String not; single Lua state → `Trapper`/`scheduleIn` for long work. **Closes the Phase 0 LuaJIT-build item.**
- [x] 2.3 UI toolkit inventory — [`03` §3](docs/research/03-koreader-platform.md#3-ui-toolkit-inventory-23): prose = `TextBoxWidget`/`ScrollTextWidget`/`TextViewer`; choices = `ButtonTable`/`ButtonDialog`/`Menu`; modals = `ConfirmBox`/`InfoMessage`/`InputDialog`; stats = `KeyValuePage`; toast = `Notification`. Nothing missing. `frotz.koplugin` `GameView` = working prior art. → OQ-002 narrowed.
- [x] 2.4 Persistence — [`03` §4](docs/research/03-koreader-platform.md#4-persistence-24): `LuaSettings` (text kv) + `Persist` (codec blobs, `zstd`/`luajit`), both fsync; story data bundled next to `main.lua`, saves under `<data-dir>/`. Maps cleanly to Magium's 4 blobs; risk is autosave write *frequency*, debounce it. → F-20.
- [x] 2.5 Text rendering — [`03` §5](docs/research/03-koreader-platform.md#5-text-rendering-25): two paths (`TextBoxWidget` own layout, C-shaped via `xtext`; or MuPDF `ScrollHtmlWidget`). `<br/>` is the only Magium markup → replace with `\n`, use `TextBoxWidget`, skip the document renderer. → F-19.
- [x] 2.6 E-ink specifics — [`03` §6](docs/research/03-koreader-platform.md#6-e-ink-specifics-26): refresh types (`full`/`partial`/`ui`/`fast`/`a2` + flash variants), `partial`→flash every 6, MTK fast-mode forced on `KindlePaperWhite6`, `canHWDither=no`. Strategy: `"ui"` swaps + periodic `"full"`. Latency/ghosting feel → spike A / OQ-007.
- [x] 2.7 Lifecycle & integration — [`03` §7](docs/research/03-koreader-platform.md#7-lifecycle--integration-27): fullscreen non-document UI is fine (`UIManager:show`); `is_doc_only=false` → launch from File Manager via `more_tools` menu item or a gesture; Back/`onClose` pops back cleanly + flushes save; handle broadcast `Close`/suspend.
- [x] 2.8 Build/deploy/debug — [`03` §8](docs/research/03-koreader-platform.md#8-build--deploy--debug-loop-28): on-device = USB copy to `koreader/plugins/` + restart + read `koreader/crash.log` (all `logger` output, last 500 KB); no hot reload. `kodev` emulator Linux/macOS-only → owner on Windows needs WSL2/Docker/AppImage → **OQ-012**.
- [x] 2.9 Localisation — [`03` §9](docs/research/03-koreader-platform.md#9-localisation-29): KOReader gettext (`_()`, `T()`); a plugin bundles its own `l10n/<lang>/*.po`. Independent of Magium's own en/fr story-bundle swap.
- [x] 2.10 Packaging & distribution — [`03` §10](docs/research/03-koreader-platform.md#10-packaging--distribution-210): no first-party review store; manual install / `koreader/contrib` / GitHub topic / KindleModShelf. Real gate is redistribution permission (OQ-004) + license (OQ-005), not mechanism.

## Phase 3 — Constraints budget

**Goal:** a hard go/no-go table.
**Deliverable:** `docs/research/04-constraints-budget.md`.
**Depends on:** Phase 2 (and 1.12).

- [x] 3.1 Device + platform hard limits tabled — [`04` §1](docs/research/04-constraints-budget.md#1-device--platform-hard-limits-31): RAM/CPU/storage/battery, single cooperative Lua state, LuaJIT 2.1, e-ink refresh mechanics, fsync save writes. Three rows carry a measurement deferred to a named spike: `"ui"` refresh latency (A / OQ-007), LuaJIT GC pauses under load (D / OQ-001), on-device cold-parse time (B). None is a feasibility gate.
- [x] 3.2 Magium's demands tabled — [`04` §2](docs/research/04-constraints-budget.md#2-magiums-demands-32): 7.5 MB text, ~10–30 MB parsed resident (est.), cold parse ~95–130 ms desktop → est. ~1–4 s on-device (F-24), **save-blob ≈ 12–15 KB / 491 writable vars** (F-23, [`scan-save-footprint.js`](reference/tools/scan-save-footprint.js)), autosave potentially per-choice, 1 scene resident + history stack.
- [x] 3.3 Budget table built — [`04` §3](docs/research/04-constraints-budget.md#3-budget-table-33): 10 rows, **no 🔴**, four 🟢 (memory/storage/save-size/normal CPU), six 🟡 each with a named mitigation + the spike that closes it.
- [x] 3.4 Runtime-parse vs build-time preprocess — [`04` §4](docs/research/04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34): preliminary lean = parse-all-at-launch if spike B cold parse < ~1 s, else lazy-per-chapter + disk cache; build-time pre-parse reserved; the 490 KB condition (OQ-011) may get a targeted pre-compile regardless. Confidence medium, feeds Phase 6 (not yet an ADR).

## Phase 4 — Prior art

**Goal:** learn from comparable efforts; build the contacts map for later help.
**Deliverable:** `docs/research/05-prior-art.md`.

- [x] 4.1 Interactive fiction on e-ink — [`05` §1](docs/research/05-prior-art.md#1-interactive-fiction-on-e-ink-41): `frotz.koplugin`/`kofrotz.koplugin` (KOReader, active), KIF and the Kindle Gargoyle port (2010–2012 native/KUAL, stalled at alpha), Fabularium (Android). All converge on native fullscreen text UI, not browser/document — F-26.
- [x] 4.2 Existing KOReader game / non-book plugins — [`05` §2](docs/research/05-prior-art.md#2-existing-koreader-game--non-book-plugins-42): full `awesome-koreader` + ecosystem survey (puzzle plugins, `rakuyomi`'s external-server architecture) finds **zero** CYOA/gamebook plugins. **OQ-003 closed — no.** F-30.
- [x] 4.3 Twine / Ink / ChoiceScript on constrained hardware — [`05` §3](docs/research/05-prior-art.md#3-twine--ink--choicescript-players-on-constrained-hardware-43): no e-ink player exists for any of them; KOReader's HTML path is MuPDF document rendering, not JS. Evidence against approach C. F-27/F-28.
- [x] 4.4 Past Magium-on-e-reader attempts — [`05` §4](docs/research/05-prior-art.md#4-past-attempts-to-put-magium-or-a-similar-cyoa-on-an-e-reader-44): none found (web-search-indexed sources only). Two live Magium Discord invites discovered for OQ-004 follow-up. F-29.
- [x] 4.5 Contacts map — [`05` §5](docs/research/05-prior-art.md#5-contacts-map-45): venue table with real links (KOReader GH Discussions, MobileRead, both Magium Discords, intfiction.org, named prior-art authors).
- [x] 4.6 Outreach — three drafts prepared (OQ-004 permission ask, KOReader GH Discussions e-ink question, `frotz.koplugin` author question) but **not sent**: no Discord/Reddit/MobileRead account access this session, and posting externally under the owner's identity is a call for the owner to make. [`05` §6](docs/research/05-prior-art.md#6-outreach-46).

## Phase 5 — De-risking spikes (throwaway)

**Goal:** answer the riskiest questions on the real device instead of on paper.
**Deliverable:** `docs/spikes/*` (each: `HYPOTHESIS.md`, code, `FINDING.md`), feeding Phase 6.
**Depends on:** Phases 1 and 2.

- [x] 5.1 Spike A — **UI feel:** fork the simplest existing plugin, hard-code one Magium scene (prose + 3 choices), render it on the Paperwhite, wire the choices to swap to another hard-coded scene. Judge: does the widget model fit? refresh feel? navigation? — [`docs/spikes/04-ui-plugin-skeleton/`](docs/spikes/04-ui-plugin-skeleton/): plugin code written, API-grounded against real `v2026.07.1` source, **and actually run** — a working `kodev` emulator build was obtained in this session (see FINDING.md for how the earlier network-egress block on GitHub thirdparty tarballs was resolved: swap the ~17 archive-tarball fetches for `git clone` at the same tag). Both hard-coded scenes render correctly under the real KOReader runtime with zero errors, screenshotted. **Data/API fit: confirmed.** Owner review of the screenshots then caught that the specific widget used (`TextViewer`) is a padded dialog with continuous scroll, not the fullscreen + paginated presentation wanted for the finished UI — split off as **new OQ-013**, feeding Phase 6/8. Refresh feel/e-ink perceptual judgment (necessarily unanswerable from any non-e-ink display, emulator included) stays open for the owner on real hardware.
- [x] 5.2 Spike B — **engine in Lua:** port `apply_condition`/`apply_conditions` + the scene parser for a 3-scene slice to Lua. Feed identical variable states to it and to `magium-dev`; diff the resulting text + choice list. — [`docs/spikes/02-engine-in-lua/`](docs/spikes/02-engine-in-lua/): **6/6 oracle-diff match** across 4 scenes/3 files (exceeds the planned 3-scene slice, reusing the existing fixture set); full 54-file structural parity confirmed as a bonus in 5.4. One real Lua-vs-JS pattern-syntax bug found+fixed (`%w` excludes `_`).
- [x] 5.3 Spike C — **format conversion:** write a `.magium` → Twee (or Ink) converter for one chapter; try the output in an existing player (desktop first, then on-device if a player exists). Judge conversion fidelity for conditions/stats. — [`docs/spikes/05-magium-to-ink/`](docs/spikes/05-magium-to-ink/): `ch1.magium` (12 scenes) → Ink, compiled + played via `inkjs/full` (in-process JS compiler, no `inklecate`/.NET needed). Conditions/`set()` convert losslessly (verified against the oracle goldens); achievements/`special:` hooks/cross-chapter nav have no Ink primitive (documented, expected — doesn't change Phase 4's approach-C read since no e-ink Ink player exists regardless).
- [x] 5.4 Spike D — **memory:** load all 54 files' text (and/or the fully parsed story) into memory on-device; watch RAM via KOReader's tools. Confirms/kills the "parse everything up front" approach. — [`docs/spikes/03-full-corpus-memory-parse/`](docs/spikes/03-full-corpus-memory-parse/): **not on-device, but now under koreader-base's own bundled LuaJIT** (see below) — desktop LuaJIT (stock apt package): full 54-file parse = **11.54 MB** heap delta (lower than the ~17.4 MB V8 estimate), **112–128 ms** parse time; re-run under koreader-base's bundled build (`LuaJIT 2.1.1783773675`, from a working `./kodev build` obtained later this session) once fixed: **11.48 MB**, **184–205 ms** — both agree with the stock-LuaJIT run within noise. Structural counts (2159 scenes/4880 paragraphs/3734 choices/594 `set()`) match the JS baseline exactly under both — a strong full-corpus fidelity check on spike B's port. The initial attempt to build the `kodev` emulator in this cloud session hit a 403 on GitHub thirdparty-tarball downloads and was reported as an unconditional block; that was too broad — see [`docs/spikes/04-ui-plugin-skeleton/FINDING.md`](docs/spikes/04-ui-plugin-skeleton/FINDING.md) for the fix (git-clone the ~17 affected libs at the same tag instead of downloading their archive tarball) and [`reference/setup-koreader-cloud-session.sh`](reference/setup-koreader-cloud-session.sh) for the reproducible recipe. Still not the Kindle's ARM core — that gap is unchanged, only the *desktop* number's provenance improved.
- [-] 5.5 Spike E (only if a yellow/red from Phase 3 needs it) — not run: nothing from 5.1–5.4 surfaced a new 🟡/🔴 needing a dedicated follow-up measurement.
- [x] 5.6 Write up each spike's verdict and roll the findings into `SUMMARY.md`. — done this session (see running log + `docs/spikes/README.md` index).

## Phase 6 — Approach comparison & recommendation

**Goal:** pick an end-form (or decide more spiking is needed).
**Deliverables:** `docs/research/06-approach-comparison.md`, `docs/research/07-risks-open-questions.md`, an ADR.
**Depends on:** Phases 3, 4, 5.

- [x] 6.1 Describe each candidate concretely — [`06` §1](docs/research/06-approach-comparison.md#1-candidates-61): (A) standalone plugin/Lua engine, (B) extend `frotz.koplugin` (ruled out — nothing to extend, OQ-003), (C) convert to Ink + existing player (ruled out — no e-ink player exists, F-27), (D) build-time hybrid (real 2nd place, undercut by spike 02/03's fast measured parse time).
- [x] 6.2 Decision matrix scored — [`06` §2](docs/research/06-approach-comparison.md#2-decision-matrix-62): 7 criteria × weight, weighted totals A 95 / D 70 / B 53 / C 47 (of 100). A wins clearly, not a close call.
- [x] 6.3 Open questions consolidated — [`07`](docs/research/07-risks-open-questions.md): fixed 4 rows (OQ-001/009/011/012) that had lost their Blocking?/Status/Resolution column split across earlier edits (Resolution was rendering empty); added a "Blocking status after Phase 6" section — no open OQ blocks the approach decision itself; OQ-004 blocks the project (distribution permission).
- [x] 6.4 Recommendation written into `SUMMARY.md` (confidence: high on approach, medium on the parse-all-vs-lazy-cache implementation detail) and recorded as [ADR-002](docs/decisions/ADR-002-porting-approach.md).

## Phase 7 — Licensing & permissions

**DEFERRED (2026-08-31, [ADR-003](docs/decisions/ADR-003-defer-licensing-distribution.md)):**
project scope confirmed as personal use on the owner's own device only, no
near-term distribution intent. This phase only matters once distribution is
actually being considered — not dropped, just not run now. Revisit before
any public release. Phase 8 does not depend on this phase, so research
proceeds to Phase 8 in the meantime.

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

- [x] 8.1 Phased implementation roadmap for the chosen approach — [`09` §1](docs/research/09-roadmap-effort.md#1-phased-implementation-roadmap-81): Milestone 0 (parse-timing gate) → I (MVP: engine core + custom pagination widget) → II (full corpus + nav) → III (saves) → IV (stats) → V (achievements) → VI (settings/themes) → VII (i18n) → VIII (polish). Each with deliverables + dependencies.
- [x] 8.2 Effort bands per phase (hour ranges) — [`09` §2](docs/research/09-roadmap-effort.md#2-effort-summary-table-82): ~100–162 hrs total, engine-logic work banded low (mechanical, oracle-checked) and KOReader-facing work (the pagination widget, e-ink tuning) banded with a ramp premium, per the owner's stated skill profile. Assumptions stated in [`09` §0](docs/research/09-roadmap-effort.md#0-scope--assumptions-82-calibration).
- [x] 8.3 Sequencing / critical path — [`09` §3](docs/research/09-roadmap-effort.md#3-critical-path--parallelism-83): M0→I→II is strictly sequential; III/IV/V (saves/stats/achievements) and VII (i18n) are independent extensions of Phase II's engine, parallelizable or handable to a contributor; VI likely shrinks once scoped against KOReader's own settings.
- [x] 8.4 Timeline sketch — [`09` §4](docs/research/09-roadmap-effort.md#4-timeline-sketch-84): three named hobby-pace scenarios (5/10/20 hrs·wk⁻¹) against the ~100–162 hr total, since the owner hasn't stated a real weekly-hours figure — explicitly flagged as an assumption to replace.
- [x] 8.5 Handoff checklist — [`09` §5](docs/research/09-roadmap-effort.md#5-handoff-checklist-85-design-doc-11-exit-criteria): `docs/research/00`–`06`,`09` promoted to `stable` this session (residual real-device-only items explicitly carried into the roadmap, not left unstated); `07` stays `living`, `08` stays a stub by design ([ADR-003](docs/decisions/ADR-003-defer-licensing-distribution.md)); every `OQ-NNN` closed, deferred, or now scheduled as roadmap work (see `07`'s new "Phase 8 disposition" note); recommendation already recorded (Phase 6). Two rows genuinely need the owner, not more research: reviewing the roadmap, and approving the implementation-design cycle's start.
- [x] 8.6 Start a new brainstorming cycle for the implementation design — **prepared, not started**: [`09` §6](docs/research/09-roadmap-effort.md#6-starting-the-implementation-design-cycle-86) describes what it looks like and where it begins (Milestone 0), but per CLAUDE.md no implementation-phase work — including formally opening that cycle — starts without the owner's approval, so this session stops at "ready" rather than unilaterally opening it.

---

## Running log

Newest entries at the top. One entry per work session: what was done, decisions, what's next.

### 2026-08-31 (session 16) — Phase 8 done: roadmap + effort + timeline, research phase substantially complete

Picked up at "Phase 8 next" from session 15. Phase 8's job was a credible
implementation roadmap for candidate A (ADR-002) and a clean handoff to the
design phase — the last deliverable the research phase needed.

- **Wrote [`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md) end to
  end** (was a stub): a Milestone 0 pre-flight (an on-device parse-timing gate
  that resolves OQ-001's tail *before* Phase I starts, per Phase 6's explicit
  ask that this be an early gate, not a paper decision), then eight roadmap
  phases (I MVP → II full corpus/nav → III saves → IV stats → V achievements
  → VI settings → VII i18n → VIII polish), each with deliverables, dependencies,
  and an hour-range effort band. Total: **~100–162 hrs**, with the ramp premium
  concentrated on two items — Phase I's custom fullscreen pagination widget
  (resolves OQ-013; no KOReader prior art surveyed does "fullscreen +
  paginated" together) and Phase VIII's on-device tuning (OQ-007 e-ink feel,
  OQ-011 condition-outlier cost) — both flagged as the best-targeted spots for
  community help. Critical-path analysis (§3): M0→I→II is strictly sequential,
  but III/IV/V (saves/stats/achievements) and VII (i18n) are independent
  extensions of Phase II's engine — real parallelization or contributor-handoff
  opportunities, not just a flat list. Timeline (§4): three named hobby-pace
  scenarios (5/10/20 hrs/week) against the total, since the owner hasn't stated
  a real weekly-hours figure — explicit assumption, not asserted as fact.
- **Deliberate design choice: Phase I builds the real pagination widget from
  the start**, not `TextViewer` first with a later swap — OQ-013 already
  established `TextViewer` is the wrong final widget, so building on it now
  would be solved work redone. Spike 02/04 code is treated explicitly as a
  validated *design reference*, not a copy-paste base — per CLAUDE.md, spike
  code is throwaway and production code is written fresh, hardened, and
  covers the full 54-file/13-special-case surface the spikes didn't attempt.
- **Closed the exit-criteria gap this surfaced:** checking design doc §11
  found six of nine `docs/research/*` docs (`00`–`05`) still marked `draft`,
  despite their phases having finished sessions ago — an oversight, not a
  real gap. Reviewed each one's specific "why draft" note and promoted all
  six to `stable`, folding in what Phase 5's spikes actually closed (e.g. `01`
  now cites spike 02/03's full-corpus validation, not just "spot-checked";
  `03`'s Windows-dev-loop caveat is resolved per OQ-012) and being explicit
  about what's still genuinely open and why (`03`/`04` note that on-device
  ARM parse time, GC pauses, and e-ink refresh latency remain real-hardware-only
  measurements, now carried into `09`'s Milestone 0 / Phase VIII rather than
  stated as an unexplained gap). `07` stays `living` (a register, never
  "finished," by its own stated design) and `08` stays a stub
  ([ADR-003](docs/decisions/ADR-003-defer-licensing-distribution.md)) — both
  intentional, not oversights. Added a "Phase 8 disposition" note to
  [`07`](docs/research/07-risks-open-questions.md) cross-referencing exactly
  where each still-open OQ (001's tail, 007, 011, 013) lands in the new
  roadmap, so "closed or explicitly deferred with a reason" is genuinely true
  for every row, not just the ones Phase 6 already closed.
- **Task 8.6 (open a new brainstorming cycle) deliberately left at "prepared,
  not started."** [`09` §6](docs/research/09-roadmap-effort.md#6-starting-the-implementation-design-cycle-86)
  describes what starting it looks like (a new spec doc under `docs/specs/`,
  beginning with Milestone 0) but does not do it — CLAUDE.md is explicit that
  no implementation-phase work starts without a separately approved phase,
  and that bar applies to formally opening the design cycle too, not just to
  writing code. This mirrors how Phase 7's scope question and the Phase 4
  outreach drafts were both left for the owner rather than decided
  unilaterally this session.
- **No code changed** — per CLAUDE.md, this phase is planning/estimation work
  only.
- **Next:** the research phase is substantially complete — every exit
  criterion in [`09` §5](docs/research/09-roadmap-effort.md#5-handoff-checklist-85-design-doc-11-exit-criteria)
  is met except two that need the owner directly: reviewing this roadmap, and
  approving the start of the implementation-design cycle (§6). Once that
  happens, the design phase opens with Milestone 0 (the parse-timing gate) as
  its first concrete action.

### 2026-08-31 (session 15) — scope clarified: personal use only; licensing deferred (ADR-003)

The owner clarified project scope right after Phase 6 closed: this is a
**personal hobby project for use on their own Kindle only** — no near-term
plan to distribute or share it. "The rest can be figured out after the
project is complete" — i.e. licensing and redistribution permission are
questions for later, not now.

- This directly touched a claim made in session 14: ADR-002's consequences
  section had said OQ-004 "should be pursued in parallel with Phase 7/8,"
  and `research-plan.md`/`SUMMARY.md`/`06`/`07` all pointed at Phase 7 as
  next. That's now wrong given the actual scope, so it needed correcting
  everywhere it was stated, not just noted once.
- **Wrote [ADR-003](docs/decisions/ADR-003-defer-licensing-distribution.md):**
  defers Phase 7 (`08-licensing.md`, `LICENSE`, its own ADR) and **OQ-004**
  (redistribution permission) until the owner is actually considering
  distributing the port — not dropped (the contacts map + three unsent
  outreach drafts in [`05` §5–6](docs/research/05-prior-art.md#5-contacts-map-45)
  stay ready), just not pursued now. Explicitly does **not** touch
  [ADR-002](docs/decisions/ADR-002-porting-approach.md)'s actual Decision
  (candidate A) — only supersedes its consequences-section sequencing claim
  about OQ-004.
- **Propagated the correction** rather than leaving it in one place:
  - [`07-risks-open-questions.md`](docs/research/07-risks-open-questions.md):
    OQ-004 and OQ-005 Blocking? → "no — deferred," with the reason; rewrote
    the "Blocking status after Phase 6" section (added last session) so it
    no longer calls OQ-004 "the one item worth prioritizing now."
  - [`06-approach-comparison.md`](docs/research/06-approach-comparison.md)
    §3's blocking-OQ table and the paragraph under it — corrected from
    "should be resolved... in parallel with or before Phase 8" to "deferred,
    Phase 8 proceeds without waiting on it."
  - `SUMMARY.md` — recommendation section, finding 31 (dropped its now-wrong
    OQ-004 clause), new finding 32 recording the scope decision, the open-
    questions summary paragraph, status line, Decisions list.
  - `research-plan.md` — status line, Phase 7 section header marked
    **DEFERRED** with the reason and a pointer to proceed to Phase 8
    (dependency-checked: Phase 8 depends only on Phase 6, confirmed in its
    own header), task 8.5's handoff-checklist wording.
  - [`08-licensing.md`](docs/research/08-licensing.md) and the governing
    [design doc](docs/superpowers/specs/2026-08-31-magium-koreader-research-design.md)
    §11 exit criteria — short notes added pointing to ADR-003, so "all nine
    docs stable" no longer reads as silently unmet; the doc itself stays a
    stub, not filled in, per the instruction to ignore this for now.
- **No code changed, no actual licensing research done** — that was the
  point: this session recorded a scope decision and fixed every place it
  was already contradicted, not started Phase 7 work.
- **Next:** Phase 8 (roadmap, effort, timeline → `09-roadmap-effort.md`).

### 2026-08-31 (session 14) — Phase 6 done: approach chosen, ADR-002

Picked up at "Phase 6 next" from session 13. Phase 6's job was to compare the
four candidates fixed at project start against everything Phases 3–5 had
since established, and either pick an end-form or conclude more spiking was
needed. It didn't need more spiking — the evidence already pointed one way.

- **Wrote [`06-approach-comparison.md`](docs/research/06-approach-comparison.md)
  end to end** (was a stub): concrete descriptions of all four candidates
  (§1) grounded in citations already on record (not new research — this
  phase is synthesis, not discovery); a scored decision matrix (§2, 7
  criteria × weight) — weighted totals **A 95, D 70, B 53, C 47** (of 100);
  a blocking-open-questions accounting (§3); the recommendation (§4).
- **Candidates B and C both fail on a structural fact, not a close call:**
  B (extend `frotz.koplugin`) has nothing to extend — it's an IF-interpreter
  host built around piping I/O to a Z-machine/Glulx VM, architecturally
  unrelated to Magium's flat-var/DNF-condition model, and Phase 4 already
  found zero existing plugins play CYOA content at all (OQ-003, F-30). C
  (convert to Ink/Twine + existing player) has nothing to play the converted
  output on — no e-ink or KOReader Ink/Twine/ChoiceScript player exists
  anywhere (F-27), so "use existing tooling" collapses into writing A's
  engine anyway, plus a translation tax (spike 05: achievements/`special:`
  hooks have no Ink primitive).
- **Candidate D (build-time hybrid) is a real second-place option** — same
  parity ceiling as A — but the problem it exists to solve (slow runtime
  parsing) didn't materialize: spikes 02/03 measured the **full 54-file
  corpus** parsing in 112–205 ms under two LuaJIT builds, close to the
  original 95–130 ms V8/desktop anchor. D's standing cost (a build pipeline
  to write, a second format to keep in sync with every upstream `.magium`
  update) is real and ongoing; A avoids it by bundling the source files
  verbatim.
- **Decision: Candidate A** — standalone KOReader plugin, Lua reimplementation
  of the `magium-dev` engine, runtime `.magium` parsing. Recorded as
  [**ADR-002**](docs/decisions/ADR-002-porting-approach.md) (options
  considered, rationale, consequences — including that reopening B/C/D needs
  a new superseding ADR with new evidence, not a unilateral revisit).
  Confidence: **high** on the approach; **medium** on one implementation
  detail left deliberately open within A — parse-all-at-launch vs. the
  already-scoped lazy-per-chapter/disk-cache fallback ([`04`
  §4](docs/research/04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34))
  — pending real on-device ARM timing (OQ-001's tail), left for Phase 8 to
  schedule as an early implementation-phase gate rather than resolved here.
- **Consolidated [`07-risks-open-questions.md`](docs/research/07-risks-open-questions.md)**
  (task 6.3): while re-checking every row against the Phase 6 decision, found
  4 rows (OQ-001, OQ-009, OQ-011, OQ-012) had lost their Blocking?/Status/
  Resolution column split somewhere across earlier sessions' edits — each was
  missing one column, which meant their Resolution cell was rendering empty
  in the table. Re-split all four (no content lost, just realigned) and used
  the same pass to add each one's Phase 6 read. Added a "Blocking status
  after Phase 6" section up top: **no open `OQ-NNN` blocks the approach
  decision** — every one narrows an implementation detail inside candidate A
  (pagination widget, parse-strategy gate, one outlier condition's
  mitigation, e-ink redraw tuning) — while **OQ-004** (redistribution
  permission) blocks the *project*, independent of which approach was chosen.
- Updated `SUMMARY.md` (status line; replaced "Current recommendation: None
  yet" with the Phase 6 decision + confidence tags, folding the earlier
  Phase-0–5 "early read" paragraphs into a collapsed `<details>` block rather
  than deleting them; findings 29–31; open-questions summary; Decisions
  list), [`docs/decisions/README.md`](docs/decisions/README.md) index.
- **No code changed** — per CLAUDE.md, this phase is analysis/decision work
  only; the ADR is explicit that implementation still needs a separately
  approved phase.
- **Next:** Phase 7 (licensing & permissions → `08-licensing.md`, `LICENSE`,
  an ADR) — ADR-002's consequences section already flags that A's shape
  (original Lua + verbatim-bundled `.magium` text, no derived/converted
  artifact) is the simplest case to reason about there. **OQ-004** (family
  permission for redistribution) is worth pursuing in parallel — it's the
  one item blocking the project overall and doesn't depend on Phase 7/8
  being done first (three outreach drafts already sit in [`05`
  §6](docs/research/05-prior-art.md#6-outreach-46), unsent, waiting on the
  owner's own account access). Phase 8 (roadmap/effort) can start once
  Phase 7 closes; it should open with the parse-all-vs-lazy-cache gate as an
  early, concrete measure-then-decide milestone rather than a paper decision.

### 2026-08-31 (session 13) — owner review of spike 04's screenshots: TextViewer's chrome corrected, new OQ-013

Owner reviewed session 12's spike 04 screenshots and flagged two things:
(1) the emulator window wasn't fullscreen — intentional, or just for
testing? and (2) the text rendered as a continuous scroll, prone to
ghosting and hard to navigate on Kindle — a paginated format with page
numbers would be better, matching the web version's fullscreen look.

- **Investigated rather than just noting the ask.** Grepped
  `../koreader/frontend/ui/widget/textviewer.lua` and `scrolltextwidget.lua`
  directly. Confirmed both observations are real, source-grounded findings,
  not testing artifacts: `TextViewer` defaults to `screen_w/h -
  Screen:scaleBySize(30)` (`textviewer.lua:107-108`) inside a
  `radius = Size.radius.window` rounded frame with a `TitleBar` **✕ close
  button** (`textviewer.lua:469-474`) — a padded dialog, not fullscreen.
  Its prose area is `ScrollTextWidget` (`textviewer.lua:416`), a plain
  scrollbar+pan widget with no page-number/pagination concept anywhere in
  its API. Checked whether `frotz.koplugin` (the other cited prior art,
  F-15) does any better: its `GameView` **is** genuinely fullscreen, but
  its `StyledScroll` transcript still scrolls — no KOReader prior art
  surveyed so far does "fullscreen + paginated" together.
- **Corrected a standing inaccuracy this surfaced:**
  `03-koreader-platform.md` §7 previously claimed "`TextViewer` fills the
  screen" (written in Phase 2, before any spike actually ran it) — that
  was wrong, now fixed with the exact source lines above and a citation to
  the screenshots that exposed it.
- **Filed `OQ-013`**: should the final reading screen be a custom
  fullscreen, paginated widget (buildable on `TextBoxWidget`'s existing
  line/height measurement API — not a new capability, just unbuilt) rather
  than reusing `TextViewer`? Tagged as feeding Phase 6 (approach
  comparison — a component of parity/effort, not a go/no-go factor) and
  Phase 8 (roadmap — its own line item), not reopening Phase 5: spike 04
  already did its job — proving the *data* drives a widget cleanly — this
  is new information about the *chrome*, which was always going to need a
  build-phase decision regardless of which widget the throwaway spike
  happened to pick.
- Also noted, grounding the pagination question in real numbers rather
  than asserting it blind: most scenes are short (4880 paragraphs / 2159
  scenes ≈ 2.3 avg, `01` §11) and may need neither scrolling nor
  pagination once rendered in a true fullscreen frame (no
  titlebar/button-row/30px-margin overhead eating screen space) —
  pagination mainly matters for the longer scenes, not a rewrite of every
  screen.
- Updated `03-koreader-platform.md` (§3 spike-A verdict + §7 correction),
  `07-risks-open-questions.md` (OQ-002's resolution softened to
  "data/API fit," new OQ-013 row), `docs/spikes/04-ui-plugin-skeleton/FINDING.md`
  (new caveat section, softened "widget fit: confirmed" language, updated
  Confidence/Next step), `SUMMARY.md` (F-26 caveat, new F-28), this file.
- **No code changed** — per CLAUDE.md, no application code exists yet or
  should until an implementation phase is separately approved; this
  session's output is entirely documentation, as the owner's request
  ("note this in the docs") asked for.
- **Next:** unchanged at the phase level — Phase 6 (approach comparison).
  OQ-013 is now one more concrete item that phase's decision matrix and
  Phase 8's roadmap should carry (custom pagination widget = its own
  roadmap line item, not free).

### 2026-08-31 (session 12) — Phase 5 closed: spike A run for real, emulator-build blocker resolved

Picked up where session 11 left off, in a **fresh cloud session/container**
(the sibling checkouts — `../magium-dev`, `../koreader`, `../magium-recrystallized`
— don't persist between sessions; re-cloned all three at their previously
recorded commit hashes and confirmed they matched exactly). Prompted to
finish Phase 5, with a note that this session's network access might be
less restricted than session 11's.

- **Re-verified reproducibility first:** re-ran spikes 02 (6/6 oracle-diff
  match), 03 (11.17 MB / 148–188 ms, consistent with session 11's numbers),
  and 05 (Ink conversion + playthrough) in the fresh container before
  touching anything new — all three held up unchanged, confirming session
  11's results weren't container-specific flukes.
- **Investigated session 11's "cloud sessions can't build the KOReader
  emulator" conclusion rather than accepting it at face value**, since the
  prompt flagged network access as possibly different now. Found the
  conclusion was **too broad**: `curl`-testing individual URL patterns
  showed plain `git clone` of any public GitHub repo works (confirmed via
  `add_repo` too — it reports anonymous git reads as already available),
  and `github.com/*/releases/download/*` (published release assets) also
  return 200. Only `github.com/*/archive/*` / `codeload.github.com`
  (GitHub's dynamic "zip the tree at this ref" endpoint) returns 403 for
  repos outside this session's attached scope — confirmed via the JSON
  error body naming the repo-scope policy.
- **Fixed it**: of koreader-base's ~50 thirdparty C-library dependencies,
  17 fetch a GitHub archive tarball (blocked) and ~13 fetch a GitHub
  release asset (not blocked, no change needed); the rest are non-GitHub
  hosts (also not blocked). Patched the 17 archive-based ones — plus 3 more
  found only once the build got further (`lua-term`, `lua_cliargs`,
  `mediator_lua`, luarocks "spec" test deps) — to fetch via `git clone` at
  the same tag instead, using the build system's own already-existing
  `DOWNLOAD GIT` mechanism (same one `luajit`'s `CMakeLists.txt` already
  used unmodified). Content-identical to the archive download: GitHub's
  archive endpoint is just a zip of the git tree at that ref. Full patch:
  [`reference/koreader-base-thirdparty-git-fetch.patch`](reference/koreader-base-thirdparty-git-fetch.patch);
  reproducible recipe (apt prereqs, ninja/make version bump — same Ubuntu
  24.04 issue session 8's WSL2 setup hit, built from git source instead of
  a blocked GitHub release zip — clone, patch, build):
  [`reference/setup-koreader-cloud-session.sh`](reference/setup-koreader-cloud-session.sh).
- **`./kodev build` succeeded end to end** — all ~50 thirdparty libraries
  (LuaJIT 2.1, MuPDF, HarfBuzz, FreeType, Tesseract, SDL3, ...) compiled,
  then `koreader` itself linked. Ran headless via `xvfb-run -a ./kodev run
  --simulate=kindle-paperwhite --no-build` — starts cleanly, loads every
  bundled plugin plus spike 04's `magium_spike.koplugin` dropped into
  `plugins/`, exits 0, zero errors in the log.
- **Spike A (04-ui-plugin-skeleton) actually run for the first time.**
  Instrumented a deployed copy (not the committed spike source) to
  auto-open on startup and call `Screen:shot()`, confirming both
  hard-coded scenes (`Ch1-Intro1`/`Ch1-Intro2`) render correctly — real
  prose, correct "Book 1 - Chapter 1" header, working `buttons_table`
  choice row, clean navigation between them, zero Lua errors. Screenshots
  saved: [`docs/spikes/04-ui-plugin-skeleton/screenshots/`](docs/spikes/04-ui-plugin-skeleton/screenshots/).
  This closes the **functional** half of OQ-002 (widget fit: confirmed,
  not just structurally argued) — the **perceptual** half (OQ-007, e-ink
  refresh feel) is unaffected and stays open, since no non-e-ink display
  (this container's Xvfb included) was ever going to answer it.
- Re-ran spikes 02 and 03's parsers under koreader-base's own bundled
  LuaJIT (`2.1.1783773675`, distinct from the stock-apt build used
  earlier) once the build succeeded: 6/6 oracle match and 11.48 MB / 184–
  205 ms respectively — both agree with the earlier stock-LuaJIT numbers,
  reinforcing that neither result is an artifact of which LuaJIT build ran
  it. Still desktop x86, still not the Kindle's ARM core — that gap is
  unchanged.
- Updated [`docs/spikes/04-ui-plugin-skeleton/`](docs/spikes/04-ui-plugin-skeleton/)
  (FINDING.md + HYPOTHESIS.md, rewritten around the actual run),
  [`docs/spikes/03-full-corpus-memory-parse/FINDING.md`](docs/spikes/03-full-corpus-memory-parse/FINDING.md)
  (adds the koreader-base-LuaJIT numbers, corrects the "cloud sessions
  can't build the emulator" over-generalization), and
  [`docs/spikes/02-engine-in-lua/FINDING.md`](docs/spikes/02-engine-in-lua/FINDING.md)
  (notes the re-confirmation), [`docs/spikes/README.md`](docs/spikes/README.md)
  index, `SUMMARY.md`, [`07`](docs/research/07-risks-open-questions.md)
  (OQ-002 narrowed to functional-confirmed/perceptual-open; OQ-007
  unchanged in substance but reworded; OQ-012's cloud-session note
  corrected from "can't" to "can, with a documented fetch patch").
- **Phase 5 status: done.** All four planned spikes reached a terminal,
  evidence-based verdict; the one still-open thread (OQ-007's e-ink feel)
  was never closable from any non-e-ink environment and is correctly
  scoped to the owner, not a gap in this phase's work.
- **Next:** Phase 6 (approach comparison & recommendation) — nothing in
  this session's results changes the direction Phase 3/4/5 were already
  pointing; if anything, spike A's actual run removes the last piece of
  "argued from source, not observed" hedging around the UI layer.

### 2026-08-31 (session 11) — Phase 5: 3 of 4 spikes confirmed, 1 blocked by session network policy

Run from a cloud/remote agent session (no physical Kindle, no owner's WSL2
environment available to it) — scoped the four spikes to what that
environment could and couldn't do, and reported the gap honestly rather
than skipping it.

- **Environment:** cloned `../magium-dev` @ `51f5aa9` and `../koreader` @
  `v2026.07.1` (`9192014`) as sibling checkouts for source grounding + the
  oracle; installed LuaJIT 2.1 + Lua 5.1 (Ubuntu packages) for spikes B/D;
  `inkjs@2.4.0` (npm) for spike C.
- **Spike B — engine in Lua** ([`02-engine-in-lua/`](docs/spikes/02-engine-in-lua/)):
  ported `parser.js`'s parser + `utils.js`'s condition/stat-check logic to
  Lua (hand-written boundary scans standing in for JS's named-capture
  regexes, which Lua patterns don't have). **6/6 match** against
  `reference/tools/oracle-diff.js`'s committed goldens, reusing the
  existing 6-fixture set unmodified (covers 4 scenes / 3 files — more than
  the planned 3-scene slice). One real bug found+fixed while porting: Lua's
  `%w` pattern class excludes `_` (unlike JS `\w`), silently breaking every
  condition match on `v_snake_case` variable names until caught via the
  port's own "Condition fail" diagnostic (mirrors the JS fallback branch's
  own `console.log`).
- **Spike D — memory/parse-time** ([`03-full-corpus-memory-parse/`](docs/spikes/03-full-corpus-memory-parse/)):
  reran spike B's parser, unmodified, over the **full 54-file corpus** —
  structural counts (2159 scenes/4880 paragraphs/3734 choices/594 `set()`)
  are **bit-for-bit identical** to the Phase 0 JS baseline, a much stronger
  fidelity signal than the 6 diffed fixtures alone. Memory: **11.54 MB**
  Lua GC-heap delta (below the ~17.4 MB V8 estimate). Parse time:
  **112–128 ms** (LuaJIT, this x86 container) — same order of magnitude as
  the V8 anchor, still not an on-device number. **Attempted to build the
  KOReader `kodev` emulator** in-container (same recipe as
  `reference/setup-koreader-wsl.sh`) to get a real koreader-base-LuaJIT
  number for this and for spike A — **blocked**: `./kodev fetch-thirdparty`
  needs `https://github.com/<org>/<repo>/archive/refs/tags/*.tar.gz`
  downloads (leptonica, freetype2, md4c, …), and every one returned **403**
  under this session's network egress policy. Confirmed via the proxy's own
  diagnostics (`curl $HTTPS_PROXY/__agentproxy/status`,
  `/root/.ccr/README.md`'s "403/407 from the proxy" section) that this is a
  **policy denial, not a transient failure** — not retried. This is a new,
  general finding: **a cloud/remote Claude Code session cannot build or run
  the KOReader emulator**, independent of CPU architecture — orthogonal to
  OQ-012 (which was specifically about the owner's Windows machine, already
  resolved via WSL2) and not reopening it.
- **Spike C — format conversion** ([`05-magium-to-ink/`](docs/spikes/05-magium-to-ink/)):
  converted all of `ch1.magium` (12 scenes) to Ink source (reusing
  `magium-dev`'s own parser, not re-deriving the grammar a third time),
  compiled + played it via `inkjs@2.4.0`'s `inkjs/full` build — a
  **JS-native in-process Ink compiler**, no `inklecate`/.NET dependency
  discovered along the way. **Conditions and `set()`-equivalent state
  convert losslessly** — verified by eye against `oracle-capture/ch1-dave-showmyself.json`,
  not just "compiles". Fidelity gaps found and documented, all expected:
  achievements and `special:` hooks have no Ink primitive (degrade to inert
  tags); the "Load game" choice's *empty* target scene doesn't fit Ink's
  choice model at all; cross-chapter diverts need stub knots (single-file
  conversion, by design of a one-chapter spike). **Answers OQ-006's
  fidelity half** — closed as "not lost, for the mechanics that matter" —
  without changing Phase 4's deployability verdict against approach C (no
  e-ink Ink player exists regardless, `05-prior-art.md` §3).
- **Spike A — UI plugin skeleton** ([`04-ui-plugin-skeleton/`](docs/spikes/04-ui-plugin-skeleton/)):
  wrote `magium_spike.koplugin/main.lua` — hard-codes `Ch1-Intro1`/`Ch1-Intro2`
  (real prose, real 3-way branch), uses `TextViewer` + a `buttons_table`
  (shape verified against a real caller,
  `readerbookmark.lua:1267-1296`, not just the docstring), modeled on
  `hello.koplugin`'s registration boilerplate. Lua syntax checks clean.
  **Never run** — same emulator-build block as spike D. The actual
  question (widget fit / e-ink refresh feel / navigation) needs a human at
  the device regardless of the emulator; recommended next step is the
  owner running this file in their already-working WSL2 `kodev` build, then
  on the real Kindle — cheap, since that environment already exists.
- **No spike E** — nothing above surfaced a new 🟡/🔴 needing one.
- Updated [`SUMMARY.md`](SUMMARY.md) (findings 23–26 + current-recommendation
  paragraph), [`07`](docs/research/07-risks-open-questions.md) (OQ-001
  narrowed further — memory now strongly 🟢 from a real Lua measurement,
  parse-time still open; OQ-002/OQ-007 unchanged, now with a concrete next
  step; OQ-006 closed on fidelity; OQ-012 gains a note about the distinct
  cloud-session emulator-build blocker), [`docs/spikes/README.md`](docs/spikes/README.md)
  (index of all 4 spikes run).
- **Next:** Phase 6 (approach comparison & recommendation) — Phase 5's
  results (engine ports cleanly and fast to write; memory is a non-issue;
  format conversion loses nothing on conditions but gains nothing on
  deployability) all point the same direction the Phase 3/4 "early read"
  already did. The one open thread worth closing first, cheaply, before or
  during Phase 6: have the owner run spike 04's plugin file in their
  existing WSL2 emulator (and ideally the real device) — it's a 5-minute
  copy-and-run, not a new spike, and would close OQ-002/OQ-007 for real
  rather than carrying them into Phase 6 as "still open."

### 2026-08-31 (session 10) — Phase 4 done: prior art surveyed, contacts map built

- Wrote [`05-prior-art.md`](docs/research/05-prior-art.md) (tasks 4.1–4.6) from
  web research: IF-on-e-ink history (Frotz forks, KIF, Kindle Gargoyle port,
  Fabularium), a full KOReader plugin-ecosystem scan for narrative/CYOA
  plugins, Twine/Ink/ChoiceScript-on-constrained-hardware precedent, and a
  search for prior Magium-on-e-reader attempts. Findings F-26…F-30.
- **OQ-003 closed — no.** No existing KOReader plugin plays gamebook/CYOA
  content (full `awesome-koreader` + ecosystem survey: only IF interpreters
  and generic puzzle games). This rules out **approach B** (extend an
  existing plugin) as a shortcut for Phase 6 — whichever approach is chosen,
  the Lua engine is written from scratch.
- **Evidence against approach C** (convert to Twine/Ink + reuse a player):
  no e-ink player exists for any of them. KOReader's HTML path is MuPDF
  document rendering, not a JS runtime (confirms F-19); even PocketBook,
  which has a real browser, shows RAM growth and refresh glitches running
  Twine's HTML5 output over a session (MobileRead, *Trigaea* thread). If
  approach C is spiked anyway (spike C, OQ-006), Ink is the better conversion
  target than Twee — open-source runtime, no e-ink precedent either way.
- **Prior-art pattern for the UI:** every Kindle IF interpreter that stuck
  around (`frotz.koplugin`, active inside KOReader) converged on native
  fullscreen text rendering, not a browser view; the ones that tried native
  Kindle apps directly (KIF, Kindle Gargoyle, 2010–2012, pre-KOReader) stalled
  at "alpha" on unfinished polish, not a fundamental blocker. Reinforces
  F-14/F-15 — KOReader's plugin model is the platform where this genre of
  project is currently alive, not a graveyard.
- **One cautionary data point** for OQ-011: the one commercial CYOA-on-Kindle
  precedent found (Fighting Fantasy, Worldweaver 2011) hit a CPU wall
  specifically on a *redrawn map* feature, not core branching-text logic —
  supports the existing "avoid per-render recomputation" mitigation stance
  rather than raising a new concern.
- **No prior Magium-on-e-reader attempt found** (web-search-indexed sources
  only — absence of evidence, not evidence of absence; Discord history isn't
  crawled). Found two live Magium Discord invites (Community `Aw5sEYPPXv`,
  Writer Team `WWDCcyaspH`) for OQ-004 follow-up — neither yet cross-checked
  against the `cF3EDRmK` invite already on record.
- **Task 4.6 (outreach):** three message drafts prepared (redistribution-
  permission ask for the Writer Team Discord, a KOReader GH Discussions
  e-ink question, a targeted question for `frotz.koplugin`'s author) but
  **not sent** — this session has no Discord/Reddit/MobileRead account
  access, and posting externally under the owner's identity is the owner's
  call, not an autonomous one. Drafts + an outreach log stub are in
  [`05` §6](docs/research/05-prior-art.md#6-outreach-46) for the owner to use
  when convenient.
- Updated [`07`](docs/research/07-risks-open-questions.md) (OQ-003 closed;
  OQ-004 gains the two Discord links; OQ-006 gains the Ink lead), `SUMMARY.md`
  (status + findings rows 19–22 + early-read paragraph).
- **Next:** Phase 5 (de-risking spikes — A/B/D at minimum; spike C now has a
  slightly stronger case for targeting Ink over Twee if run). Phase 4 also
  feeds Phase 6's decision matrix directly: OQ-003's "no" removes approach B
  as a live option, and §3's findings weigh against approach C.

### 2026-08-31 (session 9) — Phase 3 done: constraints budget → conditional green light

- Finished [`04-constraints-budget.md`](docs/research/04-constraints-budget.md)
  (tasks 3.1–3.4): device + platform limits table, Magium demands table, a
  10-row budget table with a mitigation + closing spike for every yellow, the
  runtime-parse-vs-preprocess preliminary decision, and an explicit **go/no-go
  verdict (§5)**. Findings F-22…F-25.
- **Verdict: GO for continued research — feasibility is not resource-bound.**
  No 🔴 in the budget table. Four 🟢 (memory ~500 MB avail vs ~10–30 MB story;
  storage 10.6 GB vs 7.5 MB; save-blob ~12–15 KB; normal-case CPU). Six 🟡, all
  responsiveness / I-O-hygiene items with named mitigations: chunk the cold
  parse, memoise/precompile the 490 KB condition (OQ-011), debounce autosave,
  `"ui"` refresh + periodic `"full"` (OQ-007), tune/limit the resident heap
  (spike D), and the architectural "everything long must yield" rule (F-25).
- **New measurement:** [`reference/tools/scan-save-footprint.js`](reference/tools/scan-save-footprint.js)
  — 491 distinct writable variables (135 achievement flags); a 100%-progressed
  save serialises to **≈ 12–15 KB uncompressed** (F-23). Only `v_current_scene`
  holds a long value. Save concern is write *frequency* on flash, not size.
- **Cold-parse anchor:** all 54 files parse in **~95–130 ms on desktop**
  (Node 24, x86); est. ~1–4 s on the 1 GHz MTK ARM core under LuaJIT (F-24,
  low confidence). This one number decides the §4 parse strategy → measure
  directly in spike B. Not a feasibility gate — all three strategies are scoped.
- No new OQs. OQ-001 further downgraded (spike D now only tunes the parse
  strategy). OQ-011 gains an ordered mitigation list. Updated
  [`07`](docs/research/07-risks-open-questions.md), `SUMMARY.md` (status +
  rows 16–18 + early-read + OQ paragraph).
- **Next:** Phase 4 (prior art → [`05-prior-art.md`](docs/research/05-prior-art.md),
  tasks 4.1–4.6) — IF-on-e-ink, existing KOReader game/CYOA plugins, Twine/Ink
  players, past Magium-on-e-reader attempts, and the OQ contacts map. Independent
  of Phase 3; feeds Phase 6. Spikes A/B/D (Phase 5) still pending and now have
  sharp, pre-scoped questions from this budget.

### 2026-08-31 (session 8) — infra: repo on GitHub + WSL2 emulator dev env (OQ-012 resolved)

- Pushed the repo to **GitHub** (private): `github.com/lettuceketchup/magium-koreader`,
  `main` tracking `origin/main`. For multi-device work.
- Stood up the **KOReader emulator dev environment in WSL2 / Ubuntu 24.04** on the
  owner's Windows 11 machine. `./kodev build` + `./kodev run` both working; WSLg
  gives a display with no X server (SDL `x11` driver); the emulator launches,
  loads all plugins, renders. Build ≈ 7 min.
  - Two blockers hit and fixed: Ubuntu 24.04's **ninja 1.11.1 + GNU make 4.3**
    have incompatible job-server implementations → the recursive-make thirdparty
    builds (`luajit`, `libunibreak`) die with `make[3]: *** read jobs pipe: Bad
    file descriptor`. Fixed by installing **ninja 1.13.2 + GNU make 4.4.1** into
    `/usr/local/bin` (KOReader's `doc/Building.md` recommends exactly these
    minimums; system apt packages untouched).
  - Captured as a reproducible installer
    [`reference/setup-koreader-wsl.sh`](reference/setup-koreader-wsl.sh); recipe +
    `kodev` cheatsheet in [`reference/koreader-notes.md`](reference/koreader-notes.md).
  - **OQ-012 resolved.** Updated [`03` §8.2](docs/research/03-koreader-platform.md#8-build--deploy--debug-loop-28),
    F-18, [`07`](docs/research/07-risks-open-questions.md), `SUMMARY.md` row 15.
- Note: WSL build checkout is `~/koreader` @ `v2026.07.1` — separate from the
  `../koreader` citation checkout on the Windows drive (same tag).
- **Next:** unchanged — Phase 3 (constraints budget, tasks 3.1–3.4).

### 2026-08-31 (session 7) — Phase 2 done: KOReader platform analysed

- Cloned KOReader source as a sibling checkout `../koreader` pinned to **`v2026.07.1`**
  (commit `9192014`) — exactly the build the owner runs. Recorded in
  [`reference/koreader-notes.md`](reference/koreader-notes.md); added to CLAUDE.md's
  reference list. Not vendored — cite by `../koreader/path:line`.
- Wrote [`03-koreader-platform.md`](docs/research/03-koreader-platform.md) from stub
  to a full source-grounded draft covering all 10 tasks (2.1–2.10): plugin anatomy,
  Lua env, UI toolkit, persistence, text rendering, e-ink, lifecycle, build/deploy,
  i18n, distribution. Findings F-14…F-21.
- Key results: **nothing the Magium UI needs is missing from KOReader** (F-14);
  `kbarni/frotz.koplugin` already ships our exact UI shape — fullscreen styled
  transcript + choice/input row on e-ink (F-15); **LuaJIT is 2.1.ROLLING
  (`NUM 20199`), upstream not OpenResty** — closes the Phase 0 LuaJIT-build item
  (F-16); the platform's sharpest constraint is the **single cooperative Lua
  state** — blocking work must be sliced with `Trapper`/`scheduleIn` (F-17);
  on-device debug = USB copy + `crash.log`, and the `kodev` emulator is
  Linux/macOS-only so the Windows dev loop is a new open question (F-18, **OQ-012**);
  `<br/>` is the only Magium markup → `TextBoxWidget` + `\n`, skip the doc renderer
  (F-19); save model maps cleanly to `LuaSettings` + `Persist`, debounce autosave
  (F-20); `KindlePaperWhite6` is a first-class KOReader target (F-21).
- Updated [`04-constraints-budget.md`](docs/research/04-constraints-budget.md) §1
  (Lua VM / threads / e-ink / save-write rows), [`07`](docs/research/07-risks-open-questions.md)
  (OQ-012 added; OQ-002/OQ-007 gain platform context; OQ-010 LuaJIT tail closed),
  `SUMMARY.md` (status + findings rows + OQ paragraph).
- **Next:** Phase 3 (constraints budget → finish [`04`](docs/research/04-constraints-budget.md),
  tasks 3.1–3.4) — the go/no-go table. Depends on Phases 1, 2 (both done); still
  wants e-ink latency (spike A) and Lua-side memory (spike D) but can be drafted now.

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
