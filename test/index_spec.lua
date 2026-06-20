-- The tag index: discovery/parse over a real (temp) filesystem, plus pure lookup.
-- Run with `nxvim --test-plugin`.
--
-- build_from() awaits nx.fs, and an `it` body already runs inside an nx.async
-- coroutine, so we drive it directly. parse_into/lookup are pure and need no fs.

local index = require("nxvim-help.index")
local fs = nx.fs

local function write(path, text)
  nx.await(fs.write(path, text))
end

-- A tags file body (real tabs) for a fake plugin whose doc/ lives at `dir`.
local function tags_body()
  return table.concat({
    "!_TAG_FILE_SORTED\t1\t", -- a ctags pragma line; must be skipped
    "alpha\talpha.txt\t/*alpha*",
    "alpha-sub\talpha.txt\t/*alpha-sub*",
    "beta\tbeta.txt\t/*beta*",
    "",
  }, "\n")
end

nx.test.describe("nxvim-help.index", function()
  local DIR

  nx.test.before_each(function()
    DIR = nx.test.tempdir()
    write(DIR .. "/tags", tags_body())
  end)

  nx.test.it("parses a tags file, skipping pragmas, resolving paths against its dir", function()
    local idx = nx.await(index.build_from({ DIR .. "/tags" }))
    nx.test.expect(idx["alpha"].file).to_be(DIR .. "/alpha.txt")
    nx.test.expect(idx["beta"].file).to_be(DIR .. "/beta.txt")
    nx.test.expect(idx["alpha"].name).to_be("alpha")
    -- the !_TAG_ pragma is not a tag
    nx.test.expect(idx["!_TAG_FILE_SORTED"]).to_be_falsy()
  end)

  nx.test.it("merges multiple tags files; first on the path wins", function()
    local other = nx.test.tempdir()
    write(other .. "/tags", "alpha\tother.txt\t/*alpha*\ngamma\tgamma.txt\t/*gamma*\n")
    -- DIR first, so its alpha wins over `other`'s; gamma still merges in.
    local idx = nx.await(index.build_from({ DIR .. "/tags", other .. "/tags" }))
    nx.test.expect(idx["alpha"].file).to_be(DIR .. "/alpha.txt")
    nx.test.expect(idx["gamma"].file).to_be(other .. "/gamma.txt")
  end)

  nx.test.it("looks up an exact tag", function()
    local idx = nx.await(index.build_from({ DIR .. "/tags" }))
    nx.test.expect(index.lookup(idx, "beta").name).to_be("beta")
  end)

  nx.test.it("falls back to the shortest prefix match", function()
    local idx = nx.await(index.build_from({ DIR .. "/tags" }))
    -- "alph" matches both alpha and alpha-sub; the shorter tag wins.
    nx.test.expect(index.lookup(idx, "alph").name).to_be("alpha")
  end)

  nx.test.it("returns nil for an unknown topic", function()
    local idx = nx.await(index.build_from({ DIR .. "/tags" }))
    nx.test.expect(index.lookup(idx, "nope")).to_be_falsy()
  end)
end)
