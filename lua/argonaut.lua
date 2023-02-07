local ArgonautConfig = {
    line_prefix = '',
    padded_braces = {},
    tail_comma = false,
    tail_comma_braces = {},
    tail_indent_braces = {},
    wrap_closing_brace = true,
    comma_first = false,
    comma_first_indent = false,
}

local function setup(opts)
    if opts then
        for key, value in pairs(opts) do
            ArgonautConfig[key] = value
        end
    end
end

local function get_cursor_pos()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return {row = row, col = col}
end

local function is_literal(pos)
    if not pos then
        pos = get_cursor_pos()
    end

    local syn_id = vim.fn.synID(pos.row, pos.col, false)
    local syn_attr = vim.fn.synIDattr(syn_id, 'name')

    return syn_attr:find('String$')
end

local function find_range(brace_pair)
    local row1, col1 = unpack(vim.fn.searchpairpos(brace_pair[1], '', brace_pair[2], 'Wnb', is_literal))
    if row1 > 0 and col1 > 0 then
        local row2, col2 = unpack(vim.fn.searchpairpos(brace_pair[1], '', brace_pair[2], 'Wcn', is_literal))
        if row2 > 0 and col2 > 0 then
            return {
                brace_pair = brace_pair,
                row1 = row1,
                col1 = col1,
                row2 = row2,
                col2 = col2
            }
        end
    end
end

local function find_all_ranges(brace_pairs)
    local ranges = {}
    for _, brace_pair in ipairs(brace_pairs) do
        local range = find_range(brace_pair)
        if range then
            table.insert(ranges, find_range(brace_pair))
        end
    end

    if #ranges > 0 then
        return ranges
    end
end

local function find_closest_range(brace_pairs)
    local function compare_ranges(range1, range2)
        local pos = get_cursor_pos()

        local row_diff1 = pos.row - range1.row1
        local row_diff2 = pos.row - range2.row1
        if row_diff1 < row_diff2 then
            return -1
        elseif row_diff1 > row_diff2 then
            return 1
        end

        local col_diff1 = pos.col - range1.col1
        local col_diff2 = pos.col - range2.col1
        if col_diff1 < col_diff2 then
            return -1
        elseif col_diff1 > col_diff2 then
            return 1
        end

        return 0
    end

    local ranges = find_all_ranges(brace_pairs)
    if ranges then
        return vim.fn.sort(ranges, compare_ranges)[1]
    end
end

local function parse_range(range)
    local elements = {}
    for row = range.row1, range.row2 do
        local line = vim.fn.getline(row)

        local col1 = 0
        if row == range.row1 then
            col1 = range.col1 + 1
        end

        local col2 = #line
        if row == range.row2 then
            col2 = range.col2 - 1
        end

        for i = col1, col2 do
            table.insert(elements, {
                char = line:sub(i, i), ---@diagnostic disable-line: undefined-field
                literal = is_literal({row = row, col = i}),
            })
        end
    end

    local params = {}
    local param = ''
    local flush_param = function()
        if #param > 0 then
            table.insert(params, param)
            param = ''
        end
    end

    local brace_stack = {}
    local update_brace_stack = function(char)
        local brace_stack_size = #brace_stack

        local brace_pairs_forward = {
            ['('] = ')',
            ['['] = ']',
            ['{'] = '}',
            ['<'] = '>'
        }
        local brace_pairs_backward = {
            [')'] = '(',
            [']'] = '[',
            ['}'] = '{',
            ['>'] = '<'
        }

        if brace_stack_size > 0 and brace_stack[brace_stack_size] == brace_pairs_backward[char] then
            table.remove(brace_stack, brace_stack_size)
        elseif brace_pairs_forward[char] then
            table.insert(brace_stack, char)
        end
    end

    if #elements > 0 then
        for _, element in ipairs(elements) do
            local concat = true
            if not element.literal then
                update_brace_stack(element.char)
                if #brace_stack == 0 and element.char == ',' then
                    flush_param()
                    concat = false
                end
            end

            if concat then
                param = param .. element.char
            end
        end

        flush_param()
    end

    for _, p in ipairs(params) do
        print(p)
    end
end

local function reflow()
    local brace_pairs = {{'(', ')'}, {'\\[', '\\]'}, {'{', '}'}, {'<', '>'}}
    local range = find_closest_range(brace_pairs)
    if range then
        parse_range(range)
    end
end

return {
    reflow = reflow,
    ssetup = setup,
}
