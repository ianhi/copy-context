-- GitHub permalink functionality for copy-context plugin
local M = {}

-- Git command helper
local function git_cmd(cmd)
    local handle = io.popen('git ' .. cmd .. ' 2>/dev/null')
    if not handle then return nil end
    local result = handle:read('*a')
    handle:close()
    if result and result ~= '' then
        return result:gsub('%s+$', '') -- trim whitespace
    end
    return nil
end

-- Get tag for a specific commit (if it exists)
local function get_tag_for_commit(commit_ref)
    return git_cmd('describe --exact-match --tags ' .. (commit_ref or 'HEAD'))
end

-- Parse GitHub URL from remote URL string
local function parse_github_url(remote_url)
    if not remote_url then return nil, nil end

    -- Handle different GitHub URL formats
    local user, repo

    -- SSH format: git@github.com:user/repo.git
    user, repo = remote_url:match('git@github%.com:([^/]+)/(.+)%.git')
    if user and repo then
        return user, repo
    end

    -- HTTPS format: https://github.com/user/repo.git
    user, repo = remote_url:match('https://github%.com/([^/]+)/(.+)%.git')
    if user and repo then
        return user, repo
    end

    -- HTTPS format without .git: https://github.com/user/repo
    user, repo = remote_url:match('https://github%.com/([^/]+)/(.+)')
    if user and repo then
        return user, repo
    end

    return nil, nil
end

-- Get GitHub repository info
local function get_github_repo_info()
    -- Get the origin remote URL
    local remote_url = git_cmd('remote get-url origin')
    if not remote_url then
        return nil, nil, "No origin remote found"
    end

    local user, repo = parse_github_url(remote_url)
    if not user or not repo then
        return nil, nil, "Origin remote is not a GitHub repository"
    end

    return user, repo, nil
end

-- Build GitHub permalink
function M.build_github_permalink(current_file)
    if current_file == '' then
        current_file = require('copy-context.explorers').get_explorer_file()
        if not current_file then
            return nil, "No file open"
        end
    end

    local git_root = git_cmd('rev-parse --show-toplevel')
    if not git_root then
        return nil, "Not in a git repository"
    end

    local user, repo, err = get_github_repo_info()
    if not user then
        return nil, err
    end

    -- Smart commit detection logic:
    -- 1. If we're on a tag, use the tag name for prettier URLs
    -- 2. If we have an upstream branch, use merge-base with upstream
    -- 3. Otherwise, use current HEAD

    local commit_ref = nil

    -- Check if current HEAD is tagged
    local current_tag = get_tag_for_commit()
    if current_tag then
        commit_ref = current_tag
    else
        -- Try to find upstream branch and use merge-base
        local upstream_branch = git_cmd('rev-parse --abbrev-ref --symbolic-full-name @{u}')

        if upstream_branch then
            -- Get the merge-base between current branch and upstream
            local merge_base = git_cmd('merge-base HEAD ' .. upstream_branch)

            if merge_base then
                -- Check if merge-base has a tag (for prettier URLs)
                local base_tag = get_tag_for_commit(merge_base)
                if base_tag then
                    commit_ref = base_tag
                else
                    -- Use the upstream branch ref directly for consistency
                    commit_ref = upstream_branch
                end
            else
                -- If merge-base fails, just use upstream branch
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

-- Copy GitHub file link (file only, no lines)
function M.copy_github_file()
    local current_file = vim.fn.expand('%')
    local permalink, err = M.build_github_permalink(current_file)

    if not permalink then
        vim.notify('Error: ' .. err, vim.log.levels.ERROR)
        return
    end

    finish_copy(permalink)
end

-- Copy GitHub permalink with line numbers
function M.copy_github_permalink()
    local current_file = vim.fn.expand('%')
    local permalink, err = M.build_github_permalink(current_file)

    if not permalink then
        vim.notify('Error: ' .. err, vim.log.levels.ERROR)
        return
    end

    local first, last = get_line_range()
    if first == last then
        finish_copy(permalink .. '#L' .. first)
    else
        finish_copy(permalink .. '#L' .. first .. '-L' .. last)
    end
end

return M