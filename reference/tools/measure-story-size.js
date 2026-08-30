// Measures the on-disk and in-memory size of the parsed Magium story.
// Run from anywhere:  node reference/tools/measure-story-size.js [path-to-magium-dev]
// Default magium-dev path: ../magium-dev relative to this repo root.
// Requires magium-dev to have had `npm install` run (needs its `glob` dependency).
//
// Recorded result 2026-08-31 (magium-dev @ 51f5aa9, Node v24.11.0):
//   54 files, 7.50 MB disk, 2159 scenes, 4880 paragraphs, 3734 choices, 594 set()
//   ~17.4 MB V8 heap for parsed objects, 8.16 MB JSON.stringify
// See ../magium-dev-notes.md and ../../docs/research/01-magium-analysis.md §11.

const path = require("node:path");
const fs = require("node:fs");

const repoRoot = path.resolve(__dirname, "..", "..");
const devDir = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.resolve(repoRoot, "..", "magium-dev");

const { parse } = require(path.join(devDir, "src", "parser.js"));
const { globSync } = require(path.join(devDir, "node_modules", "glob"));

(async () => {
  const files = globSync(path.join(devDir, "data", "en", "*.magium").replace(/\\/g, "/"));
  let totalDisk = 0;
  for (const f of files) totalDisk += fs.statSync(f).size;

  if (global.gc) global.gc();
  const before = process.memoryUsage().heapUsed;

  const story = {};
  for (const f of files) Object.assign(story, await parse(f));

  let scenes = 0, paragraphs = 0, choices = 0, setVars = 0;
  for (const id in story) {
    scenes++;
    paragraphs += (story[id].paragraphs || []).length;
    choices += (story[id].choices || []).length;
    setVars += (story[id].setVariables || []).length;
  }

  if (global.gc) global.gc();
  const after = process.memoryUsage().heapUsed;
  const json = JSON.stringify(story);

  console.log(`magium-dev: ${devDir}`);
  console.log(`files:              ${files.length}`);
  console.log(`disk:               ${(totalDisk / 1048576).toFixed(2)} MB`);
  console.log(`scenes:             ${scenes}`);
  console.log(`paragraphs:         ${paragraphs}`);
  console.log(`choices:            ${choices}`);
  console.log(`set() directives:   ${setVars}`);
  console.log(`parsed heap delta:  ${((after - before) / 1048576).toFixed(2)} MB  (V8; run with --expose-gc for accuracy)`);
  console.log(`JSON.stringify:     ${(json.length / 1048576).toFixed(2)} MB`);
})();
