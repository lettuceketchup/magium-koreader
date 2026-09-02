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
#   test [busted-args]  run busted from magium.koplugin/ (no args = whole suite;
#                       for one file: `mgm.sh test spec/engine/foo_spec.lua`)
#   test-engine         run `busted spec/engine` (pure layer, fastest) — takes NO
#                       path args; use `test <path>` for a single file
#   test-ui             run spec/ui/*_smoke.lua under the emulator's KOReader env
#                       (real widgets, headless, DUMMY 600x800 Screen) — proves
#                       "doesn't crash". Fast, no X server.
#   test-ui-real        same smokes under xvfb + a REAL 1272x1696 @300dpi SDL
#                       framebuffer (spec/support/real_screen.lua) — proves
#                       layout at the owner's PW12 resolution. The gate before a
#                       device pass / merge (Phase V.5, item 7).
#   test-ui-matrix      test-ui-real repeated across ~4 device profiles (small 6"
#                       Kindle .. Kindle Scribe) — proves the custom reader lays
#                       out on screens other than the PW12 (Phase VI). The gate
#                       for any ui/reader.lua / pagination.lua / choices.lua change.
#   lua <file> [args]   run luajit from magium.koplugin/
#   koenv <script> [a]  run one Lua <script> (path relative to magium.koplugin/)
#                       inside the built emulator's KOReader env: real frontend
#                       widgets on the path, DUMMY 600x800 Screen, no X server.
#   real-screen <s> [a] like koenv but xvfb + a real 1272x1696 @300dpi Screen
#                       (sets MAGIUM_REAL_SCREEN=1; a *_smoke.lua then boots
#                       spec/support/real_screen.lua instead of commonrequire).
#   gen-cases [data-dir] [out.json] [pattern]
#                       luajit spec/gen_cases.lua — derive an oracle case matrix
#                       from parsed scene conditions (no oracle needed). Defaults:
#                       data-dir=./data/en, out=spec/out/cases.json. pattern is an
#                       optional Lua pattern filtering which *.magium files to use
#                       (e.g. '^ch1%.magium$' to scope to one chapter).
#   diff <args...>      oracle-diff.js <args...>, with the oracle auto-started
#                       around the call and torn down after (file-only subcommands
#                       like `diff <a> <b>` work too — the oracle just goes unused)
#   with-oracle <cmd..> start the oracle, run <cmd..> (cwd = repo root), stop it
#   oracle-diff-lua <args..>  luajit spec/oracle_diff.lua <args..> from the plugin
#                       dir, with the oracle live for the duration
#   oracle-corpus [out-dir]  full-corpus parity sweep: derive cases for every
#                       .magium file, capture oracle goldens, render the same
#                       cases through the Lua port, diff the two. One-shot,
#                       output goes under spec/out/ (gitignored) by default —
#                       this is a run-it-and-read-the-report command, not a
#                       golden-producing one.
#   emu-deploy          symlink magium.koplugin into the built emulator
#   emu-run             xvfb-run kodev run (kindle-paperwhite, no rebuild) — blocks
#   emu-smoke [SECS]    deploy + launch headless for SECS (default 25), kill it,
#                       then dump the run log + any magium/error/traceback lines.
#                       KOReader logger output goes to STDOUT (captured), not
#                       crash.log — crash.log only fills on an actual crash.
#   emu-log [N]         tail N lines of the last emu-smoke run log (default 80)
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
    if [ -n "${1:-}" ] && [ "${1#-}" = "$1" ]; then
      die "test-engine takes no path args (busted would double-scan). Use: mgm.sh test $*"
    fi
    cd "$PLUGIN" && exec busted spec/engine "$@"   # "$@" here is only flags, if any
    ;;
  test-ui|test-ui-real)
    # Headless UI regression checks — run the real KOReader widget stack.
    # `test-ui`      : fast path, commonrequire's DUMMY 600x800 Screen (no X
    #                  server). Proves "doesn't crash". Good for the inner loop.
    # `test-ui-real` : xvfb + a REAL SDL framebuffer at the owner's PW12 profile
    #                  (1272x1696 @ 300dpi) via spec/support/real_screen.lua —
    #                  proves "lays out right at the real width". This is the
    #                  gate before a device pass / merge (Phase V.5, item 7).
    # Every spec/ui/*_smoke.lua must exit 0 under both.
    [ -x "$EMU/koreader/luajit" ] || die "emulator not built ($EMU)"
    sub=koenv; [ "$cmd" = test-ui-real ] && sub=real-screen
    rc=0
    for s in "$PLUGIN"/spec/ui/*_smoke.lua; do
      [ -f "$s" ] || continue
      echo "── ${s##*/}"
      out=$(bash "$0" "$sub" "spec/ui/${s##*/}" 2>&1) || rc=1
      echo "$out" | grep -E "^\s+(ok|FAIL)|^(PASS|FAIL)" || echo "$out" | tail -5
    done
    exit $rc
    ;;
  test-ui-matrix)
    # test-ui-real across a set of device profiles other than the owner's PW12
    # (Phase VI). Proves the custom reader (ui/reader.lua + pagination + choices)
    # lays out on small/large screens we can't test on hardware. Every
    # spec/ui/*_smoke.lua must exit 0 at every profile.
    # profile = "name WxH DPI"
    profiles=(
      "kindle-6in     600  800  167"
      "paperwhite-11  1072 1448 300"
      "paperwhite-12  1272 1696 300"
      "kindle-scribe  1860 2480 300"
    )
    rc=0
    for p in "${profiles[@]}"; do
      read -r name w h dpi <<< "$p"
      echo "════ profile $name  ${w}x${h} @${dpi}dpi"
      EMULATE_READER_W="$w" EMULATE_READER_H="$h" EMULATE_READER_DPI="$dpi" \
        bash "$0" test-ui-real || rc=1
    done
    [ $rc -eq 0 ] && echo "mgm: test-ui-matrix OK (all profiles)" || echo "mgm: test-ui-matrix FAILED"
    exit $rc
    ;;
  lua)
    [ -n "${1:-}" ] || die "usage: mgm.sh lua <file> [args]"
    cd "$PLUGIN" && exec luajit "$@"
    ;;
  koenv|real-screen)
    # Run a Lua <script> inside the built EMULATOR's KOReader environment (real
    # frontend widgets on the path), plugin dir on LUA_PATH.
    #
    #   koenv       — fast. The script's own `require("commonrequire")` builds a
    #                 DUMMY Screen, ALWAYS 600x800 (base/ffi/framebuffer_SDL3.lua:17)
    #                 regardless of EMULATE_READER_W/H. Good enough to prove a
    #                 widget doesn't crash; NOT its layout at the real width.
    #   real-screen — xvfb + a REAL SDL framebuffer at the owner's PW12 profile
    #                 (1272x1696 @ 300dpi). Sets MAGIUM_REAL_SCREEN=1 so a smoke
    #                 file boots spec/support/real_screen.lua instead of
    #                 commonrequire (the one-line switch at the top of each
    #                 spec/ui/*_smoke.lua). This is what actually catches
    #                 real-width layout bugs (Phase V.5, item 7; the class of bug
    #                 that reached the device in Phase V, research-plan 2026-09-04).
    # Usage:  mgm.sh koenv spec/ui/reader_smoke.lua   (path is relative to the plugin dir)
    [ -n "${1:-}" ] || die "usage: mgm.sh $cmd <script.lua> [args]"
    [ -x "$EMU/koreader/luajit" ] || die "emulator not built ($EMU)"
    script="$PLUGIN/$1"; shift
    [ -f "$script" ] || die "no such script: $script"
    export EMULATE_READER_W="${EMULATE_READER_W:-1272}"
    export EMULATE_READER_H="${EMULATE_READER_H:-1696}"
    run=(./luajit -e "dofile('setupkoenv.lua'); package.path='$PLUGIN/?.lua;$KO/spec/unit/?.lua;'..package.path; arg={...}; dofile('$script')" "$@")
    if [ "$cmd" = real-screen ]; then
      export EMULATE_READER_DPI="${EMULATE_READER_DPI:-300}"
      export MAGIUM_REAL_SCREEN=1
      cd "$EMU/koreader" && exec xvfb-run -a "${run[@]}"
    fi
    cd "$EMU/koreader" && exec "${run[@]}"
    ;;
  gen-cases)
    [ -d "$PLUGIN" ] || die "no magium.koplugin/ yet"
    cd "$PLUGIN" && exec luajit spec/gen_cases.lua "${1:-./data/en}" "${2:-spec/out/cases.json}" ${3:+"$3"}
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
  oracle-corpus)
    [ -d "$PLUGIN" ] || die "no magium.koplugin/ yet"
    out="${1:-$PLUGIN/spec/out/corpus}"
    mkdir -p "$out"
    _start_oracle
    ( cd "$PLUGIN" && luajit spec/gen_cases.lua ./data/en "$out/cases.json" ) || exit 1
    ( cd "$REPO" && node reference/tools/oracle-diff.js capture --cases "$out/cases.json" --out "$out/oracle" ) || exit 1
    ( cd "$PLUGIN" && luajit spec/oracle_diff.lua "$out/cases.json" "$out/port" ) || exit 1
    cd "$REPO" && node reference/tools/oracle-diff.js diff "$out/oracle" "$out/port"
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
  emu-smoke)
    secs="${1:-25}"
    [ -d "$EMU/koreader/plugins" ] || die "emulator not built ($EMU)"
    if [ -d "$PLUGIN" ]; then
      ln -sfn "$PLUGIN" "$EMU/koreader/plugins/magium.koplugin"
      echo "mgm: deployed $PLUGIN"
    fi
    : > /tmp/magium-emu.log
    # Pass a directory so the emulator lands in FileManager (where a
    # is_doc_only=false plugin loads) rather than restoring a last-opened doc.
    ( cd "$KO" && timeout $((secs + 15)) xvfb-run -a ./kodev run \
        --simulate=kindle-paperwhite --no-build "$EMU/koreader" ) >/tmp/magium-emu.log 2>&1 &
    bg=$!
    echo "mgm: emulator launched headless, waiting ${secs}s ..."
    sleep "$secs"
    pkill -f "reader.lua" 2>/dev/null
    pkill -f "koreader-emulator-x86" 2>/dev/null
    kill "$bg" 2>/dev/null
    sleep 2
    pkill -9 -f "reader.lua" 2>/dev/null; pkill -9 -f "Xvfb" 2>/dev/null
    wait "$bg" 2>/dev/null
    echo
    echo "=== run log: magium / error / traceback / warning ==="
    grep -inE "magium|error|traceback|warning|luajit" /tmp/magium-emu.log | tail -60 \
      || echo "(no matching lines)"
    echo
    echo "=== run log tail (last 25 lines) ==="
    tail -25 /tmp/magium-emu.log
    echo
    if [ -s "$EMU/koreader/crash.log" ]; then
      echo "=== crash.log IS NON-EMPTY (a crash happened) ==="
      tail -40 "$EMU/koreader/crash.log"
    else
      echo "=== crash.log empty (no crash) ==="
    fi
    ;;
  emu-log)
    tail -n "${1:-80}" /tmp/magium-emu.log
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
