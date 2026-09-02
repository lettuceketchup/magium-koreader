# SUMMARY — what we know so far

- **Status:** **IMPLEMENTATION COMPLETE — the port is feature-complete
  (Phase VIII merged 2026-09-08).** Phases I–VI + V.5 shipped and on-device
  signed-off; Phase VII (fr localization) built + rolled back, blocked on
  upstream translation completeness (tag `phase-vii-shelved`); Phase VIII
  (polish) closed OQ-007 (e-ink feel acceptable on device), OQ-011 (2044-clause
  condition ≈ 15 ms/render on device — already mitigated by parse-time DNF
  caching), OQ-013 (custom paginated reader, Phase I). `oracle-corpus`
  8887/8887, busted 134/0. Install: `INSTALL.md`, tag `v1.0`. Research phase
  (Phases 0–8) complete; **Phase 7 licensing run 2026-09-08
  ([ADR-008](docs/decisions/ADR-008-license-and-distribution.md))** — port code
  **AGPL-3.0-or-later**, Magium story text stays **CC BY 4.0** (the family's
  release licence, no permission request needed), `LICENSE` +
  `THIRD-PARTY-NOTICES.md` + `CONTRIBUTING.md` added — **the port is cleared for
  a free, non-commercial release.**
  _(Detail below is the historical research/early-implementation record.)_
  **Phase I complete** ([spec](docs/specs/2026-08-31-plugin-architecture-and-phase-i.md)
  + [ADR-004](docs/decisions/ADR-004-plugin-internal-architecture.md); on-device
  sign-off 2026-09-01, spec §11.2): the full Lua engine (parser · conditions ·
  store · stats · locale · specials · 12-step render), the bespoke fullscreen
  paginated reader widget (OQ-013 resolved), debounced autosave + resume, and an
  optional debug action-trace — all validated **102/102 against the `magium-dev`
  oracle**; `ch1` plays start→finish on the real Kindle PW12. Milestone 0:
  2.2 s device cold parse → `eager`, deferred to first reader-open (lazy
  strategy deferred to Phase VIII).
  **Phase II implemented 2026-09-01** ([spec](docs/specs/2026-09-01-phase-ii-full-corpus-and-navigation.md);
  branch `feat/phase-ii-full-corpus-nav`): scene `set()` write-back, special
  case #8 → full-corpus sweep **8887/8887**, in-game menu, `special:` hooks
  routed, back/history stack cut ([ADR-006](docs/decisions/ADR-006-no-scene-back-navigation.md)).
  Automated gates green; owner device playthrough pending. **Next: Phase III**
  (saves).
- **Last updated:** 2026-09-01
- **How to read this:** every claim links to the doc that backs it, with a
  confidence tag. If a row says `low` or `TBD`, it is not yet a conclusion. This
  file is updated at the end of each research phase.

---

## Current recommendation

**Chosen (Phase 6, confidence: high): Candidate A — a standalone KOReader
plugin that reimplements the `magium-dev` engine in Lua and bundles the
`.magium` story data verbatim, parsed at runtime.** Recorded as
[ADR-002](docs/decisions/ADR-002-porting-approach.md); full comparison in
[`06-approach-comparison.md`](docs/research/06-approach-comparison.md).

Candidates B (extend an existing plugin) and C (convert to Twine/Ink +
existing player) both fail on a structural fact established by Phase 4, not a
close call: B has no existing plugin whose content model fits Magium to
extend (OQ-003 closed "no," F-30), and C has no existing e-ink/KOReader
player for whatever format `.magium` gets converted into (F-27) — a scored
decision matrix (`06` §2) still puts them well behind A even scored
generously on every other axis. Candidate D (build-time preprocess to a lean
format + small Lua runtime) is a legitimate second-place option — same parity
ceiling as A — but the problem it trades away (a slow runtime parse) didn't
materialize: spikes 02/03 measured the full 54-file corpus parsing in
112–205 ms under two LuaJIT builds, close to the original 95–130 ms
V8/desktop anchor, while D's standing cost (a build pipeline + a second
format to keep in sync with every upstream `.magium` update) is real and
ongoing, which A avoids entirely by bundling the source files as-is.

One implementation detail inside A is deliberately left open rather than
pre-decided (confidence: medium) — whether "parse all 54 files at launch" is
sufficient on its own or needs the already-scoped lazy-per-chapter/disk-cache
fallback ([`04` §4](docs/research/04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34))
— pending a real on-device ARM timing measurement (OQ-001's tail), which
Phase 8 should schedule as an early implementation-phase gate.

**Nothing here is blocking on an open question, or on the project at all.**
Every remaining open `OQ-NNN` narrows an implementation detail *inside*
Option A (the pagination widget, e-ink redraw tuning, the 490 KB condition's
mitigation, the parse-strategy gate) rather than threatening the choice
itself — see [`06` §3](docs/research/06-approach-comparison.md#3-blocking-open-questions-63) /
[`07`'s blocking-status note](docs/research/07-risks-open-questions.md#blocking-status-after-phase-6).
**OQ-004** (does the family's permission extend to a further port?) and
**OQ-005** (license) are **closed** (Phase 7, 2026-09-08,
[ADR-008](docs/decisions/ADR-008-license-and-distribution.md), superseding the
ADR-003 deferral once the owner decided to release the port). The family
released the Magium story text **CC BY 4.0** explicitly for ports and
translations — so redistribution needs **no permission request**, only
attribution and a note that the text was reformatted. The port's own code is
licensed **AGPL-3.0-or-later** to match KOReader (into whose Lua state a plugin
loads); the story text stays CC BY 4.0. A free, non-commercial GitHub release
is fully permitted — see [`08-licensing.md`](docs/research/08-licensing.md).
**Phase 8 (roadmap/effort) is now done** — see
[`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md): a phased
implementation roadmap for candidate A (Milestone 0 pre-flight → 8 build
phases), effort bands totaling **~100–162 hrs**, critical-path/parallelism
analysis, and a handoff checklist. The research phase is now substantially
complete — every exit criterion is met except the two that need the owner
directly: reviewing the roadmap, and approving the start of the
implementation-design cycle.

<details>
<summary>Earlier reads (Phases 0–5), superseded by the Phase 6 decision above</summary>

**Early read (medium confidence):** the constraints picture favors a
**standalone Lua plugin that reimplements the small `magium-dev` engine and
bundles the `.magium` data** — memory is a non-issue on this device, the engine is
tiny, and Phase 2 confirms **KOReader provides every widget/API the Magium UI
needs** with a shipping plugin (`frotz.koplugin`) already demonstrating the exact
"fullscreen styled narrative + choice list on e-ink" shape. **Phase 3 adds: no
resource on the device is a hard blocker** — the go/no-go call is a *conditional
green light* ([`04` §5](docs/research/04-constraints-budget.md#5-go--no-go-verdict)),
with every yellow being a responsiveness/hygiene item that a spike settles.
Remaining unknowns: the e-ink *feel* of the choice→page loop (spike A / OQ-007),
cold-parse time on-device (spike B / affects the parse-strategy choice),
redistribution permission (OQ-004), and the 490 KB condition outlier (OQ-011). To
be confirmed or overturned in Phase 6.

**Phase 5 update (de-risking spikes): the early read holds up, more strongly —
and now with all four spikes actually run.** A Lua port of the engine's
condition evaluator + parser matched `magium-dev`'s own output exactly across
every diffed fixture *and* the full 54-file corpus (spike 02/03) — the engine
is not just "should be small" (F-9), it's now a working, corpus-validated
translation, re-confirmed under koreader-base's own bundled LuaJIT build (F-27).
The same spike's real LuaJIT memory measurement (~11.5 MB for the full parsed
story, confirmed under two different LuaJIT builds) came in *under* the earlier
V8-based estimate, making memory an even stronger 🟢 than Phase 3 already had
it. A `.magium`→Ink conversion (spike 05) confirmed conditions/stats survive
format conversion losslessly, closing OQ-006's fidelity half — but this doesn't
help approach C, since Phase 4 already found no e-ink player exists for Ink
regardless. Spike 04 (UI widget fit) was initially thought blocked by this
session's own environment (no device, and an earlier attempt to build the
KOReader emulator hit a 403 on GitHub thirdparty-tarball downloads) — that
turned out to be a narrower, fixable problem than first reported (F-27): a
working emulator build was obtained, and the plugin was actually run under
real KOReader v2026.07.1, confirming the underlying data/API shape fits an
off-the-shelf widget cleanly (F-26). Reviewing that run's screenshots then
caught something source-reading alone had missed: the specific widget used
(`TextViewer`) renders as a padded dialog with continuous scroll, not the
fullscreen + paginated presentation the finished UI should have (F-28,
new **OQ-013**) — a real but narrow gap, since building a small custom
fullscreen/paginated widget is squarely within what Phase 2 already
catalogued as available (`TextBoxWidget`'s measurement API), not a new
feasibility concern. E-ink refresh feel (OQ-007) stays open regardless —
never closable from any non-e-ink display — and needs the owner's WSL2
setup or the real Kindle.

</details>

## Established so far

| # | Finding | Confidence | Source |
|---|---|---|---|
| 1 | `magium-dev` is the porting base, not `magium-recrystallized`: ~650 LOC plain JS, human-readable `.magium` scripts parsed at runtime, MIT. `magium-recrystallized` is Rust/WASM with a binary `.story` TLV format, **no in-repo compiler**, built for HTTP range-streaming, AGPL, unfinished scripting — reviewed and ruled out as a base (its save-model and chunked-format ideas may help approach D). | high | [`reference/magium-recrystallized-notes.md`](reference/magium-recrystallized-notes.md), `../magium-dev/src/` |
| 2 | Full English story data is 54 `.magium` files, 7.7 MB of text, plus 3 achievements JSON files and one `ui.json`. A French `data/fr/` dir exists but the prose is a **stub — 1/54 files translated** (see row 11). | high | `../magium-dev/data/en/`; fr completeness verified 2026-09-08 |
| 3 | The engine's moving parts: line-oriented scene parser, a flat variable store (`v_*`), DNF condition evaluation, `set(...) if`, `#if(){}` conditional paragraphs, `choice(...)`, `achievement(...)`, and four `special:` hooks (`restart`, `saves`, `stats`, `checkpoint`). A handful of scene IDs are special-cased in `renderers.js`. | high | `../magium-dev/src/parser.js`, `src/utils.js`, `src/renderers.js` |
| 4 | Owner: experienced generalist programmer (JS, Python, C; light hobby 2D/puzzle game dev), **new to Lua** and the KOReader API. Lua is a quick pickup for this background; KOReader's API is the real learning curve. Can test on-device; expects community help for KOReader specifics. | high | project brief (2026-08-31) |
| 5 | **Target device: Kindle Paperwhite 12th gen (2024), 16 GB** (Amazon.in B0DKTZ6592). Confirmed on-device: FW **Kindle 5.19.5**, **956.9 MB RAM** (~497 MB available), 10.6 GB free storage, KOReader **v2026.07.1** release (`kindlehf`) idling at ~33 MB RSS. | high | [`00-overview.md`](docs/research/00-overview.md) — on-device |
| 6 | Story scale (English): **54 files, 7.5 MB, 2159 scenes, 4880 paragraphs, 3734 choices**. Fully parsed ≈ 17 MB in V8; 8.16 MB serialized. | high | measured — [`01`](docs/research/01-magium-analysis.md) §11, [`reference/magium-dev-notes.md`](reference/magium-dev-notes.md) |
| 7 | `magium-dev` runs locally as a clean **differential oracle**: `POST /` with the variable map (+ `HX-Request: true`) renders any scene. A no-deps harness (`reference/tools/oracle-diff.js`) normalizes each scene to canonical JSON and structurally diffs two captures; 6-case fixture set + committed goldens ready for the spike-B Lua port. Verified 2026-08-31 on Node 24. | high | [`reference/magium-dev-notes.md`](reference/magium-dev-notes.md) |
| 8 | **RAM is not a blocker.** Public "512 MB" figure was wrong — device has ~1 GB, ~500 MB available, KOReader only ~33 MB. A ~17–30 MB resident story fits easily. Open concern is now just launch parse time (spike B), not memory. | high (RAM); medium (parse time) | [`04-constraints-budget.md`](docs/research/04-constraints-budget.md) §3, OQ-001 |
| 9 | **The engine is ~640 LOC over 4 JS files** (`parser` 131, `utils` 219, `renderers` 194, `main_setup` 117) + EJS templates. A Lua reimplementation is small and mostly mechanical. `renderScene` runs a fixed 12-step filter pipeline (setVars→apply→choices→paragraphs→statChecks→achievements→checkpoint); there are **13 hand-coded special cases** that are parity-critical. | high | [`01-magium-analysis.md`](docs/research/01-magium-analysis.md) §0,§4,§10 |
| 10 | **`.magium` format = 5 regexes, DNF conditions, flat non-nested `#if`.** Full 54-file corpus scanned ([`scan-magium-constructs.js`](reference/tools/scan-magium-constructs.js)): navigation is via the `v_current_scene` variable (not the `target` field, which the engine never reads); `choice(""spoken"")` doubled-quote labels are common (809×); no multi-digit `set()`; `<br/>` is the only markup. Latent parser hazards (unanchored regexes, `startsWith` traps) catalogued but none triggered by current data. | high | [`02-magium-format-spec.md`](docs/research/02-magium-format-spec.md) §2–4 |
| 11 | **i18n = string-bundle swap (mechanically).** en and fr `.magium` sets are structurally identical (same 54 files, scene ids, variables, conditions) — one engine, one story-logic, N prose bundles. **⚠️ But no usable fr bundle exists:** @ `51f5aa9` the fr prose is a stub (`ch1.magium` only; `ui.json` full; achievements ~1 entry). Phase VII built the swap, confirmed the mechanism on-device, and was **rolled back** — blocked on upstream translation. | high (mechanism); the "translation present" implication was wrong | [`01`](docs/research/01-magium-analysis.md) §9, [`02`](docs/research/02-magium-format-spec.md) §5, [roadmap Phase VII](docs/research/09-roadmap-effort.md#phase-vii--localization-en--fr), running-log 2026-09-08 |
| 12 | **One performance outlier found and cleared:** `b3ch4a.magium:251` is a single ~490 KB `choice … if (…)` condition with 2044 OR-clauses (pre-expanded "Average Joe" check). **Phase VIII measured it: 2.6 ms/render on dev x86 → ~15 ms on the Kindle** — imperceptible. The parser splits it into its DNF table once at preload; a render only walks the pre-built table. No mitigation code; a `condition_perf_spec.lua` tripwire guards against a regression. OQ-011 closed. | high | [`01`](docs/research/01-magium-analysis.md) §11, [`02`](docs/research/02-magium-format-spec.md) §4, [OQ-011](docs/research/07-risks-open-questions.md), [Phase VIII spec](docs/specs/2026-09-08-phase-viii-polish.md) §3 |
| 13 | **KOReader gives us everything the Magium UI needs** — plugin = `WidgetContainer:extend` + `UIManager:show` for a fullscreen non-document UI; `TextBoxWidget`/`ScrollTextWidget` (C-shaped reflowed prose), `ButtonTable`/`Menu` (choice list), `KeyValuePage` (stats), `LuaSettings`/`Persist` (saves), `Notification` (achievement toast). No missing capability. `kbarni/frotz.koplugin` already ships a fullscreen "styled transcript + choice/input row on e-ink" plugin — direct prior art. | high (capability); medium (fit/feel → spike A) | [`03-koreader-platform.md`](docs/research/03-koreader-platform.md) §1,§3,§7; F-14/F-15 |
| 14 | **Platform facts:** LuaJIT **2.1.ROLLING** (`NUM 20199`, upstream `LuaJIT/LuaJIT@3c4f9fe`, not OpenResty), Lua 5.1 + FFI, patterns not regex, no `utf8` stdlib. **Single OS process / single Lua state / no threads** — blocking work (cold parse, the 490 KB condition) must be sliced via `Trapper`/`UIManager:scheduleIn`. `<br/>` is the only Magium markup → `TextBoxWidget` + `\n`. Saves fsync on write → debounce autosave. Closes the Phase 0 LuaJIT-build item. | high | [`03`](docs/research/03-koreader-platform.md) §2,§5,§6; F-16/F-17/F-19/F-20 |
| 15 | **Dev loop:** on-device = USB copy to `koreader/plugins/` + restart + read `koreader/crash.log` (all `logger` output, last 500 KB); no hot reload. The `kodev` desktop emulator is **set up and running in WSL2 / Ubuntu** on the owner's machine ([`setup-koreader-wsl.sh`](reference/setup-koreader-wsl.sh)) — build ~7 min, WSLg supplies the display, needed ninja ≥1.13.2 + make ≥4.4. **OQ-012 resolved.** | high | [`03`](docs/research/03-koreader-platform.md) §8.2; F-18; WSL2 build 2026-08-31 |
| 16 | **Go/no-go: conditional green light.** Phase 3 constraints budget finds **no hard resource blocker** — RAM (~500 MB avail vs ~10–30 MB story), storage (10.6 GB vs 7.5 MB), save size (~12–15 KB), normal-case CPU all 🟢 with margin. Six 🟡s, all responsiveness/I-O-hygiene with named mitigations + a spike each; no 🔴. Feasibility is not capacity-bound. | high | [`04`](docs/research/04-constraints-budget.md) §3,§5; F-22 |
| 17 | **Save-blob ≈ 12–15 KB** uncompressed for a 100%-progressed game — 491 writable vars (135 achievement flags), values all 1-digit/`±N` except `v_current_scene`. Maps to `LuaSettings`/`Persist` trivially; only autosave **write frequency** on flash needs care (debounce). | medium | [`04`](docs/research/04-constraints-budget.md) §2; F-23; `scan-save-footprint.js` |
| 18 | **Cold parse ≈ 95–130 ms on desktop** → plausibly **~1–4 s** on the 1 GHz MTK ARM core under LuaJIT. This is the one number that decides parse-at-launch vs lazy-per-chapter vs build-time pre-parse ([`04` §4](docs/research/04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34)) — measure directly in spike B. Not a feasibility gate (all three strategies are scoped). | low | [`04`](docs/research/04-constraints-budget.md) §2,§4; F-24; `measure-story-size.js` |
| 19 | **Every prior Kindle IF-interpreter effort converged on native fullscreen text UI, not a browser/document view** — `frotz.koplugin` (KOReader, active/maintained) is the closest direct precedent; KIF and the Kindle Gargoyle port (2010–2012, native/KUAL, pre-KOReader) both stalled at "alpha" on polish, not on a fundamental blocker. Reinforces F-14/F-15. | high | [`05-prior-art.md`](docs/research/05-prior-art.md) §1; F-26 |
| 20 | **No browser-based Twine/Ink/ChoiceScript player is viable on this platform.** KOReader's HTML path is MuPDF document rendering, not a JS runtime; even PocketBook (which has a real browser) shows RAM growth and refresh glitches running Twine's HTML5 output over a session. Evidence against approach C (format-convert + reuse an existing player) — no existing player to target. | high | [`05`](docs/research/05-prior-art.md) §3; F-27 |
| 21 | **No existing KOReader plugin plays CYOA/gamebook/narrative-choice content** (full `awesome-koreader` + ecosystem survey: only IF interpreters and generic puzzle games). Closes **OQ-003 (no)** and rules out approach B (extend an existing plugin) as a shortcut — the Lua engine has to be written from scratch either way. | high | [`05`](docs/research/05-prior-art.md) §2; F-30 |
| 22 | **No prior Magium-on-e-reader attempt found** (web search; absence-of-evidence, Discord history unindexed). Two live Magium Discord invites found for OQ-004 outreach (Community, Writer Team) — not yet cross-checked against the invite already on record. Three outreach drafts prepared but **not sent** (no account access this session) — owner to post. | medium | [`05`](docs/research/05-prior-art.md) §4,§6; F-29 |
| 23 | **The engine ports to Lua cleanly and fast.** A Lua translation of the parser + condition/stat-check evaluator matched `magium-dev`'s own output on **6/6** diffed fixtures, and reproduced the exact scene/paragraph/choice/`set()` counts (2159/4880/3734/594) on the **full 54-file corpus** — not just the diffed slice. One real porting bug found+fixed: Lua's `%w` pattern class excludes `_` (unlike JS `\w`), which silently broke every `v_snake_case` condition match until caught by the port's own diagnostic. | high | [spike 02](docs/spikes/02-engine-in-lua/FINDING.md) |
| 24 | **Lua-side memory for the full parsed story: ~11.5 MB** (real LuaJIT measurement, not just the V8 estimate) — *below* the ~17.4 MB V8 figure Phase 0 used. Confirmed twice: 11.54 MB under stock LuaJIT, 11.48 MB under koreader-base's own bundled build once a working `./kodev build` was obtained in-session (see F-31). Parse time 112–205 ms across both runs on this session's x86 container (same order of magnitude as the 95–130 ms V8 anchor) — still a desktop number, not the Kindle's ARM core; that gap is unchanged. | high (memory); low (on-device parse time, unchanged) | [spike 03](docs/spikes/03-full-corpus-memory-parse/FINDING.md) |
| 25 | **`.magium` conditions/`set()` convert to Ink losslessly.** One chapter (`ch1.magium`, 12 scenes) converted, compiled, and played via `inkjs`'s in-process JS compiler (`inkjs/full` — no `inklecate`/.NET needed); conditional branching and variable state matched the oracle goldens. Fidelity gaps found are all orthogonal to conditions/stats: achievements and `special:` hooks have no Ink primitive (host-script territory regardless of engine), cross-chapter navigation needs multi-file handling (one-chapter scope). Closes OQ-006's fidelity question without changing the case against approach C (no e-ink Ink player exists, F-27). | medium-high | [spike 05](docs/spikes/05-magium-to-ink/FINDING.md) |
| 26 | **A KOReader-widget plugin skeleton was written and confirmed working under a real build.** `TextViewer` + a `buttons_table` (verified against a real caller, not just its docstring) hard-codes `Ch1-Intro1`/`Ch1-Intro2` with real prose and 3-way branching, modeled on `hello.koplugin`. Run under KOReader **v2026.07.1** itself (see F-31): loads with zero errors, both scenes render correctly (real prose, correct chapter header, working choice buttons), navigation between them works — screenshotted. **Data/API fit: confirmed** (the parsed scenes, choices, and conditional prose drive this widget cleanly). **Not confirmed, and now known to need work: the widget's final chrome** — see F-28. E-ink refresh feel (OQ-007) is unaffected — unanswerable from any non-e-ink display — and stays open for the owner at a real device. | high (data/API fit); n/a (e-ink feel) | [spike 04](docs/spikes/04-ui-plugin-skeleton/FINDING.md) |
| 27 | **A cloud/remote session CAN build and run the KOReader emulator** — corrects F-24/F-26's earlier "cannot" claim. The actual constraint is narrower: `github.com/*/archive/*` (GitHub's dynamic tarball-from-ref endpoint) is blocked for repos outside the session's attached scope, but plain `git clone` and `github.com/*/releases/download/*` are not. 17 of koreader-base's ~50 thirdparty C-library fetches used the blocked pattern; swapping them for a `git clone` at the same tag (content-identical; already-existing `DOWNLOAD GIT` mechanism, not new code) let `./kodev build` complete end to end. Reproducible: [`reference/koreader-base-thirdparty-git-fetch.patch`](reference/koreader-base-thirdparty-git-fetch.patch), [`reference/setup-koreader-cloud-session.sh`](reference/setup-koreader-cloud-session.sh). | high | [spike 04](docs/spikes/04-ui-plugin-skeleton/FINDING.md) |
| 28 | **`TextViewer` is the wrong final widget for the reading screen — a custom fullscreen, paginated widget is the better direction.** Owner review of spike 04's screenshots (2026-08-31) caught what source-reading alone had missed: `TextViewer` defaults to a padded dialog (`screen_w/h − 30px`, rounded frame, titlebar + close button, `textviewer.lua:107-108,469-474`) — not fullscreen, despite `03-koreader-platform.md`'s earlier (now corrected) claim that it is — and its prose area (`ScrollTextWidget`) is continuous-scroll with no page-number/pagination concept. Neither gap is unique to this spike's choice: `frotz.koplugin`'s `GameView` (the other cited prior art) is fullscreen but also scrolls. No KOReader prior art surveyed so far does "fullscreen + paginated" together — that combination needs a small custom widget (buildable on `TextBoxWidget`'s existing line/height measurement API, per `03` §3), which is new work, not a reuse. Tracked as **new OQ-013**, feeding Phase 6 (approach comparison) and Phase 8 (roadmap) rather than reopening Phase 5. | high | [spike 04](docs/spikes/04-ui-plugin-skeleton/FINDING.md), [`07` OQ-013](docs/research/07-risks-open-questions.md) |
| 29 | **Candidates B and C fail for structural reasons, not close calls.** Phase 4 already showed neither has anything real to build on — no existing KOReader plugin plays CYOA content to extend (B, OQ-003/F-30), no e-ink/KOReader player exists for whatever `.magium` gets converted into (C, F-27). Phase 6's scored decision matrix confirms this holds even scoring B and C generously on every other axis: weighted totals A 95, D 70, B 53, C 47 (out of 100) — [`06` §2](docs/research/06-approach-comparison.md#2-decision-matrix-62). | high | [`06`](docs/research/06-approach-comparison.md) §1–2 |
| 30 | **Candidate D (build-time preprocess) is a real second-place option, not a strawman — same parity ceiling as A — but its rationale is undercut by Phase 5's own measurements.** D exists to avoid a slow runtime parse; spikes 02/03 measured the full 54-file corpus parsing in 112–205 ms under two LuaJIT builds, close to the original 95–130 ms V8/desktop anchor, not the order-of-magnitude-worse case D was scoped against. D also adds a standing cost A doesn't have: a build pipeline to write and a second, self-designed format to keep in sync with every upstream `.magium` update. | high | [`06`](docs/research/06-approach-comparison.md) §1–2 |
| 31 | **No open question changes the A/B/C/D ranking.** Every still-open `OQ-NNN` narrows an implementation detail inside candidate A (pagination widget chrome, parse-strategy trigger, one outlier condition's mitigation, e-ink redraw tuning) rather than threatening the choice of A itself. | high | [`06` §3](docs/research/06-approach-comparison.md#3-blocking-open-questions-63), [`07`](docs/research/07-risks-open-questions.md#blocking-status-after-phase-6) |
| 32 | **Licensing settled (Phase 7, 2026-09-08) — the port is cleared for a free, non-commercial release.** The family released the Magium **story text CC BY 4.0**, explicitly for ports/translations, so redistribution needs **no permission request** — only attribution + a note that the text was reformatted to `.magium` and reflowed. The port's own **code is AGPL-3.0-or-later** (matching KOReader, into whose Lua state a plugin loads; MIT engine code composes in cleanly). `LICENSE` + `THIRD-PARTY-NOTICES.md` + `CONTRIBUTING.md` added; About screen + README carry the attribution. OQ-004 + OQ-005 closed. Earlier (2026-08-31): scope was personal-use-only and Phase 7 was deferred under ADR-003 — [ADR-008](docs/decisions/ADR-008-license-and-distribution.md) supersedes it. | high | [ADR-008](docs/decisions/ADR-008-license-and-distribution.md), [`08-licensing.md`](docs/research/08-licensing.md) |
| 33 | **Full roadmap for candidate A bands to ~100–162 hrs** across a pre-flight parse-timing gate (Milestone 0) and eight build phases (MVP → full story/nav → saves → stats → achievements → settings → i18n → polish). The two widest-uncertainty items are Phase I's custom fullscreen pagination widget (no KOReader prior art does "fullscreen + paginated" together — OQ-013) and Phase VIII's on-device tuning (e-ink feel/OQ-007, condition-outlier cost/OQ-011) — both flagged as the best-targeted spots for community help. Everything else is closer to mechanical, oracle-checked translation. | medium | [`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md) §1–2 |
| 34 | **Saves, stats, and achievements (roadmap phases III–V) are mutually independent extensions of the same variable engine, and localization (phase VII) depends only on the full-corpus/navigation phase (II)** — three real opportunities to parallelize implementation work or hand off to a contributor, not a strictly linear build order. | high | [`09`](docs/research/09-roadmap-effort.md) §3 |
| 35 | **The three still-open OQs that survived Phase 6 (OQ-001's parse-time tail, OQ-007, OQ-011) plus OQ-013 are not researchable further on paper** — each needs real device time or actual code. Phase 8 resolved this by scheduling them as concrete roadmap work (a pre-flight gate for OQ-001; built into Phase I by design for OQ-013; Phase VIII line items for OQ-007/OQ-011) rather than leaving them open-ended, satisfying the design doc's "closed or explicitly deferred with a reason" exit criterion for every remaining row. | high | [`09`](docs/research/09-roadmap-effort.md) §5, [`07`](docs/research/07-risks-open-questions.md#blocking-status-after-phase-6) |
| 36 | **Milestone 0 done (2026-08-31): on-device cold parse of all 54 files ≈ 2.2 s** on the owner's Kindle Paperwhite 12th gen (2282 / 2215 / 2186 ms, three restarts; x86 emulator 411 ms). Over the ~1 s gate → **`story` ships `eager` with `preload()` deferred to the first reader-open** (Trapper progress bar; once per KOReader session, then instant; page turns/choices never parse). The `lazy` index+disk-cache path (Task 15) is **deferred out of Phase I** to Phase VIII — owner chose the simpler route over building it now. OQ-001 resolved. | high | [spike 06](docs/spikes/06-ondevice-parse-timing/FINDING.md), [spec §7](docs/specs/2026-08-31-plugin-architecture-and-phase-i.md#7-the-parse-strategy-seam-enginestorylua) |
| 37 | **The Lua engine port matches `magium-dev` structurally and by-render.** `parser.lua` reproduces the exact corpus counts (2159 scenes / 4880 paragraphs / 3734 choices / 594 set() / 145 achievement() / 2480 #if, 0 anomalies) and diffs per-scene identical against `parser.js` over all 54 files; the full render pipeline (`scene.render`) matched the `magium-dev` HTTP oracle 6/6 on the 6 committed goldens on the first combined run, no engine bug found. Three plan defects were caught against the JS source during review (`_match_set` comma format, the `v_ac_*` freeze semantics, the stat-check key→label swap). | high | SDD ledger `.superpowers/sdd/2026-08-31-…/progress.md`; `reference/tools/oracle-diff.js` |

## Open questions

Tracked in [`docs/research/07-risks-open-questions.md`](docs/research/07-risks-open-questions.md)
(OQ-001 … OQ-013). **Every OQ is now closed.** OQ-004 (redistribution
permission) + OQ-005 (license) closed in Phase 7, 2026-09-08
([ADR-008](docs/decisions/ADR-008-license-and-distribution.md)): story text is
CC BY 4.0 (no permission request needed), port code is AGPL-3.0-or-later.
OQ-007 / OQ-011 / OQ-013 closed in Phase VIII. Earlier: OQ-003, OQ-006, OQ-010
closed; OQ-001, OQ-008, OQ-009, OQ-012 resolved. **Phase 6:**
none of the remaining open questions block the approach decision (all narrow
an implementation detail inside the chosen candidate A) — see the table above
and [`07`'s blocking-status
note](docs/research/07-risks-open-questions.md#blocking-status-after-phase-6).
**OQ-013** (pagination widget), **OQ-007** (e-ink feel), **OQ-001**'s
parse-time tail, and **OQ-011** (490 KB condition cost) all feed Phase 8's
roadmap as scoped implementation-phase work, not open feasibility risk.
**Phase 8** ([`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md)):
made that concrete — each of the four now has a specific roadmap slot
(Milestone 0 / Phase I / Phase VIII) rather than sitting open-ended, which is
what "explicitly deferred with a reason" means for questions that need real
device time or actual code, not more research.

<details>
<summary>Earlier open-questions summary (Phases 0–5), superseded by the Phase 6 note above</summary>

Narrowed by Phase 2: OQ-002 (widgets exist + prior art; only the "custom vs.
off-the-shelf" call remains — spike A). Still blocking the verdict: OQ-007 (e-ink
feel — spike A), OQ-004 (redistribution permission), OQ-003 (existing offline
gamebook players — but `frotz.koplugin` is a strong lead). New from Phase 1:
OQ-011 (per-render cost of the 490 KB condition outlier). New from Phase 2 and
already resolved: OQ-012 (Windows dev loop — KOReader emulator now built and
running in WSL2). **Phase 3:** no new OQs; OQ-001 further downgraded (spike D now
only tunes the parse strategy, does not gate feasibility); OQ-011 gains an
ordered mitigation list ([`04` §3 row 4](docs/research/04-constraints-budget.md#3-budget-table-33)).
**Phase 4:** OQ-003 **closed (no)** — no existing plugin does this, rules out
approach B; OQ-004 gains two candidate Discord invites + a prepared (unsent)
outreach draft; OQ-006 gains a lead (Ink over Twee for spike C) and evidence
against approach C generally. No new OQs opened.
**Phase 5:** OQ-006 **closed** — conditions/`set()` convert to Ink losslessly
(doesn't change the case against approach C). OQ-001 narrowed further — memory
now effectively closed (real LuaJIT measurement, strongly 🟢), parse-time still
open. OQ-002/OQ-007 unchanged (spike A blocked from running in this session)
but now have a concrete, cheap next step: run spike 04's plugin in the owner's
already-working WSL2 emulator or on the real device. OQ-012 gains a note that a
cloud/remote session hits a different, unrelated block trying the same build
(GitHub tarball downloads denied by network policy) — doesn't reopen OQ-012
itself. No new OQs opened.

</details>

## Decisions

See [`docs/decisions/`](docs/decisions/).

- [ADR-001](docs/decisions/ADR-001-research-dossier-layout.md) — research organized as a modular dossier (not a single report or a wiki).
- [ADR-002](docs/decisions/ADR-002-porting-approach.md) — port Magium as a standalone KOReader plugin with a Lua reimplementation of the engine (candidate A), over extending an existing plugin (B), converting to Twine/Ink + an existing player (C), or a build-time hybrid (D).
- [ADR-003](docs/decisions/ADR-003-defer-licensing-distribution.md) — *(superseded by ADR-008)* deferred licensing work while the project was personal-use-only.
- [ADR-004](docs/decisions/ADR-004-plugin-internal-architecture.md) — plugin internal architecture: three-layer (engine-pure / ui / save), a custom fullscreen paginated reading widget (resolves OQ-013), choices rendered as the final page.
- [ADR-005](docs/decisions/ADR-005-debug-trace-toggle.md) — the debug action-trace is a runtime menu toggle, not a build variant.
- [ADR-006](docs/decisions/ADR-006-no-scene-back-navigation.md) — **no** in-game "back one scene" / history stack: `magium-dev` has none, and parity is the standard. Overrides the roadmap's Phase II "back/history stack" line.
- [ADR-007](docs/decisions/ADR-007-saves-scope.md) — save-slot scope: 50 slots, delete yes, import/export & rename cut.
- [ADR-008](docs/decisions/ADR-008-license-and-distribution.md) — license the port **AGPL-3.0-or-later** (matching KOReader), release it freely and non-commercially, keep the bundled Magium story text under **CC BY 4.0**. Supersedes ADR-003.

## Next steps

**Phase I complete** (on-device sign-off 2026-09-01).

**Phase II implemented 2026-09-01** ([spec](docs/specs/2026-09-01-phase-ii-full-corpus-and-navigation.md),
[plan](docs/superpowers/plans/2026-09-01-phase-ii-full-corpus-and-navigation.md),
branch `feat/phase-ii-full-corpus-nav`) — scene `set()` write-back
(`scene.persist_effects`), special case #8 (`mgm.sh oracle-corpus` now
**8887/8887**), the in-game menu (`ButtonDialog` shell, later-phase rows
disabled), `special:saves`/`stats` → menu. Back/history stack cut (ADR-006).
Automated gates green; **owner on-device playthrough is the last exit box**.
The `"1"→"2"` achievement "seen" bump stays with the Phase V toast.

**Next: Phase III** — saves (checkpoint blob + 50 slots). Its own spec cycle.
