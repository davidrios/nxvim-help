-- nxvim-help.tagstack — follow the help tag under the cursor (`<C-]>` / `<CR>`) and
-- return along the stack (`<C-t>`), like vim's help.
--
-- The stack is plain Lua state, independent of the editor's jumplist (a tag stack is
-- a distinct concept in vim). Each follow records where it jumped from; each back pops
-- and restores that exact position.

local index = require("nxvim-help.index")
local window = require("nxvim-help.window")

local M = {}

local stack = {}

local function run(body)
  nx.async(body)():catch(function(e)
    local msg = type(e) == "table" and e.message or e
    nx.notify("nxvim-help: " .. tostring(msg), 4)
  end)
end

-- The help tag at byte column `col` (0-based) in `line`. A `|hot-link|` or `*target*`
-- the cursor sits within yields its inner text; otherwise the maximal run of non-space,
-- non-`|`, non-`*` characters around the cursor, with trailing sentence punctuation
-- trimmed. Returns nil when the cursor is on a separator.
function M.tag_at(line, col)
  local c = col + 1 -- 1-based

  -- A delimiter pair (| … | or * … *) the cursor is inside → its inner text.
  for _, d in ipairs({ "|", "*" }) do
    local i = 1
    while true do
      local s = line:find(d, i, true)
      if not s then
        break
      end
      local e = line:find(d, s + 1, true)
      if not e then
        break
      end
      if c >= s and c <= e then
        local inner = line:sub(s + 1, e - 1)
        if inner ~= "" and not inner:find("[%s|*]") then
          return inner
        end
      end
      i = e + 1
    end
  end

  -- Otherwise the word under the cursor.
  local function sep(ch)
    return ch == "" or ch:find("[%s|*]") ~= nil
  end
  if c < 1 or c > #line or sep(line:sub(c, c)) then
    return nil
  end
  local lo, hi = c, c
  while lo > 1 and not sep(line:sub(lo - 1, lo - 1)) do
    lo = lo - 1
  end
  while hi < #line and not sep(line:sub(hi + 1, hi + 1)) do
    hi = hi + 1
  end
  local word = line:sub(lo, hi):gsub("[%.,;:%)%]]+$", "")
  return word ~= "" and word or nil
end

-- Follow the tag under the cursor: resolve it, push the current location, and open it.
function M.follow()
  run(function()
    if not window.bufnr() then
      return
    end
    local pos = nx.cursor.get()
    local tag = M.tag_at(nx.current_line(), pos[2])
    if not tag then
      nx.notify("nxvim-help: no help tag under the cursor", 3)
      return
    end
    local entry = index.lookup(nx.await(index.ensure()), tag)
    if not entry then
      nx.notify('E149: Sorry, no help for "' .. tag .. '"', 4)
      return
    end
    local from = window.current()
    if from then
      stack[#stack + 1] = { entry = from, line = window.line() }
    end
    nx.await(window.show(entry))
  end)
end

-- Pop the tag stack: return to the location the last follow jumped from.
function M.back()
  run(function()
    local top = stack[#stack]
    if not top then
      nx.notify("nxvim-help: tag stack empty", 3)
      return
    end
    stack[#stack] = nil
    nx.await(window.show(top.entry, top.line))
  end)
end

-- Clear the stack (tests).
function M._reset()
  stack = {}
end

return M
