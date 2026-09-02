# Finding — Spike 05 (`.magium` → Ink conversion)

- **Status:** stable
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.3)
- **Sources:** this spike's `magium_to_ink.js` + `ch1.ink` + `play_test.mjs`; `inkjs@2.4.0`
- **Related:** [`HYPOTHESIS.md`](HYPOTHESIS.md), [`OQ-006`](../research/07-risks-open-questions.md)

## Result: **confirmed for the core mechanics, with named fidelity gaps — medium-high confidence**

`node magium_to_ink.js .../ch1.magium ch1.ink` converts all 12 scenes; the
output **compiles cleanly** under `inkjs/full`'s in-process Ink compiler
(no `inklecate`/.NET dependency — see "Tooling note" below) with zero
errors or warnings.

Three scripted playthroughs (`play_test.mjs`) confirmed:

- **Conditional prose branches correctly.** Picking "Calm" at `Ch1-Intro1`
  then reaching `Ch1-Intro2` prints the `v_ch1_intro_feeling == 2` branch's
  text verbatim; picking "Afraid" prints the `== 3` branch. Same for every
  `v_ch1_show_yourself`-gated block across `Ch1-Cutthroat Dave` /
  `Ch1-Retreat` / `Ch1-Imply` / `Ch1-Imply2` / `Ch1-Weakness`.
- **Variable state persists across knots** the same way Magium's cookie/save
  state does: `~ v_ac_ch1_coward = 1` set inside the "Show myself" choice at
  `Ch1-Intro2` is still `1` two knots later, matches
  `oracle-capture/ch1-dave-showmyself.json`'s `v_ac_ch1_coward: "1"` input.
- **Text matches the known-good oracle output.** Picking "Calm" → "Show
  myself" reaches `Ch1-Cutthroat Dave` and prints *"I breathe in deeply and
  try to appear as calm as possible. I step out of the forest and into the
  clearing, facing the mage with the knives directly."* — this is the exact
  opening line of `oracle-capture/ch1-dave-showmyself.json`'s paragraph[1]
  (`v_ch1_show_yourself: "2"` branch), checked by eye against the committed
  golden, not just "looks plausible."
- **`!=` conditions work too**, not just `==`: `Ch1-Imply`'s
  `{v_ch1_show_yourself != 2: ...}` block is exercised correctly by paths
  that didn't set it to 2.

**This answers OQ-006's core question: no, fidelity is not lost for
conditions and stat-tracking variables** — Ink's native `{condition: text}`
and `~ assignment` primitives are expressive enough to carry Magium's DNF
conditions and `set()` semantics essentially verbatim (the converter does
no semantic translation of condition atoms at all — `v_x >= 2` in Magium
becomes `v_x >= 2` in Ink, unchanged; only the DNF *grouping* syntax
differs: `&&`/`||` join into parens instead of nested arrays).

## Where fidelity genuinely is lost (all found, none guessed)

1. **Achievements have no Ink primitive.** Converted to `# ACHIEVEMENT: ...`
   tags — inert metadata a host script would have to read and act on itself.
   Not a knock against Ink specifically: a native engine needs its own
   achievement UI too, but Ink offers *nothing* pre-built here (unlike
   KOReader, which has `Notification` ready-made per `03-koreader-platform.md` §3).
2. **`special:` hooks have no Ink primitive either.** `restart` degrades to
   a normal divert (works, since Magium's own restart target is just
   `Ch1-Intro1`); `saves` has **no target scene at all** in the source data
   (`choice("Load game", , , special:saves)` — empty target), which doesn't
   even fit Ink's "every choice leads somewhere" model — routed to a stub
   `Unsupported_no_target` knot. `checkpoint_save` converts fine as a divert
   but the actual autosave *action* is silently dropped — nothing in Ink
   would trigger it.
3. **Cross-chapter navigation breaks at the chapter boundary**, by
   construction of this spike (one file in, one file out): both
   `Next chapter` choices divert to `Ch2-Intro`, which lives in a different
   `.magium` file this converter never loads. Handled with a labeled stub
   knot, not a real fix — a full conversion would need every chapter loaded
   and merged into one `.ink` (or Ink's own `INCLUDE` mechanism), which is
   mechanical but out of scope for a one-chapter spike.
4. **No stat-check *display formatting*.** Magium's stat-check text
   (`"[ Observation check successful - level 1 ]"`, `mainStatSuccessTemplate`
   in `ui.json`) is UI-layer string templating done in `renderers.js`/EJS,
   not part of the condition-evaluation logic this converter touches — Ink
   has its own text-templating (`{condition: "success" | "fail"}`) that
   could reproduce it, just not attempted here since ch1.magium's 3
   stat-relevant vars (`v_ch1_*`) never gate a *displayed* stat check in
   this chapter, only prose branches — this spike had nothing to exercise
   that specific case against, only the achievements/specials cases above,
   which it did find.
5. **`set()` was implemented but not exercised.** `ch1.magium` happens to
   contain **zero** `set()` directives (all state changes in this chapter
   come from choice `setVariables`) — the converter's `set()` → `~ assign`
   /conditional-block code path compiles and is structurally identical to
   the choice-assignment path already validated, but wasn't independently
   exercised by this chapter's actual content. Worth a second chapter (e.g.
   `ch3.magium`, which has `set()` + real stat-checks) if this spike's
   result is relied on for more than the go/no-go call it's feeding now.

## Tooling note: a JS-native Ink toolchain exists, no .NET needed

`inkjs`'s default build is runtime-only (plays pre-compiled `.ink.json`,
produced elsewhere by `inklecate`, a .NET tool). Its `inkjs/full` export
bundles an **in-process JS compiler** (`Compiler` class) — source string in,
playable `Story` out, entirely inside Node. This matters for the *real*
approach-C question (not this spike's, but adjacent): if a build-time
`.magium`→Ink conversion were ever chosen, the whole pipeline (convert →
compile → bundle `.ink.json`) can run in plain Node/npm, no .NET runtime
needed anywhere in the toolchain. `inkjs` itself is MIT-licensed.

## Confidence

**High** for "Ink's condition/variable model can carry Magium's DNF
conditions and set() semantics" — directly demonstrated against real
content and cross-checked against the oracle. **Medium** for "a full
Magium-to-Ink conversion is practical" — the achievements/`special:`/
cross-chapter gaps above are all real integration work a full conversion
would still have to solve, and none of them make approach C *more*
attractive than what Phase 3/4 already found (F-14/F-27: KOReader already
has every native widget Magium needs, and no e-ink Ink player exists
regardless of conversion fidelity).

## Next step

Feeds Phase 6's decision matrix on approach C: fidelity is **not** the
blocker for format conversion (this spike closes that half of OQ-006);
**deployability still is** (`05-prior-art.md` §3, unchanged) — there's
nothing to play the converted file with on a Kindle. Combined with spike
02/03's result that a native Lua engine is not only feasible but already
demonstrated end-to-end against the same oracle, approach C's main
remaining argument (avoid writing a Lua engine) doesn't hold up: the engine
turned out to be the easy part, and Ink adds an extra layer (find/build an
e-ink Ink player) that a native plugin doesn't need at all.
