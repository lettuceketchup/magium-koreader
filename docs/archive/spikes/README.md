# Spikes

Small **throwaway** experiments that answer one risky question each. Spike code is
never promoted to production — an implementation phase must be separately approved
(see [design doc §1](../superpowers/specs/2026-08-31-magium-koreader-research-design.md)).

## Layout

One folder per spike: `NN-slug/`

```
NN-slug/
  HYPOTHESIS.md   the question, what "answered" looks like, what will be built
  ...             throwaway code / data
  FINDING.md      result, verdict (confirmed / refuted / inconclusive), confidence, next step
```

Roll every finding into [`../../SUMMARY.md`](../SUMMARY.md) and close the
related [`OQ-NNN`](../research/07-risks-open-questions.md).

## Planned spikes (see [`../../research-plan.md`](../research-plan.md) Phase 5)

| Spike | Question | OQ |
|---|---|---|
| A — UI feel | Does a KOReader widget combo give acceptable prose + choice-list UX on-device? | OQ-002, OQ-007 |
| B — engine in Lua | Can the condition evaluator + parser be reproduced in Lua, matching the oracle? | OQ-008 |
| C — format conversion | Can one chapter convert to Twee/Ink with conditions/stats intact? | OQ-006 |
| D — memory | Lua-side RAM cost of the full parsed story + cold-parse time at launch (memory fit already confirmed — device has ~1 GB) | OQ-001 |

## Index

Run 2026-08-31 (session 11, extended in session 12 once this session's
KOReader-emulator build blocker was resolved — see
[`04-ui-plugin-skeleton/FINDING.md`](04-ui-plugin-skeleton/FINDING.md)).
Folder numbering reflects build order, not the A/B/C/D letters above — see
each `HYPOTHESIS.md` for which planned spike it answers.

| Folder | Answers | Verdict | Confidence |
|---|---|---|---|
| [`02-engine-in-lua/`](02-engine-in-lua/) | Spike B | **confirmed** — 6/6 oracle-diff match + full 54-file structural parity, re-confirmed under koreader-base's own bundled LuaJIT | high |
| [`03-full-corpus-memory-parse/`](03-full-corpus-memory-parse/) | Spike D | **confirmed (partial)** — memory ~11.5 MB (both stock and koreader-base-bundled LuaJIT); parse-time (112–205 ms desktop x86) and the true on-device ARM number still need real hardware | medium (memory) / low (on-device parse time, unchanged) |
| [`05-magium-to-ink/`](05-magium-to-ink/) | Spike C | **confirmed for fidelity, with named gaps** — conditions/stats/set() convert to Ink losslessly; achievements/`special:` hooks/cross-chapter nav don't (expected, documented) | medium-high |
| [`04-ui-plugin-skeleton/`](04-ui-plugin-skeleton/) | Spike A | **confirmed (functional half)** — a working `kodev` emulator build was obtained in this session (see FINDING.md for how the earlier network blocker was resolved); the plugin loads and both hard-coded scenes render correctly with real prose + a real choice list, no errors, screenshotted. The perceptual e-ink-feel half of OQ-002/OQ-007 is unaffected — that always needed the real device or the owner's WSL2 build, emulator or not | high (widget fit, functional) / n/a (e-ink feel, still owner-only) |

Spike E (task 5.5) was not run: no Phase 3 🟡/🔴 came out of these four
spikes needing a dedicated follow-up measurement beyond what they already
covered.
