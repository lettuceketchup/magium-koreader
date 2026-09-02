# Spec: Phase VIII — Polish, on-device tuning & packaging (final phase)

- **Status:** draft — awaiting owner review
- **Last updated:** 2026-09-08
- **Phase:** Implementation — design cycle 8 (roadmap
  [Phase VIII](../research/09-roadmap-effort.md#phase-viii--polish-on-device-tuning--packaging))
- **Sources:**
  - [`../research/09-roadmap-effort.md`](../research/09-roadmap-effort.md)
    Phase VIII (deliverables), §3 (critical path)
  - [`../research/07-risks-open-questions.md`](../research/07-risks-open-questions.md)
    OQ-007, OQ-011, OQ-013
  - [`../research/04-constraints-budget.md`](../research/04-constraints-budget.md)
    §3 rows 3/4/7 (parse time, condition outlier, GC), §6 (e-ink refresh split)
  - [`../spikes/06-ondevice-parse-timing/FINDING.md`](../spikes/06-ondevice-parse-timing/FINDING.md)
    (device is ~5.6× the x86 emulator on CPU-bound Lua)
  - `../../../magium-dev/data/en/b3ch4a.magium:251` (the 2044-clause condition)
- **Related:** [`../../research-plan.md`](../../research-plan.md),
  [`2026-08-31-plugin-architecture-and-phase-i.md`](2026-08-31-plugin-architecture-and-phase-i.md)
  §8.3 (refresh policy scoped to `ui/refresh.lua`), §12 Phase VIII

> **This phase is measurement-driven.** Three of the roadmap's five Phase VIII
> deliverables (condition-outlier mitigation, GC tuning, the e-ink policy
> itself) are explicitly *conditional* — "only if profiling on-device shows X".
> One instrumented device pass gathers every number at once; then we implement
> **only** what the numbers justify. The expected outcome for OQ-011 and GC is
> **no code** (see §3). Phase VIII is the project's last phase — on sign-off the
> port is declared feature-complete.

---

## 1. Scope

### 1.1 In scope

1. **OQ-011 dev bench** — `spec/engine/condition_perf_spec.lua` (new): a loose
   regression tripwire around rendering the 2044-clause-condition scene, same
   shape as the existing parse tripwire in `story_eager_spec.lua`. The one
   always-written piece of code in this phase.
2. **One device measurement pass** — deploy current `main`, action trace on,
   owner plays Book 1 → Book 3. Pull `trace-*.jsonl` + `crash.log`. No code
   change to measure (see §2).
3. **E-ink tuning (OQ-007)** — edits confined to `magium.koplugin/ui/refresh.lua`
   constants, plus wiring `refresh.on_modal()` into `ui/statspage.lua` /
   `ui/savespage.lua` (they hardcode `"ui"`). Tuned to the owner's perceptual
   sign-off over as many redeploy rounds as it takes.
4. **Conditional mitigations** — OQ-011 atom-match memo and/or GC knob, *only
   if* the measurement pass shows a real stall / stutter (§3).
5. **Full-corpus QA** — run `mgm.sh oracle-corpus`, confirm the baseline holds;
   the device playthrough is the `crash.log` bug bash.
6. **Packaging** — `INSTALL.md` at repo root; `v1.0` annotated tag on merge.
7. **Close-out** — OQ-007 / OQ-011 / OQ-013 → `closed`; roadmap, `SUMMARY.md`,
   running log, memory updated; project declared feature-complete.

### 1.2 Out of scope

- **Distribution packaging** — KOReader plugin index, KindleModShelf, GitHub
  releases. Out of scope while Phase 7 stays deferred
  ([ADR-003](../decisions/ADR-003-defer-licensing-distribution.md)). Personal
  install only.
- **A release-zip build script.** `tools/kindle-ssh-deploy.ps1` already strips
  `spec/` + dotfiles and deploys. A zip builder is duplicate machinery — add it
  only if distribution is ever reopened.
- **Live rotation / window resize re-pagination** (Phase I spec §8.2, deferred
  here). Still deferred — no owner demand, and the reader re-paginates on every
  open anyway. Documented as a known limitation in `INSTALL.md`, not built.
- **Build-time condition pre-compile** (roadmap Phase VIII, mitigation #3 for
  OQ-011). Only if the memo (#1, already the architecture) and a targeted
  special-case (#2) both prove insufficient — not expected; would be its own
  ADR.
- **The lazy per-chapter parse strategy** (deferred out of Phase I by spike 06).
  Stays deferred — the once-per-session ~2.2 s parse behind a progress bar is
  accepted; nothing in this phase revisits it.

## 2. Why measurement needs no new code

- **The action trace already timestamps every event in monotonic ms.**
  `main.lua:165` configures `trace` with
  `clock = function() return time.to_ms(time.now()) end` (CLOCK_MONOTONIC_COARSE,
  ms resolution).
- **`main.lua:363` already emits a `render` event per scene**, right after the
  `scene.render` call (`main.lua:356`) that carries all condition evaluation.
- So the device OQ-011 number is the `t` delta between the `choice` event and
  the following `render` event in the pulled `trace-*.jsonl`, at
  `B3-Ch04a-Stats-spent`. A normal scene hop is ~1 ms; a 2044-clause DNF walk
  that stalls would show as a visible spike. No timing line to add, no special
  build to deploy for measurement — current `main` already carries it.
- e-ink feel and GC stutter are **perceptual** — the owner's report is the
  measurement, no instrumentation possible or needed.

## 3. OQ-011: what's already mitigated, what the bench decides

`engine/parser.lua` calls `M.parse_conditions(cond)` at **parse time**; the DNF
table is stored on the scene, and `engine/conditions.lua:eval(dnf, view)` walks
that pre-built table at render time. **Mitigation #1 from the roadmap ("memoise
the parsed DNF for that scene id") is therefore already the architecture** — the
490 KB string is split into 2044 AND-groups exactly once, during the ~2.2 s cold
preload that spike 06 already measured and the owner already accepted.

The residual cost is walking the 2044-group DNF on each visit to
`B3-Ch04a-Stats-spent`: up to 2044 `eval_atom` calls, each doing one
`string.match`. The bench (§4) measures this on x86; ×5.6 estimates the device.

| Bench result (x86, per render) | Device estimate | Action |
|---|---|---|
| < ~50 ms | < ~280 ms | **No code.** OQ-011 closes as "already mitigated by parse-time DNF caching; residual eval cost acceptable." |
| ~50–200 ms | ~0.3–1.1 s | Add a module-level `atom → {name,op,num}` memo in `engine/conditions.lua` (atoms are immutable strings; the `string.match` per atom is the hot cost). Re-bench. |
| still slow after the memo | | Special-case `B3-Ch04a-Stats-spent` as a direct `v_*` comparison in `engine/specials.lua`. → **ADR** (closes the build-time-precompile alternative). Not expected. |

The device `choice`→`render` delta from §2 confirms or overrides the estimate.

GC: resident heap after preload is ~11.5 MB (spike 03). A stutter is not
expected. If the owner reports one during the long session:
`collectgarbage("setstepmul", …)` at plugin init, or `collectgarbage("step")` on
page-turn in `ui/reader.lua:_turn`. Only if visible. → running log, not an ADR.

## 4. The dev bench — `spec/engine/condition_perf_spec.lua`

Pure `busted`, no oracle, no KOReader. Mirrors `story_eager_spec.lua`'s
tripwire:

```lua
-- preload the corpus once (setup)
-- find the scene whose choice carries the pathological condition:
--   the B3-Ch04a-Stats-spent scene (sceneId from b3ch4a.magium)
-- time N (e.g. 50) iterations of scene.render(st, view, locale)
-- assert mean per-render < BUDGET_MS  (start at 50 ms x86; comment the
--   ×5.6 device projection and spike 06 as the basis, like the parse spec)
```

Loose on purpose — it catches an accidental O(n²) blow-up in condition eval,
not a 2× drift. If it ever legitimately climbs, re-measure on device before
bumping the number (same note as the parse tripwire).

Also assert the sanity check that makes the bench meaningful: the scene's
chosen `choice` really does carry a DNF with >1000 AND-groups (so a future
data change that drops the outlier makes the bench fail loudly rather than
silently measure nothing).

## 5. E-ink policy — `ui/refresh.lua` + two call sites

Current policy (`ui/refresh.lua`, 14 lines):

| Moment | Type | Notes |
|---|---|---|
| `on_open` | `full` | first paint of the reader |
| `on_page_turn` | `ui` | no flash |
| `on_new_scene` | `ui`, `full` every 6th (`DEGHOST_EVERY`) | choice commit |
| `on_modal` | `flashui` | **defined, not wired** |

Changes, applied per the owner's report from §2:

- **Wire `on_modal`.** `ui/statspage.lua:115` and `ui/savespage.lua:46` pass a
  literal `"ui"` to `UIManager:setDirty`. Replace with `refresh.on_modal()` so
  the one file owns the policy. (Safe to do unconditionally — it is exactly
  what the module was built for; 2 one-line edits.)
- **`on_page_turn` / `on_new_scene` type**, `DEGHOST_EVERY` value — tuned to the
  owner's judgment of ghosting build-up vs. flash annoyance. Candidates:
  `"ui"` → `"fast"` or `"a2"` for page turns if `"ui"` ghosts or lags on the
  PW12's MTK panel; raise/lower `DEGHOST_EVERY`. No structural change — only the
  four `return` values and the one constant.

Every round: `test-ui` + `test-ui-real` + `test-ui-matrix` green, redeploy,
owner re-judges.

## 6. Packaging

- **`INSTALL.md`** (repo root, one screen): SSH deploy
  (`tools/kindle-ssh-deploy.ps1 -Name <n>`, one-time setup pointer), MTP
  fallback (`tools/deploy-kindle.ps1` + the silent-no-overwrite gotcha), the
  mandatory KOReader restart (no hot reload), where things live
  (`koreader/plugins/magium.koplugin/`, saves + trace under `koreader/magium/`),
  and the two known limitations (once-per-session ~2.2 s first-open parse; no
  live-rotation re-pagination — reopen after rotating).
- **`v1.0`** annotated git tag on the `--no-ff` merge commit.

## 7. Close-out

- `07-risks-open-questions.md`: OQ-007 (e-ink feel — the owner's sign-off),
  OQ-011 (per the §3 table outcome), OQ-013 (resolved by Phase I's custom
  `ui/reader.lua` — record it now on the final pass) → `Status: closed` with
  resolutions.
- `09-roadmap-effort.md`: Phase VIII → done; effort-table row; the §5 handoff
  checklist's last two open rows.
- `SUMMARY.md`: full parity achieved; project feature-complete; Phase VII
  shelved on an upstream data blocker (`phase-vii-shelved`).
- `research-plan.md`: dated running-log entry (gates + numbers + the OQ
  outcomes + ADR if any).
- `MEMORY.md` + `project-goal-and-phase.md`; fix `oracle-corpus-parity-harness.md`
  (stale — baseline is 8887/8887, the crossbow diff was resolved in Phase II).

## 8. Decisions

- **D1** — Phase VIII is measurement-driven: conditional deliverables ship zero
  code unless the one device pass shows they're needed. Rationale: the roadmap
  itself scopes them "only if profiling shows X"; OQ-011 mitigation #1 is
  already the architecture (§3).
- **D2** — No release-zip build script; `INSTALL.md` + the existing deploy
  scripts are the whole packaging story. Distribution stays out of scope
  ([ADR-003](../decisions/ADR-003-defer-licensing-distribution.md)).
- **D3** — Device measurement uses the existing ms-stamped action trace, not a
  new timing line (§2).
- **D4** — An ADR is written **only** if OQ-011 needs the targeted special-case
  (§3 row 3) — that would close the build-time-precompile alternative. The
  e-ink constants, the `on_modal` wiring, and "no GC tuning needed" are not
  ADR-worthy (refresh policy is already scoped to `ui/refresh.lua` in the Phase
  I spec).

## 9. Tests

- **`spec/engine/condition_perf_spec.lua`** (new) — §4.
- **`oracle-corpus`** — re-run **only if** a §3 mitigation touches an `engine/`
  file; confirm the baseline (8887/8887) holds. State the result (or "not
  re-run — no engine change") in the running log.
- **`test-ui` / `test-ui-real` / `test-ui-matrix`** — re-run every round that
  touches `ui/refresh.lua` / `ui/statspage.lua` / `ui/savespage.lua`. Green (6
  smokes each; 4 profiles). No new smoke needed — the refresh *type* is not
  asserted by the paint smokes and does not need to be (it is a device-feel
  parameter, and `refresh.lua` has no logic beyond the counter, which
  `on_new_scene`'s `DEGHOST_EVERY` modulo already exercises implicitly). If a
  round adds real logic to `refresh.lua`, add `spec/ui/refresh_spec.lua` then.
- **`emu-smoke`** — plugin loads clean, `crash.log` empty.
- **`busted`** full suite green on the merged tree before anything leaves the
  machine.

## 10. Exit criteria

- [ ] `spec/engine/condition_perf_spec.lua` lands and passes; the device
      `choice`→`render` trace delta at `B3-Ch04a-Stats-spent` confirms it is
      not a perceptible stall — **or** a §3 mitigation is in place, tested, and
      re-benched.
- [ ] `ui/refresh.lua` tuned to the owner's e-ink sign-off on the PW12;
      `refresh.on_modal()` wired into the stats + saves screens.
- [ ] GC: owner confirms no visible stutter across a full Book 1 → 3 session —
      or a tuning knob is in and tested.
- [ ] `mgm.sh oracle-corpus` green at the baseline (2159 scenes swept);
      `busted`, `test-ui`, `test-ui-real`, `test-ui-matrix`, `emu-smoke` all
      green on the merged tree.
- [ ] `crash.log` clean across the long playthrough, incl. resume across
      reader-close / device suspend / full KOReader restart.
- [ ] `INSTALL.md` written; `v1.0` tag on the merge commit.
- [ ] OQ-007 / OQ-011 / OQ-013 → `closed` in `07-…`; roadmap, `SUMMARY.md`,
      running log, and memory updated; project declared feature-complete.
