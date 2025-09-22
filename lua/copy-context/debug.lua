-- Debug utilities for copy-context plugin
local M = {}

-- Debug function to help troubleshoot file explorer detection
function M.debug_current_buffer()
    -- Get the main module and its internal functions
    local main_module = require('copy-context.init')
    local internals = main_module._internal

    local debug_output = {}
    table.insert(debug_output, '=== COPY-CONTEXT DEBUG ===')

    -- Buffer info
    local buftype = vim.bo.buftype
    local filetype = vim.bo.filetype
    local bufname = vim.fn.bufname('%')
    local expand_result = vim.fn.expand('%')

    table.insert(debug_output, string.format('buftype: "%s"', buftype))
    table.insert(debug_output, string.format('filetype: "%s"', filetype))
    table.insert(debug_output, string.format('bufname: "%s"', bufname))
    table.insert(debug_output, string.format('expand(%%): "%s"', expand_result))

    -- Test each extractor
    table.insert(debug_output, '')
    table.insert(debug_output, '--- Testing Extractors ---')
    for i, extractor in ipairs(internals.get_all_extractors()) do
        local extractor_name = 'Unknown'
        if i == 1 then extractor_name = 'nvim-tree'
        elseif i == 2 then extractor_name = 'neo-tree'
        elseif i == 3 then extractor_name = 'oil.nvim'
        elseif i == 4 then extractor_name = 'netrw'
        elseif i == 5 then extractor_name = 'snacks.nvim'
        else extractor_name = 'Custom-' .. (i-5)
        end

        local check_result = extractor.check()
        table.insert(debug_output, string.format('%d. %s check: %s', i, extractor_name, tostring(check_result)))

        if check_result then
            local ok, path_result = pcall(extractor.get_path)
            if ok then
                table.insert(debug_output, string.format('   -> get_path(): "%s"', path_result or 'nil'))
            else
                table.insert(debug_output, string.format('   -> get_path() ERROR: %s', path_result))
            end
        end
    end

    -- Test the full flow
    table.insert(debug_output, '')
    table.insert(debug_output, '--- Full Flow Test ---')
    local result = internals.build_base_ref()
    table.insert(debug_output, string.format('build_base_ref() result: "%s"', result))

    -- Testing guidance
    table.insert(debug_output, '')
    table.insert(debug_output, '--- TESTING GUIDE ---')
    table.insert(debug_output, 'To test all file explorers:')
    table.insert(debug_output, '• nvim-tree: Open with :NvimTreeToggle, focus file, run :CopyContextDebug')
    table.insert(debug_output, '• neo-tree: Open with :Neotree, focus file, run :CopyContextDebug')
    table.insert(debug_output, '• oil.nvim: Open with :Oil, focus file, run :CopyContextDebug')
    table.insert(debug_output, '• netrw: Open with :Ex or :Explore, focus file, run :CopyContextDebug')
    table.insert(debug_output, '• snacks: Open explorer/picker, focus file, run :CopyContextDebug')
    table.insert(debug_output, '')
    table.insert(debug_output, 'Expected results:')
    table.insert(debug_output, '• Explorer check should return true for current explorer only')
    table.insert(debug_output, '• get_path() should return valid file path')
    table.insert(debug_output, '• build_base_ref() should return @filename or @path/to/file')

    -- Join all output and copy to registers
    local full_output = table.concat(debug_output, '\n')
    vim.fn.setreg('+', full_output)
    vim.fn.setreg('"', full_output)

    -- Also print for immediate viewing
    print(full_output)
    vim.notify('Debug output copied to clipboard and unnamed register', vim.log.levels.INFO)
end

return M