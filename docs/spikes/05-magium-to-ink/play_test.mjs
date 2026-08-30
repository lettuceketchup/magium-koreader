import { Compiler } from "inkjs/full";
import fs from "fs";

const source = fs.readFileSync("ch1.ink", "utf8");
const compiler = new Compiler(source, {
  errorHandler: (msg, type) => {
    console.log(`[${type}] ${msg}`);
  }
});
const story = compiler.Compile();

function run(choicesToPick) {
  console.log("\n===== PLAYTHROUGH", JSON.stringify(choicesToPick), "=====");
  story.ResetState();
  let step = 0;
  while (true) {
    let text = "";
    while (story.canContinue) text += story.Continue();
    if (text.trim()) console.log("--", text.trim().slice(0, 200).replace(/\n+/g, " | "));
    if (story.currentChoices.length === 0) { console.log("[END]"); break; }
    if (step >= choicesToPick.length) {
      console.log("choices:", story.currentChoices.map((c,i)=>`${i}:${c.text}`));
      break;
    }
    const idx = choicesToPick[step++];
    console.log(">> picking:", story.currentChoices[idx].text);
    story.ChooseChoiceIndex(idx);
  }
  console.log("vars: v_ch1_show_yourself=", story.variablesState["v_ch1_show_yourself"],
    " v_ac_ch1_coward=", story.variablesState["v_ac_ch1_coward"]);
}

run([1, 1, 0]); // Excited -> Show myself -> Give him until count of ten to retreat
run([0, 0]);    // Excited -> Stay silent -> (see choices)
run([2, 2]);    // Afraid -> ""I see no reason to show myself to you."" (quotequote) -> (see choices)
