# SUMMARY — what we know so far

- **Status:** in-progress (Phases 0, 1 & 2 done; Phase 3 next)
- **Last updated:** 2026-08-31
- **How to read this:** every claim links to the doc that backs it, with a
  confidence tag. If a row says `low` or `TBD`, it is not yet a conclusion. This
  file is updated at the end of each research phase.

---

## Current recommendation

**None yet** — the approach comparison (Phase 6) has not run. The research plan
deliberately keeps the end-form open (standalone plugin / extend an existing
plugin / convert to a supported format) until the evidence is in.

**Early read (low→medium confidence):** the constraints picture favors a
**standalone Lua plugin that reimplements the small `magium-dev` engine and
bundles the `.magium` data** — memory is a non-issue on this device, the engine is
tiny, and Phase 2 confirms **KOReader provides every widget/API the Magium UI
needs** with a shipping plugin (`frotz.koplugin`) already demonstrating the exact
"fullscreen styled narrative + choice list on e-ink" shape. Remaining unknowns:
the e-ink *feel* of the choice→page loop (spike A / OQ-007), redistribution
permission (OQ-004), and the one 490 KB condition outlier (OQ-011). To be
confirmed or overturned in Phase 6.

## Established so far

| # | Finding | Confidence | Source |
|---|---|---|---|
| 1 | `magium-dev` is the porting base, not `magium-recrystallized`: ~650 LOC plain JS, human-readable `.magium` scripts parsed at runtime, MIT. `magium-recrystallized` is Rust/WASM with a binary `.story` TLV format, **no in-repo compiler**, built for HTTP range-streaming, AGPL, unfinished scripting — reviewed and ruled out as a base (its save-model and chunked-format ideas may help approach D). | high | [`reference/magium-recrystallized-notes.md`](reference/magium-recrystallized-notes.md), `../magium-dev/src/` |
| 2 | Full English story data is 54 `.magium` files, 7.7 MB of text, plus 3 achievements JSON files and one `ui.json`. French translation also present. | high | `../magium-dev/data/en/` |
| 3 | The engine's moving parts: line-oriented scene parser, a flat variable store (`v_*`), DNF condition evaluation, `set(...) if`, `#if(){}` conditional paragraphs, `choice(...)`, `achievement(...)`, and four `special:` hooks (`restart`, `saves`, `stats`, `checkpoint`). A handful of scene IDs are special-cased in `renderers.js`. | high | `../magium-dev/src/parser.js`, `src/utils.js`, `src/renderers.js` |
| 4 | Owner: experienced generalist programmer (JS, Python, C; light hobby 2D/puzzle game dev), **new to Lua** and the KOReader API. Lua is a quick pickup for this background; KOReader's API is the real learning curve. Can test on-device; expects community help for KOReader specifics. | high | project brief (2026-08-31) |
| 5 | **Target device: Kindle Paperwhite 12th gen (2024), 16 GB** (Amazon.in B0DKTZ6592). Confirmed on-device: FW **Kindle 5.19.5**, **956.9 MB RAM** (~497 MB available), 10.6 GB free storage, KOReader **v2026.07.1** release (`kindlehf`) idling at ~33 MB RSS. | high | [`00-overview.md`](docs/research/00-overview.md) — on-device |
| 6 | Story scale (English): **54 files, 7.5 MB, 2159 scenes, 4880 paragraphs, 3734 choices**. Fully parsed ≈ 17 MB in V8; 8.16 MB serialized. | high | measured — [`01`](docs/research/01-magium-analysis.md) §11, [`reference/magium-dev-notes.md`](reference/magium-dev-notes.md) |
| 7 | `magium-dev` runs locally as a clean **differential oracle**: `POST /` with the variable map (+ `HX-Request: true`) renders any scene. A no-deps harness (`reference/tools/oracle-diff.js`) normalizes each scene to canonical JSON and structurally diffs two captures; 6-case fixture set + committed goldens ready for the spike-B Lua port. Verified 2026-08-31 on Node 24. | high | [`reference/magium-dev-notes.md`](reference/magium-dev-notes.md) |
| 8 | **RAM is not a blocker.** Public "512 MB" figure was wrong — device has ~1 GB, ~500 MB available, KOReader only ~33 MB. A ~17–30 MB resident story fits easily. Open concern is now just launch parse time (spike B), not memory. | high (RAM); medium (parse time) | [`04-constraints-budget.md`](docs/research/04-constraints-budget.md) §3, OQ-001 |
| 9 | **The engine is ~640 LOC over 4 JS files** (`parser` 131, `utils` 219, `renderers` 194, `main_setup` 117) + EJS templates. A Lua reimplementation is small and mostly mechanical. `renderScene` runs a fixed 12-step filter pipeline (setVars→apply→choices→paragraphs→statChecks→achievements→checkpoint); there are **13 hand-coded special cases** that are parity-critical. | high | [`01-magium-analysis.md`](docs/research/01-magium-analysis.md) §0,§4,§10 |
| 10 | **`.magium` format = 5 regexes, DNF conditions, flat non-nested `#if`.** Full 54-file corpus scanned ([`scan-magium-constructs.js`](reference/tools/scan-magium-constructs.js)): navigation is via the `v_current_scene` variable (not the `target` field, which the engine never reads); `choice(""spoken"")` doubled-quote labels are common (809×); no multi-digit `set()`; `<br/>` is the only markup. Latent parser hazards (unanchored regexes, `startsWith` traps) catalogued but none triggered by current data. | high | [`02-magium-format-spec.md`](docs/research/02-magium-format-spec.md) §2–4 |
| 11 | **i18n = string-bundle swap.** en and fr `.magium` sets are structurally identical (same 54 files, scene ids, variables, conditions); only prose + labels are translated. One engine, one story-logic, N prose bundles. | high | [`01-magium-analysis.md`](docs/research/01-magium-analysis.md) §9, [`02`](docs/research/02-magium-format-spec.md) §5 |
| 12 | **One performance outlier found:** `b3ch4a.magium:251` is a single ~490 KB `choice … if (…)` condition with 2044 OR-clauses (pre-expanded "Average Joe" check). Re-evaluating it per render on the Kindle CPU is untested → OQ-011. Mitigable (cache / pre-compile). | medium | [`01`](docs/research/01-magium-analysis.md) §11, [`02`](docs/research/02-magium-format-spec.md) §4, OQ-011 |
| 13 | **KOReader gives us everything the Magium UI needs** — plugin = `WidgetContainer:extend` + `UIManager:show` for a fullscreen non-document UI; `TextBoxWidget`/`ScrollTextWidget` (C-shaped reflowed prose), `ButtonTable`/`Menu` (choice list), `KeyValuePage` (stats), `LuaSettings`/`Persist` (saves), `Notification` (achievement toast). No missing capability. `kbarni/frotz.koplugin` already ships a fullscreen "styled transcript + choice/input row on e-ink" plugin — direct prior art. | high (capability); medium (fit/feel → spike A) | [`03-koreader-platform.md`](docs/research/03-koreader-platform.md) §1,§3,§7; F-14/F-15 |
| 14 | **Platform facts:** LuaJIT **2.1.ROLLING** (`NUM 20199`, upstream `LuaJIT/LuaJIT@3c4f9fe`, not OpenResty), Lua 5.1 + FFI, patterns not regex, no `utf8` stdlib. **Single OS process / single Lua state / no threads** — blocking work (cold parse, the 490 KB condition) must be sliced via `Trapper`/`UIManager:scheduleIn`. `<br/>` is the only Magium markup → `TextBoxWidget` + `\n`. Saves fsync on write → debounce autosave. Closes the Phase 0 LuaJIT-build item. | high | [`03`](docs/research/03-koreader-platform.md) §2,§5,§6; F-16/F-17/F-19/F-20 |
| 15 | **Dev loop:** on-device = USB copy to `koreader/plugins/` + restart + read `koreader/crash.log` (all `logger` output, last 500 KB); no hot reload. The `kodev` desktop emulator is Linux/macOS-only → the owner (Windows) needs WSL2 / Docker / AppImage-extract → new **OQ-012**. | high | [`03`](docs/research/03-koreader-platform.md) §8; F-18 |

## Open questions

Tracked in [`docs/research/07-risks-open-questions.md`](docs/research/07-risks-open-questions.md)
(OQ-001 … OQ-012). Closed: OQ-010. Mostly resolved: OQ-001, OQ-008, OQ-009.
Narrowed by Phase 2: OQ-002 (widgets exist + prior art; only the "custom vs.
off-the-shelf" call remains — spike A). Still blocking the verdict: OQ-007 (e-ink
feel — spike A), OQ-004 (redistribution permission), OQ-003 (existing offline
gamebook players — but `frotz.koplugin` is a strong lead). New from Phase 1:
OQ-011 (per-render cost of the 490 KB condition outlier). New from Phase 2:
OQ-012 (Windows dev loop for the emulator).

## Decisions

See [`docs/decisions/`](docs/decisions/).

- [ADR-001](docs/decisions/ADR-001-research-dossier-layout.md) — research organized as a modular dossier (not a single report or a wiki).
