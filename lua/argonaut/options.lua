local options_current = {
    brace_last_indent = false,
    brace_last_wrap = true,
    brace_pad = false,
    comma_last = {['{'] = true},
    comma_prefix = false,
    comma_prefix_indent = false,
    object_char = 'a',
    by_filetype = {
        go = {comma_last = true},
    },
}

local function merge_table(target, source)
    for key, value in pairs(source) do
        if type(target[key]) == 'table' then
            merge_table(target[key], value)
        else
            target[key] = value
        end
    end
end

local function query_with_pairing(value, pairing)
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
    merge_table(options_current, options)

    local object_char = query('object_char')
    for _, mode in ipairs({'x', 'o'}) do
        vim.api.nvim_set_keymap(
            mode,
            'i' .. object_char,
            ':<C-u>ArgonautInnerObject<cr>',
            {noremap = true, silent = true}
        )
        vim.api.nvim_set_keymap(
            mode,
            'a' .. object_char,
            ':<C-u>ArgonautOuterObject<cr>',
            {noremap = true, silent = true}
        )
    end
end

return {
    setup = setup,
    query = query,
}
