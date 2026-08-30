# 04 — Constraints budget (go / no-go)

- **Status:** stub (public specs pre-filled 2026-08-31; on-device measurement pending)
- **Last updated:** 2026-08-31
- **Phase:** 3
- **Sources:** [`00-overview.md`](00-overview.md), [`03-koreader-platform.md`](03-koreader-platform.md), [`01-magium-analysis.md`](01-magium-analysis.md) §11, `../../reference/magium-dev-notes.md`, on-device measurement (pending), spike D (pending)
- **Related:** [`06-approach-comparison.md`](06-approach-comparison.md), [`07-risks-open-questions.md`](07-risks-open-questions.md) OQ-001

> Goal: a hard table matching each of Magium's demands against the Paperwhite's
> limits under KOReader, with a mitigation for every yellow/red. This is the
> feasibility crux.

## 1. Device hard limits *(3.1)* — Kindle Paperwhite 12th gen (2024)

| Limit | Value | Confidence | Notes |
|---|---|---|---|
| Total RAM | ~512 MB | medium | the-ebook-reader / goodereader; **confirm on-device** |
| Free RAM under KOReader | TBD | — | measure via KOReader (Dev → memory, or `free`); the number that matters |
| CPU | MediaTek dual-core @ 1 GHz | medium | first multi-core Paperwhite; ~25% faster page turns than PW5 |
| Storage | 16 GB (~13–14 GB free) | high | bundling 7.5 MB of story text is trivial here |
| Threads | none — KOReader is single-process cooperative Lua | high | long parse/convert work blocks the UI unless chunked |
| E-ink refresh | full ≈ 400–600 ms, partial faster; A2 for fast updates | low | confirm feel in spike A |
| Lua VM | LuaJIT (arm), `koreader-kindlehf` build | medium | confirm exact version Phase 2; LuaJIT has its own memory quirks on 32-bit |
| Lua GC / memory ceiling | TBD | — | LuaJIT on 32-bit has historically had a ~2 GB (often practically far less) allocation ceiling; not a concern at our scale but note GC pauses |

## 2. Magium demands *(3.2)*

| Demand | Value | Source |
|---|---|---|
| Text on disk (en) | 7.50 MB / 54 files | measured, `../../reference/magium-dev-notes.md` |
| Scenes / paragraphs / choices | 2159 / 4880 / 3734 | measured |
| Fully-parsed story in memory | ~17 MB in V8; **Lua figure unknown** | [`01`](01-magium-analysis.md) §11; needs spike D |
| Flat serialized story | 8.16 MB (`JSON.stringify`) | measured |
| Parse cost | 54 files, regex per line, done once at load | spike B/D to time on-device |
| Save blob | full variable snapshot per slot — size TBD (hundreds of `v_*` keys) | [`01`](01-magium-analysis.md) §8 |
| Save write frequency | potentially every choice (autosave) + manual slots | [`01`](01-magium-analysis.md) §7–8 |
| Scenes resident at once | 1 active; history stack for back-navigation | design choice |

## 3. Budget table *(3.3)* — preliminary

| Demand | vs. budget | Verdict | Mitigation if 🟡/🔴 |
|---|---|---|---|
| 7.5 MB story text on storage | 13+ GB free | 🟢 | — |
| Load & keep whole parsed story (~10–30 MB?) in ~512 MB RAM shared with KOReader | unknown headroom | 🟡 | spike D; else parse lazily per chapter, or preprocess to a lean indexed format loaded on demand |
| One-shot parse of 54 files at launch (blocking) | single-threaded UI | 🟡 | parse in chunks with yields; or ship a pre-parsed artifact so launch just deserializes |
| Frequent small save writes to storage | flash, cooperative IO | 🟡 | debounce autosave; write compact form; use `LuaSettings`/`Persist` |
| Per-interaction e-ink redraw of a page of prose | full/partial refresh | 🟡 | partial refresh for choice→text; full refresh occasionally to clear ghosting — validate in spike A |
| CPU for condition evaluation per scene | dual-core 1 GHz, few dozen atoms/scene | 🟢 | trivial |

## 4. Runtime parsing vs. build-time preprocessing *(3.4)*
_Decision + rationale; feeds [`06-approach-comparison.md`](06-approach-comparison.md)._

## Findings

_(none yet)_
