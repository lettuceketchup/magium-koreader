# Reference: magium-recrystallized

- **Status:** stub (not started)
- **Last updated:** 2026-08-31
- **Phase:** 0
- **Sources:** `../magium-recrystallized` @ `0dcfd2e` — `README.md`, `wasm_module/src/`, `src-tauri/`, `static/magium.story`
- **Related:** [`magium-dev-notes.md`](magium-dev-notes.md), [`../docs/research/08-licensing.md`](../docs/research/08-licensing.md)

> Secondary reference. Not the porting base (binary pipeline, AGPL), but its
> engine and save model are worth studying.

## What it is

- SvelteKit frontend + Rust/WASM engine (`wasm_module/`) + Tauri shell (`src-tauri/`).
- Story compiled to a **binary `.story` format** (`static/magium.story`); the WASM
  module decodes it (`wasm_module/src/decoder.rs`, `wasmtable.rs`).
- License: **AGPL-3.0** (vs. `magium-dev`'s MIT) — matters for [`08-licensing.md`](../docs/research/08-licensing.md).

## Worth studying *(task 0.5)*

- `wasm_module/src/lib.rs` / `decoder.rs` — how state, conditions, and scenes are
  modeled once compiled; compare semantics to `magium-dev`.
- `src/lib/stores/` (`state.ts`, `stats.ts`, `passagestore.ts`) — save/state model.
- Whether the `.story` compiler (source? build step?) is in-repo and what it
  consumes — is it the same `.magium` files or something else?

## Notes

_(none yet)_
