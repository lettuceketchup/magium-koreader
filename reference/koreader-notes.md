# Reference: KOReader source checkout

- **Status:** stable (checkout pinned + verified 2026-08-31)
- **Last updated:** 2026-08-31
- **Phase:** 2
- **Sources:** `github.com/koreader/koreader` — release tag **`v2026.07.1`**, commit
  `9192014d8bd82a91dc1012473be0f238dedfdb54`; `doc/*`, `frontend/**`, `plugins/**`,
  `datastorage.lua`, `kodev`, `platform/kindle/koreader.sh`
- **Related:** [`../docs/research/03-koreader-platform.md`](../docs/research/03-koreader-platform.md)

> Phase 2 analyses the KOReader plugin platform. Like the Magium recreations, the
> KOReader source is referenced as a **sibling checkout, not vendored** — cite it
> by relative path + tag/commit so line numbers are reproducible.

## The checkout

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

## Running the emulator (owner is on Windows)

`./kodev build && ./kodev run` needs a Linux/macOS toolchain
(`../koreader/doc/Building.md:1-10`). On Windows: WSL2 + an X server, the premade
Docker image (`koreader/virdevenv`), or extract the released Linux AppImage
(`--appimage-extract`) for pure-Lua frontend work. Native on-device debugging is a
USB copy to `koreader/plugins/` + reading `koreader/crash.log`
(`platform/kindle/koreader.sh:323-334`). Confirm the fastest loop in spike A.
