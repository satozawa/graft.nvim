-- Text objects: ag (a graft), ig (inner graft), iG (inner Graft shallow)
-- All text objects are linewise (V), operating on markdown bullet list subtrees.

local tree = require("graft.tree")

local M = {}

--- Apply a linewise visual selection over a 0-indexed inclusive row range.
--- Positions cursor at start_row, enters linewise visual, then moves to end_row.
--- @param start_row integer 0-indexed start row
--- @param end_row integer 0-indexed end row (inclusive)
local function select_range(start_row, end_row)
  vim.api.nvim_win_set_cursor(0, { start_row + 1, 0 })
  vim.cmd("normal! V")
  vim.api.nvim_win_set_cursor(0, { end_row + 1, 0 })
end

--- Select the current list_item and all its descendants (linewise).
--- Range comes from `tree.get_subtree_range()`.
--- NO-OP if cursor is not inside a list_item.
function M.around_graft()
  local node = tree.get_list_item_at_cursor()
  if not node then
    return
  end
  local start_row, end_row = tree.get_subtree_range(node)
  select_range(start_row, end_row)
end

--- Select the nested list within the current list_item (linewise).
--- Range comes from `tree.get_nested_list_range()`.
--- NO-OP if cursor is not inside a list_item or item has no children.
function M.inner_graft()
  local node = tree.get_list_item_at_cursor()
  if not node then
    return
  end
  local start_row, end_row = tree.get_nested_list_range(node)
  if not start_row or not end_row then
    return
  end
  select_range(start_row, end_row)
end

--- Select direct children only within the current list_item (linewise).
--- Range comes from `tree.get_direct_children_range()`.
--- NO-OP if cursor is not inside a list_item or item has no children.
function M.inner_graft_shallow()
  local node = tree.get_list_item_at_cursor()
  if not node then
    return
  end
  local start_row, end_row = tree.get_direct_children_range(node)
  if not start_row or not end_row then
    return
  end
  select_range(start_row, end_row)
end

--- Attach text object keymaps to a buffer.
--- @param bufnr integer Buffer number
--- @param opts? { keymaps?: { around_graft?: string, inner_graft?: string, inner_graft_shallow?: string } }
function M.attach(bufnr, opts)
  opts = opts or {}
  local keymaps = opts.keymaps or {}
  local ag = keymaps.around_graft or "ag"
  local ig = keymaps.inner_graft or "ig"
  local iG = keymaps.inner_graft_shallow or "iG"

  vim.keymap.set({ "o", "x" }, ag, function()
    M.around_graft()
  end, { buffer = bufnr, silent = true, desc = "Around graft (subtree)" })

  vim.keymap.set({ "o", "x" }, ig, function()
    M.inner_graft()
  end, { buffer = bufnr, silent = true, desc = "Inner graft (descendants)" })

  vim.keymap.set({ "o", "x" }, iG, function()
    M.inner_graft_shallow()
  end, { buffer = bufnr, silent = true, desc = "Inner graft shallow (direct children)" })
end

return M
