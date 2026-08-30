// magium_to_ink.js — spike 05 ("Spike C"): converts one Magium chapter
// (ch1.magium — 12 scenes) to Ink source, using magium-dev's OWN parser
// (../../../../magium-dev/src/parser.js, already proven correct — no reason to
// re-parse a third time after spike 02's Lua port) rather than re-deriving
// the grammar. This is a converter, not an engine: it emits Ink source text
// and lets Ink's own compiler + condition evaluator do the work, which is
// the actual thing OQ-006 asks about ("can conditions/stats be faithfully
// represented in Ink").
//
// Usage: node magium_to_ink.js <path-to-magium-dev/data/en/ch1.magium> <out.ink>

const path = require("path");
const fs = require("fs");

const devDir = path.resolve(__dirname, "..", "..", "..", "..", "magium-dev");
const { parse } = require(path.join(devDir, "src", "parser.js"));

function sanitizeKnot(sceneId) {
  return "K_" + sceneId.replace(/[^A-Za-z0-9]+/g, "_");
}

// Magium DNF: [[atom, atom], [atom]] = (atom && atom) || (atom) — Ink's
// expression language supports the same &&/|| operators and comparisons
// verbatim, so each atom needs no translation, only the grouping does.
function conditionsToInkExpr(conditions) {
  if (!conditions) return null;
  const orParts = conditions.map((andGroup) => {
    const atoms = andGroup.map((a) => (a === "True" ? "true" : a));
    return atoms.length > 1 ? `(${atoms.join(" and ")})` : atoms[0];
  });
  return orParts.length > 1 ? orParts.join(" or ") : orParts[0];
}

function textToInkLines(text) {
  // parser.js bakes line breaks in as literal "<br/>" markers, not real
  // newlines (see docs/spikes/02-engine-in-lua/magium_parser.lua's header
  // comment) — turning them back into real newlines is exactly what a
  // renderer does too, just emitted as Ink source lines instead of HTML.
  return text.split("<br/>").map((l) => l.trimEnd());
}

function collectVars(scenes) {
  const vars = new Set();
  const noteAtom = (atom) => {
    if (atom === "True") return;
    const m = atom.match(/^(\w+) /);
    if (m) vars.add(m[1]);
  };
  const noteConditions = (c) => { if (c) for (const g of c) for (const a of g) noteAtom(a); };
  for (const id in scenes) {
    const s = scenes[id];
    for (const sv of s.setVariables) {
      if (sv.name !== "v_current_scene") vars.add(sv.name);
      noteConditions(sv.conditions);
    }
    for (const p of s.paragraphs) noteConditions(p.conditions);
    for (const c of s.choices) {
      for (const k in c.setVariables) if (k !== "v_current_scene") vars.add(k);
      noteConditions(c.conditions);
    }
  }
  return [...vars].sort();
}

function convertScene(id, scene, knownIds) {
  const lines = [];
  lines.push(`=== ${sanitizeKnot(id)} ===`);

  for (const sv of scene.setVariables) {
    const assign = `~ ${sv.name} = ${sv.value}`;
    const cond = conditionsToInkExpr(sv.conditions);
    if (cond) lines.push(`{${cond}:`, `    ${assign}`, `}`);
    else lines.push(assign);
  }

  for (const p of scene.paragraphs) {
    const body = textToInkLines(p.text);
    const cond = conditionsToInkExpr(p.conditions);
    if (cond) {
      lines.push(`{${cond}:`);
      for (const l of body) lines.push(`    ${l}`);
      lines.push(`}`);
    } else {
      for (const l of body) lines.push(l);
    }
  }

  for (const ach of scene.achievements) {
    lines.push(`# ACHIEVEMENT: "${ach.text}" (${ach.variable}) — Ink has no built-in achievement UI; a host script reading this tag would still need to implement display + persistence itself, same as any other target.`);
  }

  for (const c of scene.choices) {
    const cond = conditionsToInkExpr(c.conditions);
    const prefix = cond ? `* {${cond}} ` : "* ";
    lines.push(`${prefix}[${c.text}]`);
    const assigns = Object.entries(c.setVariables).filter(([k]) => k !== "v_current_scene");
    for (const [k, v] of assigns) lines.push(`    ~ ${k} = ${v}`);
    if (c.special) {
      lines.push(`    # SPECIAL:${c.special} — a host-level action (save/restart/stats), not story content; Ink has no equivalent primitive, same gap a native engine would still have to bridge with a custom function binding.`);
    }
    if (!c.target) {
      lines.push(`    -> Unsupported_no_target`);
    } else {
      const knot = sanitizeKnot(c.target);
      lines.push(`    -> ${knot}`);
      if (!knownIds.has(c.target)) knownIds.add("__stub__:" + c.target);
    }
  }

  if (scene.choices.length === 0) lines.push("-> END");
  lines.push("");
  return lines.join("\n");
}

function convertFile(inPath, outPath) {
  return parse(inPath).then((scenes) => {
    const ids = Object.keys(scenes);
    const knownIds = new Set(ids);
    const vars = collectVars(scenes);

    const out = [];
    out.push("// Auto-converted from " + path.basename(inPath) + " by magium_to_ink.js (spike 05).");
    out.push("// Fidelity gaps are marked inline with '# SPECIAL:' / '# ACHIEVEMENT:' tags and in FINDING.md.");
    out.push("");
    for (const v of vars) out.push(`VAR ${v} = 0`);
    out.push("");
    out.push(`-> ${sanitizeKnot(ids[0])}`);
    out.push("");

    for (const id of ids) out.push(convertScene(id, scenes[id], knownIds));

    // Stub knots for any divert target this one chapter doesn't define
    // (cross-chapter targets like Ch2-Intro, and the special:saves choice's
    // empty target) — a real multi-chapter conversion would need every
    // chapter's file loaded, out of scope for a one-chapter spike.
    const stubs = [...knownIds].filter((x) => x.startsWith("__stub__:")).map((x) => x.slice(9));
    out.push(`=== Unsupported_no_target ===`);
    out.push(`This choice has no target scene in the original data (a host-level action like "load game" — see the SPECIAL tag above it).`);
    out.push(`-> END`);
    out.push("");
    for (const stub of stubs) {
      out.push(`=== ${sanitizeKnot(stub)} ===`);
      out.push(`(stub: "${stub}" is outside this one-chapter conversion)`);
      out.push(`-> END`);
      out.push("");
    }

    fs.writeFileSync(outPath, out.join("\n"));
    console.log(`wrote ${outPath}: ${ids.length} scenes, ${vars.length} vars, ${stubs.length} cross-chapter stubs`);
  });
}

const [, , inArg, outArg] = process.argv;
if (!inArg || !outArg) {
  console.error("usage: node magium_to_ink.js <ch1.magium path> <out.ink>");
  process.exit(2);
}
convertFile(inArg, outArg).catch((e) => { console.error(e); process.exit(1); });
