# Spike 03 — full-corpus memory + cold-parse time in Lua

- **Status:** done (partial — desktop LuaJIT only, not on-device; see FINDING.md)
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.4, "Spike D")
- **Sources:** `reference/tools/measure-story-size.js` (JS baseline, Phase 0);
  [`../02-engine-in-lua/`](../02-engine-in-lua/) (reused parser, unmodified)
- **Related:** [`../../research-plan.md`](../../research-plan.md) task 5.4,
  [`OQ-001`](../research/07-risks-open-questions.md),
  [`04-constraints-budget.md`](../research/04-constraints-budget.md) §2/§4 (F-24),
  [`FINDING.md`](FINDING.md)

## Question

"Lua-side memory cost of holding the full parsed story, and cold-parse time
of all 54 files" (`research-plan.md` 5.4 / OQ-001). Phase 0/3 only had a
**V8** number (~17.4 MB heap delta, ~95-130 ms parse, F-24) as a proxy —
this spike gets the equivalent numbers from an actual Lua interpreter.

## What "answered" looks like

- All 54 English `.magium` files parsed by [spike 02](../02-engine-in-lua/)'s
  Lua port (unmodified — this doubles as a full-corpus fidelity check on
  that port, not just a benchmark).
- Structural counts (scenes/paragraphs/choices/`set()`) compared against the
  JS baseline — a mismatch would mean the port has a latent bug the 6-fixture
  diff didn't catch.
- Parse time (several runs, `os.clock()`) and Lua GC-heap delta
  (`collectgarbage("count")`) reported the same way the JS script reports
  `process.hrtime`/`process.memoryUsage().heapUsed`.

## What will be built (throwaway)

- `measure_lua.lua` — CLI, `require`s spike 02's `magium_parser.lua` via a
  relative `package.path`, parses all 54 files N times, reports counts +
  timing + memory.

## Known limitation going in

This container has no real Kindle and (per this spike's own finding — see
[`FINDING.md`](FINDING.md)) could not get the KOReader `kodev` emulator built
either. So this can only produce a **desktop LuaJIT** number, exactly the
same kind of "anchor, not answer" caveat Phase 3's F-24 already carries for
the JS side (`04-constraints-budget.md` §2) — not a full close of OQ-001,
which still needs the actual device or the owner's WSL2 emulator.
