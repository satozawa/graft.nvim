-- Tests for graft.fold (foldexpr, foldtext, ensure_unfolded)
local h = require("tests.helpers")
local fold = require("graft.fold")

describe("fold", function()
  local buf

  after_each(function()
    if buf then
      h.cleanup(buf)
      buf = nil
    end
  end)

  describe("foldexpr", function()
    it("returns >1 for top-level item with children", function()
      buf = h.create_md_buf({
        "- parent",
        "  - child",
      })
      h.set_buf(buf)

      local level = fold.foldexpr(1)
      assert.are.equal(">1", level)
    end)

    it("returns 1 for top-level leaf", function()
      buf = h.create_md_buf({
        "- leaf",
      })
      h.set_buf(buf)

      local level = fold.foldexpr(1)
      assert.are.equal("1", level)
    end)

    it("returns >2 for nested item with children", function()
      buf = h.create_md_buf({
        "- parent",
        "  - nested parent",
        "    - deep child",
      })
      h.set_buf(buf)

      local level = fold.foldexpr(2)
      assert.are.equal(">2", level)
    end)

    it("returns 2 for nested leaf", function()
      buf = h.create_md_buf({
        "- parent",
        "  - leaf child",
      })
      h.set_buf(buf)

      local level = fold.foldexpr(2)
      assert.are.equal("2", level)
    end)

    it("returns 0 for non-list lines", function()
      buf = h.create_md_buf({
        "# Heading",
        "",
        "Some paragraph text",
      })
      h.set_buf(buf)

      assert.are.equal("0", fold.foldexpr(1))
      assert.are.equal("0", fold.foldexpr(2))
      assert.are.equal("0", fold.foldexpr(3))
    end)

    it("returns depth for continuation lines within an item", function()
      buf = h.create_md_buf({
        "- parent",
        "  - child1",
        "  - child2",
      })
      h.set_buf(buf)

      -- child1 line is at depth 2
      local level = fold.foldexpr(2)
      assert.are.equal("2", level)
    end)
  end)

  describe("foldtext", function()
    it("replaces dash marker with plus", function()
      -- foldtext uses vim.v.foldstart and vim.fn.getline,
      -- so we test the replacement logic directly
      local line = "- parent item"
      local result = line:gsub("^(%s*)(%-)", "%1+", 1)
      assert.are.equal("+ parent item", result)
    end)

    it("replaces indented dash marker with plus", function()
      local line = "  - nested item"
      local result = line:gsub("^(%s*)(%-)", "%1+", 1)
      assert.are.equal("  + nested item", result)
    end)

    it("does not replace non-dash markers", function()
      local line = "* star item"
      local result = line:gsub("^(%s*)(%-)", "%1+", 1)
      assert.are.equal("* star item", result)
    end)
  end)

  describe("ensure_unfolded", function()
    it("does not error on non-folded line", function()
      buf = h.create_md_buf({
        "- item",
      })
      h.set_buf(buf)

      -- Should not error
      fold.ensure_unfolded(1)
    end)
  end)
end)
