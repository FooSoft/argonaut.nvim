if not vim.g.argonaut then
    local function argonaut_reload()
        for name, _ in pairs(package.loaded) do
            if vim.startswith(name, 'argonaut') then
                package.loaded[name] = nil
            end
        end
    end

    local function argonaut_reflow()
        argonaut_reload()
        require('argonaut').reflow()
    end

    vim.api.nvim_create_user_command('ArgonautReload', argonaut_reload, {})
    vim.api.nvim_create_user_command('ArgonautReflow', argonaut_reflow, {})

    vim.g.argonaut = true
end
