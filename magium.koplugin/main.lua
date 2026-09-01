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
-- The trace file handle for the current reader-open, module-scope so the next
-- open can close it (one open handle per process, not one per open).
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
    store = self.store, writer = state_writer(),
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
  -- One trace file per reader-open — close the previous open's handle first,
  -- otherwise every open in a session leaks an fd until the process exits.
  if trace_file then
    pcall(function() trace_file:close() end)
    trace_file = nil
  end
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
    local ok = false
    trace.event("preload_start")
    local t0 = time.now()
    Trapper:wrap(function()
      -- pcall so Trapper:clear() runs on BOTH paths. Without it a preload()
      -- throw skipped the clear and left the "Loading Magium… n/54" InfoMessage
      -- on screen underneath the error box. `pok` still means "did not throw".
      local pok = pcall(function()
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
      ok = pok   -- true only if preload() did not throw
    end)
    if ok then
      shared_story, shared_loaded = story, true
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
  menu_items.magium = {
    text = _("Magium"),
    sorting_hint = "more_tools",
    sub_item_table = {
      {
        text = _("Open Magium"),
        callback = function() self:openReader() end,
      },
      {
        text = _("Record debug log"),
        help_text = _("Writes a trace-*.jsonl of your play session under koreader/magium/ for bug reports. Takes effect the next time you open Magium."),
        checked_func = function() return G_reader_settings:isTrue("magium_trace") end,
        -- flipNilOrFalse is the default-OFF pairing for checked_func→isTrue:
        -- nil/false → true, true → nil. (flipNilOrTrue never writes true.)
        callback = function() G_reader_settings:flipNilOrFalse("magium_trace") end,
      },
    },
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
      end
      -- special:saves / :stats / :checkpoint_* are Phase II/III — no-op nav for now
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
