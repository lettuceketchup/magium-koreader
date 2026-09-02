-- engine/locale.lua — ui.json strings, header derivation, stat-check templates.
-- Port of the getHeaderFromId + ui.json usage in magium-dev @ 51f5aa9.
-- PURE: Lua stdlib + engine/vendor/json.

local json = require("engine/vendor/json")

local Locale = {}
Locale.__index = Locale

local function read_file(path)
  local f = assert(io.open(path, "r"), "cannot open " .. path)
  local s = f:read("*a")
  f:close()
  return s
end

function Locale.load(data_dir, lang)
  local self = setmetatable({}, Locale)
  self.lang = lang
  self.strings = json.decode(read_file(data_dir .. "/" .. lang .. "/ui.json"))

  -- Phase V: achievements{1,2,3}.json, one per book. json.decode doesn't
  -- preserve key order, but the achievements menu needs on-disk declaration
  -- order (b2ch41/b2ch42 are declared inline between b2ch3/b2ch5 in the
  -- source data — a numeric sort of the chapter digits would NOT reproduce
  -- that). All top-level keys match "bNchM":, so one gmatch pass over the
  -- raw text per book recovers the order cheaply.
  self.achievements = {}
  self._achievement_order = {}
  for book = 1, 3 do
    local raw = read_file(data_dir .. "/" .. lang .. "/achievements" .. book .. ".json")
    self.achievements[book] = json.decode(raw)
    local order = {}
    for key in raw:gmatch('"(b%d+ch%d+)"%s*:') do order[#order + 1] = key end
    self._achievement_order[book] = order
  end

  return self
end

function Locale:str(key) return self.strings[key] end

function Locale:achievement_book_count() return #self.achievements end

-- Ordered group keys for one book, in on-disk declaration order.
function Locale:achievement_chapters(book_n)
  return self._achievement_order[book_n]
end

-- Raw [{title, caption, chapter, variable}, ...] for one group key.
function Locale:achievement_entries(book_n, key)
  return self.achievements[book_n][key]
end

-- The title for a single achievement variable, e.g. for a special-case unlock
-- that has no in-story achievement() call to source render_model text from
-- (v_ac_ch6_immersion — stats.ejs:175-190, not main.ejs's per-scene loop).
function Locale:achievement_title(variable)
  for book = 1, #self.achievements do
    for _, key in ipairs(self._achievement_order[book]) do
      for _, e in ipairs(self.achievements[book][key]) do
        if e.variable == variable then return e.title end
      end
    end
  end
end

-- <%= name %> interpolation (the only EJS feature ui.json templates use).
local function interp(tmpl, vars)
  return (tmpl:gsub("<%%=%s*([%w_]+)%s*%%>", function(k) return tostring(vars[k]) end))
end

local function collapse_ws(s)
  return (s:gsub("&nbsp;", " "):gsub("[ \t\f\v]+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Locale:header(scene_id)
  local book, chapter = scene_id:match("^B(%d*)%-Ch(%d*)[a-c]?%-")
  if not chapter then
    chapter = scene_id:match("^Ch(%d*)[a-c]?%-")
  end
  if not chapter or chapter == "" then return nil end
  book = (book ~= nil and book ~= "") and book or "1"
  local tmpl = self.strings.mainHeaderTemplate or "Book <%= book %> - Chapter <%= chapter %>"
  return collapse_ws(interp(tmpl, { book = book, chapter = tostring(tonumber(chapter)) }))
end

function Locale:stat_check_text(sc)
  if sc.variable == "v_b3_ch1_unlock" then
    return collapse_ws(self.strings.mainStatDeviceLockedText or "[ Stat device locked - check failed ]")
  end
  local tmpl = sc.success and self.strings.mainStatSuccessTemplate or self.strings.mainStatFailedTemplate
  return collapse_ws(interp(tmpl, { variable = sc.variable, value = sc.value }))
end

return Locale
