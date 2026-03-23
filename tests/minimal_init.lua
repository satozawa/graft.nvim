-- Minimal init for headless plenary tests
vim.cmd([[set runtimepath+=.]])
vim.cmd([[set runtimepath+=~/.local/share/nvim/site/pack/vendor/start/plenary.nvim]])
vim.cmd([[set runtimepath+=~/.local/share/nvim/site/pack/vendor/start/nvim-treesitter]])
vim.cmd([[runtime plugin/plenary.vim]])

-- Ensure markdown parser is available
local ok, _ = pcall(vim.treesitter.language.inspect, "markdown")
if not ok then
  pcall(function()
    vim.treesitter.language.add("markdown")
  end)
end
