-- Operations: move subtree up/down among siblings, promote/demote subtrees.
-- Uses a single nvim_buf_set_lines() call for undo atomicity (Summit A1).

local tree = require("graft.tree")
local renumber = require("graft.renumber")

local M = {}

--- Swap two sibling subtrees using a single nvim_buf_set_lines() call.
--- Handles both tight (adjacent) and loose (gap between) lists.
--- After the swap, repositions the cursor to follow the moved item.
--- @param node TSNode The current list_item at cursor
--- @param sibling TSNode The sibling to swap with
--- @param direction "up"|"down" Which direction the current node is moving
--- @param bufnr integer Buffer number
local function swap_subtrees(node, sibling, direction, bufnr)
  -- Determine which node is above and which is below
  local start_cur, end_cur = tree.get_subtree_range(node)
  local start_sib, end_sib = tree.get_subtree_range(sibling)

  local above_start, above_end, below_start, below_end
  if start_cur < start_sib then
    above_start, above_end = start_cur, end_cur
    below_start, below_end = start_sib, end_sib
  else
    above_start, above_end = start_sib, end_sib
    below_start, below_end = start_cur, end_cur
  end

  -- Extract three segments: above, gap (if any), below
  local combined_start = above_start
  local combined_end = below_end + 1 -- exclusive for nvim_buf_set_lines

  local lines_above = vim.api.nvim_buf_get_lines(bufnr, above_start, above_end + 1, false)
  local lines_below = vim.api.nvim_buf_get_lines(bufnr, below_start, below_end + 1, false)

  -- Gap lines between the two siblings (blank lines in loose lists)
  local lines_gap = {}
  if above_end + 1 < below_start then
    lines_gap = vim.api.nvim_buf_get_lines(bufnr, above_end + 1, below_start, false)
  end

  -- Reassemble: below, gap, above (swap the two siblings, keep gap in place)
  local swapped = {}
  vim.list_extend(swapped, lines_below)
  vim.list_extend(swapped, lines_gap)
  vim.list_extend(swapped, lines_above)

  -- Single atomic write
  vim.api.nvim_buf_set_lines(bufnr, combined_start, combined_end, false, swapped)

  -- Reposition cursor to follow the moved item.
  -- Use the actual cursor row for offset, not start_cur, because the cursor
  -- may be on a child line within the subtree.
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  cursor_row = cursor_row - 1 -- convert to 0-indexed
  if direction == "up" then
    -- Current was below (at below_start..below_end), now placed at combined_start
    local offset_in_block = cursor_row - below_start
    local new_row = combined_start + offset_in_block
    vim.api.nvim_win_set_cursor(0, { new_row + 1, cursor_col })
  else
    -- Current was above (at above_start..above_end), now placed after below + gap
    local offset_in_block = cursor_row - above_start
    local new_row = combined_start + #lines_below + #lines_gap + offset_in_block
    vim.api.nvim_win_set_cursor(0, { new_row + 1, cursor_col })
  end
end

--- Perform the actual move-up operation.
function M._do_move_up()
  local bufnr = 0
  local node = tree.get_list_item_at_cursor(bufnr)
  if not node then
    return
  end
  local prev = tree.prev_sibling(node)
  if not prev then
    return
  end

  swap_subtrees(node, prev, "up", bufnr)

  -- Reparse after mutation
  tree.reparse(bufnr)

  -- Renumber if ordered list (undojoin keeps move + renumber as one undo step)
  local new_node = tree.get_list_item_at_cursor(bufnr)
  if new_node and tree.is_ordered(new_node) then
    vim.cmd("undojoin")
    renumber.renumber_parent_list(new_node, bufnr)
  end
end

--- Perform the actual move-down operation.
function M._do_move_down()
  local bufnr = 0
  local node = tree.get_list_item_at_cursor(bufnr)
  if not node then
    return
  end
  local next = tree.next_sibling(node)
  if not next then
    return
  end

  swap_subtrees(node, next, "down", bufnr)

  -- Reparse after mutation
  tree.reparse(bufnr)

  -- Renumber if ordered list (undojoin keeps move + renumber as one undo step)
  local new_node = tree.get_list_item_at_cursor(bufnr)
  if new_node and tree.is_ordered(new_node) then
    vim.cmd("undojoin")
    renumber.renumber_parent_list(new_node, bufnr)
  end
end

--- Perform the actual promote (outdent) operation.
--- Removes shiftwidth spaces from the subtree. No-op at top level.
function M._do_promote()
  local bufnr = 0
  local node = tree.get_list_item_at_cursor(bufnr)
  if not node then
    return
  end

  -- Cannot promote top-level items
  if not tree.parent_item(node) then
    return
  end

  local start_row, end_row = tree.get_subtree_range(node)
  local sw = vim.bo[bufnr].shiftwidth
  if sw == 0 then
    sw = 2
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  for i, line in ipairs(lines) do
    if line:match("%S") then
      local ws = line:match("^(%s*)")
      local remove = math.min(sw, #ws)
      lines[i] = line:sub(remove + 1)
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, lines)

  -- Adjust cursor column
  local cursor = vim.api.nvim_win_get_cursor(0)
  local new_col = math.max(0, cursor[2] - sw)
  vim.api.nvim_win_set_cursor(0, { cursor[1], new_col })

  -- Reparse and renumber
  tree.reparse(bufnr)
  local new_node = tree.get_list_item_at_cursor(bufnr)
  if new_node and tree.is_ordered(new_node) then
    vim.cmd("undojoin")
    renumber.renumber_parent_list(new_node, bufnr)
  end
end

--- Perform the actual demote (indent) operation.
--- Adds shiftwidth spaces to the subtree.
function M._do_demote()
  local bufnr = 0
  local node = tree.get_list_item_at_cursor(bufnr)
  if not node then
    return
  end

  -- Cannot demote without a previous sibling (would create orphan)
  if not tree.prev_sibling(node) then
    return
  end

  local start_row, end_row = tree.get_subtree_range(node)
  local sw = vim.bo[bufnr].shiftwidth
  if sw == 0 then
    sw = 2
  end
  local padding = string.rep(" ", sw)

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  for i, line in ipairs(lines) do
    if line:match("%S") then
      lines[i] = padding .. line
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, lines)

  -- Adjust cursor column
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + sw })

  -- Reparse and renumber
  tree.reparse(bufnr)
  local new_node = tree.get_list_item_at_cursor(bufnr)
  if new_node and tree.is_ordered(new_node) then
    vim.cmd("undojoin")
    renumber.renumber_parent_list(new_node, bufnr)
  end
end

--- Move the current subtree up among siblings.
--- Supports dot-repeat via operatorfunc.
--- @param motion? string Set by operatorfunc callback (non-nil on repeat)
--- @return string? feedkeys Returns "g@l" for initial expr mapping
function M.move_up(motion)
  if motion == nil then
    vim.o.operatorfunc = "v:lua.require'graft.operations'.move_up"
    return "g@l"
  end
  M._do_move_up()
end

--- Move the current subtree down among siblings.
--- Supports dot-repeat via operatorfunc.
--- @param motion? string Set by operatorfunc callback (non-nil on repeat)
--- @return string? feedkeys Returns "g@l" for initial expr mapping
function M.move_down(motion)
  if motion == nil then
    vim.o.operatorfunc = "v:lua.require'graft.operations'.move_down"
    return "g@l"
  end
  M._do_move_down()
end

--- Promote (outdent) the current subtree.
--- Supports dot-repeat via operatorfunc.
--- @param motion? string Set by operatorfunc callback (non-nil on repeat)
--- @return string? feedkeys Returns "g@l" for initial expr mapping
function M.promote(motion)
  if motion == nil then
    vim.o.operatorfunc = "v:lua.require'graft.operations'.promote"
    return "g@l"
  end
  M._do_promote()
end

--- Demote (indent) the current subtree.
--- Supports dot-repeat via operatorfunc.
--- @param motion? string Set by operatorfunc callback (non-nil on repeat)
--- @return string? feedkeys Returns "g@l" for initial expr mapping
function M.demote(motion)
  if motion == nil then
    vim.o.operatorfunc = "v:lua.require'graft.operations'.demote"
    return "g@l"
  end
  M._do_demote()
end

--- Register global <Plug> mappings.
--- Called once (idempotent). Users bind their own keys to these <Plug> names.
function M.register_plug_mappings()
  vim.keymap.set("n", "<Plug>(graft-move-up)", M.move_up, {
    expr = true,
    silent = true,
    desc = "Move subtree up among siblings",
  })
  vim.keymap.set("n", "<Plug>(graft-move-down)", M.move_down, {
    expr = true,
    silent = true,
    desc = "Move subtree down among siblings",
  })
  vim.keymap.set("n", "<Plug>(graft-promote)", M.promote, {
    expr = true,
    silent = true,
    desc = "Promote (outdent) subtree",
  })
  vim.keymap.set("n", "<Plug>(graft-demote)", M.demote, {
    expr = true,
    silent = true,
    desc = "Demote (indent) subtree",
  })
end

--- Attach operations keymaps to a buffer.
--- Registers move/promote/demote in Normal and Insert modes.
--- Requires terminal configured with Option-as-Meta (e.g. Ghostty: macos-option-as-alt = left).
--- @param bufnr integer Buffer number
--- @param config? table Config with keymaps
function M.attach(bufnr, config)
  local keymaps = (config or {}).keymaps or {}

  local key

  key = keymaps.move_up
  if key then
    vim.keymap.set("n", key, M.move_up, {
      buffer = bufnr,
      expr = true,
      silent = true,
      desc = "Move subtree up",
    })
    vim.keymap.set("i", key, function()
      M._do_move_up()
    end, { buffer = bufnr, silent = true, desc = "Move subtree up (insert)" })
  end

  key = keymaps.move_down
  if key then
    vim.keymap.set("n", key, M.move_down, {
      buffer = bufnr,
      expr = true,
      silent = true,
      desc = "Move subtree down",
    })
    vim.keymap.set("i", key, function()
      M._do_move_down()
    end, { buffer = bufnr, silent = true, desc = "Move subtree down (insert)" })
  end

  key = keymaps.promote
  if key then
    vim.keymap.set("n", key, M.promote, {
      buffer = bufnr,
      expr = true,
      silent = true,
      desc = "Promote (outdent) subtree",
    })
    vim.keymap.set("i", key, function()
      M._do_promote()
    end, { buffer = bufnr, silent = true, desc = "Promote subtree (insert)" })
  end

  key = keymaps.demote
  if key then
    vim.keymap.set("n", key, M.demote, {
      buffer = bufnr,
      expr = true,
      silent = true,
      desc = "Demote (indent) subtree",
    })
    vim.keymap.set("i", key, function()
      M._do_demote()
    end, { buffer = bufnr, silent = true, desc = "Demote subtree (insert)" })
  end
end

return M
