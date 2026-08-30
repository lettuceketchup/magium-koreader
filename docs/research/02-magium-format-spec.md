# 02 — The `.magium` file format

- **Status:** stub (not started)
- **Last updated:** 2026-08-31
- **Phase:** 1
- **Sources:** `../magium-dev` @ `51f5aa9` — `src/parser.js`; `../magium-dev/data/en/*.magium` (54 files); `../magium-dev/data/fr/*.magium`
- **Related:** [`01-magium-analysis.md`](01-magium-analysis.md)

> Goal: a precise description of the `.magium` syntax **plus an exhaustive corpus
> of every construct actually used across all 54 English files** (not a sample),
> flagging anything the reference parser's regexes would mishandle. This underpins
> both a Lua reimplementation and any format-conversion approach.

## 1. File & line structure
_`ID:` / `TEXT:` / blank-line-after-TEXT / prose lines / `}` / `#if(...) {`._

## 2. Constructs

### 2.1 `choice(...)`
_Grammar; label quoting (incl. the `choice(""...."")` double-quote case in `ch1.magium`); empty target (`choice("Load game", , , special:saves)`); multiple `var = value` assignments; `special:` suffix; trailing `if <condition>`._

### 2.2 `set(var, value) [if <condition>]`
_Value range `[+-]?[0-9]` (single digit!) — verify no multi-digit sets exist._

### 2.3 `#if(<condition>) { ... }`
_Conditional paragraph blocks; nesting; interaction with `}`._

### 2.4 `achievement("text", v_flag)`

### 2.5 Conditions
_Atom grammar `\w+ (<|>|>=|==|<=|!=) [0-9]+`; `&&` / `||`; parentheses; `True` literal._

## 3. Construct corpus *(task 1.11)*
_Generated inventory across all 54 files. Table: construct → count → files → example → parser-safe?_

| Construct | Count | Example file | Notes / risks |
|---|---|---|---|
| _TBD_ | | | |

## 4. Parser risk list
_Cases where `parser.js` / `utils.js` regexes are fragile (multi-digit set values, quotes in labels, whitespace sensitivity, `\r\n`, unicode). Each with a file:line example._

## 5. en vs. fr divergence
_Structural differences between locales, if any._

## Findings

_(none yet)_
