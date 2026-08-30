#!/usr/bin/env node
/*
 * scan-save-footprint.js — save-blob footprint estimate for docs/research/04-constraints-budget.md (task 3.2)
 *
 * A Magium save is a flat snapshot of the whole variable store (see
 * docs/research/01-magium-analysis.md §8). The upper bound on that snapshot is the
 * set of every variable the story can ever write: set() targets, choice(...)
 * assignments, plus the achievement flags. This walks all *.magium files with the
 * same line dispatch as ../magium-dev/src/parser.js @ 51f5aa9, takes that union,
 * and estimates the serialized size of a 100%-progressed save.
 *
 * Usage:
 *   node reference/tools/scan-save-footprint.js [dataDir]
 *   dataDir defaults to ../magium-dev/data/en relative to this repo root.
 *
 * Output: JSON summary on stdout. Pure read-only; no deps.
 *
 * Recorded result 2026-08-31 (magium-dev @ 51f5aa9):
 *   491 distinct vars written (135 v_ac_* achievement flags), avg name 16.6 chars.
 *   Est. serialized {name:"value"} for all 491: ~12 KB (short values) / ~15 KB (avg-8 values).
 *   1 var read but never written by the story: v_iap_checked.
 */
const fs = require("fs");
const path = require("path");

const HERE = __dirname;
const dataDir =
  process.argv[2] ||
  path.resolve(HERE, "..", "..", "..", "magium-dev", "data", "en");

// regexes copied verbatim from magium-dev/src/parser.js @ 51f5aa9
const RE_SET = /set\((?<varName>.*),(?<value>[+\-]?[0-9])\)( if (?<condition>.*))?/;
const RE_ACH = /achievement\("(?<text>.*)",(?<variable>.*)\)/;
const RE_CHOICE =
  /choice\("(?<text>.*)", (?<target>[\w\-\s]*), (?<setVariables>(\w* = [\w\-\s+]*(, )?)*)((, )?special:(?<special>.*?))?\)( if (?<condition>.*))?/;
const RE_IF = /#if\((?<condition>.*)\)/;
const RE_ATOM = /(?<varName>\w*) (?<condType><|>|>=|==|<=|!=) (?<value>[0-9]+)/;

function parseConditions(s) {
  if (!s) return undefined;
  s = s.replace("(", "").replace(")", "").split(" || ");
  return s.map((c) => c.split(" && "));
}

const files = fs
  .readdirSync(dataDir)
  .filter((f) => f.endsWith(".magium"))
  .sort();

const written = new Set(); // variable names ever assigned by set()/choice
const acFlags = new Set(); // of those, achievement flags (v_ac*)
const condVars = new Set(); // variable names ever read in a condition
const valueSamples = {}; // varName -> Set of literal values assigned

function noteWrite(name, value) {
  name = (name || "").trim();
  if (!name) return;
  written.add(name);
  if (name.startsWith("v_ac")) acFlags.add(name);
  (valueSamples[name] = valueSamples[name] || new Set()).add(String(value).trim());
}

function collectCondVars(rawCond) {
  const groups = parseConditions(rawCond);
  if (!groups) return;
  for (const g of groups)
    for (const atomRaw of g) {
      const atom = atomRaw.trim();
      if (atom === "True") continue;
      const mm = atom.match(RE_ATOM);
      if (mm) condVars.add(mm.groups.varName);
    }
}

for (const f of files) {
  const raw = fs.readFileSync(path.join(dataDir, f), "utf8");
  const lines = raw.split(/\r?\n/);
  let skip = false;
  lines.forEach((line) => {
    const trimmed = line.trim();
    if (line.startsWith("ID")) { skip = false; return; }
    if (line.startsWith("TEXT")) { skip = true; return; }
    if (skip) { skip = false; return; }

    let m = line.match(RE_SET);
    if (m && /^set\(/.test(trimmed)) {
      noteWrite(m.groups.varName, m.groups.value);
      if (m.groups.condition) collectCondVars(m.groups.condition);
      return;
    }
    if (RE_ACH.test(line) && /^achievement\(/.test(trimmed)) {
      // achievement() only DISPLAYS a flag; the flag itself is set by set()/choice.
      return;
    }
    m = line.match(RE_CHOICE);
    if (m && /^choice\(/.test(trimmed)) {
      const assigns = (m.groups.setVariables || "")
        .trim()
        .split(", ")
        .filter((s) => /^\w+ = /.test(s));
      for (const a of assigns) {
        const [n, v] = a.split(" = ");
        noteWrite(n, v);
      }
      if (m.groups.condition) collectCondVars(m.groups.condition);
      return;
    }
    m = line.match(RE_IF);
    if (m && /^#if\(/.test(trimmed)) {
      collectCondVars(m.groups.condition);
      return;
    }
  });
}

// vars read in conditions but never written by the story (engine/client-set, or implicit 0)
const readNotWritten = [...condVars].filter((v) => !written.has(v));

// crude serialized-size estimate for {"name":"value", ...} over every written var
function estimateBytes(names, avgValueLen) {
  let bytes = 2; // braces
  for (const n of names) bytes += 2 + n.length + 1 + 2 + avgValueLen + 1; // "n":"v",
  return bytes;
}

const allWritten = [...written];
const nameLenAvg =
  allWritten.reduce((a, n) => a + n.length, 0) / allWritten.length;

console.log(
  JSON.stringify(
    {
      dataDir,
      distinctVarsWritten: written.size,
      ofWhichAchievementFlags: acFlags.size,
      distinctVarsReadInConditions: condVars.size,
      varsReadButNeverWrittenByStory: readNotWritten,
      avgVarNameLength: Number(nameLenAvg.toFixed(1)),
      estSerializedBytes_allWritten_shortVals: estimateBytes(allWritten, 2),
      estSerializedBytes_allWritten_avg8: estimateBytes(allWritten, 8),
      multiValueVarsSample: Object.entries(valueSamples)
        .filter(([k, s]) => s.size > 2 && k !== "v_current_scene")
        .slice(0, 15)
        .map(([k, s]) => `${k} = {${[...s].slice(0, 8).join(",")}}`),
    },
    null,
    2
  )
);
