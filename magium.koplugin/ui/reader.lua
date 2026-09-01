-- ui/reader.lua — custom fullscreen paginated reading widget (spec §8, OQ-013).
-- Not TextViewer: a bespoke fullscreen FrameContainer with real pagination.

local BD = require("ui/bidi")  -- luacheck: ignore (kept per Task 17 brief requires)
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
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
local Choices = require("ui/choices")
local trace = require("util/trace")

local Reader = InputContainer:extend{
  render_model = nil,
  locale = nil,
  advance = nil,     -- function(button) -> new render_model (caller-supplied, Task 18)
  on_close = nil,    -- function()
  covers_fullscreen = true,
  page_idx = 1,
}

local PROSE_FACE = "cfont"
local PROSE_SIZE = 20
local HEAD_FACE = "tfont"
-- The on-screen close affordance (C1). The owner's Paperwhite 12 is keyless —
-- KindlePaperWhite6 sets no key caps and `hasKeys` defaults to `no`
-- (../koreader/frontend/device/generic/device.lua:92 @9192014) — so the
-- key_events block below never registers there and the header label + the
-- multiswipe are the ONLY ways out of a covers_fullscreen widget.
-- "‹" (U+2039) and the ASCII word both live in tfont = NotoSans-Bold.
local CLOSE_LABEL = "‹ Close"

function Reader:init()
  self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
  self.pad = Size.padding.large
  self.text_width = self.dimen.w - 2 * self.pad
  self.face = Font:getFace(PROSE_FACE, PROSE_SIZE)

  -- Header metrics first: both self.geometry AND the gesture bands below are
  -- derived from them, so they have to exist before _zone() is called.
  self.header_h = self:_header_height()
  -- The *tappable* band is the frame's top padding plus the header row: the
  -- header text is painted at y = self.pad (FrameContainer padding), so a band
  -- of only self.header_h would leave the bottom of the visible label outside
  -- the close zone. Still ends Size.padding.default before the page body starts
  -- (the VerticalSpan under the header is Size.padding.large > default).
  self.header_band_h = self.pad + self.header_h

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
    -- The header band closes; it sits strictly above both page-turn zones.
    TapClose = { GestureRange:new{ ges = "tap", range = Geom:new{
      x = 0, y = 0, w = self.dimen.w, h = self.header_band_h,
    } } },
    -- Any multiswipe closes, from anywhere — the escape hatch that does not
    -- depend on hitting a band (pattern: imageviewer.lua:135 + :622-627).
    MultiSwipe = { GestureRange:new{ ges = "multiswipe", range = self.dimen } },
  }

  local indicator_h = self:_indicator_height()
  self.geometry = {
    width = self.text_width,
    -- dimen.h minus: frame top+bottom padding (2*self.pad), the header row,
    -- the indicator row, and the two Size.padding.large VerticalSpans that
    -- _render() places above and below the page body.
    prose_height = self.dimen.h - self.header_h - indicator_h - 2 * self.pad - 2 * Size.padding.large,
    first_page_offset = self:_head_offset(),
  }
  self.pages = pagination.paginate(self.render_model, self.geometry, self:_measure_fn())
  self.page_idx = 1
  self:_render()
  UIManager:setDirty(self, refresh.on_open())
end

-- Shared prose measurer for pagination. Task 17 kept this closure inline in
-- init(); Task 18 needs the SAME measurement in _commit_choice() when a new
-- scene is re-paginated, so it lives in one place now. _build_page() appends one
-- Size.padding.default VerticalSpan after every block — fold it in so the
-- per-page budget stays honest on both the first and every subsequent scene.
function Reader:_measure_fn()
  return function(text, w)
    local tb = TextBoxWidget:new{ text = text, face = self.face, width = w }
    local h = tb:getSize().h
    tb:free()
    return h + Size.padding.default
  end
end

-- (helper methods _zone, _header_height, _indicator_height, _head_offset,
--  _render, _build_page, _build_header, _build_indicator)

-- Page-turn half. Starts BELOW the header band so a header tap can only be a
-- TapClose — InputContainer:onGesture iterates self.ges_events with pairs()
-- (../koreader/frontend/ui/widget/container/inputcontainer.lua:265 @9192014),
-- i.e. in undefined order, so overlapping tap ranges would resolve at random.
function Reader:_zone(side)
  local w = self.dimen.w
  return Geom:new{
    x = side == "left" and 0 or math.floor(w * 0.5), y = self.header_band_h,
    w = math.ceil(w * 0.5), h = self.dimen.h - self.header_band_h,
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

-- ONE line: [ ‹ Close ][ gap ][ Book N - Chapter M ], left-aligned. Deliberately
-- not a second row — _header_height() (one line + Size.padding.default) is the
-- number self.geometry and the TapClose band are both built from.
function Reader:_build_header()
  local close = TextWidget:new{ text = CLOSE_LABEL, face = Font:getFace(HEAD_FACE, 18) }
  local gap = Size.padding.large
  return HorizontalGroup:new{
    close,
    HorizontalSpan:new{ width = gap },
    TextWidget:new{
      text = self.render_model.header or "",
      face = Font:getFace(HEAD_FACE, 18),
      -- what is left of the text column after the close label + gap, so a long
      -- header is ellipsised instead of colliding with it
      max_width = math.max(1, self.text_width - close:getSize().w - gap),
    },
  }
end

function Reader:_build_indicator()
  local total = #self.pages
  local page = self.pages[self.page_idx]
  local label = page.kind == "choices" and "choices" or (self.page_idx .. " / " .. (total - 1))
  return TextWidget:new{ text = label, face = Font:getFace("ffont", 14) }
end

function Reader:_build_page()
  local page = self.pages[self.page_idx]
  if page.kind == "choices" then
    return Choices.build{
      buttons = page.buttons,
      width = self.text_width,
      show_parent = self,
      on_select = function(button) self:_commit_choice(button) end,
    }
  end
  local vg = VerticalGroup:new{ align = "left" }
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
  return vg
end

function Reader:_render()
  -- Reclaim the previous frame's blitbuffers before dropping the tree. Task 17
  -- deferred this; Task 18 re-renders on every choice commit (a whole new tree
  -- each hop through the story), so the leak now compounds — guard it here.
  if self[1] and self[1].free then self[1]:free() end
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
  trace.event("page_turn", { from = self.page_idx - delta, to = self.page_idx, total = #self.pages })
  self:_render()
  UIManager:setDirty(self, refresh.on_page_turn())
end

function Reader:onNextPage() self:_turn(1); return true end
function Reader:onPrevPage() self:_turn(-1); return true end
function Reader:onTapForward() self:_turn(1); return true end
function Reader:onTapBackward() self:_turn(-1); return true end

-- The two keyless exits (C1). Both route through onClose() so the on_close()
-- contract (autosave flush + trace flush) runs exactly once, in one place.
function Reader:onTapClose() self:onClose(); return true end
function Reader:onMultiSwipe(_, ges) self:onClose(); return true end  -- luacheck: ignore ges

function Reader:onClose()
  if self.on_close then self.on_close() end
  UIManager:close(self)
  return true
end

-- A choice button was tapped (ui/choices.lua callback). Commit sequence
-- (spec §8.1): the caller's `advance` applies the button's set_vars to the
-- store, moves v_current_scene, dispatches any `special`, and returns the new
-- scene's render_model. We then re-paginate that scene and show its page 1.
function Reader:_commit_choice(button)
  if not self.advance then return end
  local rm = self.advance(button)
  if not rm then return end
  self.render_model = rm
  -- refresh the first-page banner/stat-check offset for the NEW scene before
  -- re-paginating (init() sets this once from the opening scene).
  self.geometry.first_page_offset = self:_head_offset()
  self.pages = pagination.paginate(rm, self.geometry, self:_measure_fn())
  self.page_idx = 1
  self:_render()
  UIManager:setDirty(self, refresh.on_new_scene())
end

return Reader
