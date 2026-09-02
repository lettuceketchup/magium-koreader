---
name: verify
description: >-
  Run the right test gates for a magium.koplugin change before calling it done,
  before asking the owner to test on device, or before merging a phase. Use
  whenever you have edited anything under magium.koplugin/ (engine/, ui/, save/,
  main.lua) and need to know which of busted / oracle-corpus / test-ui / emu-smoke
  to run and what "green" means — and whenever a test or an oracle diff fails and
  you need the triage path. Use this instead of guessing the command set or
  re-deriving the change-to-suite mapping from memory or the running log.
---

# Verify a change

A change to `magium.koplugin/` is not done until the gates for what it touched
are green **and** any suite that asserted the old behavior has been updated to
match the new one. The owner's device pass (the `device` skill) is the *final*
check — never the first.

All commands run from the repo root through WSL:

    wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh <cmd>'

## Which gates for which change

| You touched | Run | Why |
|---|---|---|
| anything | `test` (full busted suite) | always — cheap, catches the obvious |
| `engine/` — parser, conditions, store, stats, locale, specials, scene, story | `oracle-corpus` **and** `test` | per-scene render parity vs the magium-dev oracle. ~15 min. The only proof a render-path change stays faithful. |
| `ui/` | `test-ui` + `emu-smoke` + a real `paintTo` check (below) | real KOReader widget stack, headless; `emu-smoke` proves the plugin still loads |
| `save/` | `test` (save specs + the flow round-trip) | |
| `main.lua` / glue | `test` + `emu-smoke` | |

Skip `oracle-corpus` **only** when the change cannot reach a render: a pure
`save/` or `ui/` change, or an `engine/` function `scene.render` never calls.
If unsure, run it. Record in the running log which gates you ran and why any
were skipped.

## What green looks like

- **busted** — `N successes / 0 failures / 0 errors`. The success count only
  goes up; a change that adds behavior adds cases.
- **oracle-corpus** — matches the baseline in the newest `research-plan.md`
  running-log entry (currently `8887/8887`, 0 DIFF vs magium-dev @ its recorded
  commit). A new DIFF is a stop — triage below.
- **test-ui** — every `spec/ui/*_smoke.lua` exits 0.
- **emu-smoke** — no `error` / `traceback` lines in the run log, `crash.log`
  empty.

## ui/ changes: paint every reachable state

A smoke test that only builds the `item_table` and asserts its structure is not
enough. KOReader widgets lay out lazily at paint time — a too-long string in
`MenuItem.mandatory` (an unwrapped single-line `TextWidget`) passed every
structural assert and still crashed on the real device (Phase V, 2026-09-04,
`textwidget.lua:224: bad argument #2 to 'makeLine'`).

For **every** screen/state realistic user data can reach — not one sampled
case; that bug was data-length-dependent — call
`widget:paintTo(Screen.bb, 0, 0)` inside a `pcall` and assert it does not
error. Pattern: `koreader/spec/unit/widget_progresswidget_spec.lua`.

**What the paint check still cannot see:** `spec/ui/*_smoke.lua` require
`commonrequire`, whose `einkfb.dummy = true` hardcodes `Screen` to 600×800 and
ignores `EMULATE_READER_W/H`. So `paintTo` proves "does not crash", never
"looks right at the real PW12 1272×1696". Actual layout is confirmed on-device
(the `device` skill) or with a one-off non-dummy Xvfb screenshot — until
Phase V.5 item 7 ships a reusable `mgm.sh` command for it.

## Regression suites stay current

Every suite that exists is run and updated by every change, not only the one
that added it. A change that alters behavior without updating the test that
asserted the old behavior is incomplete — the same way a `ui/` change without
an emulator check is incomplete. Today that's `test`, `oracle-corpus`,
`test-ui`; Phase V.5 adds an app-level E2E harness and others, and this rule
extends to them once they land.

## When a gate fails

Use `superpowers:systematic-debugging` — root cause before any fix.

**A new `oracle-corpus` DIFF** is one of three things, most likely first:

1. **A real engine regression** — the render path changed behavior. Fix the
   engine, not the test.
2. **A known deferred special case** — check the Phase II special-case audit
   list in `docs/research/09-roadmap-effort.md` and the `oracle-corpus` notes
   before assuming a bug.
3. **A blind spot in `reference/tools/oracle-diff.js`'s HTML normalizer** —
   rare (two were found and fixed on the first full sweep). Only conclude this
   after ruling out 1 and 2, and show the exact normalization at fault.
