-- TEMPORARY — Milestone 0 timing harness only. Replaced by the real plugin
-- class in Task 20. Do not build on this file.
--
-- Purpose: measure how long engine/story.lua's eager preload() (parse all 54
-- English .magium files) takes on the owner's real Kindle Paperwhite 12th gen,
-- to set story's default strategy ("eager" if cold parse <= ~1 s, else "lazy" —
-- spec §7 / §10). It logs the wall-clock deltas with a "MAGIUM parse ..." prefix
-- so they can be grepped out of the run log (emulator: STDOUT; device: crash.log).
--
-- Two ways in, both calling the same time_parse():
--   1. Menu: ≡ → More tools → "Magium: time parse"  — what the owner taps on the
--      real Kindle (brief Step 4).
--   2. init()-time auto-run, deferred via UIManager:nextTick so it does not block
--      FileManager load. This exists ONLY because the headless-xvfb emulator
--      sanity run (tools/mgm.sh emu-smoke) has no way to tap a menu.

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local _ = require("gettext")

local Story = require("engine/story")

-- Cold: first preload after a KOReader restart. Warm: the two that follow (JIT
-- warm, page cache warm). data_root is the folder that CONTAINS <locale>/ (i.e.
-- ".../magium.koplugin/data"); Story appends "/en".
local function time_parse(data_root)
  local function once()
    local t0 = os.clock()
    Story.new{ data_dir = data_root, locale = "en", strategy = "eager" }:preload()
    return (os.clock() - t0) * 1000
  end
  local cold = once()
  logger.info(string.format("MAGIUM parse cold: %.0f ms", cold))
  local warm1, warm2 = once(), once()
  logger.info(string.format("MAGIUM parse warm: %.0f ms / %.0f ms", warm1, warm2))
  return cold, warm1, warm2
end

local Magium = WidgetContainer:extend{ name = "magium", is_doc_only = false }

function Magium:init()
  self.ui.menu:registerToMainMenu(self)
  -- Deviation from the brief: auto-run once, off the load hot path, so the
  -- headless emulator smoke test produces the timing lines without a menu tap.
  -- pcall-guarded: this fires unattended from the main loop at every launch, so
  -- a throw here (e.g. busybox `ls` / io.popen quirk on the Kindle) must NOT
  -- reach KOReader's crash handler — that would trap the owner in a boot loop
  -- recoverable only by deleting the plugin over USB. The menu path stays
  -- unguarded: it is user-triggered and a crash there is recoverable.
  UIManager:nextTick(function()
    local ok, err = pcall(function()
      local cold, w1, w2 = time_parse(self.path .. "/data")
      logger.info(string.format(
        "MAGIUM parse (init) cold %.0f ms / warm %.0f / %.0f ms", cold, w1, w2))
    end)
    if not ok then
      logger.warn("MAGIUM parse (init) failed: " .. tostring(err))
    end
  end)
end

function Magium:addToMainMenu(menu_items)
  menu_items.magium = {
    text = _("Magium: time parse"),
    sorting_hint = "more_tools",
    callback = function()
      local data_root = self.path .. "/data"
      local cold, w1, w2 = time_parse(data_root)
      UIManager:show(InfoMessage:new{
        text = string.format("cold %.0f ms\nwarm %.0f / %.0f ms\n(see crash.log)", cold, w1, w2),
      })
    end,
  }
end

return Magium
