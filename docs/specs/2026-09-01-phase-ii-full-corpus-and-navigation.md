# Spec: Phase II — Full corpus & navigation

- **Status:** stable — automated gates green (engine 72/0, busted 104/0, `oracle-corpus` **8887/8887**, headless load clean) + owner on-device sign-off 2026-09-02 ("All seems good"). Built on `feat/phase-ii-full-corpus-nav`.
- **Last updated:** 2026-09-02
- **Phase:** Implementation — design cycle 2 (roadmap [Phase II](../research/09-roadmap-effort.md#phase-ii--full-story--navigation))
- **Sources:**
  - [`2026-08-31-plugin-architecture-and-phase-i.md`](2026-08-31-plugin-architecture-and-phase-i.md) — the permanent architecture; §12 row II + §12.1 carry-forward
  - [`../research/09-roadmap-effort.md`](../research/09-roadmap-effort.md) Phase II — the roadmap this spec opens
  - [`../research/01-magium-analysis.md`](../research/01-magium-analysis.md) §4, §7, §10 — render pipeline, `special:` hooks, the 13 special cases
  - [`../decisions/ADR-006-no-scene-back-navigation.md`](../decisions/ADR-006-no-scene-back-navigation.md) — D1
  - `../../../magium-dev` @ `51f5aa9` — `src/renderers.js`, `templates/main.ejs`, `templates/menu.ejs`, `data/en/ui.json` (port target + oracle)
- **Related:** [`../../research-plan.md`](../../research-plan.md), [`../../SUMMARY.md`](../../SUMMARY.md), [`README.md`](README.md)

> Phase I shipped the engine, the paginated reader, autosave/resume, and ch1
> playable (102/102 oracle, on-device sign-off 2026-09-01). The full-corpus
> parity harness (`mgm.sh oracle-corpus`) sits at **8886 / 8887**. Phase II makes
> the whole game playable and closes that gap. The architecture is fixed by the
> Phase I spec; this cycle adds behaviour behind the existing module boundaries —
> no new layer, no `engine/` core rewrite.

---

## 1. Scope

### 1.1 In scope

1. **Scene `set()` write-back on scene entry** — persist a scene's surviving
   `set_variables` into the real `store` (§4).
2. **Special case #8** — suppress the device-lock stat-check text on
   `B3-Ch01a-Crossbow` only (§5, D3).
3. **In-game menu** — `ui/menu.lua`, the full `menu.ejs` shell with later-phase
   rows disabled (§6, D2).
4. **`special:` hook wiring** — `saves` / `stats` open the menu; `checkpoint_save`
   / `checkpoint_load` are no-op nav; `restart` unchanged (§7, D4).
5. **Full-corpus oracle parity as the phase gate** — `mgm.sh oracle-corpus` at
   8887 / 8887, 0 DIFF (§8).
6. **On-device validation beyond ch1** — owner playthrough of representative
   later chapters (§9).

### 1.2 Out of scope (unchanged from the roadmap)

- **In-game "back one scene" / history stack** — cut, [ADR-006](../decisions/ADR-006-no-scene-back-navigation.md).
  This overrides the roadmap's "back/history stack" line for Phase II.
- **Achievement flag `"1"` → `"2"` "seen" bump** — stays coupled to the unlock
  toast / achievements screen in **Phase V**. Bumping now, with no toast, would
  silently mark achievements the player never saw. The Phase I spec §12.1 #1
  "on the achievements screen" clause is Phase V work.
- Saves UI + real `checkpoint` blob (III); stats screen + stat-screen special
  cases #5 / #9 / #10 / #11 (IV); achievements screen + toast (V); settings (VI);
  `data/fr/` bundle (VII); e-ink tuning + lazy parse (VIII).

### 1.3 Already done in Phase I (not Phase II work)

- **All 54 files load.** `story:preload()` runs eager over the whole corpus on
  the first reader-open (Milestone 0 → `eager`). Phase II adds no loading code.
- Special cases #1 (default scene), #2 (`B3-Ch04a-Introduction2` no checks), #3
  (consolation prize append), #4 (checkpoint banner), #6 (`v_b3_ch1_unlock == 2`
  → failed check), #7 (lock filter), #12 (consolation counter → prize) are live
  and oracle-covered (§5 table).
- `special:restart` — full (`main.lua:reset_to_intro`, keeps `v_ac_*`).

---

## 2. Decisions

| # | Decision | Where recorded |
|---|---|---|
| D1 | **No in-game back / history stack.** `magium-dev` has none — navigation is purely forward via `v_current_scene` (verified: no `history` / `back` / `goBack` in `src/`, `templates/`, or client scripts). Closing the reader still exits to FileManager (Phase I behaviour). | [ADR-006](../decisions/ADR-006-no-scene-back-navigation.md) |
| D2 | **In-game menu = full `menu.ejs` shell, later-phase rows disabled.** Rows: Back to game · New game/Restart book · Load checkpoint · Save/Load · Achievements · Settings · About. Phase II wires **Back to game**, **New game**, **About**; the rest show "Coming in a later version." | this spec §6 |
| D3 | **`B3-Ch01a-Crossbow` device-lock label → faithful-empty (match `magium-dev`).** The scene's prose delivers the lock explicitly ("the screen of my device turns red… 'this device has been locked…'"), so the stat-check meta-line is redundant there — which is why `magium-dev` (`templates/main.ejs:17-20`) suppresses it on that scene id only. Readable `mainStatDeviceLockedText` stays everywhere else. → sweep 8887 / 8887. | this spec §5 |
| D4 | ~~`checkpoint_save` / `checkpoint_load` → full no-op~~ **→ revised after owner device test (2026-09-01): the single `checkpoint` blob is pulled forward from Phase III.** No-op `checkpoint_load` softlocked death scenes (e.g. `B2-Ch07a-Kill` offers only `restart` / `checkpoint_load` / `saves`). Now `checkpoint_save` snapshots `currentState`, `checkpoint_load` restores it (achievements kept, parity with `magium-dev`); no checkpoint yet → an `InfoMessage`, never a silent no-op. The 50 manual slots (`special:saves`) stay Phase III. | this spec §7, §9 |

D2 / D3 / D4 are spec decisions, not ADRs — none permanently closes an
architectural door. D1 gets an ADR because it closes the roadmap's stated
deliverable.

---

## 3. Module changes at a glance (as built)

**Net new files: 0** — the spec's first draft called for `engine/commit.lua`,
`ui/menu.lua`, `commit_spec.lua`, `menu_spec.lua`; the ponytail pass folded each
into an existing file (see §4, §6).

| Module | Change |
|---|---|
| `engine/scene.lua` | + `M.persist_effects(store, render_model)` (pure); special-case #8 branch in the `out_checks` loop. |
| `engine/specials.lua` | + `M.HIDE_DEVICE_LOCK_TEXT = { ["B3-Ch01a-Crossbow"] = true }`. |
| `ui/reader.lua` | Header tap band splits at `close_zone_w`; `on_menu` field + `onTapMenu`; `_text_width` helper; `"Menu"` affordance in `_build_header`. |
| `main.lua` | `scene.persist_effects` in `render_current`; `Magium:openMenu` (`ButtonDialog`) + `Magium:newGame` (`ConfirmBox`); `on_menu` on the `Reader`; `special:saves`/`stats` → `openMenu`. |
| `spec/engine/scene_spec.lua` | + `scene.persist_effects` block + special-case #8 block. |
| `spec/engine/specials_spec.lua` | + `HIDE_DEVICE_LOCK_TEXT` case. |

`engine/` stays pure (C5) — `scene.persist_effects` only calls `store:set` on the
passed-in store object.

---

## 4. Scene `set()` write-back

**Problem.** `engine/scene.render` (step 4) applies a scene's surviving
`set_variables` to a *working view* only; they are never persisted. ch1 has
**0** `set()` constructs so Phase I never needed it (Phase I SDD Ruling 3).
`magium-dev` emits `<script>storeVariable(name, value)</script>` for each
surviving `setVariable` on **every** render (`templates/main.ejs:1-3`); the
client persists them, resolving `+N` / `-N` in `storeVariable`
([`01` §4](../research/01-magium-analysis.md#4-scene-effect-ordering-in-renderscene-task-14)).

**As built (ponytail — no `engine/commit.lua`).** A 2-line pure helper on
`engine/scene.lua`:

```lua
function M.persist_effects(store, render_model)
  for _, sv in ipairs(render_model.set_variables) do
    store:set(sv.name, sv.value)          -- store:set resolves +N / -N and the v_ac_ latch
  end
end
```

`render_model.set_variables` is already the filtered, ordered survivor list — no
re-filtering. `main.lua` `render_current()` calls it right after `scene.render`,
so it runs on the initial open, on resume, and on every choice hop. The
choice-commit loop in `main.lua` `advance` was left inline (it works and nothing
asked to test it).

**Ordering on a choice hop into scene X:** apply `button.set_vars` →
`scene.render(X)` against the post-commit store view → `persist_effects(X)`.
Matches `magium-dev` (client persists `choice.setVariables`, then server-rendered
`storeVariable` scripts persist X's own survivors).

**Known parity quirk — relative `set()` re-apply (shipped faithful).**
`persist_effects` runs on **every** scene entry, including a resume onto the same
scene (close → reopen). A scene with `set(v_x, +N)` therefore adds `N` again on
each resume — exactly what `magium-dev` does (every resume re-`POST`s and re-emits
the script). Only ~10 `set()` lines corpus-wide are relative, most conditional. A
`ponytail:` comment in `scene.lua` names the upgrade path (gate on a per-session
visited-scene set) if the owner ever hits a runaway counter.

---

## 5. The 13 special cases — Phase II audit

Render-time cases must all be live and oracle-covered by the end of Phase II.
Stats-screen cases stay declared-inert until Phase IV (Phase I spec §3.1).

| # | Trigger | Status entering Phase II | Phase II action |
|---|---|---|---|
| 1 | `v_current_scene` absent → `Ch1-Intro1` | live (`specials.DEFAULT_SCENE`) | tick |
| 2 | `id == "B3-Ch04a-Introduction2"` → no stat checks | live (`specials.suppress_stat_checks`) | tick |
| 3 | `v_ac_b3_ch9_prize == "1"` → append "Consolation prize" | live (`specials.extra_achievements`) | tick |
| 4 | surviving choice sets `v_checkpoint_rich == "0"` → banner | live (`scene.lua:76-79`) | tick |
| 5 | maximised-stats animation on `Ch6-Eiden-vs-dragon` | stats screen — **Phase IV** | declared-inert |
| 6 | atom `v_b3_ch1_unlock == 2` → `{ success = false }` | live (`stats.lua:38-40`) | tick |
| 7 | any displayed check is the lock → drop all other checks | live (`stats.lua:79-90`) | tick |
| 8 | rendering the lock check **and** `id != "B3-Ch01a-Crossbow"` → show `mainStatDeviceLockedText`; on that scene show nothing | ~~the 8886/8887 diff~~ | **done** — `specials.HIDE_DEVICE_LOCK_TEXT` + `scene.lua` branch; sweep now 8887/8887 |
| 9 | `v_b3_ch11_magic` truthy → magic rows | stats screen — **Phase IV** | declared-inert |
| 10 | book 3 ch ≥ 4 → bluff/sense/hardening rows | stats screen — **Phase IV** | declared-inert |
| 11 | `maximized && v_ac_ch6_immersion == 0` → unlock "Full immersion" | stats screen — **Phase IV** | declared-inert |
| 12 | `v_ac_b3_ch9_consolation == 5` → `v_ac_b3_ch9_prize = 1` | live (`store.lua:41-43`) | tick |
| 13 | stat var unset → `0`; `v_max_stat` unset → `3` | `0`-default live (`conditions`/`store`); `v_max_stat` is a stats-screen concern | tick the `0`-default; `v_max_stat` → Phase IV |

**#8 as built.** `engine/specials.lua` gains a plain scene-id table
`M.HIDE_DEVICE_LOCK_TEXT = { ["B3-Ch01a-Crossbow"] = true }`. `engine/scene.lua`,
in the `out_checks` loop: when `var == "v_b3_ch1_unlock"` and
`specials.HIDE_DEVICE_LOCK_TEXT[st.id]`, set `text = ""` (keep `success = false`).
Mirrors `magium-dev` `templates/main.ejs:17-20` (empty `<div class='stat_fail'>`
on that scene id) — the oracle normalizer
(`reference/tools/oracle-diff.js:106-114`) turns it into `{ success=false, text="" }`.

**Carry-forward #3 (`Ch11b-Hole`).** `../magium-dev/data/en/ch11b.magium:1049`,
`v_hearing <= 4` — an unmatched operator. `stats.lua` leaves `success` nil;
`scene.lua:96` coerces it to `false`. **Confirmed 0-DIFF** in the 8887/8887
full-corpus sweep — the coercion matches the oracle's canonical form.

---

## 6. In-game menu

**As built (ponytail — no `ui/menu.lua`).** `Magium:openMenu()` in `main.lua`
builds a KOReader `ButtonDialog` (native, tap-outside dismiss, `enabled = false`
greys a row). No separate file / `menu_spec.lua` — the only logic is
`Magium:newGame()`'s one `ConfirmBox` branch. Seven rows, from
`magium-dev/templates/menu.ejs`:

| Row | `ui.json` key | Phase II |
|---|---|---|
| Back to game | `menuBackToGameText` | dismiss the menu |
| New game / Restart book | `menuNewGameText` | if a save exists → `ConfirmBox` → `reset_to_intro(store)` (keeps `v_ac_*`) + re-render scene 1 |
| Load from last checkpoint | `menuLoadCheckpointText` | enabled iff `save:has_checkpoint()` → `save:load_checkpoint()` + reopen |
| Save / Load game | `menuSaveLoadText` | `enabled = false` (50 slots = Phase III) |
| Achievements | `menuAchievementsText` | `enabled = false` |
| Settings | `menuSettingsText` | `enabled = false` |
| About | `menuAboutText` | `TextViewer` with `aboutIntroText` (`<br>` → `\n`) |

New game re-uses the whole open path: `reset_to_intro(store)` →
`save:flush_now` → `UIManager:close(reader)` → `nextTick(openReader)`, rather than
a bespoke reader-reload.

**Trigger (as built).** The reader header tap band (`ui/reader.lua`,
`header_band_h`) splits at `close_zone_w` (the `‹ Close` label width + one
`Size.padding.large`): `x < close_zone_w` → `TapClose`, `x ≥ close_zone_w` →
`TapMenu`. `reader.lua` gains `on_menu` (like `on_close`) → `onTapMenu`; a
literal `"Menu"` `TextWidget` is appended to `_build_header` as the affordance
(the header title's `max_width` shrinks to make room). No new geometry — reuses
`header_band_h` / `_text_width`.

---

## 7. `special:` hook behaviour (Phase II)

Dispatched in `main.lua` `advance`, after the `button.set_vars` loop
([`01` §7](../research/01-magium-analysis.md#7-special-hooks-task-17)):

| `special:` | Corpus count | Phase II behaviour (as built) |
|---|---|---|
| *(none)* | — | navigate to target via `v_current_scene` |
| `restart` | 145 | `reset_to_intro(store)` — keeps `v_ac_*` |
| `checkpoint_save` | 73 | `save:save_checkpoint()` — snapshot `currentState` (the choice's next-chapter `v_current_scene` is already applied) |
| `checkpoint_load` | 144 | `save:load_checkpoint()` → restore + `flush_now` + re-render the restored scene; **no checkpoint → `InfoMessage`** ("choose Restart game"), never a silent no-op |
| `saves` | 145 | `UIManager:nextTick(openMenu)` — Save/Load row disabled (50 slots = Phase III) |
| `stats` | 13 | `InfoMessage` ("stats screen arrives in a later version"); the choice's `v_current_scene` still navigates |

`trace.event("choice", { …, special = … })` records which hook fired; `openMenu`
adds `trace.event("menu", …)`, `loadCheckpoint` a `checkpoint_load` choice event.

**Edge case.** No corpus scene offers *only* a `special:` choice with no plain
Continue alongside (spot-checked; the parser counts in
[`01` §11](../research/01-magium-analysis.md#11-parsed-story-size--memory-footprint-task-112)
show `special:` choices always co-occur). If Step 5's sweep or the owner
playthrough finds a `checkpoint_load`-only dead end, revisit D4 for that scene.

---

## 8. Parity gate

`bash tools/mgm.sh oracle-corpus` — the full generate → capture → render → diff
sweep over all 54 files vs `magium-dev` @ `51f5aa9`.

- **Result: 8887 / 8887, 0 DIFF** (2026-09-01). The known `B3-Ch01a-Crossbow`
  diff closed with §5 #8; no new diff; the normalizer was untouched.
- `scene.persist_effects` (§4) is a **runtime** behaviour — `scene.render` stays
  pure, so the stateless sweep does not exercise it. Covered by
  `spec/engine/scene_spec.lua` (`scene.persist_effects` block) instead.

---

## 9. Exit criteria

- [x] `mgm.sh oracle-corpus` → **8887 / 8887**, 0 DIFF (2026-09-01).
- [x] `mgm.sh lua spec/run.lua` (engine subset **72/0**) + `mgm.sh test`
      (full busted **97/0** — incl. `scene.persist_effects`, special-case #8,
      and the 3 `save_checkpoint`/`load_checkpoint` cases).
- [x] `mgm.sh test-ui` (new headless harness — `spec/ui/reader_smoke.lua` drives
      real tap events at the `Reader` widget in the emulator's KOReader env):
      **9/9** — header-left→close, header-right/middle→menu, body→page-turn,
      choices page has no literal "Choices" footer. This is the regression test
      the stale-deploy menu report exposed the need for.
- [x] `scene.persist_effects` tests: `+N` resolves against the live store value
      in array order; `v_ac_*` latch respected; empty `set_variables` is a no-op.
      (`restart` keeps `v_ac_*` — already covered by the Phase I `main.lua`
      `reset_to_intro` behaviour, unchanged.)
- [x] Headless `kodev` load clean; plugin registers; `crash.log` empty.
- [x] **On device (owner) — retest after a CLEAN deploy** (2026-09-02): clean
      key-only-SSH deploy to the PW12 (`kindle-ssh-deploy.ps1`, 75/75 files
      md5-verified vs staging), owner playthrough — menu, checkpoint save/load,
      `special:restart`, no "Choices" footer — "All seems good". The earlier
      "menu broken" report was confirmed stale code (MTP not overwriting).
- [x] The §5 table: render-time cases #1–#4, #6–#8, #12, #13(`0`-default) live
      and sweep-covered; stats-screen #5, #9–#11 stay declared-inert (Phase IV).

---

## 10. Open items — resolved as built; flag any you want changed

1. **D3 narrative read** — shipped **faithful-empty** (match the oracle):
   `B3-Ch01a-Crossbow`'s prose already delivers the lock. If you disagree on
   review, flipping it is a one-line change + a harness allowlist entry (and the
   sweep drops from 8887/8887 by one).
2. **Relative-`set()` re-apply on resume** — shipped **faithful** (re-applies on
   every scene entry, as `magium-dev` does). `scene.lua` carries a `ponytail:`
   comment with the gate-on-`visited`-set upgrade path if a runaway counter shows
   up on device.
3. **Menu trigger** — shipped as the **header-band split** at `close_zone_w`,
   with a `"Menu"` label affordance.
4. **`special:saves` / `special:stats`** — shipped as **open the in-game menu**
   (`UIManager:nextTick(openMenu)`), no dedicated stub screen.

---

## 11. Status

**Stable.** Implemented on `feat/phase-ii-full-corpus-nav`; automated gates green
(§9) + owner on-device sign-off 2026-09-02. Plan:
[`../superpowers/plans/2026-09-01-phase-ii-full-corpus-and-navigation.md`](../superpowers/plans/2026-09-01-phase-ii-full-corpus-and-navigation.md).

Then Phase III (saves) opens its own spec cycle.
