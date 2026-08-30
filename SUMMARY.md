# SUMMARY — what we know so far

- **Status:** in-progress (research phase — Phase 0 underway)
- **Last updated:** 2026-08-31
- **How to read this:** every claim links to the doc that backs it, with a
  confidence tag. If a row says `low` or `TBD`, it is not yet a conclusion. This
  file is updated at the end of each research phase.

---

## Current recommendation

**None yet** — the approach comparison (Phase 6) has not run. The research plan
deliberately keeps the end-form open (standalone plugin / extend an existing
plugin / convert to a supported format) until the evidence is in.

## Established so far

| # | Finding | Confidence | Source |
|---|---|---|---|
| 1 | `magium-dev` is the porting base, not `magium-recrystallized`: ~650 LOC plain JS, human-readable `.magium` scripts parsed at runtime, MIT. `magium-recrystallized` is Rust/WASM with a binary `.story` TLV format, **no in-repo compiler**, built for HTTP range-streaming, AGPL, unfinished scripting — reviewed and ruled out as a base (its save-model and chunked-format ideas may help approach D). | high | [`reference/magium-recrystallized-notes.md`](reference/magium-recrystallized-notes.md), `../magium-dev/src/` |
| 2 | Full English story data is 54 `.magium` files, 7.7 MB of text, plus 3 achievements JSON files and one `ui.json`. French translation also present. | high | `../magium-dev/data/en/` |
| 3 | The engine's moving parts: line-oriented scene parser, a flat variable store (`v_*`), DNF condition evaluation, `set(...) if`, `#if(){}` conditional paragraphs, `choice(...)`, `achievement(...)`, and four `special:` hooks (`restart`, `saves`, `stats`, `checkpoint`). A handful of scene IDs are special-cased in `renderers.js`. | high | `../magium-dev/src/parser.js`, `src/utils.js`, `src/renderers.js` |
| 4 | Owner reads code, has limited Lua, expects community help; can test on-device. | high | project brief (2026-08-31) |
| 5 | **Target device: Kindle Paperwhite 12th gen (2024), 16 GB** (Amazon.in B0DKTZ6592). MediaTek dual-core 1 GHz, **~512 MB RAM**, 16 GB storage, 7″/300 ppi e-ink. Needs the **`koreader-kindlehf`** build (FW ≥ 5.16.3). | medium | [`00-overview.md`](docs/research/00-overview.md), public specs + KOReader wiki |
| 6 | Story scale (English): **54 files, 7.5 MB, 2159 scenes, 4880 paragraphs, 3734 choices**. Fully parsed ≈ 17 MB in V8; 8.16 MB serialized. | high | measured — [`01`](docs/research/01-magium-analysis.md) §11, [`reference/magium-dev-notes.md`](reference/magium-dev-notes.md) |
| 7 | `magium-dev` runs locally as a clean **differential oracle**: `POST /` with the variable map (+ `HX-Request: true`) renders any scene. Verified 2026-08-31 on Node 24. | high | [`reference/magium-dev-notes.md`](reference/magium-dev-notes.md) |
| 8 | RAM headroom is **the** open feasibility question: ~10–30 MB resident story vs. 512 MB shared with KOReader. Not obviously fatal, not obviously safe — needs on-device spike D. | medium | [`04-constraints-budget.md`](docs/research/04-constraints-budget.md) §3, OQ-001 |

## Open questions

Tracked in [`docs/research/07-risks-open-questions.md`](docs/research/07-risks-open-questions.md)
(OQ-001 … OQ-010). None resolved yet. Most blocking: OQ-001 (RAM headroom),
OQ-002/OQ-007 (UI feasibility), OQ-009 (KOReader stability on this device),
OQ-004 (redistribution permission).

## Decisions

See [`docs/decisions/`](docs/decisions/).

- [ADR-001](docs/decisions/ADR-001-research-dossier-layout.md) — research organized as a modular dossier (not a single report or a wiki).
