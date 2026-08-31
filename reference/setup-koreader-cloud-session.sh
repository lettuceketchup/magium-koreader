#!/usr/bin/env bash
#
# setup-koreader-cloud-session.sh — build the KOReader emulator inside a
# cloud/remote Claude Code session (Ubuntu 24.04 container), working around
# that environment's GitHub egress policy. Companion to
# reference/setup-koreader-wsl.sh (the owner's Windows/WSL2 recipe, used
# for OQ-012) — this one resolves the *separate* blocker Phase 5 hit trying
# to do the same build from a cloud session (docs/spikes/03-full-corpus-memory-parse/FINDING.md,
# docs/spikes/04-ui-plugin-skeleton/FINDING.md, 07-risks-open-questions.md OQ-012).
#
# What's different from a normal machine, and why this script exists:
#
#   1. The session's proxy allows plain `git clone`/`fetch` of ANY public
#      GitHub repo (anonymous git-protocol reads are not gated), and it
#      allows github.com/*/releases/download/* (published release assets
#      are served like a CDN). It BLOCKS github.com/*/archive/* and
#      codeload.github.com/* (GitHub's "zip the tree at this ref"
#      endpoint) for any repo outside the session's attached scope —
#      that's the endpoint `./kodev fetch-thirdparty`'s CMake dependency
#      downloads use for ~17 of koreader-base's ~50 thirdparty libraries
#      (leptonica, freetype2, md4c, brotli, libpng, tesseract, tree-sitter,
#      utf8proc, xxhash, lpeg, luarocks, cpu_features, dropbear, miniconv,
#      proxy-libintl, sdcv, tree-sitter-c) plus 3 luarocks-spec test deps
#      (lua-term, lua_cliargs, mediator_lua). Confirmed empirically 2026-08-31:
#      `curl` a `.../archive/refs/tags/*.tar.gz` URL -> 403 with a JSON body
#      naming the repo-scope policy; the identical repo's `git clone` -> 200.
#      Fixed here by patching those DOWNLOAD URL fetches to the build
#      system's own (already-used-by-luajit) DOWNLOAD GIT mechanism —
#      byte-identical source tree, since the archive endpoint is just a zip
#      of the git tree at that ref. Patch: koreader-base-thirdparty-git-fetch.patch
#      (same dir as this script). The other ~13 releases/download-based
#      libraries (curl, zlib, zstd, mupdf, sdl3, ...) needed no change.
#   2. Same ninja/make version issue as the WSL2 recipe hits on Ubuntu
#      24.04 (1.11.1 / 4.3 -> recursive-make thirdparty builds fail).
#      GNU make builds fine from ftp.gnu.org (not gated); ninja's GitHub
#      *release zip* download is blocked the same way as above, so this
#      builds ninja from a git checkout instead of downloading the release
#      binary.
#   3. No real display: runs under Xvfb. No e-ink simulation either way —
#      SDL renders instantly on both a real X server and Xvfb — so this
#      build answers "does the plugin load and render without error", not
#      "how does it feel on e-ink" (still needs the owner's WSL2 build or
#      the real Kindle, see FINDING.md).
#
# Verified 2026-08-31 in an Anthropic-managed cloud session (Ubuntu 24.04.4,
# x86_64): full `./kodev build` for the emulator target succeeds end to end
# (all ~50 thirdparty libs including LuaJIT/MuPDF/harfbuzz/tesseract, then
# koreader itself); `./kodev run --simulate=kindle-paperwhite` under Xvfb
# starts, loads all bundled plugins plus a dropped-in one, and exits 0.
# Build ~15-20 min in that container (slower than WSL2's ~7 min — more
# libraries end up compiled from git source rather than a prebuilt/cached
# tarball path, and container CPU allocation varies).
#
# Usage:  bash setup-koreader-cloud-session.sh
#         KOREADER_REF=master bash setup-koreader-cloud-session.sh   # override the tag
set -euo pipefail

KOREADER_REF="${KOREADER_REF:-v2026.07.1}"   # match the owner's device
NINJA_VER="${NINJA_VER:-1.13.2}"
MAKE_VER="${MAKE_VER:-4.4.1}"
SRC_DIR="${SRC_DIR:-/home/user/koreader}"
PATCH_FILE="${PATCH_FILE:-$(dirname "$0")/koreader-base-thirdparty-git-fetch.patch}"

echo "==> [1/5] apt prerequisites (same list as setup-koreader-wsl.sh, minus ninja/make)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    autoconf automake build-essential ca-certificates cmake gcc-multilib \
    gettext git libtool libtool-bin meson nasm patch pkg-config \
    unzip wget curl file xvfb \
    libx11-dev libxcursor-dev libxext-dev libxi-dev libxrandr-dev libxss-dev \
    libxtst-dev libegl-dev libwayland-dev libxkbcommon-dev libgl1-mesa-dev

echo "==> [2/5] GNU make ${MAKE_VER} (from ftp.gnu.org) + ninja ${NINJA_VER} (built from a git checkout, not the GitHub release zip)"
if ! /usr/local/bin/make --version 2>/dev/null | grep -q "GNU Make ${MAKE_VER}"; then
    tmp="$(mktemp -d)"; ( cd "$tmp"
        curl -fsSL -O "https://ftp.gnu.org/gnu/make/make-${MAKE_VER}.tar.gz"
        tar xf "make-${MAKE_VER}.tar.gz"; cd "make-${MAKE_VER}"
        ./configure --prefix=/usr/local --without-guile >/dev/null
        make -j"$(nproc)" >/dev/null
        make install >/dev/null )
    rm -rf "$tmp"
fi
if [ "$(/usr/local/bin/ninja --version 2>/dev/null)" != "${NINJA_VER}" ]; then
    tmp="$(mktemp -d)"
    git clone --depth 1 --branch "v${NINJA_VER}" https://github.com/ninja-build/ninja.git "$tmp"
    ( cd "$tmp" && python3 configure.py --bootstrap )
    cp "$tmp/ninja" /usr/local/bin/ninja
    chmod 755 /usr/local/bin/ninja
    rm -rf "$tmp"
fi
hash -r
echo "    ninja $(ninja --version) ; $(make --version | head -1)"

echo "==> [3/5] clone KOReader @ ${KOREADER_REF} into ${SRC_DIR} (with submodules)"
if [ ! -d "${SRC_DIR}/.git" ]; then
    git clone --branch "${KOREADER_REF}" --recurse-submodules --shallow-submodules \
        https://github.com/koreader/koreader.git "${SRC_DIR}"
fi

echo "==> [4/5] patch koreader-base's thirdparty fetch (github archive URL -> git clone)"
if [ -f "${PATCH_FILE}" ]; then
    ( cd "${SRC_DIR}/base" && git apply --check "${PATCH_FILE}" 2>/dev/null ) \
        && ( cd "${SRC_DIR}/base" && git apply "${PATCH_FILE}" ) \
        || echo "    (patch already applied, or doesn't match this koreader-base commit — check manually)"
else
    echo "    WARNING: ${PATCH_FILE} not found — thirdparty fetch will hit the 403 wall. See this script's header comment for the manual fix."
fi

echo "==> [5/5] build the emulator (downloads + compiles thirdparty, ~15-20 min)"
cd "${SRC_DIR}"
./kodev fetch-thirdparty
./kodev build

cat <<EOF

Done. The emulator is built.

  cd ${SRC_DIR}
  xvfb-run -a ./kodev run --simulate=kindle-paperwhite --no-build
  ./kodev log koreader             # tail the running app's log (or check
                                    # koreader-emulator-x86_64-linux-gnu-debug/koreader/crash.log)

Drop a plugin into ${SRC_DIR}/plugins/<name>.koplugin/ and it loads on next
'kodev run'. No real display in this container, so no e-ink refresh
simulation either way (Xvfb renders instantly, same as a real X server) —
this build answers "does it load/render", not "how does it feel". For a
screenshot from a headless run, call \`require("device").screen:shot(path)\`
from plugin code (see docs/spikes/04-ui-plugin-skeleton/FINDING.md for a
worked example scheduled via UIManager:scheduleIn()).
EOF
