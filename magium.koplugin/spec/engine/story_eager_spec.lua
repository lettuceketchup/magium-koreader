local helper = require("spec/spec_helper")
local Story = require("engine/story")

local DATA_ROOT = helper.data_dir_en:gsub("/en$", "")  -- ".../data"

describe("Story (eager)", function()
  local story
  setup(function()
    story = Story.new{ data_dir = DATA_ROOT, locale = "en", strategy = "eager" }
    story:preload()
  end)

  it("loads the whole corpus", function()
    assert.are.equal(2159, story:count())
  end)

  it("returns a parsed scene by id", function()
    local s = story:get_scene("Ch1-Intro1")
    assert.are.equal("Ch1-Intro1", s.id)
    assert.are.equal(3, #s.choices)
  end)

  it("returns nil for an unknown id", function()
    assert.is_nil(story:get_scene("No-Such-Scene"))
  end)

  it("reports progress", function()
    local last = 0
    local s2 = Story.new{ data_dir = DATA_ROOT, locale = "en", strategy = "eager" }
    s2:preload(function(done, total) last = done; assert.are.equal(54, total) end)
    assert.are.equal(54, last)
  end)

  it("iterates every id once", function()
    local seen = {}
    for id in story:scene_ids() do
      assert.is_nil(seen[id])
      seen[id] = true
    end
    assert.are.equal(2159, (function() local n = 0 for _ in pairs(seen) do n = n + 1 end return n end)())
  end)
end)
