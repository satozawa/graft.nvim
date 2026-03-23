local helpers = require("tests.helpers")
local paste = require("graft.paste")
local tree = require("graft.tree")

describe("paste", function()
  local buf

  after_each(function()
    if buf then
      helpers.cleanup(buf)
      buf = nil
    end
  end)

  describe("is_list_content", function()
    it("detects unordered marker with dash", function()
      assert.is_true(paste.is_list_content({ "- item" }))
    end)

    it("detects unordered marker with asterisk", function()
      assert.is_true(paste.is_list_content({ "* item" }))
    end)

    it("detects unordered marker with plus", function()
      assert.is_true(paste.is_list_content({ "+ item" }))
    end)

    it("detects indented unordered marker", function()
      assert.is_true(paste.is_list_content({ "  - nested item" }))
    end)

    it("detects ordered marker with dot", function()
      assert.is_true(paste.is_list_content({ "1. first" }))
    end)

    it("detects ordered marker with parenthesis", function()
      assert.is_true(paste.is_list_content({ "1) first" }))
    end)

    it("detects indented ordered marker", function()
      assert.is_true(paste.is_list_content({ "    2. second" }))
    end)

    it("rejects plain text", function()
      assert.is_false(paste.is_list_content({ "just some text" }))
    end)

    it("rejects heading", function()
      assert.is_false(paste.is_list_content({ "# Heading" }))
    end)

    it("rejects empty lines", function()
      assert.is_false(paste.is_list_content({ "", "" }))
    end)

    it("skips leading empty lines to find first non-empty", function()
      assert.is_true(paste.is_list_content({ "", "  - item" }))
    end)

    it("rejects dash without trailing space", function()
      assert.is_false(paste.is_list_content({ "-no-space" }))
    end)

    it("rejects number without trailing space", function()
      assert.is_false(paste.is_list_content({ "1.no-space" }))
    end)
  end)

  describe("smart_paste", function()
    -- Sample: nested list with items at different depths
    -- Line 1 (1-idx): - Alpha
    -- Line 2 (1-idx):   - Bravo
    -- Line 3 (1-idx):     - Charlie
    -- Line 4 (1-idx):   - Delta
    -- Line 5 (1-idx): - Echo
    local sample_lines = {
      "- Alpha",
      "  - Bravo",
      "    - Charlie",
      "  - Delta",
      "- Echo",
    }

    it("increases indent when pasting top-level content into nested context", function()
      buf = helpers.create_md_buf(sample_lines)
      helpers.set_buf(buf)

      -- Paste a top-level item (0 indent) while cursor is on Bravo (indent 2)
      vim.fn.setreg('"', { "- pasted item", "  - pasted child" }, "l")
      helpers.set_cursor(2, 2) -- on "  - Bravo"
      paste.smart_paste()

      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Bravo",
        "  - pasted item",
        "    - pasted child",
        "    - Charlie",
        "  - Delta",
        "- Echo",
      }, lines)
    end)

    it("decreases indent when pasting nested content into top-level context", function()
      buf = helpers.create_md_buf(sample_lines)
      helpers.set_buf(buf)

      -- Paste deeply indented content while cursor is on top-level Echo (indent 0)
      vim.fn.setreg('"', { "    - deep item", "      - deeper child" }, "l")
      helpers.set_cursor(5, 0) -- on "- Echo"
      paste.smart_paste()

      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Bravo",
        "    - Charlie",
        "  - Delta",
        "- Echo",
        "- deep item",
        "  - deeper child",
      }, lines)
    end)

    it("preserves indent when pasting at same depth", function()
      buf = helpers.create_md_buf(sample_lines)
      helpers.set_buf(buf)

      -- Paste content already at indent 2 while cursor is on Bravo (indent 2)
      vim.fn.setreg('"', { "  - same level" }, "l")
      helpers.set_cursor(2, 2) -- on "  - Bravo"
      paste.smart_paste()

      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Bravo",
        "  - same level",
        "    - Charlie",
        "  - Delta",
        "- Echo",
      }, lines)
    end)

    it("pastes below cursor line", function()
      buf = helpers.create_md_buf(sample_lines)
      helpers.set_buf(buf)

      vim.fn.setreg('"', { "- new item" }, "l")
      helpers.set_cursor(1, 0) -- on "- Alpha"
      paste.smart_paste()

      local lines = helpers.get_lines(buf)
      -- Pasted below line 1, not above
      assert.are.same({
        "- Alpha",
        "- new item",
        "  - Bravo",
        "    - Charlie",
        "  - Delta",
        "- Echo",
      }, lines)
    end)

    it("renumbers after pasting into ordered list", function()
      local ordered_lines = {
        "1. First",
        "2. Second",
        "3. Third",
      }
      buf = helpers.create_md_buf(ordered_lines)
      helpers.set_buf(buf)

      -- Paste an ordered item after "1. First"
      vim.fn.setreg('"', { "99. Inserted" }, "l")
      helpers.set_cursor(1, 0) -- on "1. First"
      paste.smart_paste()

      local lines = helpers.get_lines(buf)
      -- After renumbering, the inserted item should be 2 and subsequent items shift
      assert.are.same({
        "1. First",
        "2. Inserted",
        "3. Second",
        "4. Third",
      }, lines)
    end)

    it("handles multi-line paste with varying indent", function()
      buf = helpers.create_md_buf(sample_lines)
      helpers.set_buf(buf)

      -- Paste a subtree with 3 levels starting at indent 0
      vim.fn.setreg('"', { "- parent", "  - child", "    - grandchild" }, "l")
      helpers.set_cursor(4, 2) -- on "  - Delta" (indent 2)
      paste.smart_paste()

      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Bravo",
        "    - Charlie",
        "  - Delta",
        "  - parent",
        "    - child",
        "      - grandchild",
        "- Echo",
      }, lines)
    end)

    it("handles register content with trailing newline", function()
      buf = helpers.create_md_buf(sample_lines)
      helpers.set_buf(buf)

      -- Simulate register content that ends with a newline (common with yy)
      -- getreg returns "- item\n", split gives {"- item", ""}
      vim.fn.setreg('"', "- trailing newline\n", "l")
      helpers.set_cursor(5, 0) -- on "- Echo"
      paste.smart_paste()

      local lines = helpers.get_lines(buf)
      assert.are.same({
        "- Alpha",
        "  - Bravo",
        "    - Charlie",
        "  - Delta",
        "- Echo",
        "- trailing newline",
      }, lines)
    end)
  end)

  describe("attach", function()
    it("registers ]p keymap on buffer", function()
      buf = helpers.create_md_buf({ "- item" })
      helpers.set_buf(buf)
      paste.attach(buf, { keymaps = { smart_paste = "]p" } })

      local maps = vim.api.nvim_buf_get_keymap(buf, "n")
      local found = false
      for _, map in ipairs(maps) do
        if map.lhs == "]p" then
          found = true
          break
        end
      end
      assert.is_true(found, "]p keymap should be registered")
    end)
  end)
end)
