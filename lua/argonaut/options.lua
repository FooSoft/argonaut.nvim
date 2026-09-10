local options_current = {
    brace_last_indent = false,
    brace_last_wrap = true,
    brace_pad = false,
    comma_last = false,
    comma_prefix = false,
    comma_prefix_indent = false,
    limit_cols = 512,
    limit_rows = 64,
    by_filetype = {
        go = { comma_last = true },
    },
}

local function merge_table(target, source)
    for key, value in pairs(source) do
        if type(target[key]) == 'table' and type(value) == 'table' then
            merge_table(target[key], value)
        else
            -- Later setup calls must not mutate tables supplied by the caller.
            target[key] = vim.deepcopy(value)
        end
    end
end

local function query_with_pairing(value, pairing)
    -- Only nil falls back: an explicit false overrides a wildcard or global value.
    if type(value) == 'table' and pairing then
        local sub_value = value[pairing.open]
        if sub_value == nil then
            value = value['*']
        else
            value = sub_value
        end
    end

    return value
end

local function query(name, pairing)
    -- Resolve per-brace values within the filetype override before global options.
    local options_current_by_filetype = options_current.by_filetype[vim.bo.filetype]
    if options_current_by_filetype then
        local value = query_with_pairing(options_current_by_filetype[name], pairing)
        if value ~= nil then
            return value
        end
    end

    return query_with_pairing(options_current[name], pairing)
end

local function setup(options)
    merge_table(options_current, options or {})
end

return {
    setup = setup,
    query = query,
}
