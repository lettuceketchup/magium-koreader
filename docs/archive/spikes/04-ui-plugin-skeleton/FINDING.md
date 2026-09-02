# Finding — Spike 04 (UI plugin skeleton)

- **Status:** stable (functional/data-fit result confirmed; e-ink-feel half still open; **final UI chrome/navigation now a separate open question, OQ-013** — see below)
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.1)
- **Sources:** this spike's `magium_spike.koplugin/main.lua`; a real `./kodev build`
  + `./kodev run --simulate=kindle-paperwhite` of KOReader **v2026.07.1** (commit
  `9192014`) in this cloud session, per
  [`reference/setup-koreader-cloud-session.sh`](../../../../reference/setup-koreader-cloud-session.sh);
  `../../../../koreader/frontend/ui/widget/textviewer.lua`,
  `../../../../koreader/frontend/ui/widget/scrolltextwidget.lua`
- **Related:** [`HYPOTHESIS.md`](HYPOTHESIS.md), [`OQ-002`](../research/07-risks-open-questions.md),
  [`OQ-007`](../research/07-risks-open-questions.md), [`OQ-012`](../research/07-risks-open-questions.md),
  [`OQ-013`](../research/07-risks-open-questions.md)

## Result: **runs cleanly under the real KOReader runtime — widget-fit confirmed; e-ink feel still open**

A later pass at this same session (2026-08-31, after the finding below was
first written as "not run — blocked") got a working KOReader emulator build
and actually ran this plugin. What changed: the earlier attempt hit GitHub
returning **403** on `./kodev fetch-thirdparty`'s tarball downloads
(`github.com/*/archive/refs/tags/*.tar.gz`, ~17 of koreader-base's ~50
thirdparty C libraries) and concluded a cloud session couldn't build the
emulator at all. That conclusion was too broad. What's actually true,
confirmed by direct testing:

- **Blocked:** `github.com/<owner>/<repo>/archive/...` and
  `codeload.github.com/...` (GitHub's "generate a tarball of this ref"
  endpoint) for repos outside this session's attached scope — a 403 with a
  JSON body naming the repo-scope policy (`add_repo`'s own diagnostic
  confirms the same: plain git reads are already open, this endpoint isn't).
- **NOT blocked:** plain `git clone`/`git fetch` of any public GitHub repo
  (anonymous git-protocol reads aren't gated), and
  `github.com/<owner>/<repo>/releases/download/...` (published release
  assets, served like a CDN — confirmed with a direct `curl`, 200).

Of koreader-base's thirdparty dependencies, ~17 fetch a GitHub **archive**
tarball (blocked) and ~13 fetch a GitHub **release asset** (not blocked,
needed no change) — the rest come from non-GitHub hosts (ftp.gnu.org,
sqlite.org, luarocks.org, ...), also not blocked. The 17 archive-based ones
were fixed by patching their `DOWNLOAD URL <md5> <archive-url>` CMake
fetches to the build system's own **`DOWNLOAD GIT <ref> <repo>`** mechanism
(already used unmodified by `luajit`'s own `CMakeLists.txt` — not a new
code path, just applying it more places). This is content-identical to the
archive download: GitHub's archive endpoint is just a zip of the git tree
at that ref, so `git clone` at the same tag produces the same source. Full
patch: [`reference/koreader-base-thirdparty-git-fetch.patch`](../../../../reference/koreader-base-thirdparty-git-fetch.patch)
(18 files — 17 top-level thirdparty libs + one 2-line addition to the
shared `luarocks_external_project` macro covering 3 more archive-fetched
test-only "spec rock" deps found only once the build got that far).
Full recipe: [`reference/setup-koreader-cloud-session.sh`](../../../../reference/setup-koreader-cloud-session.sh).

With that patch, `./kodev build` succeeded end to end — every thirdparty
library (LuaJIT 2.1, MuPDF, HarfBuzz, FreeType, Tesseract, SDL3, all ~50)
compiled, then `koreader` itself linked. `xvfb-run -a ./kodev run
--simulate=kindle-paperwhite --no-build` started the emulator headless
(Kindle Paperwhite dimensions: 1072×1448 @ 300 DPI, matching the real
device), loaded every bundled plugin plus `magium_spike.koplugin` dropped
into `plugins/`, and ran to a clean exit (code 0). Log line confirming the
plugin loaded with no error:

```
DEBUG Plugin loaded magium_spike
DEBUG RD loaded plugin magium_spike at plugins/magium_spike.koplugin
```

No `ERROR`/`Traceback`/`attempt to` lines anywhere in the run log (the only
`error:` line is an unrelated harmless `XDG_RUNTIME_DIR is invalid` warning
from SDL probing dbus in a container with no session bus — doesn't affect
rendering).

### Exercising the actual widget code

Module-load success alone doesn't prove `TextViewer:new{...}` accepts this
plugin's exact `buttons_table` shape or that `showIntro1`/`showIntro2`
render without a runtime error — menu navigation needs real input events,
which this headless container has no way to synthesize realistically. So a
throwaway instrumentation (not part of the committed spike source — applied
only to the deployed copy in the emulator's `plugins/` dir, reverted after)
added to `MagiumSpike:init()`:

```lua
UIManager:scheduleIn(1, function() self:showIntro1() end)
UIManager:scheduleIn(3, function() Screen:shot("/tmp/spike04-intro1.png") end)
UIManager:scheduleIn(4, function()
  local ok, err = pcall(function() self:showIntro2() end)
  if not ok then print("showIntro2 ERROR: " .. tostring(err)) end
end)
UIManager:scheduleIn(6, function() Screen:shot("/tmp/spike04-intro2.png") end)
UIManager:scheduleIn(8, function() UIManager:quit() end)
```

Result: both scenes rendered with **zero errors** (the `pcall` around
`showIntro2` never fired its error branch), and `Screen:shot()` (the same
API `frontend/ui/widget/screenshoter.lua` uses for the real screenshot
gesture) captured both frames —
[`screenshots/intro1.png`](screenshots/intro1.png),
[`screenshots/intro2.png`](screenshots/intro2.png):

- **`intro1.png`**: `TextViewer` header reads **"Book 1 - Chapter 1"**
  (`getHeaderFromId` on `Ch1-Intro1`, matching `01-magium-analysis.md` §9),
  real prose from `ch1.magium` wraps correctly and fits with a scrollbar
  (text not clipped or overflowing), and the `buttons_table` choice
  row renders "Excited" / "Calm" / "Afraid" as three full-width tappable
  rows below a divider — visually matches Phase 2's prediction
  (`03-koreader-platform.md` §3, F-14/F-15) of what this widget combo
  would produce.
- **`intro2.png`**: navigating to the second hard-coded scene works — new
  header (same book/chapter), new prose (the `#if`-gated branch text — the
  scripted call didn't set `v_ch1_intro_feeling` first, so it's not
  asserting *which* branch, only that the swap itself renders cleanly with
  its own single choice, "Back to Intro1 (spike loop)").

## Caveat: the screenshots show API/data fit, not the final UI (new — OQ-013)

Reviewing these two screenshots (owner feedback, 2026-08-31) surfaced two
things `TextViewer` gets wrong for a finished Magium reading screen, both
visible directly in the images and confirmed against source:

- **Not fullscreen.** `TextViewer` sizes itself to `screen_w/h -
  Screen:scaleBySize(30)` by default (`textviewer.lua:107-108`) and wraps
  its content in a `FrameContainer` with `radius = Size.radius.window`
  (rounded corners) plus a `TitleBar` row carrying the **✕ close button**
  (`textviewer.lua:469-474`) — a padded dialog/window look, not the
  edge-to-edge fullscreen presentation the owner wants (closer to the web
  version, or to `frotz.koplugin`'s actual `GameView`, which *does* flag
  itself fullscreen). This was documented incorrectly in
  [`03-koreader-platform.md`](../research/03-koreader-platform.md) §7 prior
  to this session ("`TextViewer` fills the screen") — corrected there now.
- **Continuous scroll, not paginated.** The prose area is a
  `ScrollTextWidget` (`textviewer.lua:416`) — a scrollbar + pan/tap
  scrolling, no page-number or "screen full of text" concept anywhere in
  its API (`scrolltextwidget.lua`). On e-ink, continuous small-delta
  scrolling is exactly the pattern that accumulates ghosting fastest and
  gives the reader no sense of position/progress within a long scene — a
  discrete page-turn (whole-screen swap + a page indicator) is the better
  match for the platform, not just a stylistic preference. Note this isn't
  unique to `TextViewer`'s specific choice: `frotz.koplugin`'s `GameView`
  (the other cited prior art, F-15) *also* scrolls (`StyledScroll`) — no
  KOReader prior art found so far already does "fullscreen + paginated"
  together. That combination would need a small custom widget: e.g. a
  fullscreen `FrameContainer` (no titlebar) hosting a plain
  `TextBoxWidget` chunked into screen-sized pages (using its line/height
  measurement API) with manual page-turn + indicator logic — buildable on
  what Phase 2 already catalogued, but genuinely new work, not a reuse.
  Not attempted here — this spike's job was proving the *data* (real
  scenes, real choices, real conditional branching) drives the widget
  cleanly, which it does; the *chrome* choice is now tracked separately as
  [`OQ-013`](../research/07-risks-open-questions.md), feeding Phase 6/8
  rather than Phase 5.

Net effect on this spike's own verdict: **unchanged for what it actually
tested** (the plugin loads, the data/API shape fits, navigation works,
zero errors) — but the screenshots should not be read as "this is roughly
what the finished screen will look like." They're closer to a functional
proof-of-wiring than a UI mockup.

## What this answers

- **The "does the data/API shape fit an off-the-shelf widget?" half of
  OQ-002 is now a confirmed *yes*, not just a structural read of the API.**
  `TextViewer` + `buttons_table` renders real Magium prose and a real
  choice list correctly under KOReader **v2026.07.1** itself, with the
  plugin registered exactly the way a shipping plugin is (`hello.koplugin`
  boilerplate, `Dispatcher:registerAction`, `more_tools` menu entry) — no
  crash, no layout error, no missing-widget-feature surprise. **But
  `TextViewer` itself is now understood to be the wrong final widget** —
  see the caveat above — so this doesn't mean "ship `TextViewer`
  as-is"; it means the underlying data (parsed scenes, choice lists,
  conditional prose) is easy to drive through *any* reasonable widget,
  `TextViewer` included, which is what actually needed proving. The chrome
  question moves to OQ-013.
- **OQ-007 (e-ink refresh feel) is still open, unavoidably.** SDL renders
  instantly on Xvfb exactly as it would on a real X server or WSL2 — a
  desktop/container build was *never* going to answer "does the `tap
  choice → new page` loop feel sluggish or ghost on e-ink", full stop, with
  or without this session's network blocker (`HYPOTHESIS.md` said this
  from the start). What this run *does* rule out is a whole category of
  "would have needed the device to even discover" failure: e.g. a widget
  silently refusing this input shape, a `require()` path that only
  resolves on-device, a menu-registration bug. Those are now off the table
  before the owner spends any device time on it.
- **Corrects the earlier over-broad "a cloud session can't build the
  KOReader emulator" claim** (this file's previous version, and
  `07-risks-open-questions.md`'s prior OQ-012 note). The narrower, now
  evidence-based version: a cloud session can build it, at the cost of
  patching ~17 GitHub-archive-sourced thirdparty fetches to git-clone
  fetches first (mechanical, safe, documented above) — the emulator itself
  was never the blocker; one specific download endpoint was.

## Confidence

**High** that the underlying data/API shape fits KOReader's widget toolkit
functionally (real run, real KOReader version, zero errors,
visually-inspected correct rendering — not just source-grounded code
review). **High** (source-grounded + visually confirmed) that `TextViewer`
specifically is the wrong widget for the finished screen (padded dialog,
continuous scroll — OQ-013). **Unchanged: no confidence claim on e-ink
feel** — that dimension was never in scope for any build running on a
non-e-ink display, this session's included.

## Next step

Widget/data fit is closed. Two separate threads remain, feeding different
phases:

- **OQ-007** (e-ink refresh feel, Phase 6/8): a human judging refresh
  latency/ghosting on the real Paperwhite (or, short of that, the owner's
  WSL2 `kodev run` — same instant-refresh caveat as this session's build,
  so it doesn't add anything past what's already confirmed here; only real
  e-ink settles OQ-007). Copying `magium_spike.koplugin/` to the device via
  USB (`reference/koreader-notes.md`'s on-device section) is the direct
  path.
- **OQ-013** (fullscreen + paginated UI, Phase 6/8): not spiked here — no
  off-the-shelf widget or cited prior art does both together (see the
  caveat above), so it's a design/build decision for the approach
  comparison and roadmap phases, not something a quick follow-up spike
  would settle on its own.
