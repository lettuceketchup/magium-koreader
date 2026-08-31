# 04 — Constraints budget (go / no-go)

- **Status:** stable (Phase 3 pass complete 2026-08-31; go/no-go verdict
  reached — no 🔴, six 🟡 all with named mitigations. Spikes A/B/D ran in
  Phase 5: memory (row 2) and normal-case parse/condition-eval cost are now
  real LuaJIT measurements, not just the V8 estimate — but on **desktop
  x86**, not the Kindle's ARM core. Real on-device parse time, LuaJIT
  GC-pause behavior, and `"ui"`-refresh latency (rows 3, 6, 7) remain
  genuinely unmeasured and are carried forward as
  [`09-roadmap-effort.md`](09-roadmap-effort.md)'s Milestone 0 gate and
  Phase VIII polish work, not a research-phase gap)
- **Last updated:** 2026-08-31 (Phase 3: demands quantified, budget table rebuilt
  with mitigations, save-blob footprint measured, go/no-go verdict added)
- **Phase:** 3
- **Sources:** [`00-overview.md`](00-overview.md) (on-device facts),
  [`03-koreader-platform.md`](03-koreader-platform.md) (platform limits, Phase 2),
  [`01-magium-analysis.md`](01-magium-analysis.md) §8, §11 (save model, footprint),
  [`02-magium-format-spec.md`](02-magium-format-spec.md) §3–4 (construct corpus,
  parser hazards), `../../reference/tools/measure-story-size.js`,
  `../../reference/tools/scan-save-footprint.js`, `../../reference/magium-dev-notes.md`
- **Related:** [`06-approach-comparison.md`](06-approach-comparison.md),
  [`07-risks-open-questions.md`](07-risks-open-questions.md) OQ-001, OQ-007, OQ-011;
  Phase 5 spikes A (e-ink feel), B (engine + parse timing), D (Lua memory + GC)

> Goal: a hard table matching each of Magium's demands against the Paperwhite's
> limits under KOReader, with a mitigation for every yellow/red. This is the
> feasibility crux — the output is the go/no-go call in §5.

---

## 1. Device & platform hard limits *(3.1)*

Rows tagged **on-device** were read from the owner's Paperwhite 12th gen (2024)
2026-08-31 (KOReader v2026.07.1 release, FW 5.19.5) — see
[`00-overview.md` §"Target environment facts"](00-overview.md#target-environment-facts).
Rows tagged **Phase 2** come from the pinned KOReader source
([`03`](03-koreader-platform.md)).

| Limit | Value | Confidence | Source / note |
|---|---|---|---|
| Total RAM | **956.9 MB** | high | on-device; **not** the "512 MB" some reviews claimed |
| RAM available (KOReader idle) | **497.5 MB** available / 220.8 MB free | high | on-device snapshot; "available" = free + reclaimable cache |
| KOReader RSS (idle) | ~32.7 MB | high | on-device; a plugin's story data adds on top |
| CPU | MediaTek dual-core @ 1 GHz (`isMTK`) | medium | first multi-core Paperwhite; ARM, no per-core turbo data |
| Storage | 11.6 GB partition / **10.6 GB free** | high | bundling 7.5 MB of story text is trivial |
| Concurrency | **1 OS process, 1 Lua state, cooperative scheduling — no threads** | high | [`03` §2](03-koreader-platform.md#2-lua-environment-22); any work >~1 frame blocks input + redraw unless sliced via `UIManager:scheduleIn`/`nextTick` or run under `Trapper` (coroutine) |
| Lua VM | **LuaJIT 2.1.ROLLING** (`LUAJIT_VERSION_NUM 20199`, upstream `LuaJIT/LuaJIT@3c4f9fe`, **not** OpenResty); Lua 5.1 + FFI; no `utf8` stdlib; patterns not regex; all numbers are doubles | high | `koreader-base` @ `6e4bc81`, [`03` §2](03-koreader-platform.md#2-lua-environment-22) |
| Lua GC | LuaJIT incremental collector; pause behaviour while holding ~20–30 MB of tables is **unmeasured** | medium | [`03` §2](03-koreader-platform.md#2-lua-environment-22) — **spike D** (OQ-001) |
| E-ink refresh — mechanics | types `full` / `partial` / `ui` / `fast` / `a2` (+ flash variants); `partial` auto-promotes to a flash every `FULL_REFRESH_COUNT` = 6; MTK "fast mode" **force-enabled** on `KindlePaperWhite6` so `"ui"` swaps stay quick; `canHWDither = no` (irrelevant for pure text) | high | [`03` §6](03-koreader-platform.md#6-e-ink-specifics-26) |
| E-ink refresh — latency | `full` ≈ 400–600 ms (flashing); `"ui"` partial well under; **not measured on this panel** | low | [`03` §6](03-koreader-platform.md#6-e-ink-specifics-26) — **spike A** (OQ-007) |
| Storage write cost | `LuaSettings:flush()` / `Persist:save()` both **fsync** the file (+ dir on create) | high | [`03` §4](03-koreader-platform.md#4-persistence-24) — debounce autosave; risk is write *frequency* on flash, not size |
| Battery | 1900 mAh; no measurement of plugin drain | low | [`00`](00-overview.md); a text app on e-ink with Wi-Fi off draws ≈ ordinary reading — not a plausible blocker, revisit only if a spike shows an unexpected wakelock or refresh-storm |

**Nothing in this list is a hard ceiling for Magium.** The two genuinely
open numbers — measured `"ui"` refresh latency and LuaJIT GC pauses under a
20–30 MB resident heap — are *responsiveness* questions answered by spikes A and
D, not gates on feasibility.

## 2. Magium's demands *(3.2)*

| Demand | Value | Confidence | Source |
|---|---|---|---|
| Text on disk (en) | **7.50 MB / 54 files** (French is a separate equal set) | high | `measure-story-size.js`, `../../reference/magium-dev-notes.md` |
| Scenes / paragraphs / choices | 2159 / 4880 / 3734 | high | measured — [`01` §11](01-magium-analysis.md#11-parsed-story-size--memory-footprint-task-112) |
| Fully-parsed story, resident | ~17.4 MB V8 heap; **Lua figure unknown** (est. 10–30 MB with table overhead) | medium | [`01` §11](01-magium-analysis.md#11-parsed-story-size--memory-footprint-task-112) — spike D |
| Flat serialized story | 8.16 MB (`JSON.stringify`) | high | measured |
| Cold parse cost | one regex-heavy pass over 54 files. **Desktop anchor: ~95–130 ms** (Node 24, warm & cold, x86). On a 1 GHz MTK ARM core under LuaJIT-interpreted pattern matching, expect **~1–4 s** (10–30× desktop, order-of-magnitude only) | low | `measure-story-size.js` timing 2026-08-31; on-device number is **spike B** |
| Condition-eval cost, typical | tens of atoms per scene, `var op int` compares | high | [`01` §11](01-magium-analysis.md#11-parsed-story-size--memory-footprint-task-112) — trivial on any CPU |
| Condition-eval cost, **outlier** | `b3ch4a.magium:251` — one **~490 KB** `choice … if (…)` line, **2044 OR-clauses** (pre-expanded "Average Joe" DNF); sibling Average-Joe scenes similar | medium | [`02` §4 R7](02-magium-format-spec.md#4-parser-risk-list), [`01` §11](01-magium-analysis.md#11-parsed-story-size--memory-footprint-task-112) — **OQ-011**, spike B |
| Save-blob size (100% progressed) | **491 distinct writable vars** (135 `v_ac_*` flags); a full `{name:"value"}` snapshot ≈ **12–15 KB uncompressed**, low single-digit KB with any codec. `v_current_scene` is the only long value (~30-char scene ids); everything else is 1 digit or `+N`/`-N` | medium | `scan-save-footprint.js` @ magium-dev `51f5aa9`; [`01` §8](01-magium-analysis.md#8-saves--settings-task-18) |
| Save-write frequency | continuous autosave = potentially **one write per choice**, plus explicit `checkpoint` + up to 50 manual slots | high | [`01` §7–8](01-magium-analysis.md#7-special-hooks-task-17) |
| Scenes resident at once | 1 active + a small back-navigation history stack | design choice | — |

## 3. Budget table *(3.3)*

Each demand vs. the budget → 🟢 fits with margin · 🟡 fits but needs care · 🔴 blocker.
**Every 🟡 has a named mitigation and a spike that closes it.**

| # | Demand | vs. budget | Verdict | Mitigation / how it closes |
|---|---|---|---|---|
| 1 | 7.5 MB story text bundled on storage | 10.6 GB free | 🟢 | — |
| 2 | Whole parsed story resident (~10–30 MB Lua) | ~500 MB available; KOReader itself ~33 MB | 🟢 | Even a 3× blow-up over the V8 figure leaves >450 MB headroom. Lazy parsing becomes an optimisation, not a requirement. **Spike D** confirms the Lua number. |
| 3 | Cold parse of 54 files at launch (blocking) | single cooperative Lua state | 🟡 | If **spike B** shows a cold parse >~1 s: (a) slice it across ticks with `scheduleIn`/`Trapper` behind a progress bar, (b) parse lazily per chapter on first visit + cache the parsed chapter to disk (`Persist`), or (c) ship a build-time pre-parsed artifact (§4). A responsiveness problem, never a memory one. |
| 4 | Re-evaluating the 490 KB / 2044-clause condition per visit | 1 GHz ARM, no thread to offload to | 🟡 | **OQ-011 / spike B.** Mitigations, cheapest first: memoise the parsed DNF for that scene id; or special-case the Average-Joe check as a direct stat comparison; or fold it into a build-time pre-compile pass (which may be worth doing for this one line regardless). Mitigable — not a gate. |
| 5 | Autosave write on (potentially) every choice | fsync'd writes on Kindle flash | 🟡 | Debounce: write on a timer, on `onFlushSettings`, on suspend/close, and on explicit checkpoints — not per choice. Keep manual slots explicit. Blob is ~12–15 KB so each write is cheap; only frequency matters. (F-20.) |
| 6 | E-ink redraw for the "tap choice → new page of prose" loop | `full` flashes (~400–600 ms est.); `"ui"` partial no-flash | 🟡 | **OQ-007 / spike A.** Strategy from [`03` §6](03-koreader-platform.md#6-e-ink-specifics-26): `"ui"` for scene→scene and scrolling, periodic `"full"` to de-ghost, `"flashui"` on modal open/close — the split `frotz.koplugin` already ships. Feel is a device judgment, not a doc one. |
| 7 | LuaJIT GC pauses while holding the resident story | incremental collector, cooperative loop | 🟡 | **OQ-001 tail / spike D.** If pauses are visible: shrink the heap by lazy per-chapter loading (row 3b), tune `collectgarbage("setstepmul")`, or drop parsed chapters not recently visited. |
| 8 | Save-blob size (~12–15 KB, ~500 vars) | KB-scale `LuaSettings`/`Persist` | 🟢 | Trivial. One `LuaSettings` file for config + achievements + a save index; `Persist` (`zstd`/`luajit` codec) blob per slot. (F-20.) |
| 9 | Per-scene condition/stat evaluation (typical) | dual-core 1 GHz | 🟢 | Tens of integer compares. Trivial. |
| 10 | Concurrency: all long work on one cooperative loop | no threads | 🟡 (architectural) | Not a resource limit — a design constraint. Every potentially-long operation (cold parse, the row-4 condition, a big save) must yield. `scheduleIn` / `nextTick` / `Trapper` are the tools ([`03` §2](03-koreader-platform.md#2-lua-environment-22)). Carried into the Phase 8 effort premium for KOReader-facing work. |

**No 🔴.** Six 🟡s, every one a responsiveness/hygiene item with a concrete
mitigation and a spike that settles it. The 🟢s (memory, storage, save size, CPU
for normal evaluation) are the ones that used to be feared and are now decisively
clear — chiefly because the device has ~1 GB RAM, not 512 MB
([`00`](00-overview.md), session-3 correction).

## 4. Runtime parsing vs. build-time preprocessing *(3.4)*

**Preliminary decision (confidence: medium — pending spike B/D; feeds
[`06`](06-approach-comparison.md), not yet an ADR):**

- **Memory does not force the choice** — the fully-parsed story fits resident with
  a >15× margin. Parse-everything-at-launch is on the table purely on
  responsiveness grounds.
- **Launch/first-render responsiveness is the deciding factor.** Options, cheapest
  build effort first:
  1. **Parse all 54 files at launch, hold resident.** Simplest; a faithful 1:1 of
     `magium-dev`. Viable if spike B's cold parse is under ~1 s (or is
     acceptably chunked behind a one-time progress bar).
  2. **Parse lazily per chapter on first visit; cache each parsed chapter to disk**
     (`Persist`, `luajit`/`zstd` codec). First-ever launch pays a small parse;
     every launch after reads the cache. Bounded working set also eases row 7 (GC).
  3. **Build-time preprocess** `.magium` → a lean serialised/indexed artifact
     bundled with the plugin; launch just deserialises. Borrows the chunked layout
     from `magium-recrystallized`
     ([`../../reference/magium-recrystallized-notes.md`](../../reference/magium-recrystallized-notes.md)).
     Adds a build step and a second format to maintain.
- **Lean:** (1) if spike B is fast, else (2). Reserve (3) for the case where both
  stall. **Independent of that**, the single 490 KB condition line (row 4 / OQ-011)
  may justify a *targeted* build-time pre-compile of just that construct regardless
  of which option wins — decide in spike B.

## 5. Go / no-go verdict

**GO for continued research — feasibility is not resource-bound.**

Phase 3 finds **no hard blocker** to running full-parity Magium on the owner's
Paperwhite 12th gen under KOReader:

- **Memory, storage, save size, and normal-case CPU are 🟢 with large margins.**
  The parsed story (~10–30 MB) against ~500 MB available is the single biggest
  de-risking fact.
- **Every 🟡 is a responsiveness or I/O-hygiene item with a known mitigation**
  (chunk the parse, memoise/precompile the one pathological condition, debounce
  autosave, use `"ui"` refresh + periodic `"full"`, tune/limit the resident heap).
- The remaining unknowns — cold-parse time (spike B), `"ui"` refresh feel
  (spike A / OQ-007), GC pauses under load (spike D) — are **measurements that
  tune the design, not tests that could fail the project.** Their worst realistic
  outcome pushes the parse strategy from option §4.1 toward §4.2/§4.3, which are
  already scoped.
- Nothing here threatens **full parity** (narrative + conditions + stats/checks +
  achievements + multi-slot saves + i18n). The engine is ~640 LOC
  ([`01` §0](01-magium-analysis.md)), the widgets all exist
  ([`03` §3](03-koreader-platform.md#3-ui-toolkit-inventory-23)).

This is a **conditional green light**: proceed to Phases 4–6; run spikes A, B, D
to convert the 🟡s to 🟢s and to settle the §4 parse decision before the Phase 6
approach recommendation and its ADR.

## Findings

- **F-22 (confidence: high):** No resource on the target device is a hard ceiling
  for full-parity Magium. RAM (~500 MB avail vs. ~10–30 MB story), storage
  (10.6 GB vs. 7.5 MB), save size (~12–15 KB), and normal-case CPU all clear with
  large margin. The feasibility question is *responsiveness*, not *capacity*.
- **F-23 (confidence: medium):** A 100%-progressed save is **≈ 12–15 KB
  uncompressed** — 491 writable variables (135 achievement flags), all values 1
  digit / `+N` / `-N` except `v_current_scene`. Fits `LuaSettings`/`Persist`
  trivially; the only save concern is autosave *write frequency* on flash, fixed
  by debouncing. Method: `../../reference/tools/scan-save-footprint.js`.
- **F-24 (confidence: low):** Cold parse of the 54 files is **~95–130 ms on
  desktop** (Node 24, x86); a 1 GHz MTK ARM core under LuaJIT-interpreted patterns
  plausibly lands at **~1–4 s**. That is the one number that could push the port
  from "parse everything at launch" to lazy-per-chapter or a build-time
  pre-parse — measure it directly in spike B before choosing (§4).
- **F-25 (confidence: high):** The port's hardest platform constraint is the
  **single cooperative Lua state** — cold parse, the 490 KB condition (OQ-011),
  and large saves must all yield (`scheduleIn` / `nextTick` / `Trapper`). This is
  a design rule and an effort-estimate premium for KOReader-facing work
  ([Phase 8](../../research-plan.md#phase-8--roadmap-effort-timeline)), not a
  feasibility risk.
