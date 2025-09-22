local M = {}

function M.setup(opts)
    opts = opts or {}

    -- Set up custom extractors for file explorers
    if opts.custom_extractors then
        require('copy-context.explorers').set_custom_extractors(opts.custom_extractors)
    end

    -- Set up commands
    require('copy-context.commands').setup_commands()

    -- Set up default keybindings if not disabled
    if not opts.disable_default_keymap then
        require('copy-context.commands').setup_keybindings()
    end
end

-- Export core functions for direct use
M.copy_file = require('copy-context.core').copy_file
M.copy_visual_or_line = require('copy-context.core').copy_visual_or_line
M.copy_context = require('copy-context.core').copy_context

return M