# Spec: Phase V — Achievements

- **Status:** implemented, automated gates green (busted **122/0**, `oracle-corpus`
  unchanged — `scene.render()` untouched, only `persist_effects` extended — `toast`
  + `achievementsmenu` + `savespage` + `statspage` + `reader` UI smokes green,
  headless emu load clean). First device pass (2026-09-04) caught a real crash
  the smoke test's structural asserts missed: `mandatory = e.caption` on an
  entry row crashed on paint (`textwidget.lua:224: bad argument #2 to
  'makeLine'` — `mandatory` is an unwrapped single-line `TextWidget`, wrong
  field for a full sentence). Fixed (caption folded into `text`) and the smoke
  test now paints every one of the 34 chapter entry-list screens for real
  (`Screen.bb`), not just structural checks — see §4 and CLAUDE.md's
  sharpened "Doing implementation work" rule. Re-tested green; awaiting a
  second device pass.
- **Last updated:** 2026-09-04
- **Phase:** Implementation — design cycle 5 (roadmap [Phase V](../research/09-roadmap-effort.md#phase-v--achievements))
- **Sources:**
  - [`2026-08-31-plugin-architecture-and-phase-i.md`](2026-08-31-plugin-architecture-and-phase-i.md) §6, §12 row V — the architecture this fills in
  - [`../research/01-magium-analysis.md`](../research/01-magium-analysis.md) §6 (achievements)
  - `../../../magium-dev` @ `51f5aa9` — `templates/main.ejs:66-83`, `src/renderers.js:79-86,126-148`,
    `templates/achievements_menu*.ejs`, `templates/stats.ejs:175-190`, `data/en/achievements{1,2,3}.json` (port target)
- **Related:** [`../../research-plan.md`](../../research-plan.md), [Phase IV spec](2026-09-03-phase-iv-stats.md) (deferred the toast here)

> The achievement **unlock computation** (parsing, the display gate, the
> consolation-prize special case) shipped in Phase I/II and is oracle-clean.
> This phase adds the **unlock toast** and the **browsable achievements menu**.
> No `engine/scene.lua:render` change — `oracle-corpus` is unaffected. The one
> engine change (`persist_effects`) is not oracle-diffed (it runs after
> `render`, over its output).

---

## 1. Scope

### 1.1 In scope

1. **`engine/scene.lua:persist_effects`** — extended to flip each shown
   achievement's flag `"1"` → `"2"` ("seen"), so it never re-toasts. Mirrors
   `main.ejs:66-67`'s `storeVariable(variable,"2")` in the same per-render loop
   that shows the modal.
2. **`engine/locale.lua`** — loads `achievements{1,2,3}.json`, indexed both by
   group key (for the menu, in **on-disk declaration order** — not a numeric
   sort, see §3.2) and by variable (`achievement_title`, for the one special
   case with no in-story `achievement()` call).
3. **`ui/toast.lua`** (new) — the in-story unlock notification.
4. **`ui/achievementsmenu.lua`** (new) — the book → chapter → entry drill-down
   browser.
5. **`main.lua`** — wires the toast into every render that shows achievements
   (`render_current`) and into the `v_ac_ch6_immersion` special case
   (`openStats`); enables the previously-disabled "Achievements" menu row and
   adds `openAchievements()`.

### 1.2 Out of scope

- **Exact site menu ordering beyond chapter position.** Book/chapter ordering
  is now exact (declaration order, per owner request — see §3.2); entry order
  within one chapter group is JSON-array order, also exact. Nothing here is
  known to diverge from the reference.
- **Two-row toast layout.** KOReader's `Notification` wraps a single-line
  `TextWidget` (confirmed from `koreader/frontend/ui/widget/notification.lua`
  — no wrap). The reference's "ACHIEVEMENT UNLOCKED" header / title two-row
  CSS layout collapses to one line: `"<header>: <title>"`. Cheap to change to
  two stacked toasts later if the on-device look doesn't read well — `ui/toast.lua`
  is the only file that would need to change.

## 2. The port target (magium-dev @ `51f5aa9`)

- **Unlock computation** (already ported, Phase I/II): `achievement()` parsed
  per scene (`engine/parser.lua:72-74`); `scene.render` keeps those where
  `view[variable] == "1"` and appends the consolation-prize special case
  (`engine/scene.lua:61-73`, `engine/specials.lua`).
- **Toast**: `main.ejs:66-83` — for every achievement in `scene.achievements`,
  emit `storeVariable(variable,"2")` and show a 2s auto-dismiss modal with the
  achievement's `text` (== the achievements-JSON entry's `title`).
- **`v_ac_ch6_immersion`** (Phase IV's stat-screen unlock, #5/#11): its own
  modal lives in `stats.ejs:175-190`, gated on `(locals.v_ac_ch6_immersion || 0)
  === 0`, storing `"1"` (not `"2"`) — it has no in-story `achievement()` call,
  so it never advances past `"1"` in the reference either; the gate's own
  `=== 0` check is what stops it from re-showing.
- **Achievements menu**: `src/renderers.js:126-148` (`renderAchievementsMenu` /
  `…Book` / `…Chapter`) + `templates/achievements_menu*.ejs` — book list →
  chapter list → entry list (title, caption, locked/unlocked from
  `(locals[variable]||0) != "0"`, i.e. `"1"` or `"2"` both count as unlocked).
- **Data**: `achievements{1,2,3}.json`, 136 entries (35+48+53). Keys are mostly
  `b<book>ch<chapter>`; two chapters per book split into two groups declared
  inline (`b2ch41`/`b2ch42` between `b2ch3`/`b2ch5`; `b3ch61`/`b3ch62` between
  `b3ch5`/`b3ch7`) — their menu label is the literal captured number
  ("Chapter 41"/"Chapter 42"), not a renumbering.

## 3. Design

### 3.1 The seen-latch: `engine/scene.lua:persist_effects`

Extended (not a new function) to also iterate `render_model.achievements` and
`store:set(a.variable, "2")` for each — reusing the render→writeback seam
`main.lua` and `spec/support/headless_game.lua` already call every render.
`Store:set` already carries the freeze-at-2 guard and the consolation-counter
special case (`engine/store.lua:22-26,38-43`), so this just exercises
plumbing that predates this phase. `scene.render()` itself is untouched.

### 3.2 `engine/locale.lua` — achievements JSON + declaration order

`json.decode` doesn't preserve key order, and the owner wants the split
chapters (`b2ch41`/`b2ch42`, `b3ch61`/`b3ch62`) positioned inline between
their neighbors, matching the source data and the live site — not sorted
after the book's last chapter. All top-level keys match `"bNchM":`, so one
`gmatch` pass over each book's raw JSON text at load time recovers the
on-disk order directly (no general ordered-JSON parser needed).

New `Locale` accessors: `achievement_book_count()`, `achievement_chapters(book_n)`
(ordered group keys), `achievement_entries(book_n, key)` (raw entry array),
`achievement_title(variable)` (linear scan across all books — used only by
the `v_ac_ch6_immersion` special case, which has no render-time achievement
list to source its toast text from).

### 3.3 `ui/toast.lua`

`M.show(locale, achievements)` — one `Notification:new{text=header..": "..a.text,
timeout=2}` + `UIManager:show` per achievement. Text source is
`render_model.achievements[i].text` directly (== the achievement's JSON
`title`, confirmed by spot-check), not a JSON lookup — keeps this module
decoupled from `locale`'s JSON-loading code except for the header string.
`Notification`'s own `_shown_list` already staggers multiple simultaneous
toasts, so N unlocks in one render just call `M.show` in a loop.

### 3.4 `ui/achievementsmenu.lua`

`Menu:extend`, `AchievementsMenu:new{ locale, view, on_close }`. 3-level
drill-down via `self.paths` (a stack of `{table, title}`) +
`switchItemTable` + `onReturn` — the standard KOReader idiom (see
`koreader/plugins/opds.koplugin/opdsbrowser.lua`), not `ui/savespage.lua`'s
flat single-level list. Entry rows carry `dim = not unlocked` (native
KOReader "greyed out" row styling) instead of a hand-rolled locked/unlocked
glyph.

### 3.5 `main.lua` wiring

- `render_current()`: right after `scene.persist_effects`, if
  `#rm.achievements > 0` → `Toast.show` + `self.save:on_achievement_unlocked()`
  (flush the now-"2" blob immediately rather than waiting on the next
  unrelated save event).
- `openStats()`: the existing `v_ac_ch6_immersion` unlock now also calls
  `Toast.show`, sourcing its title via the new `Locale:achievement_title`
  (this achievement has no render-time achievement list — see §2).
- In-game menu: the "Achievements" row is enabled (was `enabled = false`
  since Phase I) and opens `Magium:openAchievements()`, mirroring
  `openSaves()`/`openStats()`.

## 4. Tests

- `spec/engine/scene_spec.lua` — `persist_effects` latch: flips "1"→"2",
  freeze holds on an already-"2" achievement; the 3 pre-existing cases updated
  to carry `achievements = {}`.
- `spec/engine/locale_spec.lua` — 136 entries total across the 3 books;
  `achievement_chapters(2)` returns `b2ch3, b2ch41, b2ch42, b2ch5` in exactly
  that order; a known entry (`v_ac_ch1_coward`) reads correctly.
- `spec/ui/toast_smoke.lua` (new) — single unlock, multi-unlock (one
  `Notification` per achievement), no-op on an empty list. Auto-run by `test-ui`.
- `spec/ui/achievementsmenu_smoke.lua` (new) — book list; chapter-order
  inlining (the D5 case, asserted by position); entry unlocked/dimmed for
  `"1"`, `"2"`, and absent; `onReturn` pops correctly. **Also calls
  `widget:paintTo(Screen.bb, 0, 0)` for real** — the book list, one chapter
  list, and every one of the 34 chapter entry-list screens across all 3
  books, inside a `pcall` — not just structural item_table asserts, which
  had missed the `mandatory`-caption crash. Auto-run by `test-ui`.
- `spec/flow/playthrough_spec.lua` — a real `achievement()` path
  (`Ch1-Cutthroat Dave` / `v_ac_ch1_coward`): shows on the unlocking render,
  latches to `"2"`, does not re-show on a further re-render of the same scene.
- Regression: `oracle-corpus` unchanged (`scene.render` untouched).

## 5. Exit criteria

- [x] Automated gates green (see Status).
- [ ] Owner on device: unlock a real achievement (e.g. Ch1 "Show myself") and
      see exactly one toast, not repeated on the next page turn or a resume;
      open Achievements from the menu, drill book → chapter → entry and back;
      confirm the `v_ac_ch6_immersion` ("Full immersion") toast fires from the
      stats screen.
