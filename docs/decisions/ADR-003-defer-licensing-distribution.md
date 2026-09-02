# ADR-003: Defer licensing & redistribution-permission work (Phase 7 / OQ-004) until after the port is functionally complete

- **Status:** Superseded by [ADR-008](ADR-008-license-and-distribution.md)
  (2026-09-08 — the owner decided to release the port, which is precisely the
  revisit trigger this ADR names in its Consequences section; ADR-008 runs
  Phase 7 for real)
- **Date:** 2026-08-31
- **Deciders:** rishishwarmanu@gmail.com
- **Phase:** post-6, affects sequencing of 7/8
- **Related:** [ADR-008](ADR-008-license-and-distribution.md) (supersedes this);
  [`../research/07-risks-open-questions.md`](../research/07-risks-open-questions.md)
  OQ-004, OQ-005; [`../research/08-licensing.md`](../research/08-licensing.md);
  [`ADR-002-porting-approach.md`](ADR-002-porting-approach.md);
  [design doc §2, §10, §11](../superpowers/specs/2026-08-31-magium-koreader-research-design.md)

## Context

The governing design doc's phase order runs Phase 6 (approach) → Phase 7
(licensing & permissions — [`08-licensing.md`](../research/08-licensing.md),
`LICENSE`, an ADR) → Phase 8 (roadmap/effort). Phase 7's stated goal is
"know what license the port must adopt and what redistribution of code and
story text is permitted, **before any public release**"
([`08`](../research/08-licensing.md)); [`ADR-002`](ADR-002-porting-approach.md)'s
consequences section, written immediately after Phase 6, described **OQ-004**
(does the family's community-project permission extend to a further port?) as
"the standing blocker on public distribution... should be pursued in parallel
with Phase 7/8 rather than after them."

The owner has now clarified the project's actual scope: **this is a personal
hobby project, for the owner's own use on the owner's own Kindle. There is no
near-term intent to publicly distribute or redistribute anything.**
Licensing and redistribution permission only matter once distribution is
actually being considered — Phase 7's own stated goal already frames it that
way ("before any public release"). Continuing to treat OQ-004 as something to
pursue now, or gating any later phase on it, no longer matches what the
project needs.

This does not touch [ADR-002](ADR-002-porting-approach.md)'s actual decision
(candidate A as the porting approach) — that choice was made on engineering
grounds independent of distribution, and stands unchanged. It only revises
the sequencing/priority claim in that ADR's consequences section, which this
ADR supersedes on that one point.

## Options considered

### Option A — Keep Phase 7 / OQ-004 outreach as next, per the original plan
- Pros: matches the design doc's original phase order; closes the redistribution
  question early, before any implementation effort is sunk.
- Cons: spends outreach/legal-research effort now on a question that has no
  bearing on personal use — the owner would be doing the work of a public
  release for a project that isn't (yet, if ever) becoming one; the design
  doc's own §2 non-goals already treat "committing to a distribution channel"
  as out of scope for this phase.

### Option B — Drop Phase 7 / OQ-004 entirely
- Pros: no wasted effort tracking a question the project may never need.
- Cons: throws away real, already-partially-done groundwork (contacts map,
  three outreach drafts, [`05` §5–6](../research/05-prior-art.md)) for a
  question that *would* matter the moment the owner wants to share this with
  anyone; a hobby project's scope can and often does change once something
  works.

### Option C — Defer Phase 7 and OQ-004 until after the port is functionally complete, keep them tracked, not blocking anything in the meantime
- Pros: matches the owner's stated intent exactly ("the rest can be figured
  out after the project is complete"); loses nothing — the contacts map and
  drafts stay in the dossier, ready to use whenever distribution becomes
  relevant; unblocks Phase 8 (roadmap) and any later implementation phase
  from waiting on a question that doesn't affect them technically (Phase 8
  already depends only on Phase 6, per `research-plan.md`).
- Cons: `08-licensing.md` stays a stub, so the design doc's original exit
  criterion "all nine `docs/research/*` docs are `stable`" ([design doc
  §11](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#11-handoff--exit-criteria))
  is no longer literally satisfiable on the original schedule — addressed by
  a note in that doc, not by pretending the criterion still holds.

## Decision

**Option C.** Phase 7 (`08-licensing.md`, `LICENSE`, the license ADR) and
**OQ-004** are deferred until the owner is actually considering distributing
or sharing the port — not treated as blocking Phase 8, an implementation
phase, or anything else in the meantime. Both stay in the dossier as-is
(tracked, not answered) rather than being dropped.

## Rationale

The owner is the actual authority on project scope, and "personal use only,
for now" is a legitimate, common shape for a hobby project — nothing about
Phases 0–6's technical findings changes if distribution is deferred, and
nothing about implementation (once a later phase approves it) requires a
license or redistribution answer to *build* the plugin, only to *share* it.
Keeping the outreach drafts and contacts map already written
([`05` §5–6](../research/05-prior-art.md)) means deferring costs nothing —
they're ready the moment they're needed, rather than needing to be
reconstructed. Dropping the question outright (Option B) would be the wrong
call for the opposite reason Option A is: it assumes distribution definitely
won't happen, which is not what the owner said either.

## Consequences

- **Sequencing changes:** Phase 8 (roadmap/effort) is next, not Phase 7.
  `research-plan.md`'s status line and Phase 7 entry are updated to say so.
- **[ADR-002](ADR-002-porting-approach.md)'s consequences section** — the
  line recommending OQ-004 outreach "in parallel with Phase 7/8" — is
  superseded by this ADR on that one point; ADR-002's actual Decision
  (candidate A) is untouched and this does not change its Status.
- **[`07-risks-open-questions.md`](../research/07-risks-open-questions.md)**:
  OQ-004's Blocking? column changes from "yes" to "no — deferred," with this
  ADR as the reason, per the design doc's own exit-criteria language ("every
  `OQ-NNN` is either closed or explicitly deferred with a reason").
- **[`08-licensing.md`](../research/08-licensing.md)** stays a stub by intent
  — a short header note points here rather than the doc being silently
  stale. The design doc's "all nine docs stable" exit criterion is amended
  with a note referencing this ADR rather than left contradicted.
- **What would make us revisit this:** the owner deciding to share the
  finished port with anyone else (a Discord post, a GitHub release, handing
  it to another Kindle owner) — at that point Phase 7 runs for real, using
  the groundwork already in [`05`](../research/05-prior-art.md) and
  [`08`](../research/08-licensing.md).
