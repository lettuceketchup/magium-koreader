# 03 — KOReader plugin platform & constraints

- **Status:** draft (source-grounded first pass complete 2026-08-31 against the
  v2026.07.1 tree; e-ink feel + Windows dev loop still need a spike)
- **Last updated:** 2026-08-31
- **Phase:** 2
- **Sources:** KOReader source, sibling checkout `../koreader` @ **`v2026.07.1`**
  (commit `9192014`) — see [`../../reference/koreader-notes.md`](../../reference/koreader-notes.md);
  `frontend/**`, `plugins/hello.koplugin`, `plugins/japanese.koplugin`,
  `plugins/vocabbuilder.koplugin`, `doc/{Events,Building,Building_targets,DataStore}.md`,
  `datastorage.lua`, `kodev`, `platform/kindle/koreader.sh`. Secondary:
  <https://koreader.rocks/doc/> (API mirror, tracks `master`); `koreader-base`
  build config; `kbarni/frotz.koplugin` (a shipping "narrative + choices as a
  fullscreen KOReader UI" plugin). On-device baseline from [`00-overview.md`](00-overview.md).
- **Citation note:** every load-bearing claim here cites a line in the pinned
  `../koreader` tree (reproducible: `git checkout v2026.07.1`). The few web
  sources (frotz.koplugin, koreader-base build config, koreader.rocks) are
  supplementary and were fetched 2026-08-31; `web.archive.org` captures are
  **pending** (this session's fetch tool can't reach the Wayback Machine — an
  archival pass is a loose end, tracked implicitly here).
- **Related:** [`00-overview.md`](00-overview.md), [`01-magium-analysis.md`](01-magium-analysis.md),
  [`04-constraints-budget.md`](04-constraints-budget.md), [`05-prior-art.md`](05-prior-art.md),
  [`07-risks-open-questions.md`](07-risks-open-questions.md) OQ-002/OQ-007/OQ-012

> Goal: know what the plugin platform provides for rendering prose + a choice list
> + menus + a stats panel, how persistence and text/e-ink rendering work, and how
> to build/deploy/debug on the Paperwhite. Anything device-dependent is confirmed
> by a [spike](../spikes/), not by docs alone.
>
> **Bottom line for the port:** KOReader gives us everything the Magium UI needs
> off the shelf — a plugin is a Lua table that `:extend`s `WidgetContainer`,
> `UIManager:show()` puts any widget fullscreen, `TextBoxWidget`/`ScrollTextWidget`
> lay out reflowed prose (C-accelerated shaping), `ButtonTable`/`Menu` render a
> vertical choice list, `LuaSettings`/`Persist` handle saves. The real work is
> learning the widget/event/refresh idioms, not missing capability. A prior plugin
> (`frotz.koplugin`) already does exactly the "styled scrolling transcript + input
> line, fullscreen, e-ink" shape we need.

---

## 0. Device baseline (confirmed on-device 2026-08-31 — [`00-overview.md`](00-overview.md))

- **Kindle Paperwhite 12th gen (2024)** = KOReader model **`KindlePaperWhite6`**
  (`../koreader/frontend/device/kindle/device.lua:1129`, dispatched from the
  serial-number device code, `:2205`). FW **Kindle 5.19.5**, MediaTek dual-core
  1 GHz (`isMTK = yes`), **956.9 MB RAM** (~497 MB available), 10.6 GB free,
  7″ / 300 dpi e-ink (1236×1648), USB-C.
- **KOReader v2026.07.1, official release build**, `koreader-kindlehf` (FW ≥ 5.16.3).
  Idle RSS ~32.7 MB. Ships LuaJIT (§2). `canHWDither = no`,
  `canDoSwipeAnimation = yes`, framebuffer driver `framebuffer_mxcfb`, and the
  MTK "fast mode" is force-enabled at init to stop the driver silently promoting
  refreshes to REAGL (`device.lua:1775-1790`).
- **Stability:** running fine here; the #13307-class launch crashes are not
  occurring (release build on 5.19.5). OQ-009 narrowed to "under plugin load".
- **RAM is not the constraint** it was feared to be — see [`04`](04-constraints-budget.md).
  The platform study assumes comfortable memory headroom and focuses on UI fit,
  responsiveness, and I/O hygiene.

---

## 1. Plugin anatomy *(2.1)*

### 1.1 On disk

A plugin is a directory named `<name>.koplugin` containing at least `main.lua`;
`_meta.lua` is a lightweight metadata file loaded on its own when the plugin is
disabled (`../koreader/frontend/pluginloader.lua:203-225`). Discovery scans
`koreader/plugins/` (bundled) **and** `<data-dir>/plugins/` (user, auto-registered
as `extra_plugin_paths`), matching any dir ending `.koplugin`
(`pluginloader.lua:174-228`). On a Kindle the user path is
`koreader/plugins/` under the KOReader install (§4). `package.path` /
`package.cpath` are extended per-plugin, so `require("foo")` resolves a `foo.lua`
next to `main.lua`, and `lib/?.so` is on the C path (`pluginloader.lua:242-243`).

```
magium.koplugin/
  _meta.lua      -- { fullname = _("Magium"), description = _([[...]]) }
  main.lua       -- returns the plugin module table
  engine.lua     -- our JS→Lua port of magium-dev (require("engine"))
  data/en/*.magium ...
```

`_meta.lua` (from `plugins/hello.koplugin/_meta.lua`):

```lua
local _ = require("gettext")
return {
    fullname = _("Hello"),
    description = _([[This is a debugging plugin.]]),
}
```

### 1.2 The module

`main.lua` returns a class table produced by `WidgetContainer:extend{…}`
(`plugins/hello.koplugin/main.lua:19-22`). `WidgetContainer` →
`Widget` → `EventListener` (`frontend/ui/widget/container/widgetcontainer.lua:19`,
`frontend/ui/widget/widget.lua:17`). Key fields:

| Field | Meaning | Source |
|---|---|---|
| `name` | internal id; instance is reachable as `self.ui[name]` | `pluginloader.lua:574` |
| `is_doc_only` | `true` → only instantiated inside the reader (a document is open); `false` → also in the File Manager (`FileManager` skips doc-only plugins) | `hello.koplugin/main.lua:25`; `frontend/apps/filemanager/filemanager.lua:419` |
| `fullname`, `description` | merged in from `_meta.lua` | `pluginloader.lua:253-262` |
| `disabled` | returning `{ disabled = true }` from `main.lua` skips load | `hello.koplugin/main.lua:9-11`, `pluginloader.lua:247` |

`Widget:new` calls `self:_init()` then `self:init()` on construction
(`widget.lua:40-48`); plugins implement **`init()`**. `PluginLoader:createPluginInstance`
`pcall`s `plugin:new(attr)` so a throwing `init()` just logs and disables the
plugin (`pluginloader.lua:479-488`). Every `on*` method is wrapped in a sandbox
that turns errors into logged stack traces instead of crashes
(`pluginloader.lua:158-164`).

### 1.3 Registering an entry point

Three ways in, all shown by `hello.koplugin`:

1. **Main-menu item** — in `init()` call `self.ui.menu:registerToMainMenu(self)`
   (`hello.koplugin/main.lua:31`), then define `addToMainMenu(menu_items)`:

   ```lua
   function Hello:addToMainMenu(menu_items)
       menu_items.hello_world = {
           text = _("Hello World"),
           sorting_hint = "more_tools",         -- which submenu; e.g. "more_tools", "tools", "search", "main"
           callback = function() UIManager:show(InfoMessage:new{ text = _("Hello, plugin world") }) end,
       }
   end
   ```

   `registerToMainMenu` exists on both `FileManagerMenu`
   (`frontend/apps/filemanager/filemanagermenu.lua:1133`) and `ReaderMenu`
   (`frontend/apps/reader/modules/readermenu.lua:529`). Placement is by a named
   *menu order* table (`frontend/ui/menusorter.lua`,
   `frontend/ui/elements/filemanager_menu_order.lua`); `more_tools` is a real
   bucket (`filemanager_menu_order.lua:136-138`).

2. **Dispatcher action** (assignable to a gesture, a hardware key, the QuickMenu,
   or a profile) — declare it in `onDispatcherRegisterActions()`:

   ```lua
   function Hello:onDispatcherRegisterActions()
       Dispatcher:registerAction("helloworld_action",
           {category="none", event="HelloWorld", title=_("Hello World"), general=true})
   end
   function Hello:onHelloWorld() ... end     -- the event handler
   ```

   (`hello.koplugin/main.lua:24-26,54-58`; `Dispatcher:registerAction` at
   `frontend/dispatcher.lua:660`). Call it once from `init()`.

3. **Event handlers** — any `on<EventName>(self, ...)` method. Events propagate
   **children first, in array order**; returning `true` consumes the event
   (`doc/Events.md:27-57`, `widgetcontainer.lua:80-107`). `UIManager:sendEvent`
   goes to the top window; `broadcastEvent` to all. This is how the plugin reacts
   to document/app lifecycle and to input.

### 1.4 Optional lifecycle hooks

`stopPlugin([force])` (for plugins holding external processes/resources — e.g.
SSH, Terminal) and `deletePluginSettings()` / the `settings_file` / `settings_key`
fields (so the plugin manager can offer "disable and delete settings")
(`pluginloader.lua:490-564`). Not needed for a self-contained story engine.

---

## 2. Lua environment *(2.2)*

- **LuaJIT**, Lua **5.1** language level. `koreader-base` @ `6e4bc81` builds it from
  upstream `github.com/LuaJIT/LuaJIT` commit `3c4f9fe` on the **`v2.1`** branch
  (merged 2026-07-11); it self-identifies as `"LuaJIT 2.1.ROLLING"`,
  `LUAJIT_VERSION_NUM 20199` (`koreader-base` `thirdparty/luajit/CMakeLists.txt` @
  `6e4bc81`; `LuaJIT/src/luajit_rolling.h` @ `3c4f9fe`). **Not** the OpenResty
  fork. → **closes the "exact LuaJIT build string" item** carried over from Phase 0
  (research-plan task 0.1 / OQ-010 tail).
- Practical consequences: LuaJIT = Lua 5.1 syntax/stdlib **plus** a few 5.2/5.3
  borrows (`goto`, `table.move`, `string.buffer`) and the **FFI**. No integer
  type (all numbers are doubles — fine, Magium values are small ints). No native
  `utf8` library; KOReader ships its own UTF-8 helpers (`ffi/utf8proc`,
  `util.hasCJKChar` etc., used all over `textboxwidget.lua`). String patterns, not
  full regex — the `.magium` parser port must translate the JS regexes to Lua
  patterns or a hand tokenizer (tracked for spike B; [`02` §4](02-magium-format-spec.md#4-parser-risk-list)).
- **Single OS process, single Lua state, cooperative scheduling.** No threads
  (`04` §1). Long work (a cold parse of 54 files, or re-evaluating the 490 KB
  `b3ch4a.magium:251` condition — [`02` §4 R7](02-magium-format-spec.md#4-parser-risk-list),
  OQ-011) blocks input and redraw unless chunked. Two tools for that:
  `UIManager:scheduleIn(delay, fn)` / `nextTick` to slice work across ticks, and
  the **`Trapper`** module (`frontend/ui/trapper.lua`) which wraps a job in a
  coroutine so it can show progress and be interrupted
  (`trapper.lua:1-40`; used by e.g. the exporter/newsdownloader plugins).
- Bundled libraries of interest: `rapidjson` (`require("rapidjson")`), SQLite3 via
  `lua-ljsqlite3` (`doc/DataStore.md:19-63`, used by `statistics`/`vocabbuilder`),
  `zstd` and `lua-zstd`, `string.buffer` (LuaJIT serializer), `bitser`, `md5`,
  `sha2`, `lfs` (`libs/libkoreader-lfs`), `ffi/util` (has `template` = the i18n
  `T()` / `%1` substitution). LZ-String (what `magium-dev` uses client-side) is
  **not** bundled — the port picks its own save encoding (§4; `Persist` codecs are
  the natural choice).
- GC: LuaJIT's incremental collector. Holding ~20–30 MB of parsed tables is fine
  on paper but GC pause behaviour under that load is a spike-D measurement (OQ-001).

---

## 3. UI toolkit inventory *(2.3)*

The widget toolkit is `frontend/ui/widget/` (+ `container/`). A widget knows its
size (`getSize`) and can paint to a BlitBuffer (`paintTo`); `UIManager` owns the
window stack, the paint/refresh queues, and the event pump
(`frontend/ui/uimanager.lua`). `UIManager:show(widget[, refreshtype])` pushes any
widget; `UIManager:close(widget)` pops it. Containers compose:
`FrameContainer` (border/background + records its own screen `dimen` each paint),
`VerticalGroup`/`HorizontalGroup`, `CenterContainer`, `MovableContainer`,
`ScrollableContainer`, `InputContainer` (gesture/key binding base).

| Need (Magium) | Off-the-shelf widget(s) | Notes / constraints (source) |
|---|---|---|
| **Scrollable block of prose** (a scene's paragraphs) | `TextBoxWidget` (static) → `ScrollTextWidget` (adds a scrollbar + pan/tap paging) → wrapped by `TextViewer` for a titled fullscreen viewer | `TextBoxWidget` does line-wrapping + optional justification; heavy text shaping is done in C via the optional `xtext` module (`textboxwidget.lua:1-13,238,307`). Handles multi-page text by row offset — no hard length cap seen, but *very* long strings pay a one-time measure cost. `TextViewer` binds **Back→Close**, **PgBack/PgFwd→scroll**, tap-in-corner→close (`textviewer.lua:128-146,519-550`), and auto-adds a bottom **Close / Find** button row unless you pass `buttons_table` (`textviewer.lua:76-78,384-392`). `text_type` presets pick font size / justification (`textviewer.lua:81-92`). |
| **Vertical list of tappable choices** | `ButtonTable` (grid of `Button`s, one per row) inside a `FrameContainer`; or `ButtonDialog` (`buttons = {{...}}`, a modal card); or `Menu` (paged list, `items_per_page_default = 14`, hardware-key + shortcut navigation, `fullscreen` mode) | `ButtonDialog` grid syntax is one inner table per row (`buttondialog.lua:1-40`). `Menu` is `FocusManager`-based, supports `close_callback`, `onMenuSelect`/`onMenuChoice`, paging, and `is_borderless`/`is_popout=false` for embedding (`menu.lua:583-733,1364-1391`). For 2–6 choices `ButtonTable` is the closest fit; `Menu` suits long lists (saves, achievements). |
| **Modal menu / confirm / prompt** | `ButtonDialog`, `ConfirmBox`, `MultiConfirmBox`, `InfoMessage` (toast-ish), `Notification` (transient top bar), `InputDialog` (text entry, e.g. save name) | `InfoMessage` is the one-liner popup used by `hello.koplugin`. `Notification` fits the Magium **achievement toast**. |
| **Stats panel** (14 stat vars + values) | `KeyValuePage` — paged `{ "Label", "Value" }` rows, `"---"` → divider, per-row `callback` (`keyvaluepage.lua:1-18`) | Exactly the shape of the Magium stats screen. `Menu` is the fallback if we want richer rows. |
| **Book / Chapter header** | `TitleBar` (`frontend/ui/widget/titlebar.lua`), used by `TextViewer`/`Menu` | Render `getHeaderFromId` output ([`01` §9](01-magium-analysis.md#9-localization-task-19)) here. |

**Prior-art check (OQ-002/OQ-007):** `kbarni/frotz.koplugin` ships a custom
`GameView` widget that `:extend`s **`FrameContainer`** and hosts a `StyledScroll`
(word-wrapped, multi-face styled transcript) plus an `InputText`+Send row in a
`HorizontalGroup`; it intercepts `KeyPress` for page-advance, lays a tap overlay
over the readable area, refreshes with `UIManager:setDirty(self, "ui")` for
content changes and `"full"` only on keyboard toggle, and autosaves synchronously
in `onClose()`
(`kbarni/frotz.koplugin` `main.lua`, `gameview.lua` — fetched 2026-08-31,
<https://github.com/kbarni/frotz.koplugin>). This is direct evidence the widget
model fits a "narrative + choices, fullscreen, e-ink" UI; a small custom
container over `ScrollTextWidget` + `ButtonTable` is the likely Magium shape.
Whether to reuse off-the-shelf `TextViewer`+`ButtonDialog` or build a `GameView`
-style container is a **spike A** call.

---

## 4. Persistence *(2.4)*

### 4.1 Where data lives

`DataStorage:getDataDir()` is the KOReader data root: `KO_HOME` if set, else
platform-specific, else `"."` (`../koreader/datastorage.lua:16-49`). On a Kindle
`KO_HOME` is **not** set and `koreader.sh` `cd`s into the install dir before
launch (`../koreader/platform/kindle/koreader.sh:8,25,125`), so the data dir **is
the KOReader install dir** — `/mnt/us/koreader`. Standard subdirs are created at
startup: `settings/`, `data/`, `cache/`, `plugins/`, …
(`datastorage.lua:97-123`). A plugin's own files belong either next to `main.lua`
(read-only story data — bundle `data/en/*.magium` here) or, for user-writable
saves, under `<data-dir>/` (e.g. a `magium/` folder, or a settings file in
`settings/`). `DataStorage:getSettingsDir()` and `getDataDir().."/plugins/"` are
both fair game; `vocabbuilder` keeps a SQLite DB in `settings/`.

### 4.2 The persistence APIs

| API | Format | Use | Source |
|---|---|---|---|
| **`LuaSettings`** (`require("luasettings"):open(path)`) | a `return { … }` Lua file (human-readable), written atomically with a `.old` backup | key/value config + small structured state; `G_reader_settings` is the global instance | `frontend/luasettings.lua:21-48,252-280` |
| **`Persist`** (`require("persist"):new{ path=…, codec=… }`) | pluggable codec: `dump` / `serpent` (text), `luajit` (`string.buffer`, fast binary), `zstd` (buffer + zstd, small + fast), `bitser` | larger blobs; a full variable snapshot per save slot | `frontend/persist.lua:28-216,264-294` |
| `LuaSettings:child(key)` / `:saveSettingForExt` | nested tables | namespacing per plugin | `luasettings.lua:71-73,207-228` |
| SQLite3 (`lua-ljsqlite3`) | DB file | overkill for Magium; noted for completeness | `doc/DataStore.md:19-63` |

Both `LuaSettings:flush()` and `Persist:save()` **fsync** the file (and the
directory on first create) (`luasettings.lua:270-275` via `util.writeToFile`;
`persist.lua:264-294`).

### 4.3 Fit with the Magium save model

Magium's four client blobs ([`01` §8](01-magium-analysis.md#8-saves--settings-task-18))
— continuous autosave, `checkpoint`, `save0..49`, achievements — are each a flat
`v_*` snapshot + `date`/`name`. Mapping: one `LuaSettings` file for
config/achievements + a `Persist` (`zstd` or `luajit` codec) blob per manual slot,
or a single `LuaSettings` file holding a `saves` sub-table. Sizes are small
(hundreds of short string keys → single-digit KB); the risk is **write
frequency**, not size — an autosave on every choice is many fsync'd writes on
flash. Mitigation: debounce autosave (write on a timer / on background / on exit),
keep manual slots explicit. This is the 🟡 "frequent small save writes" row in
[`04` §3](04-constraints-budget.md#3-budget-table-33);
confirm the write cost in spike D.

---

## 5. Text rendering *(2.5)*

- **Two rendering paths.** (a) `TextBoxWidget` / `ScrollTextWidget` /
  `TextWidget` — KOReader's own layout engine: takes **plain text** (with `\n`),
  wraps to a width, optional justification, per-face styling via char ranges,
  shaping through the C `xtext` lib (HarfBuzz + libunibreak) when available
  (`../koreader/frontend/ui/widget/textboxwidget.lua:1-13,307-341`). (b)
  `HtmlBoxWidget` / `ScrollHtmlWidget` — renders a **subset of HTML/CSS via
  MuPDF** (`htmlboxwidget.lua:1-13` requires `ffi/mupdf`); `TextViewer` switches
  to this when `text_format` is `html`/`htm`
  (`textviewer.lua:91-92,414,437-461`) and injects a small default stylesheet.
- **Magium markup is trivial.** The only in-prose markup is `<br/>`
  ([`02` §2.1](02-magium-format-spec.md#2-constructs-task-1111); `<br/>` appended
  per source line by `magium-dev`'s parser). Options: (1) strip/replace `<br/>` →
  `\n` and feed `TextBoxWidget` (simplest, fastest, full font control); (2) keep
  the HTML and use `ScrollHtmlWidget` (heavier — spins up MuPDF per scene — but
  future-proofs if richer markup ever appears). **Lean (1).** Stat-check lines and
  the checkpoint banner are separate UI, not prose, so they don't need markup.
- **Fonts** are `Font:getFace(name, size)` (`frontend/ui/font.lua`); KOReader
  bundles its face set. The port does not need the document (`crengine`) renderer
  at all — that's for EPUB/PDF. Font size / theme is the **reader's** setting to
  own, matching [`01` §8](01-magium-analysis.md#8-saves--settings-task-18) ("theme/font/locale are KOReader's job"),
  though a plugin can expose its own size control (as `TextViewer` does,
  `textviewer.lua:806-890`).
- Bidi/RTL and CJK are handled by the widgets; English/French Magium doesn't
  exercise them.

---

## 6. E-ink specifics *(2.6)*

`UIManager:setDirty(widget, refreshtype[, region])` enqueues a refresh; nothing
paints synchronously (`../koreader/frontend/ui/uimanager.lua:456-475`).
`show`/`close` take a `refreshtype` argument directly (`uimanager.lua:156,215`).
The refresh types (`uimanager.lua:477-518`):

| Type | Fidelity / latency | Magium use |
|---|---|---|
| `full` | highest, **flashing**, highest latency | first paint of the story UI; periodic de-ghost |
| `partial` | medium (text on white); **promoted to a flash every `FULL_REFRESH_COUNT` = 6** refreshes (`uimanager.lua:17,22`) | the reader's mode; usable for scene→scene prose swaps, but watch the flash-promotion counter |
| `ui` | medium, **no flash**, for mixed UI content — "when in doubt, use this" | choice tap → new scene text; scrolling; menu open/close |
| `fast` / `a2` | low fidelity, monochrome, lowest latency | not needed (no animation/keyboard-like updates in Magium) |
| `flashui` / `flashpartial` | `ui`/`partial` but forced flash | show/close a modal to kill ghosting |

Key facts for the tap-choice→new-page loop:

- The **MTK "fast mode"** is force-enabled on `KindlePaperWhite6` at init
  (`../koreader/frontend/device/kindle/device.lua:1775-1790`) — it stops the
  panel driver from silently upgrading every refresh to a slow high-quality
  (REAGL) waveform, so a `"ui"` page swap stays quick.
- `canHWDither = no` on this model (`device.lua` `KindlePaperWhite6`) — pure text
  is unaffected (dithering only matters for images/greys).
- Strategy: `"ui"` for scene transitions and scrolling; an occasional `"full"`
  (e.g. every N scenes, or on entering/leaving the story) to clear accumulated
  ghosting; `"flashui"` when opening/closing the stats or saves modal. `frotz.koplugin`
  uses exactly this split.
- **Actual per-interaction latency and the "does it feel sluggish / ghost?"
  judgment is [OQ-007](07-risks-open-questions.md), answered in spike A** — not
  from docs. E-ink full refresh on this panel class is ~400–600 ms (est., low
  confidence); `"ui"` partial is well under that.

---

## 7. Lifecycle & integration *(2.7)*

- **A plugin can absolutely present a fullscreen non-document UI.** `UIManager:show`
  on a screen-sized widget covers whatever is beneath (File Manager or reader);
  `Menu` has a `fullscreen` path (`menu.lua:714`), `TextViewer` fills the screen,
  and `frotz.koplugin`'s `GameView` is a bespoke fullscreen container. No
  "document" object is required.
- **Where it launches from:** with `is_doc_only = false` the plugin instance
  exists in the **File Manager** context, so a `more_tools` main-menu item (§1.3)
  opens the story straight from the home screen with no book open. A `Dispatcher`
  action additionally allows a gesture / page-turn-key / QuickMenu / profile
  launch.
- **Coexistence:** the story UI sits on the window stack above the FM. Closing it
  (`UIManager:close`, or Back → the widget's `onClose`) pops back to exactly what
  was underneath. `close_callback` / `onClose` is where we flush the save
  (`textviewer.lua:547-550`, `menu.lua:1460-1473`).
- **Clean exit / suspend:** handle the broadcast `Close` event (poweroff/reboot)
  and the standard suspend events to force a save; KOReader's plugin-event
  sandbox keeps a faulty handler from crashing the app (`pluginloader.lua:131-154`).
- **State ownership:** the plugin instance is long-lived for the session
  (`self.ui[name]`); it can hold the parsed story in memory across
  open/close of its own UI, so re-entering the story is instant after the first
  parse.

---

## 8. Build / deploy / debug loop *(2.8)*

### 8.1 On-device (the real target)

1. **Deploy:** copy `magium.koplugin/` into `koreader/plugins/` over USB
   (`pluginloader.lua:174-207`; user path also works —
   `<data-dir>/plugins/`). Restart KOReader (or toggle the plugin in
   *Tools → Plugin management*, which prompts a restart — `pluginloader.lua:322-336`).
2. **Logs:** on Kindle, `koreader.sh` runs `./reader.lua … >>crash.log 2>&1` and
   keeps the last 500 KB (`../koreader/platform/kindle/koreader.sh:323-334`). So
   **all `logger.info/dbg/warn/err` output and any Lua traceback lands in
   `koreader/crash.log`** on the device — pull it over USB. `logger` levels:
   `dbg < info < warn < err`, default `info` (`frontend/logger.lua:17-27`); raise
   verbosity in KOReader's dev settings.
3. **Iterate:** no hot reload on-device — it's copy + restart. Keep the plugin
   thin and push logic into a `require`-able `engine.lua` that also runs under
   plain `luajit` on the desktop for unit tests against the oracle (spike B).

### 8.2 Desktop emulator — set up and working on the owner's machine (WSL2)

`./kodev build && ./kodev run` (screen size/DPI via `-w -h -d`, device presets via
`-s=`) runs the full frontend on SDL3; `./kodev log koreader` tails it;
`./kodev test front` runs the busted suite; `./kodev wbuilder` is a widget
playground (`../koreader/doc/Building.md:198-226`, `kodev` help block `:713-736`).
The toolchain is Linux/macOS only (`doc/Building.md:1-10`).

**The owner is on Windows 11 → done in WSL2 / Ubuntu 24.04 (2026-08-31), OQ-012
resolved.** Reproducible installer:
[`../../reference/setup-koreader-wsl.sh`](../../reference/setup-koreader-wsl.sh);
details in [`../../reference/koreader-notes.md`](../../reference/koreader-notes.md).
Two gotchas found and fixed there: (1) Ubuntu 24.04's **ninja 1.11.1 + GNU make
4.3** have incompatible job-server implementations and the recursive-make
thirdparty builds (`luajit`, `libunibreak`) die with `make[3]: *** read jobs
pipe: Bad file descriptor` — fixed by putting **ninja ≥ 1.13.2 and make ≥ 4.4**
in `/usr/local/bin` (KOReader's own `doc/Building.md` recommends exactly these
minimums). (2) No X server needed — **WSLg** on Win 11 gives a display out of the
box and SDL picks the `x11` driver. Full build ≈ 7 min; `./kodev run` then
launches the emulator, loads all plugins, renders normally. Drop
`magium.koplugin/` in `~/koreader/plugins/` (or symlink from the Windows side).
Alternatives if ever needed: the `koreader/virdevenv` Docker image;
`--appimage-extract` a Linux AppImage for pure-Lua work.

### 8.3 Differential testing

The `engine.lua` port is diffed against the running `magium-dev` oracle
([`../../reference/magium-dev-notes.md`](../../reference/magium-dev-notes.md),
[`reference/tools/oracle-diff.js`](../../reference/tools/oracle-diff.js)) — that
harness and its 6-case golden set already exist from Phase 0 and are what spike B
runs against.

---

## 9. Localisation *(2.9)*

- KOReader's own i18n is a pure-Lua gettext subset: `local _ = require("gettext")`,
  `_("string")`, plus `C_` (pgettext), `N_`/`NC_` (ngettext), and `T()` =
  `ffi/util.template` for `%1`-style ordered substitution
  (`../koreader/frontend/gettext.lua:1-35`, `doc/Building.md:283-308`). `.po`
  files live in `l10n/<lang>/koreader.po` (a submodule fed by Weblate; not in our
  checkout).
- **A plugin ships its own translations** by bundling `l10n/<lang>/*.po` (or
  `.mo`) inside the `.koplugin` dir and loading them via the plugin's `package.path`
  — the `japanese` plugin and several `contrib` plugins do this. The plugin's
  user-facing strings still go through `_()`.
- **Magium's own localisation is a separate axis.** en/fr `.magium` sets are
  structurally identical — i18n there is a **story-bundle swap**
  ([`01` §9](01-magium-analysis.md#9-localization-task-19),
  [`02` §5](02-magium-format-spec.md#5-en-vs-fr-divergence)). The port loads
  `data/<locale>/*.magium` + that locale's `ui.json` strings; KOReader's gettext
  only covers the *plugin's* chrome (menu labels, dialog buttons). The two are
  independent and both are cheap.

---

## 10. Packaging & distribution *(2.10)*

There is **no first-party KOReader "plugin store" with review**. Channels:

| Channel | What it is | Requirements | Source |
|---|---|---|---|
| Manual install | copy `<name>.koplugin/` to `koreader/plugins/` | none | `pluginloader.lua:174-228` |
| `koreader/contrib` | official *repo* of "less commonly used, not core-maintained" plugins, as git submodules; users clone/copy what they want | PR to the repo; keep it maintained | <https://github.com/koreader/contrib> (fetched 2026-08-31) |
| GitHub topic `koreader-plugin` | discovery only (~40+ repos) | tag your repo | community convention |
| KindleModShelf | community-maintained directory of plugins/patches, has an on-device `appstore.koplugin` browser | listing request | <https://kindlemodshelf.me/> |
| `awesome-koreader` lists | curated READMEs | PR | e.g. `ruiribeiro04/awesome-koreader`, `jannick-holm/awesome-koreader` |

For Magium specifically, distribution is gated less by mechanism than by the
**story-text redistribution permission** ([OQ-004](07-risks-open-questions.md)) and
the **MIT-vs-AGPL** question ([`08-licensing.md`](08-licensing.md), OQ-005) — a
plugin bundling KOReader-side code and 7.5 MB of story text has to clear both.
Mechanically, shipping a GitHub release of a `.koplugin` zip + a KindleModShelf
listing is the low-friction path.

---

## Findings

| ID | Finding | Confidence | Basis |
|---|---|---|---|
| **F-14** | **Nothing the Magium UI needs is missing from KOReader.** Plugin = `WidgetContainer:extend`; `UIManager:show` = fullscreen; `TextBoxWidget`/`ScrollTextWidget` = reflowed prose (C-shaped); `ButtonTable`/`Menu` = choice list; `KeyValuePage` = stats; `LuaSettings`/`Persist` = saves; `Notification` = achievement toast. | high | source read of `frontend/**` @ `v2026.07.1` |
| **F-15** | **A shipping plugin already has our exact UI shape.** `kbarni/frotz.koplugin` renders a styled scrolling narrative transcript + an input/choice row as a fullscreen `FrameContainer`-based widget on e-ink, with `"ui"`/`"full"` refresh split and synchronous autosave on close. De-risks OQ-002/OQ-007 on paper; spike A confirms on our device. | medium | plugin source fetched 2026-08-31, not run |
| **F-16** | **LuaJIT = Lua 5.1 + FFI, `2.1.ROLLING` (`NUM 20199`), upstream not OpenResty**, built by `koreader-base` @ `6e4bc81` from `LuaJIT/LuaJIT@3c4f9fe`. No `utf8` stdlib, no full regex (patterns only), all-double numbers. Closes the Phase 0 "exact LuaJIT build" item. | high | `koreader-base` + `luajit_rolling.h` at pinned commits |
| **F-17** | **Single Lua state, no threads, cooperative scheduling.** A blocking cold parse or the 490 KB condition eval (OQ-011) freezes the UI unless sliced with `UIManager:scheduleIn`/`nextTick` or run under `Trapper` (coroutine). This is the platform's sharpest constraint for the port. | high | `04` §1, `frontend/ui/trapper.lua`, `uimanager.lua` |
| **F-18** | **On-device debug loop = USB copy to `koreader/plugins/` + restart + read `koreader/crash.log`** (all `logger` output + tracebacks, last 500 KB). No hot reload. The faster loop — the `kodev` **emulator — is built and running for the owner in WSL2/Ubuntu** ([`setup-koreader-wsl.sh`](../../reference/setup-koreader-wsl.sh), OQ-012 resolved): needs ninja ≥1.13.2 + make ≥4.4 (Ubuntu 24.04's are too old), WSLg supplies the display. | high | `platform/kindle/koreader.sh:323-334`, `doc/Building.md`, WSL2 build verified on-machine 2026-08-31 |
| **F-19** | **Magium markup is a non-issue.** `<br/>` is the only in-prose markup; replace with `\n` and use `TextBoxWidget` — no need for the MuPDF HTML widget or the document renderer. Theme/font stay KOReader's. | high | [`02` §2.1](02-magium-format-spec.md#2-constructs-task-1111), `textboxwidget.lua`, `textviewer.lua` |
| **F-20** | **Save model maps cleanly** onto one `LuaSettings` file (config + achievements + save index) plus optional `Persist` blobs per slot; both fsync on write. The open risk is autosave **write frequency** on flash, not blob size — debounce it. Feeds the 🟡 row in [`04` §3](04-constraints-budget.md#3-budget-table-33). | high | `luasettings.lua`, `persist.lua`; [`01` §8](01-magium-analysis.md#8-saves--settings-task-18) |
| **F-21** | **`KindlePaperWhite6` is a first-class KOReader target** (MTK, `mxcfb` driver, fast-mode forced on, `canHWDither=no`, swipe animations). No device-support gap; the platform assumes ~957 MB RAM / ~497 MB free and only ~33 MB used by KOReader. | high | `frontend/device/kindle/device.lua:1129,1775-1790,2205`; [`00`](00-overview.md) |

---

## What this unblocks

- **Phase 3 ([`04`](04-constraints-budget.md))** — device-limit rows can now be
  filled with platform facts (no threads, refresh types, fsync-on-save, LuaJIT
  GC); still needs e-ink latency (spike A) + Lua-side memory (spike D).
- **Spike A (UI feel)** — fork the simplest plugin (`hello.koplugin`) or study
  `frotz.koplugin`'s `GameView`; hard-code one Magium scene as
  `ScrollTextWidget` + `ButtonTable`; wire choices to swap scenes; judge refresh
  feel and navigation on the Paperwhite. Also settle the Windows dev loop (OQ-012).
- **Spike B (engine in Lua)** — `engine.lua` as a `require`-able module runnable
  under desktop `luajit`, diffed against the oracle; translate the JS regexes to
  Lua patterns/tokenizer; time the cold parse and the `b3ch4a.magium:251` eval
  (OQ-011).
