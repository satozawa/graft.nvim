# graft.nvim

A tiny outliner for Markdown bullet lists in Neovim.

<video src="https://github.com/user-attachments/assets/e0b09ded-af15-4eb7-a5f1-dcf825282bc7" width="700" controls muted></video>

Nested bullets are a nice way to organize thoughts. graft lets you move, select, and operate on them as subtrees.

## Requirements

- Neovim ≥ 0.10
- Tree-sitter `markdown` parser (`:TSInstall markdown`)

## Install

```lua
-- lazy.nvim
{ "satozawa/graft.nvim", ft = "markdown", opts = {} }
```

Or add `~/path/to/graft.nvim` to your runtimepath and call `require("graft").setup()`.

## Keymaps

graft only activates in Markdown buffers. Non-bullet lines fall through to native behavior.

### Subtree operations

| Key | Action |
|-----|--------|
| `Alt+k` / `Alt+j` | Move subtree up / down among siblings |
| `Alt+h` / `Alt+l` | Promote (outdent) / demote (indent) subtree |

Works in Normal and Insert mode.

### Navigation

| Key | Action |
|-----|--------|
| `]g` / `[g` | Next / previous sibling |
| `]G` / `[G` | First child / parent |

### Text objects

| Key | Selects |
|-----|---------|
| `ag` | Current item + all descendants |
| `ig` | Descendants only (excludes current item) |
| `iG` | Direct children and their subtrees |

`dag` delete subtree · `yag` yank subtree · `cag` change subtree · `>ag` indent subtree · `vag` select subtree

### Bullet continuation

| Key | Action |
|-----|--------|
| `Enter` | New sibling after subtree (Normal) or split text (Insert) |
| `o` | New child if item has children, otherwise new sibling |
| `O` | New sibling above |

Empty bullet + `Enter` removes the line.

### Other

| Key | Action |
|-----|--------|
| `]p` | Paste with indent adjusted to match tree context |
| `[x` / `]x` | Check / uncheck checkbox |

Subtree folding is set via `foldexpr`. Use Neovim's fold commands as usual.

## Configuration

All keymaps can be changed or disabled. Set any to `false` to turn it off.

```lua
require("graft").setup({
  keymaps = {
    move_up  = "<M-k>",  move_down = "<M-j>",
    promote  = "<M-h>",  demote    = "<M-l>",

    next_sibling = "]g",  prev_sibling = "[g",
    first_child  = "]G",  parent       = "[G",

    around_graft = "ag", inner_graft = "ig", inner_graft_shallow = "iG",

    enter_normal = "<CR>", enter_insert = "<CR>",
    o_normal = "o", o_upper_normal = "O",

    smart_paste = "]p", check = "[x", uncheck = "]x",
  },
})
```

Example — disable Enter/o/O overrides and remap operations to Ctrl:

```lua
require("graft").setup({
  keymaps = {
    enter_normal = false, enter_insert = false,
    o_normal = false, o_upper_normal = false,
    move_up = "<C-k>", move_down = "<C-j>",
    promote = "<C-h>", demote = "<C-l>",
  },
})
```

## macOS terminal setup

If `Alt+hjkl` produces special characters instead of working as modifiers:

| Terminal | Setting |
|----------|---------|
| Ghostty | `macos-option-as-alt = left` |
| Kitty | `macos_option_as_alt yes` |
| iTerm2 | Preferences → Profiles → Keys → Left Option → `Esc+` |
| WezTerm | `send_composed_key_when_left_alt_is_pressed = false` |

## License

[MIT](LICENSE)
