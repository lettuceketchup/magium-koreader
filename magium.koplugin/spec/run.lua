-- Convenience: run the pure specs (no KOReader frontend needed) under bare
-- luajit — engine, save, and the headless flow/playthrough harness.
-- Usage: luajit spec/run.lua      (from inside magium.koplugin/)
-- os.execute returns a number on Lua 5.1/LuaJIT (0 = success, and 0 is truthy),
-- a boolean on 5.2+. Normalize both.
local ok = os.execute("busted spec/engine spec/save spec/flow")
os.exit((ok == true or ok == 0) and 0 or 1)
