if not vim.g.argonaut then
    local argonaut = require('argonaut')

    local function argonaut_reload()
        package.loaded.argonaut = nil
        argonaut = require('argonaut')
    end

    local function argonaut_reflow()
        argonaut_reload()
        argonaut.reflow()
    end

    vim.api.nvim_create_user_command('ArgonautReload', argonaut_reload, {})
    vim.api.nvim_create_user_command('ArgonautReflow', argonaut_reflow, {})

    vim.g.argonaut = true
end
