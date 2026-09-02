# Spec: Phase V — Achievements

- **Status:** implemented, automated gates green (busted **122/0**, `oracle-corpus`
  unchanged — `scene.render()` untouched, only `persist_effects` extended — `toast`
  + `achievementsmenu` + `savespage` + `statspage` + `reader` UI smokes green,
  headless emu load clean). Two device-pass rounds so far:
  1. **First pass:** a real crash the smoke test's structural asserts missed:
     `mandatory = e.caption` on an entry row crashed on paint
     (`textwidget.lua:224: bad argument #2 to 'makeLine'` — `mandatory` is an
     unwrapped single-line `TextWidget`, wrong field for a full sentence).
     Fixed (caption folded into `text`) and the smoke test started painting
     every one of the 34 chapter entry-list screens for real (`Screen.bb`).
  2. **Second pass:** the fix from (1) *ran* without crashing but still didn't
     look right: the title+caption text was single-line-ellipsized (not
     multi-line) and the locked/unlocked state had no real checkbox, only
     text-dim color. Root cause of *both*: the smoke test's `Screen.bb` is
     `commonrequire`'s **dummy** framebuffer, hardcoded to 600×800 regardless
     of `EMULATE_READER_W/H` — so "paints without crashing" never verified
     actual layout at the real PW12 1272×1696. Diagnosed with a one-off
     non-dummy, `Xvfb`-backed screenshot script (`Screen.bb:writePNG`) built
     for this. Fixed: `multilines_show_more_text = true` on the Menu (the
     item's font shrinks to actually show wrapped text, instead of
     auto-promoting to single-line ellipsis) + a real `✓`/`▢` checkbox glyph
     in `mandatory` (short, safe — the crash class from (1) was *long* text in
     that field, not the field itself) — koreader's own
     `ui/widget/checkmark.lua` convention. Also added an owner-requested
     **reset-all-achievements** action (title-bar warning icon +
     `ConfirmBox`, no reference in magium-dev). Also caught: keyboard-shortcut
     letter boxes in the screenshots — a screenshot-environment artifact only
     (the ad hoc verification script didn't select a touch-only device
     profile); not a real bug, confirmed by reading `menu.lua:604`.
  3. **Owner review of that fix, same round:** the caption still ran into the
     title on one line — `"\n"` between them doesn't force a break;
     `MenuItem:init` unconditionally collapses it to a space
     (`menu.lua:211`), independent of `multilines_show_more_text`. Fixed with
     two real Menu rows per achievement (title+checkbox, then a dim
     non-tappable caption row) instead of one joined string.
  See §3.6 and §6. Re-tested green (busted **122/0**, all 5 UI smokes
  including reset + two-row assertions). Awaiting a follow-up device pass.
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

`Menu:extend`, `AchievementsMenu:new{ locale, view, on_close, on_reset }`.
3-level drill-down via `self.paths` (a stack of `{table, title}`) +
`switchItemTable` + `onReturn` — the standard KOReader idiom (see
`koreader/plugins/opds.koplugin/opdsbrowser.lua`), not `ui/savespage.lua`'s
flat single-level list.

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

### 3.6 Entry-row layout: title/caption as two real lines + a checkbox (2026-09-04, 2nd + 3rd pass)

Findings from a screen the emulator's dummy-`Screen` paint checks had
already "passed" (§0/Status — see the diagnosis note there):

- **Title didn't fit — single-line ellipsis, not wrapped (2nd pass).**
  `MenuItem` auto-promotes to single-line-with-ellipsis whenever the font
  can't fit 2 lines at the row's *default* height (`menu.lua:142-156`) —
  true for a title+caption pair even with room to spare, since the
  promotion check runs before considering how much text there actually is.
  Fix: `multilines_show_more_text = true` on the `Menu` — koreader's own
  mechanism for "let long item text actually show, shrinking font as
  needed", not a custom widget.
- **No visible checkbox — dim color only (2nd pass).** The original
  `dim = not unlocked` (native "greyed out" row) was the *only*
  locked/unlocked signal, and wasn't visible enough. Fix: a real checkbox
  glyph in `mandatory` — `"✓ "` / `"▢ "`, the exact glyphs
  `ui/widget/checkmark.lua` uses for the same purpose everywhere else in
  koreader (guaranteed font coverage). This reuses `mandatory`, the same
  field the 1st-pass crash came from — safe here because the crash was
  specifically about *long* text in an unwrapped field; a 2-character glyph
  is exactly what `mandatory` is for (file size, page number, ...).
- **Caption still ran into the title on one line, not its own (3rd pass).**
  `text = title .. "\n" .. caption` did NOT produce a hard break: read the
  actual code — `MenuItem:init` unconditionally runs
  `self.text:gsub("\n", " ")` (`menu.lua:211`) before any font-size or wrap
  branch even sees the string, so **no in-`text` trick can force a line
  break inside one Menu row**, `multilines_show_more_text` or not. Real fix:
  **two Menu rows per achievement** — a title row (`text=title`,
  `mandatory` = the checkbox) followed immediately by a caption row
  (`text=caption`, `dim=true`, `select_enabled=false`, no `mandatory`). Each
  row is a genuine line by construction; no custom widget needed, still 100%
  native `Menu`/`MenuItem`. Trade-off accepted: the per-row separator line
  now also appears between title and caption (Menu draws one under every
  row, no per-item override exists) — visually minor, and the checkbox only
  ever appearing on the title row keeps the pairing clear regardless.

Verified with a one-off, non-`commonrequire` script
(`Device.screen:init()` without `einkfb.dummy = true`, real SDL headless via
`xvfb-run -a`, `EMULATE_READER_W=1272 EMULATE_READER_H=1696`) that painted
the actual entry-list screen to a PNG (`Screen.bb:writePNG`) and was visually
inspected each pass — screenshots confirmed the wrap, the checkbox, and
finally the real two-line split all render correctly at the real PW12
resolution. (The same screenshots also showed keyboard-shortcut letter boxes
next to each row — a screenshot-environment artifact only: the ad hoc
bootstrap didn't select a touch-only device profile, so `Device:hasKeyboard()`
defaulted true and `menu.lua:604`'s `is_enable_shortcut` followed suit. The
real PW12 (`Device:hasKeys()` false) never shows these; nothing in this
plugin's code is involved.)

### 3.7 Reset all achievements (owner-requested, no reference in magium-dev)

Title-bar left icon (`"notice-warning"`, koreader's own warning-icon asset)
+ `AchievementsMenu:onLeftButtonTap()` — Menu's one customizable title-bar
icon slot (`menu.lua:630,728-731`). Shows a `ConfirmBox` ("Reset all
achievements? This cannot be undone.") before doing anything, matching
`ui/savespage.lua`'s Delete/Overwrite caution level. On confirm: calls
`self.on_reset()` (provided by `main.lua`, does the real store mutation +
`flush_now`) then closes the whole achievements screen via
`self:onCloseAllMenus()` — simplest correct behavior since the reset
invalidates whatever locked/unlocked state every currently-shown level was
built from, rather than trying to re-render the current level in place.

`main.lua:openAchievements()`'s `on_reset`: keeps every store key except
`v_ac_*` and `store:restore()`s that — the exact inverse of `reset_to_intro`
(which keeps *only* `v_ac_*`) — then `flush_now("achievements-reset")`.

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
  `"1"`, `"2"`, and absent (now: the `✓`/`▢` `mandatory` glyph, not `dim`);
  `onReturn` pops correctly; the reset icon/`ConfirmBox`/`on_reset`/close
  chain. **Also calls `widget:paintTo(Screen.bb, 0, 0)` for real** — the book
  list, one chapter list, and every one of the 34 chapter entry-list screens
  across all 3 books, inside a `pcall` — not just structural item_table
  asserts, which had missed the `mandatory`-caption crash. Auto-run by
  `test-ui`. **Caveat, documented in the file's own header:** this still runs
  under `commonrequire`'s dummy 600×800 `Screen` (§0/Status), so these paint
  checks only prove "doesn't crash", not "looks right at 1272×1696" — the
  title-wrap/checkbox fix itself was verified separately via a one-off
  non-dummy script (§3.6). Making non-dummy painting the norm here is Phase
  V.5 scope.
- `spec/flow/playthrough_spec.lua` — a real `achievement()` path
  (`Ch1-Cutthroat Dave` / `v_ac_ch1_coward`): shows on the unlocking render,
  latches to `"2"`, does not re-show on a further re-render of the same scene.
- Regression: `oracle-corpus` unchanged (`scene.render` untouched).

## 5. Exit criteria

- [x] Automated gates green (see Status).
- [ ] Owner on device: unlock a real achievement (e.g. Ch1 "Show myself") and
      see exactly one toast, not repeated on the next page turn or a resume;
      open Achievements from the menu, drill book → chapter → entry and back
      — titles/captions readable across multiple lines, a real checkbox glyph
      per entry; confirm the `v_ac_ch6_immersion` ("Full immersion") toast
      fires from the stats screen; confirm the reset icon asks for
      confirmation and actually clears every achievement.
