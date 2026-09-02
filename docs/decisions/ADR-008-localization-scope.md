# ADR-008: Phase VII localization — story bundle only, no plugin-chrome catalog

- **Status:** Accepted
- **Date:** 2026-09-08
- **Deciders:** owner (brainstorm 2026-09-08), Claude
- **Phase:** Implementation — Phase VII ([spec](../specs/2026-09-08-phase-vii-localization.md))
- **Related:** [`../research/09-roadmap-effort.md` Phase VII](../research/09-roadmap-effort.md#phase-vii--localization-en--fr), [`../research/03-koreader-platform.md` §9](../research/03-koreader-platform.md#9-localisation-29) (KOReader gettext; a plugin *can* ship its own `.po`), [`../research/01-magium-analysis.md` §9](../research/01-magium-analysis.md#9-localization-task-19) (localization = string-bundle swap), [ADR-003](ADR-003-defer-licensing-distribution.md) (no distribution → no external users), [ADR-007](ADR-007-saves-scope.md) (same "port `magium-dev` except where it earns its keep for a single owner" reasoning)

## Context

The roadmap's Phase VII deliverables list two localization axes:

1. **Magium's own prose** — bundle the French `data/fr/` set (54 `.magium` +
   `ui.json` + `achievements{1,2,3}.json`) alongside English. Structurally
   identical to `data/en/` file-for-file, so this is a data-bundle swap, not
   new engine logic ([`01` §9](../research/01-magium-analysis.md#9-localization-task-19),
   verified 2026-09-08: all 54 fr files parse clean, scene-ID sets == en).
2. **The plugin's own UI chrome** — the roadmap line reads "KOReader gettext
   (`_()`/`T()`) `.po` for the plugin's own UI chrome." The plugin has ~40
   `_()`-wrapped strings (menu rows, dialog buttons, `InfoMessage` text). About
   15 of them already route through `self.locale:str("key") or _("fallback")`
   and pick up French from Magium's own `ui.json`; ~25 are English-only.

Delivering axis 2 means bundling `l10n/fr/magium.po`, compiling it to `.mo` at
build time, and loading it via `GetText.loadMO` at plugin init — a translation
catalog to keep in sync with every future string, plus a build step this repo
otherwise doesn't have.

The port has **one user, who reads English** ([ADR-003](ADR-003-defer-licensing-distribution.md):
no distribution planned).

## Options considered

### Option A — Story bundle only; chrome stays English except what `ui.json` already covers
- Pros: zero new infrastructure; the French *reading experience* (prose,
  choices, chapter headers, stat-check lines, achievement titles, About text,
  cheat-mode text, Yes/No) is fully French because those already go through
  `locale:str()`; nothing new to maintain.
- Cons: ~25 chrome strings ("Back to game", "New game / Restart book", "Delete
  this save?", "Loading Magium…", the Settings row labels) render English in an
  otherwise-French session.

### Option B — Full chrome catalog (`l10n/fr/magium.po` + `.mo` + `loadMO`)
- Pros: every visible string localized; matches how large KOReader plugins do it.
- Cons: a `.po` catalog + a build step + ongoing sync discipline, for strings
  the sole English-reading user sees on menus they already know by position. No
  external user to benefit. Highest-maintenance option by far.

### Option C — Reword custom strings to reuse `ui.json` keys where a near-match exists
- Pros: no new infra; shrinks the English-only set.
- Cons: couples our menu wording to `magium-dev`'s string set; awkward
  near-fits ("New game / Restart book" has no clean `ui.json` equivalent);
  saves maybe 8 strings for real contortion.

## Decision

**Option A.** Phase VII ships the French `data/fr/` bundle and a language
switch. Plugin chrome that isn't already `self.locale:str()`-routed stays
English. **No `.po`/`.mo` catalog, no build step.**

## Rationale

The value of Phase VII is *reading Magium in French* — and Option A delivers
that completely, because every prose-adjacent string already flows through
`engine/locale.lua` from `ui.json`. The residual English is confined to
navigation chrome that a returning player operates by muscle memory. Option B's
catalog is real, permanent maintenance weight (every new `_()` string becomes a
translation TODO) with literally zero users who need it — the exact "effort with
no user" that [ADR-007](ADR-007-saves-scope.md) already rejected for
import/export. Option C trades infrastructure for wording contortions and only
gets partway.

If the plugin is ever distributed, a French speaker filing the gap is a small
additive change (drop in `l10n/fr/magium.po`, one `loadMO` call) — not a
redesign.

## Consequences

- **`main.lua` keeps ~25 bare `_()` strings.** They render via KOReader's own
  gettext, so they *are* translated when KOReader itself runs in a language it
  ships a catalog for — just not driven by the plugin's `magium_lang` setting.
- **No `l10n/` directory, no `.mo` build step** enters the repo.
- **The fr `ui.json` key delta vs en is ignored**: `menuImportExportText`
  absent (unused — [ADR-007](ADR-007-saves-scope.md) cut import/export),
  `statsPerceptionText` extra (harmless). Not reconciled.
- **Revisit if:** the port targets distribution, or a French-reading user asks
  for the chrome gap to close.
