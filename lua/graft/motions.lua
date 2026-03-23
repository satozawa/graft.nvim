-- Motions: ]g, [g (next/prev sibling), ]G (first child), [G (parent)
-- Tree-aware cursor navigation for Markdown bullet lists.

local tree = require("graft.tree")

local M = {}

--- Move cursor to the first column of a list_item's marker.
--- Falls back to the item's start row, column 0 if no marker found.
--- @param target TSNode The list_item node to jump to
local function jump_to_marker(target)
  local marker = tree.get_marker(target)
  if marker then
    local row, col = marker:start()
    vim.api.nvim_win_set_cursor(0, { row + 1, col })
  else
    local row = target:start()
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
  end
end

--- Jump to the next sibling list_item.
--- @param count? integer Override count (default: vim.v.count1)
function M.next_sibling(count)
  count = count or vim.v.count1
  local node = tree.get_list_item_at_cursor()
  if not node then
    return
  end
  local target = tree.next_sibling(node, count)
  if not target then
    return
  end
  jump_to_marker(target)
end

--- Jump to the previous sibling list_item.
--- @param count? integer Override count (default: vim.v.count1)
function M.prev_sibling(count)
  count = count or vim.v.count1
  local node = tree.get_list_item_at_cursor()
  if not node then
    return
  end
  local target = tree.prev_sibling(node, count)
  if not target then
    return
  end
  jump_to_marker(target)
end

--- Jump to the first child list_item (go deeper).
--- With count > 1, navigates to first child's first child repeatedly.
--- @param count? integer Override count (default: vim.v.count1)
function M.first_child(count)
  count = count or vim.v.count1
  local node = tree.get_list_item_at_cursor()
  if not node then
    return
  end
  local target = node
  for _ = 1, count do
    local child = tree.first_child(target)
    if not child then
      return
    end
    target = child
  end
  jump_to_marker(target)
end

--- Jump to the parent list_item (go shallower).
--- @param count? integer Override count (default: vim.v.count1)
function M.parent(count)
  count = count or vim.v.count1
  local node = tree.get_list_item_at_cursor()
  if not node then
    return
  end
  local target = tree.parent_item(node, count)
  if not target then
    return
  end
  jump_to_marker(target)
end

--- Attach motion keymaps to a buffer.
--- @param bufnr integer Buffer number
--- @param opts table Options table with optional `keymaps` field
function M.attach(bufnr, opts)
  local keymaps = opts.keymaps or {}

  vim.keymap.set({ "n", "o", "x" }, keymaps.next_sibling or "]g", function()
    M.next_sibling()
  end, { buffer = bufnr, silent = true, desc = "Next list sibling" })

  vim.keymap.set({ "n", "o", "x" }, keymaps.prev_sibling or "[g", function()
    M.prev_sibling()
  end, { buffer = bufnr, silent = true, desc = "Previous list sibling" })

  vim.keymap.set({ "n", "o", "x" }, keymaps.first_child or "]G", function()
    M.first_child()
  end, { buffer = bufnr, silent = true, desc = "First child list item" })

  vim.keymap.set({ "n", "o", "x" }, keymaps.parent or "[G", function()
    M.parent()
  end, { buffer = bufnr, silent = true, desc = "Parent list item" })
end

return M
