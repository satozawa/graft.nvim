---
name: Bug report
about: Something isn't working
labels: bug
---

## What happened

<!-- Describe the bug. -->

## Expected behavior

<!-- What should have happened instead? -->

## Repro

Neovim version: <!-- output of `nvim --version` -->

Minimal config:
```lua
-- nvim --clean -u minimal.lua
vim.opt.rtp:prepend("path/to/graft.nvim")
require("graft").setup()

-- paste sample buffer content below
```

## Sample buffer

```markdown
- parent
  - child
```
