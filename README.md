# nxvim-help

Vim-style **`:help`** for [nxvim](https://github.com/davidrios/nxvim) — an optional
first-party plugin built entirely on the native `nx.*` plugin API (ADR 0002): no core
changes, no buffer-mutation hacks. Help lives in a read-only
[`nx.view`](https://github.com/davidrios/nxvim) split, topics resolve through a tag
index merged across the runtimepath, and the file is read with the promise `nx.fs`
API.

```
:help                       fuzzy-find a topic (the picker)
:help nxvim-help            open help for a topic
:h nxvim-help-usage         :h is the abbreviation
CTRL-] / <CR>               (in help) follow the tag under the cursor
CTRL-T                      (in help) jump back along the tag stack
q                           (in the help window) close it
```

## How plugins register help

**There is no registration API.** Any plugin that ships a `doc/` directory is
discovered automatically — exactly like dropping `doc/` into a neovim plugin.
`:Plugins` already puts every installed plugin on the runtimepath, so
`nx.runtime_file` finds every `doc/` (this plugin's own docs included).

**A `tags` file is optional.** If a `doc/` has one it is used (fast, and readable by
vim); otherwise nxvim-help derives the `*targets*` straight from `doc/*.txt`, so help
works with zero setup. A `tags` file is one line per `*target*`:

```
my-topic	my-plugin.txt	/*my-topic*
```

i.e. `tag<Tab>file<Tab>address`, with `file` relative to its `doc/` directory.
Generate one with `:NxHelptags [dir]` (no arg / `ALL` does every `doc/` on the
runtimepath) — named `:NxHelptags` because nxvim core owns `:helptags`.

Topic lookup is exact-first, then the shortest prefix match (`:help my-to` →
`my-topic`); an unknown topic is a loud vim-style `E149`.

> Because nxvim-help is **optional**, a plugin's `doc/` is only *viewable* when the
> user has installed nxvim-help. The docs ship harmlessly regardless.

## Install

```lua
-- in your init.lua
nx.plugins({ { "davidrios/nxvim-help" } })
-- :help works on load; require("nxvim-help").setup() is optional (idempotent).
```

## Try it

```sh
NXVIM_CONFIG=examples cargo run -p nxvim -- README.md
# then :help nxvim-help
```

## Tests

Pure-Lua [`nx.test`](https://github.com/davidrios/nxvim) specs that drive a real
editor over a temp filesystem:

```sh
nxvim --test-plugin .
```

`test/index_spec.lua` covers tag parsing / merge / lookup; `test/helptags_spec.lua`
covers target extraction, tags generation and the tags-optional scan; and
`test/window_spec.lua` covers real runtimepath discovery (no tags file) and opening a
topic at its anchor.

## Status

Done: runtimepath discovery (tags file optional — derived from `doc/*.txt` when
absent), `:help {topic}` / `:h` opening a topic at its tag in a read-only split,
prefix resolution, a fuzzy-finder topic picker on bare `:help` (`nx.picker`), in-help
tag following (`<C-]>` / `<CR>` follow, `<C-t>` back), syntax highlighting of
headings / `*targets*` / `|links|` / `` `code` `` (extmark groups linked to standard
highlights), `q` to close, and `:NxHelptags [dir|ALL]` tag generation.

Planned: `K` / `keywordprg`.
