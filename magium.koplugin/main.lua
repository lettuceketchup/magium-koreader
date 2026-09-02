--[[--
Magium — play the text CYOA game inside KOReader. Phase I: chapter 1 playable,
autosave/resume. Later phases add saves UI, stats, achievements, i18n.
--]]--

local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local Persist = require("persist")
local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")
local Version = require("version")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local time = require("ui/time")
local _ = require("gettext")

local Story = require("engine/story")
local Locale = require("engine/locale")
local scene = require("engine/scene")
local Store = require("engine/store")
local specials = require("engine/specials")
local Reader = require("ui/reader")
local SaveManager = require("save/manager")
local trace = require("util/trace")

-- Milestone 0 (Task 6, 2026-08-31): device cold parse ≈ 2.2 s. Over the ~1 s
-- gate — but the owner chose `eager` with the parse **deferred to the first
-- reader-open** (a Trapper progress bar covers the ~2.2 s once per session)
-- rather than build the lazy/disk-cache path now. See spec §7 + spike 06.
local PARSE_STRATEGY = "eager"

-- The parsed corpus is immutable + pure after preload(), so it is shared across
-- plugin instances for the whole KOReader process (= one session). KOReader
-- builds a fresh plugin instance per UI (FileManager, ReaderUI) and a new
-- FileManager on every book-close; keeping the story here means the ~2.2 s parse
-- + progress bar happen **once per session**, not once per instance (spec §7.1).
-- `store` / `save` stay per-instance (they hold mutable play state).
local shared_story
local shared_loaded = false
-- Same reasoning for the locale bundle: Locale is immutable after load, so
-- re-reading + JSON-decoding data/en/ui.json in every init() is exactly the
-- per-instance churn Ruling 12 removed for `story`.
local shared_locale
-- The trace file handle for the current reader-open, module-scope so
-- _configureTrace can close it on the NEXT open — including the toggle-off open,
-- which opens no replacement (one open handle per process, not one per open).
local trace_file

local Magium = WidgetContainer:extend{ name = "magium", is_doc_only = false }

-- ---- helpers ----------------------------------------------------------------

local function new_story(data_dir)
  return Story.new{ data_dir = data_dir, locale = "en", strategy = PARSE_STRATEGY }
end

-- Reset to a fresh playthrough but KEEP earned achievements. Parity: magium-dev's
-- special:restart is clearState(), which rewrites only `currentState`; the
-- `achievements` blob is permanent across playthroughs (constraint C1). Since
-- SaveManager._write derives the achievements blob straight from the store,
-- wiping `v_ac_*` here would erase them on the next flush.
local function reset_to_intro(store)
  local keep = {}
  for k, v in pairs(store:snapshot()) do
    if k:sub(1, 5) == "v_ac_" then keep[k] = v end
  end
  store:restore(keep)
  store:set("v_current_scene", specials.DEFAULT_SCENE)
end

-- ---- persistence adapters (the KOReader-specific edges) -----------------------

local function save_dir()
  local d = DataStorage:getDataDir() .. "/magium"
  lfs.mkdir(d)
  return d
end

-- A { read()->table|nil, write(table) } adapter over one Persist blob — plain
-- functions (SaveManager calls them with a dot), luajit codec, fsynced on write.
local function state_writer()
  local p = Persist:new{ path = save_dir() .. "/state", codec = "luajit" }
  return {
    read = function() return p:load() end,
    write = function(t) p:save(t) end,
  }
end

-- Phase III: one Persist blob per manual slot under magium/slots/. A
-- { load(n), save(n,t), remove(n) } adapter — plain functions, dot-called.
-- Slot ops are rare and user-initiated, so a fresh Persist per call is fine.
local function slot_store()
  local dir = save_dir() .. "/slots"
  lfs.mkdir(dir)
  local function path(n) return dir .. "/" .. n .. ".blob" end
  return {
    load = function(n) return Persist:new{ path = path(n), codec = "luajit" }:load() end,
    save = function(n, t) Persist:new{ path = path(n), codec = "luajit" }:save(t) end,
    remove = function(n) os.remove(path(n)) end,
  }
end

-- (Milestone 0 chose `eager` + parse-on-first-open, so there is no lazy
--  disk-cache adapter in Phase I. The `cache_store` seam stays on `Story.new`
--  for the deferred lazy path — a later phase backs it with `Persist`.)

-- ---- lifecycle ---------------------------------------------------------------

function Magium:init()
  self:onDispatcherRegisterActions()
  self.ui.menu:registerToMainMenu(self)
  self.data_dir = self.path .. "/data"
  shared_locale = shared_locale or Locale.load(self.data_dir, "en")
  self.locale = shared_locale
  self.story = shared_story   -- nil until the first successful _ensureLoaded()
  self.store = Store.new()
  self.save = SaveManager.new{
    store = self.store, writer = state_writer(), slotstore = slot_store(),
    schedule = function(d, fn) UIManager:scheduleIn(d, fn); return fn end,
    unschedule = function(fn) UIManager:unschedule(fn) end,
    debounce = 8,
  }
  -- NOTE: no parse here. init() runs at KOReader startup for every plugin; the
  -- ~2.2 s eager parse happens in openReader() the first time the user actually
  -- opens Magium (Milestone 0 decision). The trace is configured per reader-open
  -- (openReader), NOT here — init() runs on every FileManager/ReaderUI build, so
  -- configuring here would spawn a session-header-only trace file on every book
  -- open/close and let the prune-to-5 delete the file holding real play data.
end

-- Configure the optional action trace (util/trace, spec §9.2 / ADR-005). OFF
-- unless the "Record debug log" menu checkbox (G_reader_settings "magium_trace")
-- is set. Called at the top of openReader() — once per real open, before any
-- trace.event fires — so each play session gets its own trace-<ts>.jsonl and a
-- mid-session menu flip takes effect on the next Open (matching the help text).
-- trace.configure resets the buffer + count, so per-open calls are safe.
function Magium:_configureTrace()
  -- Close the previous open's trace file FIRST, and unconditionally. Doing it
  -- inside _trace_writer() only covered the toggle-ON path; toggling "Record
  -- debug log" OFF and reopening passes writer=nil, never reaches
  -- _trace_writer(), and would leak the old handle until the process exits.
  -- The new file (if any) is opened below, after this — so the order is still
  -- close-old-then-open-new.
  if trace_file then
    pcall(function() trace_file:close() end)
    trace_file = nil
  end
  local on = G_reader_settings:isTrue("magium_trace")
  trace.configure{
    enabled = on,
    writer = on and self:_trace_writer() or nil,
    log = logger.info,
    -- time.now() is an fts (fixed-point µs), NOT a seconds number — time.to_ms()
    -- is its documented converter. Monotonic (CLOCK_MONOTONIC_COARSE), ms res;
    -- right for the relative deltas the trace records.
    clock = function() return time.to_ms(time.now()) end,
  }
  if on then
    trace.event("session", {
      plugin = "magium",
      kover = Version:getCurrentRevision() or tostring(Version:getNormalizedCurrentVersion()),
      device = Device.model or "?",
      ts = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
  end
end

-- Open this session's trace file under <datadir>/magium/ and prune old ones:
-- keep only the newest 4 pre-existing trace-*.jsonl (this run's new file makes
-- 5). Returns a line writer (fsynced per line), or nil if the file could not be
-- opened; the file is left open for the process lifetime — the OS closes it on
-- exit.
function Magium:_trace_writer()
  local dir = save_dir()   -- lfs.mkdir'd, no trailing slash
  -- Pruning is best-effort. lfs.dir throws on an unreadable directory and
  -- os.remove can fail on a locked file; a diagnostic must never break the game
  -- (ADR-005), so a throw here costs us the prune, not the trace.
  local pruned = pcall(function()
    local existing = {}
    for name in lfs.dir(dir) do
      if name:match("^trace%-.*%.jsonl$") then existing[#existing + 1] = name end
    end
    table.sort(existing)   -- trace-YYYYmmdd-HHMMSS names sort chronologically
    for i = 1, #existing - 4 do
      os.remove(dir .. "/" .. existing[i])
    end
  end)
  if not pruned then logger.warn("Magium: could not prune old trace files in " .. dir) end
  -- (the previous open's handle is already closed — _configureTrace does that
  --  unconditionally before it gets here)
  -- os.date has 1 s resolution, so two opens landing in the same second would
  -- pick the same name and io.open(path, "w") would TRUNCATE the first one's
  -- file. Suffix -2, -3, … until the name is free (bounded).
  local base = dir .. "/trace-" .. os.date("!%Y%m%d-%H%M%S")
  local path = base .. ".jsonl"
  local n = 1
  while n < 100 and lfs.attributes(path, "mode") do
    n = n + 1
    path = base .. "-" .. n .. ".jsonl"
  end
  local ok, f = pcall(io.open, path, "w")
  if not ok or not f then
    -- return nil, not a writer that silently drops every line:
    -- trace.configure{ writer = nil } is the honest degradation ("mirror to
    -- crash.log only") and flush() then skips the write path entirely.
    logger.warn("Magium: could not open trace file " .. path)
    return nil
  end
  trace_file = f
  return function(line)
    f:write(line); f:write("\n"); f:flush()
  end
end

-- Parse all 54 files once per KOReader session, the first time the reader is
-- opened, behind a Trapper progress bar. Subsequent opens (this or any later
-- plugin instance) are instant — the story stays resident in `shared_story`.
function Magium:_ensureLoaded()
  if not shared_loaded then
    -- A fresh Story per attempt: Story:_merge() throws "duplicate scene id" if a
    -- half-parsed object is re-preloaded, so a retry after a transient parse
    -- failure (disk error / truncated file on device) must start clean.
    local story = new_story(self.data_dir)
    local ok, err = false, nil
    trace.event("preload_start")
    local t0 = time.now()
    Trapper:wrap(function()
      -- pcall so Trapper:clear() runs on BOTH paths. Without it a preload()
      -- throw skipped the clear and left the "Loading Magium… n/54" InfoMessage
      -- on screen underneath the error box. `pok` still means "did not throw";
      -- `perr` is kept so the real cause reaches crash.log (see below).
      local pok, perr = pcall(function()
        story:preload(function(done, total)
          -- skip_dismiss_check = true (Trapper:info's 3rd arg) is load-bearing: on
          -- its 2nd+ call Trapper:info() otherwise coroutine.yield()s back to the
          -- resume() inside Trapper:wrap(), which returns — _ensureLoaded() would
          -- fall through with the corpus only half-parsed and openReader() would
          -- render(nil). With it, the whole preload runs synchronously to
          -- completion. A non-dismissable ~2 s bar is the right trade (dismissing
          -- mid-parse leaves exactly that broken half-parsed state).
          -- Throttled to ~10 updates so the device isn't asked for 54 e-ink flashes.
          if done == 1 or done == total or done % 6 == 0 then
            Trapper:info(string.format("%s  %d / %d", _("Loading Magium…"), done, total), false, true)
          end
        end)
      end)
      Trapper:clear()
      ok, err = pok, perr   -- ok is true only if preload() did not throw
    end)
    if ok then
      shared_story, shared_loaded = story, true
    else
      -- The only breadcrumb for a truncated .magium or a disk error on the
      -- device: openReader()'s guard below reports the generic "story data
      -- unavailable", which says nothing about the actual cause.
      logger.warn("Magium: preload failed: " .. tostring(err))
    end
    -- on failure: shared_loaded stays false → the next open retries from scratch.
    trace.event("preload_done", {
      -- count() is a ~2159-iter loop; skip it unless the trace will use it
      -- (the data table is built before trace.event can no-op).
      scenes = trace.enabled and shared_story and shared_story:count() or 0,
      ok = ok,
      ms = time.to_ms(time.now() - t0),
    })
  end
  self.story = shared_story
end

function Magium:onDispatcherRegisterActions()
  Dispatcher:registerAction("magium_open", {
    category = "none", event = "MagiumOpen", title = _("Magium"), general = true,
  })
end

function Magium:addToMainMenu(menu_items)
  -- Two flat entries under More tools rather than a submenu: opening Magium is
  -- the common action and shouldn't cost an extra tap. (A gesture can also be
  -- bound to the "magium_open" Dispatcher action registered above.)
  menu_items.magium = {
    text = _("Magium"),
    sorting_hint = "more_tools",
    callback = function() self:openReader() end,
  }
  menu_items.magium_trace = {
    text = _("Magium: record debug log"),
    sorting_hint = "more_tools",
    help_text = _("Writes a trace-*.jsonl of your play session under koreader/magium/ for bug reports. Takes effect the next time you open Magium."),
    checked_func = function() return G_reader_settings:isTrue("magium_trace") end,
    -- flipNilOrFalse is the default-OFF pairing for checked_func→isTrue:
    -- nil/false → true, true → nil. (flipNilOrTrue never writes true.)
    callback = function() G_reader_settings:flipNilOrFalse("magium_trace") end,
  }
end

function Magium:onMagiumOpen() self:openReader(); return true end

function Magium:openReader()
  self:_configureTrace()   -- (re)arm the trace for this open — reads the menu toggle, opens a fresh file
  self:_ensureLoaded()     -- first open this session: ~2.2 s parse behind a progress bar
  trace.event("open")

  -- Real precondition for everything below: the opening scene must exist. Guards
  -- a swallowed preload() throw / a partial parse (ch1.magium sorts 42nd of 54,
  -- so story:count() can be > 0 with Ch1-Intro1 still unparsed) — without this,
  -- render_current() feeds nil to scene.render() → traceback in crash.log.
  if not self.story or not self.story:get_scene(specials.DEFAULT_SCENE) then
    logger.warn("Magium: story data unavailable — cannot open reader")
    trace.event("error", { msg = "story unavailable" })
    trace.flush()   -- nothing below sets self._loaded, so no lifecycle flush will run
    UIManager:show(InfoMessage:new{ text = _("Magium: could not load the story data.") })
    return
  end

  -- resume, or start fresh (keeping achievements — reset_to_intro, not a wipe)
  local resume = self.save:load()
  trace.event("resume", { scene = resume or "fresh" })
  self._loaded = true   -- this instance's store now mirrors disk; lifecycle flushes may run
  if not resume or not self.story:get_scene(resume) then
    reset_to_intro(self.store)
  end

  local function render_current()
    local id = self.store:get("v_current_scene")
    local st = self.story:get_scene(id)
    if not st then
      logger.warn("Magium: unknown scene", id, "— resetting to intro")
      trace.event("warn", { msg = "unknown scene", scene = id })
      self.store:set("v_current_scene", specials.DEFAULT_SCENE)
      st = self.story:get_scene(specials.DEFAULT_SCENE)
    end
    local rm = scene.render(st, self.store:view(), self.locale)
    scene.persist_effects(self.store, rm)   -- persist this scene's own set() effects (spec §4)
    if #rm.achievements > 0 then
      local Toast = require("ui/toast")
      Toast.show(self.locale, rm.achievements)
      self.save:on_achievement_unlocked()   -- flush the now-"2" (seen) blob right away
    end
    trace.event("render", {
      scene = rm.scene_id,
      paras = #rm.paragraphs,
      choices = #rm.choices,
      checks = #rm.stat_checks,
      checkpoint = rm.checkpoint,
    })
    return rm
  end

  self.reader = Reader:new{
    render_model = render_current(),
    locale = self.locale,
    on_menu = function() self:openMenu() end,
    on_close = function()
      self.save:flush_now("close")
      trace.event("save", { op = "flush", reason = "close" })
      trace.event("close", { reason = "reader" })
      trace.flush()
      -- This instance is no longer mirroring a live session. Without the reset,
      -- a later onSuspend/onClose/onCloseWidget would append save/close records
      -- to the PREVIOUS session's trace file (the next open opens a new one).
      -- Nothing is lost: on_close already ran flush_now("close"), and the store
      -- cannot change again until another openReader() sets _loaded back to true.
      self._loaded = false
    end,
    advance = function(button)
      local touched_ac = false
      for k, v in pairs(button.set_vars) do
        self.store:set(k, v)
        if k:sub(1, 5) == "v_ac_" then touched_ac = true end
      end
      if button.special == "restart" then
        reset_to_intro(self.store)   -- keep achievements (parity: clearState)
      elseif button.special == "checkpoint_save" then
        -- the choice's v_current_scene (next-chapter intro) is already applied
        self.save:save_checkpoint()
      elseif button.special == "checkpoint_load" then
        if self.save:load_checkpoint() then
          self.save:flush_now("checkpoint-load")
        else
          UIManager:nextTick(function()
            UIManager:show(InfoMessage:new{
              text = _('No checkpoint saved yet. Choose "Restart game" to start over.'),
            })
          end)
        end
      elseif button.special == "stats" then
        -- v_current_scene (the -spent scene) is already applied above; open the
        -- allocation screen over the reader.
        UIManager:nextTick(function() self:openStats() end)
      elseif button.special == "saves" then
        UIManager:nextTick(function() self:openSaves() end)
      end
      trace.event("choice", {
        label = button.label,
        target = button.target or "",
        special = button.special or "",
        ac = touched_ac,
      })
      if touched_ac then
        self.save:on_achievement_unlocked()   -- spec §9: immediate flush on unlock
        trace.event("save", { op = "achievement" })
      else
        self.save:touch()
        trace.event("save", { op = "touch" })
      end
      local rm = render_current()
      trace.flush()   -- choice-commit is a flush point (spec §9.2 / ADR-005)
      return rm
    end,
  }
  UIManager:show(self.reader)
end

-- The in-game menu (spec §6, D2). The full magium-dev menu.ejs shell;
-- Settings is disabled until its phase (VI). Reached from the reader header's
-- "Menu" tap zone and from the special:stats choice.
function Magium:openMenu()
  local ButtonDialog = require("ui/widget/buttondialog")
  local TextViewer = require("ui/widget/textviewer")
  local dialog
  local function act(fn) return function() UIManager:close(dialog); fn() end end
  local about = (self.locale:str("aboutIntroText")
    or "Magium — a Choose Your Own Adventure game by Cristian Mihailescu.")
    :gsub("<br%s*/?>", "\n")
  dialog = ButtonDialog:new{
    title = _("Magium"), title_align = "center",
    buttons = {
      {{ text = _("Back to game"), callback = act(function() end) }},
      {{ text = _("New game / Restart book"), callback = act(function() self:newGame() end) }},
      {{
        text = _("Load from last checkpoint"),
        enabled = self.save:has_checkpoint(),
        callback = act(function() self:loadCheckpoint() end),
      }},
      {{
        text = self.locale:str("menuSaveLoadText") or _("Save / Load game"),
        callback = act(function() self:openSaves() end),
      }},
      {{ text = _("Stats"), callback = act(function() self:openStats() end) }},
      {{
        text = self.locale:str("menuAchievementsText") or _("Achievements"),
        callback = act(function() self:openAchievements() end),
      }},
      {{ text = _("Settings"), enabled = false }},
      {{ text = _("About"), callback = act(function()
        UIManager:show(TextViewer:new{ title = _("About"), text = about })
      end) }},
    },
  }
  UIManager:show(dialog)
  trace.event("menu", { action = "open" })
end

-- New game / Restart book: a fresh playthrough, achievements kept
-- (reset_to_intro, parity with magium-dev clearState). A save always exists here
-- (openReader flushed one on load), so always confirm. Reuses the whole open
-- path rather than a bespoke reader-reload.
function Magium:newGame()
  local ConfirmBox = require("ui/widget/confirmbox")
  UIManager:show(ConfirmBox:new{
    text = _("Start a new game? Your progress will be lost. Achievements are kept."),
    ok_text = _("New game"),
    ok_callback = function()
      reset_to_intro(self.store)
      self.save:flush_now("new-game")
      trace.event("choice", { label = "new game", target = specials.DEFAULT_SCENE })
      self:_reopenReader()
    end,
  })
end

-- Menu → Load from last checkpoint. Same restore path as an in-story
-- special:checkpoint_load, then re-open the reader on the restored scene.
function Magium:loadCheckpoint()
  local scene_id = self.save:load_checkpoint()
  if not scene_id then return end   -- button is disabled when has_checkpoint() is false
  self.save:flush_now("checkpoint-load")
  trace.event("choice", { label = "load checkpoint", target = scene_id, special = "checkpoint_load" })
  self:_reopenReader()
end

-- The 50-slot save/load screen (spec §5, ADR-007). Reached from the in-game
-- menu's "Save / Load game" row and the in-story special:saves choice. Save
-- names itself after the current chapter; load mirrors loadCheckpoint (restore →
-- flush → reopen the reader on the saved scene).
function Magium:openSaves()
  local SavesPage = require("ui/savespage")
  self.saves = SavesPage:new{
    slots_meta = function() return self.save:slots_meta() end,
    on_save = function(n)
      local name = self.locale:header(self.store:get("v_current_scene")) or "Magium"
      self.save:save_slot(n, name)
      trace.event("save", { op = "slot_save", n = n })
    end,
    on_delete = function(n)
      self.save:delete_slot(n)
      trace.event("save", { op = "slot_delete", n = n })
    end,
    on_load = function(n)
      local scene_id = self.save:load_slot(n)
      if not scene_id then return end
      self.save:flush_now("slot-load")
      trace.event("choice", { label = "load slot " .. n, target = scene_id, special = "saves" })
      self:_reopenReader()
    end,
    on_close = function() trace.event("menu", { action = "saves_close" }) end,
  }
  UIManager:show(self.saves)
  trace.event("menu", { action = "saves" })
end

-- The stat-allocation screen (spec §12 row IV). Reached from the in-game menu's
-- "Stats" row and the in-story special:stats choice. Point spends are pending in
-- the widget; on_confirm persists them, on_close (Return to game) re-renders the
-- reader since a confirmed spend can open a stat-gated choice on the -spent scene.
function Magium:openStats()
  local StatsPage = require("ui/statspage")
  local scene_id = self.store:get("v_current_scene")

  -- special case #5/#11: at Ch6-Eiden-vs-dragon with v_maximized_stats_used the
  -- screen unlocks "Full immersion" (renderStats + stats.ejs:175). The count-up
  -- animation is cosmetic and cut; only the unlock is ported. This achievement
  -- has no in-story achievement() call (stats.ejs shows its own modal, not
  -- main.ejs's per-scene loop), so it never reaches scene.persist_effects's
  -- "1"->"2" latch — the oracle itself never advances it past "1" either.
  if specials.maximized_stats(scene_id, self.store:view())
     and tonumber(self.store:get("v_ac_ch6_immersion") or 0) == 0 then
    self.store:set("v_ac_ch6_immersion", "1")
    self.save:on_achievement_unlocked()
    local Toast = require("ui/toast")
    Toast.show(self.locale, { { variable = "v_ac_ch6_immersion",
      text = self.locale:achievement_title("v_ac_ch6_immersion") } })
    trace.event("stats", { op = "immersion" })
  end

  self.stats = StatsPage:new{
    view = self.store:snapshot(),
    scene_id = scene_id,
    locale = self.locale,
    on_confirm = function(pending)
      for k, v in pairs(pending) do self.store:set(k, tostring(v)) end
      self.save:flush_now("stats")
      trace.event("stats", { op = "confirm" })
    end,
    on_close = function()
      trace.event("stats", { op = "return" })
      self:_reopenReader()
    end,
  }
  UIManager:show(self.stats)
  trace.event("menu", { action = "stats" })
end

-- The achievements browser (spec §12 row V). Reached from the in-game menu's
-- "Achievements" row. Read-only over the current save (view = a snapshot) —
-- nothing to persist or re-render on close.
function Magium:openAchievements()
  local AchievementsMenu = require("ui/achievementsmenu")
  self.achievements_ui = AchievementsMenu:new{
    locale = self.locale,
    view = self.store:snapshot(),
    on_close = function() trace.event("menu", { action = "achievements_close" }) end,
    on_reset = function()
      -- keep everything EXCEPT v_ac_* (mirrors reset_to_intro's inverse: that
      -- keeps only v_ac_*, this drops only v_ac_*). Owner-requested feature,
      -- no reference in magium-dev.
      local keep = {}
      for k, v in pairs(self.store:snapshot()) do
        if k:sub(1, 5) ~= "v_ac_" then keep[k] = v end
      end
      self.store:restore(keep)
      self.save:flush_now("achievements-reset")
      trace.event("achievements", { op = "reset" })
    end,
  }
  UIManager:show(self.achievements_ui)
  trace.event("menu", { action = "achievements" })
end

-- Close the current reader (flushing) and re-open on the current v_current_scene.
function Magium:_reopenReader()
  if self.reader then UIManager:close(self.reader) end
  UIManager:nextTick(function() self:openReader() end)
end

-- flush on suspend / shutdown — but only once THIS instance has opened the reader
-- (self._loaded, set after save:load()). Before that self.store is the empty
-- Store.new() from init() and an unconditional flush would overwrite the
-- player's real saved position — and achievements — with {}.
function Magium:onSuspend()
  if self._loaded then
    self.save:flush_now("suspend")
    trace.event("save", { op = "flush", reason = "suspend" })
    trace.flush()
  end
end
function Magium:onClose()
  if self._loaded then
    self.save:flush_now("close-broadcast")
    trace.event("save", { op = "flush", reason = "close-broadcast" })
    trace.flush()
  end
end
function Magium:onCloseWidget()
  if self._loaded then
    self.save:flush_now("close-widget")
    trace.event("save", { op = "flush", reason = "close-widget" })
    trace.flush()
  end
end

return Magium
