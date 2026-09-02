# Finding — Spike 06 (on-device parse-timing gate, Milestone 0)

- **Status:** stable — measured on the owner's Kindle Paperwhite 12th gen, 2026-08-31. **Verdict: `story` = `eager`, `preload()` deferred to the first reader-open** (cold parse ≈ 2.2 s is over the ~1 s gate; owner chose deferred-eager over building the lazy path). Lazy strategy (Task 15) deferred out of Phase I.
- **Last updated:** 2026-09-01 (citation pinned; findings unchanged)
- **Phase:** Implementation — Milestone 0
- **Sources:** this spike's harness = [`../../../magium.koplugin/main.lua`](../../../../magium.koplugin/main.lua)`@b881967` — **volatile citation, pinned**: Task 20 replaced that file wholesale, so only the `b881967` revision contains the timing harness described below — driving [`engine/story.lua`](../../../../magium.koplugin/engine/story.lua) `strategy="eager"` → [`engine/parser.lua`](../../../../magium.koplugin/engine/parser.lua); emulator run via `tools/mgm.sh emu-smoke 35` on **LuaJIT 2.1** in `koreader-emulator-x86_64-linux-gnu-debug` (KOReader v2026.07.1, `9192014`), this session's x86_64 container — **not** the Kindle
- **Related:** [`HYPOTHESIS.md`](HYPOTHESIS.md), [`../../specs/2026-08-31-plugin-architecture-and-phase-i.md` §7 / §10](../../../specs/2026-08-31-plugin-architecture-and-phase-i.md#10-milestone-0--on-device-parse-timing-gate), [spike 03](../03-full-corpus-memory-parse/FINDING.md), [ADR-002](../../../decisions/ADR-002-porting-approach.md), OQ-001

## Method

`magium.koplugin/main.lua@b881967` (temporary harness) calls `time_parse(data_root)`,
which runs `Story.new{…, strategy="eager"}:preload()` — a full parse of all 54
English `.magium` files — three times: once **cold** (first call after a KOReader
restart), then twice **warm**. Each result is `logger.info`'d with a
`MAGIUM parse cold:` / `MAGIUM parse warm:` prefix.

Two entry points, same `time_parse`:

1. **Menu** — ≡ → More tools → "Magium: time parse". This is what the owner taps
   on the real Kindle (Step 4).
2. **`init()` auto-run**, deferred via `UIManager:nextTick` so it does not block
   FileManager load. Added only because the headless-xvfb emulator sanity run has
   no way to tap a menu.

On the **emulator**, `logger.info` goes to STDOUT (captured by the `emu-smoke`
wrapper); `crash.log` stays empty unless there is an actual crash. On the **real
Kindle**, KOReader redirects stdout/stderr into `koreader/crash.log`, so the
owner greps the timing lines out of that file after the run.

The `init()` auto-run is `pcall`-guarded: it fires unattended from the main loop
at every launch, so a throw (e.g. a busybox `ls` / `io.popen` quirk on the
Kindle) is logged as `MAGIUM parse (init) failed: …` and swallowed rather than
tripping KOReader's crash handler. The menu path is left unguarded — it is
user-triggered and recoverable.

**Timing caveat:** `time_parse` uses `os.clock()`, which measures process **CPU
time**, not wall-clock, and under-counts the `io.popen("ls")` fork/wait. For a
single-threaded parse with no real I/O waits this tracks wall-clock closely, and
the discrepancy is negligible against a ~1 s gate — but an outside reader should
know the number is CPU time. (KOReader's `require("ui/time")` monotonic clock is
the swap if a true wall-clock figure is ever needed.)

## Results

### Emulator (x86) — sanity only

`wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh emu-smoke 35'`, 2026-08-31:

```
08/31/26-12:55:24 DEBUG Plugin loaded magium
08/31/26-12:55:24 DEBUG FM loaded plugin magium at plugins/magium.koplugin
08/31/26-12:55:25 INFO  MAGIUM parse cold: 411 ms
08/31/26-12:55:26 INFO  MAGIUM parse warm: 344 ms / 365 ms
=== crash.log empty (no crash) ===
```

| Measurement | Cold | Warm | Notes |
|---|---|---|---|
| **Emulator (x86, LuaJIT 2.1, this container)** | **411 ms** | **344 / 365 ms** | Plugin loads clean — no `Error when loading …/main.lua`, no traceback. Higher than spike 03's pure-parse 112–205 ms: the harness figure includes first-call JIT compilation, the `io.popen("ls …")` file enumeration, and `Story` object allocation on top of the parse itself. |
| **Device — Kindle Paperwhite 12th gen (KindlePaperWhite6, ~1 GHz MTK ARM, koreader-base LuaJIT), KOReader v2026.07.1** | **2282 ms** (consistent: 2282 / 2215 / 2186 across three restarts) | **~2037–2354 ms** | The deciding number. Plugin loaded clean — no traceback, `MAGIUM parse (init) cold 2282 ms` confirms the `init()` auto-run fired. **~5.6× the emulator's x86 figure** (411 ms) — steeper than spike 03's ~3–4× guess. Warm barely helps: the work is CPU-bound `.magium` line-scanning + table allocation, not something JIT or page cache speeds up much. |

### Device run — raw log (`koreader/crash.log`, 2026-08-31 19:56–19:57)

```
08/31/26-19:56:58 INFO  MAGIUM parse cold: 2282 ms
08/31/26-19:57:02 INFO  MAGIUM parse warm: 2037 ms / 2247 ms
08/31/26-19:57:02 INFO  MAGIUM parse (init) cold 2282 ms / warm 2037 / 2247 ms
08/31/26-19:57:24 INFO  MAGIUM parse cold: 2215 ms      (2nd restart)
08/31/26-19:57:29 INFO  MAGIUM parse warm: 2248 ms / 2354 ms
08/31/26-19:57:42 INFO  MAGIUM parse cold: 2186 ms      (menu re-tap)
08/31/26-19:57:47 INFO  MAGIUM parse warm: 2338 ms / 2190 ms
```

Deployed via MTP (Kindle PW12 has no USB-mass-storage — it presents as an MTP/WPD
device). 69 runtime files (`_meta.lua`, `main.lua`, `engine/**`, `data/en/**`);
`spec/` excluded.

## Decision rule → outcome

| Device cold parse | Options | Outcome |
|---|---|---|
| ≤ ~1 s | `eager` at launch | — |
| > ~1 s | `lazy` (scene-id index + per-chapter disk cache, spec §7.2) **or** `eager` deferred to the first reader-open | **2.2 s → `eager`, deferred to first `openReader()`** |

Threshold rationale: [`04` §3 row 3](../../research/04-constraints-budget.md#3-budget-table-33).

**Verdict: `story` = `eager`, `preload()` deferred to the first
`Magium:openReader()` of the KOReader session, behind a `Trapper` progress bar.**

The device cold parse is **≈ 2.2 s** — over the ~1 s gate. `lazy` would make the
launch invisible but costs the index + per-chapter `Persist`-cache path (~150
lines, on the launch hot path). The owner chose the simpler route: with `eager`
the ~2.2 s parse just moves to *"the first time you open Magium this session"*
(a progress bar, not a freeze), then every open after that is instant and the
story stays resident for the session (~11.5 MB heap — a non-issue). **Page turns
and choices never parse** either way — that was the real concern, and it holds.

Consequences:
- **Task 15 (lazy strategy) is deferred out of Phase I.** `engine/story.lua`
  keeps the `strategy` / `cache_store` params and the two erroring stubs
  (`_build_index` / `_lazy_get`) for a later phase (spec §7.2, §12 Phase VIII).
- `main.lua` (Task 20): `init()` does **no** parsing; `Magium:_ensureLoaded()`
  (once-guarded) runs `story:preload()` under `Trapper` on the first
  `openReader()`. No `cache_store` adapter.
- If the once-per-session ~2.2 s wait ever grates, the deferred `lazy` path is
  the fix — it slots into the same seam.

## What was done (2026-08-31)

Controller deployed the runtime files (`_meta.lua`, `main.lua`, `engine/**`,
`data/en/**` — `spec/` excluded) to `koreader/plugins/magium.koplugin/` over MTP
(Kindle PW12 presents as an MTP/WPD device, no drive letter). Owner disconnected
USB, restarted KOReader three times and tapped ≡ → More tools → "Magium: time
parse". Controller reconnected, pulled `koreader/crash.log` over MTP, recorded
the numbers above. Plugin loaded clean — no traceback, no `MAGIUM parse (init)
failed` line.

## Confidence

**High** — measured directly on the target device (the exact model, FW, and
KOReader build the owner runs), three consistent cold runs within 100 ms of each
other, well clear of the gate in the decisive direction. Memory was closed by
spike 03 (~11.5 MB heap) and is not re-measured here.
