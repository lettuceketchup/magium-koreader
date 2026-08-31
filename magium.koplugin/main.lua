--[[--
Magium — play the text CYOA game inside KOReader. Phase I: chapter 1 playable,
autosave/resume. Later phases add saves UI, stats, achievements, i18n.
--]]--

local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local Persist = require("persist")
local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local _ = require("gettext")

local Story = require("engine/story")
local Locale = require("engine/locale")
local scene = require("engine/scene")
local Store = require("engine/store")
local specials = require("engine/specials")
local Reader = require("ui/reader")
local SaveManager = require("save/manager")

-- Milestone 0 (Task 6, 2026-08-31): device cold parse ≈ 2.2 s. Over the ~1 s
-- gate — but the owner chose `eager` with the parse **deferred to the first
-- reader-open** (a Trapper progress bar covers the ~2.2 s once per session)
-- rather than build the lazy/disk-cache path now. See spec §7 + spike 06.
local PARSE_STRATEGY = "eager"

local Magium = WidgetContainer:extend{ name = "magium", is_doc_only = false }

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
  self.locale = Locale.load(self.data_dir, "en")
  self.story = Story.new{ data_dir = self.data_dir, locale = "en", strategy = PARSE_STRATEGY }
  self.store = Store.new()
  self.save = SaveManager.new{
    store = self.store, writer = state_writer(),
    schedule = function(d, fn) UIManager:scheduleIn(d, fn); return fn end,
    unschedule = function(fn) UIManager:unschedule(fn) end,
    debounce = 8,
  }
  -- NOTE: no parse here. init() runs at KOReader startup for every plugin; the
  -- ~2.2 s eager parse happens in openReader() the first time the user actually
  -- opens Magium (Milestone 0 decision).
end

-- Parse all 54 files once, the first time the reader is opened this session,
-- behind a Trapper progress bar. Subsequent opens are instant (story is resident).
function Magium:_ensureLoaded()
  if self._loaded then return end
  Trapper:wrap(function()
    self.story:preload(function(done, total)
      -- skip_dismiss_check = true (Trapper:info's 3rd arg) is load-bearing: on
      -- its 2nd+ call Trapper:info() otherwise coroutine.yield()s back to the
      -- resume() inside Trapper:wrap(), which returns — _ensureLoaded() would
      -- fall through with the corpus only half-parsed and openReader() would
      -- render(nil) → "unknown scene". With it, the whole preload runs
      -- synchronously to completion before wrap() returns. A non-dismissable
      -- ~2 s bar is the right trade (dismissing mid-parse = broken state).
      -- Throttled to ~10 updates so the device isn't asked for 54 e-ink flashes.
      if done == 1 or done == total or done % 6 == 0 then
        Trapper:info(string.format("%s  %d / %d", _("Loading Magium…"), done, total), false, true)
      end
    end)
    Trapper:clear()
  end)
  self._loaded = true
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
    callback = function() self:openReader() end,
  }
end

function Magium:onMagiumOpen() self:openReader(); return true end

function Magium:openReader()
  self:_ensureLoaded()   -- first open this session: ~2.2 s parse behind a progress bar

  -- resume, or start fresh
  local resume = self.save:load()
  if not resume or not self.story:get_scene(resume) then
    self.store:restore({})
    self.store:set("v_current_scene", specials.DEFAULT_SCENE)
  end

  local function render_current()
    local id = self.store:get("v_current_scene")
    local st = self.story:get_scene(id)
    if not st then
      logger.warn("Magium: unknown scene", id, "— resetting to intro")
      self.store:set("v_current_scene", specials.DEFAULT_SCENE)
      st = self.story:get_scene(specials.DEFAULT_SCENE)
    end
    return scene.render(st, self.store:view(), self.locale)
  end

  self.reader = Reader:new{
    render_model = render_current(),
    locale = self.locale,
    on_close = function() self.save:flush_now("close") end,
    advance = function(button)
      local touched_ac = false
      for k, v in pairs(button.set_vars) do
        self.store:set(k, v)
        if k:sub(1, 5) == "v_ac_" then touched_ac = true end
      end
      if button.special == "restart" then
        self.store:restore({})
        self.store:set("v_current_scene", specials.DEFAULT_SCENE)
      end
      -- special:saves / :stats / :checkpoint_* are Phase II/III — no-op nav for now
      if touched_ac then
        self.save:on_achievement_unlocked()   -- spec §9: immediate flush on unlock
      else
        self.save:touch()
      end
      return render_current()
    end,
  }
  UIManager:show(self.reader)
end

-- flush on suspend / shutdown — but only once the reader has been opened this
-- session. Before that self.store is the empty Store.new() from init() and an
-- unconditional flush would overwrite the player's real saved position with {}.
function Magium:onSuspend() if self._loaded then self.save:flush_now("suspend") end end
function Magium:onClose() if self._loaded then self.save:flush_now("close-broadcast") end end
function Magium:onCloseWidget() if self._loaded then self.save:flush_now("close-widget") end end

return Magium
