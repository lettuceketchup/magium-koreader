# Installing Magium on a KOReader device

Copy `magium.koplugin/` into KOReader's `plugins/` folder and restart. The story
is bundled — no extra downloads.

**Reference device:** Kindle Paperwhite 12 (2024), KOReader `v2026.07.1`
`kindlehf`. Other devices and KOReader builds are untested but should work — see
[`CONTRIBUTING.md`](CONTRIBUTING.md) if yours doesn't.

Licence: AGPL-3.0-or-later (code) + CC BY 4.0 (Magium story text, © Cristian
Mihailescu). See [`README.md`](README.md#licence) and
[`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

---

## The simple way (any device)

1. Download `magium-koreader-v1.0.zip` from the
   [latest release](https://github.com/lettuceketchup/magium-koreader/releases/latest)
   and unzip it.
2. Connect the device by USB and copy the `magium.koplugin/` folder so it lands at:

   ```
   koreader/plugins/magium.koplugin/
   ```

   On a Kindle the KOReader folder is `koreader/` at the top of the USB drive; on
   Kobo it is `.adds/koreader/`. If you already have a `magium.koplugin` there,
   delete it first (some file transfers won't overwrite).
3. Eject, and **fully restart KOReader** — exit it completely and reopen. There
   is no hot reload.
4. Open it: **File browser → ≡ menu → Magium**.

Updating later = replace the folder and restart again. Your saves live outside
the plugin folder (see below) and survive updates.

---

## Deploy over WiFi (for repeated updates)

One-time setup, then one command per update.

**One-time** (device on WiFi, USB handy):

1. On the Kindle: KOReader → Tools → Network → **SSH server** → tick
   *"Login with key only (SECURE)"*, Start it once (shows IP + port 2222).
2. From the repo root (USB-connected):
   ```
   powershell -File tools/kindle-ssh-setup.ps1 -Name paperwhite
   powershell -File tools/kindle-ssh-test.ps1  -Name paperwhite -Ip <device-ip>
   ```

**Every update:**

```
powershell -File tools/kindle-ssh-deploy.ps1 -Name paperwhite
```

Wipes the device's `magium.koplugin/`, copies a fresh tree (minus `spec/` and
dotfiles), verifies by file count. Then **restart KOReader** — there is no hot
reload.

## Deploy over USB (fallback)

Only when SSH is unreachable:

```
powershell -File tools/deploy-kindle.ps1
```

MTP `CopyHere` **silently skips files that already exist**, so the script
deletes the device folder first and verifies every file by size. If it can't
delete, remove
`This PC → Kindle → Internal Storage → koreader → plugins → magium.koplugin`
in File Explorer once, then rerun. Restart KOReader afterwards.

## Running it

File Manager → `≡` → **Magium**. Opens fullscreen.

- **The first open each KOReader session takes ~2.2 s** (parsing all 54 story
  files, behind a progress bar). Every open after that is instant; the story
  stays loaded until you quit KOReader.
- Progress autosaves on a timer and on close / suspend. Manual save slots,
  stats, achievements, and settings are in the in-game `Menu`.

## Where things live on the device

| Path | What |
|---|---|
| `koreader/plugins/magium.koplugin/` | the plugin + bundled story |
| `koreader/magium/state` | autosave (current playthrough) |
| `koreader/magium/checkpoint`, `achievements`, `slots/NN.blob` | checkpoint, achievements, manual slots |
| `koreader/magium/trace-*.jsonl` | play-session trace, only if *Menu → Settings → Record debug log* is on |
| `koreader/crash.log` | all KOReader log output + any traceback |

## Known limitations

- No live re-layout on rotation — rotate, then close and reopen Magium to
  re-paginate at the new orientation.
- The first-open parse cost above is by design (spike 06 / ADR-002).
