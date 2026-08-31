-- ui/pagination.lua — split a render_model into screen-sized pages.
-- PURE: no KOReader. measure_fn is injected (real caller wraps TextBoxWidget).

local M = {}

local function prose_blocks(paragraphs)
  -- Each render_model paragraph is one string with <br/> runs; split into
  -- display blocks on the blank-line marker <br/><br/>, keep single <br/> as \n.
  local blocks = {}
  for _, para in ipairs(paragraphs) do
    for chunk in (para .. "<br/><br/>"):gmatch("(.-)<br/><br/>") do
      local text = chunk:gsub("<br/>", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      if text ~= "" then blocks[#blocks + 1] = text end
    end
  end
  return blocks
end

-- Largest leading run of whitespace-delimited words of `text` that fits in
-- `budget` px at `width`. Always returns at least one word so pagination makes
-- progress on any budget. Returns head_text, rest_text; rest_text is nil when
-- the whole text fit (and then head_text is the ORIGINAL text, internal \n and
-- all — only a split tail is re-joined on spaces).
local function fit_words(text, width, budget, measure_fn)
  local words = {}
  for w in text:gmatch("%S+") do words[#words + 1] = w end
  if #words == 0 then return text, nil end
  local n = 1
  while n < #words do
    if measure_fn(table.concat(words, " ", 1, n + 1), width) > budget then break end
    n = n + 1
  end
  if n >= #words then return text, nil end
  return table.concat(words, " ", 1, n), table.concat(words, " ", n + 1)
end

function M.paginate(render_model, geometry, measure_fn)
  local pages = {}
  local width = geometry.width

  -- page 1 head blocks (banner + stat checks) — rendered once, on page 1.
  local head = {}
  if render_model.checkpoint then
    head[#head + 1] = { type = "banner", text = "checkpoint" }
  end
  for _, sc in ipairs(render_model.stat_checks) do
    head[#head + 1] = { type = "stat_check", text = sc.text, success = sc.success }
  end

  local blocks = prose_blocks(render_model.paragraphs)
  local i = 1
  local first = true
  while i <= #blocks do
    local budget = geometry.prose_height - (first and geometry.first_page_offset or 0)
    local page = { kind = "prose", blocks = {} }
    if first then
      for _, h in ipairs(head) do page.blocks[#page.blocks + 1] = h end
    end
    local used = 0
    local placed_any = false
    while i <= #blocks do
      local h = measure_fn(blocks[i], width)
      if used + h <= budget then
        page.blocks[#page.blocks + 1] = { type = "prose", text = blocks[i] }
        used = used + h
        placed_any = true
        i = i + 1
      elseif placed_any then
        break   -- doesn't fit here; retry it whole on a fresh page
      else
        -- this block alone exceeds the page: split at word boundaries, the
        -- tail rides the next page(s). (placed_any is false here => used == 0.)
        local htext, rest = fit_words(blocks[i], width, budget, measure_fn)
        page.blocks[#page.blocks + 1] = { type = "prose", text = htext }
        placed_any = true
        if rest then blocks[i] = rest else i = i + 1 end
        break
      end
    end
    pages[#pages + 1] = page
    first = false
  end

  -- if there was no prose at all but there are head blocks, still show page 1.
  if #pages == 0 and #head > 0 then
    pages[1] = { kind = "prose", blocks = head }
  end

  -- the trailing choices page (always present in Phase I — every scene has choices).
  local buttons = {}
  for _, c in ipairs(render_model.choices) do
    buttons[#buttons + 1] = {
      label = c.text, target = c.target,
      set_vars = c.set_variables, special = c.special,
    }
  end
  pages[#pages + 1] = { kind = "choices", buttons = buttons }

  return pages
end

return M
