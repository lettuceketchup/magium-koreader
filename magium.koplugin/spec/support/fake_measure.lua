-- Deterministic stand-in for a TextBoxWidget-backed measurer: 20px per wrapped
-- line, ~40 chars per line at the test width.
return function(text, width)
  local chars_per_line = math.max(1, math.floor(width / 10))
  local lines = 0
  for para in (text .. "\n"):gmatch("(.-)\n") do
    lines = lines + math.max(1, math.ceil(#para / chars_per_line))
  end
  return lines * 20
end
