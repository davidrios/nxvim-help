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

-- Stream every known tag as a picker item — `text` is the tag (what the matcher sees
-- and shows), `entry` carries its index entry for confirm. Sorted for a stable list.
-- Async: it builds the index first (the engine awaits the returned promise).
function M.items(ctx)
  return nx.async(function()
    local idx = nx.await(index.ensure())
    local tags = {}
    for tag in pairs(idx) do
      tags[#tags + 1] = tag
    end
    table.sort(tags)
    for _, tag in ipairs(tags) do
      ctx.push({ text = tag, entry = idx[tag] })
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
})

-- Open the help-topic picker.
function M.open()
  nx.picker.open("nxvim_help")
end

return M
