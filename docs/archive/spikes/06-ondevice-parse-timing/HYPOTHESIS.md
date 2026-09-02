# Spike 06 — on-device parse-timing gate (Milestone 0)

- **Status:** in progress
- **Last updated:** 2026-08-31
- **Phase:** Implementation — Milestone 0
- **Sources:** [`../../specs/2026-08-31-plugin-architecture-and-phase-i.md` §10](../../../specs/2026-08-31-plugin-architecture-and-phase-i.md#10-milestone-0--on-device-parse-timing-gate), [spike 03](../03-full-corpus-memory-parse/FINDING.md)
- **Related:** [ADR-002](../../../decisions/ADR-002-porting-approach.md), OQ-001

## Hypothesis

Parsing all 54 English `.magium` files with `engine/parser.lua` completes in
≤ ~1 s on the Kindle Paperwhite 12th gen's 1 GHz MTK ARM core under
koreader-base's LuaJIT — making "parse everything at launch" (`story` eager)
viable without a lazy/disk-cache layer for the MVP.

Desktop anchors (spike 03): 112–205 ms on x86 across two LuaJIT builds.

## Method

Deploy the timing `main.lua` + `engine/`. Menu → "Magium: time parse". It
restarts-cold-parses once (log line `MAGIUM parse cold: N ms`), then parses
twice more warm (`MAGIUM parse warm: N ms`). Read `koreader/crash.log`.

Run on: (a) the real Kindle, (b) the WSL2 kodev emulator (x86 — sanity only).

## Decision rule

| Kindle cold parse | `story` default |
|---|---|
| ≤ ~1 s | `eager` |
| > ~1 s | `lazy` |
