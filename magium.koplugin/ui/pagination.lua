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
      if used + h > budget and placed_any then break end
      page.blocks[#page.blocks + 1] = { type = "prose", text = blocks[i] }
      used = used + h
      placed_any = true
      i = i + 1
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
