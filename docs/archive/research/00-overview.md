# 00 — Overview

- **Status:** stable (Phase 0 complete 2026-08-31; device/problem facts unchanged through Phases 1–8)
- **Last updated:** 2026-08-31
- **Phase:** 0 (Baseline & setup)
- **Sources:** project brief (2026-08-31); [design doc](../superpowers/specs/2026-08-31-magium-koreader-research-design.md); device: Amazon.in ASIN [B0DKTZ6592](https://www.amazon.in/All-new-Amazon-Kindle-Paperwhite/dp/B0DKTZ6592); [blog.the-ebook-reader.com 12th-gen specs](https://blog.the-ebook-reader.com/2024/10/16/new-12th-gen-kindle-paperwhite-specs-and-features-summary/); [goodereader 12th-gen review](https://goodereader.com/blog/electronic-readers/amazon-kindle-paperwhite-12th-generation-e-reader-review-2024); [KOReader Kindle install wiki](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices)
- **Related:** [`../../research-plan.md`](../research-plan.md), [`../../SUMMARY.md`](../SUMMARY.md), [`01-magium-analysis.md`](01-magium-analysis.md)

## Problem statement

*(See design doc §1. Summarize here once Phase 0 confirms device facts.)*

Magium is a text-based CYOA game (prose + choice buttons + menus). It ships for
web, Android, iOS, and desktop but not e-ink readers. This project investigates
playing it on a **Kindle Paperwhite 12th gen (2024) via KOReader**, where the
interaction model is a close match for existing reader/plugin behavior.

## Goals

- Shareable, human-readable research dossier.
- Evidence-based verdict on **full feature parity** on-device (narrative +
  branching + stats/stat-checks + achievements + multi-slot saves + settings/themes,
  all three books).
- Recommended end-form among: standalone plugin / extend an existing plugin /
  format conversion.
- Effort, risk, timeline calibrated to owner context: experienced generalist
  programmer (JS, Python, C; light hobby 2D/puzzle game dev), **new to Lua and to
  the KOReader plugin/widget API**. Lua is a fast pickup here; the KOReader API
  and e-ink idioms are the real ramp. Community help expected for KOReader-specific parts.
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

*(Phase 0.1 — **confirmed on the owner's device 2026-08-31** via KOReader's
System Info, except the few rows still marked otherwise.)*

| Fact | Value | Confidence / how verified |
|---|---|---|
| Model | **Kindle Paperwhite, 12th generation (2024)**, 16 GB (non–Signature Edition) | high — Amazon.in ASIN B0DKTZ6592; device serial prefix `GN43…` |
| Community shorthand | "PW6" / "PW12" / "Paperwhite 2024" (⚠️ *not* the same as "PW5" = 11th-gen 2021) | high |
| Firmware | **Kindle 5.19.5** (build 4794310058) | high — on-device |
| RAM | **956.9 MB total** — 220.8 MB free, **497.5 MB available** at the time of reading (KOReader running) | high — KOReader System Info, on-device. *(Public reviews claiming "512 MB" were wrong.)* |
| Storage | **11.6 GB user partition, 10.6 GB free** (16 GB nominal; rest is system/reserved) | high — on-device |
| SoC | MediaTek, dual-core @ 1 GHz | medium — goodereader review |
| Display | 7″ E Ink, 300 ppi, 16-level greyscale, adjustable warm light | medium — confirm exact ppi in Phase 2 |
| Battery | 1900 mAh | medium |
| Connectivity | Wi-Fi, USB-C; no cellular, no Bluetooth audio on this SKU | medium |
| KOReader version | **v2026.07.1**, official **release** build (not nightly) | high — on-device |
| KOReader package | **`koreader-kindlehf`** (the build for FW ≥ 5.16.3; 5.19.5 qualifies) | high — KOReader wiki; matches FW |
| KOReader process footprint (idle) | **~32.7 MB RSS**, 64.6 MB virtual | high — on-device, no book open |
| Lua / LuaJIT | KOReader ships LuaJIT (arm) — assumed for `kindlehf`; confirm exact in Phase 2 | medium |
| Jailbreak | present and working (owner installed it); 5.19.5 is a very recent FW, so the JB path is current as of mid-2026 | high — owner |

**Headroom summary:** with KOReader at ~33 MB and ~500 MB "available", a plugin
holding the whole parsed story (~17–30 MB, [`01-magium-analysis.md`](01-magium-analysis.md) §11)
has comfortable room. This is the single biggest de-risking fact so far — see
[`04-constraints-budget.md`](04-constraints-budget.md) and OQ-001.

**Note (risk):** KOReader has had launch-crash reports on the 12th-gen for some
FW/build combos ([OQ-009](07-risks-open-questions.md)). This device runs a
**release** build on **5.19.5** and the owner reports it working — confirm it
stays stable under a memory-heavier plugin during spikes.

**Privacy:** the full device serial is intentionally **not** recorded here (this
dossier is meant to be shared publicly). Only the `GN43` model-identifying prefix
is kept.

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
| **ADR** | Architecture Decision Record — [`../decisions/`](../../decisions/). |
| **OQ-NNN** | Open question, tracked in [`07-risks-open-questions.md`](07-risks-open-questions.md). |
