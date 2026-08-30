# 00 — Overview

- **Status:** draft
- **Last updated:** 2026-08-31
- **Phase:** 0 (Baseline & setup)
- **Sources:** project brief (2026-08-31); [design doc](../superpowers/specs/2026-08-31-magium-koreader-research-design.md)
- **Related:** [`../../research-plan.md`](../../research-plan.md), [`../../SUMMARY.md`](../../SUMMARY.md), [`01-magium-analysis.md`](01-magium-analysis.md)

## Problem statement

*(See design doc §1. Summarize here once Phase 0 confirms device facts.)*

Magium is a text-based CYOA game (prose + choice buttons + menus). It ships for
web, Android, iOS, and desktop but not e-ink readers. This project investigates
playing it on a **Kindle Paperwhite (PW4/PW5) via KOReader**, where the
interaction model is a close match for existing reader/plugin behavior.

## Goals

- Shareable, human-readable research dossier.
- Evidence-based verdict on **full feature parity** on-device (narrative +
  branching + stats/stat-checks + achievements + multi-slot saves + settings/themes,
  all three books).
- Recommended end-form among: standalone plugin / extend an existing plugin /
  format conversion.
- Effort, risk, timeline calibrated to owner context (reads code, limited Lua,
  community help expected).
- Clean handoff: open questions tagged by venue; implementation roadmap.

## Non-goals

- Production plugin code (deferred to a later approved phase).
- Modifying or continuing the story.
- Non-Kindle targets as a primary concern.
- Choosing a distribution channel (researched only).

## Success criteria

The research phase succeeds when the [design doc §11](../superpowers/specs/2026-08-31-magium-koreader-research-design.md)
exit criteria are met: all research docs `stable`, `SUMMARY.md` states a
recommendation with confidence, every `OQ-NNN` closed or deferred, roadmap written.

## Target environment facts

*(Phase 0.1 — fill in from the actual device.)*

| Fact | Value | How verified |
|---|---|---|
| Kindle model / generation | TBD | |
| Firmware version | TBD | |
| KOReader version | TBD | |
| KOReader release channel | TBD | |
| Lua / LuaJIT build | TBD | |
| Free RAM at rest | TBD | |
| Free storage | TBD | |

## "Full parity" checklist

See [design doc §3](../superpowers/specs/2026-08-31-magium-koreader-research-design.md#3-target-definition-full-parity)
for the capability table and its `magium-dev` references. Detailed behavior is
documented in [`01-magium-analysis.md`](01-magium-analysis.md).

## Glossary

| Term | Meaning |
|---|---|
| **CYOA** | Choose-your-own-adventure: branching narrative driven by reader choices. |
| **`.magium` file** | Line-oriented script file holding one or more scenes. See [`02-magium-format-spec.md`](02-magium-format-spec.md). |
| **Scene** | A unit of the story with an `ID`, prose paragraphs, and choices. Identified by a string like `Ch1-Intro1` or `B3-Ch04a-Introduction2`. |
| **Scene ID** | Unique string key for a scene; also encodes book/chapter for the header. |
| **Variable store** | Flat map of `v_*` variables (numbers/strings, default 0) holding all game state. |
| **DNF condition** | "Disjunctive normal form": an OR of ANDs, e.g. `(v_a > 1 && v_b == 2) || v_c > 0`. How Magium conditions are structured. |
| **Stat / stat variable** | One of 14 character attributes (`v_strength`, `v_perception`, ...) shown in the stats panel. |
| **Stat-check** | A condition on a stat variable that the UI surfaces to the player (pass/fail) when a scene's outcome depends on it. |
| **Achievement** | An unlockable flagged by a `v_ac_*` variable; grouped per book/chapter. |
| **`special:` hook** | A keyword inside `choice(...)` — `restart`, `saves`, `stats`, `checkpoint` — triggering UI behavior instead of (or besides) a scene jump. |
| **Checkpoint** | A save point the game offers automatically at certain choices (`v_checkpoint_rich`). |
| **Differential oracle** | The running `magium-dev` build, used to check a port produces identical output for identical inputs. |
| **Spike** | A small throwaway experiment to answer one risky question. Lives in [`../spikes/`](../spikes/). |
| **KOReader** | Open-source document reader for e-ink devices; supports Lua plugins. |
| **Plugin** | A Lua module under `koreader/plugins/<name>.koplugin/` extending KOReader. |
| **LuaSettings / DocSettings** | KOReader's key-value persistence helpers. |
| **e-ink refresh** | Redrawing the electrophoretic display; full refresh is slow but clean, partial is fast but can ghost. |
| **ADR** | Architecture Decision Record — [`../decisions/`](../decisions/). |
| **OQ-NNN** | Open question, tracked in [`07-risks-open-questions.md`](07-risks-open-questions.md). |
