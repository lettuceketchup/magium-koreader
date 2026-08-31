# 08 — Licensing & permissions

- **Status:** stub (deferred — see note below)
- **Last updated:** 2026-08-31
- **Phase:** 7 (deferred)
- **Sources:** `../magium-dev/LICENSE` (MIT), `../magium-recrystallized/LICENSE` (AGPL-3.0), https://github.com/raduprv/Magium, https://github.com/koreader/koreader/blob/master/COPYING, Magium Discord
- **Related:** [`../decisions/`](../decisions/) (license ADR), [`07-risks-open-questions.md`](07-risks-open-questions.md) OQ-004, OQ-005, [`../decisions/ADR-003-defer-licensing-distribution.md`](../decisions/ADR-003-defer-licensing-distribution.md)

> **Deferred (2026-08-31, [ADR-003](../decisions/ADR-003-defer-licensing-distribution.md)):**
> project scope confirmed as personal use on the owner's own device only, no
> near-term distribution plan. This doc stays a stub — not filled in — until
> distribution is actually being considered; not dropped, just not run yet.
> The groundwork below (sources, related OQs) is left in place for then.

> Goal: know what license the port must adopt and what redistribution of code and
> story text is permitted, before any public release.

## 1. Upstream code licenses *(7.1)*
| Project | License | If we derive from it... |
|---|---|---|
| `magium-dev` | MIT | permissive; attribution only |
| `magium-recrystallized` | AGPL-3.0 | copyleft, network clause |
| `raduprv/Magium` (original) | TBD — read repo | |
| KOReader | AGPL-3.0 | plugins: clarify obligations |

## 2. Story-text permission chain *(7.2)*
_The family's permission to the community projects; whether it covers a further port; who to confirm with (OQ-004)._

## 3. KOReader's license and plugin implications *(7.3)*

## 4. Distribution channel implications *(7.4)*
| Channel | License/hosting requirements |
|---|---|
| KOReader plugin index | |
| kindlemodshelf | |
| GitHub releases | |

## 5. Recommendation *(7.5)*
_Chosen license for this repo + rationale → ADR + `LICENSE` file._

## Findings

_(none yet)_
