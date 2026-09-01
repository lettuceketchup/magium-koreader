# Spec: Phase IV — Stats & the stat-allocation screen

- **Status:** in review — automated gates green (busted **114/0**, `oracle-corpus` **8887/8887** unchanged, `statspage` + `savespage` + `reader` UI smokes green, headless emu load clean). Built on `feat/phase-iv-stats`. Owner on-device sign-off pending.
- **Last updated:** 2026-09-03
- **Phase:** Implementation — design cycle 4 (roadmap [Phase IV](../research/09-roadmap-effort.md#phase-iv--stats--stat-checks))
- **Sources:**
  - [`2026-08-31-plugin-architecture-and-phase-i.md`](2026-08-31-plugin-architecture-and-phase-i.md) §12 row IV — the architecture this fills in
  - [`../research/01-magium-analysis.md`](../research/01-magium-analysis.md) §5 (stats system), §10 (special cases #5, #9, #10, #11)
  - `../../../magium-dev` @ `51f5aa9` — `templates/stats.ejs`, `public/scripts/stats.js`, `src/renderers.js:renderStats`, `data/en/ui.json` (port target)
- **Related:** [`../../research-plan.md`](../../research-plan.md)

> The stat-**check display** half of "stats" (the `[ … check successful … ]`
> lines) shipped in Phase I/II and is oracle-clean. This phase adds the
> interactive **stats screen** that spends `v_available_points`. No `engine/`
> render-pipeline change — `oracle-corpus` stays 8887/8887.

---

## 1. Scope

### 1.1 In scope

1. **`ui/statspage.lua`** (new) — a fullscreen `KeyValuePage`: available points,
   one row per stat (`value / max`), tap an allocatable row to spend a pending
   point, then `Confirm changes` / `Cancel changes` / `Return to game`.
2. **`engine/specials.lua`** — three pure display gates: `maximized_stats`
   (#5), `stats_show_magic_rows` (#9), `stats_show_book3_rows` (#10).
3. **`main.lua`** — `Magium:openStats()`; the `special:stats` dispatch (was an
   `InfoMessage` stub); a **Stats** row in the in-game menu; the "Full immersion"
   unlock (#11).

### 1.2 Out of scope

- The "Full immersion" **toast** — Phase V (`ui/toast.lua`). Phase IV persists
  `v_ac_ch6_immersion`; every achievement's toast lands together in V.
- The `maximized` **count-up animation** — cut. It is cosmetic; its end state is
  the real stat values. Only the achievement side-effect is ported.
- `initStats`' zero-initialisation writes — unnecessary; unset stat vars read as
  `0` (and `v_max_stat` as `3`) directly.

## 2. The port target (magium-dev @ `51f5aa9`)

`stats.ejs` + `stats.js` + `renderStats`:

- **Rows**, fixed order:
  - `magical_power`, `magical_knowledge` — only if `v_b3_ch11_magic` is set (JS
    `if (v_b3_ch11_magic || 0)`; `"0"` is truthy, so the gate is "set and not
    empty string"). **Not allocatable**; each displays the value of
    `v_b3_ch11_magic` itself. (#9)
  - Always: strength, toughness, agility ("Speed"), reflexes, hearing,
    perception ("Observation"), ancient_languages, combat_technique, premonition.
  - bluff, magical_sense, aura_hardening — only if `sceneAfter(v_current_scene)`:
    regex `/(B(?<book>[0-9]*)-)?Ch(?<chapter>[0-9]*)[a-c]-.*$/` (the `[a-c]` is
    **mandatory**), `book == "3"` and `chapter >= 4`. (#10)
- Allocatable row shows `value / max`, `max = v_max_stat || 3`.
- `updateStat`: if `current < max` and `available_points > 0` → `+1` / `-1`.
  **Increment only.** DOM-only until confirmed.
- `Confirm changes` writes every row + `available_points` to `currentState` and
  reloads (stays on the screen). `Cancel changes` reloads (drops pending).
  `Return to game` returns **without** persisting — unconfirmed pending is lost.
- **First open**: a one-time tutorial modal (`stats_intro_seen` cookie) —
  `statsIntroductionText` + a mock failed and a mock successful check line.
- **#5 / #11**: at `Ch6-Eiden-vs-dragon` with `v_maximized_stats_used == "1"`
  the screen unlocks "Full immersion" (`v_ac_ch6_immersion = 1`) if not already.

## 3. Design

### 3.1 `ui/statspage.lua`

`KeyValuePage:extend`. Constructed with a **snapshot** of the variable store, the
current `scene_id`, the `Locale`, and two callbacks:

```
StatsPage:new{
  view = <flat v_* snapshot>, scene_id, locale,
  on_confirm = function(pending_map),   -- { [v_key]=final_int, .., v_available_points=n }
  on_close   = function(),              -- Return to game
}
```

- Pending spends live in the widget: `self.pending = { [key] = int }`,
  `self.spent`. Effective value = `pending[key] or tonumber(view[key] or 0)`;
  effective points = `base_points - spent`.
- `kv_pairs`: available-points row (no callback) → stat rows (`"2 / 3"`;
  allocatable ones carry `callback = _bump(key)`) → `Confirm` row → `Cancel` row.
  Row count is stable for the life of the screen (scene fixed, gates fixed).
- `_bump`: `updateStat` parity — no-op at `>= max_stat` or `<= 0` points.
- `_confirm`: `on_confirm(map)`, then fold `map` into `self.view`, reset pending,
  refresh — stays on the screen (magium-dev reloads).
- `_cancel`: reset pending, refresh.
- `Return to game` = the page's normal close (X / Back / swipe → `on_close`).
- First open: a `TextViewer` with `statsIntroductionText` + the two mock lines,
  gated by `G_reader_settings` key `magium_stats_intro_seen`.

### 3.2 `main.lua`

- `Magium:openStats()` — runs the #5/#11 unlock, builds `StatsPage` over
  `store:snapshot()`. `on_confirm` replays the pending map through `store:set`
  (absolute int strings — no `+N`) and `save:flush_now("stats")`. `on_close`
  calls `_reopenReader()` (the existing checkpoint/slot-load pattern) so a
  confirmed spend that opens a stat-gated choice on the `-spent` scene shows.
- `special:stats` dispatch → `UIManager:nextTick(function() self:openStats() end)`
  (`v_current_scene` is already moved to the `-spent` scene by the choice's
  `set_vars`).
- In-game menu gets a **Stats** row above Achievements (the persistent
  `STATS`-button equivalent).

## 4. Tests

- `spec/engine/specials_spec.lua` — the three gates, boundary cases
  (`B3-Ch04a-*` yes / `B3-Ch3a-*` / `B3-Ch4-*` no; magic set / unset / `""`).
- `spec/ui/statspage_smoke.lua` — against the real `KeyValuePage`: row
  count/labels/values, magic + book-3 gates, `_bump` (raise + cap + 0-points
  no-op), `Confirm` map contents, `Cancel` clears pending. Auto-run by `test-ui`.
- Regression: `oracle-corpus` must stay **8887/8887** (no render-pipeline change).

## 5. Exit criteria

- [ ] Automated gates green (see Status).
- [ ] Owner on device: menu → Stats; spend → Cancel reverts; spend → Confirm
      persists across a KOReader restart; Return to game re-renders the scene;
      an in-story "Invest points now" choice lands on the `-spent` scene with
      the screen over it.
