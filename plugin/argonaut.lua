if not vim.g.argonaut_loaded then
    local function argonaut_inspect()
        require('argonaut').inspect()
    end

    local function argonaut_object(ctx)
        require('argonaut').object(unpack(ctx.fargs))
    end

    local function argonaut_reflow()
        require('argonaut').reflow(false)
    end

    local function argonaut_reload()
        for name, _ in pairs(package.loaded) do
            if vim.startswith(name, 'argonaut') then
                package.loaded[name] = nil
            end
        end
    end

    local function argonaut_toggle()
        require('argonaut').reflow(true)
    end

    vim.api.nvim_create_user_command('ArgonautInspect', argonaut_inspect, {})
    vim.api.nvim_create_user_command('ArgonautObject', argonaut_object, {nargs = 1})
    vim.api.nvim_create_user_command('ArgonautReflow', argonaut_reflow, {})
    vim.api.nvim_create_user_command('ArgonautReload', argonaut_reload, {})
    vim.api.nvim_create_user_command('ArgonautToggle', argonaut_toggle, {})

    vim.g.argonaut_loaded = true
end
