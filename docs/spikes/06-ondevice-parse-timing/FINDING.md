# Finding — Spike 06 (on-device parse-timing gate, Milestone 0)

- **Status:** stable — measured on the owner's Kindle Paperwhite 12th gen, 2026-08-31. **Verdict: `story` default = `lazy`** (cold parse ≈ 2.2 s, over the ~1 s gate).
- **Last updated:** 2026-08-31
- **Phase:** Implementation — Milestone 0
- **Sources:** this spike's harness = [`../../../magium.koplugin/main.lua`](../../../magium.koplugin/main.lua) (temporary; Task 20 replaces it) driving [`engine/story.lua`](../../../magium.koplugin/engine/story.lua) `strategy="eager"` → [`engine/parser.lua`](../../../magium.koplugin/engine/parser.lua); emulator run via `tools/mgm.sh emu-smoke 35` on **LuaJIT 2.1** in `koreader-emulator-x86_64-linux-gnu-debug` (KOReader v2026.07.1, `9192014`), this session's x86_64 container — **not** the Kindle
- **Related:** [`HYPOTHESIS.md`](HYPOTHESIS.md), [`../../specs/2026-08-31-plugin-architecture-and-phase-i.md` §7 / §10](../../specs/2026-08-31-plugin-architecture-and-phase-i.md#10-milestone-0--on-device-parse-timing-gate), [spike 03](../03-full-corpus-memory-parse/FINDING.md), [ADR-002](../../decisions/ADR-002-porting-approach.md), OQ-001

## Method

`magium.koplugin/main.lua` (temporary harness) calls `time_parse(data_root)`,
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

## Decision rule

| Device cold parse | `story` default `strategy` |
|---|---|
| ≤ ~1 s | `eager` — parse all 54 files at launch behind a `Trapper` progress bar (spec §7.1) |
| > ~1 s | `lazy` — scene-id→file index + per-chapter disk cache (spec §7.2) |

Threshold rationale: [`04` §3 row 3](../../research/04-constraints-budget.md#3-budget-table-33).
Both implementations ship regardless; this only picks the default (a plugin
setting flips it).

**Verdict: `story` default `strategy = "lazy"`.** The device cold parse is
**≈ 2.2 s** — more than double the ~1 s gate. Parsing all 54 files at launch
would freeze the plugin for ~2 s every time it opens (and warm re-parse barely
helps, so a "parse once per session" shortcut buys nothing). `lazy` — scan every
file's `ID:` lines for a scene-id→file index at launch (milliseconds), then parse
+ disk-cache one chapter file on first access (spec §7.2) — is the default.
`eager` still ships and a plugin setting flips to it (e.g. for a desktop build,
or if a future device is faster).

Follow-ups this result creates:
- **Task 15 (lazy strategy) is now load-bearing for Phase I**, not just "also
  shipped". Its `cache_store` adapter (Persist-backed in `main.lua`, Task 20) is
  on the launch hot path.
- Even lazy's *first* `get_scene` for a chapter parses that whole file
  (~10–30 ms on device for ch1's 27 KB, extrapolating 2.2 s / 7.6 MB). Fine for
  a page turn; the `b3ch4a.magium` 490 KB file (OQ-011) would be ~30 ms to parse
  and is cached after — measure in Phase VIII if it ever feels slow.
- `Story.new{strategy="eager"}` under `Trapper` with a progress bar (spec §7.1)
  is not needed for the Phase I default, but keep it wired for the setting.

## What was done (owner, 2026-08-31)

Controller deployed `magium.koplugin/` to the Kindle over MTP, owner restarted
KOReader three times + tapped the menu item, controller pulled `crash.log` over
MTP and recorded the numbers above.

## Confidence

**High** — measured directly on the target device (the exact model, FW, and
KOReader build the owner runs), three consistent cold runs within 100 ms of each
other, well clear of the gate in the decisive direction. Memory was closed by
spike 03 (~11.5 MB heap) and is not re-measured here.
