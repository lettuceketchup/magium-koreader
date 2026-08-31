-- ui/reader.lua — custom fullscreen paginated reading widget (spec §8, OQ-013).
-- Not TextViewer: a bespoke fullscreen FrameContainer with real pagination.

local BD = require("ui/bidi")  -- luacheck: ignore (kept per Task 17 brief requires)
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen
local pagination = require("ui/pagination")
local refresh = require("ui/refresh")

local Reader = InputContainer:extend{
  render_model = nil,
  locale = nil,
  on_choice = nil,   -- function(button)
  on_close = nil,    -- function()
  covers_fullscreen = true,
  page_idx = 1,
}

local PROSE_FACE = "cfont"
local PROSE_SIZE = 20
local HEAD_FACE = "tfont"

function Reader:init()
  self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
  self.pad = Size.padding.large
  self.text_width = self.dimen.w - 2 * self.pad
  self.face = Font:getFace(PROSE_FACE, PROSE_SIZE)

  if Device:hasKeys() then
    self.key_events = {
      NextPage = { { Device.input.group.PgFwd } },
      PrevPage = { { Device.input.group.PgBack } },
      Close = { { Device.input.group.Back } },
    }
  end
  self.ges_events = {
    TapForward = { GestureRange:new{ ges = "tap", range = self:_zone("right") } },
    TapBackward = { GestureRange:new{ ges = "tap", range = self:_zone("left") } },
  }

  local header_h = self:_header_height()
  local indicator_h = self:_indicator_height()
  self.geometry = {
    width = self.text_width,
    -- dimen.h minus: frame top+bottom padding (2*self.pad), the header row,
    -- the indicator row, and the two Size.padding.large VerticalSpans that
    -- _render() places above and below the page body.
    prose_height = self.dimen.h - header_h - indicator_h - 2 * self.pad - 2 * Size.padding.large,
    first_page_offset = self:_head_offset(),
  }
  self.pages = pagination.paginate(self.render_model, self.geometry, function(text, w)
    local tb = TextBoxWidget:new{ text = text, face = self.face, width = w }
    local h = tb:getSize().h
    tb:free()
    -- _build_page() appends one Size.padding.default VerticalSpan after every
    -- block; fold it into the measurement so the budget stays honest.
    return h + Size.padding.default
  end)
  self.page_idx = 1
  self:_render()
  UIManager:setDirty(self, refresh.on_open())
end

-- (helper methods _zone, _header_height, _indicator_height, _head_offset,
--  _render, _build_page, _build_header, _build_indicator)

function Reader:_zone(side)
  local w = self.dimen.w
  return Geom:new{
    x = side == "left" and 0 or math.floor(w * 0.5), y = 0,
    w = math.ceil(w * 0.5), h = self.dimen.h,
  }
end

function Reader:_line_height(face_name, size)
  local tw = TextWidget:new{ text = "Ag", face = Font:getFace(face_name, size) }
  local h = tw:getSize().h
  tw:free()
  return h
end

function Reader:_header_height()
  return self:_line_height(HEAD_FACE, 18) + Size.padding.default
end

function Reader:_indicator_height()
  return self:_line_height("ffont", 14) + Size.padding.default
end

function Reader:_head_offset()
  -- rough px for banner + stat-check lines on page 1
  local n = (self.render_model.checkpoint and 1 or 0) + #self.render_model.stat_checks
  if n == 0 then return 0 end
  return n * (self:_line_height(HEAD_FACE, 16) + Size.padding.default) + Size.padding.default
end

function Reader:_build_header()
  return TextWidget:new{
    text = self.render_model.header or "",
    face = Font:getFace(HEAD_FACE, 18),
    max_width = self.text_width,
  }
end

function Reader:_build_indicator()
  local total = #self.pages
  local page = self.pages[self.page_idx]
  local label = page.kind == "choices" and "choices" or (self.page_idx .. " / " .. (total - 1))
  return TextWidget:new{ text = label, face = Font:getFace("ffont", 14) }
end

function Reader:_build_page()
  local vg = VerticalGroup:new{ align = "left" }
  local page = self.pages[self.page_idx]
  if page.kind == "choices" then
    for _, b in ipairs(page.buttons) do
      table.insert(vg, TextWidget:new{
        text = "> " .. b.label, face = self.face, max_width = self.text_width,
      })
      table.insert(vg, VerticalSpan:new{ width = Size.padding.default })
    end
  else
    for _, blk in ipairs(page.blocks) do
      if blk.type == "banner" then
        table.insert(vg, TextWidget:new{
          text = self.locale:str("mainCheckpointReachedText") or "[ Checkpoint reached: Game saved. ]",
          face = Font:getFace(HEAD_FACE, 16),
        })
      elseif blk.type == "stat_check" then
        table.insert(vg, TextWidget:new{ text = blk.text, face = Font:getFace(HEAD_FACE, 16) })
      else
        table.insert(vg, TextBoxWidget:new{
          text = blk.text, face = self.face, width = self.text_width,
          alignment = "left",
        })
      end
      table.insert(vg, VerticalSpan:new{ width = Size.padding.default })
    end
  end
  return vg
end

function Reader:_render()
  self[1] = FrameContainer:new{
    background = Blitbuffer.COLOR_WHITE,
    bordersize = 0,
    padding = self.pad,
    width = self.dimen.w,
    height = self.dimen.h,
    VerticalGroup:new{
      align = "left",
      self:_build_header(),
      VerticalSpan:new{ width = Size.padding.large },
      self:_build_page(),
      VerticalSpan:new{ width = Size.padding.large },
      self:_build_indicator(),
    },
  }
end

function Reader:_turn(delta)
  local next_idx = self.page_idx + delta
  if next_idx < 1 or next_idx > #self.pages then return end
  self.page_idx = next_idx
  self:_render()
  UIManager:setDirty(self, refresh.on_page_turn())
end

function Reader:onNextPage() self:_turn(1); return true end
function Reader:onPrevPage() self:_turn(-1); return true end
function Reader:onTapForward() self:_turn(1); return true end
function Reader:onTapBackward() self:_turn(-1); return true end

function Reader:onClose()
  if self.on_close then self.on_close() end
  UIManager:close(self)
  return true
end

-- Task 18 overrides this to open the real choice widget / commit a choice.
function Reader:onChoiceSelected(button)
  if self.on_choice then self.on_choice(button) end
  return true
end

return Reader
