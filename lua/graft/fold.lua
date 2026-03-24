-- Fold support for markdown bullet list subtrees.
-- Provides foldexpr based on list item depth and foldtext
-- that displays "+" instead of "-" on folded lines.

local tree = require("graft.tree")

local M = {}

--- Compute fold level for a given line number.
--- Items with children get a fold start marker (">N").
--- Leaf items and continuation lines get their depth ("N").
--- Non-list lines get "0".
--- @param lnum integer 1-indexed line number (from vim foldexpr v:lnum)
--- @return string foldlevel Vim foldexpr return value
function M.foldexpr(lnum)
  local bufnr = vim.api.nvim_get_current_buf()

  -- Quick reject: lines that can't be list items
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
  if not line or not line:match("^%s*[-*+%d]") then
    return "0"
  end

  -- Get block parser tree
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
  if not ok or not parser then
    return "0"
  end

  local trees = parser:trees()
  if not trees or #trees == 0 then
    return "0"
  end

  -- Use the content start column, not 0, to find indented list items
  local indent = #(line:match("^(%s*)") or "")
  local root = trees[1]:root()
  local node = root:named_descendant_for_range(lnum - 1, indent, lnum - 1, indent)

  -- Walk up to find list_item
  while node and node:type() ~= tree.LIST_ITEM do
    node = node:parent()
  end
  if not node then
    return "0"
  end

  local depth = tree.depth(node)
  if depth == 0 then
    return "0"
  end

  -- Only the first line of a list_item starts a fold
  local item_start = node:start()
  if item_start ~= lnum - 1 then
    return tostring(depth)
  end

  -- Items with children get fold start marker
  if tree.first_child(node) then
    return ">" .. tostring(depth)
  end

  return tostring(depth)
end

--- Custom foldtext that replaces "-" with "+" on folded lines.
--- @return string foldtext The text to display for the folded line
function M.foldtext()
  local line = vim.fn.getline(vim.v.foldstart)
  -- Replace the first list marker dash with +
  local folded = line:gsub("^(%s*)(%-)", "%1+", 1)
  local count = vim.v.foldend - vim.v.foldstart
  return folded .. "  (" .. count .. " lines)"
end

--- Ensure the fold containing the given line is open.
--- Called by bullets.lua when creating a child under a folded parent.
--- @param lnum integer 1-indexed line number
function M.ensure_unfolded(lnum)
  if vim.fn.foldclosed(lnum) ~= -1 then
    vim.cmd(lnum .. "foldopen")
  end
end

--- Attach fold settings to a buffer's window.
--- Sets window-local fold options. NOT guarded by graft_attached because
--- fold settings are window-local and must be set for each window.
--- @param bufnr integer Buffer number (unused, settings are window-local)
function M.attach(_bufnr) -- luacheck: ignore 212
  vim.wo.foldmethod = "expr"
  vim.wo.foldexpr = "v:lua.require'graft.fold'.foldexpr(v:lnum)"
  vim.wo.foldtext = "v:lua.require'graft.fold'.foldtext()"
  vim.wo.foldenable = true
  vim.wo.foldlevel = 99 -- start with all folds open
end

return M
