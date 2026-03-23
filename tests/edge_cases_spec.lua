-- Edge case tests across multiple graft modules
local h = require("tests.helpers")
local tree = require("graft.tree")
local operations = require("graft.operations")
local bullets = require("graft.bullets")

describe("edge cases", function()
  local buf

  after_each(function()
    if buf then
      h.cleanup(buf)
      buf = nil
    end
  end)

  describe("deep nesting", function()
    it("promotes from depth 5", function()
      buf = h.create_md_buf({
        "- L1",
        "  - L2",
        "    - L3",
        "      - L4",
        "        - L5",
      })
      h.set_buf(buf)
      vim.bo[buf].shiftwidth = 2
      h.set_cursor(5, 8) -- on L5
      operations._do_promote()

      local lines = h.get_lines(buf)
      assert.are.equal("      - L5", lines[5])
    end)

    it("moves deeply nested sibling up", function()
      buf = h.create_md_buf({
        "- L1",
        "  - L2",
        "    - L3a",
        "    - L3b",
      })
      h.set_buf(buf)
      h.set_cursor(4, 4) -- on L3b
      operations._do_move_up()

      local lines = h.get_lines(buf)
      assert.are.same({
        "- L1",
        "  - L2",
        "    - L3b",
        "    - L3a",
      }, lines)
    end)
  end)

  describe("checkbox within list", function()
    it("checks nested checkbox", function()
      buf = h.create_md_buf({
        "- parent",
        "  - [ ] nested task",
      })
      h.set_buf(buf)
      h.set_cursor(2, 4)
      bullets.check()

      local lines = h.get_lines(buf)
      assert.are.equal("  - [x] nested task", lines[2])
    end)

    it("unchecks nested checkbox", function()
      buf = h.create_md_buf({
        "- parent",
        "  - [x] nested done",
      })
      h.set_buf(buf)
      h.set_cursor(2, 4)
      bullets.uncheck()

      local lines = h.get_lines(buf)
      assert.are.equal("  - [ ] nested done", lines[2])
    end)
  end)

  describe("single item list", function()
    it("enter creates sibling after single item", function()
      buf = h.create_md_buf({
        "- only item",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.enter_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- only item",
        "- ",
      }, lines)
    end)

    it("o creates sibling for single leaf", function()
      buf = h.create_md_buf({
        "- only item",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.o_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- only item",
        "- ",
      }, lines)
    end)
  end)

  describe("mixed markers", function()
    it("preserves star marker on enter", function()
      buf = h.create_md_buf({
        "* star item",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.enter_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.equal("* star item", lines[1])
      assert.are.equal("* ", lines[2])
    end)

    it("preserves plus marker on enter", function()
      buf = h.create_md_buf({
        "+ plus item",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.enter_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.equal("+ plus item", lines[1])
      assert.are.equal("+ ", lines[2])
    end)
  end)
end)
