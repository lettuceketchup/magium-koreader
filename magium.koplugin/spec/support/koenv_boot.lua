-- koenv_boot.lua — isolate + bootstrap for the app-level E2E smoke
-- (spec/ui/main_e2e_smoke.lua, Phase V.5 item 1).
--
-- MUST be the FIRST require in that file: it points KO_HOME at a throwaway dir
-- *before* any KOReader module resolves DataStorage (datastorage.lua caches the
-- data dir on first getDataDir()). That keeps the real Persist blobs the E2E
-- harness writes — magium/state, magium/slots/NN.blob, trace-*.jsonl — out of
-- the emulator's own data dir and isolated per run.
--
-- Then it runs the same Screen bootstrap the *_smoke.lua files use (real
-- 1272x1696 under `mgm.sh test-ui-real`, else commonrequire's dummy 600x800).

local ffi = require("ffi")
ffi.cdef([[ int setenv(const char *name, const char *value, int overwrite); ]])

local lfs = require("libs/libkoreader-lfs")
local home = os.getenv("MAGIUM_E2E_HOME")
if not home or home == "" then
  math.randomseed(os.time() + os.clock() * 1e6)
  home = (os.getenv("TMPDIR") or "/tmp") .. "/magium-e2e-" .. os.time() .. "-" .. math.random(1, 1e9)
end
lfs.mkdir(home)
assert(ffi.C.setenv("KO_HOME", home, 1) == 0, "setenv KO_HOME failed")

if os.getenv("MAGIUM_REAL_SCREEN") then
  require("spec/support/real_screen")
else
  require("commonrequire")
end

-- sanity: the redirect took, and it is where DataStorage actually points
local DataStorage = require("datastorage")
assert(DataStorage:getDataDir() == home,
  "KO_HOME redirect missed: DataStorage at " .. DataStorage:getDataDir() .. ", wanted " .. home)

return { home = home }
