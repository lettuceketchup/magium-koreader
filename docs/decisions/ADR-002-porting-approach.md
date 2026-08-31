# ADR-002: Port Magium as a standalone KOReader plugin with a Lua reimplementation of the engine

- **Status:** Accepted
- **Date:** 2026-08-31
- **Deciders:** rishishwarmanu@gmail.com
- **Phase:** 6
- **Related:** [`../research/06-approach-comparison.md`](../research/06-approach-comparison.md),
  [`../research/04-constraints-budget.md`](../research/04-constraints-budget.md),
  [`../research/05-prior-art.md`](../research/05-prior-art.md),
  [`../spikes/02-engine-in-lua/`](../spikes/02-engine-in-lua/),
  [`../spikes/03-full-corpus-memory-parse/`](../spikes/03-full-corpus-memory-parse/),
  [`../spikes/04-ui-plugin-skeleton/`](../spikes/04-ui-plugin-skeleton/),
  [`../spikes/05-magium-to-ink/`](../spikes/05-magium-to-ink/),
  [`../research/07-risks-open-questions.md`](../research/07-risks-open-questions.md)
  OQ-001, OQ-003, OQ-004, OQ-006, OQ-013

## Context

The research design ([design doc §2](../superpowers/specs/2026-08-31-magium-koreader-research-design.md))
required Phase 6 to pick an end-form for a Magium-on-KOReader port, or
conclude more spiking was needed first, from four candidates fixed at the
start of the project: (A) a standalone KOReader plugin reimplementing the
`magium-dev` engine in Lua, running against the bundled `.magium` text at
runtime; (B) extending an existing KOReader plugin; (C) build-time converting
`.magium` to a supported narrative format (Twine/Ink/ChoiceScript/EPUB-CYOA)
and using an existing player for it; (D) a hybrid — build-time conversion to a
lean custom format plus a small Lua runtime.

By Phase 6, three prior phases had already produced hard evidence bearing
directly on this choice:

- **Phase 3** ([`04`](../research/04-constraints-budget.md)) found no device
  resource (RAM, storage, CPU, save size) is a hard ceiling for full-parity
  Magium on the owner's Paperwhite 12th gen under KOReader — the open
  questions are all responsiveness/hygiene items with named mitigations, not
  capacity blockers (F-22).
- **Phase 4** ([`05`](../research/05-prior-art.md)) found **no existing
  KOReader plugin plays CYOA/gamebook/narrative-choice content** (OQ-003
  closed "no", F-30) and **no e-ink or KOReader player exists for Twine, Ink,
  or ChoiceScript** anywhere (F-27) — KOReader's HTML rendering path is
  MuPDF-based document rendering, not a JS runtime.
- **Phase 5** (four de-risking spikes) built and confirmed the specific pieces
  candidate A needs: a Lua port of the parser + condition/stat-check evaluator
  matched the JS oracle exactly, including on the **full 54-file corpus**, not
  just a diffed slice (spike 02); the fully parsed story's real Lua memory
  footprint is ~11.5 MB against ~500 MB available, measured under two
  different LuaJIT builds (spike 03); a KOReader widget (`TextViewer` +
  `buttons_table`) actually rendered parsed Magium scenes end to end under a
  real `./kodev build`, with zero errors (spike 04) — though that same spike's
  screenshots also surfaced that `TextViewer` is the wrong *final* widget
  (padded dialog, continuous scroll, not fullscreen+paginated — new OQ-013);
  and `.magium` conditions/`set()` convert losslessly to Ink (spike 05),
  closing the fidelity half of OQ-006 without rescuing candidate C's
  deployability problem.

Full option descriptions and a scored decision matrix are in
[`06-approach-comparison.md`](../research/06-approach-comparison.md) §1–2;
this ADR records the decision itself.

## Options considered

### Option A — Standalone KOReader plugin, Lua engine, runtime `.magium` parsing
- Pros: direct 1:1 reimplementation of the ~640-LOC `magium-dev` engine —
  highest achievable parity ceiling; bundles `.magium` verbatim, so upstream
  story updates are a drop-in file replacement with zero reprocessing; every
  component (parser/condition port, memory footprint, widget data-fit) is
  already spiked and confirmed, not speculative; Lua is a fast pickup for the
  owner's background (finding 4) and `frotz.koplugin` + KOReader GitHub
  Discussions are active precedent/community for the real learning curve (the
  API).
- Cons: the custom fullscreen/paginated reading widget (OQ-013) is genuinely
  new, unbuilt work; on-device (real ARM) cold-parse timing is still
  unmeasured, so the parse-at-launch-vs-lazy-cache call inside this option
  isn't fully closed yet (OQ-001 tail).

### Option B — Extend an existing plugin (`frotz.koplugin`)
- Pros: would inherit an existing, maintained plugin's packaging and (some)
  community trust.
- Cons: `frotz.koplugin` is an IF-interpreter host built around piping I/O to
  a compiled Z-machine/Glulx VM over RemGlk's JSON protocol — architecturally
  unrelated to Magium's flat-variable-store-plus-DNF-conditions model. There
  is no game logic to "add"; its entire I/O core would need replacing with
  Option A's engine anyway, inside a plugin shell whose existing assumptions
  (single VM-session model, RemGlk protocol) work against Magium's
  save-slot/stat-check/achievement model. Phase 4's ecosystem scan found zero
  existing plugins of any kind that already play branching content (OQ-003).

### Option C — Convert `.magium` to Ink/Twine + use an existing player
- Pros: spike 05 showed the conversion itself is cheap and, for
  conditions/`set()`, lossless.
- Cons: no e-ink or KOReader player exists for Ink, Twine, or ChoiceScript —
  KOReader's HTML path is document rendering (MuPDF), not a JS runtime, so
  "use existing tooling" collapses to writing a Lua Ink-story interpreter from
  scratch anyway (no off-the-shelf one exists), which is the same order of
  effort as Option A plus a translation tax: achievements and `special:` hooks
  have no Ink primitive, and cross-chapter navigation plus the empty-target
  "Load game" choice don't fit Ink's model at all.

### Option D — Hybrid: build-time preprocess to a lean format + small Lua runtime
- Pros: same parity ceiling as Option A (same source data); moves parsing cost
  off the device entirely.
- Cons: the problem it solves (slow runtime parsing) didn't materialize —
  spikes 02/03 measured the **full 54-file corpus** parsing in 112–205 ms
  under two LuaJIT builds, the same order of magnitude as the 95–130 ms
  V8/desktop anchor. Adds a build pipeline (a compiler to write and keep
  correct) and a second, self-designed format to version and maintain,
  including re-running the build on every upstream `.magium` change — a
  standing cost Option A does not carry.

## Decision

**Option A** — a standalone KOReader plugin (`<name>.koplugin`) that bundles
the `.magium` story data verbatim and reimplements the `magium-dev` engine
directly in Lua, parsing at runtime.

Within Option A, one implementation detail is deliberately left open rather
than pre-decided: whether to parse all 54 files at launch and hold them
resident, or parse lazily per chapter with a disk cache
([`04` §4](../research/04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34)).
Memory does not force this choice either way (spike 03). It should be settled
early in the implementation phase against a real on-device ARM timing
measurement, not here.

## Rationale

Options B and C each fail on a structural fact established by Phase 4, not a
close tradeoff: B has no existing plugin whose *content model* fits Magium to
extend, and C has no existing *player* on this platform for whatever format
`.magium` is converted into. Scoring them generously on every other axis in
the [decision matrix](../research/06-approach-comparison.md#2-decision-matrix-62)
still leaves them well behind A and D. Option D is a legitimate second-place
option — same parity ceiling as A — but the specific problem it trades away
(a slow runtime parse) turned out not to exist at the magnitude assumed when
D was scoped: Phase 5's actual LuaJIT measurements are close to the original
V8-based desktop anchor, not an order of magnitude worse. Meanwhile D's costs
(a build pipeline to author, a second format to version, a standing
re-build-on-every-upstream-update tax) are real and ongoing, and Option A
avoids all of them by construction — it just reads the same files
`magium-dev` already ships.

No open question in the register ([`07`](../research/07-risks-open-questions.md))
is strong enough to overturn this — see
[`06` §3](../research/06-approach-comparison.md#3-blocking-open-questions-63)
for the full accounting of what each open item actually gates (implementation
detail within A, or project-wide distribution permission, in every case — none
of them re-open the A vs. B vs. C vs. D choice itself).

## Consequences

- Phase 8 (roadmap/effort) can now be scoped concretely against Option A's
  shape: engine port, custom pagination widget (OQ-013), save-model mapping,
  parse-strategy decision gate (OQ-001 tail), e-ink refresh tuning (OQ-007).
- Phase 7 (licensing) can reason about a single, simpler shape: original Lua
  code plus verbatim-bundled `.magium` text, with no derived/converted
  artifact in the license chain (a converted-format artifact under Option C
  or D would have raised its own licensing questions; that's now moot).
- OQ-004 (does the family's permission extend to a further port?) remains the
  standing blocker on public distribution regardless of this decision — it is
  a project-level gate, not an approach-level one, and should be pursued in
  parallel with Phase 7/8 rather than after them.
- Options B, C, and D are not being kept "on the table" as parallel paths;
  reopening any of them requires a new ADR with new evidence, per
  [`docs/decisions/README.md`](README.md)'s superseding rule — most plausibly
  D, if real on-device ARM parse timing (OQ-001's tail) turns out far worse
  than the desktop LuaJIT numbers suggest.
