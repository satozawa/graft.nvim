# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Binding Decisions

These 7 decisions are binding. Do not re-litigate.

### 1. Scope
Bullet list outlines only. No heading manipulation, no table operations, no org-mode features, no heading-to-list conversion.

### 2. TreeSitter-First
All structural understanding comes from TreeSitter AST. No regex parsing. No manual indent counting.

### 3. Vim Grammar Composability
Operations are text objects + operators, not custom commands. `dag` prunes a subtree. `>ag` pushes it deeper. `yig` yanks inner tree.

### 4. Text Objects
- `ag` — a graft: current item + all descendants (linewise)
- `ig` — inner graft: descendants only, excluding current item
- `iG` — inner Graft shallow: direct children and their subtrees (first nested list)

TreeSitter captures in `queries/markdown/textobjects.scm`: `@graft.outer` (`list_item`), `@graft.inner` (`list_item > list`).

### 5. Motions
- `]g` / `[g` — next/prev sibling at same nesting level
- `]G` — first child (go deeper); `[G` — parent (go shallower)
- Count support: `3]g` skips 2 siblings. `2[G` goes up 2 levels.

### 6. Operations
- Move subtree up/down among siblings (`<Plug>(graft-move-up)` / `<Plug>(graft-move-down)`)
- Promote/demote subtree via `>ag` / `<ag` (Vim indent operators + graft text objects)
- Smart paste: `]p` adjusts indent to match target context (markdown buffers, list content only)
- Auto-renumber ordered lists after structural mutations
- shiftwidth guard: `setup()` sets `shiftwidth=2` for markdown buffers (opt-out via `set_shiftwidth = false`)

### 7. No Dependencies Beyond TreeSitter
Only Neovim >= 0.10 built-in TreeSitter support + markdown parser. Zero external plugins.

---

## Coding Standards

- **Lua** (LuaJIT-compatible). All plugin code in `lua/graft/`.
- **LuaCATS** type annotations on all public functions.
- Comments and variable names in English.
- `stylua` for formatting — follow `.stylua.toml` (2-space indent, 100 col width).
- Prefer explicit over clever. No metaprogramming unless eliminating significant duplication.
- Each module has a single responsibility. Public API is `require("graft").setup(opts)`.

## Testing

Tests use plenary.nvim (busted-style) in `tests/`. Run the full suite:

```
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" -c "qa"
```

Every text object and motion gets at least one test with sample markdown.

## Local Files

`.local/` and `.claude/` are local-only and must never be added to git.
