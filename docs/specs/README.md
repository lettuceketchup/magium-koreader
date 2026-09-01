# Implementation specs

Design specs for the actual port (one per subsystem or per plan), produced by a
new brainstorming/spec cycle after
[`../research/09-roadmap-effort.md`](../research/09-roadmap-effort.md) handed off.

| Spec | Status | Covers |
|---|---|---|
| [2026-08-31-plugin-architecture-and-phase-i.md](2026-08-31-plugin-architecture-and-phase-i.md) | Phase I complete (signed off 2026-09-01) | The permanent three-layer module architecture; **Milestone 0** (on-device parse-timing gate) and **Phase I** (MVP) in build-ready detail; phases II–VIII as architectural notes. |
| [2026-09-01-phase-ii-full-corpus-and-navigation.md](2026-09-01-phase-ii-full-corpus-and-navigation.md) | draft — awaiting owner review | **Phase II**: scene `set()` write-back, special case #8 (full-corpus parity → 8887/8887), the in-game menu (D2 shell), `special:` hook wiring, back-nav cut ([ADR-006](../decisions/ADR-006-no-scene-back-navigation.md)). |
| [phase-i-execution-notes.md](phase-i-execution-notes.md) | archival | The 13 controller rulings from Phase I's SDD execution + the ledger self-review, preserved before the git-ignored ledger is deleted. |

Decisions recorded from these specs are ADRs in
[`../decisions/`](../decisions/) — see
[ADR-004](../decisions/ADR-004-plugin-internal-architecture.md).

The research-phase design doc lives at
[`../superpowers/specs/2026-08-31-magium-koreader-research-design.md`](../superpowers/specs/2026-08-31-magium-koreader-research-design.md).
