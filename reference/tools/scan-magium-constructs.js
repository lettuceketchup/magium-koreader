#!/usr/bin/env node
/*
 * scan-magium-constructs.js — construct corpus scan for docs/research/02-magium-format-spec.md (task 1.11)
 *
 * Walks every *.magium file in a magium-dev data directory, re-implementing the
 * exact line dispatch of ../magium-dev/src/parser.js @ 51f5aa9, and tallies every
 * distinct syntactic form actually used. Also flags lines the reference parser
 * regexes would mishandle.
 *
 * Usage:
 *   node reference/tools/scan-magium-constructs.js [dataDir]
 *   dataDir defaults to ../magium-dev/data/en relative to this repo root.
 *
 * Output: JSON summary on stdout. Pure read-only; no deps.
 *
 * Regenerate and eyeball the diff after any magium-dev bump.
 */
const fs = require("fs");
const path = require("path");

const HERE = __dirname;
const dataDir =
  process.argv[2] ||
  path.resolve(HERE, "..", "..", "..", "magium-dev", "data", "en");

// --- regexes copied verbatim from magium-dev/src/parser.js @ 51f5aa9 ---
const RE_SET = /set\((?<varName>.*),(?<value>[+\-]?[0-9])\)( if (?<condition>.*))?/;
const RE_ACH = /achievement\("(?<text>.*)",(?<variable>.*)\)/;
const RE_CHOICE =
  /choice\("(?<text>.*)", (?<target>[\w\-\s]*), (?<setVariables>(\w* = [\w\-\s+]*(, )?)*)((, )?special:(?<special>.*?))?\)( if (?<condition>.*))?/;
const RE_IF = /#if\((?<condition>.*)\)/;
// atom regex from utils.js:apply_condition / parseStatCheck
const RE_ATOM = /(?<varName>\w*) (?<condType><|>|>=|==|<=|!=) (?<value>[0-9]+)/;

// --- parseConditions from parser.js: strips the FIRST "(" and FIRST ")" only ---
function parseConditions(s) {
  if (!s) return undefined;
  s = s.replace("(", "").replace(")", "").split(" || ");
  return s.map((c) => c.split(" && "));
}

const files = fs
  .readdirSync(dataDir)
  .filter((f) => f.endsWith(".magium"))
  .sort();

const out = {
  dataDir,
  files: files.length,
  scenes: 0,
  crlfFiles: 0,
  duplicateSceneIds: [],
  constructs: {
    "set()": 0,
    "set() if": 0,
    "achievement()": 0,
    "choice()": 0,
    "choice() if": 0,
    "#if(){}": 0,
    "}": 0,
    "prose lines": 0,
  },
  setValues: {},
  setRelativeValues: 0, // +N / -N
  choiceEmptyTarget: 0,
  choiceTargetWithSpace: 0,
  choiceNoAssignments: 0,
  choiceSingleAssignment: 0,
  choiceMultiAssignment: 0,
  choiceDoubleQuotedText: 0, // choice(""...."")
  choiceSpecialValues: {},
  ifNestedMax: 0,
  conditionOperators: {},
  conditionTrueLiteral: 0,
  conditionUnknownAtoms: [], // atoms the atom regex can't parse (e.g. "False")
  conditionMultiParen: [], // >1 "(" or ">1" ")" — parseConditions would mangle
  conditionMaxOrClauses: 0,
  conditionMaxAndTerms: 0,
  distinctConditionAtoms: 0,
  distinctConditionVars: 0,
  parserFailures: {
    // lines that hit the else-branch (treated as prose) but look like a construct
    "set-like prose": [],
    "choice-like prose": [],
    // construct lines the corresponding regex could not parse
    "unparsed set()": [],
    "unparsed choice()": [],
  },
};

const seenIds = new Set();
const atoms = new Set();
const condVars = new Set();

function scanCondition(rawCond, where) {
  if (!rawCond) return;
  const opens = (rawCond.match(/\(/g) || []).length;
  const closes = (rawCond.match(/\)/g) || []).length;
  if (opens > 1 || closes > 1) out.conditionMultiParen.push(`${where}  ${rawCond}`);

  const groups = parseConditions(rawCond);
  if (!groups) return;
  out.conditionMaxOrClauses = Math.max(out.conditionMaxOrClauses, groups.length);
  for (const g of groups) {
    out.conditionMaxAndTerms = Math.max(out.conditionMaxAndTerms, g.length);
    for (const atomRaw of g) {
      const atom = atomRaw.trim();
      atoms.add(atom);
      if (atom === "True") {
        out.conditionTrueLiteral++;
        continue;
      }
      const m = atom.match(RE_ATOM);
      if (!m) {
        out.conditionUnknownAtoms.push(`${where}  «${atom}»`);
        continue;
      }
      condVars.add(m.groups.varName);
      out.conditionOperators[m.groups.condType] =
        (out.conditionOperators[m.groups.condType] || 0) + 1;
    }
  }
}

for (const f of files) {
  const raw = fs.readFileSync(path.join(dataDir, f), "utf8");
  if (raw.includes("\r\n")) out.crlfFiles++;
  const lines = raw.split(/\r?\n/);

  let skip = false;
  let ifDepth = 0;

  lines.forEach((line, idx) => {
    const where = `${f}:${idx + 1}`;
    const trimmed = line.trim();

    if (line.startsWith("ID")) {
      out.scenes++;
      const id = line.split(": ")[1];
      if (seenIds.has(id)) out.duplicateSceneIds.push(`${where}  ${id}`);
      seenIds.add(id);
      skip = false;
      ifDepth = 0;
      return;
    }
    if (line.startsWith("TEXT")) {
      skip = true;
      return;
    }
    if (skip) {
      skip = false;
      return;
    }

    // set()
    let m = line.match(RE_SET);
    if (m && /^set\(/.test(trimmed)) {
      out.constructs["set()"]++;
      if (m.groups.condition) {
        out.constructs["set() if"]++;
        scanCondition(m.groups.condition, where);
      }
      const v = m.groups.value;
      out.setValues[v] = (out.setValues[v] || 0) + 1;
      if (v.startsWith("+") || v.startsWith("-")) out.setRelativeValues++;
      return;
    }
    if (!m && /^set\(/.test(trimmed))
      out.parserFailures["unparsed set()"].push(`${where}  ${trimmed}`);

    // achievement()
    if (RE_ACH.test(line) && /^achievement\(/.test(trimmed)) {
      out.constructs["achievement()"]++;
      return;
    }

    // choice()
    m = line.match(RE_CHOICE);
    if (m && /^choice\(/.test(trimmed)) {
      out.constructs["choice()"]++;
      if (/^choice\(""/.test(trimmed)) out.choiceDoubleQuotedText++;
      const tgt = (m.groups.target || "").trim();
      if (tgt === "") out.choiceEmptyTarget++;
      else if (/\s/.test(tgt)) out.choiceTargetWithSpace++;
      const assigns = (m.groups.setVariables || "")
        .trim()
        .split(", ")
        .filter((s) => /^\w+ = /.test(s));
      if (assigns.length === 0) out.choiceNoAssignments++;
      else if (assigns.length === 1) out.choiceSingleAssignment++;
      else out.choiceMultiAssignment++;
      if (m.groups.special) {
        const sp = m.groups.special;
        out.choiceSpecialValues[sp] = (out.choiceSpecialValues[sp] || 0) + 1;
      }
      if (m.groups.condition) {
        out.constructs["choice() if"]++;
        scanCondition(m.groups.condition, where);
      }
      return;
    }
    if (!m && /^choice\(/.test(trimmed))
      out.parserFailures["unparsed choice()"].push(`${where}  ${trimmed}`);

    // #if
    m = line.match(RE_IF);
    if (m && /^#if\(/.test(trimmed)) {
      out.constructs["#if(){}"]++;
      ifDepth++;
      out.ifNestedMax = Math.max(out.ifNestedMax, ifDepth);
      scanCondition(m.groups.condition, where);
      return;
    }

    if (line.startsWith("}")) {
      out.constructs["}"]++;
      if (ifDepth > 0) ifDepth--;
      return;
    }

    // else-branch: this becomes prose (line + "<br/>")
    out.constructs["prose lines"]++;
    if (trimmed !== "") {
      if (/set\(.*,[+\-]?[0-9]\)/.test(line))
        out.parserFailures["set-like prose"].push(`${where}  ${trimmed.slice(0, 120)}`);
      if (/choice\(".*", [\w\-\s]*, /.test(line))
        out.parserFailures["choice-like prose"].push(`${where}  ${trimmed.slice(0, 120)}`);
    }
  });
}

out.distinctConditionAtoms = atoms.size;
out.distinctConditionVars = condVars.size;

console.log(JSON.stringify(out, null, 2));
