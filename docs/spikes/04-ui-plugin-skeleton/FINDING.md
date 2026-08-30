# Finding — Spike 04 (UI plugin skeleton)

- **Status:** stable (as a partial result — explicitly not closing OQ-002/OQ-007)
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.1)
- **Sources:** this spike's `magium_spike.koplugin/main.lua`
- **Related:** [`HYPOTHESIS.md`](HYPOTHESIS.md), [`OQ-002`](../research/07-risks-open-questions.md), [`OQ-007`](../research/07-risks-open-questions.md)

## Result: **code written and grounded in real APIs — not run, at any level**

`magium_spike.koplugin/main.lua` exists, cites real `v2026.07.1` source for
every widget/API call it makes, uses the real `Ch1-Intro1`/`Ch1-Intro2`
prose (not lorem ipsum), and passes a Lua syntax check
(`luajit -e "loadfile(...)"` → OK — that only proves the Lua parses, not
that KOReader's runtime accepts it, since none of `dispatcher`,
`ui/widget/textviewer`, `ui/uimanager`, etc. are loadable outside a
KOReader process).

### What's grounded, not guessed

- `TextViewer`'s `buttons_table` parameter shape
  (`{{ {text=,callback=}, ... }, ... }` — rows of buttons) was verified
  against a **real caller**
  (`../../../../koreader/frontend/apps/reader/modules/readerbookmark.lua:1267-1296`),
  not just TextViewer's own docstring, after confirming
  `textviewer.lua:48`'s `buttons_table = nil` field exists and
  `textviewer.lua:391-392` reads it (`local buttons = self.buttons_table or {}`).
- The plugin-registration boilerplate (`WidgetContainer:extend`,
  `Dispatcher:registerAction`, `addToMainMenu`, `is_doc_only = false`) is a
  direct structural copy of `../../../../koreader/plugins/hello.koplugin/main.lua`,
  the project's own minimal-plugin example (already cited as F-14's basis
  in Phase 2).
- The conditional-branch logic (`CH1_INTRO2_BRANCH[self.v_ch1_intro_feeling]`)
  mirrors the exact semantics spike 02 validated against the oracle
  (`v_ch1_intro_feeling == N` gating a paragraph) — inlined by hand here
  rather than driven through the parser, since this spike is about the
  *widget*, not the engine.

### What's NOT validated — and why, honestly

Attempted to get at least a functional (not perceptual) check by building
and running the `kodev` emulator in this session, the same way
`reference/setup-koreader-wsl.sh` resolved OQ-012 on the owner's Windows
machine. **Blocked for the identical reason [spike 03](../03-full-corpus-memory-parse/FINDING.md#blocked-could-not-get-a-real-koreader-environment-number)
was**: `./kodev fetch-thirdparty` needs GitHub release-tarball downloads
that this session's network egress policy returns 403 on (confirmed
non-transient via the proxy's own diagnostics — not retried). That finding
isn't repeated in full here; see spike 03's writeup for the evidence.

Consequences, stated plainly:

- **Never loaded by KOReader.** No confirmation the `require(...)` paths
  resolve, that `TextViewer:new{...}` accepts exactly this field
  combination without error, or that the plugin even appears in the
  `more_tools` menu.
- **No refresh-feel or navigation judgment possible** — this was never
  going to be answerable without a human at the device regardless of the
  emulator (see HYPOTHESIS.md), but the emulator would at least have
  caught a crash-on-load or a malformed-widget error before handing this
  to the owner.
- **`OQ-002` and `OQ-007` are unchanged by this spike** — still open,
  still need the owner on the real Paperwhite (or, if a future session
  gets emulator access some other way — e.g. a pre-built KOReader
  AppImage fetched from a host this policy does allow, or the owner
  running this exact plugin file in their already-working WSL2 setup — a
  cheap next step that doesn't require re-deriving anything here).

## Confidence

**Medium** that this code is close to correct (grounded in real, cited API
usage, syntactically valid, structurally modeled on a real working plugin)
— but **not verified**, and that gap is exactly what OQ-002/OQ-007 still
need closed. Do not read this spike as having answered the UI-feel
question; it hasn't.

## Next step

The fastest real close for OQ-002/OQ-007 doesn't require another cloud
session: the owner already has a **working** `kodev` build in WSL2
(`reference/koreader-notes.md`, OQ-012). Copying
`magium_spike.koplugin/` into `~/koreader/plugins/` there and running
`./kodev run` costs no new setup and would immediately answer "does it
load and render" — and, on the real Kindle via USB copy
(`reference/koreader-notes.md`'s on-device section), the actual feel
question. Recommended as the concrete next action for Phase 5's remaining
gap, ahead of Phase 6.
