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
--
-- Task 18 makes both of those Store-backed via make_reader() below (real choice
-- commits: set_vars -> store, v_current_scene moves, re-render) and extends the
-- headless hook to tap a forward choice ~10 times, hopping scene by scene and
-- logging each "[MAGIUM] scene <id> <N>pages" hop.

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

-- Build a Store-backed ui/reader.lua positioned at the story's default scene.
-- Shared by the "read ch1 intro" menu item and the headless auto-drive. The
-- `advance` closure is the Phase-I choice-commit engine (spec §8.1): apply the
-- tapped button's set_vars to the store (relative +N/-N resolve inside
-- store:set), let v_current_scene move with them (C6, it is one of the set_vars
-- for a normal choice), dispatch `special` (only `restart` is wired in Phase I —
-- saves/stats/checkpoint are inert), then re-render whatever v_current_scene now
-- points at. Task 20 replaces this with the real plugin flow (+ resume/autosave).
local function make_reader(base_path)
  local Locale = require("engine/locale")
  local scenemod = require("engine/scene")
  local Store = require("engine/store")
  local Reader = require("ui/reader")
  local specials = require("engine/specials")

  local story = Story.new{ data_dir = base_path .. "/data", locale = "en", strategy = "eager" }:preload()
  local loc = Locale.load(base_path .. "/data", "en")
  local store = Store.new()
  store:set("v_current_scene", specials.DEFAULT_SCENE)

  local function render_current()
    return scenemod.render(story:get_scene(store:get("v_current_scene")), store:view(), loc)
  end

  local reader
  reader = Reader:new{
    render_model = render_current(),
    locale = loc,
    on_close = function() end,
    advance = function(button)
      for k, v in pairs(button.set_vars) do store:set(k, v) end
      if button.special == "restart" then
        store:restore({})
        store:set("v_current_scene", specials.DEFAULT_SCENE)
      end
      return render_current()
    end,
  }
  return reader, store
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

  -- TEMPORARY (Task 17, extended Task 18) — headless drive of ui/reader.lua.
  -- emu-smoke cannot tap, so this is the only signal that the widget constructs,
  -- paginates against a real TextBoxWidget, re-renders on turn, reaches the
  -- ButtonTable choices page, and — Task 18 — that committing a choice writes
  -- the store, advances v_current_scene, re-renders and re-paginates the NEW
  -- scene, repeatedly, across real scene transitions. Same boot-loop reasoning
  -- as the timing hook above: pcall-guarded so a throw from this unattended
  -- main-loop callback never reaches KOReader's crash handler. Gone in Task 20.
  UIManager:nextTick(function()
    local ok, err = pcall(function()
      local reader = make_reader(self.path)
      UIManager:show(reader)
      logger.info(string.format("[MAGIUM] scene %s %dpages (start)",
        tostring(reader.render_model.scene_id), #reader.pages))

      -- Which button to tap. Deviation from the brief's literal "buttons[1]":
      -- in this corpus buttons[1] of Ch1-Cutthroat Dave is a death choice whose
      -- only follow-ups are special:restart / special:saves, so buttons[1] just
      -- loops Intro1->Intro2->Cutthroat Dave->Retreat->(restart) — 4 scenes, not
      -- the "~10 distinct ch1 scenes" the brief wants proven. Pick the last
      -- button that actually moves forward (skip special:restart / dead-end
      -- special choices with no target); fall back to buttons[1]. This walks
      -- Intro1 -> Intro2 -> Cutthroat Dave -> Imply -> Imply2 -> Humor -> Ch2...
      local DEAD_END = { restart = true, saves = true, checkpoint_load = true }
      local function pick_forward(buttons)
        for i = #buttons, 1, -1 do
          local b = buttons[i]
          if not DEAD_END[b.special or ""] and b.target and b.target ~= "" then
            return b
          end
        end
        return buttons[1]
      end

      -- step() self-reschedules and runs later inside UIManager's task loop,
      -- i.e. OUTSIDE the outer pcall — guard each step, stop rescheduling on a
      -- failure (a deterministic throw here would otherwise crash-loop a device
      -- restart via init()). Walk each scene's pages, tap a forward choice on
      -- the choices page, repeat for ~10 hops or until a scene has no choices.
      local hops, MAX_HOPS = 0, 10
      local function step()
        local step_ok, step_err = pcall(function()
          if reader.page_idx < #reader.pages then
            reader:onNextPage()                       -- advance to the choices page
            UIManager:scheduleIn(0.3, step)
            return
          end
          local last = reader.pages[#reader.pages]
          if last.kind ~= "choices" or not last.buttons or #last.buttons == 0 then
            logger.info(string.format("[MAGIUM] scene %s has no choices — stopping after %d hops",
              tostring(reader.render_model.scene_id), hops))
            reader:onClose()
            return
          end
          if hops >= MAX_HOPS then
            logger.info(string.format("[MAGIUM] reached %d hops — closing", hops))
            reader:onClose()
            return
          end
          local btn = pick_forward(last.buttons)
          local label = btn.label
          reader:_commit_choice(btn)
          hops = hops + 1
          logger.info(string.format("[MAGIUM] scene %s %dpages (hop %d via %q)",
            tostring(reader.render_model.scene_id), #reader.pages, hops, tostring(label)))
          UIManager:scheduleIn(0.3, step)
        end)
        if not step_ok then
          logger.warn("[MAGIUM] reader auto-drive step failed: " .. tostring(step_err))
        end
      end
      UIManager:scheduleIn(0.3, step)
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
  -- TEMPORARY (Task 17, Store-backed in Task 18) — manual launch path for
  -- ui/reader.lua from the story's default scene, choices live. Gone in Task 20.
  menu_items.magium_read = {
    text = _("Magium: read ch1 intro"),
    sorting_hint = "more_tools",
    callback = function()
      UIManager:show(make_reader(self.path))
    end,
  }
end

return Magium
