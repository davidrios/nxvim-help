# nxvim-help

Vim-style **`:help`** for [nxvim](https://github.com/davidrios/nxvim) — an optional
first-party plugin built entirely on the native `nx.*` plugin API (ADR 0002): no core
changes, no buffer-mutation hacks. Help lives in a read-only
[`nx.view`](https://github.com/davidrios/nxvim) split, topics resolve through a tag
index merged across the runtimepath, and the file is read with the promise `nx.fs`
API.

```
:help nxvim-help            open help for a topic
:help                       open the front page
:h nxvim-help-usage         :h is the abbreviation
q                           (in the help window) close it
```

## How plugins register help

**There is no registration API.** Any plugin that ships a `doc/` directory with a
`tags` file is discovered automatically — exactly like dropping `doc/` into a neovim
plugin. `:Plugins` already puts every installed plugin on the runtimepath, so
`nx.runtime_file("doc/tags", true)` finds them all (this plugin's own docs included).

A `tags` file is one line per `*target*`:

```
my-topic	my-plugin.txt	/*my-topic*
```

i.e. `tag<Tab>file<Tab>address`, with `file` relative to the `doc/` directory holding
the `tags` file. Topic lookup is exact-first, then the shortest prefix match
(`:help my-to` → `my-topic`); an unknown topic is a loud vim-style `E149`.

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

`test/index_spec.lua` covers tag parsing / merge / lookup; `test/window_spec.lua`
covers real runtimepath discovery and opening a topic at its anchor.

## Status

Phase 1 (this release): runtimepath tag discovery, `:help {topic}` / `:h` opening a
topic at its tag in a read-only split, prefix resolution, `q` to close.

Planned: a fuzzy-finder topic picker (`nx.picker`), `:helptags [ALL]` generation from
`doc/*.txt`, in-help tag following (`<C-]>` / `<C-t>`), syntax highlighting of
`*targets*` / `|links|`, and `K` / `keywordprg`.
