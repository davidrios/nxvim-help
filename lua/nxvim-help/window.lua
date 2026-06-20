-- nxvim-help.window — render a resolved help entry in a read-only split.
--
-- The help buffer is an `nx.view` (the sanctioned read-only, mountable line surface):
-- we read the target `.txt`, set its lines, mount it in a split, and jump the cursor
-- to the tag's `*anchor*` via `View:set_cursor` (the one sanctioned cursor write).
-- A singleton handle is reused across `:help` calls so a second lookup reuses the
-- same window instead of stacking splits.

local highlight = require("nxvim-help.highlight")

local M = {}

local view = nil -- the singleton help view handle
local mounted = false -- whether the view is currently shown
local current = nil -- the entry currently displayed (for the tag stack)

-- The 1-based line of the `*tag*` anchor in `lines`, or 1 if absent. Vim's tag
-- address is a `/*tag*` search; for phase 1 we locate the literal anchor directly.
local function anchor_line(lines, tag)
  local needle = "*" .. tag .. "*"
  for i, l in ipairs(lines) do
    if l:find(needle, 1, true) then
      return i
    end
  end
  return 1
end

-- Split text into lines without a synthetic trailing blank from a final newline.
local function split_lines(text)
  local out = {}
  local start = 1
  while true do
    local nl = text:find("\n", start, true)
    if not nl then
      if #text >= start then
        out[#out + 1] = text:sub(start)
      end
      break
    end
    out[#out + 1] = text:sub(start, nl - 1)
    start = nl + 1
  end
  return out
end

-- Open `entry` in the help split. Jumps to `line` if given (used to restore position
-- when popping the tag stack), else to the tag's `*anchor*`. Async (reads the file).
function M.show(entry, line)
  return nx.async(function()
    local text = nx.await(nx.fs.read_text(entry.file))
    local lines = split_lines(text)
    if not view then
      view = nx.view.create({ name = "[Help]", filetype = "help" })
    end
    view:set_lines(lines)
    if not mounted then
      view:mount({ split = "split" })
      mounted = true
    else
      view:focus()
    end
    view:set_cursor(line or anchor_line(lines, entry.name))
    current = entry
    -- Syntax highlighting (cosmetic): apply once the backing buffer exists. Don't
    -- block the show on it; surface a failure rather than swallowing it.
    highlight.apply_to_view(view, lines):catch(function(e)
      nx.notify(
        "nxvim-help: highlight failed: " .. tostring(type(e) == "table" and e.message or e),
        4
      )
    end)
    return view
  end)()
end

-- The entry currently displayed (nil before first show), so the tag stack can record
-- where a jump came from.
function M.current()
  return current
end

-- Close the help split (keeps the handle for reuse).
function M.close()
  if view and mounted then
    view:unmount()
    mounted = false
  end
end

-- ----- test seams -------------------------------------------------------------

-- The help view's backing buffer number (nil before first show), for tests.
function M.bufnr()
  return view and view:bufnr()
end

-- The help view's 1-based cursor line (nil while unfocused), for tests.
function M.line()
  return view and view:line()
end

-- Tear down the singleton entirely so a test starts from a clean slate.
function M._reset()
  if view then
    view:close()
  end
  view = nil
  mounted = false
  current = nil
end

return M
