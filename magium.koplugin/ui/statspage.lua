-- ui/statspage.lua — Phase IV: the stat-allocation screen (spec §12 row IV).
-- A fullscreen KeyValuePage. Ports magium-dev/templates/stats.ejs +
-- public/scripts/stats.js @ 51f5aa9: available points, per-stat rows with
-- value/max, tap to spend (pending), Confirm / Cancel / Return to game.
--
-- StatsPage:new{
--   view       = <flat v_* snapshot at open time>,
--   scene_id   = <string>,               -- for the book-3 row gate
--   locale     = <engine/locale instance>,
--   on_confirm = function(pending_map),  -- { [v_key]=final_int, .., v_available_points=n }
--   on_close   = function(),             -- Return to game (pending is dropped — parity)
-- }
--
-- Pending point spends live in this widget; only Confirm calls back to persist.

local KeyValuePage = require("ui/widget/keyvaluepage")
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local stats = require("engine/stats")
local specials = require("engine/specials")

-- always-shown, allocatable (stats.ejs rows, in order)
local FIXED = {
  "v_strength", "v_toughness", "v_agility", "v_reflexes", "v_hearing",
  "v_perception", "v_ancient_languages", "v_combat_technique", "v_premonition",
}
local BOOK3 = { "v_bluff", "v_magical_sense", "v_aura_hardening" }  -- gated, allocatable
local MAGIC = { "v_magical_power", "v_magical_knowledge" }          -- gated, display-only

local StatsPage = KeyValuePage:extend{
  name = "magium_stats",
}

function StatsPage:init()
  self.pending = {}      -- { [v_key] = pending_int }
  self.spent = 0
  self.max_stat = tonumber(self.view.v_max_stat or 3) or 3
  self.base_points = tonumber(self.view.v_available_points or 0) or 0
  self.title = self.locale:str("statsHeaderText") or _("Stats")
  self.close_callback = self.on_close
  self.kv_pairs = self:_build()
  KeyValuePage.init(self)
  self:_maybe_intro()
end

-- ---- state helpers ----------------------------------------------------------

function StatsPage:_val(key)
  return self.pending[key] or (tonumber(self.view[key] or 0) or 0)
end

function StatsPage:_points()
  return self.base_points - self.spent
end

function StatsPage:_magic_val()
  return tonumber(self.view.v_b3_ch11_magic or 0) or 0
end

-- ordered { key, allocatable } list per the stats.ejs gates
function StatsPage:_rows()
  local rows = {}
  if specials.stats_show_magic_rows(self.view) then
    for _, k in ipairs(MAGIC) do rows[#rows + 1] = { key = k, allocatable = false } end
  end
  for _, k in ipairs(FIXED) do rows[#rows + 1] = { key = k, allocatable = true } end
  if specials.stats_show_book3_rows(self.scene_id) then
    for _, k in ipairs(BOOK3) do rows[#rows + 1] = { key = k, allocatable = true } end
  end
  return rows
end

function StatsPage:_label(key)
  return self.locale:str(stats.var_to_stat(key)) or key
end

-- ---- kv_pairs -------------------------------------------------------------

function StatsPage:_build()
  local kv = {}
  kv[#kv + 1] = {
    self.locale:str("statsAvailablePointsText") or _("Available points"),
    tostring(self:_points()),
  }
  for _, r in ipairs(self:_rows()) do
    if r.allocatable then
      local key = r.key
      kv[#kv + 1] = {
        self:_label(key),
        string.format("%d / %d", self:_val(key), self.max_stat),
        callback = function() self:_bump(key) end,
      }
    else
      kv[#kv + 1] = { self:_label(r.key), tostring(self:_magic_val()) }
    end
  end
  kv[#kv + 1] = {
    "", self.locale:str("statsConfirmText") or _("Confirm changes"),
    callback = function() self:_confirm() end,
  }
  kv[#kv + 1] = {
    "", self.locale:str("statsCancelText") or _("Cancel changes"),
    callback = function() self:_cancel() end,
  }
  return kv
end

function StatsPage:_refresh()
  self.kv_pairs = self:_build()
  self:_populateItems()
  UIManager:setDirty(self, "ui")
end

-- ---- actions --------------------------------------------------------------

-- updateStat parity: increment only, capped at max_stat, gated on points.
function StatsPage:_bump(key)
  if self:_val(key) >= self.max_stat or self:_points() <= 0 then return end
  self.pending[key] = self:_val(key) + 1
  self.spent = self.spent + 1
  self:_refresh()
end

-- confirmStats parity: persist the pending values + available_points, then stay
-- on the screen with the new values as the baseline.
function StatsPage:_confirm()
  if self.spent == 0 then return end
  local map = {}
  for k, v in pairs(self.pending) do map[k] = v end
  map.v_available_points = self:_points()
  self.on_confirm(map)
  for k, v in pairs(map) do self.view[k] = tostring(v) end
  self.base_points = self.base_points - self.spent
  self.pending, self.spent = {}, 0
  self:_refresh()
end

function StatsPage:_cancel()
  if self.spent == 0 then return end
  self.pending, self.spent = {}, 0
  self:_refresh()
end

-- ---- first-visit tutorial (stats_intro_seen parity) ----------------------

function StatsPage:_maybe_intro()
  if G_reader_settings:isTrue("magium_stats_intro_seen") then return end
  local L = self.locale
  local intro = (L:str("statsIntroductionText") or ""):gsub("<br%s*/?>%s*", "\n")
  local fail = L:stat_check_text{ variable = L:str("statsAncientLanguagesText"), value = 3, success = false }
  local ok = L:stat_check_text{ variable = L:str("statsCombatTechniqueText"), value = 2, success = true }
  UIManager:show(TextViewer:new{
    title = self.title,
    text = intro .. "\n\n" .. fail .. "\n" .. ok,
  })
  G_reader_settings:makeTrue("magium_stats_intro_seen")
end

return StatsPage
