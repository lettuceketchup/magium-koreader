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

Roll every finding into [`../../SUMMARY.md`](../../SUMMARY.md) and close the
related [`OQ-NNN`](../research/07-risks-open-questions.md).

## Planned spikes (see [`../../research-plan.md`](../../research-plan.md) Phase 5)

| Spike | Question | OQ |
|---|---|---|
| A — UI feel | Does a KOReader widget combo give acceptable prose + choice-list UX on-device? | OQ-002, OQ-007 |
| B — engine in Lua | Can the condition evaluator + parser be reproduced in Lua, matching the oracle? | OQ-008 |
| C — format conversion | Can one chapter convert to Twee/Ink with conditions/stats intact? | OQ-006 |
| D — memory | Does the full parsed story fit in a plugin's RAM budget on a PW4? | OQ-001 |

## Index

_(none run yet)_
