# 05 — Prior art & contacts map

- **Status:** stable (tasks 4.1–4.5 complete from web research 2026-08-31; 4.6's
  outreach drafts remain prepared but intentionally unsent — deferred with
  OQ-004 under [ADR-003](../decisions/ADR-003-defer-licensing-distribution.md),
  not a gap, see §6)
- **Last updated:** 2026-08-31
- **Phase:** 4
- **Sources:** web search + fetch, 2026-08-31 — KOReader GitHub, MobileRead
  Forums, intfiction.org, IFWiki, F-Droid, KindleModShelf, `awesome-koreader`,
  personal blogs (adq/lidskialf.net, fabiszewski.net). No `web.archive.org`
  captures yet — this session's fetch tool cannot reach the Wayback Machine
  (same limitation noted in [`03` sources](03-koreader-platform.md)); an
  archival pass is a loose end for whoever shares this doc externally.
- **Related:** [`03-koreader-platform.md`](03-koreader-platform.md) §1/§3
  (`frotz.koplugin` as UI prior art), [`06-approach-comparison.md`](06-approach-comparison.md),
  [`07-risks-open-questions.md`](07-risks-open-questions.md) OQ-003/OQ-004/OQ-006

> Goal: learn from people who did the adjacent thing, and build the map of which
> question goes to which venue — the later "help me with X" asks depend on this.

---

## 1. Interactive fiction on e-ink *(4.1)*

Z-machine/Glulx/TADS interpreters on Kindle have a long, mostly community-driven
history — nearly all of it text-first, native-widget rendering rather than a
document/browser view, which validates the same choice this project is leaning
toward (F-14/F-15, [`03` §1/§3](03-koreader-platform.md)).

| Project | Platform | Approach | Status / notes |
|---|---|---|---|
| **`kbarni/frotz.koplugin`** | KOReader (all devices) | Bocfel (Z-machine) + Git (Glulx) linked via RemGlk's JSON protocol; renders through **native KOReader widgets** (real status bar, styled text, single-key + line input), no embedded-image support. GPLv3. | Active, 25 commits, 24★. Already cited in [`03` §1](03-koreader-platform.md#1-plugin-anatomy-21) as the closest direct UI prior art — a fullscreen styled-transcript + input-row shape on e-ink. <https://github.com/kbarni/frotz.koplugin> |
| **`anserina/kofrotz.koplugin`** | KOReader | Wraps the `dfrotz` interpreter directly (older, simpler than the RemGlk approach). Z-machine only (`.z1`–`.z8`, `.zlb`, `.zlo`, `.zblorb`). | Alternative/predecessor approach to the same problem — a second data point that a `dfrotz`-style pipe-to-subprocess design also works inside KOReader. <https://codeberg.org/anserina/kofrotz.koplugin> |
| **KIF** (Andrew "adq" de Quincey) | Kindle native (jailbroken, KDK) | Native Kindle app using `zmpp` as the Infocom VM, run through the Kindle Development Kit APIs (pre-KOReader era). | 2010, alpha (v0.5), dormant since. Needed a jailbreak + dev keys; author flagged styled text / auto-persistence as unfinished. Useful negative data point: **native-KDK Kindle apps were viable but stalled at "alpha" on unfinished polish**, not on a fundamental blocker. <https://blog.lidskialf.net/2010/10/09/kif-an-infocom-text-adventure-interpreter-for-the-kindle/> |
| **Kindle port of Gargoyle** (Jakub Fabiszewski) | Kindle native, via KUAL launcher (no jailbreak) | Ports Gargoyle (14+ IF formats: Z-machine, Glulx, TADS, Hugo, AGiliTy, Alan, JACL, Quest, Magnetic, Level 9, Scott Adams) with Gargoyle's own typography/layout engine. | 2011–2012, reached a "v0.2 alpha" with a maintained config for fonts/margins/colors. Shows KUAL (no-jailbreak launcher) as an alternative install path predating KOReader's own plugin model. <https://www.fabiszewski.net/kindle-gargoyle/> |
| **Fabularium** (Tim Cadogan-Cowper, fork by David A Roberts) | Android | Broadest format coverage found (Adrift, AdvSys, AGT, Alan 2/3, Glulx, Hugo, Level 9, Magnetic Scrolls, Scott Adams, TADS 2/3, Z-code) plus an in-app authoring IDE. Open source, F-Droid. | Original Play Store build unmaintained; F-Droid fork active. Android, not e-ink-specific — no notes found on e-ink refresh handling. Relevant mainly as a UI/format-breadth reference, not a KOReader precedent. <https://f-droid.org/packages/io.davidar.fabularium/> |
| **MobileRead: "Kindle Paperwhite: Frotz or other Z-Machine interpreter?"** (2012–2013 thread) | Kindle Paperwhite (jailbroken) | Community walkthrough of getting Frotz running via a `/mnt/us/if/` game folder. | No performance/UI complaints recorded — thread is purely "does it run," and it did. Contributors: `twobob` (confirmed working), `geekmaster`, `knc1`. <https://www.mobileread.com/forums/showthread.php?t=200761> |

**Reading for this project:** every native/jailbreak-era Kindle IF interpreter
(KIF, Gargoyle port) eventually lost momentum to the *KOReader plugin* model —
`frotz.koplugin` is the living, maintained one, and it's already our closest UI
analog (F-15). This is one more point in favor of building on top of KOReader's
plugin API rather than a bespoke native/jailbreak app: it's the platform where
this exact genre of project (styled-text interpreter + choice/input line on
e-ink) is currently alive and maintained, not the platform graveyard.

## 2. Existing KOReader game / non-book plugins *(4.2)*

| Plugin | What it does | Relevant technique | Link |
|---|---|---|---|
| `frotz.koplugin` / `kofrotz.koplugin` | IF interpreters (see §1) | fullscreen native-widget narrative UI | see §1 |
| `sudoku.koplugin`, `wordsearch.koplugin`, `crossword.koplugin` (omer-faruq / roygbyte) | Puzzle games rendered as a fullscreen non-document KOReader UI | Confirms puzzle/game-shaped plugins (not just document viewers) are a normal, accepted plugin category, and that `is_doc_only=false` fullscreen UIs (F-14, [`03` §7](03-koreader-platform.md#7-lifecycle--integration-27)) are a well-trodden pattern, not novel | github.com/omer-faruq/sudoku.koplugin, wordsearch.koplugin; github.com/roygbyte/crossword.koplugin |
| `connections.koplugin` (odrling) | NYT Connections puzzle | Same pattern | github.com/odrling/connections.koplugin |
| `rakuyomi` (hanatsumi, forks by tachibana-shin/kravenos) | Manga reader — browses/downloads/reads manga from external source ecosystems (Aidoku/Tachiyomi/Mihon/LNReader) inside KOReader | **Non-document fullscreen UI backed by an external Rust server** (JNI-bridged on Android via a companion app, native binary elsewhere) talking to KOReader's Lua frontend over a local API/SQLite — the most architecturally ambitious KOReader plugin found. Overkill for Magium (no external content source, no sync need), but confirms KOReader plugins can host a non-trivial content/state layer behind the UI if a project ever needed it. | github.com/hanatsumi/rakuyomi |
| `appstore.koplugin` (omer-faruq) | Discovers/installs/updates community KOReader plugins by searching GitHub for the `koreader-plugin` topic | Distribution channel — see §5/[`03` §10](03-koreader-platform.md#10-packaging--distribution-210). If a Magium plugin is tagged `koreader-plugin` on GitHub it becomes discoverable here for free. | omer-faruq.github.io/appstore.koplugin |
| **`awesome-koreader`** (curated list, two maintained forks: ruiribeiro04, jannick-holm) | Plugin/patch/tool directory | Best single index of the plugin ecosystem; **no CYOA/gamebook/visual-novel/narrative-choice plugin found in it** — only IF interpreters (§1) and generic puzzle games (this table) | github.com/ruiribeiro04/awesome-koreader |
| `KindlePaperWhite6` non-KOReader games (KindleModShelf) | Terminal Tetris, Gnome Chess/Minesweeper ports, Gambatte-K(2) GB/GBC emulators, Connect Four, Mahjongg, Draughts, Klondike, Xiangqi, plus IF in Z-machine/Glulx/TADS | These are **not** KOReader plugins — separate native jailbreak-side apps distributed via KindleModShelf, running alongside or instead of KOReader | kindlemodshelf.me |

**Answers OQ-003 (partial):** no existing KOReader plugin plays Twine/Ink/
gamebook content today. The closest thing is `frotz.koplugin`'s IF-interpreter
UI shape, not a CYOA/branching-prose engine. **Nothing to reuse at the plugin
level — the Lua engine reimplementation (approach A/D) still has to be written
from scratch**, but the UI toolkit choice is de-risked by precedent (confirms
[`03` §3](03-koreader-platform.md#3-ui-toolkit-inventory-23)/F-14).

## 3. Twine / Ink / ChoiceScript players on constrained hardware *(4.3)*

The recurring theme across every venue: **Twine's HTML5+JS output is the
practical dead end for e-ink**, while native/precompiled approaches (what this
project is already leaning toward, [`04` §4](04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34))
are what actually ships.

- **PocketBook + Twine, "in the built-in browser"** (MobileRead, Oct–Nov 2024,
  users `hotdaisy`/`neil_swann80`/`diegoocampo`, playing *Trigaea*): works only
  because PocketBook ships a real WebView-class browser that permits local
  file access (unlike Android browsers, per the thread). Even then: **RAM climbs
  over a session, background audio drops after ~15 min, and refreshes
  sometimes need a manual tap-then-swipe to trigger** — i.e. *even with a full
  browser engine available*, Twine-as-HTML5 needs workarounds on e-ink.
  KOReader has no such general-purpose JS-capable browser view — its HTML
  renderer path is MuPDF-based document rendering (F-19,
  [`03` §5](03-koreader-platform.md#5-text-rendering-25)), not a JS runtime —
  so this route is **not available to us at all**, reinforcing the existing
  decision to hand-parse `.magium` in Lua rather than embed the JS engine.
  <https://www.mobileread.com/forums/showthread.php?t=364199>
- **"Gamebooks on Kindle 3"** (MobileRead, older thread): the OP tried
  converting Twine HTML/RTF output to MOBI via Calibre/MobiPocket — hyperlink
  navigation **did not survive conversion**; the fix suggested was authoring
  location-based (not page-based) links by hand. Also surfaces **KIF** (§1) as
  the "native, works-offline" alternative to a browser-based Parchment
  interpreter — the same native-vs-browser tradeoff this project already faces.
  <https://www.mobileread.com/forums/showthread.php?t=104482>
- **Fighting Fantasy gamebooks on Kindle (Worldweaver Ltd, Feb 2011)** — the
  one commercial, non-Twine precedent found: a bespoke Kindle app (not a
  document format) automated dice rolls/inventory and drew a live dungeon map.
  User complaint (`Ticallion`): **"the map takes a long time to load... Kindle
  just isn't powerful enough to process it at a decent speed."** Directly
  relevant as a **cautionary data point for OQ-011/OQ-007**: even a
  purpose-built native Kindle app hit CPU limits on a *rendering* feature (a
  redrawn map), not core text logic — supports keeping any Magium equivalent
  (e.g. a stats/progress screen) simple and reinforces "avoid recomputing
  expensive things per-render" (the same principle behind the OQ-011
  mitigation list, [`04` §3](04-constraints-budget.md#3-budget-table-33)).
  <https://www.mobileread.com/forums/showthread.php?t=121074>
- **Choice of Games on Kindle** (`Choice of the Dragon`, `Choice of Broadsides`,
  Dec 2010): released as Kindle Store apps, reported to "feel quite at home on
  the Kindle" (`bcressey`, Feb 2011) — but the thread doesn't say whether this
  targeted e-ink Kindles or Kindle Fire (Android), and no technical detail on
  how ChoiceScript was ported survived in the discussion found. **Inconclusive
  — flagged, not a resolved data point.**
  <https://intfiction.org/t/choice-of-games-releases-interactive-fiction-apps-for-kindle/1609>
- **Ink** (inkle, MIT, <https://github.com/inkle/ink>): open-source, has a
  small portable C#/reference-runtime story format, but no e-ink or KOReader
  port found anywhere in this search. Noted for **OQ-006** (could `.magium`
  be losslessly represented in Ink?) as a live option worth a spike-C
  comparison against Twee, not as existing prior art.

**Net for OQ-003/OQ-006:** no one has shipped a Twine/Ink/ChoiceScript
*player* on e-ink hardware — every precedent either (a) leans on a full
browser/JS runtime KOReader doesn't have, or (b) is a bespoke native app, i.e.
exactly the "reimplement the engine natively" approach (A/D) already favored
by [`04` §4](04-constraints-budget.md#4-runtime-parsing-vs-build-time-preprocessing-34).
This is a point of evidence *against* approach C (convert `.magium` to Twine/Ink
+ use an existing player) for Phase 6 — there is no existing player to use.

## 4. Past attempts to put Magium (or a similar CYOA) on an e-reader *(4.4)*

**No evidence found** of anyone previously attempting a Magium port to Kindle,
KOReader, or any e-reader — across web search, MobileRead, r/koreader-adjacent
queries, and Discord-invite discovery. This is a **negative result**, not an
exhaustive one: it only rules out anything indexed/discoverable via general web
search; it does **not** rule out unindexed Discord conversation history (search
engines don't crawl Discord messages) — that requires actually looking inside
the Magium Discord itself (§6/OQ-004 venue).

Two live Magium Discord servers were found (previously only one, without a
verified invite, was on record in [`07`](07-risks-open-questions.md) OQ-004 /
CLAUDE.md):

- **Magium Community** — <https://discord.com/invite/Aw5sEYPPXv> (~1,432
  members, general community)
- **Magium Writer Team** — <https://discord.com/invite/WWDCcyaspH> (~1,026
  members, story-writing side)

Neither has been confirmed against the `#dev`-channel invite
(`https://discord.com/invite/cF3EDRmK`) already on record in
[`07-risks-open-questions.md`](07-risks-open-questions.md); that link predates
this session and was not re-verified here. **Action for whoever does the
outreach (§6):** check whether `cF3EDRmK` still resolves, and if not, use
`Aw5sEYPPXv` (community) as the entry point — the OQ-004/permission question
likely needs a maintainer inside the Writer Team server specifically, since
that's where story-content ownership questions would be answered.

## 5. Contacts map *(4.5)*

| Question type | Best venue | Link / handle | Notes |
|---|---|---|---|
| KOReader plugin API / widget internals, blocking-work idioms, e-ink refresh semantics | KOReader GitHub Discussions | <https://github.com/koreader/koreader/discussions> | Official; maintainers active here (example precedent: Discussion #12059, a plugin-dev help request that got answered). Best venue for OQ-002/OQ-007 follow-ups a spike can't resolve alone. |
| KOReader on Kindle-specific quirks (jailbreak status, `kindlehf` build issues, device idiosyncrasies) | MobileRead Forums — "Amazon Kindle" + KOReader-adjacent subforums | <https://www.mobileread.com/forums/forumdisplay.php?f=50> | Long institutional memory (threads found here span 2010–2024); good for OQ-009-style "does it stay stable" questions and general Kindle jailbreak/dev-key context. |
| General KOReader usage / community troubleshooting | r/koreader | (not directly queried this session — no unique finding beyond GitHub Discussions/MobileRead) | Lower priority than GH Discussions for anything code-shaped. |
| Magium engine / story-data questions, general dev chat | Magium Community Discord | <https://discord.com/invite/Aw5sEYPPXv> | New link found this session (§4) — verify against the existing `cF3EDRmK` reference before using. |
| Magium licensing / family's redistribution permission (**OQ-004**) | Magium Writer Team Discord (story owners) | <https://discord.com/invite/WWDCcyaspH> | This is a **permission** question, not a technical one — needs whoever holds the family's authorization, most likely reachable via the writer/maintainer side, not the general community server. |
| IF interpreter internals, format comparisons (Ink/Twee/Z-machine), general "is this feasible" sanity checks | intfiction.org forum | <https://intfiction.org> | Active, technically deep (e.g. the 2010 Choice-of-Games-on-Kindle thread ran for months); good venue for an OQ-006-style "can `.magium` map onto Ink/Twee losslessly" question once spike C exists to ask about concretely. |
| Prior-art authors directly, if a specific technical question about their approach comes up | `kbarni` (frotz.koplugin), Jakub Fabiszewski (Kindle Gargoyle), Andrew de Quincey / `adq` (KIF) | GitHub profiles / blog contact pages linked in §1 | Cheap to ask narrow, specific questions (e.g. "did you hit any RemGlk perf issues on `KindlePaperWhite6`?") once there's a concrete spike-A finding to compare notes on — not before. |

## 6. Outreach *(4.6)*

**No outreach has been sent.** This session has no Discord, Reddit, or
MobileRead account access — posting under the owner's identity on external,
persistent, publicly-visible platforms is exactly the kind of hard-to-reverse,
externally-visible action this project's working agreement reserves for the
owner to do directly (see repo-level operating rules on irreversible/external
actions). Sending it here would also mean fabricating what such a post looks
like without being able to verify delivery or read the reply.

Instead, three outreach drafts are prepared below, each tied to a blocking OQ,
for the owner to post personally when convenient. Record responses back into
this file's Outreach log (add rows as they come in) and resolve the linked OQ.

**Draft 1 — Magium Writer Team Discord (OQ-004, redistribution permission).**
> Hi! I'm doing feasibility research on porting Magium to run offline on a
> Kindle e-reader (via KOReader, an open-source reader app) — parsing the
> `.magium` story files locally, no hosting/redistribution of the game as a
> product, just a reader-side interpreter you'd point at your own copy of the
> game data. Before I get further into implementation, I want to check: does
> the family's existing permission for community projects like `magium-dev`
> extend to this kind of port, and is there anyone I should loop in about it?

**Draft 2 — KOReader GitHub Discussions (OQ-002/OQ-007, once spike A has a
concrete finding to report or a specific blocker).**
> Working on a KOReader plugin that renders branching narrative text + a
> choice list, fullscreen, on a Kindle Paperwhite 12th gen (`KindlePaperWhite6`).
> [insert spike-A finding: e.g. "`"ui"` refresh feels fine for scene swaps but
> X happens when Y"] — is there a recommended pattern for [specific thing],
> or has anyone hit this with `frotz.koplugin` or a similar fullscreen
> text-transcript plugin?

**Draft 3 — `kbarni` (frotz.koplugin author), via GitHub issue/discussion on
that repo (only after spike A, if a RemGlk/native-widget-specific question
remains).**
> Really appreciate frotz.koplugin — using it as a UI reference for a
> different KOReader narrative-text plugin (Magium, a choice-based story). Did
> you run into [specific e-ink/perf/widget issue] on the Paperwhite line, and
> if so how did you handle it?

### Outreach log

_(none yet — see drafts above)_

## Findings

- **F-26** (§1, high confidence): every prior IF-interpreter effort on Kindle
  converged on the same shape this project is already planning — native/
  in-app text rendering with a fullscreen custom UI, not a browser/document
  view. `frotz.koplugin` is the living, maintained example inside KOReader
  itself and remains the closest direct precedent (reinforces F-14/F-15).
- **F-27** (§3, high confidence): no browser-based Twine/Ink/ChoiceScript
  player exists that could be pointed at `.magium`-derived content on this
  platform — KOReader's HTML path is MuPDF-based document rendering, not a JS
  runtime (F-19), and even devices that *do* have a real browser (PocketBook)
  show RAM growth and refresh glitches running Twine's HTML5 output over a
  session. This is evidence against approach C (format-conversion +
  existing-player) for the Phase 6 comparison — no existing player to convert
  to.
- **F-28** (§3, medium confidence): the one commercial CYOA-on-Kindle
  precedent (Fighting Fantasy, Worldweaver 2011) hit a CPU wall specifically
  on a *redrawn map/graphic* feature, not core branching-text logic — a data
  point supporting the existing OQ-011 mitigation stance (cache/avoid
  per-render recomputation of anything non-trivial) rather than a new
  concern.
- **F-29** (§4, medium confidence — absence-of-evidence): no prior Magium-
  on-e-reader attempt is discoverable via web search. Does not rule out
  undiscoverable Discord history; two live Magium Discord invites found
  (§4) for the owner to check directly, one of which may supersede the
  `cF3EDRmK` link on record in [`07`](07-risks-open-questions.md).
- **F-30** (§2, high confidence): scanning `awesome-koreader` plus KOReader's
  own plugin ecosystem turns up puzzle-game plugins and one architecturally
  large content-sync plugin (`rakuyomi`), but **zero** CYOA/gamebook/visual-
  novel plugins — confirms OQ-003's answer is "no," and that the Lua engine
  for Magium has to be written from scratch (no shortcut via an existing
  narrative-plugin codebase to extend/fork — narrows out approach B).
