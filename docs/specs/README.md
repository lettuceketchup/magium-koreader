# Implementation specs

Design specs for the actual port (one per subsystem or per plan), produced by a
new brainstorming/spec cycle after
[`../research/09-roadmap-effort.md`](../research/09-roadmap-effort.md) handed off.

Running a phase (spec → implement → verify → device sign-off → merge → log) is
the **`phase`** skill.

| Spec | Status | Covers |
|---|---|---|
| [2026-08-31-plugin-architecture-and-phase-i.md](2026-08-31-plugin-architecture-and-phase-i.md) | Phase I complete (signed off 2026-09-01) | The permanent three-layer module architecture; **Milestone 0** (on-device parse-timing gate) and **Phase I** (MVP) in build-ready detail; phases II–VIII as architectural notes. |
| [2026-09-01-phase-ii-full-corpus-and-navigation.md](2026-09-01-phase-ii-full-corpus-and-navigation.md) | draft — awaiting owner review | **Phase II**: scene `set()` write-back, special case #8 (full-corpus parity → 8887/8887), the in-game menu (D2 shell), `special:` hook wiring, back-nav cut ([ADR-006](../decisions/ADR-006-no-scene-back-navigation.md)). |
| [2026-09-02-phase-iii-saves.md](2026-09-02-phase-iii-saves.md) | stable — merged 2026-09-02 | **Phase III**: 50 manual save slots (`save/manager` slotstore API, one `Persist` blob per slot), [ADR-007](../decisions/ADR-007-saves-scope.md). |
| [2026-09-03-phase-iv-stats.md](2026-09-03-phase-iv-stats.md) | stable — merged 2026-09-03 | **Phase IV**: `ui/statspage.lua` stat-allocation screen (batched Confirm/Cancel, `?` tutorial), 3 stats-screen special-case gates, "Full immersion" unlock. |
| [2026-09-04-phase-v-achievements.md](2026-09-04-phase-v-achievements.md) | stable — merged 2026-09-04 (`2ec0dad`) | **Phase V**: achievement unlock toast, 3-level browsable menu, `"1"→"2"` seen-latch, owner-requested reset-all. |
| [2026-09-04-phase-v5-test-hardening.md](2026-09-04-phase-v5-test-hardening.md) | stable — items 1/2/4/7 merged 2026-09-05; 3/5/6 deferred | **Phase V.5**: app-level E2E harness (`spec/ui/main_e2e_smoke.lua`), achievements content-integrity check, save-schema fixture, real-1272×1696 smoke bootstrap (`test-ui-real`). |
| [phase-i-execution-notes.md](phase-i-execution-notes.md) | archival | The 13 controller rulings from Phase I's SDD execution + the ledger self-review, preserved before the git-ignored ledger is deleted. |

Decisions recorded from these specs are ADRs in
[`../decisions/`](../decisions/) — see
[ADR-004](../decisions/ADR-004-plugin-internal-architecture.md).

The research-phase design doc lives at
[`../superpowers/specs/2026-08-31-magium-koreader-research-design.md`](../superpowers/specs/2026-08-31-magium-koreader-research-design.md).
