#!/bin/bash
# ---------------------------------------------------------------------------
# mgm.sh — magium-koreader dev task runner. Runs INSIDE WSL2 Ubuntu.
#
# Why this exists: the dev host is Windows; the Lua/Node/emulator toolchain
# lives in WSL2. Inline `wsl -d Ubuntu -- bash -lc '...'` strings that contain
# $VARS, $(cmd-subst) or embedded quotes get mangled by the Git-Bash -> wsl.exe
# boundary, and `bash -lc` does NOT give a clean PATH (no ~/.luarocks/bin, and
# the Windows PATH is appended). A script file read directly by Linux bash has
# none of those problems. So: put the logic here, call it with a bare relative
# path and simple args.
#
# Invoke from the repo root (the Windows session's cwd is inherited as
#   /mnt/f/Projects/Magium - Kindle/magium-koreader ):
#
#   wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh <cmd> [args...]'
#
# Commands:
#   env                 print toolchain versions
#   test [busted-args]  run busted from magium.koplugin/ (default: whole suite)
#   test-engine [args]  run only spec/engine (pure, fastest)
#   lua <file> [args]   run luajit from magium.koplugin/
#   diff <args...>      oracle-diff.js <args...>, with the oracle auto-started
#                       around the call and torn down after (file-only subcommands
#                       like `diff <a> <b>` work too — the oracle just goes unused)
#   with-oracle <cmd..> start the oracle, run <cmd..> (cwd = repo root), stop it
#   oracle-diff-lua <args..>  luajit spec/oracle_diff.lua <args..> from the plugin
#                       dir, with the oracle live for the duration
#   emu-deploy          symlink magium.koplugin into the built emulator
#   emu-run             xvfb-run kodev run (kindle-paperwhite, no rebuild)
#   emu-log [N]         tail N lines of the emulator crash.log (default 80)
#   kindle-tag          print the koreader checkout's tag/commit
#
# NOTE: WSL kills a `wsl.exe <cmd>` invocation's whole process tree on return,
# so a backgrounded oracle from one call is GONE by the next call. Every
# oracle-consuming operation must therefore run inside ONE invocation — that is
# what `diff`, `with-oracle` and `oracle-diff-lua` are for. There is no
# standalone `oracle-up`.
# ---------------------------------------------------------------------------
set -uo pipefail

export PATH="$HOME/.luarocks/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$REPO/magium.koplugin"
DEV="$(cd "$REPO/.." && pwd)/magium-dev"
KO="$HOME/koreader"
EMU="$KO/koreader-emulator-x86_64-linux-gnu-debug"
PORT="${MAGIUM_ORACLE_PORT:-3000}"

die() { echo "mgm: $*" >&2; exit 1; }

# Start the magium-dev oracle, wait until it answers, register a cleanup trap,
# and return. Caller runs its payload, then the trap kills the oracle on EXIT.
_ORACLE_PID=""
_start_oracle() {
  [ -f "$DEV/main_node.js" ] || die "no $DEV/main_node.js"
  if curl -sf -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
    echo "mgm: reusing oracle already on :$PORT" >&2
    return 0
  fi
  ( cd "$DEV" && (npm ls >/dev/null 2>&1 || npm install >/dev/null 2>&1) )
  ( cd "$DEV" && exec node main_node.js "$PORT" ) >/tmp/magium-oracle.log 2>&1 &
  _ORACLE_PID=$!
  trap '[ -n "$_ORACLE_PID" ] && kill "$_ORACLE_PID" 2>/dev/null' EXIT INT TERM
  for i in $(seq 1 25); do
    sleep 1
    curl -sf -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null && { echo "mgm: oracle up on :$PORT (${i}s)" >&2; return 0; }
  done
  echo "mgm: oracle failed to start in 25s" >&2; cat /tmp/magium-oracle.log >&2; exit 1
}

cmd="${1:-help}"; shift || true
case "$cmd" in
  env)
    echo "repo    : $REPO"
    echo "luajit  : $(command -v luajit || echo MISSING) — $(luajit -v 2>&1 | head -1)"
    echo "busted  : $(command -v busted || echo MISSING) — $(busted --version 2>&1)"
    echo "node    : $(command -v node || echo MISSING) — $(node -v 2>&1)"
    echo "xvfb-run: $(command -v xvfb-run || echo MISSING)"
    echo "oracle  : magium-dev at $DEV  (port $PORT)"
    echo "emulator: $([ -x "$EMU/koreader/luajit" ] && echo "built: $EMU" || echo "NOT BUILT")"
    ;;
  test)
    [ -d "$PLUGIN" ] || die "no magium.koplugin/ yet (Task 1 creates it)"
    cd "$PLUGIN" && exec busted "$@"
    ;;
  test-engine)
    [ -d "$PLUGIN/spec/engine" ] || die "no spec/engine/ yet"
    cd "$PLUGIN" && exec busted spec/engine "$@"
    ;;
  lua)
    [ -n "${1:-}" ] || die "usage: mgm.sh lua <file> [args]"
    cd "$PLUGIN" && exec luajit "$@"
    ;;
  diff)
    # oracle-diff.js. `capture`/`scene` need the live oracle; `diff <a> <b>` does
    # not — starting it unconditionally is harmless and keeps the recipe uniform.
    _start_oracle
    cd "$REPO" && node reference/tools/oracle-diff.js "$@"
    ;;
  with-oracle)
    [ -n "${1:-}" ] || die "usage: mgm.sh with-oracle <command...>"
    _start_oracle
    cd "$REPO" && "$@"
    ;;
  oracle-diff-lua)
    [ -d "$PLUGIN" ] || die "no magium.koplugin/ yet"
    _start_oracle
    cd "$PLUGIN" && luajit spec/oracle_diff.lua "$@"
    ;;
  emu-deploy)
    [ -d "$PLUGIN" ] || die "no magium.koplugin/ yet"
    [ -d "$EMU/koreader/plugins" ] || die "emulator not built ($EMU)"
    ln -sfn "$PLUGIN" "$EMU/koreader/plugins/magium.koplugin"
    echo "linked $PLUGIN -> $EMU/koreader/plugins/magium.koplugin"
    ;;
  emu-run)
    [ -d "$KO" ] || die "no $KO"
    cd "$KO" && exec xvfb-run -a ./kodev run --simulate=kindle-paperwhite --no-build
    ;;
  emu-log)
    tail -n "${1:-80}" "$EMU/koreader/crash.log"
    ;;
  kindle-tag)
    git -C "$KO" describe --tags --always
    git -C "$KO" log --oneline -1
    ;;
  *)
    grep -E '^#( |--|$)' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
