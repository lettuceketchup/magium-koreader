-- real_screen.lua — KOReader test bootstrap like koreader's own
-- spec/unit/commonrequire.lua, BUT with a REAL SDL framebuffer at the owner's
-- device resolution (1272x1696 @ 300 dpi) instead of commonrequire's dummy
-- 600x800 buffer.
--
-- Why: commonrequire hardcodes `einkfb.dummy = true` before `Screen:init()`
-- (commonrequire.lua:22), and the dummy SDL3 framebuffer ALWAYS allocates a
-- 600x800 blitbuffer regardless of EMULATE_READER_W/H
-- (base/ffi/framebuffer_SDL3.lua:17). Every spec/ui/*_smoke.lua that does
-- `widget:paintTo(Screen.bb, ...)` under commonrequire therefore only ever
-- proved "doesn't crash", never "lays out correctly at the real width" — which
-- is exactly how the Phase V achievements-menu title-wrap bug passed the
-- emulator and only showed on device (research-plan.md 2026-09-04, session 30).
--
-- This requires a real X server: run it under `xvfb-run`. The `real-screen`
-- and `test-ui-real` mgm.sh commands do that. `mgm.sh koenv` / `test-ui` still
-- use the fast dummy path.
--
-- Mirrors commonrequire's other setup (G_defaults / G_reader_settings / dbg /
-- CanvasContext / Input.dummy / the package.* helpers) so a smoke file can
-- `require` exactly one of the two bootstraps and nothing else changes.

require("dbg"):turnOff()
local logger = require("logger")
logger:setLevel(logger.levels.warn)

local DataStorage = require("datastorage")
require("libs/libkoreader-lfs").mkdir(DataStorage:getHistoryDir())

os.remove(DataStorage:getDataDir() .. "/defaults.tests.lua")
os.remove(DataStorage:getDataDir() .. "/defaults.tests.lua.old")
G_defaults = require("luadefaults"):open(DataStorage:getDataDir() .. "/defaults.tests.lua")

os.remove(DataStorage:getDataDir() .. "/settings.tests.lua")
os.remove(DataStorage:getDataDir() .. "/settings.tests.lua.old")
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.tests.lua")
G_reader_settings:saveSetting("document_metadata_folder", "dir")

-- The one deviation from commonrequire: a REAL framebuffer. SDL3.lua:open()
-- reads EMULATE_READER_W/H (SDL3.lua:118-119); framebuffer.lua reads
-- EMULATE_READER_DPI (:128). mgm.sh's real-screen command exports all three at
-- the owner's PW12 profile before we get here; default them too so a bare
-- `luajit -e "dofile(...)"` still lands somewhere sane.
einkfb = require("ffi/framebuffer") --luacheck: ignore
einkfb.dummy = false --luacheck: ignore

local Device = require("device")
local Screen = Device.screen
Screen:init()

-- Fail loud if the real framebuffer did not come up at the requested size (a
-- silent fallback to some default would put us right back to testing the wrong
-- resolution — the whole point of this bootstrap).
local want_w = tonumber(os.getenv("EMULATE_READER_W")) or 1272
local want_h = tonumber(os.getenv("EMULATE_READER_H")) or 1696
assert(Screen:getWidth() == want_w and Screen:getHeight() == want_h,
  string.format("real_screen: got %dx%d, wanted %dx%d (no X server? run under xvfb-run / `mgm.sh real-screen`)",
    Screen:getWidth(), Screen:getHeight(), want_w, want_h))

local CanvasContext = require("document/canvascontext")
CanvasContext:init(Device)

local Input = Device.input
Input.dummy = true

package.unload = function(module)
    if type(module) ~= "string" then return false end
    package.loaded[module] = nil
    _G[module] = nil
    return true
end
package.replace = function(name, module)
    if type(name) ~= "string" then return false end
    assert(package.unload(name))
    package.loaded[name] = module
    return true
end
package.reload = function(name)
    if type(name) ~= "string" then return false end
    assert(package.unload(name))
    return require(name)
end

return { Screen = Screen }
