# ADR-004: Plugin internal architecture — three-layer, engine-pure, custom paginated reader

- **Status:** Accepted
- **Date:** 2026-08-31
- **Deciders:** rishishwarmanu@gmail.com
- **Phase:** Implementation — design cycle 1
- **Related:** [`../specs/2026-08-31-plugin-architecture-and-phase-i.md`](../specs/2026-08-31-plugin-architecture-and-phase-i.md)
  (the spec this records decisions from), [ADR-002](ADR-002-porting-approach.md)
  (the approach this refines), [`../research/03-koreader-platform.md`](../archive/research/03-koreader-platform.md),
  [`../research/09-roadmap-effort.md`](../archive/research/09-roadmap-effort.md),
  [`../research/07-risks-open-questions.md`](../archive/research/07-risks-open-questions.md) OQ-013,
  [`../spikes/02-engine-in-lua/`](../archive/spikes/02-engine-in-lua/), [`../spikes/04-ui-plugin-skeleton/`](../archive/spikes/04-ui-plugin-skeleton/)

## Context

[ADR-002](ADR-002-porting-approach.md) fixed the *approach* — a standalone
`.koplugin`, a Lua reimplementation of the `magium-dev` engine, `.magium` bundled
and parsed at runtime — but left the plugin's **internal structure** open. The
implementation-design cycle (opened 2026-08-31) had to settle three things before
an implementation plan could be written:

1. **How the code is layered.** The parity-verification strategy depends on
   running the engine against the live `magium-dev` differential oracle
   ([design doc §9](../archive/superpowers/specs/2026-08-31-magium-koreader-research-design.md#9-how-research-findings-are-validated),
   [`03` §8.3](../archive/research/03-koreader-platform.md#83-differential-testing)),
   which only works if the engine has no KOReader dependency. The roadmap also
   identified phases III/IV/V/VII as independent extensions that should be
   parallelizable / contributor-handoffable
   ([`09` §3](../archive/research/09-roadmap-effort.md#3-critical-path--parallelism-83), F-37) —
   which needs real module boundaries.
2. **The reading widget.** [Spike 04](../archive/spikes/04-ui-plugin-skeleton/) proved the
   data/API fit but its screenshots established that `TextViewer` is the wrong
   final widget — padded dialog, continuous scroll, no page concept (OQ-013,
   [`03` §3 spike-A verdict](../archive/research/03-koreader-platform.md#3-ui-toolkit-inventory-23)).
3. **Where choices sit** relative to paginated prose — a play-feel decision on
   e-ink.

## Options considered

### Layering

#### Option A — Three-layer, engine-pure
`engine/` (pure Lua, zero KOReader `require`s, desktop-testable) + `ui/` (KOReader
widgets, depends on engine render-model shapes) + `save/` (thin persistence) +
`main.lua` (glue).
- Pros: the oracle diff and busted engine specs run under bare `luajit`, not just
  the emulator; `ui/reader.lua` and `engine/scene.lua` change independently;
  later phases only *add* modules; matches `magium-dev`'s own functional shape.
- Cons: slightly more upfront structure than a direct file-for-file port;
  `pagination` and `save` need injected seams (a `measure_fn`, a writer) to stay
  testable.

#### Option B — Two-layer faithful port
Mirror `parser.js` / `utils.js` / `renderers.js` file-for-file as `parser.lua` /
`utils.lua` / `renderers.lua`, with widgets inline in a thin `main.lua`.
- Pros: fastest to first-playable; closest to the reference for line-by-line
  diffing; `utils.lua` maps 1:1 to `utils.js`.
- Cons: `renderers.lua` inevitably accretes KOReader-widget concerns, breaking the
  desktop-test boundary that the whole parity strategy (C5) rests on; `utils.js`
  is already a grab-bag (conditions + stats + headers + locale) and freezing that
  split forward is a liability; no clean seam for the parallel later phases.

#### Option C — Engine-pure, defer the custom widget
Layer 1 identical to Option A, but Phase I ships `ScrollTextWidget` in a
fullscreen container and the real paginated widget waits until Phase VIII.
- Pros: playable sooner; the risky new widget work is pushed past the MVP.
- Cons: reintroduces exactly the rework the roadmap deliberately avoided
  ([`09` Phase I](../archive/research/09-roadmap-effort.md#phase-i--mvp-engine-core--the-real-reading-widget):
  "resolves OQ-013 up front rather than shipping `TextViewer` first and
  rebuilding"); continuous scroll carries the e-ink ghosting / no-position-sense
  problems OQ-013 raised; the "temporary" widget still costs real integration
  work that is then thrown away.

### Choice placement

- **Choices as the final page** — prose paginates full-screen; one more page-turn
  past the last prose page shows just the choice list.
- **Pinned choice footer** — prose in the top ~75 %, choices always visible in a
  bottom band.
- **Choices on demand** — prose full-bleed; a bar on the last page opens choices
  as a bottom sheet.

## Decision

- **Layering: Option A** — three-layer, engine-pure. `engine/` requires nothing
  from KOReader; `ui/` → `engine/`; `save/` → `engine/store` + KOReader
  `Persist`/`LuaSettings`; `main.lua` wires them. `engine/scene.render()` stays a
  pure function of `(scene_table, store_view, locale)`.
- **Reading widget: a custom fullscreen paginated widget** (`ui/reader.lua` +
  `ui/pagination.lua`), built in Phase I — not `TextViewer`, not a deferred
  stopgap. Pagination is a pure algorithm with an injected text-measurer.
- **Choice placement: choices as the final page.** The pagination output ends
  with exactly one `kind = "choices"` page.

Full module map, data-shape contracts, and the Phase I build in
[the spec](../specs/2026-08-31-plugin-architecture-and-phase-i.md).

## Rationale

The engine-pure boundary is not a style preference — it is what makes C5
(differential-oracle parity verification) executable outside the emulator, and
what the roadmap's parallelism claim (F-37) actually requires. Option B trades
that away for a familiarity that spike 02 shows is already available anyway (its
Lua port matched the oracle 6/6 without mirroring the JS file split). Option C
optimizes for a sooner demo at the cost of known, roadmap-acknowledged rework;
the widget is the single most KOReader-idiom-heavy item in the project
([`09` §2](../archive/research/09-roadmap-effort.md#2-effort-summary-table-82)) and doing
it once, early, against real requirements is cheaper than doing it twice.

Choices-as-final-page is the best fit for e-ink: page turns are whole-screen
buffer swaps with no partial-refresh regions to ghost, which is the entire point
of building pagination instead of reusing a scroll widget. It also mirrors how
the web version separates the prose block from the end-of-scene choice buttons.
The footer option spends vertical space on every page and needs a separately
refreshed region; the bottom-sheet option keeps a partial-refresh overlay and an
extra tap.

## Consequences

- **Easier:** engine work is testable and reviewable in isolation (`luajit
  spec/run.lua`); the oracle diff gates every engine change from Phase I;
  phases III/IV/V/VII can proceed against a frozen `engine/` + `ui/reader.lua`.
- **Harder / obligations:** `ui/pagination.lua` must take an injected
  `measure_fn` and `save/manager.lua` an injected writer, or they become
  emulator-only tests; reviewers must actively reject any `require("ui/…")` or
  `require("apps/…")` that creeps into `engine/`.
- **New work:** the custom paginated widget is Phase I scope (15–30 h band) and
  the best-identified spot for community help
  ([`09` §3](../archive/research/09-roadmap-effort.md#3-critical-path--parallelism-83)).
- **Revisit if:** Milestone 0's on-device parse timing forces `story` into a
  shape the seam (§7 of the spec) can't absorb; or on-device testing shows
  whole-page e-ink swaps are *slower* to the reader than a scroll delta (OQ-007) —
  in which case the choice-placement and refresh strategy get revisited in a
  superseding ADR, not the layering.

## Milestone 0 outcome (2026-08-31)

The `story` seam absorbed the parse-timing result without an architecture
change. On-device cold parse ≈ 2.2 s (over the ~1 s gate). Rather than build the
`lazy` implementation, the owner chose **`eager` with `preload()` deferred to the
first `Magium:openReader()`** — the ~2.2 s lands once per KOReader session behind
a progress bar, page turns and choices never parse. Phase I ships `eager` only;
the `lazy` index + per-chapter disk cache stays a stubbed second implementation
behind the same interface, deferred to a later phase (spec §7.2, §12 Phase VIII).
Recorded in [spike 06](../archive/spikes/06-ondevice-parse-timing/FINDING.md) and
[the spec](../specs/2026-08-31-plugin-architecture-and-phase-i.md) §7.
