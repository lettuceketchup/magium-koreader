// Enumerate every ID: in ch1.magium and emit oracle cases: each scene under a
// small matrix of the variables ch1 actually branches on. Output shape matches
// reference/tools/oracle-cases.json.
const fs = require("node:fs");
const path = require("node:path");

const CH1 = path.resolve(__dirname, "..", "..", "magium-dev", "data", "en", "ch1.magium");
const ids = fs.readFileSync(CH1, "utf8")
  .split(/\r?\n/).filter(l => l.startsWith("ID: ")).map(l => l.slice(4));

// ch1 branch variables (from reading ch1.magium — keep this list in sync if the
// upstream file changes). ch1 branches on v_ch1_intro_feeling (1/2/3) and
// v_ch1_show_yourself (1/2/3 — #if == 1/2/3 and != 1/2), and displays three
// achievements (v_ac_ch1_coward / v_ac_ch1_die / v_ac_ch1_honesty).
const MATRIX = [
  {},                                        // all unset (0) — covers the != branches
  { v_ch1_intro_feeling: "1" },
  { v_ch1_intro_feeling: "2" },
  { v_ch1_intro_feeling: "3" },
  { v_ch1_show_yourself: "1" },               // #if(v_ch1_show_yourself == 1) ×5
  { v_ch1_show_yourself: "2", v_ac_ch1_coward: "1" },
  { v_ch1_show_yourself: "3" },
  { v_ac_ch1_coward: "1", v_ac_ch1_die: "1", v_ac_ch1_honesty: "1" },  // all achievement displays
];

const cases = [];
for (const id of ids) {
  MATRIX.forEach((vars, i) => {
    cases.push({
      name: `ch1-${id.replace(/[^A-Za-z0-9]+/g, "_")}-m${i}`,
      sceneId: id,
      vars,
    });
  });
}
fs.writeFileSync(
  path.resolve(__dirname, "..", "reference", "tools", "oracle-cases-ch1.json"),
  JSON.stringify(cases, null, 2) + "\n"
);
console.log(`${cases.length} cases for ${ids.length} ch1 scenes`);
