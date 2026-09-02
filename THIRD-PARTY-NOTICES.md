# Third-party notices & attribution

`magium-koreader` is a fan port. It could not exist without the work below, and
this file is the required attribution for all of it. Nothing here is our own
work.

Summary of what is bundled or derived, and under which licence:

| Component | Origin | Licence | How it is used here |
|---|---|---|---|
| **Magium story text** (`magium.koplugin/data/en/*.magium`, `ui.json`, `achievements*.json`) | Written by **Cristian Mihailescu**; released by his family; transcribed to the `.magium` format by the **magium-dev** project | **CC BY 4.0** | Bundled **verbatim** from `magium-dev/data/en` and reflowed/paginated at runtime. Story content is unchanged. |
| **Engine design** (`magium.koplugin/engine/`) | **magium-dev** (`src/parser.js`, `src/utils.js`, `src/renderers.js`) | **MIT** | Reimplemented in Lua. Behaviour is verified scene-for-scene against magium-dev as a differential oracle. |
| **Original source** | **raduprv/Magium** (Clickteam Fusion project + data dump) | **MIT** (code) / **CC BY 4.0** (data) | The `.magium` format and the story data originate here. Not vendored. |
| **KOReader** | koreader/koreader | **AGPL-3.0** | Host platform. This plugin targets its documented plugin API; KOReader itself is not bundled. |

---

## Magium — story text and original game

Magium is a text-based Choose Your Own Adventure game written and developed by
**Cristian Mihailescu** (1996–2024). Following his passing in August 2024, his
brother Radu released the game's source and data **with the family's
permission**, so that the community could preserve the story, translate it, and
continue it in line with the author's wishes.

- Original release: <https://github.com/raduprv/Magium>
- The README of that repository states, verbatim:
  > "All the data (text and such) is released under CC BY 4.0 license."
- The stated purpose of the release was "porting the game to other languages,
  and hopefully finishing it too."

**The Magium story text in this repository is © Cristian Mihailescu and is
licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).**
Changes made here: the text was transcribed into the line-oriented `.magium`
scene format by the magium-dev project, and this port reflows and paginates it
for e-ink screens. The narrative content itself is not altered.

### Original code — MIT

```
MIT License

Copyright (c) 2024 Cristian Mihailescu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## magium-dev / MagiumJS — the porting base

<https://github.com/thuiop/magium-dev> — a fan-made JS/Electron recreation of
the three original Magium books, created "to better preserve his stories once
they are taken off the various app stores Magium is currently offered on." This
project's Lua engine is a reimplementation of magium-dev's engine, and the
bundled `.magium` files are copied from its `data/en` directory.

```
MIT License

Copyright (c) 2024 Christian Mihailescu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Contributors: <https://github.com/thuiop/magium-dev/graphs/contributors>

---

## magium-recrystallized — secondary reference

<https://github.com/Br3nnabee/magium-recrystallized> — a Svelte + Rust/WASM
community recreation and continuation, **AGPL-3.0**. Used only for cross-checking
behaviour during research. No code or data from it is included in this
repository.

---

## KOReader — host platform

<https://github.com/koreader/koreader> — **AGPL-3.0**. This plugin is written
against KOReader's plugin API and is distributed on its own; KOReader is not
bundled here. Because a KOReader plugin is loaded into KOReader's process, this
plugin's own code is licensed **AGPL-3.0-or-later** to match — see
[`LICENSE`](LICENSE) and [ADR-008](docs/decisions/ADR-008-license-and-distribution.md).

---

## This port

Everything original to this repository — the Lua engine reimplementation, the
KOReader UI, the save system, the build/test tooling, and the documentation — is
© the `magium-koreader` contributors and licensed **AGPL-3.0-or-later**
([`LICENSE`](LICENSE)).

This is an unofficial fan project. It is not affiliated with, sponsored by, or
endorsed by the family of Cristian Mihailescu, the magium-dev project, the
magium-recrystallized project, or KOReader. It is non-commercial.
