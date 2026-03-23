local helpers = require("tests.helpers")
local motions = require("graft.motions")

-- Sample nested markdown:
--   Line 1: "- alpha"
--   Line 2: "  - alpha.1"
--   Line 3: "    - alpha.1.1"
--   Line 4: "  - alpha.2"
--   Line 5: "- beta"
--   Line 6: "  - beta.1"
--   Line 7: "- gamma"
local function sample_lines()
  return {
    "- alpha",
    "  - alpha.1",
    "    - alpha.1.1",
    "  - alpha.2",
    "- beta",
    "  - beta.1",
    "- gamma",
  }
end

describe("motions", function()
  local buf

  before_each(function()
    buf = helpers.create_md_buf(sample_lines())
    helpers.set_buf(buf)
  end)

  after_each(function()
    helpers.cleanup(buf)
  end)

  describe("]g next_sibling", function()
    it("jumps from first to second top-level sibling", function()
      helpers.set_cursor(1, 0)
      motions.next_sibling()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 5, 0 }, pos)
    end)

    it("jumps from second to third top-level sibling", function()
      helpers.set_cursor(5, 0)
      motions.next_sibling()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 7, 0 }, pos)
    end)

    it("is a no-op at the last sibling", function()
      helpers.set_cursor(7, 0)
      motions.next_sibling()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 7, 0 }, pos)
    end)

    it("respects count (skip siblings)", function()
      helpers.set_cursor(1, 0)
      motions.next_sibling(2)
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 7, 0 }, pos)
    end)

    it("is a no-op when count exceeds available siblings", function()
      helpers.set_cursor(1, 0)
      motions.next_sibling(10)
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 1, 0 }, pos)
    end)

    it("works for nested siblings", function()
      helpers.set_cursor(2, 2)
      motions.next_sibling()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 4, 2 }, pos)
    end)
  end)

  describe("[g prev_sibling", function()
    it("jumps from last to second top-level sibling", function()
      helpers.set_cursor(7, 0)
      motions.prev_sibling()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 5, 0 }, pos)
    end)

    it("is a no-op at the first sibling", function()
      helpers.set_cursor(1, 0)
      motions.prev_sibling()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 1, 0 }, pos)
    end)

    it("respects count", function()
      helpers.set_cursor(7, 0)
      motions.prev_sibling(2)
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 1, 0 }, pos)
    end)

    it("is a no-op when count exceeds available siblings", function()
      helpers.set_cursor(5, 0)
      motions.prev_sibling(5)
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 5, 0 }, pos)
    end)

    it("works for nested siblings", function()
      helpers.set_cursor(4, 2)
      motions.prev_sibling()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 2, 2 }, pos)
    end)
  end)

  describe("]G first_child", function()
    it("jumps from parent to first child", function()
      helpers.set_cursor(1, 0)
      motions.first_child()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 2, 2 }, pos)
    end)

    it("is a no-op on a leaf item", function()
      helpers.set_cursor(7, 0)
      motions.first_child()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 7, 0 }, pos)
    end)

    it("respects count=2 to reach grandchild", function()
      helpers.set_cursor(1, 0)
      motions.first_child(2)
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 3, 4 }, pos)
    end)

    it("is a no-op when count exceeds nesting depth", function()
      helpers.set_cursor(1, 0)
      motions.first_child(10)
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 1, 0 }, pos)
    end)
  end)

  describe("[G parent", function()
    it("jumps from child to parent", function()
      helpers.set_cursor(2, 2)
      motions.parent()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 1, 0 }, pos)
    end)

    it("is a no-op at top-level", function()
      helpers.set_cursor(1, 0)
      motions.parent()
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 1, 0 }, pos)
    end)

    it("respects count=2 to go up two levels", function()
      helpers.set_cursor(3, 4)
      motions.parent(2)
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 1, 0 }, pos)
    end)

    it("is a no-op when count exceeds nesting depth", function()
      helpers.set_cursor(2, 2)
      motions.parent(5)
      local pos = vim.api.nvim_win_get_cursor(0)
      assert.are.same({ 2, 2 }, pos)
    end)
  end)

  describe("cursor outside list", function()
    it("all motions are no-ops when cursor is not on a list item", function()
      local text_buf = helpers.create_md_buf({ "# Heading", "", "Some paragraph text." })
      helpers.set_buf(text_buf)
      helpers.set_cursor(1, 0)

      motions.next_sibling()
      assert.are.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

      motions.prev_sibling()
      assert.are.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

      motions.first_child()
      assert.are.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

      motions.parent()
      assert.are.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

      helpers.cleanup(text_buf)
    end)
  end)
end)
