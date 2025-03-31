if vim.g.argonaut_loaded then
    return
else
    vim.g.argonaut_loaded = true
end

vim.api.nvim_create_user_command(
    'ArgonautInspect',
    function()
        require('argonaut').inspect()
    end,
    {}
)

vim.api.nvim_create_user_command(
    'ArgonautObject',
    function(ctx)
        require('argonaut').object(unpack(ctx.fargs))
    end,
    {nargs = 1}
)

vim.api.nvim_create_user_command(
    'ArgonautReflow',
    function()
        require('argonaut').reflow(false)
    end,
    {}
)

vim.api.nvim_create_user_command(
    'ArgonautToggle',
    function()
        require('argonaut').reflow(true)
    end,
    {}
)
