# 04 — Constraints budget (go / no-go)

- **Status:** stub (not started)
- **Last updated:** 2026-08-31
- **Phase:** 3
- **Sources:** [`03-koreader-platform.md`](03-koreader-platform.md), [`01-magium-analysis.md`](01-magium-analysis.md) §11, on-device measurement, spike D
- **Related:** [`06-approach-comparison.md`](06-approach-comparison.md)

> Goal: a hard table matching each of Magium's demands against the Paperwhite's
> limits under KOReader, with a mitigation for every yellow/red. This is the
> feasibility crux.

## 1. Device hard limits *(3.1)*
| Limit | PW4 | PW5 | Notes |
|---|---|---|---|
| Usable RAM for a plugin | TBD | TBD | |
| CPU class | TBD | TBD | |
| Storage | TBD | TBD | |
| Threads | none (cooperative) | | |
| E-ink refresh latency | TBD | TBD | |
| Lua memory ceiling / GC | TBD | TBD | |

## 2. Magium demands *(3.2)*
| Demand | Value | Source |
|---|---|---|
| Text on disk (en) | 7.7 MB / 54 files | `../magium-dev/data/en/` |
| Parsed-story memory | TBD | [`01`](01-magium-analysis.md) §11 / spike D |
| Parse cost (regex-heavy) | TBD | spike B/D |
| Save blob size | TBD | [`01`](01-magium-analysis.md) §8 |
| Save write frequency | every choice? | [`01`](01-magium-analysis.md) §8 |
| Scenes resident at once | TBD | |

## 3. Budget table *(3.3)*
| Demand | vs. budget | Verdict | Mitigation |
|---|---|---|---|
| _TBD_ | | 🟢/🟡/🔴 | |

## 4. Runtime parsing vs. build-time preprocessing *(3.4)*
_Decision + rationale; feeds [`06-approach-comparison.md`](06-approach-comparison.md)._

## Findings

_(none yet)_
