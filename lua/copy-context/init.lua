local M = {}

-- Store custom extractors separately, only merge when needed
local custom_extractors = nil

function M.setup(opts)
    opts = opts or {}

    -- Store custom extractors for lazy loading
    if opts.custom_extractors then
        custom_extractors = opts.custom_extractors
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
        M.copy_github_permalink()
    end, { range = true })

    vim.api.nvim_create_user_command('CopyGitHubFile', function()
        M.copy_github_file()
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
            M.copy_github_permalink()
        end, { desc = 'Copy GitHub permalink' })
        vim.keymap.set('n', '<leader>cgY', function()
            M.copy_github_file()
        end, { desc = 'Copy GitHub file link' })
    end
end

-- Execute git command and return output or nil on failure
local function git_cmd(cmd)
    local output = vim.fn.system('git ' .. cmd .. ' 2>/dev/null'):gsub('\n', '')
    if vim.v.shell_error == 0 and output ~= '' then
        return output
    end
    return nil
end

-- Get tag name for a commit if it exists
local function get_tag_for_commit(commit_ref)
    return git_cmd('describe --exact-match --tags ' .. (commit_ref or 'HEAD'))
end

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

-- Lazy-load custom extractors on first use
local function get_all_extractors()
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
local function get_explorer_file()
    local buftype = vim.bo.buftype

    -- Early return if we're not in a special buffer
    if buftype == '' then
        return nil
    end

    -- Only iterate through extractors if we might be in an explorer
    for _, extractor in ipairs(get_all_extractors()) do
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

-- Build the base reference for the current buffer's path
local function build_base_ref()
    local current_file = vim.fn.expand('%')

    -- Only check explorers if normal expand returns empty
    if current_file == '' then
        local explorer_file = get_explorer_file()
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

-- Parse GitHub URL from remote URL string
local function parse_github_url(remote_url)
    if not remote_url then return nil, nil end

    local user, repo
    -- SSH format: git@github.com:user/repo.git
    user, repo = remote_url:match('git@github%.com:([^/]+)/([^%.]+)%.git')

    -- HTTPS format: https://github.com/user/repo.git
    if not user then
        user, repo = remote_url:match('https://github%.com/([^/]+)/([^%.]+)%.git')
    end

    -- HTTPS format without .git: https://github.com/user/repo
    if not user then
        user, repo = remote_url:match('https://github%.com/([^/]+)/([^/]+)/?$')
    end

    return user, repo
end

-- Get GitHub remote URL and parse repo info (optimized to check both remotes at once)
local function get_github_repo_info()
    -- Get all remotes at once, then parse
    local remotes_output = git_cmd('remote -v')
    if not remotes_output then
        return nil, nil
    end

    -- Look for upstream first, then origin
    for _, remote_name in ipairs({'upstream', 'origin'}) do
        local remote_url = remotes_output:match(remote_name .. '%s+([^%s]+)')
        if remote_url then
            local user, repo = parse_github_url(remote_url)
            if user and repo then
                return user, repo
            end
        end
    end

    return nil, nil
end

-- Build GitHub permalink
local function build_github_permalink()
    local current_file = vim.fn.expand('%')

    -- Only check explorers if needed
    if current_file == '' then
        current_file = get_explorer_file()
        if not current_file then
            return nil, "No file open"
        end
    end

    local git_root = git_cmd('rev-parse --show-toplevel')
    if not git_root then
        return nil, "Not in a git repository"
    end

    local user, repo = get_github_repo_info()
    if not user or not repo then
        return nil, "Could not find GitHub remote (upstream or origin)"
    end

    -- Get commit reference - prefer tags, then upstream branch, then HEAD
    local commit_ref

    -- First, check if current HEAD is on a tag
    commit_ref = get_tag_for_commit()
    if commit_ref then
        -- Found a tag for current HEAD, use it
    else
        -- Try to get the upstream commit if we're on a tracking branch
        -- Note: this might fail in detached HEAD state (when checked out to a tag)
        local upstream_branch = git_cmd('rev-parse --abbrev-ref --symbolic-full-name @{upstream}')
        if upstream_branch then
            -- We have an upstream, use the merge-base (common ancestor) or upstream HEAD
            local merge_base = git_cmd('merge-base HEAD ' .. upstream_branch)
            if merge_base then
                -- Check if merge-base is on a tag
                commit_ref = get_tag_for_commit(merge_base) or merge_base
            else
                -- Fallback to upstream HEAD - but we can derive this from upstream_branch
                -- Instead of another rev-parse, just use the upstream_branch ref directly
                commit_ref = upstream_branch
            end
        end

        -- Fallback to current HEAD if upstream logic fails (common in detached HEAD)
        if not commit_ref then
            commit_ref = git_cmd('rev-parse HEAD')
            if not commit_ref then
                return nil, "Could not get current commit hash"
            end
        end
    end

    -- Get relative path from git root
    local relative_path = vim.fn.fnamemodify(current_file, ':p')
    if string.sub(relative_path, 1, #git_root) == git_root then
        relative_path = string.sub(relative_path, #git_root + 2)
    else
        return nil, "File is not within git repository"
    end

    return string.format('https://github.com/%s/%s/blob/%s/%s', user, repo, commit_ref, relative_path), nil
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

function M.copy_file()
    local base = build_base_ref()
    finish_copy(base)
end

function M.copy_visual_or_line()
    local base = build_base_ref()
    local first, last = get_line_range()

    if first == last then
        finish_copy(base .. '#L' .. first)
    else
        finish_copy(base .. '#L' .. first .. '-' .. last)
    end
end

function M.copy_github_file()
    local permalink, err = build_github_permalink()
    if not permalink then
        vim.notify('GitHub file error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
        return
    end

    finish_copy(permalink)
end

function M.copy_github_permalink()
    local permalink, err = build_github_permalink()
    if not permalink then
        vim.notify('GitHub permalink error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
        return
    end

    local first, last = get_line_range()

    if first == last then
        finish_copy(permalink .. '#L' .. first)
    else
        finish_copy(permalink .. '#L' .. first .. '-L' .. last)
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
    get_all_extractors = get_all_extractors,
    build_base_ref = build_base_ref,
    get_explorer_file = get_explorer_file
}

return M