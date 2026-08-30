# 04 — Constraints budget (go / no-go)

- **Status:** draft (device limits confirmed on-device 2026-08-31; spikes B/D pending)
- **Last updated:** 2026-08-31
- **Phase:** 3
- **Sources:** [`00-overview.md`](00-overview.md), [`03-koreader-platform.md`](03-koreader-platform.md), [`01-magium-analysis.md`](01-magium-analysis.md) §11, `../../reference/magium-dev-notes.md`, on-device measurement (pending), spike D (pending)
- **Related:** [`06-approach-comparison.md`](06-approach-comparison.md), [`07-risks-open-questions.md`](07-risks-open-questions.md) OQ-001

> Goal: a hard table matching each of Magium's demands against the Paperwhite's
> limits under KOReader, with a mitigation for every yellow/red. This is the
> feasibility crux.

## 1. Device hard limits *(3.1)* — Kindle Paperwhite 12th gen (2024)

Confirmed on the owner's device 2026-08-31 (KOReader v2026.07.1 release, FW 5.19.5) —
see [`00-overview.md`](00-overview.md).

| Limit | Value | Confidence | Notes |
|---|---|---|---|
| Total RAM | **956.9 MB** | high | on-device; **not** the "512 MB" some reviews claimed |
| RAM available (KOReader running, idle) | **497.5 MB** available / 220.8 MB free | high | on-device snapshot; "available" = free + reclaimable cache |
| KOReader RSS (idle) | ~32.7 MB | high | on-device; a plugin's story data adds on top of this |
| CPU | MediaTek dual-core @ 1 GHz | medium | first multi-core Paperwhite |
| Storage | 11.6 GB partition / 10.6 GB free | high | bundling 7.5 MB of story text is trivial |
| Threads | none — KOReader is single-process cooperative Lua | high | long parse/convert work blocks the UI unless chunked/yielded |
| E-ink refresh | full ≈ 400–600 ms est., partial faster; A2 for fast updates | low | confirm feel in spike A |
| Lua VM | LuaJIT (arm), `koreader-kindlehf` build | medium | confirm exact version Phase 2 |
| Lua GC | incremental; watch for pauses when holding ~20–30 MB of tables | medium | measure in spike D |

## 2. Magium demands *(3.2)*

| Demand | Value | Source |
|---|---|---|
| Text on disk (en) | 7.50 MB / 54 files | measured, `../../reference/magium-dev-notes.md` |
| Scenes / paragraphs / choices | 2159 / 4880 / 3734 | measured |
| Fully-parsed story in memory | ~17 MB in V8; **Lua figure unknown** | [`01`](01-magium-analysis.md) §11; needs spike D |
| Flat serialized story | 8.16 MB (`JSON.stringify`) | measured |
| Parse cost | 54 files, regex per line, done once at load | spike B/D to time on-device |
| Condition-eval cost | ~tens of atoms/scene typically; **one outlier** at `b3ch4a.magium:251` — a ~490 KB condition, 2044 OR-clauses | [`01` §11](01-magium-analysis.md#11-parsed-story-size--memory-footprint-task-112), [`02` §4 R7](02-magium-format-spec.md#4-parser-risk-list), OQ-011 |
| Save blob | full variable snapshot per slot — size TBD (hundreds of `v_*` keys) | [`01`](01-magium-analysis.md) §8 |
| Save write frequency | potentially every choice (autosave) + manual slots | [`01`](01-magium-analysis.md) §7–8 |
| Scenes resident at once | 1 active; history stack for back-navigation | design choice |

## 3. Budget table *(3.3)* — updated with real device RAM

| Demand | vs. budget | Verdict | Notes / mitigation |
|---|---|---|---|
| 7.5 MB story text on storage | 10.6 GB free | 🟢 | — |
| Load & keep whole parsed story (~17–30 MB est.) resident | ~500 MB available; KOReader itself only ~33 MB | 🟢 *(pending spike D to confirm Lua-side figure)* | Even a 3× blow-up vs. the V8 number fits. Lazy/per-chapter parsing becomes an optimization, not a requirement. |
| One-shot parse of 54 files at launch (blocking) | single-threaded UI | 🟡 | Time it in spike B. If a cold parse is >1–2 s, chunk it with yields or ship a pre-parsed artifact. Not a memory problem, a responsiveness one. |
| Frequent small save writes to storage | flash, cooperative IO | 🟡 | Debounce autosave; compact form; `LuaSettings`/`Persist`. |
| Per-interaction e-ink redraw of a page of prose | full/partial refresh | 🟡 | Partial refresh for choice→text; periodic full refresh to clear ghosting — validate feel in spike A. |
| CPU for condition evaluation per scene | dual-core 1 GHz, tens of atoms/scene | 🟢 | Trivial. |

**Bottom line:** with ~1 GB RAM (not 512 MB), the memory objection to a
"parse-and-hold everything" plugin (approach A) largely falls away. The remaining
yellows are UI-responsiveness and I/O hygiene, not hard blockers. Spike D still
runs to get the real Lua-side number, but it's now a confirmation rather than a
gate.

## 4. Runtime parsing vs. build-time preprocessing *(3.4)*

Preliminary (confidence: medium, pending spike B/D):

- **Memory** no longer forces a choice — both fit.
- **Launch responsiveness** is the deciding factor. Options, cheapest first:
  1. Parse all 54 files at launch, hold resident. Simplest; viable if cold parse < ~1–2 s.
  2. Parse lazily per chapter on first visit, cache parsed chapters.
  3. Build-time preprocess `.magium` → a lean serialized/indexed artifact bundled
     with the plugin; launch just deserializes (or mmaps an index). Borrows the
     chunked layout idea from `magium-recrystallized`
     ([`../../reference/magium-recrystallized-notes.md`](../../reference/magium-recrystallized-notes.md)).
- Recommendation leans (1) or (2) for a faithful port; (3) only if timing demands it.

Feeds [`06-approach-comparison.md`](06-approach-comparison.md).

## Findings

_(none yet)_
