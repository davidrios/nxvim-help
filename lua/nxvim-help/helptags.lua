-- nxvim-help.helptags — extract *targets* from help text and (optionally) write a
-- vim-style `doc/tags` file, like vim's :helptags.
--
-- A generated `tags` file is *optional*: the index (index.lua) derives the same
-- targets directly from `doc/*.txt` for any dir that lacks one, so help works with
-- zero setup. Writing the file is an interop/speed convenience — vim and other tools
-- can read it, and parsing one tab-separated file is cheaper than scanning every .txt.
--
-- nxvim core owns `:helptags` (a stub), so this exposes generation as a Lua function
-- and the non-colliding `:NxHelptags` command instead.

local M = {}

-- Every `*target*` on `text`. A help tag is `*…*` whose body is printable ASCII minus
-- space, tab, '*' and '"' — vim's tag character set. The first `*` must be adjacent to
-- a non-space (so "a * b *" and bullet "*" lines never match), matching vim. Returns a
-- list in file order (duplicates within the file preserved for the caller to report).
function M.targets(text)
  local out = {}
  for tag in text:gmatch('%*([^ \t*"]+)%*') do
    out[#out + 1] = tag
  end
  return out
end

-- Escape a tag for the `/…/` search address column: only the chars that would break
-- the search — backslash and the slash delimiter. Mirrors vim's loose form
-- (`/*quickref.txt*` leaves the `.` unescaped).
local function esc(tag)
  return (tag:gsub("[\\/]", "\\%0"))
end

-- The unique doc/ directories on the runtimepath that ship help text — i.e. the dirs
-- :NxHelptags (no arg / ALL) regenerates. Derived from the `doc/*.txt` glob, so a dir
-- with only a stale tags file (no .txt) is skipped (nothing to regenerate from).
function M.doc_dirs()
  local seen, out = {}, {}
  for _, p in ipairs(nx.runtime_file("doc/*.txt", true) or {}) do
    local dir = (p:gsub("/[^/]*$", ""))
    if not seen[dir] then
      seen[dir] = true
      out[#out + 1] = dir
    end
  end
  return out
end

-- Generate `dir/tags` from every `dir/*.txt`. Async. Returns
-- { count = <#tags>, dupes = { <tag>, … }, files = <#txt> }. A duplicate tag (same
-- tag in two files, or twice in one) keeps the first and is reported — surfaced loud
-- by the caller, never silently dropped (matching vim's "duplicate tag" warning).
function M.generate(dir)
  return nx.async(function()
    local entries = nx.await(nx.fs.readdir(dir))
    local names = {}
    for _, e in ipairs(entries) do
      if e.type ~= "directory" and e.name:sub(-4) == ".txt" then
        names[#names + 1] = e.name
      end
    end
    table.sort(names)

    local seen = {} -- tag -> first file
    local dupes = {}
    local tags = {} -- { { tag, file }, … }
    for _, name in ipairs(names) do
      local text = nx.await(nx.fs.read_text(dir .. "/" .. name))
      for _, tag in ipairs(M.targets(text)) do
        if seen[tag] then
          dupes[#dupes + 1] = tag
        else
          seen[tag] = name
          tags[#tags + 1] = { tag, name }
        end
      end
    end
    -- vim writes the tags file sorted (it binary-searches it).
    table.sort(tags, function(a, b)
      return a[1] < b[1]
    end)

    local lines = {}
    for _, t in ipairs(tags) do
      lines[#lines + 1] = t[1] .. "\t" .. t[2] .. "\t/*" .. esc(t[1]) .. "*"
    end
    local body = #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
    nx.await(nx.fs.write(dir .. "/tags", body))
    return { count = #tags, dupes = dupes, files = #names }
  end)()
end

return M
