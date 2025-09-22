local M = {}

function M.setup(opts)
    opts = opts or {}

    -- Set up custom extractors for file explorers
    if opts.custom_extractors then
        require('copy-context.explorers').set_custom_extractors(opts.custom_extractors)
    end

    -- Set up user commands
    vim.api.nvim_create_user_command('CopyContext', function()
        M.copy_context()
    end, {})

    vim.api.nvim_create_user_command('CopyFileContext', function()
        M.copy_file()
    end, {})

    vim.api.nvim_create_user_command('CopyLineContext', function()
        M.copy_visual_or_line()
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

    -- Set up default keybindings if not disabled
    if not opts.disable_default_keymap then
        vim.keymap.set('n', '<leader>cf', function()
            M.copy_file()
        end, { desc = 'Copy file context' })
        vim.keymap.set({ 'n', 'v' }, '<leader>cs', function()
            M.copy_visual_or_line()
        end, { desc = 'Copy visual selection context' })
        vim.keymap.set({ 'n', 'v' }, '<leader>cgy', function()
            require('copy-context.github').copy_github_permalink()
        end, { desc = 'Copy GitHub permalink' })
        vim.keymap.set('n', '<leader>cgY', function()
            require('copy-context.github').copy_github_file()
        end, { desc = 'Copy GitHub file link' })
    end
end

-- Build the base reference for the current buffer's path
local function build_base_ref()
    local current_file = vim.fn.expand('%')

    -- Only check explorers if normal expand returns empty
    if current_file == '' then
        local explorer_file = require('copy-context.explorers').get_explorer_file()
        if explorer_file then
            local relative_path = vim.fn.fnamemodify(explorer_file, ':.')
            return '@' .. relative_path
        end
        return '@[No file]'
    end

    -- Normal file case (most common, fastest path)
    local relative_path = vim.fn.fnamemodify(current_file, ':.')
    return '@' .. relative_path
end

-- Check if we're in visual/select mode
local function is_visual_mode()
    local mode = vim.fn.mode()
    return mode == 'v' or mode == 'V' or mode == '\22' -- visual modes
        or mode == 's' or mode == 'S' or mode == '\19' -- select modes
end

-- Get line range for current selection or current line
local function get_line_range()
    if is_visual_mode() then
        local vpos = vim.fn.getpos('v')
        local cpos = vim.fn.getpos('.')
        local first = math.min(vpos[2], cpos[2])
        local last = math.max(vpos[2], cpos[2])
        return first, last
    else
        local line = vim.fn.line('.')
        return line, line
    end
end

-- Write to clipboards and notify
local function finish_copy(ref)
    vim.fn.setreg('+', ref)
    vim.fn.setreg('"', ref)
    vim.notify('Copied: ' .. ref, vim.log.levels.INFO)
end

-- Copy file reference
function M.copy_file()
    local ref = build_base_ref()
    finish_copy(ref)
end

-- Copy line reference
function M.copy_line()
    local base_ref = build_base_ref()
    if base_ref == '@[No file]' then
        finish_copy(base_ref)
        return
    end

    local line = vim.fn.line('.')
    finish_copy(base_ref .. '#L' .. line)
end

-- Copy visual selection or current line
function M.copy_visual_or_line()
    local base_ref = build_base_ref()
    if base_ref == '@[No file]' then
        finish_copy(base_ref)
        return
    end

    local first, last = get_line_range()
    if first == last then
        finish_copy(base_ref .. '#L' .. first)
    else
        finish_copy(base_ref .. '#L' .. first .. '-' .. last)
    end
end

-- Backwards-compatible smart command: selection if present, else file
function M.copy_context()
    if is_visual_mode() then
        return M.copy_visual_or_line()
    else
        return M.copy_file()
    end
end

-- Expose internal functions for debugging (only when debug module is loaded)
M._internal = {
    build_base_ref = build_base_ref
}

return M