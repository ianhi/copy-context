-- File explorer support for copy-context plugin
local M = {}

-- Store custom extractors separately, only merge when needed
local custom_extractors = nil

-- File explorer extractors (lazy-loaded, checked in order)
-- Each extractor is only loaded when its check passes
local explorer_extractors = {
    -- nvim-tree
    {
        check = function()
            return vim.bo.filetype == 'NvimTree'
        end,
        get_path = function()
            -- Only require nvim-tree when we're actually in an nvim-tree buffer
            local ok, api = pcall(require, 'nvim-tree.api')
            if not ok then return nil end

            local node = api.tree.get_node_under_cursor()
            return node and node.absolute_path or nil
        end
    },

    -- neo-tree
    {
        check = function()
            return vim.bo.filetype == 'neo-tree'
        end,
        get_path = function()
            -- Only require neo-tree when we're actually in a neo-tree buffer
            local ok, manager = pcall(require, 'neo-tree.sources.manager')
            if not ok then return nil end

            local state = manager.get_state('filesystem')
            if not state or not state.tree then return nil end

            local node = state.tree:get_node()
            return node and node:get_id() or nil
        end
    },

    -- oil.nvim
    {
        check = function()
            return vim.bo.filetype == 'oil'
        end,
        get_path = function()
            -- Only require oil when we're actually in an oil buffer
            local ok, oil = pcall(require, 'oil')
            if not ok then return nil end

            -- Get the entry under cursor
            local entry = oil.get_cursor_entry()
            if not entry then return nil end

            local dir = oil.get_current_dir()
            return dir and (dir .. entry.name) or nil
        end
    },

    -- netrw (built-in, no require needed)
    {
        check = function()
            return vim.bo.filetype == 'netrw'
        end,
        get_path = function()
            local dir = vim.b.netrw_curdir or vim.fn.getcwd()
            local line = vim.fn.getline('.')
            -- Clean up the line (remove markers like @, /, *, etc.)
            local filename = line:gsub('^[%s@/*|\\]+', ''):gsub('[%s@/*|\\]+$', '')

            if filename ~= '' and filename ~= '..' and filename ~= '.' then
                return vim.fn.simplify(dir .. '/' .. filename)
            end
            return nil
        end
    },

    -- snacks.nvim explorer/picker
    {
        check = function()
            return vim.bo.filetype == 'snacks_explorer' or vim.bo.filetype == 'snacks_picker_list'
        end,
        get_path = function()
            local line = vim.fn.getline('.')
            if not line or line == '' then return nil end

            -- Parse the current line to extract filename
            -- Example: " ├╴  AGENTS.md" -> "AGENTS.md"
            local filename = line
                :gsub('^[%s│├└─╴]*', '')  -- Remove tree characters and spaces
                :gsub('^[%s]*', '')       -- Remove any remaining leading spaces
                :gsub('[%s]*$', '')       -- Remove trailing spaces

            if filename == '' or filename == '..' or filename == '.' then
                return nil
            end

            -- Get the current working directory as base
            local cwd = vim.fn.getcwd()

            -- For snacks picker, it might be showing files from different directories
            -- Try to build the full path
            local full_path = vim.fn.simplify(cwd .. '/' .. filename)

            -- Check if the file exists
            if vim.fn.filereadable(full_path) == 1 or vim.fn.isdirectory(full_path) == 1 then
                return full_path
            end

            -- If not found in cwd, try some common patterns
            -- Check if it's already a relative path that works
            if vim.fn.filereadable(filename) == 1 or vim.fn.isdirectory(filename) == 1 then
                return vim.fn.fnamemodify(filename, ':p')
            end

            -- Last resort: return the cleaned filename and let the user know
            return filename
        end
    }
}

-- Set custom extractors (called from main setup)
function M.set_custom_extractors(extractors)
    custom_extractors = extractors
end

-- Lazy-load custom extractors on first use
function M.get_all_extractors()
    if custom_extractors then
        -- Merge custom with built-in (only done once)
        local merged = {}
        for _, ext in ipairs(custom_extractors) do
            table.insert(merged, ext)
        end
        for _, ext in ipairs(explorer_extractors) do
            table.insert(merged, ext)
        end
        explorer_extractors = merged
        custom_extractors = nil  -- Clear to prevent re-merging
    end
    return explorer_extractors
end

-- Lazy-loaded: only checks explorers when called
function M.get_explorer_file()
    local buftype = vim.bo.buftype

    -- Early return if we're not in a special buffer
    if buftype == '' then
        return nil
    end

    -- Only iterate through extractors if we might be in an explorer
    for _, extractor in ipairs(M.get_all_extractors()) do
        if extractor.check() then
            -- Extractor's get_path will lazy-load the plugin if needed
            local path = extractor.get_path()
            if path then
                return path
            end
        end
    end
    return nil
end

return M