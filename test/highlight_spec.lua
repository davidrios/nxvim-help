-- Help-buffer highlighting: opening a topic places extmarks for tags, links,
-- headings and delimiters. Run with `nxvim --test-plugin`.

local help = require("nxvim-help")
local window = require("nxvim-help.window")
local highlight = require("nxvim-help.highlight")
local index = require("nxvim-help.index")

-- The set of hl_groups currently marked on `buf` under our namespace.
local function marked_groups(buf)
  local groups = {}
  for _, mk in ipairs(nx.buf.extmarks(buf, highlight.ns, 0, -1, { details = true })) do
    local d = mk[4]
    if d and d.hl_group then
      groups[d.hl_group] = true
    end
  end
  return groups
end

nx.test.describe("nxvim-help highlight", function()
  nx.test.before_each(function()
    window._reset()
    index._index = nil
    help.setup()
  end)

  nx.test.after_each(function()
    window._reset()
  end)

  nx.test.it("marks tags, links, headings and delimiters when a topic opens", function(t)
    help.help("nxvim-help") -- the front page has all four
    local buf = t:wait_for(function()
      return window.bufnr()
    end)
    local groups = t:wait_for(function()
      local g = marked_groups(buf)
      -- wait until highlighting has been applied (it lands a tick after the buffer)
      return next(g) and g
    end)
    nx.test.expect(groups["nxHelpTag"]).to_be_truthy()
    nx.test.expect(groups["nxHelpLink"]).to_be_truthy()
    nx.test.expect(groups["nxHelpHeadline"]).to_be_truthy()
    nx.test.expect(groups["nxHelpDelim"]).to_be_truthy()
  end)

  nx.test.it("marks a *target* span at its exact byte columns", function(t)
    help.help("nxvim-help")
    local buf = t:wait_for(function()
      return window.bufnr()
    end)
    -- wait for marks, then slice each nxHelpTag span out of its line and confirm it
    -- is exactly a *…* run (columns line up).
    local sliced = t:wait_for(function()
      local found = {}
      for _, mk in ipairs(nx.buf.extmarks(buf, highlight.ns, 0, -1, { details = true })) do
        local row, col, d = mk[2], mk[3], mk[4]
        if d and d.hl_group == "nxHelpTag" then
          local line = nx.buf.lines(buf, row, row + 1, false)[1] or ""
          found[#found + 1] = line:sub(col + 1, d.end_col)
        end
      end
      return #found > 0 and found
    end)
    for _, s in ipairs(sliced) do
      nx.test.expect(s:sub(1, 1)).to_be("*")
      nx.test.expect(s:sub(-1)).to_be("*")
    end
  end)
end)
