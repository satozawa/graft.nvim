-- Smart paste with indent adjustment for Markdown bullet lists.
-- Overrides `]p` in markdown buffers. Adjusts pasted list content
-- to match the indent level of the cursor's current list context.
-- Non-list content falls through to native `]p`.

local tree = require("graft.tree")
local renumber = require("graft.renumber")

local M = {}

--- Per-buffer opts storage so native_paste() can re-attach without losing config.
--- @type table<integer, table>
local buf_opts = {}

--- Tracks which buffers have BufDelete cleanup registered.
--- @type table<integer, boolean>
local buf_cleanup = {}

--- Pattern matching an unordered list marker: leading whitespace + [-*+] + space.
local UNORDERED_PATTERN = "^%s*[-*+]%s"

--- Pattern matching an ordered list marker: leading whitespace + digits + [.)] + space.
local ORDERED_PATTERN = "^%s*%d+[.)]%s"

--- Check if text looks like list content.
--- Examines the first non-empty line for a list marker.
--- @param lines string[] Lines to check
--- @return boolean
function M.is_list_content(lines)
  for _, line in ipairs(lines) do
    if line:match("%S") then
      return line:match(UNORDERED_PATTERN) ~= nil
        or line:match(ORDERED_PATTERN) ~= nil
    end
  end
  return false
end

--- Execute native `]p` without recursing into the graft override.
--- Temporarily removes the buffer-local ]p mapping, executes native ]p,
--- then restores the mapping. This guarantees no recursion regardless of
--- how Neovim resolves nvim_feedkeys noremap vs buffer-local mappings.
--- @param bufnr integer
local function native_paste(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  -- Remove our override so native ]p runs
  local cfg_key = ((buf_opts[bufnr] or {}).keymaps or {}).smart_paste or "]p"
  pcall(vim.keymap.del, "n", cfg_key, { buffer = bufnr })
  local reg = vim.v.register ~= "" and ('"' .. vim.v.register) or ""
  vim.cmd("normal! " .. reg .. vim.v.count1 .. "]p")
  -- Restore the override with preserved opts
  M.attach(bufnr, buf_opts[bufnr])
end

--- Compute the leading whitespace length of a line.
--- @param line string
--- @return integer
local function leading_indent(line)
  local ws = line:match("^(%s*)")
  return ws and #ws or 0
end

--- Adjust indent of all lines by a delta (positive = add, negative = remove).
--- @param lines string[] Lines to adjust (modified in place)
--- @param delta integer Number of spaces to add (positive) or remove (negative)
--- @return string[] lines The adjusted lines (same table)
local function adjust_indent(lines, delta)
  if delta == 0 then
    return lines
  end
  local padding = delta > 0 and string.rep(" ", delta) or nil
  for i, line in ipairs(lines) do
    if line:match("%S") then
      if delta > 0 then
        lines[i] = padding .. line
      else
        -- Remove up to |delta| leading spaces
        local remove = math.min(-delta, leading_indent(line))
        lines[i] = line:sub(remove + 1)
      end
    end
    -- Leave blank lines untouched
  end
  return lines
end

--- Perform a smart paste: adjust pasted list content to match target indent.
--- If the pasted content is not a list, or the cursor is not on a list item,
--- falls through to native `]p`.
--- @param bufnr? integer Buffer number (default: current)
function M.smart_paste(bufnr)
  bufnr = bufnr or 0

  -- Step 1: Get register content
  local reg = vim.fn.getreg(vim.v.register)
  if not reg or reg == "" then
    native_paste(bufnr)
    return
  end

  -- Step 2: Split into lines
  local lines = vim.split(reg, "\n", { plain = true })

  -- Remove trailing empty line (registers often end with a newline)
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end

  if #lines == 0 then
    native_paste(bufnr)
    return
  end

  -- Step 3: Check if content looks like a list
  if not M.is_list_content(lines) then
    native_paste(bufnr)
    return
  end

  -- Step 4: Find target context — cursor must be on a list_item
  local node = tree.get_list_item_at_cursor(bufnr)
  if not node then
    native_paste(bufnr)
    return
  end

  local marker = tree.get_marker(node)
  if not marker then
    native_paste(bufnr)
    return
  end

  local _, target_indent = marker:start()

  -- Step 5: Compute source indent from first non-empty line
  local source_indent = 0
  for _, line in ipairs(lines) do
    if line:match("%S") then
      source_indent = leading_indent(line)
      break
    end
  end

  -- Step 6: Compute delta
  local delta = target_indent - source_indent

  -- Step 7: Apply delta
  adjust_indent(lines, delta)

  -- Step 8: Paste below current line
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
  vim.api.nvim_buf_set_lines(bufnr, cursor_row, cursor_row, false, lines)

  -- Position cursor on the first pasted line
  vim.api.nvim_win_set_cursor(0, { cursor_row + 1, target_indent })

  -- Step 9: Reparse, then renumber if ordered
  tree.reparse(bufnr)

  -- Check if the pasted content is in an ordered list context
  -- Re-fetch the node at the new cursor position after reparse
  -- undojoin keeps paste + renumber as one undo step
  local pasted_node = tree.get_list_item_at_cursor(bufnr)
  if pasted_node and tree.is_ordered(pasted_node) then
    vim.cmd("undojoin")
    renumber.renumber_parent_list(pasted_node, bufnr)
  end
end

--- Attach the `]p` smart paste keymap to a buffer.
--- @param bufnr integer Buffer number
--- @param opts? table Options (reserved for future use)
function M.attach(bufnr, opts)
  opts = opts or {}
  buf_opts[bufnr] = opts

  -- Clean up on buffer delete to prevent leak
  if not buf_cleanup[bufnr] then
    buf_cleanup[bufnr] = true
    vim.api.nvim_create_autocmd("BufDelete", {
      buffer = bufnr,
      once = true,
      callback = function()
        buf_opts[bufnr] = nil
        buf_cleanup[bufnr] = nil
      end,
    })
  end

  local key = (opts.keymaps or {}).smart_paste
  if key then
    vim.keymap.set("n", key, function()
      M.smart_paste()
    end, { buffer = bufnr, silent = true, desc = "Smart paste (graft)" })
  end
end

return M
