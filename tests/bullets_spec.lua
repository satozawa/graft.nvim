-- Tests for graft.bullets (Enter, o, O, checkbox toggle)
local h = require("tests.helpers")
local bullets = require("graft.bullets")

describe("bullets", function()
  local buf

  after_each(function()
    if buf then
      h.cleanup(buf)
      buf = nil
    end
  end)

  describe("enter_normal", function()
    it("creates sibling after subtree (subtree skip)", function()
      buf = h.create_md_buf({
        "- parent",
        "  - child1",
        "  - child2",
        "- sibling",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.enter_normal()
      -- Stop insert mode for assertion
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- parent",
        "  - child1",
        "  - child2",
        "- ",
        "- sibling",
      }, lines)
    end)

    it("creates sibling after leaf (no children)", function()
      buf = h.create_md_buf({
        "- alpha",
        "- beta",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.enter_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- alpha",
        "- ",
        "- beta",
      }, lines)
    end)

    it("inherits unordered marker type", function()
      buf = h.create_md_buf({
        "* item",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.enter_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "* item",
        "* ",
      }, lines)
    end)

    it("increments ordered marker", function()
      buf = h.create_md_buf({
        "1. first",
        "2. second",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.enter_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      -- After renumbering, the new item gets correct number
      assert.are.equal("1. first", lines[1])
      assert.are.equal("2. ", lines[2])
    end)

    it("produces unchecked checkbox from checkbox line", function()
      buf = h.create_md_buf({
        "- [x] done task",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.enter_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- [x] done task",
        "- [ ] ",
      }, lines)
    end)

    it("preserves indent level", function()
      buf = h.create_md_buf({
        "- parent",
        "  - child",
      })
      h.set_buf(buf)
      h.set_cursor(2, 2)
      bullets.enter_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- parent",
        "  - child",
        "  - ",
      }, lines)
    end)
  end)

  describe("enter_insert", function()
    it("removes empty bullet and exits insert", function()
      buf = h.create_md_buf({
        "- first",
        "- ",
      })
      h.set_buf(buf)
      h.set_cursor(2, 2)
      vim.cmd("startinsert")
      bullets.enter_insert()

      local lines = h.get_lines(buf)
      assert.are.same({
        "- first",
      }, lines)

      local mode = vim.api.nvim_get_mode().mode
      assert.are.equal("n", mode)
    end)

    it("splits text at cursor position", function()
      buf = h.create_md_buf({
        "- hello world",
      })
      h.set_buf(buf)
      h.set_cursor(1, 7) -- after "hello "
      vim.cmd("startinsert")
      bullets.enter_insert()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- hello",
        "- world",
      }, lines)
    end)
  end)

  describe("o_normal", function()
    it("creates child when parent has children", function()
      buf = h.create_md_buf({
        "- parent",
        "  - existing child",
      })
      h.set_buf(buf)
      vim.bo[buf].shiftwidth = 2
      h.set_cursor(1, 0)
      bullets.o_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- parent",
        "  - ",
        "  - existing child",
      }, lines)
    end)

    it("creates sibling when on leaf", function()
      buf = h.create_md_buf({
        "- leaf1",
        "- leaf2",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.o_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- leaf1",
        "- ",
        "- leaf2",
      }, lines)
    end)

    it("creates checkbox child from checkbox parent", function()
      buf = h.create_md_buf({
        "- [x] parent task",
        "  - sub-task",
      })
      h.set_buf(buf)
      vim.bo[buf].shiftwidth = 2
      h.set_cursor(1, 0)
      bullets.o_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- [x] parent task",
        "  - [ ] ",
        "  - sub-task",
      }, lines)
    end)

    it("creates unordered child from numbered parent", function()
      buf = h.create_md_buf({
        "1. numbered parent",
        "   - existing child",
      })
      h.set_buf(buf)
      vim.bo[buf].shiftwidth = 2
      h.set_cursor(1, 0)
      bullets.o_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      -- Child should be "- " not "1. "
      assert.are.equal("  - ", lines[2])
    end)
  end)

  describe("o_upper_normal", function()
    it("creates sibling above with same marker", function()
      buf = h.create_md_buf({
        "- alpha",
        "- beta",
      })
      h.set_buf(buf)
      h.set_cursor(2, 0)
      bullets.o_upper_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- alpha",
        "- ",
        "- beta",
      }, lines)
    end)

    it("creates unchecked checkbox above checked line", function()
      buf = h.create_md_buf({
        "- [x] done",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.o_upper_normal()
      vim.cmd("stopinsert")

      local lines = h.get_lines(buf)
      assert.are.same({
        "- [ ] ",
        "- [x] done",
      }, lines)
    end)
  end)

  describe("checkbox", function()
    it("checks an unchecked checkbox", function()
      buf = h.create_md_buf({
        "- [ ] todo",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.check()

      local lines = h.get_lines(buf)
      assert.are.equal("- [x] todo", lines[1])
    end)

    it("unchecks a checked checkbox", function()
      buf = h.create_md_buf({
        "- [x] done",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.uncheck()

      local lines = h.get_lines(buf)
      assert.are.equal("- [ ] done", lines[1])
    end)

    it("is a no-op on non-checkbox lines", function()
      buf = h.create_md_buf({
        "- plain bullet",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.check()

      local lines = h.get_lines(buf)
      assert.are.equal("- plain bullet", lines[1])
    end)

    it("is a no-op when check called on already checked", function()
      buf = h.create_md_buf({
        "- [x] done",
      })
      h.set_buf(buf)
      h.set_cursor(1, 0)
      bullets.check()

      local lines = h.get_lines(buf)
      assert.are.equal("- [x] done", lines[1])
    end)
  end)
end)
