# Decision records (ADRs)

Every decision that closes off an alternative gets a short Architecture Decision
Record here, so the reasoning survives after the decision looks obvious.

## Rules

- One file per decision: `ADR-NNN-short-slug.md`, `NNN` zero-padded, sequential.
- Copy `ADR-000-template.md` to start.
- **Never edit a decided ADR's Decision section.** To change course, write a new
  ADR that supersedes it: the new one links back, and the old one's status
  becomes `Superseded by ADR-MMM`.
- Reference ADRs from other docs by ID (`ADR-001`), not by restating them.
- `SUMMARY.md` lists the current live decisions.

## Index

| ADR | Title | Status |
|---|---|---|
| [001](ADR-001-research-dossier-layout.md) | Research organized as a modular dossier | Accepted |
