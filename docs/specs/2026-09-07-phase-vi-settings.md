# Spec: Phase VI — Settings & viewport robustness

- **Status:** implemented on `feat/phase-vi-settings` — automated gates green
  (busted **132/0**, `test-ui` + `test-ui-real` + new `test-ui-matrix` all
  profiles green, `emu-smoke` clean; `oracle-corpus` not re-run — no `engine/`
  change, baseline stays **8887/8887**). **Awaiting owner device sign-off.**
- **Last updated:** 2026-09-07
- **Phase:** Implementation — design cycle 6 (roadmap [Phase VI](../research/09-roadmap-effort.md#phase-vi--settings--themes))
- **Sources:**
  - [`2026-08-31-plugin-architecture-and-phase-i.md`](2026-08-31-plugin-architecture-and-phase-i.md) §8.2 (fixed prose size, rotation deferred), §12 row VI
  - [`../research/01-magium-analysis.md`](../research/01-magium-analysis.md) §8.2 (settings)
  - `../../../magium-dev` @ `51f5aa9` — `templates/settings.ejs`, `templates/language.ejs`, `public/scripts/{theme,utils}.js`, `data/en/ui.json`
- **Related:** [`../../research-plan.md`](../../research-plan.md), [Phase VII](../research/09-roadmap-effort.md#phase-vii--localization-en--fr) (language, split out)

> **Scoping pass result:** of `magium-dev`'s four settings — language, theme,
> font size, cheat mode — only **cheat mode** and a **reader-local text size**
> are ported here. Theme is KOReader's job; language is Phase VII. The phase
> also hardens the custom reader's layout for **screen sizes other than the
> owner's Paperwhite 12**, emulator-verified (no other hardware available).
> No `engine/` change → `oracle-corpus` stays **8887/8887**.

---

## 1. Scope

### 1.1 In scope

1. **`main.lua`** — enable the disabled in-game-menu "Settings" row; add
   `openSettings()` (a `ButtonDialog`), a text-size sub-dialog, and a
   cheat-mode `ConfirmBox`.
2. **`ui/reader.lua`** — read the persisted prose point size; floor
   `prose_height` so a tiny viewport can't break pagination; pass a height
   budget to the choices page.
3. **`ui/choices.lua`** — scroll the choice list when it overflows the page
   body.
4. **`spec/ui/reader_smoke.lua`** + **`tools/mgm.sh`** — a page-body-bounds
   assertion and a `test-ui-matrix` run across ~4 device profiles.

### 1.2 Out of scope

- **Theme / night mode.** KOReader has its own (`Screen:toggleNightMode`, the
  reader's own theming). `magium-dev`'s 4 CSS presets (`theme.js`) are not
  ported. [`01` §8.2](../research/01-magium-analysis.md#82-settings).
- **Language switch.** Phase VII (`language.ejs` + the fr `.magium` bundle +
  plugin-chrome `.po`). Not a Phase VI concern.
- **Font *slider* / arbitrary point sizes.** 3 presets is enough for e-ink;
  `magium-dev`'s 0.75×–1.25× slider granularity is not reproduced.
- **Scaling the header / choice-button fonts** with the prose preset. Prose
  only. Revisit only if Large prose visibly clashes with the fixed chrome.
- **Live rotation / window resize.** `onSetRotationMode` / `onSetDimensions`
  re-pagination stays in **Phase VIII** (Phase I spec §8.2). Phase VI covers
  only the layout KOReader reports **when the reader is opened**.

## 2. The port target (`magium-dev` @ `51f5aa9`)

`templates/settings.ejs`:

| Control | Behaviour | Port |
|---|---|---|
| Language button | → `/language`, cookie + reload | Phase VII |
| Theme `<select>` | `handleThemeChange(value)` → `localStorage.theme`, CSS class swap | dropped (KOReader native) |
| Cheat mode button | modal → `storeVariable('v_available_points', 50)` | **ported** (§3.2) |
| Font-size `<input type=range>` | `updateFontSize()` → `--font-size` var + `fontsize` cookie, 0.75–1.25 | **ported as 3 presets** (§3.3) — KOReader's document font setting does not reach the custom reader widget |

`v_available_points` feeds the stats screen (`ui/statspage.lua:41`
`base_points = tonumber(view.v_available_points or 0)`); cheat mode just
raises it to 50 so every stat can be maxed on the next stats-screen visit.
The web modal is one-shot and unconditional — no gate, no persistence flag.

## 3. Design

### 3.1 `main.lua` — the Settings dialog

`openMenu()`'s disabled row becomes:

```lua
{{ text = _("Settings"), callback = act(function() self:openSettings() end) }},
```

`Magium:openSettings()` mirrors `openMenu()`'s own construction (a
`ButtonDialog`, the local `act(fn)` close-then-run helper):

- **Text size** → `self:_openTextSizeDialog()` (§3.3).
- **Cheat mode** — label `self.locale:str("settingsCheatModeText")`
  (fallback `_("Cheat mode")`).
- **Back to game** — `act(function() end)`.

`trace.event("menu", { action = "settings" })` on open, matching the other
`open*` methods.

### 3.2 Cheat mode

`ConfirmBox` (not a bespoke modal — same widget `newGame()` already uses):

- `text` = `self.locale:str("settingsCheatModeModalText")` (fallback
  `_("Enable cheat mode? You will get 50 stat points to spend.")`), with
  `<br>` → `\n` like `openMenu()`'s About text.
- `ok_text` = `self.locale:str("localeYes")`, `cancel_text` =
  `self.locale:str("localeNo")`.
- `ok_callback`: `self.store:set("v_available_points", "50")` →
  `self.save:flush_now("cheat")` → `trace.event("settings", { op = "cheat" })`
  → a short `InfoMessage` (`_("Cheat mode enabled — open Stats to spend your points.")`).

Store value is the **string** `"50"` — the store is a string namespace
(`v_*` values are strings everywhere; `statspage` does `tonumber(...)`).

### 3.3 Reader text size

**Persistence.** `G_reader_settings` key **`magium_prose_size`**, an integer
point size — the same global-settings convention as the existing
`magium_trace` key (`main.lua:292`). Absent → the current default.

**`ui/reader.lua`.** `PROSE_SIZE = 20` stays as the default constant;
`init()` changes from

```lua
self.face = Font:getFace(PROSE_FACE, PROSE_SIZE)
```

to

```lua
local prose_pt = G_reader_settings and G_reader_settings:readSetting("magium_prose_size") or PROSE_SIZE
self.face = Font:getFace(PROSE_FACE, prose_pt)
```

(`G_reader_settings` is a KOReader global, always present at runtime and under
both test bootstraps; the `and` guard is belt-and-braces for a bare unit
require.) `_measure_fn()` already closes over `self.face`, so pagination
re-measures at the new size for free.

**Presets.** `PROSE_PRESETS = { {_("Small"), 17}, {_("Medium"), 20}, {_("Large"), 25} }`
in `main.lua`. `_openTextSizeDialog()` builds a `ButtonDialog`, one row per
preset; the active one (matching the stored value, or `PROSE_SIZE` when unset)
gets a `" ✓"` suffix on its label — no custom checkbox widget. Selecting a row:

```lua
G_reader_settings:saveSetting("magium_prose_size", pt)
-- close both dialogs, then:
self:_reopenReader()
```

`_reopenReader()` (`main.lua:584`) already closes the reader and re-opens it on
`v_current_scene` — `Reader:init()` re-runs, re-reads the setting,
re-paginates. No new re-pagination path.

Final preset point sizes are confirmed against a real-resolution screenshot in
each setting during implementation (17/20/25 is the starting guess).

### 3.4 Choices scroll on overflow — `ui/reader.lua` + `ui/choices.lua`

The choices page is `Choices.build{...}` dropped straight into `_render()`'s
fixed-height `FrameContainer` with no height clamp (`reader.lua:203-209`,
`:252`). A tall choice list (many choices, or long wrapping labels on a narrow
screen) paints past the frame and its lower buttons become untappable.

- `reader.lua:_build_page()` passes `height = self.geometry.prose_height` into
  `Choices.build` (the page-body box; the choices page has no first-page head
  offset).
- `ui/choices.lua`: after building the `ButtonTable`, if
  `bt:getSize().h > opts.height`, return it wrapped in
  `ScrollableContainer:new{ dimen = Geom:new{ w = opts.width, h = opts.height },
  show_parent = opts.show_parent, <bt> }` (KOReader-native,
  `ui/widget/scrollablecontainer` — the same widget `KeyValuePage` uses for
  overflow). Otherwise return `bt` bare — **zero behavioural change on PW12**
  for the common case (2–4 short choices). The empty-list degradation path
  (`choices.lua:20-36`) is unchanged.
- `ScrollableContainer` needs `show_parent` for its scrollbar refreshes;
  `_build_page` already passes `show_parent = self`.

### 3.5 `prose_height` floor — `ui/reader.lua`

`reader.lua:98`:

```lua
prose_height = self.dimen.h - self.header_h - indicator_h - 2*self.pad - 2*Size.padding.large,
```

On a 600×800 (or smaller) screen with a checkpoint banner + stat-check head
offset, this can approach or cross zero, and `pagination.fit_words` then emits
one word per page (it always makes progress, so no infinite loop — but
hundreds of pages). Floor it at one prose line:

```lua
local min_body = self:_line_height(PROSE_FACE, prose_pt) + Size.padding.default
prose_height = math.max(min_body, <the subtraction above>),
```

Anything else the §5 matrix run surfaces is fixed here too, case by case —
not pre-specified. **No `engine/` file is touched.**

### 3.6 Not an ADR (yet)

The "don't port theme/font/language" call is already recorded in the roadmap
(Phase VI row) and restated in §1.2 here. The only genuinely *new* decisions —
reader text size is a plugin-local preset rather than deferred to KOReader,
and live rotation stays in Phase VIII — are small and uncontested. If
implementation turns up a contested fork, it gets ADR-008 then; otherwise the
running log carries it.

## 4. Tests

- **`spec/ui/reader_smoke.lua`** (extended):
  - After each `_render()`, assert the rendered tree's height
    (`r[1]:getSize().h`) is `<= Screen:getHeight()` — the page-body-bounds
    check. Runs at whatever size the env set.
  - Build the reader at each `PROSE_PRESETS` size (set `magium_prose_size` via
    `G_reader_settings` before `Reader:new`) and paint page 1 for real; assert
    no crash and in-bounds.
  - Extend the existing "widest 15 labels" block (item 5) to also assert that
    on a **small** profile the choices page is either in-bounds or wrapped in a
    `ScrollableContainer` (check the returned widget type).
- **`spec/flow` / busted** — a `main`-level test (or extend
  `spec/ui/main_e2e_smoke.lua`) that drives `openSettings()` → cheat row →
  confirm, and asserts `store:get("v_available_points") == "50"` and a flush
  happened; and that `_openTextSizeDialog` selection writes `magium_prose_size`
  and triggers a reader reopen.
- **`tools/mgm.sh test-ui-matrix`** — re-runs `test-ui-real` with
  `EMULATE_READER_W/H/DPI` exported for each profile:

  | Profile | W×H | DPI |
  |---|---|---|
  | small 6″ Kindle | 600×800 | 167 |
  | Paperwhite 11 | 1072×1448 | 300 |
  | Paperwhite 12 (owner) | 1272×1696 | 300 |
  | Kindle Scribe | 1860×2480 | 300 |

  Every `*_smoke.lua` must exit 0 at every profile. Added to the `verify`
  skill as the gate for any `reader.lua` / `pagination.lua` / `choices.lua`
  change.
- **Regression:** `oracle-corpus` **not** re-run — no `engine/` or
  `scene.render` change (baseline stays 8887/8887); state this in the log.
  `busted` + `test-ui` + `test-ui-real` all green.

## 5. Exit criteria

- [ ] Automated gates green: `busted` (≥ 132/0 + new asserts), `test-ui`,
      `test-ui-real`, **`test-ui-matrix`** (all 4 profiles), `emu-smoke` clean.
      `oracle-corpus` unchanged at 8887/8887 (not re-run — no engine change).
- [ ] Owner on device (PW12): in-game menu → **Settings** opens; **Text size**
      → Small/Medium/Large visibly changes the reading font and the choice is
      kept across a reader close/reopen and a suspend/resume; **Cheat mode**
      asks Yes/No then, on Yes, the Stats screen shows 50 points to spend; a
      scene with many long choices scrolls rather than clipping.
- [ ] Other-viewport correctness is covered by `test-ui-matrix` in the
      emulator, not asked of the owner.
