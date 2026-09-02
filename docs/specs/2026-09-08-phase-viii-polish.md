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
> itself) are explicitly *conditional* — "only if profiling shows X".
>
> **The owner cannot run sessions longer than ~5 minutes** (stated 2026-09-08).
> So the on-device work is a **single ≤5-minute e-ink pass** — the one thing no
> emulator can judge. Everything else moves off the device:
> - **OQ-011** — closed on the dev bench (§3: 2.6 ms/render x86 → ~15 ms device
>   at spike 06's validated ×5.6). No device confirmation needed.
> - **GC stutter** — not a phase gate (a long session would be needed to
>   provoke it, and ~11.5 MB resident heap makes it very unlikely). Downgraded
>   to a post-release watch: if the owner ever notices a hitch in normal play,
>   reopen with a `collectgarbage` knob.
> - **Full-corpus crash bash** — `mgm.sh oracle-corpus` already renders all
>   2159 scenes headlessly; that *is* the full-corpus render-crash check.
>
> Phase VIII is the project's last phase — on sign-off the port is declared
> feature-complete.

---

## 1. Scope

### 1.1 In scope

1. **OQ-011 dev bench** — `spec/engine/condition_perf_spec.lua` (new): a loose
   regression tripwire around rendering the 2044-clause-condition scene, same
   shape as the existing parse tripwire in `story_eager_spec.lua`. Landed
   (measured 2.6 ms/render x86). Closes OQ-011 (§3).
2. **One ≤5-minute device e-ink pass** — deploy, owner taps through ~2–3 min of
   prose + a handful of choices in any chapter, opens Stats / Saves / Menu once
   each, reports feel; `crash.log` clean after. Pull `crash.log` (+
   `trace-*.jsonl` if they left the trace on). That's the whole device ask.
3. **E-ink tuning (OQ-007)** — `magium.koplugin/ui/refresh.lua` constants (the 4
   `return` values + `DEGHOST_EVERY`), tuned to the owner's ≤5-min-pass report
   over as many quick redeploy rounds as it takes. Modal open/close fix lands at
   the `main.lua` call sites *only if* the pass flags it (the `on_modal()`
   helper exists unused; KOReader's default show/close refresh governs those
   today).
4. **Full-corpus QA** — `mgm.sh oracle-corpus` (renders all 2159 scenes) + the
   device pass's clean `crash.log`.
5. **Packaging** — `INSTALL.md` at repo root (landed); `v1.0` annotated tag on
   merge.
6. **Close-out** — OQ-007 / OQ-011 / OQ-013 → `closed`; roadmap, `SUMMARY.md`,
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

## 2. The device pass needs no new code

- **e-ink feel is perceptual** — the owner's ≤5-min report *is* the
  measurement; nothing to instrument.
- If the owner leaves *Menu → Settings → Record debug log* on, the trace is a
  bonus: `main.lua:165` already stamps every event in monotonic ms
  (`time.to_ms(time.now())`) and `main.lua:363` emits a `render` event per
  scene, so a `choice`→`render` `t` delta is there for free if we want to spot
  a slow hop. Not required — OQ-011 is closed on the dev bench (§3), and no
  other per-scene cost is in question.

## 3. OQ-011: what's already mitigated, what the bench decides

`engine/parser.lua` calls `M.parse_conditions(cond)` at **parse time**; the DNF
table is stored on the scene, and `engine/conditions.lua:eval(dnf, view)` walks
that pre-built table at render time. **Mitigation #1 from the roadmap ("memoise
the parsed DNF for that scene id") is therefore already the architecture** — the
490 KB string is split into 2044 AND-groups exactly once, during the ~2.2 s cold
preload that spike 06 already measured and the owner already accepted.

The residual cost is walking the 2044-group DNF on each visit to
`B3-Ch04a-Stats-spent`: up to ~4000 `eval_atom` calls, each doing one
`string.match`. **Measured during spec-writing (dev x86 LuaJIT):
2.6 ms/render** with a realistic player view (1.1 ms with an empty view) — a
full `scene.render`, condition walk included. At spike 06's ×5.6, that projects
to **~15 ms on the owner's Kindle** — imperceptible.

| Bench result (x86, per render) | Device estimate | Action |
|---|---|---|
| < ~50 ms → **measured 2.6 ms** | < ~280 ms → **~15 ms** | **No code.** OQ-011 closes: "already mitigated by parse-time DNF caching; residual eval cost ~15 ms/render on device — acceptable." |
| ~50–200 ms | ~0.3–1.1 s | Add a module-level `atom → {name,op,num}` memo in `engine/conditions.lua` (atoms are immutable strings; the `string.match` per atom is the hot cost). Re-bench. |
| still slow after the memo | | Special-case `B3-Ch04a-Stats-spent` as a direct `v_*` comparison in `engine/specials.lua`. → **ADR** (closes the build-time-precompile alternative). Not expected. |

**Outcome: OQ-011 closes on the 2.6 ms measurement.** No mitigation code; the
bench lands as a permanent tripwire. The owner can't reach `B3-Ch04a-Stats-spent`
in a 5-min pass and no device confirmation is required — spike 06 already
measured the x86→device factor (×5.6) directly on the same class of CPU-bound
Lua, and even a 10× pessimistic factor leaves this under 30 ms.

GC (not a phase gate — see the header note): resident heap after preload is
~11.5 MB (spike 03); a stutter would need a long session to provoke and is very
unlikely. Post-release watch only — if the owner ever notices a hitch in normal
play, reopen with `collectgarbage("setstepmul", …)` at plugin init or
`collectgarbage("step")` in `ui/reader.lua:_turn`. → running log, not an ADR.

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

## 5. E-ink policy — `ui/refresh.lua`

Current policy (`ui/refresh.lua`, 14 lines):

| Moment | Type | Notes |
|---|---|---|
| `on_open` | `full` | first paint of the reader (`reader.lua:116`) |
| `on_page_turn` | `ui` | no flash (`reader.lua:288`) |
| `on_new_scene` | `ui`, `full` every 6th (`DEGHOST_EVERY`) | choice commit (`reader.lua:326`) |
| `on_modal` | `flashui` | **defined, unused** — stats/saves/menu currently ride KOReader's default show/close refresh; their in-widget `_refresh()` uses a literal `"ui"` (correct — an in-place tap update, not a modal transition) |

Changes, applied **per the owner's ≤5-min pass report** (nothing here is done
speculatively):

- **`on_page_turn` / `on_new_scene` type**, `DEGHOST_EVERY` value — tuned to the
  owner's judgment of ghosting build-up vs. flash annoyance. Candidates:
  `"ui"` → `"fast"` or `"a2"` for page turns if `"ui"` ghosts or lags on the
  PW12's MTK panel; raise/lower `DEGHOST_EVERY`. Only the 4 `return` values and
  the one constant — no structural change.
- **Modal transitions** — only if the owner flags a stats/saves/menu
  open or close as flashing wrong or ghosting: wire `refresh.on_modal()` (or a
  new `on_modal_close`) at the `UIManager:show`/`close` call sites in `main.lua`.
  Not expected; not pre-built.

If the first pass is "feels fine", `ui/refresh.lua` ships unchanged and OQ-007
closes on that. Each round that does touch `ui/`: `test-ui` + `test-ui-real` +
`test-ui-matrix` green, redeploy, owner re-judges.

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
  code unless shown needed. Rationale: the roadmap scopes them "only if
  profiling shows X"; OQ-011 mitigation #1 is already the architecture (§3).
- **D2** — The owner's ≤5-min session limit (2026-09-08) reshapes the device
  work: **OQ-011 closes on the dev bench** (no device confirmation — spike 06
  already measured the ×5.6 x86→device factor for this class of work);
  **GC is a post-release watch, not a phase gate** (a long session is needed to
  provoke it); the only on-device deliverable is the e-ink feel pass, which
  fits in ≤5 min of tapping any chapter.
- **D3** — No release-zip build script; `INSTALL.md` + the existing deploy
  scripts are the whole packaging story. Distribution stays out of scope
  ([ADR-003](../decisions/ADR-003-defer-licensing-distribution.md)).
- **D4** — An ADR is written **only** if OQ-011 unexpectedly needs the targeted
  special-case (§3 row 3) — that would close the build-time-precompile
  alternative. The e-ink constants and the GC watch are not ADR-worthy (refresh
  policy is already scoped to `ui/refresh.lua` in the Phase I spec).

## 9. Tests

- **`spec/engine/condition_perf_spec.lua`** (new) — §4.
- **`oracle-corpus`** — re-run **only if** a §3 mitigation touches an `engine/`
  file; confirm the baseline (8887/8887) holds. State the result (or "not
  re-run — no engine change") in the running log.
- **`test-ui` / `test-ui-real` / `test-ui-matrix`** — re-run every round that
  touches a `ui/` file. Green (6 smokes each; 4 profiles). No new smoke needed —
  the refresh *type* is a device-feel parameter, not asserted by the paint
  smokes, and `refresh.lua` has no logic beyond the `DEGHOST_EVERY` counter
  (already exercised implicitly by the `on_new_scene` modulo). If a round adds
  real branching to `refresh.lua`, add `spec/ui/refresh_spec.lua` then.
- **`emu-smoke`** — plugin loads clean, `crash.log` empty.
- **`busted`** full suite green on the merged tree before anything leaves the
  machine.

## 10. Exit criteria

- [x] `spec/engine/condition_perf_spec.lua` lands and passes (2.6 ms/render
      x86 → ~15 ms device). OQ-011 closed on the bench — no device confirmation
      required (D2).
- [ ] `ui/refresh.lua`: owner's ≤5-min e-ink pass on the PW12 — page turns,
      choice-commit de-ghost cadence, and stats/saves/menu transitions all
      judged acceptable, or tuned until they are.
- [ ] `crash.log` clean after that pass, incl. resume across reader-close /
      device suspend / full KOReader restart.
- [ ] `mgm.sh oracle-corpus` green at the baseline (2159 scenes swept);
      `busted`, `test-ui`, `test-ui-real`, `test-ui-matrix`, `emu-smoke` all
      green on the merged tree.
- [x] `INSTALL.md` written. `v1.0` tag on the merge commit — at merge.
- [ ] OQ-007 / OQ-011 / OQ-013 → `closed` in `07-…`; roadmap, `SUMMARY.md`,
      running log, and memory updated; project declared feature-complete.
- GC stutter: post-release watch, not an exit criterion (D2).
