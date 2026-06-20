-- nxvim-help — vim-style `:help` for nxvim, built entirely on the native `nx.*`
-- plugin API (ADR 0002). It is an *optional* first-party plugin: install it and
-- `:help {topic}` works against every installed plugin's docs.
--
-- How help "registration" works (phase 1): there is no registration API. Any plugin
-- that ships a `doc/` directory with a `tags` file is already on the runtimepath
-- (`:Plugins` calls `nx._add_rtp`), so `nx.runtime_file("doc/tags", true)` discovers
-- all of them — exactly like dropping `doc/` into a neovim plugin. This plugin's own
-- docs are found the same way.
--
-- Module map:
--   index.lua    runtimepath tags scan + parse + merge + topic lookup
--   window.lua   render a resolved entry in a read-only help split
--
-- Quick start (init.lua): require("nxvim-help").setup() — then `:help nxvim-help`.

local index = require("nxvim-help.index")
local window = require("nxvim-help.window")
local helptags = require("nxvim-help.helptags")
local picker = require("nxvim-help.picker")
local tagstack = require("nxvim-help.tagstack")

local M = {}

-- Run an async body, surfacing any rejection as an error notification rather than an
-- unhandled promise error.
local function run(body)
  nx.async(body)():catch(function(e)
    local msg = type(e) == "table" and e.message or e
    nx.notify("nxvim-help: " .. tostring(msg), 4)
  end)
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- :help [topic] — with a topic, resolve it against the merged runtimepath tag index
-- and open it in the help split; with no topic, open the fuzzy topic picker. An
-- unknown topic is a loud, vim-style E149 (a user error, surfaced — never silent).
function M.help(topic)
  topic = topic and trim(topic) or ""
  if topic == "" then
    picker.open()
    return
  end
  run(function()
    local idx = nx.await(index.ensure())
    local entry = index.lookup(idx, topic)
    if not entry then
      nx.notify('E149: Sorry, no help for "' .. topic .. '"', 4)
      return
    end
    nx.await(window.show(entry))
  end)
end

-- :NxHelptags [dir] — write a vim-style doc/tags from doc/*.txt. No argument (or
-- "ALL") regenerates every doc/ dir on the runtimepath. Optional: the index already
-- reads .txt directly, so this is for interop/startup speed, not correctness. Named
-- :NxHelptags because nxvim core owns (a stub of) :helptags.
function M.helptags(dir)
  run(function()
    dir = dir and trim(dir) or ""
    local dirs
    if dir == "" or dir:upper() == "ALL" then
      dirs = helptags.doc_dirs()
    else
      dirs = { dir }
    end
    local total = 0
    for _, d in ipairs(dirs) do
      local res = nx.await(helptags.generate(d))
      total = total + res.count
      if #res.dupes > 0 then
        nx.notify("nxvim-help: duplicate tags in " .. d .. ": " .. table.concat(res.dupes, ", "), 3)
      end
    end
    index._index = nil -- invalidate the cache so the next :help sees the new tags
    nx.notify("nxvim-help: wrote tags for " .. #dirs .. " dir(s), " .. total .. " tags")
  end)
end

local did_setup = false

-- setup() — register the :help / :h commands and the help-buffer keymaps. Idempotent,
-- so the auto-loader (plugin/nxvim-help.lua) and a user's explicit call coexist.
function M.setup(_opts)
  if did_setup then
    return
  end
  did_setup = true

  -- nxvim core has no built-in :help, so this defines it; :h is the vim abbreviation.
  -- A core built-in (if one is ever added) takes precedence, so registering :h is safe.
  for _, name in ipairs({ "help", "h" }) do
    nx.user_command.create(name, function(a)
      M.help(a.args)
    end, { desc = "Open nxvim help for {topic}" })
  end

  -- :NxHelptags [dir|ALL] — (re)generate doc/tags. (:helptags is core-owned.)
  nx.user_command.create("NxHelptags", function(a)
    M.helptags(a.args)
  end, { desc = "Generate help tags from doc/*.txt ([dir] or ALL)" })

  -- Buffer-local maps for the help window, installed when a help buffer loads.
  nx.autocmd.create("FileType", {
    pattern = "help",
    callback = function()
      nx.keymap.set("n", "q", function()
        window.close()
      end, { buffer = 0, desc = "Close help" })
      -- Follow the tag under the cursor (vim binds both <C-]> and <CR> in help)…
      for _, lhs in ipairs({ "<C-]>", "<CR>" }) do
        nx.keymap.set("n", lhs, function()
          tagstack.follow()
        end, { buffer = 0, desc = "Follow help tag" })
      end
      -- …and pop back along the tag stack.
      nx.keymap.set("n", "<C-t>", function()
        tagstack.back()
      end, { buffer = 0, desc = "Back (help tag stack)" })
    end,
  })
end

return M
