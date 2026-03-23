-- Bullet continuation, checkbox toggle, and structural node creation.
-- Handles Enter, o, O keymaps and [x / ]x checkbox operations.

local tree = require("graft.tree")
local fold = require("graft.fold")
local renumber = require("graft.renumber")

local M = {}

--- Parse a bullet line into its components.
--- Returns indent, marker, and content text. Returns nil if not a bullet line.
--- Handles: "- ", "* ", "+ ", "- [ ] ", "- [x] ", "1. ", "1) "
--- @param line string
--- @return string? indent Leading whitespace
--- @return string? marker Full marker text including trailing space
--- @return string? content Text after the marker
local function parse_bullet(line)
  -- Checkbox: "  - [ ] text" or "  - [x] text"
  local indent, marker, content = line:match("^(%s*)([-*+] %[[x ]%] )(.*)")
  if indent then
    return indent, marker, content
  end

  -- Unordered: "  - text"
  indent, marker, content = line:match("^(%s*)([-*+] )(.*)")
  if indent then
    return indent, marker, content
  end

  -- Ordered with dot: "  1. text"
  indent, marker, content = line:match("^(%s*)(%d+%. )(.*)")
  if indent then
    return indent, marker, content
  end

  -- Ordered with paren: "  1) text"
  indent, marker, content = line:match("^(%s*)(%d+%) )(.*)")
  if indent then
    return indent, marker, content
  end

  return nil, nil, nil
end

--- Generate the next marker based on the current marker.
--- Unordered markers stay the same. Ordered markers increment.
--- Checkbox markers produce unchecked "- [ ] ".
--- @param marker string Current marker text (e.g., "- ", "1. ", "- [ ] ")
--- @return string next_marker
local function next_marker(marker)
  -- Checkbox
  if marker:match("%[[x ]%]") then
    return "- [ ] "
  end

  -- Ordered with dot
  local num = marker:match("^(%d+)%.")
  if num then
    return tostring(tonumber(num) + 1) .. ". "
  end

  -- Ordered with paren
  num = marker:match("^(%d+)%)")
  if num then
    return tostring(tonumber(num) + 1) .. ") "
  end

  -- Unordered: same marker
  return marker
end

--- Generate the child marker for a parent's marker type.
--- Checkbox parent → "- [ ] "; everything else → "- ".
--- Never generates numbered children from numbered parents.
--- @param parent_marker string Parent's marker text
--- @return string child_marker
local function child_marker(parent_marker)
  if parent_marker:match("%[[x ]%]") then
    return "- [ ] "
  end
  return "- "
end

--- Handle Enter in Normal mode.
--- Creates a new bullet line after the current subtree (subtree skip).
function M.enter_normal()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_get_current_line()
  local indent, marker, _ = parse_bullet(line)
  if not indent or not marker then
    -- Not on a bullet line, fall through to default Enter
    local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    vim.api.nvim_feedkeys(cr, "n", false)
    return
  end

  -- Find subtree end via TreeSitter
  local node = tree.get_list_item_at_cursor(bufnr)
  local insert_row
  if node then
    local _, end_row = tree.get_subtree_range(node)
    insert_row = end_row + 1 -- 0-indexed, line AFTER subtree
  else
    -- Fallback: insert after current line
    insert_row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed row = 0-indexed next
  end

  local new_marker = next_marker(marker)
  local new_line = indent .. new_marker

  vim.api.nvim_buf_set_lines(bufnr, insert_row, insert_row, false, { new_line })
  vim.api.nvim_win_set_cursor(0, { insert_row + 1, #new_line })

  -- Reparse and renumber if ordered
  tree.reparse(bufnr)
  if new_marker:match("^%d") then
    local new_node = tree.get_list_item_at_cursor(bufnr)
    if new_node then
      vim.cmd("undojoin")
      renumber.renumber_parent_list(new_node, bufnr)
    end
  end

  vim.cmd("startinsert!")
end

--- Handle Enter in Insert mode.
--- Splits text at cursor position, creates new bullet with remainder.
--- Empty bullet (no text after marker): delete line, exit Insert.
function M.enter_insert()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] -- 1-indexed
  local col = cursor[2] -- 0-indexed byte position
  local line = vim.api.nvim_get_current_line()

  local indent, marker, content = parse_bullet(line)
  if not indent or not marker then
    -- Not on a bullet line, fall through to default Enter
    local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    vim.api.nvim_feedkeys(cr, "n", false)
    return
  end

  local prefix_len = #indent + #marker

  -- Empty bullet check: no content text at all
  if content:match("^%s*$") then
    -- Remove this line and exit Insert mode
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, {})
    if row > 1 then
      local prev_line = vim.api.nvim_buf_get_lines(bufnr, row - 2, row - 1, false)[1]
      vim.api.nvim_win_set_cursor(0, { row - 1, #(prev_line or "") })
    end
    vim.cmd("stopinsert")
    return
  end

  -- Clamp cursor to content area (if cursor is on the marker, treat as start of content)
  if col < prefix_len then
    col = prefix_len
  end

  -- Split text at cursor position, trim leading space from remainder
  local text_before = line:sub(prefix_len + 1, col)
  local text_after = line:sub(col + 1):gsub("^%s+", "")

  -- Update current line (trim text after cursor)
  local current_line_new = indent .. marker .. text_before
  vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { current_line_new })

  -- Subtree skip: find end of current subtree
  local node = tree.get_list_item_at_cursor(bufnr)
  local insert_row
  if node then
    tree.reparse(bufnr)
    node = tree.get_list_item_at_cursor(bufnr)
    if node then
      local _, end_row = tree.get_subtree_range(node)
      insert_row = end_row + 1 -- 0-indexed
    else
      insert_row = row -- 0-indexed = 1-indexed current = line after
    end
  else
    insert_row = row
  end

  -- Insert new line at subtree end
  local new_marker = next_marker(marker)
  local new_line = indent .. new_marker .. text_after
  vim.cmd("undojoin")
  vim.api.nvim_buf_set_lines(bufnr, insert_row, insert_row, false, { new_line })

  vim.api.nvim_win_set_cursor(0, { insert_row + 1, #indent + #new_marker })

  tree.reparse(bufnr)
  -- Renumber if ordered
  if new_marker:match("^%d") then
    local new_node = tree.get_list_item_at_cursor(bufnr)
    if new_node then
      vim.cmd("undojoin")
      renumber.renumber_parent_list(new_node, bufnr)
    end
  end
end

--- Handle o in Normal mode.
--- Has children: create first child (before existing children).
--- Leaf: create sibling below.
function M.o_normal()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_get_current_line()
  local indent, marker, _ = parse_bullet(line)
  if not indent or not marker then
    -- Not on a bullet, fall through to native o
    local o_key = vim.api.nvim_replace_termcodes("o", true, false, true)
    vim.api.nvim_feedkeys(o_key, "n", false)
    return
  end

  local node = tree.get_list_item_at_cursor(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed

  local first = node and tree.first_child(node)

  if first then
    -- Has children: create child before existing children
    fold.ensure_unfolded(row)

    local sw = vim.bo[bufnr].shiftwidth
    if sw == 0 then
      sw = 2
    end
    local new_indent = indent .. string.rep(" ", sw)
    local new_marker = child_marker(marker)
    local new_line = new_indent .. new_marker

    -- Insert before first child
    local child_row = first:start() -- 0-indexed
    vim.api.nvim_buf_set_lines(bufnr, child_row, child_row, false, { new_line })
    vim.api.nvim_win_set_cursor(0, { child_row + 1, #new_line })
  else
    -- Leaf: create sibling after current item's subtree end
    local new_marker = next_marker(marker)
    local new_line = indent .. new_marker

    local insert_row
    if node then
      local _, end_row = tree.get_subtree_range(node)
      insert_row = end_row + 1 -- 0-indexed, line AFTER subtree
    else
      insert_row = row -- fallback: after current line (0-indexed)
    end

    vim.api.nvim_buf_set_lines(bufnr, insert_row, insert_row, false, { new_line })
    vim.api.nvim_win_set_cursor(0, { insert_row + 1, #new_line })
  end

  tree.reparse(bufnr)
  vim.cmd("startinsert!")
end

--- Handle O in Normal mode.
--- Insert line above with same indent and marker. Enter Insert mode.
function M.o_upper_normal()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_get_current_line()
  local indent, marker, _ = parse_bullet(line)
  if not indent or not marker then
    -- Not on a bullet, fall through to native O
    local key = vim.api.nvim_replace_termcodes("O", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed

  -- For checkboxes, new item gets unchecked
  local new_marker = marker
  if marker:match("%[x%]") then
    new_marker = marker:gsub("%[x%]", "[ ]")
  end

  local new_line = indent .. new_marker
  vim.api.nvim_buf_set_lines(bufnr, row - 1, row - 1, false, { new_line })
  vim.api.nvim_win_set_cursor(0, { row, #new_line })

  tree.reparse(bufnr)
  -- Renumber if ordered
  if new_marker:match("^%d") then
    local new_node = tree.get_list_item_at_cursor(bufnr)
    if new_node then
      vim.cmd("undojoin")
      renumber.renumber_parent_list(new_node, bufnr)
    end
  end

  vim.cmd("startinsert!")
end

--- Check a checkbox: replace [ ] with [x] on current line.
--- No-op on non-checkbox lines or already checked.
function M.check()
  local line = vim.api.nvim_get_current_line()
  local new_line = line:gsub("^(%s*[-*+] )%[ %]", "%1[x]", 1)
  if new_line ~= line then
    vim.api.nvim_set_current_line(new_line)
  end
end

--- Uncheck a checkbox: replace [x] with [ ] on current line.
--- No-op on non-checkbox lines or already unchecked.
function M.uncheck()
  local line = vim.api.nvim_get_current_line()
  local new_line = line:gsub("^(%s*[-*+] )%[x%]", "%1[ ]", 1)
  if new_line ~= line then
    vim.api.nvim_set_current_line(new_line)
  end
end

--- Attach bullet keymaps to a buffer.
--- @param bufnr integer Buffer number
--- @param config table Config with keymaps
function M.attach(bufnr, config)
  local keymaps = config.keymaps or {}

  local key

  key = keymaps.enter_normal
  if key then
    vim.keymap.set("n", key, M.enter_normal, {
      buffer = bufnr,
      silent = true,
      desc = "Bullet: new sibling after subtree",
    })
  end

  key = keymaps.enter_insert
  if key then
    vim.keymap.set("i", key, M.enter_insert, {
      buffer = bufnr,
      silent = true,
      desc = "Bullet: split or continue",
    })
  end

  key = keymaps.o_normal
  if key then
    vim.keymap.set("n", key, M.o_normal, {
      buffer = bufnr,
      silent = true,
      desc = "Bullet: child or sibling below",
    })
  end

  key = keymaps.o_upper_normal
  if key then
    vim.keymap.set("n", key, M.o_upper_normal, {
      buffer = bufnr,
      silent = true,
      desc = "Bullet: sibling above",
    })
  end

  key = keymaps.check
  if key then
    vim.keymap.set("n", key, M.check, {
      buffer = bufnr,
      silent = true,
      desc = "Check checkbox",
    })
  end

  key = keymaps.uncheck
  if key then
    vim.keymap.set("n", key, M.uncheck, {
      buffer = bufnr,
      silent = true,
      desc = "Uncheck checkbox",
    })
  end
end

return M
