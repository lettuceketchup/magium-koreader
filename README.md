# magium-koreader

Can *Magium* — the text-based choose-your-own-adventure game by the late
Cristian Mihailescu — be played on a **Kindle Paperwhite running
[KOReader](https://github.com/koreader/koreader)**?

Yes — and this repository is the port. It began as a **research and design
effort** (the dossier under `docs/`) and is now **implementing the game** as a
KOReader plugin in [`magium.koplugin/`](magium.koplugin/). Magium's interaction
model (scrolling prose, a few choice buttons, menus) lines up closely with what
KOReader already does, which is what makes the port work.

Reference device: **Kindle Paperwhite 12th gen (2024)**, firmware 5.19.5,
KOReader v2026.07.1 (`kindlehf`), ~1 GB RAM.

## Status

**Feature-complete (`v1.0`, 2026-09-08).** All three books are playable
end-to-end on the reference device, with saves, stats, achievements, and
settings. Research is complete — chosen approach
([ADR-002](docs/decisions/ADR-002-porting-approach.md)), phased roadmap
([`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md)); Phases I–VI + VIII
shipped with on-device sign-off. Work now is maintenance and polish. French
localization is built but shelved pending a complete upstream translation.
See the running log in [`research-plan.md`](research-plan.md).

Install: [`INSTALL.md`](INSTALL.md). It targets the Kindle Paperwhite 12 but
should run on other KOReader devices — reports welcome
([`CONTRIBUTING.md`](CONTRIBUTING.md)).

## Where to look

| You want... | Go to |
|---|---|
| The plugin itself | [`magium.koplugin/`](magium.koplugin/) |
| The implementation spec | [`docs/specs/`](docs/specs/) |
| The short version of what the research concluded | [`SUMMARY.md`](SUMMARY.md) |
| The plan and its status | [`research-plan.md`](research-plan.md) |
| Why this phase is structured the way it is | [`docs/superpowers/specs/2026-08-31-magium-koreader-research-design.md`](docs/superpowers/specs/2026-08-31-magium-koreader-research-design.md) |
| Individual research topics (shareable) | [`docs/research/`](docs/research/) |
| Decisions and their rationale | [`docs/decisions/`](docs/decisions/) |
| Open questions and where to ask them | [`docs/research/07-risks-open-questions.md`](docs/research/07-risks-open-questions.md) |
| Throwaway experiments and their findings | [`docs/spikes/`](docs/spikes/) |
| Guidance for AI agents working here | [`CLAUDE.md`](CLAUDE.md) |

## Research topic docs

- [`00-overview.md`](docs/research/00-overview.md) — problem, goals, non-goals, success criteria, glossary
- [`01-magium-analysis.md`](docs/research/01-magium-analysis.md) — how the Magium engine works
- [`02-magium-format-spec.md`](docs/research/02-magium-format-spec.md) — the `.magium` file format
- [`03-koreader-platform.md`](docs/research/03-koreader-platform.md) — KOReader plugin platform & constraints
- [`04-constraints-budget.md`](docs/research/04-constraints-budget.md) — device limits vs. game needs (go/no-go)
- [`05-prior-art.md`](docs/research/05-prior-art.md) — how others have done comparable things; who to ask
- [`06-approach-comparison.md`](docs/research/06-approach-comparison.md) — candidate approaches, decision matrix
- [`07-risks-open-questions.md`](docs/research/07-risks-open-questions.md) — risk register & open questions
- [`08-licensing.md`](docs/research/08-licensing.md) — licenses, permissions, distribution
- [`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md) — implementation roadmap, effort, timeline

## Upstream projects

This project stands on the shoulders of the community recreations of Magium.
Neither is vendored here — they are consulted as references.

- [magium-dev / MagiumJS](https://github.com/thuiop/magium-dev) — JS/Electron port; primary porting base (MIT)
- [magium-recrystallized](https://github.com/Br3nnabee/magium-recrystallized) — Svelte + Rust/WASM continuation (AGPL-3.0)
- [Original Magium](https://github.com/raduprv/Magium) — where the `.magium` format originates
- Community: [r/Magium](https://www.reddit.com/r/Magium/) · [Magium Discord](https://discord.com/invite/cF3EDRmK)

## Credit

**Magium was created by [Cristian Mihailescu](https://github.com/raduprv/Magium)**
(1996–2024). After his passing, his family released the game and **licensed all
of its story text [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)** so
the community could preserve, translate, and continue it — which is what this
port does.

- The **story text** here is copied from [magium-dev](https://github.com/thuiop/magium-dev),
  which transcribed the original into the `.magium` scene format. It is © Cristian
  Mihailescu, CC BY 4.0; this port reflows and paginates it for e-ink, and the
  narrative content is unchanged.
- The **engine** is a Lua reimplementation of magium-dev's engine (MIT).
- The **platform** is [KOReader](https://github.com/koreader/koreader) (AGPL-3.0).

Full attribution and the third-party licence texts:
[`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

This is an **unofficial, non-commercial fan project**. It is not affiliated with
or endorsed by the family of Cristian Mihailescu, the magium-dev or
magium-recrystallized projects, or KOReader.

## Licence

- This port's **code, docs, and tooling**: **AGPL-3.0-or-later**
  ([`LICENSE`](LICENSE)) — matching KOReader, into which the plugin loads. See
  [ADR-008](docs/decisions/ADR-008-license-and-distribution.md) and
  [`docs/research/08-licensing.md`](docs/research/08-licensing.md).
- The bundled **Magium story text**: **CC BY 4.0**, © Cristian Mihailescu — not
  relicensed.

## Contributing

Contributors are welcome — testers, coders, e-ink specialists, or fans. Bug
reports (especially for e-ink devices other than the Kindle Paperwhite 12),
issues, PRs, and forks that continue the work are all invited. See
[`CONTRIBUTING.md`](CONTRIBUTING.md).
