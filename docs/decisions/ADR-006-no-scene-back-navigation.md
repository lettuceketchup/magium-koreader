# ADR-006: No in-game "back one scene" / history stack

- **Status:** Accepted
- **Date:** 2026-09-01
- **Deciders:** owner (Q&A 2026-09-01), Claude
- **Phase:** Implementation — Phase II ([spec](../specs/2026-09-01-phase-ii-full-corpus-and-navigation.md))
- **Related:** [`../research/09-roadmap-effort.md` Phase II](../research/09-roadmap-effort.md#phase-ii--full-story--navigation) (the deliverable this closes), [ADR-004](ADR-004-plugin-internal-architecture.md) (reader widget), [`../research/01-magium-analysis.md` §4](../research/01-magium-analysis.md#4-scene-effect-ordering-in-renderscene-task-14)

## Context

The Phase 8 roadmap listed a "back/history stack" as a Phase II deliverable, and
the Phase I spec §12 row II carried it forward as "reader (history stack)". No
prior artefact established *why* — it was an assumed nicety of porting a CYOA to
an e-reader.

Two facts force a decision now that Phase II is being specced:

- **`magium-dev` has no back navigation.** Verified across the whole reference:
  no `history`, `back`, `goBack`, `previous`, or `window.history` use in `src/`,
  `templates/`, or `public/scripts/`. Navigation is purely forward — every choice
  writes `v_current_scene` and the next render reads it
  ([`01` §4](../research/01-magium-analysis.md#4-scene-effect-ordering-in-renderscene-task-14),
  [`01` F-13](../research/01-magium-analysis.md#findings)). The only "back"
  buttons in the reference return from sub-screens (menu → game, settings → menu).
- **Choices have side effects.** A choice applies `set_vars` to the store, and
  the entered scene's own surviving `set()` effects are persisted too
  ([Phase II spec §4](../specs/2026-09-01-phase-ii-full-corpus-and-navigation.md#4-scene-set-write-back-enginecommitlua)).
  A correct "back" must therefore either restore a full pre-choice store snapshot
  or accept re-applied / double-applied effects — real design work, not a free
  breadcrumb.

The owner's instruction when asked: **"use whatever the current `magium-dev` is
doing."**

## Options considered

### Option A — No back navigation (match `magium-dev`)
- Pros: exact parity with the oracle (the project's core thesis, constraint C1);
  zero new state; no snapshot-semantics design; smallest Phase II. Closing the
  reader (header tap / multiswipe → FileManager) is unchanged and still there as
  the "get out" affordance.
- Cons: a misclick on a choice is unrecoverable within a session (though the
  in-game menu's New Game and, later, Phase III save slots mitigate).

### Option B — Scene-id breadcrumb, re-render against current store
- Pros: cheap to implement (a list of visited ids).
- Cons: not parity; re-picking a choice from a "back" page double-applies its
  `set_vars`; confusing semantics (prose rewinds, variables don't).

### Option C — Full snapshot-stack undo
- Pros: clean, correct undo.
- Cons: not parity; new bounded-depth snapshot stack in the reader or store;
  interacts with autosave, resume, and the Phase II `set()` write-back; a
  meaningful slice of Phase II's budget for a feature the reference does not have
  and the owner did not ask for.

## Decision

**Option A.** Phase II ships no in-game "back one scene" and no history stack.
The reader remains forward-only on `v_current_scene`; the existing
close-to-FileManager affordance is the only backward motion.

## Rationale

Parity with `magium-dev` is the explicit standard for behaviour questions in
this port, and the owner applied it directly here. Options B and C both diverge
from the reference *and* cost real design effort in Phase II — the opposite of
what a "match the oracle" instruction asks for. The recovery paths a reader
actually needs (start over, load a save) are already planned: New Game in the
Phase II in-game menu, and save slots in Phase III.

## Consequences

- **Easier:** Phase II drops a deliverable; the reader keeps its Phase I shape;
  no snapshot/resume/autosave interaction to reason about.
- **The roadmap and the Phase I spec §12 are now partially wrong** — both list a
  history stack for Phase II. The Phase II spec notes the override; the roadmap
  Phase II section and Phase I spec §12 row II get a one-line "cut, see ADR-006".
- **Revisit if:** the owner later wants an undo despite the parity cost, or a
  distribution audience expects it — that would be a new ADR superseding this
  one, with Option C's snapshot design worked out against the then-current save
  model.
