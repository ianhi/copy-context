-- Core copying functionality for copy-context plugin
local M = {}

-- Build the base reference for the current buffer's path
function M.build_base_ref()
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
function M.is_visual_mode()
    local mode = vim.fn.mode()
    return mode == 'v' or mode == 'V' or mode == '\22' -- visual modes
        or mode == 's' or mode == 'S' or mode == '\19' -- select modes
end

-- Get line range for current selection or current line
function M.get_line_range()
    if M.is_visual_mode() then
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
function M.finish_copy(ref)
    vim.fn.setreg('+', ref)
    vim.fn.setreg('"', ref)
    vim.notify('Copied: ' .. ref, vim.log.levels.INFO)
end

-- Copy file reference
function M.copy_file()
    local ref = M.build_base_ref()
    M.finish_copy(ref)
end

-- Copy visual selection or current line
function M.copy_visual_or_line()
    local base_ref = M.build_base_ref()
    if base_ref == '@[No file]' then
        M.finish_copy(base_ref)
        return
    end

    local first, last = M.get_line_range()
    if first == last then
        M.finish_copy(base_ref .. '#L' .. first)
    else
        M.finish_copy(base_ref .. '#L' .. first .. '-' .. last)
    end
end

-- Smart command: selection if present, else file (for user custom bindings)
function M.copy_context()
    if M.is_visual_mode() then
        return M.copy_visual_or_line()
    else
        return M.copy_file()
    end
end

return M