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

**Phase: IMPLEMENTATION.** Research is complete — chosen approach
([ADR-002](docs/decisions/ADR-002-porting-approach.md)), phased roadmap
([`09-roadmap-effort.md`](docs/research/09-roadmap-effort.md)). Phase I (MVP: the
full engine, chapter 1 playable end-to-end on the real Kindle, autosave/resume)
has landed; Phase II (full corpus + navigation) is next. See the running log in
[`research-plan.md`](research-plan.md) for live status and
[`docs/specs/`](docs/specs/) for the implementation spec.

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

Magium was created by Cristian Mihailescu. The community recreations continue his
work with his family's permission. This project is an independent, non-commercial
attempt to make the story playable on e-ink readers.
