local options_current = {
    default = {
        brace_last_indent = false,
        brace_last_wrap = true,
        brace_pad = false,
        comma_last = false,
        comma_prefix = false,
        comma_prefix_indent = false,
    },
    go = {
        comma_last = true,
    },
    lua = {
        comma_last = true,
    },
}

local function setup(opt)
    for file_type, file_options in pairs(opt) do
        local file_options_current = options_current[file_type]
        if not file_options_current then
            file_options_current = {}
            options_current[file_type] = file_options_current
        end

        for param_name, param_value in pairs(file_options) do
            file_options_current[param_name] = param_value
        end
    end
end

local function query(param_name, pairing)
    assert(pairing)

    local default_param_value = options_current.default[param_name]
    local param_value = default_param_value

    local file_options_current = options_current[vim.bo.filetype]
    if file_options_current then
        param_value = file_options_current[param_name]
        if param_value == nil then
            param_value = default_param_value
        end
    end

    if type(param_value) == 'table' then
        param_value = param_value[pairing.open]
        if param_value == nil then
            param_value = default_param_value
        end
    end

    if type(param_value) == 'table' then
        param_value = param_value[pairing.open]
    end

    return param_value
end

return {
    setup = setup,
    query = query,
}
