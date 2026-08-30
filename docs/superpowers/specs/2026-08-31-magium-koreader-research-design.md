# Design: Magium-on-KOReader Research & Design Phase

- **Status:** Approved (2026-08-31); device target updated to Paperwhite 12th gen after Phase 0
- **Owner:** rishishwarmanu@gmail.com
- **Type:** Architectural (new project) — this document governs the *research/design phase only*, not implementation.
- **Related:** [`../../../research-plan.md`](../../../research-plan.md), [`../../../README.md`](../../../README.md), [`../../../SUMMARY.md`](../../../SUMMARY.md)

---

## 1. Problem statement

Magium is a text-based choose-your-own-adventure (CYOA) game by the late Cristian
Mihailescu. After the author's death, two community projects continue it with the
family's permission. It currently ships as HTML/web, Android, iOS, and desktop
builds — but not for e-ink readers.

The goal of this project is to determine whether Magium can be played on a
**Kindle Paperwhite 12th gen (2024) running KOReader**, and if so, how. Magium's
interaction model (scrolling prose + a short list of choice buttons + menus) maps
closely onto what KOReader and its plugins already do, which is what makes the
port plausible.

**This repo, for now, is a feasibility study and design dossier.** No
implementation happens until the research concludes and a separate design/spec
phase is approved. Implementation, if it happens, lands in this same repo later.

## 2. Goals / non-goals

### Goals of the research phase

- Produce a **human-readable, shareable** research dossier that a contributor on
  Discord/Reddit/MobileRead can read (in whole or in part) and immediately help with.
- Establish, with evidence, whether **full feature parity** is achievable on the
  target device: narrative + branching conditions + stats and stat-checks +
  achievements + multi-slot saves + settings/themes, across all three books.
- Compare the viable end-forms (standalone plugin / extend an existing plugin /
  convert to a supported format) and recommend one.
- Quantify effort, risk, and a rough timeline calibrated to the owner's context
  ("can read code, limited Lua", expecting community help).
- Leave a clean handoff: a defined set of open questions, each tagged with where
  to ask it, and a roadmap the design phase can pick up.

### Non-goals

- Writing production plugin code (deferred to a later, separately-approved phase).
- Continuing or modifying the Magium story content.
- Supporting non-Kindle KOReader targets as a primary concern (documented only
  where it is free to note).
- Committing to a distribution channel (researched, not decided).

## 3. Target definition: "full parity"

The web version (`magium-dev`) is the parity reference. Parity means a Kindle
player reproduces:

| Capability | Reference in `magium-dev` |
|---|---|
| Scene rendering with conditional paragraphs (`#if(...)` blocks) | `src/parser.js`, `src/renderers.js:renderScene` |
| Choices with conditions and variable assignments | `src/parser.js` (`choice(...)` regex) |
| Variable store + DNF ("OR of ANDs") condition evaluation | `src/utils.js:apply_conditions` |
| `set(var, value) if <condition>` scene effects | `src/parser.js` (`set(...)` regex) |
| Stat variables + stat-check display | `src/utils.js` (`stats_variables`, `statChecksToDisplay`, `parseStatCheck`) |
| Achievements (per book/chapter) | `data/en/achievements{1,2,3}.json`, `renderers.js` |
| `special:` choice hooks — `restart`, `saves`, `stats`, `checkpoint` | grep `special:` in `data/en/*.magium` |
| Multi-slot saves with name + date | `renderers.js:renderSaves`, `renderSavesByPage` |
| Settings / theming (Original, Catppuccin) | `templates/settings.ejs` |
| Localization (en, fr) | `data/locales.json`, `data/<lang>/ui.json` |
| Book/Chapter header derivation from scene ID | `src/utils.js:getHeaderFromId` |
| Hardcoded per-scene special cases | e.g. `renderers.js` checks for `B3-Ch04a-Introduction2`, `Ch6-Eiden-vs-dragon` |

Any parity gap discovered during research is recorded as an open question, not
silently dropped.

## 4. Reference material (siblings, not vendored)

The two upstream recreations live as **sibling folders** next to this repo. They
are referenced for analysis and for confirming functionality mapping; they are
not submodules or vendored copies. Cite them by relative path and commit hash.

| Repo | Path | Upstream | Commit seen at research start | License | Role |
|---|---|---|---|---|---|
| `magium-dev` (MagiumJS) | `../magium-dev` | https://github.com/thuiop/magium-dev | `51f5aa9` | MIT | **Primary porting base & differential oracle.** ~650 LOC plain-JS engine; parses human-readable `.magium` files at runtime; 54 English chapter files, 7.7 MB. |
| `magium-recrystallized` | `../magium-recrystallized` | https://github.com/Br3nnabee/magium-recrystallized | `0dcfd2e` | AGPL-3.0 | Secondary reference. Svelte + Rust/WASM; compiles story to a binary `.story` format — harder to bring to Kindle, but its WASM engine (`wasm_module/src/`) and save model are worth studying. |
| Original Magium | n/a | https://github.com/raduprv/Magium | — | see repo | Historical origin of the `.magium` format. |
| Magium-SDL | n/a | https://github.com/Colaboi2009/Magium-SDL | — | see repo | Another reference implementation cited by `magium-recrystallized`. |

**Finding (Phase 0, high confidence):** `magium-dev` is the better base for a
Lua port — small, readable, and format-driven, so the engine can be
reimplemented in Lua and the data files bundled as-is. `magium-recrystallized`'s
binary pipeline would have to be reproduced or bypassed.

## 5. Key external references

| Topic | URL |
|---|---|
| KOReader plugin list | https://kindlemodshelf.me/plugins |
| KOReader plugin development guide | https://kindlemodshelf.me/koreaderplugindev |
| Magium web game | http://www.magium.org/menu |
| Magium subreddit | https://www.reddit.com/r/Magium/ |
| Magium Discord | https://discord.com/invite/cF3EDRmK |
| KOReader (project) | https://github.com/koreader/koreader |

Live link status and archived copies are tracked in `docs/research/05-prior-art.md`.

## 6. Approach for running the research phase

**Chosen: modular research dossier (option B).** Separate numbered topic docs
under `docs/research/`, each independently shareable, driven by one
`research-plan.md` checklist, with `SUMMARY.md` aggregating current conclusions.

Rejected alternatives:

- **A — Single living report.** One large doc. Rejected: can't hand a helper just
  the relevant slice; harder to review carefully.
- **C — GitHub wiki + issues.** Rejected for primary storage: splits content from
  the repo, weaker offline, heavier setup. GitHub issues may be layered on later
  for tracking without moving content.

### Methods baked into the plan (how comparable projects are actually done)

1. **Prior-art scan first** — find everyone who did the adjacent thing (IF/Glulx
   on e-ink, existing KOReader game/IF plugins, Twine/Ink players, past
   Magium-on-e-reader attempts) and record what broke + who to ask.
2. **Constraints budget** — enumerate device hard limits under KOReader, then
   check Magium's demands against them before committing to an approach.
3. **De-risking spikes, not just desk research** — the owner has a Kindle running
   KOReader, so the plan schedules named throwaway spikes (fork the simplest
   plugin, hard-code one scene, run on-device) to answer the riskiest questions
   cheaply.
4. **Reference-oracle / differential approach** — keep `magium-dev` runnable
   locally; diff any ported logic against it on identical inputs.
5. **Data-format-first** — pin down the `.magium` grammar and build a
   construct corpus before any UI work; this also underpins a format-conversion
   approach.
6. **Lightweight design doc / RFC** — circulate written design for comment before
   building (this document and its successors).

## 7. Repo structure

```
magium-koreader/
  README.md                     project intro, current status (RESEARCH), links to dossier + upstreams
  SUMMARY.md                    living "what we know so far" — conclusions, current recommendation, confidence
  research-plan.md              executable checklist: phases -> tasks -> deliverables -> status
  CLAUDE.md                     guidance for AI agents working in this repo
  LICENSE                       deferred — chosen in Phase 7 (note upstream MIT vs AGPL split)
  docs/
    decisions/
      README.md                 how to write an ADR here
      ADR-000-template.md
      ADR-001-research-dossier-layout.md
    research/
      00-overview.md            problem statement, goals, non-goals, success criteria, glossary
      01-magium-analysis.md     engine semantics, state model, stats/achievements/saves, i18n
      02-magium-format-spec.md  .magium grammar + every construct found across the 54 files, with examples
      03-koreader-platform.md   plugin API, Lua env, UI widgets, persistence, lifecycle, deploy/debug loop
      04-constraints-budget.md  device hard limits vs. what Magium needs — the go/no-go table
      05-prior-art.md           IF-on-e-ink, existing KOReader game/IF plugins, past attempts, contacts map
      06-approach-comparison.md standalone plugin vs. extend existing vs. format conversion — decision matrix
      07-risks-open-questions.md risk register; every open question has a stable ID + venue tag
      08-licensing.md           upstream licenses, family-permission chain, distribution constraints
      09-roadmap-effort.md      phased implementation roadmap, effort bands, timeline, milestones, handoff
    spikes/
      README.md                 spike log index + how to record a spike
      <NN-slug>/                one folder per spike: HYPOTHESIS.md, throwaway code, FINDING.md
    specs/                      empty until the design phase — implementation specs land here later
    superpowers/
      specs/
        2026-08-31-magium-koreader-research-design.md   (this file)
  reference/
    magium-dev-notes.md         how to run it locally as the differential oracle; output-capture method
    magium-recrystallized-notes.md  binary .story pipeline + WASM engine notes
```

## 8. Documentation & traceability conventions

**Every artifact in this repo must be traceable.** Any AI agent or human should
be able to find, from a claim, the evidence behind it; from a decision, the
reasoning and alternatives; and from an open problem, its current status and
owner. The rules:

### 8.1 Every doc has a standard header

```
# <Title>

- Status: draft | in-review | stable | superseded
- Last updated: YYYY-MM-DD
- Phase: <research-plan phase this belongs to>
- Sources: <links / repo paths / forum threads this doc is built from>
- Related: <relative links to sibling docs, ADRs, spikes, open questions>
```

### 8.2 Every non-obvious claim carries a citation

Inline, right after the claim. Accepted citation forms:

- Code: `` `../magium-dev/src/parser.js:72` `` (path + line; include the commit
  hash if the file may move: `@51f5aa9`).
- Web: a full URL **plus** an archive link (`web.archive.org`) captured the same
  day, because forum posts and wikis disappear.
- Forum/Discord/Reddit: link + author handle + date + a one-line quote of the
  relevant point (screenshots saved under the owning doc's folder if the source
  is volatile).
- Spike: `` [spike 03](../spikes/03-lua-condition-eval/FINDING.md) ``.

### 8.3 Confidence tags

Findings are tagged `confidence: high | medium | low` with a one-line reason
(e.g. "verified on-device", "inferred from source, not run", "single forum post,
unconfirmed"). `SUMMARY.md` never states a conclusion more confidently than its
underlying finding.

### 8.4 Decisions are ADRs

Every decision that closes off an alternative gets an Architecture Decision
Record in `docs/decisions/` (`ADR-NNN-slug.md`): context, options considered,
decision, consequences, date, status. Superseding a decision means a new ADR that
links back, and the old one's status becomes `superseded`. ADR-001 records the
dossier-layout decision from this document.

### 8.5 Open questions have stable IDs

`docs/research/07-risks-open-questions.md` holds a table of `OQ-NNN` entries:
question, why it matters, current status, **venue** (KOReader Discord / MobileRead
/ r/koreader / Magium Discord / specific plugin author / spike needed), owner,
resolution + link when closed. Other docs reference questions as `OQ-017`, never
by restating them. Closed questions stay in the table with their resolution.

### 8.6 Cross-linking

Relative links only (works on GitHub, offline, and in editors). When doc A relies
on a fact established in doc B, A links to the specific section of B rather than
duplicating it. `SUMMARY.md` links to the doc for every claim it makes.

### 8.7 Running log

`research-plan.md` carries a dated changelog at the bottom: what was done, what
changed, what's next. Each work session appends an entry. This is the fastest way
for a returning agent or human to see where things stand.

### 8.8 Glossary

`docs/research/00-overview.md` maintains a glossary (stillwater, stat-check,
scene ID, DNF conditions, `special:` hook, LuaSettings, e-ink refresh, ...) so
shared docs are readable by people who know KOReader but not Magium, or vice
versa.

## 9. How research findings are validated

This phase produces documents, not code, so "testing" means:

- **Source-grounded:** every engine-behavior claim is traced to a specific line
  in `magium-dev` (or verified against the running web version).
- **Oracle-checked:** any behavior we intend to reproduce is confirmed by running
  `magium-dev` locally with known inputs and capturing the output
  (`reference/magium-dev-notes.md` documents the method).
- **Spike-verified:** anything that depends on how KOReader behaves *on the
  actual device* (memory, refresh, widget limits, deploy loop) is confirmed by a
  throwaway spike on the owner's Paperwhite, not by documentation alone.
- **Peer-reviewed:** the dossier is written to be handed to KOReader/Magium
  community members; their corrections feed back as new findings with citations.

## 10. Phased research plan (summary)

Full task breakdown and status live in `research-plan.md`. Phases:

| # | Phase | Primary deliverables |
|---|---|---|
| 0 | Baseline & setup | `00-overview.md`, `reference/magium-dev-notes.md`, device/KOReader facts |
| 1 | Magium analysis | `01-magium-analysis.md`, `02-magium-format-spec.md` |
| 2 | KOReader platform | `03-koreader-platform.md` |
| 3 | Constraints budget | `04-constraints-budget.md` (go/no-go table) |
| 4 | Prior art | `05-prior-art.md` (+ contacts map) |
| 5 | De-risking spikes | `docs/spikes/*`, inputs to Phase 6 |
| 6 | Approach comparison & recommendation | `06-approach-comparison.md`, `07-risks-open-questions.md` |
| 7 | Licensing & permissions | `08-licensing.md`, `LICENSE` decision (ADR) |
| 8 | Roadmap, effort, timeline | `09-roadmap-effort.md`, handoff to design phase |

Phases 1–2 may overlap; 3 depends on 2; 5 depends on 1 and 2; 6 depends on 3–5.

## 11. Handoff / exit criteria

The research phase is done when:

- All nine `docs/research/*` docs are `stable`.
- `SUMMARY.md` states a recommended end-form with a confidence tag and links.
- Every `OQ-NNN` is either closed or explicitly deferred with a reason.
- `09-roadmap-effort.md` gives a phased implementation roadmap with effort bands
  and milestones.
- An ADR records the chosen approach.

At that point a new brainstorming/spec cycle starts for the implementation design.

## 12. Risks to the research phase itself

| Risk | Mitigation |
|---|---|
| Scope creep into implementation | HARD gate: spikes are throwaway and labeled; production code needs a new approved phase. |
| Upstream repos change mid-research | Cite by commit hash; note commit at research start (§4). |
| Volatile sources (forum posts, Discord) vanish | §8.2 requires archive links / saved screenshots. |
| Owner's limited Lua time becomes the bottleneck | Effort bands in Phase 8 assume "read code, limited Lua" + community help; spikes are scoped small. |
| `.magium` format has undocumented edge cases | Phase 1 builds an exhaustive construct corpus from all 54 files, not a sample. |
