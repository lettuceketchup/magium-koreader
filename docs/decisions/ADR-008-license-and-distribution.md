# ADR-008: License the port AGPL-3.0-or-later; release it freely and non-commercially; keep the bundled story text under CC BY 4.0

- **Status:** Accepted
- **Date:** 2026-09-08
- **Deciders:** rishishwarmanu@gmail.com
- **Phase:** 7 (licensing & permissions — run now that distribution is the intent)
- **Related:** supersedes [ADR-003](ADR-003-defer-licensing-distribution.md) (its
  deferral condition — "revisit when the owner decides to share the port" — has
  now triggered); [`../research/08-licensing.md`](../archive/research/08-licensing.md)
  (the analysis), [`../research/07-risks-open-questions.md`](../archive/research/07-risks-open-questions.md)
  OQ-004 / OQ-005; [ADR-002](ADR-002-porting-approach.md) (standalone plugin);
  [`../../LICENSE`](../../LICENSE), [`../../THIRD-PARTY-NOTICES.md`](../../THIRD-PARTY-NOTICES.md)

## Context

[ADR-003](ADR-003-defer-licensing-distribution.md) deferred all licensing work
while the project was personal-use-only, naming a single revisit trigger: "the
owner deciding to share the finished port with anyone else." The owner now wants
exactly that — a free, non-commercial public release via GitHub, with
contributors (testers, coders, e-ink specialists, fans) and forks welcome, and
issues/PRs invited for other e-ink devices. So Phase 7 runs.

The facts, from [`08-licensing.md`](../archive/research/08-licensing.md) (sources cited
there):

- **Original `raduprv/Magium`:** code **MIT** (`Copyright (c) 2024 Cristian
  Mihailescu`); **all data / text released CC BY 4.0** by the family, with the
  explicit stated goal of enabling ports and translations.
- **`magium-dev`** (this port's base): **MIT**. Its `data/en/*.magium` files
  are a format transcription of the CC BY 4.0 original — CC BY 4.0 flows
  through. This port bundles those files verbatim and reimplements the engine
  in Lua.
- **`magium-recrystallized`** (AGPL): research reference only; no code or data
  from it ships here, so its copyleft never attaches.
- **KOReader:** **AGPL-3.0**. A `.koplugin` is `require`d into KOReader's single
  Lua state at runtime — a plausible "single program / derivative work" case
  under the FSF reading, even though the plugin ecosystem in practice carries
  mixed third-party licences.

No permission request is outstanding: MIT and CC BY 4.0 *are* the grant. The
only hard obligation is attribution + indicating that the text was reformatted.

## Options considered

### Option A — MIT for the plugin code
- Pros: matches the engine's upstream licence; simplest inbound-contribution story.
- Cons: leaves the "is a plugin `require`d into an AGPL host a derivative work?"
  question open; if it *is*, an MIT licence on the plugin is ineffective and
  misleading. Weakest answer to F-33.

### Option B — GPL-3.0-or-later for the plugin code
- Pros: copyleft; compatible with combining MIT engine code; closes most of the
  derivative-work question.
- Cons: KOReader is specifically **A**GPL (the network clause). Matching GPL
  rather than AGPL is a near-match that still leaves a gap if the combined-work
  reading is taken seriously.

### Option C — AGPL-3.0-or-later for the plugin code, CC BY 4.0 kept on the story text, free non-commercial GitHub release
- Pros: exactly matches the host licence, so the combined-work question
  disappears at no practical cost; MIT engine code composes into an AGPL
  aggregate cleanly (one-way permitted), with the MIT notice retained in
  `THIRD-PARTY-NOTICES.md`; the story text stays under the licence the family
  actually granted (we can't relicense it anyway); "inbound = outbound" gives
  contributors a clear, conventional basis; nothing about AGPL impedes a
  non-commercial hobby release.
- Cons: AGPL is a strong copyleft — a downstream who wanted to build a
  proprietary derivative can't. For a preservation-oriented fan port that is
  the *intended* outcome, not a cost. Slightly more friction for a contributor
  who dislikes copyleft.

## Decision

**Option C.**

1. **Plugin / repo code, docs, and tooling:** **AGPL-3.0-or-later**. `LICENSE`
   at the repo root is the GNU AGPL-3.0 text.
2. **Bundled Magium story text and UI / achievement JSON**
   (`magium.koplugin/data/**`): remains **CC BY 4.0**, © Cristian Mihailescu.
   Not relicensed. Attribution and the change note ("transcribed to `.magium`,
   reflowed and paginated for KOReader; content unchanged") carried in
   `THIRD-PARTY-NOTICES.md`, `README.md`, and the in-app About screen.
3. **Distribution:** free and non-commercial, via the GitHub repository and
   tagged Releases. No permission request is required — the licences grant it.
   Optionally tag the repo `koreader-plugin` for in-reader discovery later.
4. **Contributions:** accepted under the repo's AGPL-3.0-or-later on an
   inbound-equals-outbound basis; `CONTRIBUTING.md` states this and that forks
   / continuations are explicitly welcome. Story-text changes must preserve
   CC BY 4.0 provenance.
5. **Naming:** keep "unofficial" / "fan port" prominent; do not use official
   Magium branding assets or imply an official release.

## Rationale

The combined-work question (F-33) is the only real fork in the road, and
matching KOReader's own AGPL settles it for free — there is no scenario where
this port benefits from a permissive licence that AGPL would block, because the
whole point is a shared, preservable, community-continuable artifact. The story
text licence isn't a choice at all: CC BY 4.0 is what the family granted, we
honour its attribution terms, and we don't have standing to relicense it. A
non-commercial free release needs no one's sign-off — ADR-003 had assumed the
permission chain was murky; confirming the data is CC BY 4.0 dissolved that.

## Consequences

- **OQ-004** (redistribution permission) and **OQ-005** (which licence governs
  a port) both close in [`07-risks-open-questions.md`](../archive/research/07-risks-open-questions.md)
  — resolutions point here.
- **[ADR-003](ADR-003-defer-licensing-distribution.md)** status →
  `Superseded by ADR-008`. Its deferral was correct for its time and its own
  revisit trigger fired; this ADR is that revisit.
- **New files:** `LICENSE`, `THIRD-PARTY-NOTICES.md`, `CONTRIBUTING.md`;
  `08-licensing.md` filled from stub to `stable`.
- **`README.md`** gains Licence + Contributing sections and the non-affiliation
  disclaimer; the plugin **About** screen gains the attribution + licence lines.
- **`CLAUDE.md`** scope line changes from "personal use only" to "freely
  distributable, non-commercial".
- **Every future source file** is under AGPL-3.0-or-later by virtue of the repo
  `LICENSE`; no per-file header is mandated (KOReader itself doesn't), but new
  contributors are told the licence in `CONTRIBUTING.md`.
- **What would make us revisit:** wanting to distribute through a channel with
  incompatible terms, a request from the family to change attribution or
  licensing, or a decision to commercialise (which CC BY 4.0 allows but the
  project has chosen against).
