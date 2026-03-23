local helpers = require("tests.helpers")

describe("textobjects", function()
  local textobjects = require("graft.textobjects")
  local buf

  -- Sample markdown with nested bullet lists:
  -- Line 1 (0-idx 0): - Alpha
  -- Line 2 (0-idx 1):   - Bravo
  -- Line 3 (0-idx 2):     - Charlie
  -- Line 4 (0-idx 3):   - Delta
  -- Line 5 (0-idx 4): - Echo
  local sample_lines = {
    "- Alpha",
    "  - Bravo",
    "    - Charlie",
    "  - Delta",
    "- Echo",
  }

  before_each(function()
    buf = helpers.create_md_buf(sample_lines)
    helpers.set_buf(buf)
    textobjects.attach(buf, {})
  end)

  after_each(function()
    -- Exit visual mode if still active
    local mode = vim.api.nvim_get_mode().mode
    if mode:find("[vV]") then
      vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
    end
    helpers.cleanup(buf)
  end)

  describe("ag (around graft)", function()
    it("selects item and all descendants from parent", function()
      helpers.set_cursor(1, 0) -- on "- Alpha"
      -- Use dag to delete and check remaining lines
      vim.cmd("normal dag")
      local lines = helpers.get_lines(buf)
      assert.are.same({ "- Echo" }, lines)
    end)

    it("selects item and descendants from child", function()
      helpers.set_cursor(2, 0) -- on "  - Bravo"
      vim.cmd("normal dag")
      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Delta",
        "- Echo",
      }, lines)
    end)

    it("selects leaf item only", function()
      helpers.set_cursor(3, 0) -- on "    - Charlie"
      vim.cmd("normal dag")
      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Bravo",
        "  - Delta",
        "- Echo",
      }, lines)
    end)

    it("selects single item with no children", function()
      helpers.set_cursor(5, 0) -- on "- Echo"
      vim.cmd("normal dag")
      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Bravo",
        "    - Charlie",
        "  - Delta",
      }, lines)
    end)
  end)

  describe("ig (inner graft)", function()
    it("selects all descendants of parent item", function()
      helpers.set_cursor(1, 0) -- on "- Alpha"
      vim.cmd("normal dig")
      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "- Echo",
      }, lines)
    end)

    it("selects descendants of mid-level item", function()
      helpers.set_cursor(2, 0) -- on "  - Bravo"
      vim.cmd("normal dig")
      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Bravo",
        "  - Delta",
        "- Echo",
      }, lines)
    end)

    it("is no-op on leaf item", function()
      helpers.set_cursor(3, 0) -- on "    - Charlie" (no children)
      vim.cmd("normal dig")
      local lines = helpers.get_lines(buf)
      -- Nothing should be deleted
      assert.are.same(sample_lines, lines)
    end)

    it("is no-op on childless top-level item", function()
      helpers.set_cursor(5, 0) -- on "- Echo" (no children)
      vim.cmd("normal dig")
      local lines = helpers.get_lines(buf)
      assert.are.same(sample_lines, lines)
    end)
  end)

  describe("iG (inner graft shallow)", function()
    it("selects direct children including their subtrees", function()
      helpers.set_cursor(1, 0) -- on "- Alpha"
      -- iG selects the full nested list (Bravo+Charlie, Delta)
      -- For this sample, iG and ig produce the same result since there's
      -- only one nested list. iG differs from ig when an item has multiple
      -- nested lists at different positions.
      vim.cmd("normal diG")
      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "- Echo",
      }, lines)
    end)

    it("selects direct children of mid-level item", function()
      helpers.set_cursor(2, 0) -- on "  - Bravo"
      -- Bravo has one direct child: Charlie
      vim.cmd("normal diG")
      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Bravo",
        "  - Delta",
        "- Echo",
      }, lines)
    end)

    it("is no-op on leaf item", function()
      helpers.set_cursor(3, 0) -- on "    - Charlie" (no children)
      vim.cmd("normal diG")
      local lines = helpers.get_lines(buf)
      assert.are.same(sample_lines, lines)
    end)
  end)

  describe("attach", function()
    it("registers keymaps with default bindings", function()
      local maps = vim.api.nvim_buf_get_keymap(buf, "o")
      local found = {}
      for _, map in ipairs(maps) do
        if map.lhs == "ag" or map.lhs == "ig" or map.lhs == "iG" then
          found[map.lhs] = true
        end
      end
      assert.is_true(found["ag"], "ag keymap should be registered")
      assert.is_true(found["ig"], "ig keymap should be registered")
      assert.is_true(found["iG"], "iG keymap should be registered")
    end)

    it("registers keymaps in visual mode", function()
      local maps = vim.api.nvim_buf_get_keymap(buf, "x")
      local found = {}
      for _, map in ipairs(maps) do
        if map.lhs == "ag" or map.lhs == "ig" or map.lhs == "iG" then
          found[map.lhs] = true
        end
      end
      assert.is_true(found["ag"], "ag keymap should be registered in x mode")
      assert.is_true(found["ig"], "ig keymap should be registered in x mode")
      assert.is_true(found["iG"], "iG keymap should be registered in x mode")
    end)

    it("respects custom keymap overrides", function()
      local buf2 = helpers.create_md_buf(sample_lines)
      helpers.set_buf(buf2)
      textobjects.attach(buf2, {
        keymaps = {
          around_graft = "af",
          inner_graft = "if",
          inner_graft_shallow = "iF",
        },
      })
      local maps = vim.api.nvim_buf_get_keymap(buf2, "o")
      local found = {}
      for _, map in ipairs(maps) do
        if map.lhs == "af" or map.lhs == "if" or map.lhs == "iF" then
          found[map.lhs] = true
        end
      end
      assert.is_true(found["af"], "custom af keymap should be registered")
      assert.is_true(found["if"], "custom if keymap should be registered")
      assert.is_true(found["iF"], "custom iF keymap should be registered")
      helpers.cleanup(buf2)
    end)
  end)

  describe("deep nesting", function()
    -- Line 1 (0-idx 0): - Root
    -- Line 2 (0-idx 1):   - A
    -- Line 3 (0-idx 2):     - A1
    -- Line 4 (0-idx 3):       - A1a
    -- Line 5 (0-idx 4):   - B
    local deep_lines = {
      "- Root",
      "  - A",
      "    - A1",
      "      - A1a",
      "  - B",
    }

    it("ag from root selects everything", function()
      local dbuf = helpers.create_md_buf(deep_lines)
      helpers.set_buf(dbuf)
      textobjects.attach(dbuf, {})
      helpers.set_cursor(1, 0) -- on "- Root"
      vim.cmd("normal dag")
      local lines = helpers.get_lines(dbuf)
      assert.are.same({ "" }, lines)
      helpers.cleanup(dbuf)
    end)

    it("iG from root selects all direct children including their subtrees", function()
      local dbuf = helpers.create_md_buf(deep_lines)
      helpers.set_buf(dbuf)
      textobjects.attach(dbuf, {})
      helpers.set_cursor(1, 0) -- on "- Root"
      vim.cmd("normal diG")
      local lines = helpers.get_lines(dbuf)
      -- Deletes all nested content (A, A1, A1a, B)
      assert.are.same({
        "- Root",
      }, lines)
      helpers.cleanup(dbuf)
    end)
  end)
end)
