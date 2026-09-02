# 09 — Implementation roadmap, effort & timeline

- **Status:** stable — **implementation complete** (Phase VIII merged
  2026-09-08, the port is feature-complete; Phase VII localization stays
  **blocked** on upstream fr content — see its section)
- **Last updated:** 2026-09-08
- **Phase:** 8 (done)
- **Sources:** [`06-approach-comparison.md`](06-approach-comparison.md) (chosen
  approach, candidate A), [`04-constraints-budget.md`](04-constraints-budget.md)
  (device budget + parse-strategy fork), [`03-koreader-platform.md`](03-koreader-platform.md)
  (widget/persistence/lifecycle APIs), [`01-magium-analysis.md`](01-magium-analysis.md)
  (engine surface to port), [`07-risks-open-questions.md`](07-risks-open-questions.md)
  (open items carried into this roadmap), [`../spikes/`](../spikes/) (validated
  pieces + a working dev loop), [design doc §11](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#11-handoff--exit-criteria)
- **Related:** [ADR-002](../decisions/ADR-002-porting-approach.md) (approach),
  [ADR-003](../decisions/ADR-003-defer-licensing-distribution.md) (licensing
  deferred), `../../SUMMARY.md`, `../../research-plan.md`

> Goal: a credible phased roadmap for candidate A (standalone KOReader plugin,
> Lua engine, runtime `.magium` parsing) with effort bands and a timeline, plus
> the handoff to the implementation-design phase. **Not a commitment — an
> estimate with stated assumptions**, calibrated to the owner's actual skill
> profile rather than a generic port.

---

## 0. Scope & assumptions *(8.2 calibration)*

- **Owner:** experienced generalist programmer (JS, Python, C; light hobby
  2D/puzzle game dev) — [`SUMMARY.md` finding 4](../../SUMMARY.md). **New to
  Lua:** a small language, C-family control flow, one data structure (tables)
  — days, not weeks, to get fluent. **New to the KOReader plugin/widget API
  and e-ink idioms:** this is the real ramp. Every effort band below carries a
  premium on KOReader-facing work (widget construction, persistence API,
  lifecycle, e-ink refresh tuning) and close-to-none on engine-logic work
  (parser/condition/state translation), per design doc §12's risk row and
  [`04` finding F-25](04-constraints-budget.md#findings).
- **Community help is assumed for KOReader specifics**, not for the engine
  port — `frotz.koplugin`'s author and KOReader GH Discussions
  ([`05` §5](05-prior-art.md#5-contacts-map-45)) are the best-targeted venues
  for the two most KOReader-idiom-heavy items: the custom pagination widget
  (Phase I) and e-ink refresh tuning (Phase VIII).
- **Reference `magium-dev` (JS) reads directly for the owner** — porting is
  translation + API-mapping against a running oracle
  ([`reference/magium-dev-notes.md`](../../reference/magium-dev-notes.md)),
  not reverse-engineering from scratch.
- **Approach:** candidate A, per [`06`](06-approach-comparison.md) /
  [ADR-002](../decisions/ADR-002-porting-approach.md) — standalone plugin,
  Lua engine, `.magium` bundled verbatim and parsed at runtime.
- **Spike code is a design reference, not a starting point.** Per CLAUDE.md,
  spike code is throwaway and is never promoted to production without a new
  approved phase. [Spike 02](../spikes/02-engine-in-lua/FINDING.md) (parser +
  condition evaluator for a 3-file slice, 6/6 oracle match, full-corpus
  structural parity) and [spike 04](../spikes/04-ui-plugin-skeleton/FINDING.md)
  (a working `TextViewer`-based skeleton, now known to need the wrong widget
  swapped out — OQ-013) prove the approach and the dev loop work, and lower
  *risk* on the effort bands below, but the production code is written fresh,
  hardened, and covers the full 54-file/13-special-case surface the spikes
  didn't attempt.
- **Time budget:** the owner hasn't stated a weekly-hours figure, so §4 below
  gives three named pace scenarios instead of asserting one — pick the row
  that matches, or supply a real number to replace this assumption.
- **Effort bands are hour ranges**, not story points, so they can be checked
  against reality as implementation proceeds — a band that's blown through by
  2× on the very first phase is a signal to recalibrate the rest, not a
  reason to stop.

## 1. Phased implementation roadmap *(8.1)*

> **UI-verification standard for every remaining phase (V–VIII), from
> session 29b (2026-09-03):** any `ui/` change is confirmed in the WSL emulator
> and lands an automated check — a `spec/ui/*_smoke.lua` against the real
> KOReader widget stack (`mgm.sh test-ui`) and/or a `spec/flow/*` navigation
> test — *before* the owner is asked to test on-device. The device pass
> confirms e-ink feel and real input only; it is never the first check that the
> code works. Codified in `CLAUDE.md` → "Doing implementation work"; the
> per-change procedure is the **`verify`** skill.

### Milestone 0 — Pre-flight: on-device parse-timing gate

**Resolves the [`04` §4](04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34)
/ [OQ-001](07-risks-open-questions.md) tail before any production code is
written**, per [`06`](06-approach-comparison.md#4-recommendation-64) and
[`SUMMARY.md`](../../SUMMARY.md)'s explicit ask that Phase 8 schedule this as
an early gate rather than a paper decision. Deploy [spike 02](../spikes/02-engine-in-lua/FINDING.md)'s
Lua parser (or a version extended to the full 54-file corpus, matching
[spike 03](../spikes/03-full-corpus-memory-parse/FINDING.md)'s scope) inside
an actual `koplugin` shell, run it on the owner's real Kindle Paperwhite (or
their working WSL2 `kodev` build as a first pass — same ARM-vs-x86 caveat
spike 03 already flagged), and record wall-clock cold-parse time.

- **Decides:** parse-all-at-launch (§4 option 1) vs. lazy-per-chapter +
  `Persist` disk cache (§4 option 2) — the single biggest fork in this
  roadmap, because option 2 changes Phase I's engine *and* widget data-fetch
  layer, not just the parser. Doing this before Phase I avoids building the
  wrong shape twice.
- **Deliverable:** a number (ms), a go/no-go against the ~1 s threshold
  [`04` §3 row 3](04-constraints-budget.md#3-budget-table-33) used, and which
  of §4's three options Phase I builds around.
- **Depends on:** nothing — can start immediately; only needs the dev loop
  ([OQ-012](07-risks-open-questions.md), already resolved) and spike 02's
  code as a reference.
- **Effort band: 2–4 hrs.** Mostly deployment + measurement; the parser
  logic already exists as a validated reference.

### Phase I — MVP: engine core + the real reading widget

Covers design doc §3's first two parity rows (scene rendering with `#if`
blocks; choices with conditions/assignments) for a single chapter, **and**
resolves [OQ-013](07-risks-open-questions.md) up front rather than shipping
`TextViewer` first and rebuilding — Phase 6 already established `TextViewer`
is the wrong final widget (padded dialog, continuous scroll,
[`SUMMARY.md` finding 28](../../SUMMARY.md)), so building on it now would be
solved work redone.

- **Deliverables:**
  - Lua port of the scene parser, flat `v_*` variable store, DNF condition
    evaluator (`apply_conditions`), `set(...) if`, `#if(){}` blocks —
    verified against [`reference/tools/oracle-diff.js`](../../reference/tools/oracle-diff.js)'s
    existing fixture set (reuse the harness directly; it was built for
    exactly this).
  - A **custom fullscreen, paginated widget** built on `TextBoxWidget`'s
    line/height measurement API ([`03` §3](03-koreader-platform.md#3-ui-toolkit-inventory-23)),
    with a page indicator and page-turn refresh — the shape OQ-013 asked for
    (fullscreen "like the web version," no continuous scroll/ghosting).
  - Choice list wired to the widget (`ButtonTable`/`Menu`,
    [`03` §3](03-koreader-platform.md#3-ui-toolkit-inventory-23)), one
    chapter playable start to finish.
- **Depends on:** Milestone 0 (its answer shapes how this phase's engine
  loads data — parse-all vs. lazy).
- **Effort band: 35–55 hrs**, split roughly: engine core 15–25 hrs (mechanical,
  oracle-checked — the part Lua-newness barely touches); pagination widget
  15–30 hrs (genuinely new build, the single most KOReader-idiom-heavy item
  in the whole roadmap — this is where the KOReader-ramp premium and any
  community help land first).

### Phase II — Full story & navigation

Extends Phase I's proof-of-concept to design doc §3's full scope for
narrative + choices. **Implemented 2026-09-01** —
[spec](../specs/2026-09-01-phase-ii-full-corpus-and-navigation.md), sweep
8887/8887; **back/history stack was cut** ([ADR-006](../decisions/ADR-006-no-scene-back-navigation.md)
— `magium-dev` has no back navigation, so parity means none here).

- **Deliverables:** all 54 English `.magium` files loaded per Milestone 0's
  chosen strategy; ~~back/history stack~~ (cut, ADR-006); all **13 hardcoded
  per-scene special cases** audited and ported one by one
  ([`01` §10](01-magium-analysis.md#10-hardcoded-scene-id--variable-special-cases-task-110));
  the four `special:` hooks (`restart`/`saves`/`stats`/`checkpoint_load`/`checkpoint_save`,
  [`01` §7](01-magium-analysis.md#7-special-hooks-task-17)) wired as
  navigation stubs (their actual screens land in Phases III/IV).
- **Depends on:** Phase I (reuses its engine + widget, doesn't rebuild them).
- **Effort band: 15–25 hrs.** Mostly mechanical once the harness validates
  each file — the long tail is auditing the 13 special cases against real
  behavior, not writing new architecture.
- **Harness ready (session 24):** `magium.koplugin/spec/gen_cases.lua` derives
  an oracle case matrix for any/all chapters from the parsed conditions;
  `mgm.sh oracle-corpus` runs the whole generate→capture→render→diff sweep.
  First full run: **8886 / 8887** derived cases match `magium-dev` @ `51f5aa9`.
  Use it as this phase's parity gate.
- **Known corpus diff to resolve here (special-case audit):** at
  `B3-Ch01a-Crossbow` with `v_b3_ch1_unlock == 2`, `magium-dev` renders an
  *empty* stat-check label for the "stat device locked" sentinel;
  `engine/locale.lua:stat_check_text` returns `mainStatDeviceLockedText`
  instead. Decide faithful-empty vs. deliberate-readable during the
  special-case #12 pass (the `achievement()`/sentinel family flagged in
  [`phase-i-execution-notes.md`](../specs/phase-i-execution-notes.md)).

### Phase III — Saves

> **Implemented 2026-09-02** — [`docs/specs/2026-09-02-phase-iii-saves.md`](../specs/2026-09-02-phase-iii-saves.md).
> `checkpoint` blob landed early (Phase II). Actual design deviates from the
> deliverables below: one `Persist` blob per slot, **no `{NN→{date,name}}`
> index**; **import/export and rename cut**, delete added
> ([ADR-007](../decisions/ADR-007-saves-scope.md)). Slot name = chapter header.

Design doc §3 "Multi-slot saves with name + date."

- **Deliverables:** the four save blobs (`currentState` autosave,
  `checkpoint`, `save0`–`save49`, `achievements`,
  [`01` §8](01-magium-analysis.md#8-saves--settings-task-18)) on
  `LuaSettings` (text kv) + `Persist` (codec blobs,
  [`03` §4](03-koreader-platform.md#4-persistence-24)); **debounced**
  autosave — write on a timer / `onFlushSettings` / suspend / explicit
  checkpoint, never per-choice ([`04` finding F-20](04-constraints-budget.md#findings));
  slot name + date UI.
- **Depends on:** Phase II (needs the full variable surface + navigation to
  round-trip meaningfully).
- **Effort band: 10–15 hrs.** New API surface (`LuaSettings`/`Persist`) but
  well-scoped — [`03` §4](03-koreader-platform.md#4-persistence-24) already
  maps each blob to a concrete API call.

### Phase IV — Stats & stat-checks

> **Merged to `main` 2026-09-03** — [`docs/specs/2026-09-03-phase-iv-stats.md`](../specs/2026-09-03-phase-iv-stats.md)
> → stable. The stat-check *display* (`stat_checks_to_display` etc.) shipped in
> Phase I/II; this phase added `ui/statspage.lua` (the `KeyValuePage` allocation
> screen with faithful Confirm/Cancel + a `?`-button tutorial), the three
> stats-screen gates in `specials.lua` (#5/#9/#10), the "Full immersion" unlock
> (#11), and `main.lua` wiring (`special:stats`, in-game menu row). Owner device
> sign-off after a first-pass fix (auto-popup tutorial → `?` button). No
> `engine/scene` change → `oracle-corpus` unchanged at 8887/8887. busted 116/0.

Design doc §3 "Stat variables + stat-check display."

- **Deliverables:** 14 stat vars, `varToStat`, `parseStatCheck`'s 4 branches
  (covers 100% of the corpus per [`01` §5](01-magium-analysis.md#5-stats-system-task-15)),
  `statChecksToDisplay` (fed by set ∪ paragraphs ∪ choices), lock filter,
  de-dup, `KeyValuePage` stats screen.
- **Depends on:** Phase II (variable engine). Not blocked by Phase III — can
  run in parallel with it if a contributor is available (see §3).
- **Effort band: 8–12 hrs.**

### Phase V — Achievements

> **Merged to `main` 2026-09-04** — [`docs/specs/2026-09-04-phase-v-achievements.md`](../specs/2026-09-04-phase-v-achievements.md)
> → stable. `ui/toast.lua` unlock toast, `ui/achievementsmenu.lua`
> book→chapter→entry browser, `engine/scene.lua persist_effects` "1"→"2"
> seen-latch, `engine/locale.lua` achievements JSON (exact on-disk chapter
> order). Four device-pass rounds refined the entry-list layout (a paint-time
> crash from `mandatory` misuse; dummy-`Screen`-masked wrap/checkbox issues;
> title/caption as two real rows; bold titles + no stray separator) — the
> UI-smoke methodology gap this exposed is what Phase V.5 (below) exists to
> close. Owner sign-off across the full exit checklist. No
> `engine/scene:render` change → `oracle-corpus` unchanged at 8887/8887.
> busted 122/0.

Design doc §3 "Achievements (per book/chapter)."

- **Deliverables:** `achievement()` gating on flag `=== "1"`,
  `Notification` toast with the JSON `title`, the 136-entry
  `achievements{1,2,3}.json` data, the `b2ch41`-style group quirk, the
  always-on `v_ac_b3_ch9_prize` special case
  ([`01` §6](01-magium-analysis.md#6-achievements-task-16)).
- **Depends on:** Phase II. Parallelizable with Phase IV — both extend the
  same variable engine independently and don't share UI surface.
- **Effort band: 6–10 hrs.**

### Phase V.5 — Test hardening

> **Complete** —
> [`docs/specs/2026-09-04-phase-v5-test-hardening.md`](../specs/2026-09-04-phase-v5-test-hardening.md).
> Owner-requested, scoped 2026-09-04 after two device-only bugs (Phase IV's
> lingering tutorial popup, Phase V's `mandatory`-field paint crash) each
> slipped past a test suite that only checked pieces in isolation.
> **Items 1, 2, 4, 7** merged 2026-09-05 (`88d119c`): app-level E2E harness,
> achievements content-integrity check, save-schema fixture, real-1272×1696
> smoke bootstrap. **Items 3, 5, 6** merged 2026-09-06: varied stat-profile
> graph walk, choice-label + slot-name stress paint, parse-time tripwire
> budget. All test-only. Phase VI unblocked.

Not in the original design doc — added after Phase V's device pass exposed
that no test drives the real top-level `Magium` object, and no test checks
the achievements *data* for orphaned/unreachable content.

- **Deliverables** (priority order — see the spec doc for full detail on each):
  1. **App-level / E2E harness** — construct the real `Magium` object
     (`main.lua`) headlessly (stub `self.ui.menu`, reuse
     `spec/support/fake_writer.lua` / `fake_slotstore.lua`) and drive it
     through `openReader()` → the real `openMenu()` `ButtonDialog` →
     `openSaves()`/`openStats()`/`openAchievements()` → `newGame()` →
     `onSuspend()`/`onClose()`, asserting screens actually open/close and
     state survives. The one thing standing between "each piece works" and
     "the game works."
  2. **Content integrity: orphaned achievements** — cross-reference every
     `variable` in `achievements{1,2,3}.json` (136 entries) against parsed
     `achievement()` calls (`engine/parser.lua`) + `specials.lua`'s hardcoded
     exceptions (`v_ac_b3_ch9_prize`, `v_ac_ch6_immersion`); fail on any
     variable nobody can ever earn. Same shape as `navigation_spec.lua`.
  3. **Systematic graph exploration** — replace/extend `playthrough_spec.lua`'s
     single greedy walk with a BFS/DFS that tries multiple stat-variable
     profiles at branch points, to exercise reachability under stat-gate
     combinations the one heuristic path never visits. Lower value than 1–2
     since `oracle-corpus` already exhaustively covers per-scene condition
     correctness via `gen_cases.lua` — this is about reachability, not render
     correctness.
  4. **Save schema/compatibility regression** — a golden fixture of the
     current save blob shape (`state`/`achievements`/`checkpoint`/slots) + a
     loader test, so a later engine change that silently breaks an existing
     save is caught. Low urgency now (no saves exist outside the owner's own
     device yet) but cheap to establish before the format drifts further.
  5. **Content stress-testing beyond achievements** — extend the
     "paint every real instance, not a sample" principle that caught the
     Phase V crash to other free-form-text widgets: longest choice label
     through `ui/reader.lua`'s choice buttons, longest save-slot name.
  6. **Performance regression** — a cheap `assert(elapsed < N)` around
     `Story:preload()` in the test suite so a parse-time regression is
     caught automatically instead of rediscovered on-device (currently only
     tracked as a one-off spike finding, `docs/spikes/06-ondevice-parse-timing`).
  7. **Fix `spec/ui/*_smoke.lua`'s dummy-`Screen` resolution** — found
     2026-09-04 chasing a real layout bug the emulator's paint checks had
     already "passed" at a hardcoded 600×800 instead of the real PW12
     1272×1696 (`commonrequire`'s `einkfb.dummy=true` ignores
     `EMULATE_READER_W/H` entirely). A reusable non-dummy bootstrap +
     `mgm.sh` command, so every paint check proves layout, not just
     crash-avoidance. Groups with item 5.
- **Shipped 2026-09-05:** items **1** (`spec/ui/main_e2e_smoke.lua` +
  `spec/support/koenv_boot.lua`, real `Magium` object + real `Persist` against an
  isolated `KO_HOME`), **2** (`spec/engine/navigation_spec.lua` new
  `describe` block), **4** (`spec/save/schema_compat_spec.lua` +
  `spec/save/fixtures/save_v1.lua`), **7** (`spec/support/real_screen.lua` +
  `mgm.sh real-screen` / `test-ui-real`; all 5 existing `*_smoke.lua` switched
  to the `MAGIUM_REAL_SCREEN` bootstrap).
- **Shipped 2026-09-06:** items **3** (`spec/flow/playthrough_spec.lua` — greedy
  walker extracted, run under 4 contrasting stat profiles, union vs the maxed
  walk asserted), **5** (`spec/ui/reader_smoke.lua` paints the 15 widest corpus
  `choice()` labels; `spec/ui/savespage_smoke.lua` audits + paints the widest
  `locale:header()` slot name), **6** (`spec/engine/story_eager_spec.lua` — full
  parse under a 3s tripwire; dev actual ≈ 0.24s).
- **Depends on:** Phase V (uses its screens/data as fixtures; the app-level
  harness naturally exercises the achievements menu too).
- **Effort band: 13–21 hrs** (≈4–6 / 1–2 / 3–5 / 2–3 / 1–2 / 1 / 1–2 hrs per
  item above).
- **Standing rule this phase establishes:** once its suites exist, **every
  subsequent phase and change must run them and update them as needed** —
  same status as `busted`/`oracle-corpus`/`spec/ui/*_smoke.lua` today. See
  CLAUDE.md "Doing implementation work."

### Phase VI — Settings / themes

> **Merged to `main` 2026-09-07** —
> [`../specs/2026-09-07-phase-vi-settings.md`](../specs/2026-09-07-phase-vi-settings.md)
> → stable (owner device sign-off, two passes). Scoping pass result: of
> magium-dev's 4 settings only **cheat mode** and a **reader-local text-size
> preset** (`magium_prose_size`, 3 presets) are ported — theme is KOReader's
> job, language is Phase VII. Also hardened the custom reader for non-PW12
> screen sizes: choices page scrolls on overflow (`ScrollableContainer`),
> `prose_height` floored, new `mgm.sh test-ui-matrix` (4 device profiles). The
> device pass also caught + fixed a pre-existing bug (Phase IV): `openReader()`
> reloaded the store from disk on every `_reopenReader()`, so a `special:stats`
> choice reverted to the last autosave on return. No `engine/` change →
> `oracle-corpus` unchanged at 8887/8887; busted 132/0. No ADR (the
> theme/language non-port is already recorded here).

Design doc §3 "Settings / theming (Original, Catppuccin)."

- **Deliverables:** first, a scoping pass — [`01` §8](01-magium-analysis.md#8-saves--settings-task-18)
  already notes theme/font/locale are KOReader's own job, not the ported
  app's, so most of `magium-dev`'s `settings.ejs` (font size, color theme)
  is likely redundant with KOReader's native reader settings and doesn't
  need porting at all. Port only whatever's genuinely game-specific (if
  anything, once audited).
- **Depends on:** Phase II.
- **Effort band: 4–8 hrs** — deliberately narrow; the scoping pass itself
  may cut most of the naive estimate for this phase.

### Phase VII — Localization (en + fr)

> **BLOCKED on upstream translation completeness (2026-09-08).** Implemented and
> device-tested this session, then **rolled back** — nothing merged; the work is
> preserved as the annotated tag `phase-vii-shelved`
> ([running log session 35](../../research-plan.md)). `../magium-dev/data/fr/` @
> `51f5aa9` turned out to be a near-abandoned stub: `ui.json` is fully French but
> the **story prose is 1 of 54 `.magium` files** (`ch1` only; 29/54 byte-identical
> to `data/en/`). The switch/re-parse/re-render mechanism works (verified on the
> owner's device), but there is almost no French content to render. This
> invalidates the "i18n = string-bundle swap" assumption for *content*
> (structure is still identical) — see the caveats added to
> [`01` §9](01-magium-analysis.md#9-localization-task-19),
> [`02` §5](02-magium-format-spec.md#5-en-vs-fr-divergence), F-08. **Revisit only
> when a substantially complete fr `.magium` set exists** (upstream, or another
> source). The tagged implementation is directly reusable.

Design doc §3 "Localization (en, fr)."

- **Deliverables:** bundle the French `.magium` set + `ui.json` alongside
  English (structurally identical file-for-file,
  [`01` §9](01-magium-analysis.md#9-localization-task-19)); KOReader
  gettext (`_()`/`T()`) `.po` for the plugin's own UI chrome — independent
  of Magium's own prose-bundle swap
  ([`03` §9](03-koreader-platform.md#9-localisation-29)); a locale switch.
- **Depends on:** Phase II only — **does not** depend on III–VI, since it's
  a data-bundle swap plus UI-chrome strings, not new engine logic. Good
  candidate to hand to a French-fluent contributor in parallel with III–VI
  (see §3). *(Superseded by the block note above — the dependency was never
  the issue; the content is.)*
- **Effort band: 4–8 hrs.** *(The implementation cost ~this; the blocker is
  data, not effort.)*

### Phase VIII — Polish, on-device tuning & packaging

> **DONE — merged to `main` 2026-09-08** ([spec](../specs/2026-09-08-phase-viii-polish.md)
> → stable). **The port is feature-complete.** Measurement-driven, and reshaped
> once the owner stated a ≤5-min session limit:
> - **OQ-011** (the 2044-clause `b3ch4a:251` condition) — closed on a dev bench
>   (`spec/engine/condition_perf_spec.lua`): **2.6 ms/render x86 → ~15 ms on
>   device**. Mitigation #1 (parse-time DNF caching) was already the
>   architecture; no mitigation code, bench kept as a tripwire.
> - **OQ-007** (e-ink feel) — owner ran the choice→page loop on the real PW12,
>   judged it **acceptable** (minor ghosting, not worth tuning for personal
>   use). `ui/refresh.lua` ships unchanged. `crash.log` clean across the pass.
> - **OQ-013** — already resolved (custom paginated `ui/reader.lua`, Phase I).
> - **GC tuning** — not needed; downgraded to a post-release watch.
> - **Full-corpus QA** — `oracle-corpus` (all 2159 scenes) at the baseline.
> - **Packaging** — `INSTALL.md` (personal install only, [ADR-003](../decisions/ADR-003-defer-licensing-distribution.md));
>   `v1.0` tag. No ADR (no alternative closed). busted 134/0.

Closes out the remaining 🟡s from [`04` §3](04-constraints-budget.md#3-budget-table-33)
and design doc §3's residual parity gap (nothing left unaddressed by
Phases I–VII).

- **Deliverables:**
  - **E-ink refresh strategy** ([OQ-007](07-risks-open-questions.md)):
    `"ui"` for scene swaps/scrolling, periodic `"full"` to de-ghost,
    `"flashui"` on modal open/close — the split `frotz.koplugin` already
    ships ([`03` §6](03-koreader-platform.md#6-e-ink-specifics-26)). Tuned
    by the owner on the real device — this is a perceptual judgment no
    desktop/emulator run can make.
  - **Condition-outlier mitigation** ([OQ-011](07-risks-open-questions.md)),
    only if profiling on-device shows the 490 KB/2044-clause
    `b3ch4a.magium:251` condition actually stalls: cheapest first — memoize
    the parsed DNF for that scene id, then special-case it as a direct stat
    comparison, then (last resort) a targeted build-time pre-compile of
    just that one construct ([`04` §3 row 4](04-constraints-budget.md#3-budget-table-33)).
  - **LuaJIT GC tuning** if pauses are visible under the resident heap
    ([`04` §3 row 7](04-constraints-budget.md#3-budget-table-33)): lazy
    per-chapter loading, `collectgarbage("setstepmul")`, or evicting
    not-recently-visited parsed chapters.
  - **Full-corpus QA**: run `oracle-diff.js` across all 2159 scenes, not
    just the fixture set, as a final parity check; a `crash.log`-driven bug
    bash on the real device.
  - **Minimal packaging** for the owner's own install (`koreader/plugins/`
    copy) — distribution-channel packaging (KOReader plugin index,
    KindleModShelf, GitHub releases) is **out of scope while Phase 7
    ([ADR-003](../decisions/ADR-003-defer-licensing-distribution.md)) stays
    deferred**; revisit this line item if that changes.
- **Depends on:** everything — needs the whole plugin in hand to tune
  against.
- **Effort band: 15–25 hrs.**

## 2. Effort summary table *(8.2)*

| Milestone | Deliverable | Depends on | Effort band |
|---|---|---|---|
| M0 | Parse-timing gate (resolves OQ-001 tail) | dev loop only | 2–4 hrs |
| I | Engine core + custom pagination widget (resolves OQ-013), 1 chapter | M0 | 35–55 hrs |
| II | Full 54-file corpus, nav/history, 13 special cases | I | 15–25 hrs |
| III | Saves (4 blobs, debounced autosave, slots) | II | 10–15 hrs |
| IV | Stats & stat-checks | II (∥ III) | 8–12 hrs |
| V | Achievements | II (∥ III, IV) | 6–10 hrs |
| V.5 | Test hardening — **done** (app-level E2E, achievements content-integrity, save-schema regression, real-resolution smoke bootstrap, varied-profile walk, content stress-paint, parse-time budget) | V | 13–21 hrs |
| VI | Settings/themes — **done** (scoped down: cheat mode + reader text-size preset only; + custom-reader viewport robustness + a reopen-bug fix) | II, V.5 | 4–8 hrs |
| VII | Localization en+fr — **blocked** (upstream fr `.magium` is a stub: 1/54 files translated; implemented + rolled back 2026-09-08, tag `phase-vii-shelved`) | II (∥ III–VI) | 4–8 hrs (spent; blocker is data) |
| VIII | Polish — **done** (OQ-011 closed on a dev bench ~15 ms/render device; OQ-007 e-ink judged acceptable on device, `refresh.lua` unchanged; OQ-013 already done in Phase I; GC → post-release watch; `oracle-corpus` full-corpus QA; `INSTALL.md` + `v1.0`) | all | 15–25 hrs (well under — most items closed by measurement, no code) |
| **Total** | | | **~113–183 hrs** |

The total is a rough band, not a promise — the two widest-uncertainty items
are Phase I's pagination widget (genuinely new, no direct KOReader prior art
does "fullscreen + paginated" per [`07` OQ-013](07-risks-open-questions.md))
and Phase VIII's on-device tuning (inherently unmeasurable until real
hardware time). Everything else is closer to mechanical translation against
an oracle, which is where this port's risk profile is actually good — see
[`06`](06-approach-comparison.md)'s "risk" criterion (candidate A scored 5/5).

## 3. Critical path & parallelism *(8.3)*

**Critical path:** M0 → I → II → (III, IV, V, VII in any order/overlap) → V.5
→ VI → VIII. Everything from III onward extends the full-corpus engine +
widget Phase II establishes, so I and II can't be skipped or reordered — but
once II lands, several branches stop depending on each other:

- **III (saves), IV (stats), V (achievements) are largely independent
  extensions of the same variable engine** — each touches its own UI screen
  and its own slice of `v_*` state, with no shared blocking dependency
  between them beyond II. A second contributor could pick up any one of
  these without waiting on the others.
- **V.5 (test hardening) is a deliberate stop, not a parallel branch** —
  it's scheduled right after V, before VI opens more UI surface, precisely
  because two device-only bugs (IV's tutorial popup, V's paint crash) each
  slipped past isolated per-piece tests. Once V.5's suites exist, every
  phase from VI onward is expected to run and extend them, not just the
  existing busted/oracle-corpus/UI-smoke gates.
- **VII (localization) is the best candidate to hand off or parallelize
  early** — it depends only on II (the full corpus + nav structure being in
  place), not on III–VI's logic at all, since it's a data-bundle swap plus
  UI-chrome `.po` strings. A French-fluent contributor could start this
  the moment Phase II lands. *(Update 2026-09-08: the code side was done in
  ~one session and is trivial. The actual blocker is that no substantially
  complete French `.magium` translation exists upstream — see the Phase VII
  block note. A "French-fluent contributor" would be doing translation work,
  not porting work.)*
- **VI (settings/themes) is also low-coupling** — independent of stats/saves/
  achievements internals, and likely to shrink once the KOReader-redundancy
  scoping pass (§1) runs.
- **VIII's two hardest items (pagination-widget polish in I, e-ink tuning in
  VIII) are exactly the two places to target community help**
  ([`05` §5 contacts map](05-prior-art.md#5-contacts-map-45)) — they're the
  most KOReader-idiom-heavy, least owner-familiar work, per the design doc
  §12 risk row.
- **What M0 actually unblocks:** its result decides whether Phase I's engine
  (and Phase II's data-loading layer) is built around parse-all-at-launch or
  the lazy-per-chapter/disk-cache fallback — the single largest structural
  fork in this roadmap. Running it before Phase I, not during polish, avoids
  building the wrong shape and having to retrofit it later.

## 4. Timeline sketch *(8.4)*

**Assumption, stated explicitly because the owner hasn't given a number:**
the table below scores three hobby-pace scenarios against the ~100–162 hr
total from §2. Replace the "Owner's actual pace" row once known.

| Pace | Hours/week | Calendar time (100–162 hrs) |
|---|---|---|
| Light hobby (evenings/weekends, sparse) | ~5 hrs/wk | ~20–32 weeks (≈5–8 months) |
| Moderate hobby (regular weekly sessions) | ~10 hrs/wk | ~10–16 weeks (≈2.5–4 months) |
| Focused sprint (e.g. a vacation stretch) | ~20 hrs/wk | ~5–8 weeks (≈1.5–2 months) |
| Owner's actual pace | _TBD_ | _recompute from §2's total once known_ |

None of these assume full-time work, and none assume the estimate is exact —
they exist so the roadmap is legible at whatever pace the owner actually
works, not to promise a date. A useful signal to recalibrate: compare actual
hours spent on Milestone 0 + Phase I against the 37–59 hr band above — if
that ratio holds, the rest of the estimate is probably in the right range; if
it's off by 2×, rescale the remaining phases the same way rather than
re-deriving them from scratch.

## 5. Handoff checklist *(8.5, design doc §11 exit criteria)*

| Exit criterion | Status |
|---|---|
| All nine `docs/research/*` docs `stable` (or explicitly deferred with a reason) | **Met.** `00`–`06` and `09` promoted to `stable` this session (residual real-device-only measurements — OQ-001's parse-time tail, OQ-007, OQ-011, OQ-013 — explicitly carried into this roadmap's M0/Phase I/Phase VIII rather than left as unstated research gaps); `07` stays `living` by design (a register, never "finished"); `08` stays a stub by design, per [ADR-003](../decisions/ADR-003-defer-licensing-distribution.md). |
| `SUMMARY.md` states a recommended end-form with a confidence tag and links | **Met** since Phase 6 — candidate A, confidence high (approach) / medium (parse-strategy detail, now gated at M0 above). |
| Every `OQ-NNN` closed or explicitly deferred with a reason | **Met.** Closed: OQ-003, OQ-006, OQ-010. Mostly resolved: OQ-001 (memory half), OQ-008, OQ-009, OQ-012. Deferred (scope, [ADR-003](../decisions/ADR-003-defer-licensing-distribution.md)): OQ-004, OQ-005. Remaining open (OQ-001's parse-time tail, OQ-007, OQ-011, OQ-013) are **not researchable further on paper** — each needs either real device time or actual code — and are now scheduled as concrete roadmap work (M0, Phase I, Phase VIII) rather than left open-ended. |
| `09-roadmap-effort.md` gives a phased roadmap with effort bands and milestones | **Met** — this document. |
| An ADR records the chosen approach | **Met** — [ADR-002](../decisions/ADR-002-porting-approach.md), Phase 6. |
| This roadmap reviewed by owner | **Open — needs the owner.** Nothing in Phases 0–8 required approval to research; starting to *build* does, per CLAUDE.md ("no implementation... until an implementation design is separately approved") — see §6. |
| New brainstorming cycle opened for implementation design *(8.6)* | **Prepared, not started** — see §6; opening it is the owner's call, matching how Phase 7's scope question and the outreach drafts in [`05` §6](05-prior-art.md#6-outreach-46) were both left for the owner rather than decided unilaterally. |

## 6. Starting the implementation-design cycle *(8.6)*

This roadmap is the last research-phase deliverable — with it, every exit
criterion in §5 is met except the two that require the owner directly. Per
CLAUDE.md, **no application code is added until an implementation design is
separately approved**; that line applies equally to formally kicking off the
design phase itself. So this section is a prepared on-ramp, not an autostart:

- **What "starting the cycle" looks like, when approved:** a new design/spec
  doc under `docs/specs/` (currently empty per the repo layout in the
  [governing design doc §7](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#7-repo-structure)),
  following the same conventions this dossier used (§8 of that doc) — a
  concrete plugin architecture (module boundaries for the parser/engine/
  widget/persistence layers), file/folder layout for the `.koplugin`, and a
  build-order sequencing that follows this roadmap's Phase I → VIII shape.
- **What it should start with:** Milestone 0 (§1) — it's cheap (2–4 hrs),
  resolves the one structural fork the rest of the design depends on, and
  needs no design doc to begin, only the dev loop this project already has
  working.
- **Trigger:** the owner reviewing this roadmap (§5's last open row) and
  saying to proceed. That mirrors exactly how Phase 7's scope question was
  handled this session — reported, not assumed.

## Findings

- **F-35 (confidence: medium):** the full roadmap (M0 through Phase VIII)
  bands to **~100–162 hours**, with the two widest-uncertainty items being
  Phase I's custom pagination widget (no direct KOReader prior art for
  "fullscreen + paginated," [`07` OQ-013](07-risks-open-questions.md)) and
  Phase VIII's on-device tuning (inherently unmeasurable before real hardware
  time). Everything else — the engine core, saves, stats, achievements,
  i18n — is closer to mechanical oracle-checked translation, which is where
  Phase 6's "risk" scoring already rated candidate A highest
  ([`06` §2](06-approach-comparison.md#2-decision-matrix-62)).
- **F-36 (confidence: high):** three items previously open only because
  "more research won't answer them" (OQ-001's on-device parse-time tail,
  OQ-007's e-ink feel, OQ-011's condition-outlier cost) are now concrete,
  scoped roadmap work (Milestone 0 and Phase VIII) rather than indefinitely
  open research questions — the correct way to close out a research phase
  against reality-bound unknowns is to schedule them as implementation-time
  measurements, not to manufacture a paper answer for them.
- **F-37 (confidence: high):** Saves, stats, and achievements (Phases III–V)
  are mutually independent extensions of the same Phase II variable engine,
  and localization (Phase VII) depends only on Phase II — three real
  opportunities to parallelize or hand off to a contributor without
  restructuring the roadmap, unlike the strictly sequential M0→I→II spine.
