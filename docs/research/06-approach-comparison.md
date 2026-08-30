# 06 — Approach comparison & recommendation

- **Status:** stub (not started)
- **Last updated:** 2026-08-31
- **Phase:** 6
- **Sources:** [`04-constraints-budget.md`](04-constraints-budget.md), [`05-prior-art.md`](05-prior-art.md), [`../spikes/`](../spikes/)
- **Related:** [`07-risks-open-questions.md`](07-risks-open-questions.md), [`../decisions/`](../decisions/), [`09-roadmap-effort.md`](09-roadmap-effort.md)

> Goal: pick an end-form, or conclude that specific further spiking is needed
> first. Result is recorded as an ADR and written into `SUMMARY.md`.

## Candidates *(6.1)*

### A — Standalone KOReader plugin (Lua engine)
_Reimplement the `magium-dev` engine in Lua; bundle `.magium` data; custom UI._

### B — Extend an existing plugin
_Add Magium support to an existing IF/gamebook/CYOA plugin (identified in [`05`](05-prior-art.md))._

### C — Convert to a supported format + existing player
_Build-time `.magium` → Twine/Ink/ChoiceScript/EPUB-CYOA; play with existing tooling._

### D — Hybrid
_Build-time conversion to a lean custom format + a small Lua runtime (if runtime parsing loses in Phase 3)._

## Decision matrix *(6.2)*

| Criterion (weight) | A | B | C | D |
|---|---|---|---|---|
| Implementation effort | | | | |
| Parity ceiling | | | | |
| On-device performance | | | | |
| Maintainability / upstream sync | | | | |
| Fit with owner skills + community | | | | |
| Distribution ease | | | | |
| Risk | | | | |
| **Total** | | | | |

## Blocking open questions *(6.3)*
_Which `OQ-NNN` must close before this decision is safe._

## Recommendation *(6.4)*
_Chosen approach + confidence + link to ADR._

## Findings

_(none yet)_
