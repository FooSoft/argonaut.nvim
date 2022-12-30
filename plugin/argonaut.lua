if not vim.g.argonaut then
    local argonaut = require('argonaut')
    vim.api.nvim_create_user_command('ArgonautWrapToggle', argonaut.wrap_toggle, {})
    vim.g.argonaut = true
end
