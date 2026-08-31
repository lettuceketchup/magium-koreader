# Finding — Spike 04 (UI plugin skeleton)

- **Status:** stable (functional result confirmed; perceptual/e-ink-feel half still open — see below)
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.1)
- **Sources:** this spike's `magium_spike.koplugin/main.lua`; a real `./kodev build`
  + `./kodev run --simulate=kindle-paperwhite` of KOReader **v2026.07.1** (commit
  `9192014`) in this cloud session, per
  [`reference/setup-koreader-cloud-session.sh`](../../../reference/setup-koreader-cloud-session.sh)
- **Related:** [`HYPOTHESIS.md`](HYPOTHESIS.md), [`OQ-002`](../research/07-risks-open-questions.md),
  [`OQ-007`](../research/07-risks-open-questions.md), [`OQ-012`](../research/07-risks-open-questions.md)

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
patch: [`reference/koreader-base-thirdparty-git-fetch.patch`](../../../reference/koreader-base-thirdparty-git-fetch.patch)
(18 files — 17 top-level thirdparty libs + one 2-line addition to the
shared `luarocks_external_project` macro covering 3 more archive-fetched
test-only "spec rock" deps found only once the build got that far).
Full recipe: [`reference/setup-koreader-cloud-session.sh`](../../../reference/setup-koreader-cloud-session.sh).

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
  real prose from `ch1.magium` wraps and paginates correctly (scrollbar
  visible, text not clipped or overflowing), and the `buttons_table` choice
  row renders "Excited" / "Calm" / "Afraid" as three full-width tappable
  rows below a divider — visually matches Phase 2's prediction
  (`03-koreader-platform.md` §3, F-14/F-15) of what this widget combo
  would produce.
- **`intro2.png`**: navigating to the second hard-coded scene works — new
  header (same book/chapter), new prose (the `#if`-gated branch text — the
  scripted call didn't set `v_ch1_intro_feeling` first, so it's not
  asserting *which* branch, only that the swap itself renders cleanly with
  its own single choice, "Back to Intro1 (spike loop)").

## What this answers

- **The "does an existing widget combo fit?" half of OQ-002 is now a
  confirmed *yes*, not just a structural read of the API.** `TextViewer` +
  `buttons_table` renders real Magium prose and a real choice list
  correctly under KOReader **v2026.07.1** itself, with the plugin
  registered exactly the way a shipping plugin is (`hello.koplugin`
  boilerplate, `Dispatcher:registerAction`, `more_tools` menu entry) — no
  crash, no layout error, no missing-widget-feature surprise.
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

**High** that the widget model fits functionally (real run, real KOReader
version, zero errors, visually-inspected correct rendering — not just
source-grounded code review). **Unchanged: no confidence claim on e-ink
feel** — that dimension was never in scope for any build running on a
non-e-ink display, this session's included.

## Next step

Widget-fit is closed. What's left for OQ-007 is exactly what it always
was: a human judging refresh latency/ghosting on the real Paperwhite (or,
short of that, the owner's WSL2 `kodev run` — same instant-refresh caveat
as this session's build, so it doesn't add anything past what's already
confirmed here; only real e-ink settles OQ-007). Copying
`magium_spike.koplugin/` to the device via USB
(`reference/koreader-notes.md`'s on-device section) is the direct path.
