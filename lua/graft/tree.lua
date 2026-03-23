-- TreeSitter interface for markdown bullet list nodes.
-- All other modules call this module — never vim.treesitter directly.
-- Isolates the block_continuation workaround (tree-sitter-markdown #154).

local M = {}

--- Node type constants.
M.LIST = "list"
M.LIST_ITEM = "list_item"
M.BLOCK_CONTINUATION = "block_continuation"

--- Ordered list marker types.
M.ORDERED_MARKERS = {
  list_marker_dot = true,
  list_marker_parenthesis = true,
}

--- All list marker types.
M.MARKER_TYPES = {
  list_marker_minus = true,
  list_marker_plus = true,
  list_marker_star = true,
  list_marker_dot = true,
  list_marker_parenthesis = true,
}

--- Re-parse the buffer's TreeSitter tree. Call after buffer mutations.
--- @param bufnr? integer
function M.reparse(bufnr)
  bufnr = bufnr or 0
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
  if ok and parser then
    parser:parse()
  end
end

--- Check if treesitter markdown parser is available for a buffer.
--- @param bufnr? integer
--- @return boolean
function M.has_parser(bufnr)
  bufnr = bufnr or 0
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
  return ok and parser ~= nil
end

--- Find the list_item node at or above cursor position.
--- Uses the block parser tree directly to avoid the inline parser boundary
--- problem: vim.treesitter.get_node() may return inline parser nodes
--- (emphasis, code_span, inline_link) whose parent() chain never crosses
--- back to the block parser's list_item.
--- @param bufnr? integer Buffer number (default: current)
--- @return TSNode? list_item The list_item node, or nil
function M.get_list_item_at_cursor(bufnr)
  bufnr = bufnr or 0
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
  if not ok or not parser then
    return nil
  end
  parser:parse()

  -- Get the block parser's tree (first tree), NOT the inline parser
  local trees = parser:trees()
  if not trees or #trees == 0 then
    return nil
  end

  local root = trees[1]:root()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  -- When cursor is in leading whitespace (e.g., col 0 on "  - item"),
  -- snap to the indent position so we find the correct nested list_item
  -- instead of the parent whose range starts at col 0.
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if line then
    local indent = #(line:match("^(%s*)") or "")
    if col < indent then
      col = indent
    end
  end

  -- Query the block parser tree directly — inline nodes don't exist here
  local node = root:named_descendant_for_range(row, col, row, col)
  while node do
    if node:type() == M.LIST_ITEM then
      return node
    end
    node = node:parent()
  end
  return nil
end

--- Convert an exclusive TreeSitter end position to an inclusive row index.
--- TreeSitter ranges are [start_row, start_col) to [end_row, end_col).
--- When end_col == 0, end_row points to the line AFTER the last content line.
--- @param end_row integer 0-indexed end row from node:range()
--- @param end_col integer end column from node:range()
--- @param start_row integer 0-indexed start row (guard against underflow)
--- @return integer inclusive_end_row 0-indexed (last line of content)
local function to_inclusive_end(end_row, end_col, start_row)
  if end_col == 0 and end_row > start_row then
    return end_row - 1
  end
  return end_row
end

--- Trim trailing block_continuation from a node's range.
--- Recursively checks the last child chain (list_item → paragraph → ...)
--- because block_continuation can appear as a direct child of list_item
--- OR nested inside a paragraph within the list_item.
--- @param n TSNode
--- @param end_row integer Current end row
--- @param end_col integer Current end col
--- @return integer end_row Adjusted end row
--- @return integer end_col Adjusted end col
local function trim_block_continuation(n, end_row, end_col)
  local child_count = n:named_child_count()
  if child_count == 0 then
    return end_row, end_col
  end

  local last_child = n:named_child(child_count - 1)
  if last_child:type() == M.BLOCK_CONTINUATION then
    -- Find the last non-block_continuation child
    for i = child_count - 1, 0, -1 do
      local child = n:named_child(i)
      if child:type() ~= M.BLOCK_CONTINUATION then
        local _, _, cr, cc = child:range()
        return cr, cc
      end
    end
    return end_row, end_col
  end

  -- Recurse into the last child (list, paragraph, etc.) to find
  -- block_continuation at any depth in the tree
  return trim_block_continuation(last_child, end_row, end_col)
end

--- Get the line range of a list_item, excluding trailing block_continuation.
--- This is the block_continuation workaround for tree-sitter-markdown #154.
--- Handles block_continuation both as direct child and nested in paragraph.
--- @param node TSNode A list_item node
--- @return integer start_row 0-indexed
--- @return integer end_row 0-indexed (inclusive — last line of content)
function M.get_subtree_range(node)
  local start_row, _, raw_end_row, raw_end_col = node:range()
  local end_row, end_col = trim_block_continuation(node, raw_end_row, raw_end_col)
  return start_row, to_inclusive_end(end_row, end_col, start_row)
end

--- Get sibling list_items in the same parent list.
--- @param node TSNode A list_item node
--- @return TSNode[] siblings Ordered list of sibling list_item nodes
function M.get_siblings(node)
  local parent = node:parent()
  if not parent or parent:type() ~= M.LIST then
    return { node }
  end
  local siblings = {}
  for i = 0, parent:named_child_count() - 1 do
    local child = parent:named_child(i)
    if child:type() == M.LIST_ITEM then
      siblings[#siblings + 1] = child
    end
  end
  return siblings
end

--- Get the index of a node among its siblings (1-indexed).
--- @param node TSNode
--- @return integer index
function M.sibling_index(node)
  local siblings = M.get_siblings(node)
  for i, sib in ipairs(siblings) do
    if sib:id() == node:id() then
      return i
    end
  end
  return 1
end

--- Get the next sibling list_item.
--- @param node TSNode
--- @param count? integer Number of siblings to skip (default: 1)
--- @return TSNode? next_sibling
function M.next_sibling(node, count)
  count = count or 1
  local siblings = M.get_siblings(node)
  local idx = M.sibling_index(node)
  local target = idx + count
  if target > #siblings then
    return nil
  end
  return siblings[target]
end

--- Get the previous sibling list_item.
--- @param node TSNode
--- @param count? integer
--- @return TSNode? prev_sibling
function M.prev_sibling(node, count)
  count = count or 1
  local siblings = M.get_siblings(node)
  local idx = M.sibling_index(node)
  local target = idx - count
  if target < 1 then
    return nil
  end
  return siblings[target]
end

--- Get the parent list_item (one nesting level up).
--- @param node TSNode
--- @param count? integer Number of levels to go up (default: 1)
--- @return TSNode? parent_item
function M.parent_item(node, count)
  count = count or 1
  local current = node
  for _ = 1, count do
    -- Go up: list_item -> list -> list_item
    local parent = current:parent() -- should be 'list'
    if not parent then
      return nil
    end
    parent = parent:parent() -- should be 'list_item' or 'section'/'document'
    if not parent or parent:type() ~= M.LIST_ITEM then
      return nil
    end
    current = parent
  end
  return current
end

--- Get the first child list_item (one nesting level down).
--- @param node TSNode A list_item node
--- @return TSNode? first_child
function M.first_child(node)
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    if child:type() == M.LIST then
      -- Return the first list_item in this nested list
      for j = 0, child:named_child_count() - 1 do
        local grandchild = child:named_child(j)
        if grandchild:type() == M.LIST_ITEM then
          return grandchild
        end
      end
    end
  end
  return nil
end

--- Get direct child list_items (first nested list only).
--- @param node TSNode A list_item node
--- @return TSNode[] children
function M.direct_children(node)
  local children = {}
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    if child:type() == M.LIST then
      for j = 0, child:named_child_count() - 1 do
        local grandchild = child:named_child(j)
        if grandchild:type() == M.LIST_ITEM then
          children[#children + 1] = grandchild
        end
      end
      break -- Only first nested list for direct children
    end
  end
  return children
end

--- Get all descendant list_items (recursive).
--- @param node TSNode A list_item node
--- @return TSNode[] descendants
function M.all_descendants(node)
  local descendants = {}
  local function collect(n)
    for i = 0, n:named_child_count() - 1 do
      local child = n:named_child(i)
      if child:type() == M.LIST then
        for j = 0, child:named_child_count() - 1 do
          local item = child:named_child(j)
          if item:type() == M.LIST_ITEM then
            descendants[#descendants + 1] = item
            collect(item)
          end
        end
      end
    end
  end
  collect(node)
  return descendants
end

--- Get the nested list node within a list_item (if any).
--- @param node TSNode A list_item node
--- @return TSNode? nested_list The first child list node
function M.nested_list(node)
  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    if child:type() == M.LIST then
      return child
    end
  end
  return nil
end

--- Get the range of the nested list within a list_item.
--- Used for `ig` text object.
--- @param node TSNode A list_item node
--- @return integer? start_row 0-indexed
--- @return integer? end_row 0-indexed (inclusive)
function M.get_nested_list_range(node)
  local nested = M.nested_list(node)
  if not nested then
    return nil, nil
  end
  local start_row = nested:start()
  local raw_end_row, raw_end_col = nested:end_()
  local end_row, end_col = trim_block_continuation(nested, raw_end_row, raw_end_col)
  return start_row, to_inclusive_end(end_row, end_col, start_row)
end

--- Get the range of direct children including their subtrees.
--- Used for `iG` text object.
--- For items with one nested list, returns the range of only that list's items.
--- Unlike `ig` (which returns the nested list node range), this computes the
--- range from the first direct child's start to the last direct child's subtree end.
--- @param node TSNode A list_item node
--- @return integer? start_row 0-indexed
--- @return integer? end_row 0-indexed (inclusive)
function M.get_direct_children_range(node)
  local children = M.direct_children(node)
  if #children == 0 then
    return nil, nil
  end
  local first_start = children[1]:start()
  -- Use the last direct child's full subtree range (including its descendants)
  local _, last_end = M.get_subtree_range(children[#children])
  return first_start, last_end
end

--- Compute nesting depth (1 = top-level list item).
--- @param node TSNode A list_item node
--- @return integer depth
function M.depth(node)
  local depth = 0
  local current = node:parent()
  while current do
    if current:type() == M.LIST then
      depth = depth + 1
    end
    current = current:parent()
  end
  return depth
end

--- Get the marker node of a list_item.
--- @param node TSNode A list_item node
--- @return TSNode? marker
function M.get_marker(node)
  local first = node:named_child(0)
  if first and M.MARKER_TYPES[first:type()] then
    return first
  end
  return nil
end

--- Check if a list_item has an ordered marker.
--- @param node TSNode
--- @return boolean
function M.is_ordered(node)
  local marker = M.get_marker(node)
  if not marker then
    return false
  end
  return M.ORDERED_MARKERS[marker:type()] or false
end

--- Get the parent list node.
--- @param node TSNode A list_item node
--- @return TSNode? list The parent list node
function M.parent_list(node)
  local parent = node:parent()
  if parent and parent:type() == M.LIST then
    return parent
  end
  return nil
end

return M
