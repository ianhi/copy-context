We are making a neovim plugin called `copy-context` that copies file and line
references in multiple formats for use with AI agents and sharing code.

## Architecture

The plugin uses a modular architecture with focused single-responsibility modules:

### Core Modules
- **`init.lua`** (24 lines) - Plugin entry point and setup orchestration
- **`core.lua`** (81 lines) - Core copying logic and utilities
- **`commands.lua`** (50 lines) - Command and keybinding setup

### Feature Modules
- **`explorers.lua`** (167 lines) - File explorer support (nvim-tree, neo-tree, oil.nvim, netrw, snacks.nvim)
- **`github.lua`** (196 lines) - GitHub permalink generation with smart commit detection
- **`debug.lua`** (80 lines) - Debug utilities and testing tools

## Core Functionality

### AI Agent Format
Copy file references in `@file` format for AI agents:
- File: `@src/main.py`
- Single line: `@src/main.py#L5`
- Line range: `@src/main.py#L5-10`

### GitHub Permalinks
Copy GitHub URLs that link directly to code:
- File: `https://github.com/user/repo/blob/v1.2.3/src/main.py`
- With lines: `https://github.com/user/repo/blob/v1.2.3/src/main.py#L5-L10`

### File Explorer Support
Automatically detects when you're in a file explorer and copies the focused file:
- **nvim-tree**, **neo-tree**, **oil.nvim**, **netrw**, **snacks.nvim**
- Lazy-loading for zero performance impact on normal editing
- Custom extractor system for adding new explorers

## Smart Reference Selection

The plugin intelligently chooses the best commit reference:
1. **Git tags** (v1.2.3) - for prettier, stable URLs
2. **Upstream merge-base** - for branch collaboration
3. **Current HEAD** - fallback for local work

Paths resolve relative to git root when available, otherwise relative to cwd.

## Commands & Keybindings

- `<leader>cf` / `:CopyFileContext` - Copy AI agent file reference
- `<leader>cs` / `:CopyLineContext` - Copy AI agent line reference
- `<leader>cgY` / `:CopyGitHubFile` - Copy GitHub file link
- `<leader>cgy` / `:CopyGitHubPermalink` - Copy GitHub permalink with lines
- `:CopyContextDebug` - Debug file explorer detection

### Available Functions for Custom Bindings
- `require('copy-context').copy_context()` - Smart function that copies selection if present, else file

The plugin is loadable via LazyVim from the `mpiannucci/copy-context` repository.

## Development Notes

### Modular Benefits
- **Maintainability**: Clear separation of concerns
- **Testability**: Each module can be tested independently
- **Performance**: Lazy loading ensures minimal impact
- **Extensibility**: Easy to add features without affecting existing code
