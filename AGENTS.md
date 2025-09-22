# copy-context

A Neovim plugin to copy file and line references for AI agent prompts and code sharing.

## Architecture

Modular design with focused single-responsibility modules:

### Core Modules
- **`init.lua`** - Plugin entry point, setup orchestration, function exports
- **`core.lua`** - Core copying logic, reference building, visual mode detection
- **`commands.lua`** - Vim command and keybinding setup

### Feature Modules
- **`explorers.lua`** - File explorer detection (nvim-tree, neo-tree, oil.nvim, netrw, snacks.nvim)
- **`github.lua`** - GitHub permalink generation with smart commit detection
- **`debug.lua`** - Debug utilities and testing tools

## Output Formats

### AI Agent References
- `@path/to/file` - File references
- `@path/to/file#L5` - Single line references
- `@path/to/file#L5-10` - Line range references

### GitHub Permalinks
- `https://github.com/user/repo/blob/commit/file`
- `https://github.com/user/repo/blob/commit/file#L5-L10`

## Key Technical Details

### File Explorer Support
- Lazy-loaded extractors with zero performance impact on normal editing
- Custom extractor system for extensibility
- Automatic detection when focused on file explorer buffers

### Smart Commit Detection (GitHub)
Priority order: Git tags → upstream merge-base → current HEAD

### Path Resolution
Relative to git root when available, otherwise relative to current working directory

## Commands & Keybindings

**Commands:**
- `:CopyFileContext` / `<leader>cf` - Copy file reference
- `:CopyLineContext` / `<leader>cs` - Copy line/selection reference
- `:CopyGitHubFile` / `<leader>cgY` - Copy GitHub file link
- `:CopyGitHubPermalink` / `<leader>cgy` - Copy GitHub permalink with lines
- `:CopyContextDebug` - Debug file explorer detection

**Available for custom bindings:**
- `require('copy-context').copy_context()` - Smart function (selection if present, else file)

