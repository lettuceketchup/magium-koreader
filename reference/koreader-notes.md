# Reference: KOReader source checkout

- **Status:** stable (citation checkout pinned + emulator dev env built & run 2026-08-31)
- **Last updated:** 2026-08-31
- **Phase:** 2
- **Sources:** `github.com/koreader/koreader` — release tag **`v2026.07.1`**, commit
  `9192014d8bd82a91dc1012473be0f238dedfdb54`; `doc/*`, `frontend/**`, `plugins/**`,
  `datastorage.lua`, `kodev`, `platform/kindle/koreader.sh`; WSL2 build verified on-machine
- **Related:** [`../docs/research/03-koreader-platform.md`](../docs/research/03-koreader-platform.md),
  [`setup-koreader-wsl.sh`](setup-koreader-wsl.sh), [`07` OQ-012](../docs/research/07-risks-open-questions.md)

> Phase 2 analyses the KOReader plugin platform. Two checkouts:
> 1. **`../koreader`** — a **citation checkout** pinned to the exact release the
>    Kindle runs, so line numbers in the dossier are reproducible. Sibling of this
>    repo, not vendored (same convention as `../magium-dev`).
> 2. **`~/koreader` inside WSL2** — a separate **build/run checkout** for the
>    emulator dev loop (see "Emulator dev environment" below). Also `v2026.07.1`.

## The citation checkout (`../koreader`)

```sh
cd ".."                      # the "Magium - Kindle" folder, sibling to magium-koreader/
git clone --filter=blob:none https://github.com/koreader/koreader.git
cd koreader
git fetch --depth 1 origin tag v2026.07.1
git checkout v2026.07.1      # -> detached HEAD at 9192014
```

- Sibling path: `../koreader/` (sibling of the `magium-koreader/` repo, same as
  `../magium-dev`). Cited that way by convention regardless of the citing doc's
  depth — matching the existing `../magium-dev/src/...` style.
- **`v2026.07.1` is exactly the build the owner runs** (KOReader v2026.07.1
  release, `kindlehf`, on FW 5.19.5 — see [`00-overview.md`](../docs/research/00-overview.md)).
  The annotated tags `v2026.07.1` (2026-08-01) and `v2026.07.2` (2026-08-02) both
  point at commit `9192014`; `.2` was a packaging re-tag with no frontend change.
- Submodules (`base/` = koreader-base, `l10n/`, `resources/fonts`) are **not**
  checked out — not needed for frontend/plugin analysis. koreader-base at this tag
  is pinned to `6e4bc81`; it builds LuaJIT from upstream `github.com/LuaJIT/LuaJIT`
  commit `3c4f9fe` (v2.1 branch, "LuaJIT 2.1.ROLLING", `LUAJIT_VERSION_NUM 20199`)
  — see [`03-koreader-platform.md` §2](../docs/research/03-koreader-platform.md#2-lua-environment-22).

## Citing it

`` `../koreader/frontend/ui/uimanager.lua:477` `` — add `@v2026.07.1` when the line
is likely to move between releases. The API doc mirror at
<https://koreader.rocks/doc/> tracks `master`, not this tag; prefer source lines.

## Emulator dev environment — WSL2 / Ubuntu (resolves OQ-012)

`./kodev build && ./kodev run` needs a Linux/macOS toolchain
(`../koreader/doc/Building.md:1-10`). **On this machine (Windows 11) it is set up
and working in WSL2.** One-shot reproducible install:

```sh
wsl -d Ubuntu        # or run the script from inside the distro
bash /mnt/f/Projects/Magium\ -\ Kindle/magium-koreader/reference/setup-koreader-wsl.sh
```

[`setup-koreader-wsl.sh`](setup-koreader-wsl.sh) installs the apt prerequisites,
then **ninja 1.13.2 and GNU make 4.4.1 into `/usr/local/bin`** (Ubuntu 24.04's
1.11.1 / 4.3 have incompatible job-server implementations — the recursive-make
thirdparty builds fail with `make[3]: *** read jobs pipe: Bad file descriptor`),
clones KOReader to `~/koreader` at `v2026.07.1`, and builds. ~7 min.

Then, from `~/koreader`:

| Command | Does |
|---|---|
| `./kodev run` | launches the emulator in a window (WSLg on Win 11 gives a display out of the box — SDL uses the `x11` driver) |
| `./kodev run -s=kobo-aura-one` | run at a preset device size/DPI |
| `./kodev log koreader` | tail the running app's log |
| `./kodev build && ./kodev run` | rebuild + run after editing Lua |

Verified 2026-08-31: build OK, `./kodev run` starts, loads all plugins, renders
the quickstart doc. The emulator's own data dir (settings, plugins it loads,
`crash.log`) is `~/koreader/koreader-emulator-x86_64-linux-gnu-debug/koreader/`.
Drop `magium.koplugin/` in `~/koreader/plugins/` (or symlink from the Windows
side) and it loads on the next `kodev run`.

**Alternatives** (not needed now): the `koreader/virdevenv` Docker image; or
`--appimage-extract` a released Linux AppImage for pure-Lua frontend work.

**Cloud/remote Claude Code session variant:** the recipe above assumes normal
unrestricted internet access. A cloud session's egress policy blocks
`github.com/*/archive/*` (GitHub's dynamic tarball-from-ref endpoint, used by
`./kodev fetch-thirdparty` for ~17 of koreader-base's thirdparty C libraries)
for repos outside the session's attached scope, while allowing plain
`git clone` and `github.com/*/releases/download/*` — see
[`setup-koreader-cloud-session.sh`](setup-koreader-cloud-session.sh) (same
steps as above, plus a small patch —
[`koreader-base-thirdparty-git-fetch.patch`](koreader-base-thirdparty-git-fetch.patch)
— swapping those 17 fetches for `git clone` at the same tag) and
[`07` OQ-012](../docs/research/07-risks-open-questions.md)'s Phase 5 note.
Verified working end-to-end 2026-08-31 in such a session, headless via
`xvfb-run -a ./kodev run --simulate=kindle-paperwhite --no-build` (no real
display, so no e-ink refresh simulation either way — see
[spike 04](../docs/spikes/04-ui-plugin-skeleton/FINDING.md)).

## On-device debugging (the real target)

USB copy the plugin to `koreader/plugins/` on the Kindle, restart KOReader, read
`koreader/crash.log` — all `logger` output + tracebacks, last 500 KB
(`../koreader/platform/kindle/koreader.sh:323-334`). No hot reload. Feel of the
choice→page loop on real e-ink is still spike A / OQ-007.
