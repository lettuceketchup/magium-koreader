# SUMMARY — what we know so far

- **Status:** in-progress (research phase)
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
| 1 | `magium-dev` is a better porting base than `magium-recrystallized`: ~650 LOC of plain JS, parses human-readable `.magium` scripts at runtime, so the engine can be reimplemented in Lua and data bundled as-is. `magium-recrystallized` compiles to a binary `.story` format via Rust/WASM. | high | [design doc §4](docs/superpowers/specs/2026-08-31-magium-koreader-research-design.md), `../magium-dev/src/` |
| 2 | Full English story data is 54 `.magium` files, 7.7 MB of text, plus 3 achievements JSON files and one `ui.json`. French translation also present. | high | `../magium-dev/data/en/` |
| 3 | The engine's moving parts: line-oriented scene parser, a flat variable store (`v_*`), DNF condition evaluation, `set(...) if`, `#if(){}` conditional paragraphs, `choice(...)`, `achievement(...)`, and four `special:` hooks (`restart`, `saves`, `stats`, `checkpoint`). A handful of scene IDs are special-cased in `renderers.js`. | high | `../magium-dev/src/parser.js`, `src/utils.js`, `src/renderers.js` |
| 4 | Target device is a Kindle Paperwhite (PW4/PW5) with KOReader already installed; owner can test plugins on-device. Owner reads code, has limited Lua, expects community help. | high | project brief (2026-08-31) |

## Open questions

Tracked in [`docs/research/07-risks-open-questions.md`](docs/research/07-risks-open-questions.md).
None resolved yet.

## Decisions

See [`docs/decisions/`](docs/decisions/).

- [ADR-001](docs/decisions/ADR-001-research-dossier-layout.md) — research organized as a modular dossier (not a single report or a wiki).
