# Spec: Phase VII — Localization (en + fr)

- **Status:** draft — awaiting owner review
- **Last updated:** 2026-09-08
- **Phase:** Implementation — design cycle 7 (roadmap [Phase VII](../research/09-roadmap-effort.md#phase-vii--localization-en--fr))
- **Sources:**
  - [`../research/01-magium-analysis.md`](../research/01-magium-analysis.md) §9 (localization = string-bundle swap, not a re-parse)
  - [`../research/03-koreader-platform.md`](../research/03-koreader-platform.md) §9 (KOReader gettext; a plugin ships its own `.po` — *not done here, §1.2*)
  - `../../../magium-dev` @ `51f5aa9` — `data/fr/` (54 `.magium` + `ui.json` + `achievements{1,2,3}.json`), `data/locales.json`, `templates/language.ejs`
  - Probe 2026-09-08: all 54 `data/fr/*.magium` parse clean with `engine/parser.lua`; fr scene-ID sets == en, file-for-file.
- **Related:** [`../../research-plan.md`](../../research-plan.md), [ADR-008](../decisions/ADR-008-localization-scope.md), [Phase VI spec](2026-09-07-phase-vi-settings.md) (the Settings dialog this extends)

> French is a **drop-in data bundle**. Scene IDs and `v_*` variables are
> locale-invariant, so the parser, engine, save schema and oracle are all
> untouched — the phase is: bundle `data/fr/`, add a language key + a Settings
> picker, and make the switch re-parse + re-render in place. Plugin chrome that
> isn't already `locale:str()`-routed stays English ([ADR-008](../decisions/ADR-008-localization-scope.md)).

---

## 1. Scope

### 1.1 In scope

1. **`magium.koplugin/data/fr/`** — `../magium-dev/data/fr/` copied verbatim
   (same as `data/en/` was). 54 `.magium`, `ui.json`, `achievements{1,2,3}.json`.
2. **`main.lua`** — `magium_lang` `G_reader_settings` key (default `"en"`;
   any non-`"fr"` value → `"en"`); a `current_lang()` / `ensure_locale()` pair;
   `new_story()` + `init()` + `openReader()` read the current language instead
   of a hardcoded `"en"`.
3. **`main.lua` Settings dialog** — a "Language" row → English / Français picker.
   Switching clears the shared story/locale caches and calls `_reopenReader()`,
   which re-parses in the new language (behind the existing Trapper bar) and
   re-renders the current scene.
4. **`engine/locale.lua`** — a one-line guard: unknown lang dir → fall back to `"en"`.
5. **Tests** — fr-bundle parity block, fr `locale_spec` assertions, an
   `openSettings → Language` E2E path, a French-scene paint in `reader_smoke`.

### 1.2 Out of scope — → [ADR-008](../decisions/ADR-008-localization-scope.md)

- **Plugin-chrome gettext catalog** (`l10n/fr/magium.po` + `.mo` + `GetText.loadMO`).
  The roadmap listed it; dropped. The sole user reads English, and the chrome
  worth translating (About text, cheat-mode strings, Yes/No, Save/Load &
  Achievements labels, stat labels, `mainHeaderTemplate`) already routes through
  `self.locale:str(...)` and turns French from `ui.json` for free. The ~25
  remaining bare `_()` strings stay English.
- **Locales beyond fr** — upstream ships only en/fr.
- **A `locales.json` file** — the picker holds two hardcoded entries.
- **fr `oracle-corpus` sweep** — `engine/` is not touched and the render path is
  locale-agnostic; §4's parity block is the fr gate. Baseline stays **8887/8887**.
- **The fr `ui.json` key delta vs en** — `menuImportExportText` absent (unused;
  import/export cut in [ADR-007](../decisions/ADR-007-saves-scope.md)),
  `statsPerceptionText` extra (harmless). No action.

## 2. The port target (`magium-dev` @ `51f5aa9`)

- `data/locales.json` = `{ "en": "English", "fr": "Français" }` — drives
  magium-dev's language menu and which `data/<locale>/` loads. We inline the
  two entries.
- `templates/language.ejs` — a list of buttons, one per locale; click sets a
  cookie and reloads. Our equivalent: the Settings picker + `_reopenReader()`.
- `data/fr/ui.json` `mainHeaderTemplate` = `"Livre <%= book %> - Chapitre <%= chapter %>"`;
  `localeYes`/`localeNo` = `"Oui"`/`"Non"`. `engine/locale.lua:header` /
  `:stat_check_text` already interpolate `<%= … %>`, so these work unmodified.

## 3. Design — `main.lua` (+ the data copy, + a 1-line `locale.lua` guard)

### 3.1 Module-level helpers (by the `shared_*` cache locals)

```lua
local function current_lang()
  local l = G_reader_settings and G_reader_settings:readSetting("magium_lang")
  return l == "fr" and "fr" or "en"
end

-- single source of truth for shared_locale; rebuilds when the language changed
local function ensure_locale(data_dir)
  local want = current_lang()
  if not shared_locale or shared_locale.lang ~= want then
    shared_locale = Locale.load(data_dir, want)
  end
  return shared_locale
end
```

`Locale` already stores `self.lang` (`engine/locale.lua:19`), so the staleness
check is free.

### 3.2 Wiring

| Site | Was | Now |
|---|---|---|
| `new_story()` (`main.lua:62`) | `locale = "en"` | `locale = current_lang()` |
| `init()` (`main.lua:122`) | `shared_locale = shared_locale or Locale.load(self.data_dir, "en")` | `self.locale = ensure_locale(self.data_dir)` |
| `openReader()` top (~`main.lua:308`, before `_ensureLoaded()`) | — | `self.locale = ensure_locale(self.data_dir)` |

The `openReader()` line covers a second plugin instance (FileManager vs
ReaderUI) whose `self.locale` predates a switch made in the other. `init()`
re-runs on every FileManager/ReaderUI rebuild, so the stale window is already
small; this closes it.

`_ensureLoaded()` is unchanged — it re-parses whenever `shared_loaded` is false,
which `_setLanguage` sets.

### 3.3 The language switch

```lua
function Magium:_setLanguage(lang)
  if lang == current_lang() then return end
  G_reader_settings:saveSetting("magium_lang", lang)
  shared_story, shared_loaded = nil, false   -- force a re-parse in the new language
  trace.event("settings", { op = "language", lang = lang })
  self:_reopenReader()                       -- openReader → ensure_locale + _ensureLoaded rebuild both
end
```

`_reopenReader()` (`main.lua:673`) closes the reader and `nextTick`s
`openReader()`, which now: refreshes `self.locale` (§3.2), re-parses the fr
corpus behind the existing "Loading Magium… n/54" Trapper bar (~0.24 s dev,
~2.2 s device — acceptable for a rare settings action), and re-renders
`v_current_scene`. `self._loaded` is already true on this path, so
`openReader()` keeps the in-memory store (the resume fix from Phase VI §3.7) —
and scene IDs are locale-invariant, so nothing about play state changes.

### 3.4 The Settings picker — extract the shared dialog

`_openTextSizeDialog()` (`main.lua:628`) and the new language picker are the
same widget: a `ButtonDialog`, one row per `{label, value}`, `" ✓"` on the
active row, a `Cancel` row, apply-on-tap. Extract:

```lua
function Magium:_openPickerDialog(title, options, current, apply)
  -- options: { {label, value}, ... }  · rows built as in _openTextSizeDialog
  -- tap: close dialog, apply(value) unless value == current
end
```

- `_openTextSizeDialog()` becomes a call with the `PROSE_PRESETS` options and
  `apply = function(pt) G_reader_settings:saveSetting("magium_prose_size", pt); self:_reopenReader() end`.
- `_openLanguageDialog()` = a call with `{{"English","en"},{"Français","fr"}}`,
  `current = current_lang()`, `apply = function(l) self:_setLanguage(l) end`.

`openSettings()` (`main.lua:610`) gains a row above "Back to game":

```lua
{{ text = _("Language"), callback = act(function() self:_openLanguageDialog() end) }},
```

### 3.5 `engine/locale.lua` guard

`Locale.load` (`engine/locale.lua:17`) `assert(io.open(...))`s on the ui.json
path — a bad `magium_lang` would throw at startup. Before the reads:

```lua
if not lfs_or_io_can_see(data_dir .. "/" .. lang) then lang = "en" end
```

(pure-Lua check — `io.open(dir .. "/ui.json")` probe, since `engine/` takes no
KOReader deps and `lfs` isn't guaranteed there). Belt-and-braces; `current_lang`
already clamps to `en`/`fr`.

## 4. Tests (extend existing files — no new spec file)

- **fr-bundle parity** — a `describe` block in
  `spec/engine/navigation_spec.lua` (its content-integrity home): for every
  `data/en/*.magium`, `parser.parse` the `data/fr/` copy without error and
  assert its scene-ID set equals the en copy's. The one non-trivial guarantee
  the whole phase rests on.
- **`spec/engine/locale_spec.lua`** — load the fr bundle:
  `header("B2-Ch7-Foo") == "Livre 2 - Chapitre 7"`; `str("localeYes") == "Oui"`;
  `achievement_chapters(1)` returns the same ordered keys as en.
- **`spec/ui/main_e2e_smoke.lua`** — `openSettings()` → Language → Français:
  `self.locale.lang == "fr"`, the reader reopens, `v_current_scene` re-renders
  (header begins "Livre", no paint crash); then switch back to English and
  assert `self.locale.lang == "en"`.
- **`spec/ui/reader_smoke.lua`** — paint page 1 of one French scene (accented
  glyphs é/à/ç through `pagination` + `PROSE_FACE`); runs under every
  `test-ui-matrix` profile.
- **Unchanged, stated in the log:** `oracle-corpus` **8887/8887** (no
  engine/scene.render change); `spec/save/schema_compat_spec.lua`
  (`magium_lang` is a `G_reader_settings` key, not in the save blob).

## 5. Decisions

- **D1** — French is a verbatim `data/fr/` bundle, parsed at runtime like en.
  No build-time preprocessing. (Verified: parses clean, scene IDs match en.)
- **D2** — Plugin chrome not already `locale:str()`-routed stays English; no
  bundled `.po`/`.mo`. → [ADR-008](../decisions/ADR-008-localization-scope.md).
- **D3** — Default `"en"`; `magium_lang` `G_reader_settings` key; switch in the
  in-game Settings dialog (not KOReader's UI-language setting).
- **D4** — Switching = live reload: clear `shared_story`/`shared_locale`,
  re-parse, re-render `v_current_scene` in place. Play state carries over
  untouched (locale-invariant IDs/vars).
- **D5** — Unknown `magium_lang` → `"en"` (clamp in `current_lang`, guard in
  `Locale.load`).

## 6. Exit criteria

- [ ] Automated gates green: `busted` (fr parity + locale blocks added),
      `test-ui` + `test-ui-real` + `test-ui-matrix` (all 4 profiles paint a
      French scene), `emu-smoke`. `oracle-corpus` unchanged at 8887/8887 (not
      re-run — no engine change).
- [ ] Owner on device (PW12): Settings → **Language → Français** switches the
      story prose + chapter header to French on the current scene; menu / stats
      / a choice round-trip work in French; **Language → English** switches
      back; the switch survives close/reopen + suspend/resume + a KOReader
      restart; play position is unchanged across the switch.
