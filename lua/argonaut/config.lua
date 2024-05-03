local opt_curr = {
    default = {
        brace_last_indent = false,
        brace_last_wrap = true,
        brace_pad = false,
        comma_last = false,
        comma_prefix = false,
        comma_prefix_indent = false,
        line_max = 32,
        line_prefix = '',
        trim_inner_spaces = true,
    },
    go = {
        comma_last = true,
    },
    vim = {
        brace_last_wrap = false,
        line_prefix = '\\ ',
    }
}

local function setup(opt)
    for file_type, file_opt in pairs(opt) do
        local file_opt_curr = opt_curr[file_type]
        if not file_opt_curr then
            file_opt_curr = {}
            opt_curr[file_type] = file_opt_curr
        end

        for param_name, param_value in pairs(file_opt) do
            file_opt_curr[param_name] = param_value
        end
    end
end

local function get()
    local file_opt_curr = opt_curr[vim.bo.filetype]

    local file_opt = {}
    for param_name, param_value in pairs(opt_curr.default) do
        file_opt[param_name] = param_value
        if file_opt_curr then
            param_value = file_opt_curr[param_name]
            if param_value ~= nil then
                file_opt[param_name] = param_value
            end
        end
    end

    return file_opt
end

return {
    setup = setup,
    get = get,
}
