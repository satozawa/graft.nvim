-- graft.nvim — tree-aware text objects and operators for Markdown bullet lists.
-- Public API: require("graft").setup(opts)

local M = {}

M.version = "0.1.0"

--- @class graft.Config
--- @field set_shiftwidth? boolean Set shiftwidth=2 for markdown buffers (default: true)
--- @field normalize_tabs? boolean Replace tabs with spaces on attach (default: true)
--- @field warn_odd_indent? boolean Warn about non-2-space indentation (default: true)
--- @field keymaps? graft.KeymapConfig Keymap overrides

--- @class graft.KeymapConfig
--- @field around_graft? string|false Text object: subtree (default: "ag")
--- @field inner_graft? string|false Text object: descendants (default: "ig")
--- @field inner_graft_shallow? string|false Text object: direct children (default: "iG")
--- @field next_sibling? string|false Motion: next sibling (default: "]g")
--- @field prev_sibling? string|false Motion: prev sibling (default: "[g")
--- @field first_child? string|false Motion: first child (default: "]G")
--- @field parent? string|false Motion: parent (default: "[G")
--- @field check? string|false Checkbox check (default: "[x")
--- @field uncheck? string|false Checkbox uncheck (default: "]x")
--- @field enter_normal? string|false Normal Enter (default: "<CR>")
--- @field enter_insert? string|false Insert Enter (default: "<CR>")
--- @field o_normal? string|false Normal o (default: "o")
--- @field o_upper_normal? string|false Normal O (default: "O")
--- @field move_up? string|false Move subtree up (default: "<M-k>")
--- @field move_down? string|false Move subtree down (default: "<M-j>")
--- @field promote? string|false Promote subtree (default: "<M-h>")
--- @field demote? string|false Demote subtree (default: "<M-l>")
--- @field smart_paste? string|false Smart paste (default: "]p")

--- @type graft.Config
local defaults = {
  set_shiftwidth = true,
  normalize_tabs = false,
  warn_odd_indent = true,
  keymaps = {
    around_graft = "ag",
    inner_graft = "ig",
    inner_graft_shallow = "iG",
    next_sibling = "]g",
    prev_sibling = "[g",
    first_child = "]G",
    parent = "[G",
    check = "[x",
    uncheck = "]x",
    enter_normal = "<CR>",
    enter_insert = "<CR>",
    o_normal = "o",
    o_upper_normal = "O",
    move_up = "<M-k>",
    move_down = "<M-j>",
    promote = "<M-h>",
    demote = "<M-l>",
    smart_paste = "]p",
  },
}

--- @type graft.Config
local config = {}

--- Merge user opts with defaults.
--- @param opts? graft.Config
--- @return graft.Config
local function merge_config(opts)
  opts = opts or {}
  local merged = vim.tbl_deep_extend("force", defaults, opts)
  return merged
end

--- Replace tab characters with spaces in a buffer.
--- @param bufnr integer
local function normalize_tabs(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local sw = vim.bo[bufnr].shiftwidth
  if sw == 0 then
    sw = 2
  end
  local spaces = string.rep(" ", sw)
  local changed = false
  for i, line in ipairs(lines) do
    if line:find("\t") then
      lines[i] = line:gsub("\t", spaces)
      changed = true
    end
  end
  if changed then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end
end

--- Warn about odd (non-2-space-multiple) indentation in list items.
--- Warns once per buffer, not per line.
--- @param bufnr integer
local function warn_odd_indent(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    local ws = line:match("^(%s+)[-*+%d]")
    if ws and #ws % 2 ~= 0 then
      vim.notify(
        string.format("graft.nvim: odd indent (%d spaces) on line %d", #ws, i),
        vim.log.levels.WARN
      )
      return -- warn once
    end
  end
end

--- Attach all graft keymaps to a markdown buffer.
--- Guarded against double-attach (e.g., if :set ft=markdown is run twice).
--- @param bufnr integer
local function attach(bufnr)
  -- Fold settings are window-local — always set, even on re-attach
  local fold_mod = require("graft.fold")
  fold_mod.attach(bufnr)

  -- Shiftwidth must be set on every FileType trigger because Neovim's
  -- built-in markdown ftplugin may override it after our first attach.
  if config.set_shiftwidth then
    vim.bo[bufnr].shiftwidth = 2
  end

  -- Guard against double-attach for buffer-local operations
  if vim.b[bufnr] and vim.b[bufnr].graft_attached then
    return
  end

  local tree_mod = require("graft.tree")
  if not tree_mod.has_parser(bufnr) then
    vim.notify("graft.nvim: markdown treesitter parser not found", vim.log.levels.WARN)
    return
  end

  -- Normalize tabs before any TreeSitter operations
  if config.normalize_tabs ~= false then
    normalize_tabs(bufnr)
  end

  -- Warn about odd indentation
  if config.warn_odd_indent ~= false then
    warn_odd_indent(bufnr)
  end

  local textobjects = require("graft.textobjects")
  local motions = require("graft.motions")
  local operations = require("graft.operations")
  local paste = require("graft.paste")
  local bullets = require("graft.bullets")

  textobjects.attach(bufnr, config)
  motions.attach(bufnr, config)
  operations.attach(bufnr, config)
  paste.attach(bufnr, config)
  bullets.attach(bufnr, config)

  vim.b[bufnr].graft_attached = true
end

--- Configure graft.nvim.
--- @param opts? graft.Config
function M.setup(opts)
  config = merge_config(opts)

  -- Register global <Plug> mappings (idempotent)
  local operations = require("graft.operations")
  operations.register_plug_mappings()

  -- Set up FileType autocmd for markdown
  local group = vim.api.nvim_create_augroup("graft", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(ev)
      attach(ev.buf)
    end,
  })

  -- Attach to any already-open markdown buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "markdown" then
      attach(buf)
    end
  end
end

return M
