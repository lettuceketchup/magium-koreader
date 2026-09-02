--[[--
magium_spike.koplugin — spike 04 ("Spike A"): hard-codes ONE real Magium
scene (Ch1-Intro1, prose + 3 choices) plus its follow-on scene
(Ch1-Intro2, 3 conditional prose branches gated on the choice made), wires
the choices to swap between them, and renders via TextViewer — the widget
Phase 2 identified as the closest off-the-shelf fit for "prose + a short
choice-button row" (../../research/03-koreader-platform.md §3, F-14/F-15;
TextViewer accepts a `buttons_table` in the exact
{{text=,callback=},...},{...}} shape as ButtonDialog — grounded against
../../../../koreader/frontend/apps/reader/modules/readerbookmark.lua:1267-1296's
usage, not guessed).

Modeled on ../../../../koreader/plugins/hello.koplugin/main.lua (the
project's own minimal-plugin skeleton) for the WidgetContainer/Dispatcher/
menu-registration boilerplate.

Text is the REAL prose from ../../../../magium-dev/data/en/ch1.magium
(Ch1-Intro1, Ch1-Intro2), not placeholder text — the point of this spike is
whether paragraph-length real prose fits/reads well in this widget, so
shortening it would defeat the purpose.

RUN, functionally confirmed. See FINDING.md — a working `./kodev build` +
`./kodev run --simulate=kindle-paperwhite` was obtained in a later pass of
this same session (the earlier network-egress block only affected one
GitHub download endpoint and turned out to be fixable). Both hard-coded
scenes render correctly under real KOReader v2026.07.1 with zero errors,
screenshotted. Widget fit (OQ-002) is confirmed; e-ink refresh feel
(OQ-007) is unaffected by any of this — unanswerable from a non-e-ink
display regardless — and stays open, owner-only.
--]]--

local Dispatcher = require("dispatcher")  -- luacheck:ignore
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

-- ---------------------------------------------------------------- content
-- Verbatim from ../../../../magium-dev/data/en/ch1.magium (parser.js turns
-- each source line into "<line><br/>" — here that's just real newlines,
-- since this is hand-transcribed for the spike rather than run through the
-- parser; the parser itself is what spikes 02/05 exercise).

local CH1_INTRO1_TEXT = table.concat({
  "They say there is a very fine line between bravery and stupidity. As I stand here, in the middle of this forest, gazing at all of the explosions far in the distance, I realize I may well have crossed that line, to a point of no return.",
  "My name is Barry. I am twenty-eight years old, and I could quite accurately be described as your everyday ordinary guy. I have no talents, no particular skills and no academic background. The only thing that defines me is my lifelong obsession to become a mage. It is what I've wished for ever since I was five years old. It has been my driving passion throughout my life, as I've constantly amassed knowledge about mages and travelled the world in the hopes of finding a way to make my dream come true.",
  "After endless years of searching through dusty tomes and weathered parchments I have finally found a way to do it.",
  "The catch? I need to first win a tournament against the most powerful mages in the world. Sounds crazy? That's probably because it is. But it is far too late to go back now. The only way that's left for me is forward.",
  "As I stand here, knowing that it's no longer possible to return to my normal life, I can't help but feel quite...",
}, "\n\n")

local CH1_INTRO2_BRANCH = {
  [1] = "...excited about this whole thing. Maybe I really am completely out of my mind. I would have expected to feel at least a little bit scared about all of this. But instead of that, I get this constant tingling sensation that won't go away. The feeling that I am closer to my dream than ever before in my life. All of the terrible dangers that await me seem distant to me, and all I can really think about now is that at the end of the tournament, when I win this, I will finally become a mage.",
  [2] = "...calm about this whole thing. It must be because I've been getting mentally prepared for this for so long. Or maybe I'm just stronger than I thought myself to be. But even in the face of the mortal danger that awaits me, even against these impossible odds, I feel confident. I know I can do this. I am going to win this tournament and become a mage. I cannot allow myself to fail.",
  [3] = "...afraid. Deep down, I always knew this would happen. I've been spending the past few weeks getting mentally prepared and making plans. Telling myself I was ready for whatever this tournament is going to throw at me. But once I got here, once I knew there was no way for me to go back, all of my confidence turned to uncertainty, and all of my courage turned to fear. I am going up against the strongest mages in the world. No amount of planning could ever really make me prepared for this. But it's too late to change my mind now. I've had enough time to back out of this before coming here. I am going to win this tournament against all odds. I'm going to do it. I just have to...",
}

local CH1_INTRO2_TAIL = "There's an explosion maybe a few hundred feet from my location. The fights have already begun. And one of them is much closer to me than I would have hoped. There's no way I can get in a fight with any of the mages at this point. I need to avoid combat for as long as possible if I am to survive until the end."

-- ------------------------------------------------------------- plugin glue

local MagiumSpike = WidgetContainer:extend{
  name = "magium_spike",
  is_doc_only = false,
}

function MagiumSpike:onDispatcherRegisterActions()
  Dispatcher:registerAction("magium_spike_open", {
    category = "none", event = "MagiumSpikeOpen", title = _("Magium spike"), general = true,
  })
end

function MagiumSpike:init()
  self:onDispatcherRegisterActions()
  self.ui.menu:registerToMainMenu(self)
  self.v_ch1_intro_feeling = nil -- the one variable this spike's condition logic depends on
end

function MagiumSpike:addToMainMenu(menu_items)
  menu_items.magium_spike = {
    text = _("Magium spike (Ch1-Intro1/2)"),
    sorting_hint = "more_tools",
    callback = function() self:showIntro1() end,
  }
end

function MagiumSpike:onMagiumSpikeOpen()
  self:showIntro1()
end

-- Ch1-Intro1: prose + 3 choices (Excited/Calm/Afraid), each a `set()` of
-- v_ch1_intro_feeling + a divert to Ch1-Intro2 — the exact shape of
-- renderers.js:renderScene()'s choice.setVariables + navigation-by-variable
-- (docs/research/01-magium-analysis.md §2), just hand-wired instead of
-- driven by the parsed scene table spike 02 builds.
function MagiumSpike:showIntro1()
  local widget
  widget = TextViewer:new{
    title = _("Book 1 - Chapter 1"),
    text = CH1_INTRO1_TEXT,
    buttons_table = {
      {
        {
          text = _("Excited"),
          callback = function()
            UIManager:close(widget)
            self.v_ch1_intro_feeling = 1
            self:showIntro2()
          end,
        },
      },
      {
        {
          text = _("Calm"),
          callback = function()
            UIManager:close(widget)
            self.v_ch1_intro_feeling = 2
            self:showIntro2()
          end,
        },
      },
      {
        {
          text = _("Afraid"),
          callback = function()
            UIManager:close(widget)
            self.v_ch1_intro_feeling = 3
            self:showIntro2()
          end,
        },
      },
    },
  }
  UIManager:show(widget)
end

-- Ch1-Intro2: the #if(v_ch1_intro_feeling == N) conditional-paragraph
-- selection (docs/research/01-magium-analysis.md §3-4) done in plain Lua
-- `if`/`elseif` — this is the one piece of "engine logic" this spike
-- touches, and it's the same apply_condition semantics spike 02 already
-- validated against the oracle, just inlined for one hardcoded variable
-- instead of driven by a parsed condition list.
function MagiumSpike:showIntro2()
  local branch = CH1_INTRO2_BRANCH[self.v_ch1_intro_feeling] or ""
  local text = branch .. "\n\n" .. CH1_INTRO2_TAIL
  local widget
  widget = TextViewer:new{
    title = _("Book 1 - Chapter 1"),
    text = text,
    buttons_table = {
      {
        {
          text = _("Back to Intro1 (spike loop)"),
          callback = function()
            UIManager:close(widget)
            self.v_ch1_intro_feeling = nil
            self:showIntro1()
          end,
        },
      },
    },
  }
  UIManager:show(widget)
end

return MagiumSpike
