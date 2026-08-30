# Finding — Spike 02 (engine in Lua)

- **Status:** stable
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.2)
- **Sources:** this spike's code (`magium_parser.lua`, `magium_utils.lua`,
  `render_scene.lua`, `spike_run.lua`); run under **LuaJIT 2.1.1703358377**
  (`luajit -v`) — the same major/minor line KOReader v2026.07.1 bundles
  (2.1.ROLLING, `03-koreader-platform.md` §2), though not the identical build
- **Related:** [`HYPOTHESIS.md`](HYPOTHESIS.md), [`OQ-008`](../research/07-risks-open-questions.md), [spike 03](../03-full-corpus-memory-parse/FINDING.md)

## Result: **confirmed, high confidence**

```
$ luajit spike_run.lua /home/user/magium-dev/data/en <outdir>
parsed 150 scenes from 3 files
rendered ch1-intro1                   1p 3c 0s
rendered ch1-dave-showmyself          3p 2c 0s
rendered ch1-showmyself-quotequote    3p 2c 0s
rendered ch3-vantage-statchecks       2p 3c 2s
rendered ch3-vantage-nostat           2p 3c 1s
rendered b2ch1-intro-checkpoint       1p 1c 0s

$ node ../../../reference/tools/oracle-diff.js diff ../../../reference/tools/oracle-capture <outdir>
ok   b2ch1-intro-checkpoint.json
ok   ch1-dave-showmyself.json
ok   ch1-intro1.json
ok   ch1-showmyself-quotequote.json
ok   ch3-vantage-nostat.json
ok   ch3-vantage-statchecks.json

6/6 match
```

**6/6 structural matches against `magium-dev`'s own committed goldens**, no
edits to the goldens or to the diff harness. Every field of the canonical
scene shape matched exactly: prose (with `<br/>` line-break markers and
whitespace collapsing intact), the doubled-quote `""spoken text""` choice-label
idiom, per-choice `setVariables`, two live stat-checks with their formatted
`"[ Ancient languages check successful - level 2 ]"`-style text, an
achievement unlock, and the `v_checkpoint_rich === "0"` checkpoint banner
flag.

**Full-corpus structural check (spike 03 bonus finding):** running this same
parser, completely unmodified, over all 54 files produced **scene/paragraph/
choice/`set()` counts that exactly match** the JS baseline
(2159 / 4880 / 3734 / 594 — see [`../03-full-corpus-memory-parse/FINDING.md`](../03-full-corpus-memory-parse/FINDING.md)).
That's a much stronger fidelity signal than the 6 diffed fixtures alone: the
hand-written boundary-scan matchers (standing in for JS's named-capture
regexes — Lua patterns don't have those) behave correctly across every line
of the real corpus, not just the slice that was diffed byte-for-byte.

## What this answers

**OQ-008** (does a faithful port need to fix latent parser bugs, or copy
them?) — this port **copies** them deliberately (documented inline in
`magium_parser.lua`'s header: `currentParagraph` not reset across scene
boundaries; the bogus leading placeholder scene). Both are harmless for the
current corpus (Phase 1's construct-corpus scan already established this),
and copying them keeps this spike's job — proving portability — separate
from the judgment call OQ-008 leaves for the real port (assert, not
silently diverge, per `02-magium-format-spec.md` §4).

This also substantially de-risks the largest remaining unknown from
Phase 3/4: **the engine port is mechanical, not just "should be small"**
(F-9's ~640 LOC estimate) — a working, corpus-validated Lua translation of
the hardest logic (condition DNF evaluation, the parser's five regex-shaped
constructs) took one focused session with no genuinely novel design
decisions, only careful boundary-condition translation.

## Deliberate simplifications (and why they don't undermine the result)

1. **No EJS/HTML round-trip.** This spike builds the canonical scene shape
   directly from parsed data (mirroring `renderers.js:renderScene()`'s
   pre-template pipeline), instead of rendering HTML and re-parsing it the
   way `oracle-diff.js`'s *oracle*-side normalizer must (because the oracle
   is only reachable over HTTP as rendered HTML). This is strictly a more
   direct comparison, not a weaker one — it exercises the same condition
   logic and skips only presentation-layer plumbing (EJS templating, HTML
   entity round-tripping) that the port will replace with KOReader widgets
   anyway, never with EJS.
2. **`ui.json` is hand-transcribed, not parsed.** The ~16 locale-string
   keys these 3 files' scenes touch (14 `statsXxxText` names + the two
   stat-check templates) are hardcoded in `spike_run.lua` rather than
   writing a JSON *decoder* in Lua — this spike is about the parser/condition
   engine, and KOReader ships `rapidjson` (`03-koreader-platform.md` §2) for
   the real port, so a hand-rolled decoder here would be throwaway effort
   twice over. `json.lua` in this spike is encoder-only.
3. **Header template is a 2-line format, not full EJS.** `getHeaderFromId`
   + a literal `"Book X - Chapter Y"` build stand in for
   `ejs.render(mainHeaderTemplate, ...)`; `render_scene.lua` does carry a
   tiny generic `<%= key %>` substitution (`ejs_lite`) for the stat-check
   templates, which is the only other EJS use in scope.
4. **Choice/`set()`/`achievement()` matching is hand-written boundary scans,
   not literal regex translation** — Lua patterns lack named captures and
   true backtracking. Each scan is commented with the exact JS-regex
   backtracking behavior it reproduces (e.g., "greedy `.*` finds the LAST
   comma/quote-pair that leaves a valid tail"). The full-corpus structural
   match (above) is the empirical check that this reproduction is faithful,
   not just plausible-looking.

## One real bug found and fixed during porting

Lua's `%w` pattern class is alphanumeric-only — unlike JS's `\w`, it does
**not** include `_`. Every Magium variable name is `v_snake_case`, so the
first version of `apply_condition`'s pattern silently failed on every
condition (logged "Condition fail", matching the JS code's own diagnostic
message for its `console.log` fallback branch, so the failure surfaced
immediately rather than silently). Fixed by using `[%w_]` wherever a JS
`\w` was being translated. **This is exactly the kind of trap the design
doc's "KOReader-API is the real ramp, Lua is a fast pickup" framing (F-4,
design doc §12) undersells slightly** — Lua syntax is close enough to look
like a copy-paste job and isn't; small semantic gaps between Lua patterns
and JS/PCRE regex are a real, if minor, translation cost worth budgeting a
little time for in Phase 8's effort estimate.

## Confidence

**High** for "the engine's logic ports to Lua faithfully" — validated
against real story content via the existing differential-oracle method, not
inferred from reading source. **Medium** (unchanged from Phase 1) for
whether the *parity-critical special cases* (`01-magium-analysis.md` §10)
all port equally cleanly — none of the 4 scenes in this slice happen to hit
one; that risk is unaffected by this spike and stays open for the real
implementation phase to work through case-by-case, not exhaustively
re-spiked here.

## Next step

Feeds Phase 6 directly: this is the strongest evidence yet for approach A/D
(standalone Lua plugin/hybrid) over anything requiring a format conversion
(approach C) — the engine itself is not the risk. Not spiked here and still
open: the 490 KB condition outlier's *runtime cost* under this same
`apply_conditions` implementation (OQ-011 — would need `b3ch4a.magium`
included in a future spike's file list, deliberately out of scope for this
one) and the KOReader-widget side of things (spike A, blocked this session
— see [`../04-ui-plugin-skeleton/FINDING.md`](../04-ui-plugin-skeleton/FINDING.md)).
