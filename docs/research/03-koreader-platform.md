# 03 — KOReader plugin platform & constraints

- **Status:** stub (device baseline added 2026-08-31; platform study not started)
- **Last updated:** 2026-08-31
- **Phase:** 2
- **Sources:** https://kindlemodshelf.me/koreaderplugindev (+ archive) ; https://github.com/koreader/koreader (cite files by path@ref) ; [KOReader Kindle install wiki](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices) ; [KOReader issue #13307](https://github.com/koreader/koreader/issues/13307) ; on-device observation
- **Related:** [`00-overview.md`](00-overview.md), [`04-constraints-budget.md`](04-constraints-budget.md), [`05-prior-art.md`](05-prior-art.md)

> Goal: know what the plugin platform provides for rendering prose + choice lists +
> menus + a stats panel, how persistence works, and how to build/deploy/debug on
> the Paperwhite. Anything device-dependent is confirmed by a [spike](../spikes/),
> not by docs alone.

## 0. Device baseline (confirmed on-device 2026-08-31 — [`00-overview.md`](00-overview.md))

- **Kindle Paperwhite 12th gen (2024)**, FW **Kindle 5.19.5**, MediaTek dual-core
  1 GHz, **956.9 MB RAM** (~497 MB available), 10.6 GB free storage, 7″ e-ink, USB-C.
- **KOReader v2026.07.1, official release build**, `koreader-kindlehf` (build for
  FW ≥ 5.16.3). Idle RSS ~32.7 MB. Ships LuaJIT (confirm exact version — task 2.2).
- **Stability:** running fine on this device; the #13307-class launch crashes are
  not occurring here (release build on 5.19.5). OQ-009 narrowed to "under plugin load".
- **RAM is not the constraint** it was feared to be — see
  [`04-constraints-budget.md`](04-constraints-budget.md). The platform study can
  assume comfortable memory headroom and focus on UI fit and responsiveness.

## 1. Plugin anatomy *(2.1)*
_Directory layout, `_meta.lua`, `main.lua`, `WidgetContainer`, `init()`, menu registration, dispatcher/events. Cite a real example plugin._

## 2. Lua environment *(2.2)*
_Lua 5.1 / LuaJIT, available stdlib, string/regex facilities, JSON, UTF-8._

## 3. UI toolkit inventory *(2.3)*
| Need | Candidate widget(s) | Constraints observed |
|---|---|---|
| Long scrollable prose | `TextViewer`, `ScrollTextWidget` | TBD |
| Vertical choice-button list | `ButtonDialog*`, `Menu` | TBD |
| Modal menus / dialogs | `ButtonDialog`, `InputDialog` | TBD |
| Stats panel | `KeyValuePage`? `Menu`? | TBD |

## 4. Persistence *(2.4)*
_`LuaSettings`, `DocSettings`, `Persist`, plain files; where Kindle user data should live; cost of frequent multi-KB save writes._

## 5. Text rendering *(2.5)*
_Layout/reflow, fonts, markup support (our data has `<br/>`), reuse of the document renderer vs. text widgets._

## 6. E-ink specifics *(2.6)*
_Refresh modes (full / partial / A2), ghosting avoidance, per-interaction latency._

## 7. Lifecycle & integration *(2.7)*
_Fullscreen non-document UI, coexistence with file browser/reader, launch (menu/gesture), clean exit._

## 8. Build / deploy / debug loop *(2.8)*
_USB copy to `koreader/plugins/`, `logger` output & crash logs, hot reload, desktop emulator for fast iteration._

## 9. Localisation *(2.9)*
_KOReader gettext i18n; shipping plugin translations._

## 10. Packaging & distribution *(2.10)*
_KOReader plugin index, kindlemodshelf, manual install — requirements of each._

## Findings

_(none yet)_
