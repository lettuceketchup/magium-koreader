# ADR-005: Debug action-trace — runtime menu toggle, per-session JSONL, no build variants

- **Status:** Accepted
- **Date:** 2026-09-01
- **Deciders:** rishishwarmanu@gmail.com
- **Phase:** Implementation — Phase I (added mid-execution, after Task 20)
- **Related:** [`../specs/2026-08-31-plugin-architecture-and-phase-i.md`](../specs/2026-08-31-plugin-architecture-and-phase-i.md)
  §9.2 (the deliverable this records), [ADR-004](ADR-004-plugin-internal-architecture.md)
  (the plugin structure this extends), [`../research/03-koreader-platform.md`](../research/03-koreader-platform.md)
  §7 F-18 (`crash.log` is the on-device log sink), OQ-007 (e-ink refresh — the trace helps tune it).

## Context

Phase I ships chapter 1 playable on the owner's Kindle. The on-device debug loop
(F-18) is USB-copy + restart + read `koreader/crash.log`; the emulator can't
reproduce real e-ink timing, real gestures, or a real KOReader session lifecycle,
so the first real signal about bugs comes from the owner actually playing. A
structured record of *what the player did* and *how the plugin reacted* —
loads, resumes, renders, page turns, choices, saves, warnings — turns "it
misbehaved somewhere" into a diff against the oracle-validated engine.

The owner's first framing was a build-time flag producing separate dev/release
plugin variants. The plugin has **no build step** (deploy = copy the folder), so
that would mean introducing a build script + a marker-file or name-templating
mechanism. The owner then re-scoped: the trace only needs to exist when the
player *wants* to record a session for a bug report — a runtime choice, not a
build-time one.

## Options considered

### Option A — runtime menu toggle, always-compiled tracer (chosen)
- Pros: no build machinery; one plugin artifact; player enables it exactly when
  reproducing an issue; `trace.event()` is a single `if not enabled then return`
  when off (page turns stay cheap on e-ink); trivially testable (pure module,
  injected writer/clock).
- Cons: the tracer code always ships (a few hundred bytes, dormant).

### Option B — build script + marker file / side-by-side dev plugin
- Pros: release artifact carries zero trace code; a `magium_dev.koplugin` could
  sit beside the release one on the device.
- Pros/cons wash out: the runtime cost of the dormant tracer is negligible, so
  the only thing a build split buys is code cleanliness at the cost of a whole
  new build/packaging subsystem this project otherwise doesn't need.
- Cons: new `tools/build.sh`, a variant-selection mechanism, `_meta.lua`
  name-templating for side-by-side, two things to test and ship.

### Option C — piggyback `crash.log` only (tagged `logger` lines, no separate file)
- Pros: near-zero new code; the owner already pulls `crash.log`.
- Cons: `crash.log` is a 500 KB rotating buffer shared with all KOReader output —
  a long session's early trace rotates out; not cleanly machine-parseable;
  interleaved with unrelated noise.

## Decision

**Option A**, with a dual sink:

1. **Toggle:** a `Record debug log` checkbox in the plugin's `≡ → More tools →
   Magium` submenu, persisted as `G_reader_settings` key `magium_trace` (default
   off, survives restarts). Read once at `Magium:init()`.
2. **Durable sink:** `util/trace.lua` buffers `{ t = <ms>, ev = <kind>, … }`
   records and flushes them as **JSON Lines** to `koreader/magium/trace-<YYYYMMDD-HHMMSS>.jsonl`
   — one file per reader-open-with-logging-on, newest 5 kept (older pruned on
   open). First line is a `session` header (plugin + KOReader version, device,
   timestamp, resume scene).
3. **Quick-look sink:** every event also mirrors a one-line `logger.info("[MGM]
   …")` summary → lands in `crash.log` immediately, so an unflushed buffer still
   survives a hard crash.
4. Flush points: choice commit, reader close, suspend/close broadcast, and every
   32 buffered events. **Not** per page turn.
5. `util/trace.lua` is pure (Lua stdlib + `engine/vendor/json`); the file writer,
   the `logger` fn, and the clock are injected by `main.lua` — same
   injected-seam pattern as `save/manager`'s writer.

## Rationale

The re-scoping removed the only thing that justified a build split. A dormant
`if not enabled then return` costs nothing measurable; a build subsystem costs a
script, a variant mechanism, and ongoing maintenance for a one-person project.
JSON Lines in a dedicated per-session file is the format that makes the trace
*useful* — greppable, diffable, and replayable against the `magium-dev` oracle
offline — which is the entire point. Mirroring to `crash.log` keeps the
zero-friction path (the owner already pulls that file) without making it the
system of record.

## Consequences

- **Easier:** bug reports from real play carry a deterministic action log; a
  divergence from the engine's oracle-validated behaviour is visible in the
  trace; the owner's Task 21 device playthrough is itself traced.
- **Harder:** ~13 one-line instrumentation calls across `main.lua` + one in
  `ui/reader.lua` are a small ongoing "keep the trace complete" tax on future
  UI/flow changes.
- **Follow-up:** Phase I gains Task 22 (`util/trace.lua` + spec) and Task 23
  (toggle + instrumentation + emu verification), executed after Task 20 and
  before Task 21. Spec §9.2 + §11.1/§11.2 updated.
- **Revisit if:** the trace needs to capture full variable-store snapshots for
  true offline replay (currently records only `set_vars` keys per choice), or if
  a release channel ever genuinely needs zero trace code — at which point Option
  B's build split can wrap this module unchanged.
