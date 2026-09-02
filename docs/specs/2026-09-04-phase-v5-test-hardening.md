# Spec: Phase V.5 — Test hardening

- **Status:** planned, not started. Owner is executing this phase in its own
  session, before Phase VI.
- **Last updated:** 2026-09-04
- **Phase:** Implementation — design cycle 5.5 (roadmap [Phase V.5](../research/09-roadmap-effort.md#phase-v5--test-hardening))
- **Sources:**
  - Owner-requested audit, 2026-09-04, prompted by two device-only bugs each
    slipping past a per-piece test suite: Phase IV's lingering tutorial
    `TextViewer` (caught on first device pass, `research-plan.md` 2026-09-03
    session 29b) and Phase V's `mandatory`-field paint crash in the
    achievements menu (caught on first device pass, `research-plan.md`
    2026-09-04 session 30).
  - [`2026-09-04-phase-v-achievements.md`](2026-09-04-phase-v-achievements.md) — the
    phase whose device pass exposed the gap; V.5's fixtures reuse its screens/data.
  - `koreader/spec/unit/widget_progresswidget_spec.lua` — the real-`paintTo`
    pattern already adopted for `spec/ui/achievementsmenu_smoke.lua`, generalized
    here.
- **Related:** [`../../research-plan.md`](../../research-plan.md), CLAUDE.md
  "Doing implementation work" (the emulator-first rule this phase sharpens
  further; also where the new standing regression rule this phase establishes
  is codified once it lands)

> Not in the original design doc. Every phase I–V shipped its own tests and
> passed them, yet two bugs reached the device anyway — both were failures of
> *integration*, not of any single piece: a widget correct in isolation, never
> actually driven the way `main.lua` drives it, or never actually painted with
> real (long) data. This phase is a deliberate pause to close that class of
> gap before Phase VI adds more UI surface on the same untested foundation.

---

## 1. Scope

### 1.1 Why now, not later

`docs/specs/2026-08-31-plugin-architecture-and-phase-i.md`'s own testing
discipline (engine: oracle-diff; UI: emulator smoke before device) was
followed for every phase so far, and still let two device-only bugs through:

- **Phase IV:** a `TextViewer` shown from `StatsPage:init()` was never closed
  — lingered behind the reopened reader. The smoke test built the screen and
  checked its `kv_pairs`; nothing ever asked "what does `UIManager`'s widget
  stack look like after this screen closes?"
- **Phase V:** `mandatory = e.caption` on an achievements-menu entry row
  crashed on paint (`textwidget.lua:224`). The smoke test built the
  `item_table` and asserted its fields; nothing ever asked KOReader to
  actually lay the row out.

Both gaps share a root cause: **tests exercised data/structure, not the real
render or the real top-level wiring.** Phase V's fix (§4 of its own spec)
already generalized "paint every real instance" for one screen. This phase
generalizes the *class* of fix — plus a second, unrelated gap noticed in the
same review: no test protects the achievements *content* itself from going
stale (an unreachable/orphaned achievement).

### 1.2 In scope (priority order)

1. **App-level / E2E harness.** Construct the real `Magium` object
   (`magium.koplugin/main.lua`) headlessly and drive it through a realistic
   session. This is the highest-value item — it is the one thing standing
   between "every screen works in isolation" and "the game works."
2. **Content integrity: orphaned achievements.** A static check, same shape
   as `spec/engine/navigation_spec.lua`, over the achievements data.
3. **Systematic graph exploration.** Extend `spec/flow/playthrough_spec.lua`
   beyond its single greedy walk.
4. **Save schema/compatibility regression.** A golden fixture + loader test
   for the current save blob shape.
5. **Content stress-testing beyond achievements.** Generalize "paint every
   real instance" to other free-form-text widgets.
6. **Performance regression.** A parse-time budget assertion.
7. **Fix `spec/ui/*_smoke.lua`'s paint checks to run at the real PW12
   resolution, not a dummy 600×800.** Found chasing the achievements-menu
   layout bug (`research-plan.md` 2026-09-04 session 30, 2nd device pass):
   every `spec/ui/*_smoke.lua` requires `commonrequire`, whose
   `einkfb.dummy = true` hardcodes `Screen` to 600×800
   (`base/ffi/framebuffer_SDL3.lua:17`) regardless of `EMULATE_READER_W/H` —
   so every existing `widget:paintTo(Screen.bb,...)` check (item 5 above and
   the achievements-menu fix included) has only ever proven "doesn't crash",
   never "looks right at 1272×1696". A one-off non-dummy, `Xvfb`-backed
   bootstrap script (real `Screen:init()`, skip the dummy flag) proved this
   works and is what actually caught the title-wrap bug — turn that into a
   reusable `spec/support/real_screen_require.lua` (or similar) + a `mgm.sh`
   command every `spec/ui/*_smoke.lua` can opt into. Groups naturally with
   item 5; do both together.

### 1.3 Out of scope

- Real device/hardware-in-the-loop CI — not achievable in this repo's setup;
  the owner's manual device pass stays the final gate for e-ink feel and real
  input, per the existing emulator-first rule. This phase raises the ceiling
  of what the emulator catches, not a replacement for that pass.
- Fuzzing the parser/condition-evaluator with malformed `.magium` syntax —
  out of scope; the corpus is a fixed, owner-controlled asset, not
  user-supplied input, so this isn't a real trust boundary.

## 2. Design notes per item

### 2.1 App-level / E2E harness

`main.lua:Magium` is a `WidgetContainer:extend{...}`. `Magium:init()`
(`main.lua:112`) requires `self.ui.menu:registerToMainMenu(self)` and
`self.path` — normally supplied by KOReader's plugin loader (a real
`FileManager`/`ReaderUI` instance). To construct one headlessly:

```lua
local fake_ui = { menu = { registerToMainMenu = function() end } }
local m = Magium:new{ ui = fake_ui, path = PLUGIN }   -- PLUGIN via the
                                                        -- package.path trick
                                                        -- already used in
                                                        -- achievementsmenu_smoke.lua
```

`Magium:init()` builds its own `SaveManager` internally
(`state_writer()`/`slot_store()` closures over `Persist` + `DataStorage`,
`main.lua:76-104`) — those write to a real (test-scoped) `DataStorage`
dir under `koenv`'s environment, OR the constructor needs a seam to inject
`spec/support/fake_writer.lua` / `fake_slotstore.lua` the way
`spec/support/headless_game.lua` does. **Decide which** before starting:
injecting fakes is more isolated and faster; using real `Persist` against a
throwaway dir is more faithful to what actually runs on-device. Recommend
real `Persist` against a temp dir (closer to the actual crash class this
phase exists to catch — the fake writers already have equivalent coverage
via `headless_game.lua`).

Drive, asserting real effects each time (not just no-crash):

- `openReader()` — the real story parse + progress bar path (`_ensureLoaded`),
  resume-or-fresh logic, and the reader widget actually shows.
- `openMenu()` — the real `ButtonDialog` is constructed with the right
  buttons enabled/disabled (mirrors what `main.lua:420-448` currently builds
  by hand-verified reading, not an automated check).
- `openSaves()` / `openStats()` / `openAchievements()` — opened from the real
  menu callback (not constructed directly, which is what the existing
  per-widget smokes already do), and `on_close`/`_reopenReader()` actually
  returns to a live reader.
  
  Note: `openStats()`'s "Full immersion" achievement path does display-order
  matter here vs the toast? — verify the E2E harness's stats-screen drive
  also exercises the `Toast.show` call added in Phase V (`main.lua`
  `openStats()`), not just `openReader()`'s.
- `newGame()` — the real `ConfirmBox`, confirmed → `reset_to_intro` actually
  runs, achievements survive.
- `onSuspend()` / `onClose()` / `onCloseWidget()` — flush actually happens
  before teardown; the trace file (if enabled) actually closes without
  leaking a handle into the next session (the exact class of bug the
  `_configureTrace` comment at `main.lua:140-145` already flags as fragile).

### 2.2 Content integrity: orphaned achievements

Cross-reference every `variable` across all `achievements{1,2,3}.json`
entries (136 total, `engine/locale.lua:achievement_entries`) against:

- every parsed `achievement()` call's `variable` field
  (`engine/parser.lua:72-74`, collected across the full corpus the way
  `spec/engine/navigation_spec.lua:load_all()` already does), **and**
- `specials.lua`'s hardcoded special-case variables (`CONSOLATION.variable`
  = `v_ac_b3_ch9_prize`; `v_ac_ch6_immersion` from the Phase IV/V "Full
  immersion" unlock).

Fail (listing every offender, not just the first) if a JSON variable matches
neither set — that achievement can never be earned. Also worth the reverse
check while the cross-reference exists: an `achievement()` call whose
variable has no matching JSON entry (shows a toast for something with no
menu entry) — cheap to add once the two sets are built.

### 2.3 Systematic graph exploration

`spec/flow/playthrough_spec.lua`'s existing walk (`depth_of`-scored greedy
BFS-ish walker, one stat profile: everything maxed) reaches depth ≥105 and
>40 distinct scenes, but never varies its stat profile and stops at the first
dead end per branch. A systematic version would run the walk multiple times
with different stat-variable profiles (all-maxed, all-zero, a few
partial/mixed profiles) and union the reachable-scene sets, to catch
reachability bugs `oracle-corpus`'s per-scene (not per-path) checks don't
surface. Lower priority than 2.1/2.2 — most of the render-correctness value
this would add is already covered by `oracle-corpus`'s exhaustive per-scene
condition sweep; this item is specifically about *graph* reachability under
varied state, a narrower and less commonly-buggy surface.

### 2.4 Save schema/compatibility regression

Snapshot the current save blob shape (`save/manager.lua`'s `state` /
`achievements` / `checkpoint` / per-slot blobs) as a checked-in fixture file,
and add a test that loads it through `SaveManager` and asserts the expected
fields land in the store correctly. The value isn't today (no saves exist
outside the owner's own device) — it's the tripwire for the day the format
changes and an old save silently breaks. Cheap to establish now while the
format is still simple; establishing it later means reconstructing "what did
the format look like before" from git history instead of a fixture.

### 2.5 Content stress-testing beyond achievements

Same principle as the achievements-menu fix (§4 of the Phase V spec): paint
every real instance of free-form corpus text through a layout-sensitive
widget, not a sampled case. Candidates:

- `ui/reader.lua`'s choice buttons — the longest `choice("...")` label text
  across the full corpus, painted for real (an analog of what
  `reader_smoke.lua` already does for prose page-length, but for *choice
  label width*, not paragraph height).
- Save-slot names (`ui/savespage.lua`) — currently derived from
  `locale:header(...)`, which is bounded/short by construction, so lower risk
  than achievement captions were — audit rather than assume safe.

### 2.6 Performance regression

Wrap `Story:preload()` (or the `openReader()` call path that triggers it) in
one test with a generous time budget (e.g. 2x the ~2.2s on-device baseline
from `docs/spikes/06-ondevice-parse-timing/FINDING.md`, adjusted for the dev
machine vs. Kindle CPU) — not a tight perf gate, just a tripwire against an
accidental O(n²) regression going unnoticed until the next device pass.

## 3. Tests this phase produces

Each deliverable in §2 *is* a test (or a small test file) — this phase's
"tests" section is its own deliverable list, not a separate layer on top.
Expect roughly:

- `spec/app/magium_e2e_spec.lua` (or `spec/ui/main_smoke.lua`, name TBD —
  match whichever existing convention (`busted` vs. `koenv`-plain-assert)
  fits once the fake-`ui`/real-`Persist` decision in §2.1 is made) — the
  app-level harness.
- `spec/engine/achievements_integrity_spec.lua` (or folded into
  `navigation_spec.lua` as a new `describe` block) — §2.2.
- `spec/flow/playthrough_spec.lua` extended, not a new file — §2.3.
- `spec/save/manager_spec.lua` extended, or a new
  `spec/save/schema_compat_spec.lua` with a checked-in fixture — §2.4.
- `spec/ui/reader_smoke.lua` extended — §2.5.
- One new assertion in an existing engine/story spec, or a tiny new one —
  §2.6.

## 4. The standing rule this phase establishes

Once this phase's suites exist, **every subsequent phase and change must run
them and update them as needed** — the same status `busted` / `oracle-corpus`
/ `spec/ui/*_smoke.lua` already have. A phase that changes behavior without
updating the tests that assert the old behavior is incomplete, the same way
a `ui/` change without an emulator check is incomplete today. This gets
codified as an explicit CLAUDE.md rule (see "Doing implementation work") once
the concrete file names/commands from §3 exist to point to.

## 5. Exit criteria

- [ ] All six items in §1.2 have a corresponding test (or an explicit,
      documented reason one was cut/deferred).
- [ ] `mgm.sh test`, `mgm.sh test-ui`, and `mgm.sh oracle-corpus` all stay
      green with the new suites added.
- [ ] CLAUDE.md's "Doing implementation work" section updated with the
      concrete commands/paths for the new regression suites, and the
      standing "every phase must run + update them" rule made explicit
      (§4).
- [ ] `docs/research/09-roadmap-effort.md` Phase V.5 row marked done, same
      pattern as Phases II/IV/V.
