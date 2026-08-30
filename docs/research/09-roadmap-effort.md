# 09 — Implementation roadmap, effort & timeline

- **Status:** stub (not started)
- **Last updated:** 2026-08-31
- **Phase:** 8
- **Sources:** [`06-approach-comparison.md`](06-approach-comparison.md) (chosen approach), [`04-constraints-budget.md`](04-constraints-budget.md), [`03-koreader-platform.md`](03-koreader-platform.md)
- **Related:** [design doc §11](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#11-handoff--exit-criteria)

> Goal: a credible phased roadmap for the chosen approach with effort bands and a
> timeline, plus the handoff to the implementation-design phase. Not a
> commitment — an estimate with stated assumptions.

## Assumptions
- Owner: reads code, limited Lua, ~N hours/week (fill in).
- Community help expected for Lua-heavy and KOReader-specific parts.
- Approach: _(from [`06`](06-approach-comparison.md))_.

## Roadmap *(8.1 / 8.2)*
| Phase | Deliverable | Depends on | Effort band | Notes |
|---|---|---|---|---|
| I | Render one scene + follow choices + evaluate conditions on-device | research done | | MVP / proof |
| II | Full story loads; navigation across all chapters; back/history | I | | |
| III | Save / load (multi-slot, name + date); checkpoints | II | | |
| IV | Stats + stat-check display | II | | |
| V | Achievements | III | | |
| VI | Settings / themes | II | | |
| VII | Localization (en + fr) | II | | |
| VIII | Polish, packaging, distribution | all | | |

## Critical path & parallelism *(8.3)*

## Timeline sketch *(8.4)*
_Under the stated weekly-hours assumption._

## Handoff checklist *(8.5)*
- [ ] All `docs/research/*` are `stable`
- [ ] Every `OQ-NNN` closed or explicitly deferred with reason
- [ ] `SUMMARY.md` recommendation recorded with confidence
- [ ] Approach ADR written
- [ ] This roadmap reviewed by owner
- [ ] New brainstorming cycle opened for implementation design *(8.6)*

## Findings

_(none yet)_
