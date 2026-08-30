# Finding — Spike 03 (full-corpus memory + cold-parse time in Lua)

- **Status:** stable
- **Last updated:** 2026-08-31
- **Phase:** 5 (task 5.4)
- **Sources:** this spike's `measure_lua.lua`, run under **LuaJIT
  2.1.1703358377** on this session's x86_64 container (not the Kindle)
- **Related:** [`HYPOTHESIS.md`](HYPOTHESIS.md), [`OQ-001`](../research/07-risks-open-questions.md), [`../02-engine-in-lua/FINDING.md`](../02-engine-in-lua/FINDING.md)

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

## Blocked: could not get a real KOReader-environment number

This spike's `HYPOTHESIS.md` flagged going in that only a desktop LuaJIT
number was achievable from this cloud session. Confirmed: attempted to
build the KOReader `kodev` emulator in this container (same recipe as
`reference/setup-koreader-wsl.sh`, which resolved OQ-012 on the owner's
Windows/WSL2 machine) to get a stronger result — running this same parser
*inside* koreader-base's actual LuaJIT build, not stock Ubuntu LuaJIT.

**Blocked by this session's network egress policy, not a tooling
problem.** `./kodev fetch-thirdparty` needs to download several C
libraries' release tarballs directly from GitHub
(`https://github.com/<org>/<repo>/archive/refs/tags/*.tar.gz` — leptonica,
freetype2, md4c, and others), and every one of those returned **403** from
this session's outbound proxy. Per the proxy's own diagnostics
(`curl -sS "$HTTPS_PROXY/__agentproxy/status"`, `/root/.ccr/README.md`
"403 / 407 from the proxy" section): *"The destination host is not allowed
by your organization's egress policy for this session. Do not retry or
route around it."* This is a policy denial, not a transient failure —
**not retried**, per that guidance. (Plain `git clone` of `github.com`
repos, used earlier for `../magium-dev` and `../koreader`, works fine —
it's specifically the GitHub-tarball-archive download pattern that's
blocked, a different code path than the git smart-HTTP protocol.)

This means: a cloud/remote agent session **cannot** build or run the
KOReader emulator, independent of the CPU-architecture limitation (kodev
runs on the host's own CPU regardless — this isn't about ARM emulation, the
egress block happens before any build step that would care about
architecture). The owner's WSL2 environment (`reference/koreader-notes.md`,
OQ-012) or the real Kindle remain the only ways to close OQ-001/OQ-007/OQ-002
with an actual KOReader-environment measurement. Spike A ([`../04-ui-plugin-skeleton/`](../04-ui-plugin-skeleton/))
hits the same wall.

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
