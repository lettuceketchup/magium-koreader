# ADR-001: Research organized as a modular dossier

- **Status:** Accepted
- **Date:** 2026-08-31
- **Deciders:** rishishwarmanu@gmail.com
- **Phase:** research-phase setup
- **Related:** [design doc §6](../archive/superpowers/specs/2026-08-31-magium-koreader-research-design.md), [`../../research-plan.md`](../archive/research-plan.md)

## Context

The near-term output of this project is a feasibility/design study, not code. The
owner intends to share it — often in pieces — with people on Discord, Reddit, and
MobileRead to get help with platform-specific questions. The study needs to be
navigable later by both humans and AI agents, with decisions and evidence
traceable.

## Options considered

### Option A — Single living report
One large feasibility document that grows section by section, plus a task list.
- Pros: everything in one place; easy to read top-to-bottom once.
- Cons: can't hand a helper just the relevant slice; large files are harder to
  review carefully and harder for an AI agent to hold in context; merge-unfriendly.

### Option B — Modular research dossier
Separate numbered topic docs under `docs/research/`, one `research-plan.md`
checklist, a `SUMMARY.md` aggregator, ADRs for decisions, an `OQ-NNN` register.
- Pros: each doc is independently shareable and reviewable; small focused files;
  clear separation of findings / plan / decisions / open questions; scales to
  multiple contributors.
- Cons: more files to keep cross-linked; needs discipline (the §8 conventions).

### Option C — GitHub wiki + issues
Use the repo wiki for content and issues for tracking.
- Pros: community-familiar; issues are good for open questions.
- Cons: content lives outside the repo (weaker offline, not versioned with code,
  harder for an agent to work with); heavier setup. Issues can still be layered
  on later without moving content.

## Decision

**Option B — modular research dossier**, with the traceability conventions in
design doc §8 (standard doc headers, inline citations with archive links,
confidence tags, ADRs, `OQ-NNN` register, relative cross-links, running log).

## Rationale

The deciding factor is shareability in pieces plus reviewability: the owner will
repeatedly need to send one topic doc to one community and ask a pointed
question. B also keeps files small enough for careful review and for an AI agent
to work within. C's out-of-repo storage is a poor fit for agent-driven work and
offline use.

## Consequences

- Contributors must follow the §8 conventions; `CLAUDE.md` restates them for agents.
- `SUMMARY.md` must be kept current or it becomes misleading — updated at the end
  of each phase.
- GitHub issues may still be adopted later purely for task tracking; if so, a
  follow-up ADR records how issues and `research-plan.md` stay in sync.
