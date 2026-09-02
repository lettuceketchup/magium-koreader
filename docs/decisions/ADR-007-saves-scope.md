# ADR-007: Phase III saves — drop import/export and rename, add delete

- **Status:** Accepted
- **Date:** 2026-09-02
- **Deciders:** owner (Q&A 2026-09-02), Claude
- **Phase:** Implementation — Phase III ([spec](../specs/2026-09-02-phase-iii-saves.md))
- **Related:** [`../research/09-roadmap-effort.md` Phase III](../archive/research/09-roadmap-effort.md#phase-iii--saves), [ADR-006](ADR-006-no-scene-back-navigation.md) (also a "match `magium-dev` except where the device forces a change" call), [`../specs/2026-08-31-plugin-architecture-and-phase-i.md` §9](../specs/2026-08-31-plugin-architecture-and-phase-i.md#9-save-model-savemanagerlua)

## Context

`magium-dev`'s saves screen (`templates/saves.ejs`, `public/scripts/saves.js` @
`51f5aa9`) offers, per slot: **Save**, **Load**, **Import** (paste a base64 save
string), **Export** (copy the string to clipboard), and an editable **name**
field — plus screen-level "export achievements / all" and "import achievements /
all". There is **no delete**; you overwrite.

Phase III ports this to a KOReader `Menu` screen. Two of those features do not
carry to the target device, and one useful one is missing.

## Decision

**Port Save and Load faithfully. Cut Import/Export. Cut the name field and
rename. Add Delete.**

- **No import/export.** It is entirely clipboard-driven (`copyToClipboard`,
  `navigator.clipboard.writeText`, `window.prompt`-style paste). KOReader on the
  Kindle has no clipboard paste surface a player would use, and the owner already
  has the save files directly over USB and the key-only SSH deploy loop — the
  real backup path. Building a file-picker import/export for a single-user,
  no-distribution port (ADR-003) is effort with no user.
- **No rename, no name entry.** A slot's `name` is set at save time to the
  current chapter header (`locale:header(v_current_scene)`, e.g. "Book 2 -
  Chapter 4"), or `"Magium"` if the scene has no chapter. `magium-dev` defaults
  `name` to a UTC date string and makes it editable through a text input; the
  chapter header is strictly more informative and needs no on-screen keyboard
  (slow and unpleasant on an e-ink Kindle).
- **Delete added.** One `os.remove` behind a `ConfirmBox`. `magium-dev` users
  clear a slot by overwriting it; on the device, with no dev console, an explicit
  delete is worth the one button.

## Consequences

- **`ui.json`'s `saves*Import*` / `saves*Export*` strings become unused** in this
  port. Left in place (they cost nothing and keep the file aligned with
  upstream); not wired to anything.
- **Phase I spec §9 is partially superseded**: its slot row lists a `{NN →
  {date,name}}` index and an editable `name`. The [Phase III spec](../specs/2026-09-02-phase-iii-saves.md)
  §3/§5 records the actual design (one `Persist` file per slot, no index,
  header-derived name); §9 gets a one-line pointer.
- **Revisit if:** the port ever targets distribution (import/export becomes a
  real "move my save to another device" need), or the owner asks for custom slot
  names — either is a small additive change, not a redesign.
