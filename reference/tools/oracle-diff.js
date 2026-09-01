// Differential-oracle harness for the Magium port.
//
// magium-dev (../magium-dev @ 51f5aa9) is the known-good implementation. This
// script drives it as a black box over HTTP, normalizes each rendered scene to
// a canonical JSON shape, and diffs two such captures. When a Lua port exists
// (spike B) it emits the same shape and we diff port-vs-oracle here.
//
// The oracle server must be running:
//     cd ../magium-dev && node main_node.js 3000
// See ../magium-dev-notes.md for the request contract.
//
// Usage (run from anywhere):
//     node reference/tools/oracle-diff.js scene  <SceneId> [k=v ...]      [--base URL]
//     node reference/tools/oracle-diff.js capture [--cases FILE] [--out DIR] [--base URL]
//     node reference/tools/oracle-diff.js diff    <expected> <actual>
//
//   scene    fetch one scene, print its canonical JSON to stdout.
//   capture  run every case in --cases (default: oracle-cases.json next to this
//            file), write <out>/<name>.json each (default out: oracle-capture/)
//            plus <out>/_index.json.
//   diff     compare two canonical files, or two directories of them, pairwise
//            by filename. Exit 1 if anything differs.
//
// Canonical scene shape (keys always in this order):
//   { sceneId, header, checkpoint, statChecks:[{success,text}],
//     setVariables:[{name,value}], paragraphs:[string],
//     choices:[{text,target,special,setVariables:{}}], achievements:[{variable,text}] }
//
// Values are compared as-is; variable values are strings on both sides (matches
// how magium-dev's client and apply_condition treat them).

const fs = require("node:fs");
const path = require("node:path");

const DEFAULT_BASE = process.env.MAGIUM_ORACLE || "http://localhost:3000";
const HERE = __dirname;

// ---------------------------------------------------------------- html helpers

const ENTITIES = {
  "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"',
  "&#34;": '"', "&#39;": "'", "&apos;": "'", "&nbsp;": " ",
};

function decodeEntities(s) {
  return String(s)
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&[a-z]+;/gi, (m) => (m in ENTITIES ? ENTITIES[m] : m));
}

// Collapse runs of whitespace, normalize <br> variants, trim.
function normalizeText(s) {
  return decodeEntities(s)
    .replace(/<br\s*\/?>/gi, "<br/>")
    .replace(/[ \t\f\v ]+/g, " ")
    .replace(/\s*\n\s*/g, " ")
    .trim();
}

// ------------------------------------------------------------- scene normalizer

// Turn one rendered scene fragment (HX-Request response body) into canonical JSON.
// Structure mirrors magium-dev/templates/main.ejs @ 51f5aa9.
function normalizeSceneHtml(html, sceneId, uiStrings) {
  const checkpointText = normalizeText(uiStrings.mainCheckpointReachedText || "");

  // Everything up to the first choice / achievement / footer is the "head"
  // (setVariables scripts, checkpoint div, stat-check divs) + prose; the rest
  // is the "tail" (choice buttons, achievement modals, out-of-band header).
  //
  // The achievement block is `<script>storeVariable(V,"2")</script>` then its
  // `<div ... class="achievement-modal">` (the class attr may wrap to the next
  // line). That leading script belongs with the modal in the tail — in a
  // scene with choices it lands there naturally, but when the modal itself is
  // the cut point the script would be stranded at the end of the head, where
  // it gets miscounted as a setVariable and starves the achievements match.
  // So anchor the achievement cut at the script, not the modal div.
  const responseCut = html.indexOf('<div class="response">');
  const displayCut = html.indexOf('<div style="display:none">');
  let achCut = -1;
  const modal = html.match(/<div\s+class="achievement-modal"/);
  if (modal) {
    achCut = modal.index;
    const scripts = html
      .slice(0, modal.index)
      .match(/(?:<script>\s*storeVariable\("[^"]*","2"\)\s*<\/script>\s*)+$/);
    if (scripts) achCut = scripts.index;
  }
  const candidates = [responseCut, achCut, displayCut].filter((x) => x !== -1);
  const cut = candidates.length ? Math.min(...candidates) : -1;
  const headAndProse = cut === -1 ? html : html.slice(0, cut);
  const tail = cut === -1 ? "" : html.slice(cut);

  // --- setVariables: storeVariable() scripts in the head region only.
  const setVariables = [];
  for (const m of headAndProse.matchAll(
    /<script>\s*storeVariable\("([^"]*)","([^"]*)"\)\s*<\/script>/g
  )) {
    setVariables.push({ name: m[1], value: m[2] });
  }

  // --- checkpoint + stat checks: <div class='stat_success'> / 'stat_fail'>.
  let checkpoint = false;
  const statChecks = [];
  for (const m of headAndProse.matchAll(
    /<div class='(stat_success|stat_fail)'>\s*([\s\S]*?)\s*<\/div>/g
  )) {
    const text = normalizeText(m[2]);
    if (m[1] === "stat_success" && text === checkpointText) {
      checkpoint = true;
    } else {
      statChecks.push({ success: m[1] === "stat_success", text });
    }
  }

  // --- paragraphs: prose lines left after stripping head markup.
  const proseRegion = headAndProse
    .replace(/<script>[\s\S]*?<\/script>/g, "")
    .replace(/<div class='(?:stat_success|stat_fail)'>[\s\S]*?<\/div>/g, "");
  const paragraphs = [];
  for (const rawLine of proseRegion.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line) continue;
    if (line.startsWith("<script") || line.startsWith("<div ")) continue;
    // main.ejs emits an orphaned closing </div> right before the header's
    // hidden div whenever a scene has zero surviving choices (no matching
    // open tag in this fragment — verified against a live zero-choice
    // response). A bare closing tag is never real prose; drop it so it
    // doesn't get counted as a fake extra paragraph.
    if (/^<\/[a-zA-Z][\w-]*>$/.test(line)) continue;
    paragraphs.push(normalizeText(line));
  }

  // --- choices: setResponseVariables({...}) payload per button.
  const choices = [];
  for (const m of tail.matchAll(/onClick="([^"]*)"/g)) {
    const call = decodeEntities(m[1]);
    const open = call.indexOf("setResponseVariables(");
    if (open === -1) continue;
    const json = call.slice(open + "setResponseVariables(".length, call.lastIndexOf(")"));
    let choice;
    try {
      choice = JSON.parse(json);
    } catch (e) {
      throw new Error(`bad choice JSON in ${sceneId}: ${json}\n${e.message}`);
    }
    choices.push({
      text: normalizeText(choice.text),
      target: choice.target ?? null,
      special: choice.special ?? null,
      setVariables: choice.setVariables || {},
    });
  }

  // --- achievements: modal caption + the v_ac_* flag it bumps to "2".
  const achievements = [];
  for (const m of tail.matchAll(
    /<script>\s*storeVariable\("([^"]*)","2"\)\s*<\/script>\s*<div\s+class="achievement-modal"[\s\S]*?achievement-modal-caption">\s*([\s\S]*?)\s*<\/div>/g
  )) {
    achievements.push({ variable: m[1], text: normalizeText(m[2]) });
  }

  // --- header: the out-of-band <h2 id="header">.
  const hm = html.match(/<h2[^>]*id="header"[^>]*>\s*([\s\S]*?)\s*<\/h2>/);
  const header = hm ? normalizeText(hm[1]) : null;

  return { sceneId, header, checkpoint, statChecks, setVariables, paragraphs, choices, achievements };
}


// --------------------------------------------------------------- oracle client

async function fetchScene(base, sceneId, vars) {
  const body = JSON.stringify({ ...vars, v_current_scene: sceneId });
  const res = await fetch(base.replace(/\/$/, "") + "/", {
    method: "POST",
    headers: { "Content-Type": "application/json", "HX-Request": "true" },
    body,
  });
  if (!res.ok) throw new Error(`oracle ${res.status} for ${sceneId}`);
  return res.text();
}

// magium-dev's ui.json holds the templated UI strings we match against.
function loadUiStrings(base) {
  // Try the sibling checkout first; fall back to a minimal built-in set.
  const guess = path.resolve(HERE, "..", "..", "..", "magium-dev", "data", "en", "ui.json");
  try {
    return JSON.parse(fs.readFileSync(guess, "utf8"));
  } catch {
    return { mainCheckpointReachedText: "[ Checkpoint reached: Game saved. ]" };
  }
}

// ------------------------------------------------------------------ canonical io

const KEY_ORDER = {
  _scene: ["sceneId", "header", "checkpoint", "statChecks", "setVariables", "paragraphs", "choices", "achievements"],
  _statCheck: ["success", "text"],
  _setVar: ["name", "value"],
  _choice: ["text", "target", "special", "setVariables"],
  _achievement: ["variable", "text"],
};

function orderKeys(obj, order) {
  const out = {};
  for (const k of order) if (k in obj) out[k] = obj[k];
  for (const k of Object.keys(obj)) if (!(k in out)) out[k] = obj[k];
  return out;
}

function canonicalScene(s) {
  return orderKeys(
    {
      ...s,
      statChecks: s.statChecks.map((x) => orderKeys(x, KEY_ORDER._statCheck)),
      setVariables: s.setVariables.map((x) => orderKeys(x, KEY_ORDER._setVar)),
      choices: s.choices.map((c) => ({
        ...orderKeys(c, KEY_ORDER._choice),
        setVariables: sortObject(c.setVariables),
      })),
      achievements: s.achievements.map((x) => orderKeys(x, KEY_ORDER._achievement)),
    },
    KEY_ORDER._scene
  );
}

function sortObject(o) {
  const out = {};
  for (const k of Object.keys(o).sort()) out[k] = o[k];
  return out;
}

function writeJson(file, obj) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(obj, null, 2) + "\n");
}

// ------------------------------------------------------------------- diff

// Deep structural diff. Returns an array of human-readable difference lines.
function diffCanonical(expected, actual, at = "") {
  const diffs = [];
  const t = (v) => (Array.isArray(v) ? "array" : v === null ? "null" : typeof v);
  if (t(expected) !== t(actual)) {
    diffs.push(`${at || "(root)"}: type ${t(expected)} -> ${t(actual)}`);
    return diffs;
  }
  if (Array.isArray(expected)) {
    if (expected.length !== actual.length) {
      diffs.push(`${at}: length ${expected.length} -> ${actual.length}`);
    }
    for (let i = 0; i < Math.max(expected.length, actual.length); i++) {
      diffs.push(...diffCanonical(expected[i], actual[i], `${at}[${i}]`));
    }
    return diffs;
  }
  if (expected && typeof expected === "object") {
    const keys = new Set([...Object.keys(expected), ...Object.keys(actual)]);
    for (const k of keys) {
      diffs.push(...diffCanonical(expected[k], actual[k], at ? `${at}.${k}` : k));
    }
    return diffs;
  }
  if (expected !== actual) {
    diffs.push(`${at}: ${JSON.stringify(expected)} -> ${JSON.stringify(actual)}`);
  }
  return diffs;
}

// ------------------------------------------------------------------- cli

function parseArgs(argv) {
  const opts = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--")) opts[argv[i].slice(2)] = argv[++i];
    else opts._.push(argv[i]);
  }
  return opts;
}

async function cmdScene(opts) {
  const base = opts.base || DEFAULT_BASE;
  const [sceneId, ...kv] = opts._;
  if (!sceneId) die("scene: need a scene id");
  const vars = {};
  for (const pair of kv) {
    const eq = pair.indexOf("=");
    vars[pair.slice(0, eq)] = pair.slice(eq + 1);
  }
  const html = await fetchScene(base, sceneId, vars);
  const scene = canonicalScene(normalizeSceneHtml(html, sceneId, loadUiStrings(base)));
  process.stdout.write(JSON.stringify(scene, null, 2) + "\n");
}

async function cmdCapture(opts) {
  const base = opts.base || DEFAULT_BASE;
  const casesFile = opts.cases || path.join(HERE, "oracle-cases.json");
  const outDir = opts.out || path.join(HERE, "oracle-capture");
  const cases = JSON.parse(fs.readFileSync(casesFile, "utf8"));
  const ui = loadUiStrings(base);
  const index = [];
  for (const c of cases) {
    const name = c.name || c.sceneId;
    const html = await fetchScene(base, c.sceneId, c.vars || {});
    const scene = canonicalScene(normalizeSceneHtml(html, c.sceneId, ui));
    writeJson(path.join(outDir, `${name}.json`), scene);
    index.push({ name, sceneId: c.sceneId, vars: c.vars || {} });
    console.log(`captured ${name}  (${scene.paragraphs.length}p ${scene.choices.length}c ${scene.statChecks.length}s)`);
  }
  writeJson(path.join(outDir, "_index.json"), index);
  console.log(`\n${index.length} scenes -> ${outDir}`);
}

function cmdDiff(opts) {
  const [expected, actual] = opts._;
  if (!expected || !actual) die("diff: need <expected> <actual>");
  const pairs = [];
  if (fs.statSync(expected).isDirectory()) {
    for (const f of fs.readdirSync(expected)) {
      if (f.endsWith(".json") && !f.startsWith("_")) {
        pairs.push([path.join(expected, f), path.join(actual, f), f]);
      }
    }
  } else {
    pairs.push([expected, actual, path.basename(expected)]);
  }
  let bad = 0;
  for (const [ef, af, label] of pairs) {
    let e, a;
    try {
      e = JSON.parse(fs.readFileSync(ef, "utf8"));
      a = JSON.parse(fs.readFileSync(af, "utf8"));
    } catch (err) {
      console.log(`MISSING ${label}: ${err.message}`);
      bad++;
      continue;
    }
    const d = diffCanonical(e, a);
    if (d.length) {
      bad++;
      console.log(`DIFF ${label}`);
      for (const line of d) console.log(`  ${line}`);
    } else {
      console.log(`ok   ${label}`);
    }
  }
  console.log(`\n${pairs.length - bad}/${pairs.length} match`);
  if (bad) process.exit(1);
}

function die(msg) {
  console.error(msg);
  process.exit(2);
}

(async () => {
  const [cmd, ...rest] = process.argv.slice(2);
  const opts = parseArgs(rest);
  if (cmd === "scene") await cmdScene(opts);
  else if (cmd === "capture") await cmdCapture(opts);
  else if (cmd === "diff") cmdDiff(opts);
  else {
    console.error("commands: scene <id> [k=v...] | capture | diff <a> <b>");
    process.exit(2);
  }
})().catch((e) => {
  console.error(e.stack || String(e));
  process.exit(1);
});
