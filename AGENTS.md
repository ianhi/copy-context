# copy-context

A `neovim` plugin to copy the current context for use in an AI agent prompt.

## Architecture

The plugin is organized into focused, single-responsibility modules:

### Core Modules

- **`init.lua`** (24 lines) - Ultra-clean main entry point
  - Setup orchestration and plugin initialization
  - Function exports for backwards compatibility

- **`core.lua`** (81 lines) - Core copying logic and utilities
  - `build_base_ref()` - Creates `@path/to/file` references
  - `copy_file()`, `copy_visual_or_line()`, `copy_context()` - Main copy functions
  - Visual mode detection and line range utilities

- **`commands.lua`** (50 lines) - Command and keybinding setup
  - `setup_commands()` - Creates vim user commands
  - `setup_keybindings()` - Sets up default keybindings

### Feature Modules

- **`explorers.lua`** (167 lines) - File explorer detection and support
  - Lazy-loaded extractors for nvim-tree, neo-tree, oil.nvim, netrw, snacks.nvim
  - Custom extractor system for extensibility
  - Zero performance impact on normal file editing

- **`github.lua`** (196 lines) - GitHub permalink functionality
  - Smart commit detection (tags → upstream → HEAD)
  - Git operations and GitHub URL generation
  - Support for both file links and line-specific permalinks

- **`debug.lua`** (80 lines) - Debug utilities and testing tools
  - `:CopyContextDebug` command for troubleshooting
  - File explorer testing and validation
  - Built-in testing guidance

## Key Features

### File Context Copying
- `@path/to/file` - File references
- `@path/to/file#L5` - Single line references
- `@path/to/file#L5-10` - Line range references

### File Explorer Support
Automatically detects and works with popular file explorers:
- **nvim-tree**, **neo-tree**, **oil.nvim**, **netrw**, **snacks.nvim**
- Lazy-loading architecture for zero performance impact
- Custom extractor system for adding new explorers

### GitHub Integration
- Smart commit detection for prettier URLs
- File links: `https://github.com/user/repo/blob/commit/file`
- Line permalinks: `https://github.com/user/repo/blob/commit/file#L5-L10`

### Commands
- `:CopyFileContext` - Copy file reference
- `:CopyLineContext` - Copy line/selection reference
- `:CopyGitHubFile` - Copy GitHub file link
- `:CopyGitHubPermalink` - Copy GitHub permalink with lines
- `:CopyContextDebug` - Debug file explorer detection

### Default Keybindings
- `<leader>cf` - Copy file context
- `<leader>cs` - Copy selection/line context
- `<leader>cgY` - Copy GitHub file link
- `<leader>cgy` - Copy GitHub permalink

## Benefits of Modular Architecture

✅ **Maintainability** - Each module has a single, clear responsibility
✅ **Testability** - Modules can be tested independently
✅ **Performance** - Lazy loading ensures minimal impact
✅ **Extensibility** - Easy to add new features without affecting existing code
✅ **Clarity** - Clean separation makes the codebase easy to understand

