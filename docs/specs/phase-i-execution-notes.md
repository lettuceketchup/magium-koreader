# Phase I execution notes — controller rulings (archived from the SDD ledger)

- **Status:** stable — archival. Phase I is complete (spec §11.2 signed off 2026-09-01).
- **Last updated:** 2026-09-01
- **Phase:** Implementation — design cycle 1 (Milestone 0 + Phase I)
- **Sources:** the SDD execution ledger
  `.superpowers/sdd/2026-08-31-magium-plugin-milestone-0-phase-i/progress.md`
  (git-ignored; deleted at branch-finish — this file is what survives it),
  `../magium-dev` @ `51f5aa9`
- **Related:** [`2026-08-31-plugin-architecture-and-phase-i.md`](2026-08-31-plugin-architecture-and-phase-i.md)
  (esp. §12.1 carry-forward), [ADR-005](../decisions/ADR-005-debug-trace-toggle.md)

> Phase I was executed under subagent-driven development against
> [the Milestone 0 + Phase I plan](../superpowers/plans/2026-08-31-magium-plugin-milestone-0-phase-i.md).
> Where a plan/brief step was defective or conflicted with the spec, the
> controller made a **ruling** (spec is the authority). Those rulings — and the
> reasoning that could matter to a later phase — lived only in the SDD ledger,
> which is git-ignored and deleted when the branch finishes. This file preserves
> them. All rulings are already reflected in the merged Phase I code; this is a
> record, not a task list.

## Rulings

Numbered as in the ledger (1–5, 7–14; no Ruling 6 was recorded).

| # | Ruling | Cost if wrong |
|---|---|---|
| 1 | **Pagination `geometry` shape** = `{width, prose_height, first_page_offset}` (plan Tasks 16/17, mutually consistent), not spec §8.2's illustrative `{width, height, line_height, header_h, indicator_h}`. §8.2's list was illustrative. | Rename fields in 2 plan-authored files. |
| 2 | **`advance()` must call `save:on_achievement_unlocked()`** (immediate fsync) when a choice's `set_vars` introduces a new `v_ac_*` key, else `save:touch()` (debounced). Spec §9 + C1: "`v_ac_*` flushes immediately on unlock." Task 19 provided the method; Task 20's brief only called `touch()`. | Harmless extra fsync, or a lost achievement on crash (the exact risk the spec names). |
| 3 | **`render_model.set_variables` / `achievements` write-back is DEFERRED to Phase II.** `magium-dev` `main.ejs:1-3,66-67` persists surviving scene `set()` effects and bumps displayed achievements `"1"→"2"`; Phase I does not. Safe because `ch1.magium` has **0** `set()` constructs and its 3 achievements unlock via choice `set_vars` (which `advance()` already persists). Keep `advance()` structured so the write-back is a clean 1-block addition. → **spec §12.1 item 1.** | If some ch1 path needed it: ~4 lines in `main.lua`/`reader.lua`. Per-scene oracle diff would not catch it; the emulator playthroughs would. |
| 4 | **Task 14 oracle-diff expectation is the actual printed count** (96/96 ch1 matrix — the plan's "72" and "78" were both stale), re-verified fresh 2026-09-01. | None — executor checks the printed count. |
| 5 | **All oracle-consuming steps use `tools/mgm.sh`** (`diff` / `oracle-diff-lua` / `with-oracle`), which polls oracle readiness up to 25 s and tears down after. The plan's `node main_node.js 3000 & sleep 2` is too short (4–8 s cold) and leaks the process across `wsl.exe` calls. | None — `mgm.sh` is strictly more robust. |
| 7 | **`engine/parser.lua` `_match_set`**: (a) corpus `set()` values have **no** space after the comma (`set(v_x,1)`, all 594 lines) — the brief's spaced test data was wrong; (b) the R3 multi-digit guard must actually assert (`if after_comma:match("^[%+%-]?%d%d") then error(...)`), not be dead code behind a pattern that already failed to match. No `%s*` tolerance (parity). | Task 4's full-corpus 594-`set()` count is the real parity gate and catches any divergence. |
| 8 | **`engine/store.lua` `v_ac_*` freeze**: the latch is `if data[key] ~= 2` for `v_ac_*` keys **only**, blocking **all** writes (incl. `+N`) once the value is (loosely) `2` — per `magium-dev` client `public/scripts/utils.js` `storeVariable`/`storeItem` (the authoritative write path). The plan's `"2"→"1"`-only, unscoped check was both too narrow and leaked non-`ac` vars. Consolation check is `== 5` (parity, though effectively dead — the freeze caps `v_ac_b3_ch9_consolation` at 2 first). | `+N`/`−N` and freeze paths are small and directly tested; the consolation branch is dead either way. **See caveat below.** |
| 9 | **`ui/pagination.lua` `paginate` splits an over-budget block at word boundaries** (`fit_words` helper + 3-way inner branch), per spec §8.2 "accumulate paragraph lines". The brief's block-level-only packing contradicted its own test #2 and would clip long prose off an e-ink page after a font-size bump. Unsplit path stays byte-identical. | A whitespace-word split can land ~1 line short/over vs the real `TextBoxWidget` wrap — harmless uneven fill; `reader.lua` re-paginates on resize. **See caveat below.** |
| 10 | **`special:restart` (and invalid-resume) preserve `v_ac_*`** via a shared `reset_to_intro(store)` helper, not spec §8.1's `store:restore({})` shorthand. Parity: `magium-dev` `clearState()` rewrites only `currentState`; the achievements blob is permanent across playthroughs (C1). | A stale "seen" flag persists a restart — harmless, matches the oracle. |
| 11 | **`openReader()` guards `story:get_scene(DEFAULT_SCENE)` after `_ensureLoaded`** (InfoMessage + return), and `_ensureLoaded` marks loaded only on parse success. Closes the `scene.render(nil)` crash path (§11.2). Recorded because the brief's structure omitted it. | Traceback in `crash.log` on a truncated/partial parse instead of a clean error message. |
| 12 | **The parsed `story` is a module-scope upvalue** (`shared_story` / `shared_loaded`), not `self.story` per-instance — delivers spec §7.1 "parse once per session" (KOReader builds a fresh plugin instance per UI). Safe: the parsed story is immutable/pure after `preload()`. Same treatment applied to `Locale` (M5). | Shared mutable module state — revisit if a later feature mutates the story object. |
| 13 | **Menu toggle uses `flipNilOrFalse`** (with `checked_func → isTrue`), not `flipNilOrTrue`. Verified vs `../koreader/frontend/luasettings.lua:143-163` @ `9192014`: `flipNilOrFalse` is the default-OFF helper (nil/false → **true**, true → nil); `flipNilOrTrue` never writes `true` and so could never check the box. | None — this is the documented KOReader idiom. |
| 14 | **`_configureTrace()` runs at the top of `openReader()`, not in `init()`.** `init()` is per-UI-instance, so an `init()` placement spawns a session-header-only trace file on every FileManager/ReaderUI build and the prune-to-5 then deletes the file holding real play data. `openReader()` placement = lazy file, accurate help text, mid-session toggle honoured on next open (ADR-005 / §9.2). | A re-scan + file-open per `openReader()` when tracing is on (cheap; fully guarded off when disabled). |

## Ledger self-review verdict

- **13/14 rulings sound as written** (1–5, 7–14; Rulings 8, 10, 12, 13 and the
  D1 basis independently source-verified).
- **Ruling 9** — conclusion holds (word-boundary split is correct), but its
  "whole paragraph taller than a page" measurement premise was off: on the ch1
  corpus the max block is ~942 chars vs a ~1300px budget, so `fit_words` is
  effectively unreachable there. Cost of the mis-measurement: zero. Its deferred
  minor (a lone internal `<br/>`'s `\n` collapses to a space in a split tail)
  is even less urgent than the ledger first thought — revisit only if a later
  chapter has a page-spanning paragraph with internal single-`<br/>` breaks.
- **Ruling 8** — correct, but the "freeze caps `v_ac_b3_ch9_consolation` at 2"
  reasoning **silently depends on `v_ac_b3_ch9_consolation` not being an
  `achievement()` variable** (it isn't — it's driven by `+1` `set_vars`). If it
  were, Ruling 3's deferred write-back (which bumps displayed `achievement()`
  flags to `"2"`) would reopen the consolation-trigger divergence. **Carry into
  the Phase II 13-special-case audit** (special case #12, spec §6 step 10).

## Mid-execution scope addition

Phase I scope was extended **once**, at the owner's request during execution: the
optional **debug action-trace** (`util/trace.lua` + a "Record debug log" menu
toggle, off by default). Recorded as
[ADR-005](../decisions/ADR-005-debug-trace-toggle.md) (runtime toggle chosen over
build variants) and spec §9.2. It made the owner's Task 21 device playthrough
itself traceable.

## Where the forward-relevant items live now

- Render-model → store write-back; `B3-Ch01a-Crossbow` device-lock suppression;
  `v_hearing <= 4` unmatched-operator stat check; achievement-text norm — all in
  **spec §12.1** (Phase I → II carry-forward).
- Ruling 8's `achievement()`-variable caveat — spec §12.1 item 1 already
  records the "not an `achievement()` variable → write-back has no bearing on
  it" nuance; the "Ledger self-review verdict" section above states *why* that
  nuance is load-bearing, for the Phase II special-case-#12 audit.
