# 07 — Risk register & open questions

- **Status:** living (updated every phase)
- **Last updated:** 2026-08-31
- **Phase:** all
- **Related:** every other research doc; [`../decisions/`](../decisions/)

> This is the single home for open questions. Elsewhere, reference them by ID
> (`OQ-007`), never restate. Closed questions stay here with their resolution.

## How to use

- Add a row when a question arises. Assign the next `OQ-NNN`.
- **Venue** = where the answer comes from: `spike` · `magium-dev source` · `web build` ·
  `KOReader GH` · `MobileRead` · `r/koreader` · `Magium Discord` · `intfiction.org` ·
  `<plugin author>`.
- **Blocking?** = does an approach decision or the feasibility verdict depend on it.
- On close: set Status = `closed`, fill Resolution with a link to the finding/ADR.

## Open questions

| ID | Question | Why it matters | Venue | Blocking? | Status | Resolution |
|---|---|---|---|---|---|---|
| OQ-001 | Can the full parsed story fit in a KOReader plugin's RAM budget on a PW4? | Decides runtime-parse vs. build-time preprocess (approach A vs. D). | spike D | yes | open | |
| OQ-002 | Is there an existing KOReader widget combo that gives acceptable prose + choice-list UX without building custom widgets? | Effort + approach B feasibility. | spike A / KOReader GH | yes | open | |
| OQ-003 | Does any existing KOReader plugin already play Twine/Ink/gamebook content offline? | Enables approach B or C. | prior art / KOReader GH | yes | open | |
| OQ-004 | Does the family's permission for the community recreations extend to a further e-reader port and redistribution of story text? | Legal basis for distribution. | Magium Discord | yes | open | |
| OQ-005 | Which upstream license governs a port — MIT (from `magium-dev` code) or does bundling KOReader-side make it AGPL? | Repo license choice. | intfiction/legal reading | no | open | |
| OQ-006 | Can `.magium` conditions/stats be faithfully represented in Twine/Ink, or is fidelity lost? | Viability of approach C. | spike C | no | open | |
| OQ-007 | E-ink refresh feel for a "tap choice → new page of prose" loop — acceptable or sluggish/ghosting? | Core UX viability. | spike A | yes | open | |
| OQ-008 | Does the `magium-dev` parser have latent bugs on multi-digit `set()` values or quoted choice labels that a port should fix rather than copy? | Correctness of a faithful port. | magium-dev source / web build | no | open | |

## Retired / deferred

_(none yet)_
