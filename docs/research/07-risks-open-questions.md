# 07 — Risk register & open questions

- **Status:** living (updated every phase)
- **Last updated:** 2026-08-31 (device facts in; OQ-010 closed, OQ-001/OQ-009 downgraded)
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
| OQ-001 | What is the *Lua-side* memory cost of holding the full parsed story, and is a cold parse of 54 files fast enough not to stall launch? | Chooses parse-all vs. lazy-per-chapter vs. build-time preprocess. | spike B + D | **downgraded** — not a feasibility gate | Device has **~957 MB RAM / ~500 MB available**, KOReader only ~33 MB ([`00`](00-overview.md), [`04`](04-constraints-budget.md)). ~17–30 MB resident story fits comfortably. Remaining concern is launch responsiveness, not memory. |
| OQ-002 | Is there an existing KOReader widget combo that gives acceptable prose + choice-list UX without building custom widgets? | Effort + approach B feasibility. | spike A / KOReader GH | yes | open | |
| OQ-003 | Does any existing KOReader plugin already play Twine/Ink/gamebook content offline? | Enables approach B or C. | prior art / KOReader GH | yes | open | |
| OQ-004 | Does the family's permission for the community recreations extend to a further e-reader port and redistribution of story text? | Legal basis for distribution. | Magium Discord | yes | open | |
| OQ-005 | Which upstream license governs a port — MIT (from `magium-dev` code) or does bundling KOReader-side make it AGPL? | Repo license choice. | intfiction/legal reading | no | open | |
| OQ-006 | Can `.magium` conditions/stats be faithfully represented in Twine/Ink, or is fidelity lost? | Viability of approach C. | spike C | no | open | |
| OQ-007 | E-ink refresh feel for a "tap choice → new page of prose" loop — acceptable or sluggish/ghosting? | Core UX viability. | spike A | yes | open | |
| OQ-008 | Does the `magium-dev` parser have latent bugs on multi-digit `set()` values or quoted choice labels that a port should fix rather than copy? | Correctness of a faithful port. | magium-dev source / web build | no | open | |
| OQ-009 | Does KOReader v2026.07.1 stay stable on this device under a memory-heavier plugin (holding the story + doing IO)? | A flaky base platform blocks all testing. | spike A/D on-device | partially | **mostly resolved:** KOReader v2026.07.1 **release** build runs fine on FW 5.19.5 (owner). #13307-class launch crashes not seen here. Only the "under plugin load" part remains — check during spikes. |
| OQ-010 | Exact KOReader version, release channel, firmware, and RAM on the owner's device? | Every constraint estimate depends on these. | on-device (Phase 0.1) | — | **closed** | FW **Kindle 5.19.5** (4794310058); KOReader **v2026.07.1** release (`kindlehf`); **956.9 MB RAM** (497.5 available); 10.6 GB free storage; KOReader idle RSS ~32.7 MB. Recorded in [`00-overview.md`](00-overview.md). LuaJIT exact build still TBD in Phase 2. |

## Retired / deferred

_(none yet)_
