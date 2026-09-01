-- Spec bootstrap. Two jobs, both trivial:
--   1. prepend the plugin root to package.path so require("engine/...") /
--      require("ui/...") resolve under bare luajit (busted runs from
--      magium.koplugin/);
--   2. return the two data-dir paths specs need — the plugin's own data/en, and
--      the magium-dev corpus used as the differential oracle (overridable with
--      MAGIUM_DEV_EN).
-- It stubs nothing: the pure layer never touches a KOReader global.
package.path = "./?.lua;./?/init.lua;" .. package.path

return {
  data_dir_en = "./data/en",
  magium_dev_en = os.getenv("MAGIUM_DEV_EN") or
    "/mnt/f/Projects/Magium - Kindle/magium-dev/data/en",
}
