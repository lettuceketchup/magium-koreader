# Reference: magium-recrystallized

- **Status:** draft (source skim done 2026-08-31; not run)
- **Last updated:** 2026-08-31
- **Phase:** 0
- **Sources:** `../magium-recrystallized` @ `0dcfd2e` — `README.md`, `package.json`, `wasm_module/Cargo.toml`, `wasm_module/src/{lib,decoder,wasmtable,utils}.rs`, `static/magium.story` (hex), `src/lib/stores/`
- **Related:** [`magium-dev-notes.md`](magium-dev-notes.md), [`../docs/research/08-licensing.md`](../docs/archive/research/08-licensing.md), [`../docs/research/06-approach-comparison.md`](../docs/archive/research/06-approach-comparison.md)

> Secondary reference. **Not** the porting base. This note records *why*, and what
> is still worth borrowing.

## What it is

- **SvelteKit 2 / Svelte 5** frontend + **Rust→WASM** engine (`wasm_module/`, built
  with `wasm-pack build --target web`) + **Tauri 2** shell for desktop/mobile.
- License: **AGPL-3.0-only** (contrast `magium-dev` = MIT).
- Rust edition 2024; deps include `zstd`, `byteorder`, `wasm-bindgen`, `web-sys`
  (Request/Response/Headers — i.e. it does its own HTTP).

## The `.story` binary format

- Magic `CYOA`, version `0x0001`, then **TLV / chunk-packed** data. Chunk types
  (`decoder.rs`): `Node 0x01`, `Edge 0x02`, `Content 0x03`, `Metadata 0x04`,
  `ArgBlobPool 0xFD`, `WasmTable 0xFE`.
- `static/magium.story` in-repo is **43 KB and stores text uncompressed**
  (plaintext "They say there is a very fine line…" visible in hex). zstd support
  exists in the decoder but isn't used for this artifact. 43 KB ⇒ this committed
  file is a **partial/sample story**, not all three books.
- The decoder is built around **HTTP range requests**: "fetch only the header and
  index, then lazily load nodes & edges" with an LRU chunk cache
  (`decoder.rs` module doc). Designed for streaming from a server, not offline use.
- `WasmTable` chunk + `wasmtable.rs::run_guard(fid, gb) -> bool` implies
  **executable logic embedded in the story file** — but `run_guard` is currently
  a stub `{ true }`, so the scripting path is unfinished. How conditions/stats
  actually evaluate in this build is unclear from source alone (likely via `Edge`
  metadata + `ArgBlobPool`) — would need to run it.

## Why not the porting base

| Factor | Impact |
|---|---|
| Binary `.story` format, no `.magium`→`.story` compiler in the repo | We'd depend on an external/unpublished toolchain, or reverse the format. |
| Engine is Rust/WASM | Can't run as-is under KOReader (LuaJIT). Would need a full reimplementation *and* a WASM runtime, or a rewrite. |
| Designed for HTTP range streaming | Opposite of what a self-contained offline Kindle plugin needs. |
| AGPL-3.0 | More restrictive than `magium-dev`'s MIT (matters for distribution — [`08-licensing.md`](../docs/archive/research/08-licensing.md)). |
| Scripting layer unfinished (`run_guard` stub) | Semantics not fully pinned down; the sample `.story` is partial. |

vs. `magium-dev`: ~650 LOC JS, human-readable `.magium` data, runtime parser,
MIT — everything this one isn't, for our purposes.

## Still worth borrowing *(task 0.5)*

- **State/save model:** `src/lib/stores/{state,stats,passagestore,displaysettings}.ts`
  — a second opinion on how to structure the variable store, stats, and saves in a
  modern rewrite. Compare against `magium-dev`'s cookie model.
- **Format ideas:** the `Node`/`Edge`/`Content` split and an index-first layout are
  a reasonable design if we end up building our own pre-compiled format for
  approach D (build-time preprocess). The chunked/indexed layout is exactly the
  shape that would let a Kindle plugin load scenes lazily without parsing 7.5 MB
  of text at launch.
- **Continued story content:** the writing team's post-book-3 material lands here
  first — relevant long-term, not for a feasibility port.

## Not done

- Have not built or run it (`npm run wasm` needs Rust + wasm-pack + wasm-bindgen).
  Only run it if Phase 6 seriously considers a format-conversion or
  shared-save-model path.
