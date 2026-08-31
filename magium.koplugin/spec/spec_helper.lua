-- Prepend the plugin root so require("engine/...") resolves under bare luajit.
-- Also stub the two KOReader globals a pure spec might transitively touch via
-- vendored code (none currently do — this is a guard rail, kept minimal).
package.path = "./?.lua;./?/init.lua;" .. package.path

return {
  data_dir_en = "./data/en",
  magium_dev_en = os.getenv("MAGIUM_DEV_EN") or
    "/mnt/f/Projects/Magium - Kindle/magium-dev/data/en",
}
