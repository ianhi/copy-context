-- Command and keybinding setup for copy-context plugin
local M = {}

-- Set up user commands
function M.setup_commands()
    local core = require('copy-context.core')

    vim.api.nvim_create_user_command('CopyFileContext', function()
        core.copy_file()
    end, {})

    vim.api.nvim_create_user_command('CopyLineContext', function()
        core.copy_visual_or_line()
    end, { range = true })

    vim.api.nvim_create_user_command('CopyGitHubPermalink', function()
        require('copy-context.github').copy_github_permalink()
    end, { range = true })

    vim.api.nvim_create_user_command('CopyGitHubFile', function()
        require('copy-context.github').copy_github_file()
    end, {})

    -- Debug command for troubleshooting file explorer detection
    vim.api.nvim_create_user_command('CopyContextDebug', function()
        require('copy-context.debug').debug_current_buffer()
    end, {})
end

-- Set up default keybindings
function M.setup_keybindings()
    local core = require('copy-context.core')

    vim.keymap.set('n', '<leader>cf', function()
        core.copy_file()
    end, { desc = 'Copy file context' })

    vim.keymap.set({ 'n', 'v' }, '<leader>cs', function()
        core.copy_visual_or_line()
    end, { desc = 'Copy visual selection context' })

    vim.keymap.set({ 'n', 'v' }, '<leader>cgy', function()
        require('copy-context.github').copy_github_permalink()
    end, { desc = 'Copy GitHub permalink' })

    vim.keymap.set('n', '<leader>cgY', function()
        require('copy-context.github').copy_github_file()
    end, { desc = 'Copy GitHub file link' })
end

return M