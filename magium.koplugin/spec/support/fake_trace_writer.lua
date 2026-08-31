-- Plain-function trace double (matches the real injected shape): captures the
-- JSONL lines and the mirrored log messages.
local M = {}
function M.new()
  local w = { lines = {}, logs = {} }
  w.writer = function(line) w.lines[#w.lines + 1] = line end
  w.log = function(msg) w.logs[#w.logs + 1] = msg end
  return w
end
return M
