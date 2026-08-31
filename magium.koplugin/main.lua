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
--
-- Task 17 bolts a second, equally temporary scaffold onto the same file: a
-- "Magium: read ch1 intro" menu item + a second nextTick hook that opens
-- ui/reader.lua on Ch1-Intro1 and walks every page headlessly. Also gone in
-- Task 20.

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

  -- TEMPORARY (Task 17) — headless drive of ui/reader.lua. emu-smoke cannot
  -- tap, so this is the only signal that the widget constructs, paginates
  -- against a real TextBoxWidget, re-renders on turn, and reaches the choices
  -- page. Same boot-loop reasoning as the timing hook above: pcall-guarded so a
  -- throw from this unattended main-loop callback never reaches KOReader's
  -- crash handler. Removed with the rest of this scaffold in Task 20.
  UIManager:nextTick(function()
    local ok, err = pcall(function()
      local Locale = require("engine/locale")
      local scenemod = require("engine/scene")
      local Reader = require("ui/reader")
      local story = Story.new{ data_dir = self.path .. "/data", locale = "en", strategy = "eager" }:preload()
      local loc = Locale.load(self.path .. "/data", "en")
      local rm = scenemod.render(story:get_scene("Ch1-Intro1"), {}, loc)
      local reader = Reader:new{
        render_model = rm, locale = loc,
        on_close = function() end,
        on_choice = function(b) logger.info("[MAGIUM] reader choice: " .. tostring(b.label)) end,
      }
      UIManager:show(reader)
      logger.info("[MAGIUM] reader: " .. #reader.pages .. " pages")
      -- step() self-reschedules and runs later inside UIManager's task loop,
      -- i.e. OUTSIDE the outer pcall. Tasks 18-19 rewrite reader.lua with this
      -- scaffold still present, so a deterministic throw here must not reach the
      -- crash handler (on device: restart re-runs init() -> same throw ->
      -- crash-loop). Guard each step and stop rescheduling on failure.
      local function step()
        local step_ok, step_err = pcall(function()
          logger.info("[MAGIUM] reader page " .. reader.page_idx .. "/" .. #reader.pages
            .. " kind=" .. reader.pages[reader.page_idx].kind)
          if reader.page_idx < #reader.pages then
            reader:onNextPage()
            UIManager:scheduleIn(0.4, step)
          else
            reader:onClose()
            logger.info("[MAGIUM] reader: walked all pages, closed")
          end
        end)
        if not step_ok then
          logger.warn("[MAGIUM] reader auto-drive step failed: " .. tostring(step_err))
        end
      end
      UIManager:scheduleIn(0.4, step)
    end)
    if not ok then
      logger.warn("[MAGIUM] reader (init) failed: " .. tostring(err))
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
  -- TEMPORARY (Task 17) — manual launch path for ui/reader.lua on Ch1-Intro1.
  -- Removed with the rest of this scaffold in Task 20.
  menu_items.magium_read = {
    text = _("Magium: read ch1 intro"),
    sorting_hint = "more_tools",
    callback = function()
      local Locale = require("engine/locale")
      local scenemod = require("engine/scene")
      local Reader = require("ui/reader")
      local story = Story.new{ data_dir = self.path .. "/data", locale = "en", strategy = "eager" }:preload()
      local loc = Locale.load(self.path .. "/data", "en")
      local rm = scenemod.render(story:get_scene("Ch1-Intro1"), {}, loc)
      UIManager:show(Reader:new{
        render_model = rm, locale = loc,
        on_close = function() end,
        on_choice = function(b) logger.info("[MAGIUM] reader choice: " .. tostring(b.label)) end,
      })
    end,
  }
end

return Magium
