-- ~~~ Runnable demo for nxvim-help ~~~
--
-- Run it from a checkout that sits next to your nxvim checkout:
--
--     NXVIM_CONFIG=examples cargo run -p nxvim -- README.md
--
-- TRY IT:
--   :help                         fuzzy-find a topic (the picker) — type to filter,
--                                 <C-n>/<C-p> move, <CR> opens, <Esc> cancels
--   :help nxvim-help              open this plugin's help at the top
--   :help nxvim-help-usage        jump straight to a tagged section
--   :help nxvim-help-u            prefix match resolves to …-usage
--   :h nxvim-help-registering     :h is the abbreviation
--   q                             (in the help window) close it
--   :help totally-made-up         a loud E149 — no silent no-op
--
-- The plugin auto-registers :help when it loads (plugin/nxvim-help.lua calls
-- setup()), and discovers its own doc/ via the runtimepath — the same path any
-- other installed plugin's doc/ is found on.

-- Load the plugin straight from this repo (a local-dev spec: `dir` is never cloned).
-- A real config would instead use `{ "davidrios/nxvim-help" }` and `:PluginSync`.
nx.plugins({
  {
    name = "nxvim-help",
    dir = vim.fn.expand("<sfile>:p:h:h"), -- the repo root (this file's grandparent dir)
    config = function()
      -- Opt into K = help for the word under the cursor. Put the cursor on a word
      -- like "nxvim-help-usage" (anywhere) and press K.
      require("nxvim-help").setup({ keywordprg = true })
    end,
  },
})
