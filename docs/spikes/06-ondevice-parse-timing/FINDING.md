# Finding — Spike 06 (on-device parse-timing gate, Milestone 0)

- **Status:** in progress — emulator (x86) sanity done; the on-device (ARM) number is **PENDING the owner's Kindle run** (Task 6 Step 4)
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
| **Device — Kindle Paperwhite 12th gen (1 GHz MTK ARM, koreader-base LuaJIT)** | **PENDING — owner runs on the physical Kindle (Task 6 Step 4)** | PENDING | The number that actually sets the default. x86↔ARM is the whole reason this spike exists — see spike 03's identical caveat. |

## Decision rule

| Device cold parse | `story` default `strategy` |
|---|---|
| ≤ ~1 s | `eager` — parse all 54 files at launch behind a `Trapper` progress bar (spec §7.1) |
| > ~1 s | `lazy` — scene-id→file index + per-chapter disk cache (spec §7.2) |

Threshold rationale: [`04` §3 row 3](../../research/04-constraints-budget.md#3-budget-table-33).
Both implementations ship regardless; this only picks the default (a plugin
setting flips it).

**Verdict: PENDING the device number.** The emulator's 411 ms cold is well
under the 1 s line, and spike 03's ARM extrapolation (~1–4 s) straddles it, so
the emulator result is *suggestive of `eager`* but cannot decide it — a
mid-range ARM slowdown factor lands on either side of the gate. Do not set the
`PARSE_STRATEGY` default or fill spec §7.1's measured number until the owner's
`MAGIUM parse cold:` line from the Kindle is recorded here.

## What remains (owner)

1. Copy `magium.koplugin/` to the Kindle's `koreader/plugins/`, restart KOReader.
2. Either let the `init()` auto-run fire, or tap ≡ → More tools → "Magium: time
   parse".
3. Pull `koreader/crash.log` over USB; read the `MAGIUM parse cold:` and
   `MAGIUM parse warm:` lines.
4. Record them in the device row above, set the verdict against the ~1 s rule,
   and update spec §7.1's opening note with the measured number + resulting
   default. Then flip this doc's Status to stable and confidence to match.

## Confidence

**Low** — the only measured number here is x86, and the gate is ARM. Memory is
not re-measured (spike 03 closed it: ~11.5 MB heap, a non-issue); this spike is
purely the parse-time gate, and its deciding input is not yet in hand.
