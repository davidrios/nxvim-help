-- nxvim-help.picker — fuzzy-find a help topic with nx.picker.
--
-- This is the primary discovery UX: bare `:help` (no topic) opens a picker over every
-- known tag, fuzzy-matched as you type; <CR> opens the highlighted topic. It replaces
-- vim's command-line tag completion (nxvim user commands have no completer hook) with
-- something better.

local index = require("nxvim-help.index")
local window = require("nxvim-help.window")

local M = {}

-- Run an async body, surfacing a rejection as an error notification.
local function run(body)
  nx.async(body)():catch(function(e)
    local msg = type(e) == "table" and e.message or e
    nx.notify("nxvim-help: " .. tostring(msg), 4)
  end)
end

-- 1-based line of the `*tag*` anchor within `text` (1 if absent) — where the location
-- preview should sit for that topic.
local function anchor_row(text, tag)
  local pos = text:find("*" .. tag .. "*", 1, true)
  if not pos then
    return 1
  end
  local _, n = text:sub(1, pos):gsub("\n", "")
  return n + 1
end

-- Stream every known tag as a picker item. `text` is the tag (what the matcher sees
-- and shows); `entry` carries its index entry for confirm; `path`/`row`/`col` drive the
-- "location" preview (the file scrolled to the tag's anchor). Sorted for a stable list.
-- Async: builds the index, then reads each doc file once to locate its anchors.
function M.items(ctx)
  return nx.async(function()
    local idx = nx.await(index.ensure())
    local tags = {}
    for tag in pairs(idx) do
      tags[#tags + 1] = tag
    end
    table.sort(tags)
    -- Read each file at most once; many tags share one file.
    local cache = {}
    local function text_of(file)
      if cache[file] == nil then
        local ok, t = pcall(nx.await, nx.fs.read_text(file))
        cache[file] = (ok and t) or ""
      end
      return cache[file]
    end
    for _, tag in ipairs(tags) do
      local entry = idx[tag]
      ctx.push({
        text = tag,
        entry = entry,
        path = entry.file,
        row = anchor_row(text_of(entry.file), tag),
        col = 1,
      })
    end
  end)()
end

-- Open the chosen topic in the help window.
function M.confirm(item)
  run(function()
    nx.await(window.show(item.entry))
  end)
end

-- Register the source (idempotent — keyed by name; a re-require overwrites). Named
-- nxvim_help so it can't clash with a built-in source.
nx.picker.source({
  name = "nxvim_help",
  items = M.items,
  confirm = M.confirm,
  preview = "location", -- preview the doc scrolled to the highlighted topic
})

-- Open the help-topic picker.
function M.open()
  nx.picker.open("nxvim_help")
end

return M
