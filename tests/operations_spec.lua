-- Tests for graft.operations (move up / move down)
local h = require("tests.helpers")
local operations = require("graft.operations")

describe("operations", function()
  local buf

  after_each(function()
    if buf then
      h.cleanup(buf)
      buf = nil
    end
  end)

  -- Helper: set up a buffer, place cursor, call an operation, return resulting lines
  local function run_op(lines, cursor_row, op_fn)
    buf = h.create_md_buf(lines)
    h.set_buf(buf)
    h.set_cursor(cursor_row)
    op_fn()
    return h.get_lines(buf)
  end

  describe("move_down", function()
    it("swaps current item with next sibling in a flat list", function()
      local result = run_op({
        "- alpha",
        "- beta",
        "- gamma",
      }, 1, operations._do_move_down)

      assert.are.same({
        "- beta",
        "- alpha",
        "- gamma",
      }, result)
    end)

    it("swaps the second item down to third position", function()
      local result = run_op({
        "- alpha",
        "- beta",
        "- gamma",
      }, 2, operations._do_move_down)

      assert.are.same({
        "- alpha",
        "- gamma",
        "- beta",
      }, result)
    end)

    it("is a no-op when cursor is on the last sibling", function()
      local result = run_op({
        "- alpha",
        "- beta",
        "- gamma",
      }, 3, operations._do_move_down)

      assert.are.same({
        "- alpha",
        "- beta",
        "- gamma",
      }, result)
    end)

    it("moves a subtree with children as a unit", function()
      local result = run_op({
        "- parent1",
        "  - child1a",
        "  - child1b",
        "- parent2",
      }, 1, operations._do_move_down)

      assert.are.same({
        "- parent2",
        "- parent1",
        "  - child1a",
        "  - child1b",
      }, result)
    end)

    it("moves past a subtree that has children", function()
      local result = run_op({
        "- parent1",
        "- parent2",
        "  - child2a",
        "  - child2b",
        "- parent3",
      }, 1, operations._do_move_down)

      assert.are.same({
        "- parent2",
        "  - child2a",
        "  - child2b",
        "- parent1",
        "- parent3",
      }, result)
    end)

    it("places cursor on the moved item's new position", function()
      buf = h.create_md_buf({
        "- alpha",
        "- beta",
        "- gamma",
      })
      h.set_buf(buf)
      h.set_cursor(1)
      operations._do_move_down()

      local row = vim.api.nvim_win_get_cursor(0)[1]
      -- "alpha" was at row 1, moved down past "beta" -> now at row 2
      assert.are.equal(2, row)
    end)

    it("places cursor correctly when moving a multi-line subtree down", function()
      buf = h.create_md_buf({
        "- parent1",
        "  - child1",
        "- parent2",
      })
      h.set_buf(buf)
      h.set_cursor(1) -- cursor on "parent1"
      operations._do_move_down()

      local row = vim.api.nvim_win_get_cursor(0)[1]
      -- parent1 (2 lines) was above parent2 (1 line). After swap:
      -- row 1: parent2, row 2: parent1, row 3: child1
      -- cursor should follow parent1 to row 2
      assert.are.equal(2, row)
    end)
  end)

  describe("move_up", function()
    it("swaps current item with previous sibling in a flat list", function()
      local result = run_op({
        "- alpha",
        "- beta",
        "- gamma",
      }, 2, operations._do_move_up)

      assert.are.same({
        "- beta",
        "- alpha",
        "- gamma",
      }, result)
    end)

    it("swaps the third item up to second position", function()
      local result = run_op({
        "- alpha",
        "- beta",
        "- gamma",
      }, 3, operations._do_move_up)

      assert.are.same({
        "- alpha",
        "- gamma",
        "- beta",
      }, result)
    end)

    it("is a no-op when cursor is on the first sibling", function()
      local result = run_op({
        "- alpha",
        "- beta",
        "- gamma",
      }, 1, operations._do_move_up)

      assert.are.same({
        "- alpha",
        "- beta",
        "- gamma",
      }, result)
    end)

    it("moves a subtree with children as a unit", function()
      local result = run_op({
        "- parent1",
        "- parent2",
        "  - child2a",
        "  - child2b",
      }, 2, operations._do_move_up)

      assert.are.same({
        "- parent2",
        "  - child2a",
        "  - child2b",
        "- parent1",
      }, result)
    end)

    it("moves past a subtree that has children", function()
      local result = run_op({
        "- parent1",
        "  - child1a",
        "  - child1b",
        "- parent2",
        "- parent3",
      }, 4, operations._do_move_up)

      assert.are.same({
        "- parent2",
        "- parent1",
        "  - child1a",
        "  - child1b",
        "- parent3",
      }, result)
    end)

    it("places cursor on the moved item's new position", function()
      buf = h.create_md_buf({
        "- alpha",
        "- beta",
        "- gamma",
      })
      h.set_buf(buf)
      h.set_cursor(3)
      operations._do_move_up()

      local row = vim.api.nvim_win_get_cursor(0)[1]
      -- "gamma" was at row 3, moved up past "beta" -> now at row 2
      assert.are.equal(2, row)
    end)

    it("places cursor correctly when moving up past a multi-line subtree", function()
      buf = h.create_md_buf({
        "- parent1",
        "  - child1",
        "- parent2",
      })
      h.set_buf(buf)
      h.set_cursor(3) -- cursor on "parent2"
      operations._do_move_up()

      local row = vim.api.nvim_win_get_cursor(0)[1]
      -- parent2 (1 line) was below parent1 (2 lines). After swap:
      -- row 1: parent2, row 2: parent1, row 3: child1
      -- cursor should follow parent2 to row 1
      assert.are.equal(1, row)
    end)
  end)

  describe("move in ordered list", function()
    it("renumbers after move_down", function()
      local result = run_op({
        "1. first",
        "2. second",
        "3. third",
      }, 1, operations._do_move_down)

      assert.are.same({
        "1. second",
        "2. first",
        "3. third",
      }, result)
    end)

    it("renumbers after move_up", function()
      local result = run_op({
        "1. first",
        "2. second",
        "3. third",
      }, 3, operations._do_move_up)

      assert.are.same({
        "1. first",
        "2. third",
        "3. second",
      }, result)
    end)
  end)

  describe("promote", function()
    it("decreases indent of subtree by shiftwidth", function()
      buf = h.create_md_buf({
        "- outer",
        "  - inner",
        "    - deep",
      })
      h.set_buf(buf)
      vim.bo[buf].shiftwidth = 2
      h.set_cursor(2, 2) -- on "inner"
      operations._do_promote()

      local lines = h.get_lines(buf)
      assert.are.same({
        "- outer",
        "- inner",
        "  - deep",
      }, lines)
    end)

    it("is a no-op at top level", function()
      local result = run_op({
        "- top level",
        "  - child",
      }, 1, operations._do_promote)

      assert.are.same({
        "- top level",
        "  - child",
      }, result)
    end)

    it("promotes all descendants together", function()
      buf = h.create_md_buf({
        "- root",
        "  - parent",
        "    - child1",
        "    - child2",
        "      - grandchild",
      })
      h.set_buf(buf)
      vim.bo[buf].shiftwidth = 2
      h.set_cursor(2, 2) -- on "parent"
      operations._do_promote()

      local lines = h.get_lines(buf)
      assert.are.same({
        "- root",
        "- parent",
        "  - child1",
        "  - child2",
        "    - grandchild",
      }, lines)
    end)
  end)

  describe("demote", function()
    it("increases indent of subtree by shiftwidth", function()
      buf = h.create_md_buf({
        "- first",
        "- second",
      })
      h.set_buf(buf)
      vim.bo[buf].shiftwidth = 2
      h.set_cursor(2, 0)
      operations._do_demote()

      local lines = h.get_lines(buf)
      assert.are.same({
        "- first",
        "  - second",
      }, lines)
    end)

    it("demotes all descendants together", function()
      buf = h.create_md_buf({
        "- first",
        "- second",
        "  - child",
      })
      h.set_buf(buf)
      vim.bo[buf].shiftwidth = 2
      h.set_cursor(2, 0) -- on "second"
      operations._do_demote()

      local lines = h.get_lines(buf)
      assert.are.same({
        "- first",
        "  - second",
        "    - child",
      }, lines)
    end)
  end)

  describe("boundary and edge cases", function()
    it("is a no-op when cursor is not on a list item", function()
      local result = run_op({
        "# Heading",
        "",
        "- alpha",
        "- beta",
      }, 1, operations._do_move_down)

      assert.are.same({
        "# Heading",
        "",
        "- alpha",
        "- beta",
      }, result)
    end)

    it("handles a single-item list (no siblings)", function()
      local result = run_op({
        "- only item",
      }, 1, operations._do_move_down)

      assert.are.same({
        "- only item",
      }, result)
    end)

    it("moves nested items independently from outer list", function()
      -- Cursor on child2 at col 2 (on the marker, not col 0 which is
      -- whitespace inside the parent's range and finds the wrong node)
      buf = h.create_md_buf({
        "- parent",
        "  - child1",
        "  - child2",
      })
      h.set_buf(buf)
      h.set_cursor(3, 2) -- col 2 = on the "-" of child2
      operations._do_move_up()
      local result = h.get_lines(buf)

      assert.are.same({
        "- parent",
        "  - child2",
        "  - child1",
      }, result)
    end)

    it("swaps multi-line subtrees bidirectionally (both have children)", function()
      local result = run_op({
        "- parent1",
        "  - child1a",
        "- parent2",
        "  - child2a",
        "  - child2b",
      }, 1, operations._do_move_down)

      assert.are.same({
        "- parent2",
        "  - child2a",
        "  - child2b",
        "- parent1",
        "  - child1a",
      }, result)
    end)
  end)
end)
