-- Convenience: run only the engine-layer specs (pure, no KOReader, fastest).
-- Usage: luajit spec/run.lua      (from inside magium.koplugin/)
os.exit(os.execute("busted spec/engine") and 0 or 1)
