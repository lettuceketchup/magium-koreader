# 08 — Licensing & permissions

- **Status:** stable (Phase 7 run 2026-09-08, once distribution became the
  intent — the revisit trigger [ADR-003](../../decisions/ADR-003-defer-licensing-distribution.md)
  named; decision recorded in [ADR-008](../../decisions/ADR-008-license-and-distribution.md))
- **Last updated:** 2026-09-08
- **Phase:** 7
- **Sources:** `../magium-dev/LICENSE` (MIT, `Copyright (c) 2024 Christian Mihailescu`),
  `../magium-recrystallized/LICENSE` (AGPL-3.0),
  <https://github.com/raduprv/Magium> — `LICENSE` (MIT, `Copyright (c) 2024 Cristian Mihailescu`)
  + `README.md` ("All the data (text and such) is released under CC BY 4.0 license.",
  fetched 2026-09-08), `../koreader/COPYING` (AGPL-3.0),
  <https://creativecommons.org/licenses/by/4.0/>
- **Related:** [`07-risks-open-questions.md`](07-risks-open-questions.md) OQ-004,
  OQ-005; [ADR-003](../../decisions/ADR-003-defer-licensing-distribution.md)
  (deferred this phase), [ADR-008](../../decisions/ADR-008-license-and-distribution.md)
  (the decision); [`../../LICENSE`](../../../LICENSE),
  [`../../THIRD-PARTY-NOTICES.md`](../../../THIRD-PARTY-NOTICES.md)

> Goal: know what licence the port must adopt and what redistribution of code and
> story text is permitted, before any public release. The owner now intends to
> release the port freely (non-commercial) via GitHub and welcome contributors,
> so this phase ran for real.

## 1. Upstream code licences *(7.1)*

| Project | Code licence | Data / text licence | Notes |
|---|---|---|---|
| **`raduprv/Magium`** (original) | **MIT** — `Copyright (c) 2024 Cristian Mihailescu` | **CC BY 4.0** — stated verbatim in the repo README | Released by the author's brother Radu, August 2024, "with my mother's permission", after Cristian Mihailescu's death. Explicit stated purpose: "porting the game to other languages, and hopefully finishing it too." |
| **`magium-dev` / MagiumJS** (porting base) | **MIT** — `Copyright (c) 2024 Christian Mihailescu` (the LICENSE file keeps the original author's name) | `data/en/*.magium` has no separate licence file; it is a transcription of the CC BY 4.0 original, so **CC BY 4.0** flows through | Fan recreation of the three original books "to better preserve his stories once they are taken off the various app stores". |
| **`magium-recrystallized`** | **AGPL-3.0** | AGPL-3.0 | Secondary research reference only. **No code or data from it is used** — so its copyleft never attaches to this port. |
| **KOReader** | **AGPL-3.0** | — | Host platform. Not bundled with the plugin. |

**F-31 (high confidence):** the two licences that actually bind this port are
both permissive and both were chosen specifically to enable derivative works:
MIT on the engine code, **CC BY 4.0 on the story text**. Neither requires asking
anyone for permission — the licences are the grant. This closes **OQ-004** (the
old "does the family's permission extend to a further port?" worry): the family
answered it in advance by releasing the data CC BY 4.0.

## 2. Story-text permission chain *(7.2)*

- Cristian Mihailescu wrote Magium. → His family (via his brother Radu, with
  his mother's permission) released the game and **explicitly licensed all data
  / text CC BY 4.0**, stating the goal was ports and translations. →
  `magium-dev` transcribed that text into `.magium` scene files (a format
  change, not a content change), under an MIT-licensed repo. → This port copies
  those `.magium` files verbatim and reflows them for e-ink.
- **CC BY 4.0 obligations we inherit** (<https://creativecommons.org/licenses/by/4.0/>):
  1. **Attribution** — name the creator (Cristian Mihailescu), keep any
     copyright notice, link the licence, link to the material.
  2. **Indicate changes** — state that the text was reformatted to `.magium`
     and paginated/reflowed for KOReader; content unchanged.
  3. **No additional restrictions** — don't apply DRM or legal terms that stop
     others doing what CC BY 4.0 allows.
  4. Commercial use *is* permitted by CC BY 4.0; this port stays non-commercial
     by choice, which is stricter than required, not a conflict.
- Where attribution lives in this repo:
  [`THIRD-PARTY-NOTICES.md`](../../../THIRD-PARTY-NOTICES.md) (full), the repo
  `README.md` (Credit + Licence sections), and the plugin's in-app **About**
  screen (`magium.koplugin/main.lua`).
- **Verify before a release:** the bundled `data/en` set should be the three
  original books only. If any file is post-original community continuation, it
  is covered by magium-dev's MIT repo licence / contributor terms — still
  redistributable, but the attribution line should not imply it is all
  Mihailescu's original prose. As of the bundled magium-dev commit, `data/en`
  is the original three books.

## 3. KOReader's licence and plugin implications *(7.3)*

- KOReader is **AGPL-3.0**. A `.koplugin` is a directory of Lua modules
  `require`d into KOReader's single Lua state at runtime.
- Two readings of whether that makes the plugin a derivative work of KOReader:
  - **Ecosystem practice:** KOReader's plugin ecosystem contains many
    independently-licensed third-party plugins (e.g. `frotz.koplugin` is
    GPLv3; others are MIT/Apache). Shipping only the plugin folder — not a
    KOReader bundle — is treated as the plugin carrying its own licence.
  - **Conservative (FSF) reading:** a plugin loaded into the same process as
    an AGPL host, forming "a single program", is arguably a derivative and the
    AGPL attaches. KOReader plugins are `require`d into the same Lua state,
    which is a strong "single program" case.
- **Decision (ADR-008):** license this plugin's own code **AGPL-3.0-or-later**
  — it removes the ambiguity, matches the host, and MIT-licensed engine code
  composes into an AGPL aggregate cleanly (MIT → AGPL is a permitted one-way
  combine; the MIT notice is retained in
  [`THIRD-PARTY-NOTICES.md`](../../../THIRD-PARTY-NOTICES.md)).
- The CC BY 4.0 story text is a **separately-licensed data component** in the
  same repository. AGPL code + CC BY 4.0 content side by side is fine; the
  AGPL does not "reach into" the data and CC BY 4.0 does not constrain the
  code. Both licences are named in `LICENSE` context and `THIRD-PARTY-NOTICES.md`.

## 4. Distribution channel implications *(7.4)*

| Channel | Requirements | Fit |
|---|---|---|
| **GitHub repo + Releases** (chosen) | AGPL-3.0: ship the `LICENSE`, keep source available (the repo *is* the source), preserve notices. CC BY 4.0: attribution + indicate-changes travel with the release (they're in the repo + the `.koplugin`). | **Good.** A release is a tagged tarball of `magium.koplugin/` plus the repo. Nothing extra to satisfy. |
| **KOReader plugin index / `appstore.koplugin`** discovery | Tag the GitHub repo `koreader-plugin`; no licence gate beyond having one. | Optional, free. Makes it discoverable in-reader. Do after the first release settles. |
| **KindleModShelf** | Community jailbreak-app catalogue; separate submission. | Out of scope — this is a KOReader plugin, not a native Kindle app. |

**GitHub release checklist (F-32):**
1. `LICENSE` (AGPL-3.0) at repo root. ✔ added this phase.
2. `THIRD-PARTY-NOTICES.md` with the MIT texts + the CC BY 4.0 grant +
   change note. ✔ added this phase.
3. `README.md`: Credit, Licence, Contributing, and an "unofficial fan project,
   not affiliated / non-commercial" disclaimer. ✔
4. In-app **About** screen names Cristian Mihailescu, the CC BY 4.0 licence,
   magium-dev, and KOReader. ✔
5. Don't ship third-party logo/icon art unless it is in the CC BY 4.0 data set.
6. Naming: "unofficial", "port" — avoid anything that implies an official
   release (`magium-koreader (unofficial port)`, not "Magium for Kindle").
7. Courtesy (not blocking): a heads-up in the Magium community Discord with a
   link.

## 5. Recommendation *(7.5)* → [ADR-008](../../decisions/ADR-008-license-and-distribution.md)

- **Repo / plugin code:** **AGPL-3.0-or-later** (`LICENSE`).
- **Bundled Magium story text & UI/achievement JSON:** stays **CC BY 4.0**,
  © Cristian Mihailescu, attributed per §2. Not relicensed — it isn't ours to
  relicense.
- **Trademark:** "Magium" may function as a mark; for a free, non-commercial,
  clearly-labelled fan port the risk is low. Keep "unofficial" prominent; don't
  use official branding assets.
- **Permission needed to release:** **none** beyond honouring the two licences'
  attribution terms. **OQ-004 and OQ-005 both close** (see
  [`07`](07-risks-open-questions.md)).
- **Contributors:** welcomed under the repo's AGPL-3.0 (inbound = outbound; a
  short `CONTRIBUTING.md` states this). Story-text corrections must preserve
  CC BY 4.0 provenance.

## Findings

- **F-31** (§1, high): the binding licences are MIT (engine code, via
  magium-dev) and CC BY 4.0 (story text, direct from the family's release).
  Both are permissive and were chosen to enable ports. No permission request
  is required — closes OQ-004.
- **F-32** (§4, high): a free non-commercial GitHub release is fully permitted.
  The only hard obligations are attribution (CC BY 4.0 + MIT notice retention)
  and indicating that the text was reformatted. Checklist in §4.
- **F-33** (§3, medium): a KOReader plugin `require`d into KOReader's Lua state
  has a plausible "derivative of an AGPL work" reading. Licensing this plugin
  AGPL-3.0-or-later removes the question at no real cost, since MIT engine code
  combines into an AGPL aggregate cleanly. Recorded as ADR-008.
- **F-34** (§1, low): `magium-recrystallized` (AGPL) contributes nothing to the
  shipped artifact — it was a research reference only — so its copyleft is not
  engaged.
