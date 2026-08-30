#!/usr/bin/env bash
#
# setup-koreader-wsl.sh — reproducible KOReader emulator dev environment on
# WSL2 / Ubuntu 24.04 (Windows 11). Resolves OQ-012.
#
# What it does:
#   1. installs KOReader's documented build prerequisites via apt
#   2. installs ninja >= 1.13.2 and GNU make >= 4.4 (Ubuntu 24.04 ships 1.11.1 /
#      4.3, which are too old — their job-server implementations don't agree and
#      the recursive-make thirdparty builds (luajit, libunibreak) fail with
#      "make[3]: *** read jobs pipe: Bad file descriptor.  Stop.")
#   3. clones KOReader to ~/koreader and checks out the release the Kindle runs
#   4. builds the emulator and prints how to run it
#
# Both extra tools go in /usr/local/bin (ahead of /usr/bin in PATH); the apt
# packages are untouched. To undo the version bumps:
#   sudo rm /usr/local/bin/ninja /usr/local/bin/make
#
# Verified 2026-08-31: Ubuntu 24.04.3, 4 CPU / 5.8 GB RAM. Build ~7 min.
# GUI works out of the box via WSLg (Windows 11) — SDL picks the x11 driver.
#
# Usage:  bash setup-koreader-wsl.sh              # everything
#         KOREADER_REF=master bash setup-koreader-wsl.sh   # override the tag
set -euo pipefail

KOREADER_REF="${KOREADER_REF:-v2026.07.1}"   # match the owner's device
NINJA_VER="${NINJA_VER:-1.13.2}"
MAKE_VER="${MAKE_VER:-4.4.1}"
SRC_DIR="${SRC_DIR:-$HOME/koreader}"

need_sudo() { if [ "$(id -u)" -ne 0 ]; then echo "sudo"; fi; }
SUDO="$(need_sudo)"

echo "==> [1/4] apt prerequisites"
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y --no-install-recommends \
    autoconf automake build-essential ca-certificates cmake gcc-multilib \
    gettext git libtool libtool-bin meson nasm ninja-build patch pkg-config \
    unzip wget curl file \
    libx11-dev libxcursor-dev libxext-dev libxi-dev libxrandr-dev libxss-dev \
    libxtst-dev libegl-dev libwayland-dev libxkbcommon-dev libgl1-mesa-dev

echo "==> [2/4] ninja ${NINJA_VER} + GNU make ${MAKE_VER} into /usr/local/bin"
if [ "$(ninja --version 2>/dev/null || echo 0)" != "${NINJA_VER}" ] || \
   [ "$(command -v ninja)" != "/usr/local/bin/ninja" ]; then
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/ninja.zip" \
        "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VER}/ninja-linux.zip"
    $SUDO unzip -o "$tmp/ninja.zip" -d /usr/local/bin/
    $SUDO chmod 755 /usr/local/bin/ninja
    rm -rf "$tmp"
fi
if ! /usr/local/bin/make --version 2>/dev/null | grep -q "GNU Make ${MAKE_VER}"; then
    tmp="$(mktemp -d)"; ( cd "$tmp"
        curl -fsSL -O "https://ftp.gnu.org/gnu/make/make-${MAKE_VER}.tar.gz"
        tar xf "make-${MAKE_VER}.tar.gz"; cd "make-${MAKE_VER}"
        ./configure --prefix=/usr/local --without-guile >/dev/null
        /usr/bin/make -j"$(nproc)" >/dev/null
        $SUDO /usr/bin/make install >/dev/null )
    rm -rf "$tmp"
fi
hash -r
echo "    ninja $(ninja --version) ; $(make --version | head -1)"

echo "==> [3/4] clone KOReader @ ${KOREADER_REF} into ${SRC_DIR}"
if [ ! -d "${SRC_DIR}/.git" ]; then
    git clone https://github.com/koreader/koreader.git "${SRC_DIR}"
fi
git -C "${SRC_DIR}" fetch --tags origin
git -C "${SRC_DIR}" -c advice.detachedHead=false checkout "${KOREADER_REF}"

echo "==> [4/4] build the emulator (downloads + compiles thirdparty, ~7 min)"
cd "${SRC_DIR}"
./kodev fetch-thirdparty
./kodev build

cat <<EOF

Done. The emulator is built.

  cd ${SRC_DIR}
  ./kodev run          # opens a window via WSLg
  ./kodev run -s=kobo-aura-one     # simulate a specific device size/DPI
  ./kodev log koreader             # tail the running app's log
  ./kodev build && ./kodev run     # rebuild + run after editing Lua

Drop a plugin into ${SRC_DIR}/plugins/<name>.koplugin/ (or symlink it) and it
loads on next 'kodev run'. The emulator's data dir (settings, its own plugins,
crash.log) is ${SRC_DIR}/koreader-emulator-x86_64-linux-gnu-debug/koreader/.
EOF
