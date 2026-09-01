# Phase II — Full corpus & navigation — Implementation Plan

> **Status: implemented 2026-09-01** on `feat/phase-ii-full-corpus-nav` (code
> commit `ade1a2f`). Executed inline (CLAUDE.md: no subagents for large tasks).
> Ponytail collapsed Tasks 1–3 into one code commit; docs are Task 4. Automated
> gates green — engine 72/0, busted 94/0, `oracle-corpus` **8887/8887**, headless
> load clean. **Remaining:** the owner on-device playthrough (Task 4 Step 6 /
> spec §9). Steps below are left unticked as the original plan of record.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the whole Magium corpus playable end-to-end and close the last full-corpus oracle-parity gap.

**Architecture:** Phase I's three-layer plugin is fixed. Phase II adds behaviour behind the existing boundaries — no new layer, no `engine/` core rewrite, **no new files**. Scene `set()` effects get persisted on scene entry; the one hardcoded special case left unported (#8) lands; an in-game menu (KOReader `ButtonDialog`) hangs off the reader header; the `special:` hooks route to it.

**Tech Stack:** LuaJIT 2.1 / Lua 5.1, KOReader `v2026.07.1` widget API, `busted` + bare `luajit` for engine specs, `tools/mgm.sh oracle-corpus` (WSL2) as the parity gate against `magium-dev` @ `51f5aa9`.

**Spec:** [`docs/specs/2026-09-01-phase-ii-full-corpus-and-navigation.md`](../../specs/2026-09-01-phase-ii-full-corpus-and-navigation.md)

## Global Constraints

- `engine/` stays **pure Lua, no KOReader deps** — runs under bare `luajit` and the oracle diff (spec C5).
- Navigation is authoritative on `v_current_scene`, never `choice.target` (spec C6).
- Full parity with `magium-dev` @ `51f5aa9` is the standard for every behaviour question (spec C1). Any deliberate deviation → documented in the spec, not silent.
- LuaJIT 2.1: Lua string patterns (not regex), all numbers doubles, no `utf8` stdlib (spec C4).
- Spec code is a design reference; production code is written fresh (spec C7).
- The parse strategy is `eager`, deferred to first reader-open — do not touch (`main.lua` `PARSE_STRATEGY`, Milestone 0).
- Ponytail: this plan deliberately drops the spec's `engine/commit.lua` and `ui/menu.lua` files — the write-back is a 2-line pure helper in `engine/scene.lua`, the menu is a method in `main.lua` over `ButtonDialog`. Split later only if a phase needs it.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `magium.koplugin/engine/scene.lua` | modify | + `M.persist_effects(store, render_model)` (pure); special-case #8 branch in the `out_checks` loop. |
| `magium.koplugin/engine/specials.lua` | modify | + `M.HIDE_DEVICE_LOCK_TEXT` scene-id table (case #8). |
| `magium.koplugin/main.lua` | modify | Call `scene.persist_effects` in `render_current`; `Magium:openMenu()` + `Magium:newGame()`; pass `on_menu` to `Reader`; route `special:saves`/`stats` to the menu. |
| `magium.koplugin/ui/reader.lua` | modify | Split the header tap band (close zone vs menu zone); `on_menu` callback + `onTapMenu`; a visible "Menu" affordance in the header. |
| `magium.koplugin/spec/engine/scene_spec.lua` | modify | Tests for `persist_effects` and case #8. |
| `magium.koplugin/spec/engine/specials_spec.lua` | modify | Test for `HIDE_DEVICE_LOCK_TEXT`. |
| `docs/specs/2026-09-01-phase-ii-full-corpus-and-navigation.md` | modify | Status → stable; tick §5 / §9. |
| `docs/decisions/ADR-006-no-scene-back-navigation.md` | modify | Status Proposed → Accepted. |
| `docs/specs/2026-08-31-plugin-architecture-and-phase-i.md`, `docs/research/09-roadmap-effort.md`, `SUMMARY.md`, `research-plan.md` | modify | Terse pointers (Task 4). |

---

## Task 1: Scene `set()` write-back

A scene's own surviving `set()` effects are applied to a working *view* in
`scene.render` and then discarded. `magium-dev` persists them on every render
(`templates/main.ejs:1-3` → client `storeVariable`, `+N`/`-N` resolved). ch1 has
0 `set()` so Phase I never needed it; the rest of the corpus does (594 `set()`,
466 conditional).

**Files:**
- Modify: `magium.koplugin/engine/scene.lua` (add `M.persist_effects`, near the end before `return M`)
- Modify: `magium.koplugin/main.lua` (call it in the `render_current` closure inside `openReader`)
- Test: `magium.koplugin/spec/engine/scene_spec.lua`

**Interfaces:**
- Produces: `scene.persist_effects(store, render_model)` — `store` is an `engine/store.lua` instance (has `:set(name, value)` with `+N`/`-N` resolution and the `v_ac_*` latch); `render_model` is the table returned by `scene.render`. Returns nothing. Iterates `render_model.set_variables` (`{ {name=, value=}, ... }`, already filtered + ordered by `scene.render`) and calls `store:set` for each.

- [ ] **Step 1: Write the failing test**

In `magium.koplugin/spec/engine/scene_spec.lua`, add a new `describe` block:

```lua
describe("scene.persist_effects", function()
  local Store = require("engine/store")

  it("replays render_model.set_variables into the store, resolving +N in order", function()
    local rm = {
      set_variables = {
        { name = "v_gold", value = "+5" },
        { name = "v_flag", value = "1" },
        { name = "v_gold", value = "+2" },
      },
    }
    local s = Store.new({ v_gold = "10" })
    scene.persist_effects(s, rm)
    assert.are.equal("17", s:get("v_gold"))
    assert.are.equal("1", s:get("v_flag"))
  end)

  it("respects the v_ac_* latch on write-back", function()
    local rm = { set_variables = { { name = "v_ac_x", value = "1" } } }
    local s = Store.new({ v_ac_x = "2" })
    scene.persist_effects(s, rm)
    assert.are.equal("2", s:get("v_ac_x"))
  end)

  it("is a no-op when the scene set nothing", function()
    local s = Store.new({ v_a = "1" })
    scene.persist_effects(s, { set_variables = {} })
    assert.are.equal("1", s:get("v_a"))
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd magium.koplugin && luajit spec/run.lua`
Expected: FAIL — `attempt to call field 'persist_effects' (a nil value)`.

- [ ] **Step 3: Implement `persist_effects`**

In `magium.koplugin/engine/scene.lua`, immediately before `return M`:

```lua
-- Persist a rendered scene's own surviving set() effects into the real store.
-- magium-dev emits a storeVariable() script per surviving setVariable on EVERY
-- render (templates/main.ejs:1-3 @51f5aa9); the client persists them with +N/-N
-- resolved. render_model.set_variables is already filtered + ordered by render().
--
-- ponytail: re-applies on every scene entry, INCLUDING a resume onto the same
-- scene — a scene with set(v_x, +N) adds N again per resume, exactly as
-- magium-dev does (each resume re-POSTs and re-emits the script). ~10 relative
-- set() lines corpus-wide, most conditional. Upgrade path if the owner hits a
-- runaway counter: gate this on a per-session visited-scene set.
function M.persist_effects(store, render_model)
  for _, sv in ipairs(render_model.set_variables) do
    store:set(sv.name, sv.value)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd magium.koplugin && luajit spec/run.lua`
Expected: PASS — all three new assertions green, existing scene specs unchanged.

- [ ] **Step 5: Wire into `main.lua`**

In `magium.koplugin/main.lua`, in the `render_current` local function inside
`openReader` (currently ~line 312-330), immediately after
`local rm = scene.render(st, self.store:view(), self.locale)` and before the
`trace.event("render", …)` call, insert:

```lua
    scene.persist_effects(self.store, rm)   -- persist this scene's own set() effects (spec §4)
```

`render_current` is called both for the initial `Reader:new{ render_model = … }`
and inside `advance` on every choice hop, so this covers all scene entries.

- [ ] **Step 6: Verify the engine subset + headless load still pass**

Run: `cd magium.koplugin && luajit spec/run.lua`
Run (WSL2): `bash tools/mgm.sh emu-smoke`
Expected: engine subset green; headless `kodev` load clean, plugin registers, no traceback in the log.

- [ ] **Step 7: Commit**

```bash
git add magium.koplugin/engine/scene.lua magium.koplugin/main.lua magium.koplugin/spec/engine/scene_spec.lua
git commit -m "Phase II: persist a scene's own set() effects on scene entry

Ports magium-dev's per-render storeVariable() writes (templates/main.ejs:1-3).
scene.persist_effects replays render_model.set_variables into the store with
+N/-N resolved; main.lua calls it in render_current. Spec carry-forward #1.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01B7RH9AwLKK5WkJbGUzhPpR"
```

---

## Task 2: Special case #8 — device-lock label on `B3-Ch01a-Crossbow`

The `v_b3_ch1_unlock` stat-check sentinel renders `mainStatDeviceLockedText`
everywhere — but `magium-dev` (`templates/main.ejs:17-20`) renders an **empty**
`<div class='stat_fail'>` on `B3-Ch01a-Crossbow`, because that scene's prose
already states the lock ("the screen of my device turns red… 'this device has
been locked…'"). The oracle normalizer
(`reference/tools/oracle-diff.js:106-114`) turns the empty div into
`{ success = false, text = "" }`. This is the single `8886 / 8887` diff.

**Files:**
- Modify: `magium.koplugin/engine/specials.lua` (add the scene-id table)
- Modify: `magium.koplugin/engine/scene.lua` (branch in the `out_checks` loop)
- Test: `magium.koplugin/spec/engine/specials_spec.lua`, `magium.koplugin/spec/engine/scene_spec.lua`

**Interfaces:**
- Produces: `specials.HIDE_DEVICE_LOCK_TEXT` — a plain `{ [scene_id] = true }` table; `specials.HIDE_DEVICE_LOCK_TEXT["B3-Ch01a-Crossbow"] == true`, everything else `nil`.

- [ ] **Step 1: Write the failing tests**

In `magium.koplugin/spec/engine/specials_spec.lua`, inside the existing
`describe("specials", …)`:

```lua
  it("hides the device-lock stat-check text only on B3-Ch01a-Crossbow", function()
    assert.is_true(specials.HIDE_DEVICE_LOCK_TEXT["B3-Ch01a-Crossbow"])
    assert.is_nil(specials.HIDE_DEVICE_LOCK_TEXT["B3-Ch01a-Intro"])
  end)
```

In `magium.koplugin/spec/engine/scene_spec.lua`, add a new `describe` block
(the `helper` / `Locale` / `parser` requires already exist at the top of the file):

```lua
describe("scene.render — special case #8 (device-lock label)", function()
  local b3, loc
  setup(function()
    b3 = parser.parse(helper.data_dir_en .. "/b3ch1.magium")
    loc = Locale.load(helper.data_dir_en:gsub("/en$", ""), "en")
  end)

  it("renders an empty device-lock label on B3-Ch01a-Crossbow", function()
    local rm = scene.render(b3["B3-Ch01a-Crossbow"],
      { v_current_scene = "B3-Ch01a-Crossbow", v_b3_ch1_unlock = "2" }, loc)
    assert.are.equal(1, #rm.stat_checks)
    assert.is_false(rm.stat_checks[1].success)
    assert.are.equal("", rm.stat_checks[1].text)
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd magium.koplugin && luajit spec/run.lua`
Expected: FAIL — `HIDE_DEVICE_LOCK_TEXT` is nil; the Crossbow check renders `"[ Stat device locked - check failed ]"`, not `""`.

- [ ] **Step 3: Add the scene-id table**

In `magium.koplugin/engine/specials.lua`, after the `NO_STAT_CHECK_SCENES` line:

```lua
-- case #8: the device-lock stat-check line shows mainStatDeviceLockedText
-- everywhere EXCEPT B3-Ch01a-Crossbow, where the scene's own prose already
-- states the lock — magium-dev renders an empty <div> there
-- (templates/main.ejs:17-20 @51f5aa9).
M.HIDE_DEVICE_LOCK_TEXT = { ["B3-Ch01a-Crossbow"] = true }
```

- [ ] **Step 4: Branch in `scene.lua`**

In `magium.koplugin/engine/scene.lua`, in the `out_checks` assembly loop
(currently ~line 86-99), replace the single `local text = locale:stat_check_text{…}`
line with:

```lua
    local ok = sc.success and true or false
    local text
    if var == "v_b3_ch1_unlock" and specials.HIDE_DEVICE_LOCK_TEXT[st.id] then
      text = ""                                              -- special case #8
    else
      text = locale:stat_check_text{ variable = var, value = sc.value, success = ok }
    end
    out_checks[#out_checks + 1] = { success = ok, text = text }
```

(`specials` is already `require`d at the top of `scene.lua`; `var` is already the
raw `"v_b3_ch1_unlock"` for the sentinel — `scene.lua:88` skips the `locale:str`
swap for it.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd magium.koplugin && luajit spec/run.lua`
Expected: PASS — both new blocks green; existing `scene_spec` / `specials_spec` unchanged.

- [ ] **Step 6: Run the full-corpus parity sweep**

Run (WSL2): `bash tools/mgm.sh oracle-corpus`
Expected: **8887 / 8887**, 0 DIFF vs `magium-dev` @ `51f5aa9`. The previously
known `B3-Ch01a-Crossbow` diff is gone; no new diff. If a new diff appears,
triage it (normalizer blind spot vs engine regression) before continuing —
do not commit a regression.

- [ ] **Step 7: Commit**

```bash
git add magium.koplugin/engine/specials.lua magium.koplugin/engine/scene.lua \
        magium.koplugin/spec/engine/specials_spec.lua magium.koplugin/spec/engine/scene_spec.lua
git commit -m "Phase II: special case #8 — empty device-lock label on B3-Ch01a-Crossbow

magium-dev renders an empty stat_fail div there (templates/main.ejs:17-20); the
scene's prose already states the lock. Closes the last full-corpus diff:
mgm.sh oracle-corpus now 8887/8887 vs magium-dev @ 51f5aa9.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01B7RH9AwLKK5WkJbGUzhPpR"
```

---

## Task 3: In-game menu + `special:` hook routing

D2: an in-game menu with the full `menu.ejs` shell, later-phase rows disabled.
Reached from the reader header. `special:saves` / `special:stats` route to it;
`special:checkpoint_*` stay no-op (D4).

**Files:**
- Modify: `magium.koplugin/main.lua` (`Magium:openMenu`, `Magium:newGame`, `on_menu` wiring, `special:` routing in `advance`)
- Modify: `magium.koplugin/ui/reader.lua` (`on_menu` field, header tap-band split, `onTapMenu`, "Menu" affordance)

**Interfaces:**
- Consumes (reader ← main): `Reader:new{ on_menu = function() end, … }` — called on a tap in the header's menu zone.
- Produces (main): `Magium:openMenu()` shows a `ButtonDialog`; `Magium:newGame()` shows a `ConfirmBox` then resets + reopens the reader.

- [ ] **Step 1: Reader — add the `on_menu` field and split the header tap band**

In `magium.koplugin/ui/reader.lua`:

(a) Add to the `Reader = InputContainer:extend{ … }` table, next to `on_close`:

```lua
  on_menu = nil,     -- function() — opens the in-game menu (Phase II)
```

(b) Add a text-width helper near `_line_height`:

```lua
function Reader:_text_width(text, face)
  local tw = TextWidget:new{ text = text, face = face }
  local w = tw:getSize().w
  tw:free()
  return w
end
```

(c) In `init()`, after `self.header_band_h = self.pad + self.header_h`, add:

```lua
  -- The header band splits into a left close zone (just the "‹ Close" label)
  -- and a right menu zone (the rest). Both sit above the page-turn zones.
  self.close_zone_w = self:_text_width(CLOSE_LABEL, Font:getFace(HEAD_FACE, 18))
    + Size.padding.large
```

(d) In the `self.ges_events = { … }` table, replace the single `TapClose` entry with:

```lua
    TapClose = { GestureRange:new{ ges = "tap", range = Geom:new{
      x = 0, y = 0, w = self.close_zone_w, h = self.header_band_h,
    } } },
    TapMenu = { GestureRange:new{ ges = "tap", range = Geom:new{
      x = self.close_zone_w, y = 0,
      w = self.dimen.w - self.close_zone_w, h = self.header_band_h,
    } } },
```

(e) Add the handler next to `onTapClose`:

```lua
function Reader:onTapMenu()
  if self.on_menu then self.on_menu() end
  return true
end
```

(f) In `_build_header`, add a visible affordance. Change the return to append a
`"Menu"` label after the title, and shrink the title's `max_width` to leave room:

```lua
function Reader:_build_header()
  local close = TextWidget:new{ text = CLOSE_LABEL, face = Font:getFace(HEAD_FACE, 18) }
  local menu = TextWidget:new{ text = "Menu", face = Font:getFace(HEAD_FACE, 18) }
  local gap = Size.padding.large
  return HorizontalGroup:new{
    close,
    HorizontalSpan:new{ width = gap },
    TextWidget:new{
      text = self.render_model.header or "",
      face = Font:getFace(HEAD_FACE, 18),
      max_width = math.max(1,
        self.text_width - close:getSize().w - menu:getSize().w - 2 * gap),
    },
    HorizontalSpan:new{ width = gap },
    menu,
  }
end
```

- [ ] **Step 2: Reader — sanity-check the split with the pagination spec**

Run: `cd magium.koplugin && luajit spec/run.lua`
Run: `bash tools/mgm.sh emu-smoke` (WSL2)
Expected: pagination spec unaffected (geometry math unchanged — `prose_height`
still starts at `self.header_band_h`); headless load clean.

`ui/reader.lua` has no unit spec (Phase I precedent) — the real check is the
emulator run in Step 6 and the owner device run (Task 4).

- [ ] **Step 3: main.lua — `openMenu` and `newGame`**

In `magium.koplugin/main.lua`, add two methods (after `openReader`, before the
`onSuspend` lifecycle block). `InfoMessage` and `UIManager` are already required
at the top; `ButtonDialog` / `ConfirmBox` / `TextViewer` are required locally:

```lua
-- The in-game menu (spec §6, D2). Full menu.ejs shell; Load checkpoint /
-- Save-Load / Achievements / Settings are disabled until their phases (III–VI).
function Magium:openMenu()
  local ButtonDialog = require("ui/widget/buttondialog")
  local TextViewer = require("ui/widget/textviewer")
  local dialog
  local function act(fn) return function() UIManager:close(dialog); fn() end end
  local about = (self.locale:str("aboutIntroText")
    or "Magium — a Choose Your Own Adventure game by Cristian Mihailescu.")
    :gsub("<br%s*/?>", "\n")
  dialog = ButtonDialog:new{
    title = _("Magium"), title_align = "center",
    buttons = {
      {{ text = _("Back to game"), callback = act(function() end) }},
      {{ text = _("New game / Restart book"), callback = act(function() self:newGame() end) }},
      {{ text = _("Load from last checkpoint"), enabled = false }},
      {{ text = _("Save / Load game"), enabled = false }},
      {{ text = _("Achievements"), enabled = false }},
      {{ text = _("Settings"), enabled = false }},
      {{ text = _("About"), callback = act(function()
        UIManager:show(TextViewer:new{ title = _("About"), text = about })
      end) }},
    },
  }
  UIManager:show(dialog)
  trace.event("menu", { action = "open" })
end

-- New game / Restart book: a fresh playthrough, achievements kept
-- (reset_to_intro, parity with magium-dev clearState). A save always exists here
-- (openReader flushed one), so always confirm.
function Magium:newGame()
  local ConfirmBox = require("ui/widget/confirmbox")
  UIManager:show(ConfirmBox:new{
    text = _("Start a new game? Your progress will be lost. Achievements are kept."),
    ok_text = _("New game"),
    ok_callback = function()
      reset_to_intro(self.store)
      self.save:flush_now("new-game")
      trace.event("choice", { label = "new game", target = specials.DEFAULT_SCENE })
      if self.reader then UIManager:close(self.reader) end
      UIManager:nextTick(function() self:openReader() end)
    end,
  })
end
```

- [ ] **Step 4: main.lua — pass `on_menu` to the reader**

In `openReader`, in the `self.reader = Reader:new{ … }` table, add next to `locale`:

```lua
    on_menu = function() self:openMenu() end,
```

- [ ] **Step 5: main.lua — route `special:saves` / `special:stats`**

In the `advance` closure, replace:

```lua
      if button.special == "restart" then
        reset_to_intro(self.store)   -- keep achievements (parity: clearState)
      end
      -- special:saves / :stats / :checkpoint_* are Phase II/III — no-op nav for now
```

with:

```lua
      if button.special == "restart" then
        reset_to_intro(self.store)   -- keep achievements (parity: clearState)
      elseif button.special == "saves" or button.special == "stats" then
        UIManager:nextTick(function() self:openMenu() end)   -- real screens: Phases III / IV
      end
      -- special:checkpoint_save / :checkpoint_load — no-op until Phase III (D4).
      -- The choice's own v_current_scene assignment (applied in the loop above)
      -- still navigates.
```

- [ ] **Step 6: Run the emulator and click through the menu**

Run (WSL2): `./kodev run` (or `bash tools/mgm.sh` equivalent), open Magium, play
into ch2, tap the header "Menu" area:
- ButtonDialog appears titled "Magium" with 7 rows; the 4 middle rows greyed.
- "Back to game" dismisses, same page.
- "About" shows the about text with real line breaks.
- "New game" → ConfirmBox → confirm → reader reopens on `Ch1-Intro1`.
- Tapping "‹ Close" (left of header) still exits to FileManager.
- Page-turn taps below the header still work.

Check the emulator log for tracebacks.

- [ ] **Step 7: Commit**

```bash
git add magium.koplugin/main.lua magium.koplugin/ui/reader.lua
git commit -m "Phase II: in-game menu + special: hook routing

Header tap band splits into close (left) / menu (right). Magium:openMenu is the
full menu.ejs shell via ButtonDialog, later-phase rows disabled (D2). New game
resets (keeping achievements) and reopens the reader. special:saves/:stats open
the menu; special:checkpoint_* stay no-op (D4).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01B7RH9AwLKK5WkJbGUzhPpR"
```

---

## Task 4: Parity gate, carry-forward audit, docs, device handoff

**Files:**
- Modify: `docs/specs/2026-09-01-phase-ii-full-corpus-and-navigation.md`, `docs/decisions/ADR-006-no-scene-back-navigation.md`, `docs/specs/2026-08-31-plugin-architecture-and-phase-i.md`, `docs/research/09-roadmap-effort.md`, `SUMMARY.md`, `research-plan.md`

- [ ] **Step 1: Full engine + busted suite**

Run: `cd magium.koplugin && luajit spec/run.lua`
Run (WSL2): `./kodev test front` (from the koreader checkout, pointed at the plugin) — or `bash tools/mgm.sh` test target if defined.
Expected: engine subset and full busted suite green, 0 failures.

- [ ] **Step 2: Full-corpus parity sweep (the phase gate)**

Run (WSL2): `bash tools/mgm.sh oracle-corpus`
Expected: **8887 / 8887**, 0 DIFF vs `magium-dev` @ `51f5aa9`.

- [ ] **Step 3: Confirm carry-forward #3 (`Ch11b-Hole`)**

In the sweep output from Step 2, confirm the `Ch11b-Hole` cases
(`../magium-dev/data/en/ch11b.magium:1049`, `v_hearing <= 4` — an unmatched
operator) show 0 DIFF. `engine/stats.lua` leaves `success` nil for `<=`;
`engine/scene.lua:96` coerces it to `false`. If a DIFF appears here, the
coercion does not match the oracle's canonical form — fix `scene.lua` before
closing the phase.

If `gen_cases.lua` does not generate a case that exercises `Ch11b-Hole` with
`v_hearing <= 4` true, add a hand fixture to
`reference/tools/oracle-cases.json` (the 6-case hand set) covering it, capture
its golden, and re-run.

- [ ] **Step 4: Tick the spec's special-case table and exit criteria**

In `docs/specs/2026-09-01-phase-ii-full-corpus-and-navigation.md`:
- §5 table: mark #8 done; confirm #1–#4, #6, #7, #12, #13(`0`-default) are ticked; #5/#9/#10/#11 stay "declared-inert — Phase IV".
- §9 exit criteria: tick every automated box that Steps 1–3 satisfied; leave the on-device box for Step 6.
- Header Status: `draft — awaiting owner review` → `stable` **after** the owner device run (Step 6); until then leave it and note "automated gates green, device run pending".

- [ ] **Step 5: Docs — terse pointers**

- `ADR-006`: Status `Proposed` → `Accepted`.
- `docs/specs/2026-08-31-plugin-architecture-and-phase-i.md` §12 row II: append "→ done — see [2026-09-01-phase-ii spec](2026-09-01-phase-ii-full-corpus-and-navigation.md); back/history stack cut, ADR-006."
- `docs/research/09-roadmap-effort.md` Phase II section: one line — "back/history stack cut (ADR-006 — magium-dev has none); `set()` write-back + special case #8 done; full-corpus sweep 8887/8887."
- `SUMMARY.md`: Decisions list + status line — add ADR-006 and "Phase II landed".
- `research-plan.md`: new running-log entry (newest at top) — what shipped, the 8887/8887 gate, decisions D1–D4, next = Phase III.

- [ ] **Step 6: On-device validation (owner)**

Deploy: `pwsh tools/deploy-kindle.ps1` (or the documented deploy step). On the
Kindle Paperwhite 12:
- New Game from a fresh state → play Book 1 through a checkpoint boundary → into Book 2 intro.
- Tap the header "Menu": 7 rows, middle 4 greyed; "Back to game" returns to the same page; "About" readable.
- "New game" from the menu with a save present → ConfirmBox → resets to `Ch1-Intro1`, achievements retained.
- Close the reader mid-Book-2 (tap "‹ Close"), reopen → resumes the same scene + variable state.
- An in-story `special:restart` choice → `Ch1-Intro1`, achievements retained.
- A `special:saves` "Load game" choice (e.g. a Book 2 stat-gate) → opens the menu.
- `koreader/crash.log` clean across the whole run.

Record the result in the `research-plan.md` entry and tick the spec §9 on-device
box; set the spec Status to `stable`.

- [ ] **Step 7: Commit**

```bash
git add docs/ SUMMARY.md research-plan.md
git commit -m "Phase II: close out — 8887/8887 parity, docs, ADR-006 accepted

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01B7RH9AwLKK5WkJbGUzhPpR"
```

---

## Self-Review

**Spec coverage:**

| Spec §  | Requirement | Task |
|---|---|---|
| §1.1.1, §4 | Scene `set()` write-back on scene entry | Task 1 |
| §1.1.2, §5 #8 | `B3-Ch01a-Crossbow` faithful-empty device-lock label | Task 2 |
| §1.1.3, §6 | In-game menu, full shell, later rows disabled (D2) | Task 3 |
| §1.1.4, §7 | `special:saves`/`stats` → menu; `checkpoint_*` no-op (D4); `restart` unchanged | Task 3 (steps 5); `restart` already live |
| §1.1.5, §8 | Full-corpus sweep 8887/8887 as the phase gate | Task 2 step 6, Task 4 step 2 |
| §1.1.6, §9 | On-device validation beyond ch1 | Task 4 step 6 |
| §1.2 | Achievement `"1"→"2"` bump stays Phase V | not implemented — correct (out of scope) |
| §2 D1 | No back/history stack | nothing to build; ADR-006 accepted in Task 4 |
| §5 #5/#9/#10/#11 | Stats-screen special cases stay declared-inert | no change — verified in Task 4 step 4 |
| §5 carry-forward #3 | `Ch11b-Hole` `<=` coercion confirmed in the real sweep | Task 4 step 3 |
| §10 | Open items for review | resolved by the approved spec + this plan's ponytail notes; the relative-`set()` quirk is shipped faithful with a `ponytail:` upgrade comment (Task 1 step 3) |
| §11 | Build order | Tasks 1→2→3→4 match §11's 1→2→3→4→5 |

**Placeholder scan:** no TBD/TODO; every code step has real code; test steps have real assertions; no "similar to Task N".

**Type consistency:** `scene.persist_effects(store, render_model)` — same signature in the Task 1 interface block, the test, the implementation, and the `main.lua` call site. `specials.HIDE_DEVICE_LOCK_TEXT` — same name in Task 2 interface, both tests, `specials.lua`, and the `scene.lua` branch. `Reader.on_menu` / `Reader:onTapMenu` — consistent across reader.lua steps and the `main.lua` `Reader:new` call.

**Ponytail deviations from the spec (deliberate, noted in Global Constraints):** no `engine/commit.lua` (2-line helper in `scene.lua` instead); no `commit_choice` extraction (`main.lua` `advance` untouched beyond the `special:` branch); no `ui/menu.lua` file and no `menu_spec.lua` (`Magium:openMenu` over `ButtonDialog`, near-zero logic); New Game via close+reopen rather than a new `reader:reload`.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-01-phase-ii-full-corpus-and-navigation.md`. Two execution options:

1. **Subagent-Driven (recommended)** — a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — tasks executed in this session via executing-plans, batch execution with checkpoints.

**Note:** CLAUDE.md says *"Do not use subagents for large tasks. Handle multi-step / multi-file work inline."* — so for this repo, **inline execution on a `feat/…` branch** is the house style unless the owner asks otherwise. Which approach?
