# Research Plan — Magium on KOReader

- **Status:** research phase complete — Phases 0–6 and 8 done
  (approach chosen — [ADR-002](docs/decisions/ADR-002-porting-approach.md);
  roadmap written — [`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md));
  **Phase 7 deferred** (personal-use-only scope confirmed by owner —
  [ADR-003](docs/decisions/ADR-003-defer-licensing-distribution.md)).
  **Implementation underway** — the [Phase I spec](docs/specs/2026-08-31-plugin-architecture-and-phase-i.md)
  ([ADR-004](docs/decisions/ADR-004-plugin-internal-architecture.md)) is approved
  and **Phase I is complete** (on-device sign-off 2026-09-01).
  **Phase II merged to `main` 2026-09-02** (owner on-device sign-off) — full-corpus
  oracle parity **8887/8887**, in-game menu, back-nav cut
  ([ADR-006](docs/decisions/ADR-006-no-scene-back-navigation.md)).
  **Phase III merged to `main` 2026-09-02** ([spec](docs/specs/2026-09-02-phase-iii-saves.md) → stable,
  [ADR-007](docs/decisions/ADR-007-saves-scope.md)) — 50 manual save slots +
  `ui/savespage.lua`; import/export + rename cut, delete added. Owner on-device
  sign-off; busted 111/0, oracle-corpus 8887/8887, not pushed.
  **Phase IV merged to `main` 2026-09-03** ([spec](docs/specs/2026-09-03-phase-iv-stats.md)
  → stable) — `ui/statspage.lua` (the `KeyValuePage` allocation screen, faithful
  Confirm/Cancel, `?`-button tutorial), three stats-screen gates in
  `specials.lua` (#5/#9/#10), "Full immersion" unlock (#11), `main.lua` wiring
  (`special:stats`, menu row). Owner device sign-off after a first-pass fix
  (lingering tutorial popup → `?` button). busted 116/0, oracle-corpus 8887/8887
  (no `engine/scene` change), UI + flow smokes green. Not pushed.
  **New enforced convention:** every `ui/` change is emulator-verified + lands a
  `spec/ui`/`spec/flow` check before owner testing (CLAUDE.md). **Next: Phase V**
  (achievements).
- **Last updated:** 2026-09-03
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
- [x] 8.6 Start a new brainstorming cycle for the implementation design — **done (session 17, owner-approved):** the cycle is open; deliverable is [`docs/specs/2026-08-31-plugin-architecture-and-phase-i.md`](docs/specs/2026-08-31-plugin-architecture-and-phase-i.md) — whole-plugin three-layer architecture + Milestone 0 + Phase I in build-ready detail, phases II–VIII as architectural notes. Layering/widget decisions recorded as [ADR-004](docs/decisions/ADR-004-plugin-internal-architecture.md). Spec is in review; on approval → writing-plans for an implementation plan.

---

## Running log

Newest entries at the top. One entry per work session: what was done, decisions, what's next.

### 2026-09-07 (session 34) — Phase VI implemented: settings + viewport robustness

Owner: "Start phase 6 planning" → approved plan (after a `/ponytail` pass that
cut a standalone viewport smoke + `mgm.sh viewport` subcommand + a
pre-committed ADR). Spec:
[`docs/specs/2026-09-07-phase-vi-settings.md`](docs/specs/2026-09-07-phase-vi-settings.md).
On `feat/phase-vi-settings`, **not merged, not pushed** — awaiting owner device
sign-off.

- **Scoping pass (the roadmap's "maybe none" for this phase):** of magium-dev's
  4 settings, only **cheat mode** and a **reader-local text size** are ported.
  Theme = KOReader native; language = Phase VII. No ADR — the "don't port
  theme/font/language" call is already in the roadmap; the two new decisions
  (text size is a plugin-local preset; live rotation stays Phase VIII) are
  small and uncontested (spec §3.6).
- **`main.lua`** — enabled the dead in-game-menu "Settings" row →
  `openSettings()` (a `ButtonDialog`): **Text size** sub-dialog (3 presets
  Small 17 / Medium 20 / Large 25, persisted as `G_reader_settings`
  `magium_prose_size`, applied via the existing `_reopenReader()` — no new
  re-pagination path); **Cheat mode** → `ConfirmBox` reusing the localized
  `settingsCheatMode*` / `localeYes` / `localeNo` strings, sets
  `v_available_points = "50"` + `flush_now("cheat")`, one-shot & unconditional
  (parity with `settings.ejs`).
- **`ui/reader.lua`** — reads `magium_prose_size` in `init()` (the custom reader
  does not inherit KOReader's document font); `prose_height` floored at one
  prose line so a tiny viewport can't drive pagination to one-word-per-page;
  passes the page-body height into `Choices.build`; frees a scrolling choices
  page's crop buffer on re-render (`onCloseWidget`, which `WidgetContainer:free`
  doesn't reach).
- **`ui/choices.lua`** — when the built `ButtonTable` is taller than the page
  body, crop it into a `ScrollableContainer` sized to the budget; else return
  it bare (zero change for the common PW12 case).
- **Viewport testing** — new **`mgm.sh test-ui-matrix`**: re-runs `test-ui-real`
  across 4 profiles (600×800@167, 1072×1448@300, 1272×1696@300, 1860×2480@300).
  `spec/ui/reader_smoke.lua` extended: page-body-in-bounds asserts, paint at
  each text-size preset, a deterministic 60-choice scene proving the scroll
  wrap engages + paints. `spec/ui/main_e2e_smoke.lua` updated: the old
  "'Settings' is disabled" assert flipped to enabled + a new block driving
  Settings → cheat confirm (asserts `v_available_points == "50"` + disk flush)
  and Settings → Text size → Large (asserts `magium_prose_size == 25` + reader
  live). Added to the `verify` skill as the gate for any
  `reader.lua`/`pagination.lua`/`choices.lua` change.
- **Gates:** `test` **132/0** (unchanged — new asserts are in `spec/ui`
  smokes, not busted). `test-ui` + `test-ui-real` all 6 smokes green.
  `test-ui-matrix` green at all 4 profiles. `emu-smoke` clean (plugin loads,
  `crash.log` empty). `oracle-corpus` **not re-run** — no `engine/` or
  `scene.render` change; baseline stays 8887/8887.
- **Next:** owner device pass (PW12) against the spec exit checklist, then
  `--no-ff` merge + log. Phase VII (localization) is the next phase.

### 2026-09-06 (session 33) — Phase V.5: test hardening (items 3, 5, 6 — the remainder)

Owner: "Do the rest of the phase 5.5 as well." Items 3/5/6 implemented on
`feat/phase-v5-remainder`, merged to `main` via `--no-ff` (`09e3d54`; branch
deleted, NOT pushed). All test-only, no device-facing change → no device
sign-off (same as items 1/2/4/7). Phase V.5 now complete.

- **Item 3 — systematic graph exploration.** `spec/flow/playthrough_spec.lua`:
  the greedy forward walker from the maxed-stats test extracted to a file-level
  `greedy_walk(g, scenes, start, apply)` (`apply` runs after `start()`, which
  wipes the store). New test runs it under 4 stat profiles — `maxed` (all 5),
  `zero` (Store defaults), `phys` (str/tough/agi/reflex), `mage` (the 4
  magical stats) — and asserts (a) each profile reaches > 20 distinct scenes
  (walker not stuck), (b) each *weak* profile reaches ≥ 1 scene the maxed
  greedy path skips (failed-stat-check branches), (c) the union strictly
  exceeds the maxed walk alone. Reachability-under-varied-state coverage the
  per-scene `oracle-corpus` sweep structurally can't give.
- **Item 5 — content stress paint.** `spec/ui/reader_smoke.lua`: new block
  parses the whole corpus, sorts every `choice()` label by width, builds a
  choices page from the 15 widest (longest = **97 chars**) and paints it for
  real via `Screen.bb` — `RM_PROSE`'s "Go on" never stressed the button
  column. `spec/ui/savespage_smoke.lua`: audits `locale:header()` across every
  corpus scene id (widest slot name = **"Book 2 - Chapter 10"**, < 40 chars —
  bounded by construction, confirmed not assumed) and paints a full 50-slot
  list built from it (the file had no `paintTo` at all before).
- **Item 6 — parse-time tripwire.** `spec/engine/story_eager_spec.lua`: one new
  `it` times a fresh `Story.new{…}:preload()` and asserts `< 3.0s`. Loose on
  purpose — dev-machine actual ≈ **0.24s**, on-device cold ≈ 2.2s (spike 06);
  3s never flakes on a busy box but catches an accidental O(n²). Comment says
  re-measure on device before ever bumping it.
- **Docs:** Phase V.5 spec Status → all 7 landed + exit criteria filled;
  roadmap Phase V.5 callout → "Complete", effort-table row, "Shipped
  2026-09-06" bullet. No ADR (test-infra only). No CLAUDE.md change — the
  standing regression rule already covers these files by pattern.
- **Gates:** `test` **132/0** (was 130; +1 varied-profile walk, +1 parse
  budget), `test-ui` + `test-ui-real` both green (6 smokes each).
  `oracle-corpus` **not** re-run — pure `spec/` change, no `engine/`/render
  path touched (baseline stays 8887/8887). `emu-smoke` not run (no runtime
  code touched).
- **Next:** Phase VI (settings) — unblocked since session 32; Phase V.5 fully
  closed now.

### 2026-09-05 (session 32) — Phase V.5: test hardening (items 1, 2, 4, 7)

Owner: "Start phase 5.5" → "High-value 4" (items 1/2/4/7; 3/5/6 deferred),
real-`Persist`-temp-dir for the E2E harness. Merged to `main` via `--no-ff`
(`88d119c`; branch `feat/phase-v5-test-hardening` deleted, NOT pushed); owner
device sign-off **not** required — V.5 ships no device-facing behavior
(test-only). Per
[Phase V.5 spec](docs/specs/2026-09-04-phase-v5-test-hardening.md).

- **Item 7 — real-resolution smoke bootstrap.** The gap that let the Phase V
  title-wrap bug through: `commonrequire`'s `einkfb.dummy=true` hardcodes
  `Screen` to 600×800, ignoring `EMULATE_READER_W/H`, so every
  `spec/ui/*_smoke.lua` `paintTo` check only ever proved "doesn't crash".
  - **`spec/support/real_screen.lua`** — a `commonrequire` clone that skips the
    dummy flag; a non-dummy SDL3 framebuffer under xvfb honours
    `EMULATE_READER_W/H` (`base/ffi/SDL3.lua:118`) + `EMULATE_READER_DPI`
    (`framebuffer.lua:128`) → a real **1272×1696 @ 300 dpi** Screen. Asserts the
    size took (fail-loud if no X server).
  - **`mgm.sh`**: `real-screen` (= `koenv` + xvfb + `MAGIUM_REAL_SCREEN=1`) and
    `test-ui-real` (the 5 smokes under it). `test-ui` stays the fast dummy path.
  - All 5 existing `spec/ui/*_smoke.lua` switched to a one-line bootstrap:
    `MAGIUM_REAL_SCREEN` → `real_screen`, else `commonrequire`. Green both ways.
- **Item 1 — app-level E2E harness.** `spec/ui/main_e2e_smoke.lua` +
  `spec/support/koenv_boot.lua` (points `KO_HOME` at a throwaway dir via
  `ffi.C.setenv` **before** any DataStorage resolve → real `Persist` blobs,
  isolated per run). Builds the real `Magium` object (`main.lua`) with a fake
  `ui` table, drives it headless with a captured widget stack + inline
  schedulers: `openReader` (real parse + fresh start), `openMenu` (checkpoint /
  Settings button disabled-state), each sub-screen opened **from its real menu
  callback** + returning to a live `Reader`, real slot-save to disk, `newGame`
  confirm→reset keeps achievements, `onSuspend` flushes to disk,
  `onClose`/`onCloseWidget` clean, trace-file reopen doesn't error. 30 checks.
- **Item 2 — achievements content integrity.** New `describe` block in
  `spec/engine/navigation_spec.lua`: cross-refs all 136 `achievements{1,2,3}.json`
  variables against every corpus `achievement()` call + the 2 known
  no-call unlocks (`v_ac_ch6_immersion`, `v_ac_b3_ch9_prize`). Both directions
  (orphaned menu entry / stray toast). Currently 136 JSON, 134 with a call, 0
  orphans, 0 strays.
- **Item 4 — save-schema regression.** `spec/save/fixtures/save_v1.lua` (frozen
  Phase-V blob shape) + `spec/save/schema_compat_spec.lua` — loads it through the
  real `SaveManager` and asserts `load` / `load_checkpoint` / `slots_meta` /
  `load_slot` all land their fields. Tripwire for a silent old-save-won't-load
  regression; add `save_v2.lua` when the format changes.
- **Docs:** the standing "every phase runs + updates the regression suites" rule
  now names the concrete files (CLAUDE.md "Doing implementation work" + `verify`
  skill); `mgm.sh` header, roadmap Phase V.5 row + effort table, `docs/specs/README.md`
  (backfilled III/IV/V/V.5 rows). No ADR — item 7 + the fake-vs-real-Persist call
  are test-infra choices the spec §2.1 already records.
- **Gates:** `test` **130/0** (was 122; +3 integrity, +5 schema_compat), `test-ui`
  + `test-ui-real` both green (6 smokes incl. the new E2E), `oracle-corpus`
  **8887/8887** (no `engine/` byte changed — parity cannot have moved; run anyway).
  `emu-smoke` not run: no `main.lua`/`ui/` code touched, only `spec/` + tooling.
- **Next:** Phase VI (settings) — now unblocked. Deferred V.5 items 3/5/6 are
  roadmap follow-ups, not blockers.

### 2026-09-04 (session 31) — project workflow skills (`phase` / `verify` / `device`)

Tooling/docs only — no `magium.koplugin/` code touched, so no gates apply.

- Audited the 30-session running log for repeating semi-deterministic tasks
  (build, test, deploy, ssh, ui verification, log retrieval, the phase
  merge ritual). Captured the three highest-cost ones as project skills under
  `.claude/skills/` (auto-discovered by Claude Code, pointed at from CLAUDE.md):
  - **`verify`** — the change→test-suite decision matrix (`busted` /
    `oracle-corpus` / `test-ui` / `emu-smoke`), what "green" means, the
    `paintTo`-per-reachable-state rule + the dummy-`Screen` 600×800 caveat,
    the "regression suites stay current" rule, and oracle-DIFF triage.
  - **`device`** — SSH deploy (`kindle-ssh-deploy.ps1 -Name paperwhite`), the
    MTP fallback + its silent-no-overwrite gotcha, the owner-checklist framing,
    and a new **`.claude/skills/device/scripts/kindle-pull-logs.ps1`** (reuses
    `tools/kindle-ssh-common.ps1`) that pulls `crash.log` + the whole
    `koreader/magium/` state dir to a scratch dir and greps the log — the
    "pull evidence before theorizing" step that was hand-written each device pass.
  - **`phase`** — the full lifecycle: pick/unblock → brainstorm → spec (+
    `docs/specs/README.md` row) → `feat/` branch → implement (ponytail) → ADR
    if a decision closes an alternative → `verify` → `device` sign-off →
    `--no-ff` merge + re-verify + branch teardown → running-log + memory.
- **Docs re-pointed at the skills, redundancy trimmed:** CLAUDE.md gains a
  "Workflow skills" section and its two fat "Doing implementation work" bullets
  (ui-verification, regression-suites) collapse to one-liners + a skill
  pointer; `reference/koreader-notes.md`'s two workflow sections get a
  "workflow entry point: the X skill" note above the (retained) command
  reference; `docs/research/09-roadmap-effort.md` §1 and `docs/specs/README.md`
  get one-line pointers. The three procedural memory files
  (`device-deploy-and-ui-testing`, `emulator-first-for-ui-changes`,
  `regression-tests-stay-current`) trimmed to the *why* + owner-directive
  origin, deferring the *how* to the skills; `MEMORY.md` index updated.
- **Next:** unchanged — owner runs Phase V.5, then Phase VI (via the `phase`
  skill).

### 2026-09-04 (session 30) — Phase V implemented: achievements

Built the achievement unlock toast and browsable menu, per
[Phase V spec](docs/specs/2026-09-04-phase-v-achievements.md).

- **`engine/scene.lua:persist_effects`** extended (not a new function) to flip
  each shown achievement's flag `"1"` → `"2"` (seen), mirroring the JS
  oracle's `storeVariable(variable,"2")` in the same per-render loop that
  shows the modal. `scene.render()` itself untouched — `oracle-corpus` stays
  **8887/8887**.
- **`engine/locale.lua`** loads `achievements{1,2,3}.json` (136 entries),
  indexed by group key (menu) and by variable (`achievement_title`, for the
  one special case with no in-story `achievement()` call). Owner asked for
  exact on-disk chapter ordering (`b2ch41`/`b2ch42` inline between
  `b2ch3`/`b2ch5`, not sorted after the book's last chapter) — `json.decode`
  doesn't preserve key order, so recovered it with one `gmatch` pass over each
  book's raw JSON text at load time.
- **`ui/toast.lua`** (new) — one `Notification` per unlock, single combined
  line (`"ACHIEVEMENT UNLOCKED: <title>"`); KOReader's `Notification` wraps a
  single-line `TextWidget` (confirmed from source, no wrap), collapsing the
  reference's two-row layout — flagged as an easy later swap if the owner
  wants two stacked toasts instead.
- **`ui/achievementsmenu.lua`** (new) — `Menu:extend`, 3-level book → chapter
  → entry drill-down via the standard `self.paths` + `switchItemTable` +
  `onReturn` idiom (`koreader/plugins/opds.koplugin`), not `savespage.lua`'s
  flat list. Locked/unlocked via native `dim`, not a hand-rolled glyph.
- **`main.lua`**: toast wired into `render_current()` (every render that shows
  achievements) and into `openStats()`'s `v_ac_ch6_immersion` special case
  (its own modal in the reference, no in-story `achievement()` call — found
  while wiring, not in the original plan); "Achievements" menu row enabled
  (was disabled since Phase I); `openAchievements()` added.
- Tests: `scene_spec` (latch + freeze), `locale_spec` (136 entries, exact
  chapter order), `toast_smoke.lua` (new), `achievementsmenu_smoke.lua` (new,
  asserts chapter-order-by-position + locked/unlocked), a real-achievement
  flow case in `playthrough_spec.lua` (Ch1 "coward" — shows once, latches,
  no re-toast).
- All green: busted **122/0** (was 116), `oracle-corpus` **8887/8887**
  (unchanged), all 5 `spec/ui/*_smoke.lua` incl. the 2 new ones, `emu-smoke`
  clean load. Not pushed; not yet on-device.
- Deployed to the device via `tools/kindle-ssh-deploy.ps1 -Name paperwhite`
  (79/79 files verified). **SSH deploy is now the standing default — always
  use it when the device is reachable; USB/MTP (`deploy-kindle.ps1`) is
  fallback-only** (owner directive; updated `reference/koreader-notes.md`).
- **First device pass (same session):** toast confirmed working; opening
  Achievements → Book 1 worked, but **selecting any chapter crashed**
  (`textwidget.lua:224: bad argument #2 to 'makeLine' (width must be
  strictly positive)`, pulled via SSH `crash.log`). Root cause: entry rows
  used `mandatory = e.caption` — `mandatory` is an unwrapped single-line
  `TextWidget` (file size, page number, ...), and a full caption sentence
  overflows it, driving `available_width` negative at paint. The smoke test
  had only asserted `item_table` structure, never actually painted the
  widget, so it missed this entirely.
  - **Fix:** fold the caption into `text` instead (`title .. " — " ..
    caption`), which Menu wraps/shrinks/ellipsizes safely by default.
  - **Test gap closed:** `spec/ui/achievementsmenu_smoke.lua` now calls
    `widget:paintTo(Screen.bb, 0, 0)` for real (inside `pcall`) — the book
    list, one chapter list, and all 34 chapter entry-list screens across the
    3 books — not just structural asserts. Verified this would have caught
    the original bug (reintroduced the buggy line locally, confirmed 35
    checks failed; restored the fix, confirmed 0 failed).
  - **Rule sharpened:** CLAUDE.md's emulator-first rule (and the
    `emulator-first-for-ui-changes` memory) now explicitly requires a real
    `paintTo` per reachable screen/state, not just structural checks —
    owner directive, 2026-09-04.
  - Re-deployed via SSH; busted 122/0, all 5 UI smokes green (36 paint
    checks in the achievements menu alone). Awaiting a second device pass.
- **Phase V.5 (test hardening) scoped, same session.** Owner asked what
  "proper testing" for a game of this shape would look like and what's
  missing — audited the whole suite against a standard test pyramid
  (differential/unit/content-validation/flow/widget/app-level/manual).
  Strong on differential (`oracle-corpus`), unit, content-validation
  (`navigation_spec.lua`), flow, and widget layers; **zero coverage of the
  app-level layer** — nothing ever constructs the real `Magium` object
  (`main.lua`) and drives it, which is exactly the layer both device-only
  bugs this session lived in. Scoped as a new **Phase V.5**, inserted
  between V and VI in the roadmap, owner's own session, **blocks Phase VI**:
  1. app-level/E2E harness (highest value — construct real `Magium`
     headlessly, drive menu→screens→newGame→suspend/close)
  2. orphaned-achievement content-integrity check (cross-reference JSON
     variables against parsed `achievement()` calls + `specials.lua`
     exceptions)
  3. systematic graph exploration (multi-profile walk, lower priority —
     `oracle-corpus` already covers per-scene condition correctness)
  4. save schema/compatibility regression fixture
  5. content stress-testing beyond achievements (longest choice label, etc.)
  6. parse-time performance regression tripwire

  Full design notes in
  [`docs/specs/2026-09-04-phase-v5-test-hardening.md`](docs/specs/2026-09-04-phase-v5-test-hardening.md);
  roadmap entry in `docs/research/09-roadmap-effort.md`. **New standing rule**
  (CLAUDE.md "Doing implementation work"): every subsequent phase/change must
  run and update whatever regression suites exist, not just add its own.
- **Second device pass, same session.** Chapters opened without crashing
  (1st-pass fix held), but two real layout problems remained: the title text
  was single-line-ellipsized (not multi-line) and locked/unlocked had no
  visible checkbox, only text-dim color.
  - **Root cause of BOTH the bug and why the emulator "passed" it: found a
    real infra gap.** Every `spec/ui/*_smoke.lua` requires `commonrequire`,
    which sets `einkfb.dummy = true` — koreader's dummy `Screen` backend
    **hardcodes a 600×800 buffer unconditionally**
    (`base/ffi/framebuffer_SDL3.lua:17`), ignoring `EMULATE_READER_W/H`
    entirely (those vars ARE real and correctly read by the *non-dummy* SDL
    path, `base/ffi/SDL3.lua:118` — just never reached in dummy mode). So
    every "paints without crashing" check this whole phase has only proven
    exactly that — crash-avoidance — never actual PW12-resolution layout.
    Diagnosed + fixed `mgm.sh koenv`'s misleading comment; built a one-off
    non-dummy, `Xvfb`-backed screenshot script
    (`Device.screen:init()` without the dummy flag + `Screen.bb:writePNG`) to
    get a real 1272×1696 render and actually look at the bug.
  - **Fix:** `multilines_show_more_text = true` on the `AchievementsMenu`
    (koreader's own "shrink font to show wrapped text" mechanism — the
    default path auto-promotes to single-line-ellipsis whenever the font
    doesn't fit 2 lines at the row's *default* height, regardless of how much
    room the row actually has); a real `✓`/`▢` checkbox glyph in `mandatory`
    (short — safe, unlike the 1st-pass crash which was a *long* caption
    there) — the exact glyphs koreader's own `ui/widget/checkmark.lua` uses
    for the same purpose everywhere else in the app. Verified via
    before/after screenshots.
  - **New feature (owner-requested, no magium-dev reference):** reset-all-achievements
    — a title-bar warning icon + `ConfirmBox`
    ("Reset all achievements? This cannot be undone.") on the achievements
    screen, `on_reset` callback wired in `main.lua` (keeps everything except
    `v_ac_*`, mirrors `reset_to_intro`'s inverse).
  - Smoke test updated to match (`✓`/`▢` glyph assertions, reset-flow
    assertions); busted 122/0, all 5 UI smokes green. `oracle-corpus` not
    re-run (zero `engine/` touch this round, UI-file changes only).
  - Redeployed once the device came back online (79/79 files verified).
- **Owner review of that fix, same session:** title now wraps and the
  checkbox shows, but the caption still ran directly into the title on one
  line instead of its own — and no keyboard boxes should appear on the
  screenshots (real device is touch-only).
  - **Keyboard-shortcut boxes: confirmed screenshot-environment artifact,
    not a bug.** `is_enable_shortcut = Device:hasKeyboard()`
    (`menu.lua:604`) — purely a device-capability flag, nothing in this
    plugin's code. The ad hoc verification script never selected a
    touch-only device profile, so the desktop-like default reported a
    keyboard. Real PW12 (`Device:hasKeys()` false) never shows these.
  - **Caption-on-its-own-line: real bug, root-caused precisely.**
    `text = title .. "\n" .. caption` never produced a hard break because
    `MenuItem:init` unconditionally runs `self.text:gsub("\n", " ")`
    (`menu.lua:211`) *before* any font-size/wrap branch even sees the
    string — true regardless of `multilines_show_more_text`. No in-`text`
    trick can force a break inside one Menu row. **Fix:** two real Menu rows
    per achievement — title row (checkbox in `mandatory`) immediately
    followed by a caption row (`dim=true`, `select_enabled=false`, no
    `mandatory`) — each row is a genuine line by construction, no custom
    widget. Trade-off: the per-row separator line now also falls between
    title and caption (Menu has no per-item override for it) — minor,
    still reads clearly since only title rows carry the checkbox.
  - Verified via a fresh screenshot at the real resolution: title + caption
    now genuinely on separate lines. Smoke test rewritten to match (checks
    the caption is a distinct `level="caption"` row right after its title,
    not text baked into the title row). busted 122/0, all 5 UI smokes
    green. Redeployed.
- **Owner review of that fix, same session:** caption had its own line now,
  but a separator rule fell between title and caption too (same weight as
  between different achievements), and title/caption looked near-identical
  besides the checkbox + slightly lighter grey.
  - Asked first (per owner request): presented 4 options — bold title only;
    bold title + drop the separator line at the entries level, relying on
    the bold to mark new groups; soften all lines uniformly (rejected as a
    wash — softens the wanted separation between achievements too); a full
    custom row widget bypassing `Menu`'s per-row renderer (rejected —
    `Menu:updateItems()` hardcodes `MenuItem:new{...}` with no override
    hook, so custom would mean reimplementing scroll/paging/tap-hitboxes or
    monkey-patching koreader's own vendored file; not justified here).
  - Owner picked bold + drop-the-line. `bold` turns out to be a real
    per-item field (`menu.lua:1110`, missed in the earlier passes);
    `self.linesize`/`line_color` are Menu-instance-wide only (no per-item
    override exists), so toggled `self.linesize = 0` right before switching
    into the entries level and restored it (pushed/popped alongside
    `self.paths`) on the way back out. Books/chapters keep their lines.
  - Verified with a fresh screenshot before deploying (owner asked to see it
    first): clean result — bold black title + checkbox, dim caption right
    below, no line anywhere in the entry list, chapters/books unaffected.
  - Smoke test extended: title `bold==true`, `m.linesize==0` at entries,
    `m.linesize~=0` at chapters and after `onReturn`. busted 122/0, all 5 UI
    smokes green. Redeployed.
- **Owner confirmed the achievements-menu layout fix on device: "looks
  good."** Branch pushed to `origin/feat/phase-v-achievements`.
- **Owner confirmed the rest of the Phase V exit checklist done** (toast
  fires once + no repeat on resume, immersion toast from the stats screen,
  reset icon asks for confirmation and actually clears every achievement).
- **Phase V MERGED to `main` 2026-09-04** (`2ec0dad`, `--no-ff`; verified
  green on the merged tree — busted 122/0, all 5 UI smokes — before pushing).
  `origin/main` updated (`d96db02..2ec0dad`); `feat/phase-v-achievements`
  deleted (local + remote).
- **Next:** **Phase V.5** (owner's own session, test hardening — covers the
  dummy-`Screen` resolution gap found this round; full scope in
  [`docs/specs/2026-09-04-phase-v5-test-hardening.md`](docs/specs/2026-09-04-phase-v5-test-hardening.md)) —
  Phase VI does not start until it lands.

### 2026-09-03 (session 29b) — Phase IV: first device pass, tutorial reworked

Owner ran Phase IV on the PW12. **2–6 (spend / Confirm / Cancel / persist /
in-story invest) all work.** One bug: the first-visit tutorial `TextViewer`,
shown from `StatsPage:init()`, was never closed — it lingered in the UIManager
stack behind the reopened reader, flashed on repaint, and surfaced as a stuck
"dictionary window" on game-close.

- **`ui/statspage.lua`** — dropped `_maybe_intro` + the `magium_stats_intro_seen`
  `G_reader_settings` flag. Added a **`?` title-bar button**
  (`title_bar_left_icon = "notice-question"` → `_show_help()` opens the same
  `TextViewer` on demand, on top, user-dismissable). Owner's own suggestion;
  also kills the "first time per save" question (no seen-state at all now).
- **Device crosscheck** — pulled `crash.log` + `magium/` over SSH: no magium
  traceback; `state` blob confirms a persisted spend (`v_premonition = 3`,
  `v_available_points = 0`). The lingering widget doesn't throw, it's a
  UI-stacking mistake.
- **"-spent scene" explained + tested** — a `special:stats` "Invest points now"
  choice carries *both* `v_current_scene = <Scene>-Stats-spent` and
  `special:stats`, so it navigates to a near-duplicate scene (only choice:
  "Continue" → the real next scene) and opens the stats screen over it. Nothing
  mechanically special about the id. 2 new `spec/flow/playthrough_spec.lua`
  cases (ch2 `Ch2-Stats` → `Ch2-Stats-spent` → `Ch2-Fallen-trees`; `B3-Ch04a`
  `-spent` trips the book-3 row gate) — the emulator-side "book 3 without a
  device" coverage the owner asked for. `statspage_smoke` extended: real
  book-3 scene ids, combined magic+book3 = 17 rows, the `?` button.
- **Gates:** busted **116/0** (+2 flow), `test-ui` green (`statspage_smoke`
  25 checks), headless emu load clean. `oracle-corpus` unchanged (no
  render-path change — `specials.lua` only gained unused-by-render functions).
- **New enforced convention** (owner ask): every `ui/` change is verified in the
  emulator **and** lands a `spec/ui/*_smoke.lua` / `spec/flow/*` check before the
  owner is asked to test — the device pass is the final e-ink/input
  confirmation, not the first check. Codified in `CLAUDE.md` "Doing
  implementation work" + `09-roadmap-effort.md` §1.
- **Owner device re-test 2026-09-03: "Good, it works".** Spec → **stable**,
  `feat/phase-iv-stats` merged to `main` (`--no-ff`), branch deleted; busted
  **116/0** on the merged tree. Not pushed. **Next:** Phase V (achievements).

### 2026-09-03 (session 29) — Phase IV implemented: stat-allocation screen

Branch `feat/phase-iv-stats`. Spec: [`docs/specs/2026-09-03-phase-iv-stats.md`](docs/specs/2026-09-03-phase-iv-stats.md).
The stat-check *display* half of "stats" already shipped in Phase I/II; this
phase is the interactive screen.

- **`ui/statspage.lua`** (new) — a fullscreen `KeyValuePage`: available points +
  one row per stat (`value / max`), tap an allocatable row to spend a *pending*
  point, `Confirm changes` / `Cancel changes` rows, `Return to game` = the
  page's normal close. **Owner chose to port magium-dev's Confirm/Cancel
  faithfully** (pending overlay in the widget; only Confirm persists; Return to
  game drops pending). First-visit tutorial modal ported (one `TextViewer`,
  `G_reader_settings` flag `magium_stats_intro_seen`).
- **`engine/specials.lua`** — three pure gates from `stats.ejs`:
  `maximized_stats` (#5), `stats_show_magic_rows` (#9, faithful to the JS
  `|| 0` truthiness — `"0"` still shows the rows), `stats_show_book3_rows`
  (#10, `sceneAfter`: book 3, chapter ≥ 4, `[a-c]` mandatory). +1 `specials_spec`
  block (boundary cases).
- **`main.lua`** — `Magium:openStats()`; `special:stats` now opens it (was an
  `InfoMessage` stub); a **Stats** row in the in-game `ButtonDialog` (the
  persistent `STATS`-button equivalent); the "Full immersion" unlock (#11 —
  `v_ac_ch6_immersion = 1` + `on_achievement_unlocked` at `Ch6-Eiden-vs-dragon`
  with `v_maximized_stats_used`). `on_confirm` replays the pending map through
  `store:set` + `flush_now("stats")`; `on_close` re-renders via the existing
  `_reopenReader()` (a confirmed spend can open a stat-gated choice on the
  `-spent` scene).
- **Cut** (ponytail): no new `engine/` module — the row list is a static array +
  two predicates, assembled in the UI file; no `Reader:refresh_scene` — reused
  `_reopenReader()`. **Out of Phase IV:** the "Full immersion" toast (Phase V);
  the `maximized` count-up animation (cosmetic, end state == real values).
- **Gates:** busted **114/0** (was 111), `test-ui` green incl. new
  `spec/ui/statspage_smoke.lua` (19 checks), `oracle-corpus` **8887/8887**
  (no `engine/scene` change — pure regression), headless emu load clean.
  Not pushed.
- **Next:** owner deploys + on-device sign-off (menu → Stats, spend/Confirm/
  Cancel, restart-persistence, an in-story "Invest points now"), then spec
  `stable` + merge to `main`. Then Phase V (achievements).

### 2026-09-02 (session 28) — Phase III implemented: 50 manual save slots

Branch `feat/phase-iii-saves`. Spec: [`docs/specs/2026-09-02-phase-iii-saves.md`](docs/specs/2026-09-02-phase-iii-saves.md).
Checkpoint was already done (pulled forward in Phase II), so this phase is just
the manual slots.

- **`save/manager.lua`** — new optional injected `slotstore` adapter
  (`{load,save,remove}`) + 4 methods: `save_slot` / `load_slot` / `delete_slot` /
  `slots_meta`. `load_checkpoint` + `load_slot` now share `_restore_snapshot`,
  which merges the **live** `v_ac_*` from the store (not the last-flushed blob) —
  robust regardless of achievement-flush timing. Autosave never touches
  `slotstore`. +6 manager cases + 1 headless slot round-trip flow case (→ busted **111/0**).
- **`ui/savespage.lua`** (new) — fullscreen `Menu` of 50 slots; tap → `ButtonDialog`
  (Save here / Load / Overwrite / Delete), Overwrite+Delete behind a `ConfirmBox`.
  Refreshes in place via `switchItemTable`. New `spec/ui/savespage_smoke.lua`
  (plain-assert, `mgm.sh koenv`) — green.
- **`main.lua`** — `slot_store()` adapter (one `Persist` blob per slot under
  `magium/slots/NN.blob`, no index — spec D2); `Magium:openSaves()`; the in-game
  menu "Save / Load game" row and `special:saves` both open it now (were disabled
  / routed to the menu in Phase II).
- **[ADR-007](docs/decisions/ADR-007-saves-scope.md)** — three deviations from
  `magium-dev`'s saves screen: import/export cut (no clipboard on device; owner
  has USB/SSH), rename cut (slot name = chapter header, no keyboard prompt),
  delete added.
- No `engine/` change → `oracle-corpus` unaffected (sweep re-run as a regression
  gate). Headless emulator load clean.

**Owner device pass** (session end): save/load round-trip via the menu row,
overwrite/delete, survives a KOReader restart — "All good". Spec → **stable**,
merged to `main` (`c242473`, `--no-ff`); `feat/phase-iii-saves` deleted; busted
**111/0** on the merged tree. Not pushed. **Next:** Phase IV (stats).

### 2026-09-02 (session 27b) — Phase II merged to main

Owner on-device sign-off ("All seems good") after a clean key-only-SSH deploy.
Spec → **stable**. `feat/phase-ii-full-corpus-nav` merged to `main` (`bbcd114`,
`--no-ff`) and deleted; busted **104/0** on the merged tree. Not pushed
(`origin/main` unchanged). Phase III (50-slot saves UI + real checkpoint blob) is
next per the roadmap.

### 2026-09-02 (session 27) — SSH deploy: per-device key setup (owner: "all or nothing" passwordless is no good)

KOReader's "Login without password" is global, so the WiFi deploy now uses
**key-only auth** with a per-device setup, all state gitignored under
`tools/.kindle/` (one `id_ed25519` keypair + `devices/<name>.json`).

- `tools/kindle-ssh-common.ps1` — dot-sourced helpers: keypair gen (`-N '""'` is
  the Windows-OpenSSH empty-passphrase form), device-config load/save,
  `Test-KindleSsh` (probes `MAGIUM_SSH_OK` + the real koreader dir).
- `tools/kindle-ssh-setup.ps1 -Name <n>` — USB; plants the pubkey at
  `koreader/settings/SSH/authorized_keys` over MTP (delete-first + size-verify,
  same MTP-won't-overwrite guard as `deploy-kindle.ps1`), creates `settings/SSH/`
  if the SSH server was never started, writes the device config.
- `tools/kindle-ssh-test.ps1 -Name <n> -Ip <addr>` — key-auth check; persists IP
  + probed koreader dir back to the config.
- `tools/deploy-kindle-ssh.ps1` → **renamed `tools/kindle-ssh-deploy.ps1`**; now
  resolves the target from the device config, runs `Test-KindleSsh` before
  touching the device, uses `-i <key> -o BatchMode=yes`. `-Ip` alone still works.
- On device, one-time: SSH server → tick **"Login with key only (SECURE)"**.
- Smoke: 4 scripts parse-clean; common-helper round-trip/update/error paths pass.
- **End-to-end verified on the owner's PW12** (192.168.1.11): key planted over
  USB, key-auth test OK, deploy pushed 75/75 files, all 4 spot-checked files
  md5-identical to staging (no stale-MTP problem). Two PS-5.1 fixes en route:
  `2>&1` on native `ssh` throws under `EAP=Stop` (guard with local `EAP=Continue`);
  piping the sftp batch to stdin prepends a BOM → "Invalid command." (write the
  batch to a file, `sftp -b`).

### 2026-09-01 (session 26) — Phase II: owner device test → deploy bug found, checkpoint blob, UI test harness

Owner deployed Phase II to the Kindle and reported: menu doesn't work (any header
tap closes the game), `checkpoint_load`/`saves` softlock on death scenes, the
"Choices" footer is still there. Asked for emulator-based testing going forward.

- **Root cause of the menu report: the MTP deploy was silently NOT overwriting
  changed files.** The device was running a build from before session 22 (menu
  still a submenu). `tools/deploy-kindle.ps1` rewritten — **wipe the device
  plugin folder first**, then copy fresh, then **verify every file by size** and
  fail loudly. Nothing about Phase II's menu is actually broken (see next).
- **New headless UI test harness** (`tools/mgm.sh koenv` + `test-ui`,
  `spec/ui/reader_smoke.lua`): runs the real KOReader widget stack in the built
  emulator's Lua env, fires actual tap events at the `Reader`, asserts
  header-left→close, header-right/middle→menu, body→page-turn, no "Choices"
  footer. **9/9 — the Phase II header split is correct.** This is the regression
  test whose absence let the (stale-code) menu report look like a code bug.
- **`checkpoint` blob pulled forward from Phase III** (`save/manager.lua`:
  `save_checkpoint`/`load_checkpoint`/`has_checkpoint`; +3 tests). Fixes the
  real softlock: on a death scene (`B2-Ch07a-Kill` = `restart` / `checkpoint_load`
  / `saves` only), D4's no-op `checkpoint_load` left `restart` as the sole way
  out. Now it restores `currentState` from the checkpoint (achievements kept,
  parity); no checkpoint → an `InfoMessage`, not silence. Menu "Load from last
  checkpoint" enabled when one exists. `special:stats` → `InfoMessage` (Phase IV);
  `special:saves` → the menu (50 slots = Phase III). **D4 revised in the spec.**
- **`ui/reader.lua`**: choices page no longer shows the literal "Choices" footer.
- **Gates:** busted **97/0**, engine **72/0**, `test-ui` **9/9**, headless load
  clean, oracle-corpus still 8887/8887 (no `engine/` change). Commits `e70c8ee`
  (code) + this doc pass.
- **Deploy workaround (owner asked for one):** `tools/deploy-kindle-ssh.ps1` —
  deploy over WiFi via KOReader's SSH server (`rm -rf` + `sftp put -r`), no USB,
  no MTP, no manual delete. One-time: enable the SSH server in KOReader (Tools →
  Network). Now the preferred device loop. `deploy-kindle.ps1` (USB) kept as a
  fallback, now with the wipe+verify.
- **Emulator playthrough testing (owner asked — "no manual Book 1"):**
  `spec/support/headless_game.lua` plays the game headlessly (engine+save wired
  like `main.lua`); `spec/flow/playthrough_spec.lua` walks 100+ scenes of real
  choices + exercises checkpoint/restart/softlock paths;
  `spec/engine/navigation_spec.lua` statically checks every choice target +
  reachability. `mgm.sh test` 104/0, bare-luajit subset 89/0, `test-ui` 9/9.
- **Next:** owner enables the KOReader SSH server, runs `deploy-kindle-ssh.ps1`,
  spot-checks Phase II on device (menu, a checkpoint, restart, the footer). Then
  spec `stable` + branch merge.

### 2026-09-01 (session 25) — Phase II implemented: full-corpus parity 8887/8887, in-game menu, back-nav cut

Brainstorming → spec → writing-plans → executed inline on `feat/phase-ii-full-corpus-nav`.

**Shipped (commit `ade1a2f`):**
- **Scene `set()` write-back** — `engine/scene.persist_effects(store, rm)` (2-line
  pure helper, no `engine/commit.lua`), called in `main.lua` `render_current`.
  Ports magium-dev's per-render `storeVariable()` writes. Ships the faithful
  "re-applies on resume" quirk with a `ponytail:` upgrade comment.
- **Special case #8** — `specials.HIDE_DEVICE_LOCK_TEXT` + a `scene.lua` branch:
  empty device-lock stat label on `B3-Ch01a-Crossbow` only (its prose already
  states the lock). **`mgm.sh oracle-corpus` → 8887/8887**, 0 DIFF (was 8886).
  Carry-forward #3 (`Ch11b-Hole` `v_hearing <= 4`) confirmed clean in the sweep.
- **In-game menu** — `Magium:openMenu()` over KOReader `ButtonDialog` (no
  `ui/menu.lua`): full `menu.ejs` shell, Load-checkpoint/Save-Load/Achievements/
  Settings `enabled = false`, Back-to-game + New-game + About wired. Reached via
  a header tap-band split in `ui/reader.lua` (`close_zone_w`: left = close, right
  = menu; `"Menu"` label affordance). `special:saves`/`stats` → the menu;
  `checkpoint_*` stay no-op (D4).
- **New game** = `reset_to_intro` (keeps `v_ac_*`) → flush → close+reopen reader.

**Decisions:** D1 no back/history stack (**[ADR-006](docs/decisions/ADR-006-no-scene-back-navigation.md)**,
magium-dev has none — overrides the roadmap line); D2 menu full-shell-disabled;
D3 Crossbow faithful-empty; D4 checkpoint hooks no-op. Ponytail trims: 0 new
files (spec had called for `engine/commit.lua` + `ui/menu.lua` + 2 spec files).

**Gates:** engine subset 72/0, full busted 94/0, oracle-corpus 8887/8887,
headless `kodev` load clean, `main.lua` parses. **Not done:** owner on-device
playthrough (spec §9 last box) → then spec `stable` + branch merge.

**Out of Phase II (unchanged):** achievement `"1"→"2"` "seen" bump stays with
the Phase V toast.

**Next:** owner device run; then Phase III (saves) — its own spec cycle.

### 2026-09-01 (session 24) — oracle case matrix auto-derived; full-corpus sweep now runnable

Tooling, not plugin behaviour — the Lua engine is unchanged.

- **`magium.koplugin/spec/gen_cases.lua`** (new) replaces `tools/gen-ch1-cases.js`.
  Derives the oracle case matrix per scene straight from the parsed condition
  DNFs (`set()/choice()/#if`) + achievement vars — baseline, per-atom
  true/false boundary flips, one case per multi-var AND-group, one per
  achievement flag — with a generation-time coverage self-check
  (`conditions.eval` must see each DNF both true and false; warns, doesn't
  abort). No more hand-reading a chapter's variables. Linear in atom count,
  not a cross-product.
- **`spec/oracle_diff.lua`** de-hardcoded — globs all `data/en/*.magium` via
  `Story._list_magium` instead of the `ch1/ch3/b2ch1` literal.
- **`tools/mgm.sh`**: `gen-cases` and `oracle-corpus` (full generate → capture
  → render → diff sweep in one WSL invocation; output under the git-ignored
  `spec/out/`).
- **ch1 committed goldens regenerated through the new path**: 37 derived cases
  (was a 96-case hand matrix), 37/37 vs a fresh oracle, offline spec green.
  The hand-picked 6-case fixture (`oracle-cases.json` + its goldens +
  `_index.json`) is untouched — it covers text-quoting / scene-id / checkpoint
  edge cases the condition-derivation can't reach.
- **First full-corpus parity sweep — 8887 derived cases across all 54 files.**
  Started 8617/8887; every miss was one of two pre-existing blind spots in
  `reference/tools/oracle-diff.js`'s HTML normalizer, both fixed:
  1. choiceless scenes — `main.ejs` emits an orphan `</div>` before the header
     div; it was counted as a fake paragraph. Now bare closing-tag lines are
     dropped.
  2. choiceless scene **with** an achievement — the modal became the head/tail
     cut point, stranding its `storeVariable(v,"2")` script in the head (→
     phantom setVariable, starved achievements match). Cut now anchors on that
     script; the four brittle literal cut-markers (one with a hard `\n` that
     CRLF responses defeated) collapsed to a `min()` of three computed
     offsets; dead `firstIndex` removed.
  End state: **8886/8887**.
- **The one remaining diff** — `B3-Ch01a-Crossbow` @ `v_b3_ch1_unlock == 2`:
  magium-dev renders an *empty* stat-check label for the "stat device locked"
  sentinel; our `locale:stat_check_text` returns the readable
  `mainStatDeviceLockedText`. Not a tooling bug — logged as a Phase II
  hardcoded-special-case audit item (spec special-case #12 family; see
  [`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md) Phase II).
- **Next:** Phase II proper (full corpus load + navigation) — its spec cycle.
  Run `mgm.sh oracle-corpus` as the parity gate for that work.

### 2026-09-01 (session 23) — Phase I formally closed out

Bookkeeping only — no plugin code changed. Phase I was already code-complete and
merged to `main` (session 22); this session lands the paperwork so the Phase II
design cycle starts from a clean slate.

- **Doc reframe committed** (`488ca26`): `CLAUDE.md` + `README.md` moved from
  "feasibility study, no code" to "the port; Phase I landed, Phase II next".
- **Spec §11.2 exit criteria signed off** (`f5817b0`): all 7 boxes ticked.
  Automated gates re-confirmed on `main` HEAD — `busted` **89/0/0/0**, engine
  subset `luajit spec/run.lua` **67/0/0/0**, oracle diff **102/102** (96 `ch1`
  matrix + 6 goldens, fresh oracle vs fresh Lua render). Owner's session-22
  on-device playthrough covers the device-only criteria (ch1 start→finish,
  resume across close/suspend/restart, `crash.log` clean). Spec Status →
  **Phase I complete**.
- **SDD execution rulings archived** (`bcc18c7`) to
  [`docs/specs/phase-i-execution-notes.md`](docs/specs/phase-i-execution-notes.md) —
  `.superpowers/` is git-ignored, so the 13 controller rulings + the ledger
  self-review would have been lost on workspace deletion. Each ruling is one
  line + its "cost if wrong"; the Ruling 8 `achievement()`-variable caveat is
  flagged for the Phase II special-case-#12 audit; ADR-005 (the mid-execution
  debug-trace scope addition) noted.
- **Teardown:** `feat/magium-plugin-phase-i` deleted (local + origin — its tree
  was identical to `main` before this session's doc commits); the SDD workspace
  `.superpowers/sdd/2026-08-31-magium-plugin-milestone-0-phase-i/` removed. The
  5 stale research-era `origin/claude/phase-*` branches and the local
  `backup-local-main-pre-reset` were left (owner's call).

**Phase I outcome (the fuller write-up spec §11.2 called for):** the complete
Lua engine (parser · conditions · store · stats · locale · specials · 12-step
`scene.render`), the bespoke fullscreen **paginated** reader widget (OQ-013
resolved — not `TextViewer`), choices-as-final-page, debounced `currentState`
autosave + `v_ac_*` immediate flush + resume, and the optional debug
action-trace — all shipped and validated 102/102 against the `magium-dev`
oracle @ `51f5aa9`. Chapter 1 plays start to finish on the real Kindle
Paperwhite 12 with no e-ink ghosting and a ~2.2 s once-per-session parse behind
a progress bar. Not in Phase I by design (roadmap order unchanged): the in-game
menu (Phase II), the achievement unlock toast (Phase V), the `special:stats`
screen (Phase IV) — each computes/persists correctly, it just has no UI yet.

**Next:** Phase II design cycle — `superpowers:brainstorming` → a Phase II spec
under `docs/specs/` → `writing-plans` → SDD execution. Scope per the roadmap
([`09` Phase II](docs/research/09-roadmap-effort.md#phase-ii--full-story--navigation))
+ spec §12: all 54 files loading, back/history stack in `ui/reader.lua`, the
13 hardcoded special cases audited + ported against real scenes, the four
`special:` hooks as navigation stubs, the new-game/continue menu, and the
spec §12.1 Phase I→II carry-forward (render-model→store write-back, etc.).

### 2026-09-01 (session 22) — Task 21: first on-device ch1 playthrough

Owner deployed the Phase I plugin to the real Kindle PW12 (new `tools/deploy-kindle.ps1` —
MTP overlay copy, no manual delete; `Shell.Application` `InvokeVerb('delete')` hangs headless,
`CopyHere` with `FOF_NOCONFIRMATION` does not) and played ch1. Full result matrix in the SDD
ledger's "Task 21" section; headline:

- **Passes:** C1 close affordance (header-tap **and** multiswipe both work — the review Critical
  is confirmed fixed on real hardware); prose + pagination; choices + stat-gated filtering;
  autosave/resume across reader-close, suspend, and full KOReader restart (device
  `koreader/magium/state` blob verified: carries `v_current_scene` + `v_ac_*`). **No e-ink
  ghosting/refresh problems.** Deferred-eager parse (~2.2 s on first open) "not very noticeable".
  No crashes/tracebacks in `crash.log`.
- **Working as specified but surprised the owner — all out of Phase I scope:** achievements
  unlock + persist but show **no toast/screen** (`ui/toast.lua` = Phase V; §11.1 says Phase I
  only *computes* the list); `special:stats` does nothing (stats screen = Phase IV); no in-game
  menu for save/load/achievements/restart/stats/log-toggle (menu = Phase II, screens III–VI;
  §11.1 "No title/menu screen in Phase I").
- **Spec inconsistency found (not fixed):** §6 line ~274 says "achievement toasts fire on the
  render right after the unlocking choice" — contradicts the Phase V deferral of `ui/toast.lua`
  in the §11 phase table. Wording bug in the spec; implementation followed the phase table.
- **Genuine Phase I nits (not fixed):** (1) the choices page's bottom indicator shows the bare
  literal `"choices"` (`ui/reader.lua:168`) instead of a page count — looks like a debug
  artifact. (2) Magium is 4 taps deep (≡ → More tools → Magium → Open Magium); it already
  registers a `Dispatcher` action (`MagiumOpen`) bindable to a gesture with no code change.
- **Next:** owner to decide fixes vs. defer for the nits above; spec §11.2 exit-criteria
  sign-off still pending (achievement/stats/menu gaps are expected, so they don't block it).
  Branch still local-only, not pushed.

### 2026-09-01 (sessions 19–21) — Phase I implementation finished (SDD): Tasks 7–23, final review, fix wave

Continued executing [the Milestone 0 + Phase I plan](docs/superpowers/plans/2026-08-31-magium-plugin-milestone-0-phase-i.md)
on `feat/magium-plugin-phase-i` under subagent-driven development. Per-task detail (BASEs,
review rounds, every ruling) is in the SDD ledger
`.superpowers/sdd/2026-08-31-magium-plugin-milestone-0-phase-i/progress.md`; this is the summary.

- **Engine + UI + save + wiring complete and oracle-clean.** Tasks 7–14 (conditions, store,
  stats, locale, specials, the 12-step `scene.render`, oracle-diff harness, full ch1 branch
  matrix), 16–20 (pagination, the bespoke fullscreen paginated reader widget, choices-as-final-
  page + choice→scene wiring, debounced autosave/resume, `main.lua` real plugin class), 22–23
  (the optional debug action-trace). Task 15 (lazy parse) stays deferred to Phase VIII; Task 21
  (owner on-device playthrough + §11.2 exit checklist) is the only Phase I task left.
- **Differential oracle: 102/102** ch1 render cases match `magium-dev` @ `51f5aa9`, zero DIFF.
  Full busted suite 89/0/0/0. Headless `kodev` load clean.
- **New mid-execution feature (owner-requested): debug action-trace** — `util/trace.lua`, OFF
  by default, a `≡ → More tools → Magium → Record debug log` toggle. Per-session
  `trace-<ts>.jsonl` (keep 5) under `koreader/magium/` + mirrored `[MGM]` lines to `crash.log`,
  for catching bugs during real play. Recorded as **[ADR-005](docs/decisions/ADR-005-debug-trace-toggle.md)**
  (runtime toggle chosen over build variants); spec **§9.2** added.
- **SDD final whole-branch review (opus)** re-ran every gate independently + swept all 2159
  scenes. Found **1 Critical**: on the owner's keyless Paperwhite 12 the reader could not be
  closed — `ui/reader.lua` only bound a Close key `if Device:hasKeys()`, which is false on
  `KindlePaperWhite6`, and the tap zones tiled the whole screen. Every emulator run had masked
  it (SDL forces `hasKeys=yes`). Plus 6 Important + ~15 Minor.
- **Fix wave 1 (opus implementer, one pass, 21 items)** + a scoped re-review (clean: 0
  Critical / 0 Important / 7 trivial Minor):
  - **C1** — reader now closes via a labelled tap target in the header bar **or** a multiswipe
    (both flush the autosave); page-turn zones shrunk below the header. Spec **§8.1** updated.
  - **I1** — `engine/stats.lua` left `success` nil for `<=`/`!=` operators (0 ch1 impact, 1
    Book-11 scene); `scene.render` now coerces it so the render model is total.
  - **I2** — the trace can no longer throw into gameplay (`pcall` + degrade-to-off).
  - **I4** — Phase I ships a **fixed DPI-scaled prose font, no in-reader size control**;
    re-pagination on font/rotation change is now an explicit Phase VIII item (spec §8.2, §12).
  - **I5** — the Phase I→II carry-forward list (render_model→store write-back; `B3-Ch01a`
    device-lock suppression; the `v_hearing<=4` check; achievement-text norm) moved out of the
    soon-deleted SDD ledger into spec **§12.1**.
  - Test coverage added for `pagination`'s `<br/>` block-split path and `save`'s
    checkpoint-preserve / timer-cancel invariants; ~12 small hardening/doc fixes.
- **Decisions:** ADR-005 (debug-trace runtime toggle). 14 controller rulings during execution
  where a plan step was defective or conflicted with the spec (spec is authority) — all listed
  in the SDD ledger, to be surfaced at branch-finish. No new OQs; no ADR superseded.
- **Branch state:** ~27 commits, **local only — not pushed** (a push to the shared branch is a
  stop-and-ask). Working tree clean.
- **Next:** finish the development branch (surface the rulings + the ADR-005 scope addition),
  then **Task 21 — owner runs the ch1 playthrough on the real Kindle** and signs off spec
  §11.2, which produces the fuller Phase I write-up. Then Phase II (full corpus + nav).

### 2026-08-31 (session 18) — Phase I execution started (subagent-driven): Tasks 1–6

Began executing [the Milestone 0 + Phase I plan](docs/superpowers/plans/2026-08-31-magium-plugin-milestone-0-phase-i.md)
on branch `feat/magium-plugin-phase-i`, fresh subagent per task + two-stage review
(SDD ledger: `.superpowers/sdd/2026-08-31-magium-plugin-milestone-0-phase-i/progress.md`).

- **Env rebuilt in WSL2 Ubuntu** (the prior emulator setup was gone): installed luajit
  2.1 / lua5.1 / luarocks / busted 2.3.0 / xvfb; rebuilt the `kodev` emulator
  (`~/koreader` @ v2026.07.1 == 9192014). `magium-dev` oracle @ `51f5aa9` verified.
  Added `tools/mgm.sh` — a WSL task runner (the Git-Bash→wsl.exe boundary mangles inline
  `$vars`/`$(...)`/`$?`; scripts run from a file don't). `emu-smoke` does a headless
  kodev launch + log grep so subagents can verify plugin loads.
- **Tasks 1–5 complete, reviewed clean.** Scaffolding + vendored `rxi/json.lua` (plan's
  pin 404'd → used current master `dbf4b2dd`); `engine/parser.lua` (`parse_conditions`,
  the 4 construct matchers, `parse()`) — **per-scene structural parity with `magium-dev`
  proven** over all 54 files (2159 scenes / 4880 paragraphs / 3734 choices / 594 set() /
  145 achievement() / 2480 #if, 0 anomalies); `engine/story.lua` eager strategy + the
  lazy-stub seam.
- **Plan defects found & corrected mid-flight:** `spec/run.lua` exit check (LuaJIT
  `os.execute` returns a number, `0` is truthy); Task 3's `_match_set` tests used
  `set(v_x, 1)` (space) where the corpus + `parser.js` use `set(v_x,1)`, and its R3
  multi-digit assertion was dead code — both fixed in the plan and the code.
- **Task 6 (Milestone 0) — DONE.** Harness built; deployed to the owner's Kindle over
  MTP; **on-device cold parse ≈ 2.2 s** (2282 / 2215 / 2186 ms, three restarts; emulator
  x86 411 ms, ~5.6× faster). Over the ~1 s gate — **owner chose `eager` with `preload()`
  deferred to the first reader-open** (Trapper progress bar; ~2.2 s once per KOReader
  session, then instant; page turns/choices never parse) over building the lazy
  index+disk-cache path. **Task 15 (lazy strategy) deferred out of Phase I**; the
  `story.lua` lazy stubs stay for a later phase. spec §7 + `docs/spikes/06-…/FINDING.md`
  (stable, high confidence) updated; plan Task 20 `PARSE_STRATEGY = "eager"`.
- **Progress (2026-08-31, session 18):** Tasks 1–13 done + reviewed clean; the engine
  (parser + conditions + store + stats + locale + specials + 12-step render) is
  oracle-validated 6/6 on the first integrated run. Task 6 (Milestone 0) done —
  device measured, `eager`-deferred-to-first-open chosen, **Task 15 deferred**.
  Three plan defects were caught and fixed against the `magium-dev` source during
  review (`_match_set` comma format, the `v_ac_` freeze semantics, the stat-check
  key→label swap).
- **Next:** Task 14 (ch1 branch-matrix oracle diff) → 16 (pagination, pure) → 17–18
  (the fullscreen reader widget + choices) → 19 (autosave/resume) → 20 (`main.lua`
  wiring, eager `preload` deferred to first open) → 21 (**owner:** on-device ch1
  playthrough + Phase I exit checklist). Task 15 (lazy) is now a Phase VIII item.

### 2026-08-31 (session 17) — implementation-design cycle opened: architecture + Phase I spec (task 8.6)

Owner approved starting the implementation-design cycle (the last open row of
[`09` §5](docs/research/09-roadmap-effort.md#5-handoff-checklist-85-design-doc-11-exit-criteria)).
Ran the brainstorming process — architectural path — to a written spec.

- **Clarifying decisions (owner):** (1) design now with a parse-strategy *seam*
  rather than blocking on Milestone 0; (2) spec depth = Phase I in build-ready
  detail, phases II–VIII as architecture notes; (3) internal architecture =
  three-layer, engine-pure (over a two-layer faithful port or deferring the
  custom widget); (4) reading screen = choices rendered as the final page (over a
  pinned footer or an on-demand bottom sheet). Owner deferred KOReader/Lua
  pattern specifics to me.
- **Wrote [`docs/specs/2026-08-31-plugin-architecture-and-phase-i.md`](docs/specs/2026-08-31-plugin-architecture-and-phase-i.md):**
  the permanent three-layer module map (`engine/` pure Lua + no KOReader deps,
  desktop-testable against the `magium-dev` oracle; `ui/` KOReader widgets;
  `save/` thin persistence; `main.lua` glue), the `.koplugin` folder layout, the
  data-shape contracts (`scene_table`, `render_model`, `page`), the 12-step
  `scene.render` pipeline port, the `story.lua` eager/lazy seam, the custom
  fullscreen paginated reader (`ui/reader.lua` + a pure `ui/pagination.lua` with
  an injected text-measurer), the 4-blob save model with debounced autosave, and
  **Milestone 0** (on-device parse-timing gate, decision rule ≤1 s → eager else
  lazy) + **Phase I** (complete engine, `ch1` playable, autosave/resume) with
  explicit exit criteria. Phases II–VIII each get a "what it adds / what it
  touches" note so Phase I code is written to accommodate them without rework.
- **[ADR-004](docs/decisions/ADR-004-plugin-internal-architecture.md)** records
  the three decisions that closed alternatives (layering, custom paginated
  widget resolving OQ-013, choices-as-final-page). Options B/C for layering and
  the other two choice-placement options are written up with why they lost.
- **No implementation code** — per CLAUDE.md, that waits for the spec to be
  approved and an implementation plan (writing-plans) to be written.
- Updated `SUMMARY.md` (status, Decisions list, Next steps),
  `docs/specs/README.md`, `docs/decisions/README.md`, this file (status line,
  task 8.6 → done, this entry).
- **Next:** owner reviews the spec. On approval → writing-plans skill to turn
  Milestone 0 + Phase I into an ordered, checkpointed implementation plan
  (build order: pure engine + oracle diff first, paginated widget second, glue
  last). Milestone 0 (2–4 h) is the first concrete implementation action and
  sets the `story` parse-strategy default.

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
