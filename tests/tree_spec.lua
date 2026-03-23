local helpers = require("tests.helpers")

describe("tree", function()
  local tree = require("graft.tree")

  local sample_nested = {
    "- alpha",
    "  - beta",
    "    - gamma",
    "  - delta",
    "- epsilon",
  }

  local sample_flat = {
    "- one",
    "- two",
    "- three",
  }

  local sample_task = {
    "- [x] done",
    "- [ ] todo",
  }

  local sample_ordered = {
    "1. first",
    "2. second",
    "3. third",
  }

  describe("get_list_item_at_cursor", function()
    it("finds list_item when cursor is on marker line", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      assert.is_not_nil(node)
      assert.are.equal("list_item", node:type())
      helpers.cleanup(buf)
    end)

    it("finds list_item when cursor is on nested item", function()
      local buf = helpers.create_md_buf(sample_nested)
      helpers.set_buf(buf)
      helpers.set_cursor(2, 4)
      local node = tree.get_list_item_at_cursor(buf)
      assert.is_not_nil(node)
      assert.are.equal("list_item", node:type())
      helpers.cleanup(buf)
    end)

    it("returns nil when cursor is not in a list", function()
      local buf = helpers.create_md_buf({ "# heading", "", "some text" })
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      assert.is_nil(node)
      helpers.cleanup(buf)
    end)
  end)

  describe("get_subtree_range", function()
    it("returns single line for leaf item", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local start_row, end_row = tree.get_subtree_range(node)
      assert.are.equal(0, start_row)
      assert.are.equal(0, end_row)
      helpers.cleanup(buf)
    end)

    it("returns full range for item with children", function()
      local buf = helpers.create_md_buf(sample_nested)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local start_row, end_row = tree.get_subtree_range(node)
      assert.are.equal(0, start_row)
      assert.are.equal(3, end_row) -- alpha through delta
      helpers.cleanup(buf)
    end)
  end)

  describe("siblings", function()
    it("gets all siblings", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local siblings = tree.get_siblings(node)
      assert.are.equal(3, #siblings)
      helpers.cleanup(buf)
    end)

    it("gets next sibling", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local next = tree.next_sibling(node)
      assert.is_not_nil(next)
      local row = next:start()
      assert.are.equal(1, row) -- "- two" is row 1
      helpers.cleanup(buf)
    end)

    it("returns nil for last sibling next", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(3, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local next = tree.next_sibling(node)
      assert.is_nil(next)
      helpers.cleanup(buf)
    end)

    it("gets prev sibling", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(2, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local prev = tree.prev_sibling(node)
      assert.is_not_nil(prev)
      local row = prev:start()
      assert.are.equal(0, row)
      helpers.cleanup(buf)
    end)

    it("supports count for next_sibling", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local target = tree.next_sibling(node, 2)
      assert.is_not_nil(target)
      local row = target:start()
      assert.are.equal(2, row)
      helpers.cleanup(buf)
    end)
  end)

  describe("parent and children", function()
    it("gets parent item", function()
      local buf = helpers.create_md_buf(sample_nested)
      helpers.set_buf(buf)
      helpers.set_cursor(2, 4)
      local node = tree.get_list_item_at_cursor(buf)
      local parent = tree.parent_item(node)
      assert.is_not_nil(parent)
      local row = parent:start()
      assert.are.equal(0, row) -- alpha
      helpers.cleanup(buf)
    end)

    it("returns nil for top-level parent", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local parent = tree.parent_item(node)
      assert.is_nil(parent)
      helpers.cleanup(buf)
    end)

    it("gets first child", function()
      local buf = helpers.create_md_buf(sample_nested)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local child = tree.first_child(node)
      assert.is_not_nil(child)
      local row = child:start()
      assert.are.equal(1, row) -- beta
      helpers.cleanup(buf)
    end)

    it("returns nil for leaf first_child", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local child = tree.first_child(node)
      assert.is_nil(child)
      helpers.cleanup(buf)
    end)

    it("gets direct children", function()
      local buf = helpers.create_md_buf(sample_nested)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local children = tree.direct_children(node)
      assert.are.equal(2, #children) -- beta, delta
      helpers.cleanup(buf)
    end)
  end)

  describe("depth", function()
    it("returns 1 for top-level", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      assert.are.equal(1, tree.depth(node))
      helpers.cleanup(buf)
    end)

    it("returns 2 for nested", function()
      local buf = helpers.create_md_buf(sample_nested)
      helpers.set_buf(buf)
      helpers.set_cursor(2, 4)
      local node = tree.get_list_item_at_cursor(buf)
      assert.are.equal(2, tree.depth(node))
      helpers.cleanup(buf)
    end)

    it("returns 3 for deeply nested", function()
      local buf = helpers.create_md_buf(sample_nested)
      helpers.set_buf(buf)
      helpers.set_cursor(3, 6)
      local node = tree.get_list_item_at_cursor(buf)
      assert.are.equal(3, tree.depth(node))
      helpers.cleanup(buf)
    end)
  end)

  describe("marker", function()
    it("gets marker node", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local marker = tree.get_marker(node)
      assert.is_not_nil(marker)
      assert.are.equal("list_marker_minus", marker:type())
      helpers.cleanup(buf)
    end)

    it("detects ordered markers", function()
      local buf = helpers.create_md_buf(sample_ordered)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      assert.is_true(tree.is_ordered(node))
      helpers.cleanup(buf)
    end)

    it("detects unordered markers", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      assert.is_false(tree.is_ordered(node))
      helpers.cleanup(buf)
    end)
  end)

  describe("nested_list_range", function()
    it("returns range of nested list", function()
      local buf = helpers.create_md_buf(sample_nested)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0) -- alpha
      local node = tree.get_list_item_at_cursor(buf)
      local start_row, end_row = tree.get_nested_list_range(node)
      assert.is_not_nil(start_row)
      assert.are.equal(1, start_row) -- beta
      assert.are.equal(3, end_row) -- delta
      helpers.cleanup(buf)
    end)

    it("returns nil for leaf item", function()
      local buf = helpers.create_md_buf(sample_flat)
      helpers.set_buf(buf)
      helpers.set_cursor(1, 0)
      local node = tree.get_list_item_at_cursor(buf)
      local start_row, end_row = tree.get_nested_list_range(node)
      assert.is_nil(start_row)
      assert.is_nil(end_row)
      helpers.cleanup(buf)
    end)
  end)

  describe("has_parser", function()
    it("returns true for markdown buffer", function()
      local buf = helpers.create_md_buf(sample_flat)
      assert.is_truthy(tree.has_parser(buf))
      helpers.cleanup(buf)
    end)
  end)
end)
