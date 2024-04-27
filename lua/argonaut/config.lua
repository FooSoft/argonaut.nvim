local configs = {
    default = {
        brace_last_indent = false,
        brace_last_wrap = true,
        brace_pad = false,
        comma_last = false,
        comma_prefix = false,
        comma_prefix_indent = false,
        line_prefix = '',
    },
    go = {
        comma_last = true,
    },
}

local function set(opts, filetypes)
    if opts then
        if type(filetypes) == 'string' then
            filetypes = {filetypes}
        elseif not filetypes then
            filetypes = {'default'}
        end

        for _, filetype in ipairs(filetypes) do
            local config = configs[filetype]
            if not config then
                config = {}
                configs[filetype] = config
            end

            for key, value in pairs(opts) do
                config[key] = value
            end
        end
    end
end

local function get()
    local file_config = configs[vim.bo.filetype]

    local config = {}
    for key, value in pairs(configs.default) do
        config[key] = value
        if file_config then
            local file_value = file_config[key]
            if file_value ~= nil then
                config[key] = file_config[key]
            end
        end
    end

    return config
end

return {
    set = set,
    get = get,
}
