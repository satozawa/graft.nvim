local M = {}

--- Create a scratch buffer with markdown content and parse treesitter.
--- @param lines string[] Buffer lines
--- @return integer bufnr
function M.create_md_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile"
  -- Parse treesitter
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if ok and parser then
    parser:parse()
  end
  return buf
end

--- Set the current buffer and window to the given buffer.
--- @param buf integer
function M.set_buf(buf)
  vim.api.nvim_set_current_buf(buf)
end

--- Set cursor position (1-indexed row, 0-indexed col).
--- @param row integer 1-indexed
--- @param col? integer 0-indexed, default 0
function M.set_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col or 0 })
end

--- Get buffer lines.
--- @param buf integer
--- @return string[]
function M.get_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

--- Clean up a buffer.
--- @param buf integer
function M.cleanup(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

return M
