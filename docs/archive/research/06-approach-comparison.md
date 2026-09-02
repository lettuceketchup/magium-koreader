# 06 — Approach comparison & recommendation

- **Status:** stable
- **Last updated:** 2026-08-31
- **Phase:** 6
- **Sources:** [`04-constraints-budget.md`](04-constraints-budget.md), [`05-prior-art.md`](05-prior-art.md), [`../spikes/`](../spikes/), [`03-koreader-platform.md`](03-koreader-platform.md), [`01-magium-analysis.md`](01-magium-analysis.md)
- **Related:** [`07-risks-open-questions.md`](07-risks-open-questions.md), [`../decisions/ADR-002-porting-approach.md`](../../decisions/ADR-002-porting-approach.md), [`../decisions/ADR-003-defer-licensing-distribution.md`](../../decisions/ADR-003-defer-licensing-distribution.md), [`09-roadmap-effort.md`](09-roadmap-effort.md), `../../SUMMARY.md`

> Goal: pick an end-form, or conclude that specific further spiking is needed
> first. Result is recorded as [ADR-002](../../decisions/ADR-002-porting-approach.md)
> and written into `SUMMARY.md`.

---

## 0. What Phase 6 had to work with

By the time this phase ran, three prior phases had already ruled things in or
out with evidence, not just argument:

- **Phase 3** ([`04`](04-constraints-budget.md)): no device resource is a hard
  ceiling for full-parity Magium — the feasibility question is *responsiveness*,
  not *capacity* (F-22).
- **Phase 4** ([`05`](05-prior-art.md)): **no existing KOReader plugin plays
  CYOA/gamebook content** — OQ-003 closed "no" (F-30), which removes candidate
  B's central premise (there is nothing to extend); and **no e-ink/KOReader
  player exists for Twine, Ink, or ChoiceScript** (F-27), which removes
  candidate C's central premise (there is nothing to convert *to*, only a
  format to convert *into*, with no interpreter for it on this platform).
- **Phase 5** (spikes, [`../spikes/`](../spikes/)): the pieces candidate A needs
  were each individually built and confirmed — the engine ports to Lua and
  matches the JS oracle exactly on the full 54-file corpus (spike 02, F-23 in
  spike terms / finding 23 in `SUMMARY.md`), the parsed story's real Lua memory
  footprint is ~11.5 MB against ~500 MB available (spike 03, finding 24), and a
  KOReader widget actually renders parsed Magium data end to end under a real
  build (spike 04, finding 26) — with one concrete gap found along the way
  (`TextViewer` is the wrong final widget — OQ-013, finding 28).

Phase 6's job is therefore less "discover which approach might work" and more
"confirm, with the evidence assembled, which of the four candidates the prior
phases were already narrowing toward — and be explicit about why the other
three lose."

## 1. Candidates *(6.1)*

### A — Standalone KOReader plugin, Lua engine, runtime `.magium` parsing

Bundle the 54 English `.magium` files (+ the French set, for i18n) **verbatim**
inside the plugin, exactly as `magium-dev` ships them
(`../magium-dev/data/en/*.magium`). Reimplement the ~640-LOC engine
(`parser.js` 131 / `utils.js` 219 / `renderers.js` 194 / `main_setup.js` 117 —
[`01` §0](01-magium-analysis.md)) directly in Lua: the line-oriented scene
parser, the flat `v_*` variable store, DNF condition evaluation
(`apply_conditions`), `set(...) if`, `#if(){}` blocks, `choice(...)`,
`achievement(...)`, the four `special:` hooks, and the 13 hardcoded per-scene
special cases ([`01` §10](01-magium-analysis.md#10-hardcoded-scene-id--variable-special-cases-task-110)).
Parse at launch and hold the result resident in Lua tables (default), with a
lazy-per-chapter-plus-disk-cache fallback already scoped
([`04` §4](04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34))
if real on-device parse timing (OQ-001's still-open tail) turns out to need it.
UI: a fullscreen custom widget for prose + choice list (resolving **OQ-013** —
almost certainly a small custom pagination widget built on `TextBoxWidget`'s
existing measurement API, not `TextViewer`), `KeyValuePage` for stats,
`Notification` for achievement toasts, modeled on — but not extending —
`frotz.koplugin`'s fullscreen `GameView` shape (F-15/F-26). Saves map 1:1 onto
`LuaSettings` + `Persist` for the four `magium-dev` blobs
([`01` §8](01-magium-analysis.md#8-saves--settings-task-18),
[`03` §4](03-koreader-platform.md#4-persistence-24)), debounced.

This is exactly what spikes 02/03/04 already built and confirmed pieces of —
candidate A is the least speculative of the four.

### B — Extend an existing plugin

The only structurally relevant existing plugin is `kbarni/frotz.koplugin` (or
its cousin `kofrotz.koplugin`) — see [`05` §1–2](05-prior-art.md). But
`frotz.koplugin` is an **IF-interpreter host**: it pipes text I/O to and from a
Z-machine/Glulx virtual machine binary (Bocfel / Git) over RemGlk's JSON
protocol. Magium's actual data model — a flat variable store, DNF conditions,
`set()`/`#if` scene scripting evaluated directly against parsed `.magium`
text — has no correspondence to a compiled Z-machine story file. There is no
"game logic" to add to `frotz.koplugin`; its entire I/O core would need to be
replaced with candidate A's engine anyway, just built inside an unrelated
plugin's shell (RemGlk protocol, subprocess-VM model) instead of a clean one.
[`05` §2](05-prior-art.md#2-existing-koreader-game--non-book-plugins-42)
confirms via a full ecosystem scan that **no** plugin of any kind currently
plays branching/CYOA content (OQ-003, F-30) — there is no shortcut at the
engine level. The only genuinely reusable idea from `frotz.koplugin` is its UI
*shape* (fullscreen native-widget transcript + input row), which candidate A
already borrows without needing to fork or depend on the plugin itself.

### C — Convert `.magium` to a supported format + use an existing player

Build-time `.magium` → Ink conversion (spike 05 already found Ink is the
higher-fidelity target over Twee), then play the result with "existing
tooling." The catch, confirmed by [`05` §3](05-prior-art.md#3-twine--ink--choicescript-players-on-constrained-hardware-43)
(F-27): **no e-ink or KOReader player exists for Ink, Twine, or ChoiceScript,
anywhere.** KOReader's HTML rendering path is MuPDF-based document rendering,
not a JS runtime capable of hosting `inkjs`
([`03` §5](03-koreader-platform.md#5-text-rendering-25), F-19). So "use
existing tooling" collapses to *also* writing a Lua Ink-story interpreter from
scratch — no off-the-shelf Lua Ink runtime exists either — which is the same
order of engine-authoring effort as candidate A, except now paying a
translation tax: achievements and `special:` hooks have no Ink primitive and
degrade to inert tags, and cross-chapter navigation and the "Load game" choice's
empty target don't fit Ink's choice model at all (spike 05 findings). The one
thing spike 05 did establish favorably — conditions/`set()` convert losslessly
(closing OQ-006) — doesn't rescue this candidate, because the blocking problem
was never fidelity, it was deployability.

### D — Hybrid: build-time preprocess to a lean format + small Lua runtime

Preprocess `.magium` at build time into a compact serialized/indexed artifact
(borrowing the chunked-layout idea from `magium-recrystallized`'s binary
`.story` format — [`reference/magium-recrystallized-notes.md`](../../../reference/magium-recrystallized-notes.md)),
then ship a small Lua runtime that only deserializes and walks that format —
no runtime line-parsing of raw `.magium` text at all. This was flagged in
[`04` §4](04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34)
as the fallback if spikes B/D showed runtime parsing was too slow to be
viable. They didn't: spike 02/03 measured the **full 54-file corpus** parsing
in 112–205 ms under two different LuaJIT builds on this session's x86
container — the same order of magnitude as the 95–130 ms V8/desktop anchor
Phase 0 used, and with a real Lua memory number (~11.5 MB) *below* the earlier
estimate. D still has the same parity ceiling as A (same source data, no
information lost if the compiler is careful), but adds a build pipeline you
must write and keep correct, a second format to design and version, and —
critically — a **re-run-the-build-on-every-upstream-`.magium`-update** cost
that A does not have (A bundles the raw files and stays in sync for free).

## 2. Decision matrix *(6.2)*

Scored 1 (worst) – 5 (best) per criterion; **weight** reflects how much this
project's specific situation (solo/small-team hobby port, explicit
full-parity goal, owner new to the KOReader API but not to programming) should
lean on that criterion. Scores are illustrative shorthand for the qualitative
reasoning in §1 and the citations above — read the prose, not just the number,
before disagreeing with a cell.

| Criterion (weight) | A — standalone plugin | B — extend existing plugin | C — convert + existing player | D — hybrid build-time |
|---|---|---|---|---|
| Implementation effort (×2) | **4** — ~640 LOC already ported + oracle-validated (spike 02); mostly mechanical JS→Lua; the custom pagination widget (OQ-013) is the main un-built item | 2 — ends up rewriting A's engine anyway, inside a plugin shell (RemGlk/VM model) that fights the data model | 2 — conversion is cheap (spike 05), but still requires writing essentially all of A's engine as a Lua Ink-runtime, plus closing the achievement/hook/nav gaps the conversion drops | 3 — skips runtime parsing, but adds a compiler to write and a second format to define; roughly a wash against A, arguably more total work (compiler *and* runtime, vs. runtime alone) |
| Parity ceiling (×4) | **5** — direct 1:1 reimplementation of the exact engine/data; every design-doc §3 parity row maps directly; spike 02 already shows 6/6 zero-diff plus full-corpus structural match | 3 — could reach full parity in principle (since you'd write A's engine inside it), but `frotz.koplugin`'s existing single-VM-session/RemGlk assumptions actively work against Magium's save-slot/stat-check/achievement model | 2 — achievements and `special:` hooks have no Ink primitive (spike 05); cross-chapter nav and the empty-target "Load game" choice don't fit Ink's model — never a clean 1:1 without hand-written host-script logic anyway | **5** — same data, same ceiling as A, provided the compiler is written carefully (no information is inherently lost by serializing rather than parsing at runtime) |
| On-device performance (×3) | 4 — memory strongly 🟢 (11.5 MB measured); parse-time 🟡 but spike-measured desktop LuaJIT (112–205 ms full corpus) is reassuring; worst case falls back to the already-scoped lazy/disk-cache option | 3 — same engine performance as A once written, plus unnecessary RemGlk subprocess/JSON-protocol overhead Magium's simpler in-process model doesn't need | 3 — a hand-written Lua Ink-runtime is a similar order of complexity to Magium's own condition evaluator; no inherent performance gain, plus conversion-time cost | 4 — shifts parse cost to build time (device just deserializes), but the win over A's already-fast spike-measured numbers is unproven, and resident-memory profile ends up comparable either way |
| Maintainability / upstream-sync cost (×3) | **5** — bundles raw `.magium` verbatim; an upstream `magium-dev` story update is a drop-in file replacement, zero reprocessing | 2 — inherits `frotz.koplugin`'s own release cadence/API surface on top of Magium's — two upstreams to track for one plugin | 2 — every upstream `.magium` change must be re-run through the conversion step before it's playable; the converter becomes a second thing to keep working as the format evolves | 2 — same re-run-on-every-update cost as C, plus a self-authored lean format whose schema/versioning must stay stable across plugin releases |
| Fit with owner's skills + community (×2) | **5** — Lua is a fast pickup for this background (finding 4); the engine port is mechanical JS→Lua; `frotz.koplugin` + KOReader GH Discussions are active precedent for the real learning curve (the API) | 3 — same Lua ramp, plus an unfamiliar existing codebase's RemGlk/VM-hosting design to learn before touching it | 3 — adds Ink's own scripting/runtime model on top of Lua/KOReader, for a fidelity benefit spike 05 shows doesn't fix the deployability problem | 3 — adds designing and maintaining a custom binary/serialized format (schema, versioning) — a skill surface beyond Lua/KOReader |
| Distribution ease (×2) | **5** — ships as an ordinary `.koplugin` folder through the normal channels ([`03` §10](03-koreader-platform.md#10-packaging--distribution-210)) | 4 — same mechanism, but as a fork of/PR to a GPLv3 plugin — raises "why not just use frotz" confusion and licensing questions | 3 — same packaging once built, but it's a bigger deliverable (engine + converter) to explain and justify | 4 — same packaging, plus a build tool contributors need to regenerate the lean artifact from a `.magium` update |
| Risk (×4) | **5** — every element already spiked and confirmed (parser/condition port, memory, widget data-fit, working emulator dev loop); remaining risk is bounded (UI chrome detail, on-device ARM timing) | 2 — depends on an unrelated plugin's architecture bending to a fundamentally different content model; real risk of a forced rewrite mid-build | 2 — rests on "an e-ink Ink/Twine player will exist or be buildable," which Phase 4/5 evidence says isn't true today; risks ending up back at A's engine after spending effort on conversion tooling | 3 — lower technical risk than B/C (same data, same engine) but real process risk: a second format that must never silently drift from the runtime's semantics — a bug class A cannot have by construction |
| **Weighted total** (max 100) | **95** | 53 | 47 | 70 |

The ranking (A ≫ D > B > C) is not close, and every axis where A doesn't score
a clean 5 (effort, on-device performance) is a place where D ties or edges it —
D is a real second-place option, not a strawman, but its edge (skip runtime
parsing) is buying back a cost (95–130 ms → 112–205 ms in spike 02/03's actual
LuaJIT measurement) that turned out not to need buying back, while its
maintainability tax is real and ongoing. B and C both fail for the same
underlying reason: neither has anything to build *on* — Phase 4 established
that the plugin B would extend and the player C would target both don't exist
in a form that fits Magium ([`05` §2–3](05-prior-art.md)).

## 3. Blocking open questions *(6.3)*

Full register: [`07-risks-open-questions.md`](07-risks-open-questions.md).
None of the open items below are strong enough to overturn the ranking in §2 —
they narrow *how* candidate A gets built, not *whether* it's the right choice:

| OQ | Blocks the approach decision itself? | What it actually gates |
|---|---|---|
| **OQ-004** (redistribution permission) | No — blocks *distribution* of any end-form, not the choice between them | **Deferred ([ADR-003](../../decisions/ADR-003-defer-licensing-distribution.md)):** owner confirmed this is personal-use-only for now, no near-term distribution — only relevant again if/when the port is actually being shared. |
| **OQ-013** (custom pagination widget vs. `TextViewer`) | No | A UI-design detail *within* candidate A, already scoped as buildable ([`03` §3](03-koreader-platform.md#3-ui-toolkit-inventory-23)); feeds the Phase 8 roadmap as its own line item. |
| **OQ-007** (e-ink refresh feel) | No | Tunes candidate A's redraw strategy (`"ui"` vs `"full"` cadence); Phase 3 already treats it as a responsiveness question, not a feasibility gate. |
| **OQ-001 tail** (real on-device ARM parse time) | No | Decides whether A ships as "parse-all-at-launch" or needs the lazy-per-chapter fallback already scoped in [`04` §4](04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34) — an implementation detail within A, not a reason to prefer D. |
| **OQ-011** (490 KB condition outlier cost) | No | Same shape as OQ-001 tail — mitigations already ordered ([`04` §3 row 4](04-constraints-budget.md#3-budget-table-33)); worst case is a targeted pre-compile of one construct, not a reason to adopt D wholesale. |
| **OQ-005** (which license governs a port) | No | **Deferred ([ADR-003](../../decisions/ADR-003-defer-licensing-distribution.md)):** Phase 7's job, and Phase 7 itself is deferred until distribution is being considered; independent of which approach was picked, though A's "bundle `.magium` verbatim, write original Lua" shape is the cleanest case to reason about when it happens (no derived/converted artifact in the license chain). |

**Nothing here is blocking for Phase 6's purpose, and — per
[ADR-003](../../decisions/ADR-003-defer-licensing-distribution.md) — nothing
here is currently blocking the project either.** OQ-004 would block *public
distribution* of any end-form, but the owner has confirmed this is a
personal-use project for now with no near-term distribution intent; the
outreach drafts in [`05` §6](05-prior-art.md#6-outreach-46) stay ready,
unsent, until that changes. Phase 8's roadmap work proceeds without waiting
on it.

## 4. Recommendation *(6.4)*

**Candidate A — standalone KOReader plugin, Lua engine, runtime `.magium`
parsing.** Recorded as [ADR-002](../../decisions/ADR-002-porting-approach.md).

**Confidence: high** that A is the right end-form among the four candidates —
every piece of evidence gathered since Phase 3 points the same direction, B
and C each fail on a structural fact (nothing to extend; nothing to play the
converted output) rather than a close call, and D's only advantage (skip
runtime parsing) is not needed given spike 02/03's actual timing.

**Confidence: medium** on one implementation detail inside A — whether
"parse everything at launch" is sufficient on its own, or needs the
lazy-per-chapter-plus-disk-cache fallback from day one. This is *not* a
reason to prefer D (that fallback is cheaper to add inside A than a whole
build pipeline is to build), but it is genuinely undecided pending real
on-device ARM timing (OQ-001's tail) — left for Phase 8 to schedule as an
early implementation milestone with a concrete measure-then-decide gate,
rather than resolved by a research-phase spike.

This does not reopen anything Phase 3–5 already settled: it consolidates
findings 22–28 (`SUMMARY.md`) plus [`05`](05-prior-art.md)'s F-26/F-27/F-30
into a single side-by-side comparison, which is what a Phase 6 architecturally
should be — the individual pieces were never in serious tension with each
other going in.

## Findings

- **F-32 (confidence: high):** Candidates B and C fail for structural reasons,
  not close-call tradeoffs — Phase 4 already established that neither has a
  real thing to build on (no existing CYOA plugin to extend; no existing
  e-ink/KOReader Ink/Twine/ChoiceScript player to convert into). Phase 6's
  comparison confirms this holds even when B and C are scored generously on
  every other axis (§2).
- **F-33 (confidence: high):** Candidate D (build-time preprocess) is a
  legitimate second-place option, not a strawman — same parity ceiling as A —
  but its rationale (avoid a slow runtime parse) is undercut by spike 02/03's
  actual LuaJIT timing (112–205 ms for the full 54-file corpus), and it adds a
  standing maintainability cost (re-run the build on every upstream `.magium`
  change) that A does not have.
- **F-34 (confidence: high):** No open question (OQ-NNN) is strong enough to
  change the A/B/C/D ranking — the open items narrow implementation details
  *within* A (UI widget chrome, parse-strategy trigger threshold, one outlier
  condition's mitigation) rather than threaten the choice of A itself. OQ-004
  (redistribution permission) is the one open item that blocks the project
  going forward, independent of which approach was chosen.
