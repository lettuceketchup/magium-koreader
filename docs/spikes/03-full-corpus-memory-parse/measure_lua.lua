-- measure_lua.lua — Lua-side counterpart to
-- reference/tools/measure-story-size.js: parses the FULL 54-file English
-- corpus with the spike 02 parser (docs/spikes/02-engine-in-lua/magium_parser.lua,
-- reused unmodified — this is also a much stronger fidelity check on that
-- port than the 6-fixture diff, since 51 more files' worth of set()/choice()/
-- #if()/achievement() lines now flow through the same hand-written matchers),
-- and reports parse time + Lua-heap memory the same way.
--
-- Usage: luajit measure_lua.lua [path-to-magium-dev/data/en] [runs]
--
-- CAVEAT (matches F-24's on the JS side): this runs on this container's x86
-- core under stock LuaJIT 2.1, not the Kindle's ~1 GHz MTK ARM core under
-- koreader-base's LuaJIT build. It is a desktop anchor for the parse-time
-- question, not the on-device answer — see FINDING.md.

package.path = "../02-engine-in-lua/?.lua;" .. package.path
local parser = require("magium_parser")

local function list_magium_files(dir)
  local files = {}
  local p = io.popen('ls "' .. dir .. '"/*.magium 2>/dev/null')
  for line in p:lines() do table.insert(files, line) end
  p:close()
  table.sort(files)
  return files
end

local function file_size(path)
  local f = io.open(path, "rb")
  local size = f:seek("end")
  f:close()
  return size
end

local dataDir = arg[1] or "/home/user/magium-dev/data/en"
local runs = tonumber(arg[2] or "5")
local files = list_magium_files(dataDir)
if #files == 0 then
  io.stderr:write("no .magium files found in " .. dataDir .. "\n")
  os.exit(2)
end

local totalDisk = 0
for _, f in ipairs(files) do totalDisk = totalDisk + file_size(f) end

-- Parse once to get structural counts (and to prove nothing crashes on the
-- full corpus, not just the 3-file slice spike 02 was validated on).
local story = {}
for _, f in ipairs(files) do
  for id, scene in pairs(parser.parse(f)) do story[id] = scene end
end
local scenes, paragraphs, choices, setVars, achievements = 0, 0, 0, 0, 0
for _, scene in pairs(story) do
  scenes = scenes + 1
  paragraphs = paragraphs + #scene.paragraphs
  choices = choices + #scene.choices
  setVars = setVars + #scene.setVariables
  achievements = achievements + #scene.achievements
end
story = nil
collectgarbage("collect")

-- Timing runs (report min/median, matching how a warm-vs-cold spread would
-- show up; LuaJIT's tracing JIT means run 1 can be slower than steady-state).
local times = {}
for i = 1, runs do
  collectgarbage("collect")
  local t0 = os.clock()
  local s = {}
  for _, f in ipairs(files) do
    for id, scene in pairs(parser.parse(f)) do s[id] = scene end
  end
  local t1 = os.clock()
  table.insert(times, (t1 - t0) * 1000)
  s = nil
end
table.sort(times)

-- Memory: parse once more and hold the result, measuring the Lua GC heap
-- delta (collectgarbage("count") is in KB).
collectgarbage("collect")
local memBefore = collectgarbage("count")
local held = {}
for _, f in ipairs(files) do
  for id, scene in pairs(parser.parse(f)) do held[id] = scene end
end
collectgarbage("collect")
local memAfter = collectgarbage("count")

print("engine:             " .. (jit and ("LuaJIT " .. jit.version) or _VERSION))
print(string.format("files:              %d", #files))
print(string.format("disk:               %.2f MB", totalDisk / 1048576))
print(string.format("scenes:             %d", scenes))
print(string.format("paragraphs:         %d", paragraphs))
print(string.format("choices:            %d", choices))
print(string.format("set() directives:   %d", setVars))
print(string.format("achievements:       %d", achievements))
print(string.format("parse times (ms):   " .. table.concat((function()
  local out = {}
  for _, t in ipairs(times) do table.insert(out, string.format("%.1f", t)) end
  return out
end)(), ", ")))
print(string.format("parse time min/med: %.1f / %.1f ms  (os.clock CPU time, %d runs, this container's x86 core)",
  times[1], times[math.ceil(#times / 2)], runs))
print(string.format("parsed mem delta:   %.2f MB  (Lua GC heap, collectgarbage(\"count\"))", (memAfter - memBefore) / 1024))
