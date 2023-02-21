local argonaut_configs = {
    default = {
        line_prefix = '',
        padded_braces = {},
        tail_comma = false,
        tail_comma_braces = {},
        tail_indent_braces = {},
        wrap_closing_brace = true,
        comma_first = false,
        comma_first_indent = false,
    },
    go = {
        tail_comma = true,
    }
}

local function setup(opts, filetypes)
    if opts then
        if type(filetypes) == 'string' then
            filetypes = {filetypes}
        elseif not filetypes then
            filetypes = {'default'}
        end

        for _, filetype in ipairs(filetypes) do
            local config = argonaut_configs[filetype]
            if not config then
                config = {}
                argonaut_configs[filetype] = config
            end

            for key, value in pairs(opts) do
                config[key] = value
            end
        end
    end
end

local function get_config()
    local file_config = argonaut_configs[vim.bo.filetype]

    local config = {}
    for key, value in pairs(argonaut_configs.default) do
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

local function get_cursor_pos()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return {row = row, col = col}
end

local function get_brace_alt(brace)
    local brace_pairs = {{'(', ')'}, {'[', ']'}, {'{', '}'}, {'<', '>'}}

    for _, brace_pair in ipairs(brace_pairs) do
        if brace_pair[1] == brace then
            return brace_pair[2], true
        elseif brace_pair[2] == brace then
            return brace_pair[1], false
        end
    end
end

local function is_string_literal(pos)
    if not pos then
        pos = get_cursor_pos()
    end

    local syn_id = vim.fn.synID(pos.row,  pos.col,  false)
    local syn_attr = vim.fn.synIDattr(syn_id, 'name')

    return syn_attr:find('String$')
end

local function find_brace_range(brace)
    local brace_alt, _ = get_brace_alt(brace)
    assert(brace_alt)

    local escape_brace = function(brace_raw)
        if brace_raw == '[' or brace_raw == ']' then
            return '\\' .. brace_raw
        else
            return brace_raw
        end
    end

    local row1, col1 = unpack(vim.fn.searchpairpos(escape_brace(brace), '', escape_brace(brace_alt), 'Wnb', is_string_literal))
    if row1 > 0 and col1 > 0 then
        local row2, col2 = unpack(vim.fn.searchpairpos(escape_brace(brace), '', escape_brace(brace_alt), 'Wcn', is_string_literal))
        if row2 > 0 and col2 > 0 then
            return {
                brace = brace,
                row1 = row1,
                col1 = col1,
                row2 = row2,
                col2 = col2
            }
        end
    end
end

local function find_all_brace_ranges(braces)
    local brace_ranges = {}
    for _, brace in ipairs(braces) do
        local brace_range = find_brace_range(brace)
        if brace_range then
            table.insert(brace_ranges, brace_range)
        end
    end

    if #brace_ranges > 0 then
        return brace_ranges
    end
end

local function find_closest_brace_range(braces)
    local cursor_pos = get_cursor_pos()
    local compare_brace_ranges = function(brace_range_1, brace_range_2)
        local row_diff1 = cursor_pos.row - brace_range_1.row1
        local row_diff2 = cursor_pos.row - brace_range_2.row1
        if row_diff1 < row_diff2 then
            return -1
        elseif row_diff1 > row_diff2 then
            return 1
        end

        local col_diff1 = cursor_pos.col - brace_range_1.col1
        local col_diff2 = cursor_pos.col - brace_range_2.col1
        if col_diff1 < col_diff2 then
            return -1
        elseif col_diff1 > col_diff2 then
            return 1
        end

        return 0
    end

    local brace_ranges = find_all_brace_ranges(braces)
    if brace_ranges then
        return vim.fn.sort(brace_ranges, compare_brace_ranges)[1]
    end
end

local function parse_brace_range(brace_range)
    brace_range.params = {}

    local first_line = vim.fn.getline(brace_range.row1)
    brace_range.indent = first_line:match('^(%s*)')
    brace_range.prefix = first_line:sub(#brace_range.indent + 1, brace_range.col1)

    local last_line = vim.fn.getline(brace_range.row2)
    brace_range.suffix = last_line:sub(brace_range.col2)

    local brace_range_param = nil
    local flush_brace_range_param = function()
        if brace_range_param then
            local left_pad_start, left_pad_end = brace_range_param.text:find('^%s+')
            if left_pad_start and left_pad_end then
                local pad_length = left_pad_end - left_pad_start + 1
                brace_range_param.col = brace_range_param.col + pad_length
                brace_range_param.text = brace_range_param.text:sub(pad_length + 1)
            end

            local right_pad_start, right_pad_end = brace_range_param.text:find('%s+$')
            if right_pad_start and right_pad_end then
                local pad_length = right_pad_end - right_pad_start + 1
                brace_range_param.text = brace_range_param.text:sub(1, #brace_range_param.text - pad_length)
            end

            if #brace_range_param.text > 0 then
                table.insert(brace_range.params, brace_range_param)
            end

            brace_range_param = nil
        end
    end

    local update_brace_range_param = function(element)
        if brace_range_param then
            brace_range_param.text = brace_range_param.text .. element.char
        else
            brace_range_param = {text = element.char, row = element.row, col = element.col, brace = element.brace}
        end
    end

    local brace_stack = {}
    local update_brace_stack = function(c)
        local brace_stack_size = #brace_stack
        local brace_alt, brace_open = get_brace_alt(c)
        if brace_stack_size > 0 and brace_alt == brace_stack[brace_stack_size] and not brace_open then
            table.remove(brace_stack, brace_stack_size)
        elseif brace_alt then
            table.insert(brace_stack, c)
        end
    end

    local brace_range_elements = {}
    local pad_newline = false

    for row = brace_range.row1, brace_range.row2 do
        local lead_padding = true
        local line = vim.fn.getline(row)

        local col1 = 1
        if row == brace_range.row1 then
            col1 = brace_range.col1 + 1
        end

        local col2 = #line
        if row == brace_range.row2 then
            col2 = brace_range.col2 - 1
        end

        for col = col1, col2 do
            local char = line:sub(col, col)
            assert(#char > 0)

            if lead_padding then
                if char:match('%s') then
                    if pad_newline and col == col1 then
                        char = ' '
                    else
                        char = nil
                    end
                else
                    lead_padding = false
                end
            end

            if char then
                table.insert(brace_range_elements, {
                    row = row,
                    col = col,
                    char = char,
                    brace = brace_range.brace,
                    literal = is_string_literal({row = row, col = col}),
                })

                if char == ',' then
                    pad_newline = true
                else
                    pad_newline = false
                end
            end
        end
    end

    if #brace_range_elements > 0 then
        for _, brace_range_element in ipairs(brace_range_elements) do
            local append = true
            if not brace_range_element.literal then
                update_brace_stack(brace_range_element.char)
                if #brace_stack == 0 and brace_range_element.char == ',' then
                    flush_brace_range_param()
                    append = false
                end
            end

            if append then
                update_brace_range_param(brace_range_element)
            end
        end

        flush_brace_range_param()
    end
end

local function wrap_brace_range(brace_range)
    local config = get_config()

    vim.fn.setline(brace_range.row1, brace_range.indent .. brace_range.prefix)

    local row = brace_range.row1
    for i, param in ipairs(brace_range.params) do
        local on_last_row = i == #brace_range.params

        local line = brace_range.indent .. param.text
        if config.tail_comma or not on_last_row then
            line = line .. ','
        end

        if on_last_row and not config.wrap_closing_brace then
            line = line .. brace_range.suffix
        end

        vim.fn.append(row, line)
        vim.fn.execute(string.format('%d>', row + 1))

        row = row + 1
    end

    if config.wrap_closing_brace then
        vim.fn.append(row, brace_range.indent .. brace_range.suffix)
    end
end

local function unwrap_brace_range(brace_range)
    local line = brace_range.indent .. brace_range.prefix
    for i, param in ipairs(brace_range.params) do
        line = line .. param.text
        if i < #brace_range.params then
            line = line .. ', '
        end
    end
    line = line .. brace_range.suffix

    vim.fn.setline(brace_range.row1, line)
    vim.fn.execute(string.format('%d,%dd_', brace_range.row1 + 1, brace_range.row2))
end

local function reflow()
    local brace_range = find_closest_brace_range({'(',  '[',  '{',  '<'})
    if brace_range then
        parse_brace_range(brace_range)
        if brace_range.row1 == brace_range.row2 then
            wrap_brace_range(brace_range)
        else
            unwrap_brace_range(brace_range)
        end
    end
end

return {
    reflow = reflow,
    setup = setup,
}
