local helpers = require("tests.helpers")

describe("renumber", function()
  local tree = require("graft.tree")
  local renumber = require("graft.renumber")

  it("renumbers ordered list sequentially", function()
    local buf = helpers.create_md_buf({
      "3. third",
      "1. first",
      "5. fifth",
    })
    helpers.set_buf(buf)
    helpers.set_cursor(1, 0)
    local node = tree.get_list_item_at_cursor(buf)
    renumber.renumber_parent_list(node, buf)
    tree.reparse(buf)
    local lines = helpers.get_lines(buf)
    assert.are.equal("1. third", lines[1])
    assert.are.equal("2. first", lines[2])
    assert.are.equal("3. fifth", lines[3])
    helpers.cleanup(buf)
  end)

  it("handles parenthesis-style ordered markers", function()
    local buf = helpers.create_md_buf({
      "3) third",
      "1) first",
    })
    helpers.set_buf(buf)
    helpers.set_cursor(1, 0)
    local node = tree.get_list_item_at_cursor(buf)
    renumber.renumber_parent_list(node, buf)
    tree.reparse(buf)
    local lines = helpers.get_lines(buf)
    assert.are.equal("1) third", lines[1])
    assert.are.equal("2) first", lines[2])
    helpers.cleanup(buf)
  end)

  it("is a no-op on unordered lists", function()
    local buf = helpers.create_md_buf({
      "- alpha",
      "- beta",
    })
    helpers.set_buf(buf)
    helpers.set_cursor(1, 0)
    local node = tree.get_list_item_at_cursor(buf)
    renumber.renumber_parent_list(node, buf)
    local lines = helpers.get_lines(buf)
    assert.are.equal("- alpha", lines[1])
    assert.are.equal("- beta", lines[2])
    helpers.cleanup(buf)
  end)

  it("renumbers per-group in mixed ordered/unordered list", function()
    local buf = helpers.create_md_buf({
      "1. first",
      "2. second",
      "- unordered break",
      "1. third",
      "2. fourth",
    })
    helpers.set_buf(buf)
    helpers.set_cursor(1, 0)
    local node = tree.get_list_item_at_cursor(buf)
    renumber.renumber_parent_list(node, buf)
    tree.reparse(buf)
    local lines = helpers.get_lines(buf)
    assert.are.equal("1. first", lines[1])
    assert.are.equal("2. second", lines[2])
    assert.are.equal("- unordered break", lines[3])
    helpers.cleanup(buf)
  end)

  it("renumbers only the list containing the cursor node", function()
    -- TreeSitter puts different marker types in separate list nodes,
    -- so renumber_parent_list only affects the cursor's own list.
    local buf = helpers.create_md_buf({
      "3. third",
      "1. first",
    })
    helpers.set_buf(buf)
    helpers.set_cursor(1, 0)
    local node = tree.get_list_item_at_cursor(buf)
    renumber.renumber_parent_list(node, buf)
    tree.reparse(buf)
    local lines = helpers.get_lines(buf)
    assert.are.equal("1. third", lines[1])
    assert.are.equal("2. first", lines[2])
    helpers.cleanup(buf)
  end)

  it("only renumbers same parent list (not nested)", function()
    local buf = helpers.create_md_buf({
      "1. outer one",
      "   1. inner one",
      "   2. inner two",
      "2. outer two",
    })
    helpers.set_buf(buf)
    helpers.set_cursor(2, 3) -- cursor on inner one
    local node = tree.get_list_item_at_cursor(buf)
    renumber.renumber_parent_list(node, buf)
    local lines = helpers.get_lines(buf)
    -- Inner list renumbered (already correct), outer untouched
    assert.are.equal("1. outer one", lines[1])
    assert.are.equal("   1. inner one", lines[2])
    assert.are.equal("   2. inner two", lines[3])
    assert.are.equal("2. outer two", lines[4])
    helpers.cleanup(buf)
  end)
end)
