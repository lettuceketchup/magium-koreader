# Spec: Phase III — Saves (50 manual slots)

- **Status:** stable — automated gates green (busted **111/0**, `oracle-corpus` **8887/8887** unchanged, `savespage` + `reader` UI smokes green, headless emu load clean) + owner on-device sign-off 2026-09-02 ("All good"). Built on `feat/phase-iii-saves`.
- **Last updated:** 2026-09-02
- **Phase:** Implementation — design cycle 3 (roadmap [Phase III](../research/09-roadmap-effort.md#phase-iii--saves))
- **Sources:**
  - [`2026-08-31-plugin-architecture-and-phase-i.md`](2026-08-31-plugin-architecture-and-phase-i.md) §9 (save model), §12 row III — the architecture this fills in
  - [`../research/09-roadmap-effort.md`](../research/09-roadmap-effort.md) Phase III — the roadmap this spec opens
  - [`../decisions/ADR-007-saves-scope.md`](../decisions/ADR-007-saves-scope.md) — D1 (parity deltas)
  - [`../decisions/ADR-004-plugin-internal-architecture.md`](../decisions/ADR-004-plugin-internal-architecture.md) — the "III–V only add modules; `save/manager` takes an injected writer" obligation
  - `../../../magium-dev` @ `51f5aa9` — `public/scripts/saves.js`, `templates/saves.ejs`, `data/en/ui.json` (port target)
- **Related:** [`../../research-plan.md`](../../research-plan.md)

> Phase II shipped the full corpus, the in-game menu, and — pulled forward from
> this phase — the `checkpoint` blob with real `checkpoint_save` /
> `checkpoint_load`. What is left of "Saves": the 50 manual slots, a slot screen,
> and wiring the two entry points that Phase II left disabled. No `engine/`
> change; `oracle-corpus` stays at 8887/8887 untouched.

---

## 1. Scope

### 1.1 In scope

1. **50 manual save slots** `save0`–`save49`, one `Persist` file each under
   `<datadir>/magium/slots/NN.blob` (§3).
2. **`save/manager.lua` slot API** — `slots_meta` / `save_slot` / `load_slot` /
   `delete_slot`, over an injected `slotstore` adapter (§4).
3. **`ui/savespage.lua`** — a `Menu`-based 50-slot screen: save, load (with
   confirm on overwrite/delete), delete (§5).
4. **Wiring** — the in-game menu "Save / Load game" row and the in-story
   `special:saves` choice both open the slot screen (§6). Both were `enabled =
   false` / routed to the menu in Phase II.

### 1.2 Out of scope

- **Import / export** (per-slot, achievements, "all") — `magium-dev`'s
  clipboard-based transfer has no Kindle workflow; owner backs up files over
  USB/SSH. [ADR-007](../decisions/ADR-007-saves-scope.md).
- **Slot rename / custom name entry** — a slot's name is auto-set to the chapter
  header. No `InputDialog`. [ADR-007](../decisions/ADR-007-saves-scope.md).
- **The `{NN → {date,name}}` index in `state.lua`** that Phase I spec §9 lists —
  dropped; the screen reads slot files on open instead (§3, D2).
- Stats screen (IV), achievements screen + toast (V), settings (VI),
  `data/fr/` (VII), e-ink tuning + lazy parse (VIII).

### 1.3 Already done in Phase II (not Phase III work)

- `checkpoint` blob + `SaveManager:save_checkpoint` / `has_checkpoint` /
  `load_checkpoint`; the "Load from last checkpoint" menu row.
- `special:checkpoint_save` / `checkpoint_load` fully wired in `advance()`.

---

## 2. Decisions

| # | Decision | Where |
|---|---|---|
| D1 | **Import/export + rename cut; delete added.** Three deviations from `magium-dev`'s saves screen, all justified by "no clipboard / no comfortable keyboard on the device; owner has direct file access." | [ADR-007](../decisions/ADR-007-saves-scope.md) |
| D2 | **One `Persist` file per slot, no index.** `magium/slots/NN.blob`, codec `luajit`, fsynced. The saves screen reads the ≤50 small files when it opens (a deliberate user action, not launch — Phase I spec §9's launch-cost concern doesn't apply). Removes the index↔file drift the spec-§9 design carried. Add an index in Phase VIII only if screen-open lags on device. | this spec §3 |
| D3 | **Slot name = chapter header at save time.** `locale:header(v_current_scene)` (e.g. "Book 2 - Chapter 4"), or `"Magium"` if the scene has no chapter. Stored in the blob's `name`; shown as the slot's label. `magium-dev` defaults `name` to a UTC date string and lets you edit it — the header is strictly more useful and needs no keyboard. | this spec §5 |
| D4 | **Load = full currentState replace, then reopen the reader.** Exactly `magium-dev`'s `loadGameFromLocalStorage` (`saves.js:46`) + the checkpoint-load path already in `main.lua`: restore `slot.state ∪ live achievements` into the store, `flush_now`, `_reopenReader()` onto the slot's `v_current_scene`. Achievements are never overwritten by a load (own blob, parity). | this spec §4 |

---

## 3. Storage

```
<datadir>/magium/
  state              -- unchanged: currentState + achievements + checkpoint (one Persist blob)
  slots/
    0.blob  1.blob  …  49.blob     -- one Persist blob per occupied slot, codec "luajit"
```

Slot blob shape:

```lua
{ state = { v_* = "…" },   -- a currentState snapshot: everything except v_ac_*
  date  = os.time(),        -- number, for display + sort
  name  = "Book 2 - Chapter 4" }
```

`save/manager.lua` stops writing the vestigial `slots` key into the `state`
blob (`_write`, `save_checkpoint`) — no released data exists, so no migration.

## 4. `save/manager.lua` — slot API

New optional constructor key `slotstore`, same "plain functions, dot-called"
convention as the existing `writer`:

```lua
slotstore = {
  load   = function(n) return tbl_or_nil end,
  save   = function(n, tbl) end,
  remove = function(n) end,
}
```

| Method | Behaviour |
|---|---|
| `:slots_meta()` | `for n = 0, 49` → `slotstore.load(n)`; return `{ [n] = { name = b.name, date = b.date } }` for the ones that exist |
| `:save_slot(n, name)` | `local current = (self:_split())` (drops `v_ac_*`); `slotstore.save(n, { state = current, date = os.time(), name = name })` |
| `:load_slot(n)` | `local b = slotstore.load(n)`; `if not (b and b.state) then return nil end` (store untouched); else `self:_restore_snapshot(b.state)` |
| `:delete_slot(n)` | `slotstore.remove(n)` |

`_restore_snapshot(snap)` is extracted from the current `load_checkpoint` body
(restore `snap ∪ self` achievements, return `store:get("v_current_scene")`);
`load_checkpoint` and `load_slot` both call it.

Autosave is untouched: `_write` / `touch` / `flush_now` never reference
`slotstore`. A slot save never schedules or cancels the debounce timer.

## 5. `ui/savespage.lua`

`Menu`-based, `covers_fullscreen`. Constructor: `slots_meta`, `on_load(n)`,
`on_save(n)`, `on_delete(n)`, `on_close`.

- 50 items. Occupied: `text = meta.name`, `mandatory = os.date("%Y-%m-%d %H:%M",
  meta.date)`. Empty: `text = "Slot N  —  (empty)"`, no `mandatory`.
- `onMenuSelect(item)` opens a `ButtonDialog`:
  - empty → **Save here** · Cancel
  - occupied → **Load** · **Overwrite** · **Delete** · Cancel
  - **Overwrite** and **Delete** each go through a `ConfirmBox` first.
- Parent callbacks do the work and then hand back a fresh `slots_meta`;
  the page refreshes in place with `Menu:switchItemTable`.
- Strings: reuse `savesHeaderText`, `savesExplanationText`, `savesSaveText`,
  `savesLoadText` from `ui.json` via `locale:str`. "Overwrite", "Delete",
  "(empty)", and the two confirm prompts go through `_()` — no `ui.json` edit.

## 6. Wiring (`main.lua`)

- `slot_store()` adapter beside `state_writer()`: `lfs.mkdir` the `slots/` dir,
  return `{ load, save, remove }` over `Persist:new{ path = dir.."/"..n..".blob",
  codec = "luajit" }`. Pass `slotstore = slot_store()` into `SaveManager.new`.
- `Magium:openSaves()` — build `SavesPage`; `on_save(n)` →
  `self.save:save_slot(n, self.locale:header(self.store:get("v_current_scene")) or "Magium")`;
  `on_load(n)` → mirror `Magium:loadCheckpoint` (`load_slot` → `flush_now` →
  `_reopenReader`); `on_delete(n)` → `delete_slot`. Each emits
  `trace.event("save", { op = "slot_"..x, n = n })`.
- `openMenu()` — the `"Save / Load game"` row gets `callback = act(function()
  self:openSaves() end)` (drop `enabled = false`).
- `advance()` `special == "saves"` → `openSaves()` instead of `openMenu()`.

## 7. Parity gate

- `mgm.sh oracle-corpus` → **8887/8887, 0 DIFF** — no `engine/` file changes, so
  this is a regression check, not a target to move.
- `luajit spec/run.lua` green incl. the new slot cases.
- `mgm.sh test-ui spec/ui/savespage_smoke.lua` green.

## 8. Exit criteria

1. All automated gates above green.
2. Emulator: save/load round-trips via both the menu row and a `special:saves`
   choice; overwrite and delete each confirmed once.
3. Device: owner playthrough — save, play on, load, confirm the reader returns to
   the saved scene; saves survive a KOReader restart and suspend/resume; the
   saves screen opens without a noticeable delay (validates D2).
4. Owner sign-off → merge to `main` (`--no-ff`); update the memory file + running
   log; one-line notes in Phase I spec §9 / §12 and roadmap Phase III.
