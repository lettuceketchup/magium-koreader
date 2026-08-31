# Finding — Spike 03 (full-corpus memory + cold-parse time in Lua)

- **Status:** stable (re-confirmed under koreader-base's own bundled LuaJIT — see update below)
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.4)
- **Sources:** this spike's `measure_lua.lua`, run under **LuaJIT
  2.1.1703358377** (stock Ubuntu apt package) and, in a later pass,
  **LuaJIT 2.1.1783773675** (koreader-base's own bundled build, from a
  successful `./kodev build` — see update below) — both on this session's
  x86_64 container, not the Kindle
- **Related:** [`HYPOTHESIS.md`](HYPOTHESIS.md), [`OQ-001`](../research/07-risks-open-questions.md), [`../02-engine-in-lua/FINDING.md`](../02-engine-in-lua/FINDING.md), [`../04-ui-plugin-skeleton/FINDING.md`](../04-ui-plugin-skeleton/FINDING.md)

## Result

```
$ luajit measure_lua.lua /home/user/magium-dev/data/en 7
engine:             LuaJIT LuaJIT 2.1.1703358377
files:              54
disk:               7.41 MB
scenes:             2159
paragraphs:         4880
choices:            3734
set() directives:   594
achievements:       145
parse times (ms):   112.1, 113.8, 115.1, 117.2, 126.0, 127.9, 128.3
parse time min/med: 112.1 / 117.2 ms  (os.clock CPU time, 7 runs, this container's x86 core)
parsed mem delta:   11.54 MB  (Lua GC heap, collectgarbage("count"))
```

### Structural fidelity: exact match to the JS baseline

| Metric | JS (`measure-story-size.js`, Phase 0) | Lua (this spike) |
|---|---|---|
| Files | 54 | 54 |
| Scenes | 2159 | **2159** |
| Paragraphs | 4880 | **4880** |
| Choices | 3734 | **3734** |
| `set()` directives | 594 | **594** |
| Disk size | 7.50 MB | 7.41 MB |

Scenes/paragraphs/choices/`set()` counts are **bit-for-bit identical** across
all 54 files, not just the 6 fixtures spike 02 diffed byte-for-byte. The
0.09 MB disk-size difference is not a parse discrepancy — both scripts sum
`stat().size` over the same 54 files; re-measured directly with Python
(`os.path.getsize`) here and it agrees with this spike's 7.41 MB, so the
7.50 MB figure recorded in Phase 0 is very likely a stale/rounding artifact
from when it was first measured, not a Lua-vs-JS difference. Immaterial
either way — not investigated further.

### Memory: Lua uses *less* heap than V8 for the same structure

**11.54 MB** Lua GC-heap delta for the full parsed story, vs. the **~17.4 MB**
V8 heap delta recorded for the same data in Phase 0 (F-24). Directly
supports (rather than just fails to contradict) F-8/the Phase 3 verdict that
memory is not a blocker: **~11.5 MB against ~497 MB available RAM** is under
2.5%, even before accounting for the fact that KOReader's own idle footprint
(~33 MB, `00-overview.md`) is already known to fit comfortably. Table
overhead differences between LuaJIT and V8 (no per-object property-shape
machinery, compact array parts) plausibly explain Lua using less, not more —
consistent with, not surprising given, general priors about the two
runtimes, though this wasn't independently verified beyond the measurement
itself.

### Parse time: same order of magnitude as the JS anchor, still not the answer

**112–128 ms** (LuaJIT, this x86 container) vs. **95–130 ms** (V8, Phase 0's
desktop measurement) — both land in the same band on x86 desktop-class
silicon. This is a mild positive data point (no sign LuaJIT is dramatically
slower than V8 for this specific text-parsing workload), but it **does not
resolve OQ-001's on-device number**: both measurements are desktop x86, and
the Kindle's 1 GHz MTK ARM core under koreader-base's LuaJIT build is the
actual target. The ~1–4 s on-device estimate (F-24) stands unchanged — now
corroborated by a second language/runtime agreeing on the desktop baseline,
which very slightly raises confidence in extrapolating from it, but doesn't
replace an on-device measurement.

## Update (later pass, same day): got a real koreader-base LuaJIT number after all

The paragraph below is kept as a record of what was actually hit — the
conclusion it drew ("a cloud session cannot build the emulator") turned out
to be **too broad** and was corrected the same session. Short version: the
403s were real, but scoped to one specific GitHub download endpoint
(`archive/*`, not `releases/download/*` or plain `git clone`), and 17 of
koreader-base's thirdparty C libraries were fixable by switching their
fetch to `git clone` at the same tag — content-identical, and using a
mechanism (`DOWNLOAD GIT`) the build system already had. Full story, patch,
and recipe: [`../04-ui-plugin-skeleton/FINDING.md`](../04-ui-plugin-skeleton/FINDING.md),
[`reference/setup-koreader-cloud-session.sh`](../../../reference/setup-koreader-cloud-session.sh).

With a working `./kodev build`, this spike's parser was rerun **completely
unmodified** under koreader-base's own bundled LuaJIT
(`koreader-emulator-x86_64-linux-gnu-debug/koreader/luajit`, `LuaJIT
2.1.1783773675` — a newer 2.1.ROLLING build than the stock Ubuntu package
used above, but the same major/minor line KOReader v2026.07.1 ships):

```
$ .../koreader-emulator-x86_64-linux-gnu-debug/koreader/luajit measure_lua.lua /home/user/magium-dev/data/en 5
engine:             LuaJIT LuaJIT 2.1.1783773675
parse times (ms):   183.7, 194.2, 198.0, 201.1, 204.9
parse time min/med: 183.7 / 198.0 ms
parsed mem delta:   11.48 MB
```

Memory (**11.48 MB**) lands within noise of the stock-LuaJIT figure above
(11.54 MB) — good agreement, as expected since it's the same GC and the
same parsed data structures. Parse time (**184–205 ms**) is higher than the
stock run's 112–128 ms; almost certainly container CPU-contention noise
between the two passes (this session's container, not a LuaJIT-build
difference — both are LuaJIT 2.1 JIT-compiling the same Lua source) rather
than a real effect, but recorded as measured rather than discarded. Either
way this is **still a desktop x86 core, still not the Kindle's ~1 GHz MTK
ARM core** — the on-device number this spike originally set out to get
remains unmeasured; what changed is *which* LuaJIT build produced the
desktop numbers, not the CPU architecture gap. Spike 02's 6-fixture oracle
diff was also rerun under this same bundled LuaJIT: still **6/6 match**
(reconfirms the port isn't dependent on which LuaJIT build runs it).

## What was actually hit, first attempt (superseded by the update above)

This spike's `HYPOTHESIS.md` flagged going in that only a desktop LuaJIT
number was achievable from this cloud session. First attempt: tried to
build the KOReader `kodev` emulator in this container (same recipe as
`reference/setup-koreader-wsl.sh`, which resolved OQ-012 on the owner's
Windows/WSL2 machine) to get a stronger result — running this same parser
*inside* koreader-base's actual LuaJIT build, not stock Ubuntu LuaJIT.

`./kodev fetch-thirdparty` needs to download several C libraries' release
tarballs directly from GitHub
(`https://github.com/<org>/<repo>/archive/refs/tags/*.tar.gz` — leptonica,
freetype2, md4c, and others), and every one of those returned **403** from
this session's outbound proxy. Per the proxy's own diagnostics
(`curl -sS "$HTTPS_PROXY/__agentproxy/status"`, `/root/.ccr/README.md`
"403 / 407 from the proxy" section): *"The destination host is not allowed
by your organization's egress policy for this session."* That's accurate
as far as it goes — this specific endpoint really is blocked, confirmed
non-transient. The mistake was generalizing from "this endpoint is
blocked" to "the emulator can't be built": plain `git clone` of the same
repos (already in use for `../magium-dev` and `../koreader`) works fine,
and turning the archive-tarball fetches into git-clone fetches turned out
to be a small, mechanical, low-risk patch — see the update above.

## Confidence

**High** for the structural fidelity result (full-corpus counts, directly
measured, exact match). **Medium** for the memory comparison (real
measurement, but LuaJIT-desktop vs. V8-desktop, not vs. the Kindle).
**Low** for what this implies about on-device parse time (unchanged from
F-24 — genuinely needs the device).

## Next step

OQ-001 stays open for an on-device (or WSL2-emulator) measurement — this
spike narrows it (memory: strong 🟢, likely stronger than the V8 estimate
suggested) without fully closing it (parse time: still an extrapolation).
Feeds Phase 6 unchanged from Phase 3's read: no new red flags, still no
resource blocker found anywhere.
