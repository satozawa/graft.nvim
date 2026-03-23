-- graft.nvim plugin entry point
-- Autoload guard: setup() is called by user in their config
if vim.g.loaded_graft then
  return
end

if vim.fn.has("nvim-0.10") ~= 1 then
  vim.api.nvim_echo({ { "graft.nvim requires Neovim >= 0.10", "ErrorMsg" } }, true, {})
  return
end

vim.g.loaded_graft = true
