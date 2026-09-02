---
name: phase
description: >-
  Run a full magium-koreader implementation phase from start to finish — pick the
  phase, brainstorm, write the spec, branch, implement, verify, get the owner's
  device sign-off, merge, and update the running log. Use whenever starting or
  continuing a numbered phase (II–VIII, V.5), when the owner says "let's do
  Phase N" / "next phase" / "start the settings phase", or when you need the
  merge-and-log ritual at the end of one. Orchestrates the `verify` and `device`
  skills at the right points.
---

# Run an implementation phase

The backbone loop. Each step has a home in the repo; this skill is the order
and the hand-offs.

## 1. Pick the phase, check it's unblocked

The newest entry in `docs/archive/research-plan.md`'s running log = current status. Scope
for the phase = `docs/archive/research/09-roadmap-effort.md`. Confirm nothing blocks
it — e.g. Phase VI+ is blocked until Phase V.5 lands.

## 2. Brainstorm → spec

`superpowers:brainstorming` first. Then write
`docs/specs/YYYY-MM-DD-phase-<x>-<slug>.md`, copying the shape of the last one
(`docs/specs/2026-09-04-phase-v-achievements.md`): standard header block
(Status / Last updated / Phase / Sources / Related), §-numbered, explicit
**deliverables**, numbered **decisions** (D1…Dn), **exit criteria** as a
checklist. Add the row to `docs/specs/README.md`.

The spec is the authority — if a plan step later conflicts with it, the spec wins.

## 3. Plan (only if large)

`superpowers:writing-plans` for a multi-file phase. Execute **inline in the
main session** — per CLAUDE.md, no subagents for large tasks unless the owner
asks.

## 4. Branch

`feat/phase-<x>-<slug>`. Never commit to `main` unasked.

## 5. Implement

Use `ponytail`. `engine/` stays pure Lua, oracle-tested against magium-dev.
`ui/` is emulator-first — a new or changed screen adds/extends a
`spec/ui/*_smoke.lua` (real `paintTo` per reachable state) or `spec/flow/*` as
part of the same change, not later.

Any decision that closes an alternative → a new ADR:
`docs/decisions/ADR-NNN-slug.md` (next N, copy `ADR-000-template.md`, add the
index row in `docs/decisions/README.md`). Superseding = a new ADR linking back;
the old one's status → `Superseded by ADR-MMM`.

## 6. Verify

The **`verify`** skill — run the gates for what changed; green before moving on.

## 7. Owner device sign-off

The **`device`** skill — deploy, and hand the owner the spec's exit-criteria
checklist. Each round that comes back with something: re-verify, redeploy. The
device pass is the final confirmation of e-ink feel and real input, never the
first check the code works.

## 8. Merge

On sign-off:

- spec Status → `stable`, then note the merge commit once it exists
- `git merge --no-ff` into `main`
- re-run the gates on the merged tree — green before anything leaves the machine
- delete the `feat/` branch (local, and remote if it was pushed)
- **A push to `origin` is stop-and-ask** unless the owner said to push

## 9. Running log + memory

Append a dated entry to the bottom of `docs/archive/research-plan.md` (newest-first within
the "Running log" section): what shipped, the gates and their numbers, the
decisions/ADRs, what's next. Keep doc updates cheap (CLAUDE.md): the log plus
only the one or two docs that would otherwise be *wrong*, batched and terse.

If a durable fact changed — phase status, a new standing rule — update
`MEMORY.md` and its memory files.

## 10. Commit messages

What changed + which phase/task + why. Reference `ADR-NNN` when relevant.
