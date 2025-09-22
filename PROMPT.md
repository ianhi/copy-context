# copy-context Plugin Development Context

A Neovim plugin for copying file and line references in formats optimized for AI agents and code sharing.

## Purpose
Generate standardized file references that AI agents can easily consume:
- `@path/to/file` - File references
- `@path/to/file#L5` - Single line references
- `@path/to/file#L5-10` - Line range references
- GitHub permalinks with smart commit detection

## Architecture
Modular design with 6 focused modules:
- `init.lua` - Setup orchestration
- `core.lua` - Core copying logic
- `commands.lua` - Command/keybinding setup
- `explorers.lua` - File explorer detection
- `github.lua` - GitHub permalink generation
- `debug.lua` - Debug utilities

## Key Features

**File Explorer Integration:** Automatically detects nvim-tree, neo-tree, oil.nvim, netrw, snacks.nvim when focused on files

**Smart GitHub URLs:** Chooses best commit reference (tags → upstream merge-base → HEAD)

**Lazy Loading:** Zero performance impact on normal editing

## Implementation Guidelines

**Path Resolution:** Relative to git root when available, else relative to cwd

**Error Handling:** Graceful fallbacks when git/explorer APIs unavailable

**Performance:** Lazy-load explorer APIs only when in explorer buffers

**Extensibility:** Custom extractor system for adding new file explorers
