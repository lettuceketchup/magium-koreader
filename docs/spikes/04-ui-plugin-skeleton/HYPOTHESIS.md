# Spike 04 — UI plugin skeleton (widget fit)

- **Status:** run — widget-fit confirmed under a real KOReader build; e-ink feel still needs the device (see FINDING.md)
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.1, "Spike A")
- **Sources:** `../../../../koreader/plugins/hello.koplugin/main.lua`,
  `../../../../koreader/frontend/ui/widget/textviewer.lua`,
  `../../../../koreader/frontend/apps/reader/modules/readerbookmark.lua:1267-1296`
  (all @ `v2026.07.1`, commit `9192014`); `../../../../magium-dev/data/en/ch1.magium` @ `51f5aa9`
- **Related:** [`../../research-plan.md`](../../research-plan.md) task 5.1,
  [`OQ-002`](../research/07-risks-open-questions.md), [`OQ-007`](../research/07-risks-open-questions.md),
  [`03-koreader-platform.md` §3](../research/03-koreader-platform.md#3-ui-toolkit-inventory-23),
  [`FINDING.md`](FINDING.md) (includes how the earlier "cloud session can't
  build the emulator" blocker was resolved)

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
source-reading, code-writing, or even a real emulator run on a non-e-ink
display substitutes for someone tapping through it on the actual
Paperwhite. That was true before this session started, and it's still
true after: a build was eventually gotten working in this cloud session
(see FINDING.md — the earlier "blocked" state was a fixable download-fetch
problem, not a fundamental one), and it confirmed the *functional* half —
the plugin loads, the widgets accept this data shape, both hard-coded
scenes render correctly with real prose and a real choice list, navigation
between them works — but SDL renders instantly on a desktop/Xvfb display
either way, so the *feel* half was never obtainable from this environment,
emulator or not.

So this spike now delivers two separate things: a **reviewable,
source-grounded design artifact** (real widget choice, real API shapes,
real story content, wired end-to-end) *and*, as of the later pass, a
**functional confirmation under the real KOReader v2026.07.1 runtime**
(loads, renders, no errors, screenshotted). What it still can't deliver —
by nature, not by this session's limitations — is the e-ink perceptual
judgment; that stays with the owner.
