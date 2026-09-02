# Contributing to magium-koreader

This is a fan port, and it is meant to be shared. Contributions are welcome
whether you are a tester, a Lua coder, an e-ink / KOReader specialist, or just a
fan of Magium. Forking it to continue the work is welcome too. It is
non-commercial and not affiliated with the Magium authors or KOReader.

- [Ways to help](#ways-to-help)
- [Reporting a bug or a device problem](#reporting-a-bug-or-a-device-problem)
- [How the plugin is put together](#how-the-plugin-is-put-together)
- [Setting up to build and test](#setting-up-to-build-and-test)
- [Build, test, run](#build-test-run)
- [Deploying to a device](#deploying-to-a-device)
- [Regenerating the screenshots](#regenerating-the-screenshots)
- [Sending a pull request](#sending-a-pull-request)
- [How AI is used here](#how-ai-is-used-here)
- [Licensing of contributions](#licensing-of-contributions)

## Ways to help

- **Report a bug or a device problem.** Especially if Magium misbehaves on an
  e-reader other than the Kindle Paperwhite 12 (the reference device).
- **Fix something.** Small, focused PRs are easiest to review.
- **Test.** Playthrough reports — "reached Book 3, saves survived a suspend,
  choice X went to the wrong scene" — are genuinely useful.
- **E-ink / KOReader expertise.** Refresh feel, widget behaviour on other
  panels, packaging for the KOReader plugin index — all open.
- **French (or other) localization.** The mechanism is built and shelved
  pending a complete upstream `.magium` translation
  ([tag `phase-vii-shelved`](../../tree/phase-vii-shelved)).

## Reporting a bug or a device problem

Open a [GitHub issue](https://github.com/lettuceketchup/magium-koreader/issues)
with:

- your **device**, its **firmware**, and your **KOReader version**
  (KOReader → top menu → the ⓘ / *Version* row);
- what you did and what happened;
- if it crashed or misbehaved, attach **`koreader/crash.log`** from the device
  (it holds KOReader's log output and any traceback);
- if you can, turn on **Menu → Settings → Record debug log** inside Magium,
  reproduce, and attach the newest `koreader/magium/trace-*.jsonl`.

## How the plugin is put together

Everything ships in `magium.koplugin/`. Three layers:

| Path | What | KOReader deps? |
|---|---|---|
| `engine/` | Pure-Lua reimplementation of the magium-dev engine — parser, condition evaluation, scene rendering, the variable store. | **None.** Runs under plain `luajit`. |
| `ui/` | KOReader widgets — the paginated `reader`, the choices list, stats / achievements / saves screens, refresh policy. | Yes. Needs the emulator or a device. |
| `save/` | Autosave, checkpoint, and the 50 manual slots. I/O and the scheduler are injected, so it is testable without KOReader. |
| `main.lua` | The glue: KOReader plugin lifecycle, the in-game menu, wiring the layers together. | Yes. |
| `data/` | The bundled Magium story (`en/*.magium`, `ui.json`, `achievements*.json`). **CC BY 4.0** — see below. | — |
| `spec/` | Tests: `engine/` + `save/` + `flow/` (busted), `ui/*_smoke.lua` (real KOReader widgets, headless). | — |

Read **[CLAUDE.md](CLAUDE.md)** and
**[docs/specs/2026-08-31-plugin-architecture-and-phase-i.md](docs/specs/2026-08-31-plugin-architecture-and-phase-i.md)**
first — the spec is the authority on module boundaries and the `scene.render`
pipeline. Design rationale lives in **[docs/decisions/](docs/decisions/)**.

The behavioural reference for every engine question is **magium-dev**
(`../magium-dev`, a sibling checkout at its recorded commit — MIT). The engine is
tested scene-for-scene against it as a differential oracle.

## Setting up to build and test

The dev host is Windows; the Lua / Node / KOReader-emulator toolchain lives in
**WSL2 (Ubuntu)**. (Linux and macOS work too — you just need the same tools on
`PATH`.)

1. **WSL2 + Ubuntu** — `wsl --install -d Ubuntu` on Windows, then open it.
2. **The toolchain + emulator**, one shot (~7 min):

   ```sh
   bash reference/setup-koreader-wsl.sh
   ```

   This installs the apt prerequisites and a compatible `ninja` / `make`, clones
   KOReader to `~/koreader` at the pinned release tag `v2026.07.1`, and builds
   the emulator. Details and the cloud-session variant:
   [`reference/koreader-notes.md`](reference/koreader-notes.md).
3. **Lua test tooling** — `luarocks install busted` (the `env` check below
   expects `busted` on `PATH`; `~/.luarocks/bin` is added by `mgm.sh`).
4. **The oracle** — `node` (18+) is used to run magium-dev as a differential
   oracle. `mgm.sh` starts and stops it for you; `npm install` in `../magium-dev`
   happens automatically on first use.

Check it:

```sh
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh env'
```

You should see real paths for `luajit`, `busted`, `node`, `xvfb-run`, and
`emulator: built`.

## Build, test, run

There is no build step for the plugin itself — it is Lua, loaded as-is.
Everything goes through **`tools/mgm.sh`**, run inside WSL from the repo root:

```sh
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh <command>'
```

| Command | What it does | When to run it |
|---|---|---|
| `test` | Full `busted` suite — `engine/`, `save/`, `flow/` playthroughs, the app-level E2E, schema/navigation integrity. | Every change. Must be green before a PR. |
| `test <path>` | One spec file, e.g. `test spec/engine/parser_spec.lua`. | Inner loop. |
| `test-ui` | Every `spec/ui/*_smoke.lua` under the emulator's real widget stack, fast dummy 600×800 Screen. Proves "doesn't crash". | Any `ui/` or `main.lua` change. |
| `test-ui-real` | The same smokes under `xvfb` at the real 1272×1696 @300dpi. Proves layout. | Before a device test or a merge, for any `ui/` change. |
| `test-ui-matrix` | `test-ui-real` across 4 device profiles (6" Kindle … Kindle Scribe). | Any change to `ui/reader.lua`, `pagination.lua`, or `choices.lua`. |
| `oracle-corpus` | Per-scene render parity vs magium-dev across all 54 story files (~15 min). Baseline: `8887/8887`. | Any change that could alter a render path. |
| `emu-smoke` | Launches the plugin headless in the emulator for ~25 s; confirms it loads and `crash.log` stays empty. | After any change, as a final sanity check. |
| `emu-run` | `xvfb-run kodev run` — the emulator, no rebuild. Blocks. | Manual poking. |
| `emu-deploy` | Symlinks `magium.koplugin/` into the built emulator so it is always current. | Once, before `emu-run`. |

The full change-to-suite mapping and failure triage is the **`verify`** project
skill (`.claude/skills/verify/`), and is summarised in
[CLAUDE.md](CLAUDE.md#doing-implementation-work).

**Green means:** `busted` prints `N successes / 0 failures / 0 errors` (the count
only goes up); each `*_smoke.lua` prints `PASS  (0 checks failed)`;
`oracle-corpus` reports `0 DIFF`.

**A `ui/` change that doesn't add or extend a `spec/ui/*_smoke.lua` (real
`paintTo` for every state it can reach) is incomplete** — the dummy Screen hides
real-width layout bugs, which is how several device-only bugs got through early
on. `test-ui-real` is the gate.

## Deploying to a device

For iteration, prefer the emulator. For real e-ink / input checks, deploy to a
Kindle. **SSH over WiFi is the standard path**; USB/MTP is a fallback (MTP
silently refuses to overwrite existing files, so the script deletes first and
verifies by size).

```powershell
# one-time: device on WiFi + USB, SSH server started once in KOReader
powershell -File tools/kindle-ssh-setup.ps1 -Name paperwhite
powershell -File tools/kindle-ssh-test.ps1  -Name paperwhite -Ip <device-ip>

# every deploy
powershell -File tools/kindle-ssh-deploy.ps1 -Name paperwhite
```

Then **fully restart KOReader** and read `koreader/crash.log`. Full setup,
the USB fallback, and where saves live on the device: **[INSTALL.md](INSTALL.md)**.
Pulling logs + save state back off the device for a bug report is the **`device`**
project skill.

## Regenerating the screenshots

The images under `docs/media/` are captured headlessly from the real widgets at
the Paperwhite 12 resolution:

```sh
wsl -d Ubuntu -- bash -lc 'bash tools/mgm.sh real-screen spec/support/capture_screens.lua'
```

Rerun this after any `ui/` change that alters what a screen looks like, and
commit the updated PNGs.

## Sending a pull request

1. Branch off `main` (`feat/…` or `fix/…`). Don't commit to `main` directly.
2. Make the change, add/extend the test that would fail without it.
3. Run the gates for what you touched (table above). At minimum `test` must be
   green; `ui/` changes also need `test-ui-real`.
4. Open the PR against `main` with a description of what changed and why.
   Reference an `ADR-NNN` if the change relates to a recorded decision; if it
   closes off an alternative, add a new ADR
   ([`docs/decisions/`](docs/decisions/), copy `ADR-000-template.md`).

There is no CI yet, so please state which gates you ran.

## How AI is used here

This port was built largely with **Claude Code**, and ongoing maintenance —
features, bug fixes, and code review — continues to use it, under human
direction and with every release verified on real hardware. Contributions from
humans, from AI-assisted humans, and AI-assisted review of PRs are all fine.
What matters is the usual: the change is correct, it has a test, and a person
stands behind it. `CLAUDE.md` is written for the AI assistant but doubles as the
architecture and workflow guide for everyone.

## Licensing of contributions

By contributing, you agree that your contribution is licensed under the same
terms as the part of the project it touches:

- **Code, docs, tooling:** **AGPL-3.0-or-later** (inbound = outbound). See
  [LICENSE](LICENSE) and
  [ADR-008](docs/decisions/ADR-008-license-and-distribution.md).
- **Story text** (`magium.koplugin/data/**`): **CC BY 4.0**, © Cristian
  Mihailescu. Corrections are welcome but must preserve that provenance — do not
  introduce text under other terms. See
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
