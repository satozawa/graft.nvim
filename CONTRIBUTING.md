# Contributing to graft.nvim

Thanks for your interest in contributing!

## Bug reports & feature requests

Open an [issue](https://github.com/satozawa/graft.nvim/issues). Include your Neovim version (`nvim --version`) and a minimal config to reproduce the problem.

## Pull requests

1. Fork the repo and create a branch from `main`
2. Keep changes focused — one fix or feature per PR
3. Test with a minimal config (`nvim --clean -u minimal.lua`)
4. Update the README if you're adding or changing keybindings

## Development setup

```bash
git clone https://github.com/your-fork/graft.nvim.git
cd graft.nvim

# Load locally with lazy.nvim
# dir = "~/path/to/graft.nvim"
```

## Code style

- Follow existing patterns in the codebase
- No external dependencies — graft uses only Neovim built-ins and Tree-sitter

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
