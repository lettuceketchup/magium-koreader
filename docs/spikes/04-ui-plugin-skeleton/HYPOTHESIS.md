# Spike 04 — UI plugin skeleton (widget fit)

- **Status:** blocked — code written, not run (see FINDING.md)
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.1, "Spike A")
- **Sources:** `../../../../koreader/plugins/hello.koplugin/main.lua`,
  `../../../../koreader/frontend/ui/widget/textviewer.lua`,
  `../../../../koreader/frontend/apps/reader/modules/readerbookmark.lua:1267-1296`
  (all @ `v2026.07.1`, commit `9192014`); `../../../../magium-dev/data/en/ch1.magium` @ `51f5aa9`
- **Related:** [`../../research-plan.md`](../../research-plan.md) task 5.1,
  [`OQ-002`](../research/07-risks-open-questions.md), [`OQ-007`](../research/07-risks-open-questions.md),
  [`03-koreader-platform.md` §3](../research/03-koreader-platform.md#3-ui-toolkit-inventory-23),
  [spike 03's egress-block finding](../03-full-corpus-memory-parse/FINDING.md#blocked-could-not-get-a-real-koreader-environment-number)
  (same blocker hits this spike), [`FINDING.md`](FINDING.md)

## Question

"Does the widget model fit? refresh feel? navigation?" — does an existing
KOReader widget combo give an acceptable prose + choice-list UX, and how
does the choice→new-page loop actually feel on e-ink?

## What "answered" looks like (as planned)

- Fork the simplest existing plugin pattern, hard-code one real Magium scene
  (prose + 3 choices), render it on the Paperwhite, wire the choices to
  swap to another hard-coded scene, and **judge** the result — widget fit,
  refresh feel, navigation.

## What was actually built (throwaway)

`magium_spike.koplugin/main.lua` — a `WidgetContainer`-based plugin
(modeled on `hello.koplugin`'s registration boilerplate) that hard-codes
`Ch1-Intro1` (real prose + 3 choices: Excited/Calm/Afraid) and `Ch1-Intro2`
(the 3 `#if(v_ch1_intro_feeling == N)`-gated branches), rendered via
`TextViewer` with a `buttons_table` for the choice row — the exact widget
+ parameter shape Phase 2 identified as the fit (`03-koreader-platform.md`
§3, F-14/F-15) and grounded against real usage in `readerbookmark.lua`
rather than assumed from the docstring alone.

## Why this spike is only half-answered

The "judge: widget fit / refresh feel / navigation" part of the question is
an **inherently human, on-device, e-ink perceptual call** — no amount of
source-reading or code-writing substitutes for someone tapping through it
on the actual Paperwhite. That was true before this session started, and
this spike doesn't change it. What this session *could* still have added —
a run inside the `kodev` emulator, confirming the code at least loads and
renders without crashing, functional correctness short of the feel
judgment — turned out to be blocked too (see FINDING.md), for the same
network-egress reason spike 03 hit trying to build that same emulator.

So this spike delivers a **reviewable, source-grounded design artifact**:
real widget choice, real API shapes, real story content, wired end-to-end —
but genuinely **not run**, at any level, in this session. That's a
materially weaker result than spikes 02/03/05, and it's reported as such
rather than blurred.
