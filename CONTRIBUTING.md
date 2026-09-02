# Contributing to magium-koreader

This is a fan port, and it is meant to be shared. Contributions are welcome
whether you are a tester, a Lua coder, an e-ink / KOReader specialist, or just a
fan of Magium. Forking it to continue the work is welcome too.

## Ways to help

- **Report a bug or a device problem.** Open an issue. If Magium misbehaves on
  an e-ink device other than the Kindle Paperwhite 12 (the reference device),
  that is exactly the kind of report this project wants — include your device,
  firmware, and KOReader version, and attach `koreader/crash.log` if it
  crashed.
- **Fix something.** Open a PR. Small, focused changes are easiest to review.
- **Test.** Playthrough reports — "reached Book 3, saves survived a suspend,
  choice X went to the wrong scene" — are genuinely useful.
- **E-ink / KOReader expertise.** Refresh feel, widget behaviour on other
  panels, and packaging for the KOReader plugin index are all open areas.

## Working on the code

- Read [`CLAUDE.md`](CLAUDE.md) and
  [`docs/specs/2026-08-31-plugin-architecture-and-phase-i.md`](docs/specs/2026-08-31-plugin-architecture-and-phase-i.md)
  first — they explain the three-layer layout (`engine/` pure Lua, `ui/`
  KOReader widgets, `save/`) and the test gates.
- `engine/` changes are checked against the `magium-dev` differential oracle.
  `ui/` changes are emulator-verified and land an automated smoke test.
- Test commands live in `tools/mgm.sh` (run under WSL). At minimum, `test`
  must be green before a PR.
- Install / deploy: [`INSTALL.md`](INSTALL.md).

## Licensing of contributions

By contributing, you agree that your contribution is licensed under the same
terms as the part of the project it touches:

- **Code, docs, tooling:** **AGPL-3.0-or-later** (inbound = outbound). See
  [`LICENSE`](LICENSE) and
  [ADR-008](docs/decisions/ADR-008-license-and-distribution.md).
- **Story text** (`magium.koplugin/data/**`): **CC BY 4.0**, © Cristian
  Mihailescu. Corrections to the story text are welcome but must preserve that
  provenance — do not introduce text under other terms. See
  [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

## Not affiliated

This project is not affiliated with or endorsed by the family of Cristian
Mihailescu, the magium-dev or magium-recrystallized projects, or KOReader. It is
non-commercial.
