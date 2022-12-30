local argonaut = require('argonaut')

local function argonaut_wrap_toggle()
    argonaut.wrap_toggle()
end

local function argonaut_reload()
    package.loaded.argonaut = nil
    argonaut = require('argonaut')
end

if not vim.g.argonaut then
    vim.api.nvim_create_user_command('ArgonautWrapToggle', argonaut_wrap_toggle, {})
    vim.api.nvim_create_user_command('ArgonautReload', argonaut_reload, {})
    vim.g.argonaut = true
end
