---
name: device
description: >-
  Deploy magium.koplugin to the owner's Kindle Paperwhite and pull crash.log +
  save state back off it. Use whenever code needs to run on the real device — an
  owner test pass, a phase sign-off — or whenever a device bug report comes back
  (a crash, a layout problem, a stuck widget) and you need the evidence before
  theorizing. Covers the standard SSH deploy, the MTP fallback, what to ask the
  owner to check, and reading the state blob. Use this instead of hand-writing
  ssh/sftp commands.
---

# Device deploy & debug

Fast iteration is the emulator (`mgm.sh emu-deploy` + `emu-run`, and the
`verify` skill). Deploy to the device only for e-ink feel, real touch input,
and phase sign-off — it is the *final* confirmation, never the first check that
the code works.

## Deploy

From the repo root:

    powershell -File tools/kindle-ssh-deploy.ps1 -Name paperwhite

SSH over WiFi is the standard method (owner directive, 2026-09-04). It tests
the connection, wipes the device plugin folder, `sftp put -r` a fresh copy
(minus `spec/` and dotfiles), and verifies by file count. Then tell the owner
to **restart KOReader** — there is no hot reload.

First time for a device: `kindle-ssh-setup.ps1 -Name <n>` over USB once, then
`kindle-ssh-test.ps1 -Name <n> -Ip <addr>`. Full one-time steps:
`reference/koreader-notes.md` → "On-device deployment & debugging".

**Fallback — USB / MTP:** `tools/deploy-kindle.ps1`, only when SSH is
unreachable (device off WiFi, SSH server not started). MTP `CopyHere` silently
does **not** overwrite existing files — this shipped stale code to the device
for weeks before it was caught. The script wipes + verifies by size; if MTP
refuses the delete it tells you to remove the folder in File Explorer once and
rerun.

## When a device bug comes back: pull the evidence first

Do not theorize from the report. Pull the logs and state:

    powershell -File .claude/skills/device/scripts/kindle-pull-logs.ps1 -Name paperwhite

This lands, in a timestamped scratch dir: `crash.log` (all `logger` output +
tracebacks, last 500 KB) and the whole `koreader/magium/` dir — `state`,
`achievements`, `checkpoint`, `slots/`, `trace-*.jsonl`.

- The blobs are `Persist` dumps (a serialized Lua table). Read them to confirm
  what actually persisted — `v_current_scene`, `v_ac_*`, spent stat points.
- A layout / lingering-widget bug often leaves **no traceback**. An empty
  `crash.log` rules out a hard error, nothing more.
- If the debug action-trace was on, `trace-*.jsonl` holds the per-choice
  action log for the session.

## What to ask the owner to check

Give an explicit checklist tied to the change, not "does it work":

- the specific screens / interactions this change adds or alters
- resume still works across: reader close, device suspend, full KOReader restart
- `crash.log` is clean

For a phase sign-off, the checklist **is** the spec's exit criteria — see the
`phase` skill.
