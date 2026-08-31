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
  return self
end

function Locale:str(key) return self.strings[key] end

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
